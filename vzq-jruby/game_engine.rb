require 'utils'
require 'texture_loader'

class GameEngine
  attr_accessor :renderer, :texture_loader, :games
  def initialize
    @texture_loader = TextureLoader.new
    @renderer = Renderer.new
    @reload_code_wait = ElapsedTimeWait.new { EngineConfig.reload_code_wait_in_ms }
    @games = [] # stack
  end
  def destroy
    @renderer.destroy
  end
  def mainloop
    e = [nil] * 5
    until e.all? { |x| !x.nil? } # stop automatic error handling if too many consecutive frames fail
      return if @games.empty?
      (e << try_exec_one_frame).shift
    end
    puts "can't seem to recover from errors. quitting"
  end
  private
  def try_exec_one_frame
    begin
      @renderer.render_frame(@games.last)
      if @reload_code_wait.is_over_auto_reset
        time = Utils.time { reload_code }
        puts("- reload: %s ms" % time)
      end
      return nil
    rescue Exception
      puts 'exception caught at main loop:', $!, $!.backtrace[0..100]
      @games << ErrorGame.new($!)
      return $!
    end
  end
end

class Renderer

  class FpsCounter
    def initialize
      @show_fps_wait = ElapsedTimeWait.new { fpsTimeIntervalInMs }
      @fps = 0
    end
    def fpsTimeIntervalInMs; 500; end
    def step(delta)
      @fps += 1
      if @show_fps_wait.is_over_auto_reset
        yield(@fps * 1000 / fpsTimeIntervalInMs.to_f)
        @fps = 0
      end
    end
  end

  Display = org.lwjgl.opengl.Display unless defined?(Display)
  UtilDisplay = org.lwjgl.util.Display unless defined?(UtilDisplay)
  DisplayMode = org.lwjgl.opengl.DisplayMode unless defined?(DisplayMode)

  def fullscreen=(fullscreen); Display.fullscreen = @fullscreen = fullscreen; end
  def display_frequency=(display_frequency); @display_frequency = display_frequency.to_i; reset_screen; end
  def display_width=(display_width); @display_width = display_width.to_i; reset_screen; end
  def display_height=(display_height); @display_height = display_height.to_i; reset_screen; end
  attr_reader :fullscreen, :display_frequency, :display_width, :display_height
  def title=(title); Display.title = title; end
  def title(title); Display.title; end

  def reset_screen
    Display.destroy
    # Find available display modes by min and max criteria (-1 = ignored).
    # minWidth minHeight maxWidth maxHeight minBPP maxBPP minFreq maxFreq
    dm = UtilDisplay.getAvailableDisplayModes(800, 600, -1, -1, -1, -1, @display_frequency > 0 ? @display_frequency : -1, -1)
    a = { :width => @display_width, :height => @display_height, :freq => @display_frequency, :bpp => Display.displayMode.bitsPerPixel }
    puts a.inspect
    a = a.collect { |k,v| ('%s=%s' % [k,v]).to_java_string }.to_java(:string) #^$ù*¨£%µ java
    UtilDisplay.setDisplayMode(dm, a)
    Display.create
    GL11.glEnable(GL11::GL_TEXTURE_2D)
    GL11.glEnable(GL11::GL_BLEND)
    GL11.glDisable(GL11::GL_DEPTH_TEST)
    GL11.glMatrixMode(GL11::GL_PROJECTION)
    GL11.glLoadIdentity
    GL11.glOrtho(0, EngineConfig.ortho.width, EngineConfig.ortho.height, 0, -1, 1) # faut que je gère les changements de résolution et tout
    GL11.glMatrixMode(GL11::GL_MODELVIEW)
    GL11.glLoadIdentity
    GL11.glViewport(0, 0, @display_width, @display_height) # un viewport c'est un rect dans lequel on va dessiner
    GL11.glBlendFunc(GL11::GL_SRC_ALPHA, GL11::GL_ONE_MINUS_SRC_ALPHA) # tester d'autres ?
    puts("freq=%s bpp=%s" % [Display.displayMode.frequency, Display.displayMode.bitsPerPixel])
    $engine.texture_loader.remap_all_textures if defined?($engine)
  end
  def initialize
    @display_frequency = EngineConfig.default_display_frequency
    @display_width, @display_height = 800, 600
    @fpsCounter = FpsCounter.new
    @last_loop_time = Utils.get_time
    reset_screen
  end
  def destroy
    $engine.texture_loader.destroy
    Display.destroy
  end
  def render_frame(game)
    GL11.glClear(GL11::GL_COLOR_BUFFER_BIT)
    GL11.glMatrixMode(GL11::GL_MODELVIEW)
    GL11.glLoadIdentity
    # TODO: test different slowness-handling modes: slow down the FPS, skip rendering, time-delta-parametrized game logic...
    # see how each react to sudden lag or to general slowness
    Display.sync(@display_frequency) if (@display_frequency > 0)
    now = Utils.get_time
    delta, @last_loop_time = (now - @last_loop_time).to_i, now
    @fpsCounter.step(delta) { |fps| EngineConfig.show_fps_hook(fps) } # TODO: refactor this old stuff with events
    game.frame_count += 1
    game.next_frame(Display.isActive, delta)
    Display.update
    $engine.games.clear if Display.is_close_requested?
  end
end

