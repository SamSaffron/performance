puts "#{Process.pid} I am the master"

def start_fork
  fork do
    puts Process.pid
    Thread.new do
      while true
        sleep 1
        puts 1
      end
    end
    sleep 5
    bang
  end
end

p start_fork

puts "#{Process.pid} Unicorn master logic is being run here..."

gets
