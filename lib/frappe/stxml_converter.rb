require 'logging'
require 'fileutils'
require 'external_systems'
require 'frappe/file_parser'
require 'salsa_tiger_xml/file_parts_parser'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'salsa_tiger_xml/salsa_tiger_xml_helper'
require 'salsa_tiger_xml/corpus'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'tabular_format/fn_tab_format_file'
require 'frappe/fix_syn_sem_mapping'

module Shalmaneser
  module Frappe
    class STXMLConverter
      def initialize(exp)
        @exp = exp
        # @todo Implement the logger as a mixin for all classes.
        @logger = LOGGER
        # suffixes for different types of output files
        @file_suffixes = {"lemma" => ".lemma", "pos" => ".pos", "tab" => ".tab", "stxml" => ".xml"}
      end
      #############################################
      # transform_stxml
      #
      # transformation for SalsaTigerXML data
      #
      # - If the input format was SalsaTigerXML:
      #   - Tag, lemmatize and parse, if the experiment file tells you so
      #
      # - If the origin is the Salsa corpus:
      #   Change frame names from Unknown\d+ to lemma_Unknown\d+
      #
      # - fix multiword lemmas, or at least try
      # - transform to UTF 8
      # string: name of directory for parse data
      # string: name of directory for split/tab data
      # string: name of input directory
      # string: name of final output directory
      # FrappeConfigData
      def transform_stxml_dir(parse_dir, tab_dir, input_dir, output_dir)
        ####
        # Data preparation

        # Data with Salsa as origin:
        # remember the target lemma as an attribute on the
        # <target> elements
        #
        # currently deactivated: encoding problems
        #     if @exp.get("origin") == "SalsaTiger"
        #       $stderr.puts "Frprep: noting target lemmas"
        #       changed_input_dir = frprep_dirname("salsalemma", "new")
        #       note_salsa_targetlemmas(input_dir, changed_input_dir)

        #       # remember changed input dir as input dir
        #       input_dir = changed_input_dir
        #     end

        #  If data is to be parsed, split input files
        #    else copy data to stxml_indir.
        # stxml_dir: directory where SalsaTiger data is situated
        if @exp.get("do_parse")
          # split data
          stxml_splitdir = frprep_dirname("stxml_split", "new")
          stxml_dir = stxml_splitdir

          LOGGER.info "#{PROGRAM_NAME}: Splitting the input data into #{stxml_dir}."

          stxml_split_dir(input_dir, stxml_splitdir, @exp.get("parser_max_sent_num"), @exp.get("parser_max_sent_len"))
        else
          # no parsing: copy data to split dir
          stxml_dir = parse_dir

          LOGGER.info "#{PROGRAM_NAME}: Copying data to #{stxml_dir}"

          Dir[input_dir + "*.xml"].each { |f| FileUtils.cp(f, stxml_dir) }
        end

        # Some syntactic processing will take place:
        # tabify data
        if @exp.get("do_parse") || @exp.get("do_lemmatize") || @exp.get("do_postag")
          LOGGER.info "#{PROGRAM_NAME}: Making input for syn. processing."
          Dir[stxml_dir + "*" + @file_suffixes["stxml"]].each do |stxmlfilename|
            tabfilename = tab_dir + File.basename(stxmlfilename, @file_suffixes["stxml"]) + @file_suffixes["tab"]
            stxml_to_tab_file(stxmlfilename, tabfilename)
          end
        end

        ###
        # POS-tagging
        if @exp.get("do_postag")
          LOGGER.info "#{PROGRAM_NAME}: Tagging."
          sys_class = ExternalSystems.get_interface("pos_tagger", @exp.get("pos_tagger"))
          sys = sys_class.new(@exp.get("pos_tagger_path"), @file_suffixes["tab"], @file_suffixes["pos"])
          sys.process_dir(tab_dir, tab_dir)
        end

        ###
        # Lemmatization
        if @exp.get("do_lemmatize")
          LOGGER.info "#{PROGRAM_NAME}: Lemmatizing."
          sys_class = ExternalSystems.get_interface("lemmatizer", @exp.get("lemmatizer"))
          sys = sys_class.new(@exp.get("lemmatizer_path"), @file_suffixes["tab"], @file_suffixes["lemma"])
          sys.process_dir(tab_dir, tab_dir)
        end

        ###
        # Parsing, production of SalsaTigerXML output

        # get interpretation class for this
        # parser/lemmatizer/POS tagger combination
        sys_class_names = {}

        [["do_postag", "pos_tagger"],
         ["do_lemmatize", "lemmatizer"],
         ["do_parse", "parser"]].each do |service, system_name|
          # yes, perform this service
          if @exp.get(service)
            sys_class_names[system_name] = @exp.get(system_name)
          end
        end

        interpreter_class = ExternalSystems.get_interpreter(sys_class_names)

        unless interpreter_class
          raise "Shouldn't be here"
        end

        parse_obj = FileParser.new(@exp, @file_suffixes, parse_dir, "tab_dir" => tab_dir, "stxml_dir" => stxml_dir)
        parse_obj.each_parsed_file do |parsed_file_obj|
          outfilename = output_dir + parsed_file_obj.filename + ".xml"
          LOGGER.debug "Writing #{outfilename}."
          begin
            outfile = File.new(outfilename, "w")
          rescue
            raise "Cannot write to SalsaTigerXML output file #{outfilename}"
          end
          if @exp.get("do_parse")
            # read old SalsaTigerXML file
            # so we can integrate the old file's semantics later
            # array of sentence strings
            oldxml = []
            # we assume that the old and the new file have the same name,
            # ending in .xml.
            oldxmlfile = STXML::FilePartsParser.new(stxml_dir + parsed_file_obj.filename + ".xml")
            oldxmlfile.scan_s do |sent_string|
              # remember this sentence by its ID
              oldxml << sent_string
            end
          end
          outfile.puts STXML::SalsaTigerXMLHelper.get_header
          index = 0
          # work with triples
          # SalsaTigerSentence, FNTabSentence,
          # hash: tab sentence index(integer) -> array:SynNode
          parsed_file_obj.each_sentence do |st_sent, tabformat_sent, mapping|
            # parsed? then integrate semantics and lemmas from old file
            if @exp.get("do_parse")
              oldsent_string = oldxml[index]
              index += 1
              if oldsent_string
                oldsent_string = escape_berkeley_chars(oldsent_string)
                # we have both an old and a new sentence, so integrate semantics
                oldsent = STXML::SalsaTigerSentence.new(oldsent_string)

                next if st_sent.nil?

                unless integrate_stxml_semantics_and_lemmas(oldsent, st_sent, interpreter_class, @exp)
                  oldsent_string = oldxml[index]
                  index += 1
                  if oldsent_string
                    oldsent_string = escape_berkeley_chars(oldsent_string)
                    # we have both an old and a new sentence, so integrate semantics
                    oldsent = STXML::SalsaTigerSentence.new(oldsent_string)

                    integrate_stxml_semantics_and_lemmas(oldsent, st_sent, interpreter_class, @exp)
                  end
                end
              else
                # no corresponding old sentence for this new sentence
                @logger.warn "Warning: Transporting semantics - missing source sentence, skipping"
              end
            end
            # remove pseudo-frames from FrameNet data
            remove_deprecated_frames(st_sent, @exp)
            # repair syn/sem mapping problems?
            if @exp.get("fe_syn_repair") || @exp.get("fe_rel_repair")
              FixSynSemMapping.fixit(st_sent, @exp, interpreter_class)
            end

            outfile.puts st_sent.get
          end # each ST sentence
          outfile.puts STXML::SalsaTigerXMLHelper.get_footer
        end # each file parsed
      end

      ####
      # transform SalsaTigerXML file to Tab format file
      # @param [String] input_filename Name of input file.
      # @param [String] output_filename Name of output file.
      # @param [FrappeConfigData]
      def stxml_to_tab_file(input_filename, output_filename)
        corpus = STXML::Corpus.new(input_filename)

        File.open(output_filename, 'w') do |f|
          corpus.each_sentence do |sentence|
            raise 'Interface changed!!!' unless sentence.is_a?(Nokogiri::XML::Element)
            id = sentence.attributes['id'].value
            words = sentence.xpath('.//t')
            # byebug
            words.each do |word|
              word = STXML::SalsaTigerXMLHelper.unescape(word.attributes['word'].value)
              # @todo AB: I don't know why the Berkeley Parser wants this.
              #   Investigate if every Grammar needs this conversion.
              #   Try to move this convertion from FrappeHelper to BerkeleyInterface.
              if @exp.get("parser") == "berkeley"
                word.gsub!(/\(/, "*LRB*")
                word.gsub!(/\)/, "*RRB*")
                word.gsub!(/``/, '"')
                word.gsub!(/''/, '"')
                word.gsub!(%r{\&apos;\&apos;}, '"')
              end
              fields = {'word' => word, 'sent_id' => id}
              f.puts FNTabFormatFile.format_str(fields)
            end
            f.puts
          end
        end
      end
      ###############
      # frprep_dirname:
      # make directory name for frprep-internal data
      # of a certain kind described in <subdir>
      #
      # frprep_directory has one subdirectory for each experiment ID,
      # and below that there is one subdir per subtask
      #
      # If this is a new directory, it is constructed,
      # if it should be an existing directory, its existence is  checked.
      # @param subdir [String] designator of a subdirectory
      # @param neu [Nil] non-nil This may be a new directory
      def frprep_dirname(subdir, neu = nil)
        dirname = File.new_dir(@exp.get("frprep_directory"), @exp.get("prep_experiment_ID"), subdir)

        neu ? File.new_dir(dirname) : File.existing_dir(dirname)
      end


      def escape_berkeley_chars(str)
        # modified by ines, 27/08/08
        # for Berkeley => substitute ( ) for *LRB* *RRB*
        # @note AB: Duplicated code!! Move it to the Berkeley Interface.
        if @exp.get("parser") == "berkeley"
          str.gsub!(/word='\('/, "word='*LRB*'")
          str.gsub!(/word='\)'/, "word='*RRB*'")
          str.gsub!(/word=\"\(\"/, "word='*LRB*'")
          str.gsub!(/word=\"\)\"/, "word='*RRB*'")
        end

        str
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
      def stxml_split_dir(input_dir, # string: input directory with STXML files
                                       split_dir, # string: output directory
                                       max_sentnum, # integer: max num of sentences per file
                                       max_sentlen) # integer: max num of terminals per sentence


        # @note AB: Effectevely copying all files.
        Dir["#{input_dir}*.xml"].each do |file|
          FileUtils.cp file, split_dir
        end

        # @note AB: Switch off splitting for now.
        #   The algorithms are weird.
=begin
        $stderr.puts "Frprep: splitting data"

        filenames = Dir[input_dir + "*.xml"].to_a

        graph_hash = {} # for each sentence id, keep <s...</graph>
        frame_hash = {} # for each sentence id , keep the <frame...  </frame> string
        uspfes_hash = {} # for each sentence id, keep the uspfes stuff
        uspframes_hash = {} # for each sentence id, keep the uspframes stuff

        ########################
        # Traverse of file(s): compute an index of all frames for each sentence, with unique identifiers

        filenames.each { |filename|

          infile = STXML::FilePartsParser.new(filename)
          infile.scan_s { |sent_str|

            sentlen = 0
            sent_str.delete("\n").scan(/<t\s/) { |occ| sentlen += 1}
            if sentlen > max_sentlen
              sent = STXML::RegXML.new(sent_str)
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

            this_frames = []

            temp_subs = []
            final_subs = []

            sent = STXML::RegXML.new(sent_str)
            sentid = sent.attributes["id"].to_s
            if sentid.nil?
              STDERR.puts "[frprep] Warning: cannot find sentence id, skipping sentence:"
              STDERR.puts sent_str
              # strange sentence, no ID? skip
              next
            end

            unless frame_hash.key? sentid
              frame_hash[sentid] = []
              uspfes_hash[sentid] = []
              uspframes_hash[sentid] = []
            end

            # find everything up to and including the graph
            sent_children = sent.children_and_text
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

                  temp_frameid = "#{sentid}_temp_f#{frame_hash[sentid].length + this_frames.length + 1}"
                  final_frameid = "#{sentid}_f#{frame_hash[sentid].length + this_frames.length + 1}"

                  temp_subs << [frameid, temp_frameid]
                  final_subs << [temp_frameid, final_frameid]

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
              usp_elt = STXML::RegXML.new(usp)
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
        sent_stack = []

        graph_hash = graph_hash.sort { |a, b| a[0].to_i <=> b[0].to_i }

        graph_hash.each do |sentid, graph_str|
          unless outfile
            outfile = File.new(split_dir + filecounter.to_s + ".xml", "w")
            outfile.puts STXML::SalsaTigerXMLHelper.get_header
            filecounter += 1
            sentcounter = 0
          end

          xml = []
          xml << graph_str
          xml << "<sem>"
          xml << "<globals>"
          xml << "</globals>"
          xml << "<frames>"

          frame_hash[sentid].each { |frame_str| xml << frame_str }

          xml << "</frames>"
          xml << "<usp>"
          xml << "<uspframes>"

          uspframes_hash[sentid].each { |uspblock_str| xml << uspblock_str }

          xml << "</uspframes>"
          xml << "<uspfes>"

          uspfes_hash[sentid].each { |uspblock_str| xml << uspblock_str }

          xml << "</uspfes>"
          xml << "</usp>"
          xml << "</sem>"
          xml << "</s>"

          outfile.puts xml.join("\n")
          sentcounter += 1
        end

        if outfile
          outfile.puts STXML::SalsaTigerXMLHelper.get_footer
          outfile.close
          outfile = nil
        end
=end
      end


      #####################
      #
      # Integrate the semantic annotation of an old sentence
      # into the corresponding new sentence
      # At the same time, integrate the lemma information from the
      # old sentence into the new sentence
      def integrate_stxml_semantics_and_lemmas(oldsent,
                                                            newsent,
                                                            interpreter_class,
                                                            exp)
        if oldsent.nil? or newsent.nil?
          return
        end
        ##
        # match old and new sentence via terminals
        newterminals = newsent.terminals_sorted
        oldterminals = oldsent.terminals_sorted
        # sanity check: exact match on terminals?
        newterminals.interleave(oldterminals).each { |newnode, oldnode|
          #print "old ", oldnode.word, "  ", newnode.word, "\n"
          # new and old word: use both unescaped and escaped variant
          if newnode
            newwords = [ newnode.word, STXML::SalsaTigerXMLHelper.escape(newnode.word) ]
          else
            newwords = [nil, nil]
          end
          if oldnode
            oldwords = [ oldnode.word, STXML::SalsaTigerXMLHelper.escape(oldnode.word) ]
          else
            oldwords = [ nil, nil]
          end

          if (newwords & oldwords).empty?
            # old and new word don't match, either escaped or non-escaped

            $stderr.puts "Warning: could not match terminals of sentence #{newsent.id}"
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
          newframe = newsent.add_frame(oldframe.name, oldframe.id)
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
            new_fe = newsent.add_fe(newframe, oldfe.name, newnodes, oldfe.id)
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
            newnode = newsent.sem_node_with_id(oldnode.id)
            if newnode
              newuspframe.add_child(newnode)
            else
              $stderr.puts "Error: unknown frame with ID #{oldnode.id}"
            end
          }
        }
        oldsent.each_usp_feblock { |olduspfe|
          newuspfe = newsent.add_usp("fe")
          olduspfe.each_child { |oldnode|
            newnode = newsent.sem_node_with_id(oldnode.id)
            if newnode
              newuspfe.add_child(newnode)
            else
              $stderr.puts "Error: unknown FE with ID #{oldnode.id}"
            end
          }
        }

      end
      ####
      # note salsa targetlemma
      #
      # old_dir contains xml files whose name starts with the
      # target lemma for all frames in the file
      # record that target lemma in the <target> element of each frame
      def note_salsa_targetlemma(old_dir, # string ending in /
                                              new_dir) # string ending in /


        # each input file: extract target lemma from filename,
        # not this lemma in the <target> element of each frame
        Dir[old_dir + "*.xml"].each { |filename|
          changedfilename = new_dir + File.basename(filename)

          if File.basename(filename) =~ /^(.*?)[_\.]/
            lemma = $1

            infile = STXML::FilePartsParser.new(filename)
            outfile = File.new(changedfilename, "w")

            # write header
            outfile.puts infile.head

            # iterate through sentences, yield as SalsaTigerSentence objects
            infile.scan_s { |sent_string|
              sent = STXML::SalsaTigerSentence.new(sent_string)
              sent.each_frame { |frame|
                frame.target.set_attribute("lemma", lemma)
              }

              # write changed sentence
              outfile.puts sent.get
            } # each sentence

            # write footer
            outfile.puts infile.tail
            infile.close
            outfile.close

          else
            # couldn't determine lemma
            # just copy the file
            `cp #{filename} #{changedfilename}`
          end
        }
      end

      ###################3
      # given a SalsaTigerSentence,
      # look for FrameNet frames that are
      # test frames, and remove them
      # @param [SalsaTigerSentence] sent
      # @param [FrprepConfigData] exp
      def remove_deprecated_frames(sent, exp)
        unless exp.get("origin") == "FrameNet"
          return
        end

        sent.frames.each do |frame_obj|
          if frame_obj.name == "Boulder" || frame_obj.name =~ /^Test/
            sent.remove_frame(frame_obj)
          end
        end
      end
    end
  end
end
