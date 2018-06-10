require_relative '../rerunner/rerunner'
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'activesupport'#, path: '../../rails/activesupport'
  gem 'activerecord'#, path: '../../rails/activerecord'
  gem 'activemodel'#, path: '../../rails/activemodel'
end

require 'active_record'
require_relative 'pool_drainer'
require 'objspace'

ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :database => "test_db"
)

pg = ActiveRecord::Base.connection.raw_connection

pg.async_exec <<SQL
drop table if exists topics
SQL

pg.async_exec <<SQL
CREATE TABLE topics (
    id integer NOT NULL,
    title character varying NOT NULL
)
SQL

class Topic < ActiveRecord::Base
end

def count_pools
  Topic.first
  pools = ObjectSpace.each_object(ActiveRecord::ConnectionAdapters::ConnectionPool).count
  puts "There is/are #{pools} connection pool/s"
end

count_pools

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


unless ENV['__ALREADY_FORKED']
  ENV['__ALREADY_FORKED'] = true.to_s
  fork do
    count_pools
    begin
      count_pools
      3.times do
        GC.start(full_mark: true, immediate_sweep: true)
      end
      count_pools
      pools = ObjectSpace.each_object(ActiveRecord::ConnectionAdapters::ConnectionPool)
      pools.each do |pool|
        pool.drain(30, 30)
      end
    rescue => e
      puts "BOOM #{e}"
      puts e.backtrace
    end
  end
  Process.wait
end
