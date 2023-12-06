include("utils.jl")

NAME = "George"
DYN_NAME = "Mildred"

function server1(self)
    for msg in self.inbox
        @info "[$(self.id)] recv: $msg"
        if isshutdown(msg)
            break
        elseif msg.request === :get_name
            put!(msg.inbox, NAME)
        end
    end
end

function server2(self)
    for msg in self.inbox
        @info "[$(self.id)] recv: $msg"
        if isshutdown(msg)
            break
        elseif msg.request === :get_name
            put!(msg.inbox, DYN_NAME)
        end
    end
end

function sv1_process(pd)
    return sleep(1)
end

foo_specs = [process("process-1", server1)]

specs = [supervisor("foo", foo_specs)]

sv = supervise(specs; wait=false)

name = call("foo.process-1", :get_name)
@test name === NAME

dyn_proc = startup(process("process-2", server2))

prc = from("process-2")
@info "TEST PRC: $prc"

name = call(prc, :get_name)
@test name === DYN_NAME

p1 = startup(process("process-3", server2))
p2 = startup(process("process-3:$(Visor.uid())", server2))
@test length(p2.id) > length(p1.id)

# add a composite node
prc = startup(supervisor("sv-1", process(sv1_process)))
@test from("sv-1.sv1_process") === prc.processes["sv1_process"]

Visor.procs(sv)

shutdown(sv)
