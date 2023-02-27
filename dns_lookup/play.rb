require_relative '../rerunner/rerunner'
require 'benchmark/ips'
require 'socket'

class Resolver
  def self.timeout
    @timeout || 2
  end

  def self.timeout=(val)
    @timeout = val
  end

  @mutex = Mutex.new
  def self.lookup(addr)
    @mutex.synchronize do
      @result = nil

      @queue ||= Queue.new
      @queue << ""
      ensure_lookup_thread

      @lookup = addr
      @parent = Thread.current

      sleep timeout
      if !@result
        @thread.kill
        @thread = nil
        if @error
          raise @error
        else
          raise Timeout::Error
        end
      end
      @result
    end
  end

  def self.ensure_lookup_thread
    @thread ||= Thread.new do
      while true
        @queue.deq
        @error = nil
        begin
          @result = Socket.getaddrinfo @lookup, "http"
        rescue => e
          @error = e
        end
        @parent.wakeup
      end
    end if !@thread&.alive?
  end
end

i = 0

Benchmark.ips do |x|
  x.report("Resolver") do |times|
    while times > 0
      Resolver.lookup("cnn.com")
      i += 1
      times -= 1
    end
  end

  x.report("Direct") do |times|
    while times > 0
      Socket.getaddrinfo "cnn.com", "http"
      i += 1
      times -= 1
    end
  end

  x.compare!
end

# Warming up --------------------------------------
#             Resolver    23.000  i/100ms
#               Direct    20.000  i/100ms
# Calculating -------------------------------------
#             Resolver    234.217  (±11.1%) i/s -      1.173k in   5.075972s
#               Direct    246.213  (±11.4%) i/s -      1.220k in   5.028819s

# Comparison:
#               Direct:      246.2 i/s
#             Resolver:      234.2 i/s - same-ish: difference falls within error




