lib_path = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

# Rake provides FileUtils and its own FileUtils extensions
require 'rake'
require 'rake/clean'
require 'erb'

CLEAN.include('.*~')
CLOBBER.include('ydoc',
                'rdoc',
                '.yardoc',
                '*.gem')

task clobber: [:remove_exp_files, :remove_test_output]

# Generate documentation.
require 'rdoc/task'
RDoc::Task.new do |rdoc|
  rdoc.rdoc_files.include('README.md',
                          'LICENSE.md',
                          'CHANGELOG.md',
                          'lib/**/*',
                          'bin/**/*',
                          'doc/**/*.md'
                          )
  rdoc.rdoc_dir = 'rdoc'
end

require 'yard'
YARD::Rake::YardocTask.new(name = :ydoc) do |t|
  t.options += ['-o', 'ydoc']
  t.files = ['lib/**/*.rb', 'bin/**/*', '-', 'doc/index.md', 'doc/exp_files.md']
end

# Testing.
require 'rake/testtask'
Rake::TestTask.new(test: [:remove_exp_files, :remove_test_output]) do |t|
  t.libs << 'test'
  t.warning
  t.ruby_opts = ['-rubygems'] # not necessary now
  t.test_files = FileList['test/**/*.rb']
end

Rake::TestTask.new(test_functional: [:remove_exp_files, :remove_test_output]) do |t|
  t.libs << 'test'
  t.warning
  t.ruby_opts = ['-rubygems']
  t.test_files = FileList['test/functional/test_*.rb']
end

Rake::TestTask.new(:test_prep) do |t|
  t.libs << 'test'
  t.warning
  t.ruby_opts = ['-rubygems']
  t.test_files = FileList['test/frprep/test_*.rb']
end

desc 'Remove generated experiment files.'
task :remove_exp_files do
  files = FileList.new('test/functional/sample_experiment_files/*') do |f|
    f.exclude(/.erb$/)
  end

  File.delete(*files)
end

# In the <output> dir are only dirs to be found, no files.
desc 'Remove output of functional tests.'
task :remove_test_output do
  dirs = FileList.new('test/functional/output/*') do |d|
    d.exclude(/tmp$/)
    d.exclude(/trash$/)
  end
  FileUtils.rm_rf(dirs)
end

desc 'Generate sample experiment files.'
task :generate_experiment_files do
  files = FileList.new('test/functional/sample_experiment_files/*.erb')
  files.each do |f|
    template = File.read(f)
    text = ERB.new(template).result(binding)
    File.open(f.chomp('.erb'), 'w') do |out_file|
      out_file.write(text)
    end
  end
end

desc 'Build java dependencies.'
task :build_java_dependencies do
  cp = "tools/maxent/maxent-2.4.0/output/maxent-2.4.0.jar:#{ENV['CLASSPATH']}"
  sh "javac -cp #{cp} lib/ext/maxent/*.java"
end

desc 'Publish the documentation on the homepage.'
task publish: [:clobber, :ydoc] do
  system "scp -r ydoc/* #{File.read('SENSITIVE').chomp}"
end

desc 'Dummy task for TravisCI'
task :travis do
  # do nothing for now
end

desc 'Open an irb session preloaded with this library.'
task :irb do
  require 'irb'
  require 'irb/completion'
  require 'shalmaneser'
  ARGV.clear
  IRB.start
end

desc 'Open a Pry session in the context of this library.'
task :pry do
  require 'pry'
  require 'shalmaneser'
  ARGV.clear
  Pry.start
end

namespace :build do
  desc 'Make all.'
  task :shalmaneser => [:frappuccino, :fred, :rosy] do
    sh 'bundle exec gem build shalmaneser.gemspec'
  end
  task :frappuccino do
    sh 'bundle exec gem build shalmaneser-prep.gemspec'
  end
  task :fred do
    sh 'bundle exec gem build shalmaneser-fred.gemspec'
  end
  task :rosy do
    sh 'bundle exec gem build shalmaneser-rosy.gemspec'
  end
end
