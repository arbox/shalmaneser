###########
# KE dec 7, 06
# common mixin for both Treetagger modules, doing the actual processing

require 'tempfile'
require 'pathname'

module Shalmaneser
  module Frappe
    module TreetaggerModule
      ###
      # Treetagger does both lemmatization and POS-tagging.
      # However, the way the SynInterface system is set up in Shalmaneser,
      # each SynInterface can offer only _one_ service.
      # This means that we cannot do a SynInterface that writes
      # both a POS file and a lemma file.
      # Instead, both will include this module, which does the
      # actual TreeTagger call and then stores the result in a file
      # of its own, similar to the 'outfilename' given to TreetaggerInterface.process_file
      # but with a separate extension.
      # really_process_file checks for existence of this file because,
      # if the TreeTagger lemmatization and POS-tagging classes are called separately,
      # one of them will go first, and the 2nd one will not need to do the
      # TreeTagger call anymore
      #
      # really_process_file returns a filename, the name of the file containing
      # the TreeTagger output with both POS tags and lemma information
      #
      # WARNING: this method assumes that outfilename contains a suffix
      # that can be replaced by .TreeTagger
      def really_process_file(infilename, # string: name of input file
                              outfilename, # string: name of file that the caller is to produce
                              make_new_outfile_anyway = false) # Boolean: run TreeTagger in any case?

        # fabricate the filename in which the
        # actual TreeTagger output will be placed:
        # <directory> + <outfilename minus last suffix> + ".TreeTagger"
        current_suffix = outfilename[outfilename.rindex(".")..-1]
        my_outfilename = File.dirname(outfilename) + "/" +
                         File.basename(outfilename, current_suffix) +
                         ".TreeTagger"

        ##
        # does it exist? then just return it
        if !make_new_outfile_anyway && File.exist?(my_outfilename)
          my_outfilename
        end

        ##
        # else construct it, then return it
        tempfile = Tempfile.new("Treetagger")
        TreetaggerInterface.fntab_words_to_file(infilename, tempfile, "<EOS>", "iso")
        tempfile.close

        # @todo AB: Remove it by my shame :(
        # AB: A very dirty hack of mine:
        # We need the language attribute, but we don't have the FrappeConfigData,
        # then we'll try to find it in the ObjectSpace since we should have only one.
        lang = ''
        ObjectSpace.each_object(::Shalmaneser::Configuration::FrappeConfigData) do |o|
          lang = o.get('language')
        end

        case lang
        when 'en'
          tt_model = Pathname.new(@program_path).join('lib').join(ENV['SHALM_TREETAGGER_MODEL'] || 'english.par')
          tt_filter = ''
        when 'de'
          tt_model = Pathname.new(@program_path).join('lib').join(ENV['SHALM_TREETAGGER_MODEL'] || 'german.par')
          tt_filter = "#{Pathname.new(@program_path).join('cmd').join('filter-german-tags')}"
        end

        # call TreeTagger
        tt_binary = Pathname.new(@program_path).join('bin').join(ENV.fetch('SHALM_TREETAGGER_BIN', 'tree-tagger'))

        invocation_str = "#{tt_binary} -lemma -token -sgml #{tt_model} "\
                         "#{tempfile.path} 2>/dev/null | #{tt_filter} > #{my_outfilename}"

        STDERR.puts "*** Tagging and lemmatizing #{tempfile.path} with TreeTagger."
        STDERR.puts invocation_str

        Kernel.system(invocation_str)
        tempfile.close(true) # delete first tempfile

        # external problem: sometimes, the treetagger keeps the last <EOS> for itself,
        # resulting on a .tagged file missing the last (blank) line

        original_length = File.readlines(infilename).size
        lemmatised_length = File.readlines(infilename).size

        case (original_length - lemmatised_length)
        when 0
        # everything ok, don't do anything
        when 1
          # @todo Add here a Logger Warning.
          # add one more newline to the .tagged file
          `echo "" >> #{my_outfilename}`
        else
          # this is "real" error
          LOGGER.fatal "Original length: #{original_length}\tLemmatised length: #{lemmatised_length}"
          LOGGER.fatal "Error: lemmatiser/tagger output for for #{File.basename(infilename)} "\
                       "has different line number from corpus file!"
          raise
        end

        my_outfilename
      end
    end
  end
end
