require_relative 'abstract_gv_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # gov. verb path consisting of dependencies and directions
    class GVEdgelabelPathFeature < AbstractGVPathFeature
      GVEdgelabelPathFeature.announce_me

      def GVEdgelabelPathFeature.feature_name
        return "gf_gvpath"
      end

      ################
      private

      def my_path_computation
        return @@gv_paths[@@node.id].print(true, true, false)
      end
    end
  end
end
