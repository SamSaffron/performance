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
  end
end

# sam@arch fast_pluck % ruby fast_pluck.rb
# Warming up --------------------------------------
# fast pluck 1 items   927.000  i/100ms
#      pluck 1 items   770.000  i/100ms
# Calculating -------------------------------------
# fast pluck 1 items      6.554k (± 6.3%) i/s -     33.372k in   5.108559s
#      pluck 1 items      6.841k (±11.1%) i/s -     33.880k in   5.008220s
# Warming up --------------------------------------
# fast pluck 10 items   904.000  i/100ms
#     pluck 10 items   769.000  i/100ms
# Calculating -------------------------------------
# fast pluck 10 items      8.404k (± 9.5%) i/s -     42.488k in   5.111812s
#     pluck 10 items      7.036k (± 8.7%) i/s -     35.374k in   5.068965s
# Warming up --------------------------------------
# fast pluck 100 items   742.000  i/100ms
#    pluck 100 items   466.000  i/100ms
# Calculating -------------------------------------
# fast pluck 100 items      7.295k (± 2.9%) i/s -     37.100k in   5.090454s
#    pluck 100 items      4.679k (± 4.1%) i/s -     23.766k in   5.087828s
# Warming up --------------------------------------
# fast pluck 1000 items
#                      299.000  i/100ms
#   pluck 1000 items   119.000  i/100ms
# Calculating -------------------------------------
# fast pluck 1000 items
#                         2.807k (±11.8%) i/s -     14.053k in   5.107343s
#   pluck 1000 items      1.085k (± 7.5%) i/s -      5.474k in   5.070442s
# Warming up --------------------------------------
# fast pluck 10000 items
#                       48.000  i/100ms
#  pluck 10000 items    13.000  i/100ms
# Calculating -------------------------------------
# fast pluck 10000 items
#                       444.380  (±16.4%) i/s -      2.160k in   5.072202s
#  pluck 10000 items    137.700  (± 5.1%) i/s -    689.000  in   5.021911s
# sam@arch fast_pluck % ruby fast_pluck.rb
# Warming up --------------------------------------
# fast pluck 1 items   803.000  i/100ms
#      pluck 1 items   788.000  i/100ms
# Calculating -------------------------------------
# fast pluck 1 items      9.067k (± 2.2%) i/s -     45.771k in   5.050399s
#      pluck 1 items      8.001k (± 1.2%) i/s -     40.188k in   5.023479s
# Warming up --------------------------------------
# fast pluck 10 items   876.000  i/100ms
#     pluck 10 items   642.000  i/100ms
# Calculating -------------------------------------
# fast pluck 10 items      8.613k (± 4.4%) i/s -     43.800k in   5.095413s
#     pluck 10 items      7.512k (± 4.7%) i/s -     37.878k in   5.055772s
# Warming up --------------------------------------
# fast pluck 100 items   644.000  i/100ms
#    pluck 100 items   362.000  i/100ms
# Calculating -------------------------------------
# fast pluck 100 items      7.094k (± 3.0%) i/s -     36.064k in   5.088190s
#    pluck 100 items      4.626k (± 3.0%) i/s -     23.168k in   5.013261s
# Warming up --------------------------------------
# fast pluck 1000 items
#                      276.000  i/100ms
#   pluck 1000 items   114.000  i/100ms
# Calculating -------------------------------------
# fast pluck 1000 items
#                         2.801k (± 6.0%) i/s -     14.076k in   5.053027s
#   pluck 1000 items      1.174k (± 2.0%) i/s -      5.928k in   5.050410s
# Warming up --------------------------------------
# fast pluck 10000 items
#                       42.000  i/100ms
#  pluck 10000 items    13.000  i/100ms
# Calculating -------------------------------------
# fast pluck 10000 items
#                       421.343  (± 4.5%) i/s -      2.142k in   5.095367s
#  pluck 10000 items    128.693  (± 9.3%) i/s -    650.000  in   5.099353s
