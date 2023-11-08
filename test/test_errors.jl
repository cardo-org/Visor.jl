include("utils.jl")

# Throws an exception because the supervisor fake-supervisor does not exist
function getrunning(sv)
    process = from("fake-supervisor")
    @info "supervisor: $process"

    return Visor.nproc(process)
end

specs = [process("process-1", worker; namedargs=(steps=15, check_interrupt_every=5))]

@test_throws ErrorException supervise(specs, strategy=:invalid)
@test_throws ErrorException supervise(specs, terminateif=:invalid)

sv = Visor.supervise(specs; wait=false)

running = Visor.nproc(sv)
@info "running processes: $running"
@test running == 1

@test_throws Visor.UnknownProcess call("invalid-process", :some_data)

@test_throws Visor.UnknownProcess getrunning(sv)

@test_throws ErrorException process(worker, restart=:invalid_restart)

shutdown(sv)
