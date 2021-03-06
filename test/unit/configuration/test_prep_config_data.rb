require 'minitest/autorun'
require 'configuration/frappe_config_data'
require 'functional/functional_test_helper'

class TestFrappeConfigData < Minitest::Test
  include Shalmaneser::Configuration
  include FunctionalTestHelper

  def test_for_missing_frprep_directory
    create_exp_file(PRP_MISSING_DIR)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_MISSING_DIR)
    end
    assert_match('frprep_directory', e.message)
  ensure
    remove_exp_file(PRP_MISSING_DIR)
  end

  def test_for_missing_frprep_input_directory
    create_exp_file(PRP_MISSING_INPUT_DIR)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_MISSING_INPUT_DIR)
    end
    assert_match('directory_input', e.message)
  ensure
    remove_exp_file(PRP_MISSING_INPUT_DIR)
  end

  def test_for_missing_frprep_preprocessed_directory
    create_exp_file(PRP_MISSING_PRP_DIR)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_MISSING_PRP_DIR)
    end
    assert_match('directory_preprocessed', e.message)
  ensure
    remove_exp_file(PRP_MISSING_PRP_DIR)
  end

  def test_for_format_clash
    create_exp_file(PRP_FORMAT_CLASH)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_FORMAT_CLASH)
    end
    assert_match('tabformat_output', e.message)
  ensure
    remove_exp_file(PRP_FORMAT_CLASH)
  end

  def test_for_nonexistent_experiment_file
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new('some_nonexistent_file.exp')
    end
    assert_match('open', e.message)
  end

  def test_for_missing_tagger
    create_exp_file(PRP_MISSING_TAGGER)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_MISSING_TAGGER)
    end
    assert_match('pos_tagger', e.message)
  ensure
    remove_exp_file(PRP_MISSING_TAGGER)
  end

  def test_for_missing_lemmatizer
    create_exp_file(PRP_MISSING_LEMMATIZER)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_MISSING_LEMMATIZER)
    end
    assert_match('lemmatizer', e.message)
  ensure
    remove_exp_file(PRP_MISSING_LEMMATIZER)
  end

  def test_for_the_wrong_encoding
    create_exp_file(PRP_WRONG_ENC)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_WRONG_ENC)
    end
    assert_match('encoding', e.message)
  ensure
    remove_exp_file(PRP_WRONG_ENC)
  end

  def test_for_the_wrong_input_format
    create_exp_file(PRP_WRONG_FORMAT)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_WRONG_FORMAT)
    end
    assert_match('format', e.message)
  ensure
    remove_exp_file(PRP_WRONG_FORMAT)
  end

  def test_for_the_wrong_exp_id
    create_exp_file(PRP_WRONG_ID)
    e = assert_raises(ConfigurationError) do
      FrappeConfigData.new(PRP_WRONG_ID)
    end
    assert_match('experiment ID', e.message)
  ensure
    remove_exp_file(PRP_WRONG_ID)
  end
end
