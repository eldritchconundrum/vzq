# BUG: collision detection does not support the zoom factor; also, don't check the sprite rectangle, just check a small circle around the center

# Entities add some game logic to sprites
class Entity
  attr_accessor :pos, :movement, :frame_index, :tags, :rect, :life # TODO: move some entity state elsewhere?
  def initialize(sprite, movement = nil)
    @sprite, @movement = sprite, movement
    @pos = @sprite.pos unless @sprite.nil?
    @pos = @movement.pos(0) if @movement.is_a?(Trajectory)
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

# TODO: test dynamically background size with resolution and tile it nicely
class Background < Entity
  def initialize(pos, sprite_creator)
    super(nil)
    @pos = pos
    @sprites = [sprite_creator.call, sprite_creator.call]
    @sprites.each { |s| s.z_order = -1 }
  end
  def sprites
    @movement = Point2D.new(0, ShootEmUpConfig.background_speed)
    @sprites[0].pos = @pos
    @sprites[1].pos = @pos.clone
    @sprites[1].pos.y = @pos.y - @sprites[0].size.y
    @pos.y -= @sprites[0].size.y if @pos.y > EngineConfig.ortho.y # alter state
    return @sprites
  end
end

# optimization. I could use a list, but
# searching everytime makes 'tagged' slow, so use hash tables to keep entities indexed by tags
# 'tagged' is called every frame, 'entities add/remove' are not.
class EntitiesSet
  include Enumerable # uses 'each'
  def initialize
    @list = []
    @lists_by_tag_list = Hash.new { |h,tags| h[tags] = @list.find_all { |e| matches(tags, e) } }
  end
  def size; @list.size; end
  def <<(arg); add(arg); end
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

# TODO: faire une mini-classe autour de ça
$p = Hash.new(0) # time profiling (ms)


# TODO: déplacer logique de mouvement (dx/dy) hors entity pour qu'elle puisse être définie par une simple fonction du temps
# TODO: move animation logic (texture change) into the entities and out of sprite (not its business, unless it also handles the timing, which it doesn't)



class Trajectory # il faudrait que ça lag moins
  def initialize(pos)
    @time_origin = Utils.get_time
    @pos_origin = pos
  end
  def pos
    elapsed_ms = Utils.get_time - @time_origin
    Point2D.new(0, 2 * elapsed_ms / 100)
  end
end

class LinearTraj < Trajectory
  def initialize(pos, movement_vector)
    super(pos)
    @movement_vector = movement_vector
  end
  def pos(delta)
    elapsed_ms = Utils.get_time - @time_origin
    @pos_origin + @movement_vector * (10 * elapsed_ms / 1000)
  end
end

class PlayerInfo # mouaif
  attr_accessor :spread_level
  def initialize
    reset
  end
  def reset
    @spread_level = 1
  end
end

class GameBase; end # forward decl for reloading
class ShootEmUp < GameBase # TODO: move pause logic to base class? and clean up pause and autoplay
  include Renewable
  attr_accessor :entities
  def initialize
    super()
    @entities = EntitiesSet.new
    @frame_count = 0
    @paused = false
    @autoplay = true
    @fire_spread = 0
    # use ElapsedTimeWait to enforce a mandatory delay between player actions
    @can_fire_wait = ElapsedTimeWait.new { ShootEmUpConfig.fire_rate }
    @can_fire2_wait = ElapsedTimeWait.new { ShootEmUpConfig.fire_rate * 50 }
    @fire_spread_change_wait = ElapsedTimeWait.new { ShootEmUpConfig.fire_rate }
    # use wait_manager to trigger game events at regular intervals (in no particular order)
    @wait_manager.add(:log_entities) { 5000 }
    @wait_manager.add(:add_random_aliens) { 1000 }
    @wait_manager.add(:animate_sprites) { ShootEmUpConfig.alien_frame_duration }
    @wait_manager.add(:make_aliens_fire) { ShootEmUpConfig.alien_fire_rate }
    @wait_manager.add(:add_bonus) { ShootEmUpConfig.bonus_wait }
    @player = PlayerInfo.new
    init_state
  end

  def nextFrame(isDisplayActive, delta)
    @paused = true if !isDisplayActive
    player_actions = nil
    $p[:input] += Utils.time { player_actions = process_input }
    $p[:change_state] += Utils.time { change_state(delta, player_actions) }
    $p[:draw] += Utils.time { draw(delta) }
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
      puts('  ' + $p.map{ |k,v| "#{k}=#{v}" }.join(' ')) # TODO: generalize the profiling thing to GameBase ; affichage en arbre
      puts("  frame %s: %s entities" % [@frame_count, @entities.size])
      puts('  ' + @entities.to_s)
      $p.clear
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
        Shot.new(spri,
                 Point2D.new(speed * Math.cos(angle), speed * Math.sin(angle))
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

  def add_bonus
    return if @player.spread_level >= 5
    direction = rand < 0.5
    pos = Point2D.new(direction ? 0 : EngineConfig.ortho.x, 10+rand*EngineConfig.ortho.y/3)
    @entities << Entity.new(get_sprite(TextTextureDesc.new('$', 24, RGBA[255, 128, 255, 255])).
                            with(:center => pos),
                            LinearTraj.new(pos, Point2D.new((direction ? 1 : -1) * ShootEmUpConfig.ship_move_speed, 0))
                            ).with(:tags => [:bonus])
  end

  # --- WaitManager events end ---

  def get_new_alien(pos, movement, is_boss = false)
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
    cd = CollisionDetector.new(@entities)
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
      @player.spread_level += 1
      @entities.remove(bonus)
    }
    cd.test(@entities.tagged(:enemy_shot), @entities.tagged(:arrobase_shot)) { |enemy_shot, arrobase_shot|
      @entities.remove(enemy_shot)
    }
    @entities.remove(@shot_has_damaged_someone_already.keys) # remove used shots
  end

  def change_state(delta, player_actions) # TODO: cleanup game logic
    @frame_count += 1

    $p[:cs_colli] += Utils.time { process_collisions(delta) }
    $p[:cs_events] += Utils.time { @wait_manager.run_events }
    $p[:cs_misc] += Utils.time {
      if !@paused || @autoplay
        # process player actions
        @entities.tagged(:ship).each { |ship|
          e = ship
          ship.movement = Point2D.new(0, 0)
          ship.movement.x += ShootEmUpConfig.ship_move_speed if player_actions.right_pressed
          ship.movement.x -= ShootEmUpConfig.ship_move_speed if player_actions.left_pressed
          ship.movement.y += ShootEmUpConfig.ship_move_speed if player_actions.down_pressed
          ship.movement.y -= ShootEmUpConfig.ship_move_speed if player_actions.up_pressed
        }
        if player_actions.fire_pressed && @can_fire_wait.is_over_auto_reset
          @fire_spread = 1 - @fire_spread if @fire_spread_change_wait.is_over_auto_reset
          @entities.tagged(:ship).each { |ship|
            speed = -1.1 * ShootEmUpConfig.ship_move_speed
            shots = []
            case @fire_spread
            when 0
              shots << [Point2D.new(ship.size.x*0.5, 0), Point2D.new(0, speed)] if @player.spread_level % 2 == 1
              shots << [Point2D.new(ship.size.x*0.5, 10), Point2D.new(-7, speed)] if @player.spread_level / 2 >= 2
              shots << [Point2D.new(ship.size.x*0.5, 10), Point2D.new(7, speed)] if @player.spread_level / 2 >= 2
            when 1
              shots << [Point2D.new(ship.size.x*0.5, 5), Point2D.new(-3, speed)] if @player.spread_level / 2 >= 1
              shots << [Point2D.new(ship.size.x*0.5, 5), Point2D.new(3, speed)] if @player.spread_level / 2 >= 1
            end
            shots = shots.collect { |shot| p1, p2 = *shot
              sprite = get_sprite(ShootEmUpConfig.sprite_shot).with(:center => ship.pos + p1)
              Shot.new(sprite, p2).with(:damage => 5, :tags => [:shot, :player_shot])
            }
            @entities << shots
          }
        end
        if player_actions.fire2_pressed && @can_fire2_wait.is_over_auto_reset
          multiplier = defined?(@last_fire2_time) ? (Utils.get_time - @last_fire2_time) / @can_fire2_wait.duration : 1
          @last_fire2_time = Utils.get_time
          damage = 1.2 * multiplier # gameplay: must be just less than enough to kill a simple alien
          @entities.tagged(:ship).each { |ship|
            # sly chars : ★☆ȸȹɅϞϟ༄༅༗།༎༒༓༔࿂ ࿃ ࿄  ࿅࿆࿇ ࿈࿉ ࿊ ࿋ ࿌✌
            desc = TextTextureDesc.new('@', 32 * (1 + Math.log(multiplier)), RGBA[255, 255, 0, 255])
            sprite = get_sprite(desc).with(:center => ship.pos + Point2D.new(ship.size.x*0.5, 0))
            @entities << Shot.new(sprite, Point2D.new(0, -10)).with(:dot => damage,
                                                                    :tags => [:shot, :arrobase_shot, :player_shot, :rotating])
          }
        end
        if @frame_count % 1 == 0 # peu urgent et cpu-intensif (sur mon portable)
          @entities.remove(@entities.tagged(:shot, :alien, :bonus).find_all { |e| # remove some off screen entities
                             margin = e.size.x + e.size.y + 50
                             #!(-margin..EngineConfig.ortho.x + margin).include?(e.pos.x) ||
                             #!(-margin..EngineConfig.ortho.y + margin).include?(e.pos.y)
                             x,y=e.pos.x,e.pos.y
                             x<-margin || x>EngineConfig.ortho.x + margin ||
                             y<-margin || y>EngineConfig.ortho.y + margin
                           })
        end
        @entities.remove(@entities.tagged(:alien, :ship).find_all { |alien| alien.dead? }) # remove dead aliens and ships
        @entities.each { |e|
          next if e.movement.nil?
          e.pos = e.pos + e.movement * delta.to_f / 100 if e.movement.is_a?(Point2D)
          e.pos = e.movement.pos(delta) if e.movement.is_a?(Trajectory)
        }
        @entities.tagged(:ship).each { |ship| # ship must stay on screen
          ship.pos.x = [[ship.pos.x, 0].max, EngineConfig.ortho.x - ship.size.x].min
          ship.pos.y = [[ship.pos.y, 0].max, EngineConfig.ortho.y - ship.size.y].min
        }
      end
      @entities.tagged(:rotating).each { |e| e.sprites.each { |s| s.angle += delta / 2.0 } }
    }
  end

  def draw(delta)
    # draw sprites
    @entities.collect { |e| e.sprites }.flatten.sort_by { |sprite| sprite.z_order }.each { |sprite|
      $p[:d_draw] += Utils.time { sprite.draw }
    }
    # with pause text on top
    write_centered(@autoplay ? '-- paused (autoplay) --' : '-- paused --', EngineConfig.ortho / 2, 32) if @paused
  end
end
