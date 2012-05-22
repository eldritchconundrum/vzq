# -*- coding: iso-8859-1 -*-


# experimental: solution to the need of late evaluation of config options
# hmmmm TODO: à tester (à la place de passer des procs explicitement, déjà)
class Object
  def from_config_value
    self
  end
end

class Proc
  def from_config_value # sera-ce utilisé ?
    call
  end
end

# ne faire aucun configvalue.new depuis le code, les faire depuis dans
# ConfBase, pour s'assurer que tout le monde référence toujours la
# meme instance de ConfigValue, pour que quand elle change, tout le
# monde suive.

class ConfigValue
  attr_reader :name
  def initialize(name)
    @name = name
  end

  def to_s
    "%s = %s" % [@name, from_config_value]
  end

  def set(value = nil, &block)
    @constant_value, @block = if block_given? then
                                [nil, block]
                              else
                                [value, nil]
                              end
    puts "config value change: %s" % self if $VERBOSE
  end

  def from_config_value
    fail "config value %s not found" % @name unless defined?(@block)
    if @block.nil? then @constant_value else @block.call end
  end
end
a = ConfigValue.new('')
a.set { 2 }
t = [1.from_config_value, a.from_config_value, lambda { 3 }.from_config_value]
a = ConfigValue.new('')
a.set(4)
t << a.from_config_value
a.set { 5 }
t << a.from_config_value
fail 'unit test: %s' % t.inspect unless t == [1,2,3,4,5]






# all config values are defined as blocks

class ConfBase # method_missing-based hashtable of blocks
  def initialize
    @blocks = {}
  end
  def method_missing(method, *args, &block)
    if block_given?
      @blocks[method.to_sym] = block
    else
      block = @blocks[method.to_sym]
      fail "config value %s not found" % method.to_sym.to_s if block.nil?
      block.call(*args)
    end
  end
  def toggle(name) # mouaif ; c'est pas le boulot des IHM de paramétrage ça ?
    b = !self.send(name)
    self.send(name, &proc { b })
  end
end

class ConfBase2 # ensures that the ConfigValue instances used are always the same
  def initialize
    @config_values = Hash.new { |h, name|
      h[name] = ConfigValue.new(name)
    }
  end
  def [](name)
    @config_values[name.to_s]
  end
  def method_missing(method, *args, &block)
    if block_given? || args.size > 0
      super(method, *args, &block)
    else
      self[method]
    end
  end
  def toggle(name)
    self[name].set(!self[name].from_config_value)
  end
end

const_def :EngineConfig2, ConfBase2.new # pratique pour les settings
                                        # utilisés depuis
                                        # ElapsedTimeWait ou
                                        # WaitManager
const_def :EngineConfig, ConfBase.new   # pratique quand meme pour les settings de l'engine

EngineConfig2.reload_code_wait_in_ms.set 3000 # ms ; -1 disables
EngineConfig2.fpsTimeIntervalInMs.set 1000
EngineConfig2.default_font.set 'font/Vera.ttf'
EngineConfig2.limit_fps.set true
EngineConfig2.drawarrays_sans_vbo.set false
EngineConfig2.use_display_lists_not_drawarray.set true
EngineConfig2.disable_draw.set false
EngineConfig2.pause_when_not_focused.set false
EngineConfig2.vbo_use_mapbuffer.set true

EngineConfig.resource_root { 'res/' }
EngineConfig.default_display_frequency { 60 } # -1 or > 0
EngineConfig.ortho { Point2D.new(800, 600) }
EngineConfig.debug { true }
EngineConfig.use_gl { true }

def EngineConfig.debug_sprite_box(drawer); false && EngineConfig.debug; end

# y'a une vraie réfléxion à avoir sur quoi comme config et où
# -> quand est-ce que ça change ?
# la valeur de config est-elle
#   une config de l'utilisateur ?  -> dans un ~/.vzq/* user ?
#   un paramétrage de l'engine ?   -> EngineConfig ?
#   un simple état du jeu ?        -> dans la représentation ad-hoc du jeu ?
#   un tuning de jouabilité ?      -> dans la représentation ad-hoc du jeu ?


exec_once('mfyfofsghgzb456fshgdw') {
  #EngineConfig2.reload_code_wait_in_ms.set -1
  # Engine.games.last.instance_eval { @player.fire_level = 9 }
  # Engine.renderer.display_frequency = -1 # EngineConfig.default_display_frequency
}

# utiliser une string et eval ! la lenteur éventuelle n'est pas grave pour une valeur de config
