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

require 'frappe/Ampersand'
require 'frappe/utf_iso'
require 'common/salsa_tiger_xml/reg_xml'

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
    while (line = file.gets())
      string << line
    end
    @lexunit = RegXML.new(string)
    attributes = @lexunit.attributes()
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
    @lexunit.children_and_text().each { |subcorpus|
      subcorpus.children_and_text().each { |annotationSet|
        if annotationSet.name == "annotationSet"
          # sentence found
          yield FrameXMLSentence.new(annotationSet,self)
        end
      }
    }
  end
end

class FrameXMLSentence
  def initialize(annotationSet,file_obj)
    @file_obj = file_obj

    # layers: hash layer_name -> array:[name, start, stop]
    #  name: name of the element, string
    #  start: start character, integer
    #  stop:  end character, integer
    @layers = Hash.new

    annotationSet.children_and_text().each { |sentence_or_layer_elt|

      case sentence_or_layer_elt.name
      when "sentence"
        # sentence: has ID, its child is <text>[text]</text>
        @sent_id = sentence_or_layer_elt.attributes["ID"]
        text_elt = sentence_or_layer_elt.children_and_text().detect { |child|
          child.name == "text"
        }
        if text_elt
          # found the text element. its only child should be the text
          @orig_text = text_elt.children_and_text().detect { |child|
            child.text?
          }
          if @orig_text
            # take text out of RegXMl object
            @orig_text = @orig_text.to_s()
          end
        end

      when "layers"
        # contains annotation layers
        sentence_or_layer_elt.children_and_text().each { |layer|
          unless layer.name == "layer"
            # additional material, ignore
            next
          end

          name = layer.attributes["name"]
          unless name
            raise "layer without a name"
          end
          unless @layers.key?(name)
            @layers[name] = analyse_layer(layer, name)
          end
        }
      end
    }

    @pos_text = UtfIso.to_iso_8859_1(@orig_text).split(" ") # text with special characters replaced by iso8859 characters
    @text = Ampersand.utf8_to_hex(@orig_text).split(" ")  # text with special characters replaced by &...; sequences

    # all text and pos_text have the same number of elements!
    @start_is = Hash.new # map char indices (start of words) onto word indices
    @stop_is = Hash.new   # map char indices (end of words) onto word indices
    @charidx = Array.new # maps word indices on [start,stop]

    @double_space = Array.new
    pos = 0
    while (match = @orig_text.index(/(\s\s+)/,pos))
      @double_space << match
      pos = match+1
    end


    # fill start, stop and charidx arrays
    char_i = 0
    @pos_text.each_index {|word_i|
      @start_is[char_i] = word_i
      startchar = char_i
      #      puts "Remembering "+char_i.to_s+" as start index of word "+word_i.to_s
      char_i += our_length(@pos_text[word_i])
      @stop_is[char_i-1] = word_i

      stopchar = char_i-1

      #      puts "Remembering "+(char_i-1).to_s+" as stop index of word "+word_i.to_s

      @charidx << [startchar,stopchar]

      # separators
      if @double_space.include?(char_i) then
        char_i += 2
      else
        char_i += 1
      end
    }
  end

  def get_file_obj
    return @file_obj
  end

  def get_sent_id
    return @sent_id
  end

  def print_text
    puts "("+@id+ ")\t"+@text
  end

  def contains_FE_annotation_and_target
    target_info = @layers["Target"][0]
    unless target_info[0] == "Target"
      STDERR.puts "Error in sentence from "+filename+": No target" # strictly speaking, no target at pos 0 in @layers["Target"]
      STDERR.puts "Sentence: "+@text
      return false
    else
      return (@layers.key?("FE") and target_info[2] != 0)
    end
  end

  # we only verify the interesting layers (FE,GF,Target)
  # if there is weird stuff going on on e.g. the Noun or Adj layer, we don't care.

  def verify_annotation # returns true if some change has taken place
    change = false
    @layers.each_pair {|layername,l|

      if layername=="FE" or layername=="GF" or layername=="PT" or layername=="Target" # only verify the "important" layers

        l.each_index {|i|

          element,start,stop = l[i]

          newstart = start
          newstop = stop

          @charidx.each_index{|j|
            unless j== 0
              pstartidx, pstopidx = @charidx[j-1]
            end
            startidx, stopidx = @charidx[j]

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
          if start != newstart or stop != newstop
            change = true
            @layers[layername][i] = [element,newstart,newstop]
            STDERR.puts "Heuristics has changed element "+element+" from ["+[start,stop].join(",")+"] to ["+[newstart,newstop].join(",")+"] in file "+@file_obj.get_filename+"."
            markable_as_string(layername,element).each {|string|
              STDERR.puts "New markable: "+string
            }
            STDERR.puts "Sentence: "+@pos_text.join(" ")
            puts
          end
        }
      end
    }
    return change
  end

  def print_conll_style
    print_conll_style_to(STDOUT)
  end

  # CHANGED KE January 2007:
  # write new adapted FNTab format
  # ( "word", ("pt", "gf", "role", "target", "frame", "stuff")* "ne", "sent_id" )
  def print_conll_style_to(out)

    # even though in principle there might be multiple
    # labels for one span [i.e. in one value of the
    # {gf,fe,pt} hashes], we only ever record one

    gf = Hash.new
    add_all_to_hash(gf,"GF")
    fe = Hash.new
    add_all_to_hash(fe,"FE")
    pt = Hash.new
    add_all_to_hash(pt,"PT")
    target = Hash.new
    add_all_to_hash(target,"Target")

    in_target = false

    @pos_text.each_index {|i|
      # write format:
      #  "word" "pt", "gf", "role", "target", "frame", "stuff" "ne", "sent_id"
      line = Array.new
      # word
      word = @pos_text[i]
      line << word

      start, stop = @charidx[i]
      # "pt", "gf", "role",
      [pt,gf,fe].each {|hash|
        token = Array.new
        if hash.key?([start,"start"])
          markables = hash.delete([start,"start"])
          markables.each {|element|
            token << "B-"+element
          }
        end
        if hash.key?([stop,"stop"])
          markables = hash.delete([stop,"stop"])
          markables.each {|element|
            token << "E-"+element
          }
        end
        if token.empty?
          line << "-"
        else
          line << token.sort.join(":")
        end
      }
      # "target"
      if target.key?([start,"start"])
        target.delete([start,"start"])
        in_target = true
      end
      if in_target
        line << @file_obj.get_lu+"."+@file_obj.get_pos
      else
        line << "-"
      end
      if target.key?([stop,"stop"])
        target.delete([stop,"stop"])
        in_target = false
      end
      # "frame"
      line << @file_obj.get_frame

      # "stuff" "ne",
      line << "-"
      line << "-"

      # "sent_id"
      line << @file_obj.get_lu_id+"-"+@sent_id

      out.puts line.join("\t")
    }

    out.puts

    [gf,fe,pt,target].each {|hash|
      unless hash.empty?
        STDERR.puts @file_obj.get_filename
        raise "**** Error: Hash not empty after creation of Sentence in CoNLL-Format (could not find matching words for some markup element)!"
      end
    }
  end


  def print_layers
    @layers.each {|ln,l|
      puts "Layer "+ln+":"
      l.each {|element,start,stop|
        puts "\t"+element+": "+start.to_s+" -- "+stop.to_s
      }
      puts "***"
    }
  end


  private


  def our_length(string)   # (1) replace &...; with 1 char and " with two chars
    return string.gsub(/&(.+?);/,"X").length
  end

  def is_fe(fename)
    @layers["FE"].each {|name,start,stop|
      if fename == name
        return true
      end
    }
    return false
  end


  def markable_as_string(layername,markup_name) # returns an array of all markables with this name

    result = Array.new

    festart = nil
    festop = nil
    @layers[layername].each {|name,start,stop|
      if markup_name == name
        fe = Array.new
        infe = false
        @charidx.each_index {|i|
          startidx,stopidx = @charidx[i]
          if startidx == start
            infe = true
          end
          if infe
            fe << @pos_text[i]
          end
          if stopidx == stop
            result << (fe.join(" ")+"["+start.to_s+","+stop.to_s+", VERIFIED]")
            break
          elsif stopidx > stop
            result <<  (fe.join(" ")+"["+start.to_s+","+stop.to_s+",ERROR]")
            break
          end
        }
      end
    }
    return result
  end

  def add_to_hash(hash,key,name)
    exists = false
    if hash.key?(key)
      exists = true
    else
      hash[key] = Array.new
      hash[key] << name
    end
    return exists
  end

  def add_all_to_hash(hash,layername)
    # use "uniq" to remove wrong double annotations
    @layers[layername].uniq.each {|element,start,stop|
      exists = add_to_hash(hash,[start, "start"],element)
      if exists
        STDERR.puts "Warning ["+@file_obj.get_filename+"]: In layer "+layername+", two elements start at position "+start.to_s+". Only using first. Layer as read from FrameXML: "+@layers[layername].map {|element,start,stop| element+" ("+start.to_s+","+stop.to_s+")"}.join(" ")
      else
        add_to_hash(hash,[stop, "stop"],element)
      end
    }
  end


  def analyse_layer(layer_elt,name) # read layer information from file and store in @layers
    if name.nil?
      STDERR.puts "Error: layer line "+line+" with empty name."
    end

    # thisLayer, retv: array:[name(string), start(integer), end(integer)]
    thisLayer = Array.new
    retv = Array.new

    labels_elt = layer_elt.children_and_text.detect { |child| child.name == "labels"}
    unless labels_elt
      # no labels found, return empty array
      return thisLayer
    end

    labels_elt.children_and_text.each { |label|
      unless label.name == "label"
        # some other markup, ignore
        next
      end

      attributes = label.attributes()
      if attributes["itype"]
        # null instantiation, don't retain
        next
      end
      if not(attributes["start"]) and not(attributes["end"])
        # no start and end labels
        next
      end
      thisLayer << [attributes["name"], attributes["start"].to_i, attributes["end"].to_i]
    }

    # sanity check: verify that
    # 1. we don't have overlapping labels

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
          deleteHash[i] = true
        end
      }
      # matched with all other labels. If "keep", return

      if deleteHash[i]
      #       $stderr.puts " deleting entry #{i}"
      else
        retv << thisLayer[i]
      end
    }

    return retv
  end
end
