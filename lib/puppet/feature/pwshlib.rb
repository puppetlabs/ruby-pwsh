# frozen_string_literal: true

require 'puppet/util/feature'

Puppet.features.add(:pwshlib, libs: ['ruby-pwsh'])
