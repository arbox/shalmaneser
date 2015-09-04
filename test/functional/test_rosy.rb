# -*- encoding: utf-8 -*-

require 'minitest/autorun'
require 'functional/functional_test_helper'

class TestRosy < Minitest::Test
  include FunctionalTestHelper

  def setup
    @msg = "Rosy is doing bad, you've just broken something!"
  end

  def test_rosy_testing
    create_exp_file(ROSY_TEST_FILE)
    create_exp_file(PRP_TEST_FILE_ROSY_STD)
    execute("ruby -I lib bin/rosy -t featurize -e #{ROSY_TEST_FILE} -d test")
    execute("ruby -I lib bin/rosy -t test -e #{ROSY_TEST_FILE}")
    remove_exp_file(ROSY_TEST_FILE)
    remove_exp_file(PRP_TEST_FILE_ROSY_STD)
  end

  def test_rosy_training
    create_exp_file(ROSY_TRAIN_FILE)
    create_exp_file(PRP_TRAIN_FILE_ROSY_STD)
    execute("ruby -rubygems -I lib bin/rosy -t featurize -e #{ROSY_TRAIN_FILE} -d train")
    execute("ruby -rubygems -I lib bin/rosy -t train -e #{ROSY_TRAIN_FILE} -s argrec")
    execute("ruby -rubygems -I lib bin/rosy -t train -e #{ROSY_TRAIN_FILE} -s arglab")
    remove_exp_file(ROSY_TRAIN_FILE)
    remove_exp_file(PRP_TRAIN_FILE_ROSY_STD)
  end

  def test_rosy_training_onestep
    create_exp_file(ROSY_TRAIN_FILE)
    create_exp_file(PRP_TRAIN_FILE_ROSY_STD)
    execute("ruby -rubygems -I lib bin/rosy -t featurize -e #{ROSY_TRAIN_FILE} -d train")
    execute("ruby -rubygems -I lib bin/rosy -t train -e #{ROSY_TRAIN_FILE} -s onestep")
    remove_exp_file(ROSY_TRAIN_FILE)
    remove_exp_file(PRP_TRAIN_FILE_ROSY_STD)
  end
end
