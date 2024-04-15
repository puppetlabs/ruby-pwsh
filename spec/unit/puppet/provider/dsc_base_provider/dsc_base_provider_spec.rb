# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type'
require 'puppet/resource_api'
require 'puppet/provider/dsc_base_provider/dsc_base_provider'
require 'json'

RSpec.describe Puppet::Provider::DscBaseProvider do
  subject(:provider) { described_class.new }

  let(:context) { instance_double(Puppet::ResourceApi::BaseContext, 'context') }
  let(:type) { instance_double(Puppet::ResourceApi::TypeDefinition, 'typedef') }
  let(:ps_manager) { instance_double(Pwsh::Manager) }
  let(:execute_response) { { stdout: nil, stderr: nil, exitcode: 0 } }

  # Reset the caches after each run
  after do
    provider.instance_variable_set(:@cached_canonicalized_resource, [])
    provider.instance_variable_set(:@cached_query_results, [])
    provider.instance_variable_set(:@cached_test_results, [])
    provider.instance_variable_set(:@logon_failures, [])
  end

  describe '.initialize' do
    before do
      # Need to initialize the provider to load the instance variables
      provider
    end

    it 'initializes the cached_canonicalized_resource instance variable' do
      expect(provider.instance_variable_get(:@cached_canonicalized_resource)).to eq([])
    end

    it 'initializes the cached_query_results instance variable' do
      expect(provider.instance_variable_get(:@cached_query_results)).to eq([])
    end

    it 'initializes the cached_test_results instance variable' do
      expect(provider.instance_variable_get(:@cached_test_results)).to eq([])
    end

    it 'initializes the logon_failures instance variable' do
      expect(provider.instance_variable_get(:@logon_failures)).to eq([])
    end
  end

  describe '.cached_test_results' do
    let(:cache_value) { %w[foo bar] }

    before do
      provider.instance_variable_set(:@cached_test_results, cache_value)
    end

    it 'returns the value of the @cached_test_results instance variable' do
      expect(provider.cached_test_results).to eq(cache_value)
    end
  end

  describe '.fetch_cached_hashes' do
    let(:cached_hashes) { [{ foo: 1, bar: 2, baz: 3 }, { foo: 4, bar: 5, baz: 6 }] }
    let(:findable_full_hash) { { foo: 1, bar: 2, baz: 3 } }
    let(:findable_sub_hash) { { foo: 1 } }
    let(:undiscoverable_hash) { { foo: 7, bar: 8, baz: 9 } }

    it 'finds a hash that exactly matches one in the cache' do
      expect(provider.fetch_cached_hashes(cached_hashes, [findable_full_hash])).to eq([findable_full_hash])
    end

    it 'finds a hash that is wholly contained by a hash in the cache' do
      expect(provider.fetch_cached_hashes(cached_hashes, [findable_sub_hash])).to eq([findable_full_hash])
    end

    it 'returns an empty array if there is no match' do
      expect(provider.fetch_cached_hashes(cached_hashes, [undiscoverable_hash])).to eq([])
    end
  end

  describe '.canonicalize' do
    subject(:canonicalized_resource) { provider.canonicalize(context, [manifest_resource]) }

    let(:resource_name_hash) { { name: 'foo', dsc_name: 'foo' } }
    let(:namevar_keys) { %i[name dsc_name] }
    let(:parameter_keys) { %i[dsc_parameter dsc_psdscrunascredential] }
    let(:credential_hash) { { 'username' => 'foo', 'password' => 'bar' } }
    let(:base_resource) { resource_name_hash.dup }

    before do
      allow(context).to receive(:debug)
      allow(provider).to receive(:namevar_attributes).and_return(namevar_keys)
      allow(provider).to receive(:fetch_cached_hashes).and_return(cached_canonicalized_resource)
    end

    context 'when a manifest resource has meta parameters' do
      let(:manifest_resource) { base_resource.merge({ dsc_ensure: 'present', noop: true }) }
      let(:expected_resource) { base_resource.merge({ dsc_property: 'foobar' }) }
      let(:cached_canonicalized_resource) { expected_resource.dup }

      it 'does not get removed as part of the canonicalization' do
        expect(canonicalized_resource.first[:noop]).to be(true)
      end
    end

    context 'when a manifest resource is in the canonicalized resource cache' do
      let(:manifest_resource) { base_resource.merge({ dsc_property: 'FooBar' }) }
      let(:expected_resource) { base_resource.merge({ dsc_property: 'foobar' }) }
      let(:cached_canonicalized_resource) { expected_resource.dup }

      it 'returns the manifest resource' do
        expect(canonicalized_resource).to eq([manifest_resource])
      end
    end

    context 'when a manifest resource not in the canonicalized resource cache' do
      let(:cached_canonicalized_resource) { [] }

      before do
        allow(provider).to receive(:invoke_get_method).and_return(actual_resource)
      end

      context 'when invoke_get_method returns nil for the manifest resource' do
        let(:manifest_resource) { base_resource.merge({ dsc_property: 'FooBar' }) }
        let(:actual_resource) { nil }

        it 'treats the manifest as canonical' do
          expect(canonicalized_resource).to eq([manifest_resource])
        end
      end

      context 'when invoke_get_method returns a resource' do
        before do
          allow(provider).to receive(:parameter_attributes).and_return(parameter_keys)
          allow(provider).to receive(:enum_attributes).and_return([])
        end

        context 'when canonicalizing property values' do
          let(:manifest_resource) { base_resource.merge({ dsc_property: 'bar' }) }

          context 'when the value is a downcased match' do
            let(:actual_resource) { base_resource.merge({ dsc_property: 'Bar' }) }

            it 'assigns the value of the discovered resource for that property' do
              expect(canonicalized_resource.first[:dsc_property]).to eq('Bar')
            end
          end

          context 'when the value is not a downcased match' do
            let(:actual_resource) { base_resource.merge({ dsc_property: 'Baz' }) }

            it 'assigns the value of the manifest resource for that property' do
              expect(canonicalized_resource.first[:dsc_property]).to eq('bar')
            end
          end

          context 'when the value should be nil and the actual state is not' do
            let(:manifest_resource) { base_resource.merge({ dsc_property: nil }) }
            let(:actual_resource) { base_resource.merge({ dsc_property: 'Bar' }) }

            it 'treats the manifest value as canonical' do
              expect(canonicalized_resource.first[:dsc_property]).to be_nil
            end
          end

          context 'when the value should not be nil and the actual state is nil' do
            let(:manifest_resource) { base_resource.merge({ dsc_property: 'bar' }) }
            let(:actual_resource) { base_resource.merge({ dsc_property: nil }) }

            it 'treats the manifest value as canonical' do
              expect(canonicalized_resource.first[:dsc_property]).to eq('bar')
            end
          end

          context 'when the property is an enum and the casing differs' do
            let(:manifest_resource) { base_resource.merge({ dsc_property: 'Dword' }) }
            let(:actual_resource) { base_resource.merge({ dsc_property: 'DWord' }) }

            before do
              allow(provider).to receive(:enum_attributes).and_return([:dsc_property])
            end

            it 'treats the manifest value as canonical' do
              expect(context).to receive(:type).and_return(type)
              expect(type).to receive(:attributes).and_return({ dsc_property: { type: "Enum['Dword']" } })
              expect(canonicalized_resource.first[:dsc_property]).to eq('Dword')
            end
          end
        end

        context 'when handling dsc_psdscrunascredential' do
          let(:actual_resource) { base_resource.merge({ dsc_psdscrunascredential: nil }) }

          context 'when it is specified in the resource' do
            let(:manifest_resource) { base_resource.merge({ dsc_psdscrunascredential: credential_hash }) }

            it 'is included from the manifest resource' do
              expect(canonicalized_resource.first[:dsc_psdscrunascredential]).not_to be_nil
            end
          end

          context 'when it is not specified in the resource' do
            let(:manifest_resource) { base_resource.dup }

            it 'is not included in the canonicalized resource' do
              expect(canonicalized_resource.first[:dsc_psdscrunascredential]).to be_nil
            end
          end
        end

        context 'when an ensurable resource is specified' do
          context 'when it should be present' do
            let(:manifest_resource) { base_resource.merge({ dsc_ensure: 'present', dsc_property: 'bar' }) }

            context 'when the actual state is set to absent' do
              let(:actual_resource) { base_resource.merge({ dsc_ensure: 'absent', dsc_property: nil }) }

              it 'treats the manifest as canonical' do
                expect(canonicalized_resource).to eq([manifest_resource])
              end
            end

            context 'when it is returned from invoke_get_method with ensure set to present' do
              let(:actual_resource) { base_resource.merge({ dsc_ensure: 'present', dsc_property: 'Bar' }) }

              it 'is case insensitive but case preserving' do
                expect(canonicalized_resource.first[:dsc_property]).to eq('Bar')
              end
            end
          end

          context 'when it should be absent' do
            let(:manifest_resource) { base_resource.merge({ dsc_ensure: 'absent' }) }
            let(:actual_resource) { base_resource.merge({ dsc_ensure: 'present', dsc_property: 'Bar' }) }

            it 'treats the manifest as canonical' do
              expect(provider).not_to receive(:invoke_get_method)
              expect(canonicalized_resource).to eq([manifest_resource])
            end
          end
        end
      end
    end
  end

  describe '.get' do
    after do
      provider.instance_variable_set(:@cached_canonicalized_resource, [])
    end

    it 'checks the cached results, returning if one exists for the specified names' do
      provider.instance_variable_set(:@cached_canonicalized_resource, [])
      allow(context).to receive(:debug)
      expect(provider).to receive(:fetch_cached_hashes).with([], [{ name: 'foo' }]).and_return([{ name: 'foo', property: 'bar' }])
      expect(provider).not_to receive(:invoke_get_method)
      expect(provider.get(context, [{ name: 'foo' }])).to eq([{ name: 'foo', property: 'bar' }])
    end

    it 'adds mandatory properties to the name hash when calling invoke_get_method' do
      provider.instance_variable_set(:@cached_canonicalized_resource, [{ name: 'foo', property: 'bar', dsc_some_parameter: 'baz' }])
      allow(context).to receive(:debug)
      expect(provider).to receive(:fetch_cached_hashes).with([], [{ name: 'foo' }]).and_return([])
      expect(provider).to receive(:namevar_attributes).and_return([:name]).exactly(3).times
      expect(provider).to receive(:mandatory_get_attributes).and_return([:dsc_some_parameter]).exactly(3).times
      expect(provider).to receive(:invoke_get_method).with(context, { name: 'foo', dsc_some_parameter: 'baz' }).and_return({ name: 'foo', property: 'bar' })
      expect(provider.get(context, [{ name: 'foo' }])).to eq([{ name: 'foo', property: 'bar' }])
    end
  end

  describe '.set' do
    subject(:result) { provider.set(context, change_set) }

    let(:name_hash) { { name: 'foo', dsc_name: 'foo' } }
    let(:change_set) { { name_hash => { is: actual_state, should: should_state } } }
    # Empty because we can mock everything but calling .keys on the hash
    let(:attributes) { { name: {}, dsc_name: {}, dsc_setting: {} } }

    before do
      allow(context).to receive(:type).and_return(type)
      allow(type).to receive(:namevars).and_return(%i[name dsc_name])
      allow(type).to receive(:attributes).and_return(attributes)
    end

    context 'when the resource is not ensurable' do
      let(:actual_state) { name_hash.merge(dsc_setting: 'Bar') }
      let(:should_state) { name_hash.merge(dsc_setting: 'Foo') }

      it 'calls context.updating and provider.update' do
        expect(context).to receive(:updating).with(name_hash).and_yield
        expect(provider).to receive(:update).with(context, name_hash, should_state)
        expect { result }.not_to raise_error
      end
    end

    context 'when the resource is ensurable' do
      let(:attributes) { { name: {}, dsc_name: {}, dsc_setting: {}, dsc_ensure: {} } }

      context 'when the resource should be present' do
        let(:should_state) { name_hash.merge({ dsc_setting: 'Foo', dsc_ensure: 'Present' }) }

        context 'when the resource exists but is out of sync' do
          let(:actual_state) { name_hash.merge({ dsc_setting: 'Bar', dsc_ensure: 'Present' }) }

          it 'calls context.updating and provider.update' do
            expect(context).to receive(:updating).with(name_hash).and_yield
            expect(provider).to receive(:update).with(context, name_hash, should_state)
            expect { result }.not_to raise_error
          end
        end

        context 'when the resource does not exist' do
          let(:actual_state) { name_hash.merge({ dsc_name: 'Foo', dsc_ensure: 'Absent' }) }

          it 'calls context.creating and provider.create' do
            expect(context).to receive(:creating).with(name_hash).and_yield
            expect(provider).to receive(:create).with(context, name_hash, should_state)
            expect { result }.not_to raise_error
          end
        end
      end

      context 'when the resource should be absent' do
        let(:should_state) { name_hash.merge({ dsc_setting: 'Foo', dsc_ensure: 'Absent' }) }
        let(:actual_state) { name_hash.merge({ dsc_name: 'Foo', dsc_ensure: 'Present' }) }

        it 'calls context.deleting and provider.delete' do
          expect(context).to receive(:deleting).with(name_hash).and_yield
          expect(provider).to receive(:delete).with(context, name_hash)
          expect { result }.not_to raise_error
        end
      end

      context 'when ensure is not passed to should' do
        let(:should_state) { name_hash.merge({ dsc_setting: 'Foo' }) }
        let(:actual_state) { name_hash.merge({ dsc_name: 'Foo', dsc_ensure: 'Present' }) }

        it 'assumes dsc_ensure should be `Present` and acts accordingly' do
          expect(context).to receive(:updating).with(name_hash).and_yield
          expect(provider).to receive(:update).with(context, name_hash, should_state)
          expect { result }.not_to raise_error
        end
      end

      context 'when ensure is not passed to is' do
        let(:should_state) { name_hash.merge({ dsc_setting: 'Foo', dsc_ensure: 'Present' }) }
        let(:actual_state) { name_hash.merge({ dsc_name: 'Foo', dsc_ensure: 'Absent' }) }

        it 'assumes dsc_ensure should be `Present` and acts accordingly' do
          expect(context).to receive(:creating).with(name_hash).and_yield
          expect(provider).to receive(:create).with(context, name_hash, should_state)
          expect { result }.not_to raise_error
        end
      end
    end

    context 'when `is` is nil' do
      let(:change_set) { { name_hash => { should: should_state } } }
      let(:should_state) { name_hash.merge(dsc_setting: 'Foo') }

      it 'attempts to retrieve the resource from the machine to populate `is` value' do
        pending('Implementation only works for when `get` returns an array, but `get` returns one resource as a hash')
        expect(provider).to receive(:get).with(context, [name_hash]).and_return(name_hash.merge(dsc_setting: 'Bar'))
        expect(type).to receive(:check_schema)
        expect(context).to receive(:updating).with(name_hash)
        expect(provider).to receive(:update).with(context, name_hash, should_state)
        expect { result }.not_to raise_error
      end
    end
  end

  describe '.create' do
    it 'calls invoke_set_method' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:invoke_set_method)
      expect { provider.create(context, 'foo', { foo: 1 }) }.not_to raise_error
    end
  end

  describe '.update' do
    it 'calls invoke_set_method' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:invoke_set_method)
      expect { provider.update(context, 'foo', { foo: 1 }) }.not_to raise_error
    end
  end

  describe '.delete' do
    it 'calls invoke_set_method' do
      allow(context).to receive(:debug)
      expect(provider).to receive(:invoke_set_method)
      expect { provider.delete(context, { foo: 1 }) }.not_to raise_error
    end
  end

  describe '.insync?' do
    let(:name)               { { name: 'foo' } }
    let(:attribute_name)     { :foo }
    let(:is_hash)            { { name: 'foo', foo: 1 } }
    let(:cached_test_result) { [{ name: 'foo', in_desired_state: true }] }
    let(:should_hash_validate_by_property) { { name: 'foo', foo: 1, validation_mode: 'property' } }
    let(:should_hash_validate_by_resource) { { name: 'foo', foo: 1, validation_mode: 'resource' } }

    context 'when the validation_mode is "resource"' do
      it 'calls invoke_test_method if the result of a test is not already cached' do
        expect(provider).to receive(:fetch_cached_hashes).and_return([])
        expect(provider).to receive(:invoke_test_method).and_return(true)
        expect(provider.send(:insync?, context, name, attribute_name, is_hash, should_hash_validate_by_resource)).to be true
      end

      it 'does not call invoke_test_method if the result of a test is already cached' do
        expect(provider).to receive(:fetch_cached_hashes).and_return(cached_test_result)
        expect(provider).not_to receive(:invoke_test_method)
        expect(provider.send(:insync?, context, name, attribute_name, is_hash, should_hash_validate_by_resource)).to be true
      end
    end

    context 'when the validation_mode is "property"' do
      it 'does not call invoke_test_method and returns nil' do
        expect(provider).not_to receive(:fetch_cached_hashes)
        expect(provider).not_to receive(:invoke_test_method)
        expect(provider.send(:insync?, context, name, attribute_name, is_hash, should_hash_validate_by_property)).to be_nil
      end
    end
  end

  describe '.invoke_get_method' do
    subject(:result) { provider.invoke_get_method(context, name_hash) }

    let(:attributes) do
      {
        name: {
          type: 'String',
          behaviour: :namevar
        },
        dsc_name: {
          type: 'String',
          behaviour: :namevar,
          mandatory_for_get: true,
          mandatory_for_set: true,
          mof_type: 'String',
          mof_is_embedded: false
        },
        dsc_psdscrunascredential: {
          type: 'Optional[Struct[{ user => String[1], password => Sensitive[String[1]] }]]',
          behaviour: :parameter,
          mandatory_for_get: false,
          mandatory_for_set: false,
          mof_type: 'PSCredential',
          mof_is_embedded: true
        },
        dsc_ensure: {
          type: "Optional[Enum['Present', 'Absent']]",
          mandatory_for_get: false,
          mandatory_for_set: false,
          mof_type: 'String',
          mof_is_embedded: false
        },
        dsc_time: {
          type: 'Optional[Timestamp]',
          mandatory_for_get: false,
          mandatory_for_set: false,
          mof_type: 'DateTime',
          mof_is_embedded: false
        },
        dsc_ciminstance: {
          type: "Optional[Struct[{
                  foo => Optional[Boolean],
                  bar => Optional[String],
                }]]",
          mandatory_for_get: false,
          mandatory_for_set: false,
          mof_type: 'FooBarCimInstance',
          mof_is_embedded: true
        },
        dsc_nestedciminstance: {
          type: "Optional[Struct[{
                  baz => Optional[Boolean],
                  nestedProperty => Struct[{
                    nestedFoo => Optional[Enum['Yay', 'Boo']],
                    nestedBar => Optional[String],
                    cim_instance_type => 'FooBarNestedCimInstance'
                  }],
                }]]",
          mandatory_for_get: false,
          mandatory_for_set: false,
          mof_type: 'BazCimInstance',
          mof_is_embedded: true
        },
        dsc_array: {
          type: 'Optional[Array[String]]',
          mandatory_for_get: false,
          mandatory_for_set: false,
          mof_type: 'String[]',
          mof_is_embedded: false
        },
        dsc_param: {
          type: 'Optional[String]',
          behaviour: :parameter,
          mandatory_for_get: false,
          mandatory_for_set: false,
          mof_type: 'String',
          mof_is_embedded: false
        }
      }
    end
    let(:name_hash) { { name: 'foo', dsc_name: 'foo', dsc_time: '2100-01-01' } }
    let(:mandatory_get_attributes) { %i[dsc_name] }
    let(:query_props) { { dsc_name: 'foo' } }
    let(:resource) { "Resource: #{query_props}" }
    let(:script) { "Script: #{query_props}" }
    let(:parsed_invocation_data) do
      {
        'Name' => 'foo',
        'Ensure' => 'Present',
        'Time' => '2100-01-01',
        'CimInstance' => { 'Foo' => true, 'Bar' => 'Ope' },
        'NestedCimInstance' => {
          'Baz' => true,
          'NestedProperty' => { 'NestedFoo' => 'yay', 'NestedBar' => 'Ope', 'cim_instance_type' => 'FooBarNestedCimINstance' }
        },
        'Array' => %w[foo bar],
        'EmptyArray' => nil,
        'Param' => 'Value',
        'UnusedProperty' => 'foo'
      }
    end

    before do
      allow(context).to receive(:debug)
      allow(provider).to receive(:mandatory_get_attributes).and_return(mandatory_get_attributes)
      allow(provider).to receive(:invocable_resource).with(query_props, context, 'get').and_return(resource)
      allow(provider).to receive(:ps_script_content).with(resource).and_return(script)
      allow(provider).to receive(:redact_secrets).with(script)
      allow(provider).to receive(:remove_secret_identifiers).with(script).and_return(script)
      allow(provider).to receive(:ps_manager).and_return(ps_manager)
      allow(context).to receive(:type).and_return(type)
      allow(type).to receive(:attributes).and_return(attributes)
    end

    after do
      provider.instance_variable_set(:@cached_query_results, [])
    end

    context 'when the invocation script returns data without errors' do
      before do
        allow(ps_manager).to receive(:execute).with(script).and_return({ stdout: 'DSC Data' })
        allow(JSON).to receive(:parse).with('DSC Data').and_return(parsed_invocation_data)
        allow(Puppet::Pops::Time::Timestamp).to receive(:parse).with('2100-01-01').and_return('TimeStamp:2100-01-01')
        allow(provider).to receive(:fetch_cached_hashes).and_return([])
      end

      it 'does not check for logon failures as no PSDscRunAsCredential was passed' do
        expect(provider).not_to receive(:logon_failed_already?)
        expect { result }.not_to raise_error
      end

      it 'writes no errors to the context' do
        expect(context).not_to receive(:err)
        expect { result }.not_to raise_error
      end

      it 're-adds the puppet name to the resource' do
        expect(result[:name]).to eq('foo')
      end

      it 'caches the result' do
        expect { result }.not_to raise_error
        expect(provider.instance_variable_get(:@cached_query_results)).to eq([result])
      end

      it 'removes unrelated properties from the result' do
        expect(result.keys).not_to include('UnusedProperty')
        expect(result.keys).not_to include('unusedproperty')
        expect(result.keys).not_to include(:unusedproperty)
      end

      it 'removes parameters from the result' do
        expect(result[:dsc_param]).to be_nil
      end

      it 'handles timestamps' do
        expect(result[:dsc_time]).to eq('TimeStamp:2100-01-01')
      end

      it 'downcases keys in cim instance properties' do
        expect(result[:dsc_nestedciminstance].keys).to eq(%w[baz nestedproperty])
        expect(result[:dsc_nestedciminstance]['nestedproperty'].keys).to eq(%w[cim_instance_type nestedbar nestedfoo])
      end

      it 'recursively sorts the result for order-insensitive comparisons' do
        expect(result.keys).to eq(%i[dsc_array dsc_ciminstance dsc_ensure dsc_name dsc_nestedciminstance dsc_time name])
        expect(result[:dsc_array]).to eq(%w[bar foo])
        expect(result[:dsc_ciminstance].keys).to eq(%w[bar foo])
        expect(result[:dsc_nestedciminstance].keys).to eq(%w[baz nestedproperty])
        expect(result[:dsc_nestedciminstance]['nestedproperty'].keys).to eq(%w[cim_instance_type nestedbar nestedfoo])
      end

      context 'when a namevar is an array' do
        let(:name_hash) { { name: 'foo', dsc_name: 'foo', dsc_array: %w[foo bar] } }
        let(:query_props) { { dsc_name: 'foo', dsc_array: %w[foo bar] } }
        let(:mandatory_get_attributes) { %i[dsc_name dsc_array] }
        let(:attributes) do
          {
            name: {
              type: 'String',
              behaviour: :namevar
            },
            dsc_name: {
              type: 'String',
              behaviour: :namevar,
              mandatory_for_get: true,
              mandatory_for_set: true,
              mof_type: 'String',
              mof_is_embedded: false
            },
            dsc_array: {
              type: 'Array[String]',
              mandatory_for_get: true,
              mandatory_for_set: true,
              mof_type: 'String[]',
              mof_is_embedded: false
            }
          }
        end
        let(:parsed_invocation_data) do
          { 'Name' => 'foo', 'Ensure' => 'Present', 'Array' => %w[foo bar] }
        end

        it 'behaves like any other namevar when specified as not empty' do
          expect(result[:dsc_array]).to eq(%w[bar foo])
        end

        context 'when the namevar array is empty' do
          # Does this ever happen?
          let(:name_hash) { { name: 'foo', dsc_name: 'foo', dsc_array: [] } }
          let(:query_props) { { dsc_name: 'foo', dsc_array: [] } }

          context 'when DSC returns @()' do
            let(:parsed_invocation_data) do
              { 'Name' => 'foo', 'Ensure' => 'Present', 'Array' => [] }
            end

            it 'returns [] for the array value' do
              expect(result[:dsc_array]).to eq([])
            end
          end

          context 'when DSC returns $null' do
            let(:parsed_invocation_data) do
              { 'Name' => 'foo', 'Ensure' => 'Present', 'Array' => nil }
            end

            it 'returns [] for the array value' do
              expect(result[:dsc_array]).to eq([])
            end
          end
        end
      end
    end

    context 'when the DSC invocation errors' do
      it 'writes an error and returns nil' do
        expect(provider).not_to receive(:logon_failed_already?)
        expect(ps_manager).to receive(:execute).with(script).and_return({ stdout: nil })
        expect(context).to receive(:err).with('Nothing returned')
        expect(result).to be_nil
      end
    end

    context 'when handling DateTimes' do
      before do
        allow(ps_manager).to receive(:execute).with(script).and_return({ stdout: 'DSC Data' })
        allow(JSON).to receive(:parse).with('DSC Data').and_return(parsed_invocation_data)
        allow(provider).to receive(:fetch_cached_hashes).and_return([])
      end

      context 'When the DateTime is nil' do
        let(:name_hash) { { name: 'foo', dsc_name: 'foo', dsc_time: nil } }
        let(:parsed_invocation_data) do
          { 'Name' => 'foo', 'Ensure' => 'Present', 'Time' => nil }
        end

        it 'returns nil for the value' do
          expect(context).not_to receive(:err)
          expect(result[:dsc_time]).to be_nil
        end
      end

      context 'When the DateTime is an invalid string' do
        let(:name_hash) { { name: 'foo', dsc_name: 'foo', dsc_time: 'foo' } }
        let(:parsed_invocation_data) do
          { 'Name' => 'foo', 'Ensure' => 'Present', 'Time' => 'foo' }
        end

        it 'writes an error and sets the value of `dsc_time` to nil' do
          expect(context).to receive(:err).with(/Value returned for DateTime/)
          expect(result[:dsc_time]).to be_nil
        end
      end

      context 'When the DateTime is an invalid type (integer, hash, etc)' do
        let(:name_hash) { { name: 'foo', dsc_name: 'foo', dsc_time: 2100 } }
        let(:parsed_invocation_data) do
          { 'Name' => 'foo', 'Ensure' => 'Present', 'Time' => 2100 }
        end

        it 'writes an error and sets the value of `dsc_time` to nil' do
          expect(context).to receive(:err).with(/Value returned for DateTime/)
          expect(result[:dsc_time]).to be_nil
        end
      end
    end

    context 'with PSDscCredential' do
      let(:credential_hash) { { 'user' => 'SomeUser', 'password' => 'FooBarBaz' } }
      let(:dsc_logon_failure_error) { 'Logon failure: the user has not been granted the requested logon type at this computer' }
      let(:puppet_logon_failure_error) { 'PSDscRunAsCredential account specified (SomeUser) does not have appropriate logon rights; are they an administrator?' }
      let(:name_hash) { { name: 'foo', dsc_name: 'foo', dsc_psdscrunascredential: credential_hash } }
      let(:query_props) { { dsc_name: 'foo', dsc_psdscrunascredential: credential_hash } }

      context 'when the credential is invalid' do
        before do
          allow(provider).to receive(:logon_failed_already?).and_return(false)
          allow(ps_manager).to receive(:execute).with(script).and_return({ stdout: 'DSC Data' })
          allow(JSON).to receive(:parse).with('DSC Data').and_return({ 'errormessage' => dsc_logon_failure_error })
          allow(context).to receive(:err).with(name_hash[:name], puppet_logon_failure_error)
        end

        after do
          provider.instance_variable_set(:@logon_failures, [])
        end

        it 'errors specifically for a logon failure and returns nil' do
          expect(result).to be_nil
        end

        it 'caches the logon failure' do
          expect { result }.not_to raise_error
          expect(provider.instance_variable_get(:@logon_failures)).to eq([credential_hash])
        end

        it 'caches the query results' do
          expect { result }.not_to raise_error
          expect(provider.instance_variable_get(:@cached_query_results)).to eq([name_hash])
        end
      end

      context 'with a previously failed logon' do
        it 'errors and returns nil if the specified account has already failed to logon' do
          expect(provider).to receive(:logon_failed_already?).and_return(true)
          expect(context).to receive(:err).with('Logon credentials are invalid')
          expect(result).to be_nil
        end
      end
    end
  end

  describe '.invoke_set_method' do
    subject(:result) { provider.invoke_set_method(context, name, should_hash) }

    let(:name) { { name: 'foo', dsc_name: 'foo' } }
    let(:should_hash) { name.merge(dsc_foo: 'bar') }
    let(:apply_props) { { dsc_name: 'foo', dsc_foo: 'bar' } }
    let(:resource) { "Resource: #{apply_props}" }
    let(:script) { "Script: #{apply_props}" }

    before do
      allow(context).to receive(:debug)
      allow(provider).to receive(:invocable_resource).with(apply_props, context, 'set').and_return(resource)
      allow(provider).to receive(:ps_script_content).with(resource).and_return(script)
      allow(provider).to receive(:ps_manager).and_return(ps_manager)
      allow(provider).to receive(:remove_secret_identifiers).with(script).and_return(script)
    end

    context 'when the specified account has already failed to logon' do
      let(:should_hash) { name.merge(dsc_psdscrunascredential: 'bar') }

      it 'returns immediately' do
        expect(provider).to receive(:logon_failed_already?).and_return(true)
        expect(context).to receive(:err).with('Logon credentials are invalid')
        expect(result).to be_nil
      end
    end

    context 'when the invocation script returns nil' do
      it 'errors via context but does not raise' do
        expect(ps_manager).to receive(:execute).and_return({ stdout: nil })
        expect(context).to receive(:err).with('Nothing returned')
        expect { result }.not_to raise_error
      end
    end

    context 'when the invocation script errors' do
      it 'writes the error via context but does not raise and returns nil' do
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": "DSC Error!"}' })
        expect(context).to receive(:err).with('DSC Error!')
        expect(result).to be_nil
      end
    end

    context 'when the invocation script errors with a collision' do
      it 'writes a notice via context and applies successfully on retry' do
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": "The Invoke-DscResource cmdlet is in progress and must return before Invoke-DscResource can be invoked"}' })
        expect(context).to receive(:notice).with(/Invoke-DscResource collision detected: Please stagger the timing of your Puppet runs as this can lead to unexpected behaviour./).once
        expect(context).to receive(:notice).with('Sleeping for 60 seconds.').twice
        expect(context).to receive(:notice).with(/Retrying: attempt [1-2] of 5/).twice
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": "The Invoke-DscResource cmdlet is in progress and must return before Invoke-DscResource can be invoked"}' })
        expect(context).to receive(:notice).with('Attempt 1 of 5 failed.')
        allow(provider).to receive(:sleep)
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": null}' })
        expect { result }.not_to raise_error
      end

      it 'writes a error via context and fails to apply when all retry attempts used' do
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": "The Invoke-DscResource cmdlet is in progress and must return before Invoke-DscResource can be invoked"}' })
                                               .exactly(5).times
        expect(context).to receive(:notice).with(/Invoke-DscResource collision detected: Please stagger the timing of your Puppet runs as this can lead to unexpected behaviour./).once
        expect(context).to receive(:notice).with('Sleeping for 60 seconds.').exactly(5).times
        expect(context).to receive(:notice).with(/Retrying: attempt [1-5] of 5/).exactly(5).times
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": "The Invoke-DscResource cmdlet is in progress and must return before Invoke-DscResource can be invoked"}' })
        expect(context).to receive(:notice).with(/Attempt [1-5] of 5 failed/).exactly(5).times
        expect(context).to receive(:err).with(/The Invoke-DscResource cmdlet is in progress and must return before Invoke-DscResource can be invoked/)
        allow(provider).to receive(:sleep)
        expect(result).to be_nil
      end

      it 'writes an error via context and fails to apply when encountering an unexpected error' do
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": "The Invoke-DscResource cmdlet is in progress and must return before Invoke-DscResource can be invoked"}' })
        expect(context).to receive(:notice).with(/Invoke-DscResource collision detected: Please stagger the timing of your Puppet runs as this can lead to unexpected behaviour./).once
        expect(context).to receive(:notice).with('Sleeping for 60 seconds.').once
        expect(context).to receive(:notice).with(/Retrying: attempt 1 of 5/).once
        allow(provider).to receive(:sleep)
        expect(ps_manager).to receive(:execute).and_return({ stdout: '{"errormessage": "Some unexpected error"}' }).once
        expect(context).to receive(:notice).with(/Attempt 1 of 5 failed/).once
        expect(context).to receive(:err).with(/Some unexpected error/)
        expect(result).to be_nil
      end
    end

    context 'when the invocation script returns data without errors' do
      it 'filters for the correct properties to invoke and returns the results' do
        expect(ps_manager).to receive(:execute).with("Script: #{apply_props}").and_return({ stdout: '{"in_desired_state": true, "errormessage": null}' })
        expect(context).not_to receive(:err)
        expect(result).to eq({ 'in_desired_state' => true, 'errormessage' => nil })
      end
    end
  end

  describe '.puppetize_name' do
    it 'downcases the input string' do
      expect(provider.puppetize_name('FooBar')).to eq('foobar')
    end

    it 'replaces nonstandard characters with underscores' do
      expect(provider.puppetize_name('Foo!Bar?Baz Ope')).to eq('foo_bar_baz_ope')
    end

    it 'prepends "a" if the input string starts with a numeral' do
      expect(provider.puppetize_name('123bc')).to eq('a123bc')
    end
  end

  describe '.invocable_resource' do
    subject(:result) { provider.invocable_resource(should_hash, context, 'Get') }

    let(:definition) do
      {
        name: 'dsc_foo',
        dscmeta_resource_friendly_name: 'Foo',
        dscmeta_resource_name: 'PUPPET_Foo',
        dscmeta_module_name: 'PuppetDsc',
        dscmeta_module_version: '1.2.3.4',
        docs: 'The DSC Foo resource type. Automatically generated from version 1.2.3.4',
        features: %w[simple_get_filter canonicalize],
        attributes: {
          name: {
            type: 'String',
            desc: 'Description of the purpose for this resource declaration.',
            behaviour: :namevar
          },
          dsc_name: {
            type: 'String',
            desc: 'The unique name of the Foo resource to manage',
            behaviour: :namevar,
            mandatory_for_get: true,
            mandatory_for_set: true,
            mof_type: 'String',
            mof_is_embedded: false
          },
          dsc_psdscrunascredential: {
            type: 'Optional[Struct[{ user => String[1], password => Sensitive[String[1]] }]]',
            desc: 'The Credential to run DSC under',
            behaviour: :parameter,
            mandatory_for_get: false,
            mandatory_for_set: false,
            mof_type: 'PSCredential',
            mof_is_embedded: true
          },
          dsc_ensure: {
            type: "Optional[Enum['Present', 'Absent']]",
            desc: 'Whether Foo should be absent from or present on the system',
            mandatory_for_get: false,
            mandatory_for_set: false,
            mof_type: 'String',
            mof_is_embedded: false
          }
        }
      }
    end
    let(:should_hash) { { dsc_name: 'foo' } }
    let(:vendored_modules_path) { 'C:/code/puppetlabs/gems/ruby-pwsh/lib/puppet_x/puppetdsc/dsc_resources' }

    before do
      allow(context).to receive(:debug)
      allow(context).to receive(:type).and_return(type)
      allow(type).to receive(:definition).and_return(definition)
      allow(provider).to receive(:vendored_modules_path).and_return(vendored_modules_path)
    end

    it 'retrieves the metadata from the type definition for the resource' do
      expect(result[:name]).to eq(definition[:name])
      expect(result[:dscmeta_resource_friendly_name]).to eq(definition[:dscmeta_resource_friendly_name])
      expect(result[:dscmeta_resource_name]).to eq(definition[:dscmeta_resource_name])
      expect(result[:dscmeta_module_name]).to eq(definition[:dscmeta_module_name])
      expect(result[:dscmeta_module_version]).to eq(definition[:dscmeta_module_version])
    end

    it 'includes the specified parameter and its value' do
      expect(result[:parameters][:dsc_name][:value]).to eq('foo')
    end

    it 'adds the mof information to a parameter if required' do
      expect(result[:parameters][:dsc_name][:mof_type]).to eq('String')
      expect(result[:parameters][:dsc_name][:mof_is_embedded]).to be false
    end

    context 'handling dsc_psdscrunascredential' do
      context 'when it is not specified in the should hash' do
        it 'is not included in the resource hash' do
          expect(result[:parameters].keys).not_to include(:dsc_psdscrunascredential)
        end
      end

      context 'when it is nil in the should hash' do
        let(:should_hash) { { dsc_name: 'foo', dsc_psdscrunascredential: nil } }

        it 'is not included in the resource hash' do
          expect(result[:parameters].keys).not_to include(:dsc_psdscrunascredential)
        end
      end

      context 'when it is specified fully in the should hash' do
        let(:should_hash) { { dsc_name: 'foo', dsc_psdscrunascredential: { 'user' => 'foo', 'password' => 'bar' } } }

        it 'is added to the parameters of the resource hash' do
          expect(result[:parameters][:dsc_psdscrunascredential][:value]).to eq({ 'user' => 'foo', 'password' => 'bar' })
        end
      end
    end
  end

  describe '.vendored_modules_path' do
    let(:load_path) { [] }
    let(:new_path_nil_root_module) { 'C:/code/puppetlabs/gems/ruby-pwsh/lib/puppet_x/puppetdsc/dsc_resources' }

    before do
      allow(provider).to receive(:load_path).and_return(load_path)
      allow(File).to receive(:exist?).and_call_original
    end

    it 'raises an error when the vendored resources cannot be found' do
      expect { provider.vendored_modules_path('NeverGonnaFindMe') }.to raise_error(/Unable to find expected vendored DSC Resource/)
    end

    context 'when the vendored resources are in puppet_x/<module_name>/dsc_resources' do
      context 'when the root module path can be found' do
        let(:load_path) { ['/Puppet/modules/puppetdsc/lib'] }
        let(:vendored_path) { File.expand_path('/Puppet/modules/puppetdsc/lib/puppet_x/puppetdsc/dsc_resources') }

        it 'returns the constructed path' do
          expect(File).to receive(:exist?).twice.with(vendored_path).and_return(true)
          expect(provider.vendored_modules_path('PuppetDsc')).to eq(vendored_path)
        end
      end

      context 'when the root module path cannot be found' do
        # This is awkward but necessary to get to /path/to/gem/lib/puppet_x/
        let(:vendored_path) { File.expand_path(Pathname.new(__FILE__).dirname + '../../../../../' + 'lib/puppet_x/puppetdsc/dsc_resources') } # rubocop:disable Style/StringConcatenation

        it 'returns the relative path' do
          expect(File).to receive(:exist?).twice.with(vendored_path).and_return(true)
          expect(provider.vendored_modules_path('PuppetDsc')).to eq(vendored_path)
        end
      end
    end

    context 'when the vendored resources are in puppet_x/dsc_resources' do
      context 'when the root module path can be found' do
        let(:load_path) { ['/Puppet/modules/puppetdsc/lib'] }
        let(:namespaced_vendored_path) { File.expand_path('/Puppet/modules/puppetdsc/lib/puppet_x/puppetdsc/dsc_resources') }
        let(:legacy_vendored_path) { File.expand_path('/Puppet/modules/puppetdsc/lib/puppet_x/dsc_resources') }

        it 'returns the constructed path' do
          expect(File).to receive(:exist?).with(namespaced_vendored_path).and_return(false)
          expect(File).to receive(:exist?).with(legacy_vendored_path).and_return(true)
          expect(provider.vendored_modules_path('PuppetDsc')).to eq(legacy_vendored_path)
        end
      end

      context 'when the root module path cannot be found' do
        # This is awkward but necessary to get to /path/to/gem/lib/puppet_x/
        let(:namespaced_vendored_path) { File.expand_path(Pathname.new(__FILE__).dirname + '../../../../../' + 'lib/puppet_x/puppetdsc/dsc_resources') } # rubocop:disable Style/StringConcatenation
        let(:legacy_vendored_path) { File.expand_path(Pathname.new(__FILE__).dirname + '../../../../../' + 'lib/puppet_x/dsc_resources') } # rubocop:disable Style/StringConcatenation

        it 'returns the constructed path' do
          expect(File).to receive(:exist?).with(namespaced_vendored_path).and_return(false)
          expect(File).to receive(:exist?).with(legacy_vendored_path).and_return(true)
          expect(provider.vendored_modules_path('PuppetDsc')).to eq(legacy_vendored_path)
        end
      end
    end
  end

  describe '.load_path' do
    it 'returns the ruby LOAD_PATH global variable' do
      expect(provider.load_path).to eq($LOAD_PATH)
    end
  end

  describe '.invoke_test_method' do
    subject(:result) { provider.invoke_test_method(context, name, should_hash) }

    let(:name) { { name: 'foo', dsc_name: 'bar' } }
    let(:should_hash) { name.merge(dsc_ensure: 'present') }
    let(:test_properties) { should_hash.reject { |k, _v| k == :name } }
    let(:invoke_dsc_resource_data) { nil }

    before do
      allow(context).to receive(:notice)
      allow(context).to receive(:debug)
      allow(provider).to receive(:invoke_dsc_resource).with(context, name, test_properties, 'test').and_return(invoke_dsc_resource_data)
    end

    after do
      provider.instance_variable_set(:@cached_test_results, [])
    end

    context 'when something went wrong calling Invoke-DscResource' do
      it 'falls back on property-by-property state comparison and does not cache anything' do
        expect(context).not_to receive(:err)
        expect(result).to be_nil
        expect(provider.cached_test_results).to eq([])
      end
    end

    context 'when the DSC Resource is in the desired state' do
      let(:invoke_dsc_resource_data) { { 'indesiredstate' => true, 'errormessage' => '' } }

      it 'returns true and caches the result' do
        expect(context).not_to receive(:err)
        expect(result).to be(true)
        expect(provider.cached_test_results).to eq([name.merge(in_desired_state: true)])
      end
    end

    context 'when the DSC Resource is not in the desired state' do
      let(:invoke_dsc_resource_data) { { 'indesiredstate' => false, 'errormessage' => '' } }

      it 'returns false and caches the result' do
        expect(context).not_to receive(:err)
        # Resource is not in the desired state
        expect(result.first).to be(false)
        # Custom out-of-sync message passed
        expect(result.last).to match(/not in the desired state/)
        expect(provider.cached_test_results).to eq([name.merge(in_desired_state: false)])
      end
    end
  end

  describe '.random_variable_name' do
    it 'creates random variables' do
      expect(provider.random_variable_name).not_to be_nil
    end

    it 'includes underscores instead of hyphens' do
      expect(provider.random_variable_name).to match(/_/)
      expect(provider.random_variable_name).not_to match(/-/)
    end
  end

  describe '.instantiated_variables' do
    after do
      provider.instance_variable_set(:@instantiated_variables, [])
    end

    it 'sets the instantiated_variables instance variable to {} if not initialized' do
      expect(provider.instantiated_variables).to eq({})
    end

    it 'returns the instantiated_variables instance variable if already initialized' do
      provider.instance_variable_set(:@instantiated_variables, { foo: 'bar' })
      expect(provider.instantiated_variables).to eq({ foo: 'bar' })
    end
  end

  describe '.clear_instantiated_variables!' do
    after do
      provider.instance_variable_set(:@instantiated_variables, [])
    end

    it 'sets the instantiated_variables instance variable to {}' do
      provider.instance_variable_set(:@instantiated_variables, { foo: 'bar' })
      expect { provider.clear_instantiated_variables! }.not_to raise_error
      expect(provider.instance_variable_get(:@instantiated_variables)).to eq({})
    end
  end

  describe '.logon_failed_already?' do
    let(:good_password) { instance_double(Puppet::Pops::Types::PSensitiveType::Sensitive, 'foo') }
    let(:bad_password) { instance_double(Puppet::Pops::Types::PSensitiveType::Sensitive, 'bar') }
    let(:good_credential_hash) { { 'user' => 'foo', 'password' => good_password } }
    let(:bad_credential_hash) { { 'user' => 'bar', 'password' => bad_password } }

    context 'when the logon_failures cache is empty' do
      it 'returns false' do
        expect(provider.logon_failed_already?(good_credential_hash)).to be(false)
      end
    end

    context 'when the logon_failures cache has entries' do
      before do
        allow(good_password).to receive(:unwrap).and_return('foo')
        allow(bad_password).to receive(:unwrap).and_return('bar')
      end

      after do
        provider.instance_variable_set(:@logon_failures, [])
      end

      it 'returns false if there have been no failed logons with the username/password combination' do
        provider.instance_variable_set(:@logon_failures, [bad_credential_hash])
        expect(provider.logon_failed_already?(good_credential_hash)).to be(false)
      end

      it 'returns true if the username/password specified are found in the logon_failures instance variable' do
        provider.instance_variable_set(:@logon_failures, [good_credential_hash, bad_credential_hash])
        expect(provider.logon_failed_already?(bad_credential_hash)).to be(true)
      end
    end
  end

  describe '.downcase_hash_keys!' do
    let(:test_hash) do
      {
        'SomeKey' => 'value',
        'SomeArray' => [
          { 'ArrayKeyOne' => 1, 'ArrayKeyTwo' => 2 },
          { 'ArrayKeyOne' => '1', 'ArrayKeyTwo' => '2' }
        ],
        'SomeHash' => {
          'NestedKey' => 'foo',
          'NestedArray' => [{ 'NestedArrayKeyOne' => 1, 'NestedArrayKeyTwo' => 2 }],
          'NestedHash' => {
            'DeeplyNestedKey' => 'foo',
            'DeeplyNestedArray' => [{ 'DeeplyNestedArrayKeyOne' => 1, 'DeeplyNestedArrayKeyTwo' => 2 }],
            'DeeplyNestedHash' => {
              'VeryDeeplyNestedKey' => 'foo'
            }
          }
        }
      }
    end

    it 'converts all the keys in a hash into downcase, even if nested in another hash or array' do
      downcased_hash = test_hash.dup
      expect { provider.downcase_hash_keys!(downcased_hash) }.not_to raise_error
      expect(downcased_hash.keys).to eq(%w[somekey somearray somehash])
      expect(downcased_hash['somearray'][0].keys).to eq(%w[arraykeyone arraykeytwo])
      expect(downcased_hash['somearray'][1].keys).to eq(%w[arraykeyone arraykeytwo])
      expect(downcased_hash['somehash'].keys).to eq(%w[nestedkey nestedarray nestedhash])
      expect(downcased_hash['somehash']['nestedarray'].first.keys).to eq(%w[nestedarraykeyone nestedarraykeytwo])
      expect(downcased_hash['somehash']['nestedhash'].keys).to eq(%w[deeplynestedkey deeplynestedarray deeplynestedhash])
      expect(downcased_hash['somehash']['nestedhash']['deeplynestedarray'].first.keys).to eq(%w[deeplynestedarraykeyone deeplynestedarraykeytwo])
      expect(downcased_hash['somehash']['nestedhash']['deeplynestedhash'].keys).to eq(%w[verydeeplynestedkey])
    end
  end

  describe '.munge_cim_instances!' do
    let(:cim_instance) do
      {
        'CertificateSubject' => nil,
        'SslFlags' => '0',
        'CertificateStoreName' => nil,
        'CertificateThumbprint' => nil,
        'HostName' => nil,
        'BindingInformation' => '*:80:',
        'cim_instance_type' => 'MSFT_xWebBindingInformation',
        'Port' => 80,
        'IPAddress' => '*',
        'Protocol' => 'http'
      }
    end
    let(:nested_cim_instance) do
      {
        'AccessControlEntry' => [
          {
            'AccessControlType' => 'Allow',
            'Inheritance' => 'This folder and files',
            'Ensure' => 'Present',
            'cim_instance_type' => 'NTFSAccessControlEntry',
            'FileSystemRights' => ['FullControl']
          }
        ],
        'ForcePrincipal' => true,
        'Principal' => 'Everyone'
      }
    end

    before { provider.munge_cim_instances!(value) }

    context 'when called against a non-nested cim instance' do
      let(:value) { cim_instance.dup }

      it 'removes the cim_instance_type key' do
        expect(value.keys).not_to include('cim_instance_type')
      end

      context 'in an array' do
        let(:value) { [cim_instance.dup] }

        it 'removes the cim_instance_type key' do
          expect(value.first.keys).not_to include('cim_instance_type')
        end
      end
    end

    context 'when called against a nested cim instance' do
      let(:value) { nested_cim_instance.dup }

      it 'does not remove the cim_instance_type key' do
        expect(value['AccessControlEntry'].first.keys).to include('cim_instance_type')
      end

      context 'in an array' do
        let(:value) { [nested_cim_instance.dup] }

        it 'does not remove the cim_instance_type key' do
          expect(value.first['AccessControlEntry'].first.keys).to include('cim_instance_type')
        end
      end
    end

    context 'when called against a value which is not a cim_instance' do
      let(:original) { %w[foo bar baz] }
      let(:value) { original.dup }

      it 'does not change the value' do
        expect(value).to eq(original)
      end
    end
  end

  describe '.recursively_downcase' do
    let(:test_hash) do
      {
        SomeKey: 'Value',
        SomeArray: [
          { ArrayKeyOne: 1, ArrayKeyTwo: 2 },
          { ArrayKeyOne: 'ONE', ArrayKeyTwo: 2 }
        ],
        SomeHash: {
          NestedKey: 'Foo',
          NestedArray: [{ NestedArrayKeyOne: 'ONE', NestedArrayKeyTwo: 2 }],
          NestedHash: {
            DeeplyNestedKey: 'Foo',
            DeeplyNestedArray: [{ DeeplyNestedArrayKeyOne: 'One', DeeplyNestedArrayKeyTwo: 2 }],
            DeeplyNestedHash: {
              VeryDeeplyNestedKey: 'Foo'
            }
          }
        }
      }
    end
    let(:downcased_array) { [{ arraykeyone: 1, arraykeytwo: 2 }, { arraykeyone: 'one', arraykeytwo: 2 }] }
    let(:downcased_hash) do
      {
        nestedkey: 'foo',
        nestedarray: [{ nestedarraykeyone: 'one', nestedarraykeytwo: 2 }],
        nestedhash: {
          deeplynestedkey: 'foo',
          deeplynestedarray: [{ deeplynestedarraykeyone: 'one', deeplynestedarraykeytwo: 2 }],
          deeplynestedhash: {
            verydeeplynestedkey: 'foo'
          }
        }
      }
    end

    it 'downcases any string passed, whether alone or in a hash or array or nested deeply' do
      result = provider.recursively_downcase(test_hash)
      expect(result[:somekey]).to eq('value')
      expect(result[:somearray]).to eq(downcased_array)
      expect(result[:somehash]).to eq(downcased_hash)
    end
  end

  describe '.recursively_sort' do
    let(:test_hash) do
      {
        SomeKey: 'Value',
        SomeArray: [2, 3, 1],
        SomeComplexArray: [2, 3, [2, 1]],
        SomeHash: {
          NestedKey: 'Foo',
          NestedArray: [{ NestedArrayKeyTwo: 2, NestedArrayKeyOne: 'ONE' }, 2, 1],
          NestedHash: {
            DeeplyNestedKey: 'Foo',
            DeeplyNestedArray: [2, 3, 'a', 1, 'c', 'b'],
            DeeplyNestedHash: {
              VeryDeeplyNestedKey2: 'Foo',
              VeryDeeplyNestedKey1: 'Bar'
            }
          }
        }
      }
    end
    let(:sorted_keys) { %i[SomeArray SomeComplexArray SomeHash SomeKey] }
    let(:sorted_some_array) { [1, 2, 3] }
    let(:sorted_complex_array) { [2, 3, [1, 2]] }
    let(:sorted_some_hash_keys) { %i[NestedArray NestedHash NestedKey] }
    let(:sorted_nested_array) { [1, 2, { NestedArrayKeyOne: 'ONE', NestedArrayKeyTwo: 2 }] }
    let(:sorted_nested_hash_keys) { %i[DeeplyNestedArray DeeplyNestedHash DeeplyNestedKey] }
    let(:sorted_deeply_nested_array) { [1, 2, 3, 'a', 'b', 'c'] }
    let(:sorted_deeply_nested_hash_keys) { %i[VeryDeeplyNestedKey1 VeryDeeplyNestedKey2] }

    it 'downcases any string passed, whether alone or in a hash or array or nested deeply' do
      result = provider.recursively_sort(test_hash)
      expect(result.keys).to eq(sorted_keys)
      expect(result[:SomeArray]).to eq(sorted_some_array)
      expect(result[:SomeComplexArray]).to eq(sorted_complex_array)
      expect(result[:SomeHash].keys).to eq(sorted_some_hash_keys)
      expect(result[:SomeHash][:NestedArray]).to eq(sorted_nested_array)
      expect(result[:SomeHash][:NestedHash].keys).to eq(sorted_nested_hash_keys)
      expect(result[:SomeHash][:NestedHash][:DeeplyNestedArray]).to eq(sorted_deeply_nested_array)
      expect(result[:SomeHash][:NestedHash][:DeeplyNestedHash].keys).to eq(sorted_deeply_nested_hash_keys)
    end
  end

  describe '.same?' do
    it 'compares hashes regardless of order' do
      expect(provider.same?({ foo: 1, bar: 2 }, { bar: 2, foo: 1 })).to be true
    end

    it 'compares hashes with nested arrays regardless of order' do
      expect(provider.same?({ foo: [1, 2], bar: { baz: [1, 2] } }, { foo: [2, 1], bar: { baz: [2, 1] } })).to be true
    end

    it 'compares arrays regardless of order' do
      expect(provider.same?([1, 2], [2, 1])).to be true
    end

    it 'compares arrays with nested arrays regardless of order' do
      expect(provider.same?([1, [1, 2]], [[2, 1], 1])).to be true
    end

    it 'compares non enumerables directly' do
      expect(provider.same?(1, 1)).to be true
      expect(provider.same?(1, 2)).to be false
    end
  end

  describe '.mandatory_get_attributes' do
    let(:attributes) do
      {
        name: { type: 'String' },
        dsc_ensure: { mandatory_for_get: true },
        dsc_enum: { mandatory_for_get: false },
        dsc_string: { mandatory_for_get: true }
      }
    end

    it 'returns the list of attributes from the type where the mandatory_for_get meta property is true' do
      expect(context).to receive(:type).and_return(type)
      expect(type).to receive(:attributes).and_return(attributes)
      expect(provider.mandatory_get_attributes(context)).to eq(%i[dsc_ensure dsc_string])
    end
  end

  describe '.mandatory_set_attributes' do
    let(:attributes) do
      {
        name: { type: 'String' },
        dsc_ensure: { mandatory_for_set: true },
        dsc_enum: { mandatory_for_set: false },
        dsc_string: { mandatory_for_set: true }
      }
    end

    it 'returns the list of attributes from the type where the mandatory_for_set meta property is true' do
      expect(context).to receive(:type).and_return(type)
      expect(type).to receive(:attributes).and_return(attributes)
      expect(provider.mandatory_set_attributes(context)).to eq(%i[dsc_ensure dsc_string])
    end
  end

  describe '.namevar_attributes' do
    let(:attributes) do
      {
        name: { type: 'String', behaviour: :namevar },
        dsc_name: { type: 'String', behaviour: :namevar },
        dsc_ensure: { type: "[Enum['Present', 'Absent']]" },
        dsc_enum: { type: "Optional[Enum['Trusted', 'Untrusted']]" },
        dsc_string: { type: 'Optional[String]' }
      }
    end

    it 'returns the list of attributes from the type where the attribute has the namevar behavior' do
      expect(context).to receive(:type).and_return(type)
      expect(type).to receive(:attributes).and_return(attributes)
      expect(provider.namevar_attributes(context)).to eq(%i[name dsc_name])
    end
  end

  describe '.parameter_attributes' do
    let(:attributes) do
      {
        name: { type: 'String', behaviour: :namevar },
        dsc_name: { type: 'String', behaviour: :namevar },
        dsc_ensure: { type: "[Enum['Present', 'Absent']]" },
        dsc_enum: { type: "Optional[Enum['Trusted', 'Untrusted']]", behaviour: :parameter },
        dsc_string: { type: 'Optional[String]', behaviour: :parameter }
      }
    end

    it 'returns the list of attributes from the type where the attribute has the parameter behavior' do
      expect(context).to receive(:type).and_return(type)
      expect(type).to receive(:attributes).and_return(attributes)
      expect(provider.parameter_attributes(context)).to eq(%i[dsc_enum dsc_string])
    end
  end

  describe '.enum_attributes' do
    let(:enum_test_attributes) do
      {
        name: { type: 'String' },
        dsc_ensure: { type: "[Enum['Present', 'Absent']]" },
        dsc_enum: { type: "Optional[Enum['Trusted', 'Untrusted']]" },
        dsc_string: { type: 'Optional[String]' }
      }
    end

    it 'returns the list of attributes from the type where the attribute data type is an enum' do
      expect(context).to receive(:type).and_return(type)
      expect(type).to receive(:attributes).and_return(enum_test_attributes)
      expect(provider.enum_attributes(context)).to eq(%i[dsc_ensure dsc_enum])
    end
  end

  describe '.interpolate_variables' do
    let(:instantiated_variables) do
      {
        some_variable_name: 'FooBar',
        another_variable_name: 'Get-Foo',
        third_variable_name: 'Get-Foo "bar"'
      }
    end

    before do
      allow(provider).to receive(:instantiated_variables).and_return(instantiated_variables)
    end

    it 'replaces all discovered pointers to a variable with the variable' do
      expect(provider.interpolate_variables("'FooBar' ; 'FooBar'")).to eq('$some_variable_name ; $some_variable_name')
    end

    it 'replaces discovered pointers in reverse order they were stored' do
      expect(provider.interpolate_variables("'Get-Foo \"bar\"'")).to eq('$third_variable_name')
    end
  end

  describe '.munge_psmodulepath' do
    subject(:result) { provider.munge_psmodulepath(test_resource) }

    context 'when the resource does not have the dscmeta_resource_implementation key' do
      let(:test_resource) { {} }

      it 'sets $UnmungedPSModulePath to the current PSModulePath' do
        # since https://github.com/puppetlabs/ruby-pwsh/pull/261 we load vendored path for MOF resources as well
        expect(result).to match(/\$UnmungedPSModulePath = .+GetEnvironmentVariable.+PSModulePath.+machine/)
      end
    end

    context "when the resource's dscmeta_resource_implementation is not 'Class'" do
      let(:test_resource) { { dscmeta_resource_implementation: 'MOF' } }

      # since https://github.com/puppetlabs/ruby-pwsh/pull/261 we load vendored path for MOF resources as well
      it 'sets $UnmungedPSModulePath to the current PSModulePath' do
        expect(result).to match(/\$UnmungedPSModulePath = .+GetEnvironmentVariable.+PSModulePath.+machine/)
      end
    end

    context "when the resource's dscmeta_resource_implementation is 'Class'" do
      let(:test_resource) { { dscmeta_resource_implementation: 'Class', vendored_modules_path: 'C:/foo/bar' } }

      it 'sets $UnmungedPSModulePath to the current PSModulePath' do
        expect(result).to match(/\$UnmungedPSModulePath = .+GetEnvironmentVariable.+PSModulePath.+machine/)
      end

      it 'sets $MungedPSModulePath the vendor path with backslash separators' do
        expect(result).to match(/\$MungedPSModulePath = .+;C:\\foo\\bar/)
      end

      it 'updates the system PSModulePath to $MungedPSModulePath' do
        expect(result).to match(/SetEnvironmentVariable\('PSModulePath', \$MungedPSModulePath/)
      end

      it 'sets the process level PSModulePath to the modified system PSModulePath' do
        expect(result).to match(/\$env:PSModulePath = .+GetEnvironmentVariable.+PSModulePath.+machine/)
      end
    end
  end

  describe '.prepare_credentials' do
    subject(:result) { provider.prepare_credentials(test_resource) }

    let(:base_resource) do
      {
        parameters: {
          dsc_name: { value: 'foo', mof_type: 'String', mof_is_embedded: false }
        }
      }
    end

    context 'when no PSCredentials are passed as parameters' do
      let(:test_resource) { base_resource.dup }

      it 'returns an empty string' do
        expect(result).to eq('')
      end
    end

    context 'when one or more PSCredentials are passed as parameters' do
      let(:foo_password) { instance_double(Puppet::Pops::Types::PSensitiveType::Sensitive, 'foo') }
      let(:bar_password) { instance_double(Puppet::Pops::Types::PSensitiveType::Sensitive, 'bar') }
      let(:additional_parameters) do
        {
          parameters: {
            dsc_psdscrunascredential: { value: nil, mof_type: 'PSCredential' },
            dsc_somecredential: { value: { 'user' => 'foo', 'password' => foo_password }, mof_type: 'PSCredential' },
            dsc_othercredential: { value: { 'user' => 'bar', 'password' => bar_password }, mof_type: 'PSCredential' }
          }
        }
      end
      let(:test_resource) { base_resource.merge(additional_parameters) }

      before do
        allow(foo_password).to receive(:unwrap).and_return('foo')
        allow(bar_password).to receive(:unwrap).and_return('bar')
      end

      after do
        provider.instance_variable_set(:@instantiated_variables, [])
      end

      it 'writes the ruby representation of the credentials as the value of a key named for the new variable into the instantiated_variables cache' do
        expect(result.count).to eq(2) # dsc_psdscrunascredential should not get an entry as it is nil
        instantiated_variables = provider.instantiated_variables
        first_variable_name, first_credential_hash = instantiated_variables.first
        instantiated_variables.delete(first_variable_name)
        _variable_name, second_credential_hash = instantiated_variables.first
        expect(first_credential_hash).to eq({ 'user' => 'foo', 'password' => 'foo' })
        expect(second_credential_hash).to eq({ 'user' => 'bar', 'password' => 'bar' })
      end

      it 'returns an array of strings each containing the instantiation of a PowerShell variable representing the credential hash' do
        expect(result[0]).to match(/^\$\w+ = New-PSCredential -User foo -Password 'foo#PuppetSensitive'/)
        expect(result[1]).to match(/^\$\w+ = New-PSCredential -User bar -Password 'bar#PuppetSensitive'/)
      end
    end
  end

  describe '.format_pscredential' do
    let(:credential_hash) { { 'user' => 'foo', 'password' => 'bar' } }

    it 'returns a string representing the instantiation of a PowerShell variable representing the credential hash' do
      expected_powershell_code = "$foo = New-PSCredential -User foo -Password 'bar#PuppetSensitive'"
      expect(provider.format_pscredential('foo', credential_hash)).to eq(expected_powershell_code)
    end
  end

  describe '.prepare_cim_instances' do
    subject(:result) { provider.prepare_cim_instances(test_resource) }

    after do
      provider.instance_variable_set(:@instantiated_variables, [])
    end

    context 'when a cim instance is passed without nested cim instances' do
      let(:test_resource) do
        {
          parameters: {
            dsc_someciminstance: {
              value: { 'foo' => 1, 'bar' => 'two' },
              mof_type: 'SomeCimType',
              mof_is_embedded: true
            },
            dsc_name: { value: 'foo', mof_type: 'String', mof_is_embedded: false }
          }
        }
      end

      before do
        allow(provider).to receive(:nested_cim_instances).with(test_resource[:parameters][:dsc_someciminstance][:value]).and_return([nil, nil])
        allow(provider).to receive(:random_variable_name).and_return('cim_foo')
      end

      it 'processes only for properties which have an embedded mof' do
        expect(provider).not_to receive(:nested_cim_instances).with(test_resource[:parameters][:dsc_name][:value])
        expect { result }.not_to raise_error
      end

      it 'instantiates a variable for the cim instance' do
        expect(result).to eq("$cim_foo = New-CimInstance -ClientOnly -ClassName 'SomeCimType' -Property @{'foo' = 1; 'bar' = 'two'}")
      end
    end

    context 'when a cim instance is passed with nested cim instances' do
      let(:test_resource) do
        {
          parameters: {
            dsc_accesscontrollist: {
              value: [{
                'accesscontrolentry' => [{
                  'accesscontroltype' => 'Allow',
                  'ensure' => 'Present',
                  'cim_instance_type' => 'NTFSAccessControlEntry'
                }],
                'principal' => 'veryRealUserName'
              }],
              mof_type: 'NTFSAccessControlList[]',
              mof_is_embedded: true
            }
          }
        }
      end
      let(:nested_cim_instances) do
        [[[{ 'accesscontroltype' => 'Allow', 'ensure' => 'Present', 'cim_instance_type' => 'NTFSAccessControlEntry' }], nil]]
      end

      before do
        allow(provider).to receive(:nested_cim_instances).with(test_resource[:parameters][:dsc_accesscontrollist][:value]).and_return(nested_cim_instances)
        allow(provider).to receive(:random_variable_name).and_return('cim_foo', 'cim_bar')
      end

      it 'processes nested cim instances first' do
        cim_instance_declarations = result.split("\n")
        expect(cim_instance_declarations.first).to match(/\$cim_foo =/)
        expect(cim_instance_declarations.first).to match(/ClassName 'NTFSAccessControlEntry'/)
      end

      it 'references nested cim instances as variables in the parent cim instance' do
        cim_instance_declarations = result.split("\n")
        expect(cim_instance_declarations[1]).to match(/\$cim_bar =.+Property @{'accesscontrolentry' = \[CimInstance\[\]\]@\(\$cim_foo\); 'principal' = 'veryRealUserName'}/)
      end
    end

    context 'when there are no cim instances' do
      let(:test_resource) do
        {
          parameters: {
            dsc_name: { value: 'foo', mof_type: 'String', mof_is_embedded: false }
          }
        }
      end

      it 'returns an empty string' do
        expect(result).to eq('')
      end
    end
  end

  describe '.nested_cim_instances' do
    subject(:nested_cim_instances) { provider.nested_cim_instances(enumerable).flatten }

    let(:enumerable) do
      [{
        'accesscontrolentry' => [{
          'accesscontroltype' => 'Allow',
          'ensure' => 'Present',
          'cim_instance_type' => 'NTFSAccessControlEntry'
        }],
        'principal' => 'veryRealUserName'
      }]
    end

    it 'returns an array with only nested cim instances as non-nil' do
      expect(nested_cim_instances.first).to eq(enumerable.first['accesscontrolentry'].first)
      expect(nested_cim_instances[1]).to be_nil
    end
  end

  describe '.format_ciminstance' do
    after do
      provider.instance_variable_set(:@instantiated_variables, [])
    end

    it 'defines and returns a new cim instance as a PowerShell variable, passing the class name and property hash' do
      property_hash = { 'foo' => 1, 'bar' => 'two' }
      expected_command = "$foo = New-CimInstance -ClientOnly -ClassName 'SomeClass' -Property @{'foo' = 1; 'bar' = 'two'}"
      expect(provider.format_ciminstance('foo', 'SomeClass', property_hash)).to eq(expected_command)
    end

    it 'handles arrays of cim instances' do
      property_hash = [{ 'foo' => 1, 'bar' => 'two' }, { 'foo' => 3, 'bar' => 'four' }]
      expected_cim_instance_array_regex = /Property \[CimInstance\[\]\]@\(@\{'foo' = 1; 'bar' = 'two'}, @\{'foo' = 3; 'bar' = 'four'\}\)/
      expect(provider.format_ciminstance('foo', 'SomeClass', property_hash)).to match(expected_cim_instance_array_regex)
    end

    it 'interpolates variables in the case of a cim instance containing a nested instance' do
      provider.instance_variable_set(:@instantiated_variables, { 'SomeVariable' => { 'bar' => 'ope' } })
      property_hash = { 'foo' => { 'bar' => 'ope' } }
      expect(provider.format_ciminstance('foo', 'SomeClass', property_hash)).to match(/@\{'foo' = \$SomeVariable\}/)
    end
  end

  describe '.invoke_params' do
    subject(:result) { provider.invoke_params(test_resource) }

    let(:test_parameter) { { dsc_name: { value: 'foo', mof_type: 'String', mof_is_embedded: false } } }
    let(:test_resource) do
      {
        parameters: test_parameter,
        name: 'dsc_foo',
        dscmeta_resource_friendly_name: 'Foo',
        dscmeta_resource_name: 'PUPPET_Foo',
        dscmeta_module_name: 'PuppetDsc',
        dsc_invoke_method: 'Get',
        vendored_modules_path: 'C:/code/puppetlabs/gems/ruby-pwsh/lib/puppet_x/puppetdsc/dsc_resources',
        attributes: nil
      }
    end

    it 'includes the DSC Resource name in the output hash' do
      expect(result).to match(/Name = 'Foo'/)
    end

    it 'includes the specified method in the output hash' do
      expect(result).to match(/Method = 'Get'/)
    end

    it 'includes the properties as a hashtable to pass the DSC Resource in the output hash' do
      expect(result).to match(/Property = @\{name = 'foo'\}/)
    end

    context 'when handling module versioning' do
      context 'when the dscmeta_module_version is not specified' do
        it 'includes the ModuleName in the output hash as a string' do
          expect(result).to match(/ModuleName = 'PuppetDsc'/)
        end
      end

      context 'when the dscmeta_module_version is specified' do
        let(:test_resource) do
          {
            parameters: test_parameter,
            dscmeta_resource_friendly_name: 'Foo',
            dscmeta_module_name: 'PuppetDsc',
            dscmeta_module_version: '1.2.3.4',
            dsc_invoke_method: 'Get',
            vendored_modules_path: 'C:/path/to/ruby-pwsh/lib/puppet_x/puppetdsc/dsc_resources'
          }
        end
        let(:expected_module_name) do
          "ModuleName = @{ModuleName = 'C:/path/to/ruby-pwsh/lib/puppet_x/puppetdsc/dsc_resources/PuppetDsc/PuppetDsc.psd1'; RequiredVersion = '1.2.3.4'}"
        end

        it 'includes the ModuleName in the output hash as a hashtable of name and version' do
          expect(result).to match(/#{expected_module_name}/)
        end
      end
    end

    context 'parameter handling' do
      context 'PSCredential' do
        let(:password) { instance_double(Puppet::Pops::Types::PSensitiveType::Sensitive, 'FooPassword') }
        let(:test_parameter) do
          { dsc_credential: { value: { 'user' => 'foo', 'password' => password }, mof_type: 'PSCredential', mof_is_embedded: false } }
        end
        let(:formatted_param_hash) do
          "$InvokeParams = @{Name = 'Foo'; Method = 'Get'; Property = @{credential = @{'user' = 'foo'; 'password' = 'FooPassword'}}; ModuleName = 'PuppetDsc'}"
        end
        let(:variable_interpolated_param_hash) do
          "$InvokeParams = @{Name = 'Foo'; Method = 'Get'; Property = @{credential = $SomeCredential}; ModuleName = 'PuppetDsc'}"
        end

        it 'unwraps the credential hash and interpolates the appropriate variable' do
          expect(password).to receive(:unwrap).and_return('FooPassword')
          expect(provider).to receive(:interpolate_variables).with(formatted_param_hash).and_return(variable_interpolated_param_hash)
          expect(result).to eq(variable_interpolated_param_hash)
        end
      end

      context 'DateTime' do
        let(:date_time) { instance_double(Puppet::Pops::Time::Timestamp, '2100-01-01') }
        let(:test_parameter) do
          { dsc_datetime: { value: date_time, mof_type: 'DateTime', mof_is_embedded: false } }
        end

        it 'casts the formatted timestamp string to DateTime in the property hash' do
          expect(date_time).to receive(:format).and_return('2100-01-01')
          expect(result).to match(/datetime = \[DateTime\]'2100-01-01'/)
        end
      end

      context 'Empty Array' do
        let(:test_parameter) do
          { dsc_emptyarray: { value: [], mof_type: 'String[]', mof_is_embedded: false } }
        end

        it 'casts the empty aray to the mof type in the property hash' do
          expect(result).to match(/emptyarray = \[String\[\]\]@\(\)/)
        end
      end

      context 'Nested CIM Instances' do
        let(:test_parameter) do
          { dsc_ciminstance: { value: { 'something' => 1, 'another' => 'two' }, mof_type: 'NestedCimInstance[]', mof_is_embedded: true } }
        end

        it 'casts the Cim Instance value as [CimInstance[]]in the property hash' do
          expect(result).to match(/ciminstance = \[CimInstance\[\]\]@\{'something' = 1; 'another' = 'two'\}/)
        end
      end
    end
  end

  describe '.ps_script_content' do
    let(:gem_root) { File.expand_path('../../../../..', __dir__) }
    let(:template_path) { "#{gem_root}/lib/puppet/provider/dsc_base_provider" }
    let(:functions_file_handle) { instance_double(File, 'functions_file') }
    let(:preamble_file_handle) { instance_double(File, 'preamble_file') }
    let(:postscript_file_handle) { instance_double(File, 'postscript_file') }
    let(:expected_script_content) do
      "Functions Block\nPreamble Block\n\n\n\nParameters Block\nPostscript Block"
    end

    before do
      allow(File).to receive(:new).with("#{template_path}/invoke_dsc_resource_functions.ps1").and_return(functions_file_handle)
      allow(functions_file_handle).to receive(:read).and_return('Functions Block')
      allow(File).to receive(:new).with("#{template_path}/invoke_dsc_resource_preamble.ps1").and_return(preamble_file_handle)
      allow(preamble_file_handle).to receive(:read).and_return('Preamble Block')
      allow(File).to receive(:new).with("#{template_path}/invoke_dsc_resource_postscript.ps1").and_return(postscript_file_handle)
      allow(postscript_file_handle).to receive(:read).and_return('Postscript Block')
      allow(provider).to receive(:munge_psmodulepath).and_return('')
      allow(provider).to receive(:munge_psmodulepath).with('ClassBasedResource').and_return('PSModulePath Block')
      allow(provider).to receive(:prepare_credentials).and_return('')
      allow(provider).to receive(:prepare_credentials).with('ResourceWithCredentials').and_return('Credential Block')
      allow(provider).to receive(:prepare_cim_instances).and_return('')
      allow(provider).to receive(:prepare_cim_instances).with('ResourceWithCimInstances').and_return('Cim Instance Block')
      allow(provider).to receive(:invoke_params).and_return('Parameters Block')
    end

    it 'returns a powershell script with the helper functions' do
      expect(provider.ps_script_content('Basic')).to match("Functions Block\n")
    end

    it 'includes the preamble' do
      expect(provider.ps_script_content('Basic')).to match("Preamble Block\n")
    end

    it 'includes the module path block, if needed' do
      expect(provider.ps_script_content('Basic')).not_to match("PSModulePath Block\n")
      expect(provider.ps_script_content('ClassBasedResource')).to match("PSModulePath Block\n")
    end

    it 'includes the credential block, if needed' do
      expect(provider.ps_script_content('Basic')).not_to match("Credential Block\n")
      expect(provider.ps_script_content('ResourceWithCredentials')).to match("Credential Block\n")
    end

    it 'includes the cim instances block, if needed' do
      expect(provider.ps_script_content('Basic')).not_to match("Cim Instance Block\n")
      expect(provider.ps_script_content('ResourceWithCimInstances')).to match("Cim Instance Block\n")
    end

    it 'includes the parameters block' do
      expect(provider.ps_script_content('Basic')).to match("Parameters Block\n")
    end

    it 'includes the postscript block' do
      expect(provider.ps_script_content('Basic')).to match('Postscript Block')
    end

    it 'returns a single string with all the blocks joined' do
      expect(provider.ps_script_content('Basic')).to eq(expected_script_content)
    end
  end

  describe '.format' do
    let(:sensitive_string) { Puppet::Pops::Types::PSensitiveType::Sensitive.new('foo') }

    it 'uses Pwsh::Util to format the values' do
      expect(Pwsh::Util).to receive(:format_powershell_value).with('foo').and_return('bar')
      expect(provider.format('foo')).to eq('bar')
    end

    it 'handles sensitive values especially' do
      expect(Pwsh::Util).to receive(:format_powershell_value).with(sensitive_string).and_raise(RuntimeError, 'Could not format Sensitive [value redacted]')
      expect(provider).to receive(:unwrap).with(sensitive_string).and_return('foo#PuppetSensitive')
      expect(Pwsh::Util).to receive(:format_powershell_value).with('foo#PuppetSensitive').and_return("'foo#PuppetSensitive'")
      expect(provider.format(sensitive_string)).to eq("'foo#PuppetSensitive'")
    end

    it 'raises an error if Pwsh::Util raises any error not related to unwrapping a sensitive string' do
      expect(Pwsh::Util).to receive(:format_powershell_value).with('foo').and_raise(RuntimeError, 'Ope!')
      expect { provider.format('foo') }.to raise_error(RuntimeError, 'Ope!')
    end
  end

  describe '.unwrap' do
    let(:sensitive_string) { Puppet::Pops::Types::PSensitiveType::Sensitive.new('foo') }
    let(:unwrapped_string) { 'foo#PuppetSensitive' }

    it 'unwraps a sensitive string, appending "#PuppetSensitive" to the end' do
      expect(provider.unwrap(sensitive_string)).to eq(unwrapped_string)
    end

    it 'handles sensitive values in a hash' do
      expect(provider.unwrap({ key: sensitive_string })).to eq({ key: unwrapped_string })
    end

    it 'handles sensitive values in an array' do
      expect(provider.unwrap([1, sensitive_string])).to eq([1, unwrapped_string])
    end

    it 'handles sensitive values in a deeply nested structure' do
      sensitive_structure = {
        array: [sensitive_string, 'ope'],
        hash: {
          nested_value: sensitive_string,
          nested_array: [sensitive_string, 'bar'],
          nested_hash: {
            deeply_nested_value: sensitive_string
          }
        }
      }

      result = provider.unwrap(sensitive_structure)

      expect(result[:array]).to eq([unwrapped_string, 'ope'])
      expect(result[:hash][:nested_value]).to eq(unwrapped_string)
      expect(result[:hash][:nested_array]).to eq([unwrapped_string, 'bar'])
      expect(result[:hash][:nested_hash][:deeply_nested_value]).to eq(unwrapped_string)
    end

    it 'returns the input if it does not include any sensitive strings' do
      expect(provider.unwrap('foo bar baz')).to eq('foo bar baz')
    end
  end

  describe '.escape_quotes' do
    let(:no_quotes) { 'foo bar baz' }
    let(:single_quotes) { "foo 'bar' baz" }
    let(:double_quotes) { 'foo "bar" baz' }
    let(:mixed_quotes) { "'foo' \"bar\" '\"baz\"'" }

    it 'returns the original string if no single quotes are passed' do
      expect(provider.escape_quotes(no_quotes)).to eq(no_quotes)
      expect(provider.escape_quotes(double_quotes)).to eq(double_quotes)
    end

    it "replaces single ' with '' in a given string" do
      expect(provider.escape_quotes(single_quotes)).to eq("foo ''bar'' baz")
      expect(provider.escape_quotes(mixed_quotes)).to eq("''foo'' \"bar\" ''\"baz\"''")
    end
  end

  describe '.redact_secrets' do
    let(:unsensitive_string) { 'some very unsecret text' }
    let(:sensitive_string) { "$foo = New-PSCredential -User foo -Password 'foo#PuppetSensitive'" }
    let(:redacted_string) { "$foo = New-PSCredential -User foo -Password '#<Sensitive [value redacted]>'" }
    let(:sensitive_array) { "@('a', 'b#PuppetSensitive', 'c')" }
    let(:redacted_array) { "@('a', '#<Sensitive [value redacted]>', 'c')" }
    let(:sensitive_hash) { "@{a = 'foo'; b = 'bar#PuppetSensitive'; c = 1}" }
    let(:redacted_hash) { "@{a = 'foo'; b = '#<Sensitive [value redacted]>'; c = 1}" }
    let(:sensitive_complex) { "@{a = 'foo'; b = 'bar#PuppetSensitive'; c = @('a', 'b#PuppetSensitive', 'c')}" }
    let(:redacted_complex) { "@{a = 'foo'; b = '#<Sensitive [value redacted]>'; c = @('a', '#<Sensitive [value redacted]>', 'c')}" }
    let(:multiline_sensitive_string) do
      <<~SENSITIVE.strip
        $foo = New-PSCredential -User foo -Password 'foo#PuppetSensitive'
        $bar = New-PSCredential -User bar -Password 'bar#PuppetSensitive'
      SENSITIVE
    end
    let(:multiline_redacted_string) do
      <<~REDACTED.strip
        $foo = New-PSCredential -User foo -Password '#<Sensitive [value redacted]>'
        $bar = New-PSCredential -User bar -Password '#<Sensitive [value redacted]>'
      REDACTED
    end
    let(:multiline_sensitive_complex) do
      <<~SENSITIVE.strip
        @{
          a = 'foo'
          b = 'bar#PuppetSensitive'
          c = @('a', 'b#PuppetSensitive', 'c', 'd#PuppetSensitive')
          d = @{
            a = 'foo#PuppetSensitive'
            b = @('a', 'b#PuppetSensitive')
            c = @('a', @{ x = 'y#PuppetSensitive' })
          }
        }
      SENSITIVE
    end
    let(:multiline_redacted_complex) do
      <<~REDACTED.strip
        @{
          a = 'foo'
          b = '#<Sensitive [value redacted]>'
          c = @('a', '#<Sensitive [value redacted]>', 'c', '#<Sensitive [value redacted]>')
          d = @{
            a = '#<Sensitive [value redacted]>'
            b = @('a', '#<Sensitive [value redacted]>')
            c = @('a', @{ x = '#<Sensitive [value redacted]>' })
          }
        }
      REDACTED
    end

    it 'does not modify a string without any secrets' do
      expect(provider.redact_secrets(unsensitive_string)).to eq(unsensitive_string)
    end

    it 'replaces any unwrapped secret with "#<Sensitive [Value redacted]>"' do
      expect(provider.redact_secrets(sensitive_string)).to eq(redacted_string)
      expect(provider.redact_secrets(sensitive_array)).to eq(redacted_array)
      expect(provider.redact_secrets(sensitive_hash)).to eq(redacted_hash)
      expect(provider.redact_secrets(sensitive_complex)).to eq(redacted_complex)
    end

    it 'replaces unwrapped secrets in a multiline string' do
      expect(provider.redact_secrets(multiline_sensitive_string)).to eq(multiline_redacted_string)
      expect(provider.redact_secrets(multiline_sensitive_complex)).to eq(multiline_redacted_complex)
    end
  end

  describe '.remove_secret_identifiers' do
    let(:unsensitive_string) { 'some very unsecret text' }
    let(:sensitive_string) { "$foo = New-PSCredential -User foo -Password 'foo#PuppetSensitive'" }
    let(:redacted_string) { "$foo = New-PSCredential -User foo -Password 'foo'" }
    let(:sensitive_array) { "@('a', 'b#PuppetSensitive', 'c')" }
    let(:redacted_array) { "@('a', 'b', 'c')" }
    let(:sensitive_hash) { "@{a = 'foo'; b = 'bar#PuppetSensitive'; c = 1}" }
    let(:redacted_hash) { "@{a = 'foo'; b = 'bar'; c = 1}" }
    let(:sensitive_complex) { "@{a = 'foo'; b = 'bar#PuppetSensitive'; c = @('a', 'b#PuppetSensitive', 'c')}" }
    let(:redacted_complex) { "@{a = 'foo'; b = 'bar'; c = @('a', 'b', 'c')}" }
    let(:multiline_sensitive_string) do
      <<~SENSITIVE.strip
        $foo = New-PSCredential -User foo -Password 'foo#PuppetSensitive'
        $bar = New-PSCredential -User bar -Password 'bar#PuppetSensitive'
      SENSITIVE
    end
    let(:multiline_redacted_string) do
      <<~REDACTED.strip
        $foo = New-PSCredential -User foo -Password 'foo'
        $bar = New-PSCredential -User bar -Password 'bar'
      REDACTED
    end
    let(:multiline_sensitive_complex) do
      <<~SENSITIVE.strip
        @{
          a = 'foo'
          b = 'bar#PuppetSensitive'
          c = @('a', 'b#PuppetSensitive', 'c', 'd#PuppetSensitive')
          d = @{
            a = 'foo#PuppetSensitive'
            b = @('a', 'b#PuppetSensitive')
            c = @('a', @{ x = 'y#PuppetSensitive' })
          }
        }
      SENSITIVE
    end
    let(:multiline_redacted_complex) do
      <<~REDACTED.strip
        @{
          a = 'foo'
          b = 'bar'
          c = @('a', 'b', 'c', 'd')
          d = @{
            a = 'foo'
            b = @('a', 'b')
            c = @('a', @{ x = 'y' })
          }
        }
      REDACTED
    end

    it 'does not modify a string without any secrets' do
      expect(provider.remove_secret_identifiers(unsensitive_string)).to eq(unsensitive_string)
    end

    it 'removes the secret identifier from any unwrapped secret' do
      expect(provider.remove_secret_identifiers(sensitive_string)).to eq(redacted_string)
      expect(provider.remove_secret_identifiers(sensitive_array)).to eq(redacted_array)
      expect(provider.remove_secret_identifiers(sensitive_hash)).to eq(redacted_hash)
      expect(provider.remove_secret_identifiers(sensitive_complex)).to eq(redacted_complex)
    end

    it 'removes the secret identifier from any unwrapped secrets in a multiline string' do
      expect(provider.remove_secret_identifiers(multiline_sensitive_string)).to eq(multiline_redacted_string)
      expect(provider.remove_secret_identifiers(multiline_sensitive_complex)).to eq(multiline_redacted_complex)
    end
  end

  describe '.ps_manager' do
    describe '.ps_manager on non-Windows' do
      before do
        allow(Pwsh::Util).to receive(:on_windows?).and_return(false)
        allow(Pwsh::Manager).to receive(:pwsh_path).and_return('pwsh')
        allow(Pwsh::Manager).to receive(:pwsh_args).and_return('args')
      end

      it 'Initializes an instance of the Pwsh::Manager' do
        expect(Puppet::Util::Log).to receive(:level).and_return(:normal)
        expect(Pwsh::Manager).to receive(:instance).with('pwsh', 'args', debug: false)
        expect { provider.ps_manager }.not_to raise_error
      end

      it 'passes debug as true if Puppet::Util::Log.level is debug' do
        expect(Puppet::Util::Log).to receive(:level).and_return(:debug)
        expect(Pwsh::Manager).to receive(:instance).with('pwsh', 'args', debug: true)
        expect { provider.ps_manager }.not_to raise_error
      end
    end

    describe '.ps_manager on Windows' do
      before do
        allow(Pwsh::Util).to receive(:on_windows?).and_return(true)
        allow(Pwsh::Manager).to receive(:powershell_path).and_return('pwsh')
        allow(Pwsh::Manager).to receive(:powershell_args).and_return('args')
      end

      it 'Initializes an instance of the Pwsh::Manager' do
        expect(Puppet::Util::Log).to receive(:level).and_return(:normal)
        expect(Pwsh::Manager).to receive(:instance).with('pwsh', 'args', debug: false)
        expect { provider.ps_manager }.not_to raise_error
      end

      it 'passes debug as true if Puppet::Util::Log.level is debug' do
        expect(Puppet::Util::Log).to receive(:level).and_return(:debug)
        expect(Pwsh::Manager).to receive(:instance).with('pwsh', 'args', debug: true)
        expect { provider.ps_manager }.not_to raise_error
      end
    end
  end
end
