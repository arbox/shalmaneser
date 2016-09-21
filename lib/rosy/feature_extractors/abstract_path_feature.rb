require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ####################
    # path features
    class AbstractPathFeature < SingleFeatureExtractor
      def AbstractPathFeature.sql_type
        return "VARCHAR(80)"
      end
      def AbstractPathFeature.feature_type
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

      def my_path_computation
        raise "overwrite me"
      end
    end
  end
end
