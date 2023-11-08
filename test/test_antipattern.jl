using Visor
using Test

wait_time = 1.1

count = 0

now() = Int(floor(time()))

function fooob(pd)
    global count
    @info "$(now()) [$pd] starting"

    while true
        try
            sleep(0.5)
            count += 1
            @info "$(now()) [$pd] alive"
        catch e
            @info "$(now()): $e"
        end
    end
    @info "$(now()) [$pd] end"
end

sv = supervise(
    process(fooob; force_interrupt_after=0, stop_waiting_after=wait_time); wait=false
)

# simulate a SIGINT
Timer((tim) -> Visor.handle_signal(0), wait_time)

wait(sv)

@info "$(now()) done"
sleep(wait_time)

@test count >= 4
