require 'benchmark/ips'

def trace(metric)
  yield
end


def with_trace
  trace("test") do
    true
  end
end

def without_trace
  true
end

def is_true
  true
end

def extra_method_calls
  true
end

Benchmark.ips do |b|
  b.report("without_trace") do |count|
    while count > 0
      without_trace
      count -=1
    end
  end

  b.report("with_trace") do |count|
    while count > 0
      with_trace
      count -=1
    end
  end

  b.report("with_indirection") do |count|
    while count > 0
      with_trace
      count -=1
    end
  end

  b.compare!
end
