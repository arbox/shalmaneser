require 'rosy/feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # leftmost terminal of this constituent
    class FirstWordFeature < FeatureExtractor
      FirstWordFeature.announce_me

      def FirstWordFeature.designator
        return "firstword"
      end
      def FirstWordFeature.feature_names
        return ["firstword", "firstword_pos"]
      end
      def FirstWordFeature.sql_type
        return "VARCHAR(20)"
      end
      def FirstWordFeature.feature_type
        return "sem"
      end

      #####
      private

      def compute_features_instanceOK
        if @@node_leftmost_terminal
          return [FeatureExtractor.headlemma(@@node_leftmost_terminal), FeatureExtractor.headpos(@@node_leftmost_terminal)]
        else
          return [nil, nil]
        end
      end
    end
  end
end
