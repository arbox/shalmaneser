require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
       ################
    # part of speech of target lemma
    class TargetFineGrainedPOSFeature < SingleFeatureExtractor
      TargetFineGrainedPOSFeature.announce_me

      def TargetFineGrainedPOSFeature.feature_name
        return "finegrained_target_pos"
      end
      def TargetFineGrainedPOSFeature.sql_type
        return "VARCHAR(20)"
      end
      def TargetFineGrainedPOSFeature.feature_type
        return "ubiq"
      end


      #####
      private

      def compute_feature_instanceOK
        return @@interpreter_class.pt(@@target)
      end
    end
  end
end
