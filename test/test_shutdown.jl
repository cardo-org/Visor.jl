include("./utils.jl")

function ok(pd)
    while true
        if isshutdown(pd)
            @info "[test_shutdown] return from $pd"
            return nothing
        end
        sleep(0.1)
    end
end

function myprocess(pd)
    @info "[test_shutdown][$pd] starting"
    sleep(5)
    return nothing
end

@info "[test_shutdown] start"
try
    spec = [
        supervisor(
            "super",
            [
                process(ok; force_interrupt_after=0),
                process(myprocess; debounce_time=0.5, stop_waiting_after=0.01),
            ];
            strategy=:one_for_all,
            intensity=6,
        ),
    ]
    supervise(spec; intensity=3, wait=false)
catch e
    @error "[test_shutdown] error: $e"
    @test false
finally
    t = time()
    shutdown()
    delta = time() - t
    @test delta < 0.1
end
@info "[test_shutdown] stop"
