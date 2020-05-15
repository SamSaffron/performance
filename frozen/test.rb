# frozen_string_literal: true

a = %w{a b}
b = "hi"
c = "a #{1} b"
d = "a " + "b"

puts -("a " + "b").frozen?
exit

a = 1
puts "#{a}".frozen?
exit

puts a[0].frozen?
puts b.frozen?
puts c.frozen?
puts d.frozen?
puts e.frozen?
