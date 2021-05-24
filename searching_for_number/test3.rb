require 'benchmark/ips'

numbers = (1..10000).to_a
numbers_as_string = "," + (1..10000).to_a.join(",") + ","
numbers_as_hash = {}
(1..10000).each {|n| numbers_as_hash[n] = true }

serialized_numbers = Marshal.dump(numbers)
serialized_string = Marshal.dump(numbers_as_string)
serialized_hash = Marshal.dump(numbers_as_hash)


Benchmark.ips do |x|

  x.report("binary search numbers") do |i|
    while i > 0
      numbers = Marshal.load(serialized_numbers)
      numbers.bsearch { |x| x == 77 }
      i -= 1
    end
  end

  x.report("numbers") do |i|
    while i > 0
      numbers = Marshal.load(serialized_numbers)
      numbers.include?(5000)
      i -= 1
    end
  end

  x.report("string") do |i|
    while i > 0
      numbers_as_string = Marshal.load(serialized_string)
      numbers_as_string.include?(",5000,")
      i -= 1
    end
  end

  x.report("hash") do |i|
    while i > 0
      numbers_as_hash = Marshal.load(serialized_hash)
      numbers_as_hash[5000]
      i -= 1
    end
  end

  x.compare!
end

#Comparison:
#              string:   168019.7 i/s
#binary search numbers:     5586.9 i/s - 30.07x  (± 0.00) slower
#             numbers:     5061.3 i/s - 33.20x  (± 0.00) slower
#                hash:     2558.9 i/s - 65.66x  (± 0.00) slower
