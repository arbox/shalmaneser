# sp 29 07 04
# "optimise" c4.5 files by replacing all feature values which only
# occur with one label by a new, common value.
#
# two modes of operation:
# optimise <file>                -- optimise file and store optimisations in <file>.opts
# optimise <file> <file.opts>    -- apply optimisation from file.opts to file

class Optimise

  def initialize
    @ready = false
  end

  def init_from_data(infile) # find new optimisation

    STDERR.puts "[Optimise] computing new feature optimisation"

    infile = File.new(infile)
    labels = []
    features = nil
    @replacements = [] # for each feature, store the list of replacements

    # read data from infile into hash and initialise replacements array
    while (line = infile.gets)
      f_l = line.chomp.split(",")

      if features.nil? # first line: initialisation
	features = [] # for each feature: array of feature values from file
	f_l.each_index {|i|
	  features[i] = []
	  @replacements[i] = {}
	}
      end
      labels << f_l.pop
      f_l.each_index {|i|
	features[i] << f_l[i]
      }
    end
    infile.close

    features.each_index {|findex| # traverse all features

      # for each feature *value*, find all label indices

      fvalues = features[findex]

      fval_to_label = {} # record fval -> label mappings
                                  # no label : nil
                                  # one label: <label>
                                  # two labels: false

      fvalues.each_index {|inst_idx|
	label = labels[inst_idx] # current label
	fval = fvalues[inst_idx] # current feature value
	seen_label = fval_to_label[fval] # previously seen label
	if seen_label.nil?
	  fval_to_label[fval] = label
	elsif seen_label and seen_label != label
	  fval_to_label[fval] = false
	end
      } # at the end, all fvals should be mapped to either <label> or false

      # construct new feature value names

      new_fvals = {}
      labels.each {|label|
	new_fvals[label] = "f"+findex.to_s+"_"+label.gsub(/\./,"")
      }

      # record all features values for which we have only seen one label in @replacements

      fval_to_label.each_pair {|fval,label|
	if fval == "[U]"
	  puts "[U]: "+label.to_s+" "+new_fvals[label]
	end
	if label
#	  STDERR.puts "replacement of "+fval+" by "+new_fvals[label]
	  @replacements[findex][fval] = new_fvals[label]
	end
      }

    #   fvalues = features[findex]

#       l_to_v = {} # label -> array of feature values
#       v_to_l = {} # feature value -> array of labels

#       fvalues.each_index {|inst| # traverse all instances
# 	fval = fvalues[inst]
# 	label = labels[inst]


# 	unless v_to_l.key?(fval) # add entry to v_to_l
# 	  v_to_l[fval] = []
#           end
# 	v_to_l[fval] << label

# 	unless l_to_v.key?(label) # add entry to l_to_v
# 	  l_to_v[label] = []
# 	end
# 	l_to_v[label] << fval
#       }

#       l_to_v.each_pair {|label,values|
# 	newvalue = "f"+findex.to_s+"_"+label.gsub(/\./,"")
# 	values.each {|value|
# 	  if v_to_l[value].uniq.length == 1
# 	    @replacements[findex][value] = newvalue
# 	  end
# 	}
#       }
     }
    @ready = true
  end

  def init_from_file(optsfile) # use old optimisation
    optsinfile = File.new(optsfile)
    @replacements = read(optsinfile)
    optsinfile.close
    @ready = true
  end

  def store(outfilename) # store data necessary to recreate optimisation
    unless @ready
      raise "[Optimise] Error: Cannot store un-initialised optimisation"
    end
    outfile = File.new(outfilename,"w")
    @replacements.each_index {|i| # for each feature
      reps = @replacements[i]
      outfile.puts "<"+i.to_s+">"
      reps.each_pair{|old,new|
	outfile.puts [old,new].join("\t")
      }
      outfile.puts "</"+i.to_s+">"
    }
    outfile.close
  end

  def apply(infilename,outfilename)
    unless @ready
      raise "[Optimise] Error: Cannot apply un-initialised optimisation"
    end

    STDERR.puts "[Optimise] applying feature optimisation"

    infile = File.new(infilename)
    outfile = File.new(outfilename,"w")
    features = []
    labels = []


    while (line = infile.gets)
      tokens = line.chomp.split(",")

      unless tokens.length == @replacements.length
	raise "[Optimise] Error: trying to optimise incompatible feature file!\nFile has "+features.length.to_s+" features, and we know replacements for "+@replacements.length.to_s+" features."
      end

      label = tokens.pop
      tokens.each_index {|f_idx|
	fval = tokens[f_idx]
	if @replacements[f_idx].key?(fval)
	  tokens[f_idx] = @replacements[f_idx][fval]
	end
      }
      tokens.push label
      outfile.puts tokens.join(",")
    end
    outfile.close
  end

  private

  def read(infile)
    @replacements = []
    while line = infile.gets
      line.chomp!
      if line =~ /<(\d+)>/
	reps = {}
      elsif line =~ /<\/(\d+)>/
	@replacements[$1.to_i] = reps
      else
	tokens = line.chomp.split("\t")
	reps[tokens[0]] = tokens[1]
      end
    end
    infile.close
  end

  # return recommended filename to store optimisation patterns for basefile
  def Optimise.recommended_filename(basefile)
    return basefile+".optimisations"
  end

end
