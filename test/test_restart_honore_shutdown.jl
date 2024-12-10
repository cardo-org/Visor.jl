include("utils.jl")

intensity = 2
debounce_time = 1

function defective_worker(self)
    global restarts, ifrestart_called

    @info "[test_restart_honore_shutdown] defective_worker start"
    return error("bang!!")
end

@info "[test_restart_honore_shutdown] start"
try
    children = [
        process(
            "myworker",
            worker;
            debounce_time=2,
            namedargs=(steps=15, check_interrupt_every=1),
        ),
        process("defective-worker", defective_worker; debounce_time=debounce_time),
    ]

    supervise(children; intensity=intensity, strategy=:one_for_all, wait=false)
    sleep(debounce_time / 2)

catch e
    @error "[test_restart_honore_shutdown] error: $e"
    @test false
finally
    @info "[test_restart_honore_shutdown] shutting down"
    shutdown()
    sleep(2)
end
@info "[test_restart_honore_shutdown] stop"
