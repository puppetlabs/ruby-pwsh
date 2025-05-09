<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v2.0.0](https://github.com/puppetlabs/ruby-pwsh/tree/v2.0.0) - 2025-05-06

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.2.3...v2.0.0)

### Changed

- (CAT-2281) Remove puppet 7 infrastructure [#375](https://github.com/puppetlabs/ruby-pwsh/pull/375) ([LukasAud](https://github.com/LukasAud))

### Fixed

- Ensure metaparams casing is preserved [#374](https://github.com/puppetlabs/ruby-pwsh/pull/374) ([Clebam](https://github.com/Clebam))

## [v1.2.3](https://github.com/puppetlabs/ruby-pwsh/tree/v1.2.3) - 2025-03-18

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.2.2...v1.2.3)

### Fixed

- Handle string credentials [#369](https://github.com/puppetlabs/ruby-pwsh/pull/369) ([Clebam](https://github.com/Clebam))
- (Bug): do not pass dsc_timeout as timeout parameter to DSC resource params [#366](https://github.com/puppetlabs/ruby-pwsh/pull/366) ([jordanbreen28](https://github.com/jordanbreen28))
- Change [System.Environment]::SetEnvironmentVariable() to Set-ItemProperty [#365](https://github.com/puppetlabs/ruby-pwsh/pull/365) ([pkotov87](https://github.com/pkotov87))
- double quote when passing env var values [#351](https://github.com/puppetlabs/ruby-pwsh/pull/351) ([garrettrowell](https://github.com/garrettrowell))

## [v1.2.2](https://github.com/puppetlabs/ruby-pwsh/tree/v1.2.2) - 2024-09-25

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.2.1...v1.2.2)

### Fixed

- (CAT-2061) Fix empty string nullification [#346](https://github.com/puppetlabs/ruby-pwsh/pull/346) ([david22swan](https://github.com/david22swan))

## [v1.2.1](https://github.com/puppetlabs/ruby-pwsh/tree/v1.2.1) - 2024-09-20

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.2.0...v1.2.1)

### Added

- AlmaLinux 8/9 added to metadata.json [#338](https://github.com/puppetlabs/ruby-pwsh/pull/338) ([alex501212](https://github.com/alex501212))

### Fixed

- Revert "Fix empty string nullification" [#342](https://github.com/puppetlabs/ruby-pwsh/pull/342) ([jordanbreen28](https://github.com/jordanbreen28))
- (maint) - Fix incorrect test for file_path [#335](https://github.com/puppetlabs/ruby-pwsh/pull/335) ([jordanbreen28](https://github.com/jordanbreen28))
- (CAT-1991) - Skip missing dirs invalid_dir method [#334](https://github.com/puppetlabs/ruby-pwsh/pull/334) ([jordanbreen28](https://github.com/jordanbreen28))

## [v1.2.0](https://github.com/puppetlabs/ruby-pwsh/tree/v1.2.0) - 2024-08-15

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.1.1...v1.2.0)

### Added

- (CAT-1869) - Add configurable dsc_timeout [#319](https://github.com/puppetlabs/ruby-pwsh/pull/319) ([jordanbreen28](https://github.com/jordanbreen28))
- Add support for unit testing via Unix OS [#309](https://github.com/puppetlabs/ruby-pwsh/pull/309) ([chambersmp](https://github.com/chambersmp))

### Fixed

- (bug) - Fix dsc timeout matcher [#331](https://github.com/puppetlabs/ruby-pwsh/pull/331) ([jordanbreen28](https://github.com/jordanbreen28))
- Fix empty string nullification [#292](https://github.com/puppetlabs/ruby-pwsh/pull/292) ([Clebam](https://github.com/Clebam))

## [v1.1.1](https://github.com/puppetlabs/ruby-pwsh/tree/v1.1.1) - 2024-02-21

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.1.0...v1.1.1)

### Fixed

- (CAT-1724) - Fix Provider returned data not matching Type Schema [#295](https://github.com/puppetlabs/ruby-pwsh/pull/295) ([jordanbreen28](https://github.com/jordanbreen28))
- Fix enum idempotency [#291](https://github.com/puppetlabs/ruby-pwsh/pull/291) ([Clebam](https://github.com/Clebam))

## [v1.1.0](https://github.com/puppetlabs/ruby-pwsh/tree/v1.1.0) - 2024-01-31

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.0.1...v1.1.0)

### Added

- (feat) - add retries on failed dsc invocation [#282](https://github.com/puppetlabs/ruby-pwsh/pull/282) ([jordanbreen28](https://github.com/jordanbreen28))

### Fixed

- (CAT-1688) Upgrade rubocop to `~> 1.50.0` [#279](https://github.com/puppetlabs/ruby-pwsh/pull/279) ([LukasAud](https://github.com/LukasAud))

## [v1.0.1](https://github.com/puppetlabs/ruby-pwsh/tree/v1.0.1) - 2023-12-13

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v1.0.0...v1.0.1)

### Fixed

- (CAT-1617) - Always load vendored module in PSModulePath [#261](https://github.com/puppetlabs/ruby-pwsh/pull/261) ([jordanbreen28](https://github.com/jordanbreen28))

## [v1.0.0](https://github.com/puppetlabs/ruby-pwsh/tree/v1.0.0) - 2023-08-17

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v0.11.0...v1.0.0)

### Changed

- (maint) - Drop Support for Debian 8/9 [#227](https://github.com/puppetlabs/ruby-pwsh/pull/227) ([jordanbreen28](https://github.com/jordanbreen28))
- (maint) -  Drop Support for Ubuntu 16.04 [#226](https://github.com/puppetlabs/ruby-pwsh/pull/226) ([jordanbreen28](https://github.com/jordanbreen28))
- (maint) - Drop Support for Fedora 30&31 [#225](https://github.com/puppetlabs/ruby-pwsh/pull/225) ([jordanbreen28](https://github.com/jordanbreen28))
- (maint) - Drop Support for OSX 10.14 [#224](https://github.com/puppetlabs/ruby-pwsh/pull/224) ([jordanbreen28](https://github.com/jordanbreen28))
- (maint) - Drop Support for Windows 2008(R2)/7/8 [#223](https://github.com/puppetlabs/ruby-pwsh/pull/223) ([jordanbreen28](https://github.com/jordanbreen28))
- (CAT-1172) - Add Puppet 8 Support/Drop Puppet 6 Support [#221](https://github.com/puppetlabs/ruby-pwsh/pull/221) ([jordanbreen28](https://github.com/jordanbreen28))

### Added

- (feat) - Add support for Ubuntu 22.04 [#232](https://github.com/puppetlabs/ruby-pwsh/pull/232) ([jordanbreen28](https://github.com/jordanbreen28))
- (feat) - add Windows 11 & Server 2022 support [#231](https://github.com/puppetlabs/ruby-pwsh/pull/231) ([jordanbreen28](https://github.com/jordanbreen28))
- (feat) - Add support for Fedora 36 [#230](https://github.com/puppetlabs/ruby-pwsh/pull/230) ([jordanbreen28](https://github.com/jordanbreen28))
- (feat) - Add support for OSX 11&12 [#229](https://github.com/puppetlabs/ruby-pwsh/pull/229) ([jordanbreen28](https://github.com/jordanbreen28))
- (feat) - Add support for Debian 11 [#228](https://github.com/puppetlabs/ruby-pwsh/pull/228) ([jordanbreen28](https://github.com/jordanbreen28))

### Fixed

- (bug) - Fixes missing mandatory ID [#234](https://github.com/puppetlabs/ruby-pwsh/pull/234) ([jordanbreen28](https://github.com/jordanbreen28))

## [v0.11.0](https://github.com/puppetlabs/ruby-pwsh/tree/v0.11.0) - 2023-08-16

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v0.11.0.rc.1...v0.11.0)

## [v0.11.0.rc.1](https://github.com/puppetlabs/ruby-pwsh/tree/v0.11.0.rc.1) - 2023-04-17

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/v0.10.3...v0.11.0.rc.1)

### Changed

- (CONT-867) Ruby 3 / Puppet 8 Support [#208](https://github.com/puppetlabs/ruby-pwsh/pull/208) ([chelnak](https://github.com/chelnak))

## [v0.10.3](https://github.com/puppetlabs/ruby-pwsh/tree/v0.10.3) - 2022-12-19

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.10.2...v0.10.3)

### Fixed

- (MODULES-11343) Preserve metaparameters [#192](https://github.com/puppetlabs/ruby-pwsh/pull/192) ([chelnak](https://github.com/chelnak))

## [0.10.2](https://github.com/puppetlabs/ruby-pwsh/tree/0.10.2) - 2022-06-24

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.10.1...0.10.2)

### Fixed

- (GH-188) Filter current environment variables [#189](https://github.com/puppetlabs/ruby-pwsh/pull/189) ([chelnak](https://github.com/chelnak))

## [0.10.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.10.1) - 2021-08-23

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.10.0...0.10.1)

### Fixed

- (GH-180) Ensure instance_key respects full uniqueness of options [#181](https://github.com/puppetlabs/ruby-pwsh/pull/181) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-165) Ensure null-value nested cim instance arrays are appropriately munged [#177](https://github.com/puppetlabs/ruby-pwsh/pull/177) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.10.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.10.0) - 2021-07-02

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.9.0...0.10.0)

### Added

- (GH-172) Enable use of class-based DSC Resources by munging PSModulePath  [#173](https://github.com/puppetlabs/ruby-pwsh/pull/173) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.9.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.9.0) - 2021-06-28

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.8.0...0.9.0)

### Added

- (GH-147) Refactor Invocation methods to use shared helper and write error logs when appropriate [#152](https://github.com/puppetlabs/ruby-pwsh/pull/152) ([david22swan](https://github.com/david22swan))
- (GH-145) Improve DSC secrets redaction [#150](https://github.com/puppetlabs/ruby-pwsh/pull/150) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-145) Add insync? and invoke_test_method to dsc provider [#124](https://github.com/puppetlabs/ruby-pwsh/pull/124) ([michaeltlombardi](https://github.com/michaeltlombardi))

### Fixed

- (IAC-1657) Fix for invalid DateTime value error in `invoke_get_method` [#169](https://github.com/puppetlabs/ruby-pwsh/pull/169) ([david22swan](https://github.com/david22swan))
- (GH-154) Ensure values returned from `invoke_get_method` are recursively sorted in the DSC Base Provider to reduce canonicalization warnings. [#160](https://github.com/puppetlabs/ruby-pwsh/pull/160) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-154) Fix return data from `Invoke-DscResource` for empty strings and single item arrays in DSC Base Provider [#159](https://github.com/puppetlabs/ruby-pwsh/pull/159) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-155) Fix CIM Instance munging in `invoke_get_method` for DSC Base Provider [#158](https://github.com/puppetlabs/ruby-pwsh/pull/158) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-154) Fix canonicalization in `get` method for DSC Base Provider [#157](https://github.com/puppetlabs/ruby-pwsh/pull/157) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-144) Enable order-insensitive comparisons for DSC [#151](https://github.com/puppetlabs/ruby-pwsh/pull/151) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-143) Handle order insensitive arrays in the `same?` method of the DSC Base Provider [#148](https://github.com/puppetlabs/ruby-pwsh/pull/148) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-127) Canonicalize enums correctly [#131](https://github.com/puppetlabs/ruby-pwsh/pull/131) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-125) Fix dsc provider canonicalization for absent resources [#129](https://github.com/puppetlabs/ruby-pwsh/pull/129) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (MODULES-11051) Ensure environment variables are not incorrectly munged in the PowerShell Host [#128](https://github.com/puppetlabs/ruby-pwsh/pull/128) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (MODULES-11026) Ensure the PowerShell manager works with v7 [#122](https://github.com/puppetlabs/ruby-pwsh/pull/122) ([n3snah](https://github.com/n3snah))
- (Maint) Ensure canonicalize correctly compares sorted hashes [#118](https://github.com/puppetlabs/ruby-pwsh/pull/118) ([Hvid](https://github.com/Hvid))

## [0.8.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.8.0) - 2021-03-01

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.4...0.8.0)

### Added

- (MAINT) Clarify supported platforms [#113](https://github.com/puppetlabs/ruby-pwsh/pull/113) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.7.4](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.4) - 2021-02-11

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.3...0.7.4)

### Fixed

- (GH-105) Ensure set runs on ambiguous ensure states [#108](https://github.com/puppetlabs/ruby-pwsh/pull/108) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-105) Ensure canonicalized_cache check validates against namevar [#107](https://github.com/puppetlabs/ruby-pwsh/pull/107) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.7.3](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.3) - 2021-02-03

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.2...0.7.3)

### Fixed

- (MAINT) Place nil check when assigning is_same [#101](https://github.com/puppetlabs/ruby-pwsh/pull/101) ([bwilcox](https://github.com/bwilcox))

## [0.7.2](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.2) - 2021-02-03

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.1...0.7.2)

### Fixed

- (GH-97) Memoize class variables in initialize [#98](https://github.com/puppetlabs/ruby-pwsh/pull/98) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (MAINT) Ensure is_same check works for nil manifest values [#96](https://github.com/puppetlabs/ruby-pwsh/pull/96) ([bwilcox](https://github.com/bwilcox))

## [0.7.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.1) - 2021-02-02

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.7.0...0.7.1)

### Fixed

- (MAINT) Correctly canonicalize enumerable values in dsc [#92](https://github.com/puppetlabs/ruby-pwsh/pull/92) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (MAINT) Ensure vendored path check works with mix of module builds [#91](https://github.com/puppetlabs/ruby-pwsh/pull/91) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-84) Fix empty array parameter check [#90](https://github.com/puppetlabs/ruby-pwsh/pull/90) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (MAINT) Minor fixes to CIM instance handling [#89](https://github.com/puppetlabs/ruby-pwsh/pull/89) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.7.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.7.0) - 2021-01-20

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.3...0.7.0)

### Added

- (GH-75) Including module name in vendored module path [#85](https://github.com/puppetlabs/ruby-pwsh/pull/85) ([pmcmaw](https://github.com/pmcmaw))

### Fixed

- Make root module path use puppetized module name [#86](https://github.com/puppetlabs/ruby-pwsh/pull/86) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.3](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.3) - 2021-01-12

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.2...0.6.3)

### Fixed

- (MAINT) Add handling for when dsc_ensure is stripped [#78](https://github.com/puppetlabs/ruby-pwsh/pull/78) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.2](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.2) - 2020-12-09

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.1...0.6.2)

### Fixed

- (MAINT) Ensure parameters are canonicalized [#75](https://github.com/puppetlabs/ruby-pwsh/pull/75) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.1) - 2020-11-25

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.6.0...0.6.1)

### Fixed

- (maint) - Removal of inappropriate terminology [#70](https://github.com/puppetlabs/ruby-pwsh/pull/70) ([pmcmaw](https://github.com/pmcmaw))
- (Maint) Fix ensurability in the dsc base provider [#69](https://github.com/puppetlabs/ruby-pwsh/pull/69) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.6.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.6.0) - 2020-11-24

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.5.1...0.6.0)

### Added

- (GH-81) Handle parameters in the dsc base provider [#62](https://github.com/puppetlabs/ruby-pwsh/pull/62) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-74) Remove special handling for ensure in the dsc base provider [#61](https://github.com/puppetlabs/ruby-pwsh/pull/61) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-59) Refactor away from Simple Provider [#60](https://github.com/puppetlabs/ruby-pwsh/pull/60) ([michaeltlombardi](https://github.com/michaeltlombardi))

### Fixed

- (GH-57) Handle datetimes in dsc [#58](https://github.com/puppetlabs/ruby-pwsh/pull/58) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (GH-55) Handle intentionally empty arrays [#56](https://github.com/puppetlabs/ruby-pwsh/pull/56) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.5.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.5.1) - 2020-09-25

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.5.0...0.5.1)

### Fixed

- (MAINT) Ensure dsc provider finds dsc resources during agent run [#45](https://github.com/puppetlabs/ruby-pwsh/pull/45) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.5.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.5.0) - 2020-08-20

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.4.1...0.5.0)

### Added

- (IAC-1045) Add the DSC base Puppet provider to pwshlib [#39](https://github.com/puppetlabs/ruby-pwsh/pull/39) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.4.1](https://github.com/puppetlabs/ruby-pwsh/tree/0.4.1) - 2020-02-12

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.4.0...0.4.1)

### Fixed

- Ensure ruby versions older than 2.3 function correctly [#30](https://github.com/puppetlabs/ruby-pwsh/pull/30) ([binford2k](https://github.com/binford2k))

## [0.4.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.4.0) - 2020-01-13

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.3.0...0.4.0)

### Added

- (MODULES-10389) Add puppet feature for dependent modules to leverage [#20](https://github.com/puppetlabs/ruby-pwsh/pull/20) ([sanfrancrisko](https://github.com/sanfrancrisko))

## [0.3.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.3.0) - 2019-12-04

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.2.0...0.3.0)

### Added

- (FEAT) Add method for symbolizing hash keys [#16](https://github.com/puppetlabs/ruby-pwsh/pull/16) ([michaeltlombardi](https://github.com/michaeltlombardi))

### Fixed

- (FEAT) Ensure hash key casing methods work on arrays [#15](https://github.com/puppetlabs/ruby-pwsh/pull/15) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.2.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.2.0) - 2019-11-25

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0.1.0...0.2.0)

### Added

- (FEAT) Add quality of life utilities [#11](https://github.com/puppetlabs/ruby-pwsh/pull/11) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (FM-8422) Make library releasable as a Puppet module [#8](https://github.com/puppetlabs/ruby-pwsh/pull/8) ([michaeltlombardi](https://github.com/michaeltlombardi))

## [0.1.0](https://github.com/puppetlabs/ruby-pwsh/tree/0.1.0) - 2019-09-25

[Full Changelog](https://github.com/puppetlabs/ruby-pwsh/compare/0eb77a723430cfbd77d4859c43e15b3f1276d164...0.1.0)
