include("utils.jl")

intensity = 2
restarts = -1
if_restart_called = false

function defective_worker(self)
    global restarts, if_restart_called

    Visor.if_restart(self) do
        if_restart_called = true
    end

    @info "defective_worker start"
    restarts += 1
    sleep(1)
    return error("bang!!")
end

children = [
    process("myworker", worker; namedargs=(steps=15, check_interrupt_every=5)),
    process("defective-worker", defective_worker; debounce_time=0.5),
]

supervise(children; intensity=intensity)

@test restarts == intensity
@test if_restart_called