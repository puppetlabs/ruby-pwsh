# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type'
require 'puppet/provider/dsc_base_provider/dsc_base_provider'

RSpec.describe Puppet::Provider::DscBaseProvider do
  subject(:provider) { described_class.new }

  let(:context) { instance_double('Context') }
  let(:ps_manager) { instance_double('PSManager') }
  let(:command) { 'command' }
  let(:execute_response) do
    {
      stdout: nil, stderr: nil, exitcode: 0
    }
  end

  context '.initialize' do
    before(:each) do
      # Need to initialize the provider to load the class variables
      provider
    end

    it 'initializes the cached_canonicalized_resource class variable' do
      expect(described_class.class_variable_get(:@@cached_canonicalized_resource)).to eq([])
    end
    it 'initializes the cached_query_results class variable' do
      expect(described_class.class_variable_get(:@@cached_query_results)).to eq([])
    end
    it 'initializes the logon_failures class variable' do
      expect(described_class.class_variable_get(:@@logon_failures)).to eq([])
    end
  end
  context '.fetch_cached_hashes' do
    let(:cached_hashes) do
      [
        {
          foo: 1,
          bar: 2,
          baz: 3
        },
        {
          foo: 4,
          bar: 5,
          baz: 6
        }
      ]
    end
    let(:findable_full_hash) do
      {
        foo: 1,
        bar: 2,
        baz: 3
      }
    end

    let(:findable_sub_hash) do
      { foo: 1 }
    end

    let(:undiscoverable_hash) do
      {
        foo: 7,
        bar: 8,
        baz: 9
      }
    end

    it 'finds a hash that exactly matches one in the cache' do
      expect(provider.send(:fetch_cached_hashes, cached_hashes, [findable_full_hash])).to eq([findable_full_hash])
    end
    it 'finds a hash that is wholly contained by a hash in the cache' do
      expect(provider.send(:fetch_cached_hashes, cached_hashes, [findable_sub_hash])).to eq([findable_full_hash])
    end
    it 'returns an empty array if there is no match' do
      expect(provider.send(:fetch_cached_hashes, cached_hashes, [undiscoverable_hash])).to eq([])
    end
  end

  context '.canonicalize' do
    let(:resource) do
      {
        name: 'foo',
        dsc_name: 'foo',
        dsc_property: 'bar',
        dsc_parameter: 'baz'
      }
    end
    let(:resource_with_credential) do
      {
        name: 'foo',
        dsc_name: 'foo',
        dsc_property: 'bar',
        dsc_parameter: 'baz',
        dsc_psdscrunascredential: {
          'user' => 'foo',
          'password' => 'bar'
        }
      }
    end
    let(:canonicalized_resource) do
      {
        name: 'foo',
        dsc_name: 'foo',
        dsc_property: 'bar',
        dsc_parameter: 'baz'
      }
    end
    let(:canonicalized_resource_different_case) do
      {
        name: 'foo',
        dsc_name: 'foo',
        dsc_property: 'Bar',
        dsc_parameter: 'baz'
      }
    end
    let(:canonicalized_resource_with_credential) do
      {
        name: 'foo',
        dsc_name: 'foo',
        dsc_property: 'bar',
        dsc_parameter: 'baz',
        dsc_psdscrunascredential: {
          'user' => 'foo',
          'password' => 'bar'
        }
      }
    end
    let(:resource_name_hash) do
      {
        name: 'foo',
        dsc_name: 'foo'
      }
    end
    let(:resource_actual_state) do
      {
        dsc_name: 'foo',
        dsc_property: 'bar',
        dsc_unused: 1,
        dsc_psdscrunascredential: nil
      }
    end
    let(:resource_actual_state_different_case) do
      {
        dsc_name: 'foo',
        dsc_property: 'Bar',
        dsc_unused: 1,
        dsc_psdscrunascredential: nil
      }
    end
    let(:resource_actual_state_different_value) do
      {
        dsc_name: 'foo',
        dsc_property: 'DIFFERENT',
        dsc_unused: 1,
        dsc_psdscrunascredential: nil
      }
    end
    let(:namevar_keys) { %i[name dsc_name] }
    let(:parameter_keys) { %i[dsc_parameter dsc_psdscrunascredential] }

    before(:each) do
      described_class.class_variable_set(:@@cached_canonicalized_resource, []) # rubocop:disable Style/ClassVars
    end
    after(:all) do
      described_class.class_variable_set(:@@cached_canonicalized_resource, []) # rubocop:disable Style/ClassVars
    end

    it 'returns the specified resource if it is in the canonicalized resource cache' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:namevar_attributes).exactly(4).times.and_return(namevar_keys)
      expect(provider).to receive(:fetch_cached_hashes).with([], [resource_name_hash]).and_return(canonicalized_resource)
      expect(provider.canonicalize(context, [resource])).to eq([canonicalized_resource])
    end
    it 'retrieves the resource from the machine if it is not in the cache' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:namevar_attributes).exactly(4).times.and_return(namevar_keys)
      expect(provider).to receive(:fetch_cached_hashes).with([], [resource_name_hash]).and_return([])
      expect(provider).to receive(:invoke_get_method).and_return(resource_actual_state)
      expect(provider).to receive(:parameter_attributes).exactly(4).times.and_return(parameter_keys)
      expect(provider.canonicalize(context, [resource])).to eq([canonicalized_resource])
    end
    it 'caches the specified resource if the retrieval returns nil' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:namevar_attributes).exactly(4).times.and_return(namevar_keys)
      expect(provider).to receive(:fetch_cached_hashes).with([], [resource_name_hash]).and_return([])
      expect(provider).to receive(:invoke_get_method).and_return(nil)
      expect(provider.canonicalize(context, [resource])).to eq([resource])
    end
    it 'removes the dsc_psdscrunascredential from the resource if not specified' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:namevar_attributes).exactly(4).times.and_return(namevar_keys)
      expect(provider).to receive(:fetch_cached_hashes).with([], [resource_name_hash]).and_return([])
      expect(provider).to receive(:invoke_get_method).and_return(resource_actual_state)
      expect(provider).to receive(:parameter_attributes).exactly(4).times.and_return(parameter_keys)
      expect(provider.canonicalize(context, [resource])).to eq([canonicalized_resource])
    end
    it 'sets the dsc_psdscrunascredential to the value from the input, if specified' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:namevar_attributes).exactly(5).times.and_return(namevar_keys)
      expect(provider).to receive(:fetch_cached_hashes).with([], [resource_name_hash]).and_return([])
      expect(provider).to receive(:invoke_get_method).and_return(resource_actual_state)
      expect(provider).to receive(:parameter_attributes).exactly(5).times.and_return(parameter_keys)
      expect(provider.canonicalize(context, [resource_with_credential])).to eq([canonicalized_resource_with_credential])
    end
    it 'assigns the value of the discovered resource if it is a downcased match for the specified resource' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:namevar_attributes).exactly(4).times.and_return(namevar_keys)
      expect(provider).to receive(:fetch_cached_hashes).with([], [resource_name_hash]).and_return([])
      expect(provider).to receive(:invoke_get_method).and_return(resource_actual_state_different_case)
      expect(provider).to receive(:parameter_attributes).exactly(4).times.and_return(parameter_keys)
      expect(provider.canonicalize(context, [resource])).to eq([canonicalized_resource_different_case])
    end
    it 'assigns the value of the specified resource if it differs from the discovered resource by more than just casing' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:namevar_attributes).exactly(4).times.and_return(namevar_keys)
      expect(provider).to receive(:fetch_cached_hashes).with([], [resource_name_hash]).and_return([])
      expect(provider).to receive(:invoke_get_method).and_return(resource_actual_state_different_value)
      expect(provider).to receive(:parameter_attributes).exactly(4).times.and_return(parameter_keys)
      expect(provider.canonicalize(context, [resource])).to eq([canonicalized_resource])
    end
  end
  context '.get' do
    it 'checks the cached results, returning if one exists for the specified names'
    it 'adds mandatory properties to the name hash when calling invoke_get_method'
  end
  context '.create' do
    it 'calls invoke_set_method' do
      foo = Object.new
      allow(foo).to receive(:debug)
      expect(provider).to receive(:invoke_set_method)
      expect(provider.send(:create, foo, 'foo', { foo: 1 }))
    end
  end
  context '.update' do
    it 'calls invoke_set_method' do
      foo = Object.new
      allow(foo).to receive(:debug)
      expect(provider).to receive(:invoke_set_method)
      expect(provider.send(:update, foo, 'foo', { foo: 1 }))
    end
  end
  context '.delete' do
    it 'calls invoke_set_method' do
      foo = Object.new
      allow(foo).to receive(:debug)
      expect(provider).to receive(:invoke_set_method)
      expect(provider.send(:delete, foo, { foo: 1 }))
    end
  end
  context '.invoke_get_method' do
    let(:foo) { Object.new }
    let(:bad_logon) do
      {
        name: 'foo',
        dsc_psdscrunascredential: 'bar'
      }
    end

    before(:each) do
      allow(foo).to receive(:debug)
    end

    it 'returns if the specified account has already failed to logon' do
      expect(provider).to receive(:logon_failed_already?).and_return(true)
      expect(provider.send(:invoke_get_method, foo, bad_logon)).to be bad_logon
    end
    it 'filters for only the mandatory parameters'
    it 'converts the should hash to a resource object'
    it 'converts the resource object into a powershell script'
    it 'errors if no data is returned'
    it 'parses the returned output'
    it 'errors specifically for a logon failure and returns nil'
    it 'errors generally for any other error and returns nil'
    it 'filters returned data for valid attributes'
    it 'downcases and camel_cases the returned object keys'
    it 'reinserts the dsc_psdscrunascredential if specified'
    it 'caches the results'
    it 'returns the results'
  end
  context '.invoke_set_method' do
    let(:foo) { Object.new }
    let(:bad_logon) do
      {
        name: 'foo',
        dsc_psdscrunascredential: 'bar'
      }
    end

    before(:each) do
      allow(foo).to receive(:debug)
    end

    it 'returns if the specified account has already failed to logon' do
      expect(provider).to receive(:logon_failed_already?).and_return(true)
      expect(provider.send(:invoke_set_method, foo, 'foo', bad_logon)).to eq(nil)
    end
    it 'only passes the needed properties when converting to a resource'
    it 'it builds a PowerShell script to apply the resource'
    it 'attempts to apply the resource'
    it 'errors if no data is returned'
    it 'parses the data'
    it 'errors if the return data includes an error message'
    it 'returns the results object'
  end
  context '.should_to_resource' do
    it 'retrieves the metadata from the type definition for the resource'
    it 'does not pass dsc_psdscrunascredential if nil'
    it 'adds the mof information if required'
    it 'searches the load path for the relevant module where the vendored DSC resources are'
    it 'returns the resource'
  end
  context '.random_variable_name' do
    it 'creates random variables' do
      expect(provider.send(:random_variable_name).nil?).to be false
    end
    it 'includes underscores instead of hyphens' do
      expect(provider.send(:random_variable_name)).to match(/_/)
      expect(provider.send(:random_variable_name)).to_not match(/-/)
    end
  end
  context '.instantiated_variables' do
    it 'sets the instantiated_variables class variable to {} if not initialized'
    it 'returns the instantiated_variables class variable if already initialized'
  end
  context '.clear_instantiated_variables!' do
    it 'sets the instantiated_variables class variable to {}'
  end
  context '.logon_failed_already?' do
    it 'returns true if the username/password specified are found in the logon_failures class variable'
    it 'returns false if there have been no failed logons with the username/password combination'
  end
  context '.camelcase_hash_keys!' do
    it 'converts all the keys in a hash into camel_case, even if nested in another hash or array'
  end
  context '.recursively_downcase' do
    it 'downcases any string passed, whether alone or in a hash or array or nested deeply'
  end
  context '.ensurable?' do
    it 'returns true if the type has the ensure attribute'
    it 'returns false if the type does not have the ensure attribute'
  end
  context '.mandatory_get_attributes' do
    it 'returns the list of attributes from the type where the mandatory_for_get meta property is true'
  end
  context '.mandatory_set_attributes' do
    it 'returns the list of attributes from the type where the mandatory_for_set meta property is true'
  end
  context '.namevar_attributes' do
    it 'returns the list of attributes from the type where the attribute has the namevar behavior'
  end
  context '.interpolate_variables' do
    it 'replaces all discovered pointers to a variable with the variable'
  end
  context '.prepare_credentials' do
    it 'returns an empty string if no pscredential parameters were passed'
    it 'writes the ruby representation of the credentials as the value of a key named for the new variable into the instantiated_variables cache'
    it 'returns an array of strings each containing the instantiation of a PowerShell variable representing the credential hash'
  end
  context '.format_pscredential' do
    it 'returns a string representing the instantiation of a PowerShell variable representing the credential hash'
  end
  context '.prepare_cim_instances' do
    it 'processes only for properties which have an embedded mof'
    it 'creates a variable for the cim instance declaration and saves it to the instantiated_variables cache'
    it 'returns an empty string if there are no embedded cim instances'
    it 'returns an array of strings each containing the instantiation of a PowerShell variable representing the cim instance'
  end
  context '.nested_cim_instances' do
    it 'returns cim instances nested inside an array'
    it 'returns cim instances nested inside a hash'
  end
  context '.format_ciminstance' do
    it 'defines and returns a new cim instance as a PowerShell variable, passing the class name and property hash'
    it 'handles arrays of cim instances'
    it 'interpolates variables in the case of a cim instance containing a nested instance'
  end
  context '.invoke_params' do
    it 'builds a splattable hash for the invoking dsc, including the module name and required version, as well as any specified properties'
    it 'handles PSCredentials'
  end
  context '.ps_script_content' do
    it 'returns a powershell script with the helper functions'
    it 'includes the preamble'
    it 'includes the credential block, if needed'
    it 'includes the cim instances block, if needed'
    it 'includes the parameters block'
    it 'includes the postscript block'
  end
  context '.format' do
    it 'uses Pwsh::Util to format the values'
    it 'handles sensitive values especially'
  end
  context '.unwrap' do
    it 'unwraps a sensitive string, appending "#PuppetSensitive" to the end'
    it 'handles sensitive values in a hash'
    it 'handles sensitive values in an array'
    it 'returns the input if it does not include any sensitive strings'
  end
  context '.escape_quotes' do
    it "replaces single ' with '' in a given string"
  end
  context '.redact_secrets' do
    it 'replaces any unwrapped password declaration value with "#<Sensitive [Value redacted]>"'
  end
  context '.ps_manager' do
    it 'Initializes an instance of the Pwsh::Manager'
  end
end
