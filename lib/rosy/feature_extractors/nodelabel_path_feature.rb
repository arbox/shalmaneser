require_relative 'abstract_path_feature'

module Shalmaneser
  module Rosy
    ####################
    # path consisting of phrase type and directions
    class NodelabelPathFeature < AbstractPathFeature
      NodelabelPathFeature.announce_me

      def NodelabelPathFeature.feature_name
        return "pt_path"
      end

      ################
      private

      def my_path_computation
        if @@paths[@@node.id].nil?
          return nil
        end

        return @@paths[@@node.id].print(true, false, true)
      end
    end
  end
end
