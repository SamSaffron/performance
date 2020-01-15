# frozen_string_literal: true
require 'yajl'
require 'oj'
require 'json'
require 'benchmark/ips'

hash = JSON.parse(File.read("sample.json"))

json = JSON.dump(hash)
oj_compat = Oj.dump(hash, mode: :compat, time_format: :ruby)
oj = Oj.dump(hash)
yajl = Yajl::Encoder.encode(hash)

if json != oj
  raise "oj and JSON are different"
end

if json != oj_compat
  raise "oj compat and JSON are different"
end

if json != yajl
  raise "yajl is different"
end

Benchmark.ips do |x|
  x.report("Oj dump") do |times|
    while times > 0
      Oj.dump(hash, mode: :compat, time_format: :ruby)
      times -= 1
    end
  end

  x.report("Oj dump non compat") do |times|
    while times > 0
      Oj.dump(hash, time_format: :ruby)
      times -= 1
    end
  end

  x.report("JSON dump") do |times|
    while times > 0
      JSON.dump(hash)
      times -= 1
    end
  end

  x.report("Yajl encode") do |times|
    while times > 0
      Yajl::Encoder.encode(hash)
      times -= 1
    end
  end

  x.compare!
end

# sam@arch json_perf % ruby dump_perf.rb
# ...
# Comparison:
#   Oj dump non compat:     7003.9 i/s
#              Oj dump:     6311.4 i/s - 1.11x  slower
#            JSON dump:     4959.7 i/s - 1.41x  slower
#          Yajl encode:     2942.5 i/s - 2.38x  slower
#
