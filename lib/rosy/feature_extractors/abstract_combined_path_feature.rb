require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    #########
    # group of combined path features:
    # path to target combined with target part of speech and
    # info on whether the target is passive
    class AbstractCombinedPathFeature < SingleFeatureExtractor

      def AbstractCombinedPathFeature.sql_type
        return "VARCHAR(90)"
      end
      def AbstractCombinedPathFeature.feature_type
        return "syn"
      end

      ################
      private

      def compute_feature_instanceOK
        if @@paths[@@node.id].nil?
          path = ""
        else
          path = my_path_computation
        end
        return path + "--" + @@target_pos.to_s + "--" + @@target_voice.to_s
      end

      ###
      def my_path_computation
        raise "Overwrite me"
      end
    end
  end
end
