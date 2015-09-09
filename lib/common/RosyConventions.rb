# RosyConventions
# KE May 05
#
# Conventions to be used throughout the Rosy system
# for greater consistency

require "common/ruby_class_extensions"

#################################################################
#################################################################
# Table and column names to pass on to a view / SQLQuery:
# which DB table to access, which columns to view?
#
# table_obj: DBTable object or DBWrapper object, table to access.
#            The important thing is that the object must have a table_name attribute.
# columns: string|array:string, list of column names, or "*" for all columns

SelectTableAndColumns = Struct.new("SelectTableAndColumns", :table_obj, :columns)

#################################################################
#################################################################

###
# transforming feature output to a format that classifiers can handle
def prepare_output_for_classifiers(string)
  # change punctuation to _PUNCT_
  # and change empty space to _
  # because otherwise some classifiers may spit
  string.gsub(/[.":';`]/,"_PUNCT_").gsub(/\s/,"_")
end

#################################################################
#################################################################

###
# classifier directory:
#  either user-given classifier_dir or our own default classifier directory,
#  then argrec/arglab/onestep, plus the splitID, if there is one
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
# instance ID: sentence ID plus frame ID
def construct_instance_id(sentence_id, frame_id)
  return sentence_id.to_s + "---" + frame_id.to_s
end

def deconstruct_instance_id(instance_id)
  return instance_id.split("---")
end

#################################################################
#################################################################

# default test ID given when the user didn't specify one
def default_test_ID
  "apply"
end
