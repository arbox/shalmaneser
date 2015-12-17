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

    @layers = {}
    @frame_name = nil
    @lu = nil
    @aset_type = nil

    attributes = aset.attributes

    @aset_id = attributes["ID"]

    if attributes["frameName"]
      # all of these seem to be frames. store in 'frames' array
      unless attributes["luName"]
        $stderr.puts "FNCorpusAset warning: cannot determine LU name"
        $stder.puts aset.to_s
        return
      end
      @aset_type = "frame"
      @frame_name = attributes["frameName"]
      @lu = attributes["luName"]

      unless (layers = aset.first_child_matching("layers"))
        $stderr.puts "FNCorpusAset warning: unexpectedly no layers found"
        $stderr.puts aset.to_s
        return
      end

      layers.each_child_matching("layer") { |l| analyze_layer(l, charidx) }

    else
      # all we seem to get here are named entity labels.
      @aset_type = "NER"

      unless (layers = aset.first_child_matching("layers"))
        $stderr.puts "FNCorpusAset Warning: unexpectedly no layers found"
        $stderr.puts aset.to_s
        return
      end
      unless (layer = layers.first_child_matching("layer"))
        $stderr.puts "FNCorpusAset Warning: unexpectedly no layers found"
        $stderr.puts aset.to_s
        return
      end

      unless layer.attributes["name"] == "NER"
        $stderr.puts "FNCorpusAset Warning: unexpected layer #{layer.attributes["name"]}, was expecting only an NER layer."
        $stderr.puts aset.to_s
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
    layer_name = layer.attributes["name"]
    unless layer_name
      $stderr.puts "FNCorpusAset warning: cannot determine layer name"
      $stderr.puts layer.to_s
      return
    end

    # FN-specific: skip 2nd layer FEs for now
    if layer_name == "FE" and layer.attributes["rank"] == "2"
      return
    end

    unless @layers[layer_name]
      @layers[layer_name] = {}
    end

    unless (labels = layer.first_child_matching("labels"))
      # nothing to record for this layer
      return
    end


    # taking over much of analyse_layer from class FrameXML
    thisLayer = []

    labels.each_child_matching("label") { |label|
      attributes = label.attributes
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

    deleteHash = {} # keep track of the labels which are to be deleted
    # i -> Boolean

    thisLayer.each_index {|i|
      # efficiency: skip already delete labels
      if deleteHash[i]
        next
      end
      this_label, this_from , this_to = thisLayer[i]

      # compare with all remaining labels
      (i+1..thisLayer.length-1).to_a.each { |other_i|
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
            @layers[layer_name][[offset, start_or_stop]] = []
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
