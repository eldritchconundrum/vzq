class EngineConfig
  class << self
    def reload_code_wait_in_ms; 1000; end # ms ; -1 disables
    def resource_root; 'res/'; end
    def default_display_frequency; $VERBOSE && debug ? -1 : 60; end # -1 or > 0
    def show_fps_hook(fps)
      $engine.renderer.title = '%s FPS | Welcome to the eldritch realm of VZQ' % fps
      puts("FPS: %s" % fps)
    end
    def ortho; Point2D.new(800, 600); end
    def debug_sprite_box(desc); false && EngineConfig.debug; end
    def debug; true; end
  end
end

class ShootEmUpConfig
  class << self
    def alien_frame_duration; 200; end # in ms
    def background_speed; 5; end
    def fire_rate; 50; end # do not set it to a too small value (near the FPS) or it will be messed up (slower rate) (TODO: fix)
    def alien_fire_rate; 100; end # d'ailleurs c'est pas des rate, c'est des delay
    def ship_move_speed; 40; end
    def bonus_wait; 8000; end
    def alien_anim; ['', '2', '', '3'].collect { |f| "spaceinvaders/alien#{f}.gif" }; end
    def bg_moon; 'bg_moon.jpg'; end
    def sprite_ship; 'spaceinvaders/ship.gif'; end
    def sprite_shot; 'spaceinvaders/shot.gif'; end
  end
end
