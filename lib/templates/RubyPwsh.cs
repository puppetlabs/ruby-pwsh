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