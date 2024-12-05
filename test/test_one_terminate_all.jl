using Visor
using Test

terminated = true

function terminate(::Timer)
    global terminated
    terminated = false
    @error "[tast_one_terminate_all] failed to stop all processes"
    shutdown()

    return nothing
end

function task_one(pd)
    return sleep(0.5)
end

function task_all(pd)
    for msg in pd.inbox
        if isshutdown(msg)
            break
        end
    end
end

Timer(terminate, 5)

try
    #spec = [process(task_all), process(task_one), process(task_all)]
    spec = [process("p1", task_all), process("p2", task_one), process("p3", task_all)]

    sv = supervise(spec; strategy=:one_terminate_all, terminateif=:empty)

    Visor.dump()
    info = procs()
    @info "processes: $info"

    @test terminated
finally
    shutdown()
end
