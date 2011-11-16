# -*- encoding: utf-8 -*-

require 'test/unit'
require 'functional/functional_test_helper'

class TestFred < Test::Unit::TestCase

  include FunctionalTestHelper

  def setup
    @msg = "Fred is doing bad, you've just broken something!"
    @test_file = FRED_TEST_FILE
    @train_file = FRED_TRAIN_FILE
  end

  def test_fred_testing
    create_exp_file(@test_file)
    create_exp_file(PRP_TEST_FILE)
    execute("ruby -I lib bin/fred -t featurize -e #{@test_file} -d test")
    execute("ruby -I lib bin/fred -t test -e #{@test_file}")
    remove_exp_file(@test_file)
    remove_exp_file(PRP_TEST_FILE)
  end

  def test_fred_training
    create_exp_file(@train_file)
    create_exp_file(PRP_TRAIN_FILE)
    execute("ruby -I lib bin/fred -t featurize -e #{@train_file} -d train")
    execute("ruby -I lib bin/fred -t train -e #{@train_file}")
    remove_exp_file(@train_file)
    remove_exp_file(PRP_TRAIN_FILE)
  end
end
