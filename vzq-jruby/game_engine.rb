class EngineConfig
  class << self
    def reload_code_wait_in_ms; 1000; end # ms ; -1 disables
    def resource_root; 'res/'; end
    def default_display_frequency; $VERBOSE && debug ? -1 : 60; end # -1 or > 0
    def show_fps_hook(engine, fps)
      engine.renderer.title = '%s FPS | Welcome to the eldritch realm of VZQ' % fps
      puts("FPS: %s" % fps)
    end
    def ortho; Point2D.new(800, 600); end
    def debug_sprite_box(desc); false && EngineConfig.debug; end
    def debug; true; end
  end
end

exec_once('dfcffgjbojgffnopuiaopzoopffdg') {
  $engine.texture_loader.reload_all
  puts 'test'
}

class GameEngine
  attr_accessor :renderer, :texture_loader, :games
  def initialize
    @texture_loader = TextureLoader.new
    @renderer = Renderer.new(self)
    @reload_code_wait = ElapsedTimeWait.new { EngineConfig.reload_code_wait_in_ms }
    @games = [] # stack
  end
  def play(game)
    @games.push(game)
    until @games.empty?
      mainloop
    end
  end
  def mainloop
    @renderer.renderFrame(@games.last)
    if @reload_code_wait.is_over_auto_reset
      time = Utils.time { try_to_reload_code }
      puts("- reload: %s ms" % time)
    end
  end
  def destroy
    @renderer.destroy
  end
end

class Renderer

  class FpsCounter
    def initialize
      @show_fps_wait = ElapsedTimeWait.new { fpsTimeIntervalInMs }
      @fps = 0
    end
    def fpsTimeIntervalInMs; 1000; end
    def step(delta)
      @fps += 1
      if @show_fps_wait.is_over_auto_reset
        yield(@fps)
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
    a = { :width => @display_width, :height => @display_height, :freq => @display_frequency, :bpp => Display.getDisplayMode.getBitsPerPixel }
    puts a
    a = a.collect { |k,v| java.lang.String.new('%s=%s' % [k,v]) }.to_java(:string) #^$ù*¨£%µ java
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
    puts("bpp=%s" % Display.getDisplayMode.getBitsPerPixel)
    @engine.texture_loader.remap_all_textures
  end
  def initialize(engine)
    @engine = engine
    @display_frequency = EngineConfig.default_display_frequency
    @display_width, @display_height = 800, 600
    @fpsCounter = FpsCounter.new
    @last_loop_time = Utils.get_time
    reset_screen
  end
  def destroy
    @engine.texture_loader.destroy
    Display.destroy
  end
  def renderFrame(game)
    GL11.glClear(GL11::GL_COLOR_BUFFER_BIT)
    GL11.glMatrixMode(GL11::GL_MODELVIEW)
    GL11.glLoadIdentity
    # TODO: test different slowness-handling modes: slow down the FPS, skip rendering, time-delta-parametrized game logic...
    # see how each react to lag or to general slowness
    Display.sync(@display_frequency) if (@display_frequency > 0)
    now = Utils.get_time
    delta, @last_loop_time = (now - @last_loop_time).to_i, now
    @fpsCounter.step(delta) { |fps| EngineConfig.show_fps_hook(@engine, fps) }
    game.nextFrame(Display.isActive, delta)
    Display.update
    @engine.games = [] if Display.is_close_requested?
  end
end

