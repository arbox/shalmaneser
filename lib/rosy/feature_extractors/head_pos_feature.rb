require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # part of speech of the head of this constituent
    class HeadPosFeature < SingleFeatureExtractor
      HeadPosFeature.announce_me

      def self.feature_name
        "const_head_pos"
      end

      def self.sql_type
        "VARCHAR(10)"
      end

      def self.feature_type
        "syn"
      end

      #####
      private

      def compute_feature_instanceOK
        FeatureExtractor.headpos(@@node)
      end
    end
  end
end
