class AutoRun
  def self.start
    if ENV['_FORKING_PID'] == nil
      ENV['_FORKING_PID'] = Process.pid.to_s
      new.start
    end
  end

  def initialize
    @file = caller_locations[3].absolute_path
    @last_change = File.ctime(@file)
  end

  def wait_for_change
    while @last_change == File.ctime(@file)
      sleep 1
    end
    @last_change = File.ctime(@file)
    puts
    puts "RELOADING"
    puts
  end

  def start
    while true
      fork do
        begin
          Dir.chdir(File.dirname(@file)) do
            exec "ruby #{@file}"
          end
        rescue => e
          puts "OOPS something bad happened #{e}"
          sleep 5
        end
      end

      Process.wait

      wait_for_change
    end
  end

end

AutoRun.start

