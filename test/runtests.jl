using Visor
using SafeTestsets
using Test

include("logger.jl")

DEBUG = get(ENV, "DEBUG", "0")
logging(; debug=DEBUG == "0" ? [] : [Visor])

@testset "Visor.jl" begin
    @time @safetestset "process" begin
        include("test_process.jl")
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
    @time @safetestset "one_for_all" begin
        include("test_one_for_all.jl")
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
    @time @safetestset "antipattern" begin
        include("test_antipattern.jl")
    end
end
