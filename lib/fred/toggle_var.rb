module Shalmaneser
  module Fred
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
  end
end
