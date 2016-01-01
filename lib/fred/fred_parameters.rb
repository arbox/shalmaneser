# FredParameters
# Katrin Erk, April 05
#
# Frame disambiguation system:
#  test different values for system parameters,
#  construct text and graphical output

# Salsa packages
require 'fred/PlotAndREval'
require 'fred/FredConventions' # !
require 'fred/fred_split'
require 'fred/FredTrain'
require 'fred/FredTest'
require 'fred/FredEval'
require 'fred/toggle_var'
require 'fred/slide_var'

module Shalmaneser
  module Fred
    ##########################################
    # main class of this package:
    # try out different values for system parameters,
    # and record the result.
    #
    # One value can be a slide variable, taking on several numerical values.
    # 0 or more values can be toggle variables, taking on the values true and false.
    # @todo AB: Reintroduce this task!!!
    class FredParameters
      #####
      def initialize(exp_obj, # FredConfigData object
                     options) # hash: runtime option name (string) => value(string)

        @exp = exp_obj

        # evaluate runtime options:
        # record the slide variable (if any) plus all toggle variables
        @slide = SlideVar.new("", @exp)
        @toggle = []
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
      def compute
        ##
        # make a split of the training data
        begin
          feature_dir = ::Shalmaneser::Fred.fred_dirname(@exp, "train", "features")
        rescue
          $stderr.puts "To experiment with system parameters, please first featurize training data."
          exit 1
        end
        # make new split ID from system time, and make a split with 80% training, 20% test data
        splitID = Time.new.to_f.to_s
        task_obj = FredSplit.new(@exp,
                                 { "--logID" => splitID,
                                   "--trainpercent" => "80",
                                 },
                                 true  # ignore unambiguous
                                )
        task_obj.compute

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
        values_to_score = {}

        # max_score: float, describing maximum score achieved
        # max_setting: string, describing values for maximum score
        max_score = 0.0
        max_setting = ""

        ##
        # for each value of the toggle variables
        0.upto(2**@toggle.length - 1) { |binary|

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

          values_to_score[textout_line] = {}


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
            task_obj.compute
            task_obj = FredTest.new(@exp,
                                    { "--logID" => splitID,
                                      "--nooutput"=> true
                                    })
            task_obj.compute
            task_obj = FredEval.new(@exp, {"--logID" => splitID})
            task_obj.compute(false)  # don't print evaluation results to file

            ##
            # read off F-score, record result
            score = task_obj.f

            textout_file.puts textout_line + slide_value_description + " : " + score.to_s
            textout_file.flush
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
  end
end
