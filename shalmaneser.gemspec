# -*- coding: utf-8 -*-
lib_path = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'rake'
require 'shalmaneser/version'

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
  s.version = Shalmaneser::VERSION
  s.author = "Andrei Beliankou"
  s.email = 'arbox@yandex.ru'
  s.homepage = 'http://bu.chsta.be/projects/shalmaneser/'
  s.bindir = 'bin'
  s.executables = ['shalmaneser', 'frprep', 'fred', 'rosy']
  s.add_runtime_dependency('mysql')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('bundler')
  s.add_development_dependency('yard')
  s.add_development_dependency('rake')
  s.extra_rdoc_files = ['README.md', 'LICENSE.md', 'CHANGELOG.md'] +
    FileList['doc/**/*.md']
  s.rdoc_options = ['-m', 'README.md']
#  s.platform = Gem::Platform::CURRENT
  s.required_ruby_version = '>= 1.8.7'
  s.files = FileList['lib/**/*.rb',
                     'lib/**/*.class',
                     'doc/**/*.md',
                     'README.md',
                     'LICENSE.md',
                     'CHANGELOG.md',
                     '.yardopts'
                    ].to_a
# This is executed if we run <gem test>.
# s.test_files = FileList['test/**/*.rb'].to_a
  s.license = 'GPL-2.0'
  s.post_install_message = <<-EOS

Thank you for installing Shalmaneser #{Shalmaneser::VERSION}!

This software package has multiple external dependencies:
- OpenNLP Maximum Entropy Classifier;
- Berkeley Parser;
- Stanford Parser;
- Collins Parser;
- TreeTagger;
- MySQL Database Server etc.

Please proceede to installation instructions:
https://github.com/arbox/shalmaneser/blob/1.2/doc/index.md

If you find any bugs or have questions consider opeing a ticket:
https://github.com/arbox/shalmaneser/issues

  EOS
  # How to use this?
  s.requirements << 'mysql-server'
  s.metadata = {
    'issue_tracker' => 'https://github.com/arbox/shalmaneser/issues',
  }
end
