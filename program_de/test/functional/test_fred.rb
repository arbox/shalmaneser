# -*- encoding: utf-8 -*-

require 'test/unit'
require 'functional/functional_test_helper'

class TestFred < Test::Unit::TestCase

  include FunctionalTestHelper

  def setup
    @msg = "Fred is doing bad, you've just broken something!"
    @test_file = 'test/functional/sample_experiment_files/fred_test.salsa'
    @train_file = 'test/functional/sample_experiment_files/fred_train.salsa'
  end

  def test_fred_testing
    create_exp_file(@test_file)
    execute("ruby -I lib bin/fred -t featurize -e #{@test_file} -d test")
    execute("ruby -I lib bin/fred -t test -e #{@test_file}")
    remove_exp_file(@test_file)
  end

  def test_fred_training
    create_exp_file(@train_file)
    execute("ruby -I lib bin/fred -t featurize -e #{@train_file} -d train")
    execute("ruby -I lib bin/fred -t train -e #{@train_file}")
    remove_exp_file(@train_file)
  end
end
