using Visor
using Test

ENV["JULIA_DEBUG"] = Visor

ttrace = Dict()

function worker(self; steps=15, check_interrupt_every=Inf)
    @info "making $steps totals steps and checking for interrupt requests every $check_interrupt_every steps"
    try
        for i in 1:steps
            @info "[$(self.id)]: doing $i ..."
            sleep(0.5)
            if i % check_interrupt_every == 0
                @info "[$(self.id)]: checkpoint for shutdown request"
                if Visor.isshutdown(self)
                    @info "[$(self.id)]: exiting"
                    return nothing
                end
            end
        end
    catch e
        @error "worker: $e"
        rethrow()
    end
end
