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

@info "[test_phase] start"
try
    proc = process(mytask)
    spec = [proc]

    Timer(terminate, 0.2)
    sv = supervise(spec; wait=false)

    setphase(proc, :ground)

    @test getphase(proc) === :ground
catch e
    @error "[test_phase] error: $e"
    @test false
finally
    shutdown()
end

@info "[test_phase] stop"
