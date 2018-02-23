require 'memory_profiler'

MemoryProfiler.report do
  require 'rss'
end.pretty_print($stdout, detailed_report: false, allocated_strings: 0, retained_string: 10)


