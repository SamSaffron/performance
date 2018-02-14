
x = {}
x["#{1}"] = 1
x["2"] = 1

y = {}
y["#{1}"] = 1
y["2"] = 1

puts x.keys.map{|k| "#{k} #{k.object_id}"}
puts y.keys.map{|k| "#{k} #{k.object_id}"}
