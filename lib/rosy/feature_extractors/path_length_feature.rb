require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ####################
    # path length
    class PathLengthFeature < SingleFeatureExtractor
      PathLengthFeature.announce_me

      def PathLengthFeature.feature_name
        return "path_length"
      end
      def PathLengthFeature.sql_type
        return "TINYINT"
      end
      def PathLengthFeature.feature_type
        return "syn"
      end

      ################
      private

      def compute_feature_instanceOK
        if @@paths[@@node.id].nil?
          return nil
        else
          return @@paths[@@node.id].length
        end
      end
    end
  end
end
