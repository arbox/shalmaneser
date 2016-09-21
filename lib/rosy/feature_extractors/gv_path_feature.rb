require_relative 'abstract_gv_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # path from governing verb consisting of nodelabels, dependencies and directions
    class GVPathFeature < AbstractGVPathFeature
      GVPathFeature.announce_me

      def GVPathFeature.sql_type
        return "VARCHAR(120)"
      end
      def GVPathFeature.feature_name
        return "gvpath"
      end

      ################
      private

      def my_path_computation
        return @@gv_paths[@@node.id].print(true, true, true)
      end
    end
  end
end
