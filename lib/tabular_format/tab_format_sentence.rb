require "ruby_class_extensions"
require_relative 'tab_format_named_args'

#################################################
# class for keeping and yielding one sentence
# in tabular format
class TabFormatSentence
  ############
  # initialize:
  # the sentence will be stored one word (plus additional info
  # for that word) per line. Each line will be stored in a cell of
  # the array @lines. the 'initialize' method starts with an empty
  # array of lines.
  def initialize(pattern)
    @lines = []
    @pattern = pattern

    # this is just for inheritance; FNTabFormatSentence will need this
    @group_no = nil
  end

  #####
  # length: number of words in the sentence
  def length
    @lines.length
  end

  ################3
  # add_line:
  # add one entry to the @lines array, i.e. information for one word
  # of the sentence.
  def add_line(line)
    @lines << line
  end

  ###################
  # empty?:
  # returns true if there are currently no lines stored in this
  # TabFormatSentence object
  # else false
  def empty?
    @lines.empty?
  end

  ######################
  # empty!:
  # discards all entries to the @lines array,
  # i.e. empties this TabFormatSentence object of all
  # data
  def empty!
    @lines.clear
  end

  #####################
  # each_line:
  # yields each line of the sentence
  # as a string
  def each_line
    @lines.each { |l| yield l }
  end

  ######################
  # each_line_parsed:
  # yields each line of the sentence
  # broken up as follows:
  # the line is expected to contain 6 or more pieces of
  # information, separated by whitespace.
  # - the word
  # - the part of speech info for the word
  # - syntax for roles (not to be used)
  # - target (or -)
  # - gramm. function for roles (not to be used)
  # - one column with role annotation
  #
  # All pieces are yielded as strings, except for the argument columns, which
  # are yielded as an array of strings.
  def each_line_parsed
    lineno = 0
    f = nil
    @lines.each { |l|
      f = TabFormatNamedArgs.new(l.split("\t"), @pattern, @group_no)
      f.add_feature("lineno", lineno)
      yield f
      lineno += 1
    }
  end

  ###
  # read_one_line:
  # return a line of the sentence specified by its number
  def read_one_line(number)
    @lines[number]
  end

  ###
  # read_one_line_parsed:
  # like get_line, but the features in the line are returned
  # separately,
  # as in each_line_parsed
  def read_one_line_parsed(number)
    if @lines[number].nil?
      return nil
    else
      f = TabFormatNamedArgs.new(@lines[number].split("\t"), @pattern, @group_no)
      f.add_feature("lineno", number)
      return f
    end
  end

  # set line no of first line of present sentence
  def set_starting_line(n)
    raise "Deprecated"
  end

  # returns line no of first line of present sentence
  def get_starting_line
    raise "Deprecated"
  end
end
