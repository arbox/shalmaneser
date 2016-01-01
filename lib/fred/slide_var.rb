module Shalmaneser
  ##########################################
  module Fred
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
        @exp_lhs.empty?
      end
    end
  end
end
