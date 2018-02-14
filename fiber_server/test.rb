require 'socket'

s = TCPSocket.new('127.0.0.1', 9292)

s.puts "GET /bigwork HTTP/1.1\r\n\r\n"
s.flush
puts s.read
s.close
#puts s.read
