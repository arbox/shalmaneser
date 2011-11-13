# -*- coding: utf-8 -*-

require 'test/unit'
require 'frprep/opt_parser'

include FrPrep

class TestOptParser < Test::Unit::TestCase

  def setup
    @valid_opts = ['--expfile', 'file.txt',
                   '--help'
                  ]
  end

  def test_public_methods
    assert_respond_to(OptParser, :parse)
  end

  # It should return a FrPrepConfigData object.
  def test_parse_method
    file = 'test/frprep/data/prp_test.salsa'
    input = ['-e', file]
    return_value = OptParser.parse(input)
    assert(return_value.instance_of?(FrPrepConfigData))
  end

end
