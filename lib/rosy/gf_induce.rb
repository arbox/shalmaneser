# GfInduce
# Katrin Erk Jan 2006
#
# Given parse trees with FrameNet frames assigned on top of the syntactic analysis,
# and given that the Frame Elements also contain information on grammatical function
# and phrase type (as e.g. in the FrameNet annotation),
# induce a mapping from parse tree paths to grammatical functions from this information
# and apply it to new sentences

require "ruby_class_extensions"

require_relative 'gfi_gf_path_mapping'
require_relative 'gfi_subcat_frames'

#####################################################################
# Management of mapping from GFs to paths
#####################################################################
module Shalmaneser
  module Rosy
    #####################################################################
    # main class
    #####################################################################
    class GfInduce

      #########################################
      # Initialization
      #########################################

      ###
      # initialize everything to an empty hash,
      # preparing for induce_from_sent.
      # If you would like to start with induced GF already in,
      # in order to use apply(), do GfInduce.from_file(filename)
      #
      # include_sem: if true, keep frame name and FE name
      # as part of the subcat frame. if false, don't keep them
      def initialize(interpreter_class, # SynInterpreter class
                     include_sem = false)# boolean

        @interpreter = interpreter_class
        @gf_path_map = GfiGfPathMapping.new(interpreter_class)
        @subcat_frames = GfiSubcatFrames.new(include_sem)
      end

      #########################################
      # Pickling
      #########################################

      ###
      # save this GfInduce object (as a pickle) to the given file
      def to_file(filename) # string
        begin
          file = File.new(filename, "w")
        rescue
          $stderr.puts "GfInduce error: couldn't write to file #{filename}."
          return
        end

        file.puts Marshal.dump(self)
        file.close
      end

      ###
      # load a GfInduce object from the given file
      # and return it.
      # Returns nil if reading from the file failed.
      def GfInduce.from_file(filename) # string
        begin
          file = File.new(filename)
        rescue
          $stderr.puts "GfInduce error: couldn't read from file #{filename}."
          return nil
        end

        gfi_obj =  Marshal.load(file)
        file.close
        return gfi_obj
      end

      #########################################
      # Inducing mappings from training data
      #########################################

      ###
      # induce path -> gf mapping from the given SalsaTigerSentence object
      #
      # Assumption: sent contains semantic annotation: FrameNet frames
      # and the FEs of the frames have information on grammatical function (gf)
      # and phrase type (pt) of the phrase that the FE points to
      # as attributes on FeNode objects (which represent <fe> elements in the
      # underlying Salsa/Tiger XML representation)
      def induce_from_sent(sent) # SalsaTigerSentence object

        # induce GFs from each frame of the sentence
        sent.each_frame { |frame|
          unless frame.target
            # frame without a target:
            # nothing I can do
            next
          end

          # main target node, lemma
          maintarget, targetlemma, targetpos = mainnode_and_lemma(frame.target.children)
          if not(maintarget) or not(targetlemma)
            # cannot count this one
            next
          end

          # array of tuples [gfpt, prep, fe]
          subcatframe = []

          # each FE (but not the target itself):
          frame.each_child { |fe|
            if fe.name == "target"
              next
            end

            if not(fe.get_attribute("gf")) and not(fe.get_attribute("pt"))
              # no GF or PT information: nothing to learn here
              next
            end

            gfpt = "#{fe.get_attribute("gf")} #{fe.get_attribute("pt")}"

            # compute path between main target and FE syn nodes,
            # store mapping gfpt -> path in fngf_to_paths
            fe.each_child { |syn_node|

              # determine path,
              path = @interpreter.path_between(maintarget, syn_node, true)

              # store the mapping
              @gf_path_map.store_mapping(gfpt, path, syn_node, targetlemma, targetpos)

              # preposition?
              prep = @interpreter.preposition(syn_node)
              if prep
                prep.downcase!
              end

              # remember combination gfpt/prep/fe
              # as part of the subcat frame
              subcatframe << [gfpt, prep, fe.name]
            } # each syn node that the FE points to
          } # each FE of the frame

          # store the subcat frame
          @subcat_frames.store_subcatframe(subcatframe, frame.name, targetlemma, targetpos)
        } # each frame
      end

      ###
      # finish up inducing:
      #  reencode information in a fashion
      #  that makes apply() faster
      def compute_mapping
        @gf_path_map.finish_inducing
      end

      #########################################
      # Test output
      #########################################

      ###
      def test_output
        @gf_path_map.test_output
        @subcat_frames.test_output
      end

      #########################################
      # Restricting induced mappings
      # to achieve better mappings
      #########################################

      ####
      # restrict gf -> path mappings:
      # exclude all paths that include an Up edge
      def restrict_to_downpaths
        @gf_path_map.restrict_to_downpaths
      end

      ####
      # restrict gf -> path mappings:
      # only keep paths up to length n
      def restrict_pathlen(n)  # integer: maximum length to keep
        @gf_path_map.restrict_pathlen(n)
      end

      ####
      # restrict gf -> path mappings:
      # remove GFs that are often incorrect
      def remove_gfs(gf_list)
        @gf_path_map.remove_gfs(gf_list)
      end

      #########################################
      # Applying mappings to new data
      #########################################



      ###
      # given a list of nodes (idea: they form a MWE together;
      #  may of course be a single node),
      # determine all subcat frames, i.e. all consistent sets of grammatical functions,
      # for the main node among the nodelist.
      # For each subcat frame, potential FN frames and FE labels
      # are returned as well
      #
      # strict: boolean. If true, return only those subcat frames that exactly match
      #   all GFs listed in node_to_gf. If false, also return subcat frames that
      #   match a subset of the GFs mentioned in node_to_gf.
      #
      #
      # returns: list of tuples [frame(string), subcat frame, frequency(integer)],
      # where a subcat frame is an array of tuples
      # [gf (string), prep(string or nil), fe(string), synnodes(array:SynNode)]
      def apply(nodelist, # array:SynNode
                strict = false) # match: strict or subseteq?

        mainnode, lemma, pos = mainnode_and_lemma(nodelist)
        if not(mainnode) or not(lemma)
          return []
        end

        unless @subcat_frames.lemma_known(lemma, pos)
          # nothing known about the lemma
          return []
        end

        # hash: SynNode -> tuple [GF(string), preposition(string), frequency(integer)]
        node_to_gf = @gf_path_map.potential_gfs_of_node(mainnode, lemma, pos)

        #     $stderr.puts "HIER m:#{mainnode.to_s} l:#{lemma} p:{pos} "+ nodelist.map { |n| n.to_s}.join(" ")
        #     $stderr.puts "HIER2 #{@subcat_frames.lemma_known(lemma, pos)}"
        #     $stderr.puts "HIER3 #{node_to_gf.length()}"


        return @subcat_frames.match(mainnode, lemma, pos, node_to_gf, strict)
      end


      #########################################
      #########################################
      private

      #########################################
      # Main node, lemma, POS of given expression
      #########################################

      ###
      # determine main node and its lemma
      #
      # returns: SynNode*string*string, main node, lemma, POS
      def mainnode_and_lemma(nodelist)
        mainnode = @interpreter.main_node_of_expr(nodelist)
        unless mainnode
          return [nil, nil, nil]
        end

        lemma = @interpreter.lemma_backoff(mainnode)
        pos = @interpreter.category(mainnode)

        # verb? then add the voice to the POS
        if (voice = @interpreter.voice(mainnode))
          pos = pos + "-" + voice
        end
        return [mainnode, lemma, pos]
      end
    end
  end
end
