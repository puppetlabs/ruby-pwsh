# frozen_string_literal: true

require 'spec_helper'
require 'ruby-pwsh'

# Needs to be declared here so it is usable in before and it blocks alike
test_manifest = File.expand_path('../../fixtures/test.pp', File.dirname(__FILE__))
fixtures_path = File.expand_path('../../fixtures', File.dirname(__FILE__))

def execute_reset_command(command)
  result = powershell.execute(command)
  raise result[:errormessage] unless result[:errormessage].nil?
end

RSpec.describe 'DSC Acceptance: Complex' do
  let(:powershell) { Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args) }
  let(:module_path) { File.expand_path('../../fixtures/modules', File.dirname(__FILE__)) }
  let(:puppet_apply) do
    "bundle exec puppet apply #{test_manifest} --modulepath #{module_path} --detailed-exitcodes --trace"
  end

  context 'Adding a new website' do
    before(:each) do
      reset_command = <<~RESET_COMMAND
        # Ensure IIS is not installed
        $Feature = Get-WindowsFeature -Name 'Web-Asp-Net45'
        If ($Feature.Installed) {
          Remove-WindowsFeature -Name $Feature.Name -ErrorAction Stop
        }
        $DefaultSite = Get-Website 'Default Web Site' -ErrorAction Continue
        $ExampleSite = Get-Website 'Puppet DSC Site' -ErrorAction Continue
        If ($DefaultSite.State -eq 'Stopped') {
          Start-Website -Name $DefaultSite.Name
        }
        If ($ExampleSite) {
          Stop-Website -Name $ExampleSite.Name
          Remove-Website -Name $ExampleSite.Name
          Remove-Item -Path '#{fixtures_path}/website' -Recurse -Force -ErrorAction SilentlyContinue
        }
      RESET_COMMAND
      execute_reset_command(reset_command)
    end

    it 'applies idempotently' do
      content = <<~MANIFEST.strip
        $destination_path = '#{fixtures_path}/website'
        $website_name     = 'Puppet DSC Site'
        $site_id          = 7
        $index_html = @(INDEXHTML)
          <!doctype html>
          <html lang=en>

          <head>
              <meta charset=utf-8>
              <title>blah</title>
          </head>

          <body>
              <p>I'm the content</p>
          </body>

          </html>
          | INDEXHTML
        # Install the IIS role
        dsc_xwindowsfeature { 'IIS':
          dsc_ensure => 'Present',
          dsc_name   => 'Web-Server',
        }

        # Stop the default website
        dsc_xwebsite { 'DefaultSite':
            dsc_ensure          => 'Present',
            dsc_name            => 'Default Web Site',
            dsc_state           => 'Stopped',
            dsc_serverautostart => false,
            dsc_physicalpath    => 'C:\inetpub\wwwroot',
            require             => Dsc_xwindowsfeature['IIS'],
        }

        # Install the ASP .NET 4.5 role
        dsc_xwindowsfeature { 'AspNet45':
          dsc_ensure => 'Present',
          dsc_name   => 'Web-Asp-Net45',
        }

        file { 'WebContentFolder':
          ensure => directory,
          path   => $destination_path,
          require => Dsc_xwindowsfeature['AspNet45'],
        }

        # Copy the website content
        file { 'WebContentIndex':
            path    => "${destination_path}/index.html",
            content => $index_html,
            require => File['WebContentFolder'],
        }

        # Create the new Website
        dsc_xwebsite { 'NewWebsite':
            dsc_ensure          => 'Present',
            dsc_name            => $website_name,
            dsc_siteid          => $site_id,
            dsc_state           => 'Started',
            dsc_serverautostart => true,
            dsc_physicalpath    => $destination_path,
            require             => File['WebContentIndex'],
        }
      MANIFEST
      File.open(test_manifest, 'w') { |file| file.write(content) }
      # Puppet apply the test manifest
      first_run_result = powershell.execute(puppet_apply)
      expect(first_run_result[:exitcode]).to be(2)
      # The Default Site is stopped
      expect(first_run_result[:native_stdout]).to match(%r{Dsc_xwebsite\[DefaultSite\]/dsc_state: dsc_state changed 'Started' to 'Stopped'})
      expect(first_run_result[:native_stdout]).to match(/dsc_xwebsite\[{:name=>"DefaultSite", :dsc_name=>"Default Web Site"}\]: Updating: Finished/)
      # AspNet45 is installed
      expect(first_run_result[:native_stdout]).to match(%r{Dsc_xwindowsfeature\[AspNet45\]/dsc_ensure: dsc_ensure changed 'Absent' to 'Present'})
      expect(first_run_result[:native_stdout]).to match(/dsc_xwindowsfeature\[{:name=>"AspNet45", :dsc_name=>"Web-Asp-Net45"}\]: Creating: Finished/)
      # Web content folder created
      expect(first_run_result[:native_stdout]).to match(%r{File\[WebContentFolder\]/ensure: created})
      # Web content index created
      expect(first_run_result[:native_stdout]).to match(%r{File\[WebContentIndex\]/ensure: defined content as '.+'})
      # Web site created
      expect(first_run_result[:native_stdout]).to match(%r{Dsc_xwebsite\[NewWebsite\]/dsc_siteid: dsc_siteid changed  to 7})
      expect(first_run_result[:native_stdout]).to match(%r{Dsc_xwebsite\[NewWebsite\]/dsc_ensure: dsc_ensure changed 'Absent' to 'Present'})
      expect(first_run_result[:native_stdout]).to match(%r{Dsc_xwebsite\[NewWebsite\]/dsc_physicalpath: dsc_physicalpath changed  to '.+fixtures/website'})
      expect(first_run_result[:native_stdout]).to match(%r{Dsc_xwebsite\[NewWebsite\]/dsc_state: dsc_state changed  to 'Started'})
      expect(first_run_result[:native_stdout]).to match(%r{Dsc_xwebsite\[NewWebsite\]/dsc_serverautostart: dsc_serverautostart changed  to 'true'})
      expect(first_run_result[:native_stdout]).to match(/dsc_xwebsite\[{:name=>"NewWebsite", :dsc_name=>"Puppet DSC Site"}\]: Creating: Finished/)
      # Run finished
      expect(first_run_result[:native_stdout]).to match(/Applied catalog/)
      # Second run is idempotent
      second_run_result = powershell.execute(puppet_apply)
      expect(second_run_result[:exitcode]).to be(0)
    end
  end
end
