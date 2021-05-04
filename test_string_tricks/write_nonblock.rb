require 'tempfile'
require 'socket'

$port = 28344

Thread.new do
  server = TCPServer.new($port)
  loop do
    client = server.accept
    while true
      p client.read_nonblock(4000)
      sleep 1
    end
  end
end

x = "abcde" * 10000000
x = StringIO.new(x)

sock = TCPSocket.new('localhost', $port)

while true
  begin
    len = sock.write_nonblock(x)
    p len
  rescue IO::EAGAINWaitWritable
    sleep 0.01
  end
end

