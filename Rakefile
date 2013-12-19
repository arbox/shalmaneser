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

task :clobber => [:remove_exp_files, :remove_test_output]

# Generate documentation.
require 'rdoc/task'
RDoc::Task.new do |rdoc|
  rdoc.rdoc_files.include('README.rdoc',
                          'LICENSE.rdoc',
                          'CHANGELOG.rdoc',
                          'lib/**/*',
                          'bin/**/*'
                          )
  rdoc.rdoc_dir = 'rdoc'
end

require 'yard'
YARD::Rake::YardocTask.new do |ydoc|
  ydoc.options += ['-o', 'ydoc']
  ydoc.name = 'ydoc'
end

# Testing.
require 'rake/testtask'
Rake::TestTask.new(:test => [:remove_exp_files, :remove_test_output]) do |t|
  t.libs << 'test'
  t.warning
#  t.ruby_opts = ['-rubygems'] # not necessary now
  t.test_files = FileList['test/**/*.rb']
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
  end
  FileUtils.rm_rf(dirs)
end

desc 'Generate sample experiment files.'
task :generate_experiment_files do
  files = FileList.new('test/functional/sample_experiment_files/*.erb')
  files.each do |f|
    template = File.read(f)
    text = ERB.new(template).result
    File.open(f.chomp('.erb'), 'w') do |out_file|
      out_file.write(text)
    end
  end

end
