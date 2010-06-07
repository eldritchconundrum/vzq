class TextureLoader
  def initialize
    @cache = {}
    @font_cache = {}
  end
  def get(resource_name)
    # @cache.delete(resource_name.to_s) if resource_name.is_a?(TextTextureDesc) && rand < 0.01
    # TODO: memory? profile and optimize draw_text, or find a good caching policy for TextTextureDesc (time-based?)
    @cache.cache(resource_name.to_s) { Texture.new(@font_cache, resource_name) }
  end
  def reload_all
    @cache.values.each { |texture| texture.reload }
    @font_cache = {}
  end
  def remap_all_textures
    @cache.values.each { |texture| texture.remap }
  end
  def clear
    @cache.clear
    @font_cache.clear
  end
  def destroy
    GL11.glDeleteTextures(java.nio.IntBuffer.wrap(@cache.values.collect { |t| t.gl_id }.to_java(:int)))
    clear
  end
end

RGBAStruct = Struct.new(:r, :g, :b, :a) unless defined?(RGBAStruct)
class RGBA < RGBAStruct # TODO: to_i on members
  def to_s; '[rgba=%s,%s,%s,%s]' % [r, g, b, a]; end
  def to_java; java.awt.Color.new(r, g, b, a); end
  def [](r, g, b, a); RGBA.new(r.to_i, g.to_i, b.to_i, a.to_i); end
end
RGBAWhite = RGBA[255, 255, 255, 255] unless defined?(RGBAWhite)

class TextTextureDesc
  attr_accessor :text, :font_size, :color
  def initialize(text, font_size, color = RGBAWhite)
    @text, @font_size, @color = text, font_size, color
  end
  def to_s # needed for texture caching
    '[generated texture: type=text font_size=%s text=%s, color=%s]' % [@font_size, @text.inspect, @color]
  end
end

class NoiseTextureDesc # TODO
  attr_accessor :size
  def initialize(size)
    @size = size
  end
  def to_s # needed for texture caching
    '[generated texture: type=noise size=%s]' % @size
  end
end

class Texture
  attr_accessor :gl_id, :gl_target, :resource_name, :size, :gl_size, :gl_texture_buffer, :source_pixel_format

  def initialize(font_cache, resource_name)
    @font_cache, @resource_name = font_cache, resource_name
    @gl_id = Texture.create_texture_id
    @gl_target = GL11::GL_TEXTURE_2D
    reload
  end

  def reload
    t = Utils.time {
      case @resource_name
      when NoiseTextureDesc
        @size = @resource_name.size
        @gl_size = Point2D.new(@size.x.next_power_of_two, @size.y.next_power_of_two)
        @source_pixel_format = GL11::GL_RGBA
        @gl_texture_buffer = Texture.draw_noise(@size, @gl_size)
      when String, TextTextureDesc
        image = get_image
        @size = Point2D.new(image.width, image.height)
        @gl_size = Point2D.new(image.width.next_power_of_two, image.height.next_power_of_two)
        @source_pixel_format = image.color_model.has_alpha ? GL11::GL_RGBA : GL11::GL_RGB
        @gl_texture_buffer = Texture.convert_to_gl(image, gl_size)
      else
        raise ArgumentError.new("unknown resource. #{@resource_name.class} : #{@resource_name}")
      end
      remap
    }
    puts('load %s: %s ms' % [@resource_name, t])
  end

  def bind
    GL11.glBindTexture(gl_target, gl_id)
  end

  def remap
    bind
    if (gl_target == GL11::GL_TEXTURE_2D)
      GL11.glTexParameteri(gl_target, GL11::GL_TEXTURE_MIN_FILTER, GL11::GL_LINEAR)
      GL11.glTexParameteri(gl_target, GL11::GL_TEXTURE_MAG_FILTER, GL11::GL_LINEAR)
    end
    #TODO : handle exceptions (too big, etc.)
    GL11.glTexImage2D(gl_target, 0, GL11::GL_RGBA, gl_size.width, gl_size.height,
                      0, @source_pixel_format, GL11::GL_UNSIGNED_BYTE, gl_texture_buffer)
  end

  def draw
    bind
    height_ratio = size.height.to_f / gl_size.height.to_f
    width_ratio = size.width.to_f / gl_size.width.to_f
    GL11.glBegin(GL11::GL_QUADS);
    GL11.glTexCoord2f(0, 0);                      GL11.glVertex2f(0, 0)
    GL11.glTexCoord2f(0, height_ratio);           GL11.glVertex2f(0, size.height)
    GL11.glTexCoord2f(width_ratio, height_ratio); GL11.glVertex2f(size.width, size.height)
    GL11.glTexCoord2f(width_ratio, 0);            GL11.glVertex2f(size.width, 0)
    GL11.glEnd
  end

  def to_s
    "[texture%s w,h=%s (%s) %s]" % [@gl_id, @size, @gl_size, @resource_name]
  end

  private
  # use java awt to convert images to gl format

  def get_image # a java.awt.image.BufferedImage
    image = case @resource_name
            when String then Texture.load_from_file(@resource_name)
            else Texture.draw(@font_cache, @resource_name)
            end
    if EngineConfig.debug_sprite_box(@resource_name)
      g = image.create_graphics
      g.color = java.awt.Color.new(255, 0, 255, 255)
      g.draw_rect(0, 0, image.width - 1, image.height - 1)
    end
    return image
  end
  # texture loading (from file) or generation
  class << self
    Ja, Jai = java.awt, java.awt.image unless defined?(Ja) && defined?(Jai)

    def load_from_file(resource_name)
      return ResourceLoader.get_resource_as_stream(resource_name) { |input_stream| javax.imageio.ImageIO.read(input_stream) }
    end

    def convert_to_gl(image, gl_size)
      texture_image = create_texture_image(image.color_model.has_alpha, gl_size)
      g = texture_image.create_graphics
      g.color = Ja.Color.new(0, 0, 0, 0)
      g.fill_rect(0, 0, gl_size.width, gl_size.height)
      g.draw_image(image, 0, 0, nil)
      bytes = texture_image.raster.data_buffer.data
      return convert_bytes_to_gl(bytes)
    end
    def convert_bytes_to_gl(bytes)
      #puts '----', (0..bytes.size-1).collect {|i| bytes[i].to_s }.join(' '), '---' if gl_size.x == 4
      gl_texture_buffer = java.nio.ByteBuffer.allocate_direct(bytes.length)
      gl_texture_buffer.order(java.nio.ByteOrder.nativeOrder)
      gl_texture_buffer.put(bytes, 0, bytes.length) # java byte[]
      gl_texture_buffer.flip
      return gl_texture_buffer
    end

    def create_texture_image(has_alpha, gl_size)
      raster = Jai.Raster.create_interleaved_raster(Jai.DataBuffer::TYPE_BYTE, gl_size.width, gl_size.height, has_alpha ? 4 :  3, nil)
      color_space = Ja.color.ColorSpace.getInstance(Ja.color.ColorSpace::CS_sRGB)
      color_model =
        (has_alpha ?
         Jai.ComponentColorModel.new(color_space, Array[8, 8, 8, 8].to_java(:int), true, false, Ja.Transparency::TRANSLUCENT, Jai.DataBuffer::TYPE_BYTE) :
         Jai.ComponentColorModel.new(color_space, Array[8, 8, 8, 0].to_java(:int), false, false, Ja.Transparency::OPAQUE, Jai.DataBuffer::TYPE_BYTE))
      return Jai.BufferedImage.new(color_model, raster, false, java.util.Hashtable.new)
    end

    def create_texture_id
      id_buffer = org.lwjgl.BufferUtils.createIntBuffer(1)
      begin
        GL11.glGenTextures(id_buffer)
      rescue NativeException => ex
        raise 'create_texture_id must be called from the GL thread, and GL display must be initialized first.' if ex.cause.is_a?(java.lang.NullPointerException)
        raise
      end
      id_buffer.get(0)
    end

    # texture generation

    def get_font(font_cache, font_size, style = Ja.Font::PLAIN, resource_name = 'font/Vera.ttf')
      font_cache.cache(resource_name) {
        ResourceLoader.get_resource_as_stream(resource_name) { |input_stream|
          Ja.Font.create_font(Ja.Font::TRUETYPE_FONT, input_stream)
        }
      }.derive_font(style, font_size)
    end

    def draw(font_cache, desc)
      case desc
      when TextTextureDesc then draw_text(get_font(font_cache, desc.font_size), desc.text.to_s, desc.color.to_java)
      else raise 'bad texture description "%s"' % desc
      end
    end

    def draw_text(font, text, color)
      frc = Jai.BufferedImage.new(1, 1, Jai.BufferedImage::TYPE_INT_ARGB).createGraphics.get_font_render_context
      rect, line_metrics = font.get_string_bounds(text, frc), font.get_line_metrics(text, frc)
      image = Jai.BufferedImage.new(rect.width, rect.height, Jai.BufferedImage::TYPE_INT_ARGB)
      g = image.createGraphics
      g.font = font
      g.color = color
      g.draw_string(text, 0, rect.height - line_metrics.descent)
      return image
    end

    def draw_noise(size, gl_size) # slow... but I couldn't do faster with jruby: create a ruby string and use to_java_bytes
      h = Array.new(256) { |i| [(0.3 * i).to_i, (0.5 * i).to_i, (0.9 * i).to_i, 255].pack('c*') }
      bytes = '\0' * (gl_size.x * gl_size.y * 4)
      xmax, ymax, gx = size.x.to_i-1, size.y.to_i-1, gl_size.x.to_i
      (0..xmax).each { |i|
        (0..ymax).each { |j|
          c = ((Math.sin(i + j * j) + 1) * 128.0)
          color = h[c.to_i]
          index = (i + j * gx) * 4
          bytes[index..index+3] = color
        }
      }
      bytes = bytes.to_java_bytes
      return convert_bytes_to_gl(bytes)
    end
  end
end

exec_once('zdfdfgfgfrhfhgffrffhgfe') { # for texture generation testing
  $engine.texture_loader.reload_all
}
