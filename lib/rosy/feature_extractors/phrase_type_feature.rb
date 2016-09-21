require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # phrase type of the instance node
    class PhraseTypeFeature < SingleFeatureExtractor
      PhraseTypeFeature.announce_me

      def PhraseTypeFeature.feature_name
        return "pt"
      end

      def PhraseTypeFeature.sql_type
        return "VARCHAR(15)"
      end

      def PhraseTypeFeature.feature_type
        return "syn"
      end

      ################
      private

      def compute_feature_instanceOK
        return @@interpreter_class.simplified_pt(@@node)
      end
    end
  end
end
