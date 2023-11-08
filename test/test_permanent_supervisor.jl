using Visor
using Test

#
# 
#    root
#     /
#    p1
#   /  \
#  w1  w2
#

function quit(handle)
    @info "[$handle]: quitting"
    shutdown(handle)
    @info "bye bye"
end

stopped = []

function myworker(self)
    @info "worker $(self.id)"
end

p1_specs = [process("w1", myworker), process("w2", myworker)]

handle = Visor.supervise([supervisor("p1", p1_specs; terminateif=:shutdown)]; wait=false)

wait_time = 5
tmr = Timer(tim -> quit(handle), wait_time)
t = time()
wait(handle)
delta = time() - t
@info "delta time for permanent supervisor: $delta secs"
@test delta > wait_time

handle = Visor.supervise([supervisor("p1", p1_specs; terminateif=:empty)]; wait=false)

t = time()
wait(handle)
delta = time() - t
@info "delta time for transient supervisor: $delta secs"
@test delta < 0.1
