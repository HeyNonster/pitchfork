# Fork Safety

Because `pitchfork` is a preforking server, your application code and libraries
must be fork safe.

Generally, code might be fork-unsafe for one of two reasons.

## Inherited Connection

When a process is forked, any open file descriptors (sockets, files, pipes, etc)
end up shared between the parent and child process. This is never what you
want, so any code keeping persistent connections should close them either
before or after the fork happens.

Most modern Ruby libraries automatically handle this, it's the case of
Active Record, redis-rb, dalli, net-http-persistent, etc.

However, for libraries that aren't automatically fork-safe
`pitchfork` provide two callbacks in its configuration file to manually
reopen connections and restart threads:

```ruby
# pitchfork.conf.rb

before_fork do
  Sequel::DATABASES.each(&:disconnect)
end

after_mold_fork do
  SomeLibary.connection.close
end

after_worker_fork do
  SomeOtherLibary.connection.close
end
```

The documentation of any database client or network library you use should be
read with care to figure out how to disconnect it, and whether it is best to
do it before or after fork.

Since the most common Ruby application servers like `Puma`, `Unicorn` and `Passenger`
have forking at least as an option, the requirements are generally well documented.

However what is novel with `Pitchfork`, is that processes can be forked more than once.
So just because an application works fine with existing pre-fork servers doesn't necessarily
mean it will work fine with `Pitchfork`.

It's not uncommon for applications to not close connections after fork, but for it to go
unnoticed because these connections are lazily created when the first request is handled.

So if you enable reforking for the first time, you may discover some issues.

Also note that rather than to expose a callback, some libraries take on them to detect
that a fork happened, and automatically close inherited connections.

## Background Threads

When a process is forked, only the main threads will stay alive in the child process.
So any libraries that spawn a background thread for periodical work may need to be notified
that a fork happened and that it should restart its thread.

Just like with connections, some libraries take on them to automatically restart their background
thread when they detect that a fork happened.

# Refork Safety

Some code might happen to work without issue in other forking servers such as Unicorn or Puma,
but not work in Pitchfork when reforking is enabled.

This is because it is not uncommon for network connections or background threads to only be
initialized upon the first request. As such they're not inherited on the first fork.

However when reforking is enabled, new processes are forked out of a warmed up process, as such
any lazily created connection is much more likely to have been created.

As such, if you enable reforking for the first time, it is heavily recommended to first do it
in some sort of staging environment, or on a small subset of production servers as to limit the
impact of discovering such bug.

## Known Incompatible Gems

- The `grpc` isn't fork safe by default, but starting from version `1.57.0`, it does provide an experimental
  fork safe option that requires setting an environment variable before loading the library, and calling
  `GRPC.prefork`, `GRPC.postfork_parent` and `GRPC.postfork_child` around fork calls.
  (https://github.com/grpc/grpc/pull/33430).
  You can also use the [`grpc_fork_safety`](https://github.com/Shopify/grpc_fork_safety) gem to make it easier.

- The `ruby-vips` gem binds the `libvips` image processing library that isn't fork safe.
  (https://github.com/libvips/libvips/discussions/3577)

- Any gem binding with `libgobject`, such as the `gda` gem, likely aren't fork safe.

- If you use `jemalloc`, [the version `5.2` is known to have a fork safety bug that can cause childs to lock up](https://github.com/jemalloc/jemalloc/issues/2019).
  Make sure to upgrade to version `5.3`.

No other gem is known to be incompatible for now, but if you find one, please open an issue to add it to the list.
