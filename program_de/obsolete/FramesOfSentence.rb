module FramesOfSentence

  def FramesOfSentence.frames_of_sentstring(sent_string)

    frames_IDs = Array.new
    retv = Hash.new

    sent_string.scan(/<frame\s.+?<\/frame>/) { |frame|

      # determine frame name
      unless frame =~ /<frame\s[^>]*?name=['"](.+?)['"]/
	$stderr.puts "Warning: Couldn't determine frame name in:\n"+frame
	next
      end
      name = $1

      # underspecification?
      if frame =~ /<frame\s[^>]*?usp=['"]yes["']/
	usp = true
      else
	usp = false
      end

      # determine syntax node IDs
      ids = Array.new
      frame.scan(/<target[>\s].+?<\/target>/) { |target|
	target.scan(/<fenode\s.+?>/) { |fenode|

	  # determine syntactic node ID
	  unless fenode =~ /idref=['"](.+?)["']/
	    $stderr.puts "Warning: couldn't determine ID ref in:\n" + fenode
	    next
	  end

	  ids << $1
	}

	# remember frame/IDs/usp tuple
      }
      unless ids.nil?
	frames_IDs << [name, ids, usp]
      end
    }

    # handle duplicates
    frames_IDs.each { |frame, ids, usp|
      key = ids.sort.join(" ")
      
      if retv[key].nil?
	# no other frame registered yet for this ID sequence
	retv[key] = [[frame], usp]
      else
	# another frame registed for same ID sequence
	other_frames, other_usp = retv[key]
	if other_frames == [frame] and other_usp == false
	  # exact same frame occurs twice,
	  # probably with different FEs
	  # but never mind, we're only interested in the target
	  # so do nothing
	elsif other_usp == true and usp == true
	  # underspecification --
	  # add current frame to those already present
	  unless other_frames.include? frame
	    other_frames << frame
	  end
	else
	  # something fishy going on
	  # but just treat it like underspecification
	  unless other_frames.include? frame
	    other_frames << frame
	  end
#	  $stderr.puts "Problem with frame assignment. I got:"
#	  $stderr.print "Frame ", other_frames.join(" ")
#	  $stderr.print ", usp=",other_usp, " and\n"
#	  $stderr.print "Frame ", frame, ", usp=", usp, "\n"
#	  $stderr.puts "Skipping."
	end	    
      end
    }

    # remove usp information from retv
    retv.each_key { |key|
      retv[key] = retv[key].first
    }

    return retv
  end

end
