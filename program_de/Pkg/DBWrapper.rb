###########################
# DBWrapper:
# abstract class wrapping database interfaces,
# so we can have both an interface to an SQL server
# and an interface to SQLite in Shalmaneser
class DBWrapper
  attr_reader :table_name

  ###
  def initialize(exp)  # RosyConfigData experiment file object
    # remember experiment file
    @exp = exp

    # open the database:
    # please set to some other value in subclass initialization
    @database = nil

    # name of default table to access: none
    @table_name = nil
  end

  ###
  # close DB access
  def close()
    @database.close()
  end

  ####
  # querying the database:
  # returns an DBResult object
  def query(query)
    raise "Overwrite me"
  end

  ####
  # querying the database:
  # no result value
  def query_noretv(query)
    raise "Overwrite me"
  end

  ###
  # list all tables in the database:
  # no default here
  #
  # returns: list of strings
  def list_tables()
    raise "Overwrite me"
  end

  ###
  # make a table
  #
  # returns: nothing
  def create_table(table_name, # string
                   column_formats, # array: array: string*string [column_name,column_format]
                   index_column_names, # array: string: column_name
                   indexname)  # string: name of automatically created index column    
    raise "overwrite me"
  end

  ###
  # remove a table
  def drop_table(table_name)
    query_noretv("DROP TABLE " + table_name)
  end

  ###
  # list all column names of a table (no default)
  #
  # returns: array of strings
  def list_column_names(table_name)
    return list_column_formats(table_name).map { |col_name, col_format| col_name }
  end

  #####
  # list_column_formats
  #
  # list column names and column types of this table
  #
  # returns: array:string*string, list of pairs [column name, column format]
  def list_column_formats(table_name)
    raise "Overwrite me"
  end

  ####
  # num_rows
  #
  # determine the number of rows in a table
  # returns: integer
  def num_rows(table_name)
    raise "Overwrite me"
  end

  ####
  # make a temporary table: basically just make a table
  #
  # returns: DBWrapper object (or object of current subclass)
  # that has the @table_name attribute set to the name of a temporary DB
  def make_temp_table(column_formats, # array: string*string [column_name,column_format]
                      index_column_names, # array: string: column_name
                      indexname)  # string: name of autoincrement primary index

    temp_obj = self.clone()
    temp_obj.initialize_temp_table(column_formats, index_column_names, indexname)
    return temp_obj
  end

  def drop_temp_table()
    unless @table_name
      raise "can only do drop_temp_table() for objects that have a temp table"
    end
    drop_table(@table_name)
  end

  ##############################
  protected

  def initialize_temp_table(column_formats, index_column_names, indexname)
    @table_name = "t" + Time.new().to_f().to_s().gsub(/\./, "")
    create_table(@table_name, column_formats, index_column_names, indexname)
  end
end




######################################################################
# DBResult:
# abstract class keeping query results
#
# instantiate for the DB package used
class DBResult
  ###
  # initialize with query result, and keep it
  def initialize(value)
    @result = value
  end

  # column names: NO DEFAULT
  def list_column_names()
    raise "Overwrite me"
  end

  # number of rows: returns an integer
  def num_rows()
    return @result.num_rows
  end

  # yields each row as an array of values
  def each()
    @result.each { |row| yield row }
  end

  # yields each row as a hash: column name=> column value
  def each_hash()
    @result.each_hash { |row_hash| yield row_hash }
  end

  # reset object, such that each() can be run again
  # DEFAULT DOES NOTHING, PLEASE OVERWRITE
  def reset()
  end

  # free result object
  def free()
    @result.free()
  end

  # returns row as an array of column contents
  def fetch_row()
    return @result.fetch_row()
  end

end
