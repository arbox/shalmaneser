module STXML
  # RegXML
  #
  # Katrin Erk June 2005

  # SalsaTigerRegXML: take control of the data structure, no underlying xml
  # representation anymore, re-generation of xml on demand

  class RegXML

    def initialize(string, # string representing a single XML element
                   i_am_text = false) # boolean: xml element (false) or text (true)

      unless string.class == String
        raise "First argument to RegXML.new must be string. I got #{string.class}"
      end

      if i_am_text
        @s = string
        @i_am_text = true
      else
        @s = string.gsub(/\n/, " ").freeze
        @i_am_text = false

        element_test
        dyck_test
      end
    end

    def first_child_matching(child_name)
      children_and_text.detect { |c| c.name == child_name }
    end

    def each_child_matching(child_name)
      children_and_text.each do |c|
        if c.name == child_name
          yield c
        end
      end
    end

    def to_s
      xml_readable(@s)
    end

    def text?
      @i_am_text
    end

    # Return the name of the xml element contained in the string.
    # @return [String] Name of the element.
    def name
      if @i_am_text
        # text
        return nil

      else
        # xml element
        if @s =~ /^\s*<\s*([\w-]+)[\s\/>]/
          return $1
        else
          raise "Cannot parse:\n#{xml_readable(@s)}"
        end
      end
    end

    # Return a hash of attributes and their values.
    # @return [Hash<String String>] Attributes of an xml element.
    def attributes
      if @i_am_text
        # text
        return {}

      else
        #  xml element

        # remove <element_name  from the beginning of @s,
        # place the rest up to the first > into elt_contents:
        # this is a string of the form
        # - either (name=value)*
        # - or     (name=value)*/
        unless @s =~ /^\s*<\s*#{name}(.*)$/
          raise "Cannot parse:\n #{xml_readable(@s)}"
        end

        retv = {}
        elt_contents = $1

        # repeat until only > or /> is left
        while elt_contents !~ /^\s*\/?>/

          # shave off the next name=value pair
          # put the rest into elt_contents
          # make sure that if the value is quoted with ',
          # we accept " inside the value, and vice versa.
          unless elt_contents =~ /^\s*([\w-]+)=(['"])(.*?)\2(.*)$/
            raise "Cannot parse:\n #{xml_readable(elt_contents)}"
          end
          retv[$1] = $3
          elt_contents = $4
        end

        return retv
      end
    end

    def children_and_text
      if @i_am_text
        return []

      else
        if unary_element
          # <bla/>, no children
          return []
        end

        # @s has the form <bla...>  ... </bla>.
        # remove <bla ...>  from the beginning of @s,
        # place the rest up to </bla> into children_s:

        mainname = name
        unless @s =~ /^\s*<\s*#{mainname}(\s+[\w-]+=(["']).*?\2)*\s*>(.*?)<\/\s*#{mainname}\s*>\s*$/
          raise "Cannot parse:\n #{xml_readable(@s)}"
        end

        retv = []
        children_s = $3

        # repeat until only whitespace is left
        while children_s !~ /^\s*$/

          # shave off the next bit of text
          # put the rest into children_s
          unless children_s =~ /^\s*(.*?)(<.*$|$)/
            $stderr.puts "Whole was:\n #{xml_readable(@s)}"
            $stderr.puts
            raise "Cannot parse:\n #{xml_readable(children_s)}"
          end
          unless $1.strip.empty?
            children_s = $2
            retv << RegXML.new($1, true)
          end

          # anything left after we've parsed text?
          if children_s =~ /^s*$/
            break
          end

          # shave off the next child
          # and put the rest into children_s

          # determine the next child's name, and the string index at which
          # the element start tag ends with either / or >
          unless children_s =~ /^\s*(<\s*([\w-]+)(\s+[\w-]+=(["']).*?\4)*\s*)/
            $stderr.puts "Whole was:\n #{xml_readable(@s)}"
            $stderr.puts
            raise "Cannot parse:\n #{xml_readable(children_s)}"
          end
          childname = $2
          child = $1
          endofelt_ix = $&.length


          # and remove it
          case children_s[endofelt_ix..-1]
          when /^\/>(.*)$/
            # next child is a unary element
            children_s = $1
            retv << RegXML.new(child + "/>")

          when /^(>.*?<\s*\/\s*#{childname}\s*>)(.*)$/
            children_s = $2
            retv << RegXML.new(child + $1)

          else
            $stderr.puts "Whole was:\n #{xml_readable(@s)}"
            $stderr.puts
            raise "Cannot parse:\n#{xml_readable(children_s)}"
          end
        end

        return retv
      end
    end

    def RegXML.test
      bla = RegXML.new("  <bla blupp='a\"b'
lalala=\"c\">
  <lalala> </lalala>
  texttext
  <lala blupp='b'/>
  nochtext
  <la> <l/> </la>
</ bla >
")
      puts "name " + bla.name
      puts
      puts bla.to_s
      puts
      bla.attributes.each { |attr, val|
        puts "attr " + attr + "=" + val
      }
      puts
      bla.children_and_text.each { |child_obj|
        if child_obj.text?
          puts "da text " + child_obj.to_s
        else
          puts "da child " + child_obj.to_s
        end
      }
      puts

      puts "NEU"
      bla = RegXML.new("  < bla blupp='a\"'/> ")
      puts "name " + bla.name
      puts
      puts bla.to_s
      puts
      bla.attributes.each { |attr, val|
        puts "attr " + attr + "=" + val
      }
      puts
      bla.children_and_text.each { |child_obj|
        if child_obj.text?
          puts "da text " + child_obj.to_s
        else
          puts "da child " + child_obj.to_s
        end
      }
      puts

    end

    ##############
    protected

    def unary_element
      # <bla/>
      if @s =~ /^\s*<.*\/>\s*$/
        return true
      else
        return false
      end
    end

    def element_test
      # make sure we have a single XML element, either <bla/> or
      # <bla>...</bla>

      if unary_element
      # <bla/>
      elsif @s =~ /^\s*<\s*([\w-]+)\W.*?<\/\s*\1\s*>\s*$/
      # <bla  > ... </bla>
      else
        raise "Cannot parse:\n #{xml_readable(@s)}"
      end
    end

    def dyck_test
      # every prefix of @s must have at least as many < as >
      opening = 0
      closing = 0
      @s.scan(/[<>]/) { |bracket|
        case bracket
        when "<"
          opening += 1
        when ">"
          closing += 1
          if closing > opening
            raise "More closing than opening brackets in prefix of:\n #{xml_readable(@s)}"
          end
        end
      }

      # and in total, @s must have equally many < and >
      unless @s.count("<") == @s.count(">")
        raise "Inequal number of brackets in:\n #{xml_readable(@s)}"
      end
    end

    def xml_readable(string)
      string.gsub(/>/, ">\n")
    end
  end
end
