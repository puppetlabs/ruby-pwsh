# frozen_string_literal: true

require 'spec_helper'
require 'puppet'

RSpec.describe 'pwshlib puppet feature' do
  before do
    lib_path = File.expand_path('../../../../lib', __dir__)
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.expand_path('../../../../lib/puppet/feature/pwshlib.rb', __dir__)
  end

  it 'registers the pwshlib feature with Puppet' do
    expect(Puppet.features).to respond_to(:pwshlib?)
  end

  it 'reports the feature as available when ruby-pwsh is loaded' do
    expect(Puppet.features.pwshlib?).to be(true)
  end
end
