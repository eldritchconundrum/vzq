require 'utils'

# wraps one (or several) texture, adding position, zoom, angle, and looping animation
class NormalSprite
  attr_accessor :pos, :size, :textures, :zoom, :angle, :z_order
  def center=(center); @pos = center - @size / 2; end
  attr_reader :current_frame
  def current_frame=(current_frame)
    @current_frame = current_frame.to_i % @textures.size
  end
  def current_texture
    @textures[@current_frame.to_i]
  end
  def initialize(&get_textures_proc)
    @get_textures_proc = get_textures_proc
    @current_frame = 0
    @angle, @zoom, @pos, @z_order = 0, 1, Point2D.new(0, 0), 0
    refresh_textures
  end
  def refresh_textures
    @textures = @get_textures_proc.call
    current_frame = @current_frame # call the setter to refresh the modulo (textures.size may have changed)
    @size = current_texture.size
    raise 'textures size differ: %s' % @textures.collect{ |t| t.size }.join(' ') if @textures.any?{ |t| t.size != @size}
  end
  def draw
    GL11.glPushMatrix
    current_texture.bind
#   GL11.glPixelZoom(1, -1)
    if @angle != 0
      GL11.glTranslatef(@pos.x + @size.x / 2, @pos.y + @size.y / 2, 0)
      GL11.glRotatef(@angle, 0, 0, 1) if (@angle != 0) # angle is relative to center of sprite
      GL11.glTranslatef(-@size.x / 2, -@size.y / 2, 0)
    else
      GL11.glTranslatef(@pos.x, @pos.y, 0)
    end
    GL11.glScalef(@zoom, @zoom, @zoom) if (@zoom != 1)
    current_texture.draw
    GL11.glPopMatrix
  end
  def to_s
    "[sprite: anim=%s/%s pos=%s]" % [1 + @current_frame, @textures.size, @pos]
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
    @p.each { |k,v| @p[k] = ((v * 1000.0 / duration)*10).round/10.0 }
    groups = @p.group_by { |k,v| k.to_s.match(/^[^_]*_/).to_s }
    s = ''
    groups.each { |group_key, kv_list|
      s += "%s* = %s\n" % [group_key, kv_list.transpose[1].inject(0) {|a,b|a+b} ]
      kv_list.each { |kv| s += "\t%s\t= %s\n" % kv }
    }
    @p.clear
    s
  end
end

require 'game_engine.rb'

# base class for a game
class GameBase
  require 'utils'
  include Renewable
  Keyboard = org.lwjgl.input.Keyboard unless defined?(Keyboard)
  attr_accessor :frame_count
  def initialize
    @wait_manager = WaitManager.new(self)
    @frame_count = 0
  end
  def next_frame(isDisplayActive, delta)
    # override this to call process_input and render
  end

  def process_input # general key bindings
    keyboard_events = []
    Keyboard.poll
    while Keyboard.next
      keyboard_events << [Keyboard.getEventCharacter, Keyboard.getEventKeyState, Keyboard.getEventKey]
    end
    ctrl = [Keyboard::KEY_RCONTROL, Keyboard::KEY_LCONTROL].any?{|k| Keyboard.isKeyDown(k) }
    # alter = [Keyboard::KEY_RMETA, Keyboard::KEY_LMETA].any?{|k| Keyboard.isKeyDown(k) } # conflits parfois
    shift = [Keyboard::KEY_RSHIFT, Keyboard::KEY_LSHIFT].any?{|k| Keyboard.isKeyDown(k) }
    keyboard_events.each { |char, isDown, key|
      process_key(ctrl, shift, key) if isDown
    }
    return keyboard_events # for overrides
  end

  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_ESCAPE then $engine.games.pop
    when Keyboard::KEY_F9 then $engine.texture_loader.reload_all
    when Keyboard::KEY_F10
      time = Utils.time { reload_code }
      puts("reload: %s ms" % time)
    when Keyboard::KEY_F11, Keyboard::KEY_F12
      coef = key == Keyboard::KEY_F12 ? 1.2 : (1/1.2)
      if shift then $engine.renderer.display_width *= coef else $engine.renderer.display_height *= coef end
    when Keyboard::KEY_F1 then require 'debug' # works only once
    when Keyboard::KEY_F2 then raise 'user-triggered exception'
    when Keyboard::KEY_F then $engine.renderer.fullscreen ^= true if ctrl
    when Keyboard::KEY_Q then $engine.games.clear if ctrl
    when Keyboard::KEY_F3 then $engine.games << DebugMenuScreen.new
    end
  end

  def get_sprite(*resource_names)
    NormalSprite.new { resource_names.collect{ |r| $engine.texture_loader.get(r) } }
  end

  def write(text, pos, size = 16)
    pos = Point2D.new(pos.x.to_i, pos.y.to_i)
    get_sprite(TextTextureDesc.new(text, size)).with(:pos => pos).draw
  end

  def write_centered(text, pos, size = 16)
    pos = Point2D.new(pos.x.to_i, pos.y.to_i)
    get_sprite(TextTextureDesc.new(text, size)).with(:center => pos).draw
  end

  def write_list(list, pos_lambda, size = 16)
    list.each_with_index { |item, i|
      pos = pos_lambda.call(i)
      write(item, pos, size) if pos.y < EngineConfig.ortho.y
    }
  end

end



class ErrorGame < GameBase # used when toplevel gets an exception in debug mode
  def initialize(exception)
    super()
    @exception = exception
    @crashed_game = $engine.games[-1] # not -2, since we aren't yet on the stack
    @extended = !@crashed_game.is_a?(ErrorGame) # limit ourselves to simple error reporting if the exception comes from this class
  end

  def next_frame(isDisplayActive, delta)
    write(@exception.class, Point2D.new(150, 20), 24)
    write(@exception, Point2D.new(20, 70))
    if @extended
      write_list(@exception.backtrace, lambda { |i| Point2D.new(20, 120 + i * 20) })
      write_list($engine.games.reverse.collect { |g| g.class }, lambda { |i| Point2D.new(420, 20 + i * 20) })
    else
      write('extended error mode failed, falling back to simple', Point2D.new(300, 300))
    end
    process_input
  end
  private
  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_SPACE then $engine.games.pop # retry
    when Keyboard::KEY_K then 2.times { $engine.games.pop } # kill the crashing game
    when Keyboard::KEY_R then
      if ctrl # reboot the game
        $engine.games.clear
        $engine.games << StartupScreen.new
      else # try to restart the crashing game if supported
        if @crashed_game.respond_to?(:renew) # is_a?(Renewable)
          puts "renew %s !" % @crashed_game.class
          2.times { $engine.games.pop }
          $engine.games << @crashed_game.renew
        end
      end
    else super(ctrl, shift, key)
    end
  end
end

class StartupScreen < GameBase
  def next_frame(isDisplayActive, delta)
    @txt_sprite = get_sprite(TextTextureDesc.new('use arrows and space', 32)).with(:pos => Point2D.new(200, 300))
    @txt_sprite.draw
    process_input
  end
  private
  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_SPACE then $engine.games << ShootEmUp.new
    else super(ctrl, shift, key)
    end
  end
end

# TODO: refaire la répartition des raccourcis, ne pas mettre trop de commandes de debug dans gamebase

class DebugMenuScreen < GameBase
  def initialize
    super()
    @wait_manager.add(:log) { 2000 }
  end
  def next_frame(isDisplayActive, delta)
    write('F9 to reload all loaded gl textures', Point2D.new(100, 300))
    write('F4 to clear the cache of gl textures', Point2D.new(100, 350))
    @wait_manager.run_events
    process_input
  end
  private
  def log
    $engine.texture_loader.instance_eval('puts(@cache.values)')
  end
  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_F4 then $engine.texture_loader.clear
    else super(ctrl, shift, key)
    end
  end
end
