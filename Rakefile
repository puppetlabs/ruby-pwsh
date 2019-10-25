# frozen_string_literal: true

require 'rubocop/rake_task'
require 'fileutils'
require 'github_changelog_generator/task'
require 'open3'
require 'pwsh/version'
require 'rspec/core/rake_task'
require 'yard'

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'puppetlabs'
  config.project = 'ruby-pwsh'
  config.future_release = Pwsh::VERSION
  config.since_tag = '0.0.1'
  config.exclude_labels = ['maintenance']
  config.header = "# Change log\n\nAll notable changes to this project will be documented in this file." \
                  'The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).'
  config.add_pr_wo_labels = true
  config.issues = false
  config.merge_prefix = '### UNCATEGORIZED PRS; GO LABEL THEM'
  config.configure_sections = {
    'Changed' => {
      'prefix' => '### Changed',
      'labels' => %w[backwards-incompatible]
    },
    'Added' => {
      'prefix' => '### Added',
      'labels' => %w[feature enhancement]
    },
    'Fixed' => {
      'prefix' => '### Fixed',
      'labels' => %w[bugfix]
    }
  }
end

RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = %w[-D -S -E]
end

RSpec::Core::RakeTask.new(:spec)
task default: :spec

YARD::Rake::YardocTask.new do |t|
end

# Executes a command locally.
#
# @param command [String] command to execute.
# @return [Object] the standard out stream.
def run_local_command(command)
  stdout, stderr, status = Open3.capture3(command)
  error_message = "Attempted to run\ncommand:'#{command}'\nstdout:#{stdout}\nstderr:#{stderr}"
  raise error_message unless status.to_i.zero?

  stdout
end

# Build the gem
desc 'Build the gem'
task :build do
  gemspec_path = File.join(Dir.pwd, 'ruby-pwsh.gemspec')
  # Delete the puppet-specific code if it exists
  FileUtils.rm_r('lib/puppet') if File.exist?('lib/puppet')
  run_local_command("bundle exec gem build '#{gemspec_path}'")
end

# Tag the repo with a version in preparation for the release
#
# @param :version [String] a semantic version to tag the code with
# @param :sha [String] the sha at which to apply the version tag
desc 'Tag the repo with a version in preparation for release'
task :tag, [:version, :sha] do |_task, args|
  raise "Invalid version #{args[:version]} - must be like '1.2.3'" unless args[:version] =~ /^\d+\.\d+\.\d+$/

  run_local_command('git fetch upstream')
  run_local_command("git tag -a version -m #{args[:version]} #{args[:sha]}")
  run_local_command('git push upstream --tags')
end

# Push the built gem to RubyGems
#
# @param :path [String] optional, the full or relative path to the built gem to be pushed
desc 'Push to RubyGems'
task :push, [:path] do |_task, args|
  raise 'No discoverable gem for pushing' if Dir.glob("ruby-pwsh*\.gem").empty? && args[:path].nil?
  raise "No file found at specified path: '#{args[:path]}'" unless File.exist?(args[:path])

  path = args[:path] || File.join(Dir.pwd, Dir.glob("ruby-pwsh*\.gem")[0])
  run_local_command("bundle exec gem push #{path}")
end

desc 'Build for Puppet'
task :build_module do
  # Ready for module building
  content = "require 'puppet/util/feature'\n\nPuppet.features.add(:ruby_pwsh, :libs => ['ruby-pwsh'])\n"
  feature_path = 'lib/puppet/feature/ruby_pwsh.rb'
  unless File.exist?(feature_path) ? File.read(feature_path) == content : false
    FileUtils.mkdir_p(File.dirname(feature_path))
    File.open(feature_path, 'wb') { |file| file.write(content) }
  end
  actual_readme_content = File.read('README.md')
  FileUtils.copy_file('pwshlib.md', 'README.md')
  # Build
  run_local_command('pdk build --force')
  # Cleanup
  File.open('README.md', 'wb') { |file| file.write(actual_readme_content) }
  FileUtils.rm_r('lib/puppet') if File.exist?('lib/puppet')
end
