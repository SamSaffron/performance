require 'benchmark/ips'
require 'securerandom'

class Test
  def x; end
end
PROC = :x.to_proc
PROC2 = proc {|a| a.x}

Benchmark.ips do |b|
  5.times do |t|
    test = (0..t).map{ Test.new }
    b.report("map #{t}") do |i|
      while i > 0
        test.map{|a| a.x}
        i -= 1
      end
    end
    b.report("to_proc1 #{t}") do |i|
      while i > 0
        test.map(&:x)
        i -= 1
      end
    end
    b.report("to_proc2 #{t}") do |i|
      while i > 0
        test.map(&PROC)
        i -= 1
      end
    end
    b.report("to_proc3 #{t}") do |i|
      while i > 0
        test.map(&PROC2)
        i -= 1
      end
    end
  end
end


# Ruby 2.5.1
# Warming up --------------------------------------
#                  map     9.729k i/100ms
#                colon    11.385k i/100ms
# Calculating -------------------------------------
#                  map    103.892k (± 4.1%) i/s -    525.366k in   5.065502s
#                colon    122.142k (± 3.8%) i/s -    614.790k in   5.040780s
