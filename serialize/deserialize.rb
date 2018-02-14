require 'benchmark/ips'
require 'oj'
require 'json'
require 'msgpack'

hash = GC.stat

json = hash.to_json
msg_pack = MessagePack.dump(hash)

Benchmark.ips do |p|
  p.report('json') do |times|
    while (times-=1) >= 0
      JSON.parse(json)
    end
  end
  p.report('Oj') do |times|
    while (times-=1) >= 0
      Oj.load(json)
    end
  end
  p.report('Message Pack') do |times|
    while (times-=1) >= 0
      MessagePack.load(msg_pack)
    end
  end
end
