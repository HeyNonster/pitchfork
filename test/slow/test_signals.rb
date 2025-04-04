# -*- encoding: binary -*-
# frozen_string_literal: true

# Copyright (c) 2009 Eric Wong
# You can redistribute it and/or modify it under the same terms as Ruby 1.8 or
# the GPLv2+ (GPLv3+ preferred)
#
# Ensure we stay sane in the face of signals being sent to us
require 'test_helper'

class SignalsTest < Pitchfork::Test
  tag isolated: true

  include Pitchfork

  class Dd
    def initialize(bs, count)
      @count = count
      @buf = ' ' * bs
    end

    def each(&block)
      @count.times { yield @buf }
    end
  end

  def setup
    @bs = 1 * 1024 * 1024
    @count = 100
    @port = unused_port
    @sock = Pitchfork::Info.keep_io(Tempfile.new('pitchfork.sock'))
    @tmp = Pitchfork::Info.keep_io(Tempfile.new('pitchfork.write'))
    @tmp.sync = true
    File.unlink(@sock.path)
    File.unlink(@tmp.path)
    @server_opts = {
      :listeners => [ "127.0.0.1:#@port", @sock.path ],
      :after_worker_fork => lambda { |server, worker|
        trap(:HUP) { @tmp.syswrite('.') }
      },
    }
    @server = nil
  end

  def teardown
    reset_sig_handlers
  end

  def test_sleepy_kill
    rd, wr = Pitchfork::Info.keep_ios(IO.pipe)
    pid = fork {
      rd.close
      app = lambda { |env| wr.syswrite('.'); sleep; [ 200, {}, [] ] }
      redirect_test_io { HttpServer.new(app, @server_opts).start.join }
    }
    wr.close
    wait_workers_ready("test_stderr.#{pid}.log", 1)
    sock = tcp_socket('127.0.0.1', @port)
    sock.syswrite("GET / HTTP/1.0\r\n\r\n")
    buf = rd.readpartial(1)
    wait_monitor_ready("test_stderr.#{pid}.log")
    Process.kill(:INT, pid)
    Process.waitpid(pid)
    assert_equal '.', buf
    buf = nil
    assert_raises(EOFError,Errno::ECONNRESET,Errno::EPIPE,Errno::EINVAL,
                  Errno::EBADF) do
      buf = sock.sysread(4096)
    end
    assert_nil buf
  end

  def test_timeout_slow_response
    pid = fork {
      app = lambda { |env| sleep }
      opts = @server_opts.merge(:timeout => 3)
      redirect_test_io { HttpServer.new(app, opts).start.join }
    }
    t0 = Time.now
    wait_workers_ready("test_stderr.#{pid}.log", 1)
    sock = tcp_socket('127.0.0.1', @port)
    sock.syswrite("GET / HTTP/1.0\r\n\r\n")

    buf = nil
    assert_raises(EOFError,Errno::ECONNRESET,Errno::EPIPE,Errno::EINVAL,
                  Errno::EBADF) do
      buf = sock.sysread(4096)
    end
    diff = Time.now - t0
    assert_nil buf
    assert diff > 1.0, "diff was #{diff.inspect}"
    assert diff < 60.0
  ensure
    Process.kill(:INT, pid) rescue nil
  end

  def test_response_write
    app = lambda { |env|
      [ 200, { 'content-type' => 'text/plain', 'X-Pid' => Process.pid.to_s },
        Dd.new(@bs, @count) ]
    }
    redirect_test_io { @server = HttpServer.new(app, @server_opts).start }
    wait_workers_ready("test_stderr.#{$$}.log", 1)
    sock = tcp_socket('127.0.0.1', @port)
    sock.syswrite("GET / HTTP/1.0\r\n\r\n")
    buf = ''.b
    header_len = pid = nil
    buf = sock.sysread(16384, buf)
    pid = buf[/\r\nX-Pid: (\d+)\r\n/, 1].to_i
    header_len = buf[/\A(.+?\r\n\r\n)/m, 1].size
    assert pid > 0, "pid not positive: #{pid.inspect}"
    read = buf.size
    size_before = @tmp.stat.size
    assert_raises(EOFError,Errno::ECONNRESET,Errno::EPIPE,Errno::EINVAL,
                  Errno::EBADF) do
      loop do
        3.times { Process.kill(:HUP, pid) }
        sock.sysread(16384, buf)
        read += buf.size
        3.times { Process.kill(:HUP, pid) }
      end
    end

    redirect_test_io { @server.stop(true) }
    # can't check for == since pending signals get merged
    assert size_before < @tmp.stat.size
    got = read - header_len
    expect = @bs * @count
    assert_equal(expect, got, "expect=#{expect} got=#{got}")
    assert_nil sock.close
  end

  def test_request_read
    app = lambda { |env|
      while env['rack.input'].read(4096)
      end
      [ 200, {'content-type'=>'text/plain', 'X-Pid'=>Process.pid.to_s}, [] ]
    }
    redirect_test_io { @server = HttpServer.new(app, @server_opts).start }

    wait_workers_ready("test_stderr.#{$$}.log", 1)
    sock = tcp_socket('127.0.0.1', @port)
    sock.syswrite("GET / HTTP/1.0\r\n\r\n")
    pid = sock.sysread(4096)[/\r\nX-Pid: (\d+)\r\n/, 1].to_i
    assert_nil sock.close

    assert pid > 0, "pid not positive: #{pid.inspect}"
    sock = tcp_socket('127.0.0.1', @port)
    sock.syswrite("PUT / HTTP/1.0\r\n")
    sock.syswrite("Content-Length: #{@bs * @count}\r\n\r\n")
    1000.times { Process.kill(:HUP, pid) }
    size_before = @tmp.stat.size
    killer = fork { loop { Process.kill(:HUP, pid); sleep(0.01) } }
    buf = ' ' * @bs
    @count.times { sock.syswrite(buf) }
    Process.kill(:KILL, killer)
    Process.waitpid2(killer)
    redirect_test_io { @server.stop(true) }
    # can't check for == since pending signals get merged
    assert size_before < @tmp.stat.size
    assert_equal pid, sock.sysread(4096)[/\r\nX-Pid: (\d+)\r\n/, 1].to_i
    assert_nil sock.close
  end
end
