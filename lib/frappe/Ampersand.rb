# @note AB: This whole thing should be obsolete on Ruby 1.9
# @note #unpack seems to work on 1.8 and 1.9 equally
require_relative 'utf_iso'

####################3
# Reformatting to and from
# a hex format for special characters

module Ampersand
  def Ampersand.hex_to_iso(str)
    return str.gsub(/&.+?;/) { |umlaut|
      if umlaut =~ /&#x(.+);/
        bla = $1.hex
        bla.chr
      else
        umlaut
      end
    }
  end

  def Ampersand.iso_to_hex(str)
    return utf8_to_hex(UtfIso.from_iso_8859_1(str))
  end

  def Ampersand.utf8_to_hex(str)
    arr=str.unpack('U*')
    outstr = ""
    arr.each { |num|
      if num <  0x80
        outstr << num.chr
      else
        outstr.concat sprintf("&\#x%04x;", num)
      end
    }
    return outstr
  end
end
