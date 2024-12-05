using Visor
using Test

function another(pd)
    return sleep(1)
end

function mytask(pd)
    global newname
    @info "[$pd] starting"
    sleep(1)
    @info "changed name to [$pd]"
    return newname = pd.id
end

oldname = "temp_name"
newname = ""

spec = [process(oldname, mytask), process("another", another)]

sv = supervise(spec; wait=false)

p = from(oldname)
setname(p, "new_name")

Visor.dump()

wait(sv)
@test newname === "new_name"
