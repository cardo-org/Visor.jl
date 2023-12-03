using Visor

function worker(self, steps=15, check_interrupt_every=Inf)
    @info "making $steps steps, checking for interrupt requests \
           every $check_interrupt_every steps and forcing interrupt \
           after $(self.force_interrupt_after) secs"
    for i in 1:steps
        @info "[$(self.id)]: doing $i ..."
        sleep(1)
        if i % check_interrupt_every == 0
            @info "[$(self.id)]: checkpoint for shutdown request"
            if Visor.isshutdown(self)
                return nothing
            end
        end
    end
end

tasks = [process("myworker", worker; args=(15,), force_interrupt_after=0.5)]

supervise(tasks)
