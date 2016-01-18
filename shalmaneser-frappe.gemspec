lib_path = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'rake'
require 'definitions'

# Define a constant here to use this spec in the Rakefile.
Gem::Specification.new do |s|
  s.name = 'shalmaneser-frappe'
  s.summary = 'FRAPPE'
  s.description = 'Frappe - Fred and Rosy PreProcEssor.'
  s.version = Shalmaneser::Frappe::VERSION
  s.author = 'Andrei Beliankou'
  s.email = 'arbox@yandex.ru'
  s.homepage = 'https://github.com/arbox/shalmaneser'
  s.extra_rdoc_files = %w(README.md LICENSE.md CHANGELOG.md)
  s.rdoc_options = ['-m', 'README.md']
  s.required_ruby_version = '>= 2.0'
  # s.add_runtime_dependency('stxml', '~> 0.1')
  s.add_runtime_dependency('nokogiri', '~> 1.6')
  s.add_runtime_dependency('tokenizer', '~> 0.2')
  s.add_runtime_dependency('shalmaneser-lib', s.version)
  s.license = ::Shalmaneser::LICENSE
  s.files = FileList['lib/frappe/**/*.rb',
                     'lib/shalmaneser/frappe.rb',
                     'lib/doc/**/*.rb',
                     'README.md',
                     'LICENSE.md',
                     'CHANGELOG.md',
                     '.yardopts'
                    ].to_a
  # s.test_files = FileList['test/**/*.rb'].to_a
end
