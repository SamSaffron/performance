
times = 10

fork do

  puts "XXXX" * 10
  puts "in child #{Process.pid}"

  times.times do |i|
    eval <<~STR
      def to_jit_#{i}
        ""
      end
    STR

    20.times do
      send "to_jit_#{i}"
    end
  end
end

puts "in parent #{Process.pid}"

gets

