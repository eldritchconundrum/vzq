# -*- coding: iso-8859-1 -*-

#TODO: use this
class GameObject # component-based design: aggregation of features, not inheritance
  def update(*args)
    for component in @components
      component.update(*args)
    end
  end
end


# Entities add some game logic to sprites

#TODO: @scala_entity = Java.vzq.engine.EntityBase.new

# déplacer classes entities vers le modèle shmup

# à voir, l'idée des hotspot de rubygame

# à faire en premier : approche "components" pour avoir un seul GameObject.

# ou bien... d'abord les specs et le bugtracker ? :)


class Entity
  attr_accessor :tags, :life, :revolutions_per_second, :traj
  attr_reader :sprite

  def has_tag?(tag)
    @tags.include?(tag)
  end
  def dead?
    @life <= 0
  end
  def to_s
    "%s at %s" % [tags.inspect, self.center]
  end

  def initialize(sprite, position_or_traj)
    @revolutions_per_second = 2
    @sprite = sprite
    fail 'nil pos_or_traj' if position_or_traj.nil?
    if position_or_traj.respond_to?(:position)
      @traj = position_or_traj
      self.center = Point2D.new(0, 0)
    else
      @traj = nil
      self.center = position_or_traj
    end
  end

  def center
    sprite.center
  end
  def center=(value)
    @sprite.center = value
  end
  def pos
    sprite.pos
  end

  def update_traj(time)
    unless @traj.nil?
      self.center = @traj.position(time)
    end
  end

  def collision_box # this function is what really slows down collision detection now
    p, s = @sprite.center - @sprite.display_size / 2, @sprite.display_size
    [p.x.to_i, p.y.to_i, s.x.to_i, s.y.to_i]
    #[(p.x + s.x * 0.1).to_i, (p.y + s.y * 0.1).to_i, (s.x * 0.8).to_i, (s.y * 0.8).to_i]
    #a, b = rand(1000), rand(1000); return [a, b, 5, 5] # fast
  end
end

class Enemy < Entity
end

class Guile < Enemy
  def life=(value) # Guile's rotation speed is calculated from his current life%
    @life = value
    @max_life ||= 1
    @max_life = [@life, @max_life].max
    self.revolutions_per_second = -0.75 * (5 - 4 * @life * 1.0 / @max_life)
    self.revolutions_per_second = -0.75 / ((@life + 1.0) / @max_life)
  end
end

class Ship < Entity
  def move(dp)
    c = self.center + dp
    # ship must stay on screen
    s = self.sprite.display_size
    x = [[c.x, s.x / 2].max, EngineConfig.ortho.x - s.x / 2].min
    y = [[c.y, s.y / 2].max, EngineConfig.ortho.y - s.y / 2].min
    self.center = Point2D.new(x, y)
  end
  def firing_pos
    return self.center + V2I.new(0, -sprite.display_size.y*0.5)
  end
end

class Shot < Entity
  attr_accessor :damage, :dot
end

class Explosion < Entity
  def initialize(*args)
    super(*args)
    @sprite.anim_loop = false
  end
  def dead?
    @sprite.current_texture.nil?
  end
end


# optimization. I could use a list, but searching everytime makes 'tagged' slow.
# so use hash tables to keep entities indexed by tags.
# 'tagged' is called every frame, 'entities add/remove' are not.
# ... OR ARE THEY? (offscreen shot autoremove)

require 'set'
class EntitiesSet # store entities with fast 'by tag' access
  include Enumerable # uses 'each'
  def initialize
    @list = []
    @lists_by_tag_list = Hash.new { |h,tags| h[tags] = @list.find_all { |e| matches(tags, e) } }
    reset_stats
  end
  def each(*args, &block)
    @list.each(*args, &block)
  end
  def clear
    @lists_by_tag_list.clear
  end
  def size
    @list.size
  end
  def add_list(args)
    args.each { |item| add(item) }
  end
  def remove_list(args)
    args.each { |item| remove(item) }
  end
  def add(item)
#    Engine.profiler.prof(:entities_set1) do
      @stats_add += 1
      @list << item
      @lists_by_tag_list.each { |tags,list| list << item if matches(tags, item) }
#    end
  end
  def remove(item)
#    Engine.profiler.prof(:entities_set2) do
      @stats_del += 1
      @list.delete(item)
      # this assumes tag list never changes after the entity is added!
      for tags, list in @lists_by_tag_list do
        list.delete(item) if matches(tags, item)
      end
#    end
  end
  def tagged(*tags) # tagged(:enemy, :boss) returns entities tagged :enemy or :boss or both
#    Engine.profiler.prof(:entities_set_tagged) do
      @lists_by_tag_list[tags].clone
#    end
  end
  def to_s
    self.map { |e| e.tags }.flatten.uniq.map { |tag| '%s %s' % [self.tagged(tag).size, tag] } * "\n"
  end
  def stats
    "%s added, %s removed" % [@stats_add, @stats_del]
  end
  def reset_stats
    @stats_add, @stats_del = 0, 0
  end
  private
  def matches(tags, item)
    tags.any? { |t| item.has_tag?(t) }
  end
end

# essayer de passer vers scala l'indexation des entities (et l'accès aux coordonnées)
# comme ça les trajs et les écriture de VBO pourront passer aussi en scala.
#   -> definir une interface scala-able d'EntitiesSet, etc.

