using Visor

function tsk1(task)
    sleep(1)
    return error("[$(task.id)]: critical failure")
end

function tsk2(task)
    while true
        println("[$(task.id)]: do something ...")
        sleep(0.5)
    end
end

function main(task)
    for i in 1:5
        println("[$(task.id)]: step $i")
        sleep(1.5)
    end
end

sv = supervisor("mysupervisor", [process(tsk1), process(tsk2)])
supervise([process(main), sv])