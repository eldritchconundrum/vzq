# -*- coding: iso-8859-1 -*-
require 'core/ext_sysutils'

# project-specific utilities (without external dependencies)

class Numeric
  def next_power_of_two
    ret = 1
    while ret < self; ret *= 2; end
    ret
  end
end
raise 'unit test' if 5.next_power_of_two != 5.2.next_power_of_two

module Renewable
 def Renewable.included(mod)
   unless mod.respond_to?(:true_new)
     mod.instance_eval do
       class << mod
         alias_method :true_new, :new
       end
       def new(*args, &block)
         obj = true_new(*args, &block)
         obj.instance_variable_set(:@saved_ctor_args, [args, block])
         return obj
       end
     end
   end
 end
 def renew
   self.class.new(*@saved_ctor_args[0], &@saved_ctor_args[1])
 end
end
class RenewTest; include Renewable; attr_reader :val; def initialize(arg); @val = arg; end; end
raise 'unit test' if RenewTest.new(2097).renew.val != 2097
class RenewTest2; include Renewable; attr_reader :val; def initialize(&b); @val = b; end; end
raise 'unit test' if RenewTest2.new{'a'}.renew.val.call != 'a'

class Point2D # a point of int or of float, depending on your needs
  def initialize(x, y)
    @x, @y = x, y
  end
  attr_accessor :x, :y
  alias_accessor :width, :x
  alias_accessor :height, :y
  alias_accessor :w, :x
  alias_accessor :h, :y
  def to_s
    "(%s,%s)" % [@x, @y]
  end
  def ==(p); p.x == @x && p.y == @y; end
  def +(p); Point2D.new(@x + p.x, @y + p.y); end
  def -(p); Point2D.new(@x - p.x, @y - p.y); end
  def *(d); Point2D.new(@x * d, @y * d); end
  def /(d); Point2D.new(@x / d, @y / d); end
  def member_product(p); Point2D.new(@x * p.x, @y * p.y); end
  def sqr_dist; @x*@x+@y*@y; end
  def dist(p); Math.sqrt((p-self).sqr_dist); end
  def coerce(n) # ruby's way of handling commutativity of operators
    fail 'not a Numeric' unless n.is_a?(Numeric)
    return self, n
  end
  def clone
    Point2D.new(@x, @y)
  end
end
raise 'unit test' if Point2D.new(2, 4) * 2 != 2 * Point2D.new(2, 4) || Point2D.new(2, 3) == Point2D.new(1, 4)

const_redef :V2I, Java.vzq.engine.V2I
class V2I
  def +(p); self.plus(p); end
  def -(p); self.minus(p); end
  def *(n); self.mult(n); end
  def /(n); self.div(n); end
  def coerce(n) # ruby's way of handling commutativity of operators
    fail 'not a Numeric' unless n.is_a?(Numeric)
    return self, n
  end
end
fail 'unit test' unless V2I.new(1, 5) == V2I.new(1, 5)
#const_redef :V2I, Point2D

# project-specific utilities (with external dependencies)


const_def :RGBABase, ClassWithFields([:r, :g, :b, :a])
class RGBA < RGBABase
  def to_s; '0x%02x%02x%02x%02x' % [r, g, b, a]; end
  def inspect; "RGBA[%s,%s,%s,%s]" % [r, g, b, a]; end
  def to_java; java.awt.Color.new(r, g, b, a); end
  class << self
    def [](r, g, b, a = 255)
      RGBA.new(r.to_i, g.to_i, b.to_i, a.to_i)
    end
  end
  # TODO: also accept hexa string and floats between 0 and 1
end
class RGB
 class << self
    def [](*args)
      RGBA[*args]
    end
  end
end
class RGBAF
 class << self
    def [](*args)
      RGBA[*args.map { |f|
             f = 0.0 if f < 0.0
             f = 1.0 if f > 1.0
             (f * 255).to_i
           }]
    end
  end
end
const_def :RGBAWhite, RGB[255, 255, 255]
const_redef :RGBATransparent, RGBA[0, 0, 0, 0]

class Utils
  class << self
    # TODO: move time {} to WallClock
    def time # return ms spent in given block
      start = WallClock.time
      yield
      WallClock.time - start
    end

    def array_from_varargs(array)
      array.size == 1 && array.first.respond_to?(:each) ? array.first : array
    end
  end
end

class Profiler
  attr_accessor :enabled
  def initialize(enabled = true)
    @p = Hash.new(0) # time profiling (ms)
    @last = WallClock.time
    @enabled = enabled
  end
  def prof(tag, &block)
    if @enabled then
      start = WallClock.time
      result = block.call
      @p[tag] += WallClock.time - start
    else
      result = block.call
    end
    return result
  end
  def show
    return '' unless @enabled
    now = WallClock.time
    duration, @last = (now - @last), now
    @p.each { |k,v| @p[k] = ((v * 1000.0 / duration)*10).round/10.0 }
    groups = @p.group_by { |k,v| k.to_s.match(/^[^_]*_/).to_s }
    s = ''
    groups.each { |group_key, kv_list|
      kv_list = kv_list.sort_by { |k,v| k.to_s }
      s += "#{group_key}*".ljust(25) + " = %s\n" % kv_list.transpose[1].inject(0) {|a,b|a+b}
      kv_list.each { |kv| s += "        #{kv[0]}".ljust(33) + " = #{kv[1]}\n" }
    }
    @p.clear
    return s
  end
end

# tous les temps de VZQ sont en millisecondes si non précisé
class Clock
  attr_reader :time
  def initialize(time = 0)
    @time = time.to_i
  end

  def advance_time(delta_ms)
    @time += delta_ms.to_i
  end

  def reset
    @time = 0
  end
end

class WallClockInstance
  include Singleton
  const_def :Sys => org.lwjgl.Sys
  @@timerTicksPerSecond = Sys.getTimerResolution
  def time
    (Sys.getTime() * 1000) / @@timerTicksPerSecond
  end
end
const_def :WallClock, WallClockInstance.instance

class WaitManager
  attr_accessor :target
  def initialize(target, clock)
    @clock = clock
    @target = target
    @interval_funcs = {} # name -> func returning milliseconds
    @last_times = {} # name -> time
  end
  def add(name, interval_cfg = nil, &interval_func)
    @interval_funcs[name] = interval_func
    @interval_funcs[name] = interval_cfg unless interval_cfg.nil?
    @last_times[name] = @clock.time
  end
  def del(name)
    @interval_funcs.delete name
    @last_times.delete name
  end
  def run_events
    now = @clock.time
    @last_times.each { |name, last_time|
      interval = @interval_funcs[name].from_config_value # only call them again on code reload?
      if last_time + interval <= now
        @last_times[name] = now
        result = if name.respond_to? :call # name can now be a lambda
                   name.call
                 else
                   @target.send(name)
                 end
        del(name) if result == :remove_this_event
      end
    }
  end
end

class ElapsedTimeWait
  def initialize(clock, duration_cfg)
    @clock = clock
    @duration_cfg = duration_cfg
    @start_time = nil
  end
  def reset
    @start_time = @clock.time
  end
  def duration
    @duration_cfg.from_config_value
  end
  def is_over
    d = duration
    return false if d.nil?
    d = d.to_i # ms
    return (d != -1 && (@start_time.nil? || @clock.time - @start_time > d))
  end
  def is_over_auto_reset
    return false if !is_over
    reset
    true
  end
end

class ResourceLoader
  class << self
    def make_full_path(filename)
      puts 'loading %s' % filename
      EngineConfig.resource_root + filename
    end
    def get_stream(filename) # java.io.InputStream
      class_loader = JRuby.runtime.jruby_class_loader
      stream = fail_if_nil(filename, class_loader.getResourceAsStream(make_full_path(filename)))
      begin
        result = yield(stream)
      ensure
        stream.close
      end
      return result
    end
    def get_wavedata(filename)
      fail_if_nil(filename, org.lwjgl.util.WaveData.create(make_full_path(filename)))
    end
    private
    def fail_if_nil(filename, stream)
      raise 'resource file "%s" not found' % filename if stream.nil?
      stream
    end
  end
end

# TODO: qu'est-ce que je pourrais bien faire faire à un autre processeur ? hmm la collision détection, avec une frame de retard !

class AsyncCache
  attr_reader :default_proc
  def initialize(&block) # no nil keys, no nil values!
    @default_proc = block
    @inner = java.util.concurrent.ConcurrentHashMap.new # java sous la main c'est pratique des fois
  end
  def background_preload(key)
    return if @inner.contains_key(key)
    Thread.new { compute_default_value(key) }
  end
  def get(key) # nil if not found
    value = @inner.get(key)
    return value unless value.nil?
    value = compute_default_value(key)
  end
  def clear
    @inner.clear
  end
  private
  def compute_default_value(key)
    value = @default_proc.nil? ? nil : @default_proc.call(key)
    @inner.put_if_absent(key, value)
    value
  end
end
#a=AsyncCache.new { |k| sleep 1; k+1 }
#puts a.get(5)
#a.background_preload(10)
#sleep 1.1
#puts a.get(10)


module Stuff # à inclure que dans les trucs "engine", "view" ? pas "model" ?
  # TODO: conf le logging par menu
  const_redef :GL11, (false ? CallTracer.new(org.lwjgl.opengl.GL11, 'GL11') : org.lwjgl.opengl.GL11)
  const_def :GL12, org.lwjgl.opengl.GL12
  const_redef :GL15, (false ? CallTracer.new(org.lwjgl.opengl.GL15, 'GL15') : org.lwjgl.opengl.GL15)
  const_def :ByteOrder, Java.java.nio.ByteOrder
  const_def :ByteBuffer, Java.java.nio.ByteBuffer
  const_def :FloatBuffer, Java.java.nio.FloatBuffer
  const_def :IntBuffer, Java.java.nio.IntBuffer
end
include Stuff

require 'singleton'
