require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # the governing verb of the target
    class GoverningVerbOfTargetFeature < SingleFeatureExtractor
      GoverningVerbOfTargetFeature.announce_me

      def GoverningVerbOfTargetFeature.feature_name
        return "gov_verb"
      end
      def GoverningVerbOfTargetFeature.sql_type
        return "VArCHAR(20)"
      end
      def GoverningVerbOfTargetFeature.feature_type
        return "sem"
      end

      #####
      private

      def compute_feature_instanceOK
        if @@governing_verb
          return FeatureExtractor.headlemma(@@governing_verb)
        else
          return nil
        end
      end
    end
  end
end
