# PowerShell Manager: Design and Architecture

This gem allows the use of a long-lived manager to which Ruby can send PowerShell invocations and receive the exection output.
This reduces the overhead time to execute PowerShell commands from seconds to milliseconds because each execution does not need to spin up a PowerShell process, execute a single pipeline, and tear the process down.

The manager operates by instantiating a custom PowerShell host process to which Ruby can then send commands over an IO pipe—
on Windows machines, named pipes, on Unix/Linux, Unix Domain Sockets.

## Communication Between Ruby and PowerShell Host Process

Communication between Ruby and the PowerShell host process uses binary encoded strings with a [4-byte prefix indicating how long the message is](https://en.wikipedia.org/wiki/Type-length-value).
The length prefix is a Little Endian encoded 32-bit integer.
The string being passed is always UTF-8.

Before a command string is sent to the PowerShell host process, a single 1-byte command identifier is sent—
`0` to tell the process to exit, `1` to tell the process to execute the next incoming string.

The PowerShell code to be executed is always wrapped in the following for execution to standardize behavior inside the PowerShell host process:

```powershell
$params = @{
  Code                     = @'
#{powershell_code}
'@
  TimeoutMilliseconds      = #{timeout_ms}
  WorkingDirectory         = "#{working_dir}"
  ExecEnvironmentVariables = #{exec_environment_variables}
}

Invoke-PowerShellUserCode @params
```

The code itself is placed inside a herestring and the timeout (integer), working directory (string), and environment variables (hash), if any, are passed as well.

![Diagram of communication flow for execution between Ruby and PowerShell manager](./design-comms.png)

### Output

The return from a Ruby command will always include:

+ `stdout` from the output streams, as if using `*>&1` to redirect
+ `exitcode` for the exit code of the execution; this will always be `0`, unless an exit code is specified or an exception is _thrown_.
+ `stderr` will always be an empty array.
+ `errormessage` will be the exception message of any thrown exception during execution.
+ `native_stdout` will always be nil.

#### Error Handling

Because PowerShell does not halt execution when an error is encountered, only when an terminating exception is thrown, the manager _also_ continues to execute until it encounters a terminating exception when executing commands.
This means that `Write-Error` messages will go to the stdout log but will not cause a change in the `exitcode` or populate the `errormessage` field.
Using `Throw` or any other method of generating a terminating exception _will_ set the `exitcode` to `1` and populate the `errormessage` field.

## Multiple PowerShell Host Processes

Until told otherwise, or they break, or their parent process closes, the instantiated PowerShell host processes will remain alive and waiting for further commands.
The significantly speeds up the execution of serialized commands, making continual interoperation between Ruby and PowerShell less complex for the developer leveraging this library.

In order to do this, the manager class has a class variable, `@@instances`, which contains a hash of the PowerShell hosts:

+ The key is the unique combination of options - path to the executable, flags, and additional options - passed to create the instance.
+ The value is the current state of that instance of the PowerShell host process.

If you attempt to instantiate an instance of the manager using the `instance` method, it will _first_ look to see if the specified manager and host process are already built and alive - if the manager instance does not exist or the host process is dead, _then_ it will spin up a new host process.

In test executions, standup of an instance takes around 1.5 seconds - accessing a pre-existing instance takes thousandths of a second.

## Multithreading

The manager and PowerShell host process are designed to be used single-threadedly with the PowerShell host expecting a single command and returning a single output at a time.
It does not at this time have additional guarding against being sent commands by multiple processes, but since the handles are unique IDs, this should not happen in practice.
