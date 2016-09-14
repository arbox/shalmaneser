require_relative 'db_result'

module Shalmaneser
  module DB
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
  end
end
