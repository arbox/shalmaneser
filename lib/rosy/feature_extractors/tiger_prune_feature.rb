require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ####################
    # HIER changeme
    class TigerPruneFeature < SingleFeatureExtractor
      TigerPruneFeature.announce_me

      def self.feature_name
        "tiger_prune"
      end

      def self.sql_type
        "TINYINT"
      end

      def self.feature_type
        "syn"
      end

      def self.info
        # additional info: I am an index feature
        super().concat(["index"])
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
