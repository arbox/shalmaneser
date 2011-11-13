# -*- encoding: utf-8 -*-

# AB, 2011-11-13

#require 'optparse' # for reimplementation
require 'getoptlong'
require "fred/FredConfigData"

module Fred

  # This class parses options for Fred.
  class OptParser
    def self.parse(cmd_opts)
      tasks = {
        "featurize" => [ [ '--dataset', '-d', GetoptLong::REQUIRED_ARGUMENT], # set to featurize: 'train' or 'test'
                         [ "--append", "-A", GetoptLong::NO_ARGUMENT]
                       ],
        "refeaturize" => [ [ '--dataset', '-d', GetoptLong::REQUIRED_ARGUMENT], # set to featurize: 'train' or 'test'
                           [ "--append", "-A", GetoptLong::NO_ARGUMENT]
                         ],
        "split" => [ ['--logID', '-i', GetoptLong::REQUIRED_ARGUMENT],  # splitlog ID, required, no default
                     [ '--trainpercent', '-r', GetoptLong::REQUIRED_ARGUMENT]      # percentage training data, default: 90
                   ],
        "train" => [ ['--logID', '-i', GetoptLong::REQUIRED_ARGUMENT]  # splitlog ID; if given, will train on split
                     # rather than all training data
                   ],
        "test" => [ ['--logID', '-i', GetoptLong::REQUIRED_ARGUMENT],   # splitlog ID: if given, test on this split of 
                    # the training data
                    [ '--baseline', '-b', GetoptLong::NO_ARGUMENT],                # set this to compute baseline rather than
                    # apply classifiers
                    [ '--nooutput', '-N', GetoptLong::NO_ARGUMENT]               # set this to prevent output of disambiguated
                    # test data
                    
                  ],
        "eval" => [['--logID', '-i', GetoptLong::REQUIRED_ARGUMENT],    # splitlog ID: if given, evaluate this split. 
                   ['--printLog', '-l', GetoptLong::NO_ARGUMENT]
                  ]
      }
      
      # general options
      optnames = [[ '--help', '-h', GetoptLong::NO_ARGUMENT],            # get help
                  [ '--expfile', '-e', GetoptLong::REQUIRED_ARGUMENT],             # experiment file name (and path), no default
                  [ '--task', '-t', GetoptLong::REQUIRED_ARGUMENT ],               # task to perform: one of task.keys, no default
                 ]
      # append task-specific to general options
      tasks.values.each { |more_optnames|
        optnames.concat more_optnames
      }
      optnames.uniq!
      
      # asterisk: "explode" array into individual parameters
      begin
        opts = options_hash(GetoptLong.new(*optnames))
      rescue
        $stderr.puts "Error: unknown command line option: " + $!
        exit 1
      end
      
      experiment_filename = nil
      
      ##
      # are we being asked for help?
      if opts['--help']
        help()
        exit(0)
      end
      
      ##
      # now find the task
      task = opts['--task']
      # sanity checks for task
      if task.nil?
        help()
        exit(0)
      end
      unless tasks.keys.include? task
        $stderr.puts "Sorry, I don't know the task " + task
        exit 1
      end
      
      ##
      # now evaluate the rest of the options
      opts.each_pair { |opt,arg|
        case opt
        when '--help', '--task'
          # we already handled this
        when '--expfile'
          experiment_filename = arg
        else
          # do we know this option?
          unless tasks[task].assoc(opt)
            $stderr.puts "Sorry, I don't know the option " + opt + " for task " + task
            exit 1
          end
        end
      }
      
      
      
      unless experiment_filename
        $stderr.puts "I need an experiment file name, option --expfile|-e"
        exit 1
      end
      
      ##
      # open config file
      
      exp = FredConfigData.new(experiment_filename)
      
      # sanity checks
      unless exp.get("experiment_ID") =~ /^[A-Za-z0-9_]+$/
        raise "Please choose an experiment ID consisting only of the letters A-Za-z0-9_."
      end
      
      # enduser mode?
      $ENDUSER_MODE = exp.get("enduser_mode") 
      
      # set defaults
      unless exp.get("handle_multilabel")
        if exp.get("binary_classifiers")
          exp.set_entry("handle_multilabel", "binarize")
        else
          exp.set_entry("handle_multilabel", "repeat")
        end
      end
      # sanity check: if we're using option 'binarize' for handling items
      # with multiple labels, we have to have binary classifiers
      if exp.get("handle_multilabel") == "binarize" and not(exp.get("binary_classifiers"))
        $stderr.puts "Error: cannot use 'handle_multilabel=binarize' with n-ary classifiers."
        exit(1)
      end
      unless exp.get("numerical_features")
        exp.set_entry("numerical_features", "bin")
      end

      [exp, opts]
    end
    private
    ###
    # options_hash:
    #
    # GetoptLong only allows you to access options via each(),
    # not individually, and it only allows you to cycle through the options once.
    # So we re-code the options as a hash
    def self.options_hash(opts_obj) # GetoptLong object
      opt_hash = Hash.new
      
      opts_obj.each do |opt, arg|
        opt_hash[opt] = arg
      end
      
      return opt_hash
    end
    def self.help
        $stderr.puts "
Fred: FRamE Disambiguation System Version 0.3
  
Usage:
----------------

ruby fred.rb --help|-h
  Gets you this text.


ruby fred.rb --task|-t featurize --expfile|-e <e> --dataset|-d <d> 
        [--append|-A]
  Featurizes input data and stores it in feature files.
  Feature files are stored in 
  <fred_directory>/<experiment_ID>/<train/test>/features
  Enduser mode: dataset has to be test (preset as default), no --append.

  --expfile <e> Use <e> as the experiment description and configuation file

  --dataset <d> Set to featurize: <d> is either 'train' or 'test'
                Accordingly, either the directory dir_train or dir_test (as 
                specified in the experiment file) is used to store the features

  --append      Do not overwrite previously computed features for this experiment.
                Rather, append the new features to the old featurization files.
                Default: overwrite

ruby fred.rb --task|-t split --expfile|-e <e> --logID|-i <i> 
             [--trainpercent|-r <r>]
  Produces a new train/test split on the training data of the experiment.
  Split logs are stored in <fred_directory>/<experiment_ID>/split/<splitlog ID>
  Not available in enduser mode.

  --expfile <e> Use <e> as the experiment description and configuation file

  --logID <l>   Use <l> as the ID for storing this new split

  --trainpercent <r> Allocate <r> percent of the data as train, 
                and 100-<r> as test.
                default: <r>=90
     
ruby fred.rb --task|-t train --expfile|-e <e>  
             [--logID|-i <i> ]
  Train classifier(s) on the training data (or a split of it)
  Classifiers are stored in 
  <fred_directory>/<experiment_ID>/classifiers/<classifier_name>
  Not available in enduser mode.

  --expfile <e> Use <e> as the experiment description and configuation file

  --logID <l>   Train not on the whole training data but 
                on the split with ID <l>

ruby fred.rb --task|-t test --expfile|-e <e>  
             [--logID|-i <i>] [--baseline|-b]
             [--nooutput|-N]
  Apply classifier(s) to the test data (or a split of the training data)
  Classification results are stored in 
  <fred_directory>/<experiment_ID>/results/main or
  <fred_directory>/<experiment_ID>/results/baseline for the baseline.
  If you are using classifier combination, individual classification results
  are stored in <fred_directory>/<experiment_ID>/results/<classifier_name>
  System output (disambiguated text in SalsaTigerXML format) is stored in
  <fred_directory>/<experiment_ID>/output/stxml
  or <directory_output>, if that has been specified.

  --expfile <e> Use <e> as the experiment description and configuation file

  --logID <l>   Test on a split of the training data with ID <l>

  --baseline    Compute the baseline: Always assign most frequent sense.
                Default: use the trained classifiers

  --nooutput    Do not produce an output of the disambiguated test data 
                in SalsaTigerXML format. This is useful if you just want
                to evaluate the system.
                Default: output is produced.

 ruby fred.rb --task|-t eval --expfile|-e <e>  
              [--logID|-i <i>] [--printLog|-l]
  Evaluate the performance of Fred on the test data 
  (or on a split of the training data).
  Evaluation file is written to <fred_directory>/<experiment_ID>/eval/eval
  Not available in enduser mode.

  --expfile <e> Use <e> as the experiment description and configuation file

  --logID <l>   Evaluate a split of the training data with ID <l>

  --printLog    Also print logfile detailing evaluation of every instance.
                Log file is written to <fred_directory>/eval/log

"
    end
  end # class OptParser
end # module FrPrep
