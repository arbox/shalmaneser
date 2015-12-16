require_relative 'tab_format_sentence'
# require_relative 'fn_tab_frame'
require "ruby_class_extensions"
############################################
class FNTabSentence < TabFormatSentence
  ####
  # overwrite this to get a feature from
  # a group rather than from the main feature list
  def get_this(l, feature_name)
    l.get(feature_name)
  end

  ####
  def sanity_check
    each_line_parsed { |l|
      if l.get("sent_id").nil?
        raise "Error: corpus file does not conform to FN format."
      else
        return
      end
    }
  end

  ####
  # returns the sentence ID, a string, as set by FrameNet
  def get_sent_id
    sanity_check
    each_line_parsed { |l|
      return l.get("sent_id")
    }
  end

  ####
  # iterator, yields each frame of the sentence as a FNTabFrame
  # object. They contain the complete sentence, but provide
  # access to exactly one frame of that sentence.
  def each_frame
    # how many frames? assume that each line has the same
    # number of frames
    num_frames = read_one_line_parsed(0).num_groups

    0.upto(num_frames - 1) { |frame_no|
      frame_obj = FNTabFrame.new(@pattern, frame_no)
      each_line { |l| frame_obj.add_line(l) }
      yield frame_obj
    }
  end

  ####
  # computes a mapping from word indices to labels on these words
  #
  # returns a hash: index_list(array:integer) -> label(string)
  # An entry il->label means that all the lines whose line
  # numbers are listed in il are labeled with label.
  #
  # Line numbers correspond to words of the sentence. Counting starts at 0.
  #
  # By default, "markables" looks for role labels, i.e. labels in the
  # column "role", but it can also look in another column.
  # To change the default, give the column name as a parameter.
  def markables(use_this_column = "role")
    # returns hash of {index list} -> {markup label}

    sanity_check

    idlist_to_annotation_list = {}

    # add entry for the target word
    # idlist_to_annotation_list[get_target_indices()] = "target"

    # determine span of each frame element
    # if we find overlapping FEs, we write a warning to STDERR
    # ignore the 2nd label and attempt to "close" the 1st label

    ids = []
    label = nil

    each_line_parsed { |l|
      this_id = get_this(l, "lineno")

      # start of FE?
      this_col = get_this(l, use_this_column)
      unless this_col
        $stderr.puts "nil entry #{use_this_column} in line #{this_id} of sent #{get_sent_id}. Skipping."
        next
      end
      this_fe_ann = this_col.split(":")

      case this_fe_ann.length
      when 1 # nothing at all, or a single begin or end
        markup = this_fe_ann.first
        if markup == "-"  or markup == "--" # no change
          if label
            ids << this_id
          end
        elsif markup =~ /^B-(\S+)$/
          if label # are we within a markable right now?
            $stderr.puts "[TabFormat] Warning: Markable "+$1.to_s+" starts while within markable  ", label.to_s
            $stderr.puts "Debug data: Sentence id #{get_sent_id()}, current ID list #{ids.join(" ")}"
          else
            label = $1
            ids << this_id
          end
        elsif markup =~ /^E-(\S+)$/
          if label == $1 # we close the markable we've opened before
            ids << this_id
            # store information
            idlist_to_annotation_list[ids] = label
            # reset memory
            label = nil
            ids = Array.new
          else
            $stderr.puts "[TabFormat] Warning: Markable "+$1.to_s+" closes while within markable "+ label.to_s
            $stderr.puts "Debug data: Sentence id #{get_sent_id()}, current ID list #{ids.join(" ")}"
          end
        else
          $stderr.puts "[TabFormat] Warning: cannot analyse markup "+markup
          $stderr.puts "Debug data: Sentence id #{get_sent_id()}"
        end
      when 2 # this should be a one-word markable
        b_markup = this_fe_ann[0]
        e_markup = this_fe_ann[1]
        if label
          $stderr.puts "[TabFormat] Warning: Finding new markable at word #{this_id} while within markable ", label
          $stderr.puts "Debug data: Sentence id #{get_sent_id()}, current ID list #{ids.join(" ")}"
        else
          if b_markup =~ /^B-(\S+)$/
            b_label = $1
            if e_markup =~ /^E-(\S+)$/
              e_label = $1
              if b_label == e_label
                idlist_to_annotation_list[[this_id]] = b_label
              else
                $stderr.puts "[TabFormat] Warning: Starting markable "+b_label+", closing markable "+e_label
                $stderr.puts "Debug data: Sentence id #{get_sent_id()}, current ID list #{ids.join(" ")}"
              end
            else
              $stderr.puts "[TabFormat] Warning: Unknown end markup "+e_markup
              $stderr.puts "Debug data: Sentence id #{get_sent_id()}, current ID list #{ids.join(" ")}"
            end
          else
            $stderr.puts "[TabFormat] Warning: Unknown start markup "+b_markup
            $stderr.puts "Debug data: Sentence id #{get_sent_id()}, current ID list #{ids.join(" ")}"
          end
        end
      else
        $stderr.puts "Warning: cannot analyse markup with more than two colon-separated parts like "+this_fee_ann.join(":")
        $stderr.puts "Debug data: Sentence id #{get_sent_id()}"
      end
    }

    unless label.nil?
      $stderr.puts "[TabFormat] Warning: Markable ", label, " did not end in sentence."
      $stderr.puts "Debug data: Sentence id #{get_sent_id()}, current ID list #{ids.join(" ")}"
    end

    return idlist_to_annotation_list
  end

  #######
  def to_s
    sanity_check
    array = Array.new
    each_line_parsed {|l|
      array << l.get("word")
    }
    return array.join(" ")
  end

end
