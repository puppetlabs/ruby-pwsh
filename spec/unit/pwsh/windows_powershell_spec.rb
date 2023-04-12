# frozen_string_literal: false

require 'spec_helper'

RSpec.describe Pwsh::WindowsPowerShell do
  describe '.version' do
    context 'on non-Windows platforms', unless: Pwsh::Util.on_windows? do
      it 'is not defined' do
        expect(defined?(described_class.version)).to be_nil
      end
    end

    context 'On Windows', if: Pwsh::Util.on_windows? do
      context 'when Windows PowerShell version is greater than three' do
        it 'detects a Windows PowerShell version' do
          allow_any_instance_of(Win32::Registry).to receive(:[]).with('PowerShellVersion').and_return('5.0.10514.6')
          expect(described_class.version).to eq('5.0.10514.6')
        end

        it 'calls the Windows PowerShell three registry path' do
          reg_key = instance_double('bob')
          allow(reg_key).to receive(:[]).with('PowerShellVersion').and_return('5.0.10514.6')
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine', Win32::Registry::KEY_READ | 0x100).and_yield(reg_key)

          described_class.version
        end

        it 'does not call Windows PowerShell one registry path' do
          reg_key = instance_double('bob')
          allow(reg_key).to receive(:[]).with('PowerShellVersion').and_return('5.0.10514.6')
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine', Win32::Registry::KEY_READ | 0x100).and_yield(reg_key)
          expect_any_instance_of(Win32::Registry).not_to receive(:open).with('SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine', Win32::Registry::KEY_READ | 0x100)

          described_class.version
        end
      end

      context 'when Windows PowerShell version is less than three' do
        it 'detects a Windows PowerShell version' do
          allow_any_instance_of(Win32::Registry).to receive(:[]).with('PowerShellVersion').and_return('2.0')

          expect(described_class.version).to eq('2.0')
        end

        it 'calls the Windows PowerShell one registry path' do
          reg_key = instance_double('bob')
          allow(reg_key).to receive(:[]).with('PowerShellVersion').and_return('2.0')
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine',
                                                                        Win32::Registry::KEY_READ | 0x100).and_yield(reg_key)
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine',
                                                                        Win32::Registry::KEY_READ | 0x100).and_raise(Win32::Registry::Error.new(2), 'nope')

          expect(described_class.version).to eq('2.0')
        end
      end

      context 'when Windows PowerShell  is not installed' do
        it 'returns nil and not throw' do
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine',
                                                                        Win32::Registry::KEY_READ | 0x100).and_raise(Win32::Registry::Error.new(2), 'nope')
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine',
                                                                        Win32::Registry::KEY_READ | 0x100).and_raise(Win32::Registry::Error.new(2), 'nope')

          expect(described_class.version).to be_nil
        end
      end
    end
  end

  describe '.compatible_version?' do
    context 'on non-Windows platforms', unless: Pwsh::Util.on_windows? do
      it 'returns false' do
        expect(described_class.compatible_version?).to be(false)
      end
    end

    context 'On Windows', if: Pwsh::Util.on_windows? do
      context 'when the Windows PowerShell major version is nil' do
        it 'returns false' do
          expect(described_class).to receive(:version).and_return(nil)
          expect(described_class.compatible_version?).to be(false)
        end
      end
      context 'when the Windows PowerShell major version is less than two' do
        it 'returns false' do
          expect(described_class).to receive(:version).and_return('1.0')
          expect(described_class.compatible_version?).to be(false)
        end
      end
      context 'when the Windows PowerShell major version is two' do
        it 'returns true if .NET 3.5 is installed' do
          expect(described_class).to receive(:version).and_return('2.0')
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5', Win32::Registry::KEY_READ | 0x100).and_yield
          expect(described_class.compatible_version?).to be(true)
        end
        it 'returns false if .NET 3.5 is not installed' do
          expect(described_class).to receive(:version).and_return('2.0')
          allow_any_instance_of(Win32::Registry).to receive(:open).with('SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5', Win32::Registry::KEY_READ | 0x100).and_raise(Win32::Registry::Error, 1)
          expect(described_class.compatible_version?).to be(false)
        end
      end
      context 'when the Windows PowerShell major version is three' do
        it 'returns true' do
          expect(described_class).to receive(:version).and_return('3.0')
          expect(described_class.compatible_version?).to be(true)
        end
      end
      context 'when the Windows PowerShell major version is greater than three' do
        it 'returns true' do
          expect(described_class).to receive(:version).and_return('4.0')
          expect(described_class.compatible_version?).to be(true)
        end
      end
    end
  end
end
