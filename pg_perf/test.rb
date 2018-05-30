require 'pg'
require 'benchmark/ips'

$conn = PG.connect(dbname: 'postgres')


Benchmark.ips do |b|
  b.config(time: 10, warmup: 3)

  b.report("exec") do
    $conn.exec("SELECT generate_series(1,10000)").to_a
  end
  b.report("async exec") do
    $conn.async_exec("SELECT generate_series(1,10000)").to_a
  end
end




