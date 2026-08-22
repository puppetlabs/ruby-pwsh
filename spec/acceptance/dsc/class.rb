# frozen_string_literal: true

require 'spec_helper'
require 'ruby-pwsh'

powershell = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
module_path = File.expand_path('../../fixtures/modules', File.dirname(__FILE__))
psrc_path = File.expand_path('../../fixtures/example.psrc', File.dirname(__FILE__))

def execute_reset_command(reset_command)
  manager = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
  result = manager.execute(reset_command)
  raise result[:errormessage] unless result[:errormessage].nil?
end

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
        "dsc_description => 'Example role capability file'",
        '}'
      ].join(' ')
    end

    before do
      reset_command = <<~RESET_COMMAND
        $PsrcPath = '#{psrc_path}'
        # Delete the test PSRC fixture if it exists
        If (Test-Path -Path $PsrcPath -PathType Leaf) {
          Remove-Item $PsrcPath -Force
        }
      RESET_COMMAND
      execute_reset_command(reset_command)
    end

    it 'applies idempotently' do
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(//)
      expect(first_run_result[:native_stdout]).to match(/dsc_description changed.*to 'Example role capability file'/)
      expect(first_run_result[:native_stdout]).to match(/Creating: Finished/)
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
        "dsc_description => 'Updated role capability file'",
        '}'
      ].join(' ')
    end

    before do
      reset_command = <<~RESET_COMMAND
        $PsrcPath = '#{psrc_path}'
        # Delete the test PSRC fixture if it exists
        If (Test-Path -Path $PsrcPath -PathType Leaf) {
          Remove-Item $PsrcPath -Force
        }
        # Create the test PSRC fixture
        New-Item $PsrcPath -ItemType File -Value "@{'Description' = 'Example role capability file'}"
      RESET_COMMAND
      execute_reset_command(reset_command)
    end

    it 'applies idempotently' do
      first_run_result = powershell.execute(command)
      expect(first_run_result[:exitcode]).to be(2)
      expect(first_run_result[:native_stdout]).to match(/dsc_description changed 'Example role capability file' to 'Updated role capability file'/)
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

    before do
      reset_command = <<~RESET_COMMAND
        $PsrcPath = '#{psrc_path}'
        # Delete the test PSRC fixture if it exists
        If (!(Test-Path -Path $PsrcPath -PathType Leaf)) {
          # Create the test PSRC fixture
          New-Item $PsrcPath -ItemType File -Value "@{'Description' = 'Updated'}"
        }
      RESET_COMMAND
      execute_reset_command(reset_command)
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
end
