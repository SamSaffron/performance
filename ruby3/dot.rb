# frozen_string_literal: true

require 'benchmark/ips'

def bar(a,b,c)
end

def foo(...)
  bar(...)
end

def foo2(*a)
  bar(*a)
end

def foo3(*a, **b)
  bar(*a, **b)
end

foo(99, a: 1)

exit



Benchmark.ips do |x|
  x.warmup = 1
  x.time = 2

  x.report("foo") do |times|
    while times > 0
      foo(1,2,3)
      times -=1
    end
  end

  x.report("foo2") do |times|
    while times > 0
      foo(1,2,3)
      times -=1
    end
  end

  x.report("foo3") do |times|
    while times > 0
      foo(1,2,3)
      times -=1
    end
  end
  x.compare!
end
