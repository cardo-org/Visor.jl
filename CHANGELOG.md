# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.1] - 2025-03-22

### Changed

- Default to `Threads.@spawn` instead of `@async` for starting processes.

## [0.8.0] - 2025-02-26

- Added trace_exception option for showing the error stack trace when process exits by an exception.

- Remove terminated supervisor from processes's list of parent supervisor.

- Fixed demo example (#8)

## [0.7.4] - 2024-12-13

- Improved the logic of processes restart.

## [0.7.3] - 2024-11-17

- Added from_name() API method. It may be useful if the process name contains dots.

## [0.7.2] - 2024-10-15

- Event handler callback fro reporting process lifetime events revisited.

## [0.7.1] - 2024-07-26

- New api setname(process, new_name) for changing process id

## [0.7.0] - 2024-07-09

- MacOS support [#7](https://github.com/cardo-org/Visor.jl/pull/7)

## [0.6.1] - 2024-05-02

- If already active supervise() add processes instead of throwing an exception.  

## [0.6.0] - 2024-03-04

- Add 'one_terminate_all' supervisor strategy.

## [0.5.0] - 2024-02-29

- Fix `one_for_all` and `rest_for_all` strategies [#5](https://github.com/cardo-org/Visor.jl/issues/5)

## [0.4.0] - 2024-02-01

- Update supervisor status at process termination [#3](https://github.com/cardo-org/Visor.jl/issues/3)

## [0.3.0] - 2024-01-24

- Setup supervisors settings with `setsupervisor` and `setroot` functions.

- `procs()`: get the supervised processes as a nested ordered dict.

- Fixed @warn message in case of `ProcessFatal`.

- Add `hassupervised(name)` function.

- `from(path)` return `nothing` instead of throwing an exception if process identified by `path` is not found.  

## [0.2.0] - 2023-12-03

- Renamed functions:
  - is_shutdown=>isshutdown
  - is_request=>isrequest
  - if_restart=>ifrestart

- Add `handler` keyword arg to supervise. `handler` value is a callback function for handling process lifecycles events. Currently manages events are task exceptions and `ProcessFatal`.
  
- Removed `supervisor_shutdown` in case of a `ProcessFatal` exception. This implies that the other processes continue to run despite the process that thrown `ProcessFatal` will never restart.

- Log a warn message when starting a process task throws a MethodError exception.

- New function `isprocstarted`: check if process task is running.
  
- @isshutdown macro.

## [0.1.0] - 2023-11-13

- Initial release.
