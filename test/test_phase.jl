using Visor
using Test

function terminate(::Timer)
    return shutdown()
end

function mytask(pd)
    for msg in pd.inbox
        if isshutdown(msg)
            phase = getphase(pd)
            @info "[test_phase] phase=$phase"
            break
        end
    end
end

proc = process(mytask)
spec = [proc]

Timer(terminate, 2)
sv = supervise(spec; wait=false)

setphase(proc, :ground)

wait(sv)

@test getphase(proc) === :ground
