include("./utils.jl")

function mytask(pd)
    res = isshutdown(pd)
    @info "[test_isshutdown] isshutdown=$res"
end

@info "[test_isshutdown] start"
try
    proc = process(mytask)
    spec = [proc]

    sv = supervise(spec; wait=false)
    sleep(0.1)
catch e
    @error "[test_isshutdown] error: $e"
    @test false
finally
    shutdown()
end

@info "[test_isshutdown] stop"
