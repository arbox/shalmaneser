require_relative 'abstract_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # path consisting of dependencies and directions
    class EdgelabelPathFeature < AbstractPathFeature
      EdgelabelPathFeature.announce_me

      def EdgelabelPathFeature.feature_name
        return "gf_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print(true, true, false)
      end
    end
  end
end
