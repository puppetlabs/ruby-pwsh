# Change log

All notable changes to this project will be documented in this file.The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [0.8.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.8.0) (2021-03-01)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.4...0.8.0)

### Added

- \(MAINT\) Clarify supported platforms [\#113](https://github.com/puppetlabs/ruby-pwsh/pull/113) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.7.4](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.4) (2021-02-12)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.3...0.7.4)

### Fixed

- \(GH-105\) Ensure set runs on ambiguous ensure states [\#108](https://github.com/puppetlabs/ruby-pwsh/pull/108) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(GH-105\) Ensure canonicalized\_cache check validates against namevar [\#107](https://github.com/puppetlabs/ruby-pwsh/pull/107) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.7.3](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.3) (2021-02-03)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.2...0.7.3)

### Fixed

- \(MAINT\) Place nil check when assigning is\_same [\#101](https://github.com/puppetlabs/ruby-pwsh/pull/101) ([bwilcox](https://github.com/bwilcox))

## [0.7.2](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.2) (2021-02-03)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.1...0.7.2)

### Fixed

- \(GH-97\) Memoize class variables in initialize [\#98](https://github.com/puppetlabs/ruby-pwsh/pull/98) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(MAINT\) Ensure is\_same check works for nil manifest values [\#96](https://github.com/puppetlabs/ruby-pwsh/pull/96) ([bwilcox](https://github.com/bwilcox))

## [0.7.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.1) (2021-02-02)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.0...0.7.1)

### Fixed

- \(MAINT\) Correctly canonicalize enumerable values in dsc [\#92](https://github.com/puppetlabs/ruby-pwsh/pull/92) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(MAINT\) Ensure vendored path check works with mix of module builds [\#91](https://github.com/puppetlabs/ruby-pwsh/pull/91) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(GH-84\) Fix empty array parameter check [\#90](https://github.com/puppetlabs/ruby-pwsh/pull/90) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(MAINT\) Minor fixes to CIM instance handling [\#89](https://github.com/puppetlabs/ruby-pwsh/pull/89) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.7.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.0) (2021-01-20)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.3...0.7.0)

### Added

- \(GH-75\) Including module name in vendored module path [\#85](https://github.com/puppetlabs/ruby-pwsh/pull/85) ([pmcmaw](https://github.com/pmcmaw))

### Fixed

- Make root module path use puppetized module name [\#86](https://github.com/puppetlabs/ruby-pwsh/pull/86) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.3](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.3) (2020-12-16)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.2...0.6.3)

### Fixed

- \(MAINT\) Add handling for when dsc\_ensure is stripped [\#78](https://github.com/puppetlabs/ruby-pwsh/pull/78) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.2](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.2) (2020-12-09)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.1...0.6.2)

### Fixed

- \(MAINT\) Ensure parameters are canonicalized [\#75](https://github.com/puppetlabs/ruby-pwsh/pull/75) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.1) (2020-11-25)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.0...0.6.1)

### Fixed

- \(maint\) - Removal of inappropriate terminology [\#70](https://github.com/puppetlabs/ruby-pwsh/pull/70) ([pmcmaw](https://github.com/pmcmaw))
- \(Maint\) Fix ensurability in the dsc base provider [\#69](https://github.com/puppetlabs/ruby-pwsh/pull/69) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.0) (2020-11-24)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.5.1...0.6.0)

### Added

- \(GH-81\) Handle parameters in the dsc base provider [\#62](https://github.com/puppetlabs/ruby-pwsh/pull/62) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(GH-74\) Remove special handling for ensure in the dsc base provider [\#61](https://github.com/puppetlabs/ruby-pwsh/pull/61) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(GH-59\) Refactor away from Simple Provider [\#60](https://github.com/puppetlabs/ruby-pwsh/pull/60) ([michaeltlombardi](https://github.com/michaeltlombardi))

### Fixed

- \(GH-57\) Handle datetimes in dsc [\#58](https://github.com/puppetlabs/ruby-pwsh/pull/58) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(GH-55\) Handle intentionally empty arrays [\#56](https://github.com/puppetlabs/ruby-pwsh/pull/56) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.5.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.5.1) (2020-09-25)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.5.0...0.5.1)

### Fixed

- \(MAINT\) Ensure dsc provider finds dsc resources during agent run [\#45](https://github.com/puppetlabs/ruby-pwsh/pull/45) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.5.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.5.0) (2020-08-20)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.4.1...0.5.0)

### Added

- \(IAC-1045\) Add the DSC base Puppet provider to pwshlib [\#39](https://github.com/puppetlabs/ruby-pwsh/pull/39) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.4.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.4.1) (2020-02-13)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.4.0...0.4.1)

### Fixed

- Ensure ruby versions older than 2.3 function correctly [\#30](https://github.com/puppetlabs/ruby-pwsh/pull/30) ([binford2k](https://github.com/binford2k))

## [0.4.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.4.0) (2020-01-14)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.3.0...0.4.0)

### Added

- \(MODULES-10389\) Add puppet feature for dependent modules to leverage [\#20](https://github.com/puppetlabs/ruby-pwsh/pull/20) ([sanfrancrisko](https://github.com/sanfrancrisko))

## [0.3.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.3.0) (2019-12-04)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.2.0...0.3.0)

### Added

- \(FEAT\) Add method for symbolizing hash keys [\#16](https://github.com/puppetlabs/ruby-pwsh/pull/16) ([michaeltlombardi](https://github.com/michaeltlombardi))

### Fixed

- \(FEAT\) Ensure hash key casing methods work on arrays [\#15](https://github.com/puppetlabs/ruby-pwsh/pull/15) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.2.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.2.0) (2019-11-26)

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.1.0...0.2.0)

### Added

- \(FEAT\) Add quality of life utilities [\#11](https://github.com/puppetlabs/ruby-pwsh/pull/11) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(FM-8422\) Make library releasable as a Puppet module [\#8](https://github.com/puppetlabs/ruby-pwsh/pull/8) ([michaeltlombardi](https://github.com/michaeltlombardi))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
