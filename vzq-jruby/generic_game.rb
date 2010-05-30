
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
    current_frame = @current_frame # refresh the modulo: textures.size may have changed
    @size = current_texture.size
    raise 'textures size differ: %s' % @textures.collect{ |t| t.size }.join(' ') if @textures.any?{ |t| t.size != @size}
  end
  def draw
    refresh_textures
    GL11.glPushMatrix
    current_texture.bind
    GL11.glPixelZoom(1, -1)
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

# TODO: support type of collision detection, customize bounds, center of sprite, distance-based, etc.
class CollisionDetector # works only with rectangles, does not support rotation
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

# base class for a game (feed it to engine.play)
class GameBase
  Keyboard = org.lwjgl.input.Keyboard unless defined?(Keyboard)
  def initialize
    @wait_manager = WaitManager.new(self)
  end
  def nextFrame(isDisplayActive, delta)
  end
  def process_input # general key bindings
    keyboard_events = []
    Keyboard.poll
    while Keyboard.next
      keyboard_events << [Keyboard.getEventCharacter, Keyboard.getEventKeyState, Keyboard.getEventKey]
    end
    ctrl = [Keyboard::KEY_RCONTROL, Keyboard::KEY_LCONTROL].any?{|k| Keyboard.isKeyDown(k) }
    shift = [Keyboard::KEY_RSHIFT, Keyboard::KEY_LSHIFT].any?{|k| Keyboard.isKeyDown(k) }
    keyboard_events.each { |char, isDown, key|
      if isDown
        case key
        when Keyboard::KEY_ESCAPE then $engine.games.pop
        when Keyboard::KEY_F10
          time = Utils.time { try_to_reload_code }
          puts("reload: %s ms" % time)
        when Keyboard::KEY_F9 then $engine.texture_loader.reload_all
        when Keyboard::KEY_F11, Keyboard::KEY_F12
          coef = key == Keyboard::KEY_F12 ? 1.2 : (1/1.2)
          if shift then $engine.renderer.display_width *= coef else $engine.renderer.display_height *= coef end
        when Keyboard::KEY_F1 then require 'debug' # works only once, don't use 'c'.   #require 'rubygems'; require 'ruby-debug'; debugger
        when Keyboard::KEY_F then $engine.renderer.fullscreen ^= true if ctrl
        when Keyboard::KEY_Q then $engine.games.clear if ctrl
        end
      end
    }
    return keyboard_events # for overrides
  end
  def get_sprite(*resource_names)
    NormalSprite.new { resource_names.collect{ |r| $engine.texture_loader.get(r) } }
  end
end


class MenuScreen < GameBase
  def initialize
    super()
  end
  def nextFrame(isDisplayActive, delta)
    @txt_sprite = get_sprite(TextTextureDesc.new('use arrows and space', 32)).with(:pos => Point2D.new(200, 300))
    @txt_sprite.draw
    process_input
  end
  private
  def process_input
    keyboard_events = super
    keyboard_events.each { |char, isDown, key|
      if isDown
        case key
        when Keyboard::KEY_SPACE then $engine.play(ShootEmUp.new)
        when Keyboard::KEY_F3 then $engine.play(DebugMenuScreen.new)
        end
      end
    }
  end
end

# TODO: refaire la répartition des keyboard events, ne pas mettre trop de commandes de debug dans gamebase
# généraliser système de log régulier, permettre de log dans fichier plutot pour pas pourrir irb,
# faire un vrai menu qui a une bonne tete
# faire une classe pour aider à l'écriture de texte à l'écran ?

class DebugMenuScreen < GameBase
  def initialize
    super()
    @wait_manager.add(:log) { 2000 }
  end
  def write(text, y)
    get_sprite(TextTextureDesc.new(text, 16)).with(:center => Point2D.new(EngineConfig.ortho.x / 2, y)).draw
  end
  def nextFrame(isDisplayActive, delta)
    write('F9 to reload all loaded gl textures', 300)
    write('F4 to clear the cache of gl textures', 350)
    @wait_manager.run_events
    process_input
  end
  private
  def log
    $engine.texture_loader.instance_eval('puts(@cache.values)')
  end
  def process_input
    keyboard_events = super
    keyboard_events.each { |char, isDown, key|
      if isDown
        case key
        when Keyboard::KEY_F4 then $engine.texture_loader.clear
        end
      end
    }
  end
end
