include("utils.jl")

function handler(process, event)
    ttrace[event] = process
    return nothing
end

function normal_return_process(pd)
    for msg in pd.inbox
        if isshutdown(msg)
            break
        end
    end
end

function exception_process(pd)
    return error("boom!")
end

function exception_and_restart_process(pd)
    if pd.isrestart
        @info "normal return"
    else
        return error("boom!")
    end
end

function normal_return()
    Visor.setroot(; handler=handler)
    p = process(normal_return_process)
    supervise(p)
    yield()
    @test haskey(ttrace, Visor.ProcessReturn(p))
    return nothing
end

function exception()
    Visor.setroot(; handler=handler)
    p = process(exception_process)
    supervise(p)
    yield()
    @test haskey(ttrace, Visor.ProcessError(p, ErrorException("boom!")))
    @test haskey(ttrace, Visor.ProcessFatal(p))
    return nothing
end

function exception_and_restart()
    Visor.setroot(; handler=handler)
    p = process(exception_and_restart_process)
    supervise(p)
    yield()
    @test haskey(ttrace, Visor.ProcessError(p, ErrorException("boom!")))
    @test haskey(ttrace, Visor.ProcessReturn(p))
    return nothing
end

Timer((_timer) -> shutdown(), 2)
normal_return()

exception()

exception_and_restart()
