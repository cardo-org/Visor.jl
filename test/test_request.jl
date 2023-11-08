include("utils.jl")

NAME = "Alfred"

function server(self)
    try
        for msg in self.inbox
            @info "[$(self.id)] recv: $msg"
            if is_shutdown(msg)
                break
            elseif msg.request === :get_name
                put!(msg.inbox, NAME)
            end
        end
    catch e
        @error "server: $e"
        rethrow()
    end
end

function slow(self)
    for msg in self.inbox
        is_shutdown(msg) && break
        sleep(3)
        reply(msg, "pong")
    end
end

function getname(sv)
    return call("foo.process-1", :get_name; timeout=1)
end

foo_specs = [
    process("process-1", server; force_interrupt_after=Inf)
    process(slow)
]

specs = [supervisor("foo", foo_specs)]

sv = Visor.supervise(specs; wait=false)

name = getname(sv)
@test name === NAME

# test the request timeout
try
    @info "timeout request ..."
    response = call("foo.slow", "ping"; timeout=1)
    @info "response: $response"
catch e
    @test e.msg === "request [ping] to [slow] timed out"
end

shutdown()
