# FredParameters
# Katrin Erk, April 05
#
# Frame disambiguation system:
#  test different values for system parameters,
#  construct text and graphical output

# Salsa packages
require "PlotAndREval"

# Fred packages
require "FredConfigData"
require "FredConventions"
require "FredSplit"
require "FredTrain"
require "FredTest"
require "FredEval"

require 'common/EnduserMode'

##########################################

################
# SlideVar:
# keeps a single sliding variable,
# has an iterator that yields each value of the slide as a pair
#  [lhs, rhs] to be passed on to FredConfigData.set_entry()
#
# Initialization with the value of a --slide command line parameter.
# Valid forms:
#
#  feature=<f>:<what>:<start>-<end>:<slide>
#       with f in { context, ngram, syn, grfunc, fe }
#            what in { weight, dist } (dist only available for context)
#            start, end, slide floats represented as strings
#
# <var>:<start>-<end>:<slide>
#       with var in { smoothing_lambda, window_size }
class SlideVar
  attr_reader :var_name

  def initialize(string, # value of --slide parameter
                 exp)    # FredConfigData object

    # keep start and end value and step size for the sliding
    @startval = @endval = @step = @current = 0.0

    # setting experiment file values for each step of the sliding:
    # remember lhs and rhs of what needs to be set.
    # rhs contains a string REPLACEME to be replaced by the current value
    @exp_lhs = ""
    @exp_rhs = ""
    @var_name = ""
    @remove_list_variable_regexp = nil # set non-nil if we need unset_list_entry()

    if string == ""
      # empty slide variable
      return
    end

    if string =~ /^feature=(\w+):(\w+):([\d\.]+)-([\d\.]+):([\d\.]+)$/
      # --slide feature=ngram:weight:0.8-4.0:0.3
      # --slide feature=context:dist:0.7-0.9:0.05

      featurename = $1
      parname = $2
      @startval = $3.to_f
      @endval = $4.to_f
      @step = $5.to_f

      @exp_lhs = "feature"

      if featurename == "context"
        # both weight and dist possible

        case parname
        when "weight"
          @exp_rhs = "#{featurename} REPLACEME #{exp.get_lf("feature", "context", "wtdist")}"
        when "dist"
          @exp_rhs = "#{featurename} #{exp.get_lf("feature", "context", "weight")} REPLACEME"
        else
          raise "Error in argument of --slide: I found a value of neither 'weight' nor 'dist': "+ parname
        end

        if exp.get_lf("feature", "context", "mwedist")
          @exp_rhs << " mwedist"
        end

      else
        # feature name not "context": only weight possible
        unless parname == "weight"
          raise "Error in argument of --slide: can only do 'weight', what I got is "+ parname
        end

        @exp_rhs = "#{featurename} REPLACEME"
      end

      @var_name = "feature #{featurename} #{parname}"
      @remove_list_variable_regexp = Regexp.new("^#{featurename}\s")

    elsif string =~ /^(\w+):([\d\.]+)-([\d\.]+):([\d\.]+)$/
      # --slide window_size:0-4:1
      # --slide smoothing_lambda:0.3-0.9:0.05

      featurename = $1
      case exp.get_type(featurename)
      when "integer"
        @startval = $2.to_i
        @endval = $3.to_i
        @step = $4.to_i
      when "float"
        @startval = $2.to_f
        @endval = $3.to_f
        @step = $4.to_f
      else
        raise "Unslidable variable "+ featurename
      end

      @exp_lhs = featurename
      @exp_rhs = "REPLACEME"
      @var_name = featurename

    else
      # not a valid argument to --slide

      raise "Sorry, could not parse argument of --slide. \nI got: "+ string
    end
  end

  ####
  # iterate through each value of the slide variable (if there is a slide variable)
  # and set it in the experiment file data structure
  #
  # also yield a descriptive text of the current setting
  def each_slide_value(exp) # FredConfigData object

    if empty?
      # no slide variable

      yield [0, ""]
      return

    else
      # the slide variable is nonempty

      @current = @startval

      while @current <= @endval

        if @remove_list_variable_regexp
          # we have a list feature that we first need to unset before setting it
          exp.unset_list_entry(@exp_lhs, @remove_list_variable_regexp)
        end
        exp.set_entry(@exp_lhs, @exp_rhs.sub(/REPLACEME/, @current.to_s))

        yield [@current, @var_name + "=" + @current.to_s]
        @current += @step
      end
    end
  end

  def empty?
    return @exp_lhs.empty?
  end
end

################
# ToggleVar:
# keeps a single toggle variable,
# and has a method that sets this toggle variable to a given value
# in the experiment file data structure.
class ToggleVar
  attr_reader :var_name

  def initialize(string, # part of value of --slide parameter, which has been split at :
                 exp)    # FredConfigData object

    if string =~ /^feature_dim=(\w+)$/
      # feature dimension

      @exp_lhs = "feature_dim"
      @exp_rhs = $1
      @unset_at_false = true # for false, un-set list valued parameter in set_value_to()
      @var_name = "feature_dim #{@exp_rhs}"

      unless ["word", "lemma", "pos", "ne"].include? @exp_rhs
        raise "Unknown feature dimension "+ @exp_rhs
      end

    else
      # normal variable
      unless exp.get_type(string) == "bool"
        raise "Unknown value in --toggle: "+ string
      end

      if ["use_fn_gf", "window_size"].include? string
        raise "Sorry, cannot toggle #{string}, since this variable takes its effect during featurization."
      end

      @exp_lhs = string
      @exp_rhs = "REPLACEME"
      @unset_at_false = false # for false, set parameter to false in set_value_to
      @var_name = @exp_lhs
    end
  end

  ###
  # set the value of my toggle variable to the given boolean
  # in the given experiment file data structure.
  #
  # returns a descriptive text of the current setting
  def set_value_to(boolean, # true, false
                   exp)     # FredConfigData object

    if @unset_at_false and not(boolean)
      exp.unset_list_entry(@exp_lhs, @exp_rhs)
    else
      exp.set_entry(@exp_lhs, @exp_rhs.sub(/REPLACEME/, boolean.to_s))
    end

    return @var_name + "=" + boolean.to_s
  end

end


##########################################
# main class of this package:
# try out different values for system parameters,
# and record the result.
#
# One value can be a slide variable, taking on several numerical values.
# 0 or more values can be toggle variables, taking on the values true and false.
class FredParameters

  #####
  def initialize(exp_obj, # FredConfigData object
		 options) # hash: runtime option name (string) => value(string)


    in_enduser_mode_unavailable()
    @exp = exp_obj

    ##
    # evaluate runtime options:
    # record the slide variable (if any) plus all toggle variables
    @slide = SlideVar.new("", @exp)
    @toggle = Array.new
    @outfile_prefix = "fred_parameters"

    options.each_pair do |opt, arg|
      case opt
      when "--slide"
        @slide = SlideVar.new(arg, @exp)

      when "--toggle"
        arg.split(":").each { |toggle_var|
          @toggle << ToggleVar.new(toggle_var, @exp)
        }

      when "--output_to"
        @outfile_prefix = arg

      else
	# case of unknown arguments has been dealt with by fred.rb
      end
    end


    # announce the task
    $stderr.puts "---------"
    $stderr.puts "Fred parameter exploration, experiment #{@exp.get("experiment_ID")}"
    $stderr.puts "---------"

  end

  ####
  def compute()
    ##
    # make a split of the training data
    begin
      feature_dir =  fred_dirname(@exp, "train", "features")
    rescue
      $stderr.puts "To experiment with system parameters, please first featurize training data."
      exit 1
    end
    # make new split ID from system time, and make a split with 80% training, 20% test data
    splitID = Time.new().to_f.to_s
    task_obj = FredSplit.new(@exp,
                             { "--logID" => splitID,
                              "--trainpercent" => "80",
                             },
                             true  # ignore unambiguous
                             )
    task_obj.compute()

    ##
    # start recording results:

    # text output file
    begin
      textout_file = File.new(@outfile_prefix + ".txt", "w")
    rescue
      raise "Could not write to output file #{@outfile_prefix}.txt"
    end

    # values_to_score: hash toggle_values_descr(string) =>
    #                        hash slide_value(float) => score(float)
    values_to_score = Hash.new()

    # max_score: float, describing maximum score achieved
    # max_setting: string, describing values for maximum score
    max_score = 0.0
    max_setting = ""

    ##
    # for each value of the toggle variables
    0.upto(2**@toggle.length() - 1) { |binary|

      textout_line = ""

      # re-set toggle values according to 'binary':
      @toggle.each_index { |i|
        # if the i-th bit is set in binary, set this
        # boolean to true, else set it to false
        if (binary & (2**i)) > 0
          textout_line << @toggle[i].set_value_to(true, @exp) + " "
        else
          textout_line << @toggle[i].set_value_to(false, @exp) + " "
        end
      }

      values_to_score[textout_line] = Hash.new()


      ##
      # for each value of the slide variable
      @slide.each_slide_value(@exp) { |slide_value, slide_value_description|

        ##
        # progress bar
        $stderr.puts "Parameter exploration: #{textout_line} #{slide_value_description}"

        ##
        # @exp has been modified to fit the current values of the
        # slide and toggle variables.
        # Now train, test, evaluate on the split we have constructed
        task_obj = FredTrain.new(@exp, { "--logID" => splitID})
        task_obj.compute()
        task_obj = FredTest.new(@exp,
                                { "--logID" => splitID,
                                 "--nooutput"=> true
                                })
        task_obj.compute()
        task_obj = FredEval.new(@exp, {"--logID" => splitID})
        task_obj.compute(false)  # don't print evaluation results to file

        ##
        # read off F-score, record result
        score = task_obj.f

        textout_file.puts textout_line + slide_value_description + " : " + score.to_s
        textout_file.flush()
        values_to_score[textout_line][slide_value] = score

        if score > max_score
          max_score = score
          max_setting = textout_line + slide_value_description + " : " + score.to_s
        end
      }
    }

    ##
    # remove split
    FredSplit.remove_split(@exp, splitID)

    ##
    # plot outcome, report overall maximum

    unless @slide.empty?
      # gnuplot output only if some slide variable has been used
      title = "Exploring #{@slide.var_name}, " + @toggle.map { |toggle_obj| toggle_obj.var_name }.join(", ")
      PlotAndREval.gnuplot_direct(values_to_score,
                                  title,
                                  @slide.var_name,
                                  "F-score",
                                  @outfile_prefix + ".ps")
    end

    $stderr.puts "Parameter exploration finished."
    $stderr.puts "Text output was written to #{@outfile_prefix}.txt"
    unless @slide.empty?
      $stderr.puts "Gnuplot output was written to #{@outfile_prefix}.ps"
    end

    unless max_setting.empty?
      $stderr.puts "-----------------------"
      $stderr.puts "Maximum score:"
      $stderr.puts max_setting
    end
  end

end
