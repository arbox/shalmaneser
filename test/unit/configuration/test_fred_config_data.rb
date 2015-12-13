require 'minitest/autorun'
require 'common/configuration/prep_config_data'
require 'functional/functional_test_helper'

class TestFrappeConfigData < Minitest::Test
  include Shalmaneser::Configuration
  include FunctionalTestHelper

  def test_for_the_wrong_task
  end
end
