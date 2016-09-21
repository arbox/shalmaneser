require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ####################
    # HIER changeme
    class TigerPruneFeature < RosySingleFeatureExtractor
      TigerPruneFeature.announce_me

      def TigerPruneFeature.feature_name
        return "tiger_prune"
      end
      def TigerPruneFeature.sql_type
        return "TINYINT"
      end
      def TigerPruneFeature.feature_type
        return "syn"
      end
      def TigerPruneFeature.info
        # additional info: I am an index feature
        return super().concat(["index"])
      end

      ################
      private

      def compute_feature_instanceOK
        if @@changeme_tiger_include.include? @@node
          return 1
        else
          return 0
        end
      end
    end
  end
end
