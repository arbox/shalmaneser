# FredConfigData
# Katrin Erk April 05
#
# Frame disambiguation system:
# access to a configuration and experiment description file

require_relative 'config_data'

##############################
# Class FredConfigData
#
# inherits from ConfigData,
# sets variable names appropriate to WSD task

class FredConfigData < ConfigData
  CONFIG_DEFS = {
    "experiment_ID" => "string", # experiment ID
    "enduser_mode" => "bool", # work in enduser mode? (disallowing many things)

    "preproc_descr_file_train" => "string", # path to preprocessing files
    "preproc_descr_file_test" => "string",
    "directory_output" => "string", # path to Salsa/Tiger XML output directory

    "verbose" => "bool" ,     # print diagnostic messages?
    "apply_to_all_known_targets" => "bool", # apply to all known targets rather than the ones with a frame?

    "fred_directory" => "string",# directory for internal info
    "classifier_dir" => "string", # write classifiers here

    "classifier" => "list",  # classifiers

    "dbtype" => "string",    # "mysql" or "sqlite"

    "host" => "string",      # DB access: sqlite only
    "user" => "string",
    "passwd" => "string",
    "dbname" => "string",

    # featurization info
    "feature" => "list",     # which features to use for the classifier?
    "binary_classifiers" => "bool",# make binary rather than n-ary clasifiers?
    "negsense" => "string",  # binary classifier: negative sense is..?
    "numerical_features" => "string", # do what with numerical features?

    # what to do with items that have multiple senses?
    # 'binarize': binary classifiers, and consider positive
    #          if the sense is among the gold senses
    # 'join' : make one joint sense
    # 'repeat' : make multiple occurrences of the item, one sense per occ
    # 'keep' : keep as separate labels
    #
    # multilabel: consider as assigned all labels
    # above a certain confidence threshold?
    "handle_multilabel" => "string",
    "assignment_confidence_threshold" => "float",

    # single-sentence context?
    "single_sent_context" => "bool",

    # noncontiguous input? then we need access to a larger corpus
    "noncontiguous_input" => "bool",
    "larger_corpus_dir" => "string",
    "larger_corpus_format" => "string",
    "larger_corpus_encoding" => "string",
    # Imported from PrepConfigData
    'do_postag' => 'bool',
    'do_lemmatize' => 'bool',
    'do_parse' => 'bool',
    'pos_tagger' => 'string',
    'lemmatizer' => 'string',
    'parser' => 'string',
    'directory_preprocessed' => 'string',
    'language' => 'string'
  }

  def initialize(filename)

    super(filename, CONFIG_DEFS, ["train", "exp_ID"])

    # set access functions for list features
    set_list_feature_access("classifier", method("access_classifier"))
    set_list_feature_access("feature", method("access_feature"))
  end

  ###
  # protected

  #####
  # access_feature
  #
  # access function for feature 'feature'
  #
  # assumed format:
  #
  #   feature = context 50
  #   feature = context 2
  #   feature = syn
  #
  # i.e. first the name of the feature type to use, then
  # optionally a parameter,
  # and the same feature can occur more than once (which makes sense
  # only in case of parameters)
  #
  #
  # returns:
  #  - If a feature is given as a parameter,
  #    - If the feature is not set in the experiment file, nil
  #    - If the feature is set and has a parameter, the list of
  #      parameter values set for it. It is assumed that the parameters
  #      are integers, and they are returned as integers
  #    - If the feature is set and has no parameter, true
  # - If no feature is given as parameter:
  #   a list of all features that have been set in the experiment file
  #   Each feature is given as a tuple: the first element is the feature (a string),
  #   all further elements are options (integers)
  def access_feature(val_list, # array:array:string: list of tuples defined in config file
		               # for feature 'feature'
		     feature=nil)  # string: feature type name

    if feature
      # access options for this feature

      # get the right tuples
      positives = val_list.select { |entries|
        entries.first() == feature
      }.map { |entries|
        entries[1]
      }

      if positives.empty?
        # feature not defined
        return nil

      elsif positives.compact().empty?
        # feature defined, but no parameters
        return true

      else
        # feature defined, and has values
        return positives.map { |par| par.to_i() }
      end

    else
      # return all features that have been set
      return val_list.map { |feature_name, *options|
        [feature_name] + options.map { |o| o.to_i() }
      }
    end
  end

  #####
  # access_classifier
  #
  # access function for feature 'classifier'
  #
  # assumed format in the config file:
  #
  #   feature = path [option]*
  #
  # i.e. first the name of the feature type to use, then
  # optionally options associated with that feature,
  # e.g. 'argrec': use that feature only when computing argrec
  #
  # the access function is called with parameter val_list, an array of
  # string tuples, one string tuple for each feature defined.
  # the first string in the tuple is the feature name, the rest are the options
  #
  # returns: a list of pairs [feature_name(string), options(array:string)]
  # of defined features
  # @param val_list [Array] array:array:string: list of tuples defined
  #   in config file for feature 'feature'
  def access_classifier(val_list)
    if val_list.nil?
      []
    else
      val_list.map do |cl_descr_tuple|
        [cl_descr_tuple.first, cl_descr_tuple[1..-1]]
      end
    end
  end

end
