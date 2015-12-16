# DBSQLite: a subclass of DBWrapper.
#
# Use SQLite to access a database.
# Use the Ruby sqlite3 interface package for that.

require 'sqlite3'
require 'tempfile'

require 'db/db_wrapper'

#################
class DBSQLiteResult < DBResult
  # initialize with the result of SQLite::execute()
  # which returns an array of rows
  # Each row is an array
  # but additionally has attributes
  # - fields: returns an array of strings, the column names
  # - types: returns an array of strings, the column types
  def initialize(value)
    super(value)
    @counter = 0
  end

  ###
  # column names: list of strings
  def list_column_names
    return @result.columns
  end

  # number of rows: returns an integer
  def num_rows
    # remember where we were in iterating over items
    tmp_counter = @counter

    # reset, and iterate over all rows to count
    reset
    retv = 0
    each { |x| retv += 1}

    # return to where we were in iterating over items
    reset
    while @counter < tmp_counter
      @result.next
      @counter += 1
    end

    # and return the number of rows
    return retv
  end


  # yields each row as an array of values
  def each
    @result.each { |row|
      @counter += 1
      yield row.map { |x| x.to_s }
    }
  end

  # yields each row as a hash: column name=> column value
  def each_hash
    @result.each { |row|
      @counter += 1

      row_hash = {}
      row.fields.each_with_index { |key, index|
        row_hash[key] = row[index].to_s
      }
      yield row_hash
    }
  end


  ###
  # reset such that each() can be run again on the result object
  def reset
    @result.reset
    @counter = 0
  end

  # free object
  def free
    @result.close
  end

  # returns row as an array of column contents
  def fetch_row
    @counter += 1
    return @result.next
  end
end

#################
class DBSQLite < DBWrapper

  ###
  # initialization:
  #
  # open database file according to the given identifier
  def initialize(exp,  # RosyConfigData experiment file object
                 dir = nil,  # string: directory for Shalmaneser internal data, ends in "/"
                 identifier = nil) # string: identifier to use for the database
    super(exp)

    # dir and identifier may be nil, if we're only opening this object
    # in order to make temp databases
    if dir and identifier
      @database = SQLite3::Database.new(dir + identifier.to_s + ".db")
    else
      @database = nil
    end

    # temp file for temp database
    @tf = nil
  end

  ###
  # make a table
  #
  # returns: nothing
  def create_table(table_name, # string
                   column_formats, # array: array: string*string [column_name,column_format]
                   index_column_names, # array: string: column_name
                   indexname)  # string: name of automatically created index column

    # primary key and auto-increment column
    string = "CREATE TABLE #{table_name} (" +
             "#{indexname} INTEGER PRIMARY KEY"

    # column declarations
    unless column_formats.empty?
      string << ", "
      string << column_formats.map { |name, format|
        # include other keys
        if index_column_names.include? name
          name.to_s + " KEY " + format.to_s
        else
          name.to_s + " " + format.to_s
        end
      }.join(",")
    end
    string << ");"

    query_noretv(string)
  end

  ###
  # remove a table
  def drop_table(table_name)
    query_noretv("DROP TABLE " + table_name)
  end

  ###
  def query(query)
    if @database
      return DBSQLiteResult.new(@database.query(query))
    else
      return nil
    end
  end

  ####
  # querying the database:
  # no result value
  def query_noretv(query)
    if @database
      @database.execute(query)
    end
    return nil
  end

  ###
  # list all tables in the database
  #
  # array of strings
  def list_tables
    if @database
      return @database.execute("select name from sqlite_master;").map { |t|
        t.to_s
      }
    else
      return nil
    end
  end

  #####
  # list_column_formats
  #
  # list column names and column types of this table
  #
  # returns: array:string*string, list of pairs [column name, column format]
  def list_column_formats(table_name)
    unless @database
      return nil
    end

    table_descr = @database.execute("select * from sqlite_master where name=='#{table_name}';")
    # this is an array of pieces of table description.
    # the piece in the column called 'sql' is the 'create' statement.
    # get the 'create' statement
    begin
      field_names = table_descr[0].fields
    rescue
      $stderr.puts "SQLite error: could not read description of table #{table_name}"
      exit 1
    end
    create_index = (0..field_names.length).detect { |ix| field_names[ix] == 'sql' }

    # try to parse column names out of the 'create' statement
    if table_descr[0][create_index] =~ /^\s*create table \S+\s*\((.*)\)\s*$/i
      # we now have something of shape ' a key varchar2(30), b varchar2(30)'
      # split at the comma, remove whitespace at beginning and end
      # then split again to get pairs [column name, column format]
      return $1.split(",").map { |col_descrip|
        pieces = col_descrip.strip.split.reject { |entry|
          entry =~ /^key$/i or  entry =~ /^primary$/i
        }
        if pieces.length > 2
          $stderr.puts "Warning: problematic column format in #{col_descrip}, may be parsed wrong."
        end
        pieces
      }
    else
      $stderr.puts "SQLite error: cannot read column names"
      exit 1
    end
  end

  ####
  # num_rows
  #
  # determine the number of rows in a table
  # returns: integer or nil
  def num_rows(table_name)
    unless @database
      return nil
    end

    rows_s = @database.get_first_value( "select count(*) from #{table_name}" )
    if rows_s
      return rows_s.to_i
    else
      return nil
    end
  end

  ####
  # make a temporary table: make a table in a new, temporary file
  #
  # returns: DBWrapper object (or object of current subclass)
  # that has the @table_name attribute set to the name of a temporary DB
  #
  # same as in superclass
  #
  #   def make_temp_table(column_formats, # array: string*string [column_name,column_format]
  #                       index_column_names, # array: string: column_name
  #                       indexname)  # string: name of autoincrement primary index

  #     temp_obj = self.clone()
  #     temp.initialize_temp_table(column_formats, index_column_names, indexname)
  #     return temp_obj
  #   end

  def drop_temp_table
    @tf.close(true)
    @database = nil
  end

  ##############################
  protected

  def initialize_temp_table(column_formats, index_column_names, indexname)
    @table_name = "temptable"
    @tf = Tempfile.new("temp_table")
    @tf.close
    @database = SQLite3::Database.new(@tf.path)
    create_table(@table_name, column_formats, index_column_names, indexname)
  end

end
