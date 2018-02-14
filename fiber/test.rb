def recurse(i)
  return caller.length if i == 0
  recurse(i-1)
end

puts recurse(50_000)

Fiber.new do
  puts recurse(1500)
end.resume
