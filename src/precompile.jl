function task_one(pd)
    return sleep(0.5)
end

function task_all(pd)
    for msg in pd.inbox
        @info "[$pd] msg recv: $msg"
        if isshutdown(msg)
            break
        end
    end

    return nothing
end

function run()
    try
        spec = [process("p1", task_all), process("p2", task_one), process("p3", task_all)]
        sv = supervisor("sv", spec)

        Visor.format4print(sv.processes)
        Visor.format4print(collect(values(sv.processes)))
    catch e
        @error "[precompile] error: $e"
    finally
        shutdown()
    end
    return nothing
end

run()
