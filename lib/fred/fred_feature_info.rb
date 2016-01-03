module Shalmaneser
  module Fred
    class FredFeatureInfo
      ###
      # class variable:
      # list of all known extractors
      # add to it using add_feature()
      @@extractors = []

      # boolean. set to true after warning messages have been given once
      @@warned = false

      ###
      # add interface/interpreter
      def FredFeatureInfo.add_feature(class_name) # Class object
        @@extractors << class_name
      end

      ###
      def initialize(exp)

        ##
        # make list of extractors that are
        # required by the user
        @features = []
        @exp = exp

        # user-chosen extractors:
        # returns array of pairs [feature group designator(string), options(array:string)]
        exp.get_lf("feature").each { |extractor_name, *options|

          extractor = @@extractors.detect { |e| e.feature_name == extractor_name }
          unless extractor
            # no extractor found matching the given designator
            unless @@warned
              $stderr.puts "Warning: Could not find a feature extractor for #{extractor_name}: skipping."
            end
            next
          end

          # no need to use the options here,
          # the feature extractors can get their options themselves.
          @features << extractor
        }

        # do not print warnings again if another RosyFeatureInfo object is made
        @@warned = true
      end

      ###
      # get_extractor_objects
      #
      # returns a list of feature extractor objects
      def get_extractor_objects

        return @features.map{ |feature_class|
          feature_class.new(@exp)
        }
      end
    end
  end
end
