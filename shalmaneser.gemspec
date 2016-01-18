# -*- coding: utf-8 -*-
lib_path = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'rake'
require 'definitions'

# Define a constant here to use this spec in the Rakefile.
Gem::Specification.new do |s|
  s.name = 'shalmaneser'
  # It is the description for <gem list -d>.
  s.summary = 'SHALMANESER - SHALlow seMANtic parSER'
  s.description = <<-EOS
SHALMANESER - SHALlow seMANtic parSER. This package provides a toolbox for
Semantic Role Labeling (SRL). SHALMANESER uses supervised learning algorithms to
assing semantic classes and roles to raw texts. It is paradigm agnostic, i.e. it
can handle any role-semantic schema (FrameNET, PropBank etc.) and use any set
of word senses (e.g. WordNet synsets). SHALMANESER emerged as part of the SALSA
Project at the University of Saarbrücken.
  EOS
  s.version = Shalmaneser::Shalmaneser::VERSION
  s.author = 'Andrei Beliankou'
  s.email = 'arbox@yandex.ru'
  s.homepage = 'http://bu.chsta.be/projects/shalmaneser/'
  s.bindir = 'bin'
  s.executables = %w(shalmaneser)
  s.extra_rdoc_files = ['README.md', 'LICENSE.md', 'CHANGELOG.md'] +
                       FileList['doc/**/*.md']
  s.rdoc_options = ['-m', 'README.md']
  # s.platform = Gem::Platform::CURRENT
  s.required_ruby_version = '>= 2.0'
  s.add_runtime_dependency('shalmaneser-frappe', ">= #{s.version}")
  s.add_runtime_dependency('shalmaneser-fred', ">= #{s.version}")
  s.add_runtime_dependency('shalmaneser-rosy', ">= #{s.version}")
  s.files = FileList['bin/shalmaneser',
                     'lib/shalmaneser/**/**.rb',
                     'doc/**/*.md',
                     'README.md',
                     'LICENSE.md',
                     'CHANGELOG.md',
                     '.yardopts'
                    ].to_a.reject { |fn| fn =~ /frappe\.rb|fred\.rb|rosy\.rb|lib\.rb/ }
  s.license = ::Shalmaneser::LICENSE
  s.post_install_message = <<-EOS

Thank you for installing Shalmaneser #{Shalmaneser::Shalmaneser::VERSION}!

This software package has multiple external dependencies:
- OpenNLP Maximum Entropy Classifier;
- Berkeley Parser;
- Stanford Parser;
- Collins Parser;
- TreeTagger;
- MySQL Database Server etc.

Please proceed to installation instructions:
https://github.com/arbox/shalmaneser/blob/master/doc/index.md

If you find any bugs or have questions consider opeing a ticket:
https://github.com/arbox/shalmaneser/issues

  EOS
  # How to use this?
  s.requirements << 'mysql-server'
  s.metadata = {
    'issue_tracker' => 'https://github.com/arbox/shalmaneser/issues',
  }
end
