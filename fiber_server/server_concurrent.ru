# frozen_string_literal: true

require 'fiber'
require 'concurrent'

class FiberMiddleware
  # any request taking longer than this will be aborted
  DEFAULT_TIMEOUT = 30

  def initialize(app, config = {})
    @app = app

    @queue = Queue.new
    @worker = start_worker

    @defer = {}
    @timeout = config[:timeout] || DEFAULT_TIMEOUT
    if config[:queues]
      config[:queues].each do |queue, threads|
        @defer[queue] = Concurrent::FixedThreadPool.new(threads)
      end
    end
  end

  def call(env)
    env['_start'] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    io = env['rack.hijack'].call
    @queue << [io,env]
    [418, {}, []]
  end

  protected

  def response(env, io, (status, headers, body))
    io.write("HTTP/1.1 #{status}\r\n")

    str = +""
    body.each do |m|
      str << m
    end

    headers['Content-Length'] = str.bytesize
    headers['Connection'] = 'close'
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - env['_start']
    headers['X-Runtime'] = "#{"%0.6f" % duration}"
    headers.each do |name, val|
      io.write "#{name}: #{val}\r\n"
    end

    io.write("\r\n")
    io.write(str)
  rescue => e
    STDERR.puts "failed #{e} #{io.object_id}"
    STDERR.puts e.backtrace
  ensure
    io.close rescue nil
  end

  def process((io, env))
    fiber = Fiber.new do
      response env, io, @app.call(env)
    end

    env['fiber.wait'] = lambda do |t|
      Concurrent::ScheduledTask.execute(t) do
        @queue << fiber
      end
      Fiber.yield
    end

    env['fiber.queue'] = lambda do |q, &blk|

      @defer[q] << lambda do
        begin
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - env['_start']
          if duration < @timeout
            blk.call
          else
            puts "aborting"
            io.write("HTTP/1.1 500\r\n\r\n")
            io.close rescue nil
            io = nil
          end
        rescue => e
          STDERR.puts "no longer writable GOOD #{e}"
        ensure
          @queue << fiber if io
        end
      end
      Fiber.yield
    end

    fiber.resume
  rescue => e
    io.close rescue nil
    STDERR.puts "Failed responding #{e}"
  end

  def start_worker
    Thread.new do
      while true
        item = @queue.pop
        if Fiber === item
          # could have crashed
          item.resume rescue nil
        else
          process(item)
        end
      end
    end
  end
end


class DemoServer
  def call(env)

    if env["PATH_INFO"] =~ /slow/
      env["fiber.wait"].call(1.5)
    end

    if env["PATH_INFO"] =~ /bigwork/
      env["fiber.queue"].call(:slow) do
        sleep 3
        1_000_000.times do
          99.99 ** 200
        end
      end
    end

    res = Rack::Response.new
    res.write("<html><body>hello")
    res.write("</body></html>")
    res.finish
  end
end

Rack::Server.start app: FiberMiddleware.new(DemoServer.new, timeout: 2, queues: {slow: 1})
#Rack::Server.start app: DemoServer.new

