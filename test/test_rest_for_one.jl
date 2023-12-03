include("utils.jl")

NAME = "Alfred"

EXPECTED_RESTARTS = 7
restart_count = 0

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

function terminate_p2(sv)
    p2 = from("boss.p2")

    return schedule(p2.task, ErrorException("simulate a failure"); error=true)
end

workerspecs = [
    process("p1", myworker)
    process("p2", myworker)
    process("p3", myworker)
    process("p4", myworker)
]

specs = [supervisor("boss", workerspecs; strategy=:rest_for_one)]

@info "starting ..."
sv = Visor.supervise(specs; wait=false)

sleep(2)
@info "terminating p2"
terminate_p2(sv)

sleep(5)
@info "terminating all"
shutdown(sv)

@test EXPECTED_RESTARTS === restart_count
