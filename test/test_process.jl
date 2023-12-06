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
        timer = Timer(_tmr->shutdown(), 2)
        supervise(process(tsk; restart=restart))
        @test restarted === expected
        close(timer)
    end
end

run()