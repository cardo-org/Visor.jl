include("./utils.jl")

function ok(pd)
    while true
        if isshutdown(pd)
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

function run()
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
    end
    t = time()
    shutdown()
    delta = time() - t
    @info "[test_shutdown] delta time: $delta"
    return delta
end

@info "[test_shutdown] start"
run()
delta = run()
@test delta < 0.1
@info "[test_shutdown] stop"
