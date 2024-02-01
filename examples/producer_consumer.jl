using Visor

# Consumer process task: read messages from process inbox and print to stdout.
# The first mandatory argument self is the process object.
# With the process object it is possible to receive any type messages, for example
# shutdown requests, and send messages to other processes via call and cast methods.
function consumer(self)
    while true
        # Fetch data or control messages, 
        # for example a request to shutdown the task.
        msg = take!(self.inbox)

        # Check if msg is the shutdown control message ...
        !isshutdown(msg) || break

        println(msg)
        if msg == 5
            error("fatal error simulation")
        end
    end
end

# Producer task.
# In this case the shutdown request is not captured by checking the inbox messages but checking
# the process object.
function producer(self)
    count = 1
    while true
        sleep(1)

        # send a message to consumer task 
        cast("consumer", count)

        # check if was requested a shutdown (for example by SIGINT signal)
        !isshutdown(self) || break

        count += 1
    end
end

# Tasks are started following the list order and are shut down in reverse order:
# producer is started last and terminated first.
tasks = [
    process(consumer)
    process(producer; thread=true)
]

# Supervises the tasks and apply restart policies in case of process failure.
# In this case it allows a maximum of 2 process restart in 1 second time window.
# In case the fail rate is above this limit the processes are terminated and the supervisor returns.
supervise(tasks; intensity=2, period=1)