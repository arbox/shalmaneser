# -*- encoding: utf-8 -*-

require 'test/unit'

class TestFrprep < Test::Unit::TestCase

  def test_for_errors
    assert(
           system('ruby bin/frprep -e SampleExperimentFiles.salsa/prp_test.salsa'),
           "FrPrep is doing bad, you've just broken something!"
           )
  end
end
