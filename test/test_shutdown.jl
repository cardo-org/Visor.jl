using Dates
using Visor
using Test

function ok(pd)
    while true
        if isshutdown(pd)
            @info "return from $pd"
            return nothing
        end
        sleep(0.1)
    end
end

function myprocess(pd)
    @info "[$(now())][$pd] starting"
    sleep(0.5)
    error("boom")

    return nothing
end

function stop(tmr)
    try
        @info "[$(now())][stop task] shutting down ..."
        #Visor.dump()
        #@info "shutting down"
        shutdown()
        #sleep(2)
        #@info "after shutdown:"
        #Visor.dump()
        #sleep(1)
    catch e
        @error "stop: $e"
    end
    return nothing
end

Timer(stop, 4.0)

spec = [
    supervisor(
        "super",
        [process(ok), process(myprocess; debounce_time=0.5)];
        strategy=:one_for_all,
        intensity=6,
    ),
]
supervise(spec; intensity=3)

sleep(5)
@info "bye bye"
