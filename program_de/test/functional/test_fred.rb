# -*- encoding: utf-8 -*-

require 'test/unit'

class TestFred < Test::Unit::TestCase

  def test_fred_testing
    val = system('ruby -I lib bin/fred -t featurize -e SampleExperimentFiles.salsa/fred_test.salsa -d test')
    assert(val, "Fred is doing bad, you've just broken something!")
    val = system('ruby -I lib bin/fred -t test -e SampleExperimentFiles.salsa/fred_test.salsa')
    assert(val, "Fred is doing bad, you've just broken something!")
    
  end

  def test_fred_training
    val = system('ruby -I lib bin/fred -t featurize -e SampleExperimentFiles.salsa/fred_train.salsa -d train')
    assert(val, "Fred is doing bad, you've just broken something!")
    val = system('ruby -I lib bin/fred -t train -e SampleExperimentFiles.salsa/fred_train.salsa')
    assert(val, "Fred is doing bad, you've just broken something!")
  end
end
