require 'fred/fred_feature_info'

module Shalmaneser
  module Fred
    ##################################3
    class FredFeatureExtractor
      ###
      # feature name:
      # name by which you choose this feature
      # in the experiment file
      def FredFeatureExtractor.feature_name
        raise "Overwrite me."
      end

      ###
      # initialize with Fred experiment file object
      def initialize(exp)
        @exp = exp
      end

      ###
      # compute features from meta-features
      #
      # argument: hash
      # metafeature_label -> metafeatures
      #  string -> array:string
      #
      # yields each feature as a string
      def each_feature(feature_hash)
        raise "overwrite me"
      end

      ######
      protected

      def FredFeatureExtractor.announce_me
        # This check is obsolete since we require FeatureInfo.
        # AB: In 1.9 constants are symbols.
        if Module.constants.include?("FredFeatureInfo") or Module.constants.include?(:FredFeatureInfo)
          # yup, we have a class to which we can announce ourselves
          FredFeatureInfo.add_feature(self)
        else
          # no interface collector class
          #      $stderr.puts "Feature #{self.name()} not announced: no RosyFeatureInfo."
        end
      end

    end
  end
end
