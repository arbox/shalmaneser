# class ConfigData:
#
# reads config data file,
# matches it against feature declarations given in its new() method,
# offers access methods for different kinds of features
#
# In the config file, all feature specifications have the form
#
#       feature_name = feature_value
#
# where feature_name is a string without spaces. feature_value 
# may include spaces, depending on the feature type (see below).
#
# To include a comment in a config file, start the comment line with
# '#'.
#
# Features are typed. The following types are supported:
#
# - normal types:
#   "bool", "float", "integer", "string"
#   For the get() function with which features in the ConfigData object
#   are accessed, the values are transformed from the strings in the 
#   config file to the appropriate class: Boolean, Float, Integer, String
#
# - other types:
#   pattern:  This is a feature that may include variables in 
#             <> brackets. When this feature is accesssed,
#             values for these variables are given, i.e. this
#             pattern has to be instantiated.
#             For example, given a feature 
#
#               fileformat = features.<type>.train
#
#             and method call
#               instantiate("fileformat", "type" => "path")
# 
#             what is returned is a string "features.path.train"
#
#             Variables used in a pattern have to be declared to 
#             the new() method.
#
#   list:    This is the only feature type where more than one
#            feature specification with the same feature_name is allowed.
#            The right-hand sides of a list feature are stored in an array.
#
#            Given a 'list' feature 'bla', if the config file contains
#  
#                bla = blupp 1 2
#                bla = la di da
#
#            the list feature 'bla' is represented as follows:
#            @features['bla'] = [['blupp', 1,2], ['la', 'di', 'da']]
# 
#            For comfortable access to a list feature, arbitrary
#            access functions for list features can be defined.
#
#

require 'common/StandardPkgExtensions'

#####################################################
# helper module for ConfigData:
# deal with features that are actually directories
module ConfigAlsoHandlingDirectories

  ###
  # existing_dir
  #
  # check that dir_name refers to an existing directory and that it can be accessed
  #
  # returns: dir_name(string), definitely ending in '/'
  #
  # deprecated! use File.existing_dir() instead
  def existing_dir(dir_name) # string: name of directory
    return File.existing_dir(dir_name)
  end

  ###
  # new_dir
  #
  # check whether dir_name refers to an existing directory.
  # if not, create it
  #
  # returns: dir_name(string), definitely ending in '/'
  #
  # deprecated! use File.new_dir() instead
  def new_dir(dir_name) # string: name of  directory
    return File.new_dir(dir_name)
  end  
end

#####################################################
####################################################
# ConfigData is the main class in this package.
# It manages config files.
#
# To use it, inherit from it and just make a new new() method
# that only takes as input the name of the config file
# and that declares all the feature types and variable names
# needed for the given application.

class ConfigData
  include ConfigAlsoHandlingDirectories

  ###########
  # new()
  #
  # reads the config file
  #
  # Input parameters: the name of the config file, a hash declaring all 
  # features by mapping feature names to their types,
  # and an array of all variables that may occur in pattern type features
  #
  def initialize(filename, # string: name of config file
		 feature_types, # hash: feature_name => feature_type
		 variables) # array of strings: list of variables used in pattern features

    @test_print = false
    @variables = variables
    @original_filename = filename

    ##
    # open config file
    begin
      file = File.new(filename)
    rescue
      $stderr.puts "Error: I could not open the experiment file " + filename
      exit 1
    end

    # feature_types: hash: feature_name => feature_type
    # features: hash: feature_name => value
    @feature_types = feature_types
    @features = Hash.new

    # @list_feature_access: hash feature_name => Proc
    # access method for list features
    @list_feature_access = Hash.new

    # pre-initialize list features to an empty array
    @feature_types.each_pair { |feature_name, feature_type|
      if feature_type == "list"
	@features[feature_name] = Array.new
      end
    }

    ##
    # examine the config file contents

    while (line = file.gets())
      line = line.chomp().strip()
      if line =~ /^#/   # comment
	next
      end
      
      if line.empty? # nothing to be seen here
	next
      end

      feature_name, rhs = extract_def(line)
      set_entry(feature_name, rhs)
    end
  end

  #####
  # set_entry
  #
  # set an entry in the experiment file, either an existing or a new one
  # but it must conform to the feature types declared in the new() method
  def set_entry(feature_name, rhs)

    unless @feature_types[feature_name]
      $stderr.puts "Error in experiment file:"
      $stderr.puts "Unknown parameter #{feature_name} in #{@original_filename}."
      $stderr.puts "Expected features for this type of experiment file:"
      $stderr.puts @feature_types.keys().join(", ")
      exit 1
    end

    case @feature_types[feature_name]
    when "pattern"
      # file format specification
      
      @features[feature_name] = ConfigFormatElement.new(rhs, @variables)
	
    when "list"

      # rhs is a string of space-separated words
      # the first of them is the key, the rest is the value, to be
      # stored as an array of words
      
      # split rhs into words
      if rhs.empty?
        $stderr.puts "WARNING: I got an empty value for list feature #{feature_name}."
        $stderr.puts "I'll ignore it."
      else
        unless @features[feature_name].include? rhs.split()
          @features[feature_name] << rhs.split()
        end
      end

    when "bool"
      # boolean value
      unless ["true", "false"].include? rhs
        $stderr.puts "Error in experiment file:"
        $stderr.puts "Value for #{feature_name} must be either 'true' or 'false'."
        $stderr.puts "I got: "+ rhs.to_s
        exit 1
      end
      @features[feature_name] = (rhs == "true")
      
    when "float"
      # float value
      @features[feature_name] = rhs.to_f
      
    when "integer"
      # integer value
      @features[feature_name] = rhs.to_i
      
    when "string"
      # string value
      @features[feature_name] = rhs
      
    else
      raise "Unknown feature type for feature #{feature_name}: #{@feature_types[feature_name]}"
    end
  end

  ####
  # remove list entry in this config data structure:
  # the lhs argument is the list feature name
  # the rhs argument can be a string or a regexp.
  # - string: each entry exactly matching the string is removed
  # - regexp: each entry matching the regexp is removed
  def unset_list_entry(lhs, #string: feature name
                       rhs) # string/regexp: righthand side
    unless @feature_types[lhs] == "list"
      $stderr.puts "Error in experiment file: "
      $stderr.puts "Feature #{lhs} unknown or not of type list."
      exit 1
    end

    case rhs.class.to_s
    when "String"
      rhs_match = Regexp.new("^" + Regexp.escape(rhs) + "$")
    when "Regexp"
      rhs_match = rhs
    else
      raise "Shouldn't be here: " + rhs.class.to_s
    end

    to_delete = @features[lhs].select { |entry| entry.join(" ") =~ rhs_match }
    to_delete.each { |entry| @features[lhs].delete(entry) }
  end


  #####
  # adjoin
  #
  # adds the information from a second ConfigData object
  # to this one.
  # Disjointness of feature names is assumed.
  def adjoin(config_obj)  # ConfigData object

    ##
    # sanity checks:
    # the other object must be a ConfigData object
    unless config_obj.kind_of? ConfigData
      raise "I can only adjoin another ConfigData object"
    end

    # if feature name sets are not disjoint,
    # ignore the feature names that I already have
    other_features, other_feature_types, other_list_feature_access = config_obj.get_contents()
    unless (@feature_types.keys & other_feature_types.keys).empty?
      other_features = other_features.clone()
      other_feature_types = other_feature_types.clone()
      other_list_feature_access = other_list_feature_access.clone()

      (@feature_types.keys() & other_feature_types.keys()).each { |overlap_feature|
        other_features.delete(overlap_feature)
        other_feature_types.delete(overlap_feature)
        other_list_feature_access.delete(overlap_feature)
      }
    end
    
    # now adjoin the contents of the other config objects to mine
    @features.update(other_features)
    @feature_types.update(other_feature_types)
    @list_feature_access.update(other_list_feature_access)
  end

  #####
  # get()
  #
  # returns the value of a given feature
  # raises an error if no feature of this name
  # has been declared to the new() method
  #
  # returns: a feature value. the type of the return value
  #    depends on the type of the feature.
  #    returns nil if the feature has not been set in the config file.
  def get(name) # string: name of the feature to access
    if @feature_types[name].nil?
      raise "Unknown feature " + name
    end

    # may return nil if something has not been set
    return @features[name]
  end

  ####
  # get_type
  #
  # returns the type of a given feature,
  # or nil if it is undefined
  def get_type(feature_name)
    return @feature_types[feature_name]
  end

  #####
  # is_defined
  #
  # returns: true if a feature by this name has been set in the config file,
  #   false else
  def is_defined(feature) # string: name of the feature
    if @features[feature] 
      return true
    else
      return false
    end
  end

  #####
  # instantiate
  #
  # given a pattern type feature, and a hash
  # mapping all variables occurring in the pattern to
  # values, instantiate the pattern
  #
  # returns: string, the pattern with all variables
  #  instantiated with their values
  def instantiate(key,  # string: feature name
		  var_hash={}) # hash: variable name(string) => value(string)

    unless @feature_types[key] == "pattern"
      raise "Nothing known about pattern " + key
    end
    unless @features[key]
      raise "Please define pattern in configuration file: " + key
    end

    # piece together the file name
    # expand in case it is a filename/directory
    return @features[key].instantiate(var_hash)
  end

  #####
  # get_filename:
  #
  # synonym for instantiate()
  def get_filename(key, var_hash={})
    return instantiate(key, var_hash)
  end

  #####
  # set_test_print
  #
  # set test output to on (true) or off (false)
  def set_test_print(tf) # boolean
    unless [true, false].include? tf
      raise "Shouldn't be here"
    end
    @test_print = tf
  end
	

  #####
  # get_all_filenames
  #
  # given a directory, a pattern type feature,
  # and a hash mapping some of the pattern's variables
  # to values, return all filenames in the given directory
  # that match the partially instantiated pattern
  #
  # returns: an array of pairs [filename(string), matches(hash)]
  # where the matches hash maps all variables of the pattern to
  # their values as instantiated in the given filename
  # The filename doesn't include the directory.
  def get_all_filenames(dir, #string: directory name
			key, # string: name of pattern type feature
			var_hash={}) # hash: variable name(string) => value(string)

    unless @feature_types[key] == "pattern"
      raise "Nothing known about file format " + key
    end
    
    # array of pairs [filename(string), matches(hash)]
    filenames = Array.new

    # iterate through all files of this directory
    Dir.foreach(dir) { |filename|
      # does the filename match the pattern of the feature "key"?
      if (matches = @features[key].match(filename, var_hash))
	# do the variable values for this filename conform
	# to the variable values given in var_hash?
	if @test_print
	  $stderr.puts "got " + filename
	end
	if var_hash.keys.select { |var|
	    matches[var] != var_hash[var]
	  }.empty?
	  filenames << [filename, matches]
	else
	  # mismatch for given variables
	  if @test_print
	    var_hash.keys.each { |var|
	      if matches[var] != var_hash[var]
		$stderr.puts "Mismatch for " + var + ": " +
		  matches[var].to_s + " vs. " + var_hash[var]
	      end
	    }
	  end
	end      
      end
    }

    return filenames
  end

  #####
  # set list feature access:
  # 
  # for a given list type feature, set a method that should
  # be used for accessing the feature.
  #
  # method signature: first parameter is an array of tuples of strings.
  # for each experiment file entry
  #   feature = rhs
  # there will be a tuple rhs.split() in the list.
  # 
  # The other parameters are not checked by ConfigData, there
  # may be arbitrarily many
  def set_list_feature_access(feature_name, # string: name of the feature
			      proc) # proc: access method for list feature
    unless @feature_types[feature_name] == 'list'
      raise "Cannot set list feature access to non-list feature #{feature_name}"
    end

    @list_feature_access[feature_name] = proc
  end

  #####
  # get_lf
  #
  # access a list type feature for which an access function
  # has been set using set_list_feature_access
  #
  # returns: whatever the access function returns
  def get_lf(feature_name, # string: name of list feature
	     *parameters)  # parameters for access function, collapsed into an array here

    unless @list_feature_access[feature_name]
      raise "I have no list feature access method for #{feature_name}."
    end

    # call access function, re-exploding the collapsed parameters and
    # adding the list of values for the list feature as first parameter
    return @list_feature_access[feature_name].call(@features[feature_name], *parameters)
  end


  protected

  #####
  # extract_def
  # 
  # given a line of the config file, 
  # it is assumed that it has the structure
  #  [white space] string [white space] = [white space] stuff
  #  'stuff' may include further white space, 'string' may not.
  #
  # returns: a pair of strings, the left-hand side and the right-hand side
  #  of the =, minus the [white space] in the places shown above

  def extract_def(line) # string: line from config file
    unless line =~ /^\s*(\w+)\s*=\s*([^\s].*)$/
      $stderr.puts "Error in experiment file: "
      $stderr.puts "I couldn't analyze the following line: "
      $stderr.puts line
      exit 1
    end
    return [$1, $2]
  end

  ####
  # access to the object variables
  def get_contents()
    return [@features, @feature_types, @list_feature_access]
  end

end


##############################
# ConfigFormatelement is an auxiliary class
# of ConfigData.
# It keeps track of feature patterns with variables in them
# that can be instantiated.

class ConfigFormatElement

  # new()
  #
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
    @pattern = Array.new
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
#	" against " + string + " "
#      if match.nil?
#	$stderr.puts "no"
#      else
#	$stderr.puts "yes"
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

