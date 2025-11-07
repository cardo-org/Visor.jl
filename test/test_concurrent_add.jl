include("utils.jl")

count = 0

function mytask(pd, n)
    #@info "[$pd] started $n"
    global count
    for msg in pd.inbox
        if isshutdown(msg)
            count += 1
            break
        end
    end
    #@info "[$pd] stopped $n"
end

function run(n)
    sv = supervise(Visor.Supervised[]; wait=false)
    Threads.@threads for i in 1:n
        Visor.startup(sv, process("mytask$i", mytask; args=(i,)))
    end
end

@info "[test_concurrent_add] start"
nprocs = 100
try
    procs = run(nprocs)
    sleep(1)
catch e
    @error "[test_concurrent_add] error: $e"
    @test false
finally
    shutdown()
    @test count == nprocs
end
@info "[test_concurrent_add] stop"
