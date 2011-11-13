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
end
