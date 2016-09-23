require 'fred/file_zipped'
require 'fred/abstract_fred_feature_access'

require 'fred/fred_conventions' # !!

module Shalmaneser
  module Fred
        ########################################
    # MetaFeatureAccess:
    # write all featurization data to one gzipped file,
    # directly writing the meta-features as they come
    # format:
    #
    # lemma pos id sense
    #   <feature_type>: <features>
    #
    # where feature_type is a word, and features is a list of words, space-separated

    class MetaFeatureAccess < AbstractFredFeatureAccess
      ###
      def initialize(exp, dataset, mode)
        super(exp, dataset, mode)

        @filename = MetaFeatureAccess.filename(@exp, @dataset)

        # make filename for writing features
        case @mode

        when "w", "a", "r"
          # read or write access
          @f = FileZipped.new(@filename, mode)

        else
          $stderr.puts "MetaFeatureAccess error: illegal mode #{mode}"
          exit 1
        end
      end


      ####
      def MetaFeatureAccess.filename(exp, dataset, mode="new")
        return ::Shalmaneser::Fred.fred_dirname(exp, dataset, "meta_features", mode) +
          "meta_features.txt.gz"
      end

      ####
      def MetaFeatureAccess.remove_feature_files(exp, dataset)
        filename = MetaFeatureAccess.filename(exp, dataset)
        if File.exists?(filename)
          File.delete(filename)
        end
      end


      ###
      # read items, yield one at a time
      #
      # format: tuple consisting of
      # - target_lemma: string
      # - target_pos: string
      # - target_ids: array:string
      # - target SID: string, sentence ID
      # - target_senses: array:string
      # - feature_hash: feature_type->values, string->array:string
      def each_item
        unless @mode == "r"
          $stderr.puts "MetaFeatureAccess error: cannot read file not opened for reading"
          exit 1
        end

        lemma = pos = sid = ids = senses = nil

        feature_hash = {}

        @f.each { |line|
          line.chomp!
          if line =~ /^\s/
            # line starts with whitespace: continues description of previous item
            # that is, if we have a previous item
            #
            # format of line:
            #    feature_type: feature feature feature ...
            # as in
            #    CH: SB#expansion#expansion#NN# OA#change#change#NN#
            unless lemma
              $stderr.puts "MetaFeatureAccess error: unexpected leading whitespace"
              $stderr.puts "in meta-feature file #{@filename}, ignoring line:"
              $stderr.puts line
              next
            end

            feature_type, *features = line.split

            unless feature_type =~ /^(.*):$/
              # feature type should end in ":"
              $stderr.puts "MetaFeatureAccess error: feature type should end in ':' but doesn't"
              $stderr.puts "in meta-feature file #{@filename}, ignoring line:"
              $stderr.puts line
              next
            end

            feature_hash[feature_type[0..-2]] = features


          else
            # first line of item.
            #
            # format:
            # lemma POS IDs sid senses
            #
            # as in:
            # cause verb 2-651966_8 2-651966 Causation

            # first yield previous item
            if lemma
              yield [lemma, pos, ids, sid, senses, feature_hash]
            end

            # then start new item:
            lemma, pos, ids_s, sid, senses_s = line.split
            ids = ids_s.split("::").map { |i| i.gsub(/COLON/, ":") }
            senses = senses_s.split("::").map { |s| s.gsub(/COLON/, ":") }

            # reset feature hash
            feature_hash.clear
          end
        }

        # one more item to yield?
        if lemma
          yield [lemma, pos, ids, sid, senses, feature_hash]
        end
      end



      ###
      def write_item(lemma,  # string: target lemma
                     pos,    # string: target pos
                     ids,    # array:string: unique IDs of this occurrence of the lemma
                     sid,    # string: sentence ID
                     senses, # array:string: sense
                     features) # features: hash feature type-> features (string-> array:string)

        unless ["w", "a"].include? @mode
          $stderr.puts "MetaFeatureAccess error: cannot write to feature file opened for reading"
          exit 1
        end

        if not(lemma) or lemma.empty? or not(ids) or ids.empty?
          # nothing to write
          # HIER debugging
          # raise "HIER no lemma or no IDs: #{lemma} #{ids}"
          return
        end
        if pos.nil? or pos.empty?
          # POS unknown
          pos = ""
        end
        unless senses
          senses = [ @exp.get("noval") ]
        end

        ids_s = ids.map { |i| i.gsub(/:/, "COLON") }.join("::")

        senses_s = senses.map { |s| s.gsub(/:/, "COLON") }.join("::")
        @f.puts "#{lemma} #{pos} #{ids_s} #{sid} #{senses_s}"
        features.each_pair { |feature_type, f_list|
          @f.puts "   #{feature_type}: " + f_list.map { |f| f.to_s }.join(" ")
        }
        @f.flush
      end

      ###
      def flush
        unless ["w", "a"].include? @mode
          $stderr.puts "MetaFeatureAccess error: cannot write to feature file opened for reading"
          exit 1
        end

        # actually, nothing to be done here
      end

    end

  end
end
