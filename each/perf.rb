#!/usr/bin/env ruby -w
require "benchmark"

TIMES = 100_000
ARRAY = (1..1_000).to_a

10.times do

  Benchmark.bm(30) do |b|

    b.report "each" do
      TIMES.times do |i|
        t = 0
        ARRAY.each do |element|
          t = element
        end
      end
    end

    b.report "for ... in" do
      TIMES.times do |i|
        t = 0
        for x in ARRAY
          t = x
        end
      end
    end

    b.report "for ... in 0..limit" do
      TIMES.times do |i|
        limit = ARRAY.size - 1
        t = 0
        for i in 0..limit
          t = ARRAY[i]
        end
      end
    end

    b.report "while i <ARRAY.size" do
      TIMES.times do |i|
        t = 0
        i = 0
        while i < ARRAY.size
          t = ARRAY[i]
          i += 1
        end
      end
    end

    b.report "while i <limit" do
      TIMES.times do |i|
        limit = ARRAY.size
        t = 0
        i = 0
        while i < limit
          t = ARRAY[i]
          i += 1
        end
      end
    end
    
  end
  
end
