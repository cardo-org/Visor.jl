include("./utils.jl")

#=
The process task captures the ProcessInterrupt exception
and refuses to terminate despite the scheduler indication.
=#

#wait_time = 1.1
wait_time = 0.2

count = 0

function fooob(pd)
    global count
    @info "[test_ignore_process_interrupt][$pd] starting"

    while true
        try
            sleep(wait_time / 4)
            count += 1
            @info "[test_ignore_process_interrupt][$pd] alive"
            if count === 5
                # insted of continuing forever,
                # returns after 5 iterations
                return nothing
            end
        catch e
            @info "[test_ignore_process_interrupt]: error $e"
        end
    end
    @info "[test_ignore_process_interrupt][$pd] end"
end

@info "[test_ignore_process_interrupt] start"
try
    sv = supervise(
        process(fooob; force_interrupt_after=0.1, stop_waiting_after=wait_time); wait=false
    )

    # simulate a SIGINT
    Timer((tim) -> Visor.handle_signal(0), wait_time)

    wait(sv)

    @info "[test_ignore_process_interrupt] done"
    sleep(wait_time)

    @test count >= 4
catch e
    @error "[test_ignore_process_interrupt] error: $e"
    @test false
finally
    shutdown()
end
@info "[test_ignore_process_interrupt] stop"
Visor.dump()
