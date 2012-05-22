# -*- coding: iso-8859-1 -*-
class Fade < GameScreen
  def initialize(how = :out, duration = 1000, spacing = 16)
    super()
    @how, @duration, @spacing = how, duration, spacing
    @time = 0
  end

  def next_frame(is_display_active, delta)
    @time += delta
    super(is_display_active, delta)
    Engine.games.pop if @time > @duration
  end

  def inactive_draw
    inactive_draw_lower_screen
    factor = (@time / @duration.to_f) * 2
    factor = 1.0 - factor if @how == :in
    color = RGBAF[0.0 * factor, 0.0 * factor, 0, factor]
    get_sprite(Filled.new(color)).with(:zoom => EngineConfig.ortho).draw
  end
end
