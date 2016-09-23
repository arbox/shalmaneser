# FredConventions
# Katrin Erk June 05
#
# several small things that should be uniform
# throughout the system

require 'monkey_patching/file.rb'

module Shalmaneser
  module Fred

    module_function

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
    # @param lemma [String]
    # @param pos [String]
    # @note Used on multiple points.
    def fred_lemmapos_combine(lemma, pos)
      lemma.to_s + "." + pos.to_s.gsub(/\./, "DOT")
    end
  end
end
