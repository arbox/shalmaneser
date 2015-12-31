require 'minitest/autorun'
require 'configuration/rosy_config_data'
require 'functional/functional_test_helper'

class TestRosyConfigData < Minitest::Test
  include Shalmaneser::Configuration
  include FunctionalTestHelper

  def test_for_the_wrong_exp_id
    create_exp_file(ROSY_WRONG_ID)
    e = assert_raises(ConfigurationError) do
      RosyConfigData.new(ROSY_WRONG_ID)
    end
    assert_match('experiment ID', e.message)
  ensure
    remove_exp_file(ROSY_WRONG_ID)
  end
end
