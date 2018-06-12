# frozen_string_literal: true
# tiny rerunner (I use this on local to rerun script)
require_relative '../rerunner/rerunner.rb'

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
end

require 'pg'

def count_malloc(desc)
  start = GC.stat[:malloc_increase_bytes]
  yield
  delta = GC.stat[:malloc_increase_bytes] - start
  puts "#{desc} allocated #{delta} bytes"
end

def process_rss
  puts 'RSS is: ' + `ps -o rss -p #{$$}`.chomp.split("\n").last
end

def malloc_limits
  s = GC.stat
  puts "malloc limit #{s[:malloc_increase_bytes_limit]}, old object malloc limit #{s[:oldmalloc_increase_bytes_limit]}"
end

conn = PG.connect(dbname: 'test_db')
sql = "select repeat('x', $1)"

# simulate a Rails app by long term retaining 400_000 objects
$long_term = []
400_000.times do
  $long_term << +""
end

puts "start RSS/limits"
process_rss
malloc_limits

count_malloc("100,000 bytes PG") do
  conn.exec(sql, [100_000])
end

count_malloc("100,000 byte string") do
  "x" * 100_000
end

x = []
10_000.times do |i|
  x[i%10]  = "x" * 100_000
end

puts "RSS/limits after allocating 10k 100,000 byte string"
malloc_limits
process_rss

10_000.times do |i|
  r = x[i%10] = conn.exec(sql, [100_000])
  r.clear
end

puts "RSS/limits after allocating 10k 100,000 byte strings in libpq (and clearing)"
malloc_limits
process_rss

10_000.times do |i|
  x[i%10] = conn.exec(sql, [100_000])
end

puts "RSS/limits after allocating 10k 100,000 byte strings in libpq (and NOT clearing)"
malloc_limits
process_rss
puts "done"


# start RSS/limits
# RSS is: 48628
# malloc limit 16777216, old object malloc limit 16777216
#
# 100,000 bytes PG allocated 960 bytes
# 100,000 byte string allocated 103296 bytes
#
# RSS/limits after allocating 10k 100,000 byte string
# malloc limit 33554432, old object malloc limit 45373937
# RSS is: 76984
#
# RSS/limits after allocating 10k 100,000 byte strings in libpq (and clearing)
# malloc limit 33554432, old object malloc limit 45373937
# RSS is: 79624
#
# RSS/limits after allocating 10k 100,000 byte strings in libpq (and NOT clearing)
# malloc limit 33554432, old object malloc limit 45373937
# RSS is: 1120768
