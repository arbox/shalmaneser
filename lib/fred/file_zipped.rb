require 'fred/fred_error'
require 'logging'

module Shalmaneser
  module Fred
    class FileZipped

      # @todo Rewrite this class using stdlib.
      # @return [IO]
      # @param filename [String]
      # @param mode [String]
      # @raise [FredError] if some external error occured
      def self.new(filename, mode = 'r')
        # escape characters in the filename that
        # would make the shell hiccup on the command
        filename = filename.gsub(/([();:!?'`])/, 'XXSLASHXX\1')
        filename = filename.gsub(/XXSLASHXX/, "\\")

        unless %w{r w a}.include?(mode)
          LOGGER.fatal "FileZipped error: only modes r, w, a are implemented. "\
                       "I got: #{mode}."
          raise FredError
        end

        begin
          case mode
          when "r"
            unless File.exist?(filename)
              raise FredError, 'File does not exist!'
            end
            return IO.popen("gunzip -c #{filename}")
          when "w"
            return IO.popen("gzip > #{filename}", "w")
          when "a"
            return IO.popen("gzip >> #{filename}", "w")
          end
        rescue => e
          raise FredError, "Error opening file #{filename}.", e
        end
      end
    end
  end
end
