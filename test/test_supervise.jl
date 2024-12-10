include("utils.jl")

shutdown_requested = false

function myprocess(pd)
    for msg in pd.inbox
        if isshutdown(msg)
            @info "[$pd] terminating"
            break
        end
    end
end

@info "[test_supervise] start"
try
    sv = supervisor("sv", [process("w1", myprocess)]; terminateif=:shutdown)
    supervise(sv; wait=false)
    sleep(0.1)

    w2 = process("w2", myprocess)

    startup(sv, w2)
    sleep(0.1)
    ptree = procs()
    @test issetequal(keys(ptree["root"]), ["sv"])

    Timer(tmr -> shutdown(), 0.5)
    # should log: Warning: [root] already supervisioning proc [sv]
    supervise(sv)
catch e
    @info "[test_supervise] exception: $e"
    @test false
finally
    shutdown()
end
@info "[test_supervise] stop"
