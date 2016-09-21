require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # head lemma of this constituent
    class HeadFeature < SingleFeatureExtractor
      HeadFeature.announce_me

      def HeadFeature.feature_name
        return "const_head"
      end
      def HeadFeature.sql_type
        return "VARCHAR(20)"
      end
      def HeadFeature.feature_type
        return "sem"
      end

      #####
      private

      def compute_feature_instanceOK
        return FeatureExtractor.headlemma(@@node)
      end
    end
  end
end
