# -*- encoding: utf-8 -*-

require 'test/unit'
require 'functional/functional_test_helper'

class TestRosy < Test::Unit::TestCase
  include FunctionalTestHelper
  
  def setup
    @msg = "Rosy is doing bad, you've just broken something!"
  end
  def test_rosy_testing
    create_exp_file(ROSY_TEST_FILE)
    create_exp_file(PRP_TEST_FILE_ROSY_STD)
    execute("ruby -rubygems -I lib bin/rosy -t featurize -e #{ROSY_TEST_FILE} -d test")
    execute("ruby -rubygems -I lib bin/rosy -t test -e #{ROSY_TEST_FILE}")
    remove_exp_file(ROSY_TEST_FILE)
    remove_exp_file(PRP_TEST_FILE_ROSY_STD)
  end
end
