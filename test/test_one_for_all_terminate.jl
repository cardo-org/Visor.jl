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
#  if strategy is :one_for_all and the failed process does not restart terminate
#  all sibling processes.
#

starts = 0

stopped = []

function myworker(self)
    global starts

    @info "[test_one_for_all_terminate][$self]: starting"
    starts += 1
    if self.id === "w3"
        @info "[test_one_for_all_terminate][$self]: throwing bang exception"
        error("bang")
    else
        sleep(20)
    end
    @info "[test_one_for_all_terminate][$self]: terminate"
end

@info "[test_one_for_all_terminate] start"
try
    s11_specs = [
        process("w1", myworker; thread=true, force_interrupt_after=0.1),
        process("w2", myworker; force_interrupt_after=0.1),
    ]

    s1_specs = [
        supervisor("s11", s11_specs; intensity=1, terminateif=:shutdown),
        process("w3", myworker; force_interrupt_after=0.1),
    ]

    specs = [supervisor("s1", s1_specs; strategy=:one_for_all)]

    handle = Visor.supervise(specs; wait=false)

    timer_not_triggered = true
    timer = Timer((tim) -> begin
        global timer_not_triggered = false
        shutdown(handle)
    end, 10)

    @test wait(handle) === nothing

    # if all processes terminate the timer that shutdown thw system
    # is not triggered
    @test timer_not_triggered
    @test starts === 6
    close(timer)
catch e
    @error "[test_one_for_all_terminate] error: $e"
finally
    shutdown()
end
@info "[test_one_for_all_terminate] stop"
