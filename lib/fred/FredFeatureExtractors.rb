class FredFeatureInfo
  ###
  # class variable:
  # list of all known extractors
  # add to it using add_feature()
  @@extractors = []

  # boolean. set to true after warning messages have been given once
  @@warned = false

  ###
  # add interface/interpreter
  def FredFeatureInfo.add_feature(class_name) # Class object
    @@extractors << class_name
  end

  ###
  def initialize(exp)

    ##
    # make list of extractors that are
    # required by the user
    @features = []
    @exp = exp

    # user-chosen extractors:
    # returns array of pairs [feature group designator(string), options(array:string)]
    exp.get_lf("feature").each { |extractor_name, *options|

      extractor = @@extractors.detect { |e| e.feature_name == extractor_name }
      unless extractor
        # no extractor found matching the given designator
        unless @@warned
          $stderr.puts "Warning: Could not find a feature extractor for #{extractor_name}: skipping."
        end
        next
      end

      # no need to use the options here,
      # the feature extractors can get their options themselves.
      @features << extractor
    }

    # do not print warnings again if another RosyFeatureInfo object is made
    @@warned = true
  end

  ###
  # get_extractor_objects
  #
  # returns a list of feature extractor objects
  def get_extractor_objects

    return @features.map{ |feature_class|
      feature_class.new(@exp)
    }
  end
end

##################################3
class FredFeatureExtractor
  ###
  # feature name:
  # name by which you choose this feature
  # in the experiment file
  def FredFeatureExtractor.feature_name
    raise "Overwrite me."
  end

  ###
  # initialize with Fred experiment file object
  def initialize(exp)
    @exp = exp
  end

  ###
  # compute features from meta-features
  #
  # argument: hash
  # metafeature_label -> metafeatures
  #  string -> array:string
  #
  # yields each feature as a string
  def each_feature(feature_hash)
    raise "overwrite me"
  end

  ######
  protected

  def FredFeatureExtractor.announce_me
    # AB: In 1.9 constants are symbols.
    if Module.constants.include?("FredFeatureInfo") or Module.constants.include?(:FredFeatureInfo)
      # yup, we have a class to which we can announce ourselves
      FredFeatureInfo.add_feature(self)
    else
      # no interface collector class
      #      $stderr.puts "Feature #{self.name()} not announced: no RosyFeatureInfo."
    end
  end

end

#####
# context feature
class FredContextFeatureExtractor < FredFeatureExtractor
  FredContextFeatureExtractor.announce_me

  def FredContextFeatureExtractor.feature_name
    return "context"
  end

  ###
  def initialize(exp)
    super(exp)

    # cxsizes: list of context sizes chosen as features,
    # encoded in metafeature labels
    # written in a hash for fast access
    @cxsizes = {}
    @exp.get_lf("feature", "context").each { |cxsize|
      @cxsizes[ "CX" + cxsize.to_s ] = true
    }
  end

  ###
  def each_feature(feature_hash)
    # grf#word#lemma#pos#ne
    lemma_index = 2

    feature_hash.each { |ftype, fvalues|
      if @cxsizes[ftype]
        # this is a context feature of a size chosen
        # by the user for featurization

        fvalues.each { |f|
          next if f =~ /#####/;
          yield ftype + f.split("#")[lemma_index]
        }
      end
    }
  end
end

#####
# context feature: POS separately, small contexts only
class FredContextPOSFeatureExtractor < FredFeatureExtractor
  FredContextPOSFeatureExtractor.announce_me

  def FredContextPOSFeatureExtractor.feature_name
    return "context_pos"
  end

  ###
  def initialize(exp)
    super(exp)

    # cxsizes: list of context sizes chosen as features,
    # encoded in metafeature labels
    # written in a hash for fast access
    @cxsizes = {}
    @exp.get_lf("feature", "context").each { |cxsize|
      if cxsize <= 10
        @cxsizes[ "CX" + cxsize.to_s ] = true
      end
    }
    if @cxsizes.empty?
      $stderr.puts "context_pos feature warning: will not be computed"
      $stderr.puts "as there is no context of size <= 10"
    end
  end

  ###
  def each_feature(feature_hash)
    # word#lemma#pos#ne
    pos_index = 2

    feature_hash.each { |ftype, fvalues|
      if @cxsizes[ftype]
        # this is a context feature of a size chosen
        # by the user for featurization

        fvalues.each { |f|
          yield "POS" + ftype + f.split("#")[pos_index]
        }
      end
    }
  end
end

#####
# bigram/trigram feature
class FredNgramFeatureExtractor < FredFeatureExtractor
  FredNgramFeatureExtractor.announce_me

  def FredNgramFeatureExtractor.feature_name
    return "ngram"
  end

  ###
  def initialize(exp)
    super(exp)

    # cxsize: context size from which the ngram feature will be computed
    # encoded in metafeature labels
    # written in a hash for fast access
    @cxsize = @exp.get_lf("feature", "context").detect { |cxsize|
      cxsize >= 2
    }
    unless @cxsize
      $stderr.puts "Warning: no context of size >= 2, so"
      $stderr.puts "no ngram feature computed."
    end
  end

  ###
  def each_feature(feature_hash)
    # word#lemma#pos#ne
    lemma_index = 1
    pos_index = 2

    feature_hash.each { |ftype, fvalues|
      if ftype == "CX" + @cxsize.to_s
        # compute the ngram features from this context
        # |fvalues| = 2*cxsize, that is, cxsize describes
        # the length of a one-sided context window
        # the bigram of features around the target
        # concerns fvalues[cxsize-1] and fvalues[cxsize]
        # the trigram of two words before, one word after includes
        # fvalues[cxsize-2], fvalues[cxsize-1] and fvalues[cxsize]

        [
          [[-1, 0], "BLEM", lemma_index], # bigram of lemmas
          [[-1, 0], "BPOS", pos_index],   # bigram of POSs
          [[-2, -1, 0], "TLEM", lemma_index], # trigram of lemmas
          [[-2, -1, 0], "TPOS", pos_index] # trigram of POSs
        ].each { |f_indices, label, subindex|
          fs = f_indices.map { |i| fvalues[@cxsize+i] }.compact
          if fs.length == f_indices.length
            # we successfully extracted entries for all the given indices
            yield label + fs.map { |f| f.split("#")[subindex] }.join
          end
        }
      end
    }
  end
end


#####
# syntax feature
class FredSynFeatureExtractor < FredFeatureExtractor
  FredSynFeatureExtractor.announce_me

  def FredSynFeatureExtractor.feature_name
    return "syntax"
  end

  ###
  def each_feature(feature_hash)

    feature_hash.each { |ftype, fvalues|

      case ftype
      when "CH", "PA"
        grf_index = 0

        fvalues.each { |f|
          yield ftype + f.split("#")[grf_index]
        }

      when "SI"
        # parentlemma#grf#word#lemma#pos#ne
        grf_index = 1

        fvalues.each { |f|
          yield ftype + f.split("#")[grf_index]
        }

      else
        # not a syntactic metafeature
      end
    }
  end
end




#####
# syntax-plus-headword feature
class FredSynsemFeatureExtractor < FredFeatureExtractor
  FredSynsemFeatureExtractor.announce_me

  def FredSynsemFeatureExtractor.feature_name
    return "synsem"
  end

  ###
  def each_feature(feature_hash)

    feature_hash.each { |ftype, fvalues|
      case ftype
      when "CH", "PA"
        # grf#word#lemma#pos#ne
        fvalues.each { |f|
          yield ftype + "SEM" + f
        }

      when "SI"
        # parentlemma#grf#word#lemma#pos#ne
        # remove parent lemma
        fvalues.each { |f|
          yield ftype + "SEM" + f.split("#")[1..-1].join("#")
        }

      else
        # not a syntax feature
      end
    }
  end
end
