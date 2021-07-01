# frozen_string_literal: true

require 'spec_helper'
require 'ruby-pwsh'
require 'securerandom'

powershell = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
module_path = File.expand_path('../../fixtures/modules', File.dirname(__FILE__))
# jeadsc_path = File.expand_path('jeadsc/lib/puppet_x/jeadsc/dsc_resources/JeaDsc', module_path)
psrc_path = File.expand_path('../../fixtures/example.psrc', File.dirname(__FILE__))

RSpec.describe 'DSC Acceptance: Class-Based Resource' do
  let(:puppet_apply) do
    "bundle exec puppet apply --modulepath #{module_path} --detailed-exitcodes --debug --trace"
  end
  let(:command) { "#{puppet_apply} -e \"#{manifest}\"" }

  context 'Creating' do
    let(:manifest) do
      # This very awkward pattern is because we're not writing
      # manifest files and need to pass them directly to puppet apply.
      [
        "dsc_jearolecapabilities { 'ExampleRoleCapability':",
        "dsc_ensure      => 'Present',",
        "dsc_path        => '#{psrc_path}',",
        "dsc_description => 'Modified example role capability file'",
        '}'
      ].join(' ')
    end

    before(:all) do
      # Commented out until we can figure out how to sensibly munge path
      # reset_command = <<~RESET_COMMAND
      #   $ErrorActionPreference = 'Stop'
      #   Import-Module PowerShellGet
      #   $ResetParameters = @{
      #     Name = 'JeaRoleCapabilities'
      #     ModuleName = '#{powershellget_path}'
      #     Method = 'Set'
      #     Property = @{
      #       Path = '#{psrc_path}'
      #       Ensure = 'Absent'
      #     }
      #   }
      #   Invoke-DscResource @ResetParameters | ConvertTo-Json -Compress
      # RESET_COMMAND
      # reset_result = powershell.execute(reset_command)
      # raise reset_result[:errormessage] unless reset_result[:errormessage].nil?
    end

    it 'applies idempotently' do
      pending('Release of dsc-jeadsc with the dscmeta_resource_implementation key')
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(//)
      expect(first_run_result[:native_stdout]).to match(/dsc_description changed  to 'Example role capability file'/)
      expect(first_run_result[:native_stdout]).to match(/Created: Finished/)
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      second_run_result = powershell.execute(command)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end

  context 'Updating' do
    let(:manifest) do
      # This very awkward pattern is because we're not writing
      # manifest files and need to pass them directly to puppet apply.
      [
        "dsc_jearolecapabilities { 'ExampleRoleCapability':",
        "dsc_ensure      => 'Present',",
        "dsc_path        => '#{psrc_path}',",
        "dsc_description => 'Updated'",
        '}'
      ].join(' ')
    end

    before(:all) do
      # Commented out until we can figure out how to sensibly munge path
      # reset_command = <<~RESET_COMMAND
      #   $ErrorActionPreference = 'Stop'
      #   Import-Module PowerShellGet
      #   $ResetParameters = @{
      #     Name = 'JeaRoleCapabilities'
      #     ModuleName = '#{powershellget_path}'
      #     Method = 'Set'
      #     Property = @{
      #       Path = '#{psrc_path}'
      #       Ensure = 'Absent'
      #     }
      #   }
      #   Invoke-DscResource @ResetParameters | ConvertTo-Json -Compress
      # RESET_COMMAND
      # reset_result = powershell.execute(reset_command)
      # raise reset_result[:errormessage] unless reset_result[:errormessage].nil?
    end

    it 'applies idempotently' do
      pending('Release of dsc-jeadsc with the dscmeta_resource_implementation key')
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(/dsc_description changed 'Example role capability file' to 'Updated'/)
      expect(first_run_result[:native_stdout]).to match(/Updating: Finished/)
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      second_run_result = powershell.execute(command)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end

  context 'Deleting' do
    let(:manifest) do
      # This very awkward pattern is because we're not writing
      # manifest files and need to pass them directly to puppet apply.
      [
        "dsc_jearolecapabilities { 'ExampleRoleCapability':",
        "dsc_ensure      => 'Absent',",
        "dsc_path        => '#{psrc_path}'",
        '}'
      ].join(' ')
    end

    before(:all) do
      # Commented out until we can figure out how to sensibly munge path
      # reset_command = <<~RESET_COMMAND
      #   $ErrorActionPreference = 'Stop'
      #   Import-Module PowerShellGet
      #   $ResetParameters = @{
      #     Name = 'JeaRoleCapabilities'
      #     ModuleName = '#{powershellget_path}'
      #     Method = 'Set'
      #     Property = @{
      #       Path = '#{psrc_path}'
      #       Ensure = 'Absent'
      #     }
      #   }
      #   Invoke-DscResource @ResetParameters | ConvertTo-Json -Compress
      # RESET_COMMAND
      # reset_result = powershell.execute(reset_command)
      # raise reset_result[:errormessage] unless reset_result[:errormessage].nil?
    end

    it 'applies idempotently' do
      pending('Release of dsc-jeadsc with the dscmeta_resource_implementation key')
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(/dsc_ensure changed 'Present' to 'Absent'/)
      expect(first_run_result[:native_stdout]).to match(/Deleting: Finished/)
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      second_run_result = powershell.execute(command)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end
end
