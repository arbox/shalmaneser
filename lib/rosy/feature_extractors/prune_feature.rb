require 'rosy/single_feature_extractor'
###
# Pruning, derived from the Xue/Palmer algorithm
#
# implemented in the Interpreter Class of each individual parser
module Shalmaneser
  module Rosy
    class PruneFeature < SingleFeatureExtractor
      PruneFeature.announce_me

      def self.feature_name
        "prune"
      end

      def self.sql_type
        "TINYINT"
      end

      def self.feature_type
        'syn'
      end

      def self.info
        # additional info: I am an index feature
        super().concat(["index"])
      end

      ################
      private

      def compute_feature_instanceOK
        retv = @@interpreter_class.prune?(@@node, @@paths, @@terminals_ordered)
        if [0, 1].include? retv
          return retv
        else
          return 0
        end
      end
    end
  end
end
