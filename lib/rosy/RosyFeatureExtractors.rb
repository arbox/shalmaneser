####
# ke & sp
# adapted to new feature extractor class,
# Collins and Tiger features combined:
# KE November 2005
#
# Feature Extractors for Rosy
#
# Contract: each feature extractor inherits from the RosyFeatureExtractor class
#
# Feature extractors return nil if no feature value could be
# returned


# Salsa packages
require 'rosy/AbstractFeatureAndExternal'
# require 'SalsaTigerRegXML'

# Fred and Rosy packages
require 'rosy/rosy_conventions'


################################
# base class for all following feature extractors
class RosyFeatureExtractor < AbstractFeatureExtractor
  @@instance_ok = nil  # Boolean: set_node(), set_sent() successful?
  @@split_nones = nil  # Boolean: split NONE value for gold feature?

  @@target = nil       # SynNode: main target node
  @@target_pos = nil   # string: part of speech of main target
  @@target_voice = nil # string: "active", "passive", or nil
  @@terminals_ordered = nil # Hash: sentence terminals, mapped onto their word indices (starting with 1)
  @@target_gfs = nil   # Array of pairs [rel, node]: grammatical functions of the target

  @@paths = nil        # Hash: node ID -> path object, path from main target node to the node with that ID
  @@relpos = nil       # string: position of instance relative to target
  @@node_leftmost_terminal = nil   # SynNode objects: first and last terminal
  @@node_rightmost_terminal = nil  # in the yield of @@node

  @@governing_verb = nil # SynNode object: closest governing verb of @@target
  @@gv_paths = nil       # Hash: node ID -> path object, path from main target node to the node with that ID

  ###
  # returns a string: "phase 1" or "phase 2",
  # depending on whether the feature is computed
  # directly from the SalsaTigerSentence and the SynNode objects
  # or whether it is computed from the phase 1 features
  # computed for the training set
  #
  # Here: all features in this packages are phase 1
  def RosyFeatureExtractor.phase()
    return "phase 1"
  end

  ###
  # returns an array of strings, providing information about
  # the feature extractor
  def RosyFeatureExtractor.info()
    return super().concat(["rosy"])
  end

  ###
  # set sentence, set node, set general settings: this is done prior to
  # feature computation using compute_feature_value()
  # such that computations that stay the same for
  # several features can be done in advance
  def RosyFeatureExtractor.set(var_hash) # hash. possible entries: split_nones=> true/false

    @@split_nones = var_hash["split_nones"]

    return true
  end

  ###
  def RosyFeatureExtractor.set_sentence(sent,  # SalsaTigerSentence object
					frame) # FrameNode object
    super(sent, frame)

    root = @@sent.syn_roots.first()
    word_index_counter = 1
    @@terminals_ordered = Hash.new
    root.yield_nodes_ordered.each {|yield_node|
      @@terminals_ordered[yield_node] = word_index_counter
      word_index_counter += 1
    }

    # @@target: main target node (SynNode)
    # WARNING: at this moment, we are
    # not considering true multiword targets.
    # Remove the "no_mwe" parameter in determine_main_target
    # to change this
    unless frame.target
      @@target = nil
      return false
    end
    @@target = @@interpreter_class.main_node_of_expr(frame.target.children(), "no_mwe")

    unless @@target
      return false
    end

    # @@target_pos: string, target POS
    @@target_pos = @@interpreter_class.category(@@target)

    # @@target_voice:
    # for verb targets, string, active or passive
    # else nil
    @@target_voice = @@interpreter_class.voice(@@target)
    @@target_gfs = @@interpreter_class.gfs(@@target, @@sent)

    # paths from target to all other nodes in the graph
    @@paths = RosyFeatureExtractor.all_paths_from(@@target)

    # governing verb of target.
    # If something goes wrong, this will remain unset
    @@gv_paths = Hash.new
    if (targetlemma = RosyFeatureExtractor.headlemma(@@target))
      # determine governing verb
      parent = @@target
      while (parent = parent.parent)
        parentlemma = RosyFeatureExtractor.headlemma(parent)

        if @@interpreter_class.category(parent) == "verb" and
            parentlemma != targetlemma
          # success: found the governing verb of the target

          @@governing_verb = @@interpreter_class.head_terminal(parent)
          # paths from governing verb of target to all other nodes in the graph
          if @@governing_verb
            @@gv_paths = RosyFeatureExtractor.all_paths_from(@@governing_verb)
          end

          break
        end
      end
    end


    # paths: when printing, leave off the phrase type of the end node
    @@paths.each_value { |p| p.set_cutoff_last_pt_on_printing(true) }
    @@gv_paths.each_value { |p| p.set_cutoff_last_pt_on_printing(true) }

    return true
  end

  ###
  # node: SynNode of the sentence set in set_sentence
  def RosyFeatureExtractor.set_node(node)
    super(node)

    @@instance_ok = true

    unless @@target
      # no target, nothing I can compute here
      @@instance_ok = false
      return false
    end

#    # path between target and current instance node
#    @@path = @@interpreter_class.path_between(@@target, @@node)
#    @@path.set_cutoff_last_pt_on_printing(true) # when printing path, cut off last node label


    # position of instance node relative to main target node
    @@relpos = @@interpreter_class.relative_position(@@node, @@target)
    # leftmost, rightmost terminal in the yield of @@node
    @@node_leftmost_terminal = @@interpreter_class.leftmost_terminal(@@node)
    @@node_rightmost_terminal = @@interpreter_class.rightmost_terminal(@@node)

    return true
  end

  ###
  # compute_feature_value: first check if instance is OK
  #
  # returns: list of features
  def compute_features()
    unless @@instance_ok
      return nil
    end

    return make_features_safe_for_sql(compute_features_instanceOK())
  end

  ############
  protected


  # returns: list of features
  def compute_features_instanceOK()
    raise "Overwrite me"
  end

  ###
  # in computed features:
  # replace "," by COMMA in order not to confuse SQL
  def make_features_safe_for_sql(feature_list)
    return feature_list.map { |feature|
      if feature.kind_of? String
        feature.gsub(/,/, "COMMA").gsub(/\\/, "BACK")
      else
        feature
      end
    }
  end


  ###
  # lemma of the head terminal of SynNode n
  def RosyFeatureExtractor.headlemma(n) # SynNode
    unless n
      return nil
    end

    h = @@interpreter_class.head_terminal(n)
    if h
      return @@interpreter_class.lemma_backoff(h)
    else
      return nil
    end
  end

  ###
  # part of speech of the head terminal of SynNode n
  def RosyFeatureExtractor.headpos(n) # SynNode
    unless n
      return nil
    end

    h = @@interpreter_class.head_terminal(n)
    if h
      return h.part_of_speech()
    else
      return nil
    end
  end

  ###
  # Given a SynNode n, recursively determine
  # the paths from n to all other reachable nodes,
  # skipping nodes that already have a path
  # listed in the given hash mapping node IDs to paths.
  # Paths are given as Path objects (see AbstractSynInterface).
  # It is assumed that the graph of n is a tree, which
  # is searched depth-first, first the children, then the parent of n.
  def RosyFeatureExtractor.all_paths_from(n,           # SynNode
                                          hash = nil)  # Hash: nodeID(string) => Path object
    # initial step of all: no hash existing yet
    if hash.nil?
      hash = Hash.new
      hash[n.id()] = Path.new(n)
    end

    # invariant at this point: n must be listed in hash
    unless hash[n.id()]
      raise "Shouldn't be here"
    end

    # for each child c of n: compute its path from the path of n,
    # and explore paths below c
    n.each_child_with_edgelabel { |label, c|
      if hash[c.id()].nil?
        hash[c.id()] = hash[n.id()].deep_clone().add_last_step("D",
                                                               label,
                                                               @@interpreter_class.simplified_pt(c),
                                                               c)
        RosyFeatureExtractor.all_paths_from(c, hash)
      end
    }

    # compute the path from n's parent p from the path of n,
    # and explore paths beyond p
    if (p = n.parent) and hash[p.id()].nil?
      # node has a parent, and it is not listed in the path hash
      # make a new path for parent: n's path, plus one up-step
      hash[p.id()] = hash[n.id()].deep_clone().add_last_step("U",
                                                             n.parent_label,
                                                             @@interpreter_class.simplified_pt(p),
                                                             p)
      RosyFeatureExtractor.all_paths_from(p, hash)
    end

    return hash

  end

end

###############################
# Rosy single feature extractor, duplicating stuff from
# AbstractSingleFeatureExtractor
class RosySingleFeatureExtractor < RosyFeatureExtractor

  ###
  # returns a string: the designator for this feature extractor
  # (an extractor may compute several features, but
  #  in the experiment file it is chosen by a single designator)
  #
  # here: single feature, and the feature name is the designator
  def RosySingleFeatureExtractor.designator()
    return eval(self.name()).feature_name()
  end

  ###
  def RosySingleFeatureExtractor.feature_names()
    return [eval(self.name()).feature_name()]
  end

  ###
  # compute_feature_value: first check if instance is OK
  #
  # returns: list of features
  def compute_features()
    unless @@instance_ok
      return nil
    end

    return make_features_safe_for_sql([compute_feature_instanceOK()])
  end

  ############
  private

  def compute_feature_instanceOK()
    raise "Overwrite me"
  end

end

##############################################
# Individual feature extractors
##############################################

####################
# gold role label
class GoldlabelFeature < RosySingleFeatureExtractor
  GoldlabelFeature.announce_me()

  def GoldlabelFeature.feature_name()
    return "gold"
  end
  def GoldlabelFeature.sql_type()
    return "VARCHAR(30)"
  end
  def GoldlabelFeature.feature_type()
    return "gold"
  end
  def GoldlabelFeature.info()
    # additional info: I am an index feature
    return super().concat(["index"])
  end

  ################
  private

  def compute_feature_instanceOK()
    @@frame.each_fe_by_name {|fe|
      if fe.children.include? @@node
        return fe.name
      end
    }

    # no role label for this node
    # if @@split_nones
      # split "no role" label into:
      # before/after/dominating the target node
#      return @@relpos
#    else
      return nil
#    end
  end
end

####################
# path features
class AbstractPathFeature < RosySingleFeatureExtractor
  def AbstractPathFeature.sql_type()
    return "VARCHAR(80)"
  end
  def AbstractPathFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    if @@paths[@@node.id()].nil?
      path = nil
    else
      path = my_path_computation()
    end

    if path.nil? or path.empty?
      return nil
    else
      return path
    end
  end

  def my_path_computation()
    raise "overwrite me"
  end
end


####################
# path consisting of nodelabels, dependencies and directions
class PathFeature < AbstractPathFeature
  PathFeature.announce_me()

  def PathFeature.sql_type()
    return "VARCHAR(120)"
  end
  def PathFeature.feature_name()
    return "path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print(true, true, true)
  end
end



####################
# path consisting of phrase type and directions
class NodelabelPathFeature < AbstractPathFeature
  NodelabelPathFeature.announce_me()

  def NodelabelPathFeature.feature_name()
    return "pt_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print(true, false, true)
  end
end

####################
# path consisting of dependencies and directions
class EdgelabelPathFeature < AbstractPathFeature
  EdgelabelPathFeature.announce_me()

  def EdgelabelPathFeature.feature_name()
    return "gf_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print(true, true, false)
  end
end

####################
# features: path from governing verb
class AbstractGVPathFeature < RosySingleFeatureExtractor
  def AbstractGVPathFeature.sql_type()
    return "VARCHAR(80)"
  end
  def AbstractGVPathFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    if @@gv_paths[@@node.id()].nil?
      path = nil
    else
      path = my_path_computation()
    end

    if path.nil? or path.empty?
      return nil
    else
      return path
    end
  end

  def my_path_computation()
    raise "overwrite me"
  end
end


####################
# path from governing verb consisting of nodelabels, dependencies and directions
class GVPathFeature < AbstractGVPathFeature
  GVPathFeature.announce_me()

  def GVPathFeature.sql_type()
    return "VARCHAR(120)"
  end
  def GVPathFeature.feature_name()
    return "gvpath"
  end

  ################
  private

  def my_path_computation()
    return @@gv_paths[@@node.id()].print(true, true, true)
  end
end


####################
# gov. verb path consisting of phrase type and directions
class GVNodelabelPathFeature < AbstractGVPathFeature
  GVNodelabelPathFeature.announce_me()

  def GVNodelabelPathFeature.feature_name()
    return "pt_gvpath"
  end

  ################
  private

  def my_path_computation()
    return @@gv_paths[@@node.id()].print(true, false, true)
  end
end

####################
# gov. verb path consisting of dependencies and directions
class GVEdgelabelPathFeature < AbstractGVPathFeature
  GVEdgelabelPathFeature.announce_me()

  def GVEdgelabelPathFeature.feature_name()
    return "gf_gvpath"
  end

  ################
  private

  def my_path_computation()
    return @@gv_paths[@@node.id()].print(true, true, false)
  end
end

####################
# path length
class PathLengthFeature < RosySingleFeatureExtractor
  PathLengthFeature.announce_me()

  def PathLengthFeature.feature_name()
    return "path_length"
  end
  def PathLengthFeature.sql_type()
    return "TINYINT"
  end
  def PathLengthFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    if @@paths[@@node.id()].nil?
      return nil
    else
      return @@paths[@@node.id()].length()
    end
  end
end

#########
# group of combined path features:
# path to target combined with target part of speech and
# info on whether the target is passive
class AbstractCombinedPathFeature < RosySingleFeatureExtractor

  def AbstractCombinedPathFeature.sql_type()
    return "VARCHAR(90)"
  end
  def AbstractCombinedPathFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    if @@paths[@@node.id()].nil?
      path = ""
    else
      path = my_path_computation()
    end
    return path + "--" + @@target_pos.to_s + "--" + @@target_voice.to_s
  end

  ###
  def my_path_computation()
    raise "Overwrite me"
  end
end


####################
# combined path based on nodelabels
class NodelabelCombinedPathFeature < AbstractCombinedPathFeature
  NodelabelCombinedPathFeature.announce_me()

  def NodelabelCombinedPathFeature.feature_name()
    return "pt_combined_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print(false, false, true)
  end
end

####################
# combined path based on edgelabels
class EdgelabelCombinedPathFeature < AbstractCombinedPathFeature
  EdgelabelCombinedPathFeature.announce_me()

  def EdgelabelCombinedPathFeature.feature_name()
    return "gf_combined_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print(false, true, false)
  end
end


####################
# combined path based on nodelabels and edgelabels
class CombinedPathFeature < AbstractCombinedPathFeature
  CombinedPathFeature.announce_me()

  def CombinedPathFeature.sql_type()
    return "VARCHAR(130)"
  end
  def CombinedPathFeature.feature_name()
    return "combined_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print(false, true, true)
  end
end


##################
# group of features for computing
# partial path to target: only up to
# the lowest common ancestor of current node and target
class AbstractPartialPathFeature < RosySingleFeatureExtractor

  def AbstractPartialPathFeature.sql_type()
    return "VARCHAR(70)"
  end
  def AbstractPartialPathFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    if @@paths[@@node.id()].nil?
      path = nil
    else
      path = my_path_computation()
    end
    if path.nil? or path.empty?
      return nil
    else
      return path
    end
  end
end

####
# partial path based on node labels
class NodelabelPartialPathFeature < AbstractPartialPathFeature
  NodelabelPartialPathFeature.announce_me()

  def NodelabelPartialPathFeature.feature_name()
    return "pt_partial_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print_downpart(true, false, true)
  end
end

####
# partial path based on edge labels
class EdgelabelPartialPathFeature < AbstractPartialPathFeature
  EdgelabelPartialPathFeature.announce_me()

  def EdgelabelPartialPathFeature.feature_name()
    return "gf_partial_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print_downpart(true, true, false)
  end
end

####
# partial path based on node and edge labels
class PartialPathFeature < AbstractPartialPathFeature
  PartialPathFeature.announce_me()

  def PartialPathFeature.sql_type()
    return "VARCHAR(110)"
  end
  def PartialPathFeature.feature_name()
    return "partial_path"
  end

  ################
  private

  def my_path_computation()
    if @@paths[@@node.id()].nil?
      return nil
    end

    return @@paths[@@node.id()].print_downpart(true, true, true)
  end
end



##################
# ancestor rule: grammar rule
# expanding lowest common ancestor of current node and target
class AncestorRuleFeature < RosySingleFeatureExtractor
  AncestorRuleFeature.announce_me()

  def AncestorRuleFeature.feature_name()
    return "ancestor_rule"
  end
  def AncestorRuleFeature.sql_type()
    return "VARCHAR(50)"
  end
  def AncestorRuleFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    if @@paths[@@node.id()].nil?
      return nil
    end

    lca = @@paths[@@node.id()].lca()
    unless lca
      return nil
    end

    return @@interpreter_class.simplified_pt(lca).to_s +
      " -> "+
      lca.children.map {|c| @@interpreter_class.simplified_pt(c).to_s }.join(" ")
  end
end

##################
# relative position to target: left, right, including target
class RelativePositionFeature < RosySingleFeatureExtractor
  RelativePositionFeature.announce_me()

  def RelativePositionFeature.feature_name()
    return "relpos"
  end
  def RelativePositionFeature.sql_type()
    return "CHAR(5)"
  end
  def RelativePositionFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    return @@relpos
  end
end


################
# phrase type of the instance node
class PhraseTypeFeature < RosySingleFeatureExtractor
  PhraseTypeFeature.announce_me()

  def PhraseTypeFeature.feature_name()
    return "pt"
  end
  def PhraseTypeFeature.sql_type()
    return "VARCHAR(15)"
  end
  def PhraseTypeFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    return @@interpreter_class.simplified_pt(@@node)
  end
end

################
# grammatical function that this instance node fills for the target
class GFFeature < RosySingleFeatureExtractor
  GFFeature.announce_me()

  def GFFeature.feature_name()
    return "gf"
  end
  def GFFeature.sql_type()
    return "VARCHAR(20)"
  end
  def GFFeature.feature_type()
    return "syn"
  end

  ################
  private

  def compute_feature_instanceOK()
    unless @@target_gfs
      return nil
    end

    @@target_gfs.each { |rel, other_node|
      if @@node == other_node
        return rel
      end
    }

    return nil
  end
end

##################
# phrase type of parent of this node
class FatherPhraseTypeFeature < RosySingleFeatureExtractor
  FatherPhraseTypeFeature.announce_me()

  def FatherPhraseTypeFeature.feature_name()
    return "father_pt"
  end
  def FatherPhraseTypeFeature.sql_type()
    return "VARCHAR(15)"
  end
  def FatherPhraseTypeFeature.feature_type()
    return "syn"
  end

  #####
  private

  def compute_feature_instanceOK()
    if @@node.parent
      return @@interpreter_class.simplified_pt(@@node.parent)
    else
      return nil
    end
  end
end

################
# target lemma
class TargetLemmaFeature < RosySingleFeatureExtractor
  TargetLemmaFeature.announce_me()

  def TargetLemmaFeature.feature_name()
    return "target"
  end
  def TargetLemmaFeature.sql_type()
    return "VARCHAR(20)"
  end
  def TargetLemmaFeature.feature_type()
    return "ubiq"
  end
  def TargetLemmaFeature.info()
    # additional info: I am an index feature
    return super().concat(["index"])
  end

  #####
  private

  def compute_feature_instanceOK()
    return @@interpreter_class.lemma_backoff(@@target)
  end
end

################
# part of speech of target lemma
class TargetPOSFeature < RosySingleFeatureExtractor
  TargetPOSFeature.announce_me()

  def TargetPOSFeature.feature_name()
    return "target_pos"
  end
  def TargetPOSFeature.sql_type()
    return "VARCHAR(10)"
  end
  def TargetPOSFeature.feature_type()
    return "ubiq"
  end
  def TargetPOSFeature.info()
    # additional info: I am an index feature
    return super().concat(["index"])
  end


  #####
  private

  def compute_feature_instanceOK()
    return @@target_pos
  end
end

################
# part of speech of target lemma
class TargetFineGrainedPOSFeature < RosySingleFeatureExtractor
  TargetFineGrainedPOSFeature.announce_me()

  def TargetFineGrainedPOSFeature.feature_name()
    return "finegrained_target_pos"
  end
  def TargetFineGrainedPOSFeature.sql_type()
    return "VARCHAR(20)"
  end
  def TargetFineGrainedPOSFeature.feature_type()
    return "ubiq"
  end


  #####
  private

  def compute_feature_instanceOK()
    return @@interpreter_class.pt(@@target)
  end
end

################
# voice of the target lemma
class TargetVoiceFeature < RosySingleFeatureExtractor
  TargetVoiceFeature.announce_me()

  def TargetVoiceFeature.feature_name()
    return "target_voice"
  end
  def TargetVoiceFeature.sql_type()
    return "CHAR(4)"
  end
  def TargetVoiceFeature.feature_type()
    return "ubiq"
  end

  #####
  private

  def compute_feature_instanceOK()
    voice = @@interpreter_class.voice(@@target)
    if voice
      return voice.slice(0,4)
    else
      return nil
    end
  end
end

################
# the governing verb of the target
class GoverningVerbOfTargetFeature < RosySingleFeatureExtractor
  GoverningVerbOfTargetFeature.announce_me()

  def GoverningVerbOfTargetFeature.feature_name()
    return "gov_verb"
  end
  def GoverningVerbOfTargetFeature.sql_type()
    return "VArCHAR(20)"
  end
  def GoverningVerbOfTargetFeature.feature_type()
    return "sem"
  end

  #####
  private

  def compute_feature_instanceOK()
    if @@governing_verb
      return RosyFeatureExtractor.headlemma(@@governing_verb)
    else
      return nil
    end
  end
end

################c
# preposition for this constituent
class PrepFeature < RosySingleFeatureExtractor
  PrepFeature.announce_me()

  def PrepFeature.feature_name()
    return "prep"
  end
  def PrepFeature.sql_type()
    return "VARCHAR(20)"
  end
  def PrepFeature.feature_type()
    return "syn"
  end

  #####
  private

  def compute_feature_instanceOK()
    return @@interpreter_class.preposition(@@node)
  end
end

################
# head lemma of this constituent
class HeadFeature < RosySingleFeatureExtractor
  HeadFeature.announce_me()

  def HeadFeature.feature_name()
    return "const_head"
  end
  def HeadFeature.sql_type()
    return "VARCHAR(20)"
  end
  def HeadFeature.feature_type()
    return "sem"
  end

  #####
  private

  def compute_feature_instanceOK()
    return RosyFeatureExtractor.headlemma(@@node)
  end
end

################
# part of speech of the head of this constituent
class HeadPosFeature < RosySingleFeatureExtractor
  HeadPosFeature.announce_me()

  def HeadPosFeature.feature_name()
    return "const_head_pos"
  end
  def HeadPosFeature.sql_type()
    return "VARCHAR(10)"
  end
  def HeadPosFeature.feature_type()
    return "syn"
  end

  #####
  private

  def compute_feature_instanceOK()
    return RosyFeatureExtractor.headpos(@@node)
  end
end

################
# informative content word (see AbstractSynFeature): lemma and POS
class IcontLemmaFeature < RosyFeatureExtractor
  IcontLemmaFeature.announce_me()

  def IcontLemmaFeature.designator()
    return "icont_word"
  end
  def IcontLemmaFeature.feature_names()
    return ["icont_lemma", "icont_pos"]
  end
  def IcontLemmaFeature.sql_type()
    return "VARCHAR(20)"
  end
  def IcontLemmaFeature.feature_type()
    return "sem"
  end

  #####
  private

  def compute_features_instanceOK()
    icont_node = @@interpreter_class.informative_content_node(@@node)
    if icont_node
      return [RosyFeatureExtractor.headlemma(icont_node), RosyFeatureExtractor.headpos(icont_node)]
    else
      return [nil, nil]
    end
  end
end


################
# leftmost terminal of this constituent
class FirstWordFeature < RosyFeatureExtractor
  FirstWordFeature.announce_me()

  def FirstWordFeature.designator()
    return "firstword"
  end
  def FirstWordFeature.feature_names()
    return ["firstword", "firstword_pos"]
  end
  def FirstWordFeature.sql_type()
    return "VARCHAR(20)"
  end
  def FirstWordFeature.feature_type()
    return "sem"
  end

  #####
  private

  def compute_features_instanceOK()
    if @@node_leftmost_terminal
      return [RosyFeatureExtractor.headlemma(@@node_leftmost_terminal), RosyFeatureExtractor.headpos(@@node_leftmost_terminal)]
    else
      return [nil, nil]
    end
  end
end


################
# rightmost terminal of this constituent
class LastWordFeature < RosyFeatureExtractor
  LastWordFeature.announce_me()

  def LastWordFeature.designator()
    return "lastword"
  end
  def LastWordFeature.feature_names()
    return ["lastword", "lastword_pos"]
  end
  def LastWordFeature.sql_type()
    return "VARCHAR(30)"
  end
  def LastWordFeature.feature_type()
    return "sem"
  end

  #####
  private

  def compute_features_instanceOK()
    if @@node_rightmost_terminal
      return [RosyFeatureExtractor.headlemma(@@node_rightmost_terminal), RosyFeatureExtractor.headpos(@@node_rightmost_terminal)]
    else
      return [nil, nil]
    end
  end
end

################
# left sibling of the current node
class LeftSiblingFeature < RosyFeatureExtractor
  LeftSiblingFeature.announce_me()

  def LeftSiblingFeature.designator()
    return "leftsib"
  end
  def LeftSiblingFeature.feature_names()
    return ["leftsib_pt", "leftsib_lemma"]
  end
  def LeftSiblingFeature.sql_type()
    return "VARCHAR(20)"
  end
  def LeftSiblingFeature.feature_type()
    return "sem"
  end

  #####
  private

  def compute_features_instanceOK()
    # leftsib, rightsib (node)
    # siblings with max lastword/firstword among those with lastword/firstword index
    # smaller/greater than firstword/lastword index of self
    if @@node.parent.nil?
      return [nil, nil]
    end

    node_ix = terminal_index(@@node_leftmost_terminal)
    unless node_ix
      return [nil, nil]
    end

    leftsib_ix = nil
    leftsib = nil
    @@node.parent.children.each { |sibling|
      sib_ix = terminal_index(@@interpreter_class.rightmost_terminal(sibling))
      unless sib_ix
        next
      end

      if sib_ix < node_ix and
          (leftsib.nil? or leftsib_ix < sib_ix)

        leftsib = sibling
        leftsib_ix = sib_ix
      end
    }

    if leftsib
      return [
        @@interpreter_class.simplified_pt(leftsib),
        @@interpreter_class.lemma_backoff(leftsib),
      ]
    else
      return [nil, nil]
    end
  end

  ###
  # returns: index(integer) of node in list of terminals of this sentence;
  # nil if node is nil or does not occur in the list
  def terminal_index(node) # SynNode, terminal
    unless node
      return nil
    end

    return @@terminals_ordered[node] # word index (or nil)
  end
end

################
# distance between head word of constituent and target (in words)
class WordDistanceFeature < RosySingleFeatureExtractor
  WordDistanceFeature.announce_me()

  def WordDistanceFeature.feature_name()
    return "worddistance"
  end
  def WordDistanceFeature.sql_type()
    return "TINYINT"
  end
  def WordDistanceFeature.feature_type()
    return "syn"
  end

  #####
  private

  def compute_feature_instanceOK()

    head_term = @@interpreter_class.head_terminal(@@node)
    targ_term = @@interpreter_class.head_terminal(@@target)
    if head_term.nil? or targ_term.nil?
      return nil
    end
    h_id = @@terminals_ordered[head_term]
    t_id = @@terminals_ordered[targ_term]
    if h_id.nil? or t_id.nil?
      return nil
    else
      return (h_id-t_id).abs
    end
  end
end

################
# is the current node a maximal projection?
# heuristic: is my category the same as my parent's?
class IsMaxProj < RosySingleFeatureExtractor
  IsMaxProj.announce_me()

  def IsMaxProj.feature_name()
    return "ismaxproj"
  end
  def IsMaxProj.sql_type()
    return "TINYINT"
  end
  def IsMaxProj.feature_type()
    return "syn"
  end

  #####
  private

  def compute_feature_instanceOK()
    unless @@node.parent()
      return 1
    end
    my_cat = @@interpreter_class.category(@@node)
    parent_cat = @@interpreter_class.category(@@node.parent)
    if my_cat == parent_cat
      return 0
    else
      return 1
    end
  end
end

################
# right sibling of the current node
class RightSiblingFeature < RosyFeatureExtractor
  RightSiblingFeature.announce_me()

  def RightSiblingFeature.designator()
    return "rightsib"
  end
  def RightSiblingFeature.feature_names()
    return ["rightsib_pt", "rightsib_lemma"]
  end
  def RightSiblingFeature.sql_type()
    return "VARCHAR(20)"
  end
  def RightSiblingFeature.feature_type()
    return "sem"
  end

  #####
  private

  def compute_features_instanceOK()
    # leftsib, rightsib (node)
    # siblings with max lastword/firstword among those with lastword/firstword index
    # smaller/greater than firstword/lastword index of self
    if @@node.parent.nil?
      return [nil, nil]
    end

    node_ix = terminal_index(@@node_rightmost_terminal)
    unless node_ix
      return [nil, nil]
    end

    rightsib_ix = nil
    rightsib = nil
    @@node.parent.children.each { |sibling|
      sib_ix = terminal_index(@@interpreter_class.leftmost_terminal(sibling))
      unless sib_ix
        next
      end

      if sib_ix > node_ix and
          (rightsib.nil? or sib_ix < rightsib_ix)

        rightsib = sibling
        rightsib_ix = sib_ix
      end
    }

    if rightsib
      return [
        @@interpreter_class.simplified_pt(rightsib),
        @@interpreter_class.lemma_backoff(rightsib),
      ]
    else
      return [nil, nil]
    end
  end

  ###
  # returns: index(integer) of node in list of terminals of this sentence;
  # nil if node is nil or does not occur in the list
  def terminal_index(node) # SynNode, terminal
    unless node
      return nil
    end

    return @@terminals_ordered[node] # word index (or nil)
  end
end


# ################
# # admin feature: word span of this constituent
# class WordSpanFeature < RosySingleFeatureExtractor
#   WordSpanFeature.announce_me()

#   def WordSpanFeature.feature_name()
#     return "wordspan"
#   end
#   def WordSpanFeature.sql_type()
#     return "VARCHAR(30)"
#   end
#   def WordSpanFeature.feature_type()
#     return "admin"
#   end

#   #####
#   private

#   def compute_feature_instanceOK()

#     fwh = RosyFeatureExtractor.headlemma(@@node_leftmost_terminal)
#     lwh = RosyFeatureExtractor.headlemma(@@node_rightmost_terminal)

#     if fwh.nil?
#       fwh = ""
#     end
#     if lwh.nil?
#       lwh = ""
#     end

#     return  fwh+ "-" +lwh
#   end
# end


################
# admin feature: my node ID and my father's, separated by a space
# the highest node (topnode) has ID 0, and no father ID.
class NodeIDFeature < RosySingleFeatureExtractor
  NodeIDFeature.announce_me()

  def NodeIDFeature.feature_name()
    return "nodeID"
  end
  def NodeIDFeature.sql_type()
    return "VARCHAR(100)"
  end
  def NodeIDFeature.feature_type()
    return "admin"
  end

  #####
  private

  def compute_feature_instanceOK()

    if @@node.parent
      return @@node.id.to_s+ " " + @@node.parent.id.to_s
    else
      return @@node.id.to_s
    end
  end
end

################
# admin feature: sentence ID
class SentidFeature < RosySingleFeatureExtractor
  SentidFeature.announce_me()

  def SentidFeature.feature_name()
    return "sentid"
  end
  def SentidFeature.sql_type()
    return "VARCHAR(100)"
  end
  def SentidFeature.feature_type()
    return "admin"
  end
  def SentidFeature.info()
    # additional info: I am an index feature
    return super().concat(["index"])
  end

  #####
  private

  def compute_feature_instanceOK()
    return Rosy::construct_instance_id(@@sent.id(), @@frame.id())
  end
end

# ################
#   # admin feature: tokens spanned by this constituent
# class TokensFeature < RosySingleFeatureExtractor
#   TokensFeature.announce_me()

#   def TokensFeature.feature_name()
#     return "tokens"
#   end
#   def TokensFeature.sql_type()
#     return "VARCHAR(100)"
#   end
#   def TokensFeature.feature_type()
#     return "admin"
#   end

#   #####
#   private

#   def compute_feature_instanceOK()
#     return @@node.to_s
#   end
# end

################
# admin feature: frame assigned by FN
class FrameFeature < RosySingleFeatureExtractor
  FrameFeature.announce_me()

  def FrameFeature.feature_name()
    return "frame"
  end
  def FrameFeature.sql_type()
    return "VARCHAR(35)"
  end
  def FrameFeature.feature_type()
    return "ubiq"
  end
  def FrameFeature.info()
    # additional info: I am an index feature
    return super().concat(["index"])
  end

  #####
  private

  def compute_feature_instanceOK()
    if @@frame
      return @@frame.name()
    else
      return nil
    end
  end
end

################
# admin feature: is this node a terminal?
class TerminalFeature < RosySingleFeatureExtractor
  TerminalFeature.announce_me()

  def TerminalFeature.feature_name()
    return "term"
  end
  def TerminalFeature.sql_type()
    return "TINYINT"
  end
  def TerminalFeature.feature_type()
    return "admin"
  end

  #####
  private

  def compute_feature_instanceOK()
    if @@node.is_terminal?
      return 1
    else
      return 0
    end
  end
end
