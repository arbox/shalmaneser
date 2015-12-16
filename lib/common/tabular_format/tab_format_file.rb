require_relative 'tab_format_sentence'

require "common/ruby_class_extensions"

#######################
class TabFormatFile
  #######
  # initialize:
  # open files for reading.
  #
  # fp is a list of pairs [filename, format]
  # where format is a list of strings that will be used
  # to address columns of the file, the 1st string for the 1st column
  #
  # format may contain _one_ entry that is an array (or a call to repeat())
  # e.g.:
  # ["word", "pos", "lemma", repeat("frame", "target", "gf", "pt")]
  def initialize(fp)
    # open files
    @files = Array.new
    @patterns = Array.new
    @no_of_read_lines = 0
    fp.each_index { |ix|
      if ix.modulo(2) == 0
        # filename
        begin
          @files << File.new(fp[ix])
        rescue
          raise 'Sorry, could not read input file ' + fp[ix] + "\n"
        end
      else
        # pattern
        @patterns += fp[ix]
      end
    }

    @my_sentence_class = TabFormatSentence
  end

  ########
  # each_sentence:
  # yield each sentence of the files in turn.
  # sentences are expected to be separated
  # by a line containing nothing but whitespace.
  # the last sentence may or may not be followed by
  # an empty line.
  # each_sentence ends when EOF is encountered on the first file.
  # it expects all the other files to be the same length
  # (in terms of number of lines) as the first file.
  # each sentence is returned in the form of an
  # array of TabFormatSentence sentences.
  # AB: TODO Delete this nasty exception!!!
  # @todo Change `#readline` to `#gets` to avoid Exceptions.
  # @todo Change `#gets` to `#readlines` to read all lines at once.
  def each_sentence
    unless @read_completely
      sentence = @my_sentence_class.new(@patterns)
      begin
        loop do
          linearray = []
          @files.each { |f| linearray << f.readline.chomp }

          @no_of_read_lines += 1
          if linearray.detect { |x| x.strip == '' }
            if linearray.detect { |x| x.strip != '' }
              STDERR.puts "Error: Mismatching empty lines! <from lib/common>"
              exit(1)
            else
              # sentence finished. yield it and start a new one
              unless sentence.empty?
                yield sentence
              end
              sentence = @my_sentence_class.new(@patterns)
            end
            # read an empty line in each of the other files

          else
            # sentence not yet finished.
            # add this line to it
            sentence.add_line(linearray.join("\t"))
          end
        end
      rescue EOFError
        # maybe we haven't yielded the last sentence yet.
        yield sentence unless sentence.empty?

        @read_completely = true
      end
    end
  end
end
