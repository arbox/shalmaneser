require 'minitest/autorun'
require 'configuration/frappe_config_data'
require 'functional/functional_test_helper'

class TestFrappeConfigData < Minitest::Test
  include ::Shalmaneser::Configuration
  include FunctionalTestHelper

  def atest_for_the_wrong_task
    create_exp_file(FRED_TEST_FILE)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_MISSING_DIR)
    end
    assert_match('frprep_directory', e.message)
  ensure
    remove_exp_file(PRP_MISSING_DIR)
  end
end
