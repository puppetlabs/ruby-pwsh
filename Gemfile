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
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'simplecov'
end

group :development do
  # TODO: Use gem instead of git. Section mapping is merged into master, but not yet released
  gem 'github_changelog_generator', git: 'https://github.com/skywinder/github-changelog-generator.git', ref: '20ee04ba1234e9e83eb2ffb5056e23d641c7a018'
  gem 'yard'
end

group :pry do
  gem 'fuubar'

  if RUBY_VERSION == '1.8.7'
    gem 'debugger'
  elsif RUBY_VERSION =~ /^2\.[01]/
    gem 'byebug', '~> 9.0.0'
    gem 'pry-byebug'
  elsif RUBY_VERSION =~ /^2\.[23456789]/
    gem 'pry-byebug' # rubocop:disable Bundler/DuplicatedGem
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
