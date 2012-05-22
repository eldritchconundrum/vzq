# -*- coding: iso-8859-1 -*-
require 'core/utils'
require 'core/config'

class GlBackend # Ã§a reste trÃ¨s thÃ©orique
  const_def :DisplayMode, org.lwjgl.opengl.DisplayMode
  const_def :Display, org.lwjgl.opengl.Display
  const_def :GL11, org.lwjgl.opengl.GL11
  const_def :BufferUtils, org.lwjgl.BufferUtils

  def create_texture_id
    id_buffer = BufferUtils.createIntBuffer(1) # TODO: wrapper à BufferUtils qui implémente "wrap" en faisant le Array#to_java typé
    begin
      GL11.glGenTextures(id_buffer)
    rescue NativeException => ex
      if ex.cause.is_a?(java.lang.NullPointerException) then
        raise 'glGenTextures: must be called from the GL thread, and GL display must be initialized first.'
      end
      raise
    end
    id_buffer.get(0)
  end
  def delete_texture_ids(ids)
    int_buffer = BufferUtils.createIntBuffer(1) # IntBuffer.wrap does not create "direct" buffers
    int_buffer.put(ids.to_java(:int))
    GL11.glDeleteTextures(int_buffer)
  end

  def reset_display(ortho)
    GL11.glEnable(GL11::GL_TEXTURE_2D)
    GL11.glEnable(GL11::GL_BLEND)
    GL11.glDisable(GL11::GL_DEPTH_TEST)
    GL11.glMatrixMode(GL11::GL_PROJECTION)
    GL11.glLoadIdentity
    GL11.glOrtho(0, EngineConfig.ortho.width, EngineConfig.ortho.height, 0, -1, 1)
    # faut que je gÃ¨re bien les changements de rÃ©solution et tout
    GL11.glMatrixMode(GL11::GL_MODELVIEW)
    GL11.glLoadIdentity
    GL11.glBlendFunc(GL11::GL_SRC_ALPHA, GL11::GL_ONE_MINUS_SRC_ALPHA) # tester d'autres ?
  end

  def clear_frame
    GL11.glClear(GL11::GL_COLOR_BUFFER_BIT)
    GL11.glMatrixMode(GL11::GL_MODELVIEW)
    GL11.glLoadIdentity
  end

  def draw_sprite(texture, pos, size, angle, zoom)
    xzoom, yzoom = zoom.respond_to?(:x) ? [zoom.x, zoom.y] : [zoom, zoom]
    GL11.glPushMatrix
    texture.bind
    if angle != 0
      GL11.glTranslatef(pos.x + xzoom * size.x / 2, pos.y + yzoom * size.y / 2, 0)
      GL11.glScalef(xzoom, yzoom, 0) if !zoom.is_a?(Numeric) || zoom != 1
      GL11.glRotatef(angle * 360 / Math::Tau, 0, 0, 1) if angle != 0# angle is relative to center of sprite
      GL11.glTranslatef(-size.x / 2, -size.y / 2, 0)
    else
      GL11.glTranslatef(pos.x, pos.y, 0)
      GL11.glScalef(xzoom, yzoom, 0) if !zoom.is_a?(Numeric) || zoom != 1
    end
    texture.draw
    GL11.glPopMatrix
  end


  # VBOs

  # to convert from ARB VBO to standard VBO, I just replaced every
  # ARBVertexBufferObject by GL15 and removed _ARB from every method and
  # constant.

  def is_vbo_capable
    return @vbo_capable unless !defined?(@vbo_capable)
    caps = org.lwjgl.opengl.GLContext.capabilities
    fail "GL is not initialized enough" if caps.nil? # after Display.create plz kthx
    @vbo_capable = caps.GL_ARB_vertex_buffer_object
  end

  def vbo_enabled
    is_vbo_capable && !EngineConfig2.drawarrays_sans_vbo.from_config_value
  end

  def create_buffer_id
    int_buffer = BufferUtils.createIntBuffer(1)
    begin
      GL15.glGenBuffers(int_buffer)
    rescue NativeException => ex
      if ex.cause.is_a?(java.lang.NullPointerException) then
        raise 'glGenTextures: must be called from the GL thread, and GL display must be initialized first.'
      end
      raise
    end
    int_buffer.get(0)
  end

  def delete_buffer_ids(ids)
    int_buffer = BufferUtils.createIntBuffer(1) # IntBuffer.wrap does not create "direct" buffers
    int_buffer.put(ids.to_java(:int))
    GL15.glDeleteBuffers(int_buffer)
  end


  # batch-render N times from the same texture at N different source/target positions (tex_coord/vertex)
  # (wraps VBO with fallback to DrawArray)
  class BatchTextureRenderer
    attr_reader :vvbo, :tvbo
    def initialize(sprite_count = 1, vertex_usage = GL15::GL_STREAM_DRAW, tex_coord_usage = GL15::GL_STREAM_DRAW) # STREAM/STATIC/DYNAMIC _ DRAW/READ/COPY
      @use_map_buffer = EngineConfig2.vbo_use_mapbuffer.from_config_value # used for VBO only
      # TODO: "use_map_buffer = false" ne fonctionne pas
      @use_vbo = RAL.vbo_enabled # VBO or vertex array
      @sprite_count = sprite_count.to_i
      @count = @sprite_count *  4 # 4 vertex per sprite
      @value_count = @count * 2 # 2D, 2 coords by vertex
      if @use_vbo
        @vvbo = VBO.new(@value_count, vertex_usage)
        @tvbo = VBO.new(@value_count, tex_coord_usage)
      end
      unless @use_vbo && @use_map_buffer
        @vertex_array = BufferUtils.createFloatBuffer(@value_count)
        @tex_coord_array = BufferUtils.createFloatBuffer(@value_count)
      end
      puts self
    end

    def to_s
      usage_str = GL15.constants.find { |c| eval("GL15::%s" % c) == @vvbo.usage } unless @vvbo.nil?
      "[sprite%s: %s sprites, %s]" % [@use_vbo ? 'VBO' : 'VA', @sprite_count, usage_str]
    end

    def delete
      @vvbo = @vvbo.delete unless @vvbo.nil?
      @tvbo = @tvbo.delete unless @tvbo.nil?
      @vertex_array = nil
      @tex_coord_array = nil
    end

    def map_vertex_buffer_for_write(&b)
      if @use_vbo
        if @use_map_buffer
          @vvbo.map_buffer_for_write(&b)
        else
          @vertex_array.rewind
          yield @vertex_array
          @vvbo.set_buffer(@vertex_array)
        end
      else
        @vertex_array.rewind
        yield @vertex_array
      end
    end
    # TODO: for VBOs, would glBufferData be faster than glMapBuffer?
    # provide both, switch with a flag, and test
    def map_tex_coord_buffer_for_write(&b)
      if @use_vbo
        if @use_map_buffer
          @tvbo.map_buffer_for_write(&b)
        else
          @tex_coord_array.rewind
          yield @tex_coord_array
          @tvbo.set_buffer(@tex_coord_array)
        end
      else
        @tex_coord_array.rewind
        yield @tex_coord_array
      end
    end

    def draw(sprite_count = @sprite_count)
      GL11.glEnableClientState(GL11::GL_VERTEX_ARRAY)
      GL11.glEnableClientState(GL11::GL_TEXTURE_COORD_ARRAY)
      if @use_vbo
        @vvbo.bind
        GL11.glVertexPointer(2, GL11::GL_FLOAT, 0, 0)
        @tvbo.bind
        GL11.glTexCoordPointer(2, GL11::GL_FLOAT, 0, 0)
      else
        GL15.glBindBuffer(GL15::GL_ARRAY_BUFFER, 0) # in case a VBO remains bound
        GL11.glVertexPointer(2, 0, @vertex_array)
        GL11.glTexCoordPointer(2, 0, @tex_coord_array)
      end

      if true # drawArrays
        GL11.glDrawArrays(GL11::GL_QUADS, 0, sprite_count * 4) # essayer triangles ? bah
      else # drawElements
        unless defined?(@indices)
          # drawElements permet le sharing de vertex, ce qui ne me sert
          # à rien pour mes sprites 2D à positions arbitraires.  (y a
          # que du sharing entre les coordonnées de vertex). Pour faire
          # du tiling, ça servirait (division par 4 de la taille du VBO).
          @indices = BufferUtils.createIntBuffer(sprite_count * 4)
          for i in (0...sprite_count * 4) do @indices.put(i, i) end
        end
        GL11.glDrawElements(GL11::GL_QUADS, @indices)
      end

      GL11.glDisableClientState(GL11::GL_TEXTURE_COORD_ARRAY)
      GL11.glDisableClientState(GL11::GL_VERTEX_ARRAY)
    end
  end

  private
  # bufferdata, mapbuffer, unmapbuffer travaillent sur le dernier qui a été bound
  # c'est le cas pour tout ce qui prend un param "target" GL_ARRAY_BUFFER, en fait
  class VBO
    attr_reader :usage#, :gl_id
    def initialize(value_count, usage = GL15::GL_STREAM_DRAW)
      sizeof_float = 4
      @byte_count = value_count.to_i * sizeof_float
      @usage = usage
      # create VBO
      @gl_id = RAL.create_buffer_id
      # set size and access mode
      self.bind
      GL15.glBufferData(GL15::GL_ARRAY_BUFFER, @byte_count, @usage)
    end

    def delete
      RAL.delete_buffer_ids([@gl_id])
      @gl_id = nil
    end

    def bind
      GL15.glBindBuffer(GL15::GL_ARRAY_BUFFER, @gl_id)
    end

    def set_buffer(float_buffer)
      bind
      GL15.glBufferData(GL15::GL_ARRAY_BUFFER, float_buffer, @usage)
    end

    def map_buffer_for_write
      self.bind
      mapped_buffer = nil # ByteBuffer
      new_mapped_buffer = GL15.glMapBuffer(GL15::GL_ARRAY_BUFFER, GL15::GL_WRITE_ONLY,
                                             @byte_count, mapped_buffer)
      fail 'map buffer il est pas gentil' if new_mapped_buffer.nil?
      if new_mapped_buffer != mapped_buffer
        mapped_float_buffer = new_mapped_buffer.order(ByteOrder.nativeOrder).asFloatBuffer
      end
      mapped_buffer = new_mapped_buffer
      mapped_float_buffer.rewind
      yield mapped_float_buffer
    ensure
      if !GL15.glUnmapBuffer(GL15::GL_ARRAY_BUFFER)
        # during screen mode changes, we can lose all the buffer's content! restore it entirely
        fail 'TODO: glUnmapBuffer return null (screen mode change?)'
      end
    end
  end
end


exec_once('dgffsgdfffgfggffgffgfsgfd') {
}

class RenderingAbstractionLayer < (EngineConfig.use_gl ? GlBackend : NotImplementedRenderingBackend)
  include Singleton
end
const_def :RAL, RenderingAbstractionLayer.instance
const_def :BatchTextureRenderer, RAL.class::BatchTextureRenderer

