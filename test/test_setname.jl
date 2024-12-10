using Visor
using Test

function another(pd)
    return sleep(1)
end

function mytask(pd)
    global newname
    @info "[$pd] starting"
    sleep(0.1)
    @info "[test_setname] changed name to [$pd]"
    return newname = pd.id
end

oldname = "temp_name"
newname = ""

@info "[test_setname] start"
try
    spec = [process(oldname, mytask), process("another", another)]

    sv = supervise(spec; wait=false)

    p = from(oldname)
    setname(p, "new_name")

    wait(sv)
    @test newname === "new_name"
catch e
    @error "[test_setname] error: $e"
finally
    shutdown()
end
@info "[test_setname] stop"
