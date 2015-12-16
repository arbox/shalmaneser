# DBMysql: a subclass of DBWrapper.
#
# Use a MySQL server to access a database.
# Use the Ruby mysql interface package for that.

require 'mysql'
require 'db/db_wrapper'

#################
class DBMySQLResult < DBResult
  # initialize with the result of Mysql::query
  # which is a MysqlResult object
  #
  # also remember the offset of the first row
  # for reset()
  def initialize(value)
    super(value)
    @row_first = @result.row_tell
  end

  ###
  # reset object such that each() can be run again
  def reset
    @result.row_seek(@row_first)
  end

  ###
  # column names: list of strings
  def list_column_names
    current = @result.row_tell
    fields = @result.fetch_fields.map(&:name)
    @result.row_seek(current)

    fields
  end
end

#################
class DBMySQL < DBWrapper
  ###
  # initialization:
  #
  # open connection to MySQL server
  def initialize(exp)  # RosyConfigData experiment file object
    super(exp)

    @database = Mysql.real_connect(@exp.get('host'), @exp.get('user'),
                                   @exp.get('passwd'), @exp.get('dbname'))

  end


  ###
  # make a table
  #
  # returns: nothing
  def create_table(table_name, # string
                   column_formats, # array: array: string*string [column_name,column_format]
                   index_column_names, # array: string: column_name
                   indexname)  # string: name of automatically created index column

    string = "CREATE TABLE #{table_name} (" +
      "#{indexname} INT NOT NULL AUTO_INCREMENT"

    # column declarations
    unless column_formats.empty?
      string << ", "
      string << column_formats.map { |name, format| name.to_s + " " + format.to_s }.join(",")
    end

    # primary key
    string << ", " + "PRIMARY KEY(#{indexname})"

    # other keys
    unless index_column_names.empty?
      string << ", "
      string << index_column_names.map { |name| "KEY(#{name})" }.join(",")
    end
    string << ");"

    query_noretv(string)
  end

  ####
  # querying the database:
  # returns a DBResult object
  def query(query)
    result = @database.query(query)
    if result
      return DBMySQLResult.new(result)
    else
      return nil
    end
  end

  ####
  # querying the database:
  # no result value
  def query_noretv(query)
    @database.query(query)
    return nil
  end

  ###
  # list all tables in the database
  #
  # array of strings
  def list_tables
    return @database.list_tables
  end


  #####
  # list_column_formats
  #
  # list column names and column types of this table
  #
  # returns: array:string*string, list of pairs [column name, column format]
  def list_column_formats(table_name)
    retv = []
    @database.query("DESCRIBE #{table_name}").each_hash { |field|
      retv << [field["Field"], field["Type"]]
    }
    return retv
  end

  ####
  # num_rows
  #
  # determine the number of rows in a table
  # returns: integer or nil
  def num_rows(table_name)
    @database.query("SHOW TABLE STATUS").each_hash { |hash|
      if hash["Name"] == table_name
        return hash["Rows"]
      end
    }
    return nil
  end

end
