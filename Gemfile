# For puppetcore, set GEM_SOURCE_PUPPETCORE = 'https://rubygems-puppetcore.puppet.com'
gemsource_default = ENV['GEM_SOURCE'] || 'https://rubygems.org'
gemsource_puppetcore = if ENV['PUPPET_FORGE_TOKEN'] && !ENV['PUPPET_FORGE_TOKEN'].empty?
                         'https://rubygems-puppetcore.puppet.com'
                       else
                         ENV['GEM_SOURCE_PUPPETCORE'] || gemsource_default
                       end
source gemsource_default

gem "rexml", require: false

def location_for(place_or_version, fake_version = nil, opts = {})
  git_url_regex = %r{\A(?<url>(https?|git)[:@][^#]*)(#(?<branch>.*))?}
  file_url_regex = %r{\Afile:\/\/(?<path>.*)}

  if place_or_version && (git_url = place_or_version.match(git_url_regex))
    [fake_version, { git: git_url[:url], branch: git_url[:branch], require: false }].compact
  elsif place_or_version && (file_url = place_or_version.match(file_url_regex))
    ['>= 0', { path: File.expand_path(file_url[:path]), require: false }]
  else
    [place_or_version, { require: false }.merge(opts)]
  end
end

group :development do
  gem "json", '2.11.3',                         require: false if Gem::Requirement.create(['>= 3.1.0', '< 3.1.3']).satisfied_by?(Gem::Version.new(RUBY_VERSION.dup))
  gem "json", '2.11.3',                         require: false if Gem::Requirement.create(['>= 3.2.0', '< 4.0.0']).satisfied_by?(Gem::Version.new(RUBY_VERSION.dup))
  gem "deep_merge", '~> 1.0',                    require: false
  gem "voxpupuli-puppet-lint-plugins", '~> 7.0', require: false
  gem "facterdb", '~> 4.0',                      require: false
  gem "metadata-json-lint", '~> 4.0',            require: false
  gem "rspec-puppet-facts", '~> 6.0',            require: false
  gem "dependency_checker", '~> 1.0.0',          require: false
  gem "parallel_tests", '3.13.0',              require: false
  gem "pry", '~> 0.10',                          require: false
  gem "simplecov-console", '~> 0.9',             require: false
  gem "puppet-debugger", '~> 1.0',               require: false
  gem "rubocop", '~> 1.70.0',                    require: false
  gem "rubocop-performance", '1.22.1',         require: false
  gem "rubocop-rspec", '= 2.19.0',               require: false
  gem "rb-readline", '= 0.5.5',                  require: false, platforms: [:mswin, :mingw, :x64_mingw]
end
group :development, :release_prep do
  gem "puppet-strings", '~> 4.0',         require: false
  gem "puppetlabs_spec_helper", '~> 9.0', require: false
end
group :system_tests do
  gem "CFPropertyList", '< 3.0.7', require: false, platforms: [:mswin, :mingw, :x64_mingw]
  gem "ffi",                       require: false, platforms: [:mswin, :mingw, :x64_mingw]
  gem "serverspec", '~> 2.41',     require: false
end

puppet_version = ENV['PUPPET_GEM_VERSION']
facter_version = ENV['FACTER_GEM_VERSION']
hiera_version = ENV['HIERA_GEM_VERSION']

gems = {}

gemsource_facter = if Gem.ruby_version >= Gem::Version.new('4.0')
                     gemsource_puppetcore
                   else
                     gemsource_default
                   end

gems['puppet'] = location_for(puppet_version, nil, { source: gemsource_puppetcore })
gems['facter'] = location_for(facter_version, nil, { source: gemsource_facter })

# If a hiera version has been specified via the environment variable

gems['hiera'] = location_for(hiera_version) if hiera_version

gems.each do |gem_name, gem_params|
  gem gem_name, *gem_params
end

# Evaluate Gemfile.local and ~/.gemfile if they exist
extra_gemfiles = [
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile'),
]

extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding)
  end
end
# vim: syntax=ruby
