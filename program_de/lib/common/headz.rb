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

require "common/SalsaTigerRegXML"

class Headz 

  def initialize()
    @Helpers = HeadzHelpers.new()
    @Verbose = false #KE 13.4.05: please not that many messages!
  end
  
  # head of one node
  def get_sem_head(node)
    gsh(node)
  end
  
  # all headz of top-nodes covering fe
  def get_fe_heads(fe)
    if (const = fe.children())
      const.map { |node|
	get_sem_head(node)
      }
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
	return gsh(@Helpers.get_dtr(node,'HD'))

      when 'AVP'
	return gsh(@Helpers.get_dtr(node,'HD'))
      when 'CAP', 'CAVP', 'CNP', 'CPP', 'CS', 'CVP'
	conjs = @Helpers.get_conjuncts(node)
	head = gsh(conjs.shift)
        if head
          head.update(Hash["conj"=>gsh_conjs(conjs)])
        end
        return head

      when 'NM'
	return gsh(@Helpers.get_rightmost_dtr(node,'NMC'))
      when 'NP'
        nk = @Helpers.get_rightmost_dtr(node,'NK')
        if nk
          return gsh(nk)
        else
          return gsh(@Helpers.get_rightmost_dtr(node, "NN"))
        end

      when 'PN'
	pncs = @Helpers.get_dtrs(node,'PNC')
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
        dtrs = @Helpers.get_dtrs(node,'--')

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
        return gsh(@Helpers.get_rightmost_dtr(node,'ADC'))

      when 'VZ'
	return gsh(@Helpers.get_dtr(node,'HD'))
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
      @Helpers.descend(current,flat)
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

    if (lastnk = @Helpers.get_rightmost_dtr(node,'NK'))
      head = gsh(lastnk)
      if head and prep
        head.update(Hash['prep'=>prep])      
      end

    elsif (re = @Helpers.get_dtr(node,'RE'))
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
    head = @Helpers.get_dtr(node,'HD')
    if !head
#      $stderr.puts " s: no head for #{node}"
      return Hash[]
    end
    
    if head.outdeg() == 0
      return gsh(head)
    end

    oc = @Helpers.get_dtr(node,'OC')
    case head.category
    when 'VVFIN' 
      if svp = @Helpers.get_dtr(node,'SVP') then 
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
      if oc && headd = @Helpers.get_dtr(oc,'HD')
        h = gsh(headd)
        if h
          return h.update(Hash['oc'=>gsh(oc)])
        else
          return h
        end
	
      elsif pd = @Helpers.get_dtr(node,'PD') && head = @Helpers.get_dtr(pd,'HD')
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
    head = gsh(@Helpers.get_dtr(node,'HD'))
    tmp = @Verbose
    @Verbose = false
    newHash = Hash.new
    ["da","oa"].each { |type| 
      if (dtr = @Helpers.get_dtr(node,type.upcase))
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
    return h['head']
  end

  def complex(h)
    prep(h) or conj(h)
  end

  def prep(h)
    return h['prep']
  end

  def conj(h)
    return h['conj']
  end


  
end # Class Headz


class HeadzHelpers
  @Verbose = true
  
  # Conjunction
  
  def get_conjuncts(node)
    conjuncts = get_dtrs(node,'CJ')
  end

  # flatten
  def descend(current,flat)
    if current.nil?
      return flat
    end

    if current.has_key?("conj") then
      tmp = current.delete("conj")
      flat.push current
      tmp.each {|item|     
	descend(item,flat)}
    else 
      flat.push current 
    end
  end
  
  # Zugriff
  
  def get_dtr(node,label)
    if (dtrs = node.children_by_edgelabels([label]))
      dtrs.first
    else
      if @Verbose then $stderr.puts " SelectHeadDtr: no #{label} dtr for #{node}" end
      nil
    end
  end
  
  def get_dtrs(node,label)
    if ! dtrs = node.children_by_edgelabels([label])
      if @Verbose then $stderr.puts " SelectHeadDtr: no #{label} dtr for #{node}" end
    else
      dtrs
    end
  end
  
  def get_rightmost_dtr(node,label)
    children = node.children_by_edgelabels([label])
    if re = children.last then re
    else 
      if @Verbose then $stderr.puts " SelectHeadDtr: no #{label} dtrs for #{node}" end
      nil 
    end
  end

#   def l2h(list)
#     h = Hash.new
#     while (list.length > 1) do
#       h[list.shift] = list.shift
#     end
#     if list.length == 1 then 
#       $stderr.puts "l2h: odd number of elems: " + list.join(" / ")
#     end
#     h
#   end
  
end # Class HeadzHelpers



