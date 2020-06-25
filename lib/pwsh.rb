# frozen_string_literal: false

require 'pwsh/util'
require 'pwsh/version'
require 'pwsh/windows_powershell'
require 'rexml/document'
require 'securerandom'
require 'socket'
require 'open3'
require 'base64'
require 'logger'

# Manage PowerShell and Windows PowerShell via ruby
module Pwsh
  # Standard errors
  class Error < StandardError; end
  # Create an instance of a PowerShell host and manage execution of PowerShell code inside that host.
  class Manager
    attr_reader :powershell_command
    attr_reader :powershell_arguments

    # We actually want this to be a class variable.
    @@instances = {} # rubocop:disable Style/ClassVars

    # Return the list of currently instantiated instances of the PowerShell Manager
    # @return [Hash] the list of instantiated instances of the PowerShell Manager, including their params and status.
    def self.instances
      @@instances
    end

    # Returns a set of default options for instantiating a manager
    #
    # @return [Hash] the default options for a new manager
    def self.default_options
      {
        debug: false,
        pipe_timeout: 30
      }
    end

    # Return an instance of the manager if one already exists for the specified
    # options or instantiate a new one if needed
    #
    # @param cmd [String] the full path to the PowerShell executable to manage
    # @param args [Array] the list of additional arguments to pass PowerShell
    # @param options [Hash] the set of options to set the behavior of the manager, including debug/timeout
    # @return [] specific instance matching the specified parameters either newly created or previously instantiated
    def self.instance(cmd, args, options = {})
      options = default_options.merge!(options)

      key = instance_key(cmd, args, options)
      manager = @@instances[key]

      if manager.nil? || !manager.alive?
        # ignore any errors trying to tear down this unusable instance
        begin
          manager.exit unless manager.nil? # rubocop:disable Style/SafeNavigation
        rescue
          nil
        end
        @@instances[key] = Manager.new(cmd, args, options)
      end

      @@instances[key]
    end

    # Determine whether or not the Win32 Console is enabled
    #
    # @return [Bool] true if enabled
    def self.win32console_enabled?
      @win32console_enabled ||= defined?(Win32) &&
                                defined?(Win32::Console) &&
                                Win32::Console.class == Class
    end

    # TODO: This thing isn't called anywhere and the variable it sets is never referenced...
    # Determine whether or not the machine has a compatible version of Windows PowerShell
    #
    # @return [Bool] true if Windows PowerShell 3+ is available or 2+ with .NET 3.5SP1
    # def self.compatible_version_of_windows_powershell?
    #   @compatible_version_of_powershell ||= Pwsh::WindowsPowerShell.compatible_version?
    # end

    # Determine whether or not the manager is supported on the machine for Windows PowerShell
    #
    # @return [Bool] true if Windows PowerShell is manageable
    def self.windows_powershell_supported?
      Pwsh::Util.on_windows? &&
        Pwsh::WindowsPowerShell.compatible_version? &&
        !win32console_enabled?
    end

    # Determine whether or not the manager is supported on the machine for PowerShell 6+
    #
    # @return [Bool] true if pwsh is manageable
    def self.pwsh_supported?
      !win32console_enabled?
    end

    # Instantiate a new instance of the PowerShell Manager
    #
    # @param cmd [String]
    # @param args [Array]
    # @param options [Hash]
    # @return nil
    def initialize(cmd, args = [], options = {})
      @usable = true
      @powershell_command = cmd
      @powershell_arguments = args

      raise "Bad configuration for ENV['lib']=#{ENV['lib']} - invalid path" if Pwsh::Util.invalid_directories?(ENV['lib'])

      if Pwsh::Util.on_windows?
        # Named pipes under Windows will automatically be mounted in \\.\pipe\...
        # https://github.com/dotnet/corefx/blob/a10890f4ffe0fadf090c922578ba0e606ebdd16c/src/System.IO.Pipes/src/System/IO/Pipes/NamedPipeServerStream.Windows.cs#L34
        named_pipe_name = "#{SecureRandom.uuid}PsHost"
        # This named pipe path is Windows specific.
        pipe_path = "\\\\.\\pipe\\#{named_pipe_name}"
      else
        require 'tmpdir'
        # .Net implements named pipes under Linux etc. as Unix Sockets in the filesystem
        # Paths that are rooted are not munged within C# Core.
        # https://github.com/dotnet/corefx/blob/94e9d02ad70b2224d012ac4a66eaa1f913ae4f29/src/System.IO.Pipes/src/System/IO/Pipes/PipeStream.Unix.cs#L49-L60
        # https://github.com/dotnet/corefx/blob/a10890f4ffe0fadf090c922578ba0e606ebdd16c/src/System.IO.Pipes/src/System/IO/Pipes/NamedPipeServerStream.Unix.cs#L44
        # https://github.com/dotnet/corefx/blob/a10890f4ffe0fadf090c922578ba0e606ebdd16c/src/System.IO.Pipes/src/System/IO/Pipes/NamedPipeServerStream.Unix.cs#L298-L299
        named_pipe_name = File.join(Dir.tmpdir, "#{SecureRandom.uuid}PsHost")
        pipe_path = named_pipe_name
      end
      pipe_timeout = options[:pipe_timeout] || self.class.default_options[:pipe_timeout]
      debug = options[:debug] || self.class.default_options[:debug]
      native_cmd = Pwsh::Util.on_windows? ? "\"#{cmd}\"" : cmd

      ps_args = args + ['-File', self.class.template_path, "\"#{named_pipe_name}\""]
      ps_args << '"-EmitDebugOutput"' if debug
      # @stderr should never be written to as PowerShell host redirects output
      stdin, @stdout, @stderr, @ps_process = Open3.popen3("#{native_cmd} #{ps_args.join(' ')}")
      stdin.close

      # Puppet.debug "#{Time.now} #{cmd} is running as pid: #{@ps_process[:pid]}"

      # Wait up to 180 seconds in 0.2 second intervals to be able to open the pipe.
      # If the pipe_timeout is ever specified as less than the sleep interval it will
      # never try to connect to a pipe and error out as if a timeout occurred.
      sleep_interval = 0.2
      (pipe_timeout / sleep_interval).to_int.times do
        begin
          @pipe = if Pwsh::Util.on_windows?
                    # Pipe is opened in binary mode and must always <- always what??
                    File.open(pipe_path, 'r+b')
                  else
                    UNIXSocket.new(pipe_path)
                  end
          break
        rescue
          sleep sleep_interval
        end
      end
      if @pipe.nil?
        # Tear down and kill the process if unable to connect to the pipe; failure to do so
        # results in zombie processes being left after the puppet run. We discovered that
        # closing @ps_process via .kill instead of using this method actually kills the
        # watcher and leaves an orphaned process behind. Failing to close stdout and stderr
        # also leaves clutter behind, so explicitly close those too.
        @stdout.close unless @stdout.closed?
        @stderr.close unless @stderr.closed?
        Process.kill('KILL', @ps_process[:pid]) if @ps_process.alive?
        raise "Failure waiting for PowerShell process #{@ps_process[:pid]} to start pipe server"
      end
      # Puppet.debug "#{Time.now} PowerShell initialization complete for pid: #{@ps_process[:pid]}"

      at_exit { exit }
    end

    # Return whether or not the manager is running, usable, and the I/O streams remain open.
    #
    # @return [Bool] true if manager is in working state
    def alive?
      # powershell process running
      @ps_process.alive? &&
        # explicitly set during a read / write failure, like broken pipe EPIPE
        @usable &&
        # an explicit failure state might not have been hit, but IO may be closed
        self.class.stream_valid?(@pipe) &&
        self.class.stream_valid?(@stdout) &&
        self.class.stream_valid?(@stderr)
    end

    # Run specified powershell code via the manager
    #
    # @param powershell_code [String]
    # @param timeout_ms [Int]
    # @param working_dir [String]
    # @param environment_variables [Hash]
    # @return [Hash] Hash containing exitcode, stderr, native_stdout and stdout
    def execute(powershell_code, timeout_ms = nil, working_dir = nil, environment_variables = [])
      code = make_ps_code(powershell_code, timeout_ms, working_dir, environment_variables)
      # err is drained stderr pipe (not captured by redirection inside PS)
      # or during a failure, a Ruby callstack array
      out, native_stdout, err = exec_read_result(code)

      # an error was caught during execution that has invalidated any results
      return { exitcode: -1, stderr: err } if out.nil? && !@usable

      out[:exitcode] = out[:exitcode].to_i unless out[:exitcode].nil?
      # If err contains data it must be "real" stderr output
      # which should be appended to what PS has already captured
      out[:stderr] = out[:stderr].nil? ? [] : [out[:stderr]]
      out[:stderr] += err unless err.nil?
      out[:native_stdout] = native_stdout

      out
    end

    # TODO: Is this needed in the code manager? When brought into the module, should this be
    #       added as helper code leveraging this gem?
    # Executes PowerShell code using the settings from a populated Puppet Exec Resource Type
    # def execute_resource(powershell_code, working_dir, timeout_ms, environment)
    #   working_dir = resource[:cwd]
    #   if (!working_dir.nil?)
    #     fail "Working directory '#{working_dir}' does not exist" unless File.directory?(working_dir)
    #   end
    #   timeout_ms = resource[:timeout].nil? ? nil : resource[:timeout] * 1000
    #   environment_variables = resource[:environment].nil? ? [] : resource[:environment]

    #   result = execute(powershell_code, timeout_ms, working_dir, environment_variables)

    #   stdout     = result[:stdout]
    #   native_out = result[:native_out]
    #   stderr     = result[:stderr]
    #   exit_code  = result[:exit_code]

    #   # unless stderr.nil?
    #   #   stderr.each { |e| Puppet.debug "STDERR: #{e.chop}" unless e.empty? }
    #   # end

    #   # Puppet.debug "STDERR: #{result[:errormessage]}" unless result[:errormessage].nil?

    #   output = Puppet::Util::Execution::ProcessOutput.new(stdout.to_s + native_out.to_s, exit_code)

    #   return output, output
    # end

    # Tear down the instance of the manager, shutting down the pipe and process.
    #
    # @return nil
    def exit
      @usable = false

      # Puppet.debug "Pwsh exiting..."

      # Ask PowerShell pipe server to shutdown if its still running
      # rather than expecting the pipe.close to terminate it
      begin
        write_pipe(pipe_command(:exit)) unless @pipe.closed?
      rescue
        nil
      end

      # Pipe may still be open, but if stdout / stderr are deat the PS
      # process is in trouble and will block forever on a write to the
      # pipe. It's safer to close pipe on the Ruby side, which gracefully
      # shuts down the PS side.
      @pipe.close   unless @pipe.closed?
      @stdout.close unless @stdout.closed?
      @stderr.close unless @stderr.closed?

      # Wait up to 2 seconds for the watcher thread to full exit
      @ps_process.join(2)
    end

    # Return the path to the bootstrap template
    #
    # @return [String] full path to the bootstrap template
    def self.template_path
      # A PowerShell -File compatible path to bootstrap the instance
      path = File.expand_path('../templates', __FILE__)
      path = File.join(path, 'init.ps1').gsub('/', '\\')
      "\"#{path}\""
    end

    # Return the block of code to be run by the manager with appropriate settings
    #
    # @param powershell_code [String] the actual PowerShell code you want to run
    # @param timeout_ms [Int] the number of milliseconds to wait for the command to run
    # @param working_dir [String] the working directory for PowerShell to execute from within
    # @param environment_variables [Array] Any overrides for environment variables you want to specify
    # @return [String] PowerShell code to be executed via the manager with appropriate params per config.
    def make_ps_code(powershell_code, timeout_ms = nil, working_dir = nil, environment_variables = [])
      begin
        # Zero timeout is a special case. Other modules sometimes treat this
        # as an infinite timeout. We don't support infinite, so for the case
        # of a user specifying zero, we sub in the default value of 300s.
        timeout_ms = 300 * 1000 if timeout_ms.zero?

        timeout_ms = Integer(timeout_ms)

        # Lower bound protection. The polling resolution is only 50ms.
        timeout_ms = 50 if timeout_ms < 50
      rescue
        timeout_ms = 300 * 1000
      end

      # Environment array firstly needs to be parsed and converted into a hashtable.
      # And then the values passed in need to be converted to a PowerShell Hashtable.
      #
      # Environment parsing is based on the puppet exec equivalent code
      # https://github.com/puppetlabs/puppet/blob/a9f77d71e992fc2580de7705847e31264e0fbebe/lib/puppet/provider/exec.rb#L35-L49
      environment = {}
      if (envlist = environment_variables)
        envlist = [envlist] unless envlist.is_a? Array
        envlist.each do |setting|
          if setting =~ /^(\w+)=((.|\n)+)$/
            env_name = Regexp.last_match(1)
            value    = Regexp.last_match(2)
            if environment.include?(env_name) || environment.include?(env_name.to_sym)
              # Puppet.warning("Overriding environment setting '#{env_name}' with '#{value}'")
            end
            environment[env_name] = value
          else # rubocop:disable Style/EmptyElse
            # TODO: Implement logging
            # Puppet.warning("Cannot understand environment setting #{setting.inspect}")
          end
        end
      end
      # Convert the Ruby Hashtable into PowerShell syntax
      exec_environment_variables = '@{'
      unless environment.empty?
        environment.each do |name, value|
          # PowerShell escapes single quotes inside a single quoted string by just adding
          # another single quote i.e. a value of foo'bar turns into 'foo''bar' when single quoted.
          ps_name  = name.gsub('\'', '\'\'')
          ps_value = value.gsub('\'', '\'\'')
          exec_environment_variables += " '#{ps_name}' = '#{ps_value}';"
        end
      end
      exec_environment_variables += '}'

      # PS Side expects Invoke-PowerShellUserCode is always the return value here
      # TODO: Refactor to use <<~ as soon as we can :sob:
      <<-CODE
$params = @{
  Code                     = @'
#{powershell_code}
'@
  TimeoutMilliseconds      = #{timeout_ms}
  WorkingDirectory         = "#{working_dir}"
  ExecEnvironmentVariables = #{exec_environment_variables}
}

Invoke-PowerShellUserCode @params
      CODE
    end

    # Default arguments for running Windows PowerShell via the manager
    #
    # @return [Array[String]] array of command flags to pass Windows PowerShell
    def self.powershell_args
      ps_args = ['-NoProfile', '-NonInteractive', '-NoLogo', '-ExecutionPolicy', 'Bypass']
      ps_args << '-Command' unless windows_powershell_supported?

      ps_args
    end

    # The path to Windows PowerShell on the system
    #
    # @return [String] the absolute path to the PowerShell executable. Returns 'powershell.exe' if no more specific path found.
    def self.powershell_path
      if File.exist?("#{ENV['SYSTEMROOT']}\\sysnative\\WindowsPowershell\\v1.0\\powershell.exe")
        "#{ENV['SYSTEMROOT']}\\sysnative\\WindowsPowershell\\v1.0\\powershell.exe"
      elsif File.exist?("#{ENV['SYSTEMROOT']}\\system32\\WindowsPowershell\\v1.0\\powershell.exe")
        "#{ENV['SYSTEMROOT']}\\system32\\WindowsPowershell\\v1.0\\powershell.exe"
      else
        'powershell.exe'
      end
    end

    # Retrieves the absolute path to pwsh
    #
    # @return [String] the absolute path to the found pwsh executable. Returns nil when it does not exist
    def self.pwsh_path(additional_paths = [])
      # Environment variables on Windows are not case sensitive however ruby hash keys are.
      # Convert all the key names to upcase so we can be sure to find PATH etc.
      # Also while ruby can have difficulty changing the case of some UTF8 characters, we're
      # only going to use plain ASCII names so this is safe.
      current_path = Pwsh::Util.on_windows? ? ENV.select { |k, _| k.upcase == 'PATH' }.values[0] : ENV['PATH']
      current_path = '' if current_path.nil?

      # Prefer any additional paths
      # TODO: Should we just use arrays by now instead of appending strings?
      search_paths = additional_paths.empty? ? current_path : additional_paths.join(File::PATH_SEPARATOR) + File::PATH_SEPARATOR + current_path

      # If we're on Windows, try the default installation locations as a last resort.
      # https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-6#msi
      if Pwsh::Util.on_windows?
        # TODO: What about PS 7? or 8?
        # TODO: Need to check on French/Turkish windows if ENV['PROGRAMFILES'] parses UTF8 names correctly
        # TODO: Need to ensure ENV['PROGRAMFILES'] is case insensitive, i.e. ENV['PROGRAMFiles'] should also resolve on Windows
        search_paths += ";#{ENV['PROGRAMFILES']}\\PowerShell\\6" \
                        ";#{ENV['PROGRAMFILES(X86)']}\\PowerShell\\6"
      end
      raise 'No paths discovered to search for Powershell!' if search_paths.split(File::PATH_SEPARATOR).empty?

      pwsh_paths = []
      # TODO: THis could probably be done better, but it works!
      if Pwsh::Util.on_windows?
        search_paths.split(File::PATH_SEPARATOR).each do |path|
          pwsh_paths << File.join(path, 'pwsh.exe') if File.exist?(File.join(path, 'pwsh.exe'))
        end
      else
        search_paths.split(File::PATH_SEPARATOR).each do |path|
          pwsh_paths << File.join(path, 'pwsh') if File.exist?(File.join(path, 'pwsh'))
        end
      end

      # TODO: not sure about nil? but .empty? is MethodNotFound on nil
      raise 'No pwsh discovered!' if pwsh_paths.nil? || pwsh_paths.empty?

      pwsh_paths[0]
    end

    # Default arguments for running PowerShell 6+ via the manager
    #
    # @return [Array[String]] array of command flags to pass PowerShell 6+
    def self.pwsh_args
      ['-NoProfile', '-NonInteractive', '-NoLogo', '-ExecutionPolicy', 'Bypass']
    end

    # The unique key for a given manager as determined by the full path to
    # the executable, the arguments to pass to the executable, and the options
    # specified for the manager; this enables the code to reuse an existing
    # manager if the same path, arguments, and options are specified.
    #
    # @return[String] Unique string representing the manager instance.
    def self.instance_key(cmd, args, options)
      cmd + args.join(' ') + options[:debug].to_s
    end

    # Return whether or not a particular stream is valid and readable
    #
    # @return [Bool] true if stream is readable and open
    def self.readable?(stream, timeout = 0.5)
      raise Errno::EPIPE unless stream_valid?(stream)

      read_ready = IO.select([stream], [], [], timeout)
      read_ready && stream == read_ready[0][0] && !stream.eof?
    end

    # When a stream has been closed by handle, but Ruby still has a file
    # descriptor for it, it can be tricky to detemine that it's actually
    # dead. The .fileno will still return an int, and calling get_osfhandle
    # against it returns what the CRT thinks is a valid Windows HANDLE value,
    # but that may no longer exist.
    #
    # @return [Bool] true if stream is open and operational
    def self.stream_valid?(stream)
      # When a stream is closed, it's obviously invalid, but Ruby doesn't always know
      !stream.closed? &&
        # So calling stat will yield and EBADF when underlying OS handle is bad
        # as this resolves to a HANDLE and then calls the Windows API
        !stream.stat.nil?
    # Any exceptions mean the stream is dead
    rescue
      false
    end

    # The manager sends a 4-byte integer representing the number
    # of bytes to read for the incoming string. This method reads
    # that prefix and then reads the specified number of bytes.
    # Mutates the given bytes, removing the length prefixed value.
    #
    # @return [String] The UTF-8 encoded string containing the payload
    def self.read_length_prefixed_string!(bytes)
      # 32 bit integer in Little Endian format
      length = bytes.slice!(0, 4).unpack1('V')
      return nil if length.zero?

      bytes.slice!(0, length).force_encoding(Encoding::UTF_8)
    end

    # Takes a given input byte-stream from PowerShell, length-prefixed,
    # and reads the key-value pairs from that output until all the
    # information is retrieved. Mutates the given bytes.
    #
    # @return [Hash] String pairs representing the information passed
    def self.ps_output_to_hash!(bytes)
      hash = {}

      hash[read_length_prefixed_string!(bytes).to_sym] = read_length_prefixed_string!(bytes) until bytes.empty?

      hash
    end

    # This is the command that the ruby process will send to the PowerShell
    # process and utilizes a 1 byte command identifier
    #   0 - Exit
    #   1 - Execute
    #
    # @return[String] Single byte representing the specified command
    def pipe_command(command)
      case command
      when :exit
        "\x00"
      when :execute
        "\x01"
      end
    end

    # Take a given string and prefix it with a 4-byte length and encode for sending
    # to the PowerShell manager.
    # Data format is:
    #   4 bytes - Little Endian encoded 32-bit integer length of string
    #             Intel CPUs are little endian, hence the .NET Framework typically is
    # variable length - UTF8 encoded string bytes
    #
    # @return[String] A binary encoded string prefixed with a 4-byte length identifier
    def length_prefixed_string(data)
      msg = data.encode(Encoding::UTF_8)
      # https://ruby-doc.org/core-1.9.3/Array.html#method-i-pack
      [msg.bytes.length].pack('V') + msg.force_encoding(Encoding::BINARY)
    end

    # Writes binary-encoded data to the PowerShell manager process via the pipe.
    #
    # @return nil
    def write_pipe(input)
      # For Compat with Ruby 2.1 and lower, it's important to use syswrite and
      # not write - otherwise, the pipe breaks after writing 1024 bytes.
      written = @pipe.syswrite(input)
      @pipe.flush

      if written != input.length # rubocop:disable Style/GuardClause
        msg = "Only wrote #{written} out of #{input.length} expected bytes to PowerShell pipe"
        raise Errno::EPIPE.new, msg
      end
    end

    # Read output from the PowerShell manager process via the pipe.
    #
    # @param pipe [IO] I/O Pipe to read from
    # @param timeout [Float] The number of seconds to wait for the pipe to be readable
    # @yield [String] a binary encoded string chunk
    # @return nil
    def read_from_pipe(pipe, timeout = 0.1, &_block)
      if self.class.readable?(pipe, timeout)
        l = pipe.readpartial(4096)
        # Puppet.debug "#{Time.now} PIPE> #{l}"
        # Since readpartial may return a nil at EOF, skip returning that value
        yield l unless l.nil?
      end

      nil
    end

    # Read from a specified pipe for as long as the signal is locked and
    # the pipe is readable. Then return the data as an array of UTF-8 strings.
    #
    # @param pipe [IO] the I/O pipe to read
    # @param signal [Mutex] the signal to wait for whilst reading data
    # @return [Array] An empty array if no data read or an array wrapping a single UTF-8 string if output received.
    def drain_pipe_until_signaled(pipe, signal)
      output = []

      read_from_pipe(pipe) { |s| output << s } while signal.locked?

      # There's ultimately a bit of a race here
      # Read one more time after signal is received
      read_from_pipe(pipe, 0) { |s| output << s } while self.class.readable?(pipe)

      # String has been binary up to this point, so force UTF-8 now
      output == [] ? [] : [output.join('').force_encoding(Encoding::UTF_8)]
    end

    # Open threads and pipes to read stdout and stderr from the PowerShell manager,
    # then continue to read data from the manager until either all data is returned
    # or an error interrupts the normal flow, then return that data.
    #
    # @return [Array] Array of three strings representing the output, native stdout, and stderr
    def read_streams
      pipe_done_reading = Mutex.new
      pipe_done_reading.lock
      # TODO: Uncomment again when implementing logging
      # start_time = Time.now

      stdout_reader = Thread.new { drain_pipe_until_signaled(@stdout, pipe_done_reading) }
      stderr_reader = Thread.new { drain_pipe_until_signaled(@stderr, pipe_done_reading) }

      pipe_reader = Thread.new(@pipe) do |pipe|
        # Read a Little Endian 32-bit integer for length of response
        expected_response_length = pipe.sysread(4).unpack1('V')

        next nil if expected_response_length.zero?

        # Reads the expected bytes as a binary string or fails
        buffer = ''
        # sysread may not return all of the requested bytes due to buffering or the
        # underlying IO system. Keep reading from the pipe until all the bytes are read.
        loop do
          buffer.concat(pipe.sysread(expected_response_length - buffer.length))
          break if buffer.length >= expected_response_length
        end
        buffer
      end

      # Puppet.debug "Waited #{Time.now - start_time} total seconds."

      # Block until sysread has completed or errors
      begin
        output = pipe_reader.value
        output = self.class.ps_output_to_hash!(output) unless output.nil?
      ensure
        # Signal stdout / stderr readers via Mutex so that
        # Ruby doesn't crash waiting on an invalid event.
        pipe_done_reading.unlock
      end

      # Given redirection on PowerShell side, this should always be empty
      stdout = stdout_reader.value

      [
        output,
        stdout == [] ? nil : stdout.join(''), # native stdout
        stderr_reader.value                   # native stderr
      ]
    ensure
      # Failsafe if the prior unlock was never reached / Mutex wasn't unlocked
      pipe_done_reading.unlock if pipe_done_reading.locked?
      # Wait for all non-nil threads to see mutex unlocked and finish
      [pipe_reader, stdout_reader, stderr_reader].compact.each(&:join)
    end

    # Executes PowerShell code over the PowerShell manager and returns the results.
    #
    # @param powershell_code [String] The PowerShell code to execute via the manager
    # @return [Array] Array of three strings representing the output, native stdout, and stderr
    def exec_read_result(powershell_code)
      write_pipe(pipe_command(:execute))
      write_pipe(length_prefixed_string(powershell_code))
      read_streams
    # If any pipes are broken, the manager is totally hosed
    # Bad file descriptors mean closed stream handles
    # EOFError is a closed pipe (could be as a result of tearing down process)
    # Errno::ECONNRESET is a closed unix domain socket (could be as a result of tearing down process)
    rescue Errno::EPIPE, Errno::EBADF, EOFError, Errno::ECONNRESET => e
      @usable = false
      [nil, nil, [e.inspect, e.backtrace].flatten]
    # Catch closed stream errors specifically
    rescue IOError => e
      raise unless e.message.start_with?('closed stream')

      @usable = false
      [nil, nil, [e.inspect, e.backtrace].flatten]
    end
  end
end
