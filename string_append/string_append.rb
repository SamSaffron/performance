# frozen_string_literal: true

require_relative '../rerunner/rerunner'
require 'benchmark/ips'

def append(global_id,message_id,channel,data)
  global_id.to_s << "|" << message_id.to_s << "|" << channel.gsub("|", "$$123$$") << "|" << data
end

def interpolate(global_id,message_id,channel,data)
  "#{global_id}|#{message_id}|#{channel.gsub("|", "$$123$$")}|#{data}"
end

if interpolate(1,2,"a|b","data") != append(1,2,"a|b","data")
  raise "bad implementation"
end


Benchmark.ips do |x|
  x.warmup = 1
  x.time = 10

  x.report("<<") do |times|
    while times > 0
      append(1,2,"three","four")
      times -= 1
    end
  end

  x.report("interpolate") do |times|
    while times > 0
      interpolate(1,2,"three","four")
      times -= 1
    end
  end

  x.compare!
end
