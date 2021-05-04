# pipes are used for signalling ... there is reader and writer
# you can send data to the reader by writing to the writer
# safe for multithreaded use
$r,$w = IO.pipe

Thread.new do
  # change value to 4 to demo how timeout of 3 seconds is reached
  sleep 2
  $w.write_nonblock("early_stop")
end

start = Time.now

# This means we are waiting on input to be ready on the read side of the pipe. The last param
# 3 means that we will timeout after 3 seconds
readers, _ = IO.select([$r], nil, nil, 3)

# we return an array showing what readers had data ready
if readers
  # we use read_nonblock cause we dont really care to wait here for all the data
  # we just want to grab the data ready after IO.select
  # in theory if we are unlucky with buffers maybe we need a few calls to read_nonblock to get the full text
  # early_stop
  puts readers[0].read_nonblock(20)
end

puts Time.now - start
