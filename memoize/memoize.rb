require_relative '../rerunner/rerunner'
require 'benchmark/ips'

module Memoizer
  def self.KEY(*args, **kwargs)
    [args, kwargs]
  end

  def memoize_26(method_name)
    cache = {}

    uncached = "#{method_name}_without_cache"
    alias_method uncached, method_name

    m = (define_method(method_name) do |*arguments|
      found = true
      data = cache.fetch(arguments) { found = false }
      unless found
        cache[arguments] = data = public_send(uncached, *arguments)
      end
      data
    end)

    if Module.respond_to?(:ruby2_keywords, true)
      ruby2_keywords(m)
    end
  end

  def memoize_27(method_name)
    cache = {}

    uncached = "#{method_name}_without_cache"
    alias_method uncached, method_name

    define_method(method_name) do |*args, **kwargs|
      found = true
      all_args = [args, kwargs]
      data = cache.fetch(all_args) { found = false }
      unless found
        cache[all_args] = data = public_send(uncached, *args, **kwargs)
      end
      data
    end
  end

  def memoize_27_v3(method_name)
    cache = "MEMOIZE2_#{method_name}"

    uncached = "#{method_name}_without_cache"
    alias_method uncached, method_name

    class_eval <<~RUBY
      #{cache} = {}
      def #{method_name}(...)
        found = true
        args = Memoizer.KEY(...)
        data = #{cache}.fetch(args) { found = false }
        unless found
          #{cache}[args] = data = #{uncached}(...)
        end
        data
      end
    RUBY
  end

  def memoize_27_v2(method_name)
    uncached = "#{method_name}_without_cache"
    alias_method uncached, method_name

    cache = "MEMOIZE_#{method_name}"

    params = instance_method(method_name).parameters
    has_kwargs = params.any? {|t, name| "#{t}".start_with? "key"}
    has_args = params.any? {|t, name| !"#{t}".start_with? "key"}

    args = []

    args << "args" if has_args
    args << "kwargs" if has_kwargs

    args_text = args.map do |n|
      n == "args" ? "*args" : "**kwargs"
    end.join(",")

    class_eval <<~RUBY
      #{cache} = {}
      def #{method_name}(#{args_text})
        found = true
        all_args = #{args.length === 2 ? "[args, kwargs]" : args[0]}
        data = #{cache}.fetch(all_args) { found = false }
        unless found
          #{cache}[all_args] = data = public_send(:#{uncached} #{args.empty? ? "" : ", #{args_text}"})
        end

        data
      end
    RUBY

  end

end

module Methods
  def args_only(a, b)
    sleep 0.1
    "#{a} #{b}"
  end

  def kwargs_only(a:, b: nil)
    sleep 0.1
    "#{a} #{b}"
  end

  def args_and_kwargs(a, b:)
    sleep 0.1
    "#{a} #{b}"
  end
end

class OldMethod
  extend Memoizer
  include Methods

  memoize_26 :args_and_kwargs
  memoize_26 :args_only
  memoize_26 :kwargs_only
end

class NewMethod
  extend Memoizer
  include Methods

  memoize_27 :args_and_kwargs
  memoize_27 :args_only
  memoize_27 :kwargs_only
end

class OptimizedMethod
  extend Memoizer
  include Methods

  memoize_27_v2 :args_and_kwargs
  memoize_27_v2 :args_only
  memoize_27_v2 :kwargs_only
end

class Optimized2
  extend Memoizer
  include Methods

  memoize_27_v3 :args_and_kwargs
  memoize_27_v3 :args_only
  memoize_27_v3 :kwargs_only
end

methods = [
  OldMethod.new,
  NewMethod.new,
  OptimizedMethod.new,
  Optimized2.new
]

Benchmark.ips do |x|
  x.warmup = 1
  x.time = 2

  methods.each do |m|
    x.report("#{m.class} args only") do |times|
      while times > 0
        m.args_only(10, b: 10)
        times -= 1
      end
    end

    x.report("#{m.class} kwargs only") do |times|
      while times > 0
        m.kwargs_only(a: 10, b: 10)
        times -= 1
      end
    end

    x.report("#{m.class} args and kwargs") do |times|
      while times > 0
        m.args_and_kwargs(10, b: 10)
        times -= 1
      end
    end
  end

  x.compare!
end


# # Ruby 2.6.5
# #
# OptimizedMethod args only:   974266.9 i/s
#  OldMethod args only:   949344.9 i/s - 1.03x  slower
# OldMethod args and kwargs:   945951.5 i/s - 1.03x  slower
# OptimizedMethod kwargs only:   939160.2 i/s - 1.04x  slower
# OldMethod kwargs only:   868229.3 i/s - 1.12x  slower
# OptimizedMethod args and kwargs:   751797.0 i/s - 1.30x  slower
#  NewMethod args only:   730594.4 i/s - 1.33x  slower
# NewMethod args and kwargs:   727300.5 i/s - 1.34x  slower
# NewMethod kwargs only:   665003.8 i/s - 1.47x  slower
#
# #
# # Ruby 2.7.1
#
# OptimizedMethod kwargs only:  1021707.6 i/s
# OptimizedMethod args only:   955694.6 i/s - 1.07x  (± 0.00) slower
# OldMethod args and kwargs:   940911.3 i/s - 1.09x  (± 0.00) slower
#  OldMethod args only:   930446.1 i/s - 1.10x  (± 0.00) slower
# OldMethod kwargs only:   858238.5 i/s - 1.19x  (± 0.00) slower
# OptimizedMethod args and kwargs:   773773.5 i/s - 1.32x  (± 0.00) slower
# NewMethod args and kwargs:   772653.3 i/s - 1.32x  (± 0.00) slower
#  NewMethod args only:   771253.2 i/s - 1.32x  (± 0.00) slower
# NewMethod kwargs only:   700604.1 i/s - 1.46x  (± 0.00) slower

