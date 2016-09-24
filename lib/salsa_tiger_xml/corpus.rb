require 'nokogiri'

module STXML
  class Corpus
    attr_reader :doc

    def initialize(filename)
      @doc = File.open(filename) do |f|
        Nokogiri::XML(f)
      end
    end

    def each_sentence
      return enum_for(:each_sentence) unless block_given?
      @doc.xpath('//s').each do |s|
        yield s
      end
    end

    def sentences
      @doc.xpath('//s')
    end

    def clear_roles
    end

    def clear_targets
    end
  end
end
