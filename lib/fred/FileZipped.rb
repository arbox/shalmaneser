class FileZipped

  # @todo Rewrite this class using stdlib.
  # @return [IO]
  # @param filename [String]
  # @param mode [String]
  def self.new(filename, mode = 'r')
    # escape characters in the filename that
    # would make the shell hiccup on the command
    filename = filename.gsub(/([();:!?'`])/, 'XXSLASHXX\1')
    filename = filename.gsub(/XXSLASHXX/, "\\")

    begin
      case mode
      when "r"
        unless File.exists? filename
          raise "catchme"
        end
        return IO.popen("gunzip -c #{filename}")
      when "w"
        return IO.popen("gzip > #{filename}", "w")
      when "a"
        return IO.popen("gzip >> #{filename}", "w")
      else
        $stderr.puts "FileZipped error: only modes r, w, a are implemented. I got: #{mode}."
        exit 1
      end
    rescue
      raise "Error opening file #{filename}."
    end
  end
end
