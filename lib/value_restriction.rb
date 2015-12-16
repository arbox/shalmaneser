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
  def get
    return [@column, @posneg, @value]
  end
end
