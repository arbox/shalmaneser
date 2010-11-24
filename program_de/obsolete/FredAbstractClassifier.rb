# FredAbstractClassifier
# Katrin Erk April 05
#
# frame disambiguation system:
# abstract superclass for classifiers

require "FredConfigData"

class FredAbstractClassifier
  ###
  # new
  #
  # gets the configuration as a FredConfigData object
  # and the directory to write the classifiers to
  def initialize(exp, # FredConfigData object: configuration info
		 dir) # string: directory to write classifiers to
    @exp = exp
    @directory = dir
  end

  ###
  # classifier_name
  #
  # returns a string, the name prefix for classifier file names
  # and the name for the directory in which classifiers will be stored
  #
  # WARNING: classifier files should begin with the classifier name
  # such that remove_old_classifiers() can get them.
  def FredAbstractClassifier.classifier_name()
    raise "Please overwrite this when inheriting"
  end

  ###
  # remove_old_classifiers()
  #
  # remove old classifier files in @directory
  def remove_old_classifiers()
    Dir.foreach(@directory) { |filename|
      classifier_name = self.class.classifier_name()
      # does this filename start with my classifier name prefix?
      if filename =~ /^#{classifier_name}/
	# yes: delete it
	filename = @directory + filename
	if File.exists? filename
	  File.delete filename
	end
      end
    }
  end

  ###
  # start_writing_classifier
  #
  # prepare file(s) for writing a classifier
  def start_writing_classifier(lemma, # string: make classifier specific to this lemma
			       sense) # string: make classifier specific to this sense
                                      # (may be an empty string if we are not doing binary classifiers)
    
    raise "Please overwrite this when inheriting"
  end

  ###
  # start_using_classifier
  #
  # prepare file(s) for using a classifier
  def start_using_classifier(lemma, # string: make classifier specific to this lemma
			     sense) # string: make classifier specific to this sense
                                    # (may be an empty string if we are not doing binary classifiers)
    raise "Please overwrite this when inheriting"
  end

  ###
  # close_classifier
  #
  # close streams associated with the current classifier
  def close_classifier()
    raise "Please overwrite this when inheriting"
  end


  ###
  # handle_training_instances
  #
  # use the given instances to train a classifier
  #
  # this method accepts as its parameter a reader object
  # that has methods instances() and each_instance().
  # instances() returns a list of instances, 
  # each_instance() yields each instance in turn.
  #
  # An instance is a hash 
  #  "sentid" => sentence ID(string),
  #   "lemma" => lemma(string),
  #   "sense" => sense(string),
  #   "features" => features_and_weights: array of pairs [feature(string), weight(float)]
  def handle_training_instances(reader) # object with methods as described above
    raise "Please overwrite this when inheriting"
  end

  ###
  # handle_test_instances
  #
  # classify the given instances with the appropriate classifier
  #
  # this method accepts as its parameter a reader object
  # that has methods instances() and each_instance().
  # instances() returns a list of instances, 
  # each_instance() yields each instance in turn.
  #
  # An instance is a hash 
  #  "sentid" => sentence ID(string),
  #   "lemma" => lemma(string),
  #   "sense" => sense(string),
  #   "features" => features_and_weights: array of pairs [feature(string), weight(float)]
  #
  # returns: array of classification results, one for each instance
  # that the reader object yields.
  # A classification result is a list of pairs [target_class, probability]

  def handle_test_instances(reader) # object with methods as described above
    raise "Please overwrite this when inheriting"
  end


end
