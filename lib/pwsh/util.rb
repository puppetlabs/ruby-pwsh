# frozen_string_literal: true

# Manage PowerShell and Windows PowerShell via ruby
module Pwsh
  # Various helper methods
  module Util
    module_function

    # Verifies whether or not the current context is running on a Windows node.
    #
    # @return [Bool] true if on windows
    def on_windows?
      # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
      # library uses that to test what platform it's on.
      !!File::ALT_SEPARATOR
    end

    # Verify paths specified are valid directories which exist.
    #
    # @return [Bool] true if any directories specified do not exist
    def invalid_directories?(path_collection)
      invalid_paths = false

      return invalid_paths if path_collection.nil? || path_collection.empty?

      paths = on_windows? ? path_collection.split(';') : path_collection.split(':')
      paths.each do |path|
        invalid_paths = true unless File.directory?(path) || path.empty?
      end

      invalid_paths
    end

    # Return a string or symbol converted to snake_case
    #
    # @return [String] snake_cased string
    def snake_case(object)
      # Implementation copied from: https://github.com/rubyworks/facets/blob/master/lib/core/facets/string/snakecase.rb
      # gsub(/::/, '/').
      should_symbolize = object.is_a?(Symbol)
      raise "snake_case method only handles strings and symbols, passed a #{object.class}: #{object}" unless should_symbolize || object.is_a?(String)

      text = object.to_s
                   .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                   .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                   .tr('-', '_')
                   .gsub(/\s/, '_')
                   .gsub(/__+/, '_')
                   .downcase
      should_symbolize ? text.to_sym : text
    end

    # Iterate through a hashes keys, snake_casing them
    #
    # @return [Hash] Hash with all keys snake_cased
    def snake_case_hash_keys(object)
      snake_case_proc = proc { |key| snake_case(key) }
      apply_key_mutator(object, snake_case_proc)
    end

    # Return a string or symbol converted to PascalCase
    #
    # @return [String] PascalCased string
    def pascal_case(object)
      should_symbolize = object.is_a?(Symbol)
      raise "snake_case method only handles strings and symbols, passed a #{object.class}: #{object}" unless should_symbolize || object.is_a?(String)

      # Break word boundaries to snake case first
      text = snake_case(object.to_s).split('_').collect(&:capitalize).join
      should_symbolize ? text.to_sym : text
    end

    # Iterate through a hashes keys, PascalCasing them
    #
    # @return [Hash] Hash with all keys PascalCased
    def pascal_case_hash_keys(object)
      pascal_case_proc = proc { |key| pascal_case(key) }
      apply_key_mutator(object, pascal_case_proc)
    end

    # Ensure that quotes inside a passed string will continue to be passed
    #
    # @return [String] the string with quotes escaped
    def escape_quotes(text)
      text.gsub("'", "''")
    end

    # Ensure that all keys in a hash are symbols, not strings.
    #
    # @return [Hash] a hash whose keys have been converted to symbols.
    def symbolize_hash_keys(object)
      symbolize_proc = proc(&:to_sym)
      apply_key_mutator(object, symbolize_proc)
    end

    def apply_key_mutator(object, proc)
      return object.map { |item| apply_key_mutator(item, proc) } if object.is_a?(Array)
      return object unless object.is_a?(Hash)

      modified_hash = {}
      object.each do |key, value|
        modified_hash[proc.call(key)] = apply_key_mutator(value, proc)
      end
      modified_hash
    end

    private_class_method :apply_key_mutator

    # Convert a ruby value into a string to be passed along to PowerShell for interpolation in a command
    # Handles:
    # - Strings
    # - Numbers
    # - Booleans
    # - Symbols
    # - Arrays
    # - Hashes
    #
    # @return [String] representation of the value for interpolation
    def format_powershell_value(object)
      if %i[true false].include?(object) || %w[trueclass falseclass].include?(object.class.name.downcase) # rubocop:disable Lint/BooleanSymbol
        "$#{object}"
      elsif object.class.name == 'Symbol' || object.class.ancestors.include?(Numeric)
        object.to_s
      elsif object.class.name == 'String'
        "'#{escape_quotes(object)}'"
      elsif object.class.name == 'Array'
        '@(' + object.collect { |item| format_powershell_value(item) }.join(', ') + ')'
      elsif object.class.name == 'Hash'
        '@{' + object.collect { |k, v| format_powershell_value(k) + ' = ' + format_powershell_value(v) }.join('; ') + '}'
      else
        raise "unsupported type #{object.class} of value '#{object}'"
      end
    end

    # Return the representative string of a PowerShell hash for a custom object property to be used in selecting or filtering.
    # The script block for the expression must be passed as the string you want interpolated into the hash; this method does
    # not do any of the additional work of interpolation for you as the type sits inside a code block inside a hash.
    #
    # @return [String] representation of a PowerShell hash with the keys 'Name' and 'Expression'
    def custom_powershell_property(name, expression)
      "@{Name = '#{name}'; Expression = {#{expression}}}"
    end
  end
end

# POWERSHELL_MODULE_UPGRADE_MSG ||= <<-UPGRADE
# Currently, the PowerShell module has reduced v1 functionality on this machine
# due to the following condition:

# - PowerShell v2 with .NET Framework 2.0

#   PowerShell v2 works with both .NET Framework 2.0 and .NET Framework 3.5.
#   To be able to use the enhancements, we require .NET Framework 3.5.
#   Typically you will only see this on a base Windows Server 2008 (and R2)
#   install.

# To enable these improvements, it is suggested to  ensure you have .NET Framework
# 3.5 installed.
# UPGRADE

# TODO: Generalize this upgrade message to be independent of Puppet
# def upgrade_message
#   # Puppet.warning POWERSHELL_MODULE_UPGRADE_MSG if !@upgrade_warning_issued
#   @upgrade_warning_issued = true
# end
