require 'benchmark/ips'
require 'oj'
require 'json'
require 'msgpack'

hash = GC.stat

# puts hash.to_json
# puts Oj.to_json(hash)
# puts Msgpack.serialize
#

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
