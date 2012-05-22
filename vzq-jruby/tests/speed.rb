#!/usr/bin/env jruby
# -*- coding: iso-8859-1 -*-

require 'benchmark'

if false # loop speed test
  n = 50000000
  Benchmark.bmbm(10) { |bm|
    # times win! for is slower, and upto seems to call times
    bm.report('for') { for i in 1..n; a = "1"; end }
    bm.report('times') { n.times do   ; a = "1"; end }
    bm.report('upto') { 1.upto(n) do ; a = "1"; end }
  }
end

if false # misc speed test
  n = 1000000
  Benchmark.bmbm(10) { |bm|
    bm.report('defined') { n.times { defined?(@@cd) } }
    a = 1.1
    c = 0
    bm.report('floats') { n.times {
        a *= 1.02
        b = a.to_i
        c += b
        a -= 10 if a > 12
      } }
    bm.report('new') { n.times { Java.java.awt.Rectangle.new } } if defined?(Java)
  }
end

# TODO: find the fastest way to fill float buffer with 10k floats


# cassé, a debug
if true
  require 'main.rb'
  ExternalEnvironmentSetup.new(true)
  puts "$$=#{$$}"
  $LOAD_PATH << 'src/'
  require 'src/core/utils'
  n = 1000000
  bm.report('Point2D') { n.times { Point2D.new(2, 3) } }
  bm.report('V2I') { n.times { V2I.new(2, 3) } }
end
