# sp 28 06 04
#
# this module offers methods to extract gemma corpora from the FrameNet database#

require 'frprep/FrameXML'

class FNDatabase
    
  def each_matching_sentence(file_pred,sent_pred)     
    # fundamental access function to FrameXML files

    # returns file objects where
    # FrameXMLSentence matches sent_pred
    # (FrameXMLFile is accessed through FrameXMLSentence.get_file_object and matches file_pred)
    each_matching_file(file_pred) {|frameNetFile|    
      frameNetFile.each_sentence {|frameNetSent|
	if sent_pred.call(frameNetSent)
	  frameNetSent.verify_annotation
	  yield frameNetSent
	end
      }
    }
  end 
  
  def each_matching_file(file_pred)   
    # fundamental access function to FrameXML files

    # returns file (FrameXMLFile) objects which match file_pred
    each_framexml_file{|frameNetFile|    
      if file_pred.call(frameNetFile)
	yield frameNetFile
      end
      frameNetFile.close
    }
  end
    
  def extract_frame(frame,outfile)
    each_matching_sentence(Proc.new{|fnfile| fnfile.get_frame == frame},
			   Proc.new{|fnsent| true}) {|fnsent|
      if fnsent.contains_FE_annotation_and_target
	fnsent.print_conll_style_to(outfile)
      end
    }
  end
  
  def extract_lemma(lemma,outfile) 
    each_matching_sentence(Proc.new{|fnfile| fnfile.get_lu == lemma},
			   Proc.new{|fnsent| true}) {|fnsent|
      if fnsent.contains_FE_annotation_and_target
	fnsent.print_conll_style_to(outfile)
      end
    }
  end

  def extract_everything(outdirectory)
    unless outdirectory[-1,1] == "/"
      outdirectory += "/"
    end

    outfiles = Hash.new
    each_matching_sentence(Proc.new{|fnfile| true},
			   Proc.new{|fnsent| true}) {|fnsent|
      frame = fnsent.get_file_obj.get_frame
      unless outfiles.key?(frame)
	outfiles[frame] = File.new(outdirectory+frame+".tab","w")
      end
      if fnsent.contains_FE_annotation_and_target
	fnsent.print_conll_style_to(outfiles[frame])
      end
    }
    # close output files
    outfiles.each_value {|file|
      file.close
    }
    # remove zero-size files
    Dir[outdirectory+"*"].each {|filename|
      if FileTest.zero?(filename)
	File.unlink(filename)
      end
    }
  end
    
    
  def initialize(fn_path)
    unless fn_path[-1,1] == "/"
      fn_path += "/"
    end
    @fn = fn_path
  end
  
  private 

  def each_framexml_file
    # files might be zipped
    Dir[@fn+"lu*.xml.gz"].each {|gzfile| 
      Kernel.system("cp "+gzfile+" /tmp/")
      Kernel.system("gunzip -f /tmp/"+File.basename(gzfile))
      gzfile =~ /(.+)\.gz/
      yield FrameXMLFile.new("/tmp/"+File.basename($1))
    }
    # or might not
    Dir[@fn+"/lu*.xml"].each {|filename|
      yield FrameXMLFile.new(filename)
    }
  end

  # I  don't really remember what this was good for ;-)

#   def browse_everything(allFiles)
#     if allFiles
#       Dir[fn+"*.xml.gz"].each {|gzfile|
# 	Kernel.system("cp "+gzfile+" /tmp/")
# 	Kernel.system("gunzip -f /tmp/"+File.basename(gzfile))
# 	gzfile =~ /(.+)\.gz/
# 	#    STDERR.puts File.basename($1)
# 	#    STDERR.print "."
# 	ff = FrameXMLFile.new("/tmp/"+File.basename($1))
# 	ff.each_sentence {|s|
# 	  if s.contains_FE_annotation_and_target
# 	    s.verify_annotation  
# 	    if s.verify_annotation
# 	    puts "****************** Error: Still problems after 2nd verification!"
# 	    end
# 	    s.print_conll_style
# 	  end
# 	}
#       }
#     else
#       ff = FrameXMLFile.new("/tmp/lu1870.xml")
#       ff.each_sentence {|s|
# 	if s.contains_FE_annotation_and_target
# 	  s.verify_annotation
# 	if s.verify_annotation
# 	  puts "****************** Error: Still problems after 2nd verification!"
# 	end
# 	  #      s.print_layers
# 	  s.print_conll_style
# 	end
#       }
#     end
#   end
  
end

