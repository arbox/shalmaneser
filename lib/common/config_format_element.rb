##############################
# ConfigFormatelement is an auxiliary class
# of ConfigData.
# It keeps track of feature patterns with variables in them
# that can be instantiated.
# @author Andrei Beliankou
#
class ConfigFormatElement

  # given a pattern and a list of variable names,
  # analyze the pattern and remember the variable names
  #
  def initialize(string, # string: feature name, may include names of variables.
                         # they are included in <>
                 variables) # list of variable names that can occur

    @variables = variables

    # pattern: this is what the 'string' is split into,
    # an array of elements that are either fixed parts or variables.
    # fixed part: pair [item:string, "string"]
    # variable: pair [variable_name:string, "variable"]
    @pattern = []
    state = "out"
    item = ""

    # analyze string,
    # split into variables and fixed parts
    string.split(//).each { |char|

      case state
      when "in"
        case char
        when "<"
          raise "Duplicate < in " + string
        when ">"
          unless @variables.include? item
            raise "Unknown variable " + item
          end
          @pattern << [item, "variable"]
          item = ""
          state = "out"
        else
          item << char
          state = "in"
        end

      when "out"
        case char
        when "<"
          unless item.empty?
            @pattern << [item, "string"]
            item = ""
          end
          state = "in"
        when ">"
          raise "Unexpected > in " + string
        else
          item << char
          state = "out"
        end

      else
        raise "Shouldn't be here"
      end
    }

    # read through the whole of "string"
    # end state has to be "out"
    unless state == "out"
      raise "Unclosed < in " + string
    end

    # last bit still to be recorded?
    unless item.empty?
      @pattern << [item, "string"]
    end

    # make regexp for matching this pattern
    @regexp = make_regexp(@pattern)
  end

  # instantiate: given pairs of variable names and variable values,
  # instantiate @pattern to a string in which var names are replaced
  # by their values
  #
  # returns: string
  def instantiate(var_hash) # hash variable name(string) => variable value(string)

    # instantiate the pattern
    return @pattern.map { |item, string_or_var|

      case string_or_var
      when "string"
        item

      when "variable"

        if var_hash[item].nil?
          raise "Missing variable instantiation: " + item
        end
        var_hash[item]

      else
        raise "Shouldn't be here"
      end
    }.join
  end

  # match()
  #
  # given a string, try to match it against the @pattern
  # while setting the variables given in 'fillers' to
  # the values given in that hash.
  #
  # returns: if the string matches, a hash variable name => value
  #   that includes the fillers given as a parameter as well as
  #   values for all other variables mentioned in @pattern,
  #   or false if no match.
  def match(string,   # a string
            fillers = nil) # hash variable name(string) => value(string)

    # have we been given partial info about variables?
    if fillers
      match = make_regexp(@pattern, fillers).match(string)
#      $stderr.print "matching " + make_regexp(@pattern, fillers).source +
#       " against " + string + " "
#      if match.nil?
#       $stderr.puts "no"
#      else
#       $stderr.puts "yes"
#      end
    else
      match = @regexp.match(string)
    end

    if match.nil?
      # no match via the regular expression
      return false
    end

    # regular expression matched.
    # construct return value in hash
    # retv: variable name(string) => value(string)
    retv = Hash.new()
    if fillers
      # include given fillers in retv hash
      fillers.each_pair { |name, val| retv[name] = val }
    end

    # now put values for other variables in @pattern into retv
    index = 1
    @pattern.to_a.select { |item, string_or_var|
      string_or_var == "variable"
    }.select { |item, string_or_var|
      fillers.nil? or
        fillers[item].nil?
    }.each { |item, string_or_var|
      # for all items on the pattern list
      # that are variables and
      # haven't been filled by the "fillers" list already:
      # fill from matches

      if match[index].nil?
        raise "Match, but not enough matched elements? Strange."
      end

      if retv[item].nil?
        retv[item] = match[index]
      else
        unless retv[item] == match[index]
          return false
        end
      end

      index += 1
    }

    return retv
  end

  # used_variables
  #
  # returns: an array of variable names used in @pattern
  def used_variables()
    return @pattern.select { |item, string_or_var|
      string_or_var == "variable"
    }.map { |item, string_or_var| item}
  end

  ####################
  private

  # make_regexp:
  # make regular expression from a pattern
  # together with some variable fillers
  #
  # returns: Regexp object
  def make_regexp(pattern,  # array of pairs [string, "string"] or [string, "variable"]
                  fillers = nil) # hash variable name(string) => value(string)
    return (Regexp.new "^" +
      pattern.map { |item, string_or_var|
      case string_or_var
      when "variable"
        if fillers and
            fillers[item]
          Regexp.escape(fillers[item])
        else
          "(.+)"
        end
      when "string"
        Regexp.escape(item)
      else
        raise "Shouldn't be here"
      end
    }.join + "$")
  end
end
