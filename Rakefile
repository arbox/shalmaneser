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
namespace :doc do
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
  YARD::Rake::YardocTask.new(:ydoc) do |t|
    t.options += ['-o', 'ydoc']
    t.files = ['lib/**/*.rb',
               'bin/**/*',
               '-',
               'doc/index.md',
               'doc/exp_files.md']
  end
end

# Testing.
require 'rake/testtask'

namespace :test do
  desc 'Testing everything.'
  task all: [:'functional:all', :'unit:all', :'integration:all']

  # Functional tests for the whole system (Shalmaneser) and
  # all it's subsystems: FrPrep, Fred, Rosy.
  namespace :functional do
    desc 'Run all functional tests.'
    task :all => [:shalmaneser, :frappuccino, :fred, :rosy]

    Rake::TestTask.new(:shalmaneser => :'test:cleanup') do |t|
      # @TODO: Write real tests for Shalmaneser.
      t.libs << 'test'
      t.warning = true
      t.test_files = []
      t.verbose = true
      # t.test_files = FileList['test/functional/test_*.rb']
    end

    Rake::TestTask.new(:frappuccino => :'test:cleanup') do |t|
      t.libs << 'test'
      t.warning = true
      t.test_files = FileList['test/functional/test_frprep.rb']
    end

    Rake::TestTask.new(:fred => :'test:cleanup') do |t|
      t.libs << 'test'
      t.warning = true
      t.test_files = FileList['test/functional/test_fred.rb']
    end

    Rake::TestTask.new(:rosy => :'test:cleanup') do |t|
      t.libs << 'test'
      t.warning = true
      t.test_files = FileList['test/functional/test_rosy.rb']
    end
  end

  # Unit testing.
  namespace :unit do
    desc 'Run all unit tests.'
    task :all => [:frappuccino, :fred, :rosy]

    Rake::TestTask.new(:frappuccino) do |t|
      t.libs << 'test'
      t.warning = true
      t.description = 'Run all Preprocessor Tests.'
      t.test_files = FileList['test/frprep/test_*.rb']
    end

    task :fred
    task :rosy
  end

  # Integration of external tools:
  #  - Berkeley Parser
  #  - Stanford Parser
  #  - TreeTagger
  #  - Collins Parser
  #  - Minipar
  namespace :integration do
    # @TODO: Write more specs!
    task :all
  end

  desc 'Remove older temporal files from last test runs.'
  task :cleanup => [:remove_exp_files, :remove_test_output]
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

namespace :release do
  desc 'Publish the documentation on the homepage.'
  task publish: [:clobber, :ydoc] do
    system "scp -r ydoc/* #{File.read('SENSITIVE').chomp}"
  end
end

namespace :build do
  desc 'Make all.'
  task :shalmaneser => [:frappuccino, :fred, :rosy] do
    sh 'bundle exec gem build shalmaneser.gemspec'
  end

  desc 'Make Frappuccion.'
  task :frappuccino => :java do
    sh 'bundle exec gem build shalmaneser-prep.gemspec'
  end

  desc 'Make Fred.'
  task :fred do
    sh 'bundle exec gem build shalmaneser-fred.gemspec'
  end

  desc 'Make Rosy.'
  task :rosy do
    sh 'bundle exec gem build shalmaneser-rosy.gemspec'
  end

  desc 'Build java extensions.'
  task :java do
    # @TODO: This task should be file based.
    cp = "tools/maxent/maxent-2.4.0/output/maxent-2.4.0.jar:#{ENV['CLASSPATH']}"
    sh "javac -cp #{cp} lib/ext/maxent/*.java"
  end
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
