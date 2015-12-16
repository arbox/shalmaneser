require "ruby_class_extensions"
#################################################
# class for keeping one line,
# parsed.
# The line is kept as follows:
# - normal features: in a hash @f mapping feature names to values
# - features of the repeated group: in an array @r of
#   TabFormatNamedArgs objects, one per group
#
# each feature of the line is available by name
# via the method "get".
# Additional features (from other input files) can be
# added to the TabFormatNamedArgs object via the method
# add_feature
#
# methods:
#
# new: initialize.
#    values: array of strings
#    features:  how to access the strings by name
#              'features' is an array of strings
#              later the i-th feature will be used to access
#              the i-th value,
#              except for repeated groups
#
# get: returns one feature by its name
#    name: a string
#
# add_feature: add another feature to this object,
#              which can be accessed via "get"
#    name: name for the new feature, should be distinct
#          from the ones already used in new()
#    feature: a string, the value of the feature
##

class TabFormatNamedArgs
  ############
  def initialize(values, features, group = nil)
    @f = Hash.new
    @r = Array.new
    @group = group

    # record the feature names, give special attention to a group
    # if we have one
    @group_feature_names = nil
    @feature_names = features.map { |feature|
      if feature.instance_of? Array
        # found a group
        @group_feature_names = feature
        "GROUP"
      else
        feature
      end
    }

    if @feature_names.count("GROUP") > 1
      $stderr.puts "More than one group in feature set:" + features.join(" ")
      raise "Cannot handle this."
    end

    # group_index: position of group in overall feature list
    group_index = @feature_names.index("GROUP")
    unless group_index
      group_index = @feature_names.length()
    end
    num_features_after_group = [0,
      (@feature_names.length() - 1) - group_index].max()
    index_after_groups = values.length() - num_features_after_group


    # features before group: put feature/value pairs in @f hash
    0.upto(group_index - 1) { |i|
      @f[features[i]] = values[i]
    }
    # group: store each group in @r hash
    if @group_feature_names
      # for (group_start = group_index; group_start < index_after_groups;
      #      group_start += @group_feature_names.length())
      group_no = 0
      group_index.step(index_after_groups - 1,
                       @group_feature_names.length()) { |group_start|
        @r << TabFormatNamedArgs.new(values.slice(group_start,
                                                  @group_feature_names.length()),
                                     @group_feature_names,
                                     group_no)
        group_no += 1
      }
    end

    # features after group: put feature/value pairs in @f hash
    feature_index = group_index + 1
    index_after_groups.upto(values.length() - 1) { |i|
      @f[features[feature_index]] = values[i]
      feature_index += 1
    }
  end

  ############
  # return feature/value pairs as a tab format line,
  # order of features as given in the 'features' list
  # Features not set in the hash: their entry will be "-"
  #
  # If the feature list includes a group,
  # assume zero entries for that group
  def self.format_str(hash,     # hash: feature -> value
                      features) # feature list, as for new()
    if features.nil?
      return ""
    end

    # sanity check: does the hash contain keys that are not in the feature list?
    hash.keys().reject { |f| features.include? f }.each { |bad_feature|
      $stderr.puts "Error: unknown feature #{bad_feature} in format_str: ignoring."
    }

    return features.select { |f|
      # remove the group feature, if it's there
      not(f.instance_of? Array)
    }.map { |feature|
      if hash[feature]
        hash[feature]
      else
        "-"
      end
    }.join("\t")
  end


  #############
  def add_feature(name, feature)
    if @f.has_key? name
      raise "Trying to add a feature twice: "+name
    end

    @f[name] = feature
  end

  #############
  # get feature value, identified by feature name
  # return: feature value as string
  def get(name)
    if (retv = get_nongroup(name))
      return retv
    else
      return get_from_group(name, @group)
    end
  end

  #############
  def set(name, feature)
    @f[name] = feature
  end

  #############
  def num_groups()
    return @r.length()
  end

  #############
  # return line as string, entries connected by tab,
  # in the order that the entries were in originally
  def to_s()
    return @feature_names.map { |feature|
      case feature
      when "GROUP"
        @r.map { |group_obj| group_obj.to_s }.join("\t")
      else
        @f[feature]
      end
    }.join("\t")
  end

  protected

  # get feature, non-group
  # return: feature value (string)
  def get_nongroup(feature)
    return @f[feature]
  end

  # get feature from one of the groups
  # return: feature value (string)
  def get_from_group(name, group_no)
    if not(group_no) or group_no >= @r.length()
      # no group with that number
      return nil
    else
      return @r[group_no].get_nongroup(name)
    end
  end
end
