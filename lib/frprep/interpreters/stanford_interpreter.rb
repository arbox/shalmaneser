# AB: 2013-12-25
class StanfordInterpreter < Tiger
  StanfordInterpreter.announce_me

  ###
  # names of the systems interpreted by this class:
  # returns a hash service(string) -> system name (string),
  # e.g.
  # { "parser" => "collins", "lemmatizer" => "treetagger" }
  def self.systems
    {"parser" => "stanford"}
  end

  ###
  # names of additional systems that may be interpreted by this class
  # returns a hash service(string) -> system name(string)
  # same as names()
  def self.optional_systems
    {"lemmatizer" => "treetagger", 'pos_tagger' => 'treetagger'}
  end

end
