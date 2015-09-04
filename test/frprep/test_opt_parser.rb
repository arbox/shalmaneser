# -*- coding: utf-8 -*-

require 'minitest/autorun'
require 'stringio' # for helper methods
require 'frprep/opt_parser'

include FrPrep

class TestOptParser < Minitest::Test

  def setup
    @exp_file = 'test/frprep/data/prp_test.salsa'
    @valid_opts = ['--expfile', @exp_file,
                   '--help'
                  ]
  end

  def test_public_methods
    assert_respond_to(OptParser, :parse)
  end

  # It should return a FrPrepConfigData object.
  def test_parse_method
    input = ['-e', @exp_file]
    return_value = OptParser.parse(input)
    assert(return_value.instance_of?(FrPrepConfigData))
  end

  # It should reject the empty input and exit.
  def test_empty_input
    _out, err = intercept_output do
      assert_raises(SystemExit) { OptParser.parse([]) }
    end
    assert_match(/You have to provide some options./, err)
  end

  # It should accept correct options.
  # Invalid options is the matter of OptionParser itself,
  # do not test it here.
  # We test only, that OP exits and does not raise an exception.
  def test_accept_correct_options
    # this options we should treat separately
    @valid_opts.delete('--help')

    _stdout, stderr = intercept_output do
      assert_raises(SystemExit) { OptParser.parse(['--invalid-option']) }
    end

    assert_match(/You have provided an invalid option:/, stderr)
  end

  # It should successfully exit with some options.
  def test_successful_exit
    quietly do
      success_args = ['-h', '--help']
      success_args.each do |arg|
        assert_raises(SystemExit) { OptParser.parse(arg.split) }
      end
    end
  end

end
################################################################################
# It is a helper method, many testable units provide some verbose output
# to stderr and/or stdout. It is usefull to suppress any kind of verbosity.
def quietly(&b)
  orig_stderr = $stderr.clone
  orig_stdout = $stdout.clone
  $stderr.reopen(File.new('/dev/null', 'w'))
  $stdout.reopen(File.new('/dev/null', 'w'))
  b.call
ensure
  $stderr.reopen(orig_stderr)
  $stdout.reopen(orig_stdout)
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
