# -*- coding: iso-8859-1 -*-
require 'core/utils'
require 'core/texture'
require 'core/ral'

class EngineSingleton
  include Singleton
  attr_accessor :renderer, :games, :profiler, :default_game_class, :texture_cache, :current_frame, :frames, :frame_count
  def initialize(game_class = TitleScreen)
    @renderer = Renderer.new
    @reload_code_wait = ElapsedTimeWait.new(WallClock, EngineConfig2.reload_code_wait_in_ms)
    @profiler = Profiler.new
    @texture_cache = TextureCache.new
    @games = [] # stack
    @default_game_class = game_class
    @reload_thread = nil
    @frame_count = 0
    # don't do too many things here, Engine is not set yet
    @exceptions_to_display = []
  end

  # gamescreen management. TODO: change stack into a tree? (see jmonkey gamestate)
  def exit_screen
    @games.pop
  end
  def push_screen(screen)
    @games << screen
  end
  def quit
    @games.clear
  end
  def reset
    @games.clear
    @games.push(@default_game_class.new)
  end
  def destroy
    @renderer.destroy
  end

  def mainloop # source code reloading will affect functions in the stack after this one
    reset if @games.empty?
    frame_count_to_keep = 1000
    @frames = Array.new(frame_count_to_keep) { f = Frame.new(0); f.stop; f }
    # stop automatic error handling if too many consecutive frames fail
    until @frames[-5..-1].count { |frame| frame.failed } >= 5
      return if @games.empty?
      (@frames << try_exec_one_frame).shift
    end
    puts "can't seem to recover from errors. quitting"
  end

  def frame_start_time
    @current_frame.start_time
  end

  def enqueue_exception(ex) # used for exception in other threads
    @exceptions_to_display << ex
  end

  private
  def try_exec_one_frame
    @current_frame = Frame.new(@frames.last.id + 1)
    if @exceptions_to_display.size > 0
      ex = @exceptions_to_display.pop
      puts 'exception caught in thread:', ex, ex.backtrace[0..100]
      push_screen(ErrorScreen.new(ex))
      @current_frame.exception = ex
    end
    begin
      @renderer.render_frame(@games.last)
      manage_code_reloading_thread
    rescue Exception
      puts 'exception caught at main loop:', $!, $!.backtrace[0..100]
      push_screen(ErrorScreen.new($!))
      @current_frame.exception = $!
    end
    @current_frame.stop
    moy = @frames[-20..-1].collect { |f| f.duration }.max
    is_slower_than_usual = @current_frame.duration > 1.5 * moy && moy > 5
    # is_slower_than_usual = les 20 dernières frames ont toutes pris les deux tiers du temps de celle-ci
    if @current_frame.failed || is_slower_than_usual
      puts "%s (usually %s)" % [@current_frame, moy]
    end
    return @current_frame
  end

# TODO: make the use of the separate thread optional (via menu)
# 'cause gl funcs can't be called from another thread
  def manage_code_reloading_thread
    # use a separate thread because disk access is 100x slower when I code from a shared directory
    if @reload_thread.nil? then
      if @reload_code_wait.is_over_auto_reset
        @reload_thread = Thread.new {
          time = Utils.time { SourceCodeReloader.instance.reload_code }
          puts("- reload: %s ms" % time)
        }
      end
    else
      if !@reload_thread.alive?
        t = @reload_thread
        @reload_thread = nil
        t.value # raise the thread exception on the gl thread
      end
    end
  end

  # profiling result: une fois par seconde, j'ai une GC qui prend 8ms.
  # du coup, même en ne faisant rien (minimized), je suis à 60FPS sauf
  # pour une frame qui prend 1/40ème de seconde (1/60 + 8ms).

  class Frame
    attr_accessor :id, :start_time, :stop_time, :exception
    def initialize(id)
      @id = id
      @start_time = WallClock.time
    end
    def stop
      @stop_time = WallClock.time
    end
    def duration
      @stop_time - @start_time
    end
    def failed
      defined?(@exception)
    end
    def to_s
      "[frame #%s: %sms, %s]" % [@id, duration, failed ? @exception : 'ok']
    end

    # TODO: quand on fait quelque chose pas à toutes les frames, tagger
    # la frame par la desc de ce qu'on y a fait, pour le voir dans le log
  end

  class Renderer

    class FpsCounter
      def initialize
        @show_fps_wait = ElapsedTimeWait.new(WallClock, EngineConfig2.fpsTimeIntervalInMs)
        @fps = 0
      end
      def step(delta)
        @fps += 1
        if @show_fps_wait.is_over_auto_reset
          yield(@fps * 1000 / @show_fps_wait.duration.to_f)
          @fps = 0
        end
      end
    end

    const_def :DisplayMode, org.lwjgl.opengl.DisplayMode
    const_def :Display, org.lwjgl.opengl.Display
    const_def :UtilDisplay, org.lwjgl.util.Display

    def initialize
      @display_frequency = EngineConfig.default_display_frequency
      @display_width, @display_height = 800, 600
      @fpsCounter = FpsCounter.new
      @last_loop_time = WallClock.time
      reset_display
    end
    def destroy
      Engine.texture_cache.destroy if defined?(Engine)
      Display.destroy
    end

    def fullscreen=(fullscreen); Display.fullscreen = @fullscreen = fullscreen; end
    def display_frequency=(display_frequency); @display_frequency = display_frequency.to_i; reset_display; end
    def display_width=(display_width); @display_width = display_width.to_i; reset_display; end
    def display_height=(display_height); @display_height = display_height.to_i; reset_display; end
    attr_reader :fullscreen, :display_frequency, :display_width, :display_height
    def title=(title); Display.title = title; end
    def title(title); Display.title; end

    def reset_display
      Display.destroy
      # Find available display modes by min and max criteria (-1 = ignored).
      # minWidth minHeight maxWidth maxHeight minBPP maxBPP minFreq maxFreq
      dm = UtilDisplay.getAvailableDisplayModes(800, 600, -1, -1, -1, -1, @display_frequency > 0 ? @display_frequency : -1, -1)
      display_infos = { :width => @display_width, :height => @display_height,
        :freq => @display_frequency, :bpp => Display.displayMode.bitsPerPixel }
      puts display_infos.inspect
      display_infos = display_infos.collect { |k,v| ('%s=%s' % [k,v]).to_java_string }.to_java(:string) #^$ù*¨£%µ java
      UtilDisplay.setDisplayMode(dm, display_infos)
      Display.create
      RAL.reset_display(EngineConfig.ortho)
      GL11.glViewport(0, 0, @display_width, @display_height) # un viewport c'est un rect dans lequel on va dessiner
      puts("freq=%s bpp=%s" % [Display.displayMode.frequency, Display.displayMode.bitsPerPixel])
      puts "oh hai. can has vbo = %s, %s" % [RAL.is_vbo_capable, RAL.is_vbo_capable ? "kthx" : "nowai"]
      Engine.texture_cache.remap_all_textures if defined?(Engine)
    end
    def render_frame(game)
      RAL.clear_frame
      Display.sync(@display_frequency) if @display_frequency > 0 && EngineConfig2.limit_fps.from_config_value
      now = WallClock.time
      delta, @last_loop_time = (now - @last_loop_time).to_i, now # TODO: refactor with Frame
      @fpsCounter.step(delta) do |fps|
        frms = Engine.frames[-fps..-1] || Engine.frames
        slowest_frame_time = frms.collect { |f| f.duration }.max
        Engine.renderer.title = '%s/%s FPS | VZQ' % [fps, 1000 / (slowest_frame_time+1)]
        worst_5_in_ms = frms.map{|f|f.duration}.sort.reverse[1..10] * ', '
        puts("FPS: %s, worst: %s (%s)" % [fps, 1000 / (slowest_frame_time+1), worst_5_in_ms])
        puts "display not visible" unless Display.isVisible
      end
      if Display.isVisible # !isVisible = minimized
        Engine.frame_count += 1
        delta = 100 if delta > 100 # don't advance game time too much in case of one big lag
        game.next_frame(Display.isActive, delta)
      else
        sleep 0.1 # lower CPU usage to 0% (useful when limit_fps == false)
      end
      Display.update
      Engine.quit if Display.is_close_requested?
      if EngineConfig2.pause_when_not_focused.from_config_value && !Display.is_active
        Engine.push_screen PauseScreen.new unless Engine.games.last.is_a? PauseScreen
      end
    end
  end

end

class TextureCache # enlever les textures de type texte, de temps en temps ? si on fait pas gaffe ça peut bouffer toute la mémoire
  def initialize
    @cache = {}
  end
  def get(drawer)
    @cache.cache(drawer.cache_key) { Texture.new(drawer) }
  end
  def reload_all
    @cache.values.each { |texture| texture.reload }
  end
  def remap_all_textures
    @cache.values.each { |texture| texture.remap }
  end
  def loaded_textures
    @cache.values
  end
  def clear
    @cache.clear
  end
  def destroy
    RAL.delete_texture_ids(@cache.values.collect { |t| t.gl_id })
    clear
  end
end
