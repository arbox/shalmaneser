# GfInduceFeature
# Katrin Erk Jan 06
#
# use result of GfInduce.rb as
# feature for Rosy

require "rosy/GfInduce"
require "rosy/AbstractFeatureAndExternal"
require "common/ruby_class_extensions"

###
# make filename for GfInduce picle file
def filename_gfmap(exp,         # ExternalConfigData object
		   interpreter) # SynInterpreter class

  # output dir as given in my experiment file
  # If there is an experiment ID, make subdirectory
  # named after the experiment ID and place the data there.
  output_dir = File.new_dir(exp.get("directory"))
  if exp.get("experiment_id")
    output_dir = File.new_dir(output_dir, exp.get("experiment_id"))
  end
  
  # output file name: 
  # Gfmap.{<service>=<system_name>.}*{OPT<service>=<system_name>.}*pkl
  return output_dir + 
    "Gfmap." + 
    interpreter.systems().to_a.map { |service, system_name|
    service.to_s+ "=" + system_name.to_s
  }.sort.join(".") + "." +
    interpreter.optional_systems().to_a.map { |service, system_name|
    "OPT" + service.to_s + "=" + system_name.to_s
  }.sort.join(".") + ".pkl"
end

################################
# base class for all following feature extractors
class GfInduceFeatureExtractor < ExternalFeatureExtractor
  GfInduceFeatureExtractor.announce_me()

  @@okay = true  # external experiment file present?
  @@gf_obj = nil # GfInduce object
  @@node_to_gf = nil # Hash: SynNodes of a sentence -> Gf label

  def GfInduceFeatureExtractor.designator()
    return "gf_fn"
  end
  def GfInduceFeatureExtractor.feature_names()
    return ["gf_fn"]
  end
  def GfInduceFeatureExtractor.sql_type()
    return "VARCHAR(25)"
  end
  def GfInduceFeatureExtractor.feature_type()
    return "syn"
  end
  def GfInduceFeatureExtractor.phase()
    return "phase 1"
  end

  ###
  # set sentence, set node, set other settings: 
  # this is done prior to
  # feature computation using compute_feature()
  # such that computations that stay the same for
  # several features can be done in advance
  #
  # This is just relevant for Phase 1
  #
  # returns: false/nil if there was a problem
  def GfInduceFeatureExtractor.set_sentence(sent,  # SalsaTigerSentence object
                                            frame) # FrameNode object

    super(sent, frame)

    if @@okay
      # we can actually compute something

      # let the GF object compute all subcat frames
      # for the target of this frame
      subcatframes_of_current_target = @@gf_obj.apply(frame.target.children())

      # keep the most frequent one of the
      # subcat frames returned by the GF object:
      if subcatframes_of_current_target.empty?
        # no subcat frames returned
        subcatframe = []
      else
        # we have at least one subcat frame: 
        # keep the most frequent one of them
        #
        # Also, subcatframes_of_current_target
        # contains triples [frame, actual_subcatframe, frequency]
        # Of these, keep just the actual_subcatframe

        subcatframe = subcatframes_of_current_target.sort { |a, b|
          # sort by frequency
          b.last <=> a.last
        }.first[1]
      end
      
      # change into a mapping node(SynNode) -> GF(string)
      @@node_to_gf = Hash.new
      subcatframe.each { |gf, prep, fe, synnodes|
        synnodes.each { |node|
          @@node_to_gf[node] = "#{gf} #{prep}"
        }
      }
    end
  end


  ###
  # Initialize: read GFInduce pickle
  def initialize(exp,                  # experiment file object
                 interpreter_class)    # SynInterpreter class

    super(exp, interpreter_class)
    
    if @exp_external
      pickle_filename = filename_gfmap(@exp_external, @@interpreter_class)
      @@gf_obj = GfInduce.from_file(pickle_filename)
      @@okay = true

    else
      # signal that you cannot compute anything
      @@okay = false
    end
  end

  ###
  # compute: compute features
  #
  # returns an array of features (strings), length the same as the
  # length of feature_names()
  #
  # here: array of length one, content either a string or nil
  def compute_features()
    # current node: @@node
    # check whether the current node has been assigned a slot
    # in the subcat frame
    if @@okay
      return [ @@node_to_gf[@@node] ]
    else
      return [ nil ]
    end
  end
end