include("utils.jl")

intensity = 2
restarts = -1
ifrestart_called = false

function defective_worker(self)
    global restarts, ifrestart_called

    Visor.ifrestart(self) do
        ifrestart_called = true
    end

    @info "[test_restart] defective_worker start"
    restarts += 1
    sleep(0.1)
    return error("bang!!")
end

@info "[test_restart] start"
try
    children = [
        process("myworker", worker; namedargs=(steps=2, check_interrupt_every=1)),
        process("defective-worker", defective_worker; debounce_time=0.1),
    ]

    supervise(children; intensity=intensity)

    @test restarts == intensity
    @test ifrestart_called
catch e
    @error "[test_restart] error: $e"
    @test false
finally
    shutdown()
end
@info "[test_restart] stop"
