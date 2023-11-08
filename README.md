# Visor

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://cardo-org.github.io/Visor.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://cardo-org.github.io/Visor.jl/dev/)
[![Build Status](https://github.com/cardo-org/Visor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/cardo-org/Visor.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/cardo-org/Visor.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/cardo-org/Visor.jl)

The scope of `Visor` is to provide support for reliable, long-running and fault tolerant applications written in Julia.

`Visor` is a tasks supervisor that provides:

* a workflow for ordered shutdown of tasks.
* a set of policies to control the logic of tasks restart.

`Visor` is influenced by [Erlang Supervisor](https://www.erlang.org/doc/design_principles/sup_princ.html#supervision-principles) design principles
with the aims to fit as "naturally" as possible into the Julia task system.

On Unix hosts Visor manages `SIGINT` signal in a deterministic way and shutdown tasks in an orderly fashion.

## Getting started

```julia
using Pkg
Pkg.add("Visor")
```

`demo.jl`:

```julia
using Visor

# The only requirement for a task driven by Visor is that the first argument is
# a descriptor representing the supervised task, in this case `pd` is the 
# descriptor of the `printer` process.
function printer(pd, device)
    println("(re)starting printer driver")
    receive(pd) do msg
        device.jobcount += 1
        print("processing $msg ... ")
        if device.jobcount === 3
            # unexpected printer failure 
            error("printer service panic error: $msg not printed")
        end
        println("done")
    end
end

function controller(pd)
    # from returns a Visor task object from process name.
    # The default name is the name of process task.  
    printer_process = from("printer")
    for i in 1:8
        # send a one-way message to the printer process.
        cast(printer_process, "job-$i")
    end
end

# needed for simulating a printer failure:
# when jobcount is equal to 3
mutable struct PrinterStatus
    jobcount::Int
end

supervise([process(printer; args=(PrinterStatus(0),)), process(controller)])
```

```bash
myhost:~/$ julia demo.jl
(re)starting printer driver
processing job-1 ... done
processing job-2 ... done
processing job-3 ... ┌ Error: [printer] exception: ErrorException("printer service panick error: job-3 not printed")
└ @ Visor .../Visor.jl:1107
(re)starting printer driver
processing job-3 ... done
processing job-4 ... done
processing job-5 ... done
processing job-6 ... done
processing job-7 ... done
processing job-8 ... done
^C
myhost.~/$
```

The types of nodes that compose a supervision tree are:

* `Process`: a node running a task.

* `Supervisor`: a node that supervises other nodes.

The supervision tree is controlled with the methods:

* `supervise`: start a supervision tree.

* `startup`: start a node.

* `shutdown`: terminate a node.

A supervised task function needs to have as a first argument a task descriptor `td` for inter-task communication and shutdown requests.

In the above example the `printer` function is the supervised task function of the `Process` defined by `process(printer; args=(PrinterStatus(0),))`.

Applications messages sent to the task and the `Shutdown` control message are received from the `td.inbox` Channel.

To check for a termination request use the method `is_shutdown`:

```julia
function mytask(td)
    for msg in td.inbox
        if is_shutdown(msg)
            break
        end
        # process application messages
        # ...
    end
end
```

In alternative the `receive` method processes the messages until a shutdown is received.

```julia
function mytask(td)
    receive(pd) do msg
        # process application messages
        # ...
    end
end
```

If the task is only interested in checking for shutdown request then the method `is_shutdown(td)` suffice, but in this case remember that other messages in the process inbox are silently discarded.

`simple-process.jl`:

```julia
using Visor

function worker(td; steps=15, check_interrupt_every=Inf)

    @info "making $steps steps and checking for SIGINT every $check_interrupt_every steps"
    try
        for i in 1:steps
            @info "[$(td.id)]: doing $i ..."
            sleep(0.5)
            if i % check_interrupt_every == 0
                if is_shutdown(td)
                    return
                end
            end
        end
    catch e
        @error "worker: $e"
        rethrow()
    end
end

forever([
    process(worker, namedargs=(steps=15,check_interrupt_every=5)),
])
```

```bash
myhost:~/$ julia simple-process.jl
[ Info: making 15 totals steps and checking for interrupt requests every 5 steps
[ Info: [worker]: doing 1 ...
[ Info: [worker]: doing 2 ...
^C CTRL-C
[ Info: [worker]: doing 3 ...
[ Info: [worker]: doing 4 ...
[ Info: [worker]: doing 5 ...
myhost:~/$
```

To send application messages the standard Channel api may be used or the utilities provided by Visor:

* `cast(td, "path.to.target", message)`: send a message to the node with full name `path.to.target`.
* `call(td, "path.to.target", request)`: send a request to and wait for a response.
* `is_request(message)`: check if `message` is a request.
* `reply(message, response)`: send the `response` to the `call` method that issued the `message` request .

The following example shows the mechanics of inter-task communication.
Note that the order of tasks shutdown is the reverse of startup order.

```julia
# app.jl:

using Visor

struct CounterMsg
    count::Int
end

struct ControllerMsg
    query::String
end 

function db_service(td)
    @info "[$td] starting"
    for msg in td.inbox
        if is_shutdown(msg)
            break
        elseif isa(msg, CounterMsg)
            @info "[$td] got message: $msg"
        elseif is_request(msg)
            if isa(msg.request, ControllerMsg)
                reply(msg, :on)
            end
        end
    end
    @info "[$td] shutting down"
end

function app_counter(td)
    @info "[$td] starting"
    n = 0

    # get the db_service process handle
    db = from("db_service")

    while true
        sleep(2)
        if is_shutdown(td)
            break
        end
        # send a data message to db_service process
        cast(db, CounterMsg(n))
        n += 1
    end
    @info "[$td] shutting down"
end

function app_controller(td)
    @info "[$td] starting"

    # get the db_service process handle
    db = from("db_service")

    while true
        sleep(2)
        if is_shutdown(td)
            break
        end

        # send a request to db_service process 
        response = call(db, ControllerMsg("select status from ..."), -1)
        @info "[$td] current status: $response"
    end
    @info "[$td] shutting down"
end

forever([process(db_service), process(app_counter), process(app_controller)])
```

```sh
$ julia app.jl

[ Info: [db_service] starting
[ Info: [app_counter] starting
[ Info: [app_controller] starting
[ Info: [db_service] got message: CounterMsg(0)
[ Info: [app_controller] current status: on
^C[ Info: [db_service] got message: CounterMsg(1)
[ Info: [app_controller] shutting down
[ Info: [app_counter] shutting down
[ Info: [db_service] shutting down

```
