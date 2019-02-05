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
  def fast_blank?
    false
  end

  def fast_present?
    true
  end
end


User.transaction do
  10.times do |id|
    User.create!(id: id, name: "bob bob #{id}")
  end
end

first_user = User.first
new_user = User.new

puts User.first.present?
# true
puts User.new.present?
# true

Benchmark.ips do |b|
  b.report("fast present") do |count|
    while count > 0
      new_user.fast_present?
      count -= 1
    end
  end

  b.report("fast present 2") do |count|
    while count > 0
      first_user.fast_present?
      count -= 1
    end
  end

  b.report("slow present") do |count|
    while count > 0
      new_user.present?
      count -= 1
    end
  end

  b.report("slow present 2") do |count|
    while count > 0
      first_user.present?
      count -= 1
    end
  end

  b.compare!
end

# Calculating -------------------------------------
#         fast present     25.253M (± 7.8%) i/s -    125.427M in   5.003929s
#       fast present 2     24.623M (± 6.5%) i/s -    122.722M in   5.007818s
#         slow present    335.003k (± 5.5%) i/s -      1.692M in   5.065919s
#       slow present 2    275.213k (± 5.5%) i/s -      1.385M in   5.047741s
#
# Comparison:
#         fast present: 25253295.0 i/s
#       fast present 2: 24623199.7 i/s - same-ish: difference falls within error
#         slow present:   335003.0 i/s - 75.38x  slower
#       slow present 2:   275212.8 i/s - 91.76x  slower

