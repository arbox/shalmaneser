# class DBTable
# KE, SP 27.1.05
#
# Manages one table in a (given) SQL database
# Doesn't know anything about the ROSY application
# Just creating a table, changing the table, and accessing it.
#

require "common/SQLQuery"
require "common/RosyConventions"

class DBTable
  attr_reader :index_name, :table_name

  #####
  # new
  #
  # creates the table for this object.
  # The name of the table (given as parameter) can be new, in which caes the table
  # is created, or old, in which case we check whether its format matches the format
  # given in the parameters.
  #
  # The table format is given in the form of column formats (column names and column formats,
  # formats are the usual SQLy things). Additionally, a subset of the column names can be
  # designated index columns, which means that the table is indexed (and can be searched quickly)
  # for them.
  #
  # DBTable internally constructs a "Primary index" feature that is called "XXindexXX" (autoincrement column)
  #
  # For all columns that are added later using add_columns, DBTable adds a prefix to the column names;
  # these columns are not checked against the column_formats when opening an existing table;
  # this can be used to store experiment-specific data.

  def initialize(db_obj, # DBWrapper object
		 table_name, # string: name of DB table (existing/new)
		 mode,       # new: starts new DB table, removes old if it exists. open: reopens existing DB table
		 hash={})    # hash: parameter name => parameter value, depending on mode
                             # mode= new needs: 
                             #  'col_formats': array:array len 2: string*string, [column_name, column_format] 
                             #  'index_cols':  array:string: column_names that should be used to index the table
                             #  'addcol_prefix': string: prefix for names of additional columns
                             # mode='open' needs:
                             #  'col_formats': array: string*string: column names/formats
                             #               May be nil, in that case column name match isn't tested

    @index_name = "XXindexXX"
    @db_obj = db_obj
    @table_name = table_name

    case mode
    when 'new'
      ###
      # open new database

      # sanity check: exactly the required parameters present?
      unless hash.keys.sort == ['addcol_prefix', 'col_formats', 'index_cols']
	raise "Expecting hash parameters 'addcol_prefix', 'col_formats', 'index_cols'.\n" +
	  "I got: " + hash.keys.join(", ")
      end

      # sanity check: main index column name should be unique
      all_column_names = hash['col_formats'].map { |name, format| name}
      if all_column_names.include? @index_name
	raise "[DBTable] You used the reserved name #{@index_name} as a column name. Please don't do that!"
      end

      # sanity check: index_column_names should be included in column_names
      hash['index_cols'].each { |name| 
	unless all_column_names.include? name
	  raise "[DBTable] #{name} is in the list of index names, but it isn't in the list of column names."
	end
      }

      # does a table with name table_name exist? if so, remove it
      if @db_obj.list_tables().include? table_name
	# this table exists
	# remove old table
	@db_obj.drop_table(table_name)
      end

      @db_obj.create_table(table_name,hash['col_formats'],
                           hash['index_cols'], @index_name)
    when 'open'

      ###
      # open existing database table

      # sanity check: exactly the required parameters present?
      hash.keys.each { |key|
        unless ['addcol_prefix', 'col_names'].include? key
          raise "Expecting hash parameters 'addcol_prefix', 'col_names'.\n" +
          "I got: " + hash.keys.join(", ")
        end
      }
      # sanity check: main index column name should be unique
      if hash['col_names'] and hash['col_names'].include? @index_name
	raise "[DBTable] You used the reserved name #{@index_name} as a column name. Please don't do that!"
      end


      # does a table with name table_name exist?
      unless @db_obj.list_tables().include? table_name
	raise "[DBTable] Sorry, I cannot find a database table named #{table_name}."
      end

      # check if all column formats match

      if hash['col_names']

        existing_fields = @db_obj.list_column_names(table_name).reject { |col|
          col =~ /^#{hash["addcol_prefix"]}/ or
          col == @index_name
        }

        unless existing_fields.sort() == hash["col_names"].sort()
          raise "[DBTable] Column names in the DB table #{table_name}\n" + 
                "don't match feature specification in the experiment file.\n" + 
                "Table:\n\t" + existing_fields.sort.join(", ") +
                 "\n\nExp. file:\n\t" + hash["col_names"].sort.join(", ")
        end

      else
        # no column names given, no check of column formats
      end

    else
      raise "Parameter 'mode' needs to be either 'new' or 'open'! I got " + mode.to_s
    end
  end

  #####
  # list_column_names
  #
  # list column names of this table
  #
  # returns: array:string, list of column names
  def list_column_names()
    return @db_obj.list_column_names(@table_name)
  end

  #####
  # list_column_formats
  #
  # list column names and column types of this table
  #
  # returns: array:string*string, list of pairs [column name, column format]
  def list_column_formats()
    return @db_obj.list_column_formats(@table_name)
  end

  #####
  # change_format_add_columns
  #
  # adds one or more columns to the table managed by this object
  # columns are given by their names and formats, as above
  #
  # returns: nothing
  def change_format_add_columns(column_formats) # array: string*string [column_name,column_format]

    if column_formats.nil? or column_formats.empty?
      raise "Need nonempty column_formats list"
    end
    
    column_formats.each {|col_name,col_format|
      unless col_name =~ /^#{@addcol_prefix}/
	raise "Columns that are added need to have prefix #{@addcol_prefix}!" 
      end
    }

    execute_command(SQLQuery.add_columns(@table_name, column_formats))
  end

  #####
  # change_format_remove_column
  #
  # removes one column from the table managed by this object
  #
  # returns: nothing
  def change_format_remove_column(column_name) # string:name of the column to remove
    unless list_column_names(@table_name).include? column_name
      $stderr.puts "WARNING: Cannot remove column #{column_name}: I don't have it"
      return
    end

    execute_command("ALTER TABLE #{@table_name} DROP COLUMN #{column_name}")
  end

  
  #####
  # insert_row
  #
  # inserts a new row into the table and fills cells with values, as specified
  # by the column_value_pairs
  #
  # returns: nothing
  def insert_row(column_value_pairs) # array: string*Object [column_name,column_value]
    if column_value_pairs.nil? or column_value_pairs.empty?
      raise "Need nonempty column_value_pairs list"
    end
    execute_command(SQLQuery.insert(@table_name,column_value_pairs))
  end

  #####
  # update_row
  #
  # update column values for a given row which is identified
  # via its (autoincrement) index
  #
  # returns: nothing
  def update_row(index, # index, content of autoincrement column
		 column_value_pairs) # array: string*Object [column_name, column_value]

    if column_value_pairs.nil? or column_value_pairs.empty?
      raise "Need nonempty column_value_pairs list"
    end
    execute_command(SQLQuery.update(@table_name,
				    column_value_pairs, 
				    [ValueRestriction.new(@index_name, index)]))
  end


  ####
  private

  ###
  # execute_command:
  # execute DB command
  #
  # returns nil: the commands in this package are all
  # not of the kind that requires a return value
  def execute_command(command)
    begin
      @db_obj.query_noretv(command)
    rescue 
      $stderr.puts "Error executing SQL query. Command was:\n" + command
      exit 1
    end
  end
end
