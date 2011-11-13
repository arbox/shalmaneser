# -*- encoding: utf-8 -*-

require 'test/unit'

class TestRosy < Test::Unit::TestCase

  def test_for_errors
    val = system('ruby -rubygems -I lib bin/rosy -t featurize -e SampleExperimentFiles.salsa/rosy.salsa -d test')
    assert(val, "Rosy is doing bad, you've just broken something!")
    val = system('ruby -rubygems -I lib bin/rosy -t test -e SampleExperimentFiles.salsa/rosy.salsa')
    assert(val, "Rosy is doing bad, you've just broken something!")
    
  end
end
