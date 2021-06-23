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
  config.since_tag = '0.1.0'
  config.exclude_labels = ['maint']
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
  run_local_command("git tag -a #{args[:version]} -m #{args[:version]} #{args[:sha]}")
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
  actual_readme_content = File.read('README.md')
  FileUtils.copy_file('pwshlib.md', 'README.md')
  # Build
  run_local_command('pdk build --force')
  # Cleanup
  File.open('README.md', 'wb') { |file| file.write(actual_readme_content) }
end

# Used in vendor_dsc_module
TAR_LONGLINK = '././@LongLink'

# Vendor a Puppetized DSC Module to spec/fixtures/modules.
#
# This is necessary because `puppet module install` fails on modules with
# long file paths, like xpsdesiredstateconfiguration
#
# @param command [String] command to execute.
# @return [Object] the standard out stream.
def vendor_dsc_module(name, version, destination)
  require 'open-uri'
  require 'rubygems/package'
  require 'zlib'

  module_uri = "https://forge.puppet.com/v3/files/dsc-#{name}-#{version}.tar.gz"
  tar_gz_archive = File.expand_path("#{name}.tar.gz", ENV['TEMP'])

  # Download the archive from the forge
  File.open(tar_gz_archive, 'wb') do |file|
    file.write(URI.open(module_uri).read) # rubocop:disable Security/Open
  end

  # Unzip to destination
  # Taken directly from StackOverflow:
  # - https://stackoverflow.com/a/19139114
  Gem::Package::TarReader.new(Zlib::GzipReader.open(tar_gz_archive)) do |tar|
    dest = nil
    tar.each do |entry|
      if entry.full_name == TAR_LONGLINK
        dest = File.join(destination, entry.read.strip)
        next
      end
      dest ||= File.join(destination, entry.full_name)
      if entry.directory?
        File.delete(dest) if File.file?(dest)
        FileUtils.mkdir_p(dest, mode: entry.header.mode, verbose: false)
      elsif entry.file?
        FileUtils.rm_rf(dest) if File.directory?(dest)
        File.open(dest, 'wb') do |f|
          f.print(entry.read)
        end
        FileUtils.chmod(entry.header.mode, dest, verbose: false)
      elsif entry.header.typeflag == '2' # Symlink!
        File.symlink(entry.header.linkname, dest)
      end
      dest = nil
    end
  end

  # Rename folder to just the module name, as needed by Puppet
  Dir.glob("#{destination}/*#{name}*").each do |existing_folder|
    new_folder = File.expand_path(name, destination)
    FileUtils.mv(existing_folder, new_folder)
  end
end

namespace :dsc do
  namespace :acceptance do
    desc 'Prep for running DSC acceptance tests'
    task :spec_prep do
      # Create the modules fixture folder, if needed
      modules_folder = File.expand_path('spec/fixtures/modules', File.dirname(__FILE__))
      FileUtils.mkdir_p(modules_folder) unless Dir.exist?(modules_folder)
      # symlink the parent folder to the modules folder for puppet
      symlink_path = File.expand_path('pwshlib', modules_folder)
      File.symlink(File.dirname(__FILE__), symlink_path) unless Dir.exist?(symlink_path)
      # Install each of the required modules for acceptance testing
      # Note: This only works for modules in the dsc namespace on the forge.
      puppetized_dsc_modules = [
        { name: 'powershellget', version: '2.2.5-0-1' },
        { name: 'jeadsc', version: '0.7.2-0-2' }, # update to 0.7.2-0-3 on release
        { name: 'xpsdesiredstateconfiguration', version: '9.1.0-0-1' },
        { name: 'xwebadministration', version: '3.2.0-0-2' }
      ]
      puppetized_dsc_modules.each do |puppet_module|
        next if Dir.exist?(File.expand_path(puppet_module[:name], modules_folder))

        vendor_dsc_module(puppet_module[:name], puppet_module[:version], modules_folder)
      end
    end
    RSpec::Core::RakeTask.new(:spec) do |t|
      t.pattern = 'spec/acceptance/dsc/*.rb'
    end
  end
end
