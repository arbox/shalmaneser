# ExternalConfigData
# Katrin Erk January 2006
#
# All scripts that compute additional external knowledge sources
# for Fred and Rosy:
# access to configuration and experiment description file

require 'common/ConfigData'

##############################
# Class ExternalConfigData
#
# inherits from ConfigData,
# sets variable names appropriate to tasks of external knowledge sources

class ExternalConfigData < ConfigData
  def initialize(filename)

    # initialize config data object
    super(filename,          # config file
	  { "directory" => "string", # features

	    "experiment_id" => "string",

	    "gfmap_restrict_to_downpath" => "bool",
	    "gfmap_restrict_pathlen" => "integer",
	    "gfmap_remove_gf" => "list"
	  },
	  [] # variables
	  )

    # set access functions for list features
    set_list_feature_access("gfmap_remove_gf", 
			    method("access_as_stringlist"))
  end

  ###
  protected

  #####
  # access_as_stringlist
  #
  # assumed format:
  #
  #   lhs = rhs1 rhs2 ... rhsN
  #
  # given in val_list as string tuples [rhs1,...,rhsN]
  #
  # join the rhs strings by spaces, return as string
  # "rhs1 rhs2 ... rhsN"
  #
  def access_as_stringlist(val_list) # array:array:string
    return val_list.map { |rhs| rhs.join(" ") }
  end
end


 
