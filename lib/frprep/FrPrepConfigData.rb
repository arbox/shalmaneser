# FPrepConfigData
# Katrin Erk July 05
#
# Preprocessing for Fred and Rosy: 
# access to a configuration and experiment description file

require "frprep/ConfigData"

##############################
# Class FrPrepConfigData
#
# inherits from ConfigData,
# sets variable names appropriate to preprocessing task

class FrPrepConfigData < ConfigData
  def initialize(filename)

    # initialize config data object
    super(filename,          # config file
	  { "prep_experiment_ID" => "string", # experiment identifier

           "frprep_directory" => "string", # dir for frprep internal data

            # information about the dataset
            "language" => "string", # en, de
            "origin"=> "string",    # FrameNet, Salsa, or nothing
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
	  },
	  [ ] # variables
	  )
    
  end
end


 
