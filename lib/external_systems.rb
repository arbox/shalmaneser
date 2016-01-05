# ExternalSystems.rb
#
# ke oct/nov 2005
#
# Store all known interfaces to
# systems that do syntactic analysis
#
# Given the name of a system and the service that the
# system performs, return the appropriate interface
#
# There are two types of interfaces to syntactic analysis systems:
# - interfaces:
#   offer methods for syntactic analysis,
#   and the transformation to Salsa/Tiger XML and SalsaTigerSentence objects
# - interpreters:
#   interpret the resulting Salsa/Tiger XML (represented as
#   SalsaTigerSentence and SynNode objects), e.g.
#   generalize over part of speech;
#   describe the path between a pair of nodes both as a path
#   and (potentially) as a grammatical function of one of the nodes;
#   determine whether a node describes a verb, and in which voice;
#   determine the head of a constituent
#
# Abstract classes for both interfaces and interpreters
# are in AbstractSynInterface.rb

require "ruby_class_extensions"
require 'logging'

# The list of available interface packages
# is at the end of this file.
# Please enter additional interfaces there.

# @todo AB: [2015-12-16 Wed 01:03]
#   After decoupling in OptParser and ConfigData classes move this
#   to Frappe.
module Shalmaneser
  class ExternalSystems
    ###
    # class variable:
    # list of all known interface classes
    # add to it using add_interface()
    @interfaces = []

    ###
    # class variable:
    # list of all known interpreter classes
    # add to it using add_interpreter()
    @interpreters = []

    ###
    # add interface/interpreter
    def self.add_interface(class_name)
      LOGGER.debug "Initializing interface <#{class_name}>."
      @interfaces << class_name
    end

    def self.add_interpreter(class_name)
      LOGGER.debug "Initializing interpreter <#{class_name}>."
      @interpreters << class_name
    end

    ###
    # check_interfaces_abort_if_missing:
    #
    # Given an experiment file, use some_system_missing? to
    # determine whether the system can be run with the requested
    # syntactic processing, exit with an error message if that is not possible
    # @param [FrappeConfigData] exp Experiment description.
    def self.check_interfaces_abort_if_missing(exp)
      if (missing = some_system_missing?(exp))
        interwhat, services = missing

        $stderr.puts
        $stderr.puts "ERROR: I am missing an #{interwhat} for "
        services.each_pair { |service, system_name|
          $stderr.puts "\tservice #{service}, system #{system_name}"
        }
        $stderr.puts
        $stderr.puts "I have the following interfaces:"
        @interfaces.each { |interface_class|
          $stderr.puts "\tservice #{interface_class.service}, system #{interface_class.system}"
        }
        $stderr.puts "I have the following interpreters:"
        @interpreters.each { |interpreter_class|
          $stderr.print "\t"
          $stderr.print interpreter_class.systems.to_a.map { |service, system_name|
            "service #{service}, system #{system_name}"
          }.join("; ")
          unless interpreter_class.optional_systems.empty?
            $stderr.print ", optional: "
            $stderr.print interpreter_class.optional_systems.to_a.map { |service, system_name|
              "service #{service}, system #{system_name}"
            }.join("; ")
          end
          $stderr.puts
        }
        $stderr.puts
        $stderr.puts "Please adapt your experiment file."
        exit 1
      end
    end

    ###
    # given the name of a system and the service that it
    # performs, find the matching interface class
    #
    # system: string: name of system, e.g. collins
    # service: string: service, e.g. parser
    #
    # returns: SynInterface class
    def self.get_interface(service, system)
      interfaces = @interfaces.select do |interface_class|
        interface_class.system == system && interface_class.service == service
      end

      unless interfaces.any?
        raise "I've been requested an interface for #{service} and #{system}, "\
              'but I cannot find any. Please correct your experiment files.'
      end

      # @todo AB: Actually it's bad logic, but no idea for now how to handle it.
      interfaces.first
    end

    ###
    # helper for get_interpreter:
    def self.get_interpreter_according_to_exp(exp)
      ExternalSystems.get_interpreter(ExternalSystems.requested_services(exp))
    end

    ###
    # given the names and services of a set of systems,
    # find the matching interpreter class
    #
    # an interpreter class has both obligatory systems
    # (they need to be present for this class to apply)
    # and optional systems (they may or may not be present
    # for the class to apply, but no other system performing
    # the same service may)
    #
    # systems:
    # hash: service(string) -> system name(string)
    #
    # returns: SynInterpreter class
    def self.get_interpreter(systems)
      # try to find an interface class with the given
      # service-name pairs

      @interpreters.each { |interpreter_class|

        if interpreter_class.systems.to_a.big_and { |service, system|
             # all obligatory entries of interpreter_class
             # are in systems
             systems[service] == system
           } and
          interpreter_class.optional_systems.to_a.big_and { |service, system|
             # all optional entries of interpreter_class are
             # either in systems, or the service isn't in systems at all
             systems[service].nil? or systems[service] == system
           } and
          systems.to_a.big_and { |service, system|
             # all entries in names are in either
             # the obligatory or optional set for interpreter_class
             interpreter_class.systems[service] == system or
               interpreter_class.optional_systems[service] == system
           }
          return interpreter_class
        end
      }

      # at this point, detection of a suitable interpreter class has failed
      return nil
    end

    ################
    private

    ###
    # knows about possible services that can be set in
    # the experiment file, and where the names of
    # the matching systems will be found in the experiment file data structure
    #
    # WARNING: adapt this when you introduce new services!
    #
    # returns: a hash
    #  <service> => system_name
    #
    #  such that for each service/system name pair:
    #  the service with the given name has been requested in
    #  the experiment file, and the names of the systems to be used
    #  for performing the service
    def self.requested_services(exp)
      services = {}
      [
        {"flag" => "do_postag", "service" => "pos_tagger"},
        {"flag" => "do_lemmatize", "service" => "lemmatizer"},
        {"flag" => "do_parse", "service" => "parser"}
      ].each do |hash|
        # yes, perform this service
        if exp.get(hash["flag"])
          services[hash["service"]] = exp.get(hash["service"])
        end
      end

      services
    end

    ###
    # some_system_missing?
    # returns nil if I have interfaces and interpreters
    # for all services requested in the given experiment file
    # else:
    # returns pair [interface or interpreter, info]
    #  where the 1st element is either 'interface' or 'interpreter',
    #  and the 2nd element is a hash mapping services to system names:
    #  the services that could not be provided
    # @param [FrappeConfigdata] exp FrappeConfigData object to check all the systems.
    def self.some_system_missing?(exp)
      missing_systems = nil
      # check interfaces
      requested_services(exp).each_pair do |service, system_name|
        unless get_interface(service, system_name)
          missing_systems = ["interface", {service => system_name}]
        end
      end

      # check interpreter
      unless get_interpreter_according_to_exp(exp)
        missing_systems = ["interpreter", services]
      end

      # everything okay
      missing_systems
    end
  end
end

# @todo AB: We should require programmatically all files in
# <frappe/interpreters> and <frappe/interfaces>.
require 'frappe/interfaces/collins_interface'
require 'frappe/interpreters/collins_treetagger_interpreter'
require 'frappe/interpreters/collins_tnt_interpreter'
require 'frappe/interfaces/berkeley_interface'
require 'frappe/interpreters/berkeley_interpreter'
require 'frappe/interfaces/stanford_interface'
require 'frappe/interpreters/stanford_interpreter'
require 'frappe/interfaces/treetagger_interface'
require 'frappe/interfaces/treetagger_pos_interface'
require 'frappe/interpreters/treetagger_interpreter'
require 'frappe/interpreters/empty_interpreter'
