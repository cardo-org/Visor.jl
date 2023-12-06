using Visor
using Test

ENV["JULIA_DEBUG"] = Visor
count = 0

function ok(pd)
    global count
    count += 1

    @info "starting [$pd]"
    sleep(3)
    @info "[$pd] ping"
end

function err(pd)
    global count

    @info "starting [$pd]"
    count += 1
    if count === 2
        error("bang!")
    end
    return sleep(2)
end

specs = [supervisor("s1", [supervisor("s2", [process(ok)])]), process(err)]

sv = supervise(specs; intensity=5, strategy=:one_for_all, wait=false)

tmr = Timer((tim) -> begin
    global terminated
    shutdown(sv)
    terminated = false
end, 8)

terminated = true

sleep(1)

wait(sv)
sleep(1)
@test terminated === true
@test count === 4

close(tmr)