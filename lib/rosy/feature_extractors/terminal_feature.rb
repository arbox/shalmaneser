require 'rosy/single_feature_extractor'
module Shalmaneser
  module Rosy
    ################
    # admin feature: is this node a terminal?
    class TerminalFeature < SingleFeatureExtractor
      TerminalFeature.announce_me

      def TerminalFeature.feature_name
        return "term"
      end
      def TerminalFeature.sql_type
        return "TINYINT"
      end
      def TerminalFeature.feature_type
        return "admin"
      end

      #####
      private

      def compute_feature_instanceOK
        if @@node.is_terminal?
          return 1
        else
          return 0
        end
      end
    end
  end
end
