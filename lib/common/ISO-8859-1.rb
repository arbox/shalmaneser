# KE changed July 05: now no inclusion of modules required,
# and names changed from REXML.Encodign to UtfIso

module UtfIso
  # Convert from UTF-8
  def UtfIso.to_iso_8859_1(content)
    array_utf8 = content.unpack('U*')
    array_enc = []
    array_utf8.each do |num|
      if num <= 0xFF
        array_enc << num
      else
        # Numeric entity (&#nnnn;); shard by  Stefan Scholl
        #	   array_enc += to_iso_8859("&\##{num};").unpack('C*')
      end
    end
    array_enc.pack('C*')
  end

  # Convert to UTF-8
  def UtfIso.from_iso_8859_1(str)
    str.unpack('C*').pack('U*')
  end
end
