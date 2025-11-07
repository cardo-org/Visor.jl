using Visor
using SafeTestsets
using Test

const GROUP = get(ENV, "GROUP", "all")

@testset "Visor.jl" begin
    if GROUP == "all" || GROUP == "unit"
        @time @safetestset "process" begin
            include("test_process.jl")
        end
        @time @safetestset "receive" begin
            include("test_receive.jl")
        end
        @time @safetestset "startchain" begin
            include("test_startchain.jl")
        end
        @time @safetestset "setname" begin
            include("test_setname.jl")
        end
        @time @safetestset "phase" begin
            include("test_phase.jl")
        end
        @time @safetestset "one_terminate_all" begin
            include("test_one_terminate_all.jl")
        end
        @time @safetestset "supervise" begin
            include("test_supervise.jl")
        end
        @time @safetestset "supervisor" begin
            include("test_supervisor.jl")
        end
        @time @safetestset "errors" begin
            include("test_errors.jl")
        end
        @time @safetestset "request" begin
            include("test_request.jl")
        end
        @time @safetestset "dynamic_process" begin
            include("test_dynamic.jl")
        end
        @time @safetestset "hierarchy" begin
            include("test_hierarchy.jl")
        end
        @time @safetestset "restart" begin
            include("test_restart.jl")
        end
        @time @safetestset "restart_all" begin
            include("test_restart_all.jl")
        end
        @time @safetestset "chain_restart" begin
            include("test_chain_restart.jl")
        end
        @time @safetestset "one_for_all_terminate" begin
            include("test_one_for_all_terminate.jl")
        end
        @time @safetestset "one_for_all" begin
            include("test_one_for_all.jl")
        end
        @time @safetestset "rest_for_one_terminate" begin
            include("test_rest_for_one_terminate.jl")
        end
        @time @safetestset "rest_for_one" begin
            include("test_rest_for_one.jl")
        end
        @time @safetestset "shutdown_order" begin
            include("test_shutdown_order.jl")
        end
        @time @safetestset "permanent_supervisor" begin
            include("test_permanent_supervisor.jl")
        end
        @time @safetestset "combo" begin
            include("test_combo.jl")
        end
    end
    if GROUP == "all" || GROUP == "shutdown"
        @time @safetestset "shutdown" begin
            include("test_shutdown.jl")
        end
        @time @safetestset "ignore_processinterrupt" begin
            include("test_ignore_processinterrupt.jl")
        end
        @time @safetestset "isshutdown" begin
            include("test_isshutdown.jl")
        end
        @time @safetestset "restart_honore_shutdown" begin
            include("test_restart_honore_shutdown.jl")
        end
    end
    if GROUP == "all" || GROUP == "handler"
        @time @safetestset "event_handler" begin
            include("test_event_handler.jl")
        end
    end
    if GROUP == "all" || GROUP == "concurrent"
        @time @safetestset "concurrent_add" begin
            include("test_concurrent_add.jl")
        end
        @time @safetestset "concurrent_shutdown" begin
            include("test_concurrent_shutdown.jl")
        end
    end
end

@info "expected tests: 76"
