module Visor

using DataStructures
using UUIDs

const DEFAULT_PERIOD = 5

"""
Maximun numbers of restart in period seconds.
"""
const DEFAULT_INTENSITY = 1

const ROOT_SUPERVISOR = "root"
const NODE_SEP = "."

const INBOX_CAPACITY = 1000000

# default wait time before interrupting a process
const INTERRUPT_PROCESS_AFTER = 1.0
const STOP_WAITING_AFTER = Inf

export application
export call
export cast
export from
export getphase
export ifrestart
export hassupervised
export isprocstarted
export isrequest
export isshutdown
export @isshutdown
export process
export procs
export receive
export reply
export setphase
export setname
export shutdown
export startup
export supervise
export supervisor

abstract type Message end

abstract type Command end

"""
A response value is expected when a Request message is pushed
to the target process inbox.
"""
struct Request <: Message
    inbox::Channel
    request::Any
end

Base.show(io::IO, message::Request) = show(io, message.request)

Base.@kwdef struct Shutdown <: Command
    reset::Bool = true
end

struct UnknownProcess <: Exception
    pid::String
end

struct ProcessNotRunning <: Exception
    pid::String
end

uid()::String = string(uuid4())

format4print(dict::AbstractDict) = join(["$k=>$v($(v.status))" for (k, v) in dict], ", ")
format4print(lst::AbstractArray) = join(["$(v.id)=>$v($(v.status))" for v in lst], ", ")

@enum SupervisedStatus idle = 1 running = 2 failed = 3 done = 4

abstract type Supervised end

mutable struct Supervisor <: Supervised
    id::String
    status::SupervisedStatus
    phase::Symbol
    processes::OrderedDict{String,Supervised}
    intensity::Int
    period::Int
    strategy::Symbol
    terminateif::Symbol
    evhandler::Union{Nothing,Function}
    restarts::Vector{Supervised}
    supervisor::Supervisor
    inbox::Channel
    task::Task
    function Supervisor(
        id,
        processes=OrderedDict{String,Supervised}(),
        intensity=DEFAULT_INTENSITY,
        period=DEFAULT_PERIOD,
        strategy=:one_for_one,
        terminateif=:empty,
        evhandler=nothing,
    )
        return new(
            id,
            idle,
            :undef,
            processes,
            intensity,
            period,
            strategy,
            terminateif,
            evhandler,
            [],
        )
    end
    function Supervisor(
        parent::Supervisor,
        id,
        processes=OrderedDict{String,Supervised}(),
        intensity=DEFAULT_INTENSITY,
        period=DEFAULT_PERIOD,
        strategy=:one_for_one,
        terminateif=:empty,
        evhandler=nothing,
    )
        return new(
            id,
            idle,
            :undef,
            processes,
            intensity,
            period,
            strategy,
            terminateif,
            evhandler,
            [],
            parent,
        )
    end
end

nproc(process::Supervisor) = length(process.processes)

mutable struct Process <: Supervised
    id::String
    status::SupervisedStatus
    phase::Symbol
    fn::Function
    args::Tuple
    namedargs::NamedTuple
    startstamps::Vector{Float64}
    restart::Symbol
    isrestart::Bool
    force_interrupt_after::Float64
    stop_waiting_after::Float64
    debounce_time::Float64
    thread::Bool
    onhold::Bool
    inbox::Channel
    supervisor::Union{Nothing,Supervisor}
    task::Task
    function Process(
        id,
        fn,
        args=(),
        namedargs=(;),
        force_interrupt_after=INTERRUPT_PROCESS_AFTER,
        stop_waiting_after=STOP_WAITING_AFTER,
        debounce_time=NaN,
        thread=false,
        restart=:transient,
        supervisor=nothing,
    )
        begin
            new(
                id,
                idle,
                :undef,
                fn,
                args,
                namedargs,
                Float64[],
                restart,
                false,
                force_interrupt_after,
                stop_waiting_after,
                debounce_time,
                thread,
                false,
                Channel(INBOX_CAPACITY),
                supervisor,
            )
        end
    end
end

setphase(node::Supervised, phase::Symbol) = node.phase = phase

getphase(node::Supervised) = node.phase

function __init__()
    @async wait_signal(__ROOT__)
end

clear_hold(process::Process) = process.onhold = false
clear_hold(::Supervisor) = nothing

hold(process::Process) = process.onhold = true
hold(::Supervisor) = nothing

"""
    setname(process::Process, new_name::AbstractString)

Change the process name
"""
function setname(process::Process, new_name::AbstractString)
    sv = process.supervisor
    if sv !== nothing
        # maintain the order
        child = OrderedDict{String,Supervised}()
        for pname in keys(sv.processes)
            if pname != process.id
                child[pname] = sv.processes[pname]
            else
                child[new_name] = process
            end
        end
        process.supervisor.processes = child
    end
    return process.id = new_name
end

Base.show(io::IO, process::Supervised) = print(io, process.id)

function dump(node::Supervisor)
    children = [
        isa(p, Process) ? "$(p.id)($(p.status))" : "supervisor:$(p.id)($(p.status))" for
        p in values(node.processes)
    ]
    println("[$node] nodes: $children")
    for (id, el) in node.processes
        if isa(el, Supervisor)
            dump(el)
        end
    end
end

dump() = dump(__ROOT__)

function procs(node::Supervisor, tree::OrderedDict=OrderedDict())
    children = OrderedDict()
    for p in values(node.processes)
        children[p.id] = p
    end
    tree[node.id] = children
    for (id, el) in node.processes
        if isa(el, Supervisor)
            procs(el, tree[node.id])
        end
    end
    return tree
end

procs() = procs(__ROOT__)

isprocstarted(p::Process) = istaskstarted(p.task)

function isprocstarted(name::String)
    try
        p = from(name)
        return isprocstarted(p)
    catch e
        return false
    end
end

"""
    supervisor(
        id, processes;
        intensity=DEFAULT_INTENSITY,
        period=DEFAULT_PERIOD,
        strategy=:one_for_one,
        terminateif=:empty)::SupervisorSpec

Declare a supervisor of one or more `processes`.

`processes` may be a `Process` or an array of `Process`.

```jldoctest
julia> using Visor

julia> mytask(pd) = ();

julia> supervisor("mysupervisor", process(mytask))
mysupervisor
```

```jldoctest
julia> using Visor

julia> tsk1(pd) = ();

julia> tsk2(pd) = ();

julia> supervisor("mysupervisor", [process(tsk1), process(tsk2)])
mysupervisor

See [Supervisor](@ref) documentation for more details.
"""
function supervisor(
    id,
    processes::Vector{<:Supervised}=Supervised[];
    intensity=DEFAULT_INTENSITY,
    period=DEFAULT_PERIOD,
    strategy=:one_for_one,
    terminateif=:empty,
)::Supervisor
    if !(terminateif in [:shutdown, :empty])
        error("wrong shutdown value $shutdown: must be one of :empty, :shutdown")
    end

    if isempty(processes) && terminateif === :empty
        error("immediate shutdown of supervisor [$id] with no processes")
    end

    return Supervisor(
        id,
        OrderedDict{String,Supervised}(map(proc -> proc.id => proc, processes)),
        intensity,
        period,
        strategy,
        terminateif,
    )
end

function supervisor(
    id,
    proc::Supervised;
    intensity=DEFAULT_INTENSITY,
    period=DEFAULT_PERIOD,
    strategy=:one_for_one,
    terminateif=:empty,
)::Supervisor
    if !(terminateif in [:shutdown, :empty])
        error("wrong shutdown value $shutdown: must be one of :empty, :shutdown")
    end

    return Supervisor(
        id, OrderedDict(proc.id => proc), intensity, period, strategy, terminateif
    )
end

"""
    process(id, fn;
            args=(),
            namedargs=(;),
            force_interrupt_after::Real=1.0,
            stop_waiting_after::Real=Inf,
            debounce_time=NaN,
            thread=false,
            restart=:transient)::ProcessSpec

Declare a supervised task that may be forcibly interrupted.

`id` is the process name and `fn` is the task function.

`process` returns only a specification: the task function has to be started
with [`supervise`](@ref).

See [`process`](@ref) online docs for more details.
"""
function process(
    id,
    fn::Function;
    args::Tuple=(),
    namedargs::NamedTuple=(;),
    force_interrupt_after::Real=INTERRUPT_PROCESS_AFTER,
    stop_waiting_after::Real=STOP_WAITING_AFTER,
    debounce_time::Real=NaN,
    thread::Bool=false,
    restart=:transient,
)::Process
    if !(restart in [:permanent, :temporary, :transient])
        error(
            "wrong restart value $restart: must be one of :permanent, :temporary, :transient",
        )
    end

    return Process(
        id,
        fn,
        args,
        namedargs,
        force_interrupt_after,
        stop_waiting_after,
        debounce_time,
        thread,
        restart,
    )
end

"""
    process(fn;
            args=(),
            namedargs=(;),
            force_interrupt_after::Real=1.0,
            stop_waiting_after::Real=Inf,
            debounce_time=NaN,
            thread=false,
            restart=:transient)::ProcessSpec

The process name is set equals to `string(fn)`.
"""
process(
    fn::Function;
    args::Tuple=(),
    namedargs::NamedTuple=(;),
    force_interrupt_after::Real=INTERRUPT_PROCESS_AFTER,
    stop_waiting_after::Real=STOP_WAITING_AFTER,
    debounce_time=NaN,
    thread=false,
    restart=:transient,
)::Process = process(
    string(fn),
    fn;
    args=args,
    namedargs=namedargs,
    force_interrupt_after=force_interrupt_after,
    debounce_time=debounce_time,
    stop_waiting_after=stop_waiting_after,
    thread=thread,
    restart=restart,
)

abstract type ExitReason end

# The message `ProcessError` signals that
# the process was terminated by an exception.
struct ProcessError <: ExitReason
    process::Supervised
    error::Union{Exception,Nothing}
    ProcessError(process, error=nothing) = new(process, error)
end

# The message `ProcessReturn` signals that
# the node terminated normally.
struct ProcessReturn <: ExitReason
    process::Supervised
end

# The message  `ProcessInterrupted` signals that
# process node termination was forced by supervisor.manage: Visor.ProcessError(serve_zeromq:79e6b5c0-05a3-41a4-99a7-8ebec038b2d0, ZMQ.StateError("Address already in use"))
struct ProcessInterrupted <: ExitReason
    process::Supervised
end

# The message `ProcessFatal` signals that
# node failed to restart.
struct ProcessFatal <: ExitReason
    process::Supervised
end

# Scheduled by supervisor when forcing process node shutdown.
struct ProcessInterrupt <: Exception
    id::String
end

"Trigger a supervisor resync"
struct SupervisorResync end

# Returns the list of running nodes supervised by `supervisor`:
# processes and supervisors direct children.
function running_nodes(supervisor)
    return collect(Iterators.filter(p -> !istaskdone(p.task), values(supervisor.processes)))
end

isrunning(proc) = isdefined(proc, :task) && !istaskdone(proc.task)

function startchildren(sv::Supervisor)
    for node in values(sv.processes)
        @debug "[$sv]: starting [$node]"
        start(node)
    end
end

function start(proc::Process)
    isrunning(proc) && return nothing

    clear_hold(proc)

    if proc.thread
        proc.task = Threads.@spawn proc.fn(proc, proc.args...; proc.namedargs...)
    else
        proc.task = @async proc.fn(proc, proc.args...; proc.namedargs...)
    end
    @async wait_child(proc.supervisor, proc)
    proc.status = running

    return proc.task
end

start() = start(__ROOT__)

function start(sv::Supervisor)
    if isrunning(sv)
        # this supervisor is running but perhaps the children need to be started
        startchildren(sv)
        return nothing
    end

    @debug "[$sv] supervisor starting"
    sv.inbox = Channel(INBOX_CAPACITY)
    sv.task = @async manage(sv)
    sv.status = running

    @debug "[$sv] task: $(pointer_from_objref(sv.task))"
    startchildren(sv)
    if isdefined(sv, :supervisor)
        @async wait_child(sv.supervisor, sv)
    else
        (sv.id !== ROOT_SUPERVISOR) && @error "[$sv] undefined supervisor"
    end
    return sv.task
end

function startchain(proc)
    if isdefined(proc, :supervisor) &&
        (!isdefined(proc.supervisor, :task) || istaskdone(proc.supervisor.task))
        startchain(proc.supervisor)
    else
        start(proc)
    end
end

# Supervised restart logic based on `intensity`, `period` and `strategy` parameters.
function restart_policy(supervisor, process)
    now = time()
    push!(process.startstamps, now)
    filter!(t -> t > now - supervisor.period, process.startstamps)

    @debug "[$process] process retry startstamps: $(process.startstamps)"
    if length(process.startstamps) > supervisor.intensity
        @warn "[$process]: reached max of $(supervisor.intensity) restarts in $(supervisor.period) secs period"

        # removing failed processes make possible to manually startup again
        stopped = [process]
        if supervisor.strategy === :one_for_all
            stopped = supervisor_shutdown(supervisor)
        elseif supervisor.strategy === :rest_for_one
            stopped = supervisor_shutdown(supervisor, process)
        end

        for p in stopped
            delete!(supervisor.processes, p.id)
        end
        put!(supervisor.inbox, ProcessFatal(process))
    else
        process.isrestart = true
        if !isnan(process.debounce_time)
            sleep(process.debounce_time)
        end

        if process.status === idle
            # a shutdown was issued, terminate the restarts
            @debug "[$process]: honore the shutdown request"
            delete!(supervisor.processes, process.id)
        elseif supervisor.strategy === :one_for_one
            process.task = start(process)
        elseif supervisor.strategy === :one_for_all
            # If a child process terminates, all other child processes are terminated,
            # and then all child processes, including the terminated one, are restarted.
            @debug "[$supervisor] restart strategy: $(supervisor.strategy)"
            stopped = supervisor_shutdown(supervisor)
            supervisor.restarts = stopped
        elseif supervisor.strategy === :rest_for_one
            stopped = supervisor_shutdown(supervisor, process)
            supervisor.restarts = stopped
        end
    end
end

function restart_processes(supervisor, procs)
    for proc in procs
        start(proc)
        if isdefined(proc, :debounce_time) && !isnan(proc.debounce_time)
            @debug "[$proc] waiting for debounce_time $(proc.debounce_time) secs"
            sleep(proc.debounce_time)
        end
        if istaskfailed(proc.task)
            @debug "[$proc] task failed"
            break
        end
    end
    return supervisor.restarts = []
end

"""
    startup(proc::Supervised)

Start the supervised process defined by `proc` as children of the root supervisor.
"""
startup(proc::Supervised) = startup(__ROOT__, proc)

"""
    startup(supervisor::Supervisor, proc::Supervised)

Start the supervised process defined by `proc` as child of `supervisor`.

```jldoctest
julia> using Visor

julia> foo(self) = println("foo process started");

julia> main(self) = startup(self.supervisor, process(foo));

julia> supervise([process(main)]);
foo process started
```
"""
function startup(supervisor::Supervisor, proc::Supervised)
    if isdefined(proc, :task) &&
        haskey(supervisor.processes, proc.id) &&
        !istaskdone(proc.task)
        @warn "[$supervisor] already supervisioning proc [$proc]"
    else
        add_node(supervisor, proc)

        # start now if the supervisor control task is running
        if isdefined(supervisor, :task) && !istaskdone(supervisor.task)
            start(proc)
        end
    end
    return proc
end

"""
    add_node(supervisor::Supervisor, proc::Supervised)

Add supervised `proc` to the children's collection of the controlling `supervisor`.
"""
function add_node(supervisor::Supervisor, proc::Supervised)
    try
        @debug "[$supervisor] starting proc: [$proc]"
        if isa(proc, Supervisor)
            add_supervisor(supervisor, proc)
        else
            proc.supervisor = supervisor
            supervisor.processes[proc.id] = proc
        end
        return proc
    catch e
        @error "[$supervisor] starting proc [$proc]: $e"
    end
end

function add_supervisor(parent::Supervisor, svisor::Supervisor)::Supervisor
    @debug "[$parent]: add supervisor [$svisor]"

    parent.processes[svisor.id] = svisor
    svisor.supervisor = parent

    for proc in values(svisor.processes)
        add_node(svisor, proc)
    end
    return svisor
end

"""
    add_processes(
        svisor::Supervisor,
        processes;
        intensity,
        period,
        strategy,
        terminateif::Symbol=:empty
    )::Supervisor

Setup hierarchy relationship between supervisor and supervised list of processes
and configure supervisor behavior.
"""
function add_processes(
    svisor::Supervisor, processes; intensity, period, strategy, terminateif::Symbol=:empty
)::Supervisor
    @debug "[$svisor]: add_processes with strategy $strategy"

    svisor.intensity = intensity
    svisor.period = period
    svisor.strategy = strategy
    svisor.terminateif = terminateif

    for proc in processes
        add_node(svisor, proc)
    end
    return svisor
end

# Terminate all child processes in startup reverse order.
# If invoked with a `failed_proc` argument it terminates the processes
# as far as `failed_proc`.
function supervisor_shutdown(
    supervisor, failed_proc::Union{Supervised,Nothing}=nothing, reset::Bool=false
)
    stopped_procs = []
    revs = reverse(collect(values(supervisor.processes)))
    for p in revs
        @debug "[$p] set onhold"
        hold(p)
        push!(stopped_procs, p)
        if p === failed_proc
            @debug "[$p] failed_proc reached, stopping reverse shutdown"
            break
        end
        if istaskdone(p.task)
            @debug "[$p] skipping shutdown: task already done"
        else
            # shutdown is sequential because in case a node refuses
            # to shutdown remaining nodes aren't shut down.
            shutdown(p, reset)
        end
    end
    return reverse(stopped_procs)
end

function root_supervisor(process::Supervised)
    if !isdefined(process, :supervisor)
        isa(process, Process) && error("[$process] supervisor undefined")
        return process
    end
    return root_supervisor(process.supervisor)
end

function terminate_others(proc)
    try
        for (name, p) in collect(proc.supervisor.processes)
            if p !== proc
                p.status = idle
                @async shutdown(p)
            end
        end
    catch e
        @info e
    end
end

function normal_return(supervisor::Supervisor, child::Process)
    @debug "[$child] restart if permanent. restart=$(child.restart)"
    if istaskdone(child.task)
        if supervisor.strategy === :one_terminate_all
            terminate_others(child)
        elseif child.restart === :permanent
            !child.onhold && restart_policy(supervisor, child)
        else
            @debug "[$supervisor] normal_return: [$child] done, onhold:$(child.onhold)"
            if !child.onhold
                delete!(supervisor.processes, child.id)
            end
            child.status = done
        end
    end
end

function exitby_exception(supervisor::Supervisor, child::Process)
    if istaskdone(child.task)
        if supervisor.strategy === :one_terminate_all
            terminate_others(child)
        elseif child.restart !== :temporary
            restart_policy(supervisor, child)
        else
            @debug "[$supervisor] exitby_exception: delete [$child]"
        end
    end
end

function exitby_forced_shutdown(supervisor::Supervisor, child::Process)
    if istaskdone(child.task)
        @debug "[$supervisor] exitby_forced_shutdown: delete [$child]"
    end
end

# A supervisor is never restarted
function normal_return(supervisor::Supervisor, child::Supervisor)
    if istaskdone(child.task)
        @debug "[$supervisor] normal_return: supervisor [$child] done"
        child.status = done
    else
        @debug "[$child] spourious return signal: task was restarted"
    end
end

function unknown_message(sv, msg)
    @warn "[$sv]: received unknown message [$msg]"
end

function isalldone(supervisor)
    res = all(proc -> proc.status in [done, idle], values(supervisor.processes))
    return res
end

"""
    resync(supervisor)

Restart processes previously stopped by supervisor policies.

Return true if all supervised processes terminated.
"""
function resync(supervisor)
    if !isempty(supervisor.restarts)
        @debug "[$supervisor] to be restarted: $(format4print(supervisor.restarts))"
        # check all required processes are terminated
        if all(proc -> proc.status !== running, supervisor.restarts)
            @debug "[$supervisor] restarting processes"
            restart_processes(supervisor, supervisor.restarts)
        end
    end

    @debug "[$supervisor] procs:[$(format4print(supervisor.processes))], terminateif $(supervisor.terminateif)"
    if supervisor.terminateif === :empty && isalldone(supervisor)
        return true
    end
    return false
end

# Supervisor main loop.
function manage(supervisor)
    @debug "[$supervisor] start supervisor event loop"
    try
        for msg in supervisor.inbox
            @debug "[$supervisor] recv: $msg"
            if isa(msg, Shutdown)
                supervisor_shutdown(supervisor, nothing, msg.reset)
                break
            elseif isa(msg, SupervisorResync)
                # do nothing here, just a resync() is needed
            elseif isa(msg, ProcessFatal)
                @async handle_event(supervisor, msg)
                @debug "[$supervisor] manage process fatal: process done [$(msg.process)]"
                msg.process.status = done
            elseif isa(msg, Supervised)
                add_node(supervisor, msg)
            elseif isrequest(msg)
                try
                    if isa(msg.request, Supervised)
                        reply(msg, add_node(supervisor, msg.request))
                    elseif isa(msg.request, String)
                        process = from_path(supervisor, msg.request)
                        if process === nothing
                            throw(UnknownProcess(msg.request))
                        end
                        put!(msg.inbox, process)
                    else
                        unknown_message(supervisor, msg.request)
                        put!(msg.inbox, ErrorException("unknown message [$(msg.request)]"))
                    end
                catch e
                    put!(msg.inbox, e)
                end
            else
                unknown_message(supervisor, msg)
            end

            if resync(supervisor)
                break
            end
        end
    catch e
        @error "[$supervisor]: error: $e"
        showerror(stdout, e, catch_backtrace())
    finally
        @debug "[$supervisor] terminating"
        while isready(supervisor.inbox)
            msg = take!(supervisor.inbox)
            if isrequest(msg)
                put!(msg.inbox, ErrorException("[$(msg.request)]: supervisor shut down"))
            else
                @debug "[$supervisor]: skipped msg: $msg"
            end
        end
        close(supervisor.inbox)
        supervisor.status = idle
    end
end

function force_shutdown(process)
    if !istaskdone(process.task)
        @debug "[$process]: forcing shutdown"
        schedule(process.task, ProcessInterrupt(process.id); error=true)
    end
end

"""
    ifrestart(fn, process)

Call the no-argument function `fn` if the `process` restarted.

The function `fn` is not executed at the first start of `process`.
"""
function ifrestart(fn::Function, process::Process)
    if process.isrestart
        fn()
    end
end

function wait_for_termination(process, cond)
    try
        wait(process.task)
    finally
        notify(cond, true)
    end
end

function waitprocess(process, shtmsg, maxwait=-1)
    @debug "[$process] shutdown: waiting for task termination (maxwait=$maxwait)"
    pcond = Condition()
    if Inf > maxwait > 0
        barrier_timer = Timer((tim) -> notify(pcond, false), maxwait)
    end
    try
        @async wait_for_termination(process, pcond)
        if wait(pcond) === false
            @warn "stop waiting and process [$process] still running"
        end
    finally
        Inf > maxwait > 0 && close(barrier_timer)
    end
end

"""
    shutdown(node)

Try to shutdown a process or a supervisor.

If `node` is a supervisor it first attempts to shutdown all children nodes and then it stop the supervisor.
If some process refuse to shutdown the `node` supervisor is not stopped.
"""
function shutdown(node::Process, _reset::Bool=true)
    shtmsg = Shutdown()
    put!(node.inbox, shtmsg)
    @debug "[$node]: shutdown request, force_interrupt_after: $(node.force_interrupt_after)"

    stop_time = node.stop_waiting_after
    if node.force_interrupt_after === Inf
        stop_time = Inf
    elseif node.force_interrupt_after == 0
        force_shutdown(node)
    else
        timer = Timer((tim) -> force_shutdown(node), node.force_interrupt_after)
    end

    try
        waitprocess(node, shtmsg, stop_time)
    catch
    finally
        if @isdefined timer
            close(timer)
        end
        node.status = idle
    end
end

# Stops all managed children processes and terminate supervisor `process`.
function shutdown(sv::Supervisor, reset::Bool=true)
    @debug "[$sv] supervisor: shutdown request (reset=$reset)"
    if isdefined(sv, :task) && !istaskdone(sv.task)
        if isopen(sv.inbox)
            put!(sv.inbox, Shutdown(; reset=reset))
            close(sv.inbox)
        end
        wait(sv.task)
        sv.status = idle
    end
    reset && empty!(sv.processes)
    return nothing
end

"""
    @isshutdown process_descriptor
    @isshutdown msg

Break the loop if a shutdown control message is received.
"""
macro isshutdown(msg)
    return :(isshutdown($(esc(msg))) && break)
end

"""
    shutdown()

Shutdown all supervised nodes.
"""
shutdown() = shutdown(__ROOT__)

"""
    isshutdown(msg)

Returns `true` if message `msg` is a shutdown command.
"""
isshutdown(msg) = isa(msg, Shutdown)

"""
    function isshutdown(process::Supervised)

Returns `true` if process has a shutdown command in its inbox.

As a side effect remove messages from process inbox until a `shutdown` request is found.
"""
function isshutdown(process::Supervised)
    while isready(process.inbox)
        msg = take!(process.inbox)
        if isshutdown(msg)
            return true
        end
    end
    return false
end

function wait_response(resp_cond, ch)
    response = take!(ch)
    if isa(response, Exception)
        notify(resp_cond, response; error=true)
    else
        notify(resp_cond, response)
    end
end

"""
    hassupervised(name::String)

Determine whether the supervised identified by `name` exists.
"""
function hassupervised(name::String)
    try
        from(name)
        return true
    catch
        return false
    end
end

#     from_supervisor(start_node::Supervisor, name::String)::Supervised
#
# Return the supervised node identified by relative or full qualified name `name`.
#
# If `name` start with a dot, for example `.foo.bar`, then the process search starts
# from the root supervisor.
#
# If using a relative qualified name, for example `foo.bar`, the search starts
# from `start_node` supervisor.
function from_supervisor(sv::Supervisor, name::String)
    return from_path(sv, name)
end

"""
    from(name::String)::Supervised

Return the supervised node identified by full `name`.

Given for example the process `mytask` supervised by `mysupervisor`:

    supervisor("mysupervisor", [process(mytask)])

then the full name of `mytask` process is `mysupervisor.mytask`.
"""
from(name::String) = from_supervisor(__ROOT__, name)

function from_path(start_node::Supervised, path)
    if path == NODE_SEP
        return root_supervisor(start_node)
    elseif startswith(path, NODE_SEP)
        start_sv = root_supervisor(start_node)
        path = path[2:end]
    else
        if isa(start_node, Process)
            # a relative process path requires that start_node must be a supervisor
            start_sv = start_node.supervisor
        else
            start_sv = start_node
        end
    end

    tokens = split(path, NODE_SEP)
    sv_name = tokens[1]
    if length(tokens) === 1
        if haskey(start_sv.processes, sv_name)
            return start_sv.processes[sv_name]
        end
    else
        if haskey(start_sv.processes, sv_name)
            child = start_sv.processes[sv_name]
            return from_path(child, join(tokens[2:end], NODE_SEP))
        end
    end
    return nothing
end

"""
    function receive(fn::Function, pd::Process)

Execute `fn(msg)` for every message `msg` delivered to the `pd` Process.

Return if a `Shutdown` control message is received.
"""
function receive(fn::Function, pd::Process)
    while true
        msg = fetch(pd.inbox)
        isshutdown(msg) && break
        fn(msg)
        take!(pd.inbox)
    end
end

"""
    call(name::String, request::Any; timeout::Real=3)

Send a `request` to the process identified by full `name` and wait for a response.

If `timeout` is equal to -1 then waits forever, otherwise if a response is not received
in `timeout` seconds an `ErrorException` is raised.

The message sent to the target task is a `Request` struct that contains the request and a channel for sending back the response.

```julia
using Visor

function server(task)
    for msg in task.inbox
        isshutdown(msg) && break
        put!(msg.inbox, msg.request * 2)
    end
    println("server done")
end

function requestor(task)
    request = 10
    response = call("server", request)
    println("server(",request,")=",response)
    shutdown()
end

supervise([process(server), process(requestor)])
```
"""
function call(name::String, request::Any; timeout::Real=3)
    target_process = from_supervisor(__ROOT__, name)
    if target_process === nothing
        throw(UnknownProcess(name))
    end
    return call(target_process, request; timeout=timeout)
end

"""
    call(target::Supervised, request::Any; timeout::Real=-1)

Send a `request` to `target` process and wait for a response.
"""
function call(target::Supervised, request::Any; timeout::Real=3)
    @debug "[$target] call request: $request"

    #istaskdone(target.task) && throw(ProcessNotRunning(target.id))

    resp_cond = Condition()
    inbox = Channel(1)
    put!(target.inbox, Request(inbox, request))
    if timeout != -1
        t = Timer(
            (tim) -> notify(
                resp_cond,
                ErrorException("request [$request] to [$target] timed out");
                error=true,
            ),
            timeout,
        )
    end
    @async wait_response(resp_cond, inbox)
    try
        wait(resp_cond)
    catch e
        rethrow()
    finally
        close(inbox)
        if timeout != -1
            close(t)
        end
    end
end

"""
    cast(process::Supervised, message)

The `message` value is sent to `target` process without waiting for a response.
"""
function cast(target::Supervised, message)
    put!(target.inbox, message)
    return nothing
end

"""
    cast(name::String, message::Any)

Send a `message` to process with full `name` without waiting for a response.
"""
cast(name, message) = cast(from(name), message)

"""
    reply(request::Request, response::Any)

Send the `response` to the `call` method that issued the `request`.
"""
function reply(request::Request, response::Any)
    if isopen(request.inbox)
        put!(request.inbox, response)
    else
        @warn "no requestor waiting for response: $response"
    end
end

"""
    isrequest(message)

Return true if message is a `Request`.
"""
isrequest(message) = isa(message, Request)

if Sys.islinux() || Sys.isbsd()
    function handle_signal(signo)::Int
        if signo == 0 || signo == 2
            shutdown()
        end
        return 0
    end
elseif Sys.iswindows()
    function handle_signal(signo)::Bool
        if signo == 0 || signo == 1
            shutdown()
        end
        return 0
    end
end

#https://stackoverflow.com/questions/16826097/equivalent-to-sigint-posix-signal-for-catching-ctrlc-under-windows-mingw
function wait_signal(sv)
    try
        ccall(:init_signal_handler, Int, ())
        signum = @threadcall(:wait_for_sig, Int, ())
        if signum !== 0
            put!(sv.inbox, Shutdown())
        end
    catch
        if Sys.islinux() || Sys.isbsd()
            handle_ptr = @cfunction(handle_signal, Int, (Int,))
            ccall(:signal, Int, (Int, Ptr{Cvoid}), 2, handle_ptr)
        elseif Sys.iswindows()
            handle_ptr = @cfunction(handle_signal, Bool, (UInt32,))
            ccall(:SetConsoleCtrlHandler, Bool, (Ptr{Cvoid}, Bool), handle_ptr, true)
        end
    end
end

"""
    supervise(processes::Vector{<:Supervised};
              intensity::Int=DEFAULT_INTENSITY,
              period::Int=DEFAULT_PERIOD,
              strategy::Symbol=:one_for_one,
              terminateif::Symbol=:empty,
              handler::Union{Nothing, Function}=nothing,
              wait::Bool=true)::Supervisor

The root supervisor start a family of supervised `processes`.

Return the root supervisor or wait for supervisor termination if `wait` is true.

# Arguments

- `intensity::Int`: maximum number of restarts allowed in `period` seconds.
- `period::Int`: time interval that controls the restart intensity.
- `strategy::Symbol`: defines the restart strategy:
  - `:one_for_one`: only the terminated task is restarted.
  - `:one_for_all`: if a child task terminates, all other tasks are terminated, and then all children,
                    including the terminated one, are restarted.
  - `:rest_for_one`: if a child task terminates, the rest of the children tasks (that is, the child tasks
                     after the terminated process in start order) are terminated. Then the terminated
                     child task and the rest of the child tasks are restarted.
  - `:one_terminate_all`: if a child task terminates then the remaining tasks will be concurrently terminated
                          (the startup order is not respected).
- `terminateif::Symbol`:
  - `:empty`: terminate the supervisor when all child tasks terminate.
  - `:shutdown`: the supervisor terminate at shutdown.
- `handler`: a callback function with prototype `fn(process, event)` invoked when process events occurs:
when process tasks throws exception and when a process terminate because of a `ProcessFatal` reason.
- `wait::Bool`: wait for supervised nodes termination.

```julia
    children = [process(worker, args=(15,"myid"))]
    supervise(children)
```
"""
function supervise(
    processes::Vector{<:Supervised};
    intensity::Int=DEFAULT_INTENSITY,
    period::Int=DEFAULT_PERIOD,
    strategy::Symbol=:one_for_one,
    terminateif::Symbol=:empty,
    handler::Union{Nothing,Function}=nothing,
    wait::Bool=true,
)::Supervisor
    if !(strategy in [:one_for_one, :rest_for_one, :one_for_all, :one_terminate_all])
        error(
            "wrong strategy $strategy: must be one of :one_for_one, :rest_for_one, :one_for_all",
        )
    end
    if !(terminateif in [:shutdown, :empty])
        error("wrong terminateif type $terminateif: must be one of :empty, :shutdown")
    end

    if isdefined(__ROOT__, :inbox) && isopen(__ROOT__.inbox)
        for p in processes
            startup(p)
        end
        if wait
            Base.wait(__ROOT__)
        end
        return __ROOT__
    else
        __ROOT__.inbox = Channel(INBOX_CAPACITY)
        if handler !== nothing
            __ROOT__.evhandler = handler
        end
        sv = add_processes(
            __ROOT__,
            processes;
            intensity=intensity,
            period=period,
            strategy=strategy,
            terminateif=terminateif,
        )

        supervise(wait)
        return sv
    end
end

"""
    supervise(proc::Supervised;
              intensity::Int=DEFAULT_INTENSITY,
              period::Int=DEFAULT_PERIOD,
              strategy::Symbol=:one_for_one,
              terminateif::Symbol=:empty,
              handler::Union{Nothing, Function}=nothing,
              wait::Bool=true)::Supervisor

The root supervisor start a supervised process defined by `proc`.
"""
supervise(
    proc::Supervised;
    intensity::Int=DEFAULT_INTENSITY,
    period::Int=DEFAULT_PERIOD,
    strategy::Symbol=:one_for_one,
    terminateif::Symbol=:empty,
    handler::Union{Nothing,Function}=nothing,
    wait::Bool=true,
)::Supervisor = supervise(
    [proc];
    intensity=intensity,
    period=period,
    strategy=strategy,
    terminateif=terminateif,
    handler=handler,
    wait=wait,
)

function supervise(wait::Bool=true)
    start(__ROOT__)
    wait && return Base.wait(__ROOT__)
end

#
#     wait(sv::Supervisor)
#
# Wait for supervisor `sv` termination.
#
# A supervisor terminates when all of its supervised tasks terminate.
#
function Base.wait(sv::Supervisor)
    wait(sv.task)
    try
        ccall(:filo_exit, Int, ())
    catch
    end
end

# Wait for node termination and inform the supervisor.
# If the node throws an error generates a `ProcessError` Exception.
# if the node is forcibly interrupted generates a `ProcessInterrupt`.
function wait_child(supervisor::Supervisor, process::Process)
    try
        wait(process.task)
        normal_return(supervisor, process)
        handle_event(supervisor, ProcessReturn(process))
    catch e
        taskerr = e.task.exception
        process.status = failed
        if isa(taskerr, ProcessInterrupt)
            @debug "[$supervisor]: process [$process] forcibly interrupted"
            exitby_forced_shutdown(supervisor, process)
            handle_event(supervisor, ProcessInterrupted(process))
        else
            @debug "[$process] exception: $taskerr"
            @debug "[$supervisor]: applying restart policy for [$process] ($(Int.(floor.(process.startstamps))))"
            exitby_exception(supervisor, process)
            handle_event(supervisor, ProcessError(process, taskerr))
        end
    finally
        if process.restart === :temporary
            @debug "removing temporary process $process"
            delete!(supervisor.processes, process.id)
        end
        put!(supervisor.inbox, SupervisorResync())
    end
end

function wait_child(supervisor::Supervisor, process::Supervisor)
    wait(process.task)
    normal_return(supervisor, process)
    put!(supervisor.inbox, SupervisorResync())
    return nothing
end

function handle_event(process, event)
    if isdefined(process, :supervisor)
        sv = process.supervisor
    else
        # If process supervisor is not set trace at root level.
        sv = __ROOT__
    end

    if sv.evhandler !== nothing
        sv.evhandler(process, event)
    end
end

"""
    setroot(;
        intensity::Int=1,
        period::Int=DEFAULT_PERIOD,
        strategy::Symbol=:one_for_one,
        terminateif::Symbol=:empty,
        handler::Union{Nothing,Function}=nothing,
    )

Setup root supervisor settings.
"""
setroot(;
    intensity::Int=DEFAULT_INTENSITY,
    period::Int=DEFAULT_PERIOD,
    strategy::Symbol=:one_for_one,
    terminateif::Symbol=:empty,
    handler::Union{Nothing,Function}=nothing,
) = setsupervisor(
    __ROOT__;
    intensity=intensity,
    period=period,
    strategy=strategy,
    terminateif=terminateif,
    handler=handler,
)

"""
    setsupervisor(sv::Supervisor;
        intensity::Int=1,
        period::Int=DEFAULT_PERIOD,
        strategy::Symbol=:one_for_one,
        terminateif::Symbol=:empty,
        handler::Union{Nothing,Function}=nothing,
    )

Setup supervisor settings.
"""
function setsupervisor(
    sv::Supervisor;
    intensity::Int=DEFAULT_INTENSITY,
    period::Int=DEFAULT_PERIOD,
    strategy::Symbol=:one_for_one,
    terminateif::Symbol=:empty,
    handler::Union{Nothing,Function}=nothing,
)
    sv.intensity = intensity
    sv.period = period
    sv.strategy = strategy
    sv.terminateif = terminateif
    sv.evhandler = handler
    return sv
end

const __ROOT__::Supervisor = Supervisor(
    ROOT_SUPERVISOR,
    OrderedDict{String,Supervised}(),
    DEFAULT_INTENSITY,
    DEFAULT_PERIOD,
    :one_for_one,
    :empty,
)

end
