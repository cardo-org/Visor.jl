include("utils.jl")

#         root
#          /\
#         /  \
#       sv1  sv2    
#       /      \
#    sv1-3      w3
#     /\    
#   w1  w2
#

sv2_specs = [process("w3", worker; namedargs=(steps=10, check_interrupt_every=2))]

sv3_specs = [
    process("w1", worker; namedargs=(steps=5, check_interrupt_every=1)),
    process("w2", worker; namedargs=(steps=10, check_interrupt_every=3)),
]

sv1_specs = [supervisor("sv1-3", sv3_specs; intensity=1)]

specs = [
    supervisor("sv1", sv1_specs)
    supervisor("sv2", sv2_specs)
]

function getrunning(handle)
    sv = Visor.from_supervisor(handle, "sv1.sv1-3")
    nprocs = length(Visor.running_nodes(sv))
    @info "supervisor [$(sv.id)] running processes: $nprocs"
    return ttrace["getrunning"] = nprocs == 1
end

function shutdown_request(start_node, target_id::String)
    try
        @info "broadcast shutdown for [$target_id]"
        cast(target_id, Visor.Shutdown())
    catch e
        @error "shutdown_request: $e"
    end
end

handle = supervise(specs; wait=false)

sv = from("sv1.sv1-3")

# test internal method from_path
# from_path is not thread safe, use from instead
node = Visor.from_path(sv, ".")
@test node === handle

node = Visor.from_path(sv, ".sv1")
@test node === from("sv1")

@test Visor.from_path(from("sv2.w3"), "w3") === from("sv2.w3")

t1 = Timer((tim) -> shutdown_request(handle, "sv1.sv1-3.w1"), 2)
t2 = Timer((tim) -> getrunning(handle), 3)

n = Visor.nproc(sv)
@test n == 2

wait(handle)

for (tst, result) in ttrace
    @test result
end
