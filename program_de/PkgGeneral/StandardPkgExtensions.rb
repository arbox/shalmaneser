# Katrin Erk Oct 05
#
# useful extensions to standard classes

require "ftools"

class String
  def startswith(other_string)
    self[0..other_string.length() - 1] == other_string
  end

  def endswith(other_string)
    not(other_string.length() > self.length()) and 
        self[self.length() - other_string.length()..-1] == other_string
  end
end

class File
  ########
  # check whether a given path exists,
  # and if it doesn't, make sure it is created.
  #
  # piece together the strings in 'pieces' to make the path,
  # appending "/" to all strings if necessary
  #
  # returns: the path pieced together
  def File.new_dir(*pieces) # strings, to be pieced together

    dir_path, dummy = File.make_path(pieces, true)
    unless File.exists? dir_path
      File.makedirs dir_path
    end
    # check that all went well in creating the directory)
    File.existing_dir(dir_path)

    return dir_path
  end

  ########
  # same as new_dir, but last piece is a filename
  def File.new_filename(*pieces)
    dir_path, whole_path = File.make_path(pieces, false)
    unless File.exists? dir_path
      File.makedirs dir_path
    end
    # check that all went well in creating the directory)
    File.existing_dir(dir_path)

    return whole_path
  end


  #####
  # check whether a given path exists,
  # and report failure of it does not exist.
  #
  # piece together the strings in 'pieces' to make the path,
  # appending "/" to all strings if necessary
  #
  # returns: the path pieced together
  def File.existing_dir(*pieces) # strings

    dir_path, dummy = File.make_path(pieces, true)
    
    unless File.exists? dir_path and File.directory? dir_path
      $stderr.puts "Error: Directory #{dir_path} doesn't exist. Exiting."
      exit(1)
    end
    unless File.executable? dir_path
      $stderr.puts "Error: Cannot access directory #{dir_path}. Exiting."
      exit(1)
    end

    return dir_path
  end

  ####
  # like existing_dir, but last bit is filename
  def File.existing_filename(*pieces) # strings

    dir_path, whole_path = File.make_path(pieces, false)
    
    unless File.exists? dir_path and File.directory? dir_path
      $stderr.puts "Error: Directory #{dir_path} doesn't exist. Exiting"
      exit(1)
    end
    unless File.executable? dir_path
      $stderr.puts "Error: Cannot access directory #{dir_path}. Exiting."
      exit(1)
    end

    return whole_path
  end

  ####
  # piece together the strings in 'pieces' to make a path,
  # appending "/" to all but the last string if necessary
  #
  # if 'pieces' is already a string, take that as a one-piece path
  # 
  # if dir is true, also append "/" to the last piece of the string
  #
  # the resulting path is expanded: For example, initial
  # ~ is expanded to the setting of $HOME
  #
  # returns: pair of strings (directory_part, whole_path)
  #
  def File.make_path(pieces,      # string or array:string
                     is_dir = false) # Boolean: is the path a directory?

    if pieces.kind_of? String
      pieces = [ pieces ]
    end

    dir = ""
    # iterate over all but the filename
    if is_dir
      last_dir_index = -1
    else
      last_dir_index = -2
    end
    pieces[0..last_dir_index].each { |piece|
      if piece.nil?
        # whoops, nil entry in name of path!
        $stderr.puts "File.make_path ERROR: nil for piece of path name."
        next
      end
      if piece =~ /\/$/
        dir << piece
      else
        dir << piece << "/"
      end
    }
    dir = File.expand_path(dir)
    # expand_path removes the final "/" again
    unless dir =~ /\/$/
      dir = dir + "/"
    end

    if is_dir
      return [dir, dir]
    else
      return [dir, dir + pieces[-1]]
    end
  end

end

#############################################
class Array

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
    len = [length(), arrays.map { |a| a.length() }.max()].max()
    (0..len-1).to_a.map { |ix| 
      [at(ix)] + arrays.map { |a| a[ix] }
    }
  end

  ###
  # prepend: prepend element to array
  # because I can never remember which is 'shift' 
  # and which is 'unshift'
  def prepend(element)
    unshift(element)
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
    return num
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
    elsif size >= length()
      return self.clone()
    end

    rank = Hash.new()
    each { |my_element|
      rank[my_element] = rand()
    }
    return self.sort { |a, b| rank[a] <=> rank[b] }[0..size-1]
  end
end

class Float
  ###
  # round a float to the given number of decimal points
  def round_to_decpts(n)
    if self.nan?
      return self
    else
      return (self * 10**n).round.to_f / 10**n
    end
  end
end

################
module EnumerableBool
  ###
  # And_{x \in X} block(x)
  def big_and(&block)
    each { |x|
      unless block.call(x)
	return false
      end
    }
    return true
  end

  ###
  # Or_{x \in X} block(x)
  def big_or(&block)
    each { |x|
      if block.call(x)
	return true
      end
    }
    return false
  end

  ###
  # Sum_{x \in X} block(x)
  def big_sum(init = 0, &block)
    sum = init
    unless block_given?
      block = Proc.new { |x| x}
    end
    each { |x|
      sum += block.call(x)
    }
    return sum
  end
end

################
# Given an enumerable, distribute its items into two bins (arrays)
# depending on whether the block returns true
module EnumerableDistribute
  def distribute(&block)
    retv1 = Array.new
    retv2 = Array.new
    each { |x|
      if block.call(x)
        retv1 << x
      else
        retv2 << x
      end
    }
    return [retv1, retv2]
  end
end

#####################
# map with index 
module MapWithIndex
  def map_with_index(&block)
    retv = Array.new

    each_with_index { |x, index|
      retv << block.call(x, index)
    }

    return retv
  end
end

# include new Mixins into array already.
# for other classes, do this when requiring StandardPkgExtensions
class Array
  include EnumerableBool
  include EnumerableDistribute
  include MapWithIndex
end
