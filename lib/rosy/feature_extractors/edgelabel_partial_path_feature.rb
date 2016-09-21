module Shalmaneser
  module Rosy
    ####
    # partial path based on edge labels
    class EdgelabelPartialPathFeature < AbstractPartialPathFeature
      EdgelabelPartialPathFeature.announce_me

      def EdgelabelPartialPathFeature.feature_name
        return "gf_partial_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print_downpart(true, true, false)
      end
    end
  end
end
