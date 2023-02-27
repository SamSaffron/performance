PACKETS = 50

data = `tshark -c #{PACKETS} -T fields -e frame.len -e ip.dst -e ip.src -e ipv6.src -e ipv6.dst`

from_hash = {}
to_hash = {}

def add(hash, ip, size)
  data = hash[ip] || [0,0]
  data[0] += 1
  data[1] += size.to_i
  hash[ip] = data
end

def report(hash)
  hash.sort do |a,b|
    b[1][0] <=> a[1][0]
  end.take(10).each do |ip, (count, size)|
    puts "#{ip} packets:#{count} bytes:#{size}"
  end
end

data.each_line do |line|
  size, to, from = line.split(/\s/)

  to = "<unknown>" if to.to_s.strip == ""
  from = "<unknown>" if from.to_s.strip == ""

  add(from_hash, from, size)
  add(to_hash, to, size)
end

puts "Top incoming"
puts "-" * 80

report(to_hash)

puts

puts "Top outgoing"
puts "-" * 80

report(from_hash)


