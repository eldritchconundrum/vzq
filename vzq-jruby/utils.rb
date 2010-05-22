# generic additions to std lib

module Enumerable # for ruby-1.8 compat
  def count; n = 0; each { |x| n += 1 if yield(x) }; n; end
end

raise 'unit test' if [1,2,3,4].count { |n| n % 2 == 0 } != 2
class Hash
  def cache(key, &block); self.has_key?(key) ? self[key] : (self[key] = block.call); end
end
class Module
  def alias_accessor(new_member, aliased_member)
    alias_method new_member, aliased_member
    alias_method((new_member.to_s + '=').to_sym, (aliased_member.to_s + '=').to_sym)
  end
end
class Fixnum
  def next_power_of_two
    ret = 1
    while ret < self; ret *= 2; end
    ret
  end
end
class Object
  def with(hash)
    hash.each { |k, v| self.send(k.to_s.chomp('=') + '=', v) }
    self
  end
end

class Point2D
  def initialize(x, y)
    @x, @y = x.to_f, y.to_f
  end
  attr_accessor :x, :y
  alias_accessor :width, :x
  alias_accessor :height, :y
  def to_s
    "(%s,%s)" % [@x, @y]
  end
  def ==(p); p.x == @x && p.y == @y; end
  def +(p); Point2D.new(@x + p.x, @y + p.y); end
  def -(p); Point2D.new(@x - p.x, @y - p.y); end
  def *(d); Point2D.new(@x * d, @y * d); end
  def /(d); Point2D.new(@x / d, @y / d); end
end
raise 'unit test' if Point2D.new(2, 4) != Point2D.new(2, 4) || Point2D.new(2, 3) == Point2D.new(1, 4)

# specific

class Utils
  class << self
    @@timerTicksPerSecond = org.lwjgl.Sys.getTimerResolution
    def get_time; (org.lwjgl.Sys.getTime() * 1000) / @@timerTicksPerSecond; end # milliseconds
    def chrono
      date = get_time
      yield
      get_time - date
    end
    def time # return ms spent in given block
      start = get_time
      yield
      get_time - start
    end
  end
end

class WaitManager
  def initialize(item)
    @item = item
    @interval_funcs = {} # name -> func returning milliseconds
    @last_times = {} # name -> time
  end
  def add(name, &interval_func)
    @interval_funcs[name] = interval_func
    @last_times[name] = Utils.get_time
  end
  def run_events
    now = Utils.get_time
    @last_times.each { |name, last_time|
      interval = @interval_funcs[name].call # only call them again on code reload?
      if last_time + interval <= now
        @last_times[name] = now
        @item.send(name)
      end
    }
  end
end

class ElapsedTimeWait
  def initialize(&duration_proc)
    @duration_proc = duration_proc
    @start_time = nil
  end
  def duration
    @duration_proc.nil? ? nil : @duration_proc.call
  end
  def reset
    @start_time = Utils.get_time
  end
  def is_over
    d = duration
    return false if d.nil?
    d = d.to_i # ms
    return d != -1 && (@start_time.nil? || Utils.get_time - @start_time > d)
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
    def get_resource_as_stream(filename)
      stream = fail_if_nil(filename, JRuby.runtime.jruby_class_loader.getResourceAsStream(make_full_path(filename)))
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
