# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in pwsh.gemspec
gemspec

def location_for(place_or_version, fake_version = nil)
  git_url_regex = %r{\A(?<url>(https?|git)[:@][^#]*)(#(?<branch>.*))?}
  file_url_regex = %r{\Afile:\/\/(?<path>.*)}

  if place_or_version && (git_url = place_or_version.match(git_url_regex))
    [fake_version, { git: git_url[:url], branch: git_url[:branch], require: false }].compact
  elsif place_or_version && (file_url = place_or_version.match(file_url_regex))
    ['>= 0', { path: File.expand_path(file_url[:path]), require: false }]
  else
    [place_or_version, { require: false }]
  end
end

group :development do
  gem 'faraday-retry'
  gem 'fuubar'
  gem 'pry'
  gem 'pry-stack_explorer'
  gem 'yard'
end

group :test do
  gem 'puppet', *location_for(ENV['PUPPET_LOCATION'])

  gem 'ffi'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.0'
  gem 'rspec-collection_matchers', '~> 1.0'
  gem 'rspec-its', '~> 1.0'
  gem 'rubocop', '~> 1.48', require: false
  gem 'rubocop-performance', '~> 1.16', require: false
  gem 'rubocop-rspec', '~> 2.19', require: false
  gem 'simplecov', require: false
end

