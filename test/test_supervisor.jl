include("utils.jl")

include("logger.jl")

DEBUG = get(ENV, "DEBUG", "0")
logging(; debug=DEBUG == "0" ? [] : [Visor])

shutdown_requested = false

function myprocess(pd)
    @info "$pd: done"
end

function add_process()
    sleep(1)
    return startup(from("dynamic"), process(myprocess))
end

function request_shutdown(_tmr)
    global shutdown_requested
    shutdown_requested = true
    @info "shutdown requested"
    return shutdown()
end

nat(pd) = nothing

function terminateif_empty()
    # Verify that when terminateif is equal to :empty
    # then the supervisor terminates when its
    # supervised processes are done.

    tim = Timer(request_shutdown, 2)
    @async add_process()

    supervise(supervisor("dynamic", process(nat)))
    return close(tim)
end

function terminateif_shutdown()
    # Verify that when terminateif is equal to :shutdown
    # then the supervisor does not terminate when there are
    # no more running supervised processes.

    tim = Timer(request_shutdown, 2)
    @async add_process()

    supervise(supervisor("dynamic"; terminateif=:shutdown))
    return close(tim)
end

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
    @info "exception: $e"
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

shutdown()
