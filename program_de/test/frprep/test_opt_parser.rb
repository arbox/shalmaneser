# -*- coding: utf-8 -*-

require 'test/unit'
require 'stringio' # for helper methods
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

  # It should reject the empty input and exit.
  def test_empty_input
    out, err = intercept_output do
      assert_raises(SystemExit) { OptParser.parse([]) }
    end
    assert_match(/You have to provide some options./, err)
  end

end
################################################################################
# It is a helper method, many testable units provide some verbose output
# to stderr and/or stdout. It is usefull to suppress any kind of verbosity.
def quietly(&b)
  begin
    orig_stderr = $stderr.clone
    orig_stdout = $stdout.clone
    $stderr.reopen(File.new('/dev/null', 'w'))
    $stdout.reopen(File.new('/dev/null', 'w'))
    b.call
  ensure
    $stderr.reopen(orig_stderr)
    $stdout.reopen(orig_stdout)
  end
end

# It is a helper method for handling stdout and stderr as strings.
def intercept_output
  orig_stdout = $stdout
  orig_stderr = $stderr
  $stdout = StringIO.new
  $stderr = StringIO.new
  
  yield
  
  return $stdout.string, $stderr.string
ensure
  $stdout = orig_stdout
  $stderr = orig_stderr
end

