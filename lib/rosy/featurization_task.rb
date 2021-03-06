# Salsa packages
require 'external_systems'
require "ruby_class_extensions"
require 'logging'
require 'definitions'
require_relative 'failed_parses'
require_relative 'feature_info'
require_relative 'input_data'
require 'configuration/rosy_config_data'
require_relative 'task' # !
require_relative 'training_test_table'

module Shalmaneser
  module Rosy
    # RosyFeaturize
    # KE, SP April 05
    #
    # One of the main task modules of Rosy:
    # featurize data and store it in the database
    class FeaturizationTask < Task
      # RosyConfigData object: experiment description
      # hash: runtime argument option (string) -> value (string)
      # RosyTrainingTestTable object
      def initialize(exp, opts, ttt_obj)
        ##
        # remember the experiment description

        @exp = exp
        @ttt_obj = ttt_obj

        @test_id = DEFAULT_TEST_ID
        @split_id = nil
        @append_rather_than_overwrite = false

        opts.each do |opt, arg|
          case opt
          when "--dataset"
            unless ["train", "test"].include? arg
              raise "--dataset needs to be either 'train' or 'test'"
            end
            @dataset = arg
          when "--logID"
            @split_id = arg
          when "--testID"
            @test_id = arg
          when "--append"
            @append_rather_than_overwrite = true
          end
        end

        # further sanity checks
        if @dataset.nil? && @split_id.nil?
          $stderr.puts "I need either a dataset ('train' or 'test', option --dataset) or a splitID (option --logID) in the command line."
          raise
        end

        # announce the task
        LOGGER.info "Rosy experiment #{@exp.get("experiment_ID")}: Featurization of dataset #{@dataset}"

        ##
        # add preprocessing information to the experiment file object
        # @note AB: Commented out due to separation of PrepConfigData.
        # if @dataset
        #   preproc_parameter = "preproc_descr_file_" + @dataset
        # else
        #   # split data
        #   preproc_parameter = "preproc_descr_file_train"
        # end
        # preproc_expname = @exp.get(preproc_parameter)
        # if not(preproc_expname)
        #   $stderr.puts "Please set the name of the preprocessing exp. file name"
        #   $stderr.puts "in the experiment file, parameter #{preproc_parameter}"
        #   exit 1
        # elsif not(File.readable?(preproc_expname))
        #   $stderr.puts "Error in the experiment file:"
        #   $stderr.puts "Parameter #{preproc_parameter} has to be a readable file."
        #   exit 1
        # end
        # preproc_exp = FrappeConfigData.new(preproc_expname)
        # @exp.adjoin(preproc_exp)

        ###
        # find appropriate class for interpreting syntactic structures
        @interpreter_class = ::Shalmaneser::ExternalSystems.get_interpreter_according_to_exp(@exp)

        ###
        # prepare featurization
        if @dataset
          unless @exp.get("directory_input_" + @dataset)
            raise "Please set 'directory_input_train' and/or 'directory_input_test' in your experiment file."
          end
          prepare_main_featurization(File.existing_dir(@exp.get("directory_input_" + @dataset)), @test_id)
        end
      end

      #####
      # perform
      #
      # compute features and write them to the DB table
      def perform
        # compute features for main or test table
        perform_main_featurization if @dataset
      end

      #####################
      private

      ###
      # prepare_main_featurization
      #
      # this is an auxiliary of the new() method:
      # the part of the initialization that is performed
      # if we start a new main/test table,
      # but not if we only re-featurize the split tables
      # @param datapath string: name of directory with SalsaTigerXML input data
      # @param testID string: name of this testset, or nil for no testset
      def prepare_main_featurization(datapath, testID)
        # sanity check
        unless datapath
          raise "No input path given in the preprocessing experiment file.\n" +
                "Please set 'directory_preprocessed there."
        end
        unless File.exist?(datapath) && File.directory?(datapath)
          raise "I cannot read the input path " + datapath
        end

        ##
        # determine features and feature formats

        # create feature extraction wrapper object
        @input_obj = InputData.new(@exp, @dataset, @ttt_obj.feature_info, @interpreter_class, datapath)

        # zip and store input data
        rosy_dir = File.new_dir(@exp.instantiate("rosy_dir", "exp_ID" => @exp.get("experiment_ID")))
        zipped_input_dir = File.new_dir(rosy_dir, "input_dir", @dataset)

        unless @append_rather_than_overwrite
          # remove old input data
          Dir[zipped_input_dir + "*.gz"].each { |file| File.delete(file) }
        end
        # store new input data
        Dir[datapath + "*.xml"].each do |filename|
          %x{gzip -c #{filename} > #{zipped_input_dir}#{File.basename(filename)}.gz}
        end

        ##
        # open appropriate DB table
        case @dataset
        when "train"
          # open main table
          if @append_rather_than_overwrite
            # add to existing DB table
            @db_table = @ttt_obj.existing_train_table
          else
            # start new DB table
            @db_table = @ttt_obj.new_train_table
          end
        when "test"
          if @append_rather_than_overwrite
            # add to existing DB table
            @db_table = @ttt_obj.existing_test_table(testID)
          else
            # start new DB table
            @db_table = @ttt_obj.new_test_table(testID)
          end
        else
          raise "Shouldn't be here"
        end
      end

      ##########
      # helper method of perform():
      # the part of featurization that is performed
      # if we start a new main/test table,
      # but not if we only re-featurize the split tables
      def perform_main_featurization
        ###########
        # write state to log
        log_filename =
          File.new_filename(@exp.instantiate("rosy_dir", "exp_ID" => @exp.get("experiment_ID")), "featurize.log")

        ##############
        # input object, compute features for **PHASE 1**:
        #
        # make features for each instance:
        # features that can be computed from this instance alone

        LOGGER.info "[#{Time.now}] Featurize: Start phase 1 feature extraction."

        # list of pairs [column_name(string), value(whatever)]
        @input_obj.each_instance_phase1 do |feature_list|
          # write instance to @db_table
          @db_table.insert_row(feature_list)
        end

        # during featurisation, an Object with info about failed parses has been created
        # now get this object and store it in a file in the datadir

        failed_parses_obj = @input_obj.get_failed_parses

        failed_parses_filename =
          File.new_filename(@exp.instantiate("rosy_dir", {"exp_ID" => @exp.get("experiment_ID")}),
                            @exp.instantiate("failed_file", {"exp_ID" => @exp.get("experiment_ID"), "split_ID" => "none", "dataset" => "none"}))

        failed_parses_obj.save(failed_parses_filename)

        ################
        # input object, compute features for **PHASE 2**:
        #
        # based on all features from Phase 1, make additional features

        LOGGER.info "[#{Time.now}] Featurize: Start phase 2 feature extraction."

        iterator = Iterator.new(@ttt_obj, @exp, @dataset, {"testID" => @test_id, "splitID" => @split_id, "xwise" => "frame"})

        iterator.each_group do |dummy1, dummy2|
          view = iterator.get_a_view_for_current_group("*")

          @input_obj.each_phase2_column(view) do |feature_name, feature_values|
            view.update_column(feature_name, feature_values)
          end

          view.close
        end

        #########
        # finished!!
        #
        LOGGER.info "[#{Time.now}] Featurize: Finished"
      end
    end
  end
end
