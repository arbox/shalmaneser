# WhereWasI
#
# keep track of a lengthy computation
# such that, if it is interrupted,
# we can start again where we left off
#
# Manages a list_of_steps, an array of strings. 
# the calling process notifies the WhereWasI object
# when one of the steps is finished. Then the step is
# logged in a logfile.
#
# If, on starting the WhereWasI object, the logfile is found to
# exist, the process is taken up after the last step recorded
# in the logfile.
# 
# the WhereWasI object keeps a list of steps (strings)
# and offers an access method next_step() that 
# returns the next step to be taken. 

class WhereWasI
  ###
  # new
  #
  # start progress log
  # or, if it exists, find the current point
  # in the list of steps
  def initialize(list_of_steps, #array: string, the computation steps
		 task_name, # string: name of the task
		 directory) # string: name of directory to store log
    ###
    # remember list of steps
    @list_of_steps = list_of_steps
    # @current_step: integer, index of @list_of_steps array

    ###
    # progress logfile: initialize or read
    unless directory =~ /\/$/
      directory << "/"
    end
    @logfile_name = directory + "progress_log." + task_name

    if File.exists? @logfile_name
      # logfile exists: seems our task was interrupted
      # next step is where we left off
      @current_step = read_progress_logfile(@logfile_name, task_name)
      # and continue writing at the end of the logfile
      begin
	@logfile = File.new(@logfile_name, "a")
      rescue
	raise "Couldn't write to logfile " + @logfile_name
      end

    else
      # logfile doesn't exist
      # start a new one
      # next step is the first step
      begin
	@logfile = File.new(@logfile_name, "w")
      rescue
	raise "Couldn't write to logfile " + logfile_name
      end
      @current_step = 0
      initialize_logfile(task_name)
    end
  end

  ###
  # next_step
  #
  # returns a string, the name of the next step to take
  # @current_step is not incremented
  def next_step()
    return @list_of_steps[@current_step]
  end

  ###
  # step_finished
  #
  # logs the last @current_step to the logfile,
  # increments @current_step
  def step_finished()
    if @current_step >= @list_of_steps
      raise "Shouldn't be here"
    end
      
    @logfile.puts @list_of_steps[@current_step]
    @logfile.flush()
    @current_step += 1
  end

  ###
  # task_finished
  #
  # remove log file
  def task_finished()
    if File.exists? @logfile_name
      File.delete @logfile_name
    end
  end

  ###
  private

  def initialize_logfile(task_name)
    @logfile.puts "##############################"
    @logfile.puts "# progress log for task " + task_name
    @logfile.puts "##############################"
  end

  def read_progress_logfile(filename, task_name)
    begin
      file = File.new(filename)
    rescue
      raise "Couldn't read logfile " + filename
    end

    # read file header
    line1 = file.gets().chomp()
    line2 = file.gets().chomp()
    line3 = file.gets().chomp()
    unless line1 == "##############################" and
	line2 == "# progress log for task " + task_name and
	line3 == "##############################"
      raise "Missing log file header in " + filename
    end

    # read steps taken until now
    # they should conform to the @list_of_steps
    index = 0
    while (line = file.gets())
      line.chomp!
      unless line == @list_of_steps[index]
	raise "Log file entry: expected #{@list_of_steps[index]}, got " + line
      end
      index += 1
    end

    # index is now the next step to take
    return index
  end
end
