require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'activerecord', '5.2.0'
  gem 'benchmark-ips'
end

require 'active_record'
require 'benchmark/ips'

ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :database => "test_db"
)

pg = ActiveRecord::Base.connection.raw_connection

pg.async_exec <<SQL
drop table if exists users
SQL

pg.async_exec <<SQL
  create table users (
    id int primary key,
    name varchar(100)
  )
SQL

class User < ActiveRecord::Base
end

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def select_raw(arel, name = nil, binds = [], &block)
    arel = arel_from_relation(arel)
    sql, binds = to_sql_and_binds(arel, binds)
    execute_and_clear(sql, name, binds, &block)
  end
end

class SqlBuilder
  class RailsDateTimeDecoder < PG::SimpleDecoder
    def decode(string, tuple=nil, field=nil)
      @caster ||= ActiveRecord::Type::DateTime.new
      @caster.type_cast_from_database(string)
    end
  end

  class ActiveRecordTypeMap < PG::BasicTypeMapForResults
    def initialize(connection)
      super(connection)
      rm_coder 0, 1114
      add_coder RailsDateTimeDecoder.new(name: "timestamp", oid: 1114, format: 0)
      # we don't need deprecations
      self.default_type_map = PG::TypeMapInRuby.new
    end
  end

  def self.pg_type_map
    conn = ActiveRecord::Base.connection.raw_connection
    @typemap ||= ActiveRecordTypeMap.new(conn)
  end
end

class ActiveRecord::Relation
  def fast_pluck(*column_names)
    if loaded? && (column_names.map(&:to_s) - @klass.attribute_names - @klass.attribute_aliases.keys).empty?
      return records.fast_pluck(*column_names)
    end

    if has_include?(column_names.first)
      relation = apply_join_dependency
      relation.fast_pluck(*column_names)
    else
      enforce_raw_sql_whitelist(column_names)
      relation = spawn
      relation.select_values = column_names.map { |cn|
        @klass.has_attribute?(cn) || @klass.attribute_alias?(cn) ? arel_attribute(cn) : cn
      }

      klass.connection.select_raw(relation) do |result, _|
        result.type_map = SqlBuilder.pg_type_map
        result.nfields == 1 ? result.column_values(0) : result.values
      end
    end
  end
end

User.transaction do
  10000.times do |id|
    User.create!(id: id, name: "bob bob #{id}")
  end
end

[1,10,100,1000,10_000].each do |n|
  Benchmark.ips do |b|
    b.report("fast pluck #{n} items") do |count|
      while count > 0
        User.limit(n).fast_pluck(:id)
        count -= 1
      end
    end
    b.report("pluck #{n} items") do |count|
      while count > 0
        User.limit(n).pluck(:id)
        count -= 1
      end
    end
  end
end

# sam@ubuntu fast_pluck % ruby test.rb
# Warming up --------------------------------------
#   fast pluck 1 items   439.000  i/100ms
#        pluck 1 items   454.000  i/100ms
# Calculating -------------------------------------
#   fast pluck 1 items      4.518k (± 4.9%) i/s -     22.828k in   5.066392s
#        pluck 1 items      4.520k (± 5.5%) i/s -     22.700k in   5.038813s
# Warming up --------------------------------------
#  fast pluck 10 items   441.000  i/100ms
#       pluck 10 items   439.000  i/100ms
# Calculating -------------------------------------
#  fast pluck 10 items      4.212k (± 4.7%) i/s -     21.168k in   5.036280s
#       pluck 10 items      4.329k (± 3.8%) i/s -     21.950k in   5.077540s
# Warming up --------------------------------------
# fast pluck 100 items   394.000  i/100ms
#      pluck 100 items   338.000  i/100ms
# Calculating -------------------------------------
# fast pluck 100 items      4.026k (± 4.5%) i/s -     20.094k in   5.001355s
#      pluck 100 items      3.614k (± 4.9%) i/s -     18.252k in   5.062923s
# Warming up --------------------------------------
# fast pluck 1000 items
#                        225.000  i/100ms
#     pluck 1000 items   129.000  i/100ms
# Calculating -------------------------------------
# fast pluck 1000 items
#                           2.255k (± 3.5%) i/s -     11.475k in   5.093992s
#     pluck 1000 items      1.308k (± 3.7%) i/s -      6.579k in   5.036949s
# Warming up --------------------------------------
# fast pluck 10000 items
#                         50.000  i/100ms
#    pluck 10000 items    18.000  i/100ms
# Calculating -------------------------------------
# fast pluck 10000 items
#                         514.961  (± 3.9%) i/s -      2.600k in   5.056274s
#    pluck 10000 items    184.925  (± 3.8%) i/s -    936.000  in   5.067828s
#
