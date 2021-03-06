module Shalmaneser
  module Rosy
    class RosyError < StandardError
      # @param [String] msg A custom message for this exception.
      # @param [Exception] nested_exception An external exception
      #   which is reused to provide more information.
      def initialize(msg = nil, nested_exception = nil)
        if nested_exception
          msg = "#{nested_exception.class}: #{nested_exception.message}\n#{msg}" << nested_exception.backtrace.join("\n")
        end
        super(msg)
      end
    end
  end
end
