require_relative 'config_data'

##############################
# Class RosyConfigData
#
# inherits from ConfigData,
# sets features for ROSY
module Shalm
  module Configuration
    class RosyConfigData < ConfigData
      CONFIG_DEFS = {
        "feature" => "list",
        "classifier" => "list",
        "verbose" => "bool",
        "experiment_ID" => "string",
        "directory_input_train" => "string",
        "directory_input_test" => "string",
        "directory_output" => "string",
        "preproc_descr_file_train" => "string",
        "preproc_descr_file_test" => "string",
        "external_descr_file"    => "string",
        "dbtype" => "string",    # "mysql" or "sqlite"

        "host" => "string",      # DB access: sqlite only
        "user" => "string",
        "passwd" => "string",
        "dbname" => "string",

        "data_dir" => "string",  # for external use
        "rosy_dir" => "pattern", # for internal use only, set by rosy.rb

        "classifier_dir" => "string", # if present, special directory for classifiers

        "classif_column_name" => "string",
        "main_table_name" => "pattern",
        "test_table_name" => "pattern",

        "eval_file" => "pattern",
        "log_file" => "pattern",
        "failed_file" => "pattern",
        "classifier_file" => "pattern",
        "classifier_output_file" => "pattern",
        "noval" => "string",
        "split_nones" => "bool",
        "print_eval_log" => "bool",
        "assume_argrec_perfect" => "bool",
        "xwise_argrec" => "string",
        "xwise_arglab" => "string",
        "xwise_onestep" => "string",
        "fe_syn_repair" => "bool", # map words to constituents for FEs: idealize?
        "fe_rel_repair" => "bool", # FEs: include non-included relative clauses into FEs
        "prune" => "string", # pruning prior to argrec?

        # Imported from PrepConfigData
        'do_postag' => 'bool',
        'do_lemmatize' => 'bool',
        'do_parse' => 'bool',
        'pos_tagger' => 'string',
        'lemmatizer' => 'string',
        'parser' => 'string'
      }

      def initialize(filename)
        super(filename, CONFIG_DEFS, ["exp_ID", "test_ID", "split_ID",
                                      "feature_name", "classif", "step",
                                      "group", "dataset", "mode"])

        # set access functions for list features
        set_list_feature_access("feature",
                                method("access_feature"))

        # set access functions for list features
        set_list_feature_access("classifier",
                                method("access_feature"))
        validate
      end

      ###
      # protected

      #####
      # access_feature
      #
      # access function for feature 'feature'
      #
      # assumed format in the config file:
      #
      #   feature = path [option]*
      #
      # i.e. first the name of the feature type to use, then
      # optionally options associated with that feature,
      # e.g. 'argrec': use that feature only when computing argrec
      #
      # the access function is called with parameter val_list, an array of
      # string tuples, one string tuple for each feature defined.
      # the first string in the tuple is the feature name, the rest are the options
      #
      # returns: a list of pairs [feature_name(string), options(array:string)]
      # of defined features
      def access_feature(val_list) # array:array:string: list of tuples defined in config file
        # for feature 'feature'
        if val_list.nil?
          []
        else
          val_list.map do |feature_descr_tuple|
            [feature_descr_tuple.first, feature_descr_tuple[1..-1]]
          end
        end
      end

      private

      def validate
      end
    end
  end
end
