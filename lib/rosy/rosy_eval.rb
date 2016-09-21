require_relative 'failed_parses'

module Shalmaneser
  module Rosy
    #######################################################################
    # This class is a subclass of the general evaluation class
    # Eval, which makes evaluation results readable via
    # readable object variables
    #
    # step: can be argrec, arglab, onestep, as usual, but also
    #       - "all":
    #          evaluate argrec and arglab together.
    #          When argrec == NONE, use the argrec value, else use the arglab value
    #       - "prune":
    #          evaluate the pruning column as if it were an argrec assignment
    #
    # When step == argrec or prune, evaluate _only_ the target class FE
    # Otherwise, evaluate all target classes
    class RosyEval < Eval
      def initialize(exp,      # RosyConfigData object: experiment file
                     ttt_obj,  # RosyTrainingTestTable object
                     step,     # string: argrec, arglab, onestep, all, prune
                     splitID,  # string: splitlog ID, or nil
                     testID,   # string: test ID, or nil
                     outfilename, # string: name of file to print output to
                     logfilename, # string: name of file to print eval log to (may be nil)
                     dont_adjoin_frprep_exp) # string: if non-nil, don't re-adjoin frprep experiment obj
        @exp = exp
        @step = step

        if outfilename
          $stderr.puts "Rosy evaluation: printing results to " + outfilename
        end
        if logfilename
          $stderr.puts "and printing an evaluation log to " + logfilename
        end

        ##
        # add preprocessing information to the experiment file object
        unless dont_adjoin_frprep_exp
          if splitID
            # use split data
            preproc_expname = @exp.get("preproc_descr_file_train")
          else
            # use test data
            preproc_expname = @exp.get("preproc_descr_file_test")
          end
          if not(preproc_expname)
            $stderr.puts "Please set the name of the preprocessing exp. file name"
            $stderr.puts "in the experiment file."
            exit 1
          elsif not(File.readable?(preproc_expname))
            $stderr.puts "Error in the experiment file:"
            $stderr.puts "Parameter preproc_descr_file_train has to be a readable file."
            exit 1
          end
          preproc_exp = ::Shalmaneser::Configuration::FrappeConfigData.new(preproc_expname)
          @exp.adjoin(preproc_exp)
        end

        ##
        # evaluate which labels?
        if ["argrec", "prune"].include? @step
          # evaluate only the label "FE"
          super(outfilename, logfilename, "FE")
        else
          # evaluate all target classes
          super(outfilename, logfilename)
        end

        ##
        # what are classifier columns?
        case @step
        when "all"
          # read one argrec and one arglab classifier run column
          @classif_column_argrec = ttt_obj.existing_runlog("argrec", "test", testID,splitID)
          @classif_column_arglab = ttt_obj.existing_runlog("arglab", "test", testID,splitID)
          @columns = ["gold", @classif_column_argrec, @classif_column_arglab]

          if @classif_column_argrec.nil? or @classif_column_arglab.nil?
            # no run found for the given specifications
            $stderr.puts "Couldn't determine the run to evaluate."
            $stderr.puts "There were either none or too many possible runs given your specification.\n"
            $stderr.puts "Here is a list of all runs the system knows for this experiment ID:\n\n"
            $stderr.puts ttt_obj.runlog_to_s("test", testID, splitID)
            exit 1
          end

        when "prune"
          # read pruning column, evaluate as a kind of argrec assignment
          unless Pruning.prune?(@exp)
            raise "Error: Pruning evaluation without pruning column. Skipping."
          end
          @classif_column = Pruning.colname(@exp)
          @columns = ["gold", @classif_column]

        else
          # read the classifier run column for the current step
          @classif_column = ttt_obj.existing_runlog(@step, "test", testID,splitID)
          @columns = ["gold", @classif_column]

          if @classif_column.nil?
            # no run found for the given specifications
            $stderr.puts "Couldn't determine the run to evaluate."
            $stderr.puts "There were either none or too many possible runs given your specification.\n"
            $stderr.puts "Here is a list of all runs the system knows for this experiment ID:\n\n"
            $stderr.puts ttt_obj.runlog_to_s("test", testID, splitID)
            exit 1
          end
        end

        ##
        # make object for iterating through groups and making views
        case @step
        when "all"
          # all: no step in particular
          @iterator = Iterator.new(ttt_obj, exp, "test",
                                       "step" => nil,
                                       "testID" => testID,
                                       "splitID" => splitID,
                                       "xwise" => "frame")
        when "prune"
          # prune: use argrec
          @iterator = Iterator.new(ttt_obj, exp, "test",
                                       "step" => "argrec",
                                       "testID" => testID,
                                       "splitID" => splitID)

        else
          # use the given step
          @iterator = Iterator.new(ttt_obj, exp, "test",
                                       "step" => @step,
                                       "testID" => testID,
                                       "splitID" => splitID)
        end

        ##
        # xwise
        if @step == "all"
          # argrec and arglab may have different xwises,
          # which would create trouble.
          # just use "frame" instead
          @xwise = ["frame"]
        else
          # evaluate as you have trained and tested
          @xwise = @iterator.get_xwise_column_names
        end

        ##
        # split? then include FE labels from unparsed sentences
        # in count of gold labels
        if splitID
          # get a FailedParses object for this split
          @failed_parses_split = FailedParses.new
          fp_filename = File.new_filename(@exp.instantiate("rosy_dir",
                                                           "exp_ID" => @exp.get("experiment_ID")),
                                          @exp.instantiate("failed_file",
                                                           "exp_ID" => @exp.get("experiment_ID"),
                                                           "split_ID" => splitID,
                                                           "dataset" => "test"))
          @failed_parses_split.load(fp_filename)
        end

        # announce the task
        $stderr.puts "---------"
        $stderr.print "Rosy experiment #{@exp.get("experiment_ID")}: Evaluating "
        if splitID
          $stderr.puts "on split dataset #{splitID}"
        else
          $stderr.puts "on test dataset #{testID}"
        end
        $stderr.puts "---------"
      end

      ###
      protected

      ###
      # each_group
      #
      # yield each group name in turn
      def each_group

        @view = nil

        # for the sake of the failed parses module:
        # it can split the failed parses by frame, target and target_pos,
        # but if our "xwise" splits the data along any further columns,
        # the failed parses module cannot know how to split up its failed parses.
        # so see whether we've got any column names besides the three named above
        # in our xwise,
        # and if so, count the groups and split the failed parses evenly between them
        normal_xwise_cols = ["frame", "target", "target_pos"] & @xwise
        extra_xwise_cols = @xwise - normal_xwise_cols

        # num_groups_for_normalxwise: hash: normal_xwise_values(string) -> num. of
        #  groups with these normal xwise values(integer)
        # where the key normal_xwise_values is a conjunction of
        # strings <col_name>=<value> joined by commas,
        # and the column names are in alphabetical order
        num_groups_for_normalxwise = Hash.new(0)

        unless extra_xwise_cols.empty?
          # we do have extra columns

          # for each value sequence for normal_xwise_cols: find out how many values
          # of extra xwise col.s there are
          @iterator.each_group { |group_descr_hash, group_name|

            # make the hash key
            key = normal_xwise_cols.sort.map { |col_name|
              col_name + "=" + group_descr_hash[col_name]
            }.join(",")

            # record one occurrence of this hash key
            num_groups_for_normalxwise[key] += 1
          }
        end

        @iterator.each_group { |group_descr_hash, group_name|

          if @exp.get("verbose")
            $stderr.puts group_name
          end

          # construct view for the current group
          @view = @iterator.get_a_view_for_current_group(@columns)

          ##
          # get counts of FE labels from unparsed sentences:

          # first take apart the group label to find
          # the frame name, target name, target POS name in this group
          # (all but one may be nil)
          frame = target = target_pos = nil

          # get a description of this group, array of pairs [column name, value]
          # where column name is the name of one database column
          @xwise.interleave(group_name.split).each { |col_name, col_value|
            case col_name
            when "frame"
              frame = col_value
            when "target"
              target = col_value
            when "target_pos"
              target_pos = col_value
            else
              # additional database columns: handled below
            end
          }

          # do we have additional column names in "xwise", besides 'frame', 'target', 'target_pos'?
          if extra_xwise_cols.empty?
            split_between_groups = 1
          else
            key = normal_xwise_cols.sort.map { |col_name|
              col_name + "=" + group_descr_hash[col_name]
            }.join(",")
            split_between_groups = num_groups_for_normalxwise[key]

            # sanity check
            if split_between_groups == 0
              raise "shouldn't be here"
            end
          end

          # failed_fes returns: hash that maps FE names [String] onto numbers of failed FEs [Int]
          if @failed_parses_split
            @failed_parses_split.failed_fes(frame, target, target_pos).each_pair { |fe, count|
              # add this number of gold labels we failed to find
              # to the number of gold labels that Eval counts

              # if argrec, map all non-NONE FEs to "FE"
              if @step == "argrec" and fe != @exp.get("noval")
                fe = "FE"
              end
              inject_gold_counts(group_name, fe, (count.to_f / split_between_groups.to_f).round)
            }
          end

          # yield the name of the group to the Eval object for evaluation
          yield group_name
          @view.close
        }
      end

      ###
      # each_instance
      #
      # given a group name, yield each instance of this group in turn,
      # or rather: yield pairs [gold_class(string), assigned_class(string)]
      #
      # this method depends on each_group() having been called before and
      # having initialized @view to the right view object
      def each_instance(group) # string: group name
        case @step
        when "all"
          # step "all":
          # if the argrec label is "NONE", use that as the assigned label.
          # else use the arglab-label
          @view.each_hash { |row|
            if row[@classif_column_argrec] == @exp.get("noval")
              yield [ row["gold"], row[@classif_column_argrec] ]
            else
              yield [ row["gold"], row[@classif_column_arglab] ]
            end
          }

        when "prune"
          # step "prune":
          # if the pruning column has entry 1, regard as assignment "FE",
          # else regard as assignment "NONE".
          @view.each_hash { |row|
            if row[@classif_column] == "1"
              yield [ row["gold"], "FE" ]
            else
              yield [ row["gold"], @exp.get("noval") ]
            end
          }

        else
          # argrec, arglab, onestep:
          # just yield pairs [goldlabel, classif_column_label]
          # as given in the view

          @view.each_hash { |row|
            yield [row["gold"], row[@classif_column]]
          }
        end
      end
    end
  end
end
