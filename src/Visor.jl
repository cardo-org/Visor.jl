module Visor

using DataStructures
using UUIDs

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
export if_restart
export process
export is_request
export is_shutdown
export process
export receive
export reply
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

abstract type Supervised end

mutable struct Supervisor <: Supervised
    id::String
    processes::OrderedDict{String,Supervised}
    intensity::Int
    period::Int
    strategy::Symbol
    terminateif::Symbol
    inbox::Channel
    supervisor::Supervisor
    task::Task
    function Supervisor(id, intensity=1, period=5, strategy=:one_for_one, terminateif=:auto)
        return new(
            id,
            OrderedDict(),
            intensity,
            period,
            strategy,
            terminateif,
            Channel(INBOX_CAPACITY),
        )
    end
    function Supervisor(
        parent::Supervisor,
        id,
        intensity=1,
        period=5,
        strategy=:one_for_one,
        terminateif=:auto,
    )
        return new(
            id,
            OrderedDict(),
            intensity,
            period,
            strategy,
            terminateif,
            Channel(INBOX_CAPACITY),
            parent,
        )
    end
end

nproc(process::Supervisor) = length(process.processes)

mutable struct Process <: Supervised
    supervisor::Supervisor
    id::String
    fn::Function
    args::Tuple
    namedargs::NamedTuple
    task::Task
    startstamps::Vector{Float64}
    restart::Symbol
    isrestart::Bool
    force_interrupt_after::Float64
    stop_waiting_after::Float64
    debounce_time::Float64
    thread::Bool
    inbox::Channel
    function Process(
        supervisor,
        id,
        fn,
        args=(),
        namedargs=(;),
        force_interrupt_after=INTERRUPT_PROCESS_AFTER,
        stop_waiting_after=STOP_WAITING_AFTER,
        debounce_time=NaN,
        restart=:transient,
        thread=false,
    )
        begin
            nulltask = @async () -> ()
            new(
                supervisor,
                id,
                fn,
                args,
                namedargs,
                nulltask,
                Float64[],
                restart,
                false,
                force_interrupt_after,
                stop_waiting_after,
                debounce_time,
                thread,
                Channel(INBOX_CAPACITY),
            )
        end
    end
end

Base.show(io::IO, process::Supervised) = print(io, "$(process.id)")

function printtree(node::Supervisor)
    children = [
        isa(p, Process) ? p.id : "supervisor:$(p.id)" for p in values(node.processes)
    ]
    println("[$node] nodes: $children")
    for (id, el) in node.processes
        if isa(el, Supervisor)
            printtree(el)
        end
    end
end

printtree() = printtree(__ROOT__)

function inspect(node::Supervisor, tree::OrderedDict=OrderedDict())
    children = OrderedDict()
    for p in values(node.processes)
        children[p.id] = p
    end
    tree[node.id] = children
    for (id, el) in node.processes
        if isa(el, Supervisor)
            inspect(el, tree[node.id])
        end
    end
    return tree
end

inspect() = inspect(__ROOT__)

abstract type Spec end

struct SupervisorSpec <: Spec
    id::String
    specs::Vector{Spec}
    intensity::Int
    period::Int
    strategy::Symbol
    terminateif::Symbol
end

struct ProcessSpec <: Spec
    id::String
    fn::Function
    args::Tuple
    namedargs::NamedTuple
    force_interrupt_after::Float64
    stop_waiting_after::Float64
    debounce_time::Float64
    thread::Bool
    restart::Symbol
end

"""
    supervisor(id, specs; intensity=1, period=5, strategy=:one_for_one, terminateif=:empty)::SupervisorSpec

Declare a supervisor of the nodes  defined by the specification `specs`.

`specs` may be a single specification or a list of specifications.

```jldoctest
julia> using Visor

julia> mytask(pd) = ();

julia> supervisor("mysupervisor", process(mytask))
Visor.SupervisorSpec("mysupervisor", Visor.Spec[Visor.ProcessSpec("mytask", mytask, (), NamedTuple(), 1.0, Inf, NaN, false, :transient)], 1, 5, :one_for_one, :empty)
```

```jldoctest
julia> using Visor

julia> tsk1(pd) = ();

julia> tsk2(pd) = ();

julia> supervisor("mysupervisor", [process(tsk1), process(tsk2)])
Visor.SupervisorSpec("mysupervisor", Visor.Spec[Visor.ProcessSpec("tsk1", tsk1, (), NamedTuple(), 1.0, Inf, NaN, false, :transient), Visor.ProcessSpec("tsk2", tsk2, (), NamedTuple(), 1.0, Inf, NaN, false, :transient)], 1, 5, :one_for_one, :empty)```

See [Supervisor](@ref) documentation for more details.
"""
function supervisor(
    id,
    specs::Vector{<:Spec}=Spec[];
    intensity=1,
    period=5,
    strategy=:one_for_one,
    terminateif=:empty,
)::SupervisorSpec
    if !(terminateif in [:shutdown, :empty])
        error("wrong shutdown value $shutdown: must be one of :empty, :shutdown")
    end

    if isempty(specs) && terminateif === :empty
        error("immediate shutdown of supervisor [$id] with no processes")
    end

    return SupervisorSpec(id, specs, intensity, period, strategy, terminateif)
end

function supervisor(
    id, spec::Spec; intensity=1, period=5, strategy=:one_for_one, terminateif=:empty
)::SupervisorSpec
    if !(terminateif in [:shutdown, :empty])
        error("wrong shutdown value $shutdown: must be one of :empty, :shutdown")
    end

    return SupervisorSpec(id, [spec], intensity, period, strategy, terminateif)
end

"""
    process(id, fn;
            args=(),
            namedargs=(;),
            force_interrupt_after::Real=0,
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
)::ProcessSpec
    if !(restart in [:permanent, :temporary, :transient])
        error(
            "wrong restart value $restart: must be one of :permanent, :temporary, :transient",
        )
    end

    return ProcessSpec(
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
)::ProcessSpec = process(
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
# process node termination was forced by supervisor.
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

## include("supervisor.jl")
# Returns the list of running nodes supervised by `supervisor` (processes and supervisors direct children).
function running_nodes(supervisor)
    return collect(Iterators.filter(p -> !istaskdone(p.task), values(supervisor.processes)))
end

function start(proc::Process)
    if proc.thread
        proc.task = Threads.@spawn proc.fn(proc, proc.args...; proc.namedargs...)
    else
        proc.task = @async proc.fn(proc, proc.args...; proc.namedargs...)
    end
    @async wait_child(proc.supervisor, proc)
    return proc.task
end

function start(sv::Supervisor)
    sv.task = @async manage(sv)
    for node in values(sv.processes)
        @debug "[$sv]: starting [$node]"
        start(node)
    end
    @async wait_child(sv.supervisor, sv)
    return sv.task
end

# Supervised restart logic based on `intensity`, `period` and `strategy` parameters.
function restart_policy(supervisor, process)
    now = time()
    push!(process.startstamps, now)
    filter!(t -> t > now - supervisor.period, process.startstamps)

    @debug "process retry startstamps: $(process.startstamps)"
    if length(process.startstamps) > supervisor.intensity
        @warn "[$process]: reached max of $(supervisor.intensity) restarts in $(supervisor.period) secs period"
        put!(supervisor.inbox, ProcessFatal(process))
    else
        process.isrestart = true
        if !isnan(process.debounce_time)
            sleep(process.debounce_time)
        end
        if supervisor.strategy === :one_for_one
            process.task = start(process)
        elseif supervisor.strategy === :one_for_all
            # If a child process terminates, all other child processes are terminated,
            # and then all child processes, including the terminated one, are restarted.
            supervisor_shutdown(supervisor)
            # start again from start
            for proc in values(supervisor.processes)
                @debug "restarting $(proc.id)"
                proc.task = start(proc)
            end
        elseif supervisor.strategy === :rest_for_one
            stopped = supervisor_shutdown(supervisor, process)
            for proc in reverse(stopped)
                proc.task = start(proc)
            end
        end
    end
end

"""
    startup(spec::Spec)

Start the supervised nodes defined by `spec` as children of the root supervisor.
"""
startup(spec::Spec) = startup(__ROOT__, spec)

"""
    startup(supervisor::Supervisor, spec::Spec)

Start the supervised nodes defined by `spec` as children of `supervisor`.

```jldoctest
julia> using Visor

julia> foo(self) = println("foo process started");

julia> main(self) = startup(self.supervisor, process(foo));

julia> supervise([process(main)]);
foo process started
```
"""
function startup(supervisor::Supervisor, spec::Spec)
    return call(supervisor, spec)
end

function startup(node::Supervised; start_last=true)
    start(node)
    if isdefined(node, :supervisor)
        if start_last
            node.supervisor.processes[node.id] = node
        else
            node.supervisor.processes = merge(
                OrderedDict(node.id => node), node.supervisor.processes
            )
        end
    end
end

function add_node(id::String, supervisor::Supervisor, spec::Spec)
    if isa(spec, SupervisorSpec)
        # it is a supervisor
        proc = start_processes(
            supervisor,
            id,
            spec.specs;
            intensity=spec.intensity,
            period=spec.period,
            strategy=spec.strategy,
            terminateif=spec.terminateif,
        )
        @async wait_child(supervisor, proc)
    else
        proc = Process(
            supervisor,
            id,
            spec.fn,
            spec.args,
            spec.namedargs,
            spec.force_interrupt_after,
            spec.stop_waiting_after,
            spec.debounce_time,
            spec.restart,
            spec.thread,
        )
        start(proc)
    end
    #@info "[$supervisor] added [$proc]"
    supervisor.processes[id] = proc
    return proc
end

#     add_node(supervisor::Supervisor, spec::Spec)
# 
# Add and start the process defined by specification `spec` to the `supervisor` list
# of managed processes.
# 
# `add_node` is for internal use: it is not thread safe.
# For thread safety use the `startup` method.
function add_node(supervisor::Supervisor, spec::Spec)
    id::String = spec.id
    if haskey(supervisor.processes, id)
        id = id * ":" * uid()
    end
    return add_node(id, supervisor, spec)
end

# Starts processes defined by `specs` specification.
# A dedicated supervisor is created and attached to parent supervisor if `parent`
# is a supervisor instance.
# `intensity` and `period` define process restart policy.
# `strategy` defines how to restart child processes.
function start_processes(
    parent::Supervisor, name, specs; intensity, period, strategy, terminateif::Symbol=:empty
)::Supervisor
    @debug "[$name]: start_processes with strategy $strategy"
    svisor = Supervisor(parent, name, intensity, period, strategy, terminateif)
    svisor.task = @async manage(svisor)

    parent.processes[svisor.id] = svisor

    for spec in specs
        add_node(svisor, spec)
    end
    return svisor
end

function start_processes(
    svisor::Supervisor, childspecs; intensity, period, strategy, terminateif::Symbol=:empty
)::Supervisor
    @debug "[$svisor]: start_processes with strategy $strategy"
    svisor.task = @async manage(svisor)

    svisor.intensity = intensity
    svisor.period = period
    svisor.strategy = strategy
    svisor.terminateif = terminateif

    for spec in childspecs
        add_node(svisor, spec)
    end
    return svisor
end

# Terminate all child processes in startup reverse order.
# If invoked with a `failed_proc` argument it terminates the processes as far as `failed_proc`. 
function supervisor_shutdown(
    supervisor, failed_proc::Union{Supervised,Nothing}=nothing, reset::Bool=false
)
    stopped_procs = []
    revs = reverse(collect(values(supervisor.processes)))
    for p in revs
        push!(stopped_procs, p)
        if p === failed_proc
            @debug "[$p] failed_proc reached, stopping reverse shutdown"
            break
        end
        if istaskdone(p.task)
            @debug "[$p] skipping shutdown: task already done"
        else
            # shutdown is sequential because in case a node refuses
            # to shutdown remaining nodes aren't shutted down.
            shutdown(p, reset)
        end
    end
    return stopped_procs
end

function root_supervisor(process::Supervised)
    if !isdefined(process, :supervisor)
        isa(process, Process) && error("[$process] supervisor undefined")
        return process
    end
    return root_supervisor(process.supervisor)
end

function normal_return(supervisor::Supervisor, child::Process)
    @debug "[$child] restart if permanent. restart=$(child.restart)"
    if istaskdone(child.task)
        if child.restart === :permanent
            restart_policy(supervisor, child)
        else
            @debug "[$supervisor] normal_return: delete [$child]"
            delete!(supervisor.processes, child.id)
        end
    end
end

function exitby_exception(supervisor::Supervisor, child::Process)
    if istaskdone(child.task)
        if child.restart !== :temporary
            restart_policy(supervisor, child)
        else
            @debug "[$supervisor] exitby_exception: delete [$child]"
            delete!(supervisor.processes, child.id)
        end
    end
end

# A supervisor is never restarted
function normal_return(supervisor::Supervisor, child::Supervisor)
    if istaskdone(child.task)
        @debug "[$supervisor] normal_return: delete supervisor [$child]"
        delete!(supervisor.processes, child.id)
    else
        @debug "[$child] spourious return signal: task was restarted"
    end
end

function unknown_message(sv, msg)
    @warn "[$sv]: received unknown message [$msg]"
end

# Supervisor main loop.
function manage(supervisor)
    try
        for msg in supervisor.inbox
            @debug "[$supervisor] manage: $msg"
            if isa(msg, Shutdown)
                supervisor_shutdown(supervisor, nothing, msg.reset)
                break
            elseif isa(msg, ProcessReturn)
                @debug "[$supervisor]: process [$(msg.process)] normal termination"
                normal_return(supervisor, msg.process)
            elseif isa(msg, ProcessInterrupted)
                @debug "[$supervisor]: process [$(msg.process)] forcibly interrupted"
                exitby_exception(supervisor, msg.process)
            elseif isa(msg, ProcessError)
                @debug "[$supervisor]: applying restart policy for [$(msg.process)] ($(Int.(floor.(msg.process.startstamps))))"
                exitby_exception(supervisor, msg.process)
            elseif isa(msg, ProcessFatal)
                @debug "[$supervisor] manage process fatal: delete [$(msg.process)]"
                delete!(supervisor.processes, msg.process.id)
                supervisor_shutdown(supervisor)
            elseif is_request(msg)
                try
                    if isa(msg.request, Spec)
                        reply(msg, add_node(supervisor, msg.request))
                    elseif isa(msg.request, String)
                        process = from_path(supervisor, msg.request)
                        put!(msg.inbox, process)
                    else
                        unknown_message(supervisor, msg.request)
                        put!(msg.inbox, ErrorException("unknown message [$(msg.request)]"))
                    end
                catch e
                    #showerror(stdout, e, catch_backtrace())
                    put!(msg.inbox, e)
                end
            else
                unknown_message(supervisor, msg)
            end

            @debug "[$supervisor]: terminateif=$(supervisor.terminateif), processes=$(supervisor.processes)"
            if supervisor.terminateif === :empty && isempty(supervisor.processes)
                break
            end
        end
    catch e
        @error "[$supervisor]: error: $e"
        #showerror(stdout, e, catch_backtrace())
    finally
        while isready(supervisor.inbox)
            msg = take!(supervisor.inbox)
            if is_request(msg)
                put!(msg.inbox, ErrorException("[$(msg.request)]: supervisor shutted down"))
            else
                @debug "[$supervisor]: skipped msg: $msg"
            end
        end
    end
end

function force_shutdown(process)
    if !istaskdone(process.task)
        @debug "[$process]: forcing shutdown"
        schedule(process.task, ProcessInterrupt(process.id); error=true)
    end
end

"""
    if_restart(fn, process)

Call the no-argument function `fn` if the `process` restarted.

The function `fn` is not executed at the first start of `process`.    
"""
function if_restart(fn::Function, process::Process)
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
    @debug "[$process]: waiting for task termination"
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
        @debug "[$node] scheduling forced shutdown after $(node.force_interrupt_after)"
        timer = Timer((tim) -> force_shutdown(node), node.force_interrupt_after)
    end

    try
        waitprocess(node, shtmsg, stop_time)
    catch
    finally
        if @isdefined timer
            close(timer)
        end
    end
end

# Stops all managed children processes and terminate supervisor `process`.
function shutdown(sv::Supervisor, reset::Bool=true)
    @debug "[$sv]: supervisor shutdown request (reset=$reset)"

    if isdefined(sv, :task) && !istaskdone(sv.task)
        put!(sv.inbox, Shutdown(; reset=reset))
        wait(sv.task)
    end
    reset && empty!(sv.processes)
    return nothing
end

"""
    shutdown()

Shutdown all supervised nodes.
"""
shutdown() = shutdown(__ROOT__)

"""
    is_shutdown(msg)

Returns `true` if message `msg` is a shutdown command. 
"""
is_shutdown(msg) = isa(msg, Shutdown)

"""
    function is_shutdown(process::Supervised)

Returns `true` if process has a shutdown command in its inbox.

As a side effect remove messages from process inbox until a `shutdown` request is found.
"""
function is_shutdown(process::Supervised)
    while isready(process.inbox)
        msg = take!(process.inbox)
        if is_shutdown(msg)
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

#     from_supervisor(start_node::Supervisor, name::String)::Supervised
# 
# Return the supervised node identified by relative or full qualified name `name`.
# 
# If `name` start with a dot, for example `.foo.bar`, then the process search starts
# from the root supervisor.
# 
# If using a relative qualified name, for example `foo.bar`, the search starts
# from `start_node` supervisor.
function from_supervisor(sv::Supervisor, name::String)::Supervised
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

function from_path(start_node::Supervised, path)::Supervised
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
    throw(UnknownProcess(path))
end

"""
    function receive(fn::Function, pd::Process)

Execute `fn(msg)` for every message `msg` delivered to the `pd` Process.

Return if a `Shutdown` control message is received.
"""
function receive(fn::Function, pd::Process)
    while true
        msg = fetch(pd.inbox)
        is_shutdown(msg) && break
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
        is_shutdown(msg) && break
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
    return call(target_process, request; timeout=timeout)
end

"""
    call(target::Supervised, request::Any; timeout::Real=-1)

Send a `request` to `target` process and wait for a response.
"""
function call(target::Supervised, request::Any; timeout::Real=5)
    istaskdone(target.task) && throw(ProcessNotRunning(target.id))

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
    nothing
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
    is_request(message)

Return true if message is a `Request`.
"""
is_request(message) = isa(message, Request)

if Sys.islinux()
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
        if Sys.islinux()
            handle_ptr = @cfunction(handle_signal, Int, (Int,))
            ccall(:signal, Int, (Int, Ptr{Cvoid}), 2, handle_ptr)
        elseif Sys.iswindows()
            handle_ptr = @cfunction(handle_signal, Bool, (UInt32,))
            ccall(:SetConsoleCtrlHandler, Bool, (Ptr{Cvoid}, Bool), handle_ptr, true)
        end
        wait(sv.task)
    end
end

"""
    supervise(childspecs::Vector{<:Spec};
              intensity::Int=1,
              period::Int=5,
              strategy::Symbol=:one_for_one,
              terminateif::Symbol=:empty,
              wait::Bool=true)::Supervisor

The root supervisor start a family of supervised nodes defined by `specs`.

Return the root supervisor or wait for supervisor termination if `wait` is true. 

# Arguments

- `intensity::Int`: maximum number of restarts allowed in `period` seconds.
- `period::Int`: time interval that controls the restart intensity.
- `strategy::Symbol`: defines the restart strategy:
  - `:one_for_one`: only the terminated task is restarted.
  - `:one_for_all`: if a child task terminates, all other child tasks are terminated, and then all child,
                    including the terminated one, are restarted.
  - `:rest_for_one`: if a child task terminates, the rest of the child tasks (that is, the child tasks 
                     after the terminated process in start order) are terminated. Then the terminated
                     child task and the rest of the child tasks are restarted.
- `terminateif::Symbol`:
  - `:empty`: terminate the supervisor when all child tasks terminate.
  - `:shutdown`: the supervisor terminate at shutdown. 
- `wait::Bool`: wait for supervised nodes termination.

```julia
    children = [process(worker, args=(15,"myid"))]
    supervise(children)
```
"""
function supervise(
    specs::Vector{<:Spec};
    intensity::Int=1,
    period::Int=5,
    strategy::Symbol=:one_for_one,
    terminateif::Symbol=:empty,
    wait::Bool=true,
)::Supervisor
    if !(strategy in [:one_for_one, :rest_for_one, :one_for_all])
        error(
            "wrong strategy $strategy: must be one of :one_for_one, :rest_for_one, :one_for_all",
        )
    end
    if !(terminateif in [:shutdown, :empty])
        error("wrong terminateif type $terminateif: must be one of :empty, :shutdown")
    end

    # relaxed restart because of possible messages of previous
    # supervise session.
    isdefined(__ROOT__, :task) && sleep(0.1)

    sv = start_processes(
        __ROOT__,
        specs;
        intensity=intensity,
        period=period,
        strategy=strategy,
        terminateif=terminateif,
    )

    @async wait_signal(__ROOT__)

    wait && Visor.wait(sv)
    return sv
end

"""
    supervise(spec::Spec;
              intensity::Int=1,
              period::Int=5,
              strategy::Symbol=:one_for_one,
              terminateif::Symbol=:empty,
              wait::Bool=true)::Supervisor

The root supervisor start a supervised node defined by `spec`.
"""
supervise(
    spec::Spec;
    intensity::Int=1,
    period::Int=5,
    strategy::Symbol=:one_for_one,
    terminateif::Symbol=:empty,
    wait::Bool=true,
)::Supervisor = supervise(
    [spec];
    intensity=intensity,
    period=period,
    strategy=strategy,
    terminateif=terminateif,
    wait=wait,
)

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
        put!(supervisor.inbox, ProcessReturn(process))
    catch e
        taskerr = e.task.exception
        if isa(taskerr, ProcessInterrupt)
            @debug "[$process] exit on exception: $taskerr"
            put!(supervisor.inbox, ProcessInterrupted(process))
        else
            @error "[$process] exception: $taskerr"
            #showerror(stdout, e, catch_backtrace())
            if isa(taskerr, Exception)
                put!(supervisor.inbox, ProcessError(process, taskerr))
            else
                put!(supervisor.inbox, ProcessError(process, SystemError("process exception")))
            end
        end
    finally
        if process.restart === :temporary
            @debug "removing temporary process $process"
            delete!(supervisor.processes, process.id)
        end
    end
end

function wait_child(supervisor::Supervisor, process::Supervisor)
    wait(process.task)
    return put!(supervisor.inbox, ProcessReturn(process))
end

const __ROOT__::Supervisor = Supervisor(ROOT_SUPERVISOR, 1, 5, :one_for_one, :auto)

end
