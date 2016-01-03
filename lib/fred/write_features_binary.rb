###
# Features for binary classifiers
require 'fred/FredConventions' # !

module Shalmaneser
  module Shalmaneser
    class WriteFeaturesBinary
      def initialize(lemma,
                     exp,
                     dataset,
                     feature_dir)
        @dir = feature_dir
        @lemma = lemma
        @feature_dir = feature_dir

        @negsense = exp.get("negsense")
        unless @negsense
          @negsense = "NONE"
        end

        # files: sense-> filename
        @files = {}

        # keep all instances such that, when a new sense comes around,
        # we can write them for that sense
        @instances = []
      end


      def write_instance(features, senses)
        # sense we haven't seen before? Then we need to
        # write the whole featurization file for that new sense
        check_for_presence_of_senses(senses)

        # write this new instance for all senses
        @files.each_key { |sense_of_file|
          write_to_sensefile(features, senses, sense_of_file)
        }

        # store instance in case another sense crops up later
        @instances << [features, senses]
      end


      ###
      def close
        @files.each_value { |f| f.close }
      end

      ######
      private

      def check_for_presence_of_senses(senses)
        senses.each { |sense|
          # do we have a sense file for this sense?
          unless @files[sense]
            # open new file for this sense
            @files[sense] = File.new(@feature_dir + ::Shalmaneser::Fred.fred_feature_filename(@lemma, sense, true), "w")
            # filename = @feature_dir + Fred.fred_feature_filename(@lemma, sense, true)
            # $stderr.puts "Starting new feature file #{filename}"

            # and re-write all previous instances for it
            @instances.each { |prev_features, prev_senses|
              write_to_sensefile(prev_features, prev_senses,
                                 sense)
            }
          end
        }
      end

      ###
      def write_to_sensefile(features, senses,
                             sense_of_file)
        # file to write to
        f = @files[sense_of_file]

        # print features
        f.print features.map { |x|
          x.to_s.gsub(/,/, "COMMA")
        }.join(",")

        f.print ","

        # binarize target class
        if senses.include? sense_of_file
          # $stderr.puts "writing POS #{sense_of_file}"
          f.puts sense_of_file.to_s
        else
          # $stderr.puts "writing NEG #{negsense}"
          f.puts @negsense
        end
      end
    end
  end
end
