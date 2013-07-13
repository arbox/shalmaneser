# RosyConventions
# KE May 05
#
# Conventions to be used throughout the Rosy system
# for greater consistency

require "common/ruby_class_extensions"

require "common/EnduserMode"

#################################################################
#################################################################
###
# value restriction (to pass on to a view):
# some column is restricted to be equal/inequal to some value
class ValueRestriction

  attr_reader :val_is_variable, :table_name_included

  ###
  # new(): store values
  def initialize(column, # string: column name
		 value,  # value this column is to be restricted to 
		 var_hash = {}) # hash:additional settings. possible entries:
                 # posneg: string: "=" or "!=": equality or inequality restriction
                 #         (default: =)
                 # table_name_included: boolean: is the table name aready included
                 #         in the column name? default: false

    @column = column
    @value = value

    @posneg = var_hash["posneg"]
    if @posneg.nil?
      # per default, equality restriction
      @posneg = "="
    else
      unless ["=", "!="].include? @posneg
        raise "posneg should be either '=' or '!='. I got: " + @posneg.to_s
      end
    end

    @table_name_included = var_hash["table_name_included"]
    if @table_name_included.nil?
      # per default, the table name is not yet included
      # in the column name
      @table_name_included = false
    end

    # per default, value is a value and not another column name
    @val_is_variable = false
  end

  ###
  # get(): returns a triple [column name(string), eq(string), value(object)]
  def get()
    return [@column, @posneg, @value]
  end
end

###
# value restrictions saying that variable1 = variable2:
# here, value is a variable name, and the table names
# must be already included
class VarVarRestriction < ValueRestriction
  def  initialize(column, value, var_hash={})
    super(column, value, var_hash)
    @val_is_variable = true
    @table_name_included = true
  end
end

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
  return string.gsub(/[.":';`]/,"_PUNCT_").gsub(/\s/,"_")
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
def default_test_ID()
  return "apply"
end


#################################################################
#################################################################

###
# extend Array class by subsumption
module Subsumed
  def subsumed_by?(array2)
    temp = array2.clone()
    self.each { |el|
      found = false
      temp.each_index { |ix|
        if el == temp[ix]
          temp.delete_at(ix)
          found = true
          break
        end
      }
      unless found
        return false
      end
    }
    return true
  end
end

class Array
  include Subsumed
end
