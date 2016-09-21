require_relative 'abstract_combined_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # combined path based on nodelabels and edgelabels
    class CombinedPathFeature < AbstractCombinedPathFeature
      CombinedPathFeature.announce_me

      def CombinedPathFeature.sql_type
        return "VARCHAR(130)"
      end
      def CombinedPathFeature.feature_name
        return "combined_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print(false, true, true)
      end
    end
  end
end
