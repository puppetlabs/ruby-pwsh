[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [String]
  $NamedPipeName,

  [Parameter(Mandatory = $false)]
  [Switch]
  $EmitDebugOutput = $False,

  [Parameter(Mandatory = $false)]
  [System.Text.Encoding]
  $Encoding = [System.Text.Encoding]::UTF8
)

$script:EmitDebugOutput = $EmitDebugOutput
# Necessary for [System.Console]::Error.WriteLine to roundtrip with UTF-8
# Need to ensure we ignore encoding from other places and are consistent internally
[System.Console]::OutputEncoding = $Encoding

$hostSource = @"
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;
using System.Text;
using System.Threading;

namespace RubyPwsh
{
  public class RubyPwshPSHostRawUserInterface : PSHostRawUserInterface
  {
    public RubyPwshPSHostRawUserInterface()
    {
      buffersize      = new Size(120, 120);
      backgroundcolor = ConsoleColor.Black;
      foregroundcolor = ConsoleColor.White;
      cursorposition  = new Coordinates(0, 0);
      cursorsize      = 1;
    }

    private ConsoleColor backgroundcolor;
    public override ConsoleColor BackgroundColor
    {
      get { return backgroundcolor; }
      set { backgroundcolor = value; }
    }

    private Size buffersize;
    public override Size BufferSize
    {
      get { return buffersize; }
      set { buffersize = value; }
    }

    private Coordinates cursorposition;
    public override Coordinates CursorPosition
    {
      get { return cursorposition; }
      set { cursorposition = value; }
    }

    private int cursorsize;
    public override int CursorSize
    {
      get { return cursorsize; }
      set { cursorsize = value; }
    }

    private ConsoleColor foregroundcolor;
    public override ConsoleColor ForegroundColor
    {
      get { return foregroundcolor; }
      set { foregroundcolor = value; }
    }

    private Coordinates windowposition;
    public override Coordinates WindowPosition
    {
      get { return windowposition; }
      set { windowposition = value; }
    }

    private Size windowsize;
    public override Size WindowSize
    {
      get { return windowsize; }
      set { windowsize = value; }
    }

    private string windowtitle;
    public override string WindowTitle
    {
      get { return windowtitle; }
      set { windowtitle = value; }
    }

    public override bool KeyAvailable
    {
        get { return false; }
    }

    public override Size MaxPhysicalWindowSize
    {
        get { return new Size(165, 66); }
    }

    public override Size MaxWindowSize
    {
        get { return new Size(165, 66); }
    }

    public override void FlushInputBuffer()
    {
      throw new NotImplementedException();
    }

    public override BufferCell[,] GetBufferContents(Rectangle rectangle)
    {
      throw new NotImplementedException();
    }

    public override KeyInfo ReadKey(ReadKeyOptions options)
    {
      throw new NotImplementedException();
    }

    public override void ScrollBufferContents(Rectangle source, Coordinates destination, Rectangle clip, BufferCell fill)
    {
      throw new NotImplementedException();
    }

    public override void SetBufferContents(Rectangle rectangle, BufferCell fill)
    {
      throw new NotImplementedException();
    }

    public override void SetBufferContents(Coordinates origin, BufferCell[,] contents)
    {
      throw new NotImplementedException();
    }
  }

  public class RubyPwshPSHostUserInterface : PSHostUserInterface
  {
    private RubyPwshPSHostRawUserInterface _rawui;
    private StringBuilder _sb;
    private StringWriter _errWriter;
    private StringWriter _outWriter;

    public RubyPwshPSHostUserInterface()
    {
      _sb = new StringBuilder();
      _errWriter = new StringWriter(new StringBuilder());
      // NOTE: StringWriter / StringBuilder are not technically thread-safe
      // but PowerShell Write-XXX cmdlets and System.Console.Out.WriteXXX
      // should not be executed concurrently within PowerShell, so should be safe
      _outWriter = new StringWriter(_sb);
    }

    public override PSHostRawUserInterface RawUI
    {
      get
      {
        if ( _rawui == null){
          _rawui = new RubyPwshPSHostRawUserInterface();
        }
        return _rawui;
      }
    }

    public void ResetConsoleStreams()
    {
      System.Console.SetError(_errWriter);
      System.Console.SetOut(_outWriter);
    }

    public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
    {
      _sb.Append(value);
    }

    public override void Write(string value)
    {
      _sb.Append(value);
    }

    public override void WriteDebugLine(string message)
    {
      _sb.AppendLine("DEBUG: " + message);
    }

    public override void WriteErrorLine(string value)
    {
      _sb.AppendLine(value);
    }

    public override void WriteLine(string value)
    {
      _sb.AppendLine(value);
    }

    public override void WriteVerboseLine(string message)
    {
      _sb.AppendLine("VERBOSE: " + message);
    }

    public override void WriteWarningLine(string message)
    {
      _sb.AppendLine("WARNING: " + message);
    }

    public override void WriteProgress(long sourceId, ProgressRecord record)
    {
    }

    public string Output
    {
      get
      {
        _outWriter.Flush();
        string text = _outWriter.GetStringBuilder().ToString();
        _outWriter.GetStringBuilder().Length = 0; // Only .NET 4+ has .Clear()
        return text;
      }
    }

    public string StdErr
    {
      get
      {
        _errWriter.Flush();
        string text = _errWriter.GetStringBuilder().ToString();
        _errWriter.GetStringBuilder().Length = 0; // Only .NET 4+ has .Clear()
        return text;
      }
    }

    public override Dictionary<string, PSObject> Prompt(string caption, string message, Collection<FieldDescription> descriptions)
    {
      throw new NotImplementedException();
    }

    public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice)
    {
      throw new NotImplementedException();
    }

    public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)
    {
      throw new NotImplementedException();
    }

    public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)
    {
      throw new NotImplementedException();
    }

    public override string ReadLine()
    {
      throw new NotImplementedException();
    }

    public override SecureString ReadLineAsSecureString()
    {
      throw new NotImplementedException();
    }
  }

  public class RubyPwshPSHost : PSHost
  {
    private Guid _hostId = Guid.NewGuid();
    private bool shouldExit;
    private int exitCode;

    private readonly RubyPwshPSHostUserInterface _ui = new RubyPwshPSHostUserInterface();

    public RubyPwshPSHost () {}

    public bool ShouldExit { get { return this.shouldExit; } }
    public int ExitCode { get { return this.exitCode; } }
    public void ResetExitStatus()
    {
      this.exitCode = 0;
      this.shouldExit = false;
    }
    public void ResetConsoleStreams()
    {
      _ui.ResetConsoleStreams();
    }

    public override Guid InstanceId { get { return _hostId; } }
    public override string Name { get { return "RubyPwshPSHost"; } }
    public override Version Version { get { return new Version(1, 1); } }
    public override PSHostUserInterface UI
    {
      get { return _ui; }
    }
    public override CultureInfo CurrentCulture
    {
        get { return Thread.CurrentThread.CurrentCulture; }
    }
    public override CultureInfo CurrentUICulture
    {
        get { return Thread.CurrentThread.CurrentUICulture; }
    }

    public override void EnterNestedPrompt() { throw new NotImplementedException(); }
    public override void ExitNestedPrompt() { throw new NotImplementedException(); }
    public override void NotifyBeginApplication() { return; }
    public override void NotifyEndApplication() { return; }

    public override void SetShouldExit(int exitCode)
    {
      this.shouldExit = true;
      this.exitCode = exitCode;
    }
  }
}
"@

# Load the Custom PowerShell Host CSharp code
Add-Type -TypeDefinition $hostSource -Language CSharp

# Cache the current directory as the working directory for the Dynamic PowerShell session
$global:DefaultWorkingDirectory = (Get-Location -PSProvider FileSystem).Path

# Cache initial Environment Variables and values prior to any munging:
$global:CachedEnvironmentVariables = Get-ChildItem -Path Env:\

#this is a string so we can import into our dynamic PS instance
$global:ourFunctions = @'
function Reset-ProcessEnvironmentVariables {
  param($CachedEnvironmentVariables)

  # Delete existing environment variables
  Remove-Item -Path Env:\* -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Recurse

  # Re-add the cached environment variables
  $CachedEnvironmentVariables |
    ForEach-Object -Process { Set-Item -Path "Env:\$($_.Name)" -Value $_.Value }
}

function Reset-ProcessPowerShellVariables {
  param($psVariables)

  $psVariables |
    ForEach-Object -Process {
      $tempVar = $_
      if (-not(Get-Variable -Name $_.Name -ErrorAction SilentlyContinue)) {
        New-Variable -Name $_.Name -Value $_.Value -Description $_.Description -Option $_.Options -Visibility $_.Visibility
      }
    }
}
'@

function Invoke-PowerShellUserCode {
  [CmdletBinding()]
  param(
    [String]
    $Code,

    [Int]
    $TimeoutMilliseconds,

    [String]
    $WorkingDirectory,

    [Hashtable]
    $AdditionalEnvironmentVariables
  )

  # Instantiate the PowerShell Host and a new runspace to use if one is not already defined.
  if ($global:runspace -eq $null){
    # CreateDefault2 requires PS3
    # Setup Initial Session State - can be modified later, defaults to only core PowerShell
    # commands loaded/available. Everything else will dynamically load when needed.
    if ([System.Management.Automation.Runspaces.InitialSessionState].GetMethod('CreateDefault2')){
      $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    } else {
      $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    }

    $global:RubyPwshPSHost = New-Object RubyPwsh.RubyPwshPSHost
    $global:runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($global:RubyPwshPSHost, $sessionState)
    $global:runspace.Open()
  }

  try {
    # Reset the PowerShell handle, exit status, and streams.
    $ps = $null
    $global:RubyPwshPSHost.ResetExitStatus()
    $global:RubyPwshPSHost.ResetConsoleStreams()

    # This resets the variables from prior runs, clearing them from memory.
    if ($PSVersionTable.PSVersion -ge [Version]'3.0') {
      $global:runspace.ResetRunspaceState()
    }

    # Create a new instance of the PowerShell handle and drop into our reused runspace.
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $global:runspace

    # Preload our own functions; this could be moved into the array of startup scripts in the
    # InitialSessionState, once implemented.
    [Void]$ps.AddScript($global:ourFunctions)
    $ps.Invoke()

    # Set the working directory for the runspace; if not specified, use default; If it doesn't
    # exist, terminate the execution and report the error back.
    if ([string]::IsNullOrEmpty($WorkingDirectory)) {
      [Void]$ps.Runspace.SessionStateProxy.Path.SetLocation($global:DefaultWorkingDirectory)
    } else {
      if (-not (Test-Path -Path $WorkingDirectory)) { Throw "Working directory `"$WorkingDirectory`" does not exist" }
      [Void]$ps.Runspace.SessionStateProxy.Path.SetLocation($WorkingDirectory)
    }

    # Reset the environment variables to those cached at the instantiation of the PowerShell Host.
    $ps.Commands.Clear()
    [Void]$ps.AddCommand('Reset-ProcessEnvironmentVariables').AddParameter('CachedEnvironmentVariables', $global:CachedEnvironmentVariables)
    $ps.Invoke()

    # This code is the companion to the code at L403-405 and clears variables from prior runs.
    # Because ResetRunspaceState does not work on v2 and earlier, it must be called here, after
    # a new handle to PowerShell is created in prior steps.
    if ($PSVersionTable.PSVersion -le [Version]'2.0'){
      if (-not $global:psVariables){
        $global:psVariables = $ps.AddScript('Get-Variable').Invoke()
      }

      $ps.Commands.Clear()
      [void]$ps.AddScript('Get-Variable -Scope Global | Remove-Variable -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue')
      $ps.Invoke()

      $ps.Commands.Clear()
      [void]$ps.AddCommand('Reset-ProcessPowerShellVariables').AddParameter('psVariables', $global:psVariables)
      $ps.Invoke()
    }

    # Set any provided environment variables
    if ($AdditionalEnvironmentVariables -ne $null) {
      $AdditionalEnvironmentVariables.GetEnumerator() |
        ForEach-Object -Process { Set-Item -Path "Env:\$($_.Name)" -Value $_.Value }
    }

    # We clear the commands before each new command to avoid command pollution This does not need
    # to be a single command, it works the same if you pass a string with multiple lines of
    # PowerShell code. The user supplies a string and this gives it to the Host to execute.
    $ps.Commands.Clear()
    [Void]$ps.AddScript($Code)

    # Out-Default and MergeMyResults takes all output streams and writes it to the  PowerShell Host
    # we create this needs to be the last thing executed.
    [void]$ps.AddCommand("out-default")

    # if the call operator & established an exit code, exit with it; if this is NOT included, exit
    # codes for scripts will not work; anything that does not throw will exit 0.
    [Void]$ps.AddScript('if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }')

    # This is the code that ensures the output from the Host is interleaved; this ensures
    # everything written to the streams in the Host is returned.
    if ($PSVersionTable.PSVersion -le [Version]'2.0') {
      $ps.Commands.Commands[0].MergeMyResults([System.Management.Automation.Runspaces.PipelineResultTypes]::Error,
                                              [System.Management.Automation.Runspaces.PipelineResultTypes]::Output)
    } else {
      $ps.Commands.Commands[0].MergeMyResults([System.Management.Automation.Runspaces.PipelineResultTypes]::All,
                                              [System.Management.Automation.Runspaces.PipelineResultTypes]::Output)
    }

    # The asynchronous execution enables a user to set a timeout for the execution of their
    # provided code; this keeps the process from hanging eternally until an external caller
    # times out or the user kills the process.
    $asyncResult = $ps.BeginInvoke()

    if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) {
      # forcibly terminate execution of pipeline
      $ps.Stop()
      throw "Catastrophic failure: PowerShell module timeout ($TimeoutMilliseconds ms) exceeded while executing"
    }

    try {
      $ps.EndInvoke($asyncResult)
    } catch [System.Management.Automation.IncompleteParseException] {
      # This surfaces an error for when syntactically incorrect code is passed
      # https://msdn.microsoft.com/en-us/library/system.management.automation.incompleteparseexception%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
      throw $_.Exception.Message
    } catch {
      # This catches any execution errors from the passed code, drops out of execution here and
      # throws the most specific exception available.
      if ($null -ne $_.Exception.InnerException) {
        throw $_.Exception.InnerException
      } else {
        throw $_.Exception
      }
    }

    [RubyPwsh.RubyPwshPSHostUserInterface]$ui = $global:RubyPwshPSHost.UI
    return @{
      exitcode = $global:RubyPwshPSHost.Exitcode;
      stdout = $ui.Output;
      stderr = $ui.StdErr;
      errormessage = $null;
    }
  }
  catch {
    # if an execution or parse error is surfaced, dispose of the runspace and clear the global
    # runspace; it will be rebuilt on the next execution.
    try {
      if ($global:runspace) { $global:runspace.Dispose() }
    } finally {
      $global:runspace = $null
    }
    if (($global:RubyPwshPSHost -ne $null) -and $global:RubyPwshPSHost.ExitCode) {
      $ec = $global:RubyPwshPSHost.ExitCode
    } else {
      # This is technically not true at this point as we do not
      # know what exitcode we should return as an unexpected exception
      # happened and the user did not set an exitcode. Our best guess
      # is to return 1 so that we ensure ruby treats this run as an error.
      $ec = 1
    }

    # Format the exception message; this could be improved to surface more functional messaging
    # to the user; right now it dumps the exception message as a string.
    if ($_.Exception.ErrorRecord.InvocationInfo -ne $null) {
      $output = $_.Exception.Message + "`n`r" + $_.Exception.ErrorRecord.InvocationInfo.PositionMessage
    } else {
      $output = $_.Exception.Message | Out-String
    }

    # make an attempt to read Output / StdErr as it may contain partial output / info about failures
    # The PowerShell Host could be entirely dead and broken at this stage.
    try {
      $out = $global:RubyPwshPSHost.UI.Output
    } catch {
      $out = $null
    }
    try {
      $err = $global:RubyPwshPSHost.UI.StdErr
    } catch {
      $err = $null
    }

    # Make sure we return the expected data structure for what happened.
    return @{
      exitcode = $ec;
      stdout = $out;
      stderr = $err;
      errormessage = $output;
    }
  } finally {
    # Dispose of the shell regardless of success/failure. This clears state and memory both.
    # To enable conditional keeping of state, this would need an additional condition.
    if ($ps -ne $null) { [Void]$ps.Dispose() }
  }
}

function Write-SystemDebugMessage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [String]
    $Message
  )

  if ($script:EmitDebugOutput -or ($DebugPreference -ne 'SilentlyContinue')) {
    # This writes to the console, not to the PowerShell streams.
    # This is captured for communications with the pipe server.
    [System.Diagnostics.Debug]::WriteLine($Message)
  }
}

# This is not called anywhere else in the project. It may be dead code for
# event handling used in an earlier implementation. Or magic?
function Signal-Event {
  [CmdletBinding()]
  param(
    [String]
    $EventName
  )

  $event = [System.Threading.EventWaitHandle]::OpenExisting($EventName)

  [Void]$event.Set()
  [Void]$event.Close()
  if ($PSVersionTable.CLRVersion.Major -ge 3) {
    [Void]$event.Dispose()
  }

  Write-SystemDebugMessage -Message "Signaled event $EventName"
}

function ConvertTo-LittleEndianBytes {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [Int32]
    $Value
  )

  $bytes = [BitConverter]::GetBytes($Value)
  if (-not [BitConverter]::IsLittleEndian) { [Array]::Reverse($bytes) }

  return $bytes
}

function ConvertTo-ByteArray {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [Hashtable]
    $Hash,

    [Parameter(Mandatory = $true)]
    [System.Text.Encoding]
    $Encoding
  )

  # Initialize empty byte array that can be appended to
  $result = [Byte[]]@()
  # and add length / name / length / value from Hashtable
  $Hash.GetEnumerator() |
    ForEach-Object -Process {
      $name = $Encoding.GetBytes($_.Name)
      $result += (ConvertTo-LittleEndianBytes $name.Length) + $name

      $value = @()
      if ($_.Value -ne $null) { $value = $Encoding.GetBytes($_.Value.ToString()) }
      $result += (ConvertTo-LittleEndianBytes $value.Length) + $value
    }

  return $result
}

function Write-StreamResponse {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [System.IO.Pipes.PipeStream]
    $Stream,

    [Parameter(Mandatory = $true)]
    [Byte[]]
    $Bytes
  )

  $length = ConvertTo-LittleEndianBytes -Value $Bytes.Length
  $Stream.Write($length, 0, 4)
  $Stream.Flush()

  Write-SystemDebugMessage -Message "Wrote Int32 $($bytes.Length) as Byte[] $length to Stream"

  $Stream.Write($bytes, 0, $bytes.Length)
  $Stream.Flush()

  Write-SystemDebugMessage -Message "Wrote $($bytes.Length) bytes of data to Stream"
}

function Read-Int32FromStream {
  [CmdletBinding()]
  param (
   [Parameter(Mandatory = $true)]
   [System.IO.Pipes.PipeStream]
   $Stream
  )

  $length = New-Object Byte[] 4
  # Read blocks until all 4 bytes available
  $Stream.Read($length, 0, 4) | Out-Null
  # value is sent in Little Endian, but if the CPU is not, in-place reverse the array
  if (-not [BitConverter]::IsLittleEndian) { [Array]::Reverse($length) }
  $value = [BitConverter]::ToInt32($length, 0)

  Write-SystemDebugMessage -Message "Read Byte[] $length from stream as Int32 $value"

  return $value
}

# Message format is:
# 1 byte - command identifier
#     0 - Exit
#     1 - Execute
#    -1 - Exit - automatically returned when ReadByte encounters a closed pipe
# [optional] 4 bytes - Little Endian encoded 32-bit code block length for execute
#                      Intel CPUs are little endian, hence the .NET Framework typically is
# [optional] variable length - code block
function ConvertTo-PipeCommand {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [System.IO.Pipes.PipeStream]
    $Stream,

    [Parameter(Mandatory = $true)]
    [System.Text.Encoding]
    $Encoding,

    [Parameter(Mandatory = $false)]
    [Int32]
    $BufferChunkSize = 4096
  )

  # command identifier is a single value - ReadByte blocks until byte is ready / pipe closes
  $command = $Stream.ReadByte()

  Write-SystemDebugMessage -Message "Command id $command read from pipe"

  switch ($command) {
    # Exit
    # ReadByte returns a -1 when the pipe is closed on the other end
    { @(0, -1) -contains $_ } { return @{ Command = 'Exit' }}

    # Execute
    1 { $parsed = @{ Command = 'Execute' } }

    default { throw "Catastrophic failure: Unexpected Command $command received" }
  }

  # read size of incoming byte buffer
  $parsed.Length = Read-Int32FromStream -Stream $Stream
  Write-SystemDebugMessage -Message "Expecting $($parsed.Length) raw bytes of $($Encoding.EncodingName) characters"

  # Read blocks until all bytes are read or EOF / broken pipe hit - tested with 5MB and worked fine
  $parsed.RawData = New-Object Byte[] $parsed.Length
  $readBytes = 0
  do {
    $attempt = $attempt + 1
    # This will block if there's not enough data in the pipe
    $read = $Stream.Read($parsed.RawData, $readBytes, $parsed.Length - $readBytes)
    if ($read -eq 0) {
      throw "Catastrophic failure: Expected $($parsed.Length - $readBytesh) raw bytes, but the pipe reached an end of stream"
    }

    $readBytes = $readBytes + $read
    Write-SystemDebugMessage -Message "Read $($read) bytes from the pipe"
  } while ($readBytes -lt $parsed.Length)

  if ($readBytes -lt $parsed.Length) {
    throw "Catastrophic failure: Expected $($parsed.Length) raw bytes, only received $readBytes"
  }

  # turn the raw bytes into the expected encoded string!
  $parsed.Code = $Encoding.GetString($parsed.RawData)

  return $parsed
}

function Start-PipeServer {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [String]
    $CommandChannelPipeName,

    [Parameter(Mandatory = $true)]
    [System.Text.Encoding]
    $Encoding
  )

  Add-Type -AssemblyName System.Core

  # this does not require versioning in the payload as client / server are tightly coupled
  $server = New-Object System.IO.Pipes.NamedPipeServerStream($CommandChannelPipeName,
    [System.IO.Pipes.PipeDirection]::InOut)

  try {
    # block until Ruby process connects
    $server.WaitForConnection()

    Write-SystemDebugMessage -Message "Incoming Connection to $CommandChannelPipeName Received - Expecting Strings as $($Encoding.EncodingName)"

    # Infinite Loop to process commands until EXIT received
    $running = $true
    while ($running) {
      # throws if an unxpected command id is read from pipe
      $response = ConvertTo-PipeCommand -Stream $server -Encoding $Encoding

      Write-SystemDebugMessage -Message "Received $($response.Command) command from client"

      switch ($response.Command) {
        'Execute' {
          Write-SystemDebugMessage -Message "[Execute] Invoking user code:`n`n $($response.Code)"

          # assuming that the Ruby code always calls Invoked-PowerShellUserCode,
          # result should already be returned as a hash
          $result = Invoke-Expression $response.Code

          $bytes = ConvertTo-ByteArray -Hash $result -Encoding $Encoding

          Write-StreamResponse -Stream $server -Bytes $bytes
        }
        'Exit' { $running = $false }
      }
    }
  } catch [Exception] {
    Write-SystemDebugMessage -Message "PowerShell Pipe Server Failed!`n`n$_"
    throw
  } finally {
    if ($global:runspace -ne $null) {
      $global:runspace.Dispose()
      Write-SystemDebugMessage -Message "PowerShell Runspace Disposed`n`n$_"
    }
    if ($server -ne $null) {
      $server.Dispose()
      Write-SystemDebugMessage -Message "NamedPipeServerStream Disposed`n`n$_"
    }
  }
}

# Start the pipe server and wait for it to close.
Start-PipeServer -CommandChannelPipeName $NamedPipeName -Encoding $Encoding
Write-SystemDebugMessage -Message "Start-PipeServer Finished`n`n$_"
