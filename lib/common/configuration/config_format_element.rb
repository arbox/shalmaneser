##############################
# ConfigFormatelement is an auxiliary class
# of ConfigData.
# It keeps track of feature patterns with variables in them
# that can be instantiated.
# @author Andrei Beliankou
#

require_relative 'configuration_error'

module Shalm
  module Configuration
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
              raise ConfigurationError, "Duplicate < in #{string}."
            when ">"
              unless @variables.include? item
                raise ConfigurationError, "Unknown variable #{item}."
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
              raise ConfigurationError, "Unexpected > in #{string}."
            else
              item << char
              state = "out"
            end

          else
            raise ConfigurationError, "Shouldn't be here!"
          end
        }

        # read through the whole of "string"
        # end state has to be "out"
        unless state == "out"
          raise ConfigurationError, "Unclosed < in #{string}."
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
        @pattern.map do |item, string_or_var|
          case string_or_var
          when "string"
            item
          when "variable"
            if var_hash[item].nil?
              raise ConfigurationError, "Missing variable instantiation: #{item}."
            end
            var_hash[item]
          else
            raise ConfigurationError, "Shouldn't be here!"
          end
        end.join
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
        retv = {}
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
            raise ConfigurationError, "Match, but not enough matched elements? Strange."
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

        retv
      end

      # used_variables
      #
      # returns: an array of variable names used in @pattern
      def used_variables
        @pattern.select do |_item, string_or_var|
          string_or_var == "variable"
        end.map { |item, _string_or_var| item }
      end

      ####################
      private

      # make_regexp:
      # make regular expression from a pattern
      # together with some variable fillers
      #
      # @return [Regexp] object
      # @param [Array] pattern An array of pairs [string, "string"] or [string, "variable"]
      # @param [Hash] fillers A Hash variable name(string) => value(string)
      def make_regexp(pattern, fillers = nil)
        pattern = pattern.map do |item, string_or_var|
          case string_or_var
          when "variable"
            fillers && fillers[item] ? Regexp.escape(fillers[item]) : '(.+)'
          when "string"
            Regexp.escape(item)
          else
            # @todo Find the source of this error.
            raise ConfiguratinError, "Shouldn't be here"
          end
        end.join

        Regexp.new("^#{pattern}$")
      end
    end
  end
end
