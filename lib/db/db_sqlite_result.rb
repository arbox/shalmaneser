require_relative 'db_result'

module Shalmaneser
  module DB
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
  end
end
