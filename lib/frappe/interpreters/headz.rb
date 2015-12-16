# name: Module Headz
# auth: albu@coli.uni-sb.de
#
# modified KE Sept 04:
# changed from old Sentence pkg to new SalsaTigerSentence pkg
#
# modified KE April 05:
# suppress the flood of warnings
#
# modified SP June 05: added some more cases; change to SalsTigerRegXML
#
#
# INIT: REXML TIGER sentence,
# FUNC: syn_nodes(term/non_term) -> heads
#
#
# usage:
#
# h = Headz.new()
#
# hash = h.get_sem_head(node) # node is a SalsaTigerXmlNode obj
#
# head = hash["head"]
# prep = hash["prep"]
#
# if h.complex(head)
#   print "preposition of conjunction involved"
# end

require_relative 'headz_helpers'

class Headz
  def initialize
    @helpers = HeadzHelpers.new
    @Verbose = false #KE 13.4.05: please not that many messages!
  end

  # head of one node
  def get_sem_head(node)
    gsh(node)
  end

  # all headz of top-nodes covering fe
  def get_fe_heads(fe)
    if (const = fe.children)
      const.map { |node| get_sem_head(node) }
    else
      $stderr.puts "Headz.get_sem_head: no children for FE #{fe}"
      []
    end
  end

  def gsh (node)
    if !node then
      if @Verbose then $stderr.puts "Headz.gsh: no input node" end
      return {}

    elsif node.is_terminal? then return Hash['head'=>node]

    else
      case node.category
      when 'AP'
        return gsh(@helpers.get_dtr(node,'HD'))

      when 'AVP'
        return gsh(@helpers.get_dtr(node,'HD'))
      when 'CAP', 'CAVP', 'CNP', 'CPP', 'CS', 'CVP'
        conjs = @helpers.get_conjuncts(node)
        head = gsh(conjs.shift)
        if head
          head.update(Hash["conj"=>gsh_conjs(conjs)])
        end
        return head

      when 'NM'
        return gsh(@helpers.get_rightmost_dtr(node,'NMC'))
      when 'NP'
        nk = @helpers.get_rightmost_dtr(node,'NK')
        if nk
          return gsh(nk)
        else
          return gsh(@helpers.get_rightmost_dtr(node, "NN"))
        end

      when 'PN'
        pncs = @helpers.get_dtrs(node,'PNC')
        head = gsh(pncs.last)
        if head
          head.update(Hash["pncs"=>pncs])
        end
        return head

      when 'PP'
        return pp(node)

      when 'S'
        return s(node)
      when 'VROOT'
        dtrs = @helpers.get_dtrs(node,'--')

        # discourse level node with sentence nodes below?
        # or conjunction with sentence nodes below?
        discourselevel_dtr = dtrs.detect { |n| n.category == "DL"}
        co_dtr = dtrs.detect { |n| n.category == "CO" }
        if discourselevel_dtr
          dtrs = discourselevel_dtr.children()
        elsif co_dtr
          dtrs = co_dtr.children()
        end


        # take first sentence node
        sent_dtr = dtrs.detect {|n| n.category =~ /^C?S/}
        if sent_dtr
          return gsh(sent_dtr)
        else
#          $stderr.puts "headz Warning: no sentence found below VROOT! Node #{node.id()}"
          return nil
        end

      when 'VP'
        return vp(node)

      when 'MTA'
        return gsh(@helpers.get_rightmost_dtr(node,'ADC'))

      when 'VZ'
        return gsh(@helpers.get_dtr(node,'HD'))
      else
        if @Verbose
          $stderr.puts " Headz.gsh: no rule for #{node.category}"
        end
        {}
      end
    end
  end

  # flatten the processed conjs to a list of (head) Hashes
  # containing no conj features themselves
  def gsh_conjs(conjs)
    flat = Array.new

    conjs.each {|conj|
      current = gsh(conj)
      @helpers.descend(current,flat)
    }

    flat
  end

  #####################################3
  def pp(node)
    prep = node.terminals_sorted().detect { |n|
      (pt = n.part_of_speech()) and
        (pt =~ /^APPR/ or
           pt =~ /^PWAV/ or
           pt =~ /^C?PP/
         )
    }

    if (lastnk = @helpers.get_rightmost_dtr(node,'NK'))
      head = gsh(lastnk)
      if head and prep
        head.update(Hash['prep'=>prep])
      end

    elsif (re = @helpers.get_dtr(node,'RE'))
      head = gsh(re)
      if head and prep
        head.update(Hash['prep'=>prep])
      end
    else
      if @Verbose then $stderr.puts " pp: no rule for #{node}" end
    end

    head
  end

  ################
  def s(node)
    head = @helpers.get_dtr(node,'HD')
    unless head
      return Hash[]
    end

    if head.outdeg == 0
      return gsh(head)
    end

    oc = @helpers.get_dtr(node,'OC')
    case head.category
    when 'VVFIN'
      if svp = @helpers.get_dtr(node,'SVP') then
        h = gsh(head)
        if h
          return h.update(Hash['svp'=>gsh(svp), 'oc'=>gsh(oc)])
        else
          return h
        end
      else
        return gsh(head)
      end

    when 'VAFIN'
      if oc && headd = @helpers.get_dtr(oc,'HD')
        h = gsh(headd)
        if h
          return h.update(Hash['oc'=>gsh(oc)])
        else
          return h
        end

      elsif pd = @helpers.get_dtr(node,'PD') && head = @helpers.get_dtr(pd,'HD')
        return gsh(head)

      else
        if @Verbose then $stderr.puts " s: no rule for #{node}" end
      end
    else
      if @Verbose then $stderr.puts " s: no rule for #{node}" end
    end
  end

  ################
  def vp(node)
    head = gsh(@helpers.get_dtr(node,'HD'))
    tmp = @Verbose
    @Verbose = false

    newHash = {}
    ["da","oa"].each { |type|
      if (dtr = @helpers.get_dtr(node, type.upcase))
        newHash[type] = gsh(dtr)
      end
    }
    @Verbose = tmp
    if head
      return head.update(newHash)
    else
      return newHash
    end
  end

  ################
  # Access
  def head(h)
    h['head']
  end

  def complex(h)
    prep(h) || conj(h)
  end

  def prep(h)
    h['prep']
  end

  def conj(h)
    h['conj']
  end
end # Class Headz
