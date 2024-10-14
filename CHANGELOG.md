# Change Log

## 0.7.2 (15 October, 2024)

- Event handler callback fro reporting process lifetime events revisited.

## 0.7.1 (26 July, 2024)

- New api setname(process, new_name) for changing process id

## 0.7.0 (9 July, 2024)

- MacOS support [#7](https://github.com/cardo-org/Visor.jl/pull/7)

## 0.6.1 (2 May, 2024)

- If already active supervise() add processes instead of throwing an exception.  

## 0.6.0 (4 March, 2024)

- Add 'one_terminate_all' supervisor strategy.

## 0.5.0 (29 February, 2024)

- Fix `one_for_all` and `rest_for_all` strategies [#5](https://github.com/cardo-org/Visor.jl/issues/5)

## 0.4.0 (1 February, 2024)

- Update supervisor status at process termination [#3](https://github.com/cardo-org/Visor.jl/issues/3)

## 0.3.0 (24 January, 2024)

- Setup supervisors settings with `setsupervisor` and `setroot` functions.

- `procs()`: get the supervised processes as a nested ordered dict.

- Fixed @warn message in case of `ProcessFatal`.

- Add `hassupervised(name)` function.

- `from(path)` return `nothing` instead of throwing an exception if process identified by `path` is not found.  

## 0.2.0 (3 December, 2023)

- Renamed functions:
  - is_shutdown=>isshutdown
  - is_request=>isrequest
  - if_restart=>ifrestart

- Add `handler` keyword arg to supervise. `handler` value is a callback function for handling process lifecycles events. Currently manages events are task exceptions and `ProcessFatal`.
  
- Removed `supervisor_shutdown` in case of a `ProcessFatal` exception. This implies that the other processes continue to run despite the process that thrown `ProcessFatal` will never restart.

- Log a warn message when starting a process task throws a MethodError exception.

- New function `isprocstarted`: check if process task is running.
  
- @isshutdown macro.

## 0.1.0 (November 13, 2023)

- Initial release.
