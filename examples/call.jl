using Visor

function server(task)
    for msg in task.inbox
        isshutdown(msg) && break
        put!(msg.inbox, msg.request * 2)
    end
    println("server done")
end

function requestor(task)
    request = 10
    response = call("server", request)
    println("server(",request,")=",response)
    shutdown()
end

supervise([process(server), process(requestor)])