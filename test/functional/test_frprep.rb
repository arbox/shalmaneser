# -*- encoding: utf-8 -*-

require 'minitest/autorun'
require 'functional/functional_test_helper'
# require 'fileutils' # File.delete(), File.rename(), File.symlink()
require 'digest'

class TestFrprep < Minitest::Test
  include FunctionalTestHelper

  def setup
    @msg        = "FrPrep is doing bad, you've just broken something!"
    @test_file  = PRP_TEST_FILE
    @train_file = PRP_TRAIN_FILE
    @ptb        = 'lib/frappe/interfaces/berkeley_interface.rb'
    # link_berkeley
    ENV['SHALM_BERKELEY_MODEL'] = 'sc_dash_labeled_1_smoothing.gr'
  end

  def teardown
    # unlink_berkeley
  end

  def test_frprep_testing
    create_exp_file(@test_file)
    execute("ruby -I lib bin/frappe -e #{@test_file}")
    remove_exp_file(@test_file)
  end

  def test_frprep_training
    create_exp_file(@train_file)
    execute("ruby -I lib bin/frappe -e #{@train_file}")
    remove_exp_file(@train_file)
  end

  # Testing input in different formats.
  def test_frprep_plaininput
    create_exp_file(PRP_PLAININPUT)
    execute("ruby -I lib bin/frappe -e #{PRP_PLAININPUT}")
    remove_exp_file(PRP_PLAININPUT)
  end

  def test_frprep_stxmlinput
    create_exp_file(PRP_STXMLINPUT)
    execute("ruby -I lib bin/frappe -e #{PRP_STXMLINPUT}")
    remove_exp_file(PRP_STXMLINPUT)
  end

  def test_frprep_tabinput
    create_exp_file(PRP_TABINPUT)
    execute("ruby -I lib bin/frappe -e #{PRP_TABINPUT}")
    remove_exp_file(PRP_TABINPUT)
  end

  def test_frprep_fncorpusxmlinput
    create_exp_file(PRP_FNCORPUSXMLINPUT)
    execute("ruby -I lib bin/frappe -e #{PRP_FNCORPUSXMLINPUT}")
    remove_exp_file(PRP_FNCORPUSXMLINPUT)
  end

  def test_frprep_fnxmlinput
    create_exp_file(PRP_FNXMLINPUT)
    execute("ruby -I lib bin/frappe -e #{PRP_FNXMLINPUT}")
    remove_exp_file(PRP_FNXMLINPUT)
  end

  # Testing output in different formats.
  # We test only on German input assuming English input to work.
  #
  def test_frprep_plain2stxml
    create_exp_file(PRP_STXMLOUTPUT)
    execute("ruby -I lib bin/frappe -e #{PRP_STXMLOUTPUT}")
    path = 'stxmloutput/0.xml'
    d_real = Digest::SHA256.file "test/functional/output/#{path}"
    d_gold = Digest::SHA256.file "test/functional/gold_output/#{path}"
    assert_equal(d_gold, d_real, 'The STXML output diverges from the etalon!')
    remove_exp_file(PRP_STXMLOUTPUT)
  end

  def test_frprep_stxml2stxml
    create_exp_file(PRP_STXML2STXML)
    execute("ruby -I lib bin/frappe -e #{PRP_STXML2STXML}")
    path = 'stxml2stxml/0.xml'
    d_real = Digest::SHA256.file "test/functional/output/#{path}"
    d_gold = Digest::SHA256.file "test/functional/gold_output/#{path}"
    assert_equal(d_gold, d_real, 'The STXML output diverges from the etalon!')
    remove_exp_file(PRP_STXML2STXML)
  end

  def test_frprep_plain2tab
    create_exp_file(PRP_TABOUTPUT)
    execute("ruby -I lib bin/frappe -e #{PRP_TABOUTPUT}")
    remove_exp_file(PRP_TABOUTPUT)
  end



  # This test has been created to ensure testing facilities for missing
  # arguments are moved correctly to the OptionParser.
  # @see Unit test for Frappe's OptionParser.
  def test_missing_experiment_definitions
    create_exp_file(PRP_MISSING_DIR)
    # Important to put STDERR on the return string!
    status = `ruby -I lib bin/frappe -e #{PRP_MISSING_DIR} 2>&1`
    assert_match('frprep_dir', status, '<frprep_directory> is missing in the experiment file')
    remove_exp_file(PRP_MISSING_DIR)
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
