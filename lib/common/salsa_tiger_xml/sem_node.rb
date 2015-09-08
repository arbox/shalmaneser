require_relative 'salsa_tiger_xml_node'

#############
# class SemNode
#
# common superclass for FrameNode and FeNode,
# with methods that are the same for both:
#
#
# is_usp?   returns true if the frame/FE is involved in underspecification,
#           else false
#
# flags     returns an array of all the frame/FE flags for this node.
#           members of the array are strings describing the flags
#           that have been set to true
#
# add_flag  add or remove a frame/FE flag
# remove_flag

class SemNode < SalsaTigerXmlNode
  attr_reader :flags

  def initialize(xml) # RegXML object or text
    super(xml)
    # flags: array of FlagNode objects
    @flags = Array.new()
  end

  ###
  def is_usp?
    return get_attribute("usp") == "yes"
  end

  ###
  def add_flag(name) # string: flag name
    @flags << name
  end

  ###
  def remove_flag(name) # string: flag name
    @flags.delete(name)
  end

  #############
  protected

  def get_xml_embedded()
    return super() + get_xml_offlags()
  end

  def get_xml_offlags()
    # and add flags
    return @flags.map { |flagname|
      "<flag name=\'#{xml_secure_val(flagname)}\'/>\n"
    }.join
  end
end
