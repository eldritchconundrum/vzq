# -*- coding: iso-8859-1 -*-
require 'core/utils'
require 'core/ral'

class Texture
  attr_reader :gl_id, :gl_target, :drawer, :size, :gl_size, :gl_texture_buffer, :gl_source_pixel_format

  def initialize(drawer)
    @drawer = drawer
    @gl_minifying_func = drawer.gl_minifying_func
    @gl_wrap_param = drawer.gl_wrap_param
    @gl_id = RAL.create_texture_id
    @gl_target = GL11::GL_TEXTURE_2D
    reload
  end

  def <=>(other)
    @gl_id <=> other.gl_id
  end

  def reload
    t = Utils.time {
      image = @drawer.draw_swapped
      if EngineConfig.debug_sprite_box(@drawer) && image.width > 3 && image.height > 3
        #TODO: I'd rather see the collision box (if there is one) than a sprite box... but we don't know that here
        g = image.create_graphics
        g.color = java.awt.Color.new(255, 0, 255, 255)
        g.draw_rect(0, 0, image.width - 1, image.height - 1)
      end
      @size = Point2D.new(image.width, image.height)
      @gl_source_pixel_format = image.color_model.has_alpha ? GL11::GL_RGBA : GL11::GL_RGB
      @gl_texture_buffer, @gl_size = Texture.convert_to_gl(image)
      remap
    }
    puts('load %s: %s ms' % [@drawer, t])
  end

  def bind
    GL11.glBindTexture(gl_target, gl_id)
  end

  def remap
    bind
    if (gl_target == GL11::GL_TEXTURE_2D)
      GL11.glTexParameteri(gl_target, GL11::GL_TEXTURE_MIN_FILTER, @gl_minifying_func)
      GL11.glTexParameteri(gl_target, GL11::GL_TEXTURE_MAG_FILTER, @gl_minifying_func)
      GL11.glTexParameteri(gl_target, GL11::GL_TEXTURE_WRAP_S, @gl_wrap_param)
      GL11.glTexParameteri(gl_target, GL11::GL_TEXTURE_WRAP_T, @gl_wrap_param)
    end
    #TODO : exception handling? (too big, etc.)
    GL11.glTexImage2D(gl_target, 0, GL11::GL_RGBA, @gl_size.width, @gl_size.height,
                      0, @gl_source_pixel_format, GL11::GL_UNSIGNED_BYTE, @gl_texture_buffer)

    # setup displaylist
    @displaylist_id = GL11.glGenLists(1)
    GL11.glNewList(@displaylist_id, GL11::GL_COMPILE)
    draw_without_displaylist
    GL11.glEndList
  end

  def draw
    if true then GL11.glCallList(@displaylist_id) else draw_without_displaylist end
  end

  def to_s
    "[texture%s w,h=(%s,%s) (%s,%s) %s]" %
      [@gl_id, @size.x.to_i, @size.y.to_i, @gl_size.x.to_i, @gl_size.y.to_i, @drawer]
  end

  def tex_coord_array
    height_ratio = size.height.to_f / gl_size.height.to_f
    width_ratio = size.width.to_f / gl_size.width.to_f
    [0, 0, 0, height_ratio, width_ratio, height_ratio, width_ratio, 0]
  end

  def batch_compute_vertices(&block)
    if !defined?(@btr)
      vieux_max = 2000 # bouh la vieille constante
      @btr = BatchTextureRenderer.new(vieux_max, GL15::GL_STREAM_DRAW, GL15::GL_STATIC_DRAW)
      @btr.map_tex_coord_buffer_for_write { |tbuf|
        tbuf.put((self.tex_coord_array * vieux_max).to_java(:float))
      }
    end
    a = []
    Engine.profiler.prof(:draw_compute_vertex) {
      xsize, ysize = self.size.x, self.size.y
      add_sprite = lambda { |xpos, ypos, angle, zoom|
        # TODO: passer en Scala le calcul du floatbuffer à partir de pos/size/angle/zoom, en batch
        # passer 4 float array et un int array, récup un floatbuffer
        # TODO: implém variation de tex_coord (pour animation)
        # TODO: implém mirror_* (pas via tex_coord, via inversion de vertex)
        if (zoom.nil? || (!zoom.respond_to?(:x) && zoom == 1)) && angle == 0 then
          x1,y1, x2,y2 = [xpos, ypos, xpos + xsize, ypos + ysize]
          a.concat([x1,y1,  x1,y2,  x2,y2,  x2,y1])
        else
          xzoom, yzoom = zoom.respond_to?(:x) ? [zoom.x, zoom.y] : [zoom, zoom]
          xd, yd = xsize / 2.0, ysize / 2.0
          xd *= xzoom
          yd *= yzoom
          xc, yc = xpos + xd, ypos + yd
          if angle == 0 then
            x1,y1, x2,y2 = [xc-xd, yc-yd, xc+xd, yc+yd]
            a.concat([x1,y1,  x1,y2,  x2,y2,  x2,y1])
          else
            cos, sin = Math.cos(angle), Math.sin(angle)
            xcos, ycos, xsin, ysin = xd*cos, yd*cos, xd*sin, yd*sin
            xcos_ysin_pp, ycos_xsin_pp = +xcos+ysin, +ycos+xsin
            xcos_ysin_pm, ycos_xsin_pm = +xcos-ysin, +ycos-xsin
            a.concat([xc-xcos_ysin_pm, yc-ycos_xsin_pp,
                      xc-xcos_ysin_pp, yc+ycos_xsin_pm,
                      xc+xcos_ysin_pm, yc+ycos_xsin_pp,
                      xc+xcos_ysin_pp, yc-ycos_xsin_pm])
#            a.concat([xc-xcos+ysin, yc-ycos-xsin,
#                      xc-xcos-ysin, yc+ycos-xsin,
#                      xc+xcos-ysin, yc+ycos+xsin,
#                      xc+xcos+ysin, yc-ycos+xsin])
          end
        end
      }
      block.call(add_sprite) # populate the array with vertices coords
      assert(a.size % 8 == 0)
      @btr_size = a.size / 8
      # puts "%s %s" % [@btr_size, @drawer]
    }
    ja = Engine.profiler.prof(:draw_array2java) { a.to_java(:float) }
    Engine.profiler.prof(:draw_write_buffer) {
      @btr.map_vertex_buffer_for_write { |vbuf|
        vbuf.put(ja)
      }
    }
  end
  def batch_draw
    Engine.profiler.prof(:draw_drawarrays) {
      self.bind
      @btr.draw(@btr_size)
    }
  end

  private

  def draw_without_displaylist
    bind
    height_ratio = size.height.to_f / gl_size.height.to_f
    width_ratio = size.width.to_f / gl_size.width.to_f
    GL11.glBegin(GL11::GL_QUADS)
    GL11.glTexCoord2f(0, 0);                      GL11.glVertex2f(0, 0)
    GL11.glTexCoord2f(0, height_ratio);           GL11.glVertex2f(0, size.height)
    GL11.glTexCoord2f(width_ratio, height_ratio); GL11.glVertex2f(size.width, size.height)
    GL11.glTexCoord2f(width_ratio, 0);            GL11.glVertex2f(size.width, 0)
    GL11.glEnd
  end

  class << self
    const_def :Ja, java.awt
    const_def :Jai, java.awt.image

    # use java awt to convert images to gl format
    def convert_to_gl(image)
      texture_image = image.get_copy_for_opengl
      gl_size = Point2D.new(texture_image.width, texture_image.height)
      bytes = texture_image.raster.data_buffer.data # data_buffer : DataBufferByte
      # bytes : java byte[]
      #puts '----', (0..bytes.size-1).collect {|i| bytes[i].to_s }.join(' '), '---' if gl_size.x == 4
      gl_texture_buffer = java.nio.ByteBuffer.allocate_direct(bytes.length)
      gl_texture_buffer.order(java.nio.ByteOrder.nativeOrder)
      gl_texture_buffer.put(bytes, 0, bytes.length)
      gl_texture_buffer.flip
      return [gl_texture_buffer, gl_size]
    end
  end
end

class Java::java::awt::image::BufferedImage
  def get_copy # ^$ù*¨£%µ pourquoi ça y est pas de base dans awt
    raster, cm = self.copyData(nil), self.color_model
    return java.awt.image.BufferedImage.new(cm, raster, cm.isAlphaPremultiplied, nil)
  end
  def get_copy_for_opengl
    jai, ja = java.awt.image, java.awt
    dest_size = Point2D.new(self.width.next_power_of_two, self.height.next_power_of_two)
    # when I try to simplify this code, I lose the alpha
    has_alpha = self.color_model.has_alpha
    raster = jai.Raster.create_interleaved_raster(jai.DataBuffer::TYPE_BYTE, dest_size.width,
                                                  dest_size.height, has_alpha ? 4 :  3, nil)
    color_space = ja.color.ColorSpace.getInstance(ja.color.ColorSpace::CS_sRGB)
    transparency = has_alpha ? ja.Transparency::TRANSLUCENT : Ja.Transparency::OPAQUE
    color_model = jai.ComponentColorModel.new(color_space, [8, 8, 8, has_alpha ? 8 : 0].to_java(:int),
                                              has_alpha, false, transparency, jai.DataBuffer::TYPE_BYTE)
    image = jai.BufferedImage.new(color_model, raster, false, nil)
    g = image.createGraphics
    #g.color = ja.Color.new(0, 0, 0, 0)
    #g.fill_rect(0, 0, dest_size.width, dest_size.height)
    g.draw_image(self, 0, 0, nil)
    return image
  end
end
