# Extensions for the class Array.
class Array
  # @note This method is used by [RosyConfusability]
  def subsumed_by?(array2)
    log_the_method_call
    temp = array2.clone

    self.each { |el|
      found = false
      temp.each_index { |ix|
        if el == temp[ix]
          temp.delete_at(ix)
          found = true
          break
        end
      }
      unless found
        return false
      end
    }

    return true
  end

  def distribute(&block)
    log_the_method_call
    retv1 = []
    retv2 = []
    each do |x|
      if block.call(x)
        retv1 << x
      else
        retv2 << x
      end
    end

    [retv1, retv2]
  end

  ###
  # And_(x \in X) block(x)
  def big_and(&block)
    log_the_method_call
    each do |x|
      unless block.call(x)
        return false
      end
    end

    true
  end

  ###
  # Sum_(x \in X) block(x)
  def big_sum(init = 0, &block)
    log_the_method_call
    sum = init
    block = proc { |x| x } unless block_given?
    each { |x| sum += block.call(x) }

    sum
  end

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
    log_the_method_call
    len = [length, arrays.map(&:length).max].max
    (0..len-1).to_a.map do |ix|
      [at(ix)] + arrays.map { |a| a[ix] }
    end
  end

  ###
  # count the number of occurrences of element in this array
  def count(element)
    log_the_method_call
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
    log_the_method_call
    log_the_method_call
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
    log_the_method_call
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
    log_the_method_call
    retv = []

    each_with_index { |x, index|
      retv << block.call(x, index)
    }

    return retv
  end

  private

  def log_the_method_call
    return
    File.open('/tmp/shalmaneser.log', 'a') do |f|
      f.puts caller
    end
  end
end
