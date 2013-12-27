# A sample Gemfile
source "http://rubygems.org"

gem 'mysql'

group :development do
  gem 'yard'
  gem 'rdoc'
  gem 'rake'
end

case RUBY_VERSION
when /^1.8/
  gem 'ruby-debug', :group => :development
else
  gem 'debugger', :group => :development
end

