# frozen_string_literal: true

require 'spec_helper'
require 'ruby-pwsh'
require 'securerandom'

powershell = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
module_path = File.expand_path('../../fixtures/modules', File.dirname(__FILE__))
powershellget_path = File.expand_path('powershellget/lib/puppet_x/powershellget/dsc_resources/PowerShellGet', module_path)
local_user = ['dsc', SecureRandom.uuid.slice(0, 7)].join('_')
local_pw = SecureRandom.uuid

RSpec.describe 'DSC Acceptance: Basic' do
  let(:puppet_apply) do
    "bundle exec puppet apply --modulepath #{module_path} --detailed-exitcodes --debug --trace"
  end
  let(:command) { "#{puppet_apply} -e \"#{manifest}\"" }

  context 'Updating' do
    let(:manifest) do
      # This very awkward pattern is because we're not writing
      # manifest files and need to pass them directly to puppet apply.
      [
        "dsc_psrepository { 'Trust PSGallery':",
        "dsc_name => 'PSGallery',",
        "dsc_ensure => 'Present',",
        "dsc_installationpolicy => 'Trusted'",
        '}'
      ].join(' ')
    end

    before(:all) do
      reset_command = <<~RESET_COMMAND
        $ErrorActionPreference = 'Stop'
        Import-Module PowerShellGet
        $ResetParameters = @{
          Name = 'PSRepository'
          ModuleName = '#{powershellget_path}'
          Method = 'Set'
          Property = @{
            Name = 'PSGallery'
            Ensure = 'Present'
            InstallationPolicy = 'Untrusted'
          }
        }
        Invoke-DscResource @ResetParameters | ConvertTo-Json -Compress
      RESET_COMMAND
      reset_result = powershell.execute(reset_command)
      raise reset_result[:errormessage] unless reset_result[:errormessage].nil?
    end

    it 'applies idempotently' do
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(/dsc_installationpolicy changed 'Untrusted' to 'Trusted'/)
      expect(first_run_result[:native_stdout]).to match(/Updating: Finished/)
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      second_run_result = powershell.execute(command)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end
  context 'Creating' do
    let(:manifest) do
      [
        "dsc_psmodule { 'Install BurntToast':",
        "dsc_name => 'BurntToast',",
        "dsc_ensure => 'Present',",
        '}'
      ].join(' ')
    end

    before(:all) do
      reset_command = <<~RESET_COMMAND
        $ErrorActionPreference = 'Stop'
        Import-Module PowerShellGet
        Get-InstalledModule -Name BurntToast -ErrorAction SilentlyContinue |
          Uninstall-Module -Force
      RESET_COMMAND
      reset_result = powershell.execute(reset_command)
      raise reset_result[:errormessage] unless reset_result[:errormessage].nil?
    end

    it 'applies idempotently' do
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(/dsc_ensure changed 'Absent' to 'Present'/)
      expect(first_run_result[:native_stdout]).to match(/Creating: Finished/)
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      second_run_result = powershell.execute(command)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end

  context 'Deleting' do
    let(:manifest) do
      [
        "dsc_psmodule { 'Install BurntToast':",
        "dsc_name => 'BurntToast',",
        "dsc_ensure => 'Absent',",
        '}'
      ].join(' ')
    end

    before(:all) do
      reset_command = <<~RESET_COMMAND
        $ErrorActionPreference = 'Stop'
        Import-Module PowerShellGet
        $Installed = Get-InstalledModule -Name BurntToast -ErrorAction SilentlyContinue
        If($null -eq $Installed) {
          Install-Module -Name BurntToast -Scope AllUsers -Force
        }
      RESET_COMMAND
      reset_result = powershell.execute(reset_command)
      raise reset_result[:errormessage] unless reset_result[:errormessage].nil?
    end

    it 'applies idempotently' do
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(/dsc_ensure changed 'Present' to 'Absent'/)
      expect(first_run_result[:native_stdout]).to match(/Deleting: Finished/)
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      second_run_result = powershell.execute(command)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end
  context 'PSDscRunAsCredential' do
    before(:all) do
      prep_command = <<~PREP_USER.strip
        $ErrorActionPreference = 'Stop'
        $User = Get-LocalUser -Name #{local_user} -ErrorAction SilentlyContinue
        If ($null -eq $User) {
          $Secure = ConvertTo-SecureString -String '#{local_pw}' -AsPlainText -Force
          $User = New-LocalUser -Name #{local_user} -Password $Secure -Verbose
        }
        If ($User.Name -notin (Get-LocalGroupMember -Group Administrators).Name) {
          Add-LocalGroupMember -Group Administrators -Member $User -Verbose
        }
        Get-LocalGroupMember -Group Administrators |
          Where-Object Name -match '#{local_user}'
      PREP_USER
      prep_result = powershell.execute(prep_command)
      raise prep_result[:errormessage] unless prep_result[:errormessage].nil?
    end
    after(:all) do
      cleanup_command = <<~CLEANUP_USER.strip
        Remove-LocalUser -Name #{local_user} -ErrorAction Stop
      CLEANUP_USER
      cleanup_result = powershell.execute(cleanup_command)
      raise cleanup_result[:errormessage] unless cleanup_result[:errormessage].nil?
    end

    context 'with a valid credential' do
      let(:manifest) do
        [
          "dsc_psrepository { 'Trust PSGallery':",
          "dsc_name => 'PSGallery',",
          "dsc_ensure => 'Present',",
          "dsc_installationpolicy => 'Trusted',",
          'dsc_psdscrunascredential => {',
          "'user' => '#{local_user}',",
          "'password' => Sensitive('#{local_pw}')",
          '}',
          '}'
        ].join(' ')
      end

      it 'applies idempotently without leaking secrets' do
        first_run_result = powershell.execute(command)
        expect(first_run_result[:exitcode]).to be(2)
        expect(first_run_result[:native_stdout]).to match(/dsc_installationpolicy changed 'Untrusted' to 'Trusted'/)
        expect(first_run_result[:native_stdout]).to match(/Updating: Finished/)
        expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
        expect(first_run_result[:native_stdout]).to match(/'#<Sensitive \[value redacted\]>'/)
        expect(first_run_result[:native_stdout]).not_to match(local_pw)
        second_run_result = powershell.execute(command)
        expect(second_run_result[:exitcode]).to be(0)
      end
    end
    context 'with an invalid credential' do
      let(:manifest) do
        [
          "dsc_psrepository { 'Trust PSGallery':",
          "dsc_name => 'PSGallery',",
          "dsc_ensure => 'Present',",
          "dsc_installationpolicy => 'Trusted',",
          'dsc_psdscrunascredential => {',
          "'user' => 'definitely_do_not_exist_here',",
          "'password' => Sensitive('#{local_pw}')",
          '}',
          '}'
        ].join(' ')
      end

      it 'errors loudly without leaking secrets' do
        first_run_result = powershell.execute(command)
        expect(first_run_result[:exitcode]).to be(4)
        expect(first_run_result[:stderr].first).to match(/dsc_psrepository: The user name or password is incorrect/)
        expect(first_run_result[:native_stdout]).to match(/'#<Sensitive \[value redacted\]>'/)
        expect(first_run_result[:native_stdout]).not_to match(local_pw)
      end
    end
  end
end
