# frozen_string_literal: true

require 'spec_helper'
require 'ruby-pwsh'

RSpec.describe Pwsh::Manager do
  # Shared doubles
  let(:mock_pipe) { instance_double(IO) }
  let(:mock_stdout) { instance_double(IO) }
  let(:mock_stderr) { instance_double(IO) }
  let(:mock_process) { instance_double(Thread) }
  let(:mock_stdin) { instance_double(IO) }
  let(:mock_manager) { instance_double(described_class) }

  # Allocate-based manager (no initialize called)
  let(:manager) do
    mgr = described_class.allocate
    mgr.instance_variable_set(:@pipe, mock_pipe)
    mgr.instance_variable_set(:@stdout, mock_stdout)
    mgr.instance_variable_set(:@stderr, mock_stderr)
    mgr.instance_variable_set(:@ps_process, mock_process)
    mgr.instance_variable_set(:@usable, true)
    mgr.instance_variable_set(:@powershell_command, '/usr/bin/pwsh')
    mgr.instance_variable_set(:@powershell_arguments, ['-NoProfile'])
    mgr
  end

  after do
    described_class.instances.clear
  end

  # -------------------------------------------------------------------------
  # Class methods — no I/O
  # -------------------------------------------------------------------------

  describe '.instances' do
    it 'returns a Hash' do
      expect(described_class.instances).to be_a(Hash)
    end
  end

  describe '.default_options' do
    it 'returns debug: false and pipe_timeout: 30' do
      expect(described_class.default_options).to eq(debug: false, pipe_timeout: 30)
    end
  end

  describe '.win32console_enabled?' do
    it 'returns false on macOS (Win32::Console not defined)' do
      expect(described_class).not_to be_win32console_enabled
    end
  end

  describe '.pwsh_supported?' do
    it 'returns true when win32console is not enabled' do
      allow(described_class).to receive(:win32console_enabled?).and_return(false)
      expect(described_class.pwsh_supported?).to be true
    end

    it 'returns false when win32console is enabled' do
      allow(described_class).to receive(:win32console_enabled?).and_return(true)
      expect(described_class.pwsh_supported?).to be false
    end
  end

  describe '.windows_powershell_supported?' do
    it 'returns false when not on Windows' do
      allow(Pwsh::Util).to receive(:on_windows?).and_return(false)
      expect(described_class.windows_powershell_supported?).to be false
    end
  end

  describe '.template_path' do
    it 'returns a quoted string containing init.ps1' do
      path = described_class.template_path
      expect(path).to include('init.ps1')
      expect(path).to start_with('"')
      expect(path).to end_with('"')
    end
  end

  describe '.powershell_args' do
    before { allow(Pwsh::Util).to receive(:on_windows?).and_return(false) }

    it 'includes standard flags' do
      args = described_class.powershell_args
      expect(args).to include('-NoProfile', '-NonInteractive', '-NoLogo', '-ExecutionPolicy', 'Bypass')
    end

    it 'appends -Command when windows_powershell_supported? is false' do
      allow(described_class).to receive(:windows_powershell_supported?).and_return(false)
      expect(described_class.powershell_args).to include('-Command')
    end

    it 'does not append -Command when windows_powershell_supported? is true' do
      allow(described_class).to receive(:windows_powershell_supported?).and_return(true)
      expect(described_class.powershell_args).not_to include('-Command')
    end
  end

  describe '.pwsh_args' do
    it 'returns the expected fixed array' do
      expect(described_class.pwsh_args).to eq(['-NoProfile', '-NonInteractive', '-NoLogo', '-ExecutionPolicy', 'Bypass'])
    end
  end

  describe '.instance_key' do
    it 'combines cmd, args and options into a string' do
      cmd = '/usr/bin/pwsh'
      args = ['-NoProfile']
      options = { debug: false }
      key = described_class.instance_key(cmd, args, options)
      expect(key).to eq("#{cmd}#{args.join(' ')}#{options}")
    end
  end

  describe '.powershell_path' do
    let(:systemroot) { 'C:\\Windows' }

    before { allow(ENV).to receive(:fetch).with('SYSTEMROOT', nil).and_return(systemroot) }

    it 'returns sysnative path when it exists' do
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:exist?)
        .with("#{systemroot}\\sysnative\\WindowsPowershell\\v1.0\\powershell.exe")
        .and_return(true)
      expect(described_class.powershell_path).to include('sysnative')
    end

    it 'returns system32 path when sysnative does not exist but system32 does' do
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:exist?)
        .with("#{systemroot}\\system32\\WindowsPowershell\\v1.0\\powershell.exe")
        .and_return(true)
      expect(described_class.powershell_path).to include('system32')
    end

    it 'falls back to powershell.exe when neither path exists' do
      allow(File).to receive(:exist?).and_return(false)
      expect(described_class.powershell_path).to eq('powershell.exe')
    end
  end

  describe '.pwsh_path' do
    context 'when on non-Windows' do
      before { allow(Pwsh::Util).to receive(:on_windows?).and_return(false) }

      it 'returns the first found pwsh path' do
        allow(ENV).to receive(:fetch).with('PATH', nil).and_return('/usr/local/bin:/usr/bin')
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:exist?).with('/usr/local/bin/pwsh').and_return(true)
        expect(described_class.pwsh_path).to eq('/usr/local/bin/pwsh')
      end

      it 'raises when pwsh is not found' do
        allow(ENV).to receive(:fetch).with('PATH', nil).and_return('/usr/local/bin:/usr/bin')
        allow(File).to receive(:exist?).and_return(false)
        expect { described_class.pwsh_path }.to raise_error(RuntimeError, /No pwsh discovered!/)
      end

      it 'uses additional_paths when provided' do
        allow(ENV).to receive(:fetch).with('PATH', nil).and_return('/usr/bin')
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:exist?).with('/opt/pwsh/pwsh').and_return(true)
        expect(described_class.pwsh_path(['/opt/pwsh'])).to eq('/opt/pwsh/pwsh')
      end
    end
  end

  describe '.readable?' do
    context 'when stream_valid? is false' do
      it 'raises EPIPE' do
        allow(described_class).to receive(:stream_valid?).and_return(false)
        expect { described_class.readable?(mock_pipe) }.to raise_error(Errno::EPIPE)
      end
    end

    context 'when IO.select returns nil' do
      it 'returns falsey' do
        allow(described_class).to receive(:stream_valid?).and_return(true)
        allow(IO).to receive(:select).and_return(nil)
        expect(described_class).not_to be_readable(mock_pipe)
      end
    end

    context 'when stream is ready and not at EOF' do
      it 'returns truthy' do
        allow(described_class).to receive(:stream_valid?).and_return(true)
        allow(IO).to receive(:select).and_return([[mock_pipe], [], []])
        allow(mock_pipe).to receive(:eof?).and_return(false)
        expect(described_class).to be_readable(mock_pipe)
      end
    end
  end

  describe '.stream_valid?' do
    it 'returns false when stream is closed' do
      allow(mock_pipe).to receive(:closed?).and_return(true)
      expect(described_class.stream_valid?(mock_pipe)).to be false
    end

    it 'returns false when stat raises an error' do
      allow(mock_pipe).to receive(:closed?).and_return(false)
      allow(mock_pipe).to receive(:stat).and_raise(Errno::EBADF)
      expect(described_class.stream_valid?(mock_pipe)).to be false
    end

    it 'returns true when stream is open and stat succeeds' do
      stat_double = instance_double(File::Stat)
      allow(mock_pipe).to receive(:closed?).and_return(false)
      allow(mock_pipe).to receive(:stat).and_return(stat_double)
      expect(described_class.stream_valid?(mock_pipe)).to be true
    end
  end

  describe '.read_length_prefixed_string!' do
    it 'reads a length-prefixed string' do
      payload = 'hello'
      bytes = [payload.bytesize].pack('V') + payload
      result = described_class.read_length_prefixed_string!(bytes)
      expect(result).to eq('hello')
    end

    it 'returns nil when length is zero' do
      bytes = [0].pack('V')
      result = described_class.read_length_prefixed_string!(bytes)
      expect(result).to be_nil
    end

    it 'mutates the bytes by removing the consumed prefix and string' do
      payload = 'hi'
      extra = 'rest'
      bytes = [payload.bytesize].pack('V') + payload + extra
      described_class.read_length_prefixed_string!(bytes)
      expect(bytes).to eq(extra)
    end
  end

  describe '.ps_output_to_hash!' do
    it 'parses key/value pairs from length-prefixed bytes' do
      def pack_lps(str)
        [str.bytesize].pack('V') + str
      end

      bytes = pack_lps('stdout') + pack_lps('hello world') + pack_lps('exitcode') + pack_lps('0')
      result = described_class.ps_output_to_hash!(bytes)
      expect(result).to eq(stdout: 'hello world', exitcode: '0')
    end
  end

  # -------------------------------------------------------------------------
  # Class method .instance (mocks Manager.new to avoid live process)
  # -------------------------------------------------------------------------

  describe '.instance' do
    it 'creates a new manager when none exists for the key' do
      allow(mock_manager).to receive(:alive?).and_return(true)
      allow(described_class).to receive(:new).and_return(mock_manager)

      result = described_class.instance('/usr/bin/pwsh', [])
      expect(result).to eq(mock_manager)
    end

    it 'returns an existing alive manager without creating a new one' do
      allow(mock_manager).to receive(:alive?).and_return(true)
      allow(described_class).to receive(:new).and_return(mock_manager).once

      first = described_class.instance('/usr/bin/pwsh', [])
      second = described_class.instance('/usr/bin/pwsh', [])
      expect(first).to eq(second)
    end

    it 'replaces a dead manager with a new one' do
      dead_manager = instance_double(described_class)
      allow(dead_manager).to receive(:alive?).and_return(false)
      allow(dead_manager).to receive(:exit)

      new_manager = instance_double(described_class)
      allow(new_manager).to receive(:alive?).and_return(true)

      allow(described_class).to receive(:new).and_return(dead_manager, new_manager)

      described_class.instance('/usr/bin/pwsh', [])
      # Simulate the stored manager being dead now
      key = described_class.instance_key('/usr/bin/pwsh', [], described_class.default_options)
      described_class.instances[key] = dead_manager

      result = described_class.instance('/usr/bin/pwsh', [])
      expect(result).to eq(new_manager)
    end

    it 'swallows errors when tearing down a dead manager' do
      dead_manager = instance_double(described_class)
      allow(dead_manager).to receive(:alive?).and_return(false)
      allow(dead_manager).to receive(:exit).and_raise(StandardError, 'teardown failed')

      new_manager = instance_double(described_class)
      allow(new_manager).to receive(:alive?).and_return(true)
      allow(described_class).to receive(:new).and_return(new_manager)

      key = described_class.instance_key('/usr/bin/pwsh', [], described_class.default_options)
      described_class.instances[key] = dead_manager

      expect { described_class.instance('/usr/bin/pwsh', []) }.not_to raise_error
    end
  end

  # -------------------------------------------------------------------------
  # Instance method: make_ps_code (pure string builder, no I/O)
  # -------------------------------------------------------------------------

  describe '#make_ps_code' do
    it 'wraps code in Invoke-PowerShellUserCode' do
      code = manager.make_ps_code('Write-Host "hi"')
      expect(code).to include('Invoke-PowerShellUserCode')
    end

    it 'uses 300000 ms when timeout_ms is nil' do
      code = manager.make_ps_code('foo', nil)
      expect(code).to match(/TimeoutMilliseconds\s+=\s+300000/)
    end

    it 'uses 300000 ms when timeout_ms is 0' do
      code = manager.make_ps_code('foo', 0)
      expect(code).to match(/TimeoutMilliseconds\s+=\s+300000/)
    end

    it 'uses 50 ms when timeout_ms is less than 50' do
      code = manager.make_ps_code('foo', 20)
      expect(code).to match(/TimeoutMilliseconds\s+=\s+50/)
    end

    it 'uses exact timeout when it is valid and >= 50' do
      code = manager.make_ps_code('foo', 5000)
      expect(code).to match(/TimeoutMilliseconds\s+=\s+5000/)
    end

    it 'uses 300000 ms when timeout_ms is non-integer' do
      code = manager.make_ps_code('foo', 'not_a_number')
      expect(code).to match(/TimeoutMilliseconds\s+=\s+300000/)
    end

    it 'includes the working_dir in generated code' do
      code = manager.make_ps_code('foo', nil, '/tmp/work')
      expect(code).to include('/tmp/work')
    end

    it 'includes environment variables in KEY=value format' do
      code = manager.make_ps_code('foo', nil, nil, ['MY_VAR=hello'])
      expect(code).to include("'MY_VAR'")
      expect(code).to include("'hello'")
    end

    it 'escapes single quotes in environment variable values' do
      code = manager.make_ps_code('foo', nil, nil, ["MY_VAR=it's"])
      expect(code).to include("'it''s'")
    end

    it 'ignores malformed environment entries' do
      code = manager.make_ps_code('foo', nil, nil, ['=nope', 'also_bad', ''])
      # Should still generate valid code without crashing
      expect(code).to include('Invoke-PowerShellUserCode')
      expect(code).to include('@{}')
    end

    it 'handles a single env var string (not array)' do
      code = manager.make_ps_code('foo', nil, nil, 'KEY=value')
      expect(code).to include("'KEY'")
      expect(code).to include("'value'")
    end
  end

  # -------------------------------------------------------------------------
  # Instance methods (allocate pattern)
  # -------------------------------------------------------------------------

  describe '#pipe_command' do
    it 'returns "\x00" for :exit' do
      expect(manager.pipe_command(:exit)).to eq("\x00")
    end

    it 'returns "\x01" for :execute' do
      expect(manager.pipe_command(:execute)).to eq("\x01")
    end

    it 'returns nil for unknown commands' do
      expect(manager.pipe_command(:unknown)).to be_nil
    end
  end

  describe '#length_prefixed_string' do
    it 'returns a 4-byte little-endian length prefix followed by the string bytes' do
      result = manager.length_prefixed_string('hi')
      length_bytes = result[0, 4]
      string_bytes = result[4..]
      expect(length_bytes.unpack1('V')).to eq(2)
      expect(string_bytes.force_encoding(Encoding::UTF_8)).to eq('hi')
    end

    it 'correctly encodes multi-byte UTF-8 strings' do
      str = 'Aۿ'
      result = manager.length_prefixed_string(str)
      byte_length = str.encode(Encoding::UTF_8).bytes.length
      expect(result[0, 4].unpack1('V')).to eq(byte_length)
    end
  end

  describe '#alive?' do
    before do
      allow(mock_process).to receive(:alive?).and_return(true)
      allow(described_class).to receive(:stream_valid?).and_return(true)
    end

    it 'returns true when process alive, @usable true, and all streams valid' do
      expect(manager.alive?).to be true
    end

    it 'returns false when @usable is false' do
      manager.instance_variable_set(:@usable, false)
      expect(manager.alive?).to be false
    end

    it 'returns false when ps_process is not alive' do
      allow(mock_process).to receive(:alive?).and_return(false)
      expect(manager.alive?).to be false
    end

    it 'returns false when a stream is invalid' do
      allow(described_class).to receive(:stream_valid?).with(mock_pipe).and_return(false)
      expect(manager.alive?).to be false
    end
  end

  describe '#write_pipe' do
    it 'writes to the pipe and flushes successfully' do
      input = "\x01"
      allow(mock_pipe).to receive(:write).with(input).and_return(1)
      allow(mock_pipe).to receive(:flush)
      expect { manager.write_pipe(input) }.not_to raise_error
    end

    it 'raises EPIPE when not all bytes are written' do
      input = "\x01\x02"
      allow(mock_pipe).to receive(:write).with(input).and_return(1)
      allow(mock_pipe).to receive(:flush)
      expect { manager.write_pipe(input) }.to raise_error(Errno::EPIPE)
    end
  end

  describe '#execute' do
    context 'when manager is not usable' do
      it 'returns exitcode -1' do
        manager.instance_variable_set(:@usable, false)
        # exec_read_result returns nil output when unusable
        allow(manager).to receive(:exec_read_result).and_return([nil, nil, ['some error']])
        result = manager.execute('Write-Host "hi"')
        expect(result[:exitcode]).to eq(-1)
      end
    end

    context 'when manager is usable' do
      it 'returns a hash with integer exitcode' do
        allow(manager).to receive(:exec_read_result).and_return(
          [{ exitcode: '0', stdout: 'hi', stderr: nil }, nil, nil]
        )
        result = manager.execute('Write-Host "hi"')
        expect(result[:exitcode]).to eq(0)
        expect(result[:exitcode]).to be_a(Integer)
      end

      it 'appends native_stdout to the result' do
        allow(manager).to receive(:exec_read_result).and_return(
          [{ exitcode: '0', stdout: 'output', stderr: nil }, 'native output', nil]
        )
        result = manager.execute('something')
        expect(result[:native_stdout]).to eq('native output')
      end

      it 'appends stderr from the pipe to the result' do
        allow(manager).to receive(:exec_read_result).and_return(
          [{ exitcode: '0', stdout: nil, stderr: nil }, nil, ['pipe stderr']]
        )
        result = manager.execute('something')
        expect(result[:stderr]).to include('pipe stderr')
      end

      it 'combines ps-captured stderr with pipe stderr' do
        allow(manager).to receive(:exec_read_result).and_return(
          [{ exitcode: '0', stdout: nil, stderr: 'ps error' }, nil, ['pipe error']]
        )
        result = manager.execute('something')
        expect(result[:stderr]).to include('ps error')
        expect(result[:stderr]).to include('pipe error')
      end
    end
  end

  describe '#exit' do
    before do
      allow(mock_pipe).to receive(:closed?).and_return(false)
      allow(mock_pipe).to receive(:write).and_return(1)
      allow(mock_pipe).to receive(:flush)
      allow(mock_pipe).to receive(:close)
      allow(mock_stdout).to receive(:closed?).and_return(false)
      allow(mock_stdout).to receive(:close)
      allow(mock_stderr).to receive(:closed?).and_return(false)
      allow(mock_stderr).to receive(:close)
      allow(mock_process).to receive(:join)
    end

    it 'sets @usable to false' do
      manager.exit
      expect(manager.instance_variable_get(:@usable)).to be false
    end

    it 'closes the pipe, stdout, and stderr' do
      expect(mock_pipe).to receive(:close)
      expect(mock_stdout).to receive(:close)
      expect(mock_stderr).to receive(:close)
      manager.exit
    end

    it 'skips closing streams that are already closed' do
      allow(mock_pipe).to receive(:closed?).and_return(true)
      allow(mock_stdout).to receive(:closed?).and_return(true)
      allow(mock_stderr).to receive(:closed?).and_return(true)
      expect(mock_pipe).not_to receive(:close)
      expect(mock_stdout).not_to receive(:close)
      expect(mock_stderr).not_to receive(:close)
      manager.exit
    end

    it 'does not raise when write_pipe fails during exit' do
      allow(mock_pipe).to receive(:write).and_raise(Errno::EPIPE)
      expect { manager.exit }.not_to raise_error
    end

    it 'waits for the process to finish' do
      expect(mock_process).to receive(:join).with(2)
      manager.exit
    end
  end

  # -------------------------------------------------------------------------
  # initialize — stub Open3 / UNIXSocket to avoid live process
  # -------------------------------------------------------------------------

  describe '#initialize' do
    before do
      allow(Pwsh::Util).to receive(:on_windows?).and_return(false)
      allow(Pwsh::Util).to receive(:invalid_directories?).and_return(false)
      allow(mock_stdin).to receive(:close)
      allow(Open3).to receive(:popen3).and_return([mock_stdin, mock_stdout, mock_stderr, mock_process])
      allow(UNIXSocket).to receive(:new).and_return(mock_pipe)
      allow_any_instance_of(described_class).to receive(:at_exit) # rubocop:disable RSpec/AnyInstance
    end

    it 'creates a usable manager' do
      mgr = described_class.new('/usr/bin/pwsh', [], pipe_timeout: 1)
      expect(mgr.instance_variable_get(:@usable)).to be true
    end

    it 'stores the powershell_command' do
      mgr = described_class.new('/usr/bin/pwsh', [], pipe_timeout: 1)
      expect(mgr.powershell_command).to eq('/usr/bin/pwsh')
    end

    it 'passes the command to Open3' do
      expect(Open3).to receive(:popen3).with(a_string_including('/usr/bin/pwsh')).and_return([mock_stdin, mock_stdout, mock_stderr, mock_process]) # rubocop:disable RSpec/StubbedMock
      described_class.new('/usr/bin/pwsh', [], pipe_timeout: 1)
    end

    it 'appends EmitDebugOutput when debug: true' do
      expect(Open3).to receive(:popen3).with(a_string_including('EmitDebugOutput')).and_return([mock_stdin, mock_stdout, mock_stderr, mock_process]) # rubocop:disable RSpec/StubbedMock
      described_class.new('/usr/bin/pwsh', [], pipe_timeout: 1, debug: true)
    end

    it 'closes stdin after popen3' do
      expect(mock_stdin).to receive(:close)
      described_class.new('/usr/bin/pwsh', [], pipe_timeout: 1)
    end

    it 'raises when the pipe never connects' do
      allow(mock_stdout).to receive(:closed?).and_return(false)
      allow(mock_stdout).to receive(:close)
      allow(mock_stderr).to receive(:closed?).and_return(false)
      allow(mock_stderr).to receive(:close)
      allow(mock_process).to receive(:alive?).and_return(false)
      allow(mock_process).to receive(:[]).with(:pid).and_return(99_999)
      allow(UNIXSocket).to receive(:new).and_raise(Errno::ENOENT)
      allow(Process).to receive(:kill)

      expect do
        described_class.new('/usr/bin/pwsh', [], pipe_timeout: 0.1)
      end.to raise_error(RuntimeError, /Failure waiting for PowerShell process/)
    end
  end
end
