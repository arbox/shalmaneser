require "tempfile"
require "StandardPkgExtensions"
class Array
  include EnumerableBool
end

module PlotAndREval

  ############
  # given a set of mappings x_axis_value -> y_axis_value,
  # plot them all within the same gnuplot graph
  #
  # scores: 
  # either hash: score_label(string) -> hash x_axis(float) -> y_axis(float)
  # or hash: score_label(string) -> array [x_axis(float), y_axis(float)]
  def PlotAndREval.gnuplot_direct(scores,     
                                  title,      # string: title for output files
                                  x_name,     # string: label for x axis
                                  y_name,     # string: label for y axis
                                  plotoutfile, # string: name of gnuplot output file
                                  data_style = "linespoints") # data style

    # for each score label: write x_axis/y_axis pairs to a separate tempfile
    score_file = Hash.new
    scores.each_pair { |score_label, score_values|
      score_file[score_label] = Tempfile.new("PlotAndREval")
      score_values.to_a.sort { |a, b|  a.first <=> b.first}.each { |x_val, y_val|
        score_file[score_label].puts "#{x_val} #{y_val}"
      }
      score_file[score_label].close()
    }

    # write command file for gnuplot
    gf = Tempfile.new("PlotAndREval")

    gf.puts "set title \"" + title + "\""
    gf.puts "set ylabel \""+ y_name + "\""
    gf.puts "set xlabel \""+ x_name + "\""
    gf.puts "set time"
    gf.puts "set data style " + data_style
    gf.puts "set grid"
    gf.puts "set output \"" + plotoutfile + "\""
    gf.puts "set terminal postscript color"


    gf.print "plot "
    gf.puts score_file.to_a.map { |score_label, tempfile|
      # plot "<filename>" using "<title>", "<filename>" using "<title>",...
      "\"" + tempfile.path() + "\"" + " title \"" + score_label + "\""
    }.join(", ")
    # finalize tempfile
    gf.close()

    %x{gnuplot #{gf.path()}}
  end

  #################
  # Given a list of pairs [x, y], 
  # group them into N bins (by splitting the range from min score to max score)
  # compute the average y for each x bin, and plot
  def PlotAndREval.gnuplot_average(scores, # array of pairs [x(float), y(float)
                                   title,  # string: title for output file
                                   x_label, # label for x axis
                                   y_label, # label for y axis
                                   plotoutfile, # string: name of gnuplot output file
                                   min_value, # float: minimum value
                                   bin_size) # float: size of one bin

    # sort scores into bins
    bin = Hash.new()
    
    scores.each { |xval, yval|
      bin_no = (xval - min_value / bin_size).floor
      unless bin[bin_no]
        bin[bin_no] = Array.new
      end
      bin[bin_no] << yval
    }

    # print average for each bin to temp infile for gnuplot
    tf = Tempfile.new("plot_and_r")
    
    bin.keys.sort.each { |bin_no|
      if bin[bin_no].length() > 0
        avg = (bin[bin_no].big_sum(0.0) { |yval| yval }) / bin[bin_no].length().to_f
      else
        avg = 0.0
      end
      val = min_value + (bin_no.to_f * bin_size)
      tf.print val, "\t", avg, "\n"
    }
    tf.close()
    
    # make gnuplot main infile
    gf = Tempfile.new("plot_and_r")
    gf.puts "set title \"#{title}\""
    gf.puts "set ylabel \"#{y_label}\""
    gf.puts "set xlabel \"#{x_label}\""
    gf.puts "set time"
    gf.puts "set data style linespoints"
    gf.puts "set grid"
    gf.puts "set output \"" + plotoutfile + "\""
    gf.puts "set terminal postscript color"
    gf.print "plot \"#{tf.path()}\" title \"#{y_label}\""
    gf.puts
    gf.puts
    gf.close()
    
    # now gnuplot it
    %x{gnuplot #{gf.path()}}

    # and remove temp files
    tf.close(true)
    gf.close(true)
  end
  
  #################
  # given a mapping from labels to scores,
  # split the range form min. score to max. score into
  # 20 bins, sort the label/score pairs into the bins,
  # and gnuplot them as a bar graph of 20 bars.
  #
  # A title for the graph must be given, and a 
  # name for the gnuplot output file.
  # If the name of a text output file is given,
  # the result is also printed as text.
  #
  # If minvalue and maxvalue are given, they are used 
  # as start and end of the scale instead of the
  # min. and max. values from the scores hash.
  def PlotAndREval.gnuplot_quantity_chart(scores, # hash:label(string) -> value(float), label->score-mapping
                                          title,  # string: title for output files
                                          score_name, # string: what are the scores? (label for y axis)
                                          plotoutfile, # string: name of gnuplot output file
                                          textoutfile = nil, # string: name of text output file
                                          minvalue=nil, # float: minimum value for y axis
                                          maxvalue=nil) # float: maximum value for y axis
    

    # group scores in 20 subgroups
    # first determine minimum, maximum score, single interval
    if minvalue.nil?
      minvalue = 1.0/0.0 # infinity
      scores.values.each { |score|
        minvalue = [score, minvalue].min
      }
    end
    if maxvalue.nil?
      maxvalue = -1.0/0.0 # -infinity
      scores.values.each { |score|
        maxvalue = [score, maxvalue].max
      }
    end
    
    interval = (maxvalue - minvalue) / 20.0
    
    # now compute the number of scores in each interval
    num_in_range = Hash.new(0)
    
    scores.each_pair { |label, score|
      num = (score / interval).floor
      num_in_range[num] += 1
    }

    # open output files:
    # text output, temp files for gnuplot
    if textoutfile
      textout = File.new(textoutfile, "w")
      
      # document number of scores in each range
      # to text outfile
      textout.puts "-------------------------"
      textout.puts title
      textout.puts "-------------------------"
      
    num_in_range.keys.sort.each { |rangeno|
        range_lower = interval * rangeno.to_f
        textout.print "number of values btw. ", sprintf("%.2f", range_lower),
        " and ", sprintf("%.2f", range_lower + interval), ": ", 
        num_in_range[rangeno], "\n"
      }
      
      textout.close()
    end
    
    # document number of scores in each range
    # to temp. infile for gnuplot
    tf = Tempfile.new("plot_and_r")
    
    0.upto(19) { |rangeno|
      range_lower = interval * rangeno.to_f
      tf.print range_lower, "\t", num_in_range[rangeno], "\n"
    }
    tf.close()
    
    # make gnuplot main infile
    gf = Tempfile.new("plot_and_r")
    gf.puts "set title \"" + title+ "\""
    gf.puts "set ylabel \"num items\""
    gf.puts "set xlabel \"" + score_name + "\""
    gf.puts "set time"
    gf.puts "set data style boxes"
    gf.puts "set boxwidth " + (interval/2.0).to_s
    gf.puts "set grid"
    gf.puts "set output \"" + plotoutfile + "\""
    gf.puts "set terminal postscript color"
    gf.print "plot \"" + tf.path() + "\" title \"" + score_name + "\" with boxes"
    gf.puts
    gf.puts
    gf.close()
    
    # now gnuplot it
    %x{gnuplot #{gf.path()}}

    # and remove temp files
    tf.close(true)
    gf.close(true)
  end


  #####
  # draws a scatter plot comparing two
  # mappings from labels to scores
  # the first (base) scores are drawn on the x axis,
  # the second (comparison) scores are drawn on the y axis.
  # The method only looks at labels present in the base score,
  # so if a label is present only in the comparison score but not the base score
  # it is ignored.
  def PlotAndREval.gnuplot_correlation_chart(base_scores, # hash: label(string) -> value(float)
                                             comparison_scores, # hash: label(string) -> value(float)
                                             title,  # string: title for output files
                                             base_name, # string: what are the base scores?
                                             comparison_name, # string: what are the comparison scores?
                                             plotoutfile, # string: name of gnuplot output file
                                             textoutfile = nil) # string: name of text output file
    
    # text output: base score/comparison score pairs
    if textoutfile
      begin
        textout = File.new(textoutfile, "w")
      rescue
        raise "Couldn't write to " + textoutfile
      end
      
      textout.puts "------------------------"
      textout.puts title
      textout.puts "------------------------"
      
      # text output: base score / comparison score pairs
      base_scores.to_a.sort { |a, b| b.last <=> a.last }.each { |label, score|
        
        textout.print label, ": ", base_name, ": ", score, ", ", comparison_name, ": "
        if comparison_scores[label]
          textout.print comparison_scores[label], "\n"
        else
          textout.print "--", "\n"
        end   
      }
    end
  

    # make scatter plot: base vs. comparison
    
    tf = Tempfile.new("plot_and_r")
    base_scores.each_pair { |label, score|
      if comparison_scores[label]
        tf.print score, "\t", comparison_scores[label], "\n"
      else
        $stderr.puts "no comparison scores for " + label
      end
    }
    tf.close()
    
    # make gnuplot main infile
    gf = Tempfile.new("plot_and_r")
    gf.puts "set title \"" + title + "\""
    gf.puts "set ylabel \"" + comparison_name + "\""
    gf.puts "set xlabel \"" + base_name + "\""
    gf.puts "set time"
    gf.puts "set data style points"
    gf.puts "set grid"
    gf.puts "set output \"" + plotoutfile + "\""
    gf.puts "set terminal postscript color"
    gf.puts "plot \"" + tf.path() + "\""
    gf.puts
    gf.close()
    
    # now gnuplot it
    %x{gnuplot #{gf.path()}}
    tf.close(true)
    gf.close(true)  
  end


  # given two mappings from labels to scores,
  # draw a gnuplot drawing comparing them
  # as box scores:
  # sort the first mapping by scores (in descending order),
  # then for each label draw first the score from the first mapping
  # as a box, then the score from the second mapping
  # as a differently colored box.
  #
  # Scores1 is the basis for the comparison: only those labels
  # are used that occur in mapping 1 are included in the comparison
  #
  # A title for the graph must be given, and a 
  # name for the gnuplot output file.
  # If the name of a text output file is given,
  # the result is also printed as text.
  def PlotAndREval.gnuplot_comparison_chart(scores1, # hash:label(string) -> value(float), label->score-mapping
                                            scores2, # hash:label(string) -> value(float), label->score-mapping
                                            title,  # string: title for output files
                                            score_name, # string: what are the scores? (label for y axis)
                                            plotoutfile, # string: name of gnuplot output file
                                            textoutfile = nil) # string: name of text output file
    

    # text output
    if textoutfile
      textout = File.new(textoutfile, "w")
      
      # document scores in each range
      # to text outfile
      textout.puts "-------------------------"
      textout.puts title
      textout.puts "-------------------------"
      textout.puts "Label\tScore 1\tScore 2"

      scores1.to_a.sort { |a, b| b.last <=> a.last}.each { |label, score1|
        textout.print label, "\t", score1, "\t"
        score2 = scores2[label]
        if score2
          textout.print score2, "\n"
        else
          textout.print "-", "\n"
        end
      }
      textout.close()
    end
    
    # document number of scores in each mapping
    # to temp. infile for gnuplot
    tf1 = Tempfile.new("plot_and_r")
    tf2 = Tempfile.new("plot_and_r")
    
    index = 0.0
    scores1.to_a.sort { |a, b| b.last <=> a.last}.each { |label, score1|
      score2 = scores2[label]
      tf1.print index, "\t", score1, "\n"
      if score2
        i2 = index + 0.2
        tf2.print i2, "\t", score2, "\n"
      end
      index += 1.0
    }

    tf1.close()
    tf2.close()
    
    # make gnuplot main infile
    gf = Tempfile.new("plot_and_r")
    gf.puts "set title \"" + title+ "\""
    gf.puts "set ylabel \"" + score_name + "\""
    gf.puts "set time"
    gf.puts "set boxwidth 0.2"
    gf.puts "set noxtics"
    gf.puts "set grid"
    gf.puts "set output \"" + plotoutfile + "\""
    gf.puts "set terminal postscript color"
    gf.print "plot \"" + tf1.path() + "\" title \"score 1\" with boxes fs solid 0.9,"
    gf.puts "\"" + tf2.path() + "\" title \"score 2\" with boxes fs solid 0.6"
    gf.puts
    gf.puts
    gf.close()
    
    # now gnuplot it
    %x{gnuplot #{gf.path()}}

    # and remove temp files
    tf1.close(true)
    tf2.close(true)
    gf.close(true)
  end


  #####
  #
  # computes a nonparametric rank correlation
  #
  # can compute partial correlations, i.e. correlations which factor out the influence
  # of a confound variable (last variable, can be omitted).
  
  def PlotAndREval.tau_correlation(base_scores, # hash: label(string) -> value(float)
                                   comparison_scores, # hash: label(string) -> value(float)
                                   base_name, # string: what are the base scores?
                                   comparison_name, # string: what are the comparison scores?
                                   textoutfile, # string: name of text output file
				   confound_scores = nil) # hash: label(string) -> value(float)

    # compute Kendall's tau:
    # correlation between fscore and confusion?
    tf_f = Tempfile.new("plot_and_r")
    tf_e = Tempfile.new("plot_and_r")
    if confound_scores
      tf_c = Tempfile.new("plot_and_r")
    end
    base_scores.each_pair { |label, score|
      if comparison_scores[label]
        tf_f.puts score.to_s
        tf_e.puts comparison_scores[label].to_s
	if confound_scores
	  if confound_scores[label]
            # logarithmise frequencies 
	    tf_c.puts((Math.log(confound_scores[label])).to_s)
	  else
	    $stderr.puts "no confound scores for " + label
	  end	  
	end
      else
	$stderr.puts "no comparison scores for " + label
      end
    }
    tf_e.close()
    tf_f.close()
    if confound_scores
      tf_c.close()
    end

    # write the R script to rf
    rf = Tempfile.new("plot_and_r")
    # write the output to rfout
    rfout = Tempfile.new("plot_and_r")
    rfout.close()


    if confound_scores # perform partial correlation analysis
      rf.puts "base <- read.table(\"#{tf_f.path()}\")"
      rf.puts "comparison <- read.table(\"#{tf_e.path()}\")"
      rf.puts "confuse <- read.table(\"#{tf_c.path()}\")"
      # adapted from https://stat.ethz.ch/pipermail/r-help/2001-August/012820.html
      # compute partial correlation coefficient for comparison, with confuse excluded
      rf.puts "cor(lm(base[[1]]~confuse[[1]])$resid,lm(comparison[[1]]~confuse[[1]])$resid,method=\"kendall\")"

  # compute partial correlation coefficient for confuse, with comparison excluded
      rf.puts "cor(lm(base[[1]]~comparison[[1]])$resid,lm(confuse[[1]]~comparison[[1]])$resid,method=\"kendall\")"

      # compute significance of partial correlation
      rf.puts "summary(lm(base[[1]] ~ comparison[[1]] + confuse[[1]]))"      
    else # perform normal correlation analysis
      rf.puts "base <- read.table(\"#{tf_f.path()}\")"
      rf.puts "comparison <- read.table(\"#{tf_e.path()}\")"
      rf.puts "cor.test(base[[1]], comparison[[1]], method=\"kendall\", exact=FALSE)"
    end 
    rf.close()
    %x{/proj/contrib/R/R-1.8.0/bin/R --vanilla < #{rf.path()} > #{rfout.path()}}
    rfout.open()
    
    # output of R results: to stderr and to textout file
    begin
      textout = File.new(textoutfile, "w")
    rescue
      raise "Couldn't write to file " + textoutfile
    end

    textout.puts "-----------------------"
    textout.puts "Correlation of " + base_name + " and " + comparison_name + " by Kendall's tau:"
    textout.puts "-----------------------"

    while (line = rfout.gets())
      $stderr.puts "R output: " + line
      textout.puts "R output: " + line
    end

    tf_e.close(true)
    tf_f.close(true)
    rf.close(true)
    rfout.close(true)
    textout.close()
  end
end
