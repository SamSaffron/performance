# frozen_string_literal: true

require 'active_support'

class NotificationSubscriber
  def self.add_instrument(klass, method, name)
    @subscriptions ||= {}
    @subscriptions[name] = {klass: klass, method: method}
  end

  def self.subscribe(name, &blk)
  end
end

module Kernel
  def instrument(method, name)
    NotificationSubscriber.add_instrument(self, method, name)
  end
end

class Test
  instrument(:foo, 'abc/test')
  def foo(a, b: , c: 1, &blk)
    1
  end

  def foo2
    ActiveSupport::Notifications.instrument("abc/test", a: 1) do |x|
      p x
      1
    end
  end
end

NotificationSubscriber.subscribe('abc/test') do |x|
  p x
end

ActiveSupport::Notifications.subscribe("abc/test") do |*x|
  p x
end

Test.new.foo2

class Test
  p instance_method(:foo).parameters
end





