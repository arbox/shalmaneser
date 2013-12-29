# wrapper script for the OpenNLP Maxent classifier

# sp July 2007


require "tempfile"
require 'fileutils'

class Maxent

  ###
  def initialize(program_path,parameters)
    
    # @note AB: <parameters> is an Array with the last part of the
    #   line from the experiment file, it should contain the path to our
    #   java wrappers, but we don't want it.
    #   Since the presence of this part is checked only here we
    #   suppose it obsolete and set this path manually here.
    # if parameters.empty?	
    #   puts "Error: The OpenNLP maxent system needs two paths (first the location of maxent itself and then the location of the interface, usually program/tools/maxent)."
    #   puts "I got only the program path."
    #   Kernel.exit
    # end
    # @interface_path = parameters.first

    # @note AB: Setting path manually.
    #   It assumes <Maxent.rb> ist in <lib/common> and
    #   <Classify.class> is in <lib/ext/maxent>.
    @interface_path = File.expand_path('../ext/maxent', File.dirname(__FILE__))
      
    @maxentpath = program_path

    unless @maxentpath =~ /\/$/
      @maxentpath = @maxentpath + "/"
    end
    
    # classpath for maxent
    
    @cp = "#{@maxentpath}:#{@maxentpath}lib:#{@maxentpath}lib/trove.jar:#{@maxentpath}output/maxent-2.4.0.jar:#{ENV["CLASSPATH"]}"

  end

  ###
  #
  # write classifier to training directory...
  def train(infilename,classifier_file)
    trainfile = Tempfile.new(File.basename(infilename)+".maxenttrain")
    infile = File.new(infilename)
    c45_to_maxent(infile,trainfile) # training data in csv format
    infile.close
    trainfile.close

    if classifier_file
      @classifier_location = classifier_file
    else
      @classifier_location = trainfile.path+"Model.bin.gz"
    end
    
    @classifier_location = enforce_compact_storage(@classifier_location)

    # store model in binary, gzipped form...
    command = ["cd #{@interface_path}; ",
                #"/usr/lib/jvm/java-1.7.0/bin/java -cp #{@cp} -Xmx1000m Train",
		"java -cp #{@cp} -Xmx1000m Train",
               trainfile.path,
               @classifier_location].join(" ")
    # remember location
    unless  successfully_run(command)
      return false
    end
    trainfile.close(true)
  end

  def write(classifier_file)
    
    classifier_file = enforce_compact_storage(classifier_file)
    
    if @classifier_location
      @classifier_location = enforce_compact_storage(@classifier_location)
      %x{cp #{@classifier_location} #{classifier_file}} # store classifier
   #    File.chmod(0664,classifier_file+".classifier")
    else
      $stderr.puts "Maxent error: cannot read Maxent classifier file #{@classifier_file}."
      return nil      
    end
  end

  ###
  def exists?(classifier_file)
    classifier_file = enforce_compact_storage(classifier_file)    
    return FileTest.exists?(classifier_file)
  end
  
  ###
  # return true iff reading the classifier has had success
  def read(classifier_file)
    
    classifier_file = enforce_compact_storage(classifier_file)

    if exists?(classifier_file)
      @classifier_location = classifier_file
      return true
    else
      $stderr.puts "No classifier file "+classifier_file
      return false
    end
  end
  
  ###
  def apply(infilename,outfilename)
    
    @classifier_location = enforce_compact_storage(@classifier_location)
    unless @classifier_location
      return false
    end

    testfile = Tempfile.new(File.basename(infilename)+".maxenttrain")
    
    infile = File.new(infilename)
    c45_to_maxent(infile,testfile) # training data in csv format
    infile.close
    testfile.close
    
    command = ["cd #{@interface_path}; ",
               #"/usr/lib/jvm/java-1.7.0/bin/java -cp #{@cp} -Xmx1000m Classify ",
               "java -cp #{@cp} -Xmx1000m Classify ",
               testfile.path,
               @classifier_location,
               ">",
               outfilename].join(" ")
    
    # classify
    unless  successfully_run(command)
      return false
    end
    
    # some error in classification
    unless FileTest.exists?(outfilename)
      return false
    end
    
    # no errors = success
    testfile.close(true)
    return true
  end

  #####
  # format of Maxent result file:
  # <best label>[<confidence>]  <secondbest_label>[<confidence>] ....
  #
  # returns a list of instance_results
  # where an instance_result is a list of pairs [label, confidence]
  # where the pairs are sorted by confidence
  def read_resultfile(filename)
    begin
      f = File.new(filename)
    rescue
      $stderr.puts "Maxent error: cannot read Maxent result file #{filemame}."
      return nil
    end

    retv = []

    f.each do |line|
      line_results = Array.new()
      pieces = line.split() # split at whitespace

      pieces.each {|piece|
        piece =~ /(\S+)\[(.+)\]/
        label = $1
        confidence = $2.to_f
        
        line_results << [label, confidence]        
      }

      # sort: most confident label first
      retv << line_results.sort {|a,b| b[1] <=> a[1]}
    end

    f.close

    retv
  end

  
  ###################################
  private

  ###
  # produce input file for maxent learner: make attribute-value pairs
  # where attribute ==    featureX=
  def c45_to_maxent(inpipe,outpipe) 
    while (line = inpipe.gets)
      line.chomp!
      la = line.split(",")
      label = la.pop
      if label[-1,1] == "."
	label.chop!
      end
      la.each_index {|i|
        la[i] = i.to_s() + "=" + la[i]
      }
      la.push(label)
      outpipe.puts la.join(" ")
    end
  end

  # since the OpenNLP MaxEnt system determines storage based on filename,
  # make sure that all models are stored internally as binary, gzipped files.
  
  def enforce_compact_storage(filename)
    if filename =~ /Model.bin.gz/
      return filename
    else
      return filename+"Model.bin.gz"
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
