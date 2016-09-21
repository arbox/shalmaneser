require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ##################
    # group of features for computing
    # partial path to target: only up to
    # the lowest common ancestor of current node and target
    class AbstractPartialPathFeature < SingleFeatureExtractor

      def AbstractPartialPathFeature.sql_type
        return "VARCHAR(70)"
      end
      def AbstractPartialPathFeature.feature_type
        return "syn"
      end

      ################
      private

      def compute_feature_instanceOK
        if @@paths[@@node.id].nil?
          path = nil
        else
          path = my_path_computation
        end
        if path.nil? or path.empty?
          return nil
        else
          return path
        end
      end
    end
  end
end
