require 'resolv'
require 'memory_profiler'

puts "ruby version: #{RUBY_VERSION}"

r = Resolv::DNS.new

r.getresource('www.example.net', Resolv::DNS::Resource::IN::A).address
r.getresource('www.example.net', Resolv::DNS::Resource::IN::A).address


MemoryProfiler.report do
  1000.times { r.getresource('www.example.net', Resolv::DNS::Resource::IN::A).address }
end.pretty_print

puts "RequestID table size: #{Resolv::DNS::RequestID.values.first&.count or "(empty)"}"
