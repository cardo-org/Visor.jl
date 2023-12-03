# Inter Process Communication

The standard `Channel` mechanism is used to communicate between `process` tasks: the `inbox` channel.

In addition to `put!(process.inbox, message)` method to send messages to a `process` there is a `cast` function for sending a message (fire and forget message pattern) and  a `call` function for waiting for a response (request-response message pattern).

## cast

```julia
cast(self::Supervised, target_id::String, message::Any)
```

`cast` sends a `message` to a task with name `target_id` and returns immediately.

```julia
using Visor

function controller(self)
    for msg in self.inbox
        println("reservation info: $msg")
        if msg["available"] == 0
            println("all booked!")
            break
        end
    end
end

function box_office(self)
    for avail in 50:-10:0
        seats = Dict("tot"=>50, "available"=>avail)
        cast(self, "controller", seats)
        sleep(1)
    end
end

supervise([process(controller), process(box_office)])
```

## call

```julia
call(self::Supervised, target_id::String, request::Any, timeout::Real=-1)
```

`call` sends a `request` to a task with name `target_id` and wait for a response for `timeout` seconds.

If `timeout` is equal to -1 then waits forever, otherwise if a response is not received
in `timeout` seconds an `ErrorException` is raised.

The message sent to the target task is a `Request` struct that contains the request and a channel for sending back the response.

```julia
struct Request <: Message
    inbox::Channel
    request::Any
end
```

```julia
using Visor

function server(self)
    for msg in self.inbox
        isshutdown(msg) && break
        put!(msg.inbox, msg.request*2)
    end
end

function requestor(self)
    request = 10
    response = call(self, "server", request)
    @info "server($request)=$response"
end

supervise([process(server), process(requestor)]);
```
