# Salsa packages
require 'salsa_tiger_xml/file_parts_parser'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require "ruby_class_extensions"

# Fred/Rosy packages
require_relative 'failed_parses'
require 'rosy/rosy_conventions'
require_relative 'feature_extractor'
require 'rosy/feature_extractors/features'
# require "rosy/RosyPhase2FeatureExtractors"
# require "rosy/RosyPruning"
# require "rosy/GfInduceFeature"

require 'frappe/fix_syn_sem_mapping'

module Shalmaneser
  module Rosy
    ###########
    #
    # ke / sp 12 04 05
    #
    # class for input data object
    # offers methods for preprocessing and
    # featurization
    class InputData
      ###
      # RosyConfigData object
      # train/test
      # FeatureInfo object
      # SynInterpreter class
      # Directory with input files
      def initialize(exp_object, dataset, feature_info_object, interpreter_class, input_dir)
        @exp = exp_object
        @dataset = dataset
        @interpreter_class = interpreter_class
        raise 'BumBamBim!!!' if @interpreter_class.nil?
        @input_dir = input_dir
        # store information about failed parses here
        @failed_parses = FailedParses.new

        # feature_extractors_phase1: array of AbstractFeatureExtractor objects
        @extractors_p1_rosy, @extractors_p1_other = feature_info_object.get_extractor_objects("phase 1", @interpreter_class)

        # global settings
        unless FeatureExtractor.set("split_nones" => @exp.get("split_nones"))
          raise "Some grave problem during feature extractor initialization"
        end

        #     # nothing to set here for now, so deactivated
        #     @extractors_p1_other.each { |extractor_obj|
        #       unless extractor_obj.class.set
        #         raise "Some grave problem during feature extractor initialization"
        #       end
        #     }

        # feature_extractors_phase2: array of  AbstractFeatureExtractor objects
        extractors_p2_rosy, extractors_p2_other = feature_info_object.get_extractor_objects("phase 2", @interpreter_class)
        @feature_extractors_phase2 = extractors_p2_rosy + extractors_p2_other
      end

      ###
      # each_instance_phase1()
      #
      # reads the input data from file(s), in the specific input format,
      # separates it into instances,
      # threads it through all phase 1 feature extractors
      # and yields one feature vector per instance
      #
      # yields: pairs [feature_name(string), feature_value(object)]

      def each_instance_phase1
        Dir[@input_dir + "*.xml"]. each { |parsefilename|
          xml_file = STXML::FilePartsParser.new(parsefilename)
          $stderr.puts "Processing #{parsefilename}"
          xml_file.scan_s { |sent_string|
            sent = STXML::SalsaTigerSentence.new(sent_string)

            # preprocessing: possibly change the SalsaTigerSentence object
            # before featurization
            preprocess(sent)

            sent.each_frame { |frame|
              # skip failed parses
              if sent.get_attribute("failed")
                handle_failed_parse(sent, frame)
                next
              end

              # Tell feature extractors about the sentence and frame:
              # first Rosy feature extractors, then the others
              # if there is a problem, skip this frame
              unless FeatureExtractor.set_sentence(sent, frame)
                next
              end
              skip_frame = false
              @extractors_p1_other.each { |extractor_obj|
                unless extractor_obj.class.set_sentence(sent, frame)
                  skip_frame = true
                  break
                end
              }
              if skip_frame
                next
              end

              sent.each_syn_node { |syn_node|

                # Tell feature extractors about the current node:
                # first Rosy feature extractors, then the others
                # if there is a problem, skip this node
                unless FeatureExtractor.set_node(syn_node)
                  next
                end
                skip_node = false
                @extractors_p1_other.each { |extractor_obj|
                  unless extractor_obj.class.set_node(syn_node)
                    skip_node = true
                    break
                  end
                }
                if skip_node
                  next
                end

                # features: array of pairs: [feature_name(string), feature_value(object)]
                features = []
                (@extractors_p1_rosy + @extractors_p1_other).each { |extractor|
                  # compute features
                  feature_names = extractor.class.feature_names
                  feature_index = 0

                  # append new features to features array
                  features.concat extractor.compute_features.map { |feature_value|
                    feature_name = feature_names[feature_index]
                    feature_index += 1

                    # sanity check: feature value longer than the allotted space in the DB?
                    check_feature_length(feature_name, feature_value, extractor)

                    [feature_name, nonnil_feature(feature_value, extractor.class.sql_type)]
                  }
                }
                yield features
              } # each syn node
            } # each frame
          } # each sentence
        }
      end

      ###
      # each_phase2_column
      #
      # This method implements the application of the
      # phase 2 extractors to data.
      #
      # Given a database view (of either training or test data),
      # assign a new feature value to each instance
      #
      # yields pairs [feature_name(string), feature_values(array)]
      # The feature_values array has as many lines as the view has instances
      # so the yield of this method can be fed directly into view.update_column()
      def each_phase2_column(view) # View object: training or test data

        @feature_extractors_phase2.each { |extractor|
          # apply the extractor
          feature_columns = extractor.compute_features_on_view(view)
          # interleave with feature values and yield
          feature_index = 0
          feature_names = extractor.class.feature_names
          feature_columns.each { |feature_values|
            yield [
              feature_names[feature_index],
              feature_values.map { |feature_val| nonnil_feature(feature_val, extractor.class.sql_type)  }
            ]
            feature_index += 1
          }
        }
      end

      ###
      # get_failed_parses
      #
      # returns the FailedParses object in which the info about failed parses has been stored
      def get_failed_parses
        @failed_parses
      end

      private

      ###
      def nonnil_feature(feature_value, sql_type)
        # feature value nil? then change to noval
        if feature_value.nil? && sql_type =~ /CHAR/
          return @exp.get("noval")
        elsif feature_value.is_a?(String) && feature_value.empty?
          return @exp.get("noval")
        elsif feature_value.nil?
          return 0
        else
          return feature_value
        end
      end

      ###
      # preprocess: possibly change the given SalsaTigerSentence
      # to enable better learning
      def preprocess(sent)           # SalsaTigerSentence object

        # @todo AB: [2015-12-16 Wed 15:39]
        #   Don't think it should be done by Rosy, do it only in Frappe.
        #   This module will be moved to Frappe's lib.
        if @dataset == "train" and
           (@exp.get("fe_syn_repair") or @exp.get("fe_rel_repair"))
          FixSynSemMapping.fixit(sent, @exp, @interpreter_class)
        end
      end

      ###
      # register failed parses
      def handle_failed_parse(sent,  # SalsaTigerSentence object
                              frame) # FrameNode

        # target POS
        if frame.target
          main_target = @interpreter_class.main_node_of_expr(frame.target.children, "no_mwe")
        else
          main_target = nil
        end
        if main_target
          target_pos = @interpreter_class.category(main_target)
        else
          target_pos = nil
        end
        if frame.target
          target_str = frame.target.yield_nodes_ordered.map { |t_node|
            if t_node.is_syntactic?
              @interpreter_class.lemma_backoff(t_node)
            else
              # not a syntactic node: maybe an unassigned target?
              ""
            end
          }.join(" ")
        else
          target_str = ""
        end

        @failed_parses.register(Rosy::construct_instance_id(sent.id, frame.id),
                                frame.name,
                                target_str,
                                target_pos,
                                frame.children.map { |fe| fe.name })

      end

      ###
      # sanity check: feature value longer than the allotted space in the DB?
      def check_feature_length(feature_name,  # string
                               feature_value, # object
                               extractor_obj) # AbstractFeatureExtractor object

        if extractor_obj.class.sql_type =~ /(\d+)/
          # sql type contains some statement about the length.
          # just crudely compare to feature length
          length = $1.to_i
          if feature_value.class == String and
            feature_value.length > length

            if feature_name == "sentid"
              print length;
              print feature_value;
              print feature_value.length;
              # if the sentence (instance) ID is too long, we cannot go on.
              $stderr.puts "Error: Instance ID is longer than its DB column."
              $stderr.puts "Please increase the DB column size in {Tiger,Collins}FeatureExtractors.rb"
              raise "SQL entry length surpassed"

            elsif @exp.get("verbose")
              # KE Feb 07: don't print warning,
              # this is just too frequent
              # for other features, we just issue a warning, and only if we are verbose

              # $stderr.puts "Warning: feature #{feature_name} longer than its DB column (#{length.to_s} vs #{feature_value.length}): #{feature_value}"
            end # feature name check
          end # length surpassed
        end # length found in sql type
      end
    end
  end
end
