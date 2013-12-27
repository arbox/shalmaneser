# Alexander Koller 2003
# extended Katrin Erk June 2003
#
# Classes that return a list of sentence DOMs, from various sources
#
# Each class in this file defines the following methods:
#
#   initialize(...)     "..." depends on the class
#   extractDOMs()       return list of all s nodes as DOM objects
#   each_s()            iterate over s nodes; may take less memory  


require "rexml/document"

class FileParser 

  include REXML

  def initialize(filename)
    @file = File.new(filename)
    @doc = nil
  end

  # returns an array of DOMs for the sentences
  def extractDOMs()
    ensureParsedDocument()
    @doc.get_elements("/corpus/body/s")
  end

  # Iterates over all sentence nodes. This may be more memory
  # efficient than using extractDOMs(), but isn't in this case.
  def each_s()
    extractDOMs().each { |dom| yield(dom) }
  end

  # Iterates over all sentence nodes. The block passed to this
  # method should return a DOM object as a value. After the iteration
  # has been completed, the contents of /corpus/body are then replaced
  # by the list of these results.
  # At the moment, this changes the FileParser object. This should
  # probably change in the future, but I don't want to mess with
  # cloning now.
  def process_s!()
    newBody = Element.new('body')
    each_s { |dom| newBody.add_element( yield(dom) ) }

    @doc.delete_element("/corpus/body")
    @doc.elements["corpus"].add_element(newBody)

    return @doc
  end



  private
  
  def ensureParsedDocument()
    if @doc == nil then
      @doc = Document.new(@file)
    end
  end

      
end




#####################################################################




class FilePartsParser
  # <@file> = File object for the corpus
  # <@head> = string up to the first <s> tag
  # <@tail> = string after the last </s> tag
  # <@rest> = string starting with the latest <s> tag (complete this to
  # a <s>...</s> structure by reading up to next </s> tag)
  # <@readCompletely> = boolean specifying whether there's still something
  # left to read in the file

  attr_reader :head, :tail

  def initialize(filename)
    @file = File.new(filename)
    @readCompletely = false
    # read stuff into @head and initialize @rest
    @head = ''
    begin
      while true do
	line = @file.readline() 
	if line =~ /(.*)(<s\s.*)/ then
	  @head = @head << $1
	  @rest = $2
	  break
	elsif line =~ /^(.*)(<\/body[\s>].*)$/
	  # empty corpus
	  @head = @head << $1
	  @tail = $2
	  while (line = @file.readline())
	    @tail << "\n" + line
	  end
	  @readCompletely = true
	  break
	else
	  @head = @head << line
	end
      end
    rescue EOFError
      @readCompletely = true
    end
  end

  def close()
    @file.close()
  end

  def extractDOMs()
    allDOMs = Array.new

    process_s!() { |dom| 
      allDOMs.push(dom) 
      Element.new("x")
    }
    return allDOMs
  end

  def each_s()
    process_s!() { |dom| 
      yield(dom) 
      Element.new("x")
    }
  end

  # This function returns the string for the modified corpus.
  # It doesn't change the internal state of the FilePartsParser,
  # and is much more memory (and probably time) efficient than
  # FileParser#process_s!.
  # The block that is called by the method is given an element
  # as its argument and is expected to return a changed element.
  def process_s!()
    if @readCompletely
      return
    end

    ret = ''
    scan_s() { |element|
      # Process the <s> ... </s> element
      doc = Document.new(element)
      elt = doc.root
      changedElt = yield(elt)

      changedEltAsString = ''
      changedElt.write(changedEltAsString, 0)
      ret <<= changedEltAsString
    }

    return ret
  end

  # KE 12.6.03: scan_s : 
  # doesn't parse a sentence before yielding it
  # doesn't allow for any changes
  # but otherwise the same as process_s!
  def scan_s()
    if @readCompletely
      return
    end
     
    begin
      while true do
	# Invariant: At this point, @rest always starts with an
	# unseen <s> tag.
	
	# First, we continue reading until we find the closing </s>
	# No exception should occur in this loop if we're parsing
	# a valid XML document.
	while @rest !~ /^(.*<\/s>)(.*)/m do
	  @rest = @rest << @file.readline()
	end

	element = $1
	@rest = $2

	yield(element) # change HERE: element not parsed!

	# Read on up to the next <s>
	while @rest !~ /(.*)(<s\s.*)/m do
	  @rest = @rest << @file.readline()
	end

	@rest = $2
      end
    rescue EOFError
      @tail = @rest
      @readCompletely = true
    end
  end

  # KE 5.11.03: get_rest: read all of the file not processed up to this point
  # and return it as a string
  def get_rest()
    begin
      while true do
	@rest = @rest << @file.readline()
      end
    rescue EOFError
      @readCompletely = true
    end
    return @rest
  end
end
