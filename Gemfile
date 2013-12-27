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
when /^1.9/
  unless RUBY_PLATFORM =~ /java/
    gem 'debugger', :group => :development
  end
when /^2.0/
  gem 'debugger', :group => :development
when /^2.1/
  # not doing anything for now
end

