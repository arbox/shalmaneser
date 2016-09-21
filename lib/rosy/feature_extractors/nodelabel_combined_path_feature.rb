require_relative 'abstract_combined_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # combined path based on nodelabels
    class NodelabelCombinedPathFeature < AbstractCombinedPathFeature
      NodelabelCombinedPathFeature.announce_me

      def NodelabelCombinedPathFeature.feature_name
        return "pt_combined_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print(false, false, true)
      end
    end
  end
end
