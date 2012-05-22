# -*- coding: iso-8859-1 -*-

class GameState
  attr_accessor :mobs
  def initialize
    @mobs = []
  end
  def add_mob
    @mobs << Mob.new.with(:pos => Point2D.new(100, 100), :life => 100, :max_life => 100)
  end
  def advance(delta)
    for m in mobs
      m.pos.x += rand*2-1
      m.pos.y += rand*2-1
    end
  end
end

class Mob
  attr_accessor :pos
  attr_accessor :life
  attr_accessor :max_life
end

class TowerDefense < GameScreen
  def initialize
    super()
    @gamestate = GameState.new
    @wait_manager.add(:log_entities, 5000)
  end

  def next_frame(is_display_active, delta)
    @clock.advance_time(delta)
    Engine.profiler.prof(:logic) {
      #if is_display_active
        player_actions = Engine.profiler.prof(:logic_input) { process_input }
        change_state(delta, player_actions)
      #end
    }
    Engine.profiler.prof(:draw) { inactive_draw } unless EngineConfig2.disable_draw.from_config_value
  end

  def change_state(delta, player_actions)
    Engine.profiler.prof(:logic_events) { @wait_manager.run_events }
    @gamestate.advance(delta)
  end

  def inactive_draw
    spr = get_sprite(TextDrawer.new('-', 20))
    spr.refresh_textures
    tex = spr.current_texture
    #
    # oui donc là j'en étais à me dire, c'est con, avec mon VBO du shoot'em up, je peux pas changer la couleur pour chaque mob.
    #
    tex.batch_compute_vertices { |add_sprite|
      for m in @gamestate.mobs
        add_sprite.call(m.pos.x, m.pos.y, 0, nil)
      end
    }
    tex.batch_draw
  end

  def log_entities
    puts("  frame %s: %s mobs" % [Engine.frame_count, @gamestate.mobs.size])
    puts(Engine.profiler.show.gsub(/^/, '  ')) if Engine.profiler.enabled
  end

  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_A
      50.times{@gamestate.add_mob}
    else super(ctrl, shift, key)
    end
  end
end
TitleGameScreens[TowerDefense] = 'tower defense test'
