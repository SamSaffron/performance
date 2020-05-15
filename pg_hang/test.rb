require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg', '1.2.2'
  gem 'rails', path: '../../rails'
  #gem 'rails', '6.0.2.1'
end

config = <<~CONF
  development:
    adapter: postgresql
    database: discourse_development
    pool: 10
CONF

ENV['RAILS_ENV'] = "development"
require 'active_record'

ActiveRecord::Base.configurations = ActiveRecord::DatabaseConfigurations.new(YAML::load(config))

class Car < ActiveRecord::Base
end

class CarMigration < ActiveRecord::Migration[6.0]
  def change
    create_table :cars do |t|
      t.string :name
      t.timestamps
    end
  end
end

ActiveRecord::Base.establish_connection(:development)

begin
  CarMigration.new.migrate(:up)
rescue ActiveRecord::StatementInvalid
end

$max_time = 10

Thread.new do
  begin
    while true
      Thread.list.each do |t|
        if (time = t["t"]) && time < Time.now - ($max_time)
          puts "Thread #{t} appears stalled"
        end
      end
      sleep 1
    end
  rescue => e
    STDERR.puts "Crashed monitor #{e}"
    exit 1
  end
end

Car.first
ActiveRecord::Base.clear_active_connections!

$iterations = 0

(0...5).map do
  Thread.new do
    while true
      #ActiveRecord::Base.establish_connection(:development)
      Thread.current["t"] = Time.now

      begin
        Car.columns
        Car.first
      rescue => e
        print "*"
      end

      schema_cache = ActiveRecord::Base.connection.schema_cache
      sleep rand / 100

      begin
        if ActiveRecord::Base.connection.object_id != schema_cache.object_id
          print "Y"
        end
        schema_cache.clear!
      rescue => e
        p e
        print "X"
      end

      if ($iterations += 1) % 1000 == 0
        puts "#{$iterations} done"
      end
    end
  end
end.each(&:join)
