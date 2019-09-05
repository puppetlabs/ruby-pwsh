# frozen_string_literal: true

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
      !!File::ALT_SEPARATOR # rubocop:disable Style/DoubleNegation
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
