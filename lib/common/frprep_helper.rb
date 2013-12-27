# Salsa packages
require "common/ISO-8859-1"
require "common/Parser"
require "common/RegXML"
require "common/SalsaTigerRegXML"
require "common/SalsaTigerXMLHelper"
require "common/TabFormat"
require "common/ruby_class_extensions"
require "common/AbstractSynInterface"

############################################3
# Module FrprepHelper:
#
# diverse transformation methods for frprep.rb
# moved over here to make the main file less crowded
module FrprepHelper
  
  ####
  # transform a file to UTF-8 from a given encoding
  def FrprepHelper.to_utf8_file(input_filename, # string: name of input file
                           output_filename, # string: name of output file
                           encoding) # string: "iso", "hex"
    begin
      infile = File.new(input_filename)
      outfile = File.new(output_filename, "w")
    rescue
      raise "Could not read #{input_filename}, or could not write to #{output_filename}."
    end

    while (line = infile.gets())
      case encoding
      when "iso"
        outfile.puts UtfIso.from_iso_8859_1(line)
      when "hex"
        outfile.puts UtfIso.from_iso_8859_1(Ampersand.hex_to_iso(line))
      else
        raise "Shouldn't be here."
      end
    end 
    infile.close()
    outfile.close()
  end

  ####
  # transform BNC format file to plaintext file
  def FrprepHelper.bnc_to_plain_file(input_filename, # string: name of input file
                                     output_filename) # string: name of output file
    begin
      infile = File.new(input_filename)
      outfile = File.new(output_filename, "w")
    rescue
      raise "Could not read #{input_filename}, or could not write to #{output_filename}."
    end

    infile.each { |line|
    # does this line contain a sentence?
    if line =~ /^\s*<s\s+n=/
      # remove all tags, replace by spaces, 
      # then remove superfluous spaces
      textline = line.gsub(/<.+?>/, " ").strip().squeeze(" ")


      textline.gsub!(/&bquo;/, '"')
      textline.gsub!(/&equo;/, '"')
      textline.gsub!(/&mdash;/, "-")
      textline.gsub!(/&ndash;/, "-")
      textline.gsub!(/&percnt;/, "%")
      textline.gsub!(/&pound;/, " pounds ")
      textline.gsub!(/&amp;/, " and ")
      textline.gsub!(/&hellip;/, "...")
      textline.gsub!(/&copy;/, "(copyright)")
      textline.gsub!(/&eacute;/, "e")
      textline.gsub!(/&bull;/, "*")
      textline.gsub!(/&dollar;/, "$")
      textline.gsub!(/&deg;/, " degree ")

      textline.gsub!(/&frac12;/, "1/2")
      textline.gsub!(/&frac34;/, "3/4")

      textline.gsub!(/&lsqb;/, "[")
      textline.gsub!(/&rsqb;/, "]")

      textline.gsub!(/&ins;/, "i")
      textline.gsub!(/&ft;/, "ft")

      textline.gsub!(/&rarr;/, ">")
      textline.gsub!(/&larr;/, "<")


      textline.gsub!(/&aacute;/, "a")
      textline.gsub!(/&auml;/, "a")
      textline.gsub!(/&agrave;/, "a")
      textline.gsub!(/&atilde;/, "a")
      textline.gsub!(/&acirc;/, "a")
      textline.gsub!(/&Aacute;/, "A")
      textline.gsub!(/&Auml;/, "A")
      textline.gsub!(/&Agrave;/, "A")
      textline.gsub!(/&Atilde;/, "A")
      textline.gsub!(/&Acirc;/, "A")

      textline.gsub!(/&eacute;/, "e")
      textline.gsub!(/&egrave;/, "e")
      textline.gsub!(/&ecirc;/, "e")
      textline.gsub!(/&euml;/, "e")
      textline.gsub!(/&Eacute;/, "E")
      textline.gsub!(/&Egrave;/, "E")
      textline.gsub!(/&Ecirc;/, "E")
      textline.gsub!(/&Euml;/, "E")

      textline.gsub!(/&iacute;/, "i")
      textline.gsub!(/&igrave;/, "i")
      textline.gsub!(/&icirc;/, "i")
      textline.gsub!(/&iuml;/, "i")
      textline.gsub!(/&Iacute;/, "I")
      textline.gsub!(/&Igrave;/, "I")
      textline.gsub!(/&Icirc;/, "I")

      textline.gsub!(/&oacute;/, "o")
      textline.gsub!(/&ograve;/, "o")
      textline.gsub!(/&ocirc;/, "o")
      textline.gsub!(/&ouml;/, "o")
      textline.gsub!(/&Oacute;/, "O")
      textline.gsub!(/&Ograve;/, "O")
      textline.gsub!(/&Ocirc;/, "O")
      textline.gsub!(/&Ouml;/, "O")

      textline.gsub!(/&uacute;/, "u")
      textline.gsub!(/&ugrave;/, "u")
      textline.gsub!(/&ucirc;/, "u")
      textline.gsub!(/&uuml;/, "u")
      textline.gsub!(/&Uacute;/, "U")
      textline.gsub!(/&Ugrave;/, "U")
      textline.gsub!(/&Ucirc;/, "U")
      textline.gsub!(/&Uuml;/, "U")

      textline.gsub!(/&yuml;/, "y")
      textline.gsub!(/&Yuml;/, "Y")

      textline.gsub!(/&ntilde;/, "n")
      textline.gsub!(/&Ntilde;/, "N")

      textline.gsub!(/&ccedil;/, "c")
      textline.gsub!(/&Ccedil;/, "C")


      outfile.puts textline
    end
    }
    infile.close()
    outfile.close()
  end


  ####
  # transform plaintext file to Tab format file
  def FrprepHelper.plain_to_tab_file(input_filename,# string: name of input file
                                     output_filename)    # string: name of output file
    begin
      infile = File.new(input_filename)
      outfile = File.new(output_filename, "w")
    rescue
      raise "Could not read #{input_filename}, or could not write to #{output_filename}."
    end

    # AB: TODO This assumes all input files have the extension <txt>.
    # Is it good?
    filename_core = File.basename(input_filename, 'txt')

    # array(string): keep the words of each sentence
    sentence = []
    # sentence number for making the sentence ID:
    # global count, over all input files
    sentno = 0
    
    while line = infile.gets
      
      # make a sentence ID for the next sentence: running number
      sentid = "#{filename_core}_#{sentno}"
      sentno += 1
      
      # read words into the sentence array,
      # separating out punctuation attached to the beginning or end of words
      sentence.clear

      # AB: TODO Remove this naive tokenizer, better to have a fully
      # tokenized input using an external tokenizer than that.
      line.split.each { |word|
        # punctuation at the beginning of the word
        #if word =~ /^([\(\[`'\"-]+)(.*)$/
        if word =~ /^([\(\[`\"-]+)(.*)$/
        punct = $1
          word = $2
          punct.scan(/./) { |single_punct|
            sentence << single_punct
          }
   
        end
        # punctuation at the end of the word
        #if word =~ /[,:;-\`?!'\"\.\)\]]+$/
        if word =~ /[,:;-\`?!\"\.\)\]]+$/
          sentence << $`  # part before the match: the word
          punct = $&
          punct.scan(/./) { |single_punct|
            sentence << single_punct
          }
             
        else
          # no punctuation recognized
          sentence << word
        end
      }


      
      # remove empty words
      # AB: TODO Is it possible? Remove this.
      sentence.reject! { |word| word.nil? or word.strip.empty? }

      # write words to tab file
      # KE Dec 06: TabFormat changed
      sentence.each { |word|
        # for each word, one line, entries in the line tab-separated
        # the 'word' entry is the word, the 'lu_sent_ids' entry is the sentence ID sentid,
        # all other entries (gf, pt, frame etc.) are not set
	outfile.puts FNTabFormatFile.format_str({ 
						  "word" => word,
						  "sent_id" => sentid
						})
      }
      outfile.puts
    end
    outfile.close
  end

  ###########
  # 
  # class method split_dir: 
  # read all files in one directory and produce chunk files *#{suffix} in outdir
  # with a certain number of files in them (sent_num).
  # Optionally, remove all sentences longer than sent_leng
  #
  # produces output files 1.<suffix>, 2.<suffix>, etc.
  #
  # assumes TabFormat sentences
  #
  # example: split_all("/tmp/in","/tmp/out",".tab",2000,80)

  def FrprepHelper.split_dir(indir,
			     outdir,
			     suffix,
			     sent_num,
			     sent_leng=nil)

    unless indir[-1,1] == "/"
      indir += "/"
    end
    unless outdir[-1,1] == "/"
      outdir += "/"
    end

    outfile_counter = 0
    line_stack = Array.new
    sent_stack = Array.new
    
    Dir[indir+"*#{suffix}"].each {|infilename|
      STDERR.puts "Now splitting #{infilename}"
      infile = File.new(infilename)
      
      while line = infile.gets
        line.chomp!        
        case line
        when "" # end of sentence
          if !(sent_leng.nil? or line_stack.length < sent_leng) # record sentence
            # suppress multiple empty lines
            # to avoid problems with lemmatiser
            # only record sent_stack if it is not empty.

            # change (sp 15 01 07): just cut off sentence at sent_leng.            
            
            STDERR.puts "Cutting off long sentence #{line_stack.last.split("\t").last}" 
            line_stack = line_stack[0..sent_leng-1]
          end          
          unless line_stack.empty?
            sent_stack << line_stack
            # reset line_stack
            line_stack = Array.new
          end
	

          # check if we have to empty the sent stack
          if sent_stack.length == sent_num # enough sentences for new outfile? 
            outfile = File.new(outdir+outfile_counter.to_s+"#{suffix}","w")
            sent_stack.each {|l_stack|
              outfile.puts l_stack.join("\n")              
              outfile.puts              
            }
            outfile.close
            outfile_counter += 1
            sent_stack = Array.new
          end
        
        else # for any other line
	  line_stack << line
	end
      end
      infile.close
    }
    # the last remaining sentences
    unless sent_stack.empty?
      outfile = File.new(outdir+outfile_counter.to_s+"#{suffix}","w")
      sent_stack.each {|l_stack|
        l_stack << "\n"
        outfile.puts l_stack.join("\n")
      }
      outfile.close
    end
  end  

  ####
  # note salsa targetlemma
  #
  # old_dir contains xml files whose name starts with the
  # target lemma for all frames in the file
  # record that target lemma in the <target> element of each frame
  def FrprepHelper.note_salsa_targetlemma(old_dir, # string ending in /
					  new_dir) # string ending in /

    
    # each input file: extract target lemma from filename,
    # not this lemma in the <target> element of each frame
    Dir[old_dir + "*.xml"].each { |filename|
      changedfilename = new_dir + File.basename(filename)

      if File.basename(filename) =~ /^(.*?)[_\.]/
	lemma = $1
	  
	infile = FilePartsParser.new(filename)
	outfile = File.new(changedfilename, "w")

	# write header
	outfile.puts infile.head()

	# iterate through sentences, yield as SalsaTigerSentence objects
	infile.scan_s() { |sent_string|
	  sent = SalsaTigerSentence.new(sent_string)
	  sent.each_frame { |frame|
	    frame.target.set_attribute("lemma", lemma)
	  }

	  # write changed sentence
	  outfile.puts sent.get()
	} # each sentence
	
	# write footer
	outfile.puts infile.tail()
	infile.close()
	outfile.close()
      
      else
	# couldn't determine lemma
	# just copy the file
	`cp #{filename} #{changedfilename}`
      end
    }
  end

  ####
  # stxml_split_dir
  #
  # split SalsaTigerXML files into new files of given length,
  # skipping sentences that are too long
  #
  # At the same time, sentences that occur several times (i.e. sentences which are 
  # annotated by SALSA for more than one predicate) are compacted into one occurrence
  # with combined semantics.
  #
  # assumes that all files in input_dir with 
  # extension .xml are SalsaTigerXMl files
  def FrprepHelper.stxml_split_dir(input_dir, # string: input directory with STXML files
				   split_dir, # string: output directory
				   max_sentnum, # integer: max num of sentences per file
				   max_sentlen) # integer: max num of terminals per sentence
    
    filenames = Dir[input_dir+"*.xml"].to_a
    
    graph_hash = Hash.new # for each sentence id, keep <s...</graph>
    frame_hash = Hash.new # for each sentence id , keep the <frame...  </frame> string
    uspfes_hash = Hash.new # for each sentence id, keep the uspfes stuff
    uspframes_hash = Hash.new # for each sentence id, keep the uspframes stuff

    ########################
    # Traverse of file(s): compute an index of all frames for each sentence, with unique identifiers 
    
    filenames.each {|filename|
      
      infile = FilePartsParser.new(filename)      
      infile.scan_s {|sent_str|
        
        sentlen = 0
        sent_str.delete("\n").scan(/<t\s/) { |occ| sentlen += 1}
        if sentlen > max_sentlen
          sent = RegXML.new(sent_str)
          # revisit handling of long sentences
          # $stderr.puts "I would have skipped overly long sentence " + sent.attributes["id"]+" but Sebastian forbade me.".to_s          
          # next
        end

        # substitute old frame identifiers with new, unique ones
        
        # problem: we may have several frames per sentence, and need to keep track of them
        # if we rename etc sxx_f1 to sxx_f2 and there is already a sxx_f2, then
        # we cannot distinguish between these frames 
        
        # therefore, we substitute temporary identifiers until we have substituted 
        # all ids with temporary ones, and re-substitute final ones at the end.
        
        this_frames = Array.new
        
        temp_subs = Array.new
        final_subs = Array.new
        
        sent = RegXML.new(sent_str)
        sentid = sent.attributes["id"].to_s
        if sentid.nil?
          STDERR.puts "[frprep] Warning: cannot find sentence id, skipping sentence:"
          STDERR.puts sent_str
          # strange sentence, no ID? skip
          next
        end
        
        unless frame_hash.key? sentid
          frame_hash[sentid] = Array.new      
          uspfes_hash[sentid] = Array.new
          uspframes_hash[sentid] = Array.new
        end
        
        # find everything up to and including the graph
        sent_children = sent.children_and_text()
        graph = sent_children.detect { |child| child.name == "graph" }
        graph_hash[sentid] = "<s " + 
                               sent.attributes.to_a.map { |at, val| "#{at}=\'#{val}\'" }.join(" ") +
                               ">" + 
                               graph.to_s
        
        # find the usp block
        
        sem = sent_children.detect { |child| child.name == "sem"}
        usp = ""
        if sem
          usp = sem.children_and_text.detect { |child| child.name == "usp" }
          usp = usp.to_s
        end
        
        # find all frames
        if sem
          frames = sem.children_and_text.detect { |child| child.name == "frames" }
          if frames
            frames.children_and_text.each { |frame|
              unless frame.name == "frame"
                next
              end
              frameid = frame.attributes["id"]
              
              temp_frameid = "#{sentid}_temp_f#{frame_hash[sentid].length+this_frames.length+1}"
              final_frameid = "#{sentid}_f#{frame_hash[sentid].length+this_frames.length+1}"
              
              temp_subs << [frameid,temp_frameid]
              final_subs << [temp_frameid,final_frameid]
              
              this_frames << frame.to_s
            }
          end
        end
        
        # now first rename all the frames to temporary names
        
        temp_subs.each {|orig_frameid, temp_frameid|
          this_frames.map! {|frame_str|
	#print "orig ", orig_frameid, " temp ", temp_frameid, "\n"
            frame_str.gsub(orig_frameid,temp_frameid)
          }
      
          usp.gsub!(orig_frameid,temp_frameid)
        }
        
        # and re-rename the temporary names
        
        final_subs.each {|temp_frameid, final_frameid|
          this_frames.map! {|frame_str|
            frame_str.gsub(temp_frameid,final_frameid)
          }
          usp.gsub!(temp_frameid, final_frameid)
        }
        
        # store frames in data structure
        this_frames.each {|frame_str|
          frame_hash[sentid] << frame_str
        }
        
        # store uspfes in data structure
        unless usp.empty?
          usp_elt = RegXML.new(usp)
          uspfes = usp_elt.children_and_text.detect { |child| child.name == "uspfes" }
          uspfes.children_and_text.each { |child|
            unless child.name == "uspblock"
              next
            end
            uspfes_hash[sentid] << child.to_s
          }
        
          # store uspframes in data structure
          uspframes = usp_elt.children_and_text.detect { |child| child.name == "uspframes" }
          uspframes.children_and_text.each { |child|
            unless child.name == "uspblock"
              next
            end
            uspframes_hash[sentid] << child.to_s
          }
        end
      }
    }

    # now write everything in the data structure back to a file
    
    filecounter = 0
    sentcounter = 0
    outfile = nil
    sent_stack = Array.new
        
    graph_hash.sort {|a,b| a[0].to_i <=> b[0].to_i}.each {|sentid,graph_str|
      
      if sentcounter == max_sentnum
        outfile.puts SalsaTigerXMLHelper.get_footer
        outfile.close
        outfile = nil
      end
      
      unless outfile
        outfile = File.new(split_dir+filecounter.to_s+".xml","w")
        outfile.puts SalsaTigerXMLHelper.get_header    
        filecounter +=1
        sentcounter = 0
      end
            
      xml = Array.new
      xml << graph_str
      xml << "<sem>"
      xml << "<globals>"
      xml << "</globals>"
      xml << "<frames>"
      frame_hash[sentid].each {|frame_str|
        xml << frame_str
      }
      xml << "</frames>"
      xml << "<usp>"
      xml << "<uspframes>"
      uspframes_hash[sentid].each {|uspblock_str|
        xml << uspblock_str
      }
      xml << "</uspframes>"
      xml << "<uspfes>"
      uspfes_hash[sentid].each {|uspblock_str|
        xml << uspblock_str
      }
      xml << "</uspfes>"
      xml << "</usp>"
      xml << "</sem>"
      xml << "</s>"
      
      outfile.puts xml.join("\n")
      sentcounter += 1
    }
    
    if outfile 
      outfile.puts SalsaTigerXMLHelper.get_footer
      outfile.close
      outfile = nil
    end   
    
  end


  ####
  # transform SalsaTigerXML file to Tab format file
  def FrprepHelper.stxml_to_tab_file(input_filename,   # string: name of input file
                                     output_filename,  # string: name of output file
                                     exp)              # FrprepConfigData
    infile = FilePartsParser.new(input_filename)
    begin
      outfile = File.new(output_filename,"w")
    rescue
      raise "Stxml to tab: could not write to tab file #{output_filename}"
    end

    infile.scan_s {|sent_string|        

      # determine sentence ID
      sentid = RegXML.new(sent_string).attributes["id"]
      unless sentid
        $stderr.puts "No sentence ID in sentence:\n "+ sent_string
        $stderr.puts "Making a new one up."
        sentid = Time.new().to_f.to_s
      end

      # find terminals and process them
      unless sent_string.delete("\n") =~ /<terminals[ >].+<\/terminals>/
        $stderr.puts "Warning: could not find terminals in sentence:"
        $stderr.puts sent_string
        $stderr.puts "Skipping"
        next
      end

        # modified by ines, 27/08/08
        # for Berkeley => convert ( ) to -LRB- -RRB-
       
	text = $&
        if exp.get("parser") == "berkeley"
          text.gsub!(/word='\('/, "word='*LRB*'")
          text.gsub!(/word='\)'/, "word='*RRB*'")
 	  text.gsub!(/word=['"]``['"]/, "word='\"'")
	  text.gsub!(/word=['"]''['"]/,  "word='\"'")
	  text.gsub!(/word=['"]\&apos;\&apos;['"]/,  "word='\"'")
	  #text.gsub!(/word=['"]\(['"]/,  "word='-LRB-'")
	  #text.gsub!(/word=['"]\)['"]/,  "word='-RRB-'")

        end
      terminals = text
      #terminals = sent_string
      terminals = RegXML.new(terminals)
      terminals.children_and_text.each { |terminal|
 
        unless terminal.name == "t"
          # not a terminal after all
          next
        end
  

        outfile.puts FNTabFormatFile.format_str({
						  "word" => SalsaTigerXMLHelper.unescape(terminal.attributes["word"]),
						  "sent_id" => sentid
						})
      } # each terminal
      outfile.puts
    } # each sentence
    outfile.close
  end

  ###
  # add semantics from tab:
  #
  # add information about semantics from a FN tab sentence
  # to a SalsaTigerSentence object:
  # - frames (one frame per sentence)
  # - roles
  # - FrameNet grammatical functions
  # - FrameNet POS of target
  def FrprepHelper.add_semantics_from_tab(st_sent,  # SalsaTigerSentence object
					  tab_sent, # FNTabFormatSentence object
                                          mapping,  # hash: tab lineno -> array:SynNode
                                          interpreter_class, # SynInterpreter class
                                          exp)      # FrprepConfigData

    if tab_sent.nil?
      # tab sentence not found
      return
    end

    # iterate through frames in the tabsent
    frame_index = 0
    tab_sent.each_frame { |tab_frame_obj|
      frame_name = tab_frame_obj.get_frame() # string
        
      if frame_name.nil? or frame_name =~ /^-*$/
	# weird: a frame without a frame
	$stderr.puts "Warning: frame entry without a frame in tab sentence #{st_sent.id}."
	$stderr.puts "Skipping"
	next
      end
        
      frame_node = st_sent.add_frame(frame_name, tab_sent.get_sent_id() + "_f#{frame_index}")
      frame_index += 1
    
      # target
      target_nodes = Array.new
      tab_frame_obj.get_target_indices.each {|terminal_id| 
	if mapping[terminal_id]
	  target_nodes.concat mapping[terminal_id]
	end
      }

      # let the interpreter class decide on how to determine the maximum constituents
      target_maxnodes = interpreter_class.max_constituents(target_nodes, st_sent)
      if target_maxnodes.empty?
	# HIEr
	STDERR.puts  "Warning: no target in frame entry, sentence #{st_sent.id}."
	$stderr.puts "frame is #{frame_name}, frame no #{frame_index}"
	$stderr.puts "Skipping."
	$stderr.puts "target indices: " + tab_frame_obj.get_target_indices.join(", ")
        #tab_sent.each_line { |line|
        #  $stderr.puts line
	#  $stderr.puts "--"
        #}
	next
      end
      frame_node.add_fe("target",target_maxnodes)
        
      # set features on target: target lemma, target POS
      target_lemma = tab_frame_obj.get_target()
      target_pos = nil
      if target_lemma
	if exp.get("origin") == "FrameNet"
	  # FrameNet data: here the lemma in the tab file has the form
	  # <lemma>.<POS>
	  # separate the two
	  if target_lemma =~ /^(.*)\.(.*)$/
	    target_lemma = $1
	    target_pos = $2
	  end
	end
	frame_node.target.set_attribute("lemma", target_lemma)
        if target_pos
          frame_node.target.set_attribute("pos", target_pos)
        end
      end
        
      # roles, GF, PT
      # synnode_markable_label: 
      #   hash "role" | "gf" | "pt" -> SynNode -> array: label(string)
      layer_synnode_label = Hash.new
      ["gf", "pt", "role"].each {|layer|
	termids2labels = tab_frame_obj.markables(layer)

	unless layer_synnode_label[layer]
	  layer_synnode_label[layer] = Hash.new
	end

	termids2labels.each {|terminal_indices, label|
	  terminal_indices.each { |t_i|

	    if (nodes = mapping[t_i])

	      nodes.each { |node|
		unless layer_synnode_label[layer][node]
		  layer_synnode_label[layer][node] = Array.new
		end

		layer_synnode_label[layer][node] << label
	      } # each node that t_i maps to
	    end # if t_i maps to anything

	  } # each terminal index
	} # each mapping terminal indices -> label
      } # each layer

      # 'stuff' (Support and other things)
      layer_synnode_label["stuff"] = Hash.new
      tab_frame_obj.each_line_parsed { |line_obj|
        if (label = line_obj.get("stuff")) != "-"
          if (nodes = mapping[line_obj.get("lineno")])
            nodes.each { |node|
              unless layer_synnode_label["stuff"][node]
                layer_synnode_label["stuff"][node] = Array.new
              end
              layer_synnode_label["stuff"][node] << label 
            }
          end
        end
      }

      # reencode:
      #  hash role_label(string) -> array of tuples [synnodes, gflabels, ptlabels]
      #   synnodes: array:SynNode.  gflabels, ptlabels: array:String
      #
      # note that in this step, any gf or pt labels that have been
      # assigned to a SynNode that has not also been assigned a role
      # will be lost
      role2nodes_labels = Hash.new
      layer_synnode_label["role"].each_pair { |synnode, labels|
	labels.each { | rolelabel|
	  unless role2nodes_labels[rolelabel]
	    role2nodes_labels[rolelabel] = Array.new
	  end
	  
	  role2nodes_labels[rolelabel] << [
	    synnode, 
	    layer_synnode_label["gf"][synnode], 
	    layer_synnode_label["pt"][synnode]
	  ]
	} # each role label
      } # each pair SynNode/role labels

      # reencode "stuff", but only the support cases
      role2nodes_labels["Support"] = Array.new()

      layer_synnode_label["stuff"].each_pair { |synnode, labels|
        labels.each { |stufflabel|
          if stufflabel =~ /Supp/
            # some sort of support
            role2nodes_labels["Support"] << [synnode, nil, nil]
          end
        }
      }

      ##
      # each role label: 
      # make FeNode for the current frame
      role2nodes_labels.each_pair { |rolelabel, node_gf_pt|
	
	# get list of syn nodes, GF and PT labels for this role
	# shortcut for GF and PT labels: take any labels that have
	# been assigned for _some_ Synnode of this role
	synnodes = node_gf_pt.map { |ngp| ngp[0] } 
	gflabels = node_gf_pt.map { |ngp| ngp[1] }.compact.flatten.uniq
	ptlabels = node_gf_pt.map { |ngp| ngp[2] }.compact.flatten.uniq


	# let the interpreter class decide on how to 
	# determine the maximum constituents
	maxnodes = interpreter_class.max_constituents(synnodes, st_sent)

	fe_node = st_sent.add_fe(frame_node, rolelabel, maxnodes)
	unless gflabels.empty?
	  fe_node.set_attribute("gf", gflabels.join(","))
	end
	unless ptlabels.empty?
	  fe_node.set_attribute("pt", ptlabels.join(","))
	end
      } # each role label
    } # each frame
  end


  ######
  # handle multiword targets:
  # if you find a verb with a separate prefix, 
  # change the verb's lemma information accordingly
  # and add an attribute "other_words" to the verb node
  # pointing to the other node
  #
  # In general, it will be assumed that "other_words" contains
  # a list of node IDs for other nodes belonging to the same 
  # group, node IDs separated by spaces, and that 
  # each node of a group has the "other_words" attribute.
  #
  def FrprepHelper.handle_multiword_targets(sent,  # SalsaTigerSentence object
					    interpreter, # SynInterpreter object
					    language) # string: en, de
    ##
    # only retain the interesting words of the sentence:
    # content words and prepositions
    if sent.nil?
	return
    end

    nodes = sent.terminals.select { |node|
      [  
        "adj", "adv", "card", "noun", "part", "prep", "verb"
      ].include? interpreter.category(node)
    }

    ##
    # group:
    # group verbs with their separate particles
    # (at a later point, other types of grouping can be inserted here)
    groups = FrprepHelper.group_words(nodes, interpreter)

    ##
    # record grouping information as attributes on the terminals.
    groups.each { |descr, group_of_nodes|
      case descr
      when "none"
        # no grouping
      when "part"
        # separate particle belonging to a verb
        
        # group_of_nodes is a pair [verb, particle]
        verb, particle = group_of_nodes

        verb.set_attribute("other_words", particle.id())
        particle.set_attribute("other_words", verb.id())
        
        if verb.get_attribute("lemma") and particle.get_attribute("lemma")
          case language
          when "de"
            # German: prepend SVP to get the real lemma of the verb
            verb.set_attribute("lemma", 
                               particle.get_attribute("lemma") + 
			       verb.get_attribute("lemma"))
          when "en"
            # English: append particle as separate word after the lemma of the verb
            verb.set_attribute("lemma", 
                               verb.get_attribute("lemma") + " " + 
			       particle.get_attribute("lemma"))
          else
	    # default
	    verb.set_attribute("lemma",
			       verb.get_attribute("lemma") + " " + 
			       particle.get_attribute("lemma"))
          end
        end

      else
        raise "Shouldn't be here: unexpected description #{descr}"
      end
    }
  end

  ########################
  # group_words
  #
  # auxiliary of transform_multiword targets
  #
  # Group terminals: 
  # At the moment, just find separate prefixes and particles
  # for verbs
  #
  # returns: list of pairs [descr, nodes]
  # descr: string, "none" (no group), "part" (separate verb particle)
  # nodes: array:SynNode
  def FrprepHelper.group_words(nodes,    # array: SynNode
			       interpreter) # SynInterpreter object

    retv = Array.new # array of groups, array:array:SynNode
    done = Array.new # remember nodes already covered

    nodes.each { |terminal_node|
      if done.include? terminal_node
        # we have already included this node in one of the groups
        next
      end

      if (svp = interpreter.particle_of_verb(terminal_node, nodes))
        retv << ["part", [terminal_node, svp]]
        done << terminal_node
        done << svp
      else
        retv << ["none", [terminal_node]]
        done << terminal_node
      end

    }

    return retv
  end


  ######
  # handle unknown framenames
  #
  # For all frames with names matching Unknown\d+,
  # rename them to <lemma>_Unknown\d+
  def FrprepHelper.handle_unknown_framenames(sent,     # SalsaTigerSentence
					     interpreter) # SynInterpreter class
    if sent.nil?
	return
    end

    sent.each_frame { |frame|
      if frame.name() =~ /^Unknown/
        if frame.target
          maintarget = interpreter.main_node_of_expr(frame.target.children(), "no_mwe")
        else
          maintarget = nil
        end
        unless maintarget
          $stderr.puts "Warning: Unknown frame, and I could not determine the target lemma: Frame #{frame.id()}"
          $stderr.puts "Cannot repair frame name, leaving it as is."
          return
        end
          
        # get lemma, if it exists, otherwise get word
        # also, if the lemmatizer has returned a disjunction of lemmas,
        # get the first disjunct
        lemma = interpreter.lemma_backoff(maintarget)
        if lemma
          # we have a lemma
          frame.set_name(lemma + "_" + frame.name())
        else
          # the main target word has no lemma attribute,
          # and somehow I couldn't even get the target word
          $stderr.puts "Warning: Salsa 'Unknown' frame."
          $stderr.puts "Trying to make its lemma-specificity explicit, but"
          $stderr.puts "I could not determine the target lemma nor the target word: frame #{frame.id()}"
          $stderr.puts "Leaving 'Unknown' as it is."
        end
      end
    } 
  end


  #####################
  #
  # Integrate the semantic annotation of an old sentence
  # into the corresponding new sentence
  # At the same time, integrate the lemma information from the
  # old sentence into the new sentence
  def FrprepHelper.integrate_stxml_semantics_and_lemmas(oldsent, 
                                                        newsent,
                                                        interpreter_class,
                                                        exp)
    if oldsent.nil? or newsent.nil?
	return
    end
    ##
    # match old and new sentence via terminals
    newterminals = newsent.terminals_sorted()
    oldterminals = oldsent.terminals_sorted()
    # sanity check: exact match on terminals?
    newterminals.interleave(oldterminals).each { |newnode, oldnode|
	#print "old ", oldnode.word, "  ", newnode.word, "\n"
      # new and old word: use both unescaped and escaped variant
      if newnode
        newwords = [ newnode.word, SalsaTigerXMLHelper.escape(newnode.word) ]
      else
        newwords = [nil, nil]
      end
      if oldnode
        oldwords = [ oldnode.word, SalsaTigerXMLHelper.escape(oldnode.word) ]
      else
        oldwords = [ nil, nil]
      end

      if (newwords & oldwords).empty?
        # old and new word don't match, either escaped or non-escaped

        $stderr.puts "Warning: could not match terminals of sentence #{newsent.id()}"
        $stderr.puts "This means that I cannot match the semantic annotation"
        $stderr.puts "to the newly parsed sentence. Skipping."
        #$stderr.puts "Old sentence: "
        #$stderr.puts oldterminals.map { |n| n.word }.join("--")
        #$stderr.puts "New sentence: "
        #$stderr.puts newterminals.map { |n| n.word }.join("--")
        return false
      end
    }

    ##
    # copy lemma information
    oldterminals.each_with_index { |oldnode, ix|
      newnode = newterminals[ix]
      if oldnode.get_attribute("lemma")
        newnode.set_attribute("lemma", oldnode.get_attribute("lemma"))
      end
    }

    ##
    # copy frames
    oldsent.each_frame { |oldframe|
      # make new frame with same ID
      newframe = newsent.add_frame(oldframe.name, oldframe.id())
      # copy FEs
      oldframe.each_child { |oldfe|
        # new nodes: map old terminals to new terminals,
        # then find max constituents covering them
        newnodes = oldfe.descendants.select { |n| 
          n.is_terminal? 
        }.map { |n|
          oldterminals.index(n)
        }.map { |ix|
          newterminals[ix]
        }

        # let the interpreter class decide on how to determine the maximum constituents
        newnodes = interpreter_class.max_constituents(newnodes, newsent)

        # make new FE with same ID
        new_fe = newsent.add_fe(newframe, oldfe.name(), newnodes, oldfe.id())
	# keep all attributes of the FE
	if oldfe.get_f("attributes")
	  oldfe.get_f("attributes").each_pair { |attr, value|
	    new_fe.set_attribute(attr, value)
	  }
	end
      }
    }

    ##
    ### changed by ines => appears twice in stxml file

    # copy underspecification
    # keep as is, since we've kept all frame and FE IDs
    oldsent.each_usp_frameblock { |olduspframe|
      newuspframe = newsent.add_usp("frame")
      olduspframe.each_child { |oldnode|
        newnode = newsent.sem_node_with_id(oldnode.id())
        if newnode
          newuspframe.add_child(newnode)
        else
          $stderr.puts "Error: unknown frame with ID #{oldnode.id()}"
        end
      }
    }
    oldsent.each_usp_feblock { |olduspfe|
      newuspfe = newsent.add_usp("fe")
      olduspfe.each_child { |oldnode|
        newnode = newsent.sem_node_with_id(oldnode.id())
        if newnode
          newuspfe.add_child(newnode)
        else
          $stderr.puts "Error: unknown FE with ID #{oldnode.id()}"
        end
      }
    }

  end

  ####################
  # add head attributes to each nonterminal in each 
  # SalsaTigerXML file in a directory

  def FrprepHelper.add_head_attributes(st_sent,      # SalsaTigerSentence object
				       interpreter)  # SynInterpreter class
    st_sent.each_nonterminal {|nt_node|
     head_term = interpreter.head_terminal(nt_node)
      if head_term and head_term.word()
	nt_node.set_attribute("head", head_term.word())
      else
	nt_node.set_attribute("head", "--")
      end
    } # each nonterminal
  end

  # add lemma information to each terminal in a given SalsaTigerSentence object
  def FrprepHelper.add_lemmas_from_tab(st_sent, # SalsaTigerSentence object
				       tab_sent,# FNTabFormatSentence object
                                       mapping) # hash: tab lineno -> array:SynNode
    if tab_sent.nil?
      # tab sentence not found
      return
    end

    # produce list with word, lemma pairs
    lemmat = Array.new        
    tab_sent.each_line_parsed {|line|
      word = line.get("word")
      lemma = line.get("lemma")
      lemmat << [word,lemma]
    }
    
    # match with st_sent terminal list and add lemma attributes
    # KE Jan 07: if word mismatch,
    # set to Lemmatizer file version,
    # but count mismatches
    word_mismatches = Array.new()

    st_sent.each_terminal_sorted {|t|
      matching_lineno = (0..lemmat.length()-1).to_a.detect { |tab_lineno|
        mapping[tab_lineno].include? t
      }
      unless matching_lineno
        next
      end
      word, lemma = lemmat[matching_lineno]
          
      # transform characters to XML-friendly form
      # for comparison with st_word, which is also escaped
      word = SalsaTigerXMLHelper.escape(word)
      st_word = t.word()
      if word != st_word and
          word != SalsaTigerXMLHelper.escape(st_word)
        # true mismatch.
        # use the Lemmatizer version of the word, remember the mismatch
        word_mismatches << [st_word, word]
        t.set_attribute("word", word)
      end
      
      if lemma
        # we actually do have lemma information
        lemmatised_head = SalsaTigerXMLHelper.escape(lemma)
        t.set_attribute("lemma",lemmatised_head)
      end
    } # each terminal

    # did we have mismatches? then report them
    unless word_mismatches.empty?
      $stderr.puts "Warning: Word mismatches found between Lemmatizer file and SalsaTigerXML file generalted from parser output."
      $stderr.puts "(May be due to failed reencoding of special character in the parser output.)"
      $stderr.puts "I am using the Lemmatizer version by default."
      $stderr.puts "Version used:"
      $stderr.print "\t"
      st_sent.each_terminal_sorted { |t| $stderr.print ">>#{t}<<" }
      $stderr.puts
      $stderr.print "SalsaTigerXML file had: "
      $stderr.print word_mismatches.map { |st_word, tab_word|
        "#{st_word} instead of #{tab_word}"
      }.join(", ")
      $stderr.puts
    end
  end

  ###################3
  # given a SalsaTigerSentence,
  # look for FrameNet frames that are 
  # test frames, and remove them
  def FrprepHelper.remove_deprecated_frames(sent,  # SalsaTigerSentence
                                            exp)   # FrprepConfigData

    unless exp.get("origin") == "FrameNet"
      return
    end

    sent.frames.each { |frame_obj|
      if frame_obj.name() == "Boulder" or
          frame_obj.name() =~ /^Test/
        sent.remove_frame(frame_obj)
      end
    }
  end

end

############################################3
# Class FrprepFlatSyntax:
#
# given a FNTabFormat file,
# yield each of its sentences in SalsaTigerXML,
# constructing a flat syntax
class FrprepFlatSyntax
  def initialize(tabfilename, # string: name of tab file
                 postag_suffix, # postag file suffix (or nil)  
                 lemma_suffix)  # lemmatisation file suffix (or nil)
    
    @tabfilename = tabfilename
    @pos_suffix = postag_suffix
    @lemma_suffix = lemma_suffix
  end

  # yield each non-parse sentence as a tuple
  # [ salsa/tiger xml sentence, tab format sentence, mapping]
  # of a SalsaTigerSentence object, a FNTabSentence object,
  # and a hash: FNTab sentence lineno(integer) -> array:SynNode
  # pointing each tab word to one or more SalsaTigerSentence terminals
  def each_sentence(dummy)

    # read tab file with lemma and POS info
    tabfile = FNTabFormatFile.new(@tabfilename, @pos_suffix, @lemma_suffix)

    tabfile.each_sentence() { |tabsent|
      # start new, empty sentence with "failed" attribute (i.e. no parse)
      # and with the ID of the corresponding TabFormat sentence
      sentid = tabsent.get_sent_id()
      if sentid.nil? or sentid =~ /^-*$/
        $stderr.puts "No sentence ID for sentence:"
        tabsent.each_line_parsed { |l| $stderr.print l.get("word"), " "}
        $stderr.puts
        sentid = Time.new().to_f.to_s
      end
      sent = SalsaTigerSentence.new("<s id=\"#{SalsaTigerXMLHelper.escape(sentid)}\" failed=\"true\"></s>")
      
      # add single nonterminal node, category "S"
      single_nonterminal_id = SalsaTigerXMLHelper.escape(sentid.to_s + "_NT")
      vroot = sent.add_syn("nt", "S", # category
                           nil,  # word
                           nil,  # pos
                           single_nonterminal_id)
      
      # add terminals
      tabsent.each_line_parsed() { |line_obj|
        # make terminal node with tab sent info
        node_id = sentid.to_s + "_" + line_obj.get("lineno").to_s
        word = line_obj.get("word")
        unless word
          word = ""
        end
        word = SalsaTigerXMLHelper.escape(word)
        pos = line_obj.get("pos")
        unless pos
          pos = ""
        end
        pos = SalsaTigerXMLHelper.escape(pos)
        terminal = sent.add_syn("t", nil, # category
                                word, pos, 
                                node_id)

        if line_obj.get("lemma")
          # lemma
          terminal.set_attribute("lemma", SalsaTigerXMLHelper.escape(line_obj.get("lemma")))
        end

        # add new terminal as child of vroot
        vroot.add_child(terminal, nil)
        terminal.add_parent(vroot, nil)
      } # each line of tab file

      # yield newly constructed SalsaTigerXMl sentence plus tab sentence
      yield [sent, tabsent, SynInterfaceSTXML.standard_mapping(sent, tabsent)]
    }
  end
end

############################################3
# Class FrprepReadStxml
#
# given a STXML file,
# yield each of its sentences
class FrprepReadStxml
  def initialize(stxmlfilename, # string: name of SalsaTigerXML file
                 tabfilename,   # string: name of corresponding tab file (or nil)
                 postag_suffix,    #  POS tag file suffix (or nil)
                 lemma_suffix)     #  lemmatization file suffix (or nil)

    @stxmlfilename = stxmlfilename
    @tabfilename = tabfilename
    @pos_suffix = postag_suffix
    @lemma_suffix = lemma_suffix
  end
  # yield each non-parse sentence as a tuple
  # [ salsa/tiger xml sentence, tab format sentence, mapping]
  # of a SalsaTigerSentence object, a FNTabSentence object,
  # and a hash: FNTab sentence lineno(integer) -> array:SynNode
  # pointing each tab word to one or more SalsaTigerSentence terminals
  def each_sentence(dummy)
    # read corresponding tab file?
    tab_sents = Array.new()
    if File.exists? @tabfilename
      tabfile = FNTabFormatFile.new(@tabfilename,@pos_suffix,@lemma_suffix)    
      tabfile.each_sentence { |tabsent|
        tab_sents << tabsent
      }      
    end

    # read STXML file
    infile = FilePartsParser.new(@stxmlfilename)
    index = 0
    infile.scan_s { |sent_string|
      sent = SalsaTigerSentence.new(sent_string)
      yield [sent, tab_sents.at(index), SynInterfaceSTXML.standard_mapping(sent, tab_sents.at(index))]
      index += 1
    }
  end
end