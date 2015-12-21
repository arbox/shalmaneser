require "fred/FileZipped"

require 'configuration/fred_config_data'
# require "ExternalSystems"
require 'fred/FredConventions' # !

########################################
# target determination classes:
# either determine targets from existing annotation
# with frames,
# or use all known targets.
class Targets
  attr_reader :targets_okay

  ###
  def initialize(exp,                 # experiment file object
                 interpreter_class,   # SynInterpreter class, or nil
                 mode)                # string: "r", "w", "a", as in files
    @exp = exp
    @interpreter_class = interpreter_class

    # keep recorded targets here.
    # try to read old list now.
    @targets = {}

    # write target info in the classifier directory.
    # This is _not_ dependent on a potential split ID
    @dir = File.new_dir(Fred.fred_classifier_directory(@exp), "targets")

    @targets_okay = true
    case mode
    when "w"
    # start from scratch, no list of targets
    when "a", "r"
      # read existing file containing targets
      begin
        file = FileZipped.new(@dir + "targets.txt.gz")
      rescue
        # no pickle present: signal this
        @targets_okay = false
        return
      end
      file.each { |line|
        line.chomp!
        if line =~ /^LEMMA (.+) SENSES (.+)$/
          lemmapos = $1
          senses = $2.split
          lemmapos.gsub!(/ /, '_')
          #lemmapos.gsub!(/\.[A-Z]\./, '.')
          @targets[lemmapos] = senses
        end
      }

    else
      $stderr.puts "Error: shouldn't be here."
      exit 1
    end

    if ["w", "a"].include? mode
      @record_targets = true
    else
      @record_targets = false
    end
  end

  ###
  # determine_targets:
  # for a given SalsaTigerSentence,
  # determine all targets,
  # each as a _single_ main terminal node
  #
  # We need a single terminal node in order
  # to compute the context window
  #
  # returns:
  #  hash: target_IDs -> list of senses
  #   where target_IDs is a pair [list of terminal IDs, main terminal ID]
  #
  #  where a sense is represented as a hash:
  #  "sense": sense, a string
  #  "obj":   FrameNode object
  #  "all_targets": list of node IDs, may comprise more than a single node
  #  "lex":   lemma, or multiword expression in canonical form
  #  "sid": sentence ID
  def determine_targets(sent)
    raise "overwrite me"
  end

  ##
  # returns a list of lemma-pos combined strings
  def get_lemmas
    return @targets.keys
  end

  ##
  # access to lemmas and POS, returns a list of pairs [lemma, pos] (string*string)
  def get_lemma_pos
    @targets.keys.map { |lemmapos| Fred.fred_lemmapos_separate(lemmapos) }
  end

  ##
  # access to senses
  def get_senses(lemmapos) # string, result of fred_lemmapos_combine
    @targets[lemmapos] ? @targets[lemmapos] : []
  end

  ##
  # write file
  def done_reading_targets
    begin
      file = FileZipped.new(@dir + "targets.txt.gz", "w")
    rescue
      $stderr.puts "Error: Could not write file #{@dir}targets.txt.gz"
      exit 1
    end

    @targets.each_pair { |lemma, senses|
      file.puts "LEMMA #{lemma} SENSES "+ senses.join(" ")
    }

    file.close
  end

  ###############################
  protected

  ##
  # record: record occurrence of a lemma/sense pair
  # <@targets> data structure
  def record(target_info)
    lemmapos = Fred.fred_lemmapos_combine(target_info["lex"], target_info["pos"])
    unless @targets[lemmapos]
      @targets[lemmapos] = []
    end

    unless @targets[lemmapos].include? target_info["sense"]
      @targets[lemmapos] << target_info["sense"]
    end
  end
end

########################################
class FindTargetsFromFrames < Targets
  ###
  # determine_targets:
  # use existing frames to find targets
  #
  # returns:
  #  hash: target_IDs -> list of senses
  #   where target_IDs is a pair [list of terminal IDs, main terminal ID]
  #
  #  where a sense is represented as a hash:
  #  "sense": sense, a string
  #  "obj":   FrameNode object
  #  "all_targets": list of node IDs, may comprise more than a single node
  #  "lex":   lemma, or multiword expression in canonical form
  #  "sid": sentence ID
  def determine_targets(st_sent) #SalsaTigerSentence object
    retv = {}
    st_sent.each_frame { |frame_obj|
      # instance-specific computation:
      # target and target positions
      # WARNING: at this moment, we are
      # not considering true multiword targets for German.
      # Remove the "no_mwe" parameter in main_node_of_expr
      # to change this
      term = nil
      all_targets = nil
      if frame_obj.target.nil? or frame_obj.target.children.empty?
      # no target, nothing to record

      elsif @exp.get("language") == "de"
        # don't consider true multiword targets for German
        all_targets = frame_obj.target.children
        term = @interpreter_class.main_node_of_expr(all_targets, "no_mwe")

      else
        # for all other languages: try to figure out the head target word
        # anyway
        all_targets = frame_obj.target.children
        term = @interpreter_class.main_node_of_expr(all_targets)
      end

      if term and term.is_splitword?
        # don't use parts of a word as main node
        term = term.parent
      end
      if term and term.is_terminal?
        key = [all_targets.map { |t| t.id }, term.id]

        unless retv[key]
          retv[key] = []
        end

        pos = frame_obj.target.get_attribute("pos")
        # gold POS available, may be in wrong form,
        # i.e. not the same strings that @interpreter_class.category()
        # would return
        case pos
        when /^[Vv]$/
          pos = "verb"
        when /^[Nn]$/
          pos = "noun"
        when /^[Aa]$/
          pos = "adj"
        when nil
          pos = @interpreter_class.category(term)
        end

        target_info = {
          "sense" => frame_obj.name,
          "obj" => frame_obj,
          "all_targets" => frame_obj.target.children.map { |ch| ch.id },
          "lex" => frame_obj.target.get_attribute("lemma"),
          "pos" => pos,
          "sid" => st_sent.id
        }
        #print "lex ", frame_obj.target(), " und ",frame_obj.target().get_attribute("lemma"), "\n"
        retv[key] << target_info
        if @record_targets
          record(target_info)
        end
      end
    }
    return retv
  end
end

########################################
class FindAllTargets < Targets
  ###
  # determine_targets:
  # use all known lemmas, minus stopwords
  def initialize(exp,
                 interpreter_class)
    # read target info from file
    super(exp, interpreter_class, "r")
    @training_lemmapos_pairs = get_lemma_pos

    get_senses(@training_lemmapos_pairs)
    # list of words to exclude from assignment, for now
    @stoplemmas = [
      "have",
      "do",
      "be"
      #      "make"
    ]

  end

  ####
  #
  # returns:
  #  hash: target_IDs -> list of senses
  #   where target_IDs is a pair [list of terminal IDs, main terminal ID]
  #
  #  where a sense is represented as a hash:
  #  "sense": sense, a string
  #  "obj":   FrameNode object
  #  "all_targets": list of node IDs, may comprise more than a single node
  #  "lex":   lemma, or multiword expression in canonical form
  #  "sid": sentence ID
  def determine_targets(sent) #SalsaTigerSentence object
    # map target IDs to list of senses, in our case always [ nil ]
    # because we assume that the senses of the targets we point out
    # are unknown
    retv = {}
    # iterate through terminals of the sentence, check for inclusion
    # of their lemma in @training_lemmas
    sent.each_terminal { |node|
      # we know this lemma from the training data,
      # and it is not an auxiliary,
      # and it is not in the stopword list
      # and the node does not represent a preposition

      ### modified by ines, 17.10.2008
      lemma = @interpreter_class.lemma_backoff(node)
      pos = @interpreter_class.category(node)

      #	print "lemma ", lemma, " pos ", pos, "\n"
      #      reg = /\.[ANV]/
      #      if !reg.match(lemma)
      #        if /verb/.match(pos)
      #          lemma = lemma + ".V"
      #        elsif /noun/.match(pos)
      #          lemma = lemma + ".N"
      #        elsif /adj/.match(pos)
      #          lemma = lemma + ".A"
      #        end
      #        print "LEMMA ", lemma, " POS ", pos, "\n"
      #      end

      if (@training_lemmapos_pairs.include? [lemma, pos] and
          not(@interpreter_class.auxiliary?(node)) and
          not(@stoplemmas.include? lemma) and
          not(pos == "prep"))
        key = [ [ node.id ], node.id ]

        # take this as a target.
        retv[ key ] = [
          {
            "sense" => nil,
            "obj" => nil,
            "all_targets" => [ node.id ],
            "lex" => lemma,
            "pos" => pos,
            "sid" => sent.id
          } ]
        # no recording of target info,
        # since we haven't determined anything new
      end
    }

    return retv
  end
end
