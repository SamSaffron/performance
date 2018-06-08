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


unless ENV['__ALREADY_FORKED']
  ENV['__ALREADY_FORKED'] = true
  fork do
    count_pools
  end
  Process.wait
end
