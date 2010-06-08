# ruby-1.9 backports

module Enumerable
  def count; n = 0; each { |x| n += 1 if yield(x) }; n; end
end
raise 'unit test' if [1,2,3,4].count { |n| n % 2 == 0 } != 2

class Array
  def shuffle
    a = self.clone
    (0..a.length-2).each { |i|
      r = rand(a.length - i - 1) + i + 1
      a[r], a[i] = a[i], a[r]
    }
    return a
  end unless respond_to?(:shuffle)
end
raise 'unit test' if [1,2,3,4].shuffle.nil?

# truly generic additions to std lib

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
  def with(hash)
    hash.each { |k, v| self.send(k.to_s.chomp('=') + '=', v) }
    self
  end
end
