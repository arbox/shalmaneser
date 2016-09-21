require_relative 'abstract_gv_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # gov. verb path consisting of phrase type and directions
    class GVNodelabelPathFeature < AbstractGVPathFeature
      GVNodelabelPathFeature.announce_me

      def GVNodelabelPathFeature.feature_name
        return "pt_gvpath"
      end

      ################
      private

      def my_path_computation
        return @@gv_paths[@@node.id].print(true, false, true)
      end
    end
  end
end
