# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in pwsh.gemspec
gemspec

group :test do
  gem 'ffi'
  gem 'rake', '>= 10.0'
  gem 'rspec', '~> 3.0'
  gem 'rspec-collection_matchers', '~> 1.0'
  gem 'rspec-its', '~> 1.0'
  gem 'rubocop', '>= 0.77'
  gem 'rubocop-rspec'
  gem 'simplecov'
end

group :development do
  gem 'github_changelog_generator', '~> 1.15' if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.3.0')
  gem 'yard'
end

group :puppet do
  gem 'pdk', '~> 1.0'
end

group :pry do
  gem 'fuubar'

  if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.4.0')
    gem 'pry-byebug'
  else
    gem 'pry-debugger'
  end

  gem 'pry-stack_explorer'
end

# Evaluate Gemfile.local and ~/.gemfile if they exist
extra_gemfiles = [
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile')
]

extra_gemfiles.each do |gemfile|
  eval(File.read(gemfile), binding) if File.file?(gemfile) && File.readable?(gemfile) # rubocop:disable Security/Eval
end
# vim: syntax=ruby
