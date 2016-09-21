require_relative 'abstract_partial_path_feature'

module Shalmaneser
  module Rosy
    ####
    # partial path based on node labels
    class NodelabelPartialPathFeature < AbstractPartialPathFeature
      NodelabelPartialPathFeature.announce_me

      def NodelabelPartialPathFeature.feature_name
        return "pt_partial_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print_downpart(true, false, true)
      end
    end
  end
end
