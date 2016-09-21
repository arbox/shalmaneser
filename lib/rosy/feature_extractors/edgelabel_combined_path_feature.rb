require_relative 'abstract_combined_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # combined path based on edgelabels
    class EdgelabelCombinedPathFeature < AbstractCombinedPathFeature
      EdgelabelCombinedPathFeature.announce_me

      def EdgelabelCombinedPathFeature.feature_name
        return "gf_combined_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print(false, true, false)
      end
    end
  end
end
