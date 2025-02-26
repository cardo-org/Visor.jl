# Process

A `process` defines a supervised task.

Tipically a `process` listens for shutdown request and terminates following its workflow logic.

A `process` may decide to ignore a shutdown request: in this case the supervisor may force the termination of the task with a `Visor.ProcessInterrupt` exception after a user defined amount of time.

If a process returns or fails with an exception the supervisor applies a defined restart policy.

The full signatures of process methods are:

```julia
process(fn::Function;
        args::Tuple=(),
        namedargs::NamedTuple=(;),
        force_interrupt_after::Real=1.0,
        stop_waiting_after::Real=Inf,
        debounce_time::Real=NaN,
        trace_exception::Bool=false,
        thread::Bool=false,
        restart::Symbol=:transient)

process(name::String,
        fn::Function;
        args::Tuple=(),
        namedargs::NamedTuple=(;),
        force_interrupt_after::Real=1.0,
        stop_waiting_after::Real=Inf,
        debounce_time::Real=NaN,
        trace_exception::Bool=false,
        thread::Bool=false,
        restart::Symbol=:transient)
```

Where:

* `name`: a user defined process name. Used for getting process with `from_path` api. When `name` argument is missing the process name default to `string(fn)`;
* `fn`: the process function;
* `args`: a `Tuple` of function arguments; 
* `namedargs`: a `NamedTuple` of named function arguments;
* `force_interrupt_after`: the amount of time in seconds after which if a process does not terminate by itself it is forcibly interrupted.
* `stop_waiting_after`: the amount of time in seconds after which the supervisor stop waiting for the task if a task does not terminate because it "adsorbs" the `Visor.ProcessException` exception.
* `debounce_time`: wait time in seconds before restarting a process. Default to NaN (restart immediately);
* `trace_exception`: boolean flag for printing the error stacktrace when process exits by an exception.
* `thread`: boolean flag for threaded versus asynchronous task;
* `restart`: one of the symbols:
  * `:permanent` the function is always restarted;
  * `:transient` restarted in case of exit caused by an exception;
  * `:temporary` never restarted;
