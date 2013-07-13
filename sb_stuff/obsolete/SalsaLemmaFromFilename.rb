#############################################
###############################################################
# helper module:
# given a Salsa subcorpus filename,
# extract the lemma from it
module SalsaLemmaFromFilename
  # determine_lemma_from_filename:
  #
  # try to extract the lemma from the filename
  # naming convention: lemma comes first, then possibly multiple annotator names,
  # all separated by _. The filename ends in .xml.
  def determine_lemma_from_filename(filename) # string: filename
    if filename.nil?
      return nil
    end

    if filename =~ /(^|\/)([^_\/]+).*\.xml$/
      return $2
    else
      $stderr.puts "Couldn't determine lemma in "+filename
      return nil
    end
  end
end


