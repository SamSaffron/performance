require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "pg"
  gem "activerecord", "7.0.4.2"
  gem "benchmark-ips"
end

require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: "test_db"
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
    def decode(string, tuple = nil, field = nil)
      if Rails.version >= "4.2.0"
        @caster ||= ActiveRecord::Type::DateTime.new
        @caster.type_cast_from_database(string)
      else
        ActiveRecord::ConnectionAdapters::Column.string_to_time string
      end
    end
  end

  class ActiveRecordTypeMap < PG::BasicTypeMapForResults
    def initialize(connection)
      super(connection)
      rm_coder 0, 1114
      add_coder RailsDateTimeDecoder.new(
                  name: "timestamp",
                  oid: 1114,
                  format: 0
                )
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
  def select_raw(arel, name = nil, binds = [], &block)
    arel = arel_from_relation(arel)
    sql, binds = to_sql_and_binds(arel, binds)
    execute_and_clear(sql, name, binds, &block)
  end

  def fast_pluck(*column_names)
    if loaded? &&
         (
           column_names.map(&:to_s) - @klass.attribute_names -
             @klass.attribute_aliases.keys
         ).empty?
      return records.pluck(*column_names)
    end

    if has_include?(column_names.first)
      relation = apply_join_dependency
      relation.pluck(*column_names)
    else
      relation = spawn

      relation.select_values = column_names

      klass
        .connection
        .select_raw(relation.arel) do |result, _|
          result.type_map = SqlBuilder.pg_type_map
          result.nfields == 1 ? result.column_values(0) : result.values
        end
    end
  end
end

User.transaction do
  10_000.times { |id| User.create!(id: id, name: "bob bob #{id}") }
end

if User.limit(10).order(:id).pluck(:id, :name) !=
     User.limit(10).order(:id).fast_pluck(:id, :name)
  raise "not equal"
end

[1, 10, 100, 1000, 10_000].each do |n|
  Benchmark.ips do |b|
    b.report("fast pluck #{n} items") do |count|
      while count > 0
        User.limit(n).fast_pluck(:id, :name)
        count -= 1
      end
    end
    b.report("pluck #{n} items") do |count|
      while count > 0
        User.limit(n).pluck(:id, :name)
        count -= 1
      end
    end
    b.compare!
  end
end

# sam@arch fast_pluck % ruby fast_pluck.rb
# Warming up --------------------------------------
#   fast pluck 1 items   744.000  i/100ms
#        pluck 1 items   786.000  i/100ms
# Calculating -------------------------------------
#   fast pluck 1 items      8.493k (± 5.6%) i/s -     42.408k in   5.010302s
#        pluck 1 items      7.364k (± 8.9%) i/s -     36.942k in   5.060554s

# Comparison:
#   fast pluck 1 items:     8493.3 i/s
#        pluck 1 items:     7364.3 i/s - same-ish: difference falls within error

# Warming up --------------------------------------
#  fast pluck 10 items   796.000  i/100ms
#       pluck 10 items   706.000  i/100ms
# Calculating -------------------------------------
#  fast pluck 10 items      8.645k (± 4.2%) i/s -     43.780k in   5.075225s
#       pluck 10 items      7.482k (± 3.2%) i/s -     37.418k in   5.006443s

# Comparison:
#  fast pluck 10 items:     8644.5 i/s
#       pluck 10 items:     7481.9 i/s - 1.16x  slower

# Warming up --------------------------------------
# fast pluck 100 items   579.000  i/100ms
#      pluck 100 items   443.000  i/100ms
# Calculating -------------------------------------
# fast pluck 100 items      7.111k (± 4.7%) i/s -     35.898k in   5.060275s
#      pluck 100 items      4.628k (± 3.1%) i/s -     23.479k in   5.078414s

# Comparison:
# fast pluck 100 items:     7111.3 i/s
#      pluck 100 items:     4627.9 i/s - 1.54x  slower

# Warming up --------------------------------------
# fast pluck 1000 items
#                        275.000  i/100ms
#     pluck 1000 items   114.000  i/100ms
# Calculating -------------------------------------
# fast pluck 1000 items
#                           2.739k (± 9.4%) i/s -     13.750k in   5.081272s
#     pluck 1000 items      1.152k (± 3.6%) i/s -      5.814k in   5.054777s

# Comparison:
# fast pluck 1000 items:     2739.2 i/s
#     pluck 1000 items:     1151.7 i/s - 2.38x  slower

# Warming up --------------------------------------
# fast pluck 10000 items
#                         41.000  i/100ms
#    pluck 10000 items    14.000  i/100ms
# Calculating -------------------------------------
# fast pluck 10000 items
#                         338.593  (±25.4%) i/s -      1.599k in   5.060325s
#    pluck 10000 items    110.440  (± 3.6%) i/s -    560.000  in   5.075306s

# Comparison:
# fast pluck 10000 items:      338.6 i/s
#    pluck 10000 items:      110.4 i/s - 3.07x  slower
