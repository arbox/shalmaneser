require 'ruby_class_extensions'

module Shalmaneser
  module Rosy
    class FeatureInfo
      ###
      # class variable:
      # list of all known extractors
      # add to it using add_feature()
      @@extractors = []

      # boolean. set to true after warning messages have been given once
      @@warned = false

      ###
      # add interface/interpreter
      def self.add_feature(class_name) # Class object
        @@extractors << class_name
      end

      ###
      def initialize(exp)
        ##
        # make list of extractors that are
        # either required by the user
        # or needed by the system
        @current_extractors = []
        @exp = exp

        # user-chosen extractors:
        # returns array of pairs [feature group designator(string), options(array:string)]
        exp.get_lf("feature").each { |extractor_name, options|
          extractor = @@extractors.detect { |e| e.designator == extractor_name }
          unless extractor
            # no extractor found matching the given designator
            unless @@warned
              $stderr.puts "Warning: Could not find a feature extractor for #{extractor_name}: skipping."
            end
            next
          end

          # read and check options
          step = nil

          options.each { |option|
            case option
            when "dontuse", "argrec", "arglab", "onestep"

              if step
                # step has already been set
                $stderr.puts "ERROR in feature #{extractor_name}: Please set only one of the options dontuse, argrec, arglab, onestep"
                exit 1
              end

              step = option

            else
              unless @@warned
                $stderr.puts "Warning: Unknown option for feature #{extractor_name}: #{option}. Skipping"
              end
            end
          }

          @current_extractors << {
            "extractor" => extractor,
            "step" => step
          }
        }

        # extractors needed by the system
        @@extractors.select { |e|
          # select admin features and gold feature
          ["admin", "gold"].include? e.feature_type
        }.each { |extractor|

          # if we have already added that extractor, remove it
          # and add it with our own options
          @current_extractors.delete_if { |descr| descr["extractor"].designator == extractor.designator }

          @current_extractors << {
            "extractor"=> extractor,
            "step" => "dontuse"
          }
        }

        # make sure that all extractors are computable in the current model
        # (i.e. check dependencies)

        allstep_extractors = @current_extractors.find_all {|e_hash| e_hash["step"].nil?
        }.map { |e| e["extractor"].designator }
        argrec_extractors = @current_extractors.find_all {|e_hash| e_hash["step"].nil? or e_hash["step"] == "argrec"
        }.map { |e| e["extractor"].designator }
        arglab_extractors = @current_extractors.find_all {|e_hash| e_hash["step"].nil? or e_hash["step"] == "arglab"
        }.map { |e| e["extractor"].designator }
        onestep_extractors = @current_extractors.find_all {|e_hash| e_hash["step"].nil? or e_hash["step"] == "onestep"
        }.map { |e| e["extractor"].designator }

        @current_extractors.delete_if {|extractor_hash|
          case extractor_hash["step"]
          when nil
            computable = extractor_hash["extractor"].is_computable(allstep_extractors)
          when "argrec"
            computable = extractor_hash["extractor"].is_computable(argrec_extractors)
          when "arglab"
            computable = extractor_hash["extractor"].is_computable(arglab_extractors)
          when "onestep"
            computable = extractor_hash["extractor"].is_computable(onestep_extractors)
          when "dontuse"
	    # either an admin feature or a user feature not to be used this time
            computable = true
          end

          if computable
            false # i.e. don't delete
          else
            unless @@warned
              $stderr.puts "Warning: Feature extractor #{extractor_hash["extractor"].designator} cannot be computed: skipping."
            end
            true
          end
        }

        # make list of all features as hashes
        # "feature_name" -> string,
        # "sql_type" -> string,
        # "is_index" -> boolean,
        # "step" -> string: argrec, arglab, onestep, or nil
        # "type" -> string
        # "phase" -> string: phase 1 or phase 2
        @features = []
        @current_extractors.each { |descr|
          extractor = descr["extractor"]
          extractor.feature_names.each { |feature_name|
            @features << {
              "feature_name" => feature_name,
              "sql_type"     => extractor.sql_type,
              "is_index"     => extractor.info.include?("index"),
              "step"         => descr["step"],
              "type"         => extractor.feature_type,
              "phase"        => extractor.phase
            }
          }
        }

        # do not print warnings again if another FeatureInfo object is made
        @@warned = true
      end

      ###
      # get_column_formats
      #
      # returns a list of pairs [feature_name(string), sql_column_format(string)]:
      # all features to be computed, with their SQL column formats
      def get_column_formats(phase = nil) # string: phase 1 or phase 2
        return @features.select { |feature_descr|
          phase.nil? or
            feature_descr["phase"] == phase
        }.map { |feature_descr|
          [feature_descr["feature_name"], feature_descr["sql_type"]]
        }
      end

      ###
      # get_column_names
      #
      # returns a list of feature names (strings)
      # all features to be computed
      def get_column_names(phase = nil)  # string: phase 1 or phase 2
        return @features.select { |feature_descr|
          phase.nil? or
            feature_descr["phase"] == phase
        }.map { |feature_descr|
          feature_descr["feature_name"]
        }
      end

      ###
      # get_index_columns
      #
      # returns a list of feature (column) names as Strings
      # consisting of all features that have been requested as index features
      # in the experiment file or in the list of @@all_features_we_have above
      def get_index_columns
        return @features.select { |feature_descr|
          feature_descr["is_index"]
        }.map {|feature_descr|
          feature_descr["feature_name"]
        }
      end

      ###
      # get_model_features
      #
      # returns a list of feature (column) names as strings
      # consisting of all the features to be used for the modeling
      #
      # step: argrec, arglab, onestep
      def get_model_features(step)
        return @features.select { |feature_descr|
          # features for the current step
          # feature_descr["step"] is argrec, arglab, onestep, dontuse, or nil
          # nil matches all steps
          # 'dontuse' matches no step, so these features will never be returned here
          feature_descr["step"].nil? or
            feature_descr["step"] == step
        }.reject { |feature_descr|
          # that are not admin features or the gold label
          ["admin", "gold"].include? feature_descr["type"]
        }.map { |feature_descr|
          # use just the names of the features
          feature_descr["feature_name"]
        }
      end

      ###
      # get_extractor_objects
      #
      # returns two lists of feature extractor objects,
      # covering all features of the given phase:
      # the first list contains FeatureExtractor extractors,
      # the second list contains the others.
      def get_extractor_objects(phase, # string: "phase 1" or "phase 2"
                                interpreter_class) # SynInterpreter class
        unless ["phase 1", "phase 2"].include? phase
          raise "Shouldn't be here: " + phase
        end

        return @current_extractors.select { |descr|
          # select extractors of the right phase
          descr["extractor"].phase == phase
        }.map { |descr|

          # make objects from extractor classes
          descr["extractor"].new(@exp, interpreter_class)
        }.distribute { |extractor_obj|
          # distribute extractors in two bins:
          # first, rosy extractors
          # second, others
          extractor_obj.class.info.include? "rosy"
        }
      end
    end
  end
end
