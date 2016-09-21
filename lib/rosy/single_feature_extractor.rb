require_relative 'feature_extractor'

module Shalmaneser
  module Rosy
    ###############################
    # Rosy single feature extractor, duplicating stuff from
    # AbstractSingleFeatureExtractor
    class SingleFeatureExtractor < FeatureExtractor
      ###
      # returns a string: the designator for this feature extractor
      # (an extractor may compute several features, but
      #  in the experiment file it is chosen by a single designator)
      #
      # here: single feature, and the feature name is the designator
      def self.designator
        feature_name
      end

      ###
      def self.feature_names
        [feature_name]
      end

      ###
      # compute_feature_value: first check if instance is OK
      #
      # returns: list of features
      def compute_features
        unless @@instance_ok
          return nil
        end

        make_features_safe_for_sql([compute_feature_instanceOK])
      end

      ############
      private

      # @todo Rename this method.
      def compute_feature_instanceOK
        raise "Overwrite me"
      end
    end
  end
end
