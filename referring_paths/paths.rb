require 'objspace'

class A
  attr_accessor :b
end

class B
  attr_accessor :c
end

class C
end

def make_a
  c = C.new
  b = B.new
  a = A.new
  a.b = b
  b.c = c
  a
end


def referring_object_ids(paths, depth=0)
  new_paths = []
  expanded_paths = []

  ObjectSpace.each_object do |x|
    reachables = ObjectSpace.reachable_objects_from(x)

    paths.each_with_index do |t, idx|

      # if we reach thread we are done, too much hangs off thread
      next if Thread === ObjectSpace._id2ref(t[depth]) rescue nil

      obj_id = t[depth]
      if obj_id && obj_id != x.object_id && reachables.map(&:object_id).include?(obj_id)
        new_paths << (t + [x.object_id])
        expanded_paths << idx
      end
    end
  end

  if new_paths.length > 0 && depth < 5
    expanded_paths.sort.reverse.each do |i|
      paths.delete_at i
    end
    paths = referring_object_ids((paths + new_paths).uniq, depth+1)
  end

  paths.uniq

end

def referring_paths(obj)
  paths = referring_object_ids([[obj.object_id]])

  paths.map do |path|
    path.map do |obj_id|
      ObjectSpace._id2ref(obj_id) rescue nil
    end
  end
end


$a = make_a
referring_paths($a.b.c).each do |path|
  puts
  path.each do |obj|
    print obj.class
    print " #{obj.to_s[0..20]} "
  end
end
puts

# C #<C:0x00007f002c59b40 Thread #<Thread:0x00007f002c
# C #<C:0x00007f002c59b40 B #<B:0x00007f002c599f6 A #<A:0x00007f002c599ee
