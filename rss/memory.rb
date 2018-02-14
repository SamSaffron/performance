require 'memory_profiler'

MemoryProfiler.report do
  require 'rss'
end.pretty_print
