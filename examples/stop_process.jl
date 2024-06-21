#' # How to stop supervised tasks
#'
#' In Julia parlance a task is just a function that runs as a coroutine.
#'
#' A task managed by [Visor](https://github.com/cardo-org/Visor) differs from a
#' standard julia task because it is a function
#' that requires as its first argument an handle representing the
#' supervised task.
#'
#' In the following examples the handle `self` it is not used to communicate
#' with the task using the `inbox` channel
#' but just to check if a shutdown request was delivered and in this case it stops the task.
#'
#' The task `fair_task` is a `Visor.process`: it is a cooperative task that
#' checks itself for a shutdown request and acts accordingly.
using Visor

function fair_task(self)
    while true
        println("[$(self.id)] checkpoint ...")
        if isshutdown(self)
            println("[$(self.id)] cleanup and resources deallocation")
            break
        end
        sleep(0.5)
    end
    return println("[$(self.id)] DONE")
end

spec = [process("fair", fair_task)]
println("starting supervised tasks")
svisor = supervise(spec; wait=false)

sleep(3)
task = from("fair")

println("[$(task.id)] requesting shutdown ...")
shutdown(task)

#' The following is an example of a `process` that does not check for a shutdown
#' request. In this case it is forcibly
#' interrupted by the supervisor after a configurable amount of time.

function uncooperative_task(self)
    try
        while true
            println("[$(self.id)] working ...")
            sleep(2)
        end
    catch e
        println("[$(self.id)] interrupted by $e")
    finally
        println("[$(self.id)] DONE")
    end
end

spec = [process("uncooperative", uncooperative_task; force_interrupt_after=5)]

println("starting supervised tasks")
svisor = supervise(spec; wait=false)

sleep(3)
task = from("uncooperative")

println("[$(task.id)] requesting (ignored) shutdown ...")
shutdown(task)
