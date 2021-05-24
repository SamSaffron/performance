require 'benchmark/ips'

numbers = (1..10000).to_a
numbers_as_string = "," + (1..10000).to_a.join(",") + ","


Benchmark.ips do |x|

  x.report("binary search numbers") do |i|
    while i > 0
      numbers.bsearch { |x| x == 77 }
      i -= 1
    end
  end

  x.report("numbers") do |i|
    while i > 0
      numbers.include?(5000)
      i -= 1
    end
  end

  x.report("numbers") do |i|
    while i > 0
      numbers.include?(5000)
      i -= 1
    end
  end

  x.report("string") do |i|
    while i > 0
      numbers_as_string.include?(",5000,")
      i -= 1
    end
  end

  x.compare!
end
