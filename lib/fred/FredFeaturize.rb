# FredFeaturize
#
# Featurization for WSD
#
# Katrin Erk April 2007
#
# feature types currently allowed:
# - context (with parameter giving context size; may be set several times)
# - syntax
# - synsem
#
# features in Meta-feature file:
#
# CX: context: word/lemma/pos/ne
# CH: children: grfunc/word/lemma/pos/ne
# PA: parents: grfunc/word/lemma/pos/ne
# SI: sibling: parent/grfunc/word/lemma/pos/ne
# TA: target: word/lemma/pos/ne

require 'delegate'

#######

require 'fred/FileZipped'
# require 'RegXML'
require 'salsa_tiger_xml/salsa_tiger_sentence'
# require 'SalsaTigerXMLHelper'

require 'configuration/fred_config_data'
require 'fred/FredConventions' # !
require 'fred/word_lemma_pos_ne'
# require 'prep_helper'
require 'syn_interfaces'
require 'fred/FredBOWContext'
require 'fred/FredDetermineTargets'
require 'fred/FredFeatures'

####################################
# grammatical function computation:
# given a sentence, keep all grammatical function relations in a hash
# for faster access
class GrammaticalFunctionAccess
  def initialize(interpreter_class)
    @interpreter_class = interpreter_class
    @to = Hash.new([])
    @from = Hash.new([])
  end

  # SalsaTigerRegXML sentence
  def set_sent(sent)
    @to.clear
    @from.clear

    sent.each_syn_node do |current|
      current_head = @interpreter_class.head_terminal(current)
      next unless current_head

      @interpreter_class.gfs(current, sent).map { |rel, node|
        # PPs: use head noun rather than preposition as head
        # Sbar, VP: use verb
        if (n = @interpreter_class.informative_content_node(node))
          [rel, n]
        else
          [rel, node]
        end
      }.each { |rel, node|
        rel_head = @interpreter_class.head_terminal(node)
        next unless rel_head

        unless @to.key? current_head
          @to[current_head] = []
        end

        unless @to[current_head].include? [rel, rel_head]
          @to[current_head] << [rel, rel_head]
        end

        unless @from.key?(rel_head)
          @from[rel_head] = []
        end

        unless @from[rel_head].include? [rel, current_head]
          @from[rel_head] << [rel, current_head]
        end
      }
    end
  end

  def get_children(node)
    @to[node]
  end

  def get_parents(node)
    @from[node]
  end
end

####################################
# main class of this package
####################################
class FredFeaturize < DelegateClass(GrammaticalFunctionAccess)
  include WordLemmaPosNe

  #####
  def initialize(exp_obj, # FredConfigData object
                 options, # hash: runtime option name (string) => value(string)
                 varhash = {}) # optional parameter: "refeaturize"

    @append_rather_than_overwrite = false

    # @todo Move this to FredConfigData.
    options.each_pair do |opt, arg|
      case opt
      when '--dataset'
        @dataset = arg
        unless ["train", "test"].include? @dataset
          $stderr.puts "--dataset needs to be either 'train' or 'test'"
          exit 1
        end

      when '--append'
        @append_rather_than_overwrite = true
      end
    end

    # @todo Move this to FredConfigData.
    # further sanity checks
    if @dataset.nil?
      $stderr.puts  "Please set --dataset: one of 'train', 'test'"
      exit 1
    end

    # evaluate optional "refeaturize" argument
    # "refeaturize": reuse meta-feature set,
    # just redo CSV featurization
    if varhash["refeaturize"]
      @refeaturize = varhash["refeaturize"]
    else
      @refeaturize = false
    end

    # prepare experiment file: add preprocessing experiment file data
    @exp = exp_obj

    # @note AB: The following is desabled because we don't want to use
    #   the dependence on {PrepConfigData}. We duplicate options:
    #   <do_postag>, <pos_tagger>, <do_lemmatize>, <lemmatizer>,
    #   <do_parse>, <parser>, <directory_preprocessed>
    #   in the experiment file of Fred.
    #
    # preproc_expname = @exp.get("preproc_descr_file_" + @dataset)
    # if not(preproc_expname)
    #   $stderr.puts "Please set the name of the preprocessing exp. file name"
    #   $stderr.puts "in the experiment file, feature preproc_descr_file_#{@dataset}"
    #   exit 1
    # elsif not(File.readable?(preproc_expname))
    #   $stderr.puts "Error in the experiment file:"
    #   $stderr.puts "Parameter preproc_descr_file_#{@dataset} has to be a readable file."
    #   exit 1
    # end
    # preproc_exp = FrPrepConfigData.new(preproc_expname)
    # @exp.adjoin(preproc_exp)

    # get the right syntactic interface
    SynInterfaces.check_interfaces_abort_if_missing(@exp)
    @interpreter_class = SynInterfaces.get_interpreter_according_to_exp(@exp)

    # initialize grammatical function object (delegating)
    grf_obj = GrammaticalFunctionAccess.new(@interpreter_class)
    super(grf_obj)

    # announce the task
    $stderr.puts "---------"
    $stderr.puts "Fred experiment #{@exp.get("experiment_ID")}: Featurization of dataset #{@dataset}"
    if @refeaturize
      $stderr.puts "Keeping meta-features, redoing featurization only."
    end
    if @exp.get("binary_classifiers")
      $stderr.puts "Writing features for binary classifiers."
    else
      $stderr.puts "Writing features for n-ary classifiers."
    end
    $stderr.puts "---------"

  end

  ####
  def compute
    if @refeaturize
      # read meta-feature file,
      # just redo normal featurization
      refeaturize
    else
      # write meta features and normal features
      featurize
    end
  end

  #########################
  private

  #####
  # main featurization
  def featurize
    ###
    # make objects
    unless @exp.get("directory_preprocessed")
      $stderr.puts "Shalmaneser error: could not find the directory with"
      $stderr.puts "syntactially preprocessed data."
      $stderr.puts "Please make sure that 'directory_preprocessed'"
      $stderr.puts "is set in the frprep experiment file you use with this experiment."
      exit 1
    end
    directory = File.existing_dir(@exp.get("directory_preprocessed"))

    # get context sizes
    context_sizes = @exp.get_lf("feature", "context")
    unless context_sizes
      # no contexts, nothing to compute.
      # choose default context
      $stderr.puts "Error: no contexts set."
      $stderr.puts "I will compute a context of size 1 by default."
      $stderr.puts "(This goes into the meta-features, but not"
      $stderr.puts "into the set of features used in the classifier.)"
      context_sizes = [1]
    end
    max_context_size = context_sizes.max

    # make target determination object
    if @dataset == "test" and @exp.get("apply_to_all_known_targets")
      $stderr.puts "Fred: Using all known targets as instances."
      target_obj = FindAllTargets.new(@exp, @interpreter_class)
    else
      if @append_rather_than_overwrite
        target_obj = FindTargetsFromFrames.new(@exp, @interpreter_class, "a")
      else
        target_obj = FindTargetsFromFrames.new(@exp, @interpreter_class, "w")
      end
    end

    # make context computation object
    if @exp.get("single_sent_context")
      # contexts in the input data doesn't go beyond a single sentence
      context_obj = SingleSentContextProvider.new(max_context_size, @exp,
                                                  @interpreter_class, target_obj,
                                                  @dataset)
      # @todo AB: Put it to the OptionParser, two option are not
      # compatible, don't do the check here!
      if @exp.get("noncontiguous_input")
        $stderr.puts "Warning: 'single_sent_context' has been set in the experiment file."
        $stderr.puts "So I'm ignoring the 'noncontiguous_input = true' setting."
      end

    elsif @exp.get("noncontiguous_input")
      # the input data is not contiguous but
      # consists of selected sentences from a larger text
      context_obj = NoncontiguousContextProvider.new(max_context_size, @exp,
                                                     @interpreter_class, target_obj,
                                                     @dataset)
     else
      # the input data is contiguous, and we're computing contexts not restricted to single sentences
      context_obj = ContextProvider.new(max_context_size, @exp,
                                        @interpreter_class, target_obj, @dataset)
    end

    zipped_input_dir = Fred.fred_dirname(@exp, @dataset, "input_data", "new")

    ##
    # make writer object(s)

    writer_classes = [
      MetaFeatureAccess,
      FredFeatureAccess
    ]

    if @append_rather_than_overwrite
      # append
      mode = "a"
      $stderr.puts "Appending new features to the old"

    else
      # write
      mode = "w"

      $stderr.puts "Removing old features for the same experiment (if any)"

      writer_classes.each { |w_class|
        w_class.remove_feature_files(@exp, @dataset)
      }

      Dir[zipped_input_dir + "*gz"].each { |filename|
        File.delete(filename)
      }
    end

    writers = writer_classes.map { |w_class|
      w_class.new(@exp, @dataset, mode)
    }

    ###
    # zip and store input files
    Dir[directory + "*.xml"].sort.each { |filename|
      %x{gzip -c #{filename} > #{zipped_input_dir}#{File.basename(filename)}.gz}
    }

    # always remember current sentence
    @current_sent = nil
    ###
    # featurize

    # context_obj.each_window yields tuples of:
    # - a context, an array of tuples [word,lemma, pos, ne]
    #   string/nil*string/nil*string/nil*string/nil
    # - ID of main target: string
    # - target_IDs: array:string, list of IDs of target words
    # - senses: array:string, the senses for the target
    # - sent: SalsaTigerSentence object
    #
    # for each max. context returned by context object:
    # determine meta-features:
    # - context words for all context sizes listed in context_sizes,
    # - children of target
    # - parent of target
    # - siblings of target
    #
    # and pass on to writing object(s)
    target_count = 0
    context_obj.each_window(directory) { |context, main_target_id, target_ids, senses, sent|
      # inform user
      if target_count % 500 == 0
        $stderr.puts "#{target_count}..."
      end
      target_count += 1
      # determine features
      feature_hash = Hash.new()
      compute_target_features(context, max_context_size, feature_hash)
      compute_context_features(context, max_context_size, context_sizes, feature_hash)
      compute_syn_features(main_target_id, sent, feature_hash)
      # write
      each_lemma_pos_and_senses(senses) { |target_lemma, target_pos, target_sid, target_senses|

        writers.each { |writer_obj|

          writer_obj.write_item(target_lemma,
                                target_pos,
                                target_ids,
                                target_sid,
                                target_senses,
                                feature_hash)
        }
      }
    }
    # finalize writers
    writers.each { |writer_obj|
      writer_obj.flush()
    }

    # record the targets that have been read
    target_obj.done_reading_targets()

  end

  #####
  # reuse of meta-features, recompute CSV features
  def refeaturize()

    ##
    # remove old features:
    # normal features only. Keep meta-features.
    # Don't do anything about zipped input.
    # Assume it stays as is.
    if @append_rather_than_overwrite
      # append
      mode = "a"
      $stderr.puts "Appending new features to the old"

    else
      # write
      mode = "w"

      $stderr.puts "Removing old features for the same experiment (if any)"

      FredFeatureAccess.remove_feature_files(@exp, @dataset)
    end

    ##
    # read meta-feature file,
    # write fred feature files
    meta_reader = MetaFeatureAccess.new(@exp, @dataset, "r")
    feature_writer = FredFeatureAccess.new(@exp, @dataset, mode)

    ##
    # featurize
    target_count = 0

    meta_reader.each_item { |target_lemma, target_pos, target_ids, target_sid, target_senses, feature_hash|

      # inform user
      if target_count % 500 == 0
        $stderr.puts "#{target_count}..."
      end
      target_count += 1

      feature_writer.write_item(target_lemma,
                                target_pos,
                                target_ids,
                                target_sid,
                                target_senses,
                                feature_hash)
    }
    feature_writer.flush
  end

  ####
  # given a list of sense hashes, format
  # "lex" -> lemma
  # "pos" -> part of speech
  # "sense" -> sense
  #
  # yield as triples [lemma, pos, sense]
  def each_lemma_pos_and_senses(shashes)
    # Determine target and POS.
    # If we actually have more than one lemma and POS, we're in trouble
    target_lemmas = shashes.map { |sense_hash| sense_hash["lex"].to_s.gsub(/\s/, "_") }.uniq
    target_pos_s =  shashes.map { |sense_hash| sense_hash["pos"].to_s.gsub(/\s/, "_")}.uniq
    target_sid =    shashes.map { |sense_hash| sense_hash["sid"].to_s.gsub(/\s/, "_")}.uniq

    if target_lemmas.length == 1 &&
       target_pos_s.length == 1 &&
       target_sid.length == 1

      yield [target_lemmas.first,
             target_pos_s.first,
             target_sid.first,
             shashes.map { |sense_hash| sense_hash["sense"].to_s.gsub(/\s/, "_") }
            ]
    else
      # trouble
      # group senses by SID, lemma and pos
      lemmapos2sense = {}
      shashes.each { |sense_hash|
        target_lemma = sense_hash["lex"].to_s.gsub(/\s/, "_")
        target_pos = sense_hash["pos"].to_s.gsub(/\s/, "_")
        target_sid = sense_hash["sid"].to_s.gsub(/\s/, "_")
        target_sense = sense_hash["sense"].to_s.gsub(/\s/, "_")
        key = [target_sid, target_lemma, target_pos]

        unless lemmapos2sense[key]
          lemmapos2sense[key] = []
        end

        lemmapos2sense[key] << target_sense
      }

      # and yield
      lemmapos2sense.each_key do |target_sid, target_lemma, target_pos|
        yield [target_lemma,
               target_pos,
               target_sid,
               lemmapos2sense[[target_sid, target_lemma, target_pos]]
              ]
      end
    end
  end

  ###
  # given a context, locate the target,
  # which is right in the middle,
  # and enter it into the feature hash
  #
  # feature type: TA
  # entry: word#lemma#pos#ne
  def compute_target_features(context,      # array: word*lemma*pos*ne
                              center_pos,   # integer: size of context, onesided
                              feature_hash) # hash: feature_type -> array:feature, enter features here
    feature_hash["TA"] = [context[center_pos].map(&:to_s).join("#").gsub(/\s/, "_")]
  end

  ###
  # compute context features:
  # for each context in the given list of context sizes,
  # compute a context with feature_type "CXNN" (where NN is the size of the context)
  # and with features
  # word#lemma#pos#ne
  #
  # enter each context into the feature hash
  def compute_context_features(context,       # array: word*lemma*pos*ne
                               center_pos,    # int: context is 2*cx_size_onesided + 1 long
                               context_sizes, # array:int, produce a context of each of these sizes
                               feature_hash)  # hash: feature_type -> array:feature, enter features here


    context_sizes.each { |context_size|
      # feature type: CXNN, where NN is the size of the context
      feature_type = "CX" + context_size.to_s

      # features: an array of strings
      feature_hash[feature_type]  = []

      # pre-context
      (center_pos - context_size).upto(center_pos - 1) { |ix|
        if context[ix]
          # context entries may be nil at the beginning and end of the text
          feature_hash[feature_type] << context[ix].map(&:to_s).join("#").gsub(/\s/, "_")
        end
      }
      # post-context
      (center_pos + 1).upto(center_pos + context_size) { |ix|
        if context[ix]
          # context entries may be nil at the beginning and end of the text
          feature_hash[feature_type] << context[ix].map(&:to_s).join("#").gsub(/\s/, "_")
        end
      }
    }
  end

  ###
  # compute syntax-dependent features:
  # children (that is, dependents) of the target word,
  # parent,
  # and siblings.
  #
  # format:
  #  feature type is CH for children, PA for parent, SI for siblings
  #
  #  individual features are:
  #    <dependency>#<word>#<lemma>#<pos>#<ne>
  def compute_syn_features(main_target_id,  # string: ID of the terminal node that is the target
                           sent,       # SalsaTigerRegXML object
                           feature_hash) # hash: feature_type -> array:feature, enter features here

    target = sent.terminals().detect { |t| t.id() == main_target_id }
    unless target
      $stderr.puts "Featurization error: cannot find target with ID #{main_target_id}, skipping."
      return
    end

    # if we're starting a new sentence,
    # compute dependencies using delegate object for grammatical functions.
    # also, get_children, get_parents below are methods of the delegate
    unless sent == @current_sent
      @current_sent = sent
      set_sent(sent)
    end

    # children
    feature_hash["CH"] = get_children(target).map do |rel, node|
      rel.to_s + "#" +
      word_lemma_pos_ne(node, @interpreter_class).map(&:to_s).join("#").gsub(/\s/, "_")
    end

    # parent
    feature_hash["PA"] = get_parents(target).map do |rel, node|

      rel.to_s + "#" +
      word_lemma_pos_ne(node, @interpreter_class).map(&:to_s).join("#").gsub(/\s/, "_")
    end

    # siblings
    feature_hash["SI"] = []

    get_parents(target).each do |_rel, parent|
      parent_w, _d1, _d2, _d3 = word_lemma_pos_ne(parent, @interpreter_class)

      get_children(parent).each do |rel, node|
        next if node == target
        feature_hash["SI"] << parent_w + "#" +
          rel.to_s + "#" +
          word_lemma_pos_ne(node, @interpreter_class).map { |e| e.to_s }.join("#").gsub(/\s/, "_")
      end
    end
  end
end
