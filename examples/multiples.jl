using Visor

"""

The only requirement for a task driven by Visor is that the first argument is
    an object representing the supervised process. 
"""
function worker(self; steps=15, check_interrupt_every=Inf)
    @info "making $steps steps and checking for interrupt requests every $check_interrupt_every steps"
    try
        for i in 1:steps
            @info "[$(self.id)]: doing $i ..."
            sleep(0.5)
            if i % check_interrupt_every == 0
                @info "[$(self.id)]: checkpoint for shutdown request"
                if Visor.isshutdown(self)
                    return nothing
                end
            end
        end
    catch e
        @error "worker: $e"
        rethrow()
    end
    @info "bye bye"
end

supervise(
    [
        supervisor(
            "space1",
            [
                process(
                    "myworker1",
                    worker;
                    namedargs=(steps=15, check_interrupt_every=3),
                    force_interrupt_after=5,
                ),
            ],
        )
        supervisor(
            "space2",
            [
                process(
                    "myworker2",
                    worker;
                    namedargs=(steps=10, check_interrupt_every=5),
                    force_interrupt_after=5,
                ),
            ],
        )
    ],
)
