lib_path = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'rake'
require 'definitions'

# Define a constant here to use this spec in the Rakefile.
Gem::Specification.new do |s|
  s.name = 'shalmaneser-lib'
  s.summary = 'Shalmaneser Library'
  s.description = 'Common facilities for Shalmaneser and its modules.'
  s.version = ::Shalmaneser::Shalmaneser::VERSION
  s.author = 'Andrei Beliankou'
  s.email = 'arbox@yandex.ru'
  s.homepage = 'https://github.com/arbox/shalmaneser'
  s.extra_rdoc_files = %w(README.md LICENSE.md CHANGELOG.md)
  s.rdoc_options = ['-m', 'README.md']
  s.required_ruby_version = '>= 2.0'
  s.add_runtime_dependency('pastel', '~> 0.5')
  s.license = ::Shalmaneser::LICENSE
  s.files = FileList['lib/*.rb',
                     'lib/shalmaneser/lib.rb',
                     'lib/configuration/**/*.rb',
                     'lib/db/**/*.rb',
                     'lib/ext/**/*.class',
                     'lib/framenet_format/**/*.rb',
                     'lib/tabular_format/**/*.rb',
                     'lib/ml/**/*.rb',
                     'lib/monkey_patching/**/*.rb',
                     'lib/salsa_tiger_xml/**/*.rb',
                     'lib/doc/**/*.md',
                     'README.md',
                     'LICENSE.md',
                     'CHANGELOG.md',
                     '.yardopts'
                    ].to_a.reject { |fn| fn =~ /lib\/(shalmaneser|option_parser)\.rb/ }
  # s.test_files = FileList['test/**/*.rb'].to_a
end
