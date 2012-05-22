# -*- coding: iso-8859-1 -*-

# renommer 'ShootEmUp' en 'Shmup'

module ShootEmUpGame

  class GuileTrajectory < Trajectory # looping in the center of the screen
    def initialize(time_origin)
      super(time_origin, EngineConfig.ortho / 2)
      @direction = Point2D.new(rand(2) * 2 - 1, rand(2) * 2 - 1)
    end
    def position(time)
      ms = elapsed_ms(time).to_f
      t = ms / 3000
      @pos_origin + 0.4 * @direction.member_product(EngineConfig.ortho).member_product(Point2D.new(Math.cos(2*t) * Math.sin(t), Math.sin(2*t) * Math.sin(t)))
    end
  end

  # do not set the "rates" to a too small value (near 1/FPS) or they
  # will be rounded up strangely (to the next 1/FPS). by design.
  ShootEmUpConfig.fire_rate.set 50
  ShootEmUpConfig.fire2_rate.set { ShootEmUpConfig.fire_rate.from_config_value * 50 }
  ShootEmUpConfig.enemy_fire_delay.set 100
  ShootEmUpConfig.add_enemies_delay.set 1000

  ShootEmUpConfig.ship_move_speed.set 40
  ShootEmUpConfig.bonus_wait.set 8000
  ShootEmUpConfig.background_speed.set 5

  module Model
    class ShootEmUp
      include CollisionDetection

      attr_accessor :entities, :fire_level, :autoplay
      attr_reader :bg_traj
      def initialize(screen, clock, wait_manager)
        @screen, @clock, @wait_manager = screen, clock, wait_manager
        reset_state
        init_music
      end

      def init_music
        #SoundPlayer.new(ResourceLoader.make_full_path('xtrium-underwater.ogg')).play
      end

      def reset_state
        @clock.reset
        @entities = EntitiesSet.new
        @fire_level = 2
        @autoplay = false
        @screen.make_explosion_sprite # preload (creating texture for every frame is a bit slow)
        @screen.preload_images
        # use ElapsedTimeWait to enforce a mandatory delay between player actions
        @fire2_wait = ElapsedTimeWait.new(@clock, ShootEmUpConfig.fire2_rate)
        @fire_wait = ElapsedTimeWait.new(@clock, ShootEmUpConfig.fire_rate)
        @fire_spread = 0 # belongs to ship?
        @fire_spread_change_wait = ElapsedTimeWait.new(@clock, ShootEmUpConfig.fire_rate)
        # use wait_manager to trigger game events at regular intervals (in no particular order)
        @wait_manager.target = self
        @wait_manager.add(:log_entities, 5000)
        @wait_manager.add(:add_random_enemies, ShootEmUpConfig.add_enemies_delay)
        @wait_manager.add(:enemy_fire_ticked, ShootEmUpConfig.enemy_fire_delay)
        @wait_manager.add(:add_bonus1, ShootEmUpConfig.bonus_wait)
        @wait_manager.add(:add_bonus2, ShootEmUpConfig.bonus_wait)
        @bg_traj = LinearTraj.new(0, Point2D.new(0, 0),
                                  Point2D.new(0, ShootEmUpConfig.background_speed.from_config_value))
        @wait_manager.add(:add_guile, 30000)
        add_ship
      end

      # --- WaitManager events begin ---
      def log_entities
        puts("  frame %s: %s entities, %s" % [Engine.frame_count, @entities.size, @entities.stats])
        puts("  %s" % @entities)
        @entities.reset_stats
        puts(Engine.profiler.show.gsub(/^/, '  ')) if Engine.profiler.enabled
      end

      def enemy_fire_ticked
        @entities.tagged(:enemy).each { |enemy|
          next if rand > 0.01
          if enemy.has_tag?(:boss)
            if rand > (1 - 0.02 * @entities.count {|e| e.has_tag?(:ship) })
              dot = 2 ** @entities.count {|e| e.has_tag?(:ship) }
              for i in 0..9 do
                add_entity(create_shot(enemy, 10, Math::Tau * (i + 0.5) / 20, 'LOLOLOL').with(:dot => dot))
              end
            elsif rand < 0.5
              successive_shoot_left = 7
              fire_event_lambda = lambda {
                return :remove_this_event if successive_shoot_left.to_i <= 0
                successive_shoot_left -= 1
                add_entity(create_shot(enemy, 20, Math::Tau / 4.0, '+').with(:damage => 30).with(:revolutions_per_second => 1))
              }
              @wait_manager.add(fire_event_lambda, 100)
            else
              # A FAIRE : le tir en arc de cercle des boss doit bouger un
              # peu en restant concentré (proche du point de départ)
              # pendant une demi-seconde, puis partir linéairement. (via composition de trajs)
              for i in 0..9
                add_entity(create_shot(enemy, 10, Math::Tau * (i + 0.5) / 20, 'Â¤').with(:damage => 35))
              end
              # TODO: ajouter ici un tir "(0..10).each { Tau * i / 20" qui soit non-bleu et destructible par les shots normaux
            end
          end
          add_entity(create_shot(enemy, 15, rand * 100, 'o').with(:damage => 30))
        }
      end

      def add_bonus1
        return if @fire_level >= 5
        direction = rand < 0.5
        pos = Point2D.new(direction ? 0 : EngineConfig.ortho.x, 10+rand*EngineConfig.ortho.y/3)
        bonus_speed = ShootEmUpConfig.ship_move_speed.from_config_value
        traj = LinearTraj.new(@clock, pos, Point2D.new((direction ? 1 : -1) * bonus_speed, 0))
        add_entity(Entity.new(@screen.make_bonus1_sprite, traj), [:bonus, :fire_bonus])
      end

      def add_bonus2
        direction = rand < 0.5
        pos = Point2D.new(direction ? 0 : EngineConfig.ortho.x, 10+rand*EngineConfig.ortho.y/3)
        bonus_speed = ShootEmUpConfig.ship_move_speed.from_config_value
        traj = LinearTraj.new(@clock, pos, Point2D.new((direction ? 1 : -1) * bonus_speed, 0))
        add_entity(Entity.new(@screen.make_bonus2_sprite, traj), [:bonus, :life_bonus])
      end

      def add_random_enemies
        xmax = EngineConfig.ortho.x.to_f
        n = 7
        if rand < 0.01
          add_entity(create_enemy(Point2D.new(-50, EngineConfig.ortho.y.to_f / 2), Point2D.new(50, 0), :honda))
          return
        end
        if rand < 0.01
          add_entity(create_enemy(Point2D.new(xmax, EngineConfig.ortho.y.to_f / 2), Point2D.new(-10, 0), :mario_kart_fish))
          return
        end
        case (rand(35) / 10.0).to_i
        when 0 then j, speed = 1, 2
        when 1 then j, speed = 2, 3
        when 2 then j, speed = 3, 4
        else # enemy2
          add_entity(create_enemy(Point2D.new(xmax / 2, -50), Point2D.new(0, 5), :enemy2))
          return
        end
        add_entity(create_enemy(Point2D.new(xmax * j / n, -50), Point2D.new(0, speed)))
        j = n - j
        add_entity(create_enemy(Point2D.new(xmax * j / n, -50), Point2D.new(0, speed)))
      end

      def add_guile
        return if @entities.tagged(:guile).size > 0
        center = Point2D.new(EngineConfig.ortho.x / 2, -300)
        movement = Point2D.new(0, 10)
        traj = CrossFadeTrajectoryComposition.new(@clock, SinusoidalTraj.new(@clock, center, movement, 1, rand * 0.05, rand), GuileTrajectory.new(@clock), 0, 5000)
        sprite = @screen.make_guile_sprite
        guile = Guile.new(sprite, traj).with(:life => 1500, :tags => [:enemy, :rotating, :guile])
        add_entity(guile)
      end
      # --- WaitManager events end ---

      def add_entity(entity, new_tags = nil)
        entity.tags = new_tags unless new_tags.nil?
        @entities.add(entity)
      end

      def add_ship
        add_entity(Ship.new(@screen.make_ship_sprite,
                            Point2D.new(400, 500)).with(:life => 100), [:ship])
      end

      def create_shot(enemy, speed, angle, char)
        sprite = @screen.make_enemy_fire_sprite(char)
        traj = LinearTraj.new(@clock, enemy.center, speed * V2I.new(Math.cos(angle), Math.sin(angle)))
        Shot.new(sprite, traj).with(:tags => [:shot, :enemy_shot, :rotating])
      end

#TODO: rename boss as :enemy2
      def create_enemy(pos, movement, enemy_type = :enemy1)
        sprite, life, amplitude, tags =
          case enemy_type
          when :enemy1 then [@screen.make_basic_enemy_sprite, 20, rand * 20, [:enemy]]
          when :enemy2 then [@screen.make_enemy2_enemy_sprite, 400, 40, [:enemy, :boss]]
          when :honda then [@screen.make_flying_honda, 1000, 0, [:enemy, :boss]]
          when :mario_kart_fish then [@screen.make_mario_kart_fish, 1000, 0, [:enemy, :boss, :rotating, :mario_kart_fish]]
          else fail enemy_type.to_s
          end
        traj = SinusoidalTraj.new(@clock, pos, movement, amplitude, rand * 0.05, rand)
        enemy = Enemy.new(sprite, traj).with(:life => life, :tags => tags)
        enemy.revolutions_per_second = 0 if enemy_type == :mario_kart_fish
        return enemy
      end

      def explode_at(entity)
        sprite = @screen.make_explosion_sprite
        sprite.zoom = 3 if entity.has_tag?(:boss)
        sprite.zoom = 5 if entity.is_a?(Guile)
        add_entity(Explosion.new(sprite, entity.center), [:explosion, :no_collision])
      end

      def process_player_actions(player_actions, delta)
        pdx = (player_actions.right_pressed ? 1 : 0) - (player_actions.left_pressed ? 1 : 0)
        pdy = (player_actions.down_pressed ? 1 : 0) - (player_actions.up_pressed ? 1 : 0)
        player_speed = ShootEmUpConfig.ship_move_speed.from_config_value
        player_speed *= (player_actions.fire_pressed ? 0.5 : 1)
        player_movement = Point2D.new(pdx, pdy) * player_speed
        unless player_movement.nil?
          dp = player_movement * delta.to_f / 100
          @entities.tagged(:ship).each { |ship| ship.move(dp) }
        end
        fire_shoot1(player_actions.firemod_pressed) if player_actions.fire_pressed
        fire_shoot2 if player_actions.fire2_pressed
      end

      def update_all_traj
        time = @clock.time
        @entities.each { |e| e.update_traj(time) }
      end

      def misc_logic(delta)
#puts @entities.size if Engine.frame_count % 5 == 0
        Engine.profiler.prof(:logic_misc3) {
          dead_enemies = @entities.tagged(:enemy).find_all { |enemy| enemy.dead? }
          for ship in @entities.tagged(:ship)
            ship.life += dead_enemies.size
          end
          dead_ships = @entities.tagged(:ship).find_all { |ship| ship.dead? }
          dead_entities = dead_ships + dead_enemies
          for entity in dead_entities
            explode_at(entity)
          end
          dead_entities += @entities.tagged(:explosion).find_all { |e| e.dead? }
          @entities.remove_list(dead_entities)
          @entities.tagged(:rotating).each do |e|
            e.sprite.angle += delta * e.revolutions_per_second * Math::Tau / 1000.0
          end
        }
      end


      # --- collisions begin

      class FakeEntityRect
        def initialize(collision_box)
          @collision_box = collision_box
        end
        def sprite; self; end
        def has_tag?(tag); false; end
        def collision_box
          @collision_box
        end
        def to_s
          @collision_box.inspect
        end
      end

      def make_fake_entities_for_autoremove(margin)
        far = 1000 ** 3
        [FakeEntityRect.new([-far, -far, far - margin.x, far * 2]),
         FakeEntityRect.new([-far, -far, far * 2, far - margin.y]),
         FakeEntityRect.new([EngineConfig.ortho.x + margin.x, -far, far, far * 2]),
         FakeEntityRect.new([-far, EngineConfig.ortho.y + margin.y, far * 2, far])]
      end

      def setup_collisions
# en cours : faire marcher l'autoremove offscreen par collisions et plus par parcours lent
        if false
        Engine.profiler.prof(:logic_misc1) {
          # TODO: time-critical: mais je suis bete, y'a qu'Ã  gÃ©rer Ã§a avec rectcollisiondetection ?
          if Engine.frame_count % 3 == 0
            # remove some off screen entities
            @entities.remove_list(@entities.tagged(:shot, :enemy, :bonus).find_all { |e|
                                    si = e.sprite.display_size
                                    margin = si.x + si.y + 300
                                    po = e.center
                                    ort = EngineConfig.ortho
                                    !po.y.between?(-margin, ort.y + margin) ||
                                    !po.x.between?(-margin, ort.x + margin)
                                  })
          end
        }
        end

        collision_entities = @entities.to_a

        if true
        @fake_entities_for_way_out_of_screen_detection1 ||=
          make_fake_entities_for_autoremove(Point2D.new(100, 100)) # TODO : trouver le max des tailles de sprites de shot et bonus ? ou tester leur traj ? ou trouver un autre moyen
        @fake_entities_for_way_out_of_screen_detection2 ||=
          make_fake_entities_for_autoremove(@screen.make_enemy2_enemy_sprite.display_size * 2) # TODO: pareil
        collision_entities.concat(@fake_entities_for_way_out_of_screen_detection1)
        collision_entities.concat(@fake_entities_for_way_out_of_screen_detection2)
        end

        @colli_thread = nil
        # @colli_thread = Thread.new {}
        Engine.profiler.prof(:logic_colli_ctor) {
          @collision_detector = (ShootEmUpConfig.scala_detector.from_config_value ? JavaRectCollisionDetector : RubyRectCollisionDetector).new(collision_entities)
        }
        #}
      end

      def process_collisions(delta)
        if defined?(@colli_thread)
          #Engine.profiler.prof(:logic_colli_join) {
          #  @colli_thread.join
          #}
          cd = @collision_detector
          @shot_has_damaged_someone_already = {}
          Engine.profiler.prof(:logic_colli_test) {

            if true
            # autoremove out-of-screen shots/bonus/enemies
            cd.test(@entities.tagged(:shot, :bonus),
                    @fake_entities_for_way_out_of_screen_detection1) do |e,f|
              @entities.remove(e)
            end
            cd.test(@entities.tagged(:enemy),
                    @fake_entities_for_way_out_of_screen_detection2) do |e,f|
              @entities.remove(e) unless @clock.time - e.traj.time_origin < 3000
            end
            end
if true
            cd.test(@entities.tagged(:player_shot), @entities.tagged(:enemy)) { |shot, enemy|
              do_damage(shot, enemy, delta)
              enemy.revolutions_per_second = -1 if enemy.tags.include?(:mario_kart_fish)
            }
            cd.test(@entities.tagged(:enemy_shot), @entities.tagged(:ship)) { |shot, ship|
              next if @autoplay # test inside the loop to bench collision detector
              do_damage(shot, ship, delta)
            }
            cd.test(@entities.tagged(:ship), @entities.tagged(:enemy)) { |ship, enemy|
              next if @autoplay # test inside the loop to bench collision detector
              do_collide(ship, enemy, delta)
            }
            cd.test(@entities.tagged(:ship), @entities.tagged(:bonus)) { |ship, bonus|
              if bonus.has_tag?(:life_bonus)
                @entities.tagged(:ship).each { |s| s.life += 42 }
              else
                @fire_level += 1
              end
              @entities.remove(bonus)
            }
            cd.test(@entities.tagged(:enemy_shot), @entities.tagged(:arrobase_shot)) { |enemy_shot, arrobase_shot|
              @entities.remove(enemy_shot)
              @entities.tagged(:ship).each { |ship| ship.life += 1 }
            }
end
          }
          Engine.profiler.prof(:logic_misc2) {
            @entities.remove_list(@shot_has_damaged_someone_already.keys) # remove used shots
            for shot in @shot_has_damaged_someone_already.keys
              explode_at shot
            end
          }
        end
      end

      def do_damage(shot, ent, delta)
        do_dot(ent, shot.dot, delta, shot) unless shot.dot.nil?
        unless shot.damage.nil? || ent.dead? || @shot_has_damaged_someone_already.has_key?(shot)
          ent.life -= shot.damage
          @shot_has_damaged_someone_already[shot] = true
        end
      end

      def do_dot(target, delta, dot_value = 1, where = nil)
        target.life -= dot_value * delta / 30.0
        explode_at where if where.has_tag? :ship # don't make a big explosion on enemies by dot
      end

      def do_collide(ship, enemy, delta)
        unless ship.dead? || enemy.dead?
          do_dot(ship, delta, 2, ship)
          do_dot(enemy, delta, 2, enemy)
        end
      end

      # --- collisions end

      private

      def fire_shoot1(alternative_fire)
        return unless @fire_wait.is_over_auto_reset
        @fire_spread = 1 - @fire_spread if @fire_spread_change_wait.is_over_auto_reset
        shots = []
        @entities.tagged(:ship).each { |ship|
          ps = []
          speed = -1.5 * ShootEmUpConfig.ship_move_speed.from_config_value
          x_coef = alternative_fire ? 1.0 : 2.0
          case @fire_spread
          when 0
            ps << [V2I.new(0, 0), V2I.new(0, speed)] if @fire_level % 2 == 1
            ps << [V2I.new(-15, 0), V2I.new(-7/x_coef, speed)] if @fire_level / 2 >= 2
            ps << [V2I.new(+15, 0), V2I.new(7/x_coef, speed)] if @fire_level / 2 >= 2
            ps << [V2I.new(-15, 10), V2I.new(-14/x_coef, speed)] if @fire_level / 2 >= 4
            ps << [V2I.new(+15, 10), V2I.new(14/x_coef, speed)] if @fire_level / 2 >= 4
          when 1
            ps << [V2I.new(0, -10), V2I.new(-3/x_coef, speed)] if @fire_level / 2 >= 1
            ps << [V2I.new(0, -10), V2I.new(3/x_coef, speed)] if @fire_level / 2 >= 1
            ps << [V2I.new(0, 0), V2I.new(-10/x_coef, speed)] if @fire_level / 2 >= 3
            ps << [V2I.new(0, 0), V2I.new(10/x_coef, speed)] if @fire_level / 2 >= 3
            ps << [V2I.new(0, 0), V2I.new(-17/x_coef, speed)] if @fire_level / 2 >= 5
            ps << [V2I.new(0, 0), V2I.new(17/x_coef, speed)] if @fire_level / 2 >= 5
          end
          shots = ps.collect { |ps| p1, p2 = *ps
            center = ship.firing_pos
            if p2.x.abs >= 7
              p2 = Point2D.new(p2.x * 1.2, speed * 0.7)
              phase = ((p2.x > 0) ? 0.5 : 0) + @clock.time.to_f / 16 / 40
              sprite = @screen.make_shoot1_sprite.with(:zoom => 1)
              traj = SinusoidalTraj.new(@clock, center, p2, 2, 0.5, phase)
            else
              sprite = @screen.make_shoot2_sprite.with(:zoom => 1)
              traj = LinearTraj.new(@clock, center, p2)
            end
            # TODO: dessin: animer le sprite de tir ! qu'il ait l'air de tourner sur lui-meme
            Shot.new(sprite, traj).with(:damage => 5, :tags => [:shot, :player_shot])
          }
          @entities.add_list(shots)
        }
      end

      def fire_shoot2
        return unless @fire2_wait.is_over_auto_reset
        @last_fire2_time ||= @clock.time - @fire2_wait.duration
        multiplier = (@clock.time - @last_fire2_time).to_f / @fire2_wait.duration
        fail 'bug' if multiplier < 1
        @last_fire2_time = @clock.time

        damage = 1.2 * multiplier
        for ship in @entities.tagged(:ship)
          sprite = @screen.make_arrobase_sprite(multiplier)
          traj = LinearTraj.new(@clock, ship.firing_pos, Point2D.new(0, -10))
          shot = Shot.new(sprite, traj).with(:dot => damage)
          add_entity(shot, [:shot, :arrobase_shot, :player_shot, :rotating])
        end
      end

    end

    class SpeedPerfTest < ShootEmUp
      def init_music
      end
      def add_ship
        sprites = Array.new(3) { |i|
          [@screen.make_ship_sprite, Point2D.new(300 + i * 100, 500)]
        }
        @entities.add_list(sprites.map { |s, c| Ship.new(s, c).with(:life => 100, :tags => [:ship]) })
      end
      def add_random_enemies # not random anymore
        xmax = EngineConfig.ortho.x.to_f
        n = 7
        [[1,2], [2,3], [3,4]].each { |j, speed|
          add_entity(create_enemy(Point2D.new(xmax * j / n, -50), Point2D.new(0, speed)))
          add_entity(create_enemy(Point2D.new(xmax * (n-j) / n, -50), Point2D.new(0, speed)))
        }
        add_entity(create_enemy(Point2D.new(xmax / 2, -50), Point2D.new(0, 5), :enemy2))
      end
      def do_damage(shot, ent, delta)
      end
      def do_collide(ship, enemy, delta)
      end
      def add_guile
        :remove_this_event
      end
    end
  end # Model

  require 'plugins/shmup_resources'
  class ShootEmUpScreen < GameScreen
    include View::Sprites

    def initialize
      super()
      @model = Model::ShootEmUp.new(self, @clock, @wait_manager)
    end

    def next_frame(is_display_active, delta)
      $model = @model if EngineConfig.debug # for debugging and testing only

      @clock.advance_time(delta)#TODO: do it automatically when this "gamestate" is "active" (call super)
      Engine.profiler.prof(:logic) {
        @model.autoplay = true if !is_display_active
        player_actions = Engine.profiler.prof(:logic_input) { process_input }
        change_state(delta, player_actions)
      }
      Engine.profiler.prof(:draw) { inactive_draw } unless EngineConfig2.disable_draw.from_config_value
    end

    def inactive_draw
      sprites = nil
      Engine.profiler.prof(:draw_misc1) do
        # vertically-scrolling background
        bg_sprite ||= self.make_background_sprite
        bg_h = bg_sprite.display_size.y
        bg_y = @model.bg_traj.position(@clock.time).y % bg_h
        if EngineConfig2.use_display_lists_not_drawarray.from_config_value
if true
          bg_sprite.pos.y = bg_y
          bg_sprite.draw
          bg_sprite.pos.y -= bg_h
          bg_sprite.draw
end
        else
          bg_tex = bg_sprite.current_texture
          bg_tex.batch_compute_vertices do |add_sprite|
            add_sprite.call(0, bg_y, 0, nil)
            add_sprite.call(0, bg_y - bg_h, 0, nil)
          end
          bg_tex.batch_draw
        end
      end
      # entities sprites
      Engine.profiler.prof(:draw_misc2) do
        sprites = @model.entities.collect { |e| [e.sprite] }.flatten
        for sprite in sprites
          sprite.refresh_textures if false #EngineConfig.debug # a bit slow
        end
        sprites
      end
      # draw sprites
      if EngineConfig2.use_display_lists_not_drawarray.from_config_value
        Engine.profiler.prof(:draw_sort) { sprites = sprites.sort_by { |sprite| sprite.z_order } }
        Engine.profiler.prof(:draw_sprites) { for sprite in sprites do sprite.draw end }
      else
        # z_order-sorted list of hash<tex, sprites>
        sprites_by_tex_by_z_order = Engine.profiler.prof(:draw_sort) {
          sprites_by_tex_by_z_order = sprites.
          group_by { |sprite| sprite.z_order }.
          sort_by { |z_order, sprites| z_order }.
          map { |z, sprites| sprites.group_by { |sprite| sprite.current_texture } }
        }
        #puts sprites_by_tex_by_z_order.size
        for sprites_by_tex in sprites_by_tex_by_z_order do
          for tex, sprites in sprites_by_tex do
            next if tex.nil?
            tex.batch_compute_vertices { |add_sprite|
              for sprite in sprites
                p = sprite.center - sprite.display_size / 2
                add_sprite.call(p.x, p.y, sprite.angle, sprite.zoom)
              end
            }
            tex.batch_draw
          end
        end
      end

      # then HUD on top
      Engine.profiler.prof(:draw_hud) do
        lifes = @model.entities.tagged(:ship).collect { |s| s.life }
        total_life = lifes.inject{|a,b|a+b}.to_i

        items = lifes.collect { |life| "%s HP" % (life > 9000 ? 'over 9000' : "%.0f" % life) }
        write_list(items, lambda { |i| Point2D.new(20, 48 + i * 20) }, 25)

        yellow_pixel = get_sprite(Filled.new(RGBA[200, 200, 90, 224]))
        yellow_pixel.with(:zoom => V2I.new(total_life * 2, 16), :pos => V2I.new(8, 24)).draw

        red_pixel = get_sprite(Filled.new(RGBA[255, 90, 90, 224]))
        red_pixel.with(:zoom => V2I.new(16 * @model.fire_level, 16), :pos => V2I.new(8, 8)).draw
      end
    end

    private

    def process_input
      player_actions = PlayerActions.new
      keyboard_events = super
      keyboard_events.each { |char, isDown, key|
        if isDown
          case key
          when Keyboard::KEY_P then @model.autoplay ^= true
          when Keyboard::KEY_F5 then @model.add_ship
          when Keyboard::KEY_F6 then @model.add_random_enemies
          when Keyboard::KEY_F7 then @model.entities.tagged(:enemy).each { |e| @model.explode_at(e); e.life -= 100 }
          when Keyboard::KEY_RETURN then player_actions.fire2_pressed = true
          end
        end
      }
      player_actions.left_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_LEFT)
      player_actions.right_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_RIGHT)
      player_actions.up_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_UP)
      player_actions.down_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_DOWN)
      player_actions.fire_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_SPACE)
      player_actions.firemod_pressed = true if Keyboard.isKeyDown(Keyboard::KEY_RSHIFT)

      # pratique pour tester en codant, et propre : on simule l'input du joueur
      if @model.autoplay
        player_actions = PlayerActions.new
        player_actions.right_pressed = (@clock.time % 7000) < 4000
        player_actions.left_pressed = (@clock.time % 5000) > 2000
        player_actions.fire_pressed = (@clock.time % 5000) % 3000 > 500
      end
      return player_actions
    end

    const_def :PlayerActionsBase, ClassWithFields([:fire_pressed, :fire2_pressed,
                                                   :left_pressed, :right_pressed,
                                                   :up_pressed, :down_pressed,
                                                   :firemod_pressed
                                                  ], [false] * 7)
    class PlayerActions < PlayerActionsBase # represents the player actions during this frame
    end


    # TODO: exprimer la pos comme étant une somme de points, dont le
    # point "pos" normal, et le point "traj" qui est read-only sauf
    # depuis dans Traj, qui est le seul à set ses fields directement

    def change_state(delta, player_actions)
      @model.setup_collisions
      @model.process_collisions(delta)

      Engine.profiler.prof(:logic_events) { @wait_manager.run_events }
      Engine.profiler.prof(:logic_player) { @model.process_player_actions(player_actions, delta) }
      @model.misc_logic(delta)
      Engine.profiler.prof(:logic_update_traj) { @model.update_all_traj }
      Engine.profiler.prof(:logic_sprite_frame) {
        @model.entities.each { |e| [e.sprite].each { |s| s.current_frame += 1 } } # see sprite.frame_duration
      }
    end
  end

  class SpeedPerfTest < ShootEmUpScreen
    def initialize
      super()
      @model = Model::SpeedPerfTest.new(self, @clock, @wait_manager)
      @model.fire_level = 9
      @wait_manager.target = @model
    end
    def process_input
      super()
      return PlayerActions.new.with(:fire_pressed => true, :down_pressed => true)
    end
  end

end

TitleGameScreens[ShootEmUpGame::ShootEmUpScreen] = "play a basic shoot'em up"
TitleGameScreens[ShootEmUpGame::SpeedPerfTest] = "speed/collision benchmark"

# $model.reset_state
