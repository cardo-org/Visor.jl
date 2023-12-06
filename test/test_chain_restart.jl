using Visor
using Test

#
# 
#     root
#      /
#     sv
#    /  \
#  good  bad
#

ENV["JULIA_DEBUG"] = Visor

restarts = 0

function myworker(self)
    @info "worker $(self.id)"
    #sleep(4)
end

function faulty(self)
    global restarts
    if self.isrestart
        restarts += 1
    end
    @info "faulty [$(self.id)] ($(self.task))"
    return error("failure")
end

p1_specs = [process("good", myworker), process("bad", faulty)]

handle = supervise([supervisor("sv", p1_specs; intensity=2)])

@test restarts === 2
