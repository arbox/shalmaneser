# -*- coding: utf-8 -*-
require "tempfile"
require "delegate"

require "fred/FredFeatureExtractors"
require 'fred/FredConventions' # !

module Shalmaneser
module Fred
########################################
########################################
# Feature access classes:
# read and write features
class AbstractFredFeatureAccess
  ####
  def initialize(exp, # experiment file object
                 dataset, # dataset: "train" or "test"
                 mode = "r") # mode: r, w, a
    @exp = exp
    @dataset = dataset
    @mode = mode

    unless ["r", "w", "a"].include? @mode
      $stderr.puts "FeatureAccess: unknown mode #{@mode}."
      exit 1
    end

  end

  ####
  def AbstractFredFeatureAccess.remove_feature_files
    raise "overwrite me"
  end

  ####
  def write_item(lemma,  # string: lemma
                 pos,    # string: POS
                 ids,    # array:string: unique IDs of this occurrence of the lemma
                 sid,    # string: sentence ID
                 sense,  # string: sense
                 features) # features: hash feature type-> features (string-> array:string)
    raise "overwrite me"
  end


  def flush
    raise "overwrite me"
  end
end

########################################
# MetaFeatureAccess:
# write all featurization data to one gzipped file,
# directly writing the meta-features as they come
# format:
#
# lemma pos id sense
#   <feature_type>: <features>
#
# where feature_type is a word, and features is a list of words, space-separated
class MetaFeatureAccess < AbstractFredFeatureAccess
  ###
  def initialize(exp, dataset, mode)
    super(exp, dataset, mode)

    @filename = MetaFeatureAccess.filename(@exp, @dataset)

    # make filename for writing features
    case @mode

    when "w", "a", "r"
      # read or write access
      @f = FileZipped.new(@filename, mode)

    else
      $stderr.puts "MetaFeatureAccess error: illegal mode #{mode}"
      exit 1
    end
  end


  ####
  def MetaFeatureAccess.filename(exp, dataset, mode="new")
    return ::Shalmaneser::Fred.fred_dirname(exp, dataset, "meta_features", mode) +
      "meta_features.txt.gz"
  end

  ####
  def MetaFeatureAccess.remove_feature_files(exp, dataset)
    filename = MetaFeatureAccess.filename(exp, dataset)
    if File.exists?(filename)
      File.delete(filename)
    end
  end


  ###
  # read items, yield one at a time
  #
  # format: tuple consisting of
  # - target_lemma: string
  # - target_pos: string
  # - target_ids: array:string
  # - target SID: string, sentence ID
  # - target_senses: array:string
  # - feature_hash: feature_type->values, string->array:string
  def each_item
    unless @mode == "r"
      $stderr.puts "MetaFeatureAccess error: cannot read file not opened for reading"
      exit 1
    end

    lemma = pos = sid = ids = senses = nil

    feature_hash = {}

    @f.each { |line|
      line.chomp!
      if line =~ /^\s/
        # line starts with whitespace: continues description of previous item
        # that is, if we have a previous item
        #
        # format of line:
        #    feature_type: feature feature feature ...
        # as in
        #    CH: SB#expansion#expansion#NN# OA#change#change#NN#
        unless lemma
          $stderr.puts "MetaFeatureAccess error: unexpected leading whitespace"
          $stderr.puts "in meta-feature file #{@filename}, ignoring line:"
          $stderr.puts line
          next
        end

        feature_type, *features = line.split

        unless feature_type =~ /^(.*):$/
          # feature type should end in ":"
          $stderr.puts "MetaFeatureAccess error: feature type should end in ':' but doesn't"
          $stderr.puts "in meta-feature file #{@filename}, ignoring line:"
          $stderr.puts line
          next
        end

        feature_hash[feature_type[0..-2]] = features


      else
        # first line of item.
        #
        # format:
        # lemma POS IDs sid senses
        #
        # as in:
        # cause verb 2-651966_8 2-651966 Causation

        # first yield previous item
        if lemma
          yield [lemma, pos, ids, sid, senses, feature_hash]
        end

        # then start new item:
        lemma, pos, ids_s, sid, senses_s = line.split
        ids = ids_s.split("::").map { |i| i.gsub(/COLON/, ":") }
        senses = senses_s.split("::").map { |s| s.gsub(/COLON/, ":") }

        # reset feature hash
        feature_hash.clear
      end
    }

    # one more item to yield?
    if lemma
      yield [lemma, pos, ids, sid, senses, feature_hash]
    end
  end



  ###
  def write_item(lemma,  # string: target lemma
                 pos,    # string: target pos
                 ids,    # array:string: unique IDs of this occurrence of the lemma
                 sid,    # string: sentence ID
                 senses, # array:string: sense
                 features) # features: hash feature type-> features (string-> array:string)

    unless ["w", "a"].include? @mode
      $stderr.puts "MetaFeatureAccess error: cannot write to feature file opened for reading"
      exit 1
    end

    if not(lemma) or lemma.empty? or not(ids) or ids.empty?
      # nothing to write
      # HIER debugging
      # raise "HIER no lemma or no IDs: #{lemma} #{ids}"
      return
    end
    if pos.nil? or pos.empty?
      # POS unknown
      pos = ""
    end
    unless senses
      senses = [ @exp.get("noval") ]
    end

    ids_s = ids.map { |i| i.gsub(/:/, "COLON") }.join("::")

    senses_s = senses.map { |s| s.gsub(/:/, "COLON") }.join("::")
    @f.puts "#{lemma} #{pos} #{ids_s} #{sid} #{senses_s}"
    features.each_pair { |feature_type, f_list|
      @f.puts "   #{feature_type}: " + f_list.map { |f| f.to_s }.join(" ")
    }
    @f.flush
  end

  ###
  def flush
    unless ["w", "a"].include? @mode
      $stderr.puts "MetaFeatureAccess error: cannot write to feature file opened for reading"
      exit 1
    end

    # actually, nothing to be done here
  end

end


########################################
# FredFeatureWriter:
# write chosen features (according to the experiment file)
# to
# - one file per lemma for n-ary classification
# - one file per lemma/sense pair for binary classification
#
# format: CSV, last entry is target class
class FredFeatureAccess < AbstractFredFeatureAccess
  ###
  def initialize(exp, dataset, mode)
    super(exp, dataset, mode)

    # write to auxiliary files first,
    # to sort items by lemma
    @w_tmp = AuxKeepWriters.new

    # which features has the user requested?
    feature_info_obj = FredFeatureInfo.new(@exp)
    @feature_extractors = feature_info_obj.get_extractor_objects

  end

  ####
  def FredFeatureAccess.remove_feature_files(exp, dataset)

    # remove feature files
    WriteFeaturesNaryOrBinary.remove_files(exp, dataset)

    # remove key files
    AnswerKeyAccess.remove_files(exp, dataset)
  end

  ###
  def  FredFeatureAccess.legend_filename(lemmapos)
    return "fred.feature_legend.#{lemmapos}"
  end

  ###
  def FredFeatureAccess.feature_dir(exp, dataset)
    return WriteFeaturesNaryOrBinary.feature_dir(exp, dataset, "new")
  end

  ###
  # each feature file:
  # iterate through feature files,
  # yield pairs [filename, values]
  # where 'values' is a hash containing keys
  # 'lemma' and potentially 'sense'
  #
  # filenames are sorted alphabetically before being yielded
  #
  # available in read and write mode
  def FredFeatureAccess.each_feature_file(exp, dataset)
    feature_dir = FredFeatureAccess.feature_dir(exp, dataset)
    Dir[feature_dir + "*"].sort.each { |filename|
      if (values = ::Shalmaneser::Fred.deconstruct_fred_feature_filename(filename))
        yield [filename, values]
      end
    }
  end

  ###
  # write item:
  # - transform meta-features into actual features as requested
  #   in the experiment file
  # - write item to tempfile, don't really write yet
  def write_item(lemma,  # string: target lemma
                 pos,    # string: target pos
                 ids,    # array:string: unique IDs of this occurrence of the lemma
                 sid,    # string: sentence ID
                 senses,  # array:string: sense
                 features) # features: hash feature type-> features (string-> array:string)


    unless ["w", "a"].include? @mode
      $stderr.puts "FredFeatures error: cannot write to feature file opened for reading"
      exit 1
    end

    if lemma.nil? or lemma.empty? or ids.nil? or ids.empty?
      # nothing to write
      return
    end
    if pos.nil? or pos.empty?
      # POS unknown
      pos = ""
    end

    # falsch! noval nicht zulässig für fred! (nur für rosy!) - Warum steht das hier???
    unless senses
      senses = [ @exp.get("noval") ]
    end

    # modified by ines, 19.7.2010
    # senses should be empty, but they are not - why?
    if senses.length == 1 and senses[0].eql? ""
        senses = "NONE"
    end

    writer = @w_tmp.get_writer_for(::Shalmaneser::Fred.fred_lemmapos_combine(lemma, pos))
    ids_s = ids.map { |i| i.gsub(/:/, "COLON") }.join("::")

    # AB: Ines modified <senses> and it can be a String.
    # That's corrected, but I do not guarantee the correct results.
    if senses.respond_to? :map
      senses_s = senses.map { |s| s.gsub(/:/, "COLON") }.join("::")
    end
    writer.print "#{lemma} #{pos} #{ids_s} #{sid} #{senses_s} "

    # write all features
    @feature_extractors.each { |extractor|
      extractor.each_feature(features) { |feature|
        writer.print feature, " "
      }
    }
    writer.puts
    writer.flush
  end

  ###
  def flush
    unless ["w", "a"].include? @mode
      $stderr.puts "FredFeatureAccess error: cannot write to feature file opened for reading"
      exit 1
    end

    # elements in the feature vector: get fixed with the training data,
    # get read with the test data.
    # get stored in feature_legend_dir
    case @dataset
    when "train"
      feature_legend_dir = File.new_dir(::Shalmaneser::Fred.fred_classifier_directory(@exp),
                                        "legend")
    when "test"
      feature_legend_dir= File.existing_dir(::Shalmaneser::Fred.fred_classifier_directory(@exp),
                                        "legend")
    end

    # now really write features
    @w_tmp.flush
    @w_tmp.get_lemmas.sort.each { |lemmapos|

      # inform user
      $stderr.puts "Writing #{lemmapos}..."

      # prepare list of features to use in the feature vector:
      legend_filename = feature_legend_dir + FredFeatureAccess.legend_filename(lemmapos)

      case @dataset
      when "train"
        # training data:
        # determine feature list and sense list from the data,
        # and store in the relevant file
        feature_list, sense_list = collect_feature_list(lemmapos)
        begin
          f = File.new(legend_filename, "w")
        rescue
          $stderr.puts "Error: Could not write to feature legend file #{legend_filename}: " + $!
          exit 1
        end
        f.puts feature_list.map { |x| x.gsub(/,/, "COMMA") }.join(",")
        f.puts sense_list.map { |x| x.gsub(/,/, "COMMA") }.join(",")
        f.close

      when "test"
        # test data:
        # read feature list and sense list from the relevant file

        begin
          f = File.new(legend_filename)
        rescue
          $stderr.puts "Error: Could not read feature legend file #{legend_filename}: " + $!
          $stderr.puts "Skipping this lemma."
          next
        end
        feature_list = f.gets.chomp.split(",").map { |x| x.gsub(/COMMA/, ",") }
        sense_list = f.gets.chomp.split(",").map { |x| x.gsub(/COMMA/, ",") }
      end

      # write
      # - featurization file
      # - answer key file

      f = @w_tmp.get_for_reading(lemmapos)
      answer_obj = AnswerKeyAccess.new(@exp, @dataset, lemmapos, "w")

      obj_out = WriteFeaturesNaryOrBinary.new(lemmapos, @exp, @dataset)

      f.each { |line|

        lemma, pos, ids, sid, senses, features = parse_temp_itemline(line)
        unless lemma
          # something went wrong in parsing the line
          next
        end
        each_sensegroup(senses, sense_list) { |senses_for_item, original_senses|
          # write answer key
          answer_obj.write_line(lemma, pos,
                                ids, sid, original_senses, senses_for_item)

          # write item: features, senses
          obj_out.write_instance(to_feature_list(features, feature_list),
                                 senses_for_item)
        } # each sensegroup
      } # each input line
      obj_out.close
      answer_obj.close
      @w_tmp.discard(lemmapos)
    } # each lemma


  end

  ##################
  protected

  ###
  # read temp feature file for the given lemma/pos
  # and determine the list of all features and the list of all senses,
  # each sorted alphabetically
  def collect_feature_list(lemmapos)
    # read entries for this lemma
    f = @w_tmp.get_for_reading(lemmapos)

    # keep a record of all senses and features
    # senses: binary.
    # features: keep the max. number of times a given feature occurred
    #         in an instance
    all_senses = {}
    all_features = Hash.new(0)
    features_this_instance = Hash.new(0)
    # record how often each feature occurred all in all
    num_occ = Hash.new(0)
    num_lines = 0

    f.each { |line|
      lemma, pos, id_string, sid, senses, features = parse_temp_itemline(line)

      unless lemma
        # something went wrong in parsing the line
        # print out the file contents for reference, then leave
        $stderr.puts "Could not read temporary feature file #{f.path} for #{lemmapos}."
        exit 1
      end
      num_lines += 1
      senses.each { |s| all_senses[s] = true }
      features_this_instance.clear
      features.each { |fea|
        features_this_instance[fea] += 1
        num_occ[fea] += 1
      }

      features_this_instance.each_pair { |feature, value|
        all_features[feature] = [ all_features[feature], features_this_instance[feature] ].max
      }
    }

    # HIER
    # if num_lines > 2
    #  num_occ.each_pair { |feature, num_occ|
    #    if num_occ < 2
    #      all_features.delete(feature)
    #    end
    #  }
    # end



    case @exp.get("numerical_features")
    when "keep"
      # leave numerical features as they are, or
      # don't do numerical features
      return [ all_features.keys.sort,
               all_senses.keys.sort
             ]

    when "repeat"
      # repeat: turn numerical feature with max. value N
      # into N binary features
      feature_list = []
      all_features.keys.sort.each { |feature|
        all_features[feature].times { |index|
          feature_list << feature + " #{index}/#{all_features[feature]}"
        }
      }
      return [ feature_list,
               all_senses.keys.sort
             ]

    when "bin"
      # make bins:
      # number of bins = (max. number of occurrences of a feature per item) / 10
      feature_list = []
      all_features.keys.sort.each { |feature|
        num_bins_this_feature = (all_features[feature].to_f / 10.0).ceil.to_i

        num_bins_this_feature.times { |index|
          feature_list << feature  + " #{index}/#{num_bins_this_feature}"
        }
      }
      return [ feature_list,
               all_senses.keys.sort
             ]
    else
      raise "Shouldn't be here"
    end
  end


  ###
  # given a full sorted list of items and a partial list of items,
  # match the partial list to the full list,
  # that is, produce as many items as the full list has
  # yielding 0 where the partial entry is not in the full list,
  # and > 0 otherwise
  #
  # Note that if partial contains items not in full,
  # they will not occur on the feature list returned!
  def to_feature_list(partial, full,
                      handle_numerical_features = nil)

    #print "FULL: ", full, "\n"
    #print "PART: ", partial, "\n"
    # count occurrences of each feature in the partial list
    occ_hash = Hash.new(0)
    partial.each { |p|
      occ_hash[p] += 1
    }

    # what to do with our counts?
    unless handle_numerical_features
      # no pre-set value given when this function was called
      handle_numerical_features = @exp.get("numerical_features")
    end

    case handle_numerical_features
    when "keep"
      # leave numerical features as numerical features
      return full.map { |x|
        occ_hash[x].to_s
      }

    when "repeat"
      # repeat each numerical feature up to a max. number of occurrences
      return full.map { |feature_plus_count|
        unless feature_plus_count =~ /^(.*) (\d+)\/(\d+)$/
          $stderr.puts "Error: could not parse feature: #{feature_plus_count}, bailing out."
          raise "Shouldn't be here."
        end

        feature = $1
        current_count = $2.to_i
        max_num = $3.to_i

        if occ_hash[feature] > current_count
          1
        else
          0
        end
      }

    when "bin"
      # group numerical feature values into N bins.
      # number of bins varies from feature to feature
      # each bin contains 10 different counts
      return full.map { |feature_plus_count|
        unless feature_plus_count =~ /^(.*) (\d+)\/(\d+)$/
          $stderr.puts "Error: could not parse feature: #{feature_plus_count}, bailing out."
          raise "Shouldn't be here."
        end

        feature = $1
        current_count = $2.to_i
        max_num = $3.to_i

        if occ_hash[feature] % 10 > (10 * current_count)
          1
        else
          0
        end
      }
    else
      raise "Shouldn't be here"
    end
  end


  ###
  # how to treat instances with multiple senses?
  # - either write one item per sense
  # - or combine all senses into one string
  # - or keep as separate senses
  #
  # according to 'handle_multilabel' in the experiment file
  #
  # yields pairs of [senses, original_senses]
  # both are arrays of strings
  def each_sensegroup(senses, full_sense_list)
    case @exp.get("handle_multilabel")
    when "keep"
      yield [senses, senses]
    when "join"
      yield [[::Shalmaneser::Fred.fred_join_senses(senses)], senses]
    when "repeat"
      senses.each { |s|
        yield [ [s], senses]
      }
    when "binarize"
      yield [ senses, senses ]
    else
      $stderr.puts "Error: unknown setting #{exp.get("handle_multilabel")}"
      $stderr.puts "for 'handle_multilabel' in the experiment file."
      $stderr.puts "Please choose one of 'binary', 'keep', 'join', 'repeat'"
      $stderr.puts "or leave unset -- default is 'binary'."
      exit 1
    end
  end

  ###
  def parse_temp_itemline(line)
    lemma, pos, ids_s, sid, senses_s, *features = line.split
    # fix me! senses is empty, takes context features instead
    unless senses_s
      # features may be empty, but we need senses
      $stderr.puts "FredFeatures Error in word sense item line: too short."
      $stderr.puts ">>#{line}<<"
      return nil
    end

    ids = ids_s.split("::").map { |i| i.gsub(/COLON/, ":") }
    senses = senses_s.split("::").map { |s| s.gsub(/COLON/, ":") }

    return [lemma, pos, ids, sid, senses, features]
  end

end

########################################
# read and write access to answer key files
# manages a single answer key file for a given lemma/POS pair
class AnswerKeyAccess
  ###
  def initialize(exp,      # experiment file object
                 dataset,  # "train", "test"
                 lemmapos, # lemma + POS (one string)
                 mode,     # "r", "w", "a"
                 split_id = nil,
                 split_dataset = nil)
    unless ["r", "w", "a"].include? mode
      $stderr.puts "FredFeatures error: AnswerKeyAccess initialized with mode #{mode}."
      exit 1
    end

    @mode = mode

    answer_filename = ::Shalmaneser::Fred.fred_dirname(exp, dataset, "keys", "new") +
      ::Shalmaneser::Fred.fred_answerkey_filename(lemmapos)

    # are we reading the whole answer key file, or only the test part
    # of a split of it?
    if split_id
      # we are accessing part of a split
      # we can only do that when reading!
      unless @mode == "r"
        $stderr.puts "AnswerKeyAccess error: cannot access split answer file in write mode."
        exit 1
      end

      # apply_split returns a closed temporary file
      split_obj = FredSplitPkg.new(exp)
      @f = split_obj.apply_split(answer_filename, lemmapos, split_dataset, split_id)
      if @f.nil?
        # the split_dataset part of the split doesn't contain any data
        $stderr.puts "Warning: no #{split_dataset} data for lemma #{lemmapos}"
      else
        @f.open
      end

    else
      # we are reading the whole thing
      begin
        @f = File.new(answer_filename, @mode)
      rescue
        @f = nil
      end
    end
  end

  ###
  def write_line(lemma,     # string: lemma
                 pos,       # string: POS
                 ids,       # array:string: target IDs
                 sid,       # string: sentence ID
                 senses,    # array:string: senses
                 senses_this_item) # array:string: senses for this item
    unless ["w", "a"].include? @mode
      $stderr.puts "FredFeatures error: AnswerKeyAccess: cannot write in read mode."
      exit 1
    end
    unless @f
      raise "Shouldn't be here"
    end

    # write answer key:
    # lemma POS ID senses
    if senses.include? nil or senses.include? ""
      raise "empty sense"
    end
    if senses_this_item.include? nil or senses_this_item.include? ""
      raise "empty sense for this item"
    end

    senses_s = senses.map { |s| s.gsub(/,/, "COMMA")}.join(",")
    senses_ti_s = senses_this_item.map { |s|
      s.gsub(/,/, "COMMA")}.join(",")
    id_s = ids.map { |i| i.gsub(/:/, "COLON") }.join("::")

    @f.puts "#{lemma} #{pos} #{id_s} #{sid} #{senses_s} #{senses_ti_s}"
  end

  ###
  # yield one line at a time:
  # tuple (lemma, POS, ids, sentence_ID, all_assigned_senses, transformed_senses_for_this_item)
  def each
    unless @mode == "r"
      $stderr.puts "FredFeatures error: AnsewrKeyAccess: cannot read in write mode"
    end
    unless @f
      # something went wrong during initialization:
      # split didn't contain data
      return
    end

    @f.each { |line|

      lemma, pos, id_s, sid, senses_s, senses_this_item_s = line.split
      ids = id_s.split("::").map { |i| i.gsub(/COLON/, ":") }
      senses = senses_s.split(",").map { |s| s.gsub(/COMMA/, ",") }

      senses_this_item = senses_this_item_s.split(",").map { |s|
        s.gsub(/COMMA/, ",") }

      yield [lemma, pos, ids, sid, senses, senses_this_item]
    }
  end

  ###
  def close
    @f.close
  end

  ###
  def AnswerKeyAccess.remove_files(exp, dataset)
    Dir[::Shalmaneser::Fred.fred_dirname(exp, dataset, "keys", "new") + ::Shalmaneser::Fred.fred_answerkey_filename("*")].each { |filename|
      if File.exists?(filename)
        File.delete(filename)
      end
    }
  end
end


####################3
# keep writers: auxiliary class for FredFeatureAccess:
# write to several files at a time
# in tempfiles
class AuxKeepWriters
  def initialize
    @lemma2temp = {}
    @size = 50
    @writers = []
  end


  ##
  def flush
    @writers.each { |lemmapos, writer|
      writer.close
    }
  end

  ##
  def get_lemmas
    return @lemma2temp.keys
  end

  ##
  def get_for_reading(lemmapos)
    if @lemma2temp[lemmapos]
      # we have a writer for this

      @lemma2temp[lemmapos].close
      @lemma2temp[lemmapos].open
      return @lemma2temp[lemmapos]

    else
      # no writer for this
      return nil
    end
  end

  ##
  # finally close temp file, remove information for lemma/pos
  def discard(lemmapos)
    if @lemma2temp[lemmapos]
      @lemma2temp[lemmapos].close(true)
      @lemma2temp.delete(lemmapos)
    end
  end

  ##
  def get_writer_for(lemmapos)

    # is there a temp file for this lemma/pos combination?
    unless @lemma2temp[lemmapos]
      @lemma2temp[lemmapos] = Tempfile.new("fred_features")
      @lemma2temp[lemmapos].close
    end

    # is there an open temp file for this lemma/pos combination?
    pair = @writers.assoc(lemmapos)
    if pair
      return pair.last
    end

    # no: open the temp file, kick some other temp file out of the
    # @writers list
    writer = @lemma2temp[lemmapos]
    writer.open


    # writer: open for appending
    writer.seek(0, IO::SEEK_END)


    @writers << [lemmapos, writer]
    if @writers.length > @size
      # close file associated with first writer
      @writers.first.last.close
      @writers.shift
    end
    return writer
  end

  ###
  def remove_files
    @lemma2temp.each_value { |x|
      x.close(true)
    }
  end
end

##############
# write features,
# either lemma-wise
# or lemma+sense-wise
# if lemma+sense-wise, write as binary classifier,
# i.e. map the target senses
#
# Use Delegator.

###
# Features for N-ary classifiers
class WriteFeaturesNary
  def initialize(lemma,
                 exp,
                 dataset,
                 feature_dir)

    @filename = feature_dir + ::Shalmaneser::Fred.fred_feature_filename(lemma)
    @f = File.new(@filename, "w")
    @handle_multilabel = exp.get("handle_multilabel")
  end

  def write_instance(features, senses)

    @f.print features.map { |x|
      x.to_s.gsub(/,/, "COMMA").gsub(/;/, "SEMICOLON")
    }.join(",")

    # possibly more than one sense? then use semicolon to separate
    if @handle_multilabel == "keep"
      # possibly more than one sense:
      # separate by semicolon,
      # and hope that the classifier knows this
      @f.print ";"
      @f.puts senses.map {|x|
        x.to_s.gsub(/,/, "COMMA").gsub(/;/, "SEMICOLON")
      }.join(",")
    else
      # one sense: just separate by comma
      @f.print ","
      @f.puts senses.first.to_s.gsub(/,/, "COMMA").gsub(/;/, "SEMICOLON")
    end
  end

  def close
    @f.close
  end
end

###
# Features for binary classifiers
class WriteFeaturesBinary
  def initialize(lemma,
                 exp,
                 dataset,
                 feature_dir)
    @dir = feature_dir
    @lemma = lemma
    @feature_dir = feature_dir

    @negsense = exp.get("negsense")
    unless @negsense
      @negsense = "NONE"
    end

    # files: sense-> filename
    @files = {}

    # keep all instances such that, when a new sense comes around,
    # we can write them for that sense
    @instances = []
  end


  def write_instance(features, senses)
    # sense we haven't seen before? Then we need to
    # write the whole featurization file for that new sense
    check_for_presence_of_senses(senses)

    # write this new instance for all senses
    @files.each_key { |sense_of_file|
      write_to_sensefile(features, senses, sense_of_file)
    }

    # store instance in case another sense crops up later
    @instances << [features, senses]
  end


  ###
  def close
    @files.each_value { |f| f.close }
  end

  ######
  private

  def check_for_presence_of_senses(senses)
    senses.each { |sense|
      # do we have a sense file for this sense?
      unless @files[sense]
        # open new file for this sense
        @files[sense] = File.new(@feature_dir + ::Shalmaneser::Fred.fred_feature_filename(@lemma, sense, true), "w")
        # filename = @feature_dir + Fred.fred_feature_filename(@lemma, sense, true)
        # $stderr.puts "Starting new feature file #{filename}"

        # and re-write all previous instances for it
        @instances.each { |prev_features, prev_senses|
          write_to_sensefile(prev_features, prev_senses,
                             sense)
        }
      end
    }
  end

  ###
  def write_to_sensefile(features, senses,
                         sense_of_file)
    # file to write to
    f = @files[sense_of_file]

    # print features
    f.print features.map { |x|
      x.to_s.gsub(/,/, "COMMA")
    }.join(",")

    f.print ","

    # binarize target class
    if senses.include? sense_of_file
      # $stderr.puts "writing POS #{sense_of_file}"
      f.puts sense_of_file.to_s
    else
      # $stderr.puts "writing NEG #{negsense}"
      f.puts @negsense
    end

  end
end

########
# class writing features:
# delegating to either a binary or an n-ary writer
class WriteFeaturesNaryOrBinary < SimpleDelegator
  ###
  def initialize(lemma,
                 exp,
                 dataset)
    feature_dir = WriteFeaturesNaryOrBinary.feature_dir(exp, dataset, "new")
    if exp.get("binary_classifiers")
      # binary classifiers
      # $stderr.puts "Writing binary feature data."

      # delegate writing to the binary feature writer
      @writer = WriteFeaturesBinary.new(lemma, exp, dataset, feature_dir)
      super(@writer)

    else
      # n-ary classifiers
      # $stderr.puts "Writing n-ary feature data."

      # delegate writing to the n-ary feature writer
      @writer = WriteFeaturesNary.new(lemma, exp, dataset, feature_dir)
      super(@writer)
    end
  end

  def WriteFeaturesNaryOrBinary.feature_dir(exp, dataset,
                                            mode = "existing")
    return ::Shalmaneser::Fred.fred_dirname(exp, dataset, "features", mode)
  end

  ###
  def WriteFeaturesNaryOrBinary.remove_files(exp, dataset)
    feature_dir = WriteFeaturesNaryOrBinary.feature_dir(exp, dataset, "new")

    Dir[feature_dir + ::Shalmaneser::Fred.fred_feature_filename("*")].each { |filename|
      if File.exists? filename
        File.delete(filename)
      end
    }
  end
end
end
end
