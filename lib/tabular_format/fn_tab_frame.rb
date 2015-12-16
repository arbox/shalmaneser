require_relative 'fn_tab_sentence'
require "ruby_class_extensions"

class FNTabFrame < FNTabSentence
  ############
  # initialize:
  # as parent, except that we also get a frame number
  # such that we can access the features of ``our'' frame
  def initialize(pattern, frameno)
    # by setting @group_no to frameno,
    # we are initializing each TabFormatNamedArgs object
    # in each_line_parsed() or read_one_line_parsed()
    # with the right group number,
    # such that all calls to TabFormatNamedArgs.get()
    # will access the right group.
    super(pattern)
    @group_no = frameno
  end

  # returns the frame introduced by the target word(s)
  # of this frame group, a string
  def get_frame
    sanity_check
    each_line_parsed { |l|
      return l.get("frame")
    }
  end

  ####
  # returns an array of integers: the indices of the target of
  # the frame
  # These are the line numbers, which start counting at 0
  #
  # a target may span more than one word
  def get_target_indices
    sanity_check
    idx = []
    each_line_parsed {|l|
      unless l.get("target") == "-"
        idx << l.get("lineno")
      end
    }

    return idx
  end

  ####
  # returns a string: the target
  # in the case of multiword targets,
  # we find the complete target at all
  # indices, i.e. we can just take the first one we find
  def get_target
    each_line_parsed { |l|
      t = l.get("target")
      unless t == "-"
        return t
      end
    }
  end

  ####
  # get the target POS, according to FrameNet
  def get_target_fn_pos
    get_target =~ /^[^\.]+\.(\w+)$/
    return $1
  end
end
