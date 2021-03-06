require 'erb'

# Setting $DEBUG will produce all external output.
# Otherwise it is suppreced.
module FunctionalTestHelper
  PREF = 'test/functional/sample_experiment_files'

  PRP_TEST_FILE            = "#{PREF}/prp_test.salsa"
  PRP_TEST_FILE_FRED_STD   = "#{PREF}/prp_test.salsa.fred.standalone"
  PRP_TEST_FILE_ROSY_STD   = "#{PREF}/prp_test.salsa.rosy.standalone"
  PRP_TRAIN_FILE           = "#{PREF}/prp_train.salsa"
  PRP_TRAIN_FILE_FRED_STD  = "#{PREF}/prp_train.salsa.fred.standalone"
  PRP_TRAIN_FILE_ROSY_STD  = "#{PREF}/prp_train.salsa.rosy.standalone"

  FRED_TEST_FILE  = 'test/functional/sample_experiment_files/fred_test.salsa'
  FRED_TRAIN_FILE = 'test/functional/sample_experiment_files/fred_train.salsa'

  # Testing input for Preprocessor.
  PRP_PLAININPUT         = "#{PREF}/prp_plaininput"
  PRP_STXMLINPUT         = "#{PREF}/prp_stxmlinput"
  PRP_TABINPUT           = "#{PREF}/prp_tabinput"
  PRP_FNXMLINPUT         = "#{PREF}/prp_fnxmlinput"
  PRP_FNCORPUSXMLINPUT   = "#{PREF}/prp_fncorpusxmlinput"
  PRP_MISSING_DIR        = "#{PREF}/prp_missing_dir"
  PRP_MISSING_INPUT_DIR  = "#{PREF}/prp_missing_input_dir"
  PRP_MISSING_PRP_DIR    = "#{PREF}/prp_missing_prp_dir"
  PRP_FORMAT_CLASH       = "#{PREF}/prp_format_clash"
  PRP_MISSING_TAGGER     = "#{PREF}/prp_missing_tagger"
  PRP_MISSING_LEMMATIZER = "#{PREF}/prp_missing_lemmatizer"
  PRP_WRONG_ENC          = "#{PREF}/prp_wrong_enc"
  PRP_WRONG_FORMAT       = "#{PREF}/prp_wrong_format"
  PRP_WRONG_ID           = "#{PREF}/prp_wrong_id"

  # Testing output for Preprocessor.
  PRP_STXMLOUTPUT = "#{PREF}/prp_stxmloutput"
  PRP_TABOUTPUT   = "#{PREF}/prp_taboutput"
  PRP_STXML2STXML = "#{PREF}/prp_stxml2stxml"

  # Testing input for Rosy.
  ROSY_WRONG_ID = "#{PREF}/rosy_wrong_id"

  # General Rosy tests.
  ROSY_TEST_FILE  = "#{PREF}/rosy_test.salsa"
  ROSY_TRAIN_FILE = "#{PREF}/rosy_train.salsa"

  # Testing SQLite with Rosy.
  ROSY_TEST_SQLITE  = "#{PREF}/rosy_test.sqlite.salsa"
  ROSY_TRAIN_SQLITE = "#{PREF}/rosy_train.sqlite.salsa"

  # Run an external process for functional testing and check the return code.
  # <system> returns <true> if the external code exposes no errors.
  # <@msg> is defined for every test object.
  # @param cmd [String]
  def execute(cmd)
    $DEBUG = true
    unless $DEBUG
      cmd = cmd + ' 1>/dev/null 2>&1'
    end
    status = system(cmd)
    assert(status, @msg)
  end

  # Create a temporary exp file only for this test.
  # Shalmaneser needs absolute paths, we provide them in exp files
  # using templating.
  def create_exp_file(file)
    template = File.read("#{file}.erb")
    text = ERB.new(template).result
    File.open(file, 'w') do |f|
      f.write(text)
    end
  end

  def remove_exp_file(file)
    File.delete(file)
  end
end
