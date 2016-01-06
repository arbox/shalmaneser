require_relative 'fn_corpus_aset'
require 'frappe/utf_iso'
require 'salsa_tiger_xml/reg_xml'

#######################################
# Keep one sentence from FN corpus XML
# as a RegXML object,
# offer printout in tabular format
class FNCorpusXMLSentence

  #########
  def initialize(sent_string)
    @sent = STXML::RegXML.new(sent_string)
    @sent_id = @sent.attributes["ID"]
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
    pos_text, charidx = read_sentence
    asets = read_annotation_sets(charidx)

    # aset -> are we inside the target or not?
    in_target = Hash.new(false)
    # aset -> are we in all sorts of other annotations, like Support?
    in_stuff = {}
    # are we inside a named entity?
    in_ne = nil

    # record every opening and closing label we recognize,
    # to check later
    recognized_labels = {}

    pos_text.each_index {|i|
      line = []
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
          token = []
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
          in_stuff[aset] = []
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
      unless (line.length - 3)%6 == 0
        $stderr.puts "Something wrong with the line length."
        $stderr.puts "I have #{asets.length - 1} frames plus NEs, "
        $stderr.puts "but #{line.length} columns."
        raise
      end


      file.puts line.join("\t")
    }

    # sanity check:
    # now count all labels,
    # to see if we've printed them all
    lost_labels = []
    asets.each { |aset|
      aset.layers.each_key { |layer|
        aset.layers[layer].each_key { |offset, start_or_stop|
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
      #         $stderr.puts "\t" + k.to_s
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
    frames = []

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
  def read_sentence
    # all text and pos_text have the same number of elements!
    charidx = [] # maps word indices on [start,stop]
    pos_text = []

    unless (text_elt = @sent.first_child_matching("text"))
      # no text found for this sentence
      return [pos_text, charidx]
    end

    orig_text = text_elt.children_and_text.detect { |child|
      child.text?
    }
    if orig_text
      # take text out of RegXMl object
      orig_text = orig_text.to_s
    end

    pos_text = ::Shalmaneser::Frappe::UtfIso.to_iso_8859_1(orig_text).split(" ") # text with special char.s replaced by iso8859 char.s

    double_space = []
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
