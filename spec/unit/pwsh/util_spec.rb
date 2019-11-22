# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Pwsh::Util do
  context '.invalid_directories?' do
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
  let(:camel_case_string) { 'thisIsAString' }
  let(:kebab_case_string) { 'this-is-a-string' }
  let(:pascal_case_string) { 'ThisIsAString' }
  let(:snake_case_string) { 'this_is_a_string' }

  context '.snake_case' do
    it 'converts a string to snake_case' do
      expect(described_class.snake_case(camel_case_string)).to eq snake_case_string
      expect(described_class.snake_case(kebab_case_string)).to eq snake_case_string
      expect(described_class.snake_case(pascal_case_string)).to eq snake_case_string
    end
  end

  context '.snake_case_hash_keys' do
    it 'snake_cases the keys in a passed hash' do
      expect(described_class.snake_case_hash_keys(camel_case_hash)).to eq snake_case_hash
      expect(described_class.snake_case_hash_keys(kebab_case_hash)).to eq snake_case_hash
      expect(described_class.snake_case_hash_keys(pascal_case_hash)).to eq snake_case_hash
    end
  end

  context '.pascal_case' do
    it 'converts a string to PascalCase' do
      expect(described_class.pascal_case(camel_case_string)).to eq pascal_case_string
      expect(described_class.pascal_case(kebab_case_string)).to eq pascal_case_string
      expect(described_class.pascal_case(snake_case_string)).to eq pascal_case_string
    end
  end

  context '.pascal_case_hash_keys' do
    it 'PascalCases the keys in a passed hash' do
      expect(described_class.pascal_case_hash_keys(camel_case_hash)).to eq pascal_case_hash
      expect(described_class.pascal_case_hash_keys(kebab_case_hash)).to eq pascal_case_hash
      expect(described_class.pascal_case_hash_keys(snake_case_hash)).to eq pascal_case_hash
    end
  end
end
