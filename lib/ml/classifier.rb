# sp 24 08 04

# this file provides a very simple wrapper for using different ML systems
# all you need to do is to write the appropriate learner class
# and insert them in the initialize routine here in ML()
#
# available at the moment:
# * timbl (memory-based learner)
# * mallet-maxent (another maxent system)
# * maxent (the OpenNLP maxent system)

# part of contract: learner is not initialised unless it is either trained or read

# @note AB: This is only a remark about dynamic requirement below.
# require_relative 'timbl'
# require_relative 'mallet'
# require_relative 'maxent'

require_relative 'optimize'

class Classifier

  @@learners = [
    ["timbl", "timbl", "Timbl"],
    ["mallet", "mallet", "Mallet"],
    ["maxent", "maxent", "Maxent"]
  ]

  def initialize(learner, params)

    @ready = false

    if params[0] == "optimise"
      params.shift
      @optimise = true
    else
      @optimise = false
    end

    program_path = ""
    begin
      program_path = params.shift.chomp
      unless FileTest.exist? program_path
        $stderr.puts "Error: Could not find classifier system at " + program_path
        $stderr.puts "Perhaps an erroneous entry in your experiment file?"
        exit 1
      end
    rescue NoMethodError
      $stderr.puts "Error: No program path provided for classifier system."
    end

    # try to find our learner in the pre-set list of learners
    learner_tuple = @@learners.assoc(learner)
    unless learner_tuple
      $stderr.puts "Error: I don't know the learner " + learner.to_s
      $stderr.puts "Perhaps an erroneous entry in your experiment file?"
      exit 1
    end

    # @todo AB: Investigate, why this dynamic require is necessary.
    learner_name, learner_filename, learner_classname = learner_tuple
    require_relative "#{learner_filename}"
    @learner = eval(learner_classname).new(program_path,params)
  end

  # a classifier can (and has to be) either trained or read
  def train(trainfile, classifier_file=nil)
    # train on the training data in trainfile
    # make sure we produce a valid file name

    # it is possible to directly specify a filename for storing the classifier

    trainfile.gsub!(/[<>]/,"")
    trainfile.gsub!(/ /,"_")
    if @optimise
      STDERR.puts "[ML] using feature optimisation"
      @optimiser = Optimise.new
      @optimiser.init_from_data(trainfile)
      optimisedfile = trainfile+".opted"
      @optimiser.apply(trainfile,optimisedfile)
      @learner.train(optimisedfile,classifier_file)
      File.delete(optimisedfile)
    else
      STDERR.puts "[ML] no feature optimisation"
      @learner.train(trainfile,classifier_file)
    end
    @ready = true
  end


  # returns true iff reading the classifier from the file has had success

  def read(classifier_file)
    # make sure we produce a valid file name
    classifier_file.gsub!(/[<>]/,"")
    classifier_file.gsub!(/ /,"_")

    # read file, if present

    status = @learner.read(classifier_file)

    # if reading has failed, return "false"
    unless status
      STDERR.puts "reading from #{classifier_file} did not succeed"
      return status
    end

    # read optimisation, if desired
    if @optimise
      optimisations_filename = Optimise.recommended_filename(classifier_file)
      unless FileTest.exists? optimisations_filename
        STDERR.puts "[ML] Error: attempted to read stored optimisation, but file does not exist"
        return false
      else
        @optimiser = Optimise.new
        @optimiser.init_from_file(optimisations_filename)
      end
    end

    @ready = true
    return true

  end

  # a classifier can be stored somewhere. This can be more than one file (classifier-specific),
  # but all files start with "classifier_file"

  def write(classifier_file)
    # make sure we produce a valid file name
    classifier_file.gsub!(/[<>]/,"")
    classifier_file.gsub!(/ /,"_")
    @learner.write(classifier_file)
    if @optimise
      @optimiser.store(Optimise.recommended_filename(classifier_file))
    end
  end

  ###
  # exists?
  # check if a classifier is living at some particular path

  def exists?(classifier_file)
    classifier_file.gsub!(/[<>]/,"")
    classifier_file.gsub!(/ /,"_")
    return @learner.exists?(classifier_file)
  end

  # a classifier can be applied

  # returns true iff application has had success

  def apply(testfile,outfile) # test either on the training or the test data in the specified dir
    # make sure we produce a valid file name
    testfile.gsub!(/[<>]/,"")
    testfile.gsub!(/ /,"_")
    # make sure we produce a valid file name
    outfile.gsub!(/[<>]/,"")
    outfile.gsub!(/ /,"_")

    unless @ready
      STDERR.puts "[ML] Warning: learner not ready for testing! Must be trained or read."
      return false
    end

    # do we have a testfile?
    unless FileTest.exists?(testfile)
      STDERR.puts "[ML] Warning: could not find testfile (maybe empty test set?)."
      return false
    end

    if @optimise
      optimisedfile = testfile+".opted"
      @optimiser.apply(testfile,optimisedfile)
      return @learner.apply(optimisedfile,outfile)
      File.delete(optimisedfile)
    else
      return @learner.apply(testfile,outfile)
    end
  end

  ###
  # read classifier result file,
  # returns a list of instance_results
  # where an instance_result is a list of pairs [label, confidence]
  # where the pairs are sorted by confidence
  def read_resultfile(file)
    return @learner.read_resultfile(file)
  end
end
