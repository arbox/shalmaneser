require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ##################
    # phrase type of parent of this node
    class FatherPhraseTypeFeature < SingleFeatureExtractor
      FatherPhraseTypeFeature.announce_me

      def FatherPhraseTypeFeature.feature_name
        return "father_pt"
      end
      def FatherPhraseTypeFeature.sql_type
        return "VARCHAR(15)"
      end
      def FatherPhraseTypeFeature.feature_type
        return "syn"
      end

      #####
      private

      def compute_feature_instanceOK
        if @@node.parent
          return @@interpreter_class.simplified_pt(@@node.parent)
        else
          return nil
        end
      end
    end
  end
end
