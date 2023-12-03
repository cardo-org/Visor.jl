using Visor
using Sockets

# Require a tcp server accepting connection on port 8800, for example:
# 
#   socat TCP-LISTEN:8800,reuseaddr,pf=ip4,fork -
#

function receiver(sock)
    while isopen(sock)
        data = read(sock)
        if isempty(data)
            break
        end
    end
    return close(sock)
end

# publisher process: read messages from process inbox and send them via tcp socket.
function publisher(self)
    sock = connect(8800)

    @async receiver(sock)

    while true
        # Fetch data or command messages, 
        # for example a request to shutdown the task.
        msg = fetch(self.inbox)

        # Check if msg is the shutdown control message ...
        !isshutdown(msg) || break

        # otherwise send the data
        if isopen(sock)
            write(sock, "$msg\n")
            take!(self.inbox)
        else
            error("connection lost")
        end
    end
end

function producer(self)
    count = 1
    while true
        sleep(1)
        cast("publisher", count)

        # check if was requested a shutdown (for example by SIGINT signal)
        !isshutdown(self) || break

        count += 1
    end
end

# Tasks are started following the list order and are shutted down in reverse order:
# producer is started last and terminated first.
tasks = [
    process(publisher; debounce_time=1)
    process(producer; thread=true)
]

# Supervise the tasks and apply restart policies in case of process failure.
# In this case it allows a maximum of 2 process restart in 1 second time window.
# In case the fail rate is above this limit the processes are terminated and the supervisor returns.
supervise(tasks; intensity=2, period=1)