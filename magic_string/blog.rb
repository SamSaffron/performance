require 'memory_profiler'
def get_obj
   allocated_object1 = "hello "
   allocated_object2 = "world"
   allocated_object1 + allocated_object2
end

retained_object = nil

MemoryProfiler.report do
   retained_object = get_obj
end.pretty_print
