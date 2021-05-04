# frozen_string_literal: true

require_relative '../rerunner/rerunner.rb'

class Car
  def self.all_blue!
    puts "all blue called"
    sleep 0.1
    puts "all blue set"
    @@all_blue = true
  end

  def drive(distance)
    sleep 0.1
    if @@all_blue
      puts "driving a blue car #{distance}"
    else
      puts "driving car #{distance}"
    end
  end
end


class Profiler

  INSTRUMENTS = {
    "forced blue" => [Car.singleton_class, :all_blue!],
    "drive" => [Car, :drive]
  }

  def self.instrument(name, &blk)
    klass, method = INSTRUMENTS[name]

    mod = Module.new do
      define_method method, &blk
    end

    klass.prepend mod
  end

  def self.log(name, &blk)
    instrument(name) do |*args, **kwargs|
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rval = super(*args, **kwargs)
      blk.call(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start)
      rval
    end
  end
end


Profiler.instrument("forced blue") do |*args, **kwargs|
  puts "called instrument for force blue"
  rval = super(*args, **kwargs)
  puts "after calling instrument for force blue"
  rval
end

Profiler.log("forced blue") do |duration|
  puts "called log for force blue duration was #{duration}"
end

Profiler.log("drive") do |duration|
  puts "it took #{duration} to drive"
end


Car.all_blue!
Car.new.drive(200)

