

20_000.times do |i|
  eval <<~STR
    def to_jit_#{i}
      ""
    end
  STR

  5.times do
    send "to_jit_#{i}"
  end
end

puts "methods created"


10.times do
  gets
  100.times do
    20_000.times do |i|
      send "to_jit_#{i}"
    end
  end
end
