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
#   pattern:  This is a feature that  may include variables in
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

require_relative 'config_format_element'
require_relative 'configuration_error'
require 'ruby_class_extensions'
require 'logging'

#####################################################
####################################################
# ConfigData is the main class in this package.
# It manages config files.
#
# To use it, inherit from it and just make a new new() method
# that only takes as input the name of the config file
# and that declares all the feature types and variable names
# needed for the given application.
#
# @abstract Subclass and override {#initialize} to implement
#   a custom ConfigData class.
module Shalmaneser
  module Configuration
    # @abstract Subclass and override {#validate} to implement custom
    #   ConfigurationData classes.
    # This class is responsible for the validation of the config.
    class ConfigData
      # Input parameters: the name of the config file, a hash declaring all
      # features by mapping feature names to their types,
      # and an array of all variables that may occur in pattern type features
      #
      # @param filename [String] a name of the configuration file
      # @param feature_types [Hash] feature type definitions
      # @param variables [Array] list of variables used in pattern features
      # @raise [ConfigurationError]
      def initialize(filename, feature_types, variables)
        @variables = variables
        @filename = filename

        # feature_types: hash: feature_name => feature_type
        @feature_types = feature_types

        # features: hash: feature_name => value
        @features = {}

        # hash: feature_name => Proc
        # access method for list features
        @list_feature_access = {}

        # pre-initialize list features to an empty array
        @feature_types.each_pair do |feature_name, feature_type|
          if feature_type == "list"
            @features[feature_name] = []
          end
        end

        ##
        # open config file
        # @todo Introduce custom exceptions to handle external errors.
        begin
          File.open(@filename, 'r') do |file|
            while (line = file.gets)
              line = line.strip
              # Empty lines and comments.
              next if line =~ /^#/ || line.empty?
              feature_name, rhs = extract_def(line)
              set_entry(feature_name, rhs)
            end
          end
        rescue => e
          msg = "Error: I could not open the experiment file: #{@filename}"
          raise ConfigurationError.new(msg, e)
        end
      end

      #####
      # set_entry
      #
      # set an entry in the experiment file, either an existing or a new one
      # but it must conform to the feature types declared in the new() method
      def set_entry(feature_name, rhs)
        unless @feature_types[feature_name]
          msg = "Error in experiment file:\n"\
                "Unknown parameter #{feature_name} in #{@filename}.\n"\
                "Expected features for this type of experiment file:\n"\
                "#{@feature_types.keys.join(', ')}"
          raise ConfigurationError, msg
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
            LOGGER.warn "WARNING: I got an empty value for list feature #{feature_name}. "\
                        "I'll ignore it."
          else
            unless @features[feature_name].include?(rhs.split)
              @features[feature_name] << rhs.split
            end
          end
        when "bool"
          # boolean value
          unless %w(true false).include?(rhs)
            msg = "Error in experiment file:\n"\
                  "Value for #{feature_name} must be either 'true' or 'false'.\n"\
                  "I got: #{rhs}.\n"
            raise ConfigurationError, msg
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
          raise ConfigurationError,
                "Unknown feature type for feature #{feature_name}: #{@feature_types[feature_name]}"
        end
      end

      ####
      # remove list entry in this config data structure:
      # the lhs argument is the list feature name
      # the rhs argument can be a string or a regexp.
      # - string: each entry exactly matching the string is removed
      # - regexp: each entry matching the regexp is removed
      # @param [String] lhs feature name
      # @param [String, Regexp] rhs righthand side
      # @raise [ConfigurationError]
      def unset_list_entry(lhs, rhs)
        unless @feature_types[lhs] == "list"
          msg = "Error in experiment file.\n"\
                "Feature #{lhs} unknown or not of type list."
          raise ConfigurationError, msg
        end

        case rhs
        when String
          rhs_match = Regexp.new("^" + Regexp.escape(rhs) + "$")
        when Regexp
          rhs_match = rhs
        else
          raise ConfigurationError, "Shouldn't be here: #{rhs.class}."
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
      # @param [ConfigData] config_obj A ConfigData object.
      def adjoin(config_obj)
        # sanity checks:
        # the other object must be a ConfigData object
        unless config_obj.is_a?(ConfigData)
          raise ConfigurationError, "I can only adjoin another ConfigData object"
        end

        # if feature name sets are not disjoint,
        # ignore the feature names that I already have
        other_features, other_feature_types, other_list_feature_access = config_obj.get_contents
        unless (@feature_types.keys & other_feature_types.keys).empty?
          other_features = other_features.clone
          other_feature_types = other_feature_types.clone
          other_list_feature_access = other_list_feature_access.clone

          (@feature_types.keys & other_feature_types.keys).each do |overlap_feature|
            other_features.delete(overlap_feature)
            other_feature_types.delete(overlap_feature)
            other_list_feature_access.delete(overlap_feature)
          end
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
      # @param name [String] name of the feature to access
      def get(name)
        if @feature_types[name].nil?
          raise ConfigurationError, "Unknown feature: #{name}."
        end

        # may return nil if something has not been set
        @features[name]
      end

      ####
      # get_type
      #
      # returns the type of a given feature,
      # or nil if it is undefined
      def get_type(feature_name)
        @feature_types[feature_name]
      end

      #####
      # is_defined
      #
      # returns: true if a feature by this name has been set in the config file,
      #   false else
      # @param feature [String] name of the feature
      # @note This method is nowhere used.
      def is_defined(feature)
        @features[feature] ? true : false
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
      # @param [String] key Feature name.
      # @param [Hash<String, String>] var_hash  variable name(string) => value(string)
      def instantiate(key, var_hash = {})
        unless @feature_types[key] == "pattern"
          raise ConfigurationError, "Nothing known about pattern: #{key}."
        end

        unless @features[key]
          raise ConfigurationError, "Please define pattern in configuration file: #{key}."
        end

        # piece together the file name
        # expand in case it is a filename/directory
        @features[key].instantiate(var_hash)
      end

      #####
      # get_filename:
      #
      # synonym for instantiate()
      # @note What for?
      def get_filename(key, var_hash = {})
        instantiate(key, var_hash)
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
      # @param [String] dir Directory name.
      # @param [String] key Name of the pattern type feature.
      # @param [Hash<String, String>] var_hash variable name(string) => value(string)
      def get_all_filenames(dir, key, var_hash = {})

        unless @feature_types[key] == "pattern"
          raise ConfigurationError, "Nothing known about file format #{key}."
        end

        # array of pairs [filename(string), matches(hash)]
        filenames = []

        # iterate through all files of this directory
        Dir.foreach(dir) do |filename|
          # Does the filename match the pattern of the feature "key"?
          if (matches = @features[key].match(filename, var_hash))
            # do the variable values for this filename conform
            # to the variable values given in var_hash?
            LOGGER.debug "ConfigData got #{filename}."

            mismatches = var_hash.keys.select { |k| matches[k] != var_hash[k] }
            if mismatches.empty?
              filenames << [filename, matches]
            else
              msg = mismatches.each do |k|
                "Mismatch for #{k}: #{matches[k]} vs. #{var_hash[k]}."
              end.join("\n")
              LOGGER.debug(msg)
            end
          end
        end

        filenames
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
          fail ConfigurationError,
                "Cannot set list feature access to non-list feature #{feature_name}"
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
      # @param [String] feature_name The name of a list feature.
      # @param [Array] parameters for access function, collapsed into an array here
      def get_lf(feature_name, *parameters)

        unless @list_feature_access[feature_name]
          raise ConfigurationError, "I have no list feature access method for #{feature_name}."
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
      # @param line [String] line from config file
      def extract_def(line)
        md = line.match(/^\s*(\w+)\s*=\s*([^\s].*)$/)
        unless md
          msg = "Error in experiment file:\n"\
                "I couldn't analyze the following line:\n"\
                "#{line}"
          raise ConfigurationError, msg
        end

        [md[1], md[2]]
      end

      ####
      # access to the object variables
      def get_contents
        [@features, @feature_types, @list_feature_access]
      end

      # Validate the semantics of parameters coming from the experiment files.
      # @abstract Override this in subclasses.
      def validate
        raise NotImplementedError
      end
    end
  end
end
