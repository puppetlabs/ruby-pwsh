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
end
