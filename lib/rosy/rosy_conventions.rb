require 'monkey_patching/file'

module Shalmaneser
module Rosy

  module_function

  # transforming feature output to a format that classifiers can handle
  # @note Used only under Rosy.
  def prepare_output_for_classifiers(string)
    # change punctuation to _PUNCT_
    # and change empty space to _
    # because otherwise some classifiers may spit
    string.gsub(/[.":';`]/,"_PUNCT_").gsub(/\s/,"_")
  end

  ###
  # classifier directory:
  #  either user-given classifier_dir or our own default classifier directory,
  #  then argrec/arglab/onestep, plus the splitID, if there is one
  # @note Need the extended File class.
  # @note Used only under Rosy.
  def classifier_directory_name(exp,     # RosyConfigData object
                                step,    # argrec, arglab, onestep
                                splitID) # string or nil

    if exp.get("classifier_dir")
      base_dir = File.new_dir(exp.get("classifier_dir"))
    else
      base_dir = File.new_dir(exp.instantiate("rosy_dir",
                                              "exp_ID" => exp.get("experiment_ID")))
    end
    classif_base_dir = File.new_dir(base_dir, "classif_dir")

    if splitID
      return File.new_dir(classif_base_dir, step +  "." + splitID.to_s)
    else
      return File.new_dir(classif_base_dir, step)
    end
  end

  #################################################################
  #################################################################

  ###
  # @note Used only under Rosy.
  # instance ID: sentence ID plus frame ID
  def construct_instance_id(sentence_id, frame_id)
    sentence_id.to_s + "---" + frame_id.to_s
  end

  # @note Not used anywhere.
  def deconstruct_instance_id(instance_id)
    instance_id.split("---")
  end

  #################################################################
  #################################################################

  # default test ID given when the user didn't specify one
  # @note Used only under Rosy.
  def default_test_ID
    "apply"
  end
end
end
