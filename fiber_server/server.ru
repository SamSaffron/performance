# frozen_string_literal: true

require 'fiber'
require 'thread'

class TimerThread
  attr_reader :jobs
  class Cancelable
    NOOP = proc {}

    def initialize(job)
      @job = job
    end
    def cancel
      @job[1] = NOOP
    end
  end

  class CancelableEvery
    attr_accessor :cancelled, :current
    def cancel
      current.cancel if current
      @cancelled = true
    end
  end

  def initialize
    @stopped = false
    @jobs = []
    @mutex = Mutex.new
    @next = nil
    @thread = Thread.new { do_work }
    @on_error = lambda { |e| STDERR.puts "Exception while processing Timer:\n #{e.backtrace.join("\n")}" }
  end

  def stop
    @stopped = true
    running = true
    while running
      @mutex.synchronize do
        running = @thread && @thread.alive?
        @thread.wakeup if running
      end
      sleep 0
    end
  end

  def every(delay, &block)
    result = CancelableEvery.new
    do_work = proc do
      begin
        block.call
      ensure
        result.current = queue(delay, &do_work)
      end
    end
    result.current = queue(delay, &do_work)
    result
  end

  # queue a block to run after a certain delay (in seconds)
  def queue(delay = 0, &block)
    queue_time = Time.new.to_f + delay
    job = [queue_time, block]

    @mutex.synchronize do
      i = @jobs.length
      while i > 0
        i -= 1
        current, _ = @jobs[i]
        if current < queue_time
          i += 1
          break
        end
      end
      @jobs.insert(i, job)
      @next = queue_time if i == 0
    end

    unless @thread.alive?
      @mutex.synchronize do
        @thread = Thread.new { do_work } unless @thread.alive?
      end
    end

    if @thread.status == "sleep"
      @thread.wakeup
    end

    Cancelable.new(job)
  end

  def on_error(&block)
    @on_error = block
  end

  protected

  def do_work
    while !@stopped
      if @next && @next <= Time.new.to_f
        _, blk = @mutex.synchronize { @jobs.shift }
        begin
          blk.call
        rescue => e
          @on_error.call(e) if @on_error
        end
        @mutex.synchronize do
          @next, _ = @jobs[0]
        end
      end
      unless @next && @next <= Time.new.to_f
        sleep_time = 1000
        @mutex.synchronize do
          sleep_time = @next - Time.new.to_f if @next
        end
        sleep [0, sleep_time].max
      end
    end
  end
end

class ThreadPool
  def initialize(threads)
    @queue = Queue.new

    threads.times do
      Thread.new do
        while true
          do_work
        end
      end
    end
  end

  def <<(blk)
    @queue << blk
  end

  def do_work
    blk = @queue.pop
    blk.call
  rescue => e
    STDERR.puts "Failed to run worker #{e}"
  end
end

class FiberMiddleware
  def initialize(app, config = {})
    @app = app
    @queue = Queue.new
    @worker = start_worker
    @timer = TimerThread.new

    @defer = {}
    config.each do |queue, threads|
      @defer[queue] = ThreadPool.new(threads)
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
  ensure
    io.close rescue nil
  end

  def process((io, env))
    fiber = Fiber.new do
      response env, io, @app.call(env)
    end

    env['fiber.wait'] = lambda do |t|
      @timer.queue(t) do
        @queue << fiber
      end
      Fiber.yield
    end

    env['fiber.queue'] = lambda do |q, &blk|
      @defer[q] << lambda do
        begin
          blk.call
        ensure
          @queue << fiber
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
          item.resume
        else
          process(item)
        end
      end
    end
  end
end


class FiberServer
  def call(env)

    if env["PATH_INFO"] =~ /slow/
      env["fiber.wait"].call(1.5)
    end

    if env["PATH_INFO"] =~ /bigwork/
      env["fiber.queue"].call(:slow) do
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

Rack::Server.start app: FiberMiddleware.new(FiberServer.new, slow: 1)

