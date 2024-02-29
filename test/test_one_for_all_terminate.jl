using Visor
using Test

#
# 
#       root
#        /
#       /  
#      s1   
#     /  \
#   s11  w3
#   /  \
#  w1  w2
#
#  startup order: w1, w2, w3  
#  if strategy is :one_for_all and the failed process does not restart terminate 
#  all sibling processes.   
#

#ENV["JULIA_DEBUG"] = Visor

starts = 0

stopped = []

function myworker(self)
    global starts

    @info "[$self]: starting"
    starts += 1
    if self.id === "w3"
        sleep(2)
        #if starts < 4
        @info "[$self]: THROW EXCEPTION"
        error("bang")
        #end
    else
        sleep(20)
    end
    @info "[$self]: terminate"
    #    for msg in self.inbox
    #        @debug "[$(self.id)] recv: $msg"
    #        if isshutdown(msg)
    #            push!(stopped, self.id)
    #            break
    #        end
    #    end
end

s11_specs = [
    process("w1", myworker; thread=true), process("w2", myworker; force_interrupt_after=1)
]

s1_specs = [
    supervisor("s11", s11_specs; intensity=1, terminateif=:shutdown),
    process("w3", myworker; force_interrupt_after=1),
]

specs = [supervisor("s1", s1_specs; strategy=:one_for_all)]

handle = Visor.supervise(specs; wait=false)

timer_not_triggered = true
timer = Timer((tim) -> begin
    global timer_not_triggered = false
    shutdown(handle)
end, 10)

@test wait(handle) === nothing

# if all processes terminate the timer that shutdown thw system
# is not triggered 
@test timer_not_triggered
@test starts === 6
close(timer)