a = "1234567890123456789012345678901234567890"
b = "1234567890123456789012345678901234567890"
b.taint

puts (-a).object_id
puts (-b).object_id

puts b.tainted?


class Test
  attr_accessor :a
end

x = Test.new
y = Test.new


x.a = a.dup
y.a = a.dup

x.a = -x.a
y.a = -y.a

puts (x.a).object_id
puts (y.a).object_id

