require_relative 'xml_node'
require_relative 'ts_syn_node'
require_relative 'salsa_tiger_xml_node'
require_relative 'usp_node'
require_relative 'frame_node'
require_relative 'fe_node'
require_relative 'reg_xml'

module STXML
#############
class SalsaTigerSentenceSem < XMLNode

  attr_reader :node

  ###
  def SalsaTigerSentenceSem.get_splitwords(xml_obj)
    return xml_obj.children_and_text.detect { |child|
      child.name == "splitwords"
    }
  end

  ###
  def initialize(xml_obj,      # RegXML object
                 sentence_id,  # string: sentence ID
                 id_to_node)   # hash: syn_node_id(string) -> SynNode object

    # global data:
    # node: hash node_id -> XMLNode object
    #       maps node IDs to the nodes with that ID
    # frame_id, uspframe_id, uspfe_id: arrays of node IDs,
    #   listing all frame nodes, frame underspecification nodes,
    #   and FE underspecification nodes respectively
    # globals: array of RegXML objects, each representing one sentence flag
    @node = {}
    @frame_id = []
    @uspframe_id = []
    @uspfe_id = []
    @globals = []

    if xml_obj
      # we actually have semantic information.
      # read it.

      super(xml_obj.name, xml_obj.attributes, sentence_id + "_sem", false)

      globals_obj = frames_obj = usp_obj = nil

      xml_obj.children_and_text.each { |obj|
        case obj.name
        when "globals"
          globals_obj = obj
        when "frames"
          frames_obj = obj
        when "usp"
          usp_obj = obj
        else
          add_kith(obj)
        end
      }

      # handle globals
      if globals_obj
        globals_obj.children_and_text.each { |obj|
          @globals << obj
        }
      end

      # index frames
      if frames_obj
        frames_obj.children_and_text.each { |frame|
          unless frame.name == "frame"
            warn_child_ignored("s/sem/frames/", frame)
            next
          end

          # make a node for the frame.
          node = FrameNode.new(frame)
          semnode_add_flags(node, frame)
          @node[node.id] = node
          @frame_id << node.id
          # add FEs
          frame_add_children(node, frame, id_to_node)
        }
      end

      # index underspecification
      if usp_obj
        usp_obj.children_and_text.each { |uspframe_or_fe|
          case uspframe_or_fe.name
          when "uspframes"
            initialize_usp(uspframe_or_fe, "frame")
          when "uspfes"
            initialize_usp(uspframe_or_fe, "fe")

          else
            warn_child_ignored("s/sem/usp/", uspframe_or_fe)
          end
        }
      end

    else
      # we have no semantic information
      # record it anyway

      super("sem", {}, sentence_id + "_sem", false)
    end
  end

  ################################################3
  # access methods

  ###
  def each_frame
    @frame_id.each { |node_id|
      yield @node[node_id]
    }
  end

  ###
  def frames
    return @frame_id.map { |node_id| @node[node_id] }
  end

  ###
  def each_usp_frameblock
    @uspframe_id.each { |node_id|
      yield @node[node_id]
    }
  end

  ###
  def usp_frameblocks
    return @uspframe_id.map { |node_id| @node[node_id] }
  end

  ###
  def each_usp_feblock
    @uspfe_id.each { |node_id|
      yield @node[node_id]
    }
  end

  ###
  def usp_feblocks
    return @uspfe_id.map { |node_id| @node[node_id] }
  end

  ###
  def flags
    return @globals.map { |xml_obj|
      { "type" => xml_obj.attributes["type"],
       "param" => xml_obj.attributes["param"],
       "text" => xml_obj.children_and_text.map { |c| c.to_s }.join
      }
    }
  end

  ################################################3
  # adding and removing things

  ###
  def add_frame(sentid,  # string: sentence ID
                name,    # string: name of the frame
                sem_id = nil) # string: ID for the new node

    # make a node for the frame
    if sem_id
      frameid = sem_id
    else
      frameid = sentid + "_f" + Time.new.to_f.to_s
    end
    n = FrameNode.new(RegXML.new("<frame id=\"#{frameid}\" name=\"#{name}\"/>"))
    @node[n.id] = n
    @frame_id << n.id

    return n
  end

  ###
  def remove_frame(frame_node)
    @node.delete(frame_node.id)
    @frame_id.delete(frame_node.id)
  end

  ###
  def add_fe(frame_node, # FrameNode
             fe_name,    # string: name of new FE
             fe_children, # array:SynNode, children of new FE
             sem_id = nil) # optional: ID of new FE


    new_fe = frame_node.add_fe(fe_name, fe_children, sem_id)
    @node[new_fe.id] = new_fe
    return new_fe
  end

  ###
  def remove_fe(fe_node)
    @node.delete(fe_node.id)
    fe_node.parent.remove_child(fe_node)
  end

  ###
  def add_usp(frame_or_fe)    # string: "frame" or "fe"

    n = UspNode.new(RegXML.new("<uspblock/>"), frame_or_fe)
    @node[n.id] = n
    case frame_or_fe
    when "frame"
      @uspframe_id << n.id
    when "fe"
      @uspfe_id << n.id
    else
      raise "Shouldn't be here"
    end

    return n
  end

  ###
  def remove_usp(usp_node)
    usp_node.children.each { |child|
      usp_node.remove_child(child)
    }
    @node.delete(usp_node.id)
    case usp_node.i_am
    when "frame"
      @uspframe_id.delete(usp_node.id)
    when "fe"
      @uspfe_id.delete(usp_node.id)
    else
      raise "Shouldn't be here"
    end
  end


  ###
  def add_child(arg1, arg2)
    raise "Not implemented for this class"
  end

  ###
  def remove_child(arg1, arg2)
    raise "Not implemented for this class"
  end

  ###
  def add_flag(type, param=nil, text=nil)
#    unless ["REEXAMINE", "WRONGSUBCORPUS", "INTERESTING", "LATER"].include? type
#      raise "add_flag: unknown type "+type
#    end

    newglob = "<global type=\'#{xml_secure_val(type)}\'"
    if param
      newglob << " param=\'#{xml_secure_val(param)}\'"
    end
    if text
      newglob << "> #{text} </global>"
    else
      newglob << "/>"
    end

    newglob = RegXML.new(newglob)
    @globals << newglob
    return newglob
  end

  ###
  def remove_flag(type, param=nil, text=nil)

    remove_ix = nil
    @globals.each_with_index { |glob,ix|
      if glob.attributes("type") == type
        if param.nil? or glob.attributes("param") == param
          if text.nil? or glob.children_and_text.map { |c| c.to_s }.join == text
            # found it
            remove_ix = ix
            break
          end
        end
      end
    }

    if remove_ix
     return  @globals.delete_at(remove_ix)
    else
      return nil
    end
  end

  ############################3
  protected

  def get_xml_ofchildren
    string = ""

    # globals
    string << "<globals>\n"
    @globals.each { |glob|
      string << glob.to_s + "\n"
    }
    string << "</globals>\n"

    # frames
    string << "<frames>\n"
    each_frame { |frame_node|
      string << frame_node.get
    }
    string << "</frames>\n"

    # underspecification
    string << "<usp>\n"
    string << "<uspframes>\n"
    each_usp_frameblock { |block|
      string << block.get
    }
    string << "</uspframes>\n"
    string << "<uspfes>\n"
    each_usp_feblock { |block|
      string << block.get
    }
    string << "</uspfes>\n"
    string << "</usp>\n"

    return string
  end

  ###
  def semnode_add_flags(sem_node,  # SemNode object
                        xml_obj)   # RegXML object

    xml_obj.children_and_text.each { |child|
      if child.name == "flag"
        # found a flag, record it
        name = child.attributes["name"]
        if name
          sem_node.add_flag(name)
        else
          $stderr.puts "Warning: flag without a name"
        end
      end
    }
  end

  def frame_add_children(frame_node, # FrameNode object
                         xml_obj,    # RegXML object
                         id_to_node) # hash: syn_node_id(string) -> SynNode object

    xml_obj.children_and_text.each { |fe|
      case fe.name
      when "fe", "target"
#        $stderr.puts "Da: #{fe.name}\n#{fe.to_s}"

        # make a node for this,
        # and add it as child of this frame node.
        fe_node = FeNode.new(fe)
        @node[fe_node.id] = fe_node
        frame_node.add_child(fe_node)

        semnode_add_flags(fe_node, fe)

        # add the FE's children
        fe.children_and_text.each { |fechild|
          case fechild.name
          when "fenode"

            syn_node = id_to_node[SalsaTigerXmlNode.xmlel_id(fechild)]
            if syn_node
              # normal syntactic node, which the id_to_node mapping knows
              fe_node.add_child(syn_node, fechild)
              syn_node.add_sem(fe_node)

            else
              # must be a node in a different sentence
              # make a dummy graph node for it
              fe_node.add_child(TSSynNode.new(SalsaTigerXmlNode.xmlel_id(fechild)), fechild)
            end

          when "flag"
            # nothing to do, we've handled that already
          else
            fe_node.add_kith(fechild)
          end
        }

      when "flag"
        # nothing to do, wee handled that already

      else
        # keep for output
        frame_node.add_kith(fe)
      end
    }
  end

  ###
  def initialize_usp(xml_obj,      # RegXML object
                     frame_or_fe)  # string: "frame" or "fe"

    xml_obj.children_and_text.each { |uspblock|
      unless uspblock.name == "uspblock"
        warn_child_ignored("s/sem/usp/uspframe|uspfe", uspblock)
        next
      end

      # node for this underspecified block
      n = UspNode.new(uspblock, frame_or_fe)
      @node[n.id] = n

      case frame_or_fe
      when "frame"
        @uspframe_id << n.id
      when  "fe"
        @uspfe_id << n.id
      else
        raise "Shouldn't be here"
      end

      # add its children
      uspblock.children_and_text.each { |uspitem|
        unless uspitem.name == "uspitem"
          warn_child_ignored("s/sem/usp/uspframe|uspfe/uspblock", uspitem)
          next
        end

        usp_id = SalsaTigerXmlNode.xmlel_id(uspitem)
        usp_id = usp_id.gsub(/.*_s/, "s")

        unless @node[usp_id]
          $stderr.puts "Error: Underspecification: could not find node with ID #{usp_id}. Skipping."
          next
        end
        n.add_child(@node[usp_id])
      }
    }
  end
end
end
