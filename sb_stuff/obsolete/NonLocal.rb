#############################
#
# NonLocal.rb
# Katrin Erk, June 22 2003
#


# 
# XML parser
require "rexml/document"

require "Parser"
require "SentenceNew"
require "TigerVerbs"

#########################################################

module NonlocalFEModule

  class NonlocalFEs

    ###
    def set_sentence(sent)
      # sobj is a ManageSynSem::Sentence object, 
      # the current sentence encoded partially as XML, 
      # partially in hashes to allow for faster access
      @sobj = ManageSynSem::Sentence.new(sent)
      @tvobj = TigerVerbsModule::MaxProjection.new(@sobj)
      @target = nil
    end

    ###
    def explain(file)
      @tvobj.explain(file)
    end

    ###
    def set_frame(frame_id)
      @target = @sobj.sem.get_target_nodeids(frame_id).first
    end
    private :set_frame

    ###
    def find_nonlocal_fes()
      return find_non_local_fes('nonlocal')
    end

    ###
    def find_local_nonlocal_fes()
      return find_non_local_fes('local_nonlocal')
    end

    ###
    def find_non_local_fes(which)
      if @sobj.nil?
	return []
      end

      ret_local = Array.new
      ret_nonlocal = Array.new

      @sobj.sem.frames.each_key { |frame_id|
	set_frame(frame_id)
	max_proj = @tvobj.max_projection(@target)

	@sobj.sem.frames[frame_id].fes.each_key { |fe_id|
	  # test if this FE is dominated by the max projection node
	  if dominates_fe(max_proj['max_proj'], frame_id, fe_id)
	    ret_local << construct_fe_hash(frame_id, fe_id)
	  else
	    ret_nonlocal << construct_fe_hash(frame_id, fe_id)
	  end
	}
      }

      case which
      when 'local'
	return ret_local
      when 'nonlocal'
	return ret_nonlocal
      when 'local_nonlocal'
	return [ret_local, ret_nonlocal]
      else
	$stderr.puts 'Error in NonLocal.rb: illegal parameter'
	return []
      end
    end
    private :find_non_local_fes


    def dominates_fe(node_id, frame_id, fe_id)
      fe_nodes = @sobj.sem.get_fe_nodeids(frame_id, fe_id)
      fe_nodes.each { |fe_node|
	unless @sobj.syn.is_ancestor(node_id, fe_node)
	  return false
	end
      }
      return true
    end
    private :dominates_fe

    def construct_frame_hash(frame_id)
      target_ids = @sobj.sem.get_target_nodeids(frame_id)
      return { 'id' => frame_id, 
	  'frame' => @sobj.sem.frames[frame_id].frame_name(),
	  'target_words' => get_words(target_ids)
      }  
    end
    private :construct_frame_hash

    def construct_fe_hash(frame_id, fe_id)
      hash = construct_frame_hash(frame_id)
      hash['fe_id'] = fe_id
      hash['fe'] = @sobj.sem.frames[frame_id].fe_name(fe_id)
      hash['fe_words'] = get_words(@sobj.sem.get_fe_nodeids(frame_id,
							    fe_id))
      return hash
    end
    private :construct_fe_hash

    def get_words(id_list)
      if id_list.nil?
	return []
      end
      leaves = Array.new
      id_list.each { |id|
	leaves.concat @sobj.syn.yield_ids(id)
      }
      words = @sobj.syn.sort_ids(leaves).collect { |id|
	@sobj.syn.terminal_or_split_word(id)
      }.compact
    end
    private :get_words

  end

end
