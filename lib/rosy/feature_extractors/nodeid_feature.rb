require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # admin feature: my node ID and my father's, separated by a space
    # the highest node (topnode) has ID 0, and no father ID.
    class NodeIDFeature < SingleFeatureExtractor
      NodeIDFeature.announce_me

      def NodeIDFeature.feature_name
        return "nodeID"
      end

      def NodeIDFeature.sql_type
        return "VARCHAR(100)"
      end

      def NodeIDFeature.feature_type
        return "admin"
      end

      #####
      private

      def compute_feature_instanceOK
        if @@node.parent
          return @@node.id.to_s + " " + @@node.parent.id.to_s
        else
          return @@node.id.to_s
        end
      end
    end
  end
end
