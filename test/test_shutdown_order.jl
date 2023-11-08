using Visor
using Test

#
# 
#       root
#        /\
#       /  \
#      s1   s2
#     /      \
#   s11       w3
#   /  \
#  w1  w2
#
#  startup order: w1, w2, w3  
#  shutdown order: w3, w2, w1  
#

stopped = []

function myworker(self)
    for msg in self.inbox
        @debug "[$(self.id)] recv: $msg"
        if is_shutdown(msg)
            push!(stopped, self.id)
            break
        end
    end
end

sv2_specs = [process("w3", myworker)]

sv3_specs = [process("w1", myworker), process("w2", myworker; force_interrupt_after=1)]

sv1_specs = [supervisor("s11", sv3_specs; intensity=1)]

specs = [
    supervisor("s1", sv1_specs)
    supervisor("s2", sv2_specs)
]

handle = Visor.supervise(specs; wait=false)

Timer(tim -> shutdown(handle), 2)
wait(handle)

@test stopped == ["w3", "w2", "w1"]
