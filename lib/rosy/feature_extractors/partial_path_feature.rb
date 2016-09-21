module Shalmaneser
  module Rosy
    ####
    # partial path based on node and edge labels
    class PartialPathFeature < AbstractPartialPathFeature
      PartialPathFeature.announce_me

      def PartialPathFeature.sql_type
        return "VARCHAR(110)"
      end

      def PartialPathFeature.feature_name
        return "partial_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print_downpart(true, true, true)
      end
    end
  end
end
