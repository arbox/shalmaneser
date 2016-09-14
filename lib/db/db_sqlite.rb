# DBSQLite: a subclass of DBWrapper.
#
# Use SQLite to access a database.
# Use the Ruby sqlite3 interface package for that.

require 'sqlite3'
require 'tempfile'

require_relative 'db_wrapper'
require_relative 'db_sqlite_result'

#################
module Shalmaneser
  module DB
    class DBSQLite < DBWrapper

      ###
      # initialization:
      #
      # open database file according to the given identifier
      # @param RosyConfigData experiment file object
      # @param string: directory for Shalmaneser internal data, ends in "/"
      # @param string: identifier to use for the database
      def initialize(exp, dir = nil, identifier = nil)
        super(exp)

        # dir and identifier may be nil, if we're only opening this object
        # in order to make temp databases
        if dir && identifier
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
      # @param  # string
      # @param  # array: array: string*string [column_name,column_format]
      # @param # array: string: column_name
      # @param   # string: name of automatically created index column
      def create_table(table_name, column_formats, index_column_names, indexname)
        # primary key and auto-increment column
        string = "CREATE TABLE #{table_name} (" + "#{indexname} INTEGER PRIMARY KEY"

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
        DBSQLiteResult.new(@database.query(query)) if @database
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
      # @return [Array<String>] Names of the tables in the DB.
      def list_tables
        if @database
          query = "SELECT name FROM 'sqlite_master' WHERE type = 'table';"
          @database.execute(query).flatten
        end
      end

      #####
      # list_column_formats
      #
      # list column names and column types of this table
      #
      # returns: array:string*string, list of pairs [column name, column format]
      def list_column_formats(table_name)
        return nil unless @database

        begin
          table_descr = @database.execute("SELECT sql FROM sqlite_master WHERE name = '#{table_name}';")
          # this is an array of pieces of table description.
          # the piece in the column called 'sql' is the 'create' statement.
          # get the 'create' statement
          sql_string = table_descr[0][0]
        rescue => e
          $stderr.puts "SQLite error: could not read description of table #{table_name}"
          # exit 1
          raise e
        end

        # try to parse column names out of the 'create' statement
        if sql_string =~ /^\s*create table \S+\s*\((.*)\)\s*$/i
          # we now have something of shape ' a key varchar2(30), b varchar2(30)'
          # split at the comma, remove whitespace at beginning and end
          # then split again to get pairs [column name, column format]
          return $1.split(",").map do |col_descrip|
            pieces = col_descrip.strip.split.reject do |entry|
              entry =~ /^key|primary$/i
            end
            if pieces.length > 2
              $stderr.puts "Warning: problematic column format in #{col_descrip}, may be parsed wrong."
            end
            pieces
          end
        else
          $stderr.puts "SQLite error: cannot read column names"
          raise
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
      private

      def initialize_temp_table(column_formats, index_column_names, indexname)
        @table_name = "temptable"
        @tf = Tempfile.new("temp_table")
        @tf.close
        @database = SQLite3::Database.new(@tf.path)
        create_table(@table_name, column_formats, index_column_names, indexname)
      end
    end
  end
end
