lib_path = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'rake'
require 'common/definitions'

# Define a constant here to use this spec in the Rakefile.
Gem::Specification.new do |s|
  s.name = 'shalmaneser-prep'
  s.summary = 'Frappe'
  s.description = 'Frappe - Fred and Rosy PREProcessor.'
  s.version = Shalmaneser::Frappe::VERSION
  s.author = 'Andrei Beliankou'
  s.email = 'arbox@yandex.ru'
  s.homepage = 'https://github.com/arbox/shalmaneser'
  s.extra_rdoc_files = %w(README.md LICENSE.md CHANGELOG.md)
  s.rdoc_options = ['-m', 'README.md']
  s.required_ruby_version = '2.0'
  s.license = 'GPL-2.0'
  s.files = FileList['lib/frappe/**/*.rb',
                     'README.md',
                     'LICENSE.md',
                     'CHANGELOG.md',
                     '.yardopts',
                     'ext/**/*.java'
                    ].to_a
  s.test_files = FileList['test/**/*.rb'].to_a
end