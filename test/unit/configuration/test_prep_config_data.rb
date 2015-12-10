require 'minitest/autorun'
require 'common/configuration/prep_config_data'
require 'functional/functional_test_helper'

class TestFrappeConfigData < Minitest::Test
  include Shalm::Configuration
  include FunctionalTestHelper

  def test_for_missing_frprep_directory
    create_exp_file(PRP_MISSING_DIR)
    e = assert_raises(ConfigurationError) do
      FrPrepConfigData.new(PRP_MISSING_DIR)
    end
    assert_match('frprep_directory', e.message)
  ensure
    remove_exp_file(PRP_MISSING_DIR)
  end

  def test_for_missing_frprep_input_directory
    create_exp_file(PRP_MISSING_INPUT_DIR)
    e = assert_raises(ConfigurationError) do
      FrPrepConfigData.new(PRP_MISSING_INPUT_DIR)
    end
    assert_match('directory_input', e.message)
  ensure
    remove_exp_file(PRP_MISSING_INPUT_DIR)
  end
end
