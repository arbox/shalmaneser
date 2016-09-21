# -*- coding: utf-8 -*-

require 'getoptlong'
require 'definitions'
require 'configuration/rosy_config_data'

module Shalmaneser
  module Rosy
    class OptParser
      def self.parse(cmd_args)
        ##############################
        # main starts here
        ##############################

        ##
        # evaluate runtime arguments

        tasks = {
          "featurize" => [
            # test table ID, required for test, no default
            ['--testID', '-i', GetoptLong::REQUIRED_ARGUMENT],
            # set to featurize: 'train' or 'test', no default
            ['--dataset', '-d', GetoptLong::REQUIRED_ARGUMENT],
            # splitlog ID: if given, featurize this split. Cannot use both this and -d
            ['--logID', '-l', GetoptLong::REQUIRED_ARGUMENT],
            ['--append', '-A', GetoptLong::NO_ARGUMENT]
          ],
          "split" => [
            # splitlog ID, required, no default
            ['--logID', '-l', GetoptLong::REQUIRED_ARGUMENT],
            # percentage training data, default: 90
            ['--trainpercent', '-r', GetoptLong::REQUIRED_ARGUMENT]
          ],
          "train" => [
            # splitlog ID; if given, will train on split rather than all of main table
            ['--logID', '-l', GetoptLong::REQUIRED_ARGUMENT],
            # classification step: 'argrec', 'arglab', 'both' (default) or 'onestep'
            ['--step', '-s', GetoptLong::REQUIRED_ARGUMENT]
          ],
          "test" => [
            # classification step: 'argrec', 'arglab', 'both' (default) or 'onestep'
            ['--step', '-s', GetoptLong::REQUIRED_ARGUMENT],
            # test table ID: if given, test on this table
            ['--testID', '-i', GetoptLong::REQUIRED_ARGUMENT],
            # splitlog ID: if given, test on this split. Cannot use both this and -i
            ['--logID', '-l', GetoptLong::REQUIRED_ARGUMENT],
            # set this to prevent output of disambiguated test data
            ['--nooutput', '-N', GetoptLong::NO_ARGUMENT]
          ],
          "eval" => [
            # classification step: 'argrec', 'arglab', 'both' (default) or 'onestep'
            ['--step', '-s', GetoptLong::REQUIRED_ARGUMENT],
            # test table ID: if given, test on this table
            ['--testID', '-i', GetoptLong::REQUIRED_ARGUMENT],
            ['--logID', '-l', GetoptLong::REQUIRED_ARGUMENT]
          ],
          "inspect" => [
            # describe all tables
            ['--tables', GetoptLong::NO_ARGUMENT],
            # describe table contents for current experiment
            ['--tablecont', GetoptLong::OPTIONAL_ARGUMENT],
            # test table ID: if given, describe contents of this table
            ['--testID', '-i', GetoptLong::REQUIRED_ARGUMENT],
            # describe classification runs for current experiment
            ['--runs', GetoptLong::NO_ARGUMENT],
            # list sentence IDs for given splitlog
            ['--split', GetoptLong::REQUIRED_ARGUMENT]
          ],
          "services" => [
            # delete database table
            ['--deltable', GetoptLong::REQUIRED_ARGUMENT],
            # delete experiment tables and files
            ['--delexp', GetoptLong::NO_ARGUMENT],
            # delete tables interactively
            ['--deltables', GetoptLong::NO_ARGUMENT],
            # delete runs
            ['--delruns', GetoptLong::NO_ARGUMENT],
            # delete split
            ['--delsplit', GetoptLong::REQUIRED_ARGUMENT],
            # dump experiment to files
            ['--dump', GetoptLong::OPTIONAL_ARGUMENT],
            # load experiment from files
            ['--load', GetoptLong::OPTIONAL_ARGUMENT],
            # write feature files
            ['--writefeatures', GetoptLong::OPTIONAL_ARGUMENT],
            # classification step: 'argrec', 'arglab', 'both' (default) or 'onestep'
            ['--step', '-s', GetoptLong::REQUIRED_ARGUMENT],
            # test table ID: if given, test on this table
            ['--testID', '-i', GetoptLong::REQUIRED_ARGUMENT],
            # splitlog ID: if given, test on this split. Cannot use both this and -i
            ['--logID', '-l', GetoptLong::REQUIRED_ARGUMENT]
          ]
        }

        optnames = [
          # get help
          ['--help', '-h', GetoptLong::NO_ARGUMENT],
          # experiment file name (and path), no default
          ['--expfile', '-e', GetoptLong::REQUIRED_ARGUMENT],
          # task to perform: one of task.keys, no default
          ['--task', '-t', GetoptLong::REQUIRED_ARGUMENT]
        ]

        tasks.values.each { |more_optnames| optnames.concat more_optnames }

        optnames.uniq!

        begin
          opts = GetoptLong.new(*optnames)
        rescue => e
          $stderr.puts "Error: unknown command line option: #{e.message}!"
          exit 1
        end

        experiment_filename = nil

        opts = options_hash(opts)
        ##
        # are we being asked for help?
        # @ todo work with the empty case
        if opts['--help']
          help
          exit(0)
        end

        ##
        # now find the task
        task = opts['--task']
        # sanity checks for task
        if task.nil?
          help
          exit(0)
        end

        unless tasks.keys.include?(task)
          $stderr.puts "Sorry, I don't know the task '#{task}'. Do 'rosy -h' for a list of tasks."
          exit 1
        end

        ##
        # now evaluate the rest of the options
        opts.each_pair do |opt, arg|
          case opt
          when '--help', '--task'
          # we already handled this
          when '--expfile'
            experiment_filename = arg
          else
            # do we know this option?
            unless tasks[task].assoc(opt)
              $stderr.puts "Sorry, I don't know the option " + opt + " for task " + task
              $stderr.puts "Do 'ruby rosy.rb -h' for a list of tasks and options."
              exit 1
            end
          end
        end

        # @todo This case is irreal since this restriction is set by the parser itself.
        if experiment_filename.nil?
          $stderr.puts "I need an experiment file name, option --expfile|-e"
          exit 1
        end

        ##
        # open config file

        exp = ::Shalmaneser::Configuration::RosyConfigData.new(experiment_filename)

        [exp, opts]
      end

      private

      def self.help
        $stderr.puts "
ROSY: semantic ROle assignment SYstem, Version #{VERSION}

Usage:

ruby rosy.rb --help|-h

  gets you this help text.

ruby rosy.rb --task|-t featurize --expfile|-e <e>
             [--dataset|-d <d>]  [--testID|-i <i>]
             [--logID|-l <l> ] [--append|-A]
  featurizes input data and stores it in a database.
  Enduser mode: dataset has to be 'test' (preset as default),
    no --append.

  --expfile <e>   Use <e> as the experiment description and
                  configuration file

  --dataset <d>   Set to featurize: <d> is either 'train'
                  (put data into main table) or 'test' (put data
                  into separate test table with ID given using --testID)
                  Use at least one of --logID, --dataset.

  --logID <l>     Re-featurize the split with ID <l>:
                  Features that train on training instances are done
                  separately for each split.
                  Use at least one of --logID, --dataset.

  --testID <i>    Use <i> as the ID for the table to store the test data.
                  necessary only with '--dataset test'. default: #{DEFAULT_TEST_ID}.

  --append        Do not overwrite previously computed features
                  for this experiment.
                  Rather, append the new features
                  to the old featurization files.
                  Default: overwrite

ruby rosy.rb --task|-t split --expfile|-e <f> --logID|-l <l>
            [--trainpercent|-r <r>]
  produces a new train/test split on the main table of the experiment.
  Not available in enduser mode.

  --expfile <f>   Use <f> as the experiment description and configuration file

  --logID <l>     Use <l> as the ID for storing this new split

  --trainpercent <r> Allocate <r> percent of the data as train,
                  and 100-<r> as test
                  default: <r>=90


ruby rosy.rb --task|-t train --expfile|-e <f> [--step|-s <s>] [--logID|-l <l>]
  train classifier(s) on the main table data (or a split of it)
  Not available in enduser mode.

  --expfile <f>   Use <f> as the experiment description and configuration file

  --step <s>      What kind of classifier(s) to train?
                  <s>=argrec: argument recognition,
                                distinguish role from nonrole
                  <s>=arglab: argument labeling, naming roles,
                                builds on argrec
                  <s>=both:   first argrec, then arglab
                  <s>=onestep: do argument labeling right away without
                                prior filtering of non-arguments
                  default: both

  --logID <l>     If given, train on this split of the main table rather than
                  the whole main table


ruby rosy.rb --task|-t test --expfile|-e <f> [--step|-s <s>]
             [--logID|-l <l> | --testID|-i <i>] [--nooutput|-N]
  apply classifier(s) on data from a test table, or a main table split
  Enduser mode: only -s both, -s onestep available. Cleanup: Database with
                featurization data is removed after the run.

  --expfile <f>   Use <f> as the experiment description and configuration file

  --step <s>      What kind of classifier(s) to use for testing?
                  <s>=argrec: argument recognition,
                                distinguish role from nonrole
                  <s>=arglab: argument labeling, naming roles,
                                builds on argrec
                  <s>=both:   first argrec, then arglab
                  <s>=onestep: do argument labeling right away without
                                prior filtering of non-arguments
                  default: both
  --logID <l>     If given, test on this split of the main table

  --testID <i>    If given, test on this test table.
                  (Use either this option or -l)

  --nooutput      Do not produce an output of the disambiguated test data
                  in SalsaTigerXML format. This is useful if you just want
                  to evaluate the system.
                  Default: output is produced.


ruby rosy.rb --task|-t eval --expfile|-e <f> [--step|-s <s>]
             [--logID|-l <l> | --testID|-i <i>
  evaluate the classification results.
  Not available in enduser mode.

  --expfile <f>   Use <f> as the experiment description and configuration file

  --step <s>      Evaluate results of which classification step?
                  <s>=argrec: argument recognition,
                                distinguish role from nonrole
                  <s>=arglab: argument labeling, naming roles,
                                builds on argrec
                  <s>=both:   first argrec, then arglab
                  <s>=onestep: do argument labeling right away without
                                prior filtering of non-arguments
                  default: both
                  Need not be given if --runID is given.

  --logID <l>     If given, evaluate on the test data from this split of
                  the main table.
                  (use either this option or -i or -R)

  --testID <i>    If given, evaluate on this test table.
                  (Use either this option or -l or -R)


ruby rosy.rb --task|-t inspect --expfile|-e <f> [--tables] [--runs]
             [--tablecont [N]] [--testID|-i <i>] [--split <l>]
  inspect system-internal data, both global and pertaining to the current
  experiment.
  If no options are chosen, an overview of the current experiment
  is given.

  --expfile <f>   Use <f> as the experiment description and
                  configuration file

  --tables        Lists all tables of the DB: table name,column names

  --tablecont [N|id:N] Lists the training instances (as feature vectors)
                  of the current experiment.
                  If test ID is given, test instances are listed as well.
                  The optional argument may have one of two forms:
                  - It may be a number N. Then only the N first lines
                    of each set are listed.
                  - It may be a pair id:N. Then only the N first lines of
                    the DB table with ID id are listed. To list all lines
                    of a single DB table, use id:

  --testID <i>    If given, --tablecont also lists the feature vectors for
                  this test table

  --runs          List all classification runs of the current experiment

  --split <l>     List the split with the given ID

ruby rosy.rb --task|-t services --expfile|-e <f> [--deltable <t>]
             [--delexp] [--dump [<D>]] [--load [<D>]] [--delrun <R>]
             [--delsplit <l>] [--writefeatures [<D>]]
             [--step|-s <s>]  [--testID|-i <i>] [--logID|-l <l> ]
  diverse services.
  The --del* services are not available in enduser mode.

  --dump [<D>]    Dump the database tables for the current experiment file.
                  If a directory <D> is given, the tables are written there,
                  otherwise they are written to
                  data_dir/<experiment_ID>/tables, where data_dir is the
                  data directory given in the experiment file.
                  No existing files in the directory are removed.

  --load [<D>]    Construct new database tables from the files in
                  the directory <D>, if it is given, otherwise from
                  data_dir/<experiment_id>/tables, where data_dir
                  is the data directory given in the experiment file.
                  Warning: Database tables are loaded into the
                  current experiment, the one described in the
                  experiment file. Existing data in tables with
                  the same names is overwritten!

  --deltable <t>  Remove database table <t>

  --deltables     Presents all tables in the database for interactive deletion

  --delexp        Remove the experiment described in the given experiment file,
                  all its database tables and files.

  --delruns       Presents all classification runs for the current experiment
                  for interactive deletion

  --delsplit <l>  Remove the split with ID <l> from the experiment
                  described in the given experiment file.

  --writefeatures <D> Write feature files to directory <D>, such
                  that you can use them with some external machine learning
                  system. If <D> is not given, feature files are written
                  to data_dir/<experiment_id>/your_feature_files/.

                  Uses the parameters --step, --testID, --logID to
                  determine which feature files will be written.

  --step <s>      Use with --writefeatures: task for which to write features.
                  <s>=argrec: argument recognition,
                                distinguish role from nonrole
                  <s>=arglab: argument labeling, naming roles
                  <s>=onestep: do argument labeling right away without
                                prior filtering of non-arguments
                  default: onestep.

  --logID <l>     Use with --writefeatures: write features
                  for the the split with ID <l>.

  --testID <i>    Use with --writefeatures: write features
                  for the test set with ID <i>.
                  default: #{DEFAULT_TEST_ID}.
"
      end

      ###
      # options_hash:
      #
      # GetoptLong only allows you to access options via each(),
      # not individually, and it only allows you to cycle through the options once.
      # So we re-code the options as a hash
      # @param opts_obj {GetoptLong}
      def self.options_hash(opts_obj) # GetoptLong object
        opt_hash = {}

        opts_obj.each do |opt, arg|
          opt_hash[opt] = arg
        end

        opt_hash
      end

    end # class OptParser
  end # module Rosy
end
