#################################################################
#################################################################
# Table and column names to pass on to a view / SQLQuery:
# which DB table to access, which columns to view?
#
# table_obj: DBTable object or DBWrapper object, table to access.
#            The important thing is that the object must have a table_name attribute.
# columns: string|array:string, list of column names, or "*" for all columns

SelectTableAndColumns = Struct.new("SelectTableAndColumns", :table_obj, :columns)
