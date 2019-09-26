# frozen_string_literal: true

require 'rubocop/rake_task'
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
  path = args[:path] || File.join(Dir.pwd, Dir.glob("ruby-pwsh*\.gem")[0])
  run_local_command("bundle exec gem push #{path}")
end
