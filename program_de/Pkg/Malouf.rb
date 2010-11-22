# wrapper script for the malouf maxent system
# sp 24 08 04

# contract for Learner classes:

# initialise(parameters): set parameters for learner

# train(infile):        produce model file(s) for infile, if necessary, and store place of modelfile
# test(infile,output):  classify infile and write output to outfile
# cleanup:              remove intermediate files

class Malouf
  
  def initialize(program_path, parameters)    # no parameters here
    # we have to extract the dirname because we have to call the python wrapper scripts individually
    @program_dir = File.dirname(program_path)    
    
  end

  def train(infile)
    @modelfiles_prefix = infile
    successfully_run("#{@program_dir}/estimate_encode "+infile)
    successfully_run("bash #{@program_dir}/estimate_train "+@modelfiles_prefix+".events.gz")
  end

  def exists?(classifier_file)
    return (FileTest.exists?(classifier_file+".events.gz") and
              FileTest.exists?(classifier_file+".cat.gz") and
              FileTest.exists?(classifier_file+".weights"))
  end

  # return true iff reading the classifier has had success
  def read(classifier_file)
    @modelfiles_prefix = classifier_file
    unless FileTest.exists?(@modelfiles_prefix+".events.gz") 
      STDERR.puts "[Malouf] Error: Cannot find classifier file "+@modelfiles_prefix+".events.gz"
      return false
    end
    unless FileTest.exists?(@modelfiles_prefix+".cat.gz")
      STDERR.puts "[Malouf] Error: Cannot find classifier file "+@modelfiles_prefix+".cat.gz"
      return false
    end
    unless FileTest.exists?(@modelfiles_prefix+".weights")
      STDERR.puts "[Malouf] Error: Cannot find classifier file "+@modelfiles_prefix+".weights"
      return false
    end
    return true
  end
  
  def write(classifier_file)
    %x{cp #{@modelfiles_prefix}.events.gz #{classifier_file}.events.gz}
    %x{cp #{@modelfiles_prefix}.cat.gz #{classifier_file}.cat.gz}
    %x{cp #{@modelfiles_prefix}.weights #{classifier_file}.weights}
    File.chmod(0664,classifier_file+".events.gz",
                    classifier_file+".cat.gz",
                    classifier_file+".weights")
  end
  
  def apply(infile,outfile)
    STDERR.puts "Testing on "+infile
    successfully_run("#{@program_dir}/estimate_test "+infile+" "+@modelfiles_prefix+".weights "+@modelfiles_prefix+".cat.gz")
    # estimate_test writes output to infile.out
    
    # if there was an error and estimate did not produce an output file
    unless FileTest.exists?(infile+".out")
      return false
    end
    
    # no error
    unless infile+".out" == outfile
      successfully_run("mv "+infile+".out "+outfile)
    end
    return true
    
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
