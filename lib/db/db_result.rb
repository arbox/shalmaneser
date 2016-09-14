######################################################################
# DBResult:
# abstract class keeping query results
#
module Shalmaneser
  module DB
    # instantiate for the DB package used
    # @abstract
    class DBResult
      ###
      # initialize with query result, and keep it
      def initialize(value)
        @result = value
      end

      # column names: NO DEFAULT
      # @abstract
      def list_column_names
        raise NotImplementedError
      end

      # number of rows: returns an integer
      def num_rows
        @result.num_rows
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
      # @abstract
      def reset
        raise NotImplementedError
      end

      # free result object
      def free
        @result.free
      end

      # returns row as an array of column contents
      def fetch_row
        @result.fetch_row
      end
    end
  end
end
