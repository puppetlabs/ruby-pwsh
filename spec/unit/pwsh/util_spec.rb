# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Pwsh::Util do
  describe '.invalid_directories?' do
    let(:valid_path_a)  { 'C:/some/folder' }
    let(:valid_path_b)  { 'C:/another/folder' }
    let(:valid_paths)   { 'C:/some/folder;C:/another/folder' }
    let(:invalid_path)  { 'C:/invalid/path' }
    let(:mixed_paths)   { 'C:/some/folder;C:/invalid/path;C:/another/folder' }
    let(:empty_string)  { '' }
    let(:empty_members) { 'C:/some/folder;;C:/another/folder' }

    it 'returns false if passed nil' do
      expect(described_class.invalid_directories?(nil)).to be false
    end

    it 'returns false if passed an empty string' do
      expect(described_class.invalid_directories?('')).to be false
    end

    it 'returns false if one valid path is provided' do
      expect(described_class).to receive(:on_windows?).and_return(true)
      expect(File).to receive(:directory?).with(valid_path_a).and_return(true)
      expect(described_class.invalid_directories?(valid_path_a)).to be false
    end

    it 'returns false if a collection of valid paths is provided' do
      expect(described_class).to receive(:on_windows?).and_return(true)
      expect(File).to receive(:directory?).with(valid_path_a).and_return(true)
      expect(File).to receive(:directory?).with(valid_path_b).and_return(true)
      expect(described_class.invalid_directories?(valid_paths)).to be false
    end

    it 'returns true if there is only one path and it is invalid' do
      expect(described_class).to receive(:on_windows?).and_return(true)
      expect(File).to receive(:directory?).with(invalid_path).and_return(false)
      expect(described_class.invalid_directories?(invalid_path)).to be true
    end

    it 'returns true if the collection has on valid and one invalid member' do
      expect(described_class).to receive(:on_windows?).and_return(true)
      expect(File).to receive(:directory?).with(valid_path_a).and_return(true)
      expect(File).to receive(:directory?).with(valid_path_b).and_return(true)
      expect(File).to receive(:directory?).with(invalid_path).and_return(false)
      expect(described_class.invalid_directories?(mixed_paths)).to be true
    end

    it 'returns false if collection has empty members but other entries are valid' do
      expect(described_class).to receive(:on_windows?).and_return(true)
      expect(File).to receive(:directory?).with(valid_path_a).and_return(true)
      expect(File).to receive(:directory?).with(valid_path_b).and_return(true)
      allow(File).to receive(:directory?).with('')
      expect(described_class.invalid_directories?(empty_members)).to be false
    end
  end

  let(:camel_case_hash) do
    {
      a: 1,
      appleButter: %w[a b c],
      someKeyValue: {
        nestedKey: 1,
        anotherNestedKey: 2
      }
    }
  end
  let(:kebab_case_hash) do
    {
      a: 1,
      'apple-butter': %w[a b c],
      'some-key-value': {
        'nested-key': 1,
        'another-nested-key': 2
      }
    }
  end
  let(:pascal_case_hash) do
    {
      A: 1,
      AppleButter: %w[a b c],
      SomeKeyValue: {
        NestedKey: 1,
        AnotherNestedKey: 2
      }
    }
  end
  let(:pascal_case_hash_in_an_array) do
    [
      'just a string',
      {
        SomeKey: 'a value'
      },
      1,
      {
        AnotherKey: {
          NestedKey: 1,
          NestedArray: [
            1,
            'another string',
            { SuperNestedKey: 'value' }
          ]
        }
      }
    ]
  end
  let(:snake_case_hash) do
    {
      a: 1,
      apple_butter: %w[a b c],
      some_key_value: {
        nested_key: 1,
        another_nested_key: 2
      }
    }
  end
  let(:snake_case_hash_in_an_array) do
    [
      'just a string',
      {
        some_key: 'a value'
      },
      1,
      {
        another_key: {
          nested_key: 1,
          nested_array: [
            1,
            'another string',
            { super_nested_key: 'value' }
          ]
        }
      }
    ]
  end
  let(:camel_case_string) { 'thisIsAString' }
  let(:kebab_case_string) { 'this-is-a-string' }
  let(:pascal_case_string) { 'ThisIsAString' }
  let(:snake_case_string) { 'this_is_a_string' }

  describe '.snake_case' do
    it 'converts a string to snake_case' do
      expect(described_class.snake_case(camel_case_string)).to eq snake_case_string
      expect(described_class.snake_case(kebab_case_string)).to eq snake_case_string
      expect(described_class.snake_case(pascal_case_string)).to eq snake_case_string
    end
  end

  describe '.snake_case_hash_keys' do
    it 'snake_cases the keys in a passed hash' do
      expect(described_class.snake_case_hash_keys(camel_case_hash)).to eq snake_case_hash
      expect(described_class.snake_case_hash_keys(kebab_case_hash)).to eq snake_case_hash
      expect(described_class.snake_case_hash_keys(pascal_case_hash)).to eq snake_case_hash
      expect(described_class.snake_case_hash_keys(pascal_case_hash_in_an_array)).to eq snake_case_hash_in_an_array
    end
  end

  describe '.pascal_case' do
    it 'converts a string to PascalCase' do
      expect(described_class.pascal_case(camel_case_string)).to eq pascal_case_string
      expect(described_class.pascal_case(kebab_case_string)).to eq pascal_case_string
      expect(described_class.pascal_case(snake_case_string)).to eq pascal_case_string
    end
  end

  describe '.pascal_case_hash_keys' do
    it 'PascalCases the keys in a passed hash' do
      expect(described_class.pascal_case_hash_keys(camel_case_hash)).to eq pascal_case_hash
      expect(described_class.pascal_case_hash_keys(kebab_case_hash)).to eq pascal_case_hash
      expect(described_class.pascal_case_hash_keys(snake_case_hash)).to eq pascal_case_hash
      expect(described_class.pascal_case_hash_keys(snake_case_hash_in_an_array)).to eq pascal_case_hash_in_an_array
    end
  end

  describe '.symbolize_hash_keys' do
    let(:array_with_string_keys_in_hashes) do
      [
        'just a string',
        {
          'some_key' => 'a value'
        },
        1,
        {
          'another_key' => {
            'nested_key' => 1,
            'nested_array' => [
              1,
              'another string',
              { 'super_nested_key' => 'value' }
            ]
          }
        }
      ]
    end
    let(:array_with_symbol_keys_in_hashes) do
      [
        'just a string',
        {
          some_key: 'a value'
        },
        1,
        {
          another_key: {
            nested_key: 1,
            nested_array: [
              1,
              'another string',
              { super_nested_key: 'value' }
            ]
          }
        }
      ]
    end

    it 'converts all string hash keys into symbols' do
      expect(described_class.symbolize_hash_keys(array_with_string_keys_in_hashes)).to eq array_with_symbol_keys_in_hashes
    end
  end

  describe '.escape_quotes' do
    it 'handles single quotes' do
      expect(described_class.escape_quotes("The 'Cats' go 'meow'!")).to match(/The ''Cats'' go ''meow''!/)
    end

    it 'handles double single quotes' do
      expect(described_class.escape_quotes("The ''Cats'' go 'meow'!")).to match(/The ''''Cats'''' go ''meow''!/)
    end

    it 'handles double quotes' do
      expect(described_class.escape_quotes("The 'Cats' go \"meow\"!")).to match(/The ''Cats'' go "meow"!/)
    end

    it 'handles dollar signs' do
      expect(described_class.escape_quotes("This should show \$foo variable")).to match(/This should show \$foo variable/)
    end
  end

  describe '.format_powershell_value' do
    let(:ruby_array) { ['string', 1, :symbol, true] }
    let(:powershell_array) { "@('string', 1, symbol, $true)" }
    let(:ruby_hash) do
      {
        string: 'string',
        number: 1,
        symbol: :some_symbol,
        boolean: true,
        nested_hash: {
          another_string: 'foo',
          another_number: 2,
          array: [1, 2, 3]
        }
      }
    end
    let(:powershell_hash) { "@{string = 'string'; number = 1; symbol = some_symbol; boolean = $true; nested_hash = @{another_string = 'foo'; another_number = 2; array = @(1, 2, 3)}}" }
    it 'returns a symbol as a non-interpolated string' do
      expect(described_class.format_powershell_value(:apple)).to eq('apple')
    end
    it 'returns a number as a non interpolated string' do
      expect(described_class.format_powershell_value(101)).to eq('101')
      expect(described_class.format_powershell_value(1.1)).to eq('1.1')
    end
    it 'returns boolean values as the appropriate PowerShell automatic variable' do
      expect(described_class.format_powershell_value(true)).to eq('$true')
      expect(described_class.format_powershell_value(:false)).to eq('$false') # rubocop:disable Lint/BooleanSymbol
    end
    it 'returns a string as an escaped string' do
      expect(described_class.format_powershell_value('some string')).to eq("'some string'")
    end
    it 'returns an array as a string representing a PowerShell array' do
      expect(described_class.format_powershell_value(ruby_array)).to eq(powershell_array)
    end
    it 'returns a hash as a string representing a PowerShell hash' do
      expect(described_class.format_powershell_value(ruby_hash)).to eq(powershell_hash)
    end
    it 'raises an error if an unknown type is passed' do
      expect { described_class.format_powershell_value(described_class) }.to raise_error(/unsupported type Module/)
    end
  end

  describe '.custom_powershell_property' do
    it 'returns a powershell hash with the name and expression keys' do
      expect(described_class.custom_powershell_property('apple', '$_.SomeValue / 5')).to eq("@{Name = 'apple'; Expression = {$_.SomeValue / 5}}")
    end
  end
end
