include("utils.jl")

const NAME = "Alfred"

const TIMEOUT = 0.1

function server(self)
    try
        for msg in self.inbox
            @info "[$(self.id)] recv: $msg"
            if isshutdown(msg)
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
        isshutdown(msg) && break
        sleep(0.2)
        reply(msg, "pong")
    end
end

function getname(sv)
    return call("foo.process-1", :get_name; timeout=TIMEOUT * 20)
end

@info "[test_request] start"
try
    foo_specs = [
        process("process-1", server; force_interrupt_after=Inf)
        process(slow)
    ]

    foo_supervisor = supervisor("foo", foo_specs)

    sv = Visor.supervise([foo_supervisor]; wait=false)

    name = getname(sv)
    @test name === NAME

    # test the request timeout
    try
        @info "timeout request ..."
        response = call("foo.slow", "ping"; timeout=TIMEOUT)
        @info "response: $response"
    catch e
        @test e.msg === "request [ping] to [slow] timed out"
    end

    process2 = process("process-2", server; force_interrupt_after=Inf)
    process3 = process("process-3", server; force_interrupt_after=Inf)

    # a call with a process object messages add a process to the target supervisor (foo)
    res = call("foo", process2)
    @info "[test_request] add_node(process2)=$res"
    @test res === process2

    put!(foo_supervisor.inbox, process3)

    # get back the process
    res = call(foo_supervisor, "process-3")
    @info "[test_request] call(process-3)=$res"
    @test res === process3
catch e
    @error "[test_request] error: $e"
    @test false
finally
    shutdown()
end
@info "[test_request] stop"
