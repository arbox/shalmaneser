require 'erb'

module FunctionalTestHelper

  PRP_TEST_FILE   = 'test/functional/sample_experiment_files/prp_test.salsa'
  PRP_TEST_FILE_STD   = 'test/functional/sample_experiment_files/prp_test.salsa.standalone'
  PRP_TRAIN_FILE  = 'test/functional/sample_experiment_files/prp_train.salsa'
  PRP_TRAIN_FILE_STD  = 'test/functional/sample_experiment_files/prp_train.salsa.standalone'
  FRED_TEST_FILE  = 'test/functional/sample_experiment_files/fred_test.salsa'
  FRED_TRAIN_FILE = 'test/functional/sample_experiment_files/fred_train.salsa'
  ROSY_TEST_FILE  = 'test/functional/sample_experiment_files/rosy_test.salsa'
  ROSY_TRAIN_FILE = 'test/functional/sample_experiment_files/rosy_train.salsa'

  # Run an external process for functional testing and check the return code.
  # <system> returns <true> if the external code exposes no errors.
  # <@msg> is defined for every test object.
  def execute(cmd)
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
