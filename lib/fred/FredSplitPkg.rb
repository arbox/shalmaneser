##
# splitting package for WSD:
# compute a split for feature files (one item a line, CSV),
# and apply pre-computed split
# to produce new feature files accordingly

require "tempfile"

require "fred/FredDetermineTargets"
require "fred/FredConventions"

class FredSplitPkg
  ###
  def initialize(exp)
    @exp = exp
  end

  ###
  def FredSplitPkg.split_dir(exp, split_id, mode = "existing")
    return fred_dirname(exp, "split", split_id, mode)
  end

  ###
  # make a new split
  def make_new_split(split_id,  # string: ID
                     trainpercent, # float: percentage training data
                     ignore_unambiguous = false)

    # where to store the split?
    split_dir = FredSplitPkg.split_dir(@exp, split_id, "new")

    lemmas_and_senses = Targets.new(@exp, nil, "r")
    unless lemmas_and_senses.targets_okay
      # error during initialization
      $stderr.puts "Error: Could not read list of known targets, bailing out."
      exit 1
    end

    # Iterate through lemmas,
    # split training feature files.
    #
    # Do the split only once per lemma,
    # even if we have sense-specific feature files
    feature_dir =  fred_dirname(@exp, "train", "features")

    lemmas_and_senses.get_lemmas().each { |lemma|
      # construct split file
      splitfilename = split_dir + fred_split_filename(lemma)
      begin
        splitfile = File.new(splitfilename, "w")
      rescue
        raise "Error: Couldn't write to file " + splitfilename
      end
      
      # find lemma-specific  feature file

      filename = feature_dir + fred_feature_filename(lemma)

      unless File.exists?(filename)
        # try lemma+sense-specific feature file
        file_pattern = fred_feature_filename(lemma, "*", true)
        filename = Dir[feature_dir + file_pattern].first()

        unless filename
          # no lemma+sense-specific feature file
          $stderr.puts "Warning: split: no feature file found for #{lemma}, skipping." 
          splitfile.close()
          next
        end
      end
      
      # open feature file for reading
      begin
        file = File.new(filename)
      rescue
        raise "Couldn't read feature file " + filename
      end

      if ignore_unambiguous and
          lemmas_and_senses.get_senses(lemma).length() < 2
        # unambiguous: ignore

        while file.gets()
          splitfile.puts "ignore"
        end
        
      else
        # read from feature file, classify at random
        # as train or test,
        # write result to splitfile
          
        while file.gets()
          if rand() < trainpercent
            splitfile.puts "train"
          else
            splitfile.puts "test"
          end
        end
      end

      splitfile.close()
    }
  end

  ###
  # remove an old split
  def FredSplitPkg.remove_split(exp,      # FredConfigData object
                                splitID)  # string: split ID
    begin
      split_dir = FredSplitPkg.split_dir(exp, splitID, "new")
    rescue
      # no split to be removed
      return
    end
    %x{rm -rf #{split_dir}}
  end


  ###
  # change feature files according to 
  # pre-computed split
  #
  #
  # returns: tempfile containing featurized items,
  # according to split,
  # or nil if the split file wouldn't contain any data
  def apply_split(filename, # feature file
                  lemma,    # string: lemma that filename is about
                  dataset,  # string: train, test
                  split_id) # string: split ID


    split_filename = FredSplitPkg.split_dir(@exp, split_id) +
      fred_split_filename(lemma)

    # read feature file and split file at the same time
    # write to tempfile.
    f_feat = File.new(filename)
    f_split = File.new(split_filename)
    f_out = Tempfile.new("fred_split")

    num_yes = 0

    f_feat.each { |line|
      begin
        split_part = f_split.readline().chomp()
      rescue
        $stderr.puts "FredSplit error: split file too short."
        $stderr.puts "skipping rest of featurization data."
        $stderr.puts "Split file: #{split_filename}"
        $stderr.puts "Feature file: #{filename}"
        raise "HIER"
        f_out.close()
        if num_yes > 0
          return f_out
        else
          return nil
        end
      end

      if split_part == dataset
        # write training data, and this item is in the training
        # part of the split,
        # or write test data, and item is in test part
        f_out.puts line
        num_yes += 1
      end
    }
    f_out.close()
    f_feat.close()
    f_split.close()

    if num_yes > 0
      return f_out
    else
      return nil
    end

  end
end
