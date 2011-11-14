# Katrin Erk November 05
# 
# Abstract classes for
# - Rosy features
# - Rosy interface for external knowledge sources.

require 'rosy/ExternalConfigData'

####
# Feature Extractor:
# computes one or more features for a node (a SynNode object) out of
#  a SalsaTigerSentence
class AbstractFeatureExtractor
  @@sent = nil  # SalsaTigerSentence: sentence of the current instance
  @@frame = nil # FrameNode: frame of the current instance
  @@node = nil  # SynNode: constituent that is the current instance
  @@interpreter_class = nil # SynInterpreter class
  @@instance_ok = true

  ###
  # returns a string: the designator for this feature extractor
  # (an extractor may compute several features, but
  #  in the experiment file it is chosen by a single designator)
  def AbstractFeatureExtractor.designator()
    raise "Overwrite me"
  end

  ###
  # returns an array of feature names, the names of the 
  # features that it can compute.
  # The number of features that the extractor computes must be fixed.
  def AbstractFeatureExtractor.feature_names()
    raise "Overwrite me."
  end

  ###
  # returns a string: the data type for the feature
  # to be passed on to the MySQL database,
  # e.g. VARCHAR(10), INT
  def AbstractFeatureExtractor.sql_type()
    raise "Overwrite me"
  end

  ###
  # returns a string: the feature type 
  # (the same for all features computed by this extractor)
  # possible values:
  # - gold: gold label
  # - admin: administrative feature, do not pass this on to the learner
  # - syn: feature computed from syntactic characteristics of the instance
  # - sem: feature involving semantic characteristics of the instance
  # - sentlevel: this feature is the same for all instances of a sentence
  def AbstractFeatureExtractor.feature_type()
    raise "Overwrite me"
  end

  ###
  # returns a string: "phase 1" or "phase 2",
  # depending on whether the feature is computed
  # directly from the SalsaTigerSentence and the SynNode objects
  # or whether it is computed from the phase 1 features
  def AbstractFeatureExtractor.phase()
    raise "Overwrite me."
  end

  ###
  # returns an array of strings, providing information about
  # the feature extractor
  def AbstractFeatureExtractor.info()
    return []
  end

  ###
  # set sentence, set node, set other settings: 
  # this is done prior to
  # feature computation using compute_feature()
  # such that computations that stay the same for
  # several features can be done in advance
  #
  # This is just relevant for Phase 1
  #
  # returns: false/nil if there was a problem
  def AbstractFeatureExtractor.set_sentence(sent,  # SalsaTigerSentence object
                                            frame) # FrameNode object
    @@sent = sent
    @@frame = frame
    
    return true
  end

  def AbstractFeatureExtractor.set_node(node) # SynNode of the sentence set in set_sentence
    @@node = node

    return true
  end

  ###
  # set sentence, set node, set general settings: this is done prior to
  # feature computation using compute_feature_value()
  # such that computations that stay the same for
  # several features can be done in advance
  def AbstractFeatureExtractor.set(var_hash = {})
    # no settings at this point
    
    return true
  end
  # test during initialisation whether a feature is computable
  # gives the feature the possibility to specify additional constraints
  # e.g. for phase2 features : specify which extractors from phase 1 are presupposed
  def AbstractFeatureExtractor.is_computable(extractor_list) # bool
    return true
  end

  ###
  def initialize(exp, # ConfigData object: experiment file information
                 interpreter_class)
    @exp = exp
    @@interpreter_class = interpreter_class
  end

  ###
  # compute: compute features
  #
  # returns an array of features (strings), length the same as the
  # length of feature_names()
  def compute_features()
    raise "overwrite me"
  end

  ###
  # phase 2 extractors: 
  # compute features for a complete view
  #
  # returns: an array of columns,
  # where a column is an array of feature values.
  # returns one column per entry in feature_names()
  def compute_features_on_view(view) # DBView object
    raise "overwrite me"
  end

  # At this place, we had abstract methods for "training" phase 2 features 
  # Since this involves introducing a "state" that is nontrivial to preserve
  # for a standalone version of the classifiers, without keeping the training data,
  # we decided to remove this functionality (30.11.05).
  # Features which rely on learning patterns from the training data and applying them
  # to the test data will from now on be implemented as externals.

  ######
  protected

  def AbstractFeatureExtractor.announce_me()
    if Module.constants.include? "RosyFeatureInfo"
      # yup, we have a class to which we can announce ourselves
      RosyFeatureInfo.add_feature(eval(self.name()))
    else
      # no interface collector class
#      $stderr.puts "Feature #{self.name()} not announced: no RosyFeatureInfo."
    end
  end
end

################################################################
# Wrapper class for extractors that compute a single feature
class AbstractSingleFeatureExtractor < AbstractFeatureExtractor
  
  ###
  # returns a string: the designator for this feature extractor
  # (an extractor may compute several features, but
  #  in the experiment file it is chosen by a single designator)
  #
  # here: single feature, and the feature name is the designator
  def AbstractFeatureExtractor.designator()
    return eval(self.name()).feature_name()
  end

  ###
  def AbstractSingleFeatureExtractor.feature_names()
    return [eval(self.name()).feature_name()]
  end

  ###
  def compute_features()
    return [compute_feature()]
  end

  def compute_features_on_view(view) # DBView object
    return [compute_feature_on_view(view)]
  end


  ######
  # Single-feature methods

  ###
  def AbstractSingleFeatureExtractor.feature_name()
    raise "Overwrite me."
  end
  
  ###
  def compute_feature()
    raise "Overwrite me"
  end

  ###
  def compute_feature_on_view(view) # DBView object
    raise "Overwrite me"
  end
end

######################################################

class ExternalFeatureExtractor < AbstractFeatureExtractor

  @@warning_uttered = false

  ####
  # initialization:
  #
  # read experiment file for external interfaces
  def initialize(exp,    # RosyConfigData object
                 interpreter_class)

    @exp_rosy = exp
    @@interpreter_class = interpreter_class

    unless @exp_rosy.get("external_descr_file")
      unless @@warning_uttered
	$stderr.puts "Warning: Cannot compute external feature"
	$stderr.puts "since 'external_descr_file' has not been set"
	$stderr.puts "in the Rosy experiment file."
	@@warning_uttered = true
      end

      @exp_external = nil
      return
    end

    @exp_external = ExternalConfigData.new(@exp_rosy.get("external_descr_file"))
  end
end
