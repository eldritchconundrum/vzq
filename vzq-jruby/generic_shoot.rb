require 'utils'

# Entities add some game logic to sprites
class Entity
  # à voir, l'idée des hotspot de rubygame
  attr_accessor :pos, :movement, :tags, :rect, :life
  def initialize(sprite, movement = nil)
    @sprite, @movement = sprite, movement
    @pos = @sprite.pos
    unless @movement.nil?
      @movement.pos_origin = @pos
    end
  end
  def sprites
    @sprite.pos = @pos
    return [@sprite]
  end
  def size # the first sprite is supposed to be the 'main' sprite, for purposes such as collision checking (FIXME)
    sprites.first.size * sprites.first.zoom
  end
  def has_tag?(tag); @tags.include?(tag); end
  def dead?; @life <= 0; end
  def to_s; "[%s]" % tags; end
end

class Shot < Entity
  attr_accessor :damage, :dot
end

# TODO: test dynamically background size with screen size and tile it nicely
class Background < Entity
  def initialize(pos, sprite_creator)
    @pos = pos
    @movement = LinearTraj.new(@pos, Point2D.new(0, ShootEmUpConfig.background_speed))
    @sprites = [sprite_creator.call, sprite_creator.call]
    @sprites.each { |s| s.z_order = -1 }
  end
  def sprites
    @pos.y %= @sprites[0].size.y
    @sprites[0].pos = @pos
    @sprites[1].pos = Point2D.new(@pos.x, @pos.y - @sprites[0].size.y)
    return @sprites
  end
end

# optimization. I could use a list, but searching everytime makes 'tagged' slow.
# so use hash tables to keep entities indexed by tags.
# 'tagged' is called every frame, 'entities add/remove' are not.
class EntitiesSet # store entities with fast 'by tag' access
  include Enumerable # uses 'each'
  def initialize
    @list = []
    @lists_by_tag_list = Hash.new { |h,tags| h[tags] = @list.find_all { |e| matches(tags, e) } }
  end
  def size; @list.size; end
  def <<(arg); add(arg); end
  def add(*arg); arg = Utils.array_from_varargs(arg); arg.each { |item| add_internal(item) }; end
  def remove(*arg); arg = Utils.array_from_varargs(arg); arg.each { |item| remove_internal(item) }; end
  def each(*args, &block); @list.each(*args, &block); end
  def tagged(*tags) # tagged(:alien, :boss) returns entities tagged :alien or :boss or both
    @lists_by_tag_list[tags].clone
  end
  def to_s
    self.collect { |e| e.tags }.flatten.uniq.collect { |tag| '%s %s' % [tag, self.tagged(tag).size] }.join(', ')
  end
  private
  def matches(tags, item); tags.any? { |t| item.has_tag?(t) }; end
  def add_internal(item)
    @list << item
    @lists_by_tag_list.each { |tags,list| list << item if matches(tags, item) }
  end
  def remove_internal(item)
    @list.delete(item)
    @lists_by_tag_list.each { |tags,list| list.delete(item) if matches(tags, item) }
    # this assumes tags don't change!
  end
end


# BUG: collision detection does not support zoom factor or angle

class RectCollisionDetector # works only with rectangles, does not support rotation
  def initialize(entities) # items in list need to have 'pos' and 'size'
    @rects = {}
    entities.each { |e|
      next if e.sprites.empty?
      rect = java.awt.Rectangle.new
      rect.set_bounds(e.pos.x.to_i, e.pos.y.to_i, e.size.x, e.size.y)
      @rects[e] = rect
    }
  end
  def test(list1, list2, &block) # items in list1/list2 must exist in 'entities'
    list1.each { |e1| list2.each { |e2| block.call(e1, e2) if @rects[e1].intersects(@rects[e2]) } }
  end
end

# TODO: support different types of collision detection, customize bounds, center of sprite, distance-based, etc.

class CenterDistanceCollisionDetector
  def initialize(entities, distance) # items in list need to have 'pos' and 'size'
    @sqr_distance = distance ** 2
    @center = {}
    entities.each { |e|
      next if e.sprites.empty?
      @center[e] = e.pos + e.size / 2
    }
  end
  def test(list1, list2, &block) # items in list1/list2 must exist in 'entities'
    list1.each { |e1| list2.each { |e2| block.call(e1, e2) if (@center[e1] - @center[e2]).sqr_dist < @sqr_distance } }
  end
end


# TODO: move animation logic (texture change) into the entities and out of sprite? (not its business, unless it also handles the timing, which it doesn't)


class Trajectory # abstract
  def initialize(pos = nil)
    @time_origin = Utils.get_time
    @pos_origin = pos
  end
  attr_accessor :pos_origin
  def elapsed_ms
    Utils.get_time - @time_origin # TODO: get_time: don't bash, cache?
  end
  def pos # returns a Point2D
    fail 'abstract'
  end
end

class LinearTraj < Trajectory
  def initialize(pos, movement_vector)
    super(pos)
    @movement_vector = movement_vector
  end
  def pos
    @pos_origin + @movement_vector * (elapsed_ms.to_f / 100)
  end
end

class SinusoidalTraj < Trajectory
  # amplitude is a factor of the given movement vector, 1 means a 45° maximum angle    #TODO: no it doesn't, yet.
  # freq is in Hz
  def initialize(pos, movement_vector, amplitude = 1, frequency = 1)
    super(pos)
    @movement_vector, @amplitude, @frequency = movement_vector, amplitude, frequency
  end
  def pos
    orthog_vect = Point2D.new(-@movement_vector.y, @movement_vector.x)
    return @pos_origin + (@movement_vector * elapsed_ms.to_f / 100.0) +
      (orthog_vect * (Math.sin(@frequency * elapsed_ms.to_f * Math::PI / 500) * @amplitude))
  end
end

require 'generic_game'
class ShootEmUpBase < GameBase
  def initialize
    super()
    @prof = Profiling.new # TODO: generalize the profiling thing to GameBase
    @entities = EntitiesSet.new
    @paused = false
    @wait_manager.add(:log_entities) { 5000 }
  end
  protected
  def log_entities
    if $VERBOSE # lookup runtime options settable in menudebug
      puts(@prof.show.gsub(/^/, '  '))
      puts("  frame %s: %s entities" % [@frame_count, @entities.size])
      puts('  ' + @entities.to_s)
    end
  end

end
