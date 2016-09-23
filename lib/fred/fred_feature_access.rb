# coding: utf-8
require 'fred/fred_feature_info'
require 'fred/feature_extractors'
require 'fred/FredConventions'
require 'fred/abstract_fred_feature_access'
require 'fred/answer_key_access'
require 'fred/aux_keep_writers'
require 'fred/write_features_nary_or_binary'

module Shalmaneser
  module Fred
    ########################################
    # FredFeatureWriter:
    # write chosen features (according to the experiment file)
    # to
    # - one file per lemma for n-ary classification
    # - one file per lemma/sense pair for binary classification
    #
    # format: CSV, last entry is target class
    class FredFeatureAccess < AbstractFredFeatureAccess
      ####
      def self.remove_feature_files(exp, dataset)
        # remove feature files
        WriteFeaturesNaryOrBinary.remove_files(exp, dataset)
        # remove key files
        AnswerKeyAccess.remove_files(exp, dataset)
      end

      ###
      def self.legend_filename(lemmapos)
        "fred.feature_legend.#{lemmapos}"
      end

      ###
      def self.feature_dir(exp, dataset)
        WriteFeaturesNaryOrBinary.feature_dir(exp, dataset, "new")
      end

      ###
      # each feature file:
      # iterate through feature files,
      # yield pairs [filename, values]
      # where 'values' is a hash containing keys
      # 'lemma' and potentially 'sense'
      #
      # filenames are sorted alphabetically before being yielded
      #
      # available in read and write mode
      def self.each_feature_file(exp, dataset)
        feature_dir = FredFeatureAccess.feature_dir(exp, dataset)
        Dir[feature_dir + "*"].sort.each { |filename|
          if (values = deconstruct_fred_feature_filename(filename))
            yield [filename, values]
          end
        }
      end

      ###
      def initialize(exp, dataset, mode)
        super(exp, dataset, mode)
        # write to auxiliary files first,
        # to sort items by lemma
        @w_tmp = AuxKeepWriters.new
        # which features has the user requested?
        feature_info_obj = FredFeatureInfo.new(@exp)
        @feature_extractors = feature_info_obj.get_extractor_objects

      end

      ###
      # write item:
      # - transform meta-features into actual features as requested
      #   in the experiment file
      # - write item to tempfile, don't really write yet
      def write_item(lemma,  # string: target lemma
                     pos,    # string: target pos
                     ids,    # array:string: unique IDs of this occurrence of the lemma
                     sid,    # string: sentence ID
                     senses,  # array:string: sense
                     features) # features: hash feature type-> features (string-> array:string)


        unless ["w", "a"].include? @mode
          $stderr.puts "FredFeatures error: cannot write to feature file opened for reading"
          exit 1
        end

        if lemma.nil? or lemma.empty? or ids.nil? or ids.empty?
          # nothing to write
          return
        end
        if pos.nil? or pos.empty?
          # POS unknown
          pos = ""
        end

        # falsch! noval nicht zulässig für fred! (nur für rosy!) - Warum steht das hier???
        unless senses
          senses = [@exp.get("noval")]
        end

        # modified by ines, 19.7.2010
        # senses should be empty, but they are not - why?
        if senses.length == 1 and senses[0].eql? ""
          senses = "NONE"
        end

        writer = @w_tmp.get_writer_for(::Shalmaneser::Fred.fred_lemmapos_combine(lemma, pos))
        ids_s = ids.map { |i| i.gsub(/:/, "COLON") }.join("::")

        # AB: Ines modified <senses> and it can be a String.
        # That's corrected, but I do not guarantee the correct results.
        if senses.respond_to? :map
          senses_s = senses.map { |s| s.gsub(/:/, "COLON") }.join("::")
        end
        writer.print "#{lemma} #{pos} #{ids_s} #{sid} #{senses_s} "

        # write all features
        @feature_extractors.each { |extractor|
          extractor.each_feature(features) { |feature|
            writer.print feature, " "
          }
        }
        writer.puts
        writer.flush
      end

      ###
      def flush
        unless ["w", "a"].include? @mode
          $stderr.puts "FredFeatureAccess error: cannot write to feature file opened for reading"
          exit 1
        end

        # elements in the feature vector: get fixed with the training data,
        # get read with the test data.
        # get stored in feature_legend_dir
        case @dataset
        when "train"
          feature_legend_dir = File.new_dir(::Shalmaneser::Fred.fred_classifier_directory(@exp),
                                            "legend")
        when "test"
          feature_legend_dir= File.existing_dir(::Shalmaneser::Fred.fred_classifier_directory(@exp),
                                                "legend")
        end

        # now really write features
        @w_tmp.flush
        @w_tmp.get_lemmas.sort.each { |lemmapos|

          # inform user
          $stderr.puts "Writing #{lemmapos}..."

          # prepare list of features to use in the feature vector:
          legend_filename = feature_legend_dir + FredFeatureAccess.legend_filename(lemmapos)

          case @dataset
          when "train"
            # training data:
            # determine feature list and sense list from the data,
            # and store in the relevant file
            feature_list, sense_list = collect_feature_list(lemmapos)
            begin
              f = File.new(legend_filename, "w")
            rescue
              $stderr.puts "Error: Could not write to feature legend file #{legend_filename}: " + $!
              exit 1
            end
            f.puts feature_list.map { |x| x.gsub(/,/, "COMMA") }.join(",")
            f.puts sense_list.map { |x| x.gsub(/,/, "COMMA") }.join(",")
            f.close

          when "test"
            # test data:
            # read feature list and sense list from the relevant file

            begin
              f = File.new(legend_filename)
            rescue
              $stderr.puts "Error: Could not read feature legend file #{legend_filename}: " + $!
              $stderr.puts "Skipping this lemma."
              next
            end
            feature_list = f.gets.chomp.split(",").map { |x| x.gsub(/COMMA/, ",") }
            sense_list = f.gets.chomp.split(",").map { |x| x.gsub(/COMMA/, ",") }
          end

          # write
          # - featurization file
          # - answer key file

          f = @w_tmp.get_for_reading(lemmapos)
          answer_obj = AnswerKeyAccess.new(@exp, @dataset, lemmapos, "w")

          obj_out = WriteFeaturesNaryOrBinary.new(lemmapos, @exp, @dataset)

          f.each { |line|

            lemma, pos, ids, sid, senses, features = parse_temp_itemline(line)
            unless lemma
              # something went wrong in parsing the line
              next
            end
            each_sensegroup(senses, sense_list) { |senses_for_item, original_senses|
              # write answer key
              answer_obj.write_line(lemma, pos,
                                    ids, sid, original_senses, senses_for_item)

              # write item: features, senses
              obj_out.write_instance(to_feature_list(features, feature_list),
                                     senses_for_item)
            } # each sensegroup
          } # each input line
          obj_out.close
          answer_obj.close
          @w_tmp.discard(lemmapos)
        } # each lemma


      end

      ###
      # deconstruct feature file name
      # returns: hash with keys
      # "lemma"
      # "sense
      # @note Used only in FredFeatures.
      # @note Imported from FredConventions.
      def deconstruct_fred_feature_filename(filename)
        basename = File.basename(filename)
        retv = {}

        # binary:
        # fred.features.#{lemma}.SENSE.#{sense}
        if basename =~ /^fred\.features\.(.*)\.SENSE\.(.*)$/
          retv["lemma"] = $1
          retv["sense"] = $2
        elsif basename =~ /^fred\.features\.(.*)/
          # fred.features.#{lemma}
          retv["lemma"] = $1

        else
          # complete mismatch
          return nil
        end

        return retv
      end

      ##################
      protected

      ###
      # read temp feature file for the given lemma/pos
      # and determine the list of all features and the list of all senses,
      # each sorted alphabetically
      def collect_feature_list(lemmapos)
        # read entries for this lemma
        f = @w_tmp.get_for_reading(lemmapos)

        # keep a record of all senses and features
        # senses: binary.
        # features: keep the max. number of times a given feature occurred
        #         in an instance
        all_senses = {}
        all_features = Hash.new(0)
        features_this_instance = Hash.new(0)
        # record how often each feature occurred all in all
        num_occ = Hash.new(0)
        num_lines = 0

        f.each { |line|
          lemma, pos, id_string, sid, senses, features = parse_temp_itemline(line)

          unless lemma
            # something went wrong in parsing the line
            # print out the file contents for reference, then leave
            $stderr.puts "Could not read temporary feature file #{f.path} for #{lemmapos}."
            exit 1
          end
          num_lines += 1
          senses.each { |s| all_senses[s] = true }
          features_this_instance.clear
          features.each { |fea|
            features_this_instance[fea] += 1
            num_occ[fea] += 1
          }

          features_this_instance.each_pair { |feature, value|
            all_features[feature] = [ all_features[feature], features_this_instance[feature] ].max
          }
        }

        case @exp.get("numerical_features")
        when "keep"
          # leave numerical features as they are, or
          # don't do numerical features
          return [ all_features.keys.sort,
                   all_senses.keys.sort
                 ]

        when "repeat"
          # repeat: turn numerical feature with max. value N
          # into N binary features
          feature_list = []
          all_features.keys.sort.each { |feature|
            all_features[feature].times { |index|
              feature_list << feature + " #{index}/#{all_features[feature]}"
            }
          }
          return [ feature_list,
                   all_senses.keys.sort
                 ]

        when "bin"
          # make bins:
          # number of bins = (max. number of occurrences of a feature per item) / 10
          feature_list = []
          all_features.keys.sort.each { |feature|
            num_bins_this_feature = (all_features[feature].to_f / 10.0).ceil.to_i

            num_bins_this_feature.times { |index|
              feature_list << feature  + " #{index}/#{num_bins_this_feature}"
            }
          }
          return [feature_list, all_senses.keys.sort]
        else
          raise "Shouldn't be here"
        end
      end

      ###
      # given a full sorted list of items and a partial list of items,
      # match the partial list to the full list,
      # that is, produce as many items as the full list has
      # yielding 0 where the partial entry is not in the full list,
      # and > 0 otherwise
      #
      # Note that if partial contains items not in full,
      # they will not occur on the feature list returned!
      def to_feature_list(partial, full, handle_numerical_features = nil)
        # print "FULL: ", full, "\n"
        # print "PART: ", partial, "\n"
        # count occurrences of each feature in the partial list
        occ_hash = Hash.new(0)
        partial.each { |p| occ_hash[p] += 1 }

        # what to do with our counts?
        unless handle_numerical_features
          # no pre-set value given when this function was called
          handle_numerical_features = @exp.get("numerical_features")
        end

        case handle_numerical_features
        when "keep"
          # leave numerical features as numerical features
          return full.map { |x| occ_hash[x].to_s }
        when "repeat"
          # repeat each numerical feature up to a max. number of occurrences
          return full.map do |feature_plus_count|
            unless feature_plus_count =~ /^(.*) (\d+)\/(\d+)$/
              $stderr.puts "Error: could not parse feature: #{feature_plus_count}, bailing out."
              raise "Shouldn't be here."
            end

            feature = $1
            current_count = $2.to_i
            max_num = $3.to_i

            if occ_hash[feature] > current_count
              1
            else
              0
            end
          end
        when "bin"
          # group numerical feature values into N bins.
          # number of bins varies from feature to feature
          # each bin contains 10 different counts
          return full.map do |feature_plus_count|
            unless feature_plus_count =~ /^(.*) (\d+)\/(\d+)$/
              $stderr.puts "Error: could not parse feature: #{feature_plus_count}, bailing out."
              raise "Shouldn't be here."
            end

            feature = $1
            current_count = $2.to_i
            max_num = $3.to_i

            if occ_hash[feature] % 10 > (10 * current_count)
              1
            else
              0
            end
          end
        else
          raise "Shouldn't be here"
        end
      end

      ###
      # how to treat instances with multiple senses?
      # - either write one item per sense
      # - or combine all senses into one string
      # - or keep as separate senses
      #
      # according to 'handle_multilabel' in the experiment file
      #
      # yields pairs of [senses, original_senses]
      # both are arrays of strings
      def each_sensegroup(senses, full_sense_list)
        case @exp.get("handle_multilabel")
        when "keep"
          yield [senses, senses]
        when "join"
          yield [[fred_join_senses(senses)], senses]
        when "repeat"
          senses.each { |s| yield [[s], senses] }
        when "binarize"
          yield [senses, senses]
        else
          $stderr.puts "Error: unknown setting #{exp.get("handle_multilabel")}"
          $stderr.puts "for 'handle_multilabel' in the experiment file."
          $stderr.puts "Please choose one of 'binary', 'keep', 'join', 'repeat'"
          $stderr.puts "or leave unset -- default is 'binary'."
          exit 1
        end
      end

      ###
      def parse_temp_itemline(line)
        lemma, pos, ids_s, sid, senses_s, *features = line.split
        # fix me! senses is empty, takes context features instead
        unless senses_s
          # features may be empty, but we need senses
          $stderr.puts "FredFeatures Error in word sense item line: too short."
          $stderr.puts ">>#{line}<<"
          return nil
        end

        ids = ids_s.split("::").map { |i| i.gsub(/COLON/, ":") }
        senses = senses_s.split("::").map { |s| s.gsub(/COLON/, ":") }

        return [lemma, pos, ids, sid, senses, features]
      end

      private

      ###
      # joining and breaking up senses
      # @note Used only in FredFeatures.
      # @note Imported from FredConventions.
      def fred_join_senses(senses)
        senses.sort.join("++")
      end
    end
  end
end
