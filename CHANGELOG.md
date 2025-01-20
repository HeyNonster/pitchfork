# Unreleased

- Add `setpgid` configuration option. When `false`, child processes are not reassigned to their own process group.
  Necessary for initiating a debugging session in a child process (#148).
- Assume config file is located at `config/pitchfork.rb` if `-c` argument isn't provided.

# 0.16.0

- Use `exit!` for exiting the middle process when forking a new worker or mold. 
  This skips `at_exit` and finalizer hooks, which shouldn't be needed.

# 0.15.0

- Encode pure ASCII strings in Rack env as UTF-8, as allowed by the rack spec.
  Other strings remain as ASCII-8BIT aka BINARY as required by the rack spec.
- Fix compatibility with Rack 3.1.
- Fix `rack.hijack` support.
- Support Rack 3 streaming bodies.
- Implement listen queues for fairer load balancing (optional).
- Assume C99 compatible compiler.
- Declare dependency on `logger` for Ruby 3.5 compatibility.

# 0.14.0

- Remove the dependency on `raindrops`.
- Add `X-Request-Id` header in the workers proctitle if present.
- Added experimental service workers.

# 0.13.0

- Fix compatibility with `--enable-frozen-string-literal` in preparation for Ruby 3.4.
- Extend timed out workers deadline after sending signals to avoid flooding.
- Fix compilation with Ruby 2.7 and older on macOS.

# 0.12.0

- Disable IO tracking on Rubies older than 3.2.3 to avoid running into https://bugs.ruby-lang.org/issues/19531.
  This Ruby bug can lead to memory corruption that cause VM crashes when calling various IO methods.
- Implement `rack.response_finished` (#97).
- Don't break the `rack.after_reply` callback chain if one callback raises (#97).

# 0.11.1

- Fix Ruby 3.4-dev compatibility.

# 0.11.0

- Drop invalid response headers.
- Enforce `spawn_timeout` for molds too.
- Gracefully shutdown the server if the mold appear to be corrupted (#79).
- Add more information in proctitle when forking a new sibbling.
- Add a `before_fork` callback called before forking new molds and new workers.

# 0.10.0

- Include requests count in workers proctitle.

# 0.9.0

- Implement `spawn_timeout` to protect against bugs causing workers to get stuck before they reach ready state.

# 0.8.0

- Add an `after_monitor_ready` callback, called in the monitor process at end of boot.
- Implement `Pitchfork.prevent_fork` for use in background threads that synchronize native locks with the GVL released.

# 0.7.0

- Set nicer `proctile` to better see the state of the process tree at a glance.
- Pass the last request env to `after_request_complete` callback.
- Fix the slow rollout of workers on a new generation.
- Expose `Pitchfork::Info.fork_safe?` and `Pitchfork::Info.no_longer_fork_safe!`.

# 0.6.0

- Expose `Pitchfork::Info.workers_count` and `.live_workers_count` to be consumed by application health checks.
- Implement `before_worker_exit` callback.
- Make each mold and worker a process group leader.
- Get rid of `Pitchfork::PrereadInput`.
- Add `Pitchfork.shutting_down?` to allow health check endpoints to fail sooner on graceful shutdowns.
- Treat `TERM` as graceful shutdown rather than quick shutdown.
- Implement `after_worker_hard_timeout` callback.

# 0.5.0

- Added a soft timeout in addition to the historical Unicorn hard timeout.
  On soft timeout, the `after_worker_timeout` callback is invoked.
- Implement `after_request_complete` callback.

# 0.4.1

- Avoid a Rack 3 deprecation warning.
- Fix handling on non-ASCII cookies.
- Log unknown process being reaped at INFO level.

# 0.4.0

- Preserve the current thread when reforking.

# 0.3.0

- Renamed `after_promotion` in `after_mold_fork`.
- Renamed `after_fork` in `after_worker_fork`.
- Backoff 10s after every mold spawning attempt.
- Spawn mold from workers instead of promoting workers (#42).

# 0.2.0

- Remove default middlewares.
- Refork indefinitely when `refork_after` is set, unless the last element is `false`.
- Remove `mold_selector`. The promotion logic has been moved inside workers (#38).
- Add the `after_promotion` callback.
- Removed the `before_fork` callback.
- Fork workers and molds with a clean stack to allow more generations. (#30)

# 0.1.2

- Improve Ruby 3.2 and Rack 3 compatibility.

# 0.1.1

- Fix `extconf.rb` to move the extension in the right place on gem install. (#18)

# 0.1.0

Initial release