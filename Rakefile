# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'fileutils'
require 'open3'
require 'pwsh/version'
require 'rspec/core/rake_task'
require 'puppet_litmus/rake_tasks'
require 'puppetlabs_spec_helper/rake_tasks'
require 'yard'

namespace :spec do
  task :simplecov do
    ENV['COVERAGE'] = 'yes'
    Rake::Task['spec'].execute
  end
end

YARD::Rake::YardocTask.new do |t|
end
