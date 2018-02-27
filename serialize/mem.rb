require 'memory_profiler'
require 'json'

x = "testing this"

x.to_json
state = JSON::Ext::Generator::State.new
state.generate(x)


MemoryProfiler.report do
  state.generate(x)
end.pretty_print


