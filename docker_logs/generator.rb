# frozen_string_literal: true

STDERR.puts "Logs generator startup"

MSG = "x" * 500

def run
  STDERR.puts "START"
  i = 1
  while i <= 200_000
    STDERR.puts MSG
    i += 1
  end
  STDERR.puts "FINISH"
end

Signal.trap("USR1") do
  Thread.new do
    run
  end
end

sleep

