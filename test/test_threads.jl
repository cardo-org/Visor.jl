include("utils.jl")

NUMTASK = 100000

run_count = 0

lk = ReentrantLock()

function tsk(td)
    global run_count
    lock(lk) do
        run_count += 1
    end
end

function main(td)
    Threads.@threads for i in 1:NUMTASK
        main_supervisor = from("main")
        startup(main_supervisor, process(tsk, thread=true))
    end
end

function run()
    supervise([supervisor("main", [process(main)])]) 
end

run()
@test run_count === NUMTASK