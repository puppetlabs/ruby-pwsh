# pwshlib

This module enables you to leverage the `ruby-pwsh` gem to execute PowerShell from within your Puppet providers without having to instantiate and tear down a PowerShell process for each command called.
It supports Windows PowerShell as well as PowerShell Core - if you're running **PowerShell v3+**, this gem supports you.

The `Manager` class enables you to execute and interoperate with PowerShell from within ruby, leveraging the strengths of both languages as needed.

## Prerequisites

Include `puppetlabs-pwshlib` as a dependency in your module and you can leverage it in your providers by using a requires statement, such as in this example:

```ruby
require 'puppet/resource_api/simple_provider'
begin
  require 'ruby-pwsh'
rescue LoadError
  raise 'Could not load the "ruby-pwsh" library; is the dependency module puppetlabs-pwshlib installed in this environment?'
end

# Implementation for the foo type using the Resource API.
class Puppet::Provider::Foo::Foo < Puppet::ResourceApi::SimpleProvider
  def get(context)
    context.debug("PowerShell Path: #{Pwsh::Manager.powershell_path}")
    context.debug('Returning pre-canned example data')
    [
      {
        name: 'foo',
        ensure: 'present',
      },
      {
        name: 'bar',
        ensure: 'present',
      },
    ]
  end

  def create(context, name, should)
    context.notice("Creating '#{name}' with #{should.inspect}")
  end

  def update(context, name, should)
    context.notice("Updating '#{name}' with #{should.inspect}")
  end

  def delete(context, name)
    context.notice("Deleting '#{name}'")
  end
end
```

Aside from adding it as a dependency to your module metadata, you will probably also want to include it in your `.fixtures.yml` file:

```yaml
fixtures:
  forge_modules:
    pwshlib: "puppetlabs/pwshlib"
```

## Using the Library

Instantiating the manager can be done using some defaults:

```ruby
# Instantiate the manager for Windows PowerShell, using the default path and arguments
# Note that this takes a few seconds to instantiate.
posh = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
# If you try to create another manager with the same arguments it will reuse the existing one.
ps = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
# Note that this time the return is very fast.
# We can also use the defaults for PowerShell Core, though these only work if PowerShell is
# installed to the default paths - if it is installed anywhere else, you'll need to specify
# the full path to the pwsh executable.
pwsh = Pwsh::Manager.instance(Pwsh::Manager.pwsh_path, Pwsh::Manager.pwsh_args)
```

Execution can be done with relatively little additional work - pass the command string you want executed:

```ruby
# Instantiate the Manager:
posh = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
# Pretty print the output of `$PSVersionTable` to validate the version of PowerShell running
# Note that the output is a hash with a few different keys, including stdout.
Puppet.debug(posh.execute('$PSVersionTable'))
# Lets reduce the noise a little and retrieve just the version number:
# Note: We cast to a string because PSVersion is actually a Version object.
Puppet.debug(posh.execute('[String]$PSVersionTable.PSVersion'))
# We could store this output to a ruby variable if we wanted, for further use:
ps_version = posh.execute('[String]$PSVersionTable.PSVersion')[:stdout].strip
Puppet.debug("The PowerShell version of the currently running Manager is #{ps_version}")
```

For more information, please review the [online reference documentation for the gem](https://rubydoc.info/gems/ruby-pwsh).
