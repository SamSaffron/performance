require 'benchmark/ips'
require 'json'
require 'oj'

count = 1

numbers_as_string_json = ("," + (1..count).to_a.join(",") + ",").to_json
numbers_json = (1..count).to_a.to_json

needle = 1000000
needle_s = ",#{needle.to_s},"


Benchmark.ips do |x|

  x.report("Numbers binary search") do |i|
    while i > 0
      numbers = JSON.parse(numbers_json)
      numbers.bsearch { |x| x == needle }
      i -= 1
    end
  end

  x.report("Numbers include") do |i|
    while i > 0
      numbers = JSON.parse(numbers_json)
      numbers.include?(needle)
      i -= 1
    end
  end


  x.report("Numbers binary search Oj") do |i|
    while i > 0
      numbers = Oj.load(numbers_json)
      numbers.bsearch { |x| x == needle }
      i -= 1
    end
  end

  x.report("Numbers include Oj") do |i|
    while i > 0
      numbers = Oj.load(numbers_json)
      numbers.include?(needle)
      i -= 1
    end
  end



  x.report("String hack") do |i|
    while i > 0
      string = JSON.parse(numbers_as_string_json)
      string.include?(needle_s)
      i -= 1
    end
  end

  x.report("String hack Oj") do |i|
    while i > 0
      string = Oj.load(numbers_as_string_json)
      string.include?(needle_s)
      i -= 1
    end
  end

  x.compare!
end

# Comparison:
#      String hack Oj:    28291.9 i/s
#         String hack:    20373.9 i/s - 1.39x  (± 0.00) slower
# Numbers binary search Oj:     3736.4 i/s - 7.57x  (± 0.00) slower
#  Numbers include Oj:     3492.2 i/s - 8.10x  (± 0.00) slower
# Numbers binary search:     2264.1 i/s - 12.50x  (± 0.00) slower
#     Numbers include:     2164.2 i/s - 13.07x  (± 0.00) slower

