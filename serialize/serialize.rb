require 'benchmark/ips'
require 'oj'
require 'json'
require 'msgpack'

hash = GC.stat

# puts hash.to_json
# puts Oj.to_json(hash)
# puts Msgpack.serialize
#

puts RUBY_VERSION

Benchmark.ips do |p|
  p.report('json') do |times|
    while (times-=1) >= 0
      hash.to_json
    end
  end
  p.report('Oj') do |times|
    while (times-=1) >= 0
      Oj.to_json(hash)
    end
  end
  p.report('Message Pack') do |times|
    while (times-=1) >= 0
      MessagePack.dump(hash)
    end
  end
end

# 2.4.2
# Warming up --------------------------------------
#                 json     8.163k i/100ms
#                   Oj    36.578k i/100ms
#         Message Pack    57.897k i/100ms
# Calculating -------------------------------------
#                 json     84.219k (± 1.7%) i/s -    424.476k in   5.041571s
#                   Oj    407.721k (± 2.4%) i/s -      2.048M in   5.027073s
#         Message Pack    692.894k (± 2.8%) i/s -      3.474M in   5.017708s

