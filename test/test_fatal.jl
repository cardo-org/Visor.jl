include("./utils.jl")

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
#  w2 is a task that fails after 3 seconds
#

function myworker(self)
    for msg in self.inbox
        @info "[$(self.id)] recv: $msg"
        break
    end
end

function fatal_task(self)
    sleep(3)
    @info "[$(self.id)]: failing ..."
    return error("fatal error")
end

sv2_specs = [process("w3", myworker)]

sv3_specs = [process("w1", myworker), process("w2", fatal_task)]

sv1_specs = [supervisor("s11", sv3_specs; intensity=1)]

specs = [
    supervisor("s1", sv1_specs)
    supervisor("s2", sv2_specs)
]

supervise(specs)
