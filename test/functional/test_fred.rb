# -*- encoding: utf-8 -*-

require 'minitest/autorun'
require 'functional/functional_test_helper'

# Functional tests on Fred for refactoring's sake.
class TestFred < Minitest::Test
  include FunctionalTestHelper

  def setup
    @msg = "Fred is doing bad, you've just broken something!"
    @test_file = FRED_TEST_FILE
    @train_file = FRED_TRAIN_FILE
  end

  def test_fred_testing_featurization
    create_exp_file(@test_file)
    create_exp_file(PRP_TEST_FILE_FRED_STD)
    execute("ruby -I lib bin/fred -t featurize -e #{@test_file} -d test")
    remove_exp_file(@test_file)
    remove_exp_file(PRP_TEST_FILE_FRED_STD)
  end

  def test_fred_training_featurization
    create_exp_file(@train_file)
    create_exp_file(PRP_TRAIN_FILE_FRED_STD)
    execute("ruby -I lib bin/fred -t featurize -e #{@train_file} -d train")
    remove_exp_file(@train_file)
    remove_exp_file(PRP_TRAIN_FILE_FRED_STD)
  end

  def test_fred_testing_tests
    create_exp_file(@test_file)
    create_exp_file(PRP_TEST_FILE_FRED_STD)
    execute("ruby -I lib bin/fred -t test -e #{@test_file}")
    remove_exp_file(@test_file)
    remove_exp_file(PRP_TEST_FILE_FRED_STD)
  end

  def test_fred_training_train
    create_exp_file(@train_file)
    create_exp_file(PRP_TRAIN_FILE_FRED_STD)
    execute("ruby -I lib bin/fred -t train -e #{@train_file}")
    remove_exp_file(@train_file)
    remove_exp_file(PRP_TRAIN_FILE_FRED_STD)
  end

  def test_fred_training_split
    create_exp_file(@train_file)
    create_exp_file(PRP_TRAIN_FILE_FRED_STD)
    execute("ruby -I lib bin/fred -t split -e #{@train_file} --logID myLog --trainpercent 80")
    remove_exp_file(@train_file)
    remove_exp_file(PRP_TRAIN_FILE_FRED_STD)
  end

  def atest_fred_training_evaluation
  end

  def atest_fred_testing_evaluation
  end
end
