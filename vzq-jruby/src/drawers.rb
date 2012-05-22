# -*- coding: iso-8859-1 -*-
module Drawers

  class FontCacheSingleton # java.awt.Font by filename
    include Singleton
    const_def :Ja, java.awt
    const_def :Jai, java.awt.image
    def initialize
      @font_cache = {}
    end

    def clear
      @font_cache.clear
    end

    def get_font(font_size, style = Ja.Font::PLAIN,
                 resource_name = EngineConfig2.default_font.from_config_value)
      @font_cache.cache(resource_name) {
        ResourceLoader.get_stream(resource_name) { |input_stream|
          Ja.Font.create_font(Ja.Font::TRUETYPE_FONT, input_stream)
        }
      }.derive_font(style, font_size)
    end
  end
  const_def :FontCache, FontCacheSingleton.instance

  # a Drawer produces an awt BufferedImage from which gl textures will be composed.
  class Drawer # abstract
    const_def :GL12, org.lwjgl.opengl.GL12
    const_def :Ja, java.awt
    const_def :Jai, java.awt.image
    attr_accessor :mirror_up_down, :mirror_left_right
    def initialize
      @mirror_up_down, @mirror_left_right = false, false # TODO: actually c'est mieux à faire at drawtime
    end
    def draw_swapped
      image = draw
      # http://download.oracle.com/javase/1.5.0/docs/api/java/awt/geom/AffineTransform.html
      matrix = [@mirror_left_right ? -1 : 1, 0,
                0, @mirror_up_down ? -1 : 1,
                @mirror_left_right ? image.width : 0,
                @mirror_up_down ? image.height : 0]
      transform = Java.java.awt.geom.AffineTransform.new(*matrix)
      op = Jai.AffineTransformOp.new(transform, Jai.AffineTransformOp::TYPE_BILINEAR)
      image = op.filter(image, nil)
      image
    end
    def draw # returns a java.awt.image.BufferedImage
      fail 'abstract'
    end
    def cache_key # needed for texture caching
      [to_s, @mirror_up_down, @mirror_left_right]
    end
    def gl_minifying_func
      # GL11::GL_LINEAR  # il interpole entre les centres
      # GL11::GL_NEAREST # y cherche pas à faire le malin sur les zooms
      GL11::GL_NEAREST
    end
    def gl_wrap_param
      # GL11::GL_CLAMP         # en dehors = noir (pour l'interpolation LINEAR)
      # GL12::GL_CLAMP_TO_EDGE # en dehors = la couleur du pixel de bord
      GL12::GL_CLAMP_TO_EDGE
    end
  end

  class WrapperDrawer < Drawer # wraps Scala class
    def initialize(inner)
      super()
      @inner = inner
    end
    def draw
      @inner.draw
    end
  end

  const_def :FastDrawer, Java.vzq.engine.FastDrawer

  class TextDrawer < Drawer # writes text with java.awt
    attr_accessor :text, :font_size, :color, :font
    def initialize(text, font_size, color = RGBAWhite, font = nil)
      super()
      @text, @font_size, @color, @font = text, font_size, color, font
    end
    def to_s
      '[text texture: type=text font_size=%s font=%s color=%s text=%s]' % [@font_size, @font, @color, @text.inspect]
    end
    def draw
      unless text.is_a? Java.java.lang.String
        str = text.to_s
      else
        str = text
      end
      str = '!-!' if str.to_s.size == 0 #TODO: gérer bien le cas ou pas de texte
      the_font = FontCache.get_font(font_size, Ja.Font::PLAIN, self.font || EngineConfig2.default_font.from_config_value)
      frc = Jai.BufferedImage.new(1, 1, Jai.BufferedImage::TYPE_INT_ARGB).createGraphics.get_font_render_context
      rect, line_metrics = the_font.get_string_bounds(str, frc), the_font.get_line_metrics(str, frc)
      image = Jai.BufferedImage.new(rect.width, rect.height, Jai.BufferedImage::TYPE_INT_ARGB)
      g = image.createGraphics
      g.font = the_font
      g.color = color.to_java
      g.draw_string(str, 0, rect.height - line_metrics.descent)
      return image
    end
    def gl_minifying_func
      GL11::GL_LINEAR
    end
  end

  class Filled < Drawer # creates a uniform colored rectangle
    attr_accessor :color, :size
    def initialize(color, size = Point2D.new(1, 1))
      super()
      @color, @size = color, size
    end
    def to_s
      '[filled rect texture: color=%s size=%s]' % [@color, @size]
    end
    def draw
      image = Jai.BufferedImage.new(@size.x.to_i, @size.y.to_i, Jai.BufferedImage::TYPE_INT_ARGB)
      g = image.createGraphics
      g.color = @color.to_java
      g.fill_rect(0, 0, image.width, image.height)
      return image
    end
  end

  class FileDrawer < Drawer # loads from a file
    attr_accessor :filename, :xy, :wh

    def initialize(filename, xy = nil, wh = nil)
      super()
      @filename = filename
      @xy, @wh = xy, wh # to draw a subimage
    end

    def is_sub_image
      !xy.nil? && !wh.nil?
    end

    def to_s
      is_sub_image ?
      '[texture from file: %s at (%s,%s)]' % [@filename, @xy, @wh] :
      '[texture from file: %s]' % [@filename]
    end

    def draw
      # @xy, @wh = Point2D.new(0, 0), Point2D.new(16, 16) if @filename.match(/Hippo/)
#      ImageAsyncCache.clear # DEBUG
      cached_image = ImageAsyncCache.get(@filename)
      image = cached_image.get_copy
      return image unless is_sub_image
      return image.getSubimage(xy.x.to_i, xy.y.to_i, wh.w.to_i, wh.h.to_i)
    end

    def background_preload # boaf, c'est pas l'accès disque qui est lent...
      ImageAsyncCache.background_preload(@filename)
      puts "preload image from background thread: %s" % @filename
    end

    const_def(:ImageAsyncCache, AsyncCache.new { |filename| FileDrawer.load_image(filename) })

    def FileDrawer.load_image(filename)
      ResourceLoader.get_stream(filename) { |input_stream|
        javax.imageio.ImageIO.read(input_stream)
      }
    end
  end

end
