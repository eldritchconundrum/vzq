require 'utils'

# TODO: make a shoot'em-up-specific layer between this game and GameBase

# BUG: collision detection does not support the zoom factor;
# also, don't check the sprite rectangle, just check a small circle around the center

# Entities add some game logic to sprites
class Entity
  attr_accessor :pos, :movement, :frame_index, :tags, :rect, :life # TODO: move some entity state elsewhere?
  def initialize(sprite, movement = nil)
    @sprite, @movement = sprite, movement
    @pos = @sprite.pos unless @sprite.nil?
    @pos = @movement.pos(0) unless @movement.nil?
    # corriger décentrement des origines des sprites (tir, ennemi, boss, etc) (à cause de center et de la traj)
    # -> affecter la pos initiale à LinearTraj dans ce ctor si elle est nil
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

# idée : jouer deux vaisseaux dans 2 moitiés d'écran en synchronisé
# (ce serait ça le gameplay du jeu) avec des tirs différents à éviter dans chaque

class Shot < Entity
  attr_accessor :damage, :dot
end

# TODO: test dynamically background size with screen size and tile it nicely
class Background < Entity
  def initialize(pos, sprite_creator)
    super(nil)
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

# optimization. I could use a list, but
# searching everytime makes 'tagged' slow, so use hash tables to keep entities indexed by tags
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

class Profiling # TODO: move to generic_game; reuse this instead of other profiling code
  def initialize
    @p = Hash.new(0) # time profiling (ms)
    @last = Utils.get_time
  end
  def prof(tag, &block)
    @p[tag] += Utils.time(&block)
  end
  def show
    now = Utils.get_time
    duration, @last = (now - @last), now
    @p.each { |k,v| @p[k] = ((v * 1000.0 / duration)*100).round/100.0 }
    groups = @p.group_by { |k,v| k.to_s.match(/^[^_]*_/).to_s }
    s = ''
    groups.each { |group_key, kv_list|
      s += "%s* = %s\n" % [group_key, kv_list.transpose[1].inject(0) {|a,b|a+b} ]
      kv_list.each { |kv| s += "\t%s\t= %s\n" % kv }
    }
    #s = @p.map{ |k,v| "#{k}=#{v}" }.join(' ')
    @p.clear
    s
  end
end

# TODO: déplacer logique de mouvement (dx/dy) hors entity pour qu'elle puisse être définie par une simple fonction du temps
# TODO: move animation logic (texture change) into the entities and out of sprite (not its business, unless it also handles the timing, which it doesn't)



class Trajectory
  def initialize(pos)
    @time_origin = Utils.get_time
    @pos_origin = pos
  end
  def elapsed_ms
    Utils.get_time - @time_origin
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
  def pos(delta)
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
  def pos(delta)
    elapsed_ms = Utils.get_time - @time_origin
    orthog_vect = Point2D.new(-@movement_vector.y, @movement_vector.x)
    return @pos_origin + (@movement_vector * elapsed_ms.to_f / 100.0) +
      (orthog_vect * (Math.sin(@frequency * elapsed_ms.to_f * Math::PI / 500) * @amplitude))
  end
end

require 'generic_game'
class ShootEmUp < GameBase # TODO: move pause logic to base class? and clean up pause and autoplay
  attr_accessor :entities
  def initialize
    super()
    @prof = Profiling.new
    @entities = EntitiesSet.new
    @paused = false
    @autoplay = true
    @fire_spread = 0
    # use ElapsedTimeWait to enforce a mandatory delay between player actions
    @fire_wait = ElapsedTimeWait.new { ShootEmUpConfig.fire_rate }
    @fire2_wait = ElapsedTimeWait.new { ShootEmUpConfig.fire_rate * 50 }
    @fire_spread_change_wait = ElapsedTimeWait.new { ShootEmUpConfig.fire_rate }
    # use wait_manager to trigger game events at regular intervals (in no particular order)
    @wait_manager.add(:log_entities) { 5000 }
    @wait_manager.add(:add_random_aliens) { 1000 }
    @wait_manager.add(:animate_sprites) { ShootEmUpConfig.alien_frame_duration }
    @wait_manager.add(:make_aliens_fire) { ShootEmUpConfig.alien_fire_rate }
    @wait_manager.add(:add_bonus1) { ShootEmUpConfig.bonus_wait }
    @wait_manager.add(:add_bonus2) { ShootEmUpConfig.bonus_wait }
    @player = PlayerInfo.new
    init_state
  end

  def next_frame(isDisplayActive, delta)
    @paused = true if !isDisplayActive
    player_actions = nil
    @prof.prof(:input) { player_actions = process_input }
    @prof.prof(:logic) { change_state(delta, player_actions) }
    @prof.prof(:draw) { draw(delta) }
#    @prof.prof(:gc) { GC.start } if @frame_count%20==0 # quand soudain, c'est le drame
  end

  private


  def init_state
    add_ship
    @entities << Background.new(Point2D.new(-300, 0), lambda { get_sprite(ShootEmUpConfig.bg_moon) }).with(:tags => [:background])
#    @entities << Background.new(Point2D.new(0, 0), lambda {
#                                  get_sprite(NoiseTextureDesc.new(Point2D.new(400, 300)))
#                                }).with(:tags => [:background])
  end

  # --- WaitManager events begin ---
  def log_entities
    if $VERBOSE
      # TODO: generalize the profiling thing to GameBase
      puts(@prof.show.gsub(/^/, '  '))
      puts("  frame %s: %s entities" % [@frame_count, @entities.size])
      puts('  ' + @entities.to_s)
    end
  end

  def add_random_aliens
    n = 7
    case (rand(35) / 10.0).to_i
    when 0 then j, speed = 1, 2
    when 1 then j, speed = 2, 3
    when 2 then j, speed = 3, 4
    else # boss
      @entities << get_new_alien(Point2D.new(EngineConfig.ortho.x.to_f * 0.5, -50), Point2D.new(0, 5), true)
      return
    end
    @entities << get_new_alien(Point2D.new(EngineConfig.ortho.x.to_f * j / n, -50), Point2D.new(0, speed))
    j = n - j
    @entities << get_new_alien(Point2D.new(EngineConfig.ortho.x.to_f * j / n, -50), Point2D.new(0, speed))
  end

  def make_aliens_fire
    @entities.tagged(:alien).each { |alien|
      next if rand > 0.01
      create_shot = proc { |speed, angle, char|
        spri = get_sprite(TextTextureDesc.new(char, 32, RGBA[0, 255, 255, 255])).with(:center => alien.pos + alien.size / 2)
        mv = Point2D.new(speed * Math.cos(angle), speed * Math.sin(angle))
        Shot.new(spri,
                 LinearTraj.new(spri.pos, mv)
                 ).with(:tags => [:shot, :enemy_shot, :rotating])
      }
      if alien.has_tag?(:boss)
        if rand > (1 - 0.02 * @entities.count {|e| e.has_tag?(:ship) })
          dot = 2 ** @entities.count {|e| e.has_tag?(:ship) }
          (0..9).each { |i| @entities << create_shot.call(10, Math::PI * (i + 0.5) / 10, 'LOLOLOL').with(:dot => dot) }
        elsif rand < 0.5
          (0..10).each { |i| @entities << create_shot.call(10, Math::PI * i / 10, '+').with(:damage => 30) }
        else
          (0..9).each { |i| @entities << create_shot.call(10, Math::PI * (i + 0.5) / 10, '¤').with(:damage => 35) }
        end
      end
      @entities << create_shot.call(10, rand * 100, 'o').with(:damage => 30)
    }
  end

  def animate_sprites
    @entities.each { |e| e.sprites.each { |s| s.current_frame += 1 } }
  end

  def add_bonus1
    return if @player.fire_level >= 5
    direction = rand < 0.5
    pos = Point2D.new(direction ? 0 : EngineConfig.ortho.x, 10+rand*EngineConfig.ortho.y/3)
    @entities << Entity.new(get_sprite(TextTextureDesc.new('$', 24, RGBA[255, 128, 255, 255])).
                            with(:center => pos),
                            LinearTraj.new(pos, Point2D.new((direction ? 1 : -1) * ShootEmUpConfig.ship_move_speed, 0))
                            ).with(:tags => [:bonus, :fire_bonus])
  end

  def add_bonus2
    direction = rand < 0.5
    pos = Point2D.new(direction ? 0 : EngineConfig.ortho.x, 10+rand*EngineConfig.ortho.y/3)
    @entities << Entity.new(get_sprite(TextTextureDesc.new('£', 24, RGBA[255, 255, 255, 255])).
                            with(:center => pos),
                            LinearTraj.new(pos, Point2D.new((direction ? 1 : -1) * ShootEmUpConfig.ship_move_speed, 0))
                            ).with(:tags => [:bonus, :life_bonus])
  end

  # --- WaitManager events end ---

  def get_new_alien(pos, movement, is_boss = false)
    movement = SinusoidalTraj.new(pos, movement, is_boss ? 4 : 0, 0.5)
    alien = Entity.new(get_sprite(*ShootEmUpConfig.alien_anim).with(:center => pos), movement).with(:life => 25, :tags => [:alien])
    if is_boss
      alien.tags << :boss
      alien.sprites.first.zoom = 2.0
      alien.pos = Point2D.new(EngineConfig.ortho.x.to_f * 0.5, -50) - alien.sprites.first.size
      alien.life *= 20
    end
    return alien
  end
  def add_ship
    @entities << Entity.new(get_sprite(ShootEmUpConfig.sprite_ship).with(:center => Point2D.new(400, 500))).with(:life => 100, :tags => [:ship])
  end

  def process_input
    player_actions = PlayerActions.new
    keyboard_events = super
    keyboard_events.each { |char, isDown, key|
      if isDown
        case key
        when Keyboard::KEY_P, Keyboard::KEY_PAUSE then @paused ^= true
        when Keyboard::KEY_F5 then add_ship
        when Keyboard::KEY_F6 then add_random_aliens
        end
      end
    }
    player_actions.left_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_LEFT)
    player_actions.right_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_RIGHT)
    player_actions.up_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_UP)
    player_actions.down_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_DOWN)
    player_actions.fire_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_SPACE)
    player_actions.fire2_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_RETURN)

    @autoplay = @paused && EngineConfig.debug # pratique pour tester en codant, et propre : on simule l'input du joueur
    if @autoplay
      player_actions.right_pressed = (Utils.get_time.to_i % 7000) < 5000
      player_actions.left_pressed = (Utils.get_time.to_i % 5000) > 2000
      player_actions.fire_pressed = (Utils.get_time.to_i % 5000) % 3000 > 500
    end
    return player_actions
  end
  class PlayerActions
    def initialize
      @fire_pressed, @fire2_pressed, @left_pressed, @right_pressed, @up_pressed, @down_pressed = false, false, false, false, false, false
    end
    attr_accessor :fire_pressed, :fire2_pressed, :left_pressed, :right_pressed, :up_pressed, :down_pressed
    attr_accessor :movement
  end

  class PlayerInfo # nommage : mouaif
    attr_accessor :fire_level
    def initialize
      reset
    end
    def reset
      @fire_level = 1
    end
  end

  def do_damage(shot, ent, delta)
    ent.life -= shot.dot * delta / 30.0 unless shot.dot.nil?
    unless shot.damage.nil? || @shot_has_damaged_someone_already.has_key?(shot)
      ent.life -= shot.damage
      @shot_has_damaged_someone_already[shot] = true
    end
  end

  def process_collisions(delta)
    @shot_has_damaged_someone_already = {}
    cd = RectCollisionDetector.new(@entities)
    cd.test(@entities.tagged(:player_shot), @entities.tagged(:alien)) { |shot, alien|
      do_damage(shot, alien, delta)
    }
    cd.test(@entities.tagged(:enemy_shot), @entities.tagged(:ship)) { |shot, ship|
      next if @autoplay
      do_damage(shot, ship, delta)
    }
    cd.test(@entities.tagged(:ship), @entities.tagged(:alien)) { |ship, alien|
      next if @autoplay
      unless ship.dead? || alien.dead?
        damage = [ship.life, alien.life].min
        ship.life -= damage
        alien.life -= damage
      end
    }
    cd.test(@entities.tagged(:ship), @entities.tagged(:bonus)) { |ship, bonus|
      if bonus.has_tag?(:life_bonus)
        @entities.tagged(:ship).each { |s| s.life += 42 }
      else
        @player.fire_level += 1
      end
      @entities.remove(bonus)
    }
    cd.test(@entities.tagged(:enemy_shot), @entities.tagged(:arrobase_shot)) { |enemy_shot, arrobase_shot|
      @entities.remove(enemy_shot)
    }
    @entities.remove(@shot_has_damaged_someone_already.keys) # remove used shots
  end

  def shoot1
    @fire_spread = 1 - @fire_spread if @fire_spread_change_wait.is_over_auto_reset
    @entities.tagged(:ship).each { |ship|
      speed = -1.1 * ShootEmUpConfig.ship_move_speed
      shots = []
      case @fire_spread
      when 0
        shots << [Point2D.new(ship.size.x*0.5, 0), Point2D.new(0, speed)] if @player.fire_level % 2 == 1
        shots << [Point2D.new(ship.size.x*0.5, 10), Point2D.new(-7, speed)] if @player.fire_level / 2 >= 2
        shots << [Point2D.new(ship.size.x*0.5, 10), Point2D.new(7, speed)] if @player.fire_level / 2 >= 2
      when 1
        shots << [Point2D.new(ship.size.x*0.5, 5), Point2D.new(-3, speed)] if @player.fire_level / 2 >= 1
        shots << [Point2D.new(ship.size.x*0.5, 5), Point2D.new(3, speed)] if @player.fire_level / 2 >= 1
      end
      shots = shots.collect { |shot| p1, p2 = *shot
        sprite = get_sprite(ShootEmUpConfig.sprite_shot).with(:center => ship.pos + p1)
        Shot.new(sprite, LinearTraj.new(sprite.pos, p2)).with(:damage => 5, :tags => [:shot, :player_shot])
      }
      @entities << shots
    }
  end

  def shoot2
    multiplier = defined?(@last_fire2_time) ? (Utils.get_time - @last_fire2_time) / @fire2_wait.duration : 1
    @last_fire2_time = Utils.get_time
    damage = 1.2 * multiplier # gameplay: must be just less than enough to kill a simple alien
    desc = TextTextureDesc.new('@', 32 * (1 + Math.log(multiplier)), RGBA[255, 255, 0, 255])
    @entities.tagged(:ship).each { |ship|
      sprite = get_sprite(desc).with(:center => ship.pos + Point2D.new(ship.size.x*0.5, 0))
      @entities << Shot.new(sprite, LinearTraj.new(sprite.pos, Point2D.new(0, -10))).
      with(:dot => damage,
           :tags => [:shot, :arrobase_shot, :player_shot, :rotating])
    }
  end

  def change_state(delta, player_actions) # TODO: cleanup game logic
    @prof.prof(:logic_colli) { process_collisions(delta) }
    @prof.prof(:logic_events) { @wait_manager.run_events }
    if !@paused || @autoplay
      @prof.prof(:logic_misc) {
        # process player actions
        pdx = (player_actions.right_pressed ? 1 : 0) - (player_actions.left_pressed ? 1 : 0)
        pdy = (player_actions.down_pressed ? 1 : 0) - (player_actions.up_pressed ? 1 : 0)
        player_movement = Point2D.new(pdx, pdy) * ShootEmUpConfig.ship_move_speed
        unless player_movement.nil?
          dp = player_movement * delta.to_f / 100
          @entities.tagged(:ship).each { |ship|
            ship.pos += dp
            ship.pos.x = [[ship.pos.x, 0].max, EngineConfig.ortho.x - ship.size.x].min # ship must stay on screen
            ship.pos.y = [[ship.pos.y, 0].max, EngineConfig.ortho.y - ship.size.y].min
          }
        end
        shoot1 if player_actions.fire_pressed && @fire_wait.is_over_auto_reset
        shoot2 if player_actions.fire2_pressed && @fire2_wait.is_over_auto_reset

        # mais je suis bete, y'a qu'à gérer ça avec rectcollisiondetection
        if @frame_count % 10 == 0 # peu urgent, et cpu-intensif (sur mon portable)
          # remove some off screen entities
          @entities.remove(@entities.tagged(:shot, :alien, :bonus).find_all { |e|
                             margin = e.size.x + e.size.y + 50
                             x, y = e.pos.x, e.pos.y
                             x < -margin || x > EngineConfig.ortho.x + margin ||
                             y < -margin || y > EngineConfig.ortho.y + margin
                           })
        end
        @entities.remove(@entities.tagged(:alien, :ship).find_all { |alien| alien.dead? })
        @entities.each { |e| e.pos = e.movement.pos(delta) unless e.movement.nil? }
        @entities.tagged(:rotating).each { |e| e.sprites.each { |s| s.angle += delta / 2.0 } }
      }
    end
  end

  def draw(delta)
    # draw sprites
    sprites = nil
    @prof.prof(:draw_sort) { sprites = @entities.collect { |e| e.sprites }.flatten.sort_by { |sprite| sprite.z_order } }
    sprites.each { |sprite|
      @prof.prof(:draw_sprites) {
        sprite.refresh_textures if false # not so slow, but a little
        sprite.draw
      }
    }
    # then HUD on top
    @prof.prof(:draw_hud) {
      items = @entities.tagged(:ship).collect { |s| "%s HP" % (s.life > 9000 ? 'over 9000' : s.life) }
      write_list(items, lambda { |i| Point2D.new(20, 20 + i * 20) }, 25)
      write_centered('-- paused%s --' % (@autoplay ? ' (autoplay)' : ''), EngineConfig.ortho / 2, 32) if @paused
    }
  end
end
