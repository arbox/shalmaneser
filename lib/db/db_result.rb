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
  def list_column_names
    raise "Overwrite me"
  end

  # number of rows: returns an integer
  def num_rows
    return @result.num_rows
  end

  # yields each row as an array of values
  def each
    @result.each { |row| yield row }
  end

  # yields each row as a hash: column name=> column value
  def each_hash
    @result.each_hash { |row_hash| yield row_hash }
  end

  # reset object, such that each() can be run again
  # DEFAULT DOES NOTHING, PLEASE OVERWRITE
  def reset
  end

  # free result object
  def free
    @result.free
  end

  # returns row as an array of column contents
  def fetch_row
    return @result.fetch_row
  end

end
