# name: 
# auth: albu@coli.uni-sb.de
# 
# CLASS:GetMorph 
#
# INIT: (Name of morphology, Filename) 
#       e.g. GetMorph.new("gertwol","/proj/llx/Tiger/tiger-gesamt_lemmas.gertwol")
#       file of the form:
#       word        POS     lem: "SomeLemma" 
#       word        POS     lem: --
#
# FUNC: 1. get_lemma(word,pos) ==> lemma    
#       2. lemma2word(lemma) ==> word (delete morphology-specific annotations)
#       3. lemma2parts(lemma) ==> (full lemma, part1, part2 ...) 
#          e.g.
#          lemma2parts(house#wife) ==> [housewife,wife] 
#
# ATTENTION!!!! On the first call, this script generates a hash
# and stores it as /tmp/lemmaIndex_blablah_USERNAME.rb
# Please make sure that this is possible.
# If this file is already there, it is used.
# If you change the morphology, you have to delete this file 
# by hand such that a new one is generated.


#require "#{ENV['HOME']}/.load_paths.rb"

class GetMorph

##### NOT Morphology Specific
  
  def initialize(morphology,file)
    @Morphology = morphology
    base = File::basename(file)
    # read in (or create and store) lemma index
    @Lemma_index_file =  "/tmp/lemmaIndex_#{base}_#{ENV['USER']}.rb"
    if File.exist?(@Lemma_index_file) then
      file = open(@Lemma_index_file,"r")
      @Lemmas = Marshal.load(file)
    else
      puts "generating lemma hash ====> #{@Lemma_index_file}"
      @Lemmas = make_lemma_index(file)
      file = open(@Lemma_index_file,"w")
      Marshal.dump(@Lemmas,file)
    end
  end
  
  def get_lemma(word,pos)
    if @Lemmas.has_key?(word) && @Lemmas[word].has_key?(pos) then 
      @Lemmas[word][pos]
    else 
      # KE 13.4.05: Please not that many messages!
      #   $stderr.puts "No lemma for #{word} (#{pos})"
      ""
    end
  end
  
  def make_lemma_index(file)
    lemmas = Hash.new
    open(file) {|file|
      file.each {|line|
	line =~ /(.+?)\t(\w+).*lem:\s*(.*?)\s.*/
	word = $1
	pos = $2
	lemma = $3
	if word then
	  if lemmas[word] then
	    if lemmas[word][pos] && (lemmas[word][pos] != "--") then
	      if lemmas[word][pos] != lemma && lemma != "--" then
		$stderr.puts "GetMorph.new: word #{word} has more than one lemma (#{lemmas[word][pos]}, #{lemma})"
	      end
	    else
	      lemmas[word][pos] = lemma
	    end
	  else
	    lemmas[word] = Hash[pos=>lemma]
	  end
	end
      }
    }
    lemmas
  end

  #returns [word(part),lemma]
  def last_compound_and_parts(word,pos)
    if word =~ /.*-(.*)?/ then
      [$1] + lemma2parts(get_lemma($1,pos))
    else
      [word] + lemma2parts(get_lemma(word,pos))
    end
  end


#### Morphology Specific
  
  def lemma2word(lemma)
    case @Morphology 
    when "gertwol"
      if lemma != "--" then lemma.gsub(/[\|,\~,\\,\#]/,'') 
      else ""
      end
    else
      raise "===> Morphology #{@Morphology} unknown <==="
    end
  end

  def lemma2parts(lemma)
    case @Morphology 
    when "gertwol"
      if lemma != "--" then
	split = lemma.split(/#/)
	list = []
	split.each_index{|i|
	  list << lemma2word(split.slice(i..split.length).to_s)
	}  
	return list
      else []
      end 
    else
      raise "===> Morphology #{@Morphology} unknown <==="
    end
  end

end
