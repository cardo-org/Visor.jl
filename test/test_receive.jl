include("utils.jl")

shutdown_requested = false

function myprocess(pd)
    receive(pd) do msg
        @info "[$pd] doing something with $msg"
        reply(msg, "world")
    end
    @info "[$pd] returning"
end

@info "[test_receive] start"
try
    w1 = process("w1", myprocess)
    sv = supervise([w1]; wait=false)

    #    try
    #        call(w1, "hello"; timeout=0.01)
    #        @test false
    #    catch e
    #        @info "[test_receive] expected exception: $e"
    #        @test isa(e, ErrorException)
    #        @test e.msg === "request [hello] to [w1] timed out"
    #    end

    response = call(w1, "hello"; timeout=5)
    @info "[test_receive] response:$response"
    @test response === "world"

    # do nothing,
    # (perhaps) restart the children ...
    #Visor.start(sv)
catch e
    @info "[test_receive] exception: $e"
    @test false
finally
    shutdown()
end
@info "[test_receive] stop"
