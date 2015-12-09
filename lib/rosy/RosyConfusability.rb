# RosyConfusability
# KE May 05
#
# Access instance database created by the Rosy role assignment system
# and compute the confusability of target categories
# for the data in the (training) database there.
#
# We define confusability as follows:
# Given a frame fr, let
# - fes(fr) the FEs of fr (a set)
# - gfs(fe) the grammatical functions realizing the FE fe in the data
# - gfs(fr) = U_{fe \in fes(fr)} gfs(fe) the grammatical functions realizing roles of fr
#
# Then the entropy of a grammatical function gf within fr is
#
# gfe_{fr}(gf) = \sum_{fe \in fes(fr)} -p(fe|gf) log p(fe|gf)
#
# where p(fe|gf) = f(gf, fe) / f(gf)
#
# And the confusability of a frame element fe of fr is
#
# c_{fr}(fe) = \sum_{gf \in gfs(fr)} p(gf|fe) gfe_{fr}(gf)
#
# where p(gf|fe) = f(gf, fe) / f(fe)

# @todo This require statement is wrong. This file is not read in.
require "RosyConfigData"
require "RosyIterator"
require "RosyConventions"
require "TargetsMostFrequentFrame"

require "mysql"

class RosyConfusability
  include TargetsMostFrequentSc

  attr_reader :confusability, :counts_fe_glob, :frame_confusability, :overall_confusability

  def initialize(exp) # RosyConfigData object
    @exp = exp

    @confusability = Hash.new(0.0)
    @counts_fe_glob = Hash.new(0)
    @counts_gffe_glob = Hash.new(0)
    @frame_confusability = Hash.new(0.0)
    @overall_confusability = 0.0

    @frequent_gframes = [
      # NO DUPLICATES
      "Ext_Comp", "Mod", "Comp", "Gen",
      "Ext_Obj", "Ext", "Ext_Obj_Comp", "Head",
      "Ext_Mod", "Gen_Mod", "Mod_Comp", "Comp_Ext",
      "Gen_Comp", "Ext_Gen", "Ext_Mod_Comp", "Head_Comp",
      "Obj_Comp", "Obj", "Mod_Head", "Ext_Comp_Obj",
      "Gen_Head", "Ext_Gen_Mod"
      # with duplicates
#       "Ext_Comp", "Mod", "Comp", "Gen",
#       "Ext_Obj", "Ext", "", "Ext_Obj_Comp",
#       "Ext_Comp_Comp", "Head", "Mod_Mod", "Gen_Mod",
#       "Ext_Mod", "Comp_Comp", "Mod_Comp", "Ext_Gen",
#       "Gen_Comp", "Head_Head", "Ext_Comp_Comp_Comp", "Head_Comp",
# # "Ext_Ext_Comp",
# #       "Ext_Obj_Comp_Comp", "Obj_Comp",
# #       "Ext_Mod_Mod", "Comp_Comp_Comp",
# #       "Ext_Ext_Obj", "Ext_Mod_Comp", "Comp_Ext", "Obj",
# #       "Ext_Ext", "Ext_Obj_Obj", "Mod_Mod_Mod", "Gen_Mod_Mod",
# #       "Ext_Comp_Comp_Comp_Comp", "Gen_Head", "Mod_Head",
# #       "Ext_Ext_Ext_Comp"
    ].map { |string|
      string.split("_")
    }
  end

  def compute(splitID,     # string: split ID, may be nil
              additionals) # array:string: "target", "target_pos", "gframe", "fgframe"
    ###
    # open and initialize stuff:

    # open database
    database = Mysql.real_connect(@exp.get('host'), @exp.get('user'),
                                  @exp.get('passwd'), @exp.get('dbname'))
    # make an object that creates views.
    # read one frame at a time.
    iterator = RosyIterator.new(database, @exp, "train",
                                "splitID" => splitID,
                                "xwise" => "frame")
    # get value for "no val"
    noval = @exp.get("noval")

    counts_frame = Hash.new(0)

    # iterate through all frames and compute confusability of each FE
    iterator.each_group { |group_descr_hash, frame|

      $stderr.puts "Computing confusability for #{frame}"

      # read all instances of the frame, columns: FE and GF
      view = iterator.get_a_view_for_current_group(["sentid","gold", "fn_gf",
                                                    "target","target_pos", "frame"])

      if additionals.include? "tmfframe"
        # find most frequent gframe for each target
        tmfframe = determine_target_most_frequent_sc(view, noval)
      end

      # count occurrences
      counts_gf = Hash.new(0)
      counts_fe = Hash.new(0)
      counts_gffe = Hash.new(0)

      view.each_sentence { |sentence|

        # make string consisting of all FN GFs of this sentence
        allgfs = Array.new()
        sentence.each { |inst|
          if inst["fn_gf"] != noval
            allgfs << inst["fn_gf"]
          end
        }

        # assume uniqueness of GFs
        # design decision, could also be done differently.
        # rationale: if a GF occurs more than once,
        # it's probable that this is because we get more than
        # one constituent for this GF, not because
        # it actually occurred more than once in the
        # original FrameNet annotation.
        allgfs.uniq!

        # now count each instance
        sentence.each { |row|
          if row["gold"] == "target"
            # don't count target among the FEs
            next
          end

          if row["gold"] != noval
            counts_fe[row["gold"]] += 1
          end
          if row["fn_gf"] != noval and row["fn_gf"] != "target"
            gf = row["fn_gf"]

            additionals.each { |additional|
              case additional
              when "target"
                gf << "_" + row["target"]
              when "target_pos"
                gf << "_" + row["target_pos"]
              when "gframe"
                gf << "_" + allgfs.join("_")

              when "fgframe"
                # find the maximal frequent frame subsuming allgfs
                maxfgf = nil
                @frequent_gframes.each { |fgframe|
                  if fgframe.subsumed_by?(allgfs)
                    # fgframe is a subset of allgfs
                    if maxfgf.nil? or fgframe.length() > maxfgf.length()
                      maxfgf = fgframe
                    end
                  end
                }
                if maxfgf.nil?
                  # nothing there that fits
                  # leave GF as is
                else
                  gf << "_" + maxfgf.join("_")
                end

              when "tmfframe"
                gf << "_" + tmfframe[tmf_target_key(row)]

              else
                raise "Don't know how to compute #{additional}"
              end
            }

            counts_gf[gf] += 1
          end

          if row["gold"] != noval and gf
            counts_gffe[gf + " " + row["gold"]] += 1
          end
        } # each row of sentence
      } # each sentence of view

      # compute gf entropy
      # gfe_{fr}(gf) = \sum_{fe \in fes(fr)} -p(fe|gf) log_2 p(fe|gf)
      #
      # where p(fe|gf) = f(gf, fe) / f(gf)
      gf_entropy = Hash.new

      counts_gf.keys.each { |gf|
        gf_entropy[gf] = 0.0

        counts_fe.keys.each { |fe|
          if counts_gf[gf] > 0
            p_gf_fe = counts_gffe[gf + " " + fe].to_f / counts_gf[gf].to_f

            # get log_2 via log_10
            if p_gf_fe > 0.0
              gf_entropy[gf] -= p_gf_fe * Math.log10(p_gf_fe) * 3.32193
            end
          end
        } # each FE for this GF
      } # each GF (gf entropy)

      # compute FE confusability
      # c_{fr}(fe) = \sum_{gf \in gfs(fr)} p(gf|fe) gfe_{fr}(gf)
      #
      # where p(gf|fe) = f(gf, fe) / f(fe)
      counts_fe.keys.each { |fe|
        @confusability[frame + " " + fe] = 0.0

        counts_gf.keys.each { |gf|
          if counts_fe[fe] > 0
            p_fe_gf = counts_gffe[gf + " " + fe].to_f / counts_fe[fe].to_f

            @confusability[frame + " " + fe] += p_fe_gf * gf_entropy[gf]
          end
        } # each GF for this FE
      } # each FE (fe confusability)


      # remember counts for FEs and GF/FE pairs
      counts_fe.keys.each { |fe|
        @counts_fe_glob[frame + " " + fe] = counts_fe[fe]
      }
      counts_gffe.each_pair {|event,freq|
        @counts_gffe_glob[frame+" " +event] = freq
      }

      # omit rare FEs:
      # anything below 5 occurrences
      counts_fe.each_key {  |fe|
        if counts_fe[fe] < 5
          @confusability.delete(frame + " " + fe)
        end
      }

      # compute overall frame confusability
      # omitting rare FEs with below 5 occurrences:
      #
      # c(fr) = sum_{fe \in fes(fr)} f(fe)/f(fr) * c_{fr}(fe)
      #       = \sum_{gf \in gfs(fr)} p(gf|fr) gfe_{fr}(gf)
      #
      # where p(gf|fr) = (sum_{fe\in fes(fr)} f(gf, fe)) / f(fr)
      counts_frame[frame] = 0
      counts_fe.each_value { |count|
        if count >= 5
          counts_frame[frame] += count
        end
      }
      @frame_confusability[frame] = 0.0
      counts_fe.each_pair { |fe, count|
        if count >= 5
          @frame_confusability[frame] += (count.to_f / counts_frame[frame].to_f) * @confusability[frame + " " + fe]
        end
      }
    } # each frame

    # compute overall confusability
    # c = \sum{fr \in frames} f(fr)/N * c(fr)
    #
    # where N is the number of FE occurrences overall
    counts_overall = 0
    counts_frame.each_value { |count|
      counts_overall += count
    }
    @overall_confusability = 0.0
    counts_frame.each_pair { |frame, count|
      @overall_confusability += (count.to_f / counts_overall.to_f) * @frame_confusability[frame]
    }
  end


  # return a copy of @counts_fe_glob, from which all fes with less than 5 occurrences are deleted
  def get_global_counts
    global_counts = @counts_fe_glob.clone
    global_counts.delete_if {|key, value| value < 5}
    return global_counts
  end

  ###
  #
  # compute sparseness statistics over the set of
  # base events used for computing the confusability
  # returns an array of length 4:
  # - number of events with freq 1
  # - number of events with freq 2
  # - number of events with freq 3-5
  # - number of events with freq > 5

  def counts()
    counts = [0,0,0,0]
    @counts_gffe_glob.each_value {|freq|
      case freq
      when 1
        counts[0] += 1
      when 2
        counts[1] += 1
      when 3..5
        counts[2] += 1
      else
        counts[3] += 1
      end
    }
    return counts
  end

  def to_file(filename)
    begin
      file = File.new(filename,"w")
    rescue
      raise "Couldn't open file #{filename} for writing."
    end
    Marshal.dump({"confusability" => @confusability,
                  "counts_fe_glob" => @counts_fe_glob,
                  "counts_gffe_glob" => @counts_gffe_glob,
                  "frame_confusability" => @frame_confusability,
                  "overall_confusability" => @overall_confusability
                 },
                 file)
  end

  def from_file(filename)
    begin
      file = File.new(filename)
    rescue
      raise "Couldn't open file #{filename} for reading."
    end
    hash = Marshal.load(file)
    @confusability = hash["confusability"]
    @counts_fe_glob = hash["counts_fe_glob"]
    @counts_gffe_glob = hash["counts_gffe_glob"]
    @frame_confusability = hash["frame_confusability"]
    @overall_confusability =  hash["overall_confusability"]
  end
end
