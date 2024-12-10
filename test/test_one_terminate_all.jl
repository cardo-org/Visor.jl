include("utils.jl")

terminated = true

function terminate(::Timer)
    global terminated
    terminated = false
    shutdown()
    return nothing
end

function task_one(pd)
    return sleep(0.5)
end

function task_fail(pd)
    return error("boom")
end

function task_all(pd)
    for msg in pd.inbox
        if isshutdown(msg)
            break
        end
    end
end

@info "[test_one_terminate_all] start"
try
    timer = Timer(terminate, 3)
    spec = [process("p1", task_all), process("p2", task_one), process("p3", task_all)]
    sv = supervise(spec; strategy=:one_terminate_all, terminateif=:empty)

    @test terminated
    close(timer)

    global terminated = true
    timer = Timer(terminate, 3)
    spec = [process("p1", task_all), process("p2", task_fail), process("p3", task_all)]
    sv = supervise(spec; strategy=:one_terminate_all, terminateif=:empty)

    @test terminated
    close(timer)

finally
    shutdown()
end
@info "[test_one_terminate_all] stop"
