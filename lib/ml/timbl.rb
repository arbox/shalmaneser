# wrapper script for timbl learner
# sp 24 08 04

# contract for Learner classes:

class Timbl
  def initialize(program_path, parameters)

    @timblpath = File.join(program_path, "Timbl")
    unless @timblpath =~ /\s$/
      # path must end in space so we can just attach parameters
      @timblpath << " "
    end

    if parameters.empty?
      # was: +vs
      @params = "-mM -k5 +vs" # default parameters
    else
      @params = parameters.join(" ") + " "
    end
  end

  def timbl_out_to_malouf_out(infilename,outfilename) # timbl: [all features], [gold standard label]
    infile = File.new(infilename)
    outfile = File.new(outfilename,"w")
    while (line = infile.gets)
      larray = line.chomp.split(",")
      ml_label = larray.last
      outfile.puts ml_label+"\t1"
    end
    infile.close
    outfile.close
  end

  def train(infile,classifier_location)                  # lazy learning: for training, store the
                                                         # instancebase as a tree (TiMBL -I / -i option)
    # figure out how many features we have
    f = File.new(infile)
    line = f.gets().chomp()
    num_features = line.split(",").length() - 1

    # and train
    if classifier_location then
      @instancebase = classifier_location
    else
      @instancebase = infile+".instancebase"
    end
    successfully_run(@timblpath+@params+" -N#{num_features} -f "+infile+" -I "+@instancebase)
  end

  # return true iff reading the classifier has had success
  def read(classifierfile)
    unless FileTest.exists?(classifierfile)
      STDERR.puts "[Timbl] Cannot find instancebase at #{classifierfile}"
      return false
    end
    @instancebase = classifierfile
    return true
  end

  def exists?(classifierfile)
    return FileTest.exists?(classifierfile)
  end

  def write(classifierfile)
    %x{cp #{@instancebase} #{classifierfile}} # store training data as "modelfile"
    File.chmod(0664,classifierfile)
  end

  def apply(infile,outfile)
    temp_outfile = outfile+".temp"
    successfully_run(@timblpath+@params+" -i "+@instancebase+" -t "+infile+" -o "+temp_outfile)

    # if we have an empty input file, timbl will not produce an output file
    unless FileTest.exists?(temp_outfile)
#      STDERR.puts "[Timbl] Warning: Timbl failed to produce an outfile."
      return false
    end

    # no error
    timbl_out_to_malouf_out(temp_outfile,outfile)
    File.unlink(temp_outfile)

    # true iff outfile exists
    if  FileTest.exists?(outfile)
      return true
    else
#      STDERR.puts "[Timbl] Warning: Final outfile could not be produced."
      return false
    end

  end

  #####
  def read_resultfile(filename)
    begin
      f = File.new(filename)
    rescue
      $stderr.puts "TiMBL error: cannot read TiMBL result file #{filemame}."
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

  #########################
  private

  ###
  def successfully_run(command)
    retv = Kernel.system(command)
    unless retv
      $stderr.puts "Error running classifier. Exiting."
      $stderr.puts "Offending command: "+command
      exit 1
    end
  end

end
