include("./utils.jl")

#
#
#    root
#     /
#    p1
#   /  \
#  w1  w2
#

function quit(handle)
    @info "[test_permanent_supervisor][$handle]: quitting"
    shutdown(handle)
    @info "[test_permanent_supervisor] bye bye"
end

stopped = []

function myworker(self)
    @info "[test_permanent_supervisor] worker $(self.id)"
end

@info "[test_permanent_supervisor] start"
try
    p1_specs = [process("w1", myworker), process("w2", myworker)]

    handle = Visor.supervise(
        [supervisor("p1", p1_specs; terminateif=:shutdown)]; wait=false
    )

    wait_time = 0.5
    tmr = Timer(tim -> quit(handle), wait_time)
    t = time()
    wait(handle)
    delta = time() - t
    @info "[test_permanent_supervisor] delta time for permanent supervisor: $delta secs"
    @test delta > wait_time

    handle = Visor.supervise([supervisor("p1", p1_specs; terminateif=:empty)]; wait=false)

    t = time()
    wait(handle)
    delta = time() - t
    @info "[test_permanent_supervisor] delta time for transient supervisor: $delta secs"
    @test delta < 0.1
catch e
    @error "[test_permanent_supervisor] error: $e"
finally
    shutdown()
end
@info "[test_permanent_supervisor] stop"
