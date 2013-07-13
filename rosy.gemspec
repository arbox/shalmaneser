lib_path = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'rake'
#require 'shalmaneser/version'

# Define a constant here to use this spec in the Rakefile.
Gem::Specification.new do |s|
  s.name = 'rosy'
  # it is the description for 'gem list -d'
  s.summary = 'ROSY'
  s.description = 'ROSY - ROle assignment SYstem.'
  s.version = '0.0.1.prealpha'
  s.author = "Andrei Beliankou"
  s.email = "a.belenkow@uni-trier.de"
  s.homepage = "http://www.uni-trier.de/index.php?id=34451"
#  s.bindir = 'bin'
#  s.executables = ['frprep', 'fred', 'rosy']
#  s.add_runtime_dependency('mysql')
#  s.add_development_dependency('rdoc', '>=3.9.1')
#  s.add_development_dependency('bundler')
#  s.add_development_dependency('yard')
#  s.add_development_dependency('rake')
  s.extra_rdoc_files = ['README.rdoc', 'LICENSE.rdoc', 'CHANGELOG.rdoc']
  s.rdoc_options = ['-m', 'README.rdoc']
#  s.platform = Gem::Platform::CURRENT
  s.required_ruby_version = '1.8.7'
  s.files = FileList['lib/**/*.rb',
                     'README.rdoc',
                     'LICENSE.rdoc',
                     'CHANGELOG.rdoc',
                     '.yardopts',
                     'test/**/*.rb',
                     'test/**/*.erb',
                     'ext/**/**'
                    ].to_a
  s.test_files = FileList['test/**/*.rb'].to_a
end
