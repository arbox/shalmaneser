# TabFormat.rb
# Katrin Erk, Jan 2004
#
# classes to be used with tabular format text files.
# originally CoNLL2.rb
# Original: Katrin Erk, Jan 2004 for CoNLL '04 data
# Rewrite: Sebastian Pado, Mar 2004 for Gemmas FrameNet data (no NEs etc.)

# Extensions SP Jun/Jul 04 
# renamed GemmaCorpus to FNTabFormat

# partial rewrite SP 250804: made things cleaner & leaner: no RawFormat, for example

# sp 04/05: add a "frame" column to FNTabFormat
#
# Substantial changes KE 12/06:
# variable number of columns to accommodate more than one frame per sentence

#################################################
# class for reading a file
# containing data in tabular

require "tempfile"

require "frprep/ISO-8859-1"
require "frprep/ruby_class_extensions"

#######################
# This function takes a variable number of arguments and
# returns them as an array
# Idea: make formulation of tab format entries easier to read,
# enclose variable arguments in a repeat() call,
# which immediately gets transformed into a list
def repeat(*args)
  return args
end

#######################
class TabFormatFile
  
  
  #######
  # initialize:
  # open files for reading. 
  #
  # fp is a list of pairs [filename, format]
  # where format is a list of strings that will be used
  # to address columns of the file, the 1st string for the 1st column
  #
  # format may contain _one_ entry that is an array (or a call to repeat())
  # e.g.:
  # ["word", "pos", "lemma", repeat("frame", "target", "gf", "pt")]
  def initialize(fp)
    # open files
    @files = Array.new
    @patterns = Array.new
    @no_of_read_lines = 0
    fp.each_index { |ix|
      if ix.modulo(2) == 0
	# filename
	begin
	  @files << File.new(fp[ix])
	rescue
	  raise 'Sorry, could not read input file ' + fp[ix] + "\n"
	end
      else
	# pattern
	@patterns += fp[ix]
      end
    }

    @my_sentence_class = TabFormatSentence
  end
  
  ########
  # each_sentence:
  # yield each sentence of the files in turn.
  # sentences are expected to be separated
  # by a line containing nothing but whitespace.
  # the last sentence may or may not be followed by
  # an empty line.
  # each_sentence ends when EOF is encountered on the first file.
  # it expects all the other files to be the same length
  # (in terms of number of lines) as the first file.
  # each sentence is returned in the form of an
  # array of TabFormatSentence sentences.
  
  def each_sentence
    unless @read_completely
      sentence = @my_sentence_class.new(@patterns)
      begin
	lines = Array.new
	while true do
	  line = ""
	  linearray = Array.new
	  @files.each {|f|
	    linearray << f.readline().chomp()
	  }	
          # STDERR.puts linearray
	  @no_of_read_lines += 1
	  if linearray.detect{|x| x.strip == ""}
	    if linearray.detect {|x| x.strip != ""}
	      STDERR.puts "Error: Mismatching empty lines! <from lib/frprep>" 
	      exit(1)
	    else
	      # sentence finished. yield it and start a new one
	      unless sentence.empty?
		yield sentence
	      end
	      sentence = @my_sentence_class.new(@patterns)
            end
	    # read an empty line in each of the other files
	    
	  else
	    # sentence not yet finished.
	    # add this line to it
	    sentence.add_line(linearray.join("\t"))
	  end
	end
      rescue EOFError
	unless sentence.empty?
	  # maybe we haven't yielded the last sentence yet.
	  yield sentence
	end
	@read_completely = true
      end
    end
  end

end

#################################################
# class for keeping one line,
# parsed.
# The line is kept as follows:
# - normal features: in a hash @f mapping feature names to values
# - features of the repeated group: in an array @r of
#   TabFormatNamedArgs objects, one per group
#
# each feature of the line is available by name
# via the method "get".
# Additional features (from other input files) can be
# added to the TabFormatNamedArgs object via the method
# add_feature
#
# methods:
#
# new: initialize.
#    values: array of strings
#    features:  how to access the strings by name
#              'features' is an array of strings
#              later the i-th feature will be used to access
#              the i-th value,
#              except for repeated groups
#
# get: returns one feature by its name
#    name: a string
#
# add_feature: add another feature to this object,
#              which can be accessed via "get"
#    name: name for the new feature, should be distinct
#          from the ones already used in new()
#    feature: a string, the value of the feature
##

class TabFormatNamedArgs
  ############
  def initialize(values, features, group = nil)
    @f = Hash.new
    @r = Array.new
    @group = group

    # record the feature names, give special attention to a group
    # if we have one
    @group_feature_names = nil
    @feature_names = features.map { |feature| 
      if feature.instance_of? Array
	# found a group
	@group_feature_names = feature
	"GROUP"
      else
	feature
      end
    }

    if @feature_names.count("GROUP") > 1
      $stderr.puts "More than one group in feature set:" + features.join(" ")
      raise "Cannot handle this."
    end

    # group_index: position of group in overall feature list
    group_index = @feature_names.index("GROUP")
    unless group_index
      group_index = @feature_names.length()
    end
    num_features_after_group = [0, 
      (@feature_names.length() - 1) - group_index].max()
    index_after_groups = values.length() - num_features_after_group


    # features before group: put feature/value pairs in @f hash
    0.upto(group_index - 1) { |i|
      @f[features[i]] = values[i]
    }
    # group: store each group in @r hash
    if @group_feature_names
      # for (group_start = group_index; group_start < index_after_groups;
      #      group_start += @group_feature_names.length())
      group_no = 0
      group_index.step(index_after_groups - 1, 
		       @group_feature_names.length()) { |group_start|
	@r << TabFormatNamedArgs.new(values.slice(group_start, 
						  @group_feature_names.length()),
				     @group_feature_names,
                                     group_no)
        group_no += 1
      }
    end

    # features after group: put feature/value pairs in @f hash
    feature_index = group_index + 1
    index_after_groups.upto(values.length() - 1) { |i|
      @f[features[feature_index]] = values[i]
      feature_index += 1
    }
  end

  ############
  # return feature/value pairs as a tab format line,
  # order of features as given in the 'features' list
  # Features not set in the hash: their entry will be "-"
  #
  # If the feature list includes a group,
  # assume zero entries for that group
  def TabFormatNamedArgs.format_str(hash,     # hash: feature -> value
				    features) # feature list, as for new()
    if features.nil?
      return ""
    end

    # sanity check: does the hash contain keys that are not in the feature list?
    hash.keys().reject { |f| features.include? f }.each { |bad_feature|
      $stderr.puts "Error: unknown feature #{bad_feature} in format_str: ignoring."
    }

    return features.select { |f|
      # remove the group feature, if it's there
      not(f.instance_of? Array)
    }.map { |feature|
      if hash[feature]
	hash[feature]
      else
	"-"
      end
    }.join("\t")
  end


  #############
  def add_feature(name, feature)
    if @f.has_key? name
      raise "Trying to add a feature twice: "+name
    end

    @f[name] = feature
  end

  #############
  # get feature value, identified by feature name
  # return: feature value as string
  def get(name)
    if (retv = get_nongroup(name))
      return retv
    else
      return get_from_group(name, @group)
    end
  end

  #############
  def set(name, feature)
    @f[name] = feature
  end

  #############
  def num_groups()
    return @r.length()
  end

  #############
  # return line as string, entries connected by tab,
  # in the order that the entries were in originally
  def to_s()
    return @feature_names.map { |feature|
      case feature
      when "GROUP"
	@r.map { |group_obj| group_obj.to_s }.join("\t")
      else
	@f[feature]
      end
    }.join("\t")
  end

  protected

  # get feature, non-group
  # return: feature value (string)
  def get_nongroup(feature)
    return @f[feature]
  end

  # get feature from one of the groups
  # return: feature value (string)
  def get_from_group(name, group_no)
    if not(group_no) or group_no >= @r.length()
      # no group with that number
      return nil
    else
      return @r[group_no].get_nongroup(name)
    end
  end
end


#################################################
# class for keeping and yielding one sentence
# in tabular format
class TabFormatSentence
  ############
  # initialize:
  # the sentence will be stored one word (plus additional info 
  # for that word) per line. Each line will be stored in a cell of 
  # the array @lines. the 'initialize' method starts with an empty 
  # array of lines.
  def initialize(pattern)
    @lines = Array.new
    @pattern = pattern

    # this is just for inheritance; FNTabFormatSentence will need this
    @group_no = nil
  end

  #####
  # length: number of words in the sentence
  def length
    return @lines.length
  end
  
  ################3
  # add_line:
  # add one entry to the @lines array, i.e. information for one word 
  # of the sentence.
  def add_line(line)
    @lines << line
  end
  
  ###################
  # empty?:
  # returns true if there are currently no lines stored in this
  # TabFormatSentence object
  # else false
  def empty?
    return @lines.empty?
  end
  
  ######################
  # empty!:
  # discards all entries to the @lines array,
  # i.e. empties this TabFormatSentence object of all
  # data
  def empty!
    @lines.clear
  end
  
  #####################
  # each_line:
  # yields each line of the sentence
  # as a string
  def each_line
    @lines.each { |l| yield l }
  end
  
  ######################
  # each_line_parsed:
  # yields each line of the sentence
  # broken up as follows:
  # the line is expected to contain 6 or more pieces of
  # information, separated by whitespace.
  # - the word
  # - the part of speech info for the word
  # - syntax for roles (not to be used)
  # - target (or -) 
  # - gramm. function for roles (not to be used)
  # - one column with role annotation
  # 
  # All pieces are yielded as strings, except for the argument columns, which
  # are yielded as an array of strings.
  def each_line_parsed
    lineno = 0
    f = nil
    @lines.each { |l|
      f = TabFormatNamedArgs.new(l.split("\t"), @pattern, @group_no)
      f.add_feature("lineno", lineno)
      yield f
      lineno += 1
    }
  end
  
  ###
  # read_one_line:
  # return a line of the sentence specified by its number
  def read_one_line(number)
    return(@lines[number])
  end

  ###
  # read_one_line_parsed:
  # like get_line, but the features in the line are returned
  # separately,
  # as in each_line_parsed
  def read_one_line_parsed(number)
    if @lines[number].nil?
      return nil
    else
      f = TabFormatNamedArgs.new(@lines[number].split("\t"), @pattern, @group_no)
      f.add_feature("lineno", number)
      return f
    end
  end

  # set line no of first line of present sentence
  def set_starting_line(n)
    raise "Deprecated"
  end

  # returns line no of first line of present sentence
  def get_starting_line()
    raise "Deprecated"
  end
end

########################################################
# TabFormat files containing everything that's in the FN lexunit files
#
# one target per sentence

class FNTabFormatFile < TabFormatFile

  def initialize(filename,tag_suffix=nil,lemma_suffix=nil)

    corpusname = File.dirname(filename)+"/"+File.basename(filename,".tab")

    filename_label_pairs = [filename,FNTabFormatFile.fntab_format()]
    if lemma_suffix # raise exception if lemmatisation does not esist
      filename_label_pairs.concat [corpusname+lemma_suffix,["lemma"]]
    end
    if tag_suffix # raise exception if tagging does not exist
      filename_label_pairs.concat [corpusname+tag_suffix,["pos"]]
    end
    super(filename_label_pairs)

    @my_sentence_class = FNTabSentence
  end
  

  def FNTabFormatFile.fntab_format()
#    return ["word", "pt", "gf", "role", "target", "frame", "lu_sent_ids"]
    return [ 
      "word", 
      FNTabFormatFile.frametab_format(), 
      "ne", "sent_id" 
    ]
  end

  def FNTabFormatFile.frametab_format()
    return ["pt", "gf", "role", "target", "frame", "stuff"]
  end

  ##########
  # given a hash mapping features to values,
  # format according to fntab_format
  def FNTabFormatFile.format_str(hash)
    return TabFormatNamedArgs.format_str(hash, FNTabFormatFile.fntab_format())
  end
end

############################################
class FNTabSentence < TabFormatSentence

  ####
  # overwrite this to get a feature from
  # a group rather than from the main feature list
  def get_this(l, feature_name)
    return l.get(feature_name)
  end

  ####
  def sanity_check()
    each_line_parsed {|l|
      if l.get("sent_id").nil? 
        raise "Error: corpus file does not conform to FN format."
      else
        return 
      end
    }
  end
  
  ####
  # returns the sentence ID, a string, as set by FrameNet
  def get_sent_id()
    sanity_check
    each_line_parsed {|l|
      return l.get("sent_id")
    }
  end

  ####
  # iterator, yields each frame of the sentence as a FNTabFrame
  # object. They contain the complete sentence, but provide
  # access to exactly one frame of that sentence.
  def each_frame()
    # how many frames? assume that each line has the same
    # number of frames
    num_frames = read_one_line_parsed(0).num_groups()
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
  def markables(use_this_column="role") 
    # returns hash of {index list} -> {markup label}

    sanity_check()
    
    idlist_to_annotation_list = Hash.new
    
    # add entry for the target word
    # idlist_to_annotation_list[get_target_indices()] = "target"
    
    # determine span of each frame element
    # if we find overlapping FEs, we write a warning to STDERR
    # ignore the 2nd label and attempt to "close" the 1st label 

    ids = Array.new
    label = nil

    each_line_parsed { |l|
      
      this_id = get_this(l, "lineno")
      
      # start of FE?
      this_col = get_this(l, use_this_column)
      unless this_col
        $stderr.puts "nil entry #{use_this_column} in line #{this_id} of sent #{get_sent_id()}. Skipping."
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
  def get_frame()
    sanity_check()
    each_line_parsed {|l|
      return l.get("frame")
    }
  end

  ####
  # returns an array of integers: the indices of the target of
  # the frame
  # These are the line numbers, which start counting at 0
  # 
  # a target may span more than one word
  def get_target_indices() 
    sanity_check
    idx = Array.new
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
  def get_target()
    each_line_parsed {|l|
      t = l.get("target")
      unless t == "-"
	return t
      end
    }
  end

  ####
  # get the target POS, according to FrameNet 
  def get_target_fn_pos()
    get_target() =~ /^[^\.]+\.(\w+)$/
    return $1
  end

end
