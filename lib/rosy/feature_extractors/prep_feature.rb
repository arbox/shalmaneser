require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################c
    # preposition for this constituent
    class PrepFeature < SingleFeatureExtractor
      PrepFeature.announce_me

      def PrepFeature.feature_name
        return "prep"
      end
      def PrepFeature.sql_type
        return "VARCHAR(20)"
      end
      def PrepFeature.feature_type
        return "syn"
      end

      #####
      private

      def compute_feature_instanceOK
        return @@interpreter_class.preposition(@@node)
      end
    end
  end
end
