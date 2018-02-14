require 'benchmark/ips'

class Wrapped < StandardError
  attr_reader :wrapped
  def initialize(str, wrapped)
    @wrapped = wrapped
    super(str)
  end
end

begin
  begin
    raise StandardError
  rescue => _e
    puts _e.cause
    raise
  end
rescue => _e
  puts
  puts _e.cause
end

exit

def deep(d)
  if d > 0
    deep(d-1)
    return
  end

  Benchmark.ips do |x|
    x.report("raise from rescue") do |i|
      while i > 0
        begin; begin; raise StandardError; rescue => _e; raise; end; rescue => _e; end
        i -= 1
      end
    end

    x.report("raise wrapped") do |i|
      while i > 0
        begin; begin; raise StandardError; rescue => e; raise Wrapped.new("",e); end; rescue => _e; end
        i -= 1
      end
    end

    x.report("don't re-raise") do |i|
      while i > 0
        begin; begin; raise StandardError; rescue => _e; end; rescue => _e; end
        i -= 1
      end
    end

    x.report("raise e from rescue") do |i|
      while i > 0
        begin; begin; raise StandardError; rescue => e; raise e; end; rescue => _e; end
        i -= 1
      end
    end

    x.compare!
  end
end

deep(80)
