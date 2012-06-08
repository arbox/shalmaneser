# -*- encoding: utf-8 -*-

require 'test/unit'
require 'functional/functional_test_helper'
#require 'fileutils' # File.delete(), File.rename(), File.symlink()

class TestFrprep < Test::Unit::TestCase

  include FunctionalTestHelper

  def setup
    @msg        = "FrPrep is doing bad, you've just broken something!"
    @test_file  = PRP_TEST_FILE
    @train_file = PRP_TRAIN_FILE
    @ptb        = 'lib/common/BerkeleyInterface.rb'
#    link_berkeley
  end

  def teardown
#    unlink_berkeley
  end
  def test_frprep_testing
    create_exp_file(@test_file)
    execute("ruby -I lib bin/frprep -e #{@test_file}")
    remove_exp_file(@test_file)
  end

  def test_frprep_training
    create_exp_file(@train_file)
    execute("ruby -I lib bin/frprep -e #{@train_file}")
    remove_exp_file(@train_file)
  end

  private
  # Berkeley Parser takes a long time which is bad for testing.
  # We ran it once and reuse the result file in our tests.
  # Before every test we link the Berkeley interface to a stub
  # with the BP invocation switched off.
  def link_berkeley
    File.rename(@ptb, "#{@ptb}.bak")
    File.symlink(
                 File.expand_path('test/functional/berkeley_interface.rb.stub'),
                 File.expand_path(@ptb)
                 )
  end

  # After testing we bring the right interface back, the program remains intact.
  def unlink_berkeley
    File.delete(@ptb)
    File.rename("#{@ptb}.bak", @ptb)
  end
end
