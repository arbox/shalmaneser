require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # target lemma
    class TargetLemmaFeature < SingleFeatureExtractor
      TargetLemmaFeature.announce_me

      def TargetLemmaFeature.feature_name
        return "target"
      end
      def TargetLemmaFeature.sql_type
        return "VARCHAR(20)"
      end
      def TargetLemmaFeature.feature_type
        return "ubiq"
      end
      def TargetLemmaFeature.info
        # additional info: I am an index feature
        return super().concat(["index"])
      end

      #####
      private

      def compute_feature_instanceOK
        return @@interpreter_class.lemma_backoff(@@target)
      end
    end
  end
end
