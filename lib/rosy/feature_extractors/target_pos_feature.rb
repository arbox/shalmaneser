require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # part of speech of target lemma
    class TargetPOSFeature < SingleFeatureExtractor
      TargetPOSFeature.announce_me

      def TargetPOSFeature.feature_name
        return "target_pos"
      end
      def TargetPOSFeature.sql_type
        return "VARCHAR(10)"
      end
      def TargetPOSFeature.feature_type
        return "ubiq"
      end
      def TargetPOSFeature.info
        # additional info: I am an index feature
        return super().concat(["index"])
      end

      #####
      private

      def compute_feature_instanceOK
        return @@target_pos
      end
    end
  end
end
