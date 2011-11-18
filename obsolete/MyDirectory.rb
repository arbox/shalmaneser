class ProcessDirectory
  def initialize(indir, outdir)
    @indir = indir
    @outdir = outdir
    unless @indir =~ /\/$/
      @indir = @indir + '/'
    end
    unless @outdir =~ /\/$/
      @outdir = @outdir + '/'
    end
    @prefix = ''
  end

  def add_outfile_prefix(prefix)
    @prefix = prefix
  end

  def process_dir()
    ## process each file from input directory
    Dir[@indir+"*.xml"].each { |infile|

      # construct output file name
      file = String.new(infile)
      file.slice!(/.*\//)  # cut off leading path information
      outfile = @outdir + @prefix + file

      yield [infile, outfile]
    }      
  end
end

class ReadDirectory

  def initialize(indir)
    @indir = indir
    unless @indir =~ /\/$/
      @indir = @indir + '/'
    end
  end

  def process_dir()
    ## process each file from input directory
    Dir[@indir+"*.xml"].each { |infile|

      # construct output file name
      file = String.new(infile)
      yield infile
    }      
  end
end
