using Visor

struct CounterMsg
    count::Int
end

struct ControllerMsg
    query::String
end

function db_service(td)
    @info "[$td] starting"
    try
        for msg in td.inbox
            if is_shutdown(msg)
                break
            elseif isa(msg, CounterMsg)
                @info "[$td] got message: $msg"
            elseif is_request(msg)
                if isa(msg.request, ControllerMsg)
                    reply(msg, :on)
                end
            end
        end
    catch e
        @error e
    end
    @info "[$td] shutting down"
end

function app_counter(td)
    @info "[$td] starting"
    n = 0
    while true
        sleep(2)
        if is_shutdown(td)
            break
        end
        # send a data message to process named db_service
        cast("db_service", CounterMsg(n))
        n += 1
    end
    @info "[$td] shutting down"
end

function app_controller(td)
    @info "[$td] starting"
    while true
        sleep(2)
        if is_shutdown(td)
            break
        end
        response = call("db_service", ControllerMsg("select status from ..."))
        @info "[$td] current status: $response"
    end
    @info "[$td] shutting down"
end

supervise([
    process(db_service; force_interrupt_after=Inf),
    process(app_counter; force_interrupt_after=Inf),
    process(app_controller; force_interrupt_after=Inf),
]);