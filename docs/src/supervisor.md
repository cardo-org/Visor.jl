# Supervisor

A supervisor manages an ordered list of processes and supervisors child.

The duties of a supervisor are:

1. monitor the running status of its children and apply the restart policies in case of failures;
1. shutdown all the processes in an orderly and deterministic way;

A supervisor has a name and a list of supervised elements:

```julia
function foo(self::Supervised, n::Int=100)
    # ...
end

function bar(self::Supervised, name::String="")
    # ...
end

processes = [process(foo, args(10, )),
             process(bar, args("myname", ))]

supervisor("my_supervisor", processes)
```

## Supervisor options

```julia
supervisor(name::String, specs=Spec[];
           intensity=1,
           period=5,
           strategy=:one_for_one,
           restart=:transient)
```

It is possible to control the number of restarts of supervised tasks by the two options
`intensity` and `period`.

If a greater number of restarts than `intensity` value occur in a time frame set by `period`,
the supervisor terminates all the child tasks. 

The intention of the restart mechanism is to prevent a situation where a process repeatedly dies for the same reason, only to be restarted again.

If options `intensity` and `period` are not given, they default to 1 and 5, respectively.

```@repl
using Visor

function tsk1(task)
    sleep(1)
    error("[$(task.id)]: critical failure")
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

sv = supervisor("mysupervisor", [interruptable(tsk1), interruptable(tsk2)]);
forever([interruptable(main), sv]);
```

The `strategy` option defines the restart policy and it is one of:
* `:one_for_one`
* `:one_for_all`
* `:rest_for_one`

The design of the restart strategy follows Erlang behavoir, see [Erlang documentation](https://www.erlang.org/doc/design_principles/sup_princ.html#restart-strategy) for a comprehensive explanation.

Finally there can be two types of life span for supervisor: `:permanent` and `:transient`.

The `:transient` supervisor terminates when there are left no children to supervise, whereas the `:permanent`
supervisor may outlives its supervised children.