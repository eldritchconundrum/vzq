# -*- coding: undecided -*-
# depends on the vzq jar

module CollisionDetection
  # BUG? : collision detection does not support zoom factor or angle

  def collision_detectors
    CollisionDetection.constants.find_all { |c| c.to_s.match(/CollisionDetector$/)}
  end

  # RectCollisionDetectors interface :
  # * works only with rectangles, does not support rotation
  # * elements in 'entities' list need to have 'sprite' and 'collision_box' and 'has_tag?'
  # * elements in list1/list2 must exist in 'entities'

  class RubyRectCollisionDetector
    def initialize(entities)
      @rects = {}
      entities.each { |e|
        next if e.sprite.nil? || e.has_tag?(:no_collision)
        rect = Java.java.awt.Rectangle.new
        rect.set_bounds(*e.collision_box)
        @rects[e] = rect
      }
      #puts_rect @rects[entities.last]
    end
    def test(list1, list2, &block)
      #puts "colli: %s / %s" % [list1.size, list2.size] if list1.size * list2.size > 1000 && rand < 0.1
      list1.each { |e1| list2.each { |e2| block.call(e1, e2) if @rects[e1].intersects(@rects[e2]) } }
    end

    def puts_rect(rect)
      puts "%s %s %s %s" % [rect.x, rect.y, rect.width, rect.height]
    end
  end

  class FastRectCollisionDetector
    def initialize(entities, cd) # TODO: all the time is spent in here. implement a batch "set_rect"?
      @cd = cd
      @@c ||= 0
      @@c += 1
      if @@c % 5 == 0 # heuristic: throw away old entities, but not everytime
        @cd.clear
      end

      entities.each { |e|
        next if e.sprite.nil? || e.has_tag?(:no_collision)
        @cd.set_rect(e, *e.collision_box)
      }
    end
    def test(list1, list2, &block)
      #puts "colli: %s / %s" % [list1.size, list2.size] if list1.size * list2.size > 1000 && rand < 0.1
      invert = list1.size > list2.size
      list1, list2 = list2, list1 if invert
      pairs = @cd.detect(list1.to_a.to_java, list2.to_a.to_java).to_a
      e1 = nil
      if invert then
        pairs.each { |e| if e1.nil? then e1 = e else block.call(e, e1); e1 = nil; end }
      else
        pairs.each { |e| if e1.nil? then e1 = e else block.call(e1, e); e1 = nil; end }
      end
    end
  end

  class ScalaRectCollisionDetector < FastRectCollisionDetector
    def initialize(entities)
      @@cd ||= Java.vzq.engine.ScalaRectCollisionDetectorImpl.new
      super(entities, @@cd)
    end
  end

  class JavaRectCollisionDetector < FastRectCollisionDetector
    def initialize(entities)
      super(entities, Java.vzq.engine.JavaRectCollisionDetectorImpl)
    end
  end

  # TODO: support different types of collision detection, customize
  # bounds, center of sprite, distance-based, etc.

end
