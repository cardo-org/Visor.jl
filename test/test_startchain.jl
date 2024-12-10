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

w3_proc = process("w3", worker; namedargs=(steps=10, check_interrupt_every=2))
sv2_specs = [w3_proc]

sv3_specs = [
    process("w1", worker; namedargs=(steps=15, check_interrupt_every=1)),
    process("w2", worker; namedargs=(steps=15, check_interrupt_every=1)),
    process("127.0.0.1", worker; namedargs=(steps=15, check_interrupt_every=1)),
]

sv1_specs = [supervisor("sv1-3", sv3_specs; intensity=1)]

sv2 = supervisor("sv2", sv2_specs)
specs = [
    supervisor("sv1", sv1_specs)
    sv2
]

@info "[test_startchain] start"
try
    Visor.add_node(Visor.__ROOT__, sv2)

    @info "[$w3_proc] startchain"
    Visor.startchain(w3_proc)

    sleep(0.1)
    ptree = procs()
    @test ptree["root"]["sv2"]["w3"] === w3_proc
    shutdown()

    proc = process("simple", worker; namedargs=(steps=15, check_interrupt_every=1))
    Visor.add_node(Visor.__ROOT__, proc)
    @info "[$proc] startchain"
    Visor.startchain(proc)

    sleep(0.1)
    ptree = procs()
    @test ptree["root"]["simple"] === proc
catch e
    @error "[test_startchain] error: $e"
    @test false
finally
    shutdown()
end
@info "[test_startchain] stop"
