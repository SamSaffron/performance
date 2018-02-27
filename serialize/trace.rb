require 'json'

str = "hello world this is a test"

i = 1_000_000
while i > 0
  i -= 1
  str.to_json
end

