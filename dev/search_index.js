var documenterSearchIndex = {"docs":
[{"location":"messages/#Inter-Process-Communication","page":"Messages","title":"Inter Process Communication","text":"","category":"section"},{"location":"messages/","page":"Messages","title":"Messages","text":"The standard Channel mechanism is used to communicate between process tasks: the inbox channel.","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"In addition to put!(process.inbox, message) method to send messages to a process there is a cast function for sending a message (fire and forget message pattern) and  a call function for waiting for a response (request-response message pattern).","category":"page"},{"location":"messages/#cast","page":"Messages","title":"cast","text":"","category":"section"},{"location":"messages/","page":"Messages","title":"Messages","text":"cast(self::Supervised, target_id::String, message::Any)","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"cast sends a message to a task with name target_id and returns immediately.","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"using Visor\n\nfunction controller(self)\n    for msg in self.inbox\n        println(\"reservation info: $msg\")\n        if msg[\"available\"] == 0\n            println(\"all booked!\")\n            break\n        end\n    end\nend\n\nfunction box_office(self)\n    for avail in 50:-10:0\n        seats = Dict(\"tot\"=>50, \"available\"=>avail)\n        cast(self, \"controller\", seats)\n        sleep(1)\n    end\nend\n\nsupervise([process(controller), process(box_office)])","category":"page"},{"location":"messages/#call","page":"Messages","title":"call","text":"","category":"section"},{"location":"messages/","page":"Messages","title":"Messages","text":"call(self::Supervised, target_id::String, request::Any, timeout::Real=-1)","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"call sends a request to a task with name target_id and wait for a response for timeout seconds.","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"If timeout is equal to -1 then waits forever, otherwise if a response is not received in timeout seconds an ErrorException is raised.","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"The message sent to the target task is a Request struct that contains the request and a channel for sending back the response.","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"struct Request <: Message\n    inbox::Channel\n    request::Any\nend","category":"page"},{"location":"messages/","page":"Messages","title":"Messages","text":"using Visor\n\nfunction server(self)\n    for msg in self.inbox\n        isshutdown(msg) && break\n        put!(msg.inbox, msg.request*2)\n    end\nend\n\nfunction requestor(self)\n    request = 10\n    response = call(self, \"server\", request)\n    @info \"server($request)=$response\"\nend\n\nsupervise([process(server), process(requestor)]);","category":"page"},{"location":"stop_process/#How-to-stop-supervised-tasks","page":"Shutting down","title":"How to stop supervised tasks","text":"","category":"section"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"In Julia parlance a task is just a function that runs as a coroutine.","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"A task managed by Visor differs from a standard julia task because it is a function that requires as its first argument an handle representing the supervised task.","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"In the following examples the handle self it is not used to communicate with the task using the inbox channel but just to check if a shutdown request was delivered and in this case it stops the task.  ","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"The task fair_task is a Visor.process: it is a cooperative task that checks itself for a shutdown request and acts accordingly.","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"using Visor\n\nfunction fair_task(self)\n    while true\n        println(\"[$(self.id)] checkpoint ...\")\n        if isshutdown(self)\n            println(\"[$(self.id)] cleanup and resources deallocation\")\n            break\n        end\n        sleep(2)\n    end\n    return println(\"[$(self.id)] DONE\")\nend\n\nspec = [process(\"fair\", fair_task)]\nprintln(\"starting supervised tasks\")\nsvisor = supervise(spec; wait=false)\n\nsleep(3)\ntask = from(\"fair\")\n\nprintln(\"[$(task.id)] requesting shutdown ...\")\nshutdown(task)","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"starting supervised tasks\n[fair] checkpoint ...\n[fair] checkpoint ...\n[fair] requesting shutdown ...","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"The following is an example of a process that does not check for a shutdown request. In this case it is forcibly interrupted by the supervisor after a configurable amount of time.","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"function uncooperative_task(self)\n    try\n        while true\n            println(\"[$(self.id)] working ...\")\n            sleep(2)\n        end\n    catch e\n        println(\"[$(self.id)] interrupted by $e\")\n    finally\n        println(\"[$(self.id)] DONE\")\n    end\nend\n\nspec = [process(\"uncooperative\", uncooperative_task; force_interrupt_after=5)]\n\nprintln(\"starting supervised tasks\")\nsvisor = supervise(spec; wait=false)\n\nsleep(3)\ntask = from(\"uncooperative\")\n\nprintln(\"[$(task.id)] requesting (ignored) shutdown ...\")\nshutdown(task)","category":"page"},{"location":"stop_process/","page":"Shutting down","title":"Shutting down","text":"starting supervised tasks\nError: supervise already active\n::warning file=../../../.julia/packages/Weave/f7Ly3/src/run.jl,line=224::ER\nROR: ErrorException occurred, including output in Weaved document","category":"page"},{"location":"supervisor/#Supervisor","page":"Supervisor","title":"Supervisor","text":"","category":"section"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"A supervisor manages an ordered list of processes and supervisors child.","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"The duties of a supervisor are:","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"monitor the running status of its children and apply the restart policies in case of failures;\nshutdown all the processes in an orderly and deterministic way;","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"A supervisor has a name and a list of supervised elements:","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"function foo(self::Supervised, n::Int=100)\n    # ...\nend\n\nfunction bar(self::Supervised, name::String=\"\")\n    # ...\nend\n\nprocesses = [process(foo, args(10, )),\n             process(bar, args(\"myname\", ))]\n\nsupervisor(\"my_supervisor\", processes)","category":"page"},{"location":"supervisor/#Supervisor-options","page":"Supervisor","title":"Supervisor options","text":"","category":"section"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"supervisor(name::String, specs=Spec[];\n           intensity=1,\n           period=5,\n           strategy=:one_for_one,\n           restart=:transient)","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"It is possible to control the number of restarts of supervised tasks by the two options intensity and period.","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"If a greater number of restarts than intensity value occur in a time frame set by period, the supervisor terminates all the child tasks. ","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"The intention of the restart mechanism is to prevent a situation where a process repeatedly dies for the same reason, only to be restarted again.","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"If options intensity and period are not given, they default to 1 and 5, respectively.","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"using Visor\n\nfunction tsk1(task)\n    sleep(1)\n    error(\"[$(task.id)]: critical failure\")\nend\n\nfunction tsk2(task)\n    while true\n        println(\"[$(task.id)]: do something ...\")\n        sleep(0.5)\n    end\nend\n\nfunction main(task)\n    for i in 1:5\n        println(\"[$(task.id)]: step $i\")\n        sleep(1.5)\n    end\nend\n\nsv = supervisor(\"mysupervisor\", [interruptable(tsk1), interruptable(tsk2)]);\nforever([interruptable(main), sv]);","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"The strategy option defines the restart policy and it is one of:","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":":one_for_one\n:one_for_all\n:rest_for_one","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"The design of the restart strategy follows Erlang behavoir, see Erlang documentation for a comprehensive explanation.","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"Finally there can be two types of life span for supervisor: :permanent and :transient.","category":"page"},{"location":"supervisor/","page":"Supervisor","title":"Supervisor","text":"The :transient supervisor terminates when there are left no children to supervise, whereas the :permanent supervisor may outlives its supervised children.","category":"page"},{"location":"no_handler_available/#SIGINT:-no-exception-handler-available","page":"No exception handler available","title":"SIGINT: no exception handler available","text":"","category":"section"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"A standard way to terminate a process is using an OS signal.","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"With Julia we may capture a SIGINT signal, for example generated by a user pressing Ctrl-C, and try to shutdown in a controlled way the process.","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"But the fact that an InterruptException is delivered to one task chosen at discretion of the runtime task scheduler make it very difficult to design a robust application because each concurrent/parallel task have to catch and manage correctly the InterruptException in cooperation with all the other tasks.","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"Besides this there are pathological cases where it became impossible: in fact the InterruptException may be delivered to a terminated task and in this scenario nothing can be done to control the shutdown logic.","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"The following simple example shows the case when the interrupt is delivered to a terminated task. When this occurs a fatal error is raised:","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"   fatal: error thrown and no exception handler available.","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"demo.jl:","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"function task(_)\n    println(\"doing something\")\nend\n\nTimer(task, 1)\n\nfunction main()\n    try\n        while true\n            sleep(5)\n        end\n    catch e\n        println(\"got $e: clean shutdown ...\")\n    end\nend\n\nmain()","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"Running","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"julia -e 'include(pop!(ARGS))' demo.jl","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"and pressing Ctrl-C after the timer timed out but in 5 seconds you get:","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"doing something\n^Cfatal: error thrown and no exception handler available.\nInterruptException()\n_jl_mutex_unlock at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/threading.c:798\njl_mutex_unlock at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/julia_locks.h:81 [inlined]\nijl_task_get_next at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/partr.c:394\npoptask at ./task.jl:963\nwait at ./task.jl:972\ntask_done_hook at ./task.jl:672\njfptr_task_done_hook_31470.clone_1 at /home/adona/.asdf/installs/julia/1.9.0-rc1/lib/julia/sys.so (unknown line)\n_jl_invoke at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/gf.c:2731 [inlined]\nijl_apply_generic at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/gf.c:2913\njl_apply at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/julia.h:1878 [inlined]\njl_finish_task at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/task.c:320\nstart_task at /cache/build/default-amdci5-5/julialang/julia-release-1-dot-9/src/task.c:1103","category":"page"},{"location":"no_handler_available/#The-Visor-way","page":"No exception handler available","title":"The Visor way","text":"","category":"section"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"Visor capture SIGINT and shutdown in a reliable way all supervised task following the shutdown logic configured by the application.","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"The above example instrumented with Visor becames:","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"using Visor\n\nfunction task(_)\n    println(\"doing something\")\nend\n\nTimer(task, 1)\n\nfunction main(self)\n    try\n        while true\n            sleep(5)\n        end\n    catch e\n        println(\"got $e: clean shutdown ...\")\n    end\nend\n\nsupervise([process(main)]);","category":"page"},{"location":"no_handler_available/","page":"No exception handler available","title":"No exception handler available","text":"doing something\n^Cgot Visor.ProcessInterrupt(\"main\"): clean shutdown ...","category":"page"},{"location":"#Visor","page":"Home","title":"Visor","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = Visor","category":"page"},{"location":"","page":"Home","title":"Home","text":"Visor is a tasks supervisor that provides a set of policies to control the logic for the shutdown and restart of tasks.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The scope of Visor is to provide support for reliable, long-running and fault tolerant applications written in Julia.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Visor is influenced by Erlang Supervisor design principles with the aim to fit as \"naturally\" as possible into the Julia task system.","category":"page"},{"location":"#Getting-Started","page":"Home","title":"Getting Started","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"using Pkg; \nPkg.add(\"Visor\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"# demo.jl:\n\nusing Visor\n\nstruct AppData\n    count::Int\nend\n\n# Task implementation, the first argument is a task descriptor\nfunction level_1_task(td)\n    @info \"starting $td\"\n    for msg in td.inbox\n        if isshutdown(msg)\n            break\n        elseif isa(msg, AppData)\n            @info \"$td recv: $msg\"\n        end\n    end\n    @info \"shutting down $td\"\nend\n\nfunction level_2_task(td)\n    @info \"starting $td\"\n    n = 0\n    while true\n        sleep(0.5)\n        if isshutdown(td)\n            break\n        end\n        # send a data message to process named level_1_task\n        cast(td, \"level_1_task\", AppData(n))\n        n += 1\n    end\n    @info \"shutting down $td\"\nend\n\nsupervise([process(level_1_task), process(level_2_task)])","category":"page"},{"location":"","page":"Home","title":"Home","text":"On Linux machines Visor caputures SIGINT signal and terminate the application tasks in the reverse order of startup:","category":"page"},{"location":"","page":"Home","title":"Home","text":"$ julia demo.jl\n\n[ Info: starting level_1_task\n[ Info: starting level_2_task\n[ Info: level_1_task recv: AppData(0)\n[ Info: level_1_task recv: AppData(1)\n[ Info: level_1_task recv: AppData(2)\n^C[ Info: shutting down level_2_task\n[ Info: shutting down level_1_task\n","category":"page"},{"location":"","page":"Home","title":"Home","text":"A Process is a supervised task that is started/stopped in a deterministic way and that may be restarted in case of failure.","category":"page"},{"location":"","page":"Home","title":"Home","text":"A process task function has a mandatory first argument that is a task descriptor td value that:","category":"page"},{"location":"","page":"Home","title":"Home","text":"check if a shutdown request is pending with isshutdown;\nreceive messages from the inbox Channel;","category":"page"},{"location":"","page":"Home","title":"Home","text":"function level_2_task(td)\n    while true\n        # do something ...\n        if isshutdown(td)\n            break\n        end\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"If the task function is designed to receive messages the argument of isshutdown MUST BE the message and not the task object:","category":"page"},{"location":"","page":"Home","title":"Home","text":"function level_1_task(td)\n    for msg in td.inbox\n        # check if it is a shutdown request \n        if isshutdown(msg)\n            break\n        elseif isa(msg, AppMessage)\n            # do something with the application message\n            # that some task sent to level_1_task.\n            do_something(msg)\n        end\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"supervise manages processes and supervisors until all of them terminates or a shutdown is requested.","category":"page"},{"location":"","page":"Home","title":"Home","text":"processes = [process(level_1_task), process(level_2_task)]\nsupervise(processes)","category":"page"},{"location":"","page":"Home","title":"Home","text":"supervise applied to a supervisor is an example of a hierachical supervision tree:","category":"page"},{"location":"","page":"Home","title":"Home","text":"sv = supervisor(\"bucket\", [process(foo), process(bar)])\nsupervise(sv)","category":"page"},{"location":"","page":"Home","title":"Home","text":"In this case the supervisor \"bucket\" manages the tasks foo and bar, whereas in the previous example level_1_task and level_2_task are managed by the root supervisor.","category":"page"},{"location":"","page":"Home","title":"Home","text":"see Supervisor documentation for more details.","category":"page"},{"location":"#Restart-policy-example","page":"Home","title":"Restart policy example","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The following example show the restart on failure scenario: a task failure is simulated with an error exception that terminates the consumer.","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Visor\n\n# Consumer process task: read messages from process inbox and print to stdout.\n# The first mandatory argument process is the task descriptor object.\n# With the task descriptor it is possible to receive any type of messages, for example\n# shutdown requests, and send messages to other processes via call and cast methods.\nfunction consumer(td)\n\n    while true\n        # Fetch data or control messages, \n        # for example a request to shutdown the task.\n        msg = take!(td.inbox)\n\n        # Check if msg is the shutdown control message ...\n        !isshutdown(msg) || break\n\n        println(msg)\n        if msg == 5\n            error(\"fatal error simulation\")\n        end\n\n    end\nend\n\n# Producer task.\n# In this case the shutdown request is not captured by checking the inbox messages but checking\n# the task descriptor.\nfunction producer(td)\n    count = 1\n    while true\n        sleep(1)\n\n        # send count value to consumer task\n        cast(\"consumer\", count)\n\n        # check if was requested a shutdown (for example by SIGINT signal)\n        !isshutdown(td) || break\n\n        count += 1\n    end\nend\n\n# Tasks are started following the list order and are shutted down in reverse order:\n# producer is started last and terminated first.\ntasks = [\n    process(consumer)\n    process(producer, thread=true)\n]\n\n# Supervises the tasks and apply restart policies in case of process failure.\n# In this case it allows a maximum of 2 process restart in 1 second time window.\n# In case the fail rate is above this limit the processes are terminated and the supervisor returns.\nsupervise(tasks, intensity=2, period=1);","category":"page"},{"location":"","page":"Home","title":"Home","text":"The producer process sends a number every seconds to the consumer process that get it from the inbox channel and print to stdout.","category":"page"},{"location":"","page":"Home","title":"Home","text":"When the number equals to 5 then an exception is raised, the task fails and the supervisor restarts the consumer process:","category":"page"},{"location":"","page":"Home","title":"Home","text":"$ julia producer_consumer.jl \n1\n2\n3\n4\n5\n┌ Error: [consumer] exception: ErrorException(\"fatal error simulation\")\n└ @ Visor ~/dev/Visor/src/Visor.jl:593\n6\n7\n^C8\n9","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [Visor]","category":"page"},{"location":"#Visor.Request","page":"Home","title":"Visor.Request","text":"A response value is expected when a Request message is pushed to the target process inbox.\n\n\n\n\n\n","category":"type"},{"location":"#Visor.call-Tuple{String, Any}","page":"Home","title":"Visor.call","text":"call(name::String, request::Any; timeout::Real=3)\n\nSend a request to the process identified by full name and wait for a response.\n\nIf timeout is equal to -1 then waits forever, otherwise if a response is not received in timeout seconds an ErrorException is raised. \n\nThe message sent to the target task is a Request struct that contains the request and a channel for sending back the response.\n\nusing Visor\n\nfunction server(task)\n    for msg in task.inbox\n        isshutdown(msg) && break\n        put!(msg.inbox, msg.request * 2)\n    end\n    println(\"server done\")\nend\n\nfunction requestor(task)\n    request = 10\n    response = call(\"server\", request)\n    println(\"server(\",request,\")=\",response)\n    shutdown()\nend\n\nsupervise([process(server), process(requestor)])\n\n\n\n\n\n","category":"method"},{"location":"#Visor.call-Tuple{Visor.Supervised, Any}","page":"Home","title":"Visor.call","text":"call(target::Supervised, request::Any; timeout::Real=-1)\n\nSend a request to target process and wait for a response.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.cast-Tuple{Any, Any}","page":"Home","title":"Visor.cast","text":"cast(name::String, message::Any)\n\nSend a message to process with full name without waiting for a response.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.cast-Tuple{Visor.Supervised, Any}","page":"Home","title":"Visor.cast","text":"cast(process::Supervised, message)\n\nThe message value is sent to target process without waiting for a response.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.from-Tuple{String}","page":"Home","title":"Visor.from","text":"from(name::String)::Supervised\n\nReturn the supervised node identified by full name.\n\nGiven for example the process mytask supervised by mysupervisor:\n\nsupervisor(\"mysupervisor\", [process(mytask)])\n\nthen the full name of mytask process is mysupervisor.mytask.              \n\n\n\n\n\n","category":"method"},{"location":"#Visor.hassupervised-Tuple{String}","page":"Home","title":"Visor.hassupervised","text":"hassupervised(name::String)\n\nDetermine whether the supervised identified by name exists.    \n\n\n\n\n\n","category":"method"},{"location":"#Visor.ifrestart-Tuple{Function, Visor.Process}","page":"Home","title":"Visor.ifrestart","text":"ifrestart(fn, process)\n\nCall the no-argument function fn if the process restarted.\n\nThe function fn is not executed at the first start of process.    \n\n\n\n\n\n","category":"method"},{"location":"#Visor.isrequest-Tuple{Any}","page":"Home","title":"Visor.isrequest","text":"isrequest(message)\n\nReturn true if message is a Request.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.isshutdown-Tuple{Any}","page":"Home","title":"Visor.isshutdown","text":"isshutdown(msg)\n\nReturns true if message msg is a shutdown command. \n\n\n\n\n\n","category":"method"},{"location":"#Visor.isshutdown-Tuple{Visor.Supervised}","page":"Home","title":"Visor.isshutdown","text":"function isshutdown(process::Supervised)\n\nReturns true if process has a shutdown command in its inbox.\n\nAs a side effect remove messages from process inbox until a shutdown request is found.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.process-Tuple{Any, Function}","page":"Home","title":"Visor.process","text":"process(id, fn;\n        args=(),\n        namedargs=(;),\n        force_interrupt_after::Real=0,\n        stop_waiting_after::Real=Inf,\n        debounce_time=NaN,\n        thread=false,\n        restart=:transient)::ProcessSpec\n\nDeclare a supervised task that may be forcibly interrupted.\n\nid is the process name and fn is the task function.\n\nprocess returns only a specification: the task function has to be started with supervise.\n\nSee process online docs for more details.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.process-Tuple{Function}","page":"Home","title":"Visor.process","text":"process(fn;\n        args=(),\n        namedargs=(;),\n        force_interrupt_after::Real=1.0,\n        stop_waiting_after::Real=Inf,\n        debounce_time=NaN,\n        thread=false,\n        restart=:transient)::ProcessSpec\n\nThe process name is set equals to string(fn).\n\n\n\n\n\n","category":"method"},{"location":"#Visor.receive-Tuple{Function, Visor.Process}","page":"Home","title":"Visor.receive","text":"function receive(fn::Function, pd::Process)\n\nExecute fn(msg) for every message msg delivered to the pd Process.\n\nReturn if a Shutdown control message is received.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.reply-Tuple{Visor.Request, Any}","page":"Home","title":"Visor.reply","text":"reply(request::Request, response::Any)\n\nSend the response to the call method that issued the request.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.shutdown","page":"Home","title":"Visor.shutdown","text":"shutdown(node)\n\nTry to shutdown a process or a supervisor. \n\nIf node is a supervisor it first attempts to shutdown all children nodes and then it stop the supervisor. If some process refuse to shutdown the node supervisor is not stopped.\n\n\n\n\n\n","category":"function"},{"location":"#Visor.shutdown-Tuple{}","page":"Home","title":"Visor.shutdown","text":"shutdown()\n\nShutdown all supervised nodes.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.startup-Tuple{Visor.Supervised}","page":"Home","title":"Visor.startup","text":"startup(proc::Supervised)\n\nStart the supervised process defined by proc as children of the root supervisor.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.startup-Tuple{Visor.Supervisor, Visor.Supervised}","page":"Home","title":"Visor.startup","text":"startup(supervisor::Supervisor, proc::Supervised)\n\nStart the supervised process defined by proc as child of supervisor.\n\njulia> using Visor\n\njulia> foo(self) = println(\"foo process started\");\n\njulia> main(self) = startup(self.supervisor, process(foo));\n\njulia> supervise([process(main)]);\nfoo process started\n\n\n\n\n\n","category":"method"},{"location":"#Visor.supervise-Tuple{Vector{<:Visor.Supervised}}","page":"Home","title":"Visor.supervise","text":"supervise(processes::Vector{<:Supervised};\n          intensity::Int=1,\n          period::Int=5,\n          strategy::Symbol=:one_for_one,\n          terminateif::Symbol=:empty,\n          handler::Union{Nothing, Function}=nothing,\n          wait::Bool=true)::Supervisor\n\nThe root supervisor start a family of supervised processes.\n\nReturn the root supervisor or wait for supervisor termination if wait is true. \n\nArguments\n\nintensity::Int: maximum number of restarts allowed in period seconds.\nperiod::Int: time interval that controls the restart intensity.\nstrategy::Symbol: defines the restart strategy:\n:one_for_one: only the terminated task is restarted.\n:one_for_all: if a child task terminates, all other child tasks are terminated, and then all child,                 including the terminated one, are restarted.\n:rest_for_one: if a child task terminates, the rest of the child tasks (that is, the child tasks                   after the terminated process in start order) are terminated. Then the terminated                  child task and the rest of the child tasks are restarted.\nterminateif::Symbol:\n:empty: terminate the supervisor when all child tasks terminate.\n:shutdown: the supervisor terminate at shutdown.\nhandler: a callback function with prototype fn(process, event) invoked when process events occurs:\n\nwhen process tasks throws exception and when a process terminate because of a ProcessFatal reason.\n\nwait::Bool: wait for supervised nodes termination.\n\n    children = [process(worker, args=(15,\"myid\"))]\n    supervise(children)\n\n\n\n\n\n","category":"method"},{"location":"#Visor.supervise-Tuple{Visor.Supervised}","page":"Home","title":"Visor.supervise","text":"supervise(proc::Supervised;\n          intensity::Int=1,\n          period::Int=5,\n          strategy::Symbol=:one_for_one,\n          terminateif::Symbol=:empty,\n          handler::Union{Nothing, Function}=nothing,\n          wait::Bool=true)::Supervisor\n\nThe root supervisor start a supervised process defined by proc.\n\n\n\n\n\n","category":"method"},{"location":"#Visor.supervisor","page":"Home","title":"Visor.supervisor","text":"supervisor(id, processes; intensity=1, period=5, strategy=:one_for_one, terminateif=:empty)::SupervisorSpec\n\nDeclare a supervisor of one or more processes.\n\nprocesses may be a Process or an array of Process.\n\njulia> using Visor\n\njulia> mytask(pd) = ();\n\njulia> supervisor(\"mysupervisor\", process(mytask))\nmysupervisor\n\n```jldoctest julia> using Visor\n\njulia> tsk1(pd) = ();\n\njulia> tsk2(pd) = ();\n\njulia> supervisor(\"mysupervisor\", [process(tsk1), process(tsk2)]) mysupervisor\n\nSee Supervisor documentation for more details.\n\n\n\n\n\n","category":"function"},{"location":"#Visor.@isshutdown-Tuple{Any}","page":"Home","title":"Visor.@isshutdown","text":"@isshutdown process_descriptor\n@isshutdown msg\n\nBreak the loop if a shutdown control message is received.\n\n\n\n\n\n","category":"macro"},{"location":"process/#Process","page":"Process","title":"Process","text":"","category":"section"},{"location":"process/","page":"Process","title":"Process","text":"A process defines a supervised task.","category":"page"},{"location":"process/","page":"Process","title":"Process","text":"Tipically a process listens for shutdown request and terminates following its workflow logic.","category":"page"},{"location":"process/","page":"Process","title":"Process","text":"A process may decide to ignore a shutdown request: in this case the supervisor may force the termination of the task with a Visor.ProcessInterrupt exception after a user defined amount of time.","category":"page"},{"location":"process/","page":"Process","title":"Process","text":"If a process returns or fails with an exception the supervisor applies a defined restart policy.","category":"page"},{"location":"process/","page":"Process","title":"Process","text":"The full signatures of process methods are:","category":"page"},{"location":"process/","page":"Process","title":"Process","text":"process(fn::Function;\n        args::Tuple=(),\n        namedargs::NamedTuple=(;),\n        force_interrupt_after::Real=1.0,\n        stop_waiting_after::Real=Inf,\n        debounce_time::Real=NaN,\n        thread::Bool=false,\n        restart::Symbol=:transient)\n\nprocess(name::String,\n        fn::Function;\n        args::Tuple=(),\n        namedargs::NamedTuple=(;),\n        force_interrupt_after::Real=1.0,\n        stop_waiting_after::Real=Inf,\n        debounce_time::Real=NaN,\n        thread::Bool=false,\n        restart::Symbol=:transient)","category":"page"},{"location":"process/","page":"Process","title":"Process","text":"Where:","category":"page"},{"location":"process/","page":"Process","title":"Process","text":"name: a user defined process name. Used for getting process with from_path api. When name argument is missing the process name default to string(fn);\nfn: the process function;\nargs: a Tuple of function arguments; \nnamedargs: a NamedTuple of named function arguments;\nforce_interrupt_after: the amount of time in seconds after which if a process does not terminate by itself it is forcibly interrupted.\nstop_waiting_after: the amount of time in seconds after which the supervisor stop waiting for the task if a task does not terminate because it \"adsorbs\" the Visor.ProcessException exception.\ndebounce_time: wait time in seconds before restarting a process. Default to NaN (restart immediately);\nthread: boolean flag for threaded versus asynchronous task;\nrestart: one of the symbols:\n:permanent the function is always restarted;\n:transient restarted in case of exit caused by an exception;\n:temporary never restarted;","category":"page"}]
}
