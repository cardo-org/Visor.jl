include("./utils.jl")

count = 0

function ok(pd)
    global count
    count += 1

    @info "[test_combo] starting [$pd]"
    sleep(0.1)
    @info "[test_combo][$pd] ping"
end

function err(pd)
    global count

    @info "[test_combo] starting [$pd]"
    count += 1
    if count === 2
        error("bang!")
    end
    return sleep(0.5)
end

@info "[test_combo] start"
try
    specs = [supervisor("s1", [supervisor("s2", [process(ok)])]), process(err)]

    sv = supervise(specs; intensity=5, strategy=:one_for_all, wait=false)

    tmr = Timer((tim) -> begin
        global terminated
        shutdown(sv)
        terminated = false
    end, 8)

    terminated = true

    wait(sv)
    sleep(0.1)
    @test terminated === true
    @test count === 4

    close(tmr)
catch e
    @error "[test_combo] error: $e"
    @test false
finally
    shutdown()
end
@info "[test_combo] stop"
