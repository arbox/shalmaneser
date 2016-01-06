# sp 18 06 2004
#
# access to FrameNet XML files, sentences, and annotation.
#
# sp 10 11 04: only data from the first layer with name XY is
# used for output. Other data is saved in layer XY.2nd, but is
# currently not processed.
#
# sp 22 05 04: also, if two labels exist which cover the same span
# (ie there is a double annotation within the same layer), ignore
# all but the first label.
#
# ke 13 07 05:
#   - changed to RegXMl.rb
#   - fixed two problems in analyse_layer:
#     - Deleting problematic labels:
#       For some reason, thisLayer[i+1..-1].each_index {|other_i|
#       included the index 0 in any case, resulting in the 1st
#       label being deleted in any case.
#     - Deleting problematic labels, checking for label overlap:
#       The old formulation worked only if labels occurred in the array
#       in the order they occurred in the sentence, but that was not the case.
#   - Change in deleting problematic labels:
#     No longer delete duplicate labels, since e.g. in the PT level there
#     may be more than one NP label, and we want to keep those
#
# KE January 2007:
# write new adapted FNTab format
# ( "word", ("pt", "gf", "role", "target", "frame", "stuff")* "ne", "sent_id" )


require_relative 'frame_xml_sentence'
require 'salsa_tiger_xml/reg_xml'

class FrameXMLFile #  only verified to work for FrameNet v1.1

  def initialize(filename)
    @filename = filename
    file = File.new(filename)
    counter = 0
    while true
      counter +=1
      line = file.gets
      if line =~ /<lexunit/
        break
      end
      if counter > 3
        STDERR.puts "Error: File "+filename+" does not conform to FrameNet v1.1 standard (lexunit in 3rd line)"
        Kernel.exit
      end
    end
    # found lexunit
    string = line
    while (line = file.gets)
      string << line
    end
    @lexunit = STXML::RegXML.new(string)
    attributes = @lexunit.attributes
    @id = attributes["ID"]
    attributes["name"] =~ /^([^.]+).([^.]+)$/
    @lu = $1
    @pos = $2.upcase
    if @lu.nil?
      raise "[framexml] no lemma in header of file #{@filename}"
    elsif @pos.nil?
      raise "[framexml] no pos in header of file #{@filename}"
    end
    @frame = attributes["frame"]
  end

  def get_lu
    return @lu.gsub(" ","_")
  end

  def get_lu_id
    return @id
  end

  def get_filename
    return @filename
  end

  def get_pos
    return @pos
  end

  def get_frame
    return @frame
  end

  def close
  end

  def each_sentence
    @lexunit.children_and_text.each { |subcorpus|
      subcorpus.children_and_text.each { |annotationSet|
        if annotationSet.name == "annotationSet"
          # sentence found
          yield FrameXMLSentence.new(annotationSet,self)
        end
      }
    }
  end
end
