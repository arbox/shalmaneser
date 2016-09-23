require "delegate"
require 'fred/fred_conventions' # !!
require 'fred/write_features_binary'
require 'fred/write_features_nary'

module Shalmaneser
  module Fred
    ########
    # class writing features:
    # delegating to either a binary or an n-ary writer
    class WriteFeaturesNaryOrBinary < SimpleDelegator
      ###
      def initialize(lemma,
                     exp,
                     dataset)
        feature_dir = WriteFeaturesNaryOrBinary.feature_dir(exp, dataset, "new")
        if exp.get("binary_classifiers")
          # binary classifiers
          # $stderr.puts "Writing binary feature data."

          # delegate writing to the binary feature writer
          @writer = WriteFeaturesBinary.new(lemma, exp, dataset, feature_dir)
          super(@writer)

        else
          # n-ary classifiers
          # $stderr.puts "Writing n-ary feature data."

          # delegate writing to the n-ary feature writer
          @writer = WriteFeaturesNary.new(lemma, exp, dataset, feature_dir)
          super(@writer)
        end
      end

      def self.feature_dir(exp, dataset, mode = "existing")
        ::Shalmaneser::Fred.fred_dirname(exp, dataset, "features", mode)
      end

      ###
      def self.remove_files(exp, dataset)
        feature_dir = WriteFeaturesNaryOrBinary.feature_dir(exp, dataset, "new")

        Dir[feature_dir + ::Shalmaneser::Fred.fred_feature_filename("*")].each do |filename|
          if File.exist? filename
            File.delete(filename)
          end
        end
      end
    end
  end
end
