##
# RosyTask
# KE, SP April 05
#
# this is the abstract class that describes the interface for
# the task classes of Rosy.
#
# all task classes should have a perform() method that actually
# performs the task.

class RosyTask
  def initialize
    raise "Shouldn't be here! I'm an abstract class"
  end

  def perform
    raise "Should be overwritten by the inheriting class!"
  end
end
