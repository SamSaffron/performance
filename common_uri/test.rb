require 'memory_profiler'

MemoryProfiler.report do
  require 'uri'
end.pretty_print
