require 'value_restriction'
###
# value restrictions saying that variable1 = variable2:
# here, value is a variable name, and the table names
# must be already included
class VarVarRestriction < ValueRestriction
  def initialize(column, value, var_hash = {})
    super(column, value, var_hash)
    @val_is_variable = true
    @table_name_included = true
  end
end
