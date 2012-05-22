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

module Enumerable
  def group_by
    r = Hash.new
    each{ |e| (r[yield(e)] ||= []) << e }
    r
  end
end
raise 'unit test' if [1,2,3,4].group_by{|n|n%2} != {1 => [1,3], 0 =>[2,4]}
