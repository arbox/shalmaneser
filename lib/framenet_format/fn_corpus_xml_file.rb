# KE Dec 2006
# Access for FrameNet corpus XML file
# Mainly taken over from FramesXML
#
# changes:
# - no single frame for the whole corpus
# - below <sentence> level there is an <annotationSet> level.
#   One annotationSet may include a single frame,
#   or a reference to all named entities in a sentence
#
# Write out in tab format, one line per word:
# Format:
#    word (pt gf role target frame stuff)* ne sent_id
# with
#   word: word
#   whole bracketed group: information about one frame annotation
#    pt: phrase type
#    gf: grammatical function
#    role: frame element
#    target: LU occurrence
#    frame: frame
#    stuff: support, and other things
#   ne:    named entity
#   sent_id: sentence ID

#####################
# one FrameNet corpus
#
# just the filename is stored,
# the text is read only on demand

require_relative 'fn_corpus_xml_sentence'

class FNCorpusXMLFile

  ###
  def initialize(filename)
    @filename = filename

  end

  ###
  # yield each  document in this corpus
  # as a string
  def each_document_string
    # read each <document> element and yield it

    doc_string = ""
    inside_doc_elem = false
    f = File.new(@filename)

    # <corpus>
    #   <documents>
    #     <document ...>
    #     </document>
    #     <document ...>
    #     </document>
    #   </documents>
    # </corpus>
    f.each { |line|
      if not(inside_doc_elem) and line =~ /^.*?(<document\s.*)$/
        # start of <document>
        inside_doc_elem = true
        doc_string << $1
      elsif inside_doc_elem and line =~ /^(.*?<\/document>).*$/
        # end of <document>
        doc_string << $1
        yield doc_string
        doc_string = ""
        inside_doc_elem = false
      elsif inside_doc_elem
        # within <document>
        doc_string << line
      end
    }
  end

  ###
  # yield each sentence
  # as a FNCorpusXMLSentence object
  def each_sentence
    # read each <document> element and yield it

    sent_string = ""
    inside_sent_elem = false
    f = File.new(@filename)

    # <corpus>
    #   <documents>
    #     <document ...>
    #       <paragraphs>
    #         <paragraph>
    #           <sentences>
    #             <sentence ...>
    f.each { |line|
      if not(inside_sent_elem) and line =~ /^.*?(<sentence\s.*)$/
        # start of <sentence>
        inside_sent_elem = true
        sent_string << $1
      elsif inside_sent_elem and line =~ /^(.*?<\/sentence>).*$/
        # end of <document>
        sent_string << $1
        yield FNCorpusXMLSentence.new(sent_string)
        sent_string = ""
        inside_sent_elem = false
      elsif inside_sent_elem
        # within <sentence>
        sent_string << line.chomp
      end
    }
  end

  ###
  # print whole FN file in tab format
  def print_conll_style(file = $stdout)
    each_sentence { |s_obj|
      s_obj.print_conll_style(file)
    }
  end
end
