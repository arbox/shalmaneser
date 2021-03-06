require 'fred/abstract_context_provider' # !
require 'tempfile' # !
require 'fileutils' # !

require 'salsa_tiger_xml/reg_xml' # !

require 'tabular_format/fn_tab_format_file' # !
require 'salsa_tiger_xml/salsa_tiger_sentence' # !
require 'salsa_tiger_xml/salsa_tiger_xml_helper' # !
require 'value_restriction' # !
require 'db/select_table_and_columns' # !
require 'fred/md5' # !
require 'fred/fred_conventions' # !!
require 'db/db_interface' # !
require 'db/sql_query' # !
require 'salsa_tiger_xml/file_parts_parser' # !

module Shalmaneser
  module Fred
    ####################################
    # NoncontiguousContextProvider:
    # subclass of AbstractContextProvider
    #
    # This class assumes that the input text consists of single sentences
    # drawn from a larger corpus.
    # It first constructs an index to the sentences of the input text,
    # then reads the larger corpus

    class NoncontiguousContextProvider < AbstractContextProvider

      ###
      # each_window: iterator
      #
      # given a directory with Salsa/Tiger XML data,
      # iterate through the data and construct an index to the sentences.
      #
      # Then iterate through the larger corpus,
      # yielding contexts.
      def each_window(dir) # string: directory containing Salsa/Tiger XML data

        # @todo AB: Move this chunk to OptionParser.
        # sanity check: do we know where the larger corpus is?
        unless @exp.get("larger_corpus_dir")
          $stderr.puts "Error: 'noncontiguous_input' has been set in the experiment file"
          $stderr.puts "but no location for the larger corpus has been given."
          $stderr.puts "Please set 'larger_corpus_dir' in the experiment file"
          $stderr.puts "to indicate the larger corpus from which the input corpus sentences are drawn."
          exit 1
        end

        ##
        # remember all sentences from the main corpus
        temptable_obj, sentkeys = make_index(dir)

        ##
        # make frprep experiment file
        # for lemmatization and POS-tagging of larger corpus files
        tf_exp_frprep = Tempfile.new("fred_bow_context")
        frprep_in, frprep_out, frprep_dir = write_frprep_experiment_file(tf_exp_frprep)

        ##
        # Iterate through the files of the larger corpus,
        # check for each sentence whether it is also in the input corpus
        # and yield it if it does.
        # larger corpus may contain subdirectories
        initialize_match_check

        each_infile(@exp.get("larger_corpus_dir")) { |filename|
          $stderr.puts "Larger corpus: reading #{filename}"

          # remove previous data from temp directories
          remove_files(frprep_in)
          remove_files(frprep_out)
          remove_files(frprep_dir)

          # link the input file to input directory for frprep
          File.symlink(filename, frprep_in + "infile")

          # call frprep
          # AB: Bad hack, find a way to invoke FrPrep directly.
          # We will need an FrPrep instance and an options object.
          base_dir_path = File.expand_path(File.dirname(__FILE__) + '/../..')

          # @todo AB: Remove this
          FileUtils.cp(tf_exp_frprep.path, '/tmp/frprep.exp')
          # after debugging

          # @todo AB: [2015-12-16 Wed 17:27]
          #   Change!!!
          retv = system("ruby -rubygems -I #{base_dir_path}/lib #{base_dir_path}/bin/frprep -e #{tf_exp_frprep.path}")

          unless retv
            $stderr.puts "Error analyzing #{filename}. Exiting."
            exit 1
          end


          # read the resulting Tab format file, one sentence at a time:
          # - check to see if the checksum of the sentence is in sentkeys
          #   (which means it is an input sentence)
          #   If it is, retrieve the sentence and determine targets
          # - shift the sentence through the context window
          # - whenever a target word comes to be in the center of the context window,
          #   yield.
          $stderr.puts "Computing context features from frprep output."
          Dir[frprep_out + "*.tab"].each { |tabfilename|
            tabfile = FNTabFormatFile.new(tabfilename, ".pos", ".lemma")
            tabfile.each_sentence { |tabsent|

              # get as Salsa/Tiger XML sentence, or TabSentence
              sent = get_stxml_sent(tabsent, sentkeys, temptable_obj)

              # shift sentence through context window
              each_window_for_sent(sent) { |result|
                yield result
              }

            } # each tab sent
          } # each tab file
        } # each infile from the larger corpus

        # empty the context array
        each_remaining_target { |result| yield result }
        each_unmatched(sentkeys, temptable_obj) { |result| yield result }

        # remove temporary data
        temptable_obj.drop_temp_table

        # @todo AB: TODO Rewrite this passage using pure Ruby.
        %x{rm -rf #{frprep_in}}
        %x{rm -rf #{frprep_out}}
        %x{rm -rf #{frprep_dir}}
      end

      ##################################
      private

      ###
      # for each sentence of each file in the given directory:
      # remember the sentence in a temporary DB,
      # indexed by a hash key computed from the plaintext sentence.
      #
      # return:
      # - DBTempTable object containing the temporary DB
      # - hash table containing all hash keys
      def make_index(dir)

        # AB: Why this limits? Use constants!
        space_for_sentstring = 30000
        space_for_hashkey = 500

        $stderr.puts "Indexing input corpus:"

        # start temporary table
        temptable_obj = DBInterface.get_db_interface(@exp).make_temp_table([
                                                                             ["hashkey", "varchar(#{space_for_hashkey})"],
                                                                             ["sent", "varchar(#{space_for_sentstring})"]
                                                                           ],
                                                                           ["hashkey"],
                                                                           "autoinc_index")

        # and hash table for the keys
        retv_keys = {}

        # iterate through files in the directory,
        # make an index for each sentence, and store
        # the sentence under that index
        Dir[dir + "*.xml"].each { |filename|
          $stderr.puts "\t#{filename}"
          f = STXML::FilePartsParser.new(filename)
          f.scan_s { |sent_string|

            xml_obj = STXML::RegXML.new(sent_string)

            # make hash key from words of sentence
            graph = xml_obj.children_and_text.detect { |c| c.name == "graph" }
            unless graph
              next
            end
            terminals = graph.children_and_text.detect { |c| c.name == "terminals" }
            unless terminals
              next
            end
            # in making a hash key, use special characters
            # rather than their escaped &..; form
            # $stderr.puts "HIER calling checksum for noncontig"
            hashkey = checksum(terminals.children_and_text.select { |c| c.name == "t"
                               }.map { |t|
                                 STXML::SalsaTigerXMLHelper.unescape(t.attributes["word"].to_s )
                               })
            # HIER
            # $stderr.puts "HIER " + terminals.children_and_text().select { |c| c.name() == "t"
            # }.map { |t| t.attributes()["word"].to_s() }.join(" ")

            # sanity check: if the sentence is longer than
            # the space currently allotted to sentence strings,
            # we won't be able to recover it.
            if SQLQuery.stringify_value(hashkey).length > space_for_hashkey
              $stderr.puts "Warning: sentence checksum too long, cannot store it."
              $stderr.print "Max length: #{space_for_hashkey}. "
              $stderr.puts "Required: #{SQLQuery.stringify_value(hashkey).length}."
              $stderr.puts "Skipping."
              next
            end

            if SQLQuery.stringify_value(sent_string).length > space_for_sentstring
              $stderr.puts "Warning: sentence too long, cannot store it."
              $stderr.print "Max length: #{space_for_sentstring}. "
              $stderr.puts "Required: #{SQLQuery.stringify_value(sent_string).length}."
              $stderr.puts "Skipping."
              next
            end

            # store
            temptable_obj.query_noretv(SQLQuery.insert(temptable_obj.table_name,
                                                       [["hashkey", hashkey],
                                                        ["sent", sent_string]]))
            retv_keys[hashkey] = true
          }
        }
        $stderr.puts "Indexing finished."

        return [ temptable_obj, retv_keys ]
      end

      ######
      # compute checksum from the given sentence,
      # and return as string
      def checksum(words) # array: string
        string = ""

        # HIER removed sort() after downcase
        words.map { |w| w.to_s.downcase }.each { |w|
          string << w.gsub(/[^a-z]/, "")
        }
        return MD5.new(string).hexdigest
      end

      #####
      # yield each file of the given directory
      # or one of its subdirectories
      def each_infile(indir)
        unless indir =~ /\/$/
          indir = indir + "/"
        end

        Dir[indir + "*"].each { |filename|
          if File.file?(filename)
            yield  filename
          end
        }

        # enter recursion
        Dir[indir + "**"].each { |subdir|
          # same directory we had before? don't redo
          if indir == subdir
            next
          end

          begin
            unless File.stat(subdir).directory?
              next
            end
          rescue
            # no access, I assume
            next
          end

          each_infile(subdir) { |inf|
            yield inf
          }
        }
      end

      ###
      # remove files: remove all files and subdirectories in the given directory
      def remove_files(indir)
        Dir[indir + "*"].each { |filename|
          if File.file?(filename) or File.symlink?(filename)
            retv = File.delete(filename)
          end
        }

        # enter recursion
        Dir[indir + "**"].each { |subdir|
          # same directory we had before? don't redo
          if indir == subdir
            next
          end

          begin
            unless File.stat(subdir).directory?
              next
            end
          rescue
            # no access, I assume
            next
          end

          # subdir must end in slash
          unless subdir =~ /\/$/
            subdir = subdir + "/"
          end
          # and enter recursion
          remove_files(subdir)
          FileUtils.rm_f(subdir)
        }
      end

      def write_frprep_experiment_file(tf_exp_frprep) # Tempfile object

        # make unique experiment ID
        experiment_id = "larger_corpus"
        # input and output directory for frprep
        frprep_in = ::Shalmaneser::Fred.fred_dirname(@exp, "temp", "in", "new")
        frprep_out = ::Shalmaneser::Fred.fred_dirname(@exp, "temp", "out", "new")
        frprep_dir = ::Shalmaneser::Fred.fred_dirname(@exp, "temp", "frprep", "new")

        # write file:

        # experiment ID and directories
        tf_exp_frprep.puts "prep_experiment_ID = #{experiment_id}"
        tf_exp_frprep.puts "directory_input = #{frprep_in}"
        tf_exp_frprep.puts "directory_preprocessed = #{frprep_out}"
        tf_exp_frprep.puts "frprep_directory = #{frprep_dir}"

        # output format: tab
        tf_exp_frprep.puts "tabformat_output = true"

        # corpus description: language, format, encoding
        if @exp.get("language")
          tf_exp_frprep.puts "language = #{@exp.get("language")}"
        end
        if @exp.get("larger_corpus_format")
          tf_exp_frprep.puts "format = #{@exp.get("larger_corpus_format")}"
        elsif @exp.get("format")
          $stderr.puts "Warning: 'larger_corpus_format' not set in experiment file,"
          $stderr.puts "using 'format' setting of frprep experiment file instead."
          tf_exp_frprep.puts "format = #{@exp.get("format")}"
        else
          $stderr.puts "Warning: 'larger_corpus_format' not set in experiment file,"
          $stderr.puts "relying on default setting."
        end
        if @exp.get("larger_corpus_encoding")
          tf_exp_frprep.puts "encoding = #{@exp.get("larger_corpus_encoding")}"
        elsif @exp.get("encoding")
          $stderr.puts "Warning: 'larger_corpus_encoding' not set in experiment file,"
          $stderr.puts "using 'encoding' setting of frprep experiment file instead."
          tf_exp_frprep.puts "encoding = #{@exp.get("encoding")}"
        else
          $stderr.puts "Warning: 'larger_corpus_encoding' not set in experiment file,"
          $stderr.puts "relying on default setting."
        end

        # processing: lemmatization, POS tagging, no parsing
        tf_exp_frprep.puts "do_lemmatize = true"
        tf_exp_frprep.puts "do_postag = true"
        tf_exp_frprep.puts "do_parse = false"

        # lemmatizer and POS tagger settings:
        # take verbatim from frprep file
        begin
          f = File.new(@exp.get("preproc_descr_file_" + @dataset))
        rescue
          $stderr.puts "Error: could not read frprep experiment file #{@exp.get("preproc_descr_file_" + @dataset)}"
          exit 1
        end
        f.each { |line|
          if line =~ /pos_tagger\s*=/ or
            line =~ /pos_tagger_path\s*=/ or
            line =~ /lemmatizer\s*=/ or
            line =~ /lemmatizer_path\s*=/

            tf_exp_frprep.puts line
          end
        }
        # finalize frprep experiment file
        tf_exp_frprep.close

        return [frprep_in, frprep_out, frprep_dir]
      end

      ####
      # get SalsaTigerXML sentence and targets:
      #
      # given a Tab format sentence:
      # - check whether it is in the table of input sentences.
      #   if so, retrieve it.
      # - otherwise, fashion a makeshift SalsaTigerSentence object
      #   from the words, lemmas and POS
      def get_stxml_sent(tabsent,
                         sentkeys,
                         temptable_obj)

        # SalsaTigerSentence object
        sent = nil

        # make checksum
        words = []
        words2 = []
        tabsent.each_line_parsed { |line_obj|
          words << STXML::SalsaTigerXMLHelper.unescape(line_obj.get("word"))
          words2 << line_obj.get("word")
        }
        # $stderr.puts "HIER calling checksum from larger corpus"
        hashkey_this_sentence = checksum(words)

        # HIER
        # $stderr.puts "HIER2 " + words.join(" ")
        # $stderr.puts "HIER3 " + words2.join(" ")


        if sentkeys[hashkey_this_sentence]
          # sentence from the input corpus.

          # register
          register_matched(hashkey_this_sentence)


          # select "sent" columns from temp table
          # where "hashkey" == sent_checksum
          # returns a DBResult object
          query_result = temptable_obj.query(SQLQuery.select([ SelectTableAndColumns.new(temptable_obj, ["sent"]) ],
                                                             [ ValueRestriction.new("hashkey", hashkey_this_sentence) ]))
          query_result.each { |row|

            sent_string = SQLQuery.unstringify_value(row.first.to_s)
            begin
              sent = STXML::SalsaTigerSentence.new(sent_string)
            rescue
              $stderr.puts "Error reading Salsa/Tiger XML sentence."
              $stderr.puts
              $stderr.puts "SQL-stored sentence was:"
              $stderr.puts row.first.to_s
              $stderr.puts
              $stderr.puts "==================="
              $stderr.puts "With restored quotes:"
              $stderr.puts sent_string
              exit 1
            end
            break
          }
          unless sent
            $stderr.puts "Warning: could not retrieve input corpus sentence: " + words.join(" ")
          end
        end

        if sent
          return sent
        else
          return tabsent
        end
      end

      ###
      # Keep track of which sentences from the smaller, noncontiguous corpus
      # have been matched in the larger corpus
      def initialize_match_check
        @index_matched = {}
      end

      ###
      # Record a sentence from the smaller, noncontiguous corpus
      # as matched in the larger corpus
      def register_matched(hash_key)
        @index_matched[hash_key] = true
      end

      ###
      # Call this method after all sentences from the larger corpus
      # have been checked against the smaller corpus.
      # This method prints a warning message for each sentence from the smaller corpus
      # that has not been matched,
      # and yields it in the same format as each_window(),
      # such that the unmatched sentences can still be processed,
      # but without a larger context.
      def each_unmatched(all_keys,
                         temptable_obj)

        num_unmatched = 0

        all_keys.each_key { |hash_key|
          unless @index_matched[hash_key]
            # unmatched sentence:

            num_unmatched += 1

            # retrieve
            query_result = temptable_obj.query(SQLQuery.select([ SelectTableAndColumns.new(temptable_obj, ["sent"]) ],
                                                               [ ValueRestriction.new("hashkey", hash_key) ]))

            # report and yield
            query_result.each { |row|

              sent_string = SQLQuery.unstringify_value(row.first.to_s)
              begin
                # report on unmatched sentence
                sent = STXML::SalsaTigerSentence.new(sent_string)
                $stderr.puts "Unmatched sentence from noncontiguous input:\n" +
                             sent.id.to_s + " " + sent.to_s

                # push the sentence through the context window,
                # filling it up with "nil",
                # and yield when we reach the target at center position.
                each_window_for_stsent(sent) { |result| yield result }
                each_remaining_target { |result| yield result }

              rescue
                # Couldn't turn it into a SalsaTigerSentence object:
                # just report, don't yield
                $stderr.puts "Unmatched sentence from noncontiguous input (raw):\n" +
                             sent_string
                $stderr.puts "ERROR: cannot process this sentence, skipping."
              end
            }
          end
        }

        $stderr.puts "Unmatched sentences: #{num_unmatched} all in all."
      end

    end
  end
end
