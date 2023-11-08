using Visor

#ENV["JULIA_DEBUG"] = Visor

function printer(pd, device)
    println("(re)starting printer driver")
    receive(pd) do msg
        device.jobcount += 1
        print("processing $msg ... ")
        if device.jobcount === 3
            error("printer service panick error: $msg not printed")
        end
        println("done")
    end
end

function controller(pd)
    printer_process = from("printer")
    for i in 1:8
        cast(printer_process, "job-$i")
    end
end

# needed for simulating a printer failure
mutable struct PrinterStatus
    jobcount::Int
end

supervise([process(printer; args=(PrinterStatus(0),)), process(controller)])