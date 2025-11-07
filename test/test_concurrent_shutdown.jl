include("utils.jl")

function mytask(pd, n)
    #@info "[$pd] started $n"
    for msg in pd.inbox
        if isshutdown(msg)
            break
        end
    end
    #@info "[$pd] stopped $n"
end

function run(n)
    specs = Visor.Supervised[]
    for i in 1:n
        push!(specs, process("mytask$i", mytask; args=(i,)))
    end

    supervise(specs; wait=false)

    return specs
end

@info "[test_concurrent_shutdown] start"
try
    nprocs = 100
    procs = run(nprocs)
    sleep(1)

    Threads.@threads for p in procs
        shutdown(p)
    end
catch e
    @error "[test_concurrent_shutdown] error: $e"
    @test false
finally
    try
        shutdown()
        @test true
    catch e
        @error "[test_concurrent_shutdown] shutdown: $e"
        @test false
    end
end
@info "[test_concurrent_shutdown] stop"
