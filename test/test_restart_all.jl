include("./utils.jl")

#
#
#       root
#        /
#       /
#      s1
#     /  \
#   s11  w3
#   /  \
#  w1  w2
#
#  startup order: w1, w2, w3
#  check :one_for_all restart strategy
#

starts = 0

stopped = []

tlock = ReentrantLock()

function myworker(self)
    global starts

    @info "[$self]: starting"
    lock(tlock) do
        starts += 1
    end

    if self.id === "w3"
        sleep(0.1)
        if starts < 4
            @info "[$self]: throwing bang exception"
            error("bang")
        end
    else
        sleep(3)
    end
    @info "[test_restart_all][$self]: terminate"
end

@info "[test_restart_all] start"
try
    s11_specs = [
        process("w1", myworker; thread=true, force_interrupt_after=0.01),
        process("w2", myworker; force_interrupt_after=0.01),
    ]

    s1_specs = [
        supervisor("s11", s11_specs; intensity=1, terminateif=:shutdown),
        process("w3", myworker; force_interrupt_after=0.01),
    ]

    specs = [supervisor("s1", s1_specs; strategy=:one_for_all, terminateif=:shutdown)]

    handle = Visor.supervise(specs; wait=false)
    Timer((tim) -> shutdown(handle), 1)

    @test wait(handle) === nothing
catch e
    @error "[test_restart_all] error: $e"
    @test false
finally
    shutdown()
end

@test starts === 6
@info "[test_restart_all] stop"
