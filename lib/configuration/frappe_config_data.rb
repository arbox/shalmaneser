# FPrepConfigData
# Katrin Erk July 05
#
# Preprocessing for Fred and Rosy:
# access to a configuration and experiment description file

require_relative 'config_data'

##############################
# Class FrappeConfigData
#
# inherits from ConfigData,
# sets variable names appropriate to preprocessing task
module Shalmaneser
  module Configuration
    class FrappeConfigData < ConfigData
      VALID_ENCODINGS = ['hex', 'iso', 'utf8', nil]
      VALID_INPUT_FORMATS = %w(Plain SalsaTab FNXml FNCorpusXml SalsaTigerXML)
      CONFIG_DEFS = {
        "prep_experiment_ID" => "string", # experiment identifier
        "frprep_directory" => "string", # dir for frprep internal data
        # information about the dataset
        "language" => "string", # en, de
        "origin" => "string",    # FrameNet, Salsa, or nothing
        "format" => "string",   # Plain, SalsaTab, FNXml, FNCorpusXml, SalsaTigerXML
        "encoding" => "string", # utf8, iso, hex, or nothing

        # directories
        "directory_input" => "string", # dir with input data
        "directory_preprocessed" => "string", # dir with output Salsa/Tiger XML data
        "directory_parserout" => "string", # dir with parser output for the parser named below

        # syntactic processing
        "pos_tagger" => "string", # name of POS tagger
        "lemmatizer" => "string", # name of lemmatizer
        "parser" => "string",     # name of parser
        "pos_tagger_path" => "string", # path to POS tagger
        "lemmatizer_path" => "string", # path to lemmatizer
        "parser_path" => "string",     # path to parser
        "parser_max_sent_num" => "integer", # max number of sentences per parser input file
        "parser_max_sent_len" => "integer", # max sentence length the parser handles

        "do_parse" => "bool",    # use parser?
        "do_lemmatize" => "bool",# use lemmatizer?
        "do_postag" => "bool",   # use POS tagger?

        # output format: if tabformat_output == true,
        # output in Tab format rather than Salsa/Tiger XML
        # (this will not work if do_parse == true)
        "tabformat_output" => "bool",

        # syntactic repairs, dependent on existing semantic role annotation
        "fe_syn_repair" => "bool", # map words to constituents for FEs: idealize?
        "fe_rel_repair" => "bool", # FEs: include non-included relative clauses into FEs
      }

      # @param filename [String]
      def initialize(filename)
        # @param filename [String] path to a config file
        # @param CONFIG_DEFS [Hash] a list of configuration definitions
        super(filename, CONFIG_DEFS, [])
        validate
      end

      # @return [True, False]
      # Shall we convert our input files into the target encoding?
      def convert_encoding?
        get('encoding') != 'utf8'
      end

      private

      # Validates semantically the input values from the experiment file.
      # @todo Rework the whole validation engine, the parameter definitions
      #   should entail the information about: optional, obligatory,
      #   in combination with. This information should be stored in external
      #   resource files to easily change them.
      #  @todo Accumulate error messages.
      def validate
        msg = []

        unless get('frprep_directory')
          msg << 'Please set <frprep_directory>, the Frappe internal data '\
                'directory, in the experiment file.'
        end

        unless get('directory_input')
          msg << 'Please specify <directory_input> in the Frappe experiment file.'
        end

        unless get('directory_preprocessed')
          msg << 'Please specify <directory_preprocessed> in the experiment file.'
        end

        # sanity check: output in tab format will not work
        # if we also do a parse
        if get('tabformat_output') && get('do_parse')
          msg << 'Error: Cannot do Tab format output when the input text is being'\
                'parsed. Please set either <tabformat_output> or <do_parse> to false.'
        end

        unless get("pos_tagger_path") && get("pos_tagger")
          msg << 'POS Tagging: I need <pos_tagger> and <pos_tagger_path> '\
                'in the experiment file.'
        end

        unless get('lemmatizer_path') && get('lemmatizer')
          msg << 'Lemmatization: I need <lemmatizer> and <lemmatizer_path> in the experiment file.'
        end

        unless VALID_ENCODINGS.include?(get('encoding'))
          msg << 'Please define a correct encoding in the configuration file: '\
                "<#{VALID_ENCODINGS.join('>, <')}>!"
        end

        unless VALID_INPUT_FORMATS.include?(get('format'))
          msg << 'Please define a correct input format in the configuration file: '\
                 "<#{VALID_INPUT_FORMATS.join('>, <')}>!"
        end

        unless get("prep_experiment_ID") =~ /^[A-Za-z0-9_]+$/
          msg << 'Please choose an alphanumeric experiment ID! '\
                 "You provided: #{get('prep_experiment_ID')}"
        end

        raise(ConfigurationError, msg.join("\n")) if msg.any?
      end
    end
  end
end
