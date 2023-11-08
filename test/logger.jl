using Dates
using Logging

struct PrjLogger <: AbstractLogger
    groups::Vector{Symbol}
    modules::Vector{Module}
end

function logging(;debug=[])
    groups = [item for item in debug if isa(item, Symbol)]
    modules = [item for item in debug if isa(item, Module)]
    PrjLogger(groups, modules) |> global_logger
end

function Logging.min_enabled_level(logger::PrjLogger) 
    Logging.Debug
end

function Logging.shouldlog(logger::PrjLogger, level, _module, group, id)
    level >= Logging.Info || group in logger.groups || _module in logger.modules
end

function Logging.handle_message(logger::PrjLogger, level, message, _module, group, id, file, line; kwargs...)
    println("[$(now())][$_module][$(Threads.threadid())][$level] $message")
end

