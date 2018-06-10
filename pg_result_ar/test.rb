# frozen_string_literal: true
# tiny rerunner (I use this on local to rerun script)
# require_relative '../rerunner/rerunner.rb'

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

  1000.times do |id|
    topic[:id] = id
    Topic.create!(topic)
  end
end

# introduce the patches
puts "patching"

module ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements
  alias_method :exec_query_orig, :exec_query

  def self.switch_exec_query(type)
    alias_method :exec_query, "exec_query_#{type}"
  end

  def exec_query_new(sql, name = "SQL", binds = [], prepare: false)
    execute_and_clear(sql, name, binds, prepare: prepare) do |result|
      # ideally we want to avoid this
      types = {}
      fields = result.fields
      fields.each_with_index do |fname, i|
        ftype = result.ftype i
        fmod  = result.fmod i
        types[fname] = get_oid_type(ftype, fmod, fname)
      end

      ActiveRecord::ConnectionAdapters::PostgreSQL::Result.new(result, types)
    end
  end

  switch_exec_query :new
end


class ActiveModel::AttributeSet::Builder
  alias_method :build_from_database_orig, :build_from_database

  def self.switch_build_from_database(type)
    alias_method :build_from_database, "build_from_database_#{type}"
  end

  def build_from_database_new(values = {}, additional_types = {})
    FakeSet.new values
  end

  switch_build_from_database :new

  class FakeSet
    def initialize(values)
      @values = values
    end

    def fetch_value(key)
      if block_given?
        @values.fetch(key.to_s) { yield }
      else
        @values[key.to_s]
      end
    end
  end
end

module ActiveRecord::ConnectionAdapters::PostgreSQL
  class Result
    include Enumerable

    attr_reader :column_types

    def length
      @rows.length
    end

    def each
      if block_given?
        i = 0
        while i < @rows.length
          yield @rows[i]
          i += 1
        end
      else
        data.to_enum { length }
      end
    end


    def initialize(pg_result, types)
      @rows = materialize(pg_result)
      @column_types = types
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

ten_topics_select
top_1000_wasteful
# exit
#
# MemoryProfiler.report do
#   ten_topics_select
# end.pretty_print
#
# exit

Benchmark.ips do |x|
  x.report("top 10 id / title PG bypass") do |i|
    while i > 0
      ten_topics_select
      i -= 1
    end
  end

  x.report("top 1000 id wasteful PG bypass") do |i|
    while i > 0
      top_1000_wasteful
      i -= 1
    end
  end
end

ActiveModel::AttributeSet::Builder.switch_build_from_database :orig

Benchmark.ips do |x|
  x.report("top 10 id / title PG bypass (only on result)") do |i|
    while i > 0
      ten_topics_select
      i -= 1
    end
  end

  x.report("top 1000 id wasteful PG bypass (only on result)") do |i|
    while i > 0
      top_1000_wasteful
      i -= 1
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements.switch_exec_query :orig

Benchmark.ips do |x|
  x.report("top 10 id / title (original)") do |i|
    while i > 0
      ten_topics_select
      i -= 1
    end
  end

  x.report("top 1000 id wasteful PG bypass (original)") do |i|
    while i > 0
      top_1000_wasteful
      i -= 1
    end
  end
end


# Calculating -------------------------------------
# top 10 id / title PG bypass
#                           3.602k (± 5.6%) i/s -     18.228k in   5.076349s
# top 1000 id wasteful PG bypass
#                         100.849  (± 3.0%) i/s -    510.000  in   5.061416s
# Warming up --------------------------------------
# top 10 id / title PG bypass (only on result)
#                        338.000  i/100ms
# top 1000 id wasteful PG bypass (only on result)
#                          8.000  i/100ms
# Calculating -------------------------------------
# top 10 id / title PG bypass (only on result)
#                           3.244k (± 4.6%) i/s -     16.224k in   5.011384s
# top 1000 id wasteful PG bypass (only on result)
#                          87.386  (± 3.4%) i/s -    440.000  in   5.041214s
# Warming up --------------------------------------
# top 10 id / title (original)
#                        314.000  i/100ms
# top 1000 id wasteful PG bypass (original)
#                          7.000  i/100ms
# Calculating -------------------------------------
# top 10 id / title (original)
#                           3.188k (± 5.6%) i/s -     16.014k in   5.039289s
# top 1000 id wasteful PG bypass (original)
#                          76.448  (± 3.9%) i/s -    385.000  in   5.042256s
#
