require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'activesupport'#, path: '../../rails/activesupport'
  gem 'activerecord'#, path: '../../rails/activerecord'
  gem 'activemodel'#, path: '../../rails/activemodel'
  gem 'memory_profiler'
  gem 'benchmark-ips'
  # gem 'helix_runtime'
  # gem 'rails_fast_attributes', path: '../../rails_fast_attributes'
end

require 'active_record'
require 'memory_profiler'
require 'benchmark/ips'
# require 'rails_fast_attributes'

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
    title character varying NOT NULL,
    last_posted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    user_id integer,
    last_post_user_id integer NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    featured_user1_id integer,
    featured_user2_id integer,
    featured_user3_id integer,
    avg_time integer,
    deleted_at timestamp without time zone,
    highest_post_number integer DEFAULT 0 NOT NULL,
    image_url character varying,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    category_id integer,
    visible boolean DEFAULT true NOT NULL,
    moderator_posts_count integer DEFAULT 0 NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    bumped_at timestamp without time zone NOT NULL,
    has_summary boolean DEFAULT false NOT NULL,
    vote_count integer DEFAULT 0 NOT NULL,
    archetype character varying DEFAULT 'regular'::character varying NOT NULL,
    featured_user4_id integer,
    notify_moderators_count integer DEFAULT 0 NOT NULL,
    spam_count integer DEFAULT 0 NOT NULL,
    pinned_at timestamp without time zone,
    score double precision,
    percent_rank double precision DEFAULT 1.0 NOT NULL,
    subtype character varying,
    slug character varying,
    deleted_by_id integer,
    participant_count integer DEFAULT 1,
    word_count integer,
    excerpt character varying(1000),
    pinned_globally boolean DEFAULT false NOT NULL,
    pinned_until timestamp without time zone,
    fancy_title character varying(400),
    highest_staff_post_number integer DEFAULT 0 NOT NULL,
    featured_link character varying
)
SQL

class Topic < ActiveRecord::Base
end


Topic.transaction do
  topic = {
  }
  Topic.columns.each do |c|
    topic[c.name.to_sym] = case c.type
                           when :integer then 1
                           when :datetime then Time.now
                           when :boolean then false
                           else "HELLO WORLD" * 2
                           end
  end

  1000.times do |id|
    topic[:id] = id
    Topic.create!(topic)
  end
end

$conn = ActiveRecord::Base.connection.raw_connection

class FastBase

  class Relation
    include Enumerable

    def initialize(table)
      @table = table
    end

    def limit(limit)
      @limit = limit
      self
    end

    def to_sql
      sql = +"SELECT #{@table.columns.join(',')} from #{@table.get_table_name}"
      if @limit
        sql << -" LIMIT #{@limit}"
      end
      sql
    end

    def each
      @results = $conn.async_exec(to_sql)
      i = 0
      while i < @results.cmd_tuples
        row = @table.new
        row.attach(@results, i)
        yield row
        i += 1
      end
    end

  end

  def self.columns
    @columns
  end

  def attach(recordset, row_number)
    @recordset = recordset
    @row_number = row_number
  end

  def self.get_table_name
    @table_name
  end

  def self.table_name(val)
    @table_name = val
    load_columns
  end

  def self.load_columns
    @columns = $conn.async_exec(<<~SQL).column_values(0)
      SELECT COLUMN_NAME FROM information_schema.columns
      WHERE table_schema = 'public' AND
        table_name = '#{@table_name}'
    SQL

    @columns.each_with_index do |name, idx|
      class_eval <<~RUBY
        def #{name}
          if @recordset && !@loaded_#{name}
            @loaded_#{name} = true
            @#{name} = @recordset.getvalue(@row_number, #{idx})
          end
          @#{name}
        end

        def #{name}=(val)
          @loaded_#{name} = true
          @#{name} = val
        end
      RUBY
    end
  end

  def self.limit(number)
    Relation.new(self).limit(number)
  end
end

class Topic2 < FastBase
  table_name :topics
end

def magic
  a = []
  Topic2.limit(1000).each do |t|
    a << t.id
  end
  a
end

def ar
  a = []
  Topic.limit(1000).each do |u|
    a << u.id
  end
  a
end

def ar_select
  a = []
  Topic.select(:id).limit(1000).each do |u|
    a << u.id
  end
  a
end

def ar_pluck
  Topic.limit(1000).pluck(:id)
end

def raw_all
  sql = -"select * from topics limit 1000"
  ActiveRecord::Base.connection.raw_connection.async_exec(sql).column_values(0)
end

def raw
  sql = -"select id from topics limit 1000"
  ActiveRecord::Base.connection.raw_connection.async_exec(sql).column_values(0)
end

def test(method)
  puts
  puts "-"*50
  puts method.to_s
  puts "-"*50
  send method

  MemoryProfiler.report do
    send method
  end.pretty_print(detailed_report: false, retained_strings: false, allocated_strings: false)
end


tests = %i{
  magic
  ar
  ar_select
  ar_pluck
  raw
  raw_all
}

ar
  MemoryProfiler.report do
    ar
  end.pretty_print

exit

tests.each do |t|
  test t
end

Benchmark.ips do |b|
  tests.each do |t|
    b.report(t.to_s) do |i|
      while i > 0
        send t
        i -= 1
      end
    end
  end
end

# to run deep analysis run
# MemoryProfiler.report do
#   ar
# end.pretty_print

