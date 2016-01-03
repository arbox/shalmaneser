require "tempfile"
module Shalmaneser
  module Fred

    ####################3
    # keep writers: auxiliary class for FredFeatureAccess:
    # write to several files at a time
    # in tempfiles
    class AuxKeepWriters
      def initialize
        @lemma2temp = {}
        @size = 50
        @writers = []
      end

      ##
      def flush
        @writers.each { |lemmapos, writer|
          writer.close
        }
      end

      ##
      def get_lemmas
        @lemma2temp.keys
      end

      ##
      def get_for_reading(lemmapos)
        if @lemma2temp[lemmapos]
          # we have a writer for this

          @lemma2temp[lemmapos].close
          @lemma2temp[lemmapos].open
          return @lemma2temp[lemmapos]

        else
          # no writer for this
          return nil
        end
      end

      ##
      # finally close temp file, remove information for lemma/pos
      def discard(lemmapos)
        if @lemma2temp[lemmapos]
          @lemma2temp[lemmapos].close(true)
          @lemma2temp.delete(lemmapos)
        end
      end

      ##
      def get_writer_for(lemmapos)

        # is there a temp file for this lemma/pos combination?
        unless @lemma2temp[lemmapos]
          @lemma2temp[lemmapos] = Tempfile.new("fred_features")
          @lemma2temp[lemmapos].close
        end

        # is there an open temp file for this lemma/pos combination?
        pair = @writers.assoc(lemmapos)
        if pair
          return pair.last
        end

        # no: open the temp file, kick some other temp file out of the
        # @writers list
        writer = @lemma2temp[lemmapos]
        writer.open


        # writer: open for appending
        writer.seek(0, IO::SEEK_END)


        @writers << [lemmapos, writer]
        if @writers.length > @size
          # close file associated with first writer
          @writers.first.last.close
          @writers.shift
        end
        return writer
      end

      ###
      def remove_files
        @lemma2temp.each_value { |x|
          x.close(true)
        }
      end
    end
  end
end
