include("utils.jl")

NAME = "Alfred"

EXPECTED_RESTARTS = 7
restart_count = 0

function p2(self)
    global restart_count += 1
    sleep(1)
    return error("simulate a fault")
end

function myworker(self)
    global restart_count

    @info "(re)starting [$(self.id)]"
    restart_count += 1

    try
        for msg in self.inbox
            @info "[$(self.id)] recv: $msg"
            if isshutdown(msg)
                break
            elseif msg.request === :get_name
                put!(msg.inbox, NAME)
            end
        end
    catch e
        @error "worker: $e"
        rethrow()
    end
end

workerspecs = [
    process("p1", myworker)
    process("p2", p2)
    process("p3", myworker)
    process("p4", myworker)
]

specs = [supervisor("boss", workerspecs; strategy=:rest_for_one)]

@info "starting ..."
handle = Visor.supervise(specs; wait=false)

only_p1_running = false
timer = Timer((tim) -> begin

    # check that only p1 is running
    boss = from("boss")
    procs = boss.processes
    if (length(procs) === 1)
        global only_p1_running = true
    end
    @info "boss running processes: $(boss.processes)"
    shutdown(handle)
end, 8)

@test wait(handle) === nothing

# if all processes terminate the timer that shutdown thw system
# is not triggered 
@test only_p1_running
@test EXPECTED_RESTARTS === restart_count
close(timer)