# ruby-pwsh

> _The PowerShell gem._

This gem enables you to execute PowerShell from within ruby without having to instantiate and tear down a PowerShell process for each command called.
It supports Windows PowerShell as well as PowerShell Core (and, soon, _just_ PowerShell) - if you're running *PowerShell v3+, this gem supports you.

The `Manager` class enables you to execute and interoperate with PowerShell from within ruby, leveraging the strengths of both languages as needed.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby-pwsh'
```

And then execute:

```shell
bundle install
```

Or install it yourself as:

```shell
gem install ruby-pwsh
```

## Usage

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
pp(posh.execute('$PSVersionTable'))
# Lets reduce the noise a little and retrieve just the version number:
# Note: We cast to a string because PSVersion is actually a Version object.
pp(posh.execute('[String]$PSVersionTable.PSVersion'))
# We could store this output to a ruby variable if we wanted, for further use:
ps_version = posh.execute('[String]$PSVersionTable.PSVersion')[:stdout].strip
pp("The PowerShell version of the currently running Manager is #{ps_version}")
```

## Reference

You can find the full reference documentation online, [here](https://rubydoc.info/gems/ruby-pwsh).

<!-- ## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org). -->

## Releasing the Gem and Puppet Module

Steps to release an update to the gem and module include:

1. Ensure that the release branch is up to date with the master:
   ```bash
   git push upstream upstream/master:release --force
   ```
1. Checkout a new working branch for the release prep (where xyz is the appropriate version, sans periods):
   ```bash
   git checkout -b maint/release/prep-xyz upstream/release
   ```
1. Update the version in `lib/pwsh/version.rb` and `metadata.json` to the appropriate version for the new release.
1. Run the changelog update task (make sure to verify the changelog, correctly tagging PRs as needed):
   ```bash
   bundle exec rake changelog
   ```
1. Commit your changes with a short, sensible commit message, like:
   ```text
   git add lib/pwsh/version.rb
   git add metadata.json
   git add CHANGELOG.md
   git commit -m '(MAINT) Prep for x.y.z release'
   ```
1. Push your changes and submit a pull request for review _against the **release** branch_:
   ```bash
   git push -u origin maint/release/prep-xyz
   ```
1. Ensure tests pass and the code is merged to `release`.
1. Grab the commit hash from the merge commit on release, use that as the tag for the version (replacing `x.y.z` with the appropriate version and  `commithash` with the relevant one), then push the tags to upstream:
   ```bash
   bundle exec rake tag['x.y.z', 'commithash']
   ```
1. Build the Ruby gem and publish:
   ```bash
   bundle exec rake build
   bundle exec rake push['ruby-pwsh-x.y.z.gem']
   ```
1. Verify that the correct version now exists on [RubyGems](https://rubygems.org/search?query=ruby-pwsh)
1. Build the Puppet module:
   ```bash
   bundle exec rake build_module
   ```
1. Publish the updated module version (found in the `pkg` folder) to [the Forge](https://forge.puppet.com/puppetlabs/pwshlib).
1. Submit the [mergeback PR from the release branch to master](https://github.com/puppetlabs/ruby-pwsh/compare/master...release).

## Known Issues
