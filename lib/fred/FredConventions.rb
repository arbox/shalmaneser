# FredConventions
# Katrin Erk June 05
#
# several small things that should be uniform
# throughout the system

require 'monkey_patching/file.rb'
require 'fred/FredFeatures' # AnswerKeyAccess

module Fred

  module_function

  def determine_training_senses(lemma, exp, lemmas_and_senses_obj, split_id)
    if split_id
      # oh no, we're splitting the dataset into random training and test portions.
      # this means that we actually have to look into the training part of the data to
      # determine the number of training senses

      senses_hash = {}

      reader = AnswerKeyAccess.new(exp, "train", lemma, "r", split_id, "train")
      reader.each do |_lemma, _pos, _ids, _sids, gold_senses, _transf_gold_senses|
        gold_senses.each { |s| senses_hash[s] = true }
      end

      return senses_hash.keys

    else
      # we're using separate test data.
      # so we can just look up the number of training senses
      # in the lemmas_and_senses object
      senses = lemmas_and_senses_obj.get_senses(lemma)
      if senses
        return senses
      else
        return []
      end
    end
  end


  ###
  # joining and breaking up senses
  # @note Used only in FredFeatures.
  def fred_join_senses(senses)
    senses.sort.join("++")
  end

  # @note Used only in FredEval.
  def fred_split_sense(joined_senses)
    joined_senses.split("++")
  end

  ###
  # fred_dirname
  #
  # @note Used on multiple positions.
  # constructs a directory name:
  # fred data directory / experiment ID / maindir / subdir
  #
  # if is_existing == existing, the directory is checked for existence,
  # if is_existing == new, it is created if necessary
  #
  # @return [String]
  def fred_dirname(exp,             # FredConfigData object
                   maindir,         # string: main part of directory name
                   subdir,          # string: subpart of directory name
                   is_existing = "existing")  # string: "existing" or "new", default: existing

    case is_existing
    when "existing"
      return File.existing_dir(exp.get("fred_directory"),
                               exp.get("experiment_ID"),
                               maindir,
                               subdir)
    when "new"
      return File.new_dir(exp.get("fred_directory"),
                          exp.get("experiment_ID"),
                          maindir,
                          subdir)
    else
      raise "Shouldn't be here: #{is_existing}"
    end
  end

  ####
  # filenames for feature files
  # @note Used on multiple points.
  def fred_feature_filename(lemma, sense = nil,
                            do_binary = false)
    if do_binary
      return "fred.features.#{lemma}.SENSE.#{sense}"
    else
      return "fred.features.#{lemma}"
    end
  end

  ####
  # filenames for split files
  # @note Used only in FredSplitPkg.
  def fred_split_filename(lemma)
    "fred.split.#{lemma}"
  end

  ###
  # deconstruct split filename
  # returns: lemma
  # @note Not used anywhere.
  def deconstruct_fred_split_filename(filename)
    basename = File.basename(filename)
    if basename =~ /^fred\.split\.(.*)/
      return $1
    else
      return nil
    end
  end

  ###
  # deconstruct feature file name
  # returns: hash with keys
  # "lemma"
  # "sense
  # @note Used only in FredFeatures.
  def deconstruct_fred_feature_filename(filename)
    basename = File.basename(filename)
    retv = {}

    # binary:
    # fred.features.#{lemma}.SENSE.#{sense}
    if basename =~ /^fred\.features\.(.*)\.SENSE\.(.*)$/
      retv["lemma"] = $1
      retv["sense"] = $2
    elsif basename =~ /^fred\.features\.(.*)/
      # fred.features.#{lemma}
      retv["lemma"] = $1

    else
      # complete mismatch
      return nil
    end

    return retv
  end

  ####
  # filename for answer key files
  # @note Used only in FredFeatures.
  def fred_answerkey_filename(lemma)
    return "fred.answerkey.#{lemma}"
  end

  ###
  # classifier directory
  # @note Used on multiple points.
  def fred_classifier_directory(exp,     # FredConfigData object
                                splitID = nil) # string or nil

    if exp.get("classifier_dir")
      # user-specified classifier directory

      if splitID
        return File.new_dir(exp.get("classifier_dir"), splitID)
      else
        return File.new_dir(exp.get("classifier_dir"))
      end

    else
      # my classifier directory
      if splitID
        return fred_dirname(exp, "classifiers", splitID, "new")
      else
        return fred_dirname(exp, "classifiers", "all", "new")
      end
    end
  end

  ###
  # classifier file
  # @note Used on multiple points.
  def fred_classifier_filename(classifier, lemma, sense = nil)
    if sense
      return "fred.classif.#{classifier}.LEMMA.#{lemma}.SENSE.#{sense}"
    else
      return "fred.classif.#{classifier}.LEMMA.#{lemma}"
    end
  end

  # @note Used only in Baseline.
  def deconstruct_fred_classifier_filename(filename)
    retv = {}

    if filename =~ /^fred\.classif\.(.*)\.LEMMA\.(.*)\.SENSE\.(.*)$/
      retv["lemma"] = $2
      retv["sense"] = $3
    elsif filename =~ /^fred\.classif\.(.*)\.LEMMA\.(.*)$/
      retv["lemma"] = $2
    end

    retv
  end

  ###
  # result file
  # @note Used on multiple points.
  def fred_result_filename(lemma)
    "fred.result.#{lemma.gsub(/\./, "_")}"
  end

  ##########
  # lemma and POS: combine into string separated by
  # a separator character
  #
  # fred_lemmapos_combine: take two strings, return combined string
  #      if POS is nil, returns lemma<separator character>
  # fred_lemmapos_separate: take one string, return two strings
  #      if no POS could be retrieved, returns nil as POS and the whole string as lemma
  # @param lemma [String]
  # @param pos [String]
  # @note Used on multiple points.
  def fred_lemmapos_combine(lemma, pos)
    lemma.to_s + "." + pos.to_s.gsub(/\./, "DOT")
  end

  ###
  # @param lemmapos [String]
  # @note Used only in FredDetermineTargets.
  def fred_lemmapos_separate(lemmapos)
    pieces = lemmapos.split(".")

    if pieces.length > 1
      return [pieces[0..-2].join("."), pieces[-1]]
    else
      # no POS found, treat all of lemmapos as lemma
      return [lemmapos, nil]
    end
  end
end
