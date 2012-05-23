# -*- coding: iso-8859-1 -*-
# wraps one (or several) texture, adding position, zoom, angle, and looping animation
class VZQSprite
  attr_accessor :textures, :zoom, :angle, :anim_loop, :z_order # zoom can be a number or a 2D point
  attr_accessor :frame_duration
  attr_accessor :pos
  def center=(new_center)
#puts new_center, display_size if current_texture.to_s.match /Guile/
    @pos = new_center - display_size / 2
  end
  def center
    @pos + display_size / 2
  end

  attr_reader :current_frame
  def current_frame=(current_frame)
    # TODO: use frame_duration (augment current_frame only once every frame_duration)
    if current_frame.to_i >= @textures.size && !anim_loop
      @current_frame = 10000
      return
    end
    @current_frame = current_frame.to_i % @textures.size
  end
  def initialize(&get_textures_proc)
    @get_textures_proc = get_textures_proc
    @current_frame = 0
    @angle, @zoom, @pos, @z_order = 0, 1, Point2D.new(0, 0), 0
    refresh_textures
    @anim_loop = true
    @frame_duration = 1
    # TODO: move animation logic (texture change) into the entities and out of sprite? (not its business, unless it also handles the timing, which it doesn't)

  end
  def refresh_textures # get the texture again from the texture cache, or the drawer if not found
    @textures = @get_textures_proc.call
    current_frame = @current_frame # call the setter to refresh the modulo (textures.size may have changed)
    unless current_texture.nil?
      @tex_size = current_texture.size
      raise 'textures size differ: %s' % @textures.collect{ |t| t.size }.join(' ') if @textures.any?{ |t| t.size != @tex_size}
    end
  end
  def draw # display list
    RAL.draw_sprite(current_texture, @pos, @tex_size, @angle, @zoom) unless current_texture.nil?
  end
  def to_s
    "[sprite: anim=%s/%s pos=%s zoom=%s]" % [1 + @current_frame, @textures.size, @pos, @zoom]
  end
  def current_texture
    @textures[@current_frame.to_i]
  end

  def display_size
    xzoom, yzoom = zoom.respond_to?(:x) ? [zoom.x, zoom.y] : [zoom, zoom]
    Point2D.new(@tex_size.x * xzoom, @tex_size.y * yzoom)
  end
end



# textures represent gl textures ; drawers are the texture creators
# sprites are texture wrappers with state for position, zooom, rotation, z_order (ext)
# entities are sprites with game logic
# VZQSprites are sprites with animation using one texture for one frame
# TODO: sprites with animation via subtexture drawing?

require 'drawers'


# TODO: revoir les "écrans"

# comment implémenter un overlay par dessus un screen mais qui laisse
# l'input à ce screen ? 'minor-mode' :)

# -> MVC ?
# input -> agit sur -> modèle -> rendu par -> view
# indépendance vue-modèle, pour meilleur code du modèle et pour config séparée de la view

# je pense que le controle des keyboard events est best représenté par une liste ordonnée
# de handlers, le premier gagne ou peut pass on.

# seule la vue connait opengl et tout ça


class GameScreen # base class for a screen
  include Renewable
  include Drawers
  const_def :Keyboard, org.lwjgl.input.Keyboard
  const_def :Mouse, org.lwjgl.input.Mouse

  def initialize
    puts "== new screen: #{self.class}"
    @clock = Clock.new
    @wait_manager = WaitManager.new(self, @clock)
  end

  def next_frame(is_display_active, delta)
    @clock.advance_time(delta)
    process_input
    inactive_draw
    Engine.profiler.prof(:logic_events) { @wait_manager.run_events }
  end

  def inactive_draw
    # override this to draw something when you're not active (don't change any state!)
    # you may call inactive_draw_lower_screen
  end

  def inactive_draw_lower_screen
    index = Engine.games.index(self).to_i
    return if index == 0
    to_draw = Engine.games[index - 1]
    to_draw.inactive_draw
  end

  def process_input
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

  def process_key(ctrl, shift, key) # general key bindings
    case key
    when Keyboard::KEY_F then Engine.renderer.fullscreen ^= true if ctrl
    when Keyboard::KEY_Q then Engine.quit if ctrl
    when Keyboard::KEY_R then Engine.reset if ctrl
    when Keyboard::KEY_SCROLL then EngineConfig2.toggle(:disable_draw) if shift #ctrl marche pas
    when Keyboard::KEY_ESCAPE then Engine.exit_screen
    when Keyboard::KEY_F2 then raise 'user-triggered exception'
    when Keyboard::KEY_PAUSE then Engine.push_screen PauseScreen.new unless Engine.games.last.is_a?(PauseScreen)
    when Keyboard::KEY_F3 then Engine.push_screen DebugMenuScreen.new unless Engine.games.last.is_a?(DebugMenuScreen)
    when Keyboard::KEY_F12 then take_screenshot # glDrawBuffer(GL_BACK); draw; glReadBuffer(GL_BACK); glReadPixels(...); save_to_file;
    end
  end

  def get_sprite(drawer)
    VZQSprite.new { [Engine.texture_cache.get(drawer)] }
  end

  def write(text, pos, size = 16, color = RGBAWhite)
    pos = Point2D.new(pos.x.to_i, pos.y.to_i)
    sp = get_sprite(TextDrawer.new(text, size, color))
    #sp.pos = pos
    sp.center = pos + sp.display_size / 2
    sp.draw unless text.to_s == ''
  end

  def write_centered(text, pos, size = 16)
    pos = Point2D.new(pos.x.to_i, pos.y.to_i)
    get_sprite(TextDrawer.new(text, size)).with(:center => pos).draw unless text.to_s == ''
  end

  def write_list(list, pos_lambda, size = 16, color = RGBAWhite)
    list.each_with_index { |item, i|
      pos = pos_lambda.call(i)
      write(item, pos, size, color) if pos.y < EngineConfig.ortho.y
    }
  end
end


class ErrorScreen < GameScreen # used when toplevel gets an exception in debug mode
  def initialize(exception)
    super()
    @exception = exception
    puts @exception
    @crashed_game = Engine.games[-1] # not -2, since we aren't yet on the stack
  end

  def inactive_draw
    write('%s' % @exception.class, Point2D.new(150, 20), 24, RGBA[255,0,0])
    write(@exception, Point2D.new(20, 70), 16, RGBA[255,255,0])
    write_list(@exception.backtrace, lambda { |i| Point2D.new(20, 100 + i * 20) })
    write('screens:', Point2D.new(420, 220))
    write_list(Engine.games.reverse.collect { |g| g.class }, lambda { |i| Point2D.new(440, 240 + i * 20) })
    write_list(['commands:',
                '   space/esc = resume next frame',
                '   k = kill previous screen',
                '   r = restart previous screen',
                '   ctrl+r = reset VZQ',
                '   ctrl+q = quit VZQ',
               ],
               lambda { |i| Point2D.new(420, 420 + i * 20) }, 16, RGBA[128, 255, 255])
  end

# TODO : use MenuScreen to present the choices
  private
  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_SPACE then Engine.exit_screen # retry (resume next frame)
    when Keyboard::KEY_K then 2.times { Engine.exit_screen } # kill the crashing game
    when Keyboard::KEY_R then
      if ctrl
        Engine.reset
      else # try to restart the crashing game if supported
        if @crashed_game.respond_to?(:renew)
          puts "renew %s !" % @crashed_game.class
          2.times { Engine.exit_screen }
          Engine.push_screen @crashed_game.renew
        end
      end
    else super(ctrl, shift, key)
    end
  end
end

class PauseScreen < GameScreen
  def next_frame(is_display_active, delta)
    @count ||= 0
    super
    puts "GC: %s ms" % Utils.time { Java.runtime.gc } if @count == 10
    sleep(0.08) if @count > 0 # save CPU when paused
    @count += 1
  end
  def inactive_draw
    inactive_draw_lower_screen
    color = RGBA[64, 32, 0, 192]
    get_sprite(Filled.new(color)).with(:zoom => EngineConfig.ortho).draw
    write('V  Z  Q', Point2D.new(320, 100), 48)
    write('- paused -', Point2D.new(320, 300), 32)
    write('press pause to unpause', Point2D.new(260, 500), 24)
  end
  private
  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_P, Keyboard::KEY_PAUSE, Keyboard::KEY_SPACE, Keyboard::KEY_RETURN
      Engine.exit_screen
    else super
    end
  end
end

class MenuScreenBase < GameScreen
  def initialize(menu_items)
    super()
    @menu_items = menu_items
    @index = 0
  end
  def inactive_draw
    customize_menu_draw

    list = @menu_items.map { |mi| '    ' + mi.text }
    @index = @index % list.size
    list[@index][0..3] = 'Â¤  ' #TODO: utiliser plutot une couleur avec alpha pour surligner le choix en cours
    write_list(list, lambda { |i| Point2D.new(120, 120 + i * 20) })
  end
  def customize_menu_draw
    inactive_draw_lower_screen
    get_sprite(Filled.new(RGBA[50, 60, 90, 192])).with(:zoom => 512).draw
  end
  private
  def process_input
    result = super
    wheel = Mouse.getDWheel
    if wheel != 0
      puts "wheel=%s" % wheel
      @index += wheel < 0 ? -wheel / 120 : -wheel / 120
    end
    return result
  end
  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_UP then @index -= 1
    when Keyboard::KEY_DOWN then @index += 1
    when Keyboard::KEY_RETURN, Keyboard::KEY_NUMPADENTER then @menu_items[@index].select
    else
      items = @menu_items.find_all { |mi| mi.has_shortcut(ctrl, shift, key) }
      if items.empty?
        super(ctrl, shift, key)
      else
        items.each { |mi| mi.select }
      end
    end
  end
end

class MenuItem
  def initialize(text_or_proc, shortcuts = nil, &select)
    @text = text_or_proc
    @shortcuts = shortcuts
    @select_proc = select
  end
  def text
    (@text.respond_to?(:call) ? @text.call : @text).to_s
  end
  def select
    @select_proc.call
  end
  def has_shortcut(ctrl, shift, key)
    return false if @shortcuts.nil?
    if @shortcuts.respond_to? :include?
      return @shortcuts.include? key
    else
      return @shortcuts == key
    end
  end
end


#TODO: move to plugins/ (separate engine/game debug screens ?)
const_def :ShootEmUpConfig, ConfBase2.new
ShootEmUpConfig.scala_detector.set true


class DebugMenuScreen < MenuScreenBase
  def initialize
    super([
           mi(lambda { "toggle profiling = #{Engine.profiler.enabled}" }) { Engine.profiler.enabled = !Engine.profiler.enabled },
           mi('reload source code now') { time = Utils.time { SourceCodeReloader.instance.reload_code }; puts("reload: %s ms" % time) },
           mi('kill all sounds') { SoundManager.stop_all },
           mi('clear the cache of GL textures') {  Engine.texture_cache.clear },
           mi('reload all loaded GL textures') {  Engine.texture_cache.reload_all },
           mi('log loaded GL textures') {  Engine.texture_cache.instance_eval('puts(@cache.values)') },
           mi('clear the cache of file images') { FileDrawer::ImageAsyncCache.clear },
           #mi('augment display height') { change_display_size(1.2, true) },
           #mi('augment display width') { change_display_size(1.2, false) },
           #mi('reduce display height') { change_display_size(1/1.2, true) },
           #mi('reduce display width') { change_display_size(1/1.2, false) },
           mi('see logs') { fail 'todo' },
           mi('reset VZQ') { Engine.reset },
           mi('quit VZQ') { Engine.quit },
           mi('restart the VZQ process') { fail 'TODO!' },
           mi('garbage collect now') { java.lang.Runtime.runtime.gc; GC.start },
           mi('do nothing (if you liked the preceding item)') { },
           mi('throw a javelin') { raise 'a javelin' },
           mi('fade out') { Engine.push_screen Fade.new(:in); Engine.push_screen Fade.new(:out); },#TODO

           mi(lambda { "toggle #{ShootEmUpConfig.scala_detector}" }) {
             ShootEmUpConfig.toggle(:scala_detector)
           }, # TODO: specifique au jeu, pas Ã  paramÃ©trer ici

           toggle_conf_menuitem(:pause_when_not_focused),
           toggle_conf_menuitem(:drawarrays_sans_vbo),
           toggle_conf_menuitem(:use_display_lists_not_drawarray),
           mi(lambda { "toggle #{EngineConfig2.vbo_use_mapbuffer} (pas fini)" }) { EngineConfig2.toggle(:vbo_use_mapbuffer) },
           toggle_conf_menuitem(:limit_fps),
           mi(lambda { "toggle $VERBOSE = #{$VERBOSE}" }) { $VERBOSE = !$VERBOSE },
           mi('back', Keyboard::KEY_SPACE) { Engine.exit_screen }
          ])
  end
  private
  def toggle_conf_menuitem(conf_name)
    mi(lambda { "toggle #{EngineConfig2[conf_name]}" }) { EngineConfig2.toggle(conf_name) }
  end
  def mi(*args, &block)
    MenuItem.new(*args, &block)
  end
  def change_display_size(coef, is_verti) # quite bugged
    if is_verti then
      Engine.renderer.display_height *= coef
    else
      Engine.renderer.display_width *= coef
    end
  end
end

class TitleScreen < MenuScreenBase
  def initialize
    items = TitleGameScreens.sort_by { |kv| kv[0].to_s }
    items = items.map { |kv| MenuItem.new(kv[1]) { Engine.push_screen(kv[0].new) } }
    items << MenuItem.new('exit') { Engine.quit }
    super(items)
  end
  def customize_menu_draw
    super()
    write('V  Z  Q', Point2D.new(320, 50), 48)
  end
end

const_def :TitleGameScreens, {} # only for classes with argumentless ctors
