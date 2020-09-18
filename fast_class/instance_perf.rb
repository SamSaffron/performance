# frozen_string_literal: true
require 'benchmark/ips'

X = ""
D = /a/

Benchmark.ips do |x|
  x.report("===") do |times|
    while times > 0
      Regexp === X
      Regexp === D
      times -= 1
    end
  end

  x.report("instance_of?") do |times|
    while times > 0
      X.instance_of? Regexp
      D.instance_of? Regexp
      times -= 1
    end
  end

  x.compare!
end

