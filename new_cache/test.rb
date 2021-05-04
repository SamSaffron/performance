# frozen_string_literal: true

require 'benchmark/ips'
require 'mini_sql'

class Result < Array
  attr_reader :decorator_module

  def initialize(decorator_module = nil)
    @decorator_module = decorator_module
  end

  def marshal_dump
    [
      first.to_h.keys,
      map { |row| row.to_h.values },
      decorator_module,
    ]
  end

  def marshal_load(args)
    fields, values_rows, decorator_module = args

    @decorator_module = decorator_module

    materializer = Matrializer.build(fields)
    materializer.include(decorator_module) if decorator_module

    values_rows.each do |row_result|
      r = materializer.new
      fields.each_with_index do |f, col|
        r.instance_variable_set(:"@#{f}", row_result[col])
      end
      self << r
    end

    self
  end
end

class Matrializer < Array

  def self.build(fields, instance_eval_code = '')
    Class.new do
      attr_accessor(*fields)

      # AM serializer support
      alias :read_attribute_for_serialization :send

      def to_h
        r = {}
        instance_variables.each do |f|
          r[f.to_s.sub('@', '').to_sym] = instance_variable_get(f)
        end
        r
      end

      instance_eval(instance_eval_code)
    end
  end

end

class NewDeserializerCache

  DEFAULT_MAX_SIZE = 500

  def initialize(max_size = nil)
    @cache = {}
    @max_size = max_size || DEFAULT_MAX_SIZE
  end

  def materializer(result)
    key = result.fields

    # trivial fast LRU implementation
    materializer = @cache.delete(key)
    if materializer
      @cache[key] = materializer
    else
      materializer = @cache[key] = new_row_matrializer(result.fields)
      @cache.shift if @cache.length > @max_size
    end

    materializer
  end

  def materialize(result, decorator_module = nil)
    return [] if result.ntuples == 0

    cached_materializer = materializer(result)
    cached_materializer.include(decorator_module) if decorator_module

    r = Result.new(decorator_module)
    i = 0
    # quicker loop
    while i < result.ntuples
      r << cached_materializer.materialize(result, i)
      i += 1
    end
    r
  end

  private

  def new_row_matrializer(fields)
    i = 0
    while i < fields.length
      # special handling for unamed column
      if fields[i] == "?column?"
        fields[i] = "column#{i}"
      end
      i += 1
    end

    Matrializer.build(fields, <<~RUBY)
      def materialize(pg_result, index)
        r = self.new
        #{col = -1; fields.map { |f| "r.#{f} = pg_result.getvalue(index, #{col += 1})" }.join("; ")}
        r
      end
    RUBY
  end
end

PgResult =
  Struct.new(:rows) do
    def ntuples
      rows.size
    end

    def fields
      @fields ||= rows[0].keys
    end

    def getvalue(row_num, col_num)
      rows[row_num][fields[col_num]]
    end
  end

module TopicDecorator
  def permalink
    "#{id}-#{title}"
  end
end

topics =
  1000.times.map do |i|
    id = rand(1..9999)
    {
      id: id,
      title: "topic #{id}",
    }
  end
result = PgResult.new(topics)

Benchmark.ips do |r|
  r.report("current materializer") do |n|
    materializer = MiniSql::Postgres::DeserializerCache.new
    while n > 0
      materializer.materialize(result, TopicDecorator)
      n -= 1
    end
  end
  r.report("new  materializer") do |n|
    materializer = NewDeserializerCache.new
    while n > 0
      materializer.materialize(result, TopicDecorator)
      n -= 1
    end
  end
  r.compare!
end

# Comparison:
# current materializer:     1176.2 i/s
#    new  materializer:     1127.7 i/s - same-ish: difference falls within error
