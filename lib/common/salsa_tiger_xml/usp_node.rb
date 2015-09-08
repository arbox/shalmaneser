require_relative 'salsa_tiger_xml_node'

#############
# class UspNode
#
# inherits from SalsaTigerXmlNode,
# adds to it methods specific to nodes
# that describe a frame underspecification or frame element underspecification
#
# additional/changed methods:
#----------------------------
#
# new             initializes the object
#    rexml_object: underlying XML object for this node
#    frame_or_fe:  string, either "frame" for frame underspecification
#                  or "fe" for frame element underspecification
#
# add_child, remove_child   add, remove underspecification entry

class UspNode <  SalsaTigerXmlNode

  attr_reader :i_am

  ###
  def initialize(xml_obj,      # RegXMl object
                 frame_or_fe)  # string "frame" or "fe"

    super(xml_obj)
    case frame_or_fe
    when "frame"
      @i_am = "frame"
    when "fe"
      @i_am = "fe"
    else
      raise "new: neither frame nor fe??"
    end
  end

  ###
  def add_child(node, varhash={})
    if node
      super(node, nil, "pointer_insteadof_edge" => true)
    else
      raise "Got nil for a node."
    end

    # set usp. attribute on child
    node.set_attribute("usp", "yes")
  end

  ###
  def remove_child(node, varhash={})
    super(node, nil, "pointer_insteadof_edge" => true)

    # removing "usp" attribute on child
    # this will be wrong if the child is involved in more
    # than one instance of underspecification!

    $stderr.puts "Warning: unsafe removal of attribute 'usp'"
    node.del_attribute("usp")
  end

  #############
  protected

  def get_xml_ofchildren()
    return children.map { |child|
      "<uspitem idref=\'#{xml_secure_val(child.id)}\'/>\n"
    }.join()
  end

end
