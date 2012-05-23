# -*- coding: iso-8859-1 -*-
class TestBench < GameScreen
  def initialize
    super()
    @entities = EntitiesSet.new
    @paused = false
    @wait_manager.add(:log_entities) { 5000 }
  end

  def inactive_draw

    # super test comparatif VBO/immediate de machins qui clignotent
    spr = get_sprite(TextDrawer.new('-', 20)).with(:pos => Point2D.new(100, 100))
    if false
      for x in 0...50
        for y in 25...50
          if rand < 0.5 then
            spr.pos = Point2D.new(x * 15, y * 10)
            spr.draw
          end
        end
      end
    else
      tex = spr.current_texture
      tex.batch_compute_vertices { |add_sprite|
        for x in 0...50
          for y in 25...50
            if rand < 0.5 then
              xpos, ypos = x * 15, y * 10
              angle = 0
              zoom = nil #2 #Point2D.new(1,2)
              add_sprite.call(xpos, ypos, angle, zoom)
            end
          end
        end
      }
      tex.batch_draw
    end



    # draw sprites
    sprites = Engine.profiler.prof(:olddraw_sort) {
      @entities.collect { |e|  e.update_sprite_pos; e.sprites }.flatten.sort_by { |sprite| sprite.z_order }
    }
    @txt_sprite = get_sprite(TextDrawer.new('TODO', 144)).with(:pos => Point2D.new(100, 100))
    @txt_sprite.draw
    write("ce jue n'est pas un jue sur le cyclimse", Point2D.new(500, 10))


    #draw_char_with_strange_font
#    @ii||=0;write(("f"*55)+@ii.to_s, Point2D.new(500, 10)); @ii+=1
  end
  def draw_char_with_strange_font
    # unicode chars with \u are in ruby 1.9 only
    aa = "\x1401"[0] + 300
    text = Java.java.lang.String.new((aa..aa+50).to_a.to_java(:char))
    sp = get_sprite(TextDrawer.new(text, 20, RGBAWhite, 'font/Masinahikan_h.ttf')) # U+1400-167F, U+18B0-18FF
    sp.center = Point2D.new(10, 10) + sp.display_size / 2
    sp.draw unless text.to_s == ''
  end

  protected
  def log_entities
    puts("  frame %s: %s entities, %s" % [Engine.frame_count, @entities.size, @entities.stats])
    puts("  %s" % @entities)
    @entities.reset_stats
    puts(Engine.profiler.show.gsub(/^/, '  ')) if Engine.profiler.enabled
  end

  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_P

    when Keyboard::KEY_S
      SoundManager.stop_all
    when Keyboard::KEY_U
      $wav = SoundPlayer.new(ResourceLoader.make_full_path('Winners.wav'))
      $mp3 = SoundPlayer.new(ResourceLoader.make_full_path('okkusenman.mp3'))
      $ogg = SoundPlayer.new(ResourceLoader.make_full_path('xtrium-underwater.ogg'))
      $wav.play
#      $mp3.play
      $ogg.play
#      sleep 3
#      $wav.reset
#      $mp3.reset
#      $ogg.reset
#      SoundManager.stop_all
    else super(ctrl, shift, key)
    end
  end
end
TitleGameScreens[TestBench] = "test bench"
