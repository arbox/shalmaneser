require_relative 'tree_node'


#############
# class XMLNode
#
# node with entries pointing to its children
# as well as its parent.
# all edges may be labeled.
# each node has a unique ID.
#
# indexes a string with XML data representing the same node,
# but does not look into it, just keeps it
#
# methods:
# This class inherits from TreeNode and GraphNode.
# See Tree.rb and Graph.rb for the methods they offer.
#
# new        initializes the object
#
# get        returns the XML object representing
#            the same node as this node object
#

class XMLNode < TreeNode

  # @param name [String] element name; or, for text, the whole text
  # @param attribute [Hash] attr_name(string) -> attr_value(string)
  # @param id [String] node ID
  # @param i_am_text [false, true] set to anything but false or nil to represent
  #                                not an xml element but text
  def initialize(name, attribute, id, i_am_text = false)

    if id.nil?
      # I wasn't given any ID
      # take system time for an ID
      # use to_f to get fractions of seconds too:
      # If I make several nodes in the same second,
      # they should still have unique IDs
      id = Time.new().to_f.to_s
    end

    super(id)

    # remember values for this element
    set_f("name", name)
    set_f("attributes", attribute)
    set_f("i_am_text", i_am_text)

    # sanity check
    if i_am_text and attributes
      raise "A text element cannot have attributes"
    end

    @kith = []
  end

  ###
  # add sanity check:
  # if this is text rather than an xml element,
  # it cannot have children
  def add_child(child, edgelabel, varhash={})
    if get_f("i_am_text")
      raise "A text element cannot have children"
    end
    super(child, edgelabel, varhash)
  end

  ###
  def add_kith(xml) # RegXML object
    @kith << xml
  end

  ###
  # set attribute
  # @param value [String]
  def set_attribute(name, value)
    unless value.class == String
      raise "I can only set attribute values to strings. Got: #{value.class.to_s}"
    end

    if get_f("attributes").nil?
      set_f("attributes", Hash.new())
    end
    get_f("attributes")[name] = value
  end

  ###
  def get_attribute(name)
    if get_f("attributes")
      return get_f("attributes")[name]
    else
      return nil
    end
  end

  ###
  # delete attribute
  def del_attribute(name)
    if get_f("attributes")
      get_f("attributes").delete(name)
    end
  end

  ###
  # return XML as string:
  # If this is a text, just return the text
  # which is stored in "name"
  # If this is an XMl element,
  # make a tag from its name and attributes,
  # then add tags for all its children,
  # then add an end tag.
  def get()
    if get_f("i_am_text")
      # text rather than XML element
      return get_f("name")
    else
      # XMl element, not text
      string = "<" + get_f("name")
      if get_f("attributes")
        string << get_f("attributes").to_a.map { |name, value|
          " " + name + "=\'" + xml_secure_val(value) + "\'"
        }.join()
      end
      string << ">\n"
      string << get_xml_embedded()
      string << "</#{get_f("name")}>\n"
      return string
    end
  end

  #############
  protected

  def get_xml_embedded()
    return get_xml_ofchildren() +
           get_xml_ofkith()
  end


  def get_xml_ofchildren()
    return children.map { |child|
      child.get()
    }.join()
  end


  def get_xml_ofkith()
    return @kith.map { |thing| thing.to_s + "\n" }.join()
  end


  ###
  def warn_child_ignored(where, xml_node)
    $stderr.puts "WARNING: additional material found in #{where}, will be ignored:"
    $stderr.puts "\t" + xml_node.to_s
  end

  ###
  def xml_secure_val(value) # string: value of an attribute
    return value.gsub(/'/, "&apos;").gsub(/"/, "&apos;&apos;")
    return value
  end
end
