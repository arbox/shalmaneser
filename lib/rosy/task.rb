module Shalmaneser
  module Rosy
    ##
    # RosyTask
    # KE, SP April 05
    #
    # this is the abstract class that describes the interface for
    # the task classes of Rosy.
    #
    # all task classes should have a perform() method that actually
    # performs the task.
    # @abstract
    # @todo AB: [2016-09-20 Tue]
    #       Do we actually need this class?
    class Task
      # @abstract
      def initialize
        raise NotImplementedError
      end
      # @abstract
      def perform
        raise NotImplementedError
      end
    end
  end
end
