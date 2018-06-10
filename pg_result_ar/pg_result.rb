# frozen_string_literal: true
# tiny rerunner (I use this on local to rerun script)
require_relative '../rerunner/rerunner.rb'

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'activesupport'#, path: '../../rails/activesupport'
  gem 'activerecord'#, path: '../../rails/activerecord'
  gem 'activemodel'#, path: '../../rails/activemodel'
  gem 'memory_profiler'
  gem 'benchmark-ips'
  #gem 'helix_runtime'
  #gem 'rails_fast_attributes', path: '../../rails_fast_attributes'
end

require 'active_record'
require 'memory_profiler'
require 'benchmark/ips'
#require 'rails_fast_attributes'


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

  2000.times do |id|
    topic[:id] = id
    Topic.create!(topic)
  end
end


module ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements
  alias_method :exec_query_orig, :exec_query

  def self.switch_exec_query(type)
    alias_method :exec_query, "exec_query_#{type}"
  end

  def exec_query_new(sql, name = "SQL", binds = [], prepare: false)

    result = nil
    if without_prepared_statement?(binds)
      result = exec_no_cache(sql, name, [])
    elsif !prepare
      result = exec_no_cache(sql, name, binds)
    else
      result = exec_cache(sql, name, binds)
    end
    ActiveRecord::ConnectionAdapters::PostgreSQL::Result.new(result, self)
  end

  switch_exec_query :new
end

module ActiveRecord::ConnectionAdapters::PostgreSQL
  class Result
    include Enumerable

    def column_types
      @column_types ||=
        begin
          types = {}
          fields = @pg_result.fields
          fields.each_with_index do |fname, i|
            ftype = @pg_result.ftype i
            fmod  = @pg_result.fmod i
            # need to make get_oid_type public
            types[fname] = @adapter.send :get_oid_type, ftype, fmod, fname
          end
          types
        end
    end

    def length
      @length ||= @pg_result.cmd_tuples
    end

    def each
      if block_given?
        i = 0
        while i < length
          yield @pg_result[i]
          i += 1
        end
      else
        @pg_result.to_enum { length }
      end
    end

    def cast_values(type_overrides = {})
      if @pg_result.nfields == 1
        @pg_result.column_values(0)
      else
        @pg_result.values
      end
    end

    def last
      return nil if length == 0
      @pg_result[length-1]
    end

    def first
      return nil if length == 0
      @pg_result[0]
    end

    def initialize(pg_result, adapter)
      @pg_result = pg_result
      @adapter = adapter
    end

    def rows
      # hmmm why do we need this?
      @rows ||= @pg_result.values
    end

    protected

    def materialize(result)
      data = []
      rows = result.cmd_tuples
      i = 0
      while i < rows
        data << result[i]
        i += 1
      end
      data
    end
  end
end


def ten_topics_select
  r = []
  Topic.limit(10).select(:id, :title).each do |t|
    r << t.id
    r << t.title
  end
  r
end

def top_1000_wasteful
  a = []
  Topic.limit(1000).each do |t|
    a << t.id
  end
  a
end

def pluck(n)
  Topic.limit(n).pluck(:id, :title)
end

#
# MemoryProfiler.report do
#   ten_topics_select
# end.pretty_print
#
# exit

def fast_mode(v)
  return if $fast_mode == v
  if !v
    ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements.switch_exec_query :orig
    $fast_mode = false
  else
    ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements.switch_exec_query :new
    $fast_mode = true
  end
end

Benchmark.ips do |x|
  [true, false].each do |mode|
    x.report("top 10 id / title PG: fast mode: #{mode}") do |i|
      fast_mode(mode)
      while i > 0
        ten_topics_select
        i -= 1
      end
    end
  end

  x.compare!
end

Benchmark.ips do |x|
  [true, false].each do |mode|
    x.report("top 1000 id wasteful: fast mode: #{mode} ") do |i|
      fast_mode(mode)
      while i > 0
        top_1000_wasteful
        i -= 1
      end
    end
  end

  x.compare!
end

Benchmark.ips do |x|
  [true, false].each do |mode|
    x.report("pluck 1000 mode: #{mode} ") do |i|
      fast_mode(mode)
      while i > 0
        pluck(1000)
        i -= 1
      end
    end
  end

  x.compare!
end
