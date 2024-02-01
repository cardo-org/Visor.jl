# Visor

```@meta
CurrentModule = Visor
```

[Visor](https://github.com/cardo-org/Visor) is a tasks supervisor that provides
a set of policies to control the logic for the shutdown and restart of tasks.

The scope of `Visor` is to provide support for reliable, long-running and fault tolerant applications written in Julia.

Visor is influenced by [Erlang Supervisor](https://www.erlang.org/doc/design_principles/sup_princ.html#supervision-principles) design principles
with the aim to fit as "naturally" as possible into the Julia task system.

## Getting Started

```julia
using Pkg; 
Pkg.add("Visor")
```

```julia
# demo.jl:

using Visor

struct AppData
    count::Int
end

# Task implementation, the first argument is a task descriptor
function level_1_task(td)
    @info "starting $td"
    for msg in td.inbox
        if isshutdown(msg)
            break
        elseif isa(msg, AppData)
            @info "$td recv: $msg"
        end
    end
    @info "shutting down $td"
end

function level_2_task(td)
    @info "starting $td"
    n = 0
    while true
        sleep(0.5)
        if isshutdown(td)
            break
        end
        # send a data message to process named level_1_task
        cast(td, "level_1_task", AppData(n))
        n += 1
    end
    @info "shutting down $td"
end

supervise([process(level_1_task), process(level_2_task)])
```

On Linux machines Visor caputures `SIGINT` signal and terminate the application tasks in the reverse order of startup:

```sh
$ julia demo.jl

[ Info: starting level_1_task
[ Info: starting level_2_task
[ Info: level_1_task recv: AppData(0)
[ Info: level_1_task recv: AppData(1)
[ Info: level_1_task recv: AppData(2)
^C[ Info: shutting down level_2_task
[ Info: shutting down level_1_task

```

A [Process](@ref) is a supervised task that is started/stopped in a deterministic way and that may be restarted in case of failure.

A process task function has a mandatory first argument that is a task descriptor `td` value that:

* check if a shutdown request is pending with `isshutdown`;
* receive messages from the `inbox` Channel;

```julia
function level_2_task(td)
    while true
        # do something ...
        if isshutdown(td)
            break
        end
    end
end
```

If the task function is designed to receive messages the argument of `isshutdown` MUST BE the message and not the `task` object:

```julia
function level_1_task(td)
    for msg in td.inbox
        # check if it is a shutdown request 
        if isshutdown(msg)
            break
        elseif isa(msg, AppMessage)
            # do something with the application message
            # that some task sent to level_1_task.
            do_something(msg)
        end
    end
end
```

`supervise` manages processes and supervisors until all of them terminates or a shutdown is requested.

```julia
processes = [process(level_1_task), process(level_2_task)]
supervise(processes)
```

`supervise` applied to a supervisor is an example of a hierachical supervision tree:

```julia
sv = supervisor("bucket", [process(foo), process(bar)])
supervise(sv)
```

In this case the supervisor "bucket" manages the tasks `foo` and `bar`, whereas in the previous example
`level_1_task` and `level_2_task` are managed by the root supervisor.

see [Supervisor](@ref) documentation for more details.

## Restart policy example

The following example show the restart on failure scenario: a task failure is simulated with an error exception that terminates the consumer.

```julia
using Visor

# Consumer process task: read messages from process inbox and print to stdout.
# The first mandatory argument process is the task descriptor object.
# With the task descriptor it is possible to receive any type of messages, for example
# shutdown requests, and send messages to other processes via call and cast methods.
function consumer(td)

    while true
        # Fetch data or control messages, 
        # for example a request to shutdown the task.
        msg = take!(td.inbox)

        # Check if msg is the shutdown control message ...
        !isshutdown(msg) || break

        println(msg)
        if msg == 5
            error("fatal error simulation")
        end

    end
end

# Producer task.
# In this case the shutdown request is not captured by checking the inbox messages but checking
# the task descriptor.
function producer(td)
    count = 1
    while true
        sleep(1)

        # send count value to consumer task
        cast("consumer", count)

        # check if was requested a shutdown (for example by SIGINT signal)
        !isshutdown(td) || break

        count += 1
    end
end

# Tasks are started following the list order and are shut down in reverse order:
# producer is started last and terminated first.
tasks = [
    process(consumer)
    process(producer, thread=true)
]

# Supervises the tasks and apply restart policies in case of process failure.
# In this case it allows a maximum of 2 process restart in 1 second time window.
# In case the fail rate is above this limit the processes are terminated and the supervisor returns.
supervise(tasks, intensity=2, period=1);
```

The producer process sends a number every seconds to the consumer process that get it from the inbox channel
and print to stdout.

When the number equals to 5 then an exception is raised, the task fails and the supervisor restarts the consumer process:

```sh
$ julia producer_consumer.jl 
1
2
3
4
5
┌ Error: [consumer] exception: ErrorException("fatal error simulation")
└ @ Visor ~/dev/Visor/src/Visor.jl:593
6
7
^C8
9
```

```@index
```

```@autodocs
Modules = [Visor]
```
