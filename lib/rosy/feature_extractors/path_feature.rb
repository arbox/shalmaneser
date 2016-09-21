require_relative 'abstract_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # path consisting of nodelabels, dependencies and directions
    class PathFeature < AbstractPathFeature
      PathFeature.announce_me

      def PathFeature.sql_type
        return "VARCHAR(120)"
      end
      def PathFeature.feature_name
        return "path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print(true, true, true)
      end
    end
  end
end
