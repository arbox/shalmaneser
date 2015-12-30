require_relative 'abstract_feature_extractor'
require 'configuration/external_config_data'

class ExternalFeatureExtractor < AbstractFeatureExtractor

  @@warning_uttered = false

  ####
  # initialization:
  #
  # read experiment file for external interfaces
  # @param [RosyConfigData] exp object
  def initialize(exp, interpreter_class)
    @exp_rosy = exp
    @@interpreter_class = interpreter_class

    unless @exp_rosy.get("external_descr_file")
      unless @@warning_uttered
        $stderr.puts "Warning: Cannot compute external feature"
        $stderr.puts "since 'external_descr_file' has not been set"
        $stderr.puts "in the Rosy experiment file."
        @@warning_uttered = true
      end

      @exp_external = nil
      return
    end

    @exp_external = Shalmaneser::Configuration::ExternalConfigData.new(@exp_rosy.get("external_descr_file"))
  end
end
