#!/usr/bin/env jruby
# -*- coding: iso-8859-1 -*-

require 'main.rb'
ExternalEnvironmentSetup.new(true)

puts "$$=#{$$}"
require 'src/collision_detection'
require 'benchmark'

class Entity
  attr_accessor :collision_box, :sprites
  def initialize(box)
    @sprites = ['foo']
    @collision_box = box
  end
end

$coll = []
def test(cd_class)
  coll = 0
  $n.times {
    cd = cd_class.new($entities)
    cd.test($ents1, $ents2) { |e1, e2| coll += 1 }
    cd.test($ents1, $ents3) { |e1, e2| coll += 1 }
  }
  $coll << coll
end

# je devrais arrêter de profiler ça dans la VM...
# de toute façon le test en live en regardant les FPS, c'est mieux

$n = 60 * 3

# "normal" conditions (detectors are optimised for few collisions)
Benchmark.bmbm(40) { |bm|
  $entity_count = 300
  $entities = Array.new($entity_count) {
    a, b = rand(700), rand(500)
    Entity.new([a, b, a + rand(50) + 1, b + rand(50) + 1])
  }
  $ents1, $ents2, $ents3 = [], [], []
  $entities.each_with_index { |e, i|
    $ents1 << e if i > 100 and i % 3 != 0
    $ents2 << e if i < 100
    $ents3 << e if i < 5
  }
  bm.report('ruby colli') { test(CollisionDetection::RubyRectCollisionDetector) }
  bm.report('scala colli') { test(CollisionDetection::ScalaRectCollisionDetector) }
  bm.report('java colli') { test(CollisionDetection::JavaRectCollisionDetector) }
}
for coll in $coll
  puts "collisions: %s / %s = %s" % [coll, $n, coll * 1.0 / $n]
end

# RubyRectCollisionDetectoris actually faster in the degenerate case when all entities collide
