# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pwsh/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby-pwsh'
  spec.version       = Pwsh::VERSION
  spec.authors       = ['Puppet, Inc.']
  spec.email         = ['info@puppet.com']

  spec.summary       = 'PowerShell code manager for ruby.'
  spec.description   = 'PowerShell code manager for ruby.'
  spec.homepage      = 'https://github.com/puppetlabs/ruby-pwsh'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/puppetlabs/ruby-pwsh'
    spec.metadata['changelog_uri'] = 'https://github.com/puppetlabs/ruby-pwsh'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = Dir[
    'README.md',
    'LICENSE',
    '.rubocop.yml',
    'lib/**/*',
    'bin/**/*',
    'spec/**/*',
  ]

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
