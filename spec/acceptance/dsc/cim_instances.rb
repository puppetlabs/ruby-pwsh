# frozen_string_literal: true
# TODO: Test against mcollera/AccessControlDsc for CIM instance behavior
# 1. Make sure valid nested CIM instances can be passed to Invoke-DscResource
# 2. Make sure nested CIM instances can be read back from Invoke-DscResource

# frozen_string_literal: true

require 'spec_helper'
require 'ruby-pwsh'

# Needs to be declared here so it is usable in before and it blocks alike
test_manifest = File.expand_path('../../fixtures/test.pp', File.dirname(__FILE__))
fixtures_path = File.expand_path('../../fixtures', File.dirname(__FILE__))

def execute_reset_command(reset_command)
  manager = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
  result = manager.execute(reset_command)
  raise result[:errormessage] unless result[:errormessage].nil?
end

RSpec.describe 'DSC Acceptance: Complex' do
  let(:powershell) { Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args) }
  let(:module_path) { File.expand_path('../../fixtures/modules', File.dirname(__FILE__)) }
  let(:puppet_apply) do
    "bundle exec puppet apply #{test_manifest} --modulepath #{module_path} --detailed-exitcodes --trace"
  end

  context 'Managing the access control list of a folder' do
    before(:each) do
      reset_command = <<~RESET_COMMAND
        $TestFolderPath = Join-Path -Path "#{fixtures_path}" -Childpath access_control
        # Delete the test folder if it exists (to clear access control modifications)
        If (Test-Path -Path $TestFolderPath -PathType Container) {
          Remove-Item $TestFolderPath -Recurse -Force
        }
        # Create the test folder
        New-Item $TestFolderPath -ItemType Directory
      RESET_COMMAND
      execute_reset_command(reset_command)
    end

    it 'applies idempotently' do
      content = <<~MANIFEST.strip
        $test_folder_path = "#{fixtures_path}/access_control"
        # Configure access to the test folder
        dsc_ntfsaccessentry {'Test':
          dsc_path              => $test_folder_path,
          dsc_accesscontrollist => [
            {
              principal          => 'Everyone',
              forceprincipal     => true,
              accesscontrolentry => [
                {
                  accesscontroltype => 'Allow',
                  filesystemrights  => ['FullControl'],
                  inheritance       => 'This folder and files',
                  ensure            => 'Present',
                  cim_instance_type => 'NTFSAccessControlEntry',
                }
              ]
            }
          ]
        }
      MANIFEST
      File.open(test_manifest, 'w') { |file| file.write(content) }
      # Apply the test manifest
      first_run_result = powershell.execute(puppet_apply)
      expect(first_run_result[:exitcode]).to be(2)
      # Access Control Set
      expect(first_run_result[:native_stdout]).to match(/dsc_accesscontrollist: dsc_accesscontrollist changed/)
      expect(first_run_result[:native_stdout]).to match(%r{dsc_ntfsaccessentry\[{:name=>"Test", :dsc_path=>".+/spec/fixtures/access_control"}\]: Updating: Finished})
      expect(first_run_result[:stderr]).not_to match(/Error/)
      expect(first_run_result[:stderr]).not_to match(/Warning: Provider returned data that does not match the Type Schema/)
      expect(first_run_result[:stderr]).not_to match(/Value type mismatch/)
      # Run finished
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      # Second run is idempotent
      second_run_result = powershell.execute(puppet_apply)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end
end
