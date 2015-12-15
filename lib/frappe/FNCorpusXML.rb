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

require 'frappe/Ampersand'
require 'common/ISO-8859-1'
require 'common/salsa_tiger_xml/reg_xml'

# @note AB: Moved this to the proper class.
=begin
#####################
# mixins to make work with RegXML a little less repetitive
class RegXML
  def first_child_matching(child_name)
    return children_and_text().detect { |c| c.name() == child_name }
  end

  def each_child_matching(child_name)
    children_and_text().each { |c|
      if c.name() == child_name
        yield c
      end
    }
  end
end
=end

#####################
# class to keep data for one frame
class FNCorpusAset
  attr_reader :layers, :aset_type, :aset_id, :frame_name, :lu

  #######
  # Analyze RegXML object, store in object variables:
  #
  # @aset_type: "frame" or "NER"
  # @frame_name: frame name for "frame" type
  # @lu: LU for "frame" type
  # @aset_id: ID of the annotation set
  # @layers: hash: layer type (FE, GF, PT, Target, NER) -> [offset, "start"/"stop"]  -> list of labels
  #     string -> int*string -> array:string
  #
  def initialize(aset, #RegXML object
                 charidx) # array of pairs [start index, stop index] int*int

    @layers = Hash.new()
    @frame_name = nil
    @lu = nil
    @aset_type = nil

    attributes = aset.attributes()

    @aset_id = attributes["ID"]

    if attributes["frameName"]
      # all of these seem to be frames. store in 'frames' array
      unless attributes["luName"]
        $stderr.puts "FNCorpusAset warning: cannot determine LU name"
        $stder.puts aset.to_s()
        return
      end
      @aset_type = "frame"
      @frame_name = attributes["frameName"]
      @lu = attributes["luName"]

      unless (layers = aset.first_child_matching("layers"))
        $stderr.puts "FNCorpusAset warning: unexpectedly no layers found"
        $stderr.puts aset.to_s()
        return
      end

      layers.each_child_matching("layer") { |l| analyze_layer(l, charidx) }

    else
      # all we seem to get here are named entity labels.
      @aset_type = "NER"

      unless (layers = aset.first_child_matching("layers"))
        $stderr.puts "FNCorpusAset Warning: unexpectedly no layers found"
        $stderr.puts aset.to_s()
        return
      end
      unless (layer = layers.first_child_matching("layer"))
        $stderr.puts "FNCorpusAset Warning: unexpectedly no layers found"
        $stderr.puts aset.to_s()
        return
      end

      unless layer.attributes()["name"] == "NER"
        $stderr.puts "FNCorpusAset Warning: unexpected layer #{layer.attributes()["name"]}, was expecting only an NER layer."
        $stderr.puts aset.to_s()
        return
      end

      analyze_layer(layer, charidx)

    end
  end


  #############
  # input: <layer> RegXML object
  # analyze this, put into @layers data structure
  def analyze_layer(layer, # RegXML object
                    charidx) # array:int*int pairs start/end index of words
    layer_name = layer.attributes()["name"]
    unless layer_name
      $stderr.puts "FNCorpusAset warning: cannot determine layer name"
      $stderr.puts layer.to_s
      return
    end

    # FN-specific: skip 2nd layer FEs for now
    if layer_name == "FE" and layer.attributes()["rank"] == "2"
      return
    end

    unless @layers[layer_name]
      @layers[layer_name] = Hash.new()
    end

    unless (labels = layer.first_child_matching("labels"))
      # nothing to record for this layer
      return
    end


    # taking over much of analyse_layer() from class FrameXML
    thisLayer = Array.new()

    labels.each_child_matching("label") { |label|
      attributes = label.attributes()
      if attributes["itype"] =~ /NI/
        # null instantiation, ignore
        next
      end

      if not(attributes["start"]) and not(attributes["end"])
        # no start and end labels
        next
      end
      thisLayer << [attributes["name"], attributes["start"].to_i, attributes["end"].to_i]
    }

    # sanity check: do indices
    # match word start and end indices?
    thisLayer = verify_annotation(thisLayer, charidx)

    # sanity check: verify that
    # we don't have overlapping labels

    deleteHash = Hash.new # keep track of the labels which are to be deleted
    # i -> Boolean

    thisLayer.each_index {|i|
      # efficiency: skip already delete labels
      if deleteHash[i]
        next
      end
      this_label, this_from , this_to = thisLayer[i]

      # compare with all remaining labels
      (i+1..thisLayer.length()-1).to_a.each { |other_i|
        other_label,other_from,other_to = thisLayer[other_i]

        # overlap? Throw out the later FE
        if this_from <= other_from and other_from <= this_to
          $stderr.puts "Warning: Label overlap, deleting #{other_label}"
          deleteHash[other_i] = true
        elsif this_from <= other_to and other_to <= this_to
          $stderr.puts "Warning: Label overlap, deleting #{this_label}"
          delete_hash[i] = true
        end
      }
      # matched with all other labels. If "keep", return

      if deleteHash[i]
      # $stderr.puts " deleting entry #{i}"
      else
        [ [this_from, "start"], [this_to, "stop"]].each { |offset, start_or_stop|
          unless @layers[layer_name].has_key?([offset, start_or_stop])
            @layers[layer_name][[offset, start_or_stop]] = Array.new()
          end
          @layers[layer_name][ [offset, start_or_stop] ] << this_label
        }
      end
    }
  end

  ##############3
  # verify found triples label/from_index/to_index
  # against given start/end indices of words
  #
  # returns: triples, possibly changed
  def verify_annotation(found,        # array: label/from/to, string*int*int
                        charidx)      # array: from/to, int*int

    return found.map {|element, start, stop|

      newstart = start
      newstop = stop

      # compare against word start/stop indices
      charidx.each_index{|j|
        unless j== 0
          pstartidx, pstopidx = charidx[j-1]
        end
        startidx, stopidx = charidx[j]

        if (start > startidx and start <= stopidx) or
          (j != 0 and start > pstopidx and start < startidx)
          newstart = startidx
        end

        if (stop >= startidx and stop < stopidx)
          newstop = stopidx
        elsif (j != 0 and stop > pstopidx and stop < startidx)
          newstop = pstopidx
        end
      }

      # change?
      if start != newstart or stop != newstop
        # report change
        $stderr.puts "FNCorpusXML warning: Heuristics has changed element "+element
        $stderr.puts "\tfrom ["+[start,stop].join(",")+"] to ["+[newstart,newstop].join(",")+"]"

        [element, newstart, newstop]

      else

        [element, start, stop]
      end
    }
  end
end

#####################
# one FrameNet corpus
#
# just the filename is stored,
# the text is read only on demand
class FNCorpusXMLFile

  ###
  def initialize(filename)
    @filename = filename

  end

  ###
  # yield each  document in this corpus
  # as a string
  def each_document_string()
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
  def each_sentence()
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
        sent_string << line.chomp()
      end
    }
  end

  ###
  # print whole FN file in tab format
  def print_conll_style(file = $stdout)
    each_sentence() { |s_obj|
      s_obj.print_conll_style(file)
    }
  end
end

#######################################
# Keep one sentence from FN corpus XML
# as a RegXML object,
# offer printout in tabular format
class FNCorpusXMLSentence

  #########
  def initialize(sent_string)
    @sent = RegXML.new(sent_string)
    @sent_id = @sent.attributes()["ID"]
  end

  ##############
  # print to file
  # in tabular format
  #
  # row format:
  # word (pt gf role target frame stuff)* ne sent_id
  #
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
  def print_conll_style(file = $stdout)
    pos_text, charidx = read_sentence()
    asets = read_annotation_sets(charidx)

    # aset -> are we inside the target or not?
    in_target = Hash.new(false)
    # aset -> are we in all sorts of other annotations, like Support?
    in_stuff = Hash.new()
    # are we inside a named entity?
    in_ne = nil

    # record every opening and closing label we recognize,
    # to check later
    recognized_labels = Hash.new()

    pos_text.each_index {|i|
      line = Array.new
      word = pos_text[i]

      # add: word
      line << word

      start, stop = charidx[i]

      # iterate over the frames we have
      # add: (pt gf role target frame stuff)
      asets.each { |aset|
        unless aset.aset_type == "frame"
          # don't treat NEs as a frame here
          next
        end

        # pt, gf, role
        ["PT", "GF", "FE"].each { |layer|
          token = Array.new
          hash = aset.layers[layer]
          if hash.has_key?([start,"start"])
            recognized_labels[[layer, start, "start"]] = true

            markables = hash[[start,"start"]]
            markables.each {|element|
              token << "B-"+element
            }
          end
          if hash.has_key?([stop,"stop"])
            recognized_labels[[layer, stop, "stop"]] = true

            markables = hash[[stop,"stop"]]
            markables.each {|element|
              token << "E-"+element
            }
          end

          if token.empty?
            line <<  "-"
          else
            line <<  token.sort.join(":")
          end
        }

        # target
        target = aset.layers["Target"]
        if target.has_key?([start,"start"])
          recognized_labels[["Target", start, "start"]] = true
          in_target[aset] = true
        end
        if in_target[aset]
          line << aset.lu
        else
          line << "-"
        end
        if target.has_key?([stop,"stop"])
          recognized_labels[["Target", stop, "stop"]] = true
          in_target[aset] = false
        end

        # frame
        line << aset.frame_name

        # stuff
        unless in_stuff.has_key?(aset)
          in_stuff[aset] = Array.new()
        end
        aset.layers.each_key { |layer|
          if ["PT", "GF", "FE", "Target"].include? layer
            # already done those
            next
          end
          # all the rest goes in "stuff"
          if aset.layers[layer].has_key?([start, "start"])
            aset.layers[layer][[start, "start"]].each { |entry|
              in_stuff[aset] << layer + "-" + entry
            }
            recognized_labels[[layer, start, "start"]] = true
          end
        }
        if in_stuff[aset].empty?
          line << "-"
        else
          line << in_stuff[aset].join(":")
        end
        aset.layers.each_key { |layer|
          if aset.layers[layer].has_key?([stop, "stop"])
            recognized_labels[[layer, stop, "stop"]] = true
            aset.layers[layer][[stop, "stop"]].each { |entry|
              in_stuff[aset].delete(layer + "-" + entry)
            }
          end
        }
      }

      # ne
      if (ner = asets.detect { |a| a.aset_type == "NER" })
        if ner.layers["NER"] and ner.layers["NER"].has_key?([start, "start"])
          recognized_labels[["NER", start, "start"]] = true
          in_ne = ner.layers["NER"][[start,"start"]]
        end
        if in_ne
          line << in_ne.join(":")
        else
          line << "-"
        end
        if ner.layers["NER"] and ner.layers["NER"].has_key?([stop, "stop"])
          recognized_labels[["NER", stop, "stop"]] = true
          in_ne = nil
        end
      end

      # sent id
      line << @sent_id

      # sanity check:
      # row format:
      # word (pt gf role target frame stuff)* ne sent_id
      # so number of columns must be 3 + 6x for some x >= 0
      unless (line.length() - 3)%6 == 0
        $stderr.puts "Something wrong with the line length."
        $stderr.puts "I have #{asets.length() - 1} frames plus NEs, "
        $stderr.puts "but #{line.length()} columns."
        raise
      end


      file.puts line.join("\t")
    }

    # sanity check:
    # now count all labels,
    # to see if we've printed them all
    lost_labels = Array.new()
    asets.each { |aset|
      aset.layers.each_key { |layer|
        aset.layers[layer].each_key() { |offset, start_or_stop|
          unless recognized_labels[[layer, offset, start_or_stop]]
            lost_labels << [layer, offset, start_or_stop,
                            aset.layers[layer][[offset, start_or_stop]]]
          end
        }
      }
    }
    unless lost_labels.empty?
      $stderr.puts "Offsets: "
      pos_text.each_index { |i|
        $stderr.puts "\t#{pos_text[i]} #{charidx[i][0]} #{charidx[i][1]}"
      }
      #       $stderr.puts "Recognized:"
      #       recognized_labels.each_key { |k|
      #         $stderr.puts "\t" + k.to_s()
      #       }
      lost_labels.each { |layer, offset, start_or_stop, labels|
        $stderr.puts "FNCorpusXML warning: lost label"
        $stderr.puts "\tLayer #{layer}"
        $stderr.puts "\tOffset #{offset}"
        $stderr.puts "\tStatus #{start_or_stop}"
        $stderr.puts "\tLabels #{labels.join(" ")}"
      }
    end

    file.puts
  end

  ################
  private

  ###
  # read annotation sets:
  # parse the annotation sets in the @sent object,
  # return as:
  # array of FNCorpusAset objects
  def read_annotation_sets(charidx)
    unless (annotation_sets = @sent.first_child_matching("annotationSets"))
      return
    end

    # return values
    frames = Array.new()

    annotation_sets.each_child_matching("annotationSet") { |aset|
      frames << FNCorpusAset.new(aset, charidx)
    }

    return frames
  end

  ###
  # basically taken over from FrameXML.rb
  # read sentence words,
  # return as: sentence, indices
  # - sentence as array of strings, one word per string
  # - indices: array of pairs [word start char.index, word end char.index] int*int
  def read_sentence()
    # all text and pos_text have the same number of elements!
    charidx = Array.new # maps word indices on [start,stop]
    pos_text = []

    unless (text_elt = @sent.first_child_matching("text"))
      # no text found for this sentence
      return [pos_text, charidx]
    end

    orig_text = text_elt.children_and_text().detect { |child|
      child.text?
    }
    if orig_text
      # take text out of RegXMl object
      orig_text = orig_text.to_s()
    end

    pos_text = UtfIso.to_iso_8859_1(orig_text).split(" ") # text with special char.s replaced by iso8859 char.s

    double_space = Array.new
    pos = 0
    while (match = orig_text.index(/(\s\s+)/,pos))
      double_space << match
      pos = match+1
    end

    # fill charidx array
    char_i = 0
    pos_text.each_index {|word_i|
      startchar = char_i
      #      puts "Remembering "+char_i.to_s+" as start index of word "+word_i.to_s
      char_i += our_length(pos_text[word_i])
      stopchar = char_i-1

      #      puts "Remembering "+(char_i-1).to_s+" as stop index of word "+word_i.to_s

      charidx << [startchar,stopchar]

      # separators
      if double_space.include?(char_i) then
        char_i += 2
      else
        char_i += 1
      end
    }

    return [pos_text, charidx]
  end

  ###
  def our_length(string)   # (1) replace &...; with 1 char and " with two chars
    return string.gsub(/&(.+?);/,"X").length
  end

end
