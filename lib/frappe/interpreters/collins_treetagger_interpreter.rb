require_relative 'collins_tnt_interpreter'

class CollinsTreeTaggerInterpreter < CollinsTntInterpreter
  CollinsTreeTaggerInterpreter.announce_me

  def self.systems
    {"pos_tagger" => "treetagger", "parser" => "collins"}
  end
end
