# frozen_string_literal: true

if ENV['COVERAGE'] == 'yes'
  begin
    require 'simplecov'
    require 'simplecov-console'

    SimpleCov.formatters = [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console
    ]

    if ENV['CI'] == 'true'
      require 'codecov'
      SimpleCov.formatters << SimpleCov::Formatter::Codecov
    end

    SimpleCov.start do
      track_files 'lib/**/*.rb'

      add_filter '/spec'
      add_filter 'lib/pwsh/version.rb'

      # do not track vendored files
      add_filter '/vendor'
      add_filter '/.vendor'
    end
  rescue LoadError
    raise 'Add the simplecov, simplecov-console, codecov gems to Gemfile to enable this task'
  end
end

require 'bundler/setup'
require 'ruby-pwsh'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
