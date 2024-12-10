include("utils.jl")

restarted = false
function fail(self)
    global restarted

    Visor.ifrestart(self) do
        restarted = true
    end
    return error("bang!")
end

function normal(self)
    global restarted
    @info "normal invoked"

    Visor.ifrestart(self) do
        restarted = true
    end
end

then_restart = true
then_not_restart = false

function run()
    global restarted

    cases = [
        fail :permanent then_restart
        fail :transient then_restart
        fail :temporary then_not_restart
        normal :permanent then_restart
        normal :transient then_not_restart
        normal :temporary then_not_restart
    ]

    for (tsk, restart, expected) in eachrow(cases)
        @info "testing tsk=$tsk, restart=$restart, expected to restart=$expected"
        restarted = false

        p = process(tsk; restart=restart)
        timer = Timer(_tmr -> shutdown(p), 0.1)
        supervise(p)

        @test restarted === expected
        close(timer)
    end
end

@info "[test_process] start"
try
    run()
catch e
    @error "[test_process] error: $e"
    @test false
finally
    shutdown()
end
@info "[test_process] stop"
