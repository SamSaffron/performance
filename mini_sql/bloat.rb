# frozen_string_literal: true
# tiny rerunner (I use this on local to rerun script)
require_relative '../rerunner/rerunner.rb'

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'mini_sql'
  gem 'activesupport'#, path: '../../rails/activesupport'
  gem 'activerecord'#, path: '../../rails/activerecord'
  gem 'activemodel'#, path: '../../rails/activemodel'
end

require 'active_record'
require 'mini_sql'

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: "test_db"
)

pg = ActiveRecord::Base.connection.raw_connection

def allocs(name)
  s = GC.stat
  yield
  delta = GC.stat[:total_allocated_objects] - s[:total_allocated_objects]
  puts "#{name} #{delta}"
end

allocs("raw first create") do
  pg.exec 'create temp table tests(id int, name int)'
  pg.exec 'insert into tests values(1, 1)'
end

class Test < ActiveRecord::Base
end

allocs("AR first") do
  Test.first.name
end

p pg.type_map_for_results

allocs("MiniSQL first") do
  cnn = MiniSql::Connection.get(pg)
  cnn.query("select * from tests")
end
