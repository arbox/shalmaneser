# wrapper script for the Mallet toolkit Maxent classifier

# Problem with Winnow: cannot be serialised (written to file). Support dropped.

# sp 27 10 04


require "tempfile"
require "ftools"

class Mallet

  ###
  def initialize(program_path,parameters)

    if parameters.empty?
      puts "Error: Mallet needs two paths (first the location of mallet itself and then the location of the interface, usually program/tools/mallet)."
      puts "I got only the program path."
      Kernel.exit
    end

    @malletpath = program_path
    @interface_path = parameters.first
    unless @malletpath =~ /\/$/
      @malletpath = @malletpath + "/"
    end

    @learner = "MaxEnt,gaussianPriorVariance=1.0"

    # classpath for mallet

    @cp = "#{ENV["CLASSPATH"]}:#{@malletpath}class:#{@malletpath}lib/bsh.jar"

  end

  ###
  def train(infilename,classifier_location)
    csvfile = Tempfile.new(File.basename(infilename)+".csvtrain")
    infile = File.new(infilename)
    c45_to_csv(infile,csvfile) # training data in csv format
    infile.close
    csvfile.close
    @mallet_train_vectors = infilename+".trainvectors" # training data in mallet format
    if classifier_location
      @classifier_mallet_path = classifier_location
    else
      @classifier_mallet_path = infilename+".classifier"
    end

    command1 = [@malletpath+"bin/csv2vectors ",
                    " --input ",csvfile.path,
                    " --output ",@mallet_train_vectors].join("")

    command2 = ["cd #{@interface_path}; ",
                "java -cp #{@cp} -Xmx1000m Train ",
                " --train ",@mallet_train_vectors,
                " --out ",@classifier_mallet_path,
                " --trainer ",@learner].join("")
#    STDERR.puts "[train 1] "+command1
    successfully_run(command1) # encode
#    STDERR.puts "[train 2] "+command2
    successfully_run(command2) # train
    csvfile.close(true)
  end

  def write(classifier_file)
    if @classifier_mallet_path
      %x{cp #{@classifier_mallet_path} #{classifier_file}.classifier} # store classifier
   #    File.chmod(0664,classifier_file+".classifier")
    end
    if @mallet_train_vectors
      %x{cp #{@mallet_train_vectors} #{classifier_file}.trainvectors} # store train vectors to recreate pipe for testing data
#      File.chmod(0664,classifier_file+".trainvectors")
    end
  end

  ###
  def exists?(classifier_file)
    return (FileTest.exists?(classifier_file+".trainvectors") and
              FileTest.exists?(classifier_file+".classifier"))
  end

  ###
  # return true iff reading the classifier has had success
  def read(classifier_file)
    @mallet_train_vectors = classifier_file+".trainvectors" # training data in mallet format
    @classifier_mallet_path = classifier_file+".classifier"
    unless FileTest.exists?(@mallet_train_vectors)
      $stderr.puts "No classifier file "+@mallet_train_vectors
      return false
    end
    unless FileTest.exists?(@classifier_mallet_path)
      $stderr.puts "No classifier file "+@classifier_mallet_path
      return false
    end
    return true
  end

  ###
  def apply(infilename,outfilename)
    unless @classifier_mallet_path and @mallet_train_vectors
      return false
    end

    #    STDERR.puts "Testing on "+infilename
    csvfile = Tempfile.new(File.basename(infilename)+".csvtest")

    infile = File.new(infilename)
    c45_to_csv(infile,csvfile) # training data in csv format
    infile.close
    csvfile.close

    test_mallet_path = infilename+".test.vectors" # training data in mallet format

    # $stderr.puts "test file in " + infilename
    # $stderr.puts "using training vectors from " + @mallet_train_vectors

    # copy train vectors to temp file.
    # reason: mallet in std edition reads _and writes_ this file
    # if rosy is interrupted, corrupted (ie incomplete) train vector files
    # result

    tempfile = Tempfile.new("mallet")
    tempfilename = tempfile.path
    unless File.copy(@mallet_train_vectors,tempfilename)
      return false
    end

    command1 = [@malletpath+"bin/csv2vectors", # encode testing data
                " --input ",csvfile.path,
                " --output ",test_mallet_path,
                " --use-pipe-from ",tempfilename].join("")

#    $stderr.puts "Mallet encode: " + command1
    unless successfully_run(command1) # encode
      return false
    end

    File.safe_unlink(tempfilename)

    # some error in encoding?
    unless FileTest.exists?(test_mallet_path)
      return false
    end

    command2 = ["cd #{@interface_path}; ",
                "java -cp #{@cp} -Xmx1000m Classify ",
                @classifier_mallet_path," ",
                test_mallet_path," ",
                "> ",outfilename].join("")

    # classify
#    $stderr.puts "Mallet classify: " + command2
    unless    successfully_run(command2)
      return false
    end

    # some error in classification
    unless FileTest.exists?(outfilename)
      return false
    end

     # no errors = success
    csvfile.close(true)
    return true
  end

  #####
  # format of Mallet result file:
  # <best label> <confidence> \t <secondbest_label> <confidence>....
  def read_resultfile(filename)
    begin
      f = File.new(filename)
    rescue
      $stderr.puts "Mallet error: cannot read Mallet result file #{filemame}."
      return nil
    end

    retv = Array.new()

    f.each { |line|
      line_results = Array.new()
      pieces = line.split()

      while not(pieces.empty?)
        label = pieces.shift()

        begin
          confidence = pieces.shift().to_f()
        rescue
          $stderr.puts "Error reading mallet output: invalid line: #{line}"
          confidence = 0
        end

        line_results << [label, confidence]
      end
      retv << line_results
    }

    return retv
  end


  ###################################
  private

  ###
  # mallet needs "comma separated values"-file
  # input: features separated by comma
  # output:
  # line_number classlabel features_joined_by_spaces
  def c45_to_csv(inpipe,outpipe)
    idx = 0
    while (line = inpipe.gets)
      line.chomp!
      idx += 1
      la = line.split(",")
      label = la.pop
      if label[-1,1] == "."
        label.chop!
      end
      outpipe.puts [idx,label].join(" ")+" "+la.join(" ")
    end
  end

  ###
  def successfully_run(command)
    retv = Kernel.system(command)
    unless retv
      $stderr.puts "Error running classifier. Continuing."
      $stderr.puts "Offending command: "+command
 #     exit 1
    end
    return retv
  end
end
