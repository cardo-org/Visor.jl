using Visor
using Test

include("logger.jl")

DEBUG = get(ENV, "DEBUG", "0")
logging(; debug=DEBUG == "0" ? [] : [Visor])

ttrace = Dict()

function worker(self; steps=15, check_interrupt_every=Inf)
    @info "making $steps totals steps and checking for interrupt requests every $check_interrupt_every steps"
    try
        for i in 1:steps
            sleep(0.1)
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
