# sp jul 05 05
#
# Static helper methods for SalsaTigerRegXML:

# - provide header and footer for Salsa/Tiger XML files
# - escape and unescape HTML entities
#
# changed KE nov 05:
# many methods moved to FrprepHelper

require "common/SalsaTigerRegXML"
require "common/headz"
require "common/Parser"
require "tempfile"

class SalsaTigerXMLHelper
  ###
  # get header of SalsaTigerXML files (as string)
  def self.get_header

    header = <<ENDOFHEADER
<?xml version="1.0" encoding="UTF-8"?>
  <corpus corpusname="corpus" target="">
        <head>
                <meta>
                        <format>
                        NeGra format, version 3</format>
                </meta>
                <frames xmlns="http://www.clt-st.de/framenet/frame-database">
                </frames>
                <wordtags xmlns="http://www.clt-st.de/salsa/wordtags">
                </wordtags>
                <flags>
                </flags>
                <annotation>
                        <edgelabel>
                        </edgelabel>
                        <secedgelabel>
                        </secedgelabel>
                </annotation>
        </head>
        <body>
ENDOFHEADER

    header
  end

  ###
  # get footer of SALSATigerXML files (as string)
  def self.get_footer

    footer = <<ENDOFFOOTER
        </body>
</corpus>
ENDOFFOOTER

    return footer
  end

  # escape and unescape strings for representation in XML

  @@replacements = [
    #  ["&apos;&apos;","&quot;"], # added by ines (09/03/09), might cause problems for unescape???
    ["&","&amp;"], # must be first for escaping, last for unescaping
    ["<","&lt;"],
    [">", "&gt;"],
    ["\"","&apos;&apos;"],
    #  ["\"","&quot;"],
    #  ["\'\'","&quot;"],
    #  ["\`\`","&quot;"],
    ["\'","&apos;"],
    ["\`\`","&apos;&apos;"],
    #  ["''","&apos;&apos;"]
  ]

  def self.escape(string)
    @@replacements.each do |unescaped, escaped|
      string.gsub!(unescaped, escaped)
    end

    string
  end

  def self.unescape(string)
    # reverse replacements to replace &amp last
    @@replacements.reverse_each do |unescaped, escaped|
      string.gsub!(escaped, unescaped)
    end

    string
  end
end
