require_relative 'abstract_feature_extractor'

module Shalmaneser
module Rosy
################################################################
# Wrapper class for extractors that compute a single feature
class AbstractSingleFeatureExtractor < AbstractFeatureExtractor

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
  def compute_features
    [compute_feature]
  end

  def compute_features_on_view(view) # DBView object
    [compute_feature_on_view(view)]
  end

  ######
  # Single-feature methods

  ###
  def self.feature_name
    raise "Overwrite me."
  end

  ###
  def compute_feature
    raise "Overwrite me"
  end

  ###
  def compute_feature_on_view(view) # DBView object
    raise "Overwrite me"
  end
end
end
end
