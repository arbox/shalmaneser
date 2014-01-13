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
    @ptb        = 'lib/frprep/interfaces/berkeley_interface.rb'
    #link_berkeley
    ENV['SHALM_BERKELEY_MODEL'] = 'sc_dash_labeled_1_smoothing.gr'
  end

  def teardown
    #unlink_berkeley
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

  # Testing input in different formats.
  def test_frprep_plaininput
    create_exp_file(PRP_PLAININPUT)
    execute("ruby -I lib bin/frprep -e #{PRP_PLAININPUT}")
    remove_exp_file(PRP_PLAININPUT)
  end

  def test_frprep_stxmlinput
    create_exp_file(PRP_STXMLINPUT)
    execute("ruby -I lib bin/frprep -e #{PRP_STXMLINPUT}")
    remove_exp_file(PRP_STXMLINPUT)
  end

  def test_frprep_tabinput
    create_exp_file(PRP_TABINPUT)
    execute("ruby -I lib bin/frprep -e #{PRP_TABINPUT}")
    remove_exp_file(PRP_TABINPUT)
  end

  def test_frprep_fncorpusxmlinput
    create_exp_file(PRP_FNCORPUSXMLINPUT)
    execute("ruby -I lib bin/frprep -e #{PRP_FNCORPUSXMLINPUT}")
    remove_exp_file(PRP_FNCORPUSXMLINPUT)
  end

  def test_frprep_fnxmlinput
    create_exp_file(PRP_FNXMLINPUT)
    execute("ruby -I lib bin/frprep -e #{PRP_FNXMLINPUT}")
    remove_exp_file(PRP_FNXMLINPUT)
  end

  # Testing output in different formats.
  # We test only on German input assuming English input to work.
  def test_frprep_stxmloutput
    create_exp_file(PRP_STXMLOUTPUT)
    execute("ruby -I lib bin/frprep -e #{PRP_STXMLOUTPUT}")
    remove_exp_file(PRP_STXMLOUTPUT)
  end

  def test_frprep_taboutput
    create_exp_file(PRP_TABOUTPUT)
    execute("ruby -I lib bin/frprep -e #{PRP_TABOUTPUT}")
    remove_exp_file(PRP_TABOUTPUT)
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
