include("utils.jl")

shutdown_requested = false

function myprocess(pd)
    @info "[test_supervisor][$pd]: done"
end

function add_process()
    sleep(0.05)
    return startup(from("dynamic"), process(myprocess; force_interrupt_after=0.01))
end

function request_shutdown(_tmr)
    global shutdown_requested
    shutdown_requested = true
    @info "[test_supervisor] shutdown requested"
    return shutdown()
end

function nat(pd)
    @info "[test_supervisor][$pd] nat invoked"
end

function terminateif_empty()
    # Verify that when terminateif is equal to :empty
    # then the supervisor terminates when its
    # supervised processes are done.

    tim = Timer(request_shutdown, 0.1)
    @async add_process()

    supervise(supervisor("dynamic", process(nat)))
    return close(tim)
end

function terminateif_shutdown()
    # Verify that when terminateif is equal to :shutdown
    # then the supervisor does not terminate when there are
    # no more running supervised processes.

    tim = Timer(request_shutdown, 0.1)
    @async add_process()

    supervise(supervisor("dynamic"; terminateif=:shutdown))
    return close(tim)
end

@info "[test_supervisor] start"
try
    terminateif_empty()
    @test shutdown_requested === false

    terminateif_shutdown()
    @test shutdown_requested === true

    # get an opportunity to reset the ROOT supervisor
    yield()

    sv = supervise(supervisor("test"; terminateif=:shutdown); wait=false)

    # send an unknown message
    @test_throws Visor.UnknownProcess call(sv, "a")

    try
        call(sv, Dict("a" => 1))
    catch e
        @info "[test_supervisor] expected exception: $e"
        @test startswith(e.msg, "unknown message ")
    end

    cast(sv, "a message")

    try
        supervisor("sv"; terminateif=:invalid)
    catch e
        @test e.msg === "wrong shutdown value shutdown: must be one of :empty, :shutdown"
    end
    try
        supervisor("sv", process(nat); terminateif=:invalid)
    catch e
        @test e.msg === "wrong shutdown value shutdown: must be one of :empty, :shutdown"
    end

    try
        supervisor("sv"; terminateif=:empty)
    catch e
        @test e.msg === "immediate shutdown of supervisor [sv] with no processes"
    end

catch e
    @error "[test_supervisor] error: $e"
    @test false
finally
    shutdown()
end
@info "[test_supervisor] stop"
