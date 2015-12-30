# Failed Parses
#
# SP May 05
#
# Administration of information about failed parses;
# - sentence ID
# - frame
# - missed FE markables
#
# this class is pretty much a gloriefied hash table with methods to
# - read FailedParses from a file and to write them to a file
# - access info in a frame-specific way
module Shalmaneser
module Rosy
class FailedParses

  ###
  # initialize
  #
  # nothing much happens here
  def initialize
    @failed_parses = []
  end

  ###
  # register
  #
  # register new failed parse by specifying
  # - its sentence id (any object)
  # - its frame (String)
  # - its FE list (String Array)

  def register(sent_id, # object
               frame,   # string: frame name
               target,  # string?
               target_pos, # string: target POS
               fe_list) # array:string
    if @failed_parses.assoc sent_id
#      $stderr.puts "Error: trying to register sentence id #{sent_id} twice!"
#      $stderr.puts "Skipping second occurrence."
    end
    @failed_parses << [sent_id,frame,target,target_pos,fe_list]
  end

  ###
  # make_split
  #
  # produce a "split" of the failed parses into a train and a test section
  # paramer: train_percentage, Integer between 0 and 100
  #
  # returns an Array with two FailedParses objects, the first for the
  # train data, the second for the test data

  def make_split(train_percentage)
    unless train_percentage.class < Integer and train_percentage >= 0 and train_percentage <= 100
      raise "Need Integer between 0 and 100 as training percentage."
    end
    train_failed = FailedParses.new
    test_failed = FailedParses.new
    @failed_parses.each {|sent_id,frame,target,target_pos,fe_list|
      if rand(100) > train_percentage
        test_failed.register(sent_id,frame,target,target_pos,fe_list)
      else
        train_failed.register(sent_id,frame,target,target_pos,fe_list)
      end
    }
    return [train_failed, test_failed]
  end

  ###
  # Access information
  #
  # failed_sent: number of failed sentences
  # failed_fes:  Hash that maps FE names [String] onto numbers of failed FEs [Int]
  #
  # optional parameters: frame, target, target_pos : if not specified or nil, marginal
  #                      frequencies are counted (sum over all values)


  def failed_sent(frame_spec=nil,target_spec=nil,target_pos_spec=nil)
    counter = 0
    @failed_parses.each {|sent_id,frame,target,target_pos,fe_list|
      if ((frame_spec.nil? or frame_spec == frame) and
	  (target_spec.nil? or target_spec == target) and
	  (target_pos_spec.nil? or target_pos_spec == target_pos))
	counter += 1
      end
    }
    return counter
  end

  def failed_fes(frame_spec=nil,target_spec=nil,target_pos_spec=nil)
    fe_hash = Hash.new(0)
    @failed_parses.each {|sent_id,frame,target,target_pos,fe_list|
      if ((frame_spec.nil? or frame_spec == frame) and
	  (target_spec.nil? or target_spec == target) and
	  (target_pos_spec.nil? or target_pos_spec == target))
	fe_list.each {|fe_label|
	  fe_hash[fe_label] += 1
	}
      end
    }
    return fe_hash
  end


  ###
  # Marshalling:
  #
  # save - save info about failed parses to file
  # load - load info about failed parses from file

  def save(filename)
    io_obj = File.new(filename,"w")
    Marshal.dump(@failed_parses,io_obj)
    io_obj.close
  end

  def load(filename)
    begin
      io_obj = File.new(filename)
      @failed_parses = Marshal.load(io_obj)
      io_obj.close
    rescue
      $stderr.puts "WARNING: couldn't read failed parses file #{filename}."
      $stderr.puts "I'll assume that there are no failed parses."
    end
  end

end
end
end
