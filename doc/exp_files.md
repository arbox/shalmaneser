# Experiment file description
The whole work with Shalmaneser and its submodules is governed be experiment files.

In an experiment file all feature specifications have the form:

    feature_name = feature_value

The ``feature_name`` is a string without spaces. And the ``feature_value``  may include spaces, depending on the feature type (see below).

To include a comment in a config file, start the comment line with ``#``.

Features are typed. The following ``normal`` types are supported:

- ``bool``,
- ``float``,
- ``integer``,
- ``string``

For the ``#get`` method, with which features in the ``ConfigData`` object are accessed, the values are transformed from the strings in the experiment file to the appropriate Ruby class.

Other types:

- ``pattern``,
- `` list``.

Feature of the ``pattern`` type are features that may include variables in <> brackets. When this feature is accesssed, values for these variables are given, i.e. this pattern has to be instantiated.

For example, given a feature

    fileformat = features.<type>.train

and method call

    instantiate("fileformat", "type" => "path")
 
what is returned is a String ``features.path.train``.

The ``list`` type is the only feature type where more than one feature specification with the same feature_name is allowed. The right-hand sides of a list feature are stored in an array.

Given a ``list`` feature ``bla``, if the experiment file contains:
  
    bla = blupp 1 2
    bla = la di da

the list feature ``bla`` is represented as follows:

    @features['bla'] = [['blupp', 1,2], ['la', 'di', 'da']]
 
For comfortable access to a list feature, arbitrary access functions for list features can be defined.

## Fred and Rosy Preprocessor (aka frprep|prep)

    "prep_experiment_ID" => "string", # experiment identifier
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

## Frame Disambiguation System (aka Fred)
    "experiment_ID" => "string", # experiment ID
    "enduser_mode" => "bool", # work in enduser mode? (disallowing many things)

    "preproc_descr_file_train" => "string", # path to preprocessing files
    "preproc_descr_file_test" => "string",
    "directory_output" => "string", # path to Salsa/Tiger XML output directory

    "verbose" => "bool" ,     # print diagnostic messages?
    "apply_to_all_known_targets" => "bool", # apply to all known targets rather than the ones with a frame?

    "fred_directory" => "string",# directory for internal info
    "classifier_dir" => "string", # write classifiers here

    "classifier" => "list",  # classifiers

    "dbtype" => "string",    # "mysql" or ("sqlite" doesn't work for now)

    "host" => "string",      # DB access: sqlite only
    "user" => "string",
    "passwd" => "string",
    "dbname" => "string",

    # featurization info
    "feature" => "list",     # which features to use for the classifier?
    "binary_classifiers" => "bool",# make binary rather than n-ary clasifiers?
    "negsense" => "string",  # binary classifier: negative sense is..?
    "numerical_features" => "string", # do what with numerical features?

    # what to do with items that have multiple senses?
    # 'binarize': binary classifiers, and consider positive
    #          if the sense is among the gold senses
    # 'join' : make one joint sense
    # 'repeat' : make multiple occurrences of the item, one sense per occ
    # 'keep' : keep as separate labels
    #
    # multilabel: consider as assigned all labels
    # above a certain confidence threshold?
    "handle_multilabel" => "string",
    "assignment_confidence_threshold" => "float",

    # single-sentence context?
    "single_sent_context" => "bool",

    # noncontiguous input? then we need access to a larger corpus
    # NOTE: This doesn't work for now.
    "noncontiguous_input" => "bool"
    "larger_corpus_dir" => "string"
    "larger_corpus_format" => "string"
    "larger_corpus_encoding" => "string"
## Role Assignment System (aka Rosy)
    # features
    "feature" => "list",
    "classifier" => "list",

    "verbose" => "bool" ,
    "enduser_mode" => "bool", 

    "experiment_ID" => "string",

    "directory_input_train" => "string",
    "directory_input_test" => "string",
    "directory_output" => "string", 

    "preproc_descr_file_train" => "string",
    "preproc_descr_file_test" => "string",
    "external_descr_file"    => "string",

    "dbtype" => "string",    # "mysql" ("sqlite" doen't work for now)

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

    "prune" => "string",       # pruning prior to argrec?
