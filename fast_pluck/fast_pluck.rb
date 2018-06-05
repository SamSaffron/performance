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
  1000.times do |id|
    User.create!(id: id, name: "bob bob #{id}")
  end
end

Benchmark.ips do |b|
  b.report("fast pluck active record") do |count|
    while count > 0
      User.limit(1000).fast_pluck(:id)
      count -= 1
    end
  end
  b.report("active record") do |count|
    while count > 0
      User.limit(1000).pluck(:id)
      count -= 1
    end
  end
end

