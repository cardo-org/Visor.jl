include("utils.jl")

#         root
#          /\
#         /  \
#       sv1  sv2
#       /      \
#    sv1-3      w3
#     /\
#   w1  w2 127.0.0.1
#

function getrunning(handle)
    sv = Visor.from_supervisor(handle, "sv1.sv1-3")
    nprocs = length(Visor.running_nodes(sv))
    @info "[test_hierarchy] supervisor [$(sv.id)] running processes: $nprocs"
    return ttrace["getrunning"] = nprocs == 2
end

function shutdown_request(start_node, target_id::String)
    try
        @info "[test_hierarchy] broadcast shutdown for [$target_id]"
        cast(target_id, Visor.Shutdown())
    catch e
        @error "shutdown_request: $e"
    end
end

@info "[test_hierarchy] start"
try
    sv2_specs = [process("w3", worker; namedargs=(steps=10, check_interrupt_every=2))]

    sv3_specs = [
        process("w1", worker; namedargs=(steps=15, check_interrupt_every=1)),
        process("w2", worker; namedargs=(steps=12, check_interrupt_every=2)),
        process("127.0.0.1", worker; namedargs=(steps=12, check_interrupt_every=2)),
    ]

    sv1_specs = [supervisor("sv1-3", sv3_specs; intensity=1)]

    specs = [
        supervisor("sv1", sv1_specs)
        supervisor("sv2", sv2_specs)
    ]

    @test !isprocstarted("sv1.sv1-3.w1")
    handle = supervise(specs; wait=false)
    sleep(1)
    @test isprocstarted("sv1.sv1-3.w1")

    sv = from("sv1.sv1-3")

    proc = from_name(sv, "127.0.0.1")
    @test proc.id == "127.0.0.1"

    proc = from_name("127.0.0.1")
    @test proc === nothing

    # test internal method from_path
    # from_path is not thread safe, use from instead
    node = Visor.from_path(sv, ".")
    @test node === handle

    node = Visor.from_path(sv, ".sv1")

    @test hassupervised("sv1")
    @test !hassupervised("unknown")

    @test node === from("sv1")

    @test Visor.from_path(from("sv2.w3"), "w3") === from("sv2.w3")

    t1 = Timer((tim) -> shutdown_request(handle, "sv1.sv1-3.w1"), 0.2)
    t2 = Timer((tim) -> getrunning(handle), 0.5)

    n = Visor.nproc(sv)
    @test n == 3

    wait(handle)

    for (tst, result) in ttrace
        @test result
    end

    process_tree = procs()
    @test issetequal(keys(process_tree["root"]), ["sv1", "sv2"])
    @test issetequal(keys(process_tree["root"]["sv1"]), ["sv1-3"])
    @test isempty(process_tree["root"]["sv2"])
    close(t1)
    close(t2)
catch e
    @error "[test_hierarchy] error: $e"
    showerror(stdout, e, catch_backtrace())
    @test false
finally
    shutdown()
end
@info "[test_hierarchy] stop"
