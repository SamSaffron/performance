
start = nil
i = 0

while val = gets
  if val == "START\n"
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    i = 0
  elsif val == "FINISH\n"
    finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = finish - start
    puts "Elapsed: #{duration.round(5)} total messages: #{i} rate #{(i / (duration)).round(2)} / sec"
  else
    i += 1
  end
end
