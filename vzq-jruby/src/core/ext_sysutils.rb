require 'core/ext_backports-1.9'

# extensions of std lib

class Hash
  def cache(key, &block); self.has_key?(key) ? self[key] : (self[key] = block.call); end
end

class Module
  def alias_accessor(new_member, aliased_member)
    alias_method new_member, aliased_member
    alias_method((new_member.to_s + '=').to_sym, (aliased_member.to_s + '=').to_sym)
  end
end

class Object
  def assert(cond, message = 'assert')
    fail message unless cond
  end

  def with(hash)
    hash.each { |k, v| self.send(k.to_s.chomp('=') + '=', v) }
    self
  end

  def const_def(*args)
    if args.size == 1
      args[0].each { |k, v| _const_def(k, v) }
    else
      _const_def(*args)
    end
  end

  def const_redef(*args)
    if args.size == 1
      args[0].each { |k, v| _const_redef(k, v) }
    else
      _const_redef(*args)
    end
  end

  def const_undef(*args)
    for const in args
      const = const.to_sym
      mod = self.is_a?(Module) ? self : self.class
      mod.send(:remove_const, const) if mod.const_defined?(const)
    end
  end

private
  def _const_def(const, value)
    const = const.to_sym
    mod = self.is_a?(Module) ? self : self.class
    mod.const_set(const, value) unless mod.const_defined?(const)
  end

  def _const_redef(const, value)
    const = const.to_sym
    mod = self.is_a?(Module) ? self : self.class
    mod.send(:remove_const, const) if mod.const_defined?(const)
    mod.const_set(const, value)
  end
end
const_undef :Test_2
fail 'unit test' unless begin; Test_2; false; rescue Exception; true; end
const_def :Test_2, 1
const_def :Test_2, 2
fail 'unit test' unless Test_2 == 1
const_redef :Test_2, 3
const_redef :Test_2, 4
fail 'unit test' unless Test_2 == 4

class CallTracer < Module
  def initialize(obj, name = obj.to_s, show_args = true)
    @obj, @name, @show_args = obj, name, show_args
  end
  def method_missing(method, *args)
    puts "TRACE:  %s.%s(%s)" % [@name, method, @show_args ? (args * ', ') : '']
    @obj.send(method, *args)
  end
  def const_missing(sym)
    puts "TRACE:  %s::%s" % [@name, sym]
    @obj.const_get(sym)
  end
end
fail unless CallTracer.new(1) + 2 == 3
module Test_1; module Foo; end; end; fail 'unit test' unless CallTracer.new(Test_1)::Foo == Test_1::Foo


module Math
  const_redef :Tau, 6.2831853071795864769
end

module Enumerable
  def unzip
    firsts, seconds = [], []
    each { |a, b| firsts << a; seconds << b }
    [firsts, seconds]
  end
  def to_hash(fail_on_dups = true, &by)
    hash = {}
    self.group_by(&by).each { |key, list|
      if list.size != 1
        message = "to_hash: duplicate found: %s" % list.inspect
        if fail_on_dups then fail(message) else warn(message) end
      end
      hash[key] = list.first
    }
    hash
  end
end

def ClassWithFields(fields, defaults = nil)
  fields, defaults = fields.to_a.unzip if fields.is_a? Hash
  c = Class.new
  $fields_defaults ||= {}
  $fields_defaults[c] = [fields, defaults]
  c.instance_eval { fields.each { |sym| attr_accessor sym } }
  c.class_eval {
    def initialize(*args)
      fields, defaults = $fields_defaults[self.class.ancestors.find { |c| $fields_defaults.include?(c) }]
      if args.empty?
        if !defaults.nil?
          fail "defaults.size (%s) != fields.size (%s)" % [defaults.size, fields.size] if defaults.size != fields.size
          fields.each_with_index { |sym,i| instance_variable_set('@'+sym.to_s, defaults[i]) }
        end
      else
        fail 'args.size (%s) != fields.size (%s)' % [args.size, fields.size] if args.size != fields.size
        fields.each_with_index { |sym,i| instance_variable_set('@'+sym.to_s, args[i]) }
      end
    end
  }
  return c
end
aaa = ClassWithFields(:a => false, :b => 'toto').new
raise 'unit test 1' if ClassWithFields(:a => false, :b => 'toto').new.b != 'toto'
raise 'unit test 2' if begin ClassWithFields(:c => 6).new.b rescue 42 end != 42
raise 'unit test 3' if ClassWithFields([:aa, :b, :z, :e]).new(7, 'g',  nil, Math::E).aa != 7
raise 'unit test 4' if ClassWithFields([:aa, :bb, :p], [nil, 'pa', 45]).new.bb != 'pa'
raise 'unit test 5' if aaa.b != 'toto'

