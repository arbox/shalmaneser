require_relative 'enumerable_bool'
require_relative 'enumerable_distribute'
require_relative 'subsumed'

# Extensions for the class Array.
class Array
  include EnumerableBool
  include EnumerableDistribute

  ###
  # interleave N arrays:
  # given arrays [a1... an], [b1,...,bn], ..[z1, ...,zn]
  # return [[a1,b1, .., z1]...,[an,bn, .., zn]]
  #
  # if one array is longer than the other,
  # e.g. [a1...an], [b1,...,bm] with n> m
  # the result is
  # [[a1,b1],...[am, bm], [am+1, nil], ..., [an, nil]]
  # and analogously for m>n
  def interleave(*arrays)
    len = [length, arrays.map(&:length).max].max
    (0..len-1).to_a.map do |ix|
      [at(ix)] + arrays.map { |a| a[ix] }
    end
  end

  ###
  # count the number of occurrences of element in this array
  def count(element)
    num = 0
    each { |my_element|
      if my_element == element
        num += 1
      end
    }

    num
  end

  ###
  # count the number of occurrences of
  # elements from list in this array
  def counts(list)
    num = 0
    each { |my_element|
      if list.include? my_element
        num += 1
      end
    }
    return num
  end

  ###
  # draw a random sample of size N
  # from this array
  def sample(size)
    if size < 0
      return nil
    elsif size == 0
      return []
    elsif size >= length
      return self.clone
    end

    rank = {}
    each { |my_element|
      rank[my_element] = rand
    }
    return self.sort { |a, b| rank[a] <=> rank[b] }[0..size-1]
  end

  def map_with_index(&block)
    retv = []

    each_with_index { |x, index|
      retv << block.call(x, index)
    }

    return retv
  end
end
