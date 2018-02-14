require 'benchmark/ips'

@e = StandardError.new
@e2 = (r = nil; begin; raise; rescue => e; r = e; end; r)

Benchmark.ips do |x|
  x.report("raise") do
    begin; raise; rescue; end
  end

  x.report("raise e, no backtrace") do
    begin; raise @e; rescue; end
  end

  x.report("raise e, yes backtrace") do
    begin; raise @e2; rescue; end
  end
end
