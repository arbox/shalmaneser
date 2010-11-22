#############################3
#
# Module RulesFE
# Katrin Erk, June 13 2003
# (modified by Hajo Keffer, 2003)
#
# Aim: read off, manage, and apply rules for frame and frame element assignment
# works on data in extended TIGER XML format
#
# class RuleUser (the other classes in this module are just helper classes)
# --------------
# Reads off rules for frame and frame element assignment from an annotated sentence, 
# and applies rules to annotated or unannotated sentences.
#
# Applying rules to a sentence means adding new frames and frame elements to the sentence. 


require "SentenceNew"
require "DescribeNodeAndPath"

module RulesFE

  ########################################################
  #
  # Class RuleKeeper
  #
  # keeps frame and frame element assignment rules
  # The internal format of rules is:
  # 
  # {'sid' => ID of the sentence that this rule stems from
  #  'premise_fee' => { 'main' => node description for main node of the FEE
  #                     'descr' => list of node descriptions, one for each node of the FEE }
  #  'premise_fe' => array of hashes
  #                  { 'path' => path description of path from main FEE node to an FE node 
  #                    'end' => node_description of the FE node at which the path ends }
  #  'conclusion_fe' => name of the frame element, a string
  #  'conclusion_frame' => name of the frame, a string  }
  #
  # 'premise_fe' contains more than one entry if there are several syntactic constituents which together
  # make up the frame element 'conclusion_fe'
  #
  # 'premise_fee'-'descr' contains more than one entry if there are several syntactic constituents
  # which together are the FEE of the frame 'conclusion_frame'
  #
  #
  # Methods:
  #
  # new  clears the rule list
  #
  # read_rules(file_handle) reads rules from the given file. The format is the one written by write_rules
  #
  # write_rules(file_handle) writes all rules currently known to the object to the given file
  #
  #            Format of a rule:
  #            ## rule
  #            ID : [sentence ID of the sentence the rule was derived from]
  #            PREMISE
  #            FEE : [node description of main FEE node]
  #            (FEE all : [node description of an FEE node])*
  #            (FE : [node description of FE node] by [path description from main FEE to this node])*
  #            CONCLUSION
  #            Then Frame : [frame name]
  #            Then FE : [fe name]
  #
  #            'FEE all' lines occur if there is more than one node to the FEE. 
  #               There may be 0 or more lines of this type.
  #            'FE' lines describe one node of the FE.
  #               There may be 1 or more lines of this type -- more than one if the FE consists of more than one synt. node
  #
  # add_rule(rule) 'rule' is a rule in the internal format of RuleKeeper. 
  #            The rule 'rule' is added to the rule list
  #
  # each_rule  yields each rule of the list
  #
  # each_id    yields each sentence ID occurring for rules in the rule list
  #
  # each_rule_with_id(id) yields each rule of the list that has sentence ID 'id'
  #
  #
  # Class Methods:
  #
  # make_rule_part_fee(main_id, main, descr_list) constructs and returns a part of a rule, 
  #            the part that describes the FEE -- in the internal format
  #            'main_id' is the id of the main FEE node,
  #            'main' is a node description of the main FEE node,
  #            'descr_list' is a list of node descriptions of all FEE nodes
  #
  # make_rule_part_fe(id, node_descr, path_descr) constructs and returns a part of a rule,
  #            the part that describes one node of the FE -- in the internal format
  #            'id'         is the id of the FE node
  #            'node_descr' is a description of the FE node,
  #            'path_descr' is a description of the path from the main FEE node to this FE node
  #
  # make_rule(sid, fee_descr, fe_descr, frame_name, fe_name) constructs and returns a rule in the internal format
  #            'sid' is the sentence ID of the sentence from which the rule stems
  #            'fee_descr' is a part of a rule in internal format, the part that describes the FEE,
  #            'fe_descr' is a part of a rule in internal format, the part that describes the FE,
  #            'frame_name' is a string, the name of the frame
  #            'fe_name' is a string, the name of the FE
  #
  # get_rule_part_fee(rule) returns a list of node descriptions: the list of all node descriptions for the FEE
  #
  # get_rule_part_feemain(rule) returns a node description of the main FEE node
  #
  # get_rule_part_fe(rule) returns a list of pairs: [path_description, node_description]
  #             where path_description describes a path from the main FEE node to a node,
  #             and node_description describes this end node of the path
  #
  # get_rule_frame_name(rule) returns the name of the frame as given in 'rule'
  #
  # get_rule_fe_name(rule) returns the name of the frame element as given in 'rule'
  #
  # get_id(fe_descr) returns the id of an fe description
  #
  # set_id(id, fe_descr) sets the id of an fe description to id
  #
  # get_path(fe_descr) returns the path of an fe description
  #
  # set_path(path, fe_descr) sets the path of an fe description to path
  #
  # get_end_node(fe_descr) returns the end node description of an fe description
  #
  # set_end_node(end, fe_descr) sets the end node description of an fe description to end
  #
  # get_main_node(fee_description) returns the main node description of an fee
  #                                description
  #
  # set_main_node(mnd, fee_description) sets the main node description of an fee
  #                                to mnd
  #
  # get_nodes(fee_description) returns a list of the descriptions of the 
  #                                main nodes of an fee
  #                                description
  #
  # set_nodes(descrs, fee_description) sets the main node description of an fee
  #                                to descrs
  #
  # get_main_id(fee_description) returns the id of the main node of  
  #                                an fee
  #                                description
  #
  # set_main_id(id, fee_description) sets the id of the main node 
  #                                to id
  #

  class RuleKeeper
    
    ###
    def initialize
      @rules = Array.new
    end

    ###
    def read_rules(file_handle)
    end

    ###
    def write_rules(file_handle)
      @rules.each { |rule|
	write_rule(file_handle, rule)
      }
    end

    ###
    def write_rule(file_handle, rule)
      file_handle.puts '## rule'

      # sentence ID
      file_handle.print 'ID : ', rule['sid'], "\n"
      file_handle.puts 'PREMISE'
      
      # premise: form of FEE nodes
      file_handle.print 'FEE : '
      file_handle.print DescribeNodeAndPath::NodeDescription.to_s(rule['premise_fee']['main']), "\n"
      if rule['premise_fee']['descr'].length > 1
	rule['premise_fee']['descr'].each { |fee_descr|
	  file_handle.print 'FEE all : '
	  file_handle.print DescribeNodeAndPath::NodeDescription.to_s(fee_descr), "\n"
	}	  
      end
      
      # premise: path to FE node, form of FE node
      rule['premise_fe'].each { |fe_descr|
	file_handle.print "FE : "
	file_handle.print DescribeNodeAndPath::NodeDescription.to_s(fe_descr['end']), "\n   by\n"
	file_handle.print DescribeNodeAndPath::PathDescription.to_s(fe_descr['path']), "\n"
      } 
      
      # conclusion: Frame
      file_handle.puts 'CONCLUSION'
      file_handle.print "Then Frame : ", rule['conclusion_frame'], "\n"
      
      # conclusion: frame element
      file_handle.print "Then FE : ", rule['conclusion_fe'], "\n"
      file_handle.puts
    end


    ###
    def add_rule(rule)
      @rules << rule
    end

    ###
    def each_rule
      @rules.each { |rule| yield(rule) }
    end

    ###
    def each_id
      ids = @rules.collect { |rule| rule['sid'] }
      ids.uniq!
      
      ids.each { |id| yield(id)}
    end

    ###
    def each_rule_with_id(id)
      @rules.each { |rule| 
	if rule['sid']==id
	  yield rule
	end
      }
    end
    
    ###
    def RuleKeeper.make_rule_part_fee(id, main, descr_list)
      return {'main id' => id,
	  'main' => main,
	  'descr' => descr_list
      }
    end

    ###
    def RuleKeeper.get_main_id(fee_descr)
      return fee_descr['main id']
    end
    
    ###
    def RuleKeeper.get_main_node(fee_descr)
      return fee_descr['main']
    end
    
    ###
    def RuleKeeper.get_nodes(fee_descr)
      return fee_descr['descr']
    end
    
    ###
    def RuleKeeper.set_main_id(id, fee_descr)
      fee_descr['main id'] = id
    end
    
    ###
    def RuleKeeper.set_main_node(main, fee_descr)
      fee_descr['main'] = main
    end
    
    ###
    def RuleKeeper.set_nodes(descr_list, fee_descr)
      fee_descr['descr'] = descr_list
    end
    
    ###
    def RuleKeeper.make_rule_part_fe(node_id, node_descr, path_descr)
      return {'id' => node_id,
	  'path' => path_descr,
	  'end' => node_descr }
    end

    ###
    def RuleKeeper.get_id(fe_descr)
      return fe_descr['id']
    end

    ###
    def RuleKeeper.get_path(fe_descr)
      return fe_descr['path']
    end

    def RuleKeeper.get_end_node(fe_descr)
      return fe_descr['end']
    end

   ###
    def RuleKeeper.set_id(id, fe_descr)
      fe_descr['id'] = id
    end

    ###
    def RuleKeeper.set_path(path, fe_descr)
      fe_descr['path'] = path
    end

    def RuleKeeper.set_end_node(end_node, fe_descr)
      fe_descr['end'] = end_node
    end

    ###
    def RuleKeeper.make_rule(sid, fee_descr, fe_descr, frame_name, fe_name)
      return {'sid' => sid, 
	  'premise_fee' => fee_descr,
	  'premise_fe' => fe_descr,
	  'conclusion_fe' => fe_name,
	  'conclusion_frame' => frame_name
      }
    end

    ###
    def RuleKeeper.get_rule_part_fee(rule)
      return rule['premise_fee']['descr']
    end

    ###
    def RuleKeeper.get_rule_part_feemain(rule)
      return rule['premise_fee']['main']
    end

    ###
    def RuleKeeper.get_rule_part_fe(rule)
      ret = Array.new
      rule['premise_fe'].each { |path_and_end|
	ret << [ path_and_end['path'], path_and_end['end']]
      }
      return ret
    end

    ###
    def RuleKeeper.get_rule_frame_name(rule)
      return rule['conclusion_frame']
    end

    ###
    def RuleKeeper.get_rule_fe_name(rule)
      return rule['conclusion_fe']
    end
  end

  ########################################################
  #
  # Class RuleGeneralizer
  #
  # generalizes rules to ensure broader applicability
  #
  # Methods
  #
  # new(parameters)    reads the user's parameters and creates a 
  #                    NodeGeneralizer object
  #
  # generalize(sobj, fee_descr, fe_descr, frame_name, fe_name)    returns a 
  #                    possibly generalized
  #                    rule in the internal format
  #                           'sobj' is a ManageSynSem::Sentence object, the sentence from 
  #                            which the rule stems
  #                           'fee_descr' is a part of a rule in internal 
  #                            format, the part that 
  #                               describes the FEE,
  #                           'fe_descr' is a part of a rule in internal 
  #                            format, the part that 
  #                               describes the FE,
  #                            'frame_name' is a string, the name of the frame
  #                            'fe_name' is a string, the name of the FE
  #
  #
  # generalizes TIGER-XML nodes in linguistically relevant respects
  # 
  # The basic idea is that if a node or path belongs to a certain class then its decription
  # can be replaced by a disjunctive description that will match each of the members
  # in the class 
  #
  # The linguistic problem consists in finding sets of nodes that are as large as 
  # possible without resulting in over-generalizations
  #
  # As or nodes, two sets general_np and general_s are used presently
  #
  # Additionally, PPs will get generalized by generalizing their prepositions
  # e.g. the prepostion 'in' is generalized to OR([in, im, ins, darin])
  #
  # As for paths, there are five general paths for subject, direct object, 
  # indirect object, clausal object, and modifier.
  #
  # The following constructions will be dealt with: modal auxillary (like "will helfen"),
  # future tense ("wird helfen"), subjunctive ("wuerde helfen") and (past) perfect
  # (including subjunctive) ("hat/hatte/haette/ geholfen"). Apart from that
  # coordinations on sentence level ("Er kennt Maenner und hilft Frauen") are
  # dealt with.
  #
  # Methods
  #
  # new            defines an static array general_nodes which contains the  
  #                arrays general_np and general_s
  #
  # generalize_node(node) looks for a node class the input node belongs to
  #                and if it finds one it returns the disjunctive node that corresponds
  #                to this class  
  #



  class RuleGeneralizer
    
    def initialize(parameters)

      @parameters = parameters

      ## define some TIOER-XML nodes
      ## noun phrase
      np = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(np,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(np,'NP')

      ## coordinated noun phrase
      cnp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(cnp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(cnp,'CNP')

      ## proper noun (complex proper name) 
      pn = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(pn,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(pn,'PN')
      
      ## sentence 
      s = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(s,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(s,'S')

      ## coordinated sentence 
      cs = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(cs,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(cs,'CS')

      ## vp
      vp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(vp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(vp,'VP')

      ## coordinated vp
      cvp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(cvp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(cvp,'CVP')

      ## proper name
      ne = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(ne,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(ne,'NE')

      ## normal noun
      nn = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(nn,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(nn,'NN')
      
      ## combined normal noun and proper name
      nne = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(nne,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(nne,'NNE')

      ## substituting demonstrative pronoun (e.g. 'dies' in 'dies war ...')
      pds = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(pds,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(pds,'PDS')

      ## substituting indefinite pronoun (e.g. 'alles' in 'alles kann man ..')
      pis = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(pis,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(pis,'PIS')
      
      ## substituting personal pronoun (e.g. 'er')
      pper = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(pper,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(pper,'PPER')

      ## substituting possessive pronoun (e.g. 'meins')
      pposs = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(pposs,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(pposs,'PPOSS')
      
      ## substituting relative pronoun (e.g. 'das' in 'Wasser, das ..")
      prels = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(prels,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(prels,'PRELS')

      ## substituting interrogative pronoun (e.g. 'wer')
      pws = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(pws,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(pws,'PWS')

      ## reflexive pronoun (e.g. 'sich')
      prf = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(prf,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(prf,'PRF')

      ## vvfin (e.g. "hilft")
      vvfin = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(vvfin,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(vvfin,'VVFIN')

      ## vvinf (e.g. "helfen")
      vvinf = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(vvinf,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(vvinf,'VVINF')

      ## vvpp (e.g. "geholfen")
      vvpp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(vvpp,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(vvpp,'VVPP')

      ##vvinf_or_fin
      vvinf_or_fin = DescribeNodeAndPath::NodeDescription.or([vvinf,vvfin])

      ##wo(llen)ko(ennen)so(llen)_vmfin (e.g. 'will')
      wollen_finite_forms = DescribeNodeAndPath::NodeDescription.or(['will', 'willst', 'wollen', 'wollt', 'wollte', 'wolltest', 'wollten', 'wolltet', 'wolle', 'wollest', 'wollet'])
      sollen_finite_forms = DescribeNodeAndPath::NodeDescription.or(['soll', 'sollst', 'sollen', 'sollt', 'sollte', 'solltest', 'sollten', 'solltet', 'solle', 'sollest',  'sollet'])
      koennen_finite_forms = DescribeNodeAndPath::NodeDescription.or(['kann', 'kannst', 'können', 'könnt', 'konnte', 'konntest', 'konnten', 'konntet', 'könnte', 'könntest', 'könnten', 'könntet', 'könne', 'könnest', 'könnet'])
      muessen_finite_forms = DescribeNodeAndPath::NodeDescription.or(['muß', 'mußt', 'müssen', 'müßt', 'müsse', 'müssest', 'müsset', 'mußte', 'mußtest', 'mußten', 'mußtet', 'müßte', 'müßtest', 'müßten', 'müßtet'])
      moegen_finite_forms = DescribeNodeAndPath::NodeDescription.or(['mag', 'magst', 'mögen', 'mögt', 'möge', 'mögest', 'möget', 'mochte', 'mochtest', 'mochten', 'mochtet', 'möchte', 'möchtest', 'möchten', 'möchtet'])
      wosokomomu_finite_forms = DescribeNodeAndPath::NodeDescription.or([wollen_finite_forms, sollen_finite_forms, koennen_finite_forms,moegen_finite_forms, muessen_finite_forms])
      vmfin = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(vmfin,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(vmfin,'VMFIN')
      DescribeNodeAndPath::NodeDescription.set_word(vmfin,wosokomomu_finite_forms)

      ## werden
      werden_finite_forms = DescribeNodeAndPath::NodeDescription.or(['werde', 'wirst', 'wird', 'werden', 'werdet', 'werdest', 'werde', 'würde', 'würdest', 'würdet', 'würden'])
      werden = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(werden,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(werden,'VAFIN')
      DescribeNodeAndPath::NodeDescription.set_word(werden,werden_finite_forms)

      ## werden or modal verb
      vmfin_werden = DescribeNodeAndPath::NodeDescription.or([vmfin,werden])

      ## haben
      haben_finite_forms = DescribeNodeAndPath::NodeDescription.or(['habe', 'hast', 'hat', 'haben', 'habt', 'habest', 'habet', 'hatte', 'hattest', 'hatten', 'hattet','hätte', 'hättest', 'hätten', 'hättet'])
      haben = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(haben,'terminal')
      DescribeNodeAndPath::NodeDescription.set_pos(haben,'VAFIN')
      DescribeNodeAndPath::NodeDescription.set_word(haben,haben_finite_forms)

      ## PP with preposition 'in' and cognates 
      in_variants = DescribeNodeAndPath::NodeDescription.or(['in', 'darin', 'im', 'ins'])
      in_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(in_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(in_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(in_pp,in_variants)
      
      ## PP with preposition 'von' and cognates 
      von_variants = DescribeNodeAndPath::NodeDescription.or(['davon', 'von', 'vom'])
      von_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(von_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(von_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(von_pp,von_variants)

      ## PP with preposition 'ueber' and cognates 
      ueber_variants = DescribeNodeAndPath::NodeDescription.or(['darüber', 'über', 'überm', 'übers'])
      ueber_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(ueber_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(ueber_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(ueber_pp,ueber_variants)

      ## PP with preposition 'mit' and cognates 
      mit_variants = DescribeNodeAndPath::NodeDescription.or(['damit', 'mit'])
      mit_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(mit_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(mit_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(mit_pp,mit_variants)

      ## PP with preposition 'bei' and cognates 
      bei_variants = DescribeNodeAndPath::NodeDescription.or(['dabei', 'bei', 'beim'])
      bei_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(bei_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(bei_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(bei_pp,bei_variants)

      ## PP with preposition 'fuer' and cognates 
      fuer_variants = DescribeNodeAndPath::NodeDescription.or(['dafür', 'für', 'fürs'])
      fuer_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(fuer_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(fuer_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(fuer_pp,fuer_variants)

      ## PP with preposition 'zu' and cognates 
      zu_variants = DescribeNodeAndPath::NodeDescription.or(['dazu', 'zu', 'zum', 'zur'])
      zu_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(zu_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(zu_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(zu_pp,zu_variants)

      ## PP with preposition 'nach' and cognates 
      nach_variants = DescribeNodeAndPath::NodeDescription.or(['danach', 'nach'])    
      nach_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(nach_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(nach_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(nach_pp,nach_variants)

      ## PP with preposition 'auf' and cognates 
      auf_variants = DescribeNodeAndPath::NodeDescription.or(['darauf', 'auf', 'aufs'])  
      auf_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(auf_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(auf_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(auf_pp,auf_variants)

      ## PP with preposition 'durch' and cognates 
      durch_variants = DescribeNodeAndPath::NodeDescription.or(['dadurch', 'durchs'])
      durch_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(durch_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(durch_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(durch_pp,durch_variants)

      ## PP with preposition 'an' and cognates 
      an_variants = DescribeNodeAndPath::NodeDescription.or(['daran', 'an', 'am', 'ans'])
      an_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(an_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(an_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(an_pp,an_variants)

      ## PP with preposition 'unter'and cognates 
      unter_variants = DescribeNodeAndPath::NodeDescription.or(['darunter', 'unter', 'unters'])
      unter_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(unter_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(unter_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(unter_pp,unter_variants)

      ## PP with preposition 'gegen' and cognates 
      gegen_variants = DescribeNodeAndPath::NodeDescription.or(['dagegen', 'gegen'])
      gegen_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(gegen_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(gegen_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(gegen_pp,gegen_variants)

      ## PP with preposition 'um' and cognates 
      um_variants = DescribeNodeAndPath::NodeDescription.or(['darum', 'um', 'ums'])
      um_pp = DescribeNodeAndPath::NodeDescription.make_empty_description
      DescribeNodeAndPath::NodeDescription.set_type(um_pp,'nonterminal')
      DescribeNodeAndPath::NodeDescription.set_cat(um_pp,'PP')
      DescribeNodeAndPath::NodeDescription.set_prep(um_pp,um_variants)

      ############################################

      #########
      ## define general nodes
      ##
      ##

      ## general_node_np
      ## groups together np-like nonterminals, noun-like terminals and the so-called 
      ## substituting pronouns 
      general_node_np = {'nonterminals' => [np,cnp,pn],
      'terminals' => [ne,nn,nne,pds,pis,pper,pposs,prels,pws,prf]}

      ## general_node_s
      ## groups together s-like and vp-like nonterminals. This grouping might be considered
      ## dangerously but remember that in TIGER-XML there is the distinction between modifiers
      ## and complements which will prevent from some otherwise obvious over-generalizations
      general_node_s = {'nonterminals' => [s,cs,vp,cvp],
      'terminals' => [vvinf]}
      @general_nodes = []
      @pps = [in_pp, von_pp, ueber_pp, mit_pp, bei_pp, fuer_pp, 
	zu_pp, nach_pp, auf_pp, durch_pp, an_pp, unter_pp, gegen_pp, um_pp]
      if (parameters['general_nodes'] == 'all') then 
	@general_nodes = [general_node_np, general_node_s]
      end
      if (parameters['general_nodes'] == 'np') then
	@general_nodes = [general_node_np]
      end
      if (parameters['general_nodes'] == 's') then
	@general_nodes = [general_node_s]
      end
      
      #################PATHS###########

      ###########
      ## some TigerXML paths
      ##
      ##
 
      end_node = DescribeNodeAndPath::NodeDescription.make_empty_description

      ##
      #no vp, only s node 
      #
      
      #subject
      #no conjunction

      s_2_sj = DescribeNodeAndPath::PathDescription.make_2_node_path(s, 'dn', 'SB', end_node)

      vvfin_2_sj_nc =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvfin,'up','HD',s_2_sj)

      #subject
      #coordination present

      s_2_sj2 = DescribeNodeAndPath::PathDescription.make_2_node_path(s, 'dn', 'SB', end_node)
  
      cs_2_sj =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(cs,'dn','CJ',s_2_sj2)

      s_cs_sj =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(s,'up','CJ', cs_2_sj)    

      vvfin_cs_sj =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvfin,'up','HD', s_cs_sj)

      # putting the two together 

      vvfin_2_sj = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(vvfin_2_sj_nc,vvfin_cs_sj)

      vvfin_2_sj = DescribeNodeAndPath::PathDescription.set_2_return(vvfin_2_sj)
      # dative object 

      s_2_da = DescribeNodeAndPath::PathDescription.make_2_node_path(s, 'dn', 'DA', end_node)

      vvfin_2_da =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvfin, 'up', 'HD', s_2_da)

      vvfin_2_da = DescribeNodeAndPath::PathDescription.set_2_return(vvfin_2_da)

      # accusative object

      s_2_oa = DescribeNodeAndPath::PathDescription.make_2_node_path(s, 'dn', 'OA', end_node)

      vvfin_2_oa =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvfin, 'up', 'HD', s_2_oa)

      vvfin_2_oa = DescribeNodeAndPath::PathDescription.set_2_return(vvfin_2_oa)

      # clausal object

      s_2_oc = DescribeNodeAndPath::PathDescription.make_2_node_path(s, 'dn', 'OC', end_node)

      vvfin_2_oc =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvfin, 'up', 'HD', s_2_oc)

      vvfin_2_oc = DescribeNodeAndPath::PathDescription.set_2_return(vvfin_2_oc)
      # modifier

      s_2_mo = DescribeNodeAndPath::PathDescription.make_2_node_path(s, 'dn', 'MO', end_node)

      vvfin_2_mo =  DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvfin, 'up', 'HD', s_2_mo)

      vvfin_2_mo = DescribeNodeAndPath::PathDescription.set_2_return(vvfin_2_mo)
      ##
      # modal or auxillary verb construction with werden, wollen, koennen, 
      # or sollen
      #

      # path to hilfsverb

      vvinf_2_vp = DescribeNodeAndPath::PathDescription.make_2_node_path(vvinf, 'up', 'HD', vp) 

      vvinf_2_s = DescribeNodeAndPath::PathDescription.suffix_node_2_path(vvinf_2_vp, 'up', 'OC', s)

      vvinf_2_vmfin = DescribeNodeAndPath::PathDescription.suffix_node_2_path(vvinf_2_s, 'dn', 'HD', vmfin_werden)

      # subject

      vvinf_vp_s_sj =  DescribeNodeAndPath::PathDescription.join_paths(vvinf_2_vp, 'up', 'OC', s_2_sj)

      vvinf_vp_s_sj = DescribeNodeAndPath::PathDescription.set_2_return(vvinf_vp_s_sj)
      vmfin_sj = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvinf_2_vmfin,vvinf_vp_s_sj)

      # dative object
      
      vp_2_da =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'DA', end_node) 

      vvinf_vp_da = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvinf, 'up', 'HD', vp_2_da)

      vvinf_vp_da = DescribeNodeAndPath::PathDescription.set_2_return(vvinf_vp_da)

      vmfin_da = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvinf_2_vmfin,vvinf_vp_da)

      # accusative object
      
      vp_2_oa =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'OA', end_node) 

      vvinf_vp_oa = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvinf, 'up', 'HD', vp_2_oa)

      vvinf_vp_oa = DescribeNodeAndPath::PathDescription.set_2_return(vvinf_vp_oa)

      vmfin_oa = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvinf_2_vmfin,vvinf_vp_oa)

      # clausal object
      
      vp_2_oc =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'OC', end_node) 

      vvinf_vp_oc = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvinf, 'up', 'HD', vp_2_oc)

      vvinf_vp_oc = DescribeNodeAndPath::PathDescription.set_2_return(vvinf_vp_oc)

      vmfin_oc = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvinf_2_vmfin,vvinf_vp_oc)

      # modifier
      
      vp_2_mo =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'MO', end_node) 

      vvinf_vp_mo = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvinf, 'up', 'HD', vp_2_mo)

      vvinf_vp_mo = DescribeNodeAndPath::PathDescription.set_2_return(vvinf_vp_mo)

      vmfin_mo = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvinf_2_vmfin,vvinf_vp_mo)

      ##
      # (Past) perfect
      #
      #

      # path to auxillary

      vvpp_2_vp = DescribeNodeAndPath::PathDescription.make_2_node_path(vvpp, 'up', 'HD', vp) 

      vvpp_2_s = DescribeNodeAndPath::PathDescription.suffix_node_2_path(vvpp_2_vp, 'up', 'OC', s)
      
      vvpp_2_haben = DescribeNodeAndPath::PathDescription.suffix_node_2_path(vvpp_2_s, 'dn', 'HD', haben)

      # subject

      vvpp_vp_s_sj =  DescribeNodeAndPath::PathDescription.join_paths(vvpp_2_vp, 'up', 'OC', s_2_sj)

      vvpp_vp_s_sj = DescribeNodeAndPath::PathDescription.set_2_return(vvpp_vp_s_sj)
      haben_sj = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvpp_2_haben,vvpp_vp_s_sj)

      # dative object
      
      vp_2_da2 =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'DA', end_node) 

      vvpp_vp_da = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvpp, 'up', 'HD', vp_2_da2)

      vvpp_vp_da = DescribeNodeAndPath::PathDescription.set_2_return(vvpp_vp_da)
      haben_da = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvpp_2_haben,vvpp_vp_da)

      # accusative object

      vp_2_oa2 =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'OA', end_node) 

      vvpp_vp_oa = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvpp, 'up', 'HD', vp_2_oa2)

      vvpp_vp_oa = DescribeNodeAndPath::PathDescription.set_2_return(vvpp_vp_oa)
      haben_oa = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvpp_2_haben,vvpp_vp_oa)

      # clausal object

      vp_2_oc2 =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'OC', end_node) 

      vvpp_vp_oc = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvpp, 'up', 'HD', vp_2_oc2)

      vvpp_vp_oc = DescribeNodeAndPath::PathDescription.set_2_return(vvpp_vp_oc)
      haben_oc = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvpp_2_haben,vvpp_vp_oc)

      # modifier

      vp_2_mo2 =  DescribeNodeAndPath::PathDescription.make_2_node_path(vp, 'dn', 'MO', end_node) 

      vvpp_vp_mo = DescribeNodeAndPath::PathDescription.prefix_node_2_path(vvpp, 'up', 'HD', vp_2_mo2)

      vvpp_vp_mo = DescribeNodeAndPath::PathDescription.set_2_return(vvpp_vp_mo)
      haben_mo = DescribeNodeAndPath::PathDescription.merge_paths_conjunctively(vvpp_2_haben,vvpp_vp_mo)


      ########
      ########
      # define general paths
      #

      # subject

      sj = vvfin_2_sj
      sj = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(sj,vmfin_sj)
      sj =  DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(sj,haben_sj)

      # dative object

      da = vvfin_2_da
      da = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(da,vmfin_da)
      da = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(da,haben_da)
      # accusative object

      oa = vvfin_2_oa
      oa = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(oa,vmfin_oa)
      oa = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(oa,haben_oa)

      # clausal object

      oc = vvfin_2_oc
      oc = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(oc,vmfin_oc)      
      oc = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(oc,haben_oc)

      # modifier

      mo = vvfin_2_mo
      mo = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(mo,vmfin_mo)
      mo = DescribeNodeAndPath::PathDescription.merge_paths_disjunctively(mo,haben_mo)

      #######general paths

      @general_paths = [sj,da,oa,oc,mo]      
    end
   
    def generalize(sobj, fee_descr, fe_descr, frame_name, fe_name)
      sid = sobj.sid()
      if  @parameters['general_nodes'] == 'no' && @parameters['general_paths'] == 'no' then
	return RuleKeeper.make_rule(sid, fee_descr, fe_descr, frame_name, fe_name)
      else
	target_id = RuleKeeper.get_main_id(fee_descr)
	# the new fe description list
	# consists of the old list where
	new_fe_descr = fe_descr.collect { |fe_d|
	  # for each fe description
	  # the node is generalized
	  new_end_node = nil
	  unless @parameters['general_nodes'] == 'no'
	    new_end_node = generalize_node(RuleKeeper.get_end_node(fe_d))
	  end
	  if new_end_node.nil?
	    new_end_node = RuleKeeper.get_end_node(fe_d) # default the old end node
	  end
	  RuleKeeper.set_end_node(new_end_node, fe_d)
	  # the path is generalized
	  fe_id = RuleKeeper.get_id(fe_d)
	  path = nil
	  unless @parameters['general_paths'] == 'no'
	    path = generalize_path(sobj,target_id,fe_id)
	  end
	  if path.nil?
	    path = RuleKeeper.get_path(fe_d) # default: the old path
	  end
	  # and the path is adapted to the node generalization
	  new_path = DescribeNodeAndPath::PathDescription.set_return_nodes(path,new_end_node)
	  RuleKeeper.set_path(new_path,fe_d)
	  fe_d
	}
	first = new_fe_descr.first
	first_path = RuleKeeper.get_path(first)
	## determine new description of the main fee node 
	# it describes the first node of the new path
	new_main_node = DescribeNodeAndPath::PathDescription.extract_first_node(first_path)
	# must be identical for each member of the description list or something has
	# gone wrong
	new_fe_descr.each{ |fe_d|
	  next_path = RuleKeeper.get_path(fe_d)
	  next_new_main_node = DescribeNodeAndPath::PathDescription.extract_first_node(next_path)
	  if ! next_new_main_node == new_main_node then
	    $stderr.print "WARNING: Something went wrong while extracting path's first node"
	  end
	}
	# the fee nodes list has to be adapted to the new main node
	# in particular this means that the old main node in this list has to be
	# replaced by the new node
	main_node = RuleKeeper.get_main_node(fee_descr)
	id = RuleKeeper.get_main_id(fee_descr)
	old_nodes = RuleKeeper.get_nodes(fee_descr)
	gotcha = false
	new_nodes = old_nodes.collect{ |node|
	  if node == main_node
	    node = new_main_node
	    gotcha = true
	  end
	  node
	}
	unless gotcha
	  $stderr.puts("WARNING: Coundn't find main fee node in fee node list")
	end
	new_fee_descr = RuleKeeper.make_rule_part_fee(id,new_main_node,new_nodes)
	return RuleKeeper.make_rule(sid, new_fee_descr, new_fe_descr, frame_name, fe_name)
      end
    end

    def generalize_node(node)
      if (DescribeNodeAndPath::NodeDescription.get_prep(node)).nil? then ## not a PP 
	gen_node = look_for_general_node(node)
	if empty_node(gen_node) then
	  return nil
	else	  
	  return to_node(gen_node)
	end
      else ## a PP
	if ((@parameters['general_nodes'] == 'all') || (@parameters['general_nodes'] == 'pp')) then
	  return get_general_pp(node)
	else
	  return nil
	end
      end	  
    end
    private :generalize_node

    def generalize_path(sobj,target_id,fe_id)
      path_descriptor = DescribeNodeAndPath::PathDescription.new(sobj)
      @general_paths.each {|general_path|
	end_ids = path_descriptor.follow_path_forward(target_id, general_path)
	if end_ids.length == 1
	  end_id = end_ids.first
	  if end_id == fe_id
	    return general_path
	  end
	end
      }
      return nil
    end
    private :generalize_path

    def look_for_general_path(path)
      @general_paths.each {|general_path|
	if DescribeNodeAndPath::PathDescription.match_descriptions?(general_path,path) then
	  return general_path
	end
      }
      return path
    end
    private :look_for_general_path

    def look_for_general_node(node)
      type = DescribeNodeAndPath::NodeDescription.get_type(node)
      result = nil
      if type == 'terminal' then
	pos = DescribeNodeAndPath::NodeDescription.get_pos(node)
	@general_nodes.each {|general_node|
	  general_node['terminals'].each { |terminal|
	    if DescribeNodeAndPath::NodeDescription.get_pos(terminal) == pos then
	      return general_node
	    end
	  }
	}
      elsif type == 'nonterminal' then
	cat = DescribeNodeAndPath::NodeDescription.get_cat(node)
	@general_nodes.each {|general_node|
	  general_node['nonterminals'].each { |nonterminal|
	    if DescribeNodeAndPath::NodeDescription.get_cat(nonterminal) == cat then
	      return general_node
	    end
	  }
	}
      else
	$stderr.puts 'WARNING Attempt to generalize node which is neither terminal nor nonterminal'
      end
      return result
    end
    private :look_for_general_node

    def empty_path(path)
      if path == nil then
	return true
      else
	return false
      end
    end
    private :empty_path

    def empty_node(gen_node)
      if gen_node == nil then
	return true
      else
	return false
      end
    end
    private :empty_node
    
    def to_node(gen_node)
      all_nodes = gen_node['nonterminals'].concat(gen_node['terminals'])
      return DescribeNodeAndPath::NodeDescription.or(all_nodes)
    end
    private :to_node

    def get_general_pp(node)  
      @pps.each { |pp| 
	if (DescribeNodeAndPath::NodeDescription.match_descriptions?(pp,node)) then
	  return pp
	end
      }
      return node
    end
    private :get_general_pp
    
  end


  ########################################################
  #
  # Class RulePartFEE
  #
  # deals with the part of rules that concerns the frame-evoking element
  #
  # Methods:
  #
  # new(sobj) sobj is a ManageSynSem::Sentence object
  #
  # read_off(id) read off part of a rule from the annotation in the sentence sobj
  #          'id' is the ID of the frame of sobj from which the rule should be derived
  #         Reads off a node description for all FEE nodes of this frame
  #         If there is more than one FEE, one is taken as the main one. 
  #         Current heuristics:
  #         - if there is a single node (among the FEE nodes) with part of speech VVFIN, take that one
  #         - else write out a warning and take the first node
  #         Returns a pair [ID of main FEE node, the part of a RuleKeeper rule that describes the FEE]
  #          
  # apply(rule) apply 'rule' to the sentence sobj. 'rule' is a rule in the internal format of RuleKeeper
  #         this function only checks the part of 'rule' that pertains to the FEE
  #         returns the list of FEE node IDs if 'rule' matches, and nil if 'rule' doesn't match the FEE nodes in sobj.
  #         The list of FEE nodes in sobj is read off the 'matches' part that TIGER XML generates.
  #         
  # get_main_fee(rule) returns the ID of the main FEE node of sobj, according to the rule 'rule'
  #         'rule' is a rule in the internal format of RuleKeeper.
  #         prints out an error message if it couldn't match the main FEE node,
  #         so better use this function only after having successfully used apply(rule)
  #
  class RulePartFEE

    ###
    def initialize(sobj)
      @sobj = sobj
      @node_descriptor = DescribeNodeAndPath::NodeDescription.new(sobj)
      @assignments = Array.new
    end

    ###
    def read_off(frame_id)
      # find list of node IDs that belong to the target
      target_ids = @sobj.sem.get_target_nodeids(frame_id)
      
      if target_ids.empty?
	return nil
      end

      # get node descriptions for them all
      target_descr_with_id = target_ids.collect { |id|
	[id, @node_descriptor.describe_node(id)]
      }

      # determine main node of target
      main_id, main_descr = determine_main_FEE(target_descr_with_id)

      if main_id.nil?
	return nil
      end

      return RuleKeeper.make_rule_part_fee(main_id, 
					   main_descr, 
					   target_descr_with_id.collect { |pair| pair.last})
    end

    ###
    def apply(rule)
      # get a list of node descriptions
      descr_list = RuleKeeper.get_rule_part_fee(rule)

      # filter out wildcards
      wildcards = Array.new
      true_descr_list = descr_list.select { |descr|
	if @node_descriptor.is_wildcard?(descr)
	  wildcards << descr
	  false
	else
	  true
	end
      }

      # find FEE nodes in synt.structure: consult matches
      # get_matched_ids returns a list. Each element of that list represents one match.
      # Each element of the list is a list itself, since one match may consist of more than one ID.
      id_lists = @sobj.get_matched_ids()
      if id_lists.nil? or id_lists.empty?
	$stderr.print 'WARNING: did not find any FEE nodes in sentence ', @sobj.sid(), "\n"
	$stderr.puts 'Maybe the file does not contain any TIGERSearch matches?'
	return nil
      end

      # keep only those matches that actually match the description
      matching_id_lists = id_lists.select { |ids|
	fee_matches_description(true_descr_list, wildcards, ids)
      }

      # return FEE IDs
      if matching_id_lists.empty?
	return nil
      else
	return matching_id_lists
      end
    end

    ###
    def fee_matches_description(true_descr_list, wildcards, ids)
      matched = Array.new(ids.length, false)
      
      # assign non-wildcards
      matched = match_aux(true_descr_list, ids, matched)
      if matched.nil? # non-match found
	return false
      end
	
      # assign wildcards
      matched = match_aux(wildcards, ids, matched)
      if matched.nil? # non-match found
	return false
      end
	
      # if everything is assigned, all values in matched should be 'true' now
      matched.each { |matchval|
	unless matchval
	  return false
	end
      }
      return true
    end
    private :fee_matches_description
    
    ###
    def get_main_fee(rule, ids)

      # get description of main part of FEE
      main_descr = RuleKeeper.get_rule_part_feemain(rule)

      # there should be exactly one ID in the list that matches the description
      matching = ids.select { |id|
	@node_descriptor.matches_description?(id, main_descr)
      }
      unless matching.length == 1
	$stderr.puts 'ERROR: RulesFe: Couldn\'t match description of main node of FEE'
	return nil
      end
      return matching.first
    end

    ###
    def match_aux(descrs, fee_ids, matched)
      descrs.each { |descr|
	is_assigned = false
	fee_ids.each_index { |ix|
	  if @node_descriptor.matches_description?(fee_ids[ix], descr)
	    @assignments << [fee_ids[ix], descr]
	    is_assigned = true
	    matched[ix] = true
	    break
	  end
	}
	unless is_assigned # nothing matches this description
	  return nil
	end
      }
      return matched
    end
    private :match_aux    


    ###
    def determine_main_FEE(target_descr)

      if target_descr.length == 0
	return nil
      end

      # only one fenode in this FEE: then it's the main one
      if target_descr.length == 1
	return target_descr.first
      end

      # next heuristic: if there are several of them, and one has
      # VVFIN as its part of speech, take that one
      vvfin_targets = target_descr.find_all { |pair|
	id, descr = pair
	(DescribeNodeAndPath::NodeDescription.get_type(descr) == 'terminal') and (DescribeNodeAndPath::NodeDescription.get_pos(descr) == 'VVFIN')
      }

      if vvfin_targets.length == 1
	return vvfin_targets.first
      end

      # no heuristics left -- spit out error message and take the first element of target_descr
      $stderr.print 'WARNING: RulesFE, sentence ', @sobj.sid, ": I have more than one target node\n"
      $stderr.puts 'and no heuristics to decide between them.'
      $stderr.print 'Target nodes: '
      target_descr.each { |t| 
        $stderr.print DescribeNodeAndPath::NodeDescription.to_s(t)," "
      }
      $stderr.puts

      return target_descr.first
      
    end
    private :determine_main_FEE

  end

  ########################################################
  #
  # Class RulePartFE
  #
  # deals with the part of rules that concerns the frame  elements
  #
  # Methods:
  #
  # new(sobj) sobj is a ManageSynSem::Sentence object
  #
  # read_off(frame_id, fe_id, target_id) read off part of a rule from the annotation in the sentence sobj
  #          'frame_id' is the ID of the frame of sobj from which the rule should be derived
  #          'fe_id' is the ID of the frame element of 'frame_id' from which the rule should be derived
  #          'target_id' is the node ID of the main FEE node (as found by RulePartFEE)
  #
  #         Reads off node descriptions of all nodes belonging to 'fe_id', and 
  #         path descriptions for the paths to these nodes.
  #         Returns a list, each element is the part of a RuleKeeper rule that describes an FE
  #          
  # apply(rule, target_id) apply 'rule' to the sentence sobj. 'rule' is a rule in the internal format of RuleKeeper
  #         'target_id' is the node ID of the main FEE node (as found by RulePartFEE)
  # 
  #         This function only checks the part of 'rule' that pertains to the FEs
  #         It returns a list of lists of FE node IDs.
  #         Each element of the list describes a successfule application of 'rule',
  #         it is a list of IDs that together form the FE.
  #         Returns nil if the rule doesn't match.
  #
  #         If the rule 'rule' states that the FE should consist of exactly one node,
  #         and if there are several ways of applying 'rule', we get several lists of FE nodes in our return list
  #         (implicitly connected by 'or')
  #
  #         If the rule 'rule' states that the FE should consist of several nodes,
  #         then we only handle the case that there is exactly one way of applying 'rule'.
  #         Otherwise we print out a warning.
  #

  class RulePartFE

    ###
    def initialize(sobj)
      @sobj = sobj
      @node_descriptor = DescribeNodeAndPath::NodeDescription.new(sobj)
      @path_descriptor = DescribeNodeAndPath::PathDescription.new(sobj)
    end

    ###
    def read_off(frame_id, fe_id, target_id)
      # find list of node IDs that belong to the element
      fe_ids = @sobj.sem.get_fe_nodeids(frame_id, fe_id)
      if fe_ids.nil?
	return nil
      end
      
      # get node descriptions and paths for them all
      fe_descr = fe_ids.collect { |id|
	node_descr = @node_descriptor.describe_node(id)
	path_descr = @path_descriptor.describe_path(target_id, id)
	RuleKeeper.make_rule_part_fe(id, node_descr, path_descr)
      }
      return fe_descr
    end

    ###
    def apply(rule, fee_id)

      # get a list of descriptions, each a pair of
      # - a path description and
      # - a node description describing the end node of the path
      path_and_end_descr = RuleKeeper.get_rule_part_fe(rule)

      # apply the descriptions
      # more than one path_and_end_descr: this FE is made up of several constituents
      if path_and_end_descr.length > 1

	fe_id_group = Array.new
	path_and_end_descr.each { |pair|

	  path_descr, end_descr = pair
	  end_ids = @path_descriptor.follow_path_forward(fee_id, path_descr)

	  if end_ids.nil? # path didn't match
	    return nil
	  end

	  # more than one end ID: several different constituents matching this path
	  # We're not processing both that and complex FE constituents at the same time just now
	  if end_ids.length > 1 
	    $stderr.puts 'WARNING: complex FE description plus several matches,'
	    $stderr.puts 'I\'m not processing this.'
	    return nil
	  end
	  # test whether this one ID we got matches the end description
	  if @node_descriptor.matches_description?(end_ids.first, end_descr)
	    # so we have one group of FE IDs, which may be made up of several IDs
	    fe_id_group << end_ids.first
	  else
	    return nil # path end didn't match
	  end
	  
	}
	ret = [fe_id_group]
      else # just one path_and_end_descr

	path_descr, end_descr = path_and_end_descr.first
	end_ids = @path_descriptor.follow_path_forward(fee_id, path_descr)
	if end_ids.nil? # path didn't match
	  return nil
	end

	# so we have one or more groups of FE IDs, each of which can only consist of a single ID
	ret = Array.new
	end_ids.each { |id| 
	  if @node_descriptor.matches_description?(id, end_descr) # test if the description of the 
	    ret << [id]                                           # path end matches
	  end
	}
      end
      if ret.empty?
	return nil
      else
	return ret
      end
    end
  end



  ########################################################
  #
  # Class RuleUser
  #
  # deals with rules that assign frames and frame elements on the basis of 
  # the syntactic structure of a sentence
  #
  # this is the _only_ class of this module that should be used from outside!
  #
  #
  # Methods:
  #
  # new(parameters)  initializes the rule-keeping object, empties the table of known rules,
  #                  initializes the rule-generalizing object
  #                  remembers the parameters for rule usage:
  #                  'parameters' is a hash with the following possible keys and values:
  #
  #               parameters:
  #               ------------
  #               'strategy' => 'strict' or 'sloppy'
  #                  'strict' means that there is an additional filter: Rules come in groups. A group consists of all rules
  #                     read off one and the same example sentence, i.e. all rules generated by one call to 
  #                     read_off(sobj). 
  #                     A rule is ruled out by the filter unless _all_ rules
  #                      of a group match the sentence 'sobj'. 
  #                  'sloppy' means that this additional filter is not applied. 
  #
  #               'single_frame' => true or false
  #                  true means that there is an additional filter: 
  #                     Only if all rules that apply predict the same frame name
  #                     are they applied.
  #                  false means that this additional filter is not applied.
  #
  #                'single_fe' => true or false
  #                   true means that there is an additional filter: 
  #                     For each frame element name, only if all rules that predict
  #                     this frame name assign it to exactly the same nodes is this frame element assigned
  #                   false means that this additional filter is not applied
  #
  #
  #
  # read_off(sobj) 'sobj' is a ManageSynSem::Sentence object, a sentence
  #                If there are frames annotated in 'sobj', rules for 
  #                frame and frame element assignment are read off those frames.
  #                These rules are kept in a RuleKeeper object. For the construction of the rules, 
  #                a RulePartFEE object is used to read off the part of the rules that
  #                concerns FEEs, and a RulePartFE object is used to read off the part of the rules
  #                that concerns FEs.
  #
  #                One such rule describes the constituents that form the FEE, the constituents that form 
  #                the FE, and the path from the FEE to the FE as rule premises, and the frame name and
  #                frame element name as the rule conclusion.
  #
  #                The descriptions of nodes and paths are provided by the DescribeNodeAndPath module.
  #
  #                Currently, a node description comprises:
  #                for terminal nodes: the part of speech
  #                for nonterminal nodes: the category, and, if the category is PP, the preposition
  #
  #                Currently a path description consists of a set of steps. Each step comprises:
  #                the category of the start node, the edge label of the edge between start and end node, 
  #                and the category of the end node.
  #
  # write_rules(file) write rules to a file. 'file' is a file handle.
  #                A RuleUser object contains a RuleKeeper object for remembering rules.
  #                When write_rules is evoked, all rules that have been entered 
  #                since the RuleUser object was initialized
  #                -- entering rules can be done by using read_off -- are written to 'file'
  #
  # apply(sobj)   apply to a sentence all rules that have been read up to now.
  #               'sobj' is a ManageSynSem::Sentence object, a sentence
  #               All rules that have been entered since the RuleUser object was initialized
  #               are applied to the sentence given by 'sobj'. 
  #               'sobj' is modified. 
  #               Return value : true if some rule applied, false else
  #               
  #               First all rules are tested for applicability, 
  #               and the frame and frame elements they predict
  #               (if they are applicable) are collected.
  #
  #               Then these new frame and frame element assignments are filtered and grouped:
  #
  #               - All single frame element assignments that the rules propose are grouped into frames,
  #                 i.e. all frame element assignment rules that have the 
  #                 same frame name in the conclusion
  #                 are grouped into a single new frame.
  #
  #               - If 'sobj' already contains a frame that subsumes one proposed by the rules, 
  #                 the subsumed new frame is not added. 
  #                 Subsumption means: the frame name is the same, and each frame element of the new frame
  #                 is already present in the old frame
  #  
  #

  class RuleUser

    ###
    def initialize(parameters)
      @parameters = parameters
      @keeper = RuleKeeper.new()
      @generalizer = RuleGeneralizer.new(parameters)
    end

    ###
    def read_off(sobj)
      # get objects that deal with parts of the readoff
      rules_part_fee = RulePartFEE.new(sobj)
      rules_part_fe = RulePartFE.new(sobj)
      # handle each frame in turn

      sobj.sem.frames.each_pair { |frame_id, frame|
	# determine FEE info
	fee_descr = rules_part_fee.read_off(frame_id)

	target_id = RuleKeeper.get_main_id(fee_descr)

	if target_id.nil?
	  return
	end

	# determine FE info for each FE
	sobj.sem.frames[frame_id].fes.each_key { |fe_id|

	  fe_descr = rules_part_fe.read_off(frame_id, fe_id, target_id)

	  unless fe_descr.nil? or fe_descr.empty?
	    # make rule
	    @keeper.add_rule(@generalizer.generalize(sobj,
						     fee_descr, 
						     fe_descr,
						     frame.frame_name(), 
						     frame.fe_name(fe_id)))
	  end
	}
      }
    end

    ###
    def write_rules(file)
      @keeper.write_rules(file)
    end

    ###
    def apply(sobj)

      # test if this sentence is in the wrong subcorpus
      # if yes, don't assign anything
      if sobj.sem.is_wrongsubcorpus?()
	return false
      end

      # find prospective new frames and frame elements
      case @parameters['strategy']
      when 'sloppy'
	assignments = apply_sloppy(sobj)
      when 'strict'
	assignments = apply_strict(sobj)
      else
	$stderr.print 'ERROR in RulesFe: Don\'t know strategy ', strategy, "\n"
	return false
      end

      # filter out incompatible assignments

      # Single frame, or multiple frames?
      # Do we only use the new assignments if they predict a single frame?
      if @parameters['single_frame']
	assignments1 = check_single_frame(assignments, sobj)
	if assignments1.nil?
	  return false
	end
      else
	assignments1 = group_into_frames(assignments)
      end

      # Single FE assignment or multiple FE assignments?
      # What if a FE is assigned to two different groups of constituents?
      # Do we assign both, or neither?
      if @parameters['single_fe']
	assignments2 = check_single_fe(assignments1, sobj.sid())
      else
	assignments2 = remove_duplicate_fes(assignments1)
      end

      # all remaining assignments are okay
      # turn them into frames and add them to sobj, if they are not already there
      return assignments_2_frames(filter_subsumed_assignments(assignments2, sobj), sobj)
    end

    ###
    #
    # apply_sloppy(sobj) sobj is a ManageSynSem::Sentence object
    #
    # apply rules, no 'strategy'='strict' filter
    #
    # returns a list of hashes, one hash per match that was found:
    #  for the format of the hashes, see procedure apply_one_rule
    def apply_sloppy(sobj)
      # get objects that deal with parts of the rules to be applied
      rule_part_fee = RulePartFEE.new(sobj)
      rule_part_fe = RulePartFE.new(sobj)
      
      new_assignments = Array.new
      
      # try all rules, store matches in new_assignments
      @keeper.each_rule { |rule|
	new_assignments.concat apply_one_rule(sobj, rule, rule_part_fee, rule_part_fe)
      }
      return new_assignments
    end
    private :apply_sloppy

    ###
    #
    # apply_strict(sobj) sobj is a ManageSynSem::Sentence object
    #
    # apply rules, with 'strategy'='strict' filter
    #   use apply_one_rule to see for each rule if it matches
    #   pass on results only for rules belonging to a group such that all rules of the group match
    #   a group is the set of all rules derived from the same example sentence
    #
    # returns a list of hashes, one hash per match that was found:
    #  for the format of the hashes, see procedure apply_one_rule
    def apply_strict(sobj)
      # get objects that deal with parts of the rules to be applied
      rule_part_fee = RulePartFEE.new(sobj)
      rule_part_fe = RulePartFE.new(sobj)
      
      new_assignments = Array.new

      # try rules group-wise, store matches in new_assignments
      @keeper.each_id { |group_id| 
	group_assignments = Array.new
	all_matching = true
	@keeper.each_rule_with_id(group_id) { |rule|
	  result = apply_one_rule(sobj, rule, rule_part_fee, rule_part_fe)
	  if result.empty?  # rule did not match
	    all_matching = false
	    break
	  else # rule did match
	    group_assignments.concat result
	  end
	}
	if all_matching # use matching rules only if all rules of the group matched
	  new_assignments.concat group_assignments
	end
      }
      return new_assignments
    end
    private :apply_strict


    ###
    #
    # apply_one_rule(sobj, rule, fee_tester, fe_tester)
    #
    #   sobj is a ManageSynSem::Sentence object
    #   rule is a rule in the RuleKeeper internal format
    #   fee_tester is a RulePartFEE object
    #   fe_tester is a RulePartFE object
    #
    # apply one rule to a given sentence
    #
    # returns a list of hashes, one hash per match that was found:
    # 
    #  { 'frame_name' => name of new frame to be assigned, a string
    #    'fe_name' => name of new frame element to be assigned, a string
    #    'fee_ids' => list of node IDs of syntactic nodes belonging to the FEE
    #    'fe_ids' => list of node IDs of syntactic nodes belonging to the FE }
    #
    def apply_one_rule(sobj, rule, fee_tester, fe_tester)
      # first try to match the FEE
      fee_id_lists = fee_tester.apply(rule)
      if fee_id_lists.nil? # rule not applicable
	return []
      end

      retv = Array.new

      # iterate over all FEEs in the sentence
      fee_id_lists.each { |fee_ids|

	main_fee_id = fee_tester.get_main_fee(rule, fee_ids)
	if main_fee_id.nil? #something went wrong
	  next
	end
      
	# now for the frame element
	list_of_fe_id_groups = fe_tester.apply(rule, main_fee_id)
	if list_of_fe_id_groups.nil? or list_of_fe_id_groups.empty?
	  next
	end
	# return each new assignment as a hash
	retv.concat list_of_fe_id_groups.collect { |fe_id_group|
	  {'frame_name' => RuleKeeper.get_rule_frame_name(rule), 
	    'fe_name' => RuleKeeper.get_rule_fe_name(rule), 
	    'fee_ids' => fee_ids,
	    'fe_ids' => fe_id_group
	  }
	}
      }
      return retv
    end
    private :apply_one_rule


    ###
    # 
    # check_single_frame(assignments)
    #
    #    assignments is a list of hashes as produced by apply_one_rule
    #
    # if all frame names in 'assignments' that pertain to the same FEE
    # are the same, returns a list of lists, each of which are the assignments for one FEE,
    # else returns nil
    #

    def check_single_frame(assignments, sobj)
      retv = []
      fees = assignments.collect { |a| a['fee_ids'].sort.to_s}.uniq
      fees.each { |fee_string|
	assignments_this_fee = assignments.select { |a| 
	  a['fee_ids'].sort.to_s == fee_string
	}
	frame_names = assignments_this_fee.collect{ |a| a['frame_name']}.uniq
	if frame_names.length > 1
	  $stderr.print 'WARNING: Conflicting frame assignments for sentence '
	  $stderr.print sobj.sid(), " -- did not assign any frame\n"
	  next
	else
	  retv << assignments_this_fee
	end
      }
      if retv.empty?
	return nil
      else
	return retv
      end
    end
    private :check_single_frame
    
    ###
    #
    # group_into_frames(assignments)
    # 
    #   assignments is a list of hashes as produced by apply_one_rule
    #
    # returns a list of lists L; the union of the lists L is 'assignments'
    # The hashes in 'assignments' are grouped according to the frame name they predict

    def group_into_frames(assignments)
      fees = assignments.collect { |a| a['fee_ids'].sort.to_s}.uniq
      frame_names = assignments.collect { |a| a['frame_name']}.uniq
      retv = []
      fees.each { |fee_string|
	assignments_this_fee = assignments.select { |a| 
	  a['fee_ids'].sort.to_s == fee_string
	}
	frame_names.each { |name|
	  ret << assignments_this_fee.select { |a| a['frame_name'] == name}
	}
      }
      return ret
    end
    private :group_into_frames

    ###
    #
    # check_single_fe(assignments_framewise, sentence_id)
    #
    #   assignments_framewise is a list of lists of hashes as produced by apply_one_rule
    #       in each element of the list of lists, all hashes predict the same frame name
    #   sentence_id is the ID of the sentence concerned in the TIGER XML structure
    #
    # In each member of assignments_framewise, the elements are filtered:
    #  If there are two or more elements that predict the same FE name, but
    #  with different node ID lists, they are removed.
    #  If there are two or more elements that predict the same FE name with the
    #  same node ID list, only one of them is retained
    #
    # If this filtering has made a member of assignments_framewise empty, it is removed.
    #

    def check_single_fe(assignments_framewise, sentence_id)
      # each member of assignments_framewise describes one frame
      # in each frame, each FE may appear at most once
      # new_list is new list of assignments-describing-one-frame-each
      new_list = assignments_framewise.collect { |assignment|
	fe_names = assignment.collect { |a| a['fe_name']}.uniq
	# new_a will consist of those assignments from a
	# that describe an unambiguous FE assignment
	new_a = []
	# check each FE in turn
	fe_names.each { |fe_name|
	  this_fe_1, *this_fe_rest = assignment.select { |a| a['fe_name'] == fe_name}
	  is_good = true
	  this_fe_rest.each { |this_fe_2|
	    unless array_eq( this_fe_1['fe_ids'] , this_fe_2['fe_ids'])  # same IDs in both lists
	      is_good = false
	    end	      
	  }
	  if is_good
	    new_a << this_fe_1
	  else
	    $stderr.print "WARNING: sentence ", sentence_id, ", FE ", fe_name
	    $stderr.print ": conflicting assignments, did not assign this FE\n"
	  end
	}	  
	new_a
      }
      # new_list may still contain empty assignments
      return new_list.select { |a| not a.empty?}
    end
    private :check_single_fe

    ###
    #
    # remove_duplicate_fes(assignments_framewise)
    #
    #   assignments_framewise is a list of lists of hashes as produced by apply_one_rule
    #       in each element of the list of lists, all hashes predict the same frame name
    #
    # In each member of assignments_framewise, the elements are filtered:
    #  If there are two or more elements that predict the same FE name with the
    #  same node ID list, only one of them is retained
    #

    def remove_duplicate_fes(assignments_framewise)
      new_list = assignments_framewise.collect { |assignment|
	new_a = []
	assignment.each_index { |ix|
	  is_good = true
	  for ix1 in (ix+1)..assignment.length
	    # if the assignments at ix and at ix1 describe the same assignment,
	    # don't keep the one at ix
	    if assignment[ix]['fe_name'] == assignment[ix1]['fe_name'] and
		array_eq( assignment[ix]['fe_ids'], assignment[ix1]['fe_ids'])
	      is_good = false
	      break
	    end
	    if is_good
	      new_a << assignment[ix]
	    end
	  end
	}
	new_a
      }
      return new_list
    end
    private :remove_duplicate_fes

    ###
    #
    # filter_subsumed_assignments(assignments, sobj)
    #
    #   assignments is a list of lists of hashes as produced by apply_one_rule
    #       in each element of the list of lists, all hashes predict the same frame name
    #   sobj is a ManageSynSem::Sentence object
    #
    #  Each list in "assignments" describes a single frame
    #  In each frame description, each frame element description occurs only once. But this could mean
    # - either that each frame element name is assigned only once
    # - or that a frame element name can be assigned twice, but to different node ID sets
    #
    # Tests for each member of 'assignments' if it is subsumed by a frame annotated in 'sobj'
    #
    # Subsumption means: 
    #   if @parameters['add_to_old_frames'] == true:
    #     the frame name is the same, and for each frame element assignment 
    #     in the member of 'assignments', the same frame element assignment 
    #     is already present in that frame
    #   if @parameters['add_to_old_frames'] == false:
    #     there is at least one frame that is evoked by this FEE in sobj

    def filter_subsumed_assignments(assignments, sobj)
      filtered_assignments = []
      assignments.each{ |new_frame|

	# check back with sobj if this frame is already there
	new_frame_subsumed = false

	sobj.sem.frames.each_pair { |frame_id, frame|
	  if frame_subsumes_assignment(sobj, frame, frame_id, new_frame)
	    new_frame_subsumed = true
	    break
	  end
	}
	unless new_frame_subsumed
	  filtered_assignments << new_frame
	end
      }
      filtered_assignments
    end
    private :filter_subsumed_assignments


    ###
    #
    # frame_subsumes_assignment(sobj, frame, frame_id, new_frame)
    #
    #  sobj is a ManageSynSem::Sentence object
    #  frame is a ManageSynSem::Frame object, part of sobj
    #  frame_id is the ID of 'frame' as given in the extended TIGER XML structure
    #  new_frame is a list of hashes as produced by apply_one_rule, all
    #    assigning the same frame name
    #
    # aux procedure of filter_subsumed_assignments
    # tests if the frame name FEE IDS in frame and new_frame are the same
    
    def frame_subsumes_assignment(sobj, frame, frame_id, new_frame)
      # subsumption only if we have the same frame and FEE
      if @parameters['add_to_old_frame']
	# same frame and FEE?
	if frame.frame_name() == new_frame.first['frame_name'] and
	    array_eq( sobj.sem.get_target_nodeids(frame_id), new_frame.first['fee_ids']) and
	    fes_subsume_new_fes(sobj, frame, frame_id, new_frame)
	  return true
	else
	  return false
	end
      else
	# subsumption already if we have the same FEE
	if array_eq(sobj.sem.get_target_nodeids(frame_id), new_frame.first['fee_ids'])
	  return true
	else
	  return false
	end
      end
    end
    private :frame_subsumes_assignment

    ###
    #
    # fes_subsume_new_fes(sobj, frame, frame_id, new_frame)
    #
    #  sobj is a ManageSynSem::Sentence object
    #  frame is a ManageSynSem::Frame object, part of sobj
    #  frame_id is the ID of 'frame' as given in the extended TIGER XML structure
    #  new_frame is a list of hashes as produced by apply_one_rule, all
    #    assigning the same frame name
    #
    # aux procedure of filter_subsumed_assignments
    # tests whether all hashes in 'new_frame' describe FEs that are present in 'frame'

    def fes_subsume_new_fes(sobj, frame, frame_id, new_frame)
      new_frame.each { |new_fe|

	this_fe_subsumed = false

	frame.fes.each_key { |fe_id|
	  if frame.fe_name(fe_id) == new_fe['fe_name'] and
	      array_eq(sobj.sem.get_fe_nodeids(frame_id, fe_id), new_fe['fe_ids'])

	    this_fe_subsumed = true
	    break
	  end
	} 
	  
	unless this_fe_subsumed
	  return false
	end
      } 
      return true
    end
    private :fes_subsume_new_fes

    ###
    #
    # assignments_2_frames(assignments, sobj)
    #
    #   assignments is a list of lists of hashes as produced by apply_one_rule
    #       in each element of the list of lists, all hashes predict the same frame name
    #   sobj is a ManageSynSem::Sentence object
    #
    # for each frame description in 'assignments', a new frame as an extended TIGEr XML structure is constructed
    # and added to sobj

    def assignments_2_frames(assignments, sobj)
      if assignments.empty?
	return false
      end
      something_applied = false
      assignments.each { |new_frame|
	if new_frame.empty?
	  next
	end
	something_applied = true
	frame_id = sobj.sem.add_frame(sobj.sid(), 
				      new_frame.first['frame_name'], 
				      new_frame.first['fee_ids'])
	new_frame.each { |new_fe|
	  sobj.sem.add_fe(frame_id, 
			  new_fe['fe_name'],
			  new_fe['fe_ids'])
	}
      }
      return something_applied
    end
    private :assignments_2_frames

    ###
    #
    # array_eq(a1, a2)
    #
    # a1, a2 are arrays
    #
    # returns true if a1, a2 contain the same elements, possibly in different order
    # else false
    #
    # this function works only if a1, a2 don't contain duplicate elements 
    # or if duplicate elements don't matter in the comparison
    # 

    def array_eq(a1, a2)
      if a1 - a2 == [] and a2 - a1 == []
	return true
      else
	return false
      end
    end
    private :array_eq

  end

end
