require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ##################
    # relative position to target: left, right, including target
    class RelativePositionFeature < SingleFeatureExtractor
      RelativePositionFeature.announce_me

      def RelativePositionFeature.feature_name
        return "relpos"
      end
      def RelativePositionFeature.sql_type
        return "CHAR(5)"
      end
      def RelativePositionFeature.feature_type
        return "syn"
      end

      ################
      private

      def compute_feature_instanceOK
        return @@relpos
      end
    end
  end
end
