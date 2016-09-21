require 'rosy/feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # rightmost terminal of this constituent
    class LastWordFeature < FeatureExtractor
      LastWordFeature.announce_me

      def LastWordFeature.designator
        return "lastword"
      end
      def LastWordFeature.feature_names
        return ["lastword", "lastword_pos"]
      end
      def LastWordFeature.sql_type
        return "VARCHAR(30)"
      end
      def LastWordFeature.feature_type
        return "sem"
      end

      #####
      private

      def compute_features_instanceOK
        if @@node_rightmost_terminal
          return [FeatureExtractor.headlemma(@@node_rightmost_terminal), FeatureExtractor.headpos(@@node_rightmost_terminal)]
        else
          return [nil, nil]
        end
      end
    end
  end
end
