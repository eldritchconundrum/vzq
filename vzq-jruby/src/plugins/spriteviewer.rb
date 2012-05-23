# -*- coding: iso-8859-1 -*-
class SpriteViewer < GameScreen
  def initialize
    super()
    update_loaded_textures
    @current = @loaded_textures.first
    @zoom = 1
    @pos = Point2D.new(0, 0)
    @wait_manager.add(:cycle_clearcolor) { 100 }
  end

  def cycle_clearcolor
    r = (Math.cos(@clock.time / (16 * 23.0) + 0) + 1.5) * 0.1
    g = (Math.cos(@clock.time / (16 * 27.0) + 1) + 1.5) * 0.1
    b = (Math.cos(@clock.time / (16 * 19.0) + 2) + 1.5) * 0.1
    GL11.glClearColor(r, g, b, 255)
  end

  def update_loaded_textures
    @loaded_textures = Engine.texture_cache.loaded_textures.sort_by { |t| t.to_s }.to_a
    @loaded_textures.reject! { |s| s.drawer.is_a?(TextDrawer) || s.drawer.is_a?(Filled) }
    puts "#{@loaded_textures.size} textures"
  end

  def inactive_draw
    unless @current.nil?
      write(@current.drawer.to_s[0..200], Point2D.new(0, 0))
      write("zoom: %s, pos=%s, size=%s" % [@zoom, @pos, @current.size], Point2D.new(0, 16))
      VZQSprite.new { [@current] }.with(:zoom => @zoom, :pos => @pos + Point2D.new(0, 8 + 16 * 2)).draw
    end
  end

  private
  def process_input
    super() # calls process_key
    dx = (Keyboard.isKeyDown(Keyboard::KEY_RIGHT) ? 1 : 0) - (Keyboard.isKeyDown(Keyboard::KEY_LEFT) ? 1 : 0)
    dy = (Keyboard.isKeyDown(Keyboard::KEY_DOWN) ? 1 : 0) - (Keyboard.isKeyDown(Keyboard::KEY_UP) ? 1 : 0)
    @pos += Point2D.new(dx * @zoom, dy * @zoom)
  end

  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_U then update_loaded_textures
    when Keyboard::KEY_R then Engine.texture_cache.reload_all
    when Keyboard::KEY_SPACE then @current.reload unless @current.nil?
    # TODO: load sprite by filename !
    when Keyboard::KEY_PRIOR, Keyboard::KEY_NEXT, Keyboard::KEY_P, Keyboard::KEY_N
      i = @loaded_textures.index(@current)
      unless i.nil?
        di = [Keyboard::KEY_PRIOR, Keyboard::KEY_P].include?(key) ? -1 : 1
        @current = @loaded_textures[(i + di) % @loaded_textures.size]
        @pos = Point2D.new(0, 0)
      end
    when Keyboard::KEY_ADD, Keyboard::KEY_SUBTRACT
      factor = key == Keyboard::KEY_ADD ? 2 : 0.5
      @zoom *= factor
    else super(ctrl, shift, key)
    end
  end
end
# TODO: faire un affichage spécial pour les sprites animés
TitleGameScreens[SpriteViewer] = 'funky sprite viewer'
