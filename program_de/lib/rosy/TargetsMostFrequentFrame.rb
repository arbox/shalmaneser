module TargetsMostFrequentSc
  def determine_target_most_frequent_sc(view, 
                                        noval, 
                                        with_frame_default = nil)
    target_subcat = Hash.new()
    frame_subcat = Hash.new()

    view.each_sentence { |sentence|

      target = tmf_target_key(sentence.first)
      frame = sentence.first["frame"]
      subcat = []
      # each instance: count individual Gf
      # add to sentencewide string
      sentence.each { |inst|
        if inst["fn_gf"] != noval and inst["fn_gf"] != "target"
          subcat << inst["fn_gf"]
        end
      } # each instance of sentence

      subcat.sort!
      subcat.uniq!

      # count sentwise GF for target
      if target_subcat[target].nil?
        target_subcat[target] = Hash.new(0)
      end
      target_subcat[target][subcat.join("_")] += 1

      # count same for frame
      if frame_subcat[frame].nil?
        frame_subcat[frame] = Hash.new(0)
      end
      frame_subcat[frame][subcat.join("_")] += 1
    } # each sentence of view

    # most frequent subcat for each target:
    retv = Hash.new()
    retv2 = Hash.new()
    [[retv, target_subcat], [retv2, frame_subcat]].each { |out_hash, in_hash|

      in_hash.each_pair { |key, subcats|
        most_frequent_subcat = subcats.to_a.max { |a,b| a.last <=> b.last }.first
        out_hash[key] = most_frequent_subcat
      }
    }

    if with_frame_default
      return [retv, retv2]
    else
      return retv
    end
  end

  def tmf_target_key(instance)
    return instance["frame"] + "." + 
           instance["target"] + "." + 
           instance["target_pos"] 
  end
end
