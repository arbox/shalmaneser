require 'fileutils'

# Extensions for the class File.
class File
  ########
  # check whether a given path exists,
  # and if it doesn't, make sure it is created.
  #
  # piece together the strings in 'pieces' to make the path,
  # appending "/" to all strings if necessary
  #
  # returns: the path pieced together
  # strings, to be pieced together
  def self.new_dir(*pieces)
    dir_path, _dummy = File.make_path(pieces, true)

    unless File.exist?(dir_path)
      FileUtils.mkdir_p(dir_path)
    end
    # check that all went well in creating the directory)
    File.existing_dir(dir_path)

    dir_path
  end

  ########
  # same as new_dir, but last piece is a filename
  def self.new_filename(*pieces)
    dir_path, whole_path = File.make_path(pieces, false)

    unless File.exist?(dir_path)
      FileUtils.mkdir_p dir_path
    end
    # check that all went well in creating the directory)
    File.existing_dir(dir_path)

    whole_path
  end

  #####
  # check whether a given path exists,
  # and report failure of it does not exist.
  #
  # piece together the strings in 'pieces' to make the path,
  # appending "/" to all strings if necessary
  #
  # returns: the path pieced together
  def self.existing_dir(*pieces) # strings
    dir_path, _dummy = File.make_path(pieces, true)

    unless File.exist?(dir_path) && File.directory?(dir_path)
      $stderr.puts "Error: Directory #{dir_path} doesn't exist. Exiting."
      exit(1)
    end
    unless File.executable? dir_path
      $stderr.puts "Error: Cannot access directory #{dir_path}. Exiting."
      exit(1)
    end

    dir_path
  end

  ####
  # like existing_dir, but last bit is filename
  def self.existing_filename(*pieces)
    dir_path, whole_path = File.make_path(pieces, false)

    unless File.exist?(dir_path) && File.directory?(dir_path)
      $stderr.puts "Error: Directory #{dir_path} doesn't exist. Exiting"
      exit(1)
    end

    unless File.executable?(dir_path)
      $stderr.puts "Error: Cannot access directory #{dir_path}. Exiting."
      exit(1)
    end

    whole_path
  end

  ####
  # piece together the strings in 'pieces' to make a path,
  # appending "/" to all but the last string if necessary
  #
  # if 'pieces' is already a string, take that as a one-piece path
  #
  # if dir is true, also append "/" to the last piece of the string
  #
  # the resulting path is expanded: For example, initial
  # ~ is expanded to the setting of $HOME
  #
  # returns: pair of strings (directory_part, whole_path)
  # @param pieces [String, Array]
  # @param is_dir [True, False, Nil]
  def self.make_path(pieces, is_dir = false)
    if pieces.is_a?(String)
      pieces = [pieces]
    end

    dir = ''
    # iterate over all but the filename
    if is_dir
      last_dir_index = -1
    else
      last_dir_index = -2
    end
    pieces[0..last_dir_index].each { |piece|
      if piece.nil?
        # whoops, nil entry in name of path!
        $stderr.puts "File.make_path ERROR: nil for piece of path name."
        next
      end
      if piece =~ /\/$/
        dir << piece
      else
        dir << piece << "/"
      end
    }

    dir = File.expand_path(dir)

    # expand_path removes the final "/" again
    unless dir =~ /\/$/
      dir = dir + "/"
    end

    is_dir ? [dir, dir] : [dir, dir + pieces[-1]]
  end
end
