require_relative 'sem_node'
require_relative 'reg_xml'

#############
# class FeNode
#
# inherits from SemNode,
# adds to it methods specific to nodes
# that describe a frame element or target
#
# additional/changed methods:
#----------------------------
#
# name      returns the name of the frame element, or "target"
#
# add_child, remove_child

class FeNode < SemNode

  ###
  def initialize(name_or_xml, # either RegXMl object or the name of the FE as a string
                 id_if_name = nil) # string: ID to use if we just got the name of the FE

    case name_or_xml.class.to_s
    when "String"
      if name_or_xml == "target"
        super(RegXML.new("<target id=\'#{xml_secure_val(id_if_name.to_s)}\'/>"))
        @i_am_target = true
      else
        super(RegXML.new("<fe name=\'#{xml_secure_val(name_or_xml)}\' id=\'#{xml_secure_val(id_if_name.to_s)}\'/>"))
        @i_am_target = false
      end

    when "RegXML"
      super(name_or_xml)

      if name_or_xml.name == "target"
        @i_am_target = true
      else
        @i_am_target = false
      end
    else
      raise "Shouldn't be here: " + name_or_xml.class.to_s
    end

    # child_attr: keep additional attributes of <fenode> elements,
    # if there are any
    # child_attr: hash syn_node_id(string) -> attributes(hash)
    @child_attr = {}
  end

  ###
  def name
    if @i_am_target
      return "target"
    else
      return get_attribute("name")
    end
  end

  ###
  def add_child(syn_node,
                xml_obj = nil)
    if xml_obj
      # we've been given the fenode XML element
      # see if there are any attributes that we will need:
      # get attributes, remove the idref (we get that from the
      # child's ID directly)
      at = xml_obj.attributes
      at.delete("idref")
      unless at.empty?
        @child_attr[syn_node.id] = at
      end
    end

    super(syn_node, nil, "pointer_insteadof_edge" => true)
  end

  ###
  def remove_child(syn_node, varhash={})
    super(syn_node, nil, "pointer_insteadof_edge" => true)
  end

  #############
  protected

  def get_xml_ofchildren
    return children.map { |child|
      if @child_attr[child.id]
        "<fenode idref=\'#{xml_secure_val(child.id)}\'" +
        @child_attr[child.id].to_a.map { |attr, val|
          " #{attr}=\'#{xml_secure_val(val)}\'"
        }.join +
        "/>\n"

      else
        "<fenode idref=\'#{xml_secure_val(child.id)}\'/>\n"
      end
    }.join
  end
end
