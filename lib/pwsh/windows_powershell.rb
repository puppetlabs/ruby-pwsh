# frozen_string_literal: true

require File.join(File.dirname(__FILE__), 'util')

module Pwsh
  # Returns information about the available versions of Windows PowerShell on the node, if any.
  class WindowsPowerShell
    # Return whether or not the latest version of PowerShell available on the machine
    # is compatible with the implementation of the Manager.
    def self.compatible_version?
      # If this method isn't defined, we're not on Windows!
      return false if defined?(Pwsh::WindowsPowerShell.version).nil?

      powershell_version = defined?(Pwsh::WindowsPowerShell.version) ? Pwsh::WindowsPowerShell.version : nil

      # If we get nil, something's gone wrong and we're not compatible.
      return false if powershell_version.nil?

      # PowerShell v1 - definitely not good to go. Really the whole library
      # may not even work but I digress
      return false if Gem::Version.new(powershell_version) < Gem::Version.new(2)

      # PowerShell v3+, we are good to go b/c .NET 4+
      # https://msdn.microsoft.com/en-us/powershell/scripting/setup/windows-powershell-system-requirements
      # Look at Microsoft .NET Framwork Requirements section.
      return true if Gem::Version.new(powershell_version) >= Gem::Version.new(3)

      # If we are using PowerShell v2, we need to see what the latest
      # version of .NET is that we have
      # https://msdn.microsoft.com/en-us/library/hh925568.aspx
      value = false
      if Pwsh::Util.on_windows?
        require 'win32/registry'
        begin
          # At this point in the check, PowerShell is using .NET Framework
          # 2.x family, so we only need to verify v3.5 key exists.
          # If we were verifying all compatible types we would look for
          # any of these keys: v3.5, v4.0, v4
          Win32::Registry::HKEY_LOCAL_MACHINE.open('SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5', Win32::Registry::KEY_READ | 0x100) do
            value = true
          end
        rescue Win32::Registry::Error
          value = false
        end
      end

      value
    end
  end
end

if Pwsh::Util.on_windows?
  require 'win32/registry'
  module Pwsh
    # Returns information about the available versions of Windows PowerShell on the node, if any.
    class WindowsPowerShell
      # Shorthand constant to reference the registry key access type
      ACCESS_TYPE       = Win32::Registry::KEY_READ | 0x100
      # Shorthand constant to reference the local machine hive
      HKLM              = Win32::Registry::HKEY_LOCAL_MACHINE
      # The path to the original version of the Windows PowerShell Engine's data in registry
      PS_ONE_REG_PATH   = 'SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine'
      # The path to the newer version of the Windows PowerShell Engine's data in registry
      PS_THREE_REG_PATH = 'SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine'
      # The name of the registry key for looking up the latest version of Windows PowerShell for a given engine.
      REG_KEY           = 'PowerShellVersion'

      # Returns the latest available version of Windows PowerShell on the machine
      #
      # @return [String] a version string representing the latest version of Windows PowerShell available
      def self.version
        powershell_three_version || powershell_one_version
      end

      # Returns the latest available version of Windows PowerShell using the older
      # engine as determined by checking the registry.
      #
      # @return [String] a version string representing the latest version of Windows PowerShell using the original engine
      def self.powershell_one_version
        version = nil
        begin
          HKLM.open(PS_ONE_REG_PATH, ACCESS_TYPE) do |reg|
            version = reg[REG_KEY]
          end
        rescue
          version = nil
        end
        version
      end

      # Returns the latest available version of Windows PowerShell as determined by
      # checking the registry.
      #
      # @return [String] a version string representing the latest version of Windows PowerShell using the newer engine
      def self.powershell_three_version
        version = nil
        begin
          HKLM.open(PS_THREE_REG_PATH, ACCESS_TYPE) do |reg|
            version = reg[REG_KEY]
          end
        rescue
          version = nil
        end
        version
      end
    end
  end
end
