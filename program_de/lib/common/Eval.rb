# Eval
# Katrin Erk May 05
#
# Evaluate classification results
# abstract class, has to be instantiated
# to something that can read in 
# task-specific input data
#
# the Eval class provides access methods to all the
# individual evaluation results and allows for a flag that
# suppresses evaluation output to a file

require "StandardPkgExtensions"

class Eval

  # prec_group_class, rec_group_class, f_group_class: 
  # values for each group/class pair
  # hashes "group class"(string) => score(float)
  attr_reader :prec_group_class, :rec_group_class, :f_group_class

  # accuracy_group:
  # micro-averaged values for each group
  # hash group(string) => score(float)
  attr_reader :accuracy_group

  # prec, rec, f, accuracy: float
  # micro-averaged overall values
  attr_reader :prec, :rec, :f, :accuracy

  ###
  # new
  # 
  # outfilename = name of file to print results to.
  #  nil: print_evaluation_result() will not do anything
  #
  # logfilename: name of file to print instance-wise results to
  #  nil: no logfile output
  #
  # consider_only_one_class:
  #  compute and print evaluation for only one of the class labels,
  #  the one given as this argument.
  #  In this case, overall precision/recall/f-score
  #  is available instead of just accuracy, and 
  #  no group-wise evaluation is done.
  #  nil: consider all classes.
  def initialize(outfilename = nil, 
		 logfilename = nil, # string: 
                 consider_only_one_class = nil) # string/nil: evaluate only one class?

    # print logfile containing
    # results for every single instance?
    if logfilename
      @print_log = true
      @logfilename = logfilename
    else
      @print_log = false
    end
    @outfilename = outfilename
    @consider_only_one_class = consider_only_one_class

    ###
    # initialize object data:
    #
    # num_assigned, num_truepos, num_gold:
    # hashes: [group class] (string*string) => value(integer):  number of times that...
    #                num_assigned: ...this "group class" pair has been 
    #                              assigned by the classifier
    #                num_gold: ... this "group class" pair has been
    #                          annotated in the gold standard
    #                num_truepos:...this "group class" pair has been
    #                            assigned correctly by the classifier
    @num_assigned = Hash.new(0)
    @num_truepos = Hash.new(0)
    @num_gold = Hash.new(0)

    # num_instances:
    # hash: group(string) -> value(integer): number of instances
    #                                for the given group
    @num_instances = Hash.new(0)

    # precision, recall, f-score:
    # for the format of these, see above
    @prec_group_class = Hash.new(0.0)
    @rec_group_class = Hash.new(0.0)
    @f_group_class = Hash.new(0.0)
    
    @accuracy_group = Hash.new(0.0)
    
    @prec = @rec = @f = @accuracy = 0.0
  end
  
  ###
  # compute
  #
  # do the evaluation
  def compute(printme = true) # boolean: print evaluation results to file?
    
    start_printlog()

    # hash: group => value(integer): number of true positives for a group
    num_truepos_group = Hash.new
    # integers: overall assigned/gold/truepos/instances
    num_assigned_all = 0
    num_gold_all = 0
    num_truepos_all = 0
    num_instances_all = 0

    ###
    # iterate through all training/test file pairs,
    # record correct/incorrect assignments
    each_group { |group|

      # read gold file and classifier output file in parallel
      each_instance(group) { |goldclass, assigned_class|

        # make sure that there are no spaces in the group name:
        # later on we assume that by doing "group class".split()
        # we can recover the group and the class, which won't work
        # in case the group name contains spaces
        mygroup = group.gsub(/ /, "_")

	print_log(mygroup + " gold: " + goldclass.to_s + " " + "assigned: " + assigned_class.to_s)

        # record instance
        @num_instances[mygroup] += 1
	
	# record gold standard class
        if goldclass and not(goldclass.empty?) and goldclass != "-"
          @num_gold[[mygroup, goldclass]] += 1
        end
	
	# record assigned classes (if present)
	if assigned_class and not(assigned_class.empty?) and assigned_class != "-"
	  # some class has been assigned:
	  # record it
	  @num_assigned[[mygroup, assigned_class]] += 1
	end

	# is the assigned class included in the list of gold standard classes?
	# then count this as a match
	if goldclass == assigned_class
	  # gold file class matches assigned class
	  @num_truepos[[mygroup, assigned_class]] += 1

	  print_log(" => correct\n")

	elsif assigned_class.nil? or assigned_class.empty? or assigned_class == "-"
	  print_log(" => unassigned\n")
	  
	else
	  print_log(" => incorrect\n")
	end
      } # each instance for this group 
    } # all groups


    ####
    # compute precision, recall, f-score

    # map each group to its classes.
    # groups: array of strings
    # group_classes: hash group(string) -> array of classes(strings)
    #  if @consider_only_one_class has been set, only that class will be listed
    groups = @num_gold.keys.map { |group, tclass| group }.uniq.sort
    group_classes = Hash.new

    # for all group/class pairs occurring either in the gold file or
    # the classifier output file: record it in the group_classes hash
    (@num_gold.keys.concat @num_assigned.keys).each { |group, tclass|
      if group_classes[group].nil?
	group_classes[group] = Array.new
      end
      if @consider_only_one_class and 
          tclass != @consider_only_one_class
        # we are computing results for only one target class,
        # and this is not it
        next
      end
      if tclass 
        group_classes[group] << tclass
      end
    }
    group_classes.each_key { |group|
      group_classes[group] = group_classes[group].uniq.sort
    }


    # precision, recall, f for each group/class pair
    groups.each { |group|
      if group_classes[group].nil?
	next
      end

      # iterate through all classes of the group
      group_classes[group].each { |tclass|
	
        key = [group, tclass]
	
	# compute precision, recall, f-score
	@prec_group_class[key], @rec_group_class[key], @f_group_class[key] = 
	  prec_rec_f(@num_assigned[key], @num_gold[key], @num_truepos[key])
      }
    }
    
    
    # micro-averaged accuracy for each group 
    if @consider_only_one_class
      # we are computing results for only one target class,
      # so precision/recall/f-score group-wise would be
      # exactly the same as group+class-wise.
    else
      groups.each { |group|
        # sum true positives over all target classes of the group
        num_truepos_group[group] = @num_truepos.keys.big_sum(0) { |othergroup, tclass|
          if othergroup == group
            @num_truepos[[othergroup, tclass]]
          else
            0
          end
        }

        @accuracy_group[group] = accuracy(num_truepos_group[group], @num_instances[group])
      }
    end
    

    # overall values:
    if @consider_only_one_class
      # we are computing results for only one target class,
      # so overall precision/recall/f-score (micro-average) make sense
      
      # compute precision, recall, f-score, micro-averaged
      # but only include the target class we are interested in 
      num_assigned_all, num_gold_all, num_truepos_all = [@num_assigned, @num_gold, @num_truepos].map { |hash|
        hash.keys.big_sum(0) { |group, tclass| 
          if tclass == @consider_only_one_class
            hash[[group, tclass]] 
          else
            0
          end
        }
      }
      
      @prec, @rec, @f = prec_rec_f(num_assigned_all, num_gold_all, num_truepos_all)

      # stderr output of global results
      $stderr.print "Overall result: prec: ", sprintf("%.4f", @prec)
      $stderr.print "  rec: ", sprintf("%.4f", @rec)
      $stderr.print "  f: ",  sprintf("%.4f", @f), "\n"

    else
      # we are computing results for all classes,
      # so use accuracy instead of precision/recall/f-score
      num_truepos_all, num_instances_all = [@num_truepos, @num_instances].map { |hash|
        hash.keys.big_sum(0) { |key| hash[key] }
      }
      @accuracy = accuracy(num_truepos_all, num_instances_all)
      # stderr output of global results
      $stderr.print "Overall result: accuracy ", sprintf("%.4f", @accuracy), "\n"
    end

    ###
    # print precision, recall, f-score to file
    # (optional)
    if printme
      print_evaluation_result(groups, group_classes, num_truepos_group, num_instances_all, num_assigned_all, num_gold_all, num_truepos_all)
    end

    end_printlog()
  end

  #####
  protected


  ###
  # inject_gold_counts
  #
  # deal with instances that failed preprocessing:
  # add more gold labels that occur in the missing instances
  # these are added to @num_gold
  # so they lower recall.
  def inject_gold_counts(group, tclass, count)
    @num_gold[group + " " + tclass] += count
  end

  ###
  # print log? if so, start logfile
  def start_printlog()
    if @print_log
      begin
	@logfile = File.new(@logfilename, "w")
	$stderr.puts "Writing evaluation log to " + @logfilename
      rescue
	raise "Couldn't write to eval logfile"
      end
    else
      @logfile = nil
    end

  end

  ###
  # print log? if so, end logfile
  def end_printlog()
    if @print_log
      @logfile.close()
    end
  end

  ###
  # print log? If so, print this string to the logfile
  # (no newline added)
  def print_log(string) # string to be printed
    if @logfile
      @logfile.print string
    end
  end

  ###
  # each_group
  #
  # yield each group name in turn
  def each_group()
    raise "Abstract, please instantiate"
  end

  ###
  # each_instance
  #
  # given a group name, yield each instance of this group in turn,
  # or rather: yield pairs [gold_class(string), assigned_class(string)]
  def each_instance(group) # string: group name
    raise "Abstract, please instantiate"
  end

  ###
  # print_evaluation_result
  #
  # print out all info, sense-specific, lemma-specific and overall,
  # micro- and macro-averaged,
  # to a file
  def print_evaluation_result(groups,          # array:string: group names
                              group_classes,   # hash: group(string) => target classes (array:string)
                              num_truepos_group, # hash: group(string) => num true positives(integer)
                              num_instances_all, num_assigned_all, num_gold_all, num_truepos_all) # integers
    if @outfilename.nil?
      $stderr.puts "Warning: Can't print evaluation results, got not outfile name."
      return 
    end

    begin
      outfile = File.new(@outfilename, "w")
    rescue 
      raise "Couldn't write to eval file " + @outfilename
    end

    
    # print out precision, recall, f-score for each group/class pair
    outfile.puts "-----------------------------"
    outfile.puts "Evaluation per group/target class pair"
    outfile.puts "-----------------------------"
    
    # iterate through all groups
    groups.each { |group|
      if group_classes[group].nil?
	next
      end

      outfile.puts "=============="
      outfile.puts group

      
      # iterate through all classes of the group
      group_classes[group].each { |tclass|
	
	key = [group, tclass]
	
	outfile.print tclass, "\t", "prec: ", sprintf("%.4f", @prec_group_class[key])
        outfile.print " (", @num_truepos[key], "/", @num_assigned[key], ")"

	outfile.print "\trec: ", sprintf("%.4f", @rec_group_class[key])
        outfile.print " (", @num_truepos[key], "/", @num_gold[key], ")"

	outfile.print "\tfscore: ", sprintf("%.4f", @f_group_class[key]), "\n"
      }
    }
    
    
    # print out evaluation for each group
    unless @consider_only_one_class
      outfile.puts
      outfile.puts "-----------------------------"
      outfile.puts "Evaluation per group"
      outfile.puts "-----------------------------"
    
      # iterate through all groups
      groups.each { |group|

        # micro-averaged accuracy
        outfile.print group, "\t", "accuracy: ", sprintf("%.4f", @accuracy_group[group]), 
        " (" , num_truepos_group[group], "/", @num_instances[group], ")\n"
      }
    end
    
    # print out overall evaluation
    outfile.puts
    outfile.puts "-----------------------------"
    outfile.puts "Overall evaluation"
    outfile.puts "-----------------------------"
    
    if @consider_only_one_class

      # micro average: precision, recall, f-score
      outfile.print "prec: ", sprintf("%.4f", @prec)
      outfile.print " (", num_truepos_all, "/", num_assigned_all, ")"

      outfile.print "\trec: ",  sprintf("%.4f", @rec)
      outfile.print " (", num_truepos_all, "/", num_gold_all, ")"

      outfile.print "\tfscore: ", sprintf("%.4f", @f), "\n"
      
    else

      # overall accuracy
      outfile.print "accuracy: ", sprintf("%.4f", @accuracy)
      outfile.print " (", num_truepos_all, "/", num_instances_all, ")\n"
    end
    outfile.flush()
  end

  ###
  # method prec_rec_f
  # assigned, gold, truepos: counts(integers)
  #
  # compute precision, recall, f-score:
  #
  # precision: true positives / assigned positives
  # recall:    true positives / gold positives
  # f-score:  2*precision*recall / (precision + recall)
  # 
  # return: precision, recall, f-score as floats
  def prec_rec_f(assigned, gold, truepos)
    # precision
    precision = truepos.to_f / assigned.to_f
    if precision.nan?
      precision = 0.0
    end

    # recall
    recall = truepos.to_f / gold.to_f
    if recall.nan?
      recall = 0.0
    end

    # fscore
    fscore = (2 * precision * recall) / (precision + recall)
    if fscore.nan?
      fscore = 0.0
    end

    return [precision, recall, fscore]
  end
  
  ###
  # accuracy:
  #
  # accuracy = true positives / instances
  #
  # returns: accuracy, a float
  def accuracy(truepos, num_inst)
    acc = truepos.to_f / num_inst.to_f
    if acc.nan?
      return 0.0
    else
      return acc
    end
  end
end
