require_relative 'tab_format_file'
require_relative 'fn_tab_sentence'
require_relative 'tab_format_named_args'

########################################################
# TabFormat files containing everything that's in the FN lexunit files
#
# one target per sentence
# require "ruby_class_extensions"

class FNTabFormatFile < TabFormatFile
  def initialize(filename, tag_suffix = nil, lemma_suffix = nil)
    corpusname = File.dirname(filename) + "/" + File.basename(filename, ".tab")
    filename_label_pairs = [filename, FNTabFormatFile.fntab_format]
    # raise exception if lemmatisation does not esist
    if lemma_suffix
      filename_label_pairs.concat [corpusname + lemma_suffix, ["lemma"]]
    end
    # raise exception if tagging does not exist
    if tag_suffix
      filename_label_pairs.concat [corpusname + tag_suffix, ["pos"]]
    end
    super(filename_label_pairs)

    @my_sentence_class = FNTabSentence
  end

  def self.fntab_format
    return [
      "word",
      FNTabFormatFile.frametab_format,
      "ne", "sent_id"
    ]
  end

  def self.frametab_format
    ["pt", "gf", "role", "target", "frame", "stuff"]
  end

  ##########
  # given a hash mapping features to values,
  # format according to fntab_format
  def self.format_str(hash)
    TabFormatNamedArgs.format_str(hash, FNTabFormatFile.fntab_format)
  end
end
