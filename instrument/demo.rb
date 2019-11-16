# frozen_string_literal: true
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'activesupport', path: '../../rails/activesupport'
  gem 'benchmark-ips'
end

require 'active_support'

class NotificationSubscriber
  def self.add_instrument(klass, method, name)
    @instruments ||= {}
    @instruments[name] = { klass: klass, method: method }
  end

  def self.subscribe(name, &blk)

    info = @instruments[name]
    raise "nothing to subscribe to" if !info

    patch = <<~RUBY
      alias_method #{info[:method]}, #{info[:method]}_orig
      def #{info[:method]}(a: )
        #{info[:method]}_orig(a: a)

        @instrument
      end
    RUBY

    info[:klass].class_eval patch

  end
end

module Kernel
  def instrument(method, name)
    NotificationSubscriber.add_instrument(self, method, name)
  end
end

class Test
  instrument(:foo, 'abc/test')
  def empty_v2(a:)
  end

  def empty(a:)
  end

  def empty_as(a:)
    ActiveSupport::Notifications.instrument("abc/test", a: a) do |x|
    end
  end
end

NotificationSubscriber.subscribe('abc/test') do |x|
  p x
end

ActiveSupport::Notifications.subscribe("abc/test") do |x|
end

class Test
  #p instance_method(:foo).parameters
end

t = Test.new

t.empty_v2(a: 1)
exit

Benchmark.ips do |x|
  x.report("empty") do |times|
    while times > 0
      t.empty(a: 1)
      times -= 1
    end
  end

  x.report("empty_as") do |times|
    while times > 0
      t.empty_as(a: 1)
      times -= 1
    end
  end

end
