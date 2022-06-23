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

$TemplateFolderPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$hostSource = Get-Content -Path "$TemplateFolderPath/RubyPwsh.cs" -Raw

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

  # When Protected Event Logging and PowerShell Script Block logging are enabled together
  # the SystemRoot environment variable is a requirement. If it is removed as part of this purge
  # it causes the PowerShell process to crash, therefore breaking the pipe between Ruby and the
  # remote PowerShell session.
  # The least descructive way to avoid this is to filter out SystemRoot when pulling our current list
  # of environment variables. Then we can continue safely with the removal.
  $CurrentEnvironmentVariables = Get-ChildItem -Path Env:\* |
    Where-Object {$_.Name -ne "SystemRoot"}

  # Delete existing environment variables
  $CurrentEnvironmentVariables |
    ForEach-Object -Process { Remove-Item -Path "ENV:\$($_.Name)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Recurse }

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
