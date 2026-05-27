# Eagle `[exec]` Command: Comprehensive Analysis of Command Line and Argument Processing

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[exec]` command internals. For basic command syntax and options, see [`core_language.md`](core_language.md#cmd-exec). For usage examples, see [`core_examples.md`](core_examples.md#ex-exec). For the `exec.eagle` script library procedures, see [`core_script_library.md`](core_script_library.md#execution-utilities-execeagle).

## 1. Executive Summary

Eagle's `[exec]` is **not** a native-Tcl-style pipeline parser. It is a rich
wrapper around a **single** .NET `ProcessStartInfo` launch, with a large option
surface for building one command-line string, handling I/O, callbacks, logging,
credentials, timeouts, and result mapping. The central design difference is that
Eagle usually **re-serializes** its post-parser argument words into one
`ProcessStartInfo.Arguments` string, either with a simple `ListOps.Concat`
path or with the explicit `RuntimeOps.BuildCommandLine` quoting/escaping path.
Native Tcl, by contrast, treats the `[exec]` arguments as a shell-pipeline
specification where each word already has semantic meaning as a command word,
redirection token, or pipeline separator.

That one architectural choice explains most of the behavioral differences. In
native Tcl, quoting is primarily about getting the **Tcl parser** to produce
the words you want, and then `[exec]` interprets those words as pipeline syntax
and argv items. In Eagle, once the script parser has already produced words,
`[exec]` often performs a **second-stage command-line construction step**; in that
stage, literal double-quote characters can be intentional data for Eagle's
algorithm instead of just parser syntax.

**Key source files:**

| File | Role |
|------|------|
| `Eagle/Library/Commands/Exec.cs` | Main command implementation (638 lines) |
| `Eagle/Library/Components/Private/CommandOptions.cs` | Centralized option dictionary factory (see [`options.md`](options.md)) |
| `Eagle/Library/Components/Private/ObjectOps.cs` | Option definitions (`GetExecOptions`), delegated from `CommandOptions` |
| `Eagle/Library/Components/Private/RuntimeOps.cs` | Command line building and argument escaping |
| `Eagle/Library/Components/Private/ProcessOps.cs` | Process creation, capture, and result handling |
| `Eagle/Library/Components/Private/Enumerations.cs` | `EscapeMode` flags enum |
| `Eagle/lib/Eagle1.0/exec.eagle` | Script-level execution utilities |

## 2. Native Tcl Baseline

Native Tcl `[exec]` treats its arguments as a pipeline specification. The
documented grammar includes `|`, `|&`, `<`, `<<`, `>`, `2>`, `2>@1`, and
related redirection operators, and each distinct command in the pipeline becomes
a subprocess. If the last argument is `&`, Tcl runs the pipeline in the
background and returns a list of subprocess IDs. Tcl does not perform shell
globbing or shell-like substitution on command arguments by default; arguments
are passed as arguments, not reparsed by a shell unless you explicitly invoke
one.

On Windows, Tcl's `[exec]` also performs platform-specific quoting/escaping
transparently. Arguments are mapped to the called program's arguments, quotes
are added where needed, and special characters are escaped. For shell built-ins
like `dir` and `copy`, Tcl requires you to invoke `cmd.exe /c ...` explicitly,
because those are not standalone executables.

Tcl's documented option surface is intentionally small: `-ignorestderr`,
`-keepnewline`, and `--`. All I/O control is done through positional
redirection operators and the pipeline syntax.

## 3. Eagle's Command Syntax

```tcl
exec ?options? arg ?arg ...? ?&?
```

- The first non-option argument is the executable file name.
- Subsequent arguments are passed to the executable.
- A trailing `&` (as a separate argument) runs the process in the background.
- Options begin with `-` and are parsed via Eagle's standard `GetOptions`
  mechanism.
- The `--` marker terminates option processing.
- Eagle explicitly does **not** support Tcl-style pipeline syntax and does
  **not** support Tcl-style redirection syntax such as `< file`, `> file`, or
  `2>&1`. The docs instead point users to options like `-stdin`, `-stdout`,
  `-stderr`, `-shell`, or to invoking a shell manually, e.g.,
  `exec cmd /c "cmd1 | cmd2"`.

## 4. Complete Options Reference

Eagle's `[exec]` has **45+ options**, defined in `ObjectOps.GetExecOptions()`,
organized into the following categories:

| Option | Description |
|--------|-------------|
| **Output Control** | |
| `-keepnewline` | Don't remove trailing newline from output |
| `-nocarriagereturns` | Remove carriage returns from output (Windows) |
| `-trimall` | Trim whitespace from stdout and stderr |
| `-unicode` | Use Unicode encoding for captured output |
| `-ignorestderr` | Don't treat stderr output as an error |
| **Capture Control** | |
| `-nocapture` | Don't capture stdin or stdout (disables both) |
| `-nocaptureinput` | Don't capture/redirect stdin |
| `-nocaptureoutput` | Don't capture stdout/stderr |
| `-overridecapture` | Use custom handlers instead of wrapping built-in ones |
| `-noexitcode` | Don't capture exit code |
| **Variable Storage** | |
| `-processid varName` | Store process ID in variable |
| `-exitcode varName` | Store exit code in variable |
| `-stdin varName` | Read stdin content from variable |
| `-stdout varName` | Store stdout in variable (instead of returning) |
| `-stderr varName` | Store stderr in variable |
| `-stdinobject varName` | Get stdin stream object handle for direct writing |
| `-setall` | Set all output variables even on error |
| **Execution Control** | |
| `-background` | Run process in background (same as trailing `&`) |
| `-shell` | Use ShellExecute (opens documents, URLs, etc.) |
| `-timeout milliseconds` | Maximum time to wait for process exit |
| `-killonerror` | Kill process if interpreter error occurs |
| `-success exitCode` | Expected success exit code (default: none) |
| `-directory path` | Working directory for child process |
| `-windowstyle style` | Window style: Normal, Hidden, Minimized, Maximized |
| **Authentication** | |
| `-domainname name` | Domain for process credentials |
| `-username name` | Username for process credentials |
| `-password secureString` | Password for process credentials |
| **Callbacks** | |
| `-startcallback script` | Script to call when process starts |
| `-stdoutcallback script` | Script to call for each stdout line |
| `-stderrcallback script` | Script to call for each stderr line |
| **Logging** | |
| `-stdoutlogpath path` | Log stdout to file |
| `-stderrlogpath path` | Log stderr to file |
| `-logtag string` | Tag to include in log entries |
| **Argument Processing** | |
| `-commandline` | Build proper command line with quoting |
| `-dequote` | Remove outer quotes from arguments before building command line |
| `-quoteall` | Quote all arguments in command line |
| `-forprocessor` | Use command processor escaping rules |
| `-escaperanges ranges` | Index ranges of arguments to escape |
| `-escapesubstring command` | Custom command for substring escaping |
| `-preprocessarguments command` | Custom command to preprocess arguments |
| **Debugging** | |
| `-debug` | Enable debug output |
| `-trace` | Trace the final command line |
| `-nonormalize` | Don't normalize paths in debug output |
| `-noellipsis` | Don't truncate long values in debug output |
| **Event Processing** | |
| `-noevents` | Don't process events while waiting |
| `-nosleep` | Don't sleep while waiting for process |
| `-userinterface` | Process window messages while waiting |
| `-eventflags flags` | Event flags for waiting |
| **Miscellaneous** | |
| `-nointerpreter` | Don't associate interpreter with process |
| `-nopreviousprocessid` | Don't set interpreter's PreviousProcessId |
| `-objectflags flags` | Object flags for stdin stream handle |
| `-tags list` | Tags for external use |
| `--` | End of options |

## 5. Argument Flow: From Script to Process

The full lifecycle of a call to `[exec]` proceeds through seven stages:

### Stage 1: Option Parsing (`Exec.Execute`, lines 61-65)

```csharp
OptionDictionary options = ObjectOps.GetExecOptions(interpreter);
int argumentIndex = Index.Invalid;

code = interpreter.GetOptions(options, arguments, 0, 1,
    Index.Invalid, true, ref argumentIndex, ref result);
```

Eagle's generic option parser scans the argument list starting at index 1
(index 0 is the command name "exec" itself). It matches each `-flagname`
against the `OptionDictionary` returned by `ObjectOps.GetExecOptions()`.
Options that require values consume the next argument. The parser sets
`argumentIndex` to the index of the first non-option argument (the executable
file name). This is much broader than Tcl's small switch surface of
`-ignorestderr`, `-keepnewline`, and `--`.

### Stage 2: Background Detection (lines 336-349)

```csharp
int argumentStopIndex = argumentCount - 1;
bool background = false;

if (SharedStringOps.SystemEquals(
        arguments[argumentStopIndex],
        Characters.Ampersand.ToString()))
{
    argumentStopIndex--;
    background = true;
}
else if (options.IsPresent("-background"))
{
    background = true;
}
```

If the last argument is literally `"&"`, it is consumed and background mode is
activated. The `-background` option achieves the same effect. This mirrors
Tcl's trailing `&` convention.

### Stage 3: Executable Resolution (lines 351-354)

```csharp
string execFileName = arguments[argumentIndex];

if (!PathOps.IsRemoteUri(execFileName))
    execFileName = PathOps.GetNativePath(execFileName);
```

The first non-option argument is taken as the executable. Forward slashes are
converted to native path separators (on Windows). Remote URIs are preserved
as-is for use with `-shell`.

A second resolution step occurs later inside `ProcessOps.ExecuteProcess()`.
It rejects a null or empty file name, calls
`PathOps.SubstituteOrResolvePath(interpreter, fileName, true, ref remoteUri)`,
and, if the resulting name is an absolute local path, verifies that the file
exists with `File.Exists()`. If the name is not an absolute local path, Eagle
deliberately does **not** pre-verify it, because it may still be something the
OS or shell can resolve (e.g., via PATH lookup). That is why relative or bare
names can still work, while a rooted nonexistent path fails immediately with a
Tcl-compatible "couldn't execute ...: no such file or directory".

### Stage 4: Argument Assembly (lines 371-421)

This is the most critical stage and where Eagle diverges most significantly from
Tcl. There are **three distinct code paths** for assembling the argument string
passed to the child process:

#### Path A: `-commandline` mode (lines 373-386)

```csharp
if (commandLine)
{
    execArguments = RuntimeOps.BuildCommandLine(
        interpreter,
        ArgumentList.GetRangeAsStringList(
            arguments, argumentStartIndex,
            argumentStopIndex, dequote),
        escapeSubStringCommand, quoteAll,
        forProcessor, true, ref done, ref result);
}
```

When `-commandline` is specified, arguments are individually processed by
`RuntimeOps.BuildCommandLine()`, which applies Windows-style command line
quoting and escaping (see Section 7 below). This is the path specifically
intended by Eagle for "build proper command line with quoting" and is the
recommended path when arguments contain spaces, quotes, or backslashes.

#### Path B: `-escaperanges` mode (lines 387-401)

```csharp
else if (escapeRanges != null)
{
    execArguments = RuntimeOps.BuildCommandLine(
        interpreter,
        ArgumentList.GetRangeAsStringList(...),
        escapeRanges,
        interpreter.InternalCultureInfo,
        escapeSubStringCommand, quoteAll,
        forProcessor, true, ref done, ref result);
}
```

When `-escaperanges` is specified (without `-commandline`), a more selective
variant is used. Only arguments whose zero-based indices fall within the
specified comma-separated ranges are quoted/escaped; the remaining arguments are
appended verbatim. This allows fine-grained control, e.g.,
`-escaperanges "1,3-5"` would only escape the 2nd, 4th, 5th, and 6th
arguments. So `-escaperanges` is not "escape everything"; it is selective
argument-level escaping over an otherwise raw command-line string.

#### Path C: Default/simple concatenation (lines 403-407)

```csharp
else
{
    execArguments = ListOps.Concat(arguments,
        argumentStartIndex, argumentStopIndex);
}
```

Without `-commandline` or `-escaperanges`, arguments are simply concatenated
with spaces. **No quoting or escaping is applied.** This is the default behavior
and is the simplest mode, but it means arguments containing spaces will not be
properly delimited for the child process.

Importantly, `ListOps.Concat` is not an argv-preserving join. It joins
arguments with spaces **after trimming leading and trailing whitespace from each
one**, and skips values that become null or empty after trimming. This means the
default Eagle path removes outer whitespace from each argument and drops
empty/whitespace-only arguments entirely. This is a major semantic difference
from native Tcl `[exec]`, where the already-parsed Tcl words are the logical argv
items for the command/pipeline.

#### Priority Rules Among the Argument Options

The branch order in `Exec.cs` is exact: **`-commandline` wins first**; only if
it is absent does Eagle consider `-escaperanges`; only if both are absent does
Eagle fall back to `ListOps.Concat`. This means that `-dequote`, `-quoteall`,
`-forprocessor`, and `-escapesubstring` **only matter when one of the
`BuildCommandLine` paths is active**. In the default `ListOps.Concat` path,
those options are effectively inert because the source never consults them
there.

### Stage 5: Pre-Processing Hook (lines 482-485)

```csharp
code = ProcessOps.PreProcessArguments(
    interpreter, preProcessArgumentsCommand,
    execFileName, directory, ref execArguments,
    ref done, ref result);
```

If `-preprocessarguments` is specified, the given Eagle/Tcl command is invoked
with the executable name, working directory, and assembled argument string
appended as additional arguments. The command can:

- Return normally (`ReturnCode.Ok`): no change to arguments.
- Use `return -code return <value>`: replace the argument string with `<value>`.
- Use `return -code continue`: abort the exec entirely (successfully, setting
  `done = true`).
- Return error: abort with an error.

This is an important difference from Tcl: Eagle exposes a dedicated post-build,
pre-launch rewrite hook for the final argument string.

### Stage 6: Process Execution (lines 503-515)

The assembled arguments are passed to `ProcessOps.ExecuteProcess()`, which
populates a .NET `ProcessStartInfo` (setting `FileName`, `WorkingDirectory`,
and `Arguments`), starts the process, manages I/O capture, waits for
completion (unless background), and collects exit code and output. If `-trace`
is enabled, a trace is emitted containing the final `startInfo.FileName` and
`startInfo.Arguments`. This confirms that Eagle's end product is a `FileName`
plus one command-line string, not a Tcl pipeline graph or an argv vector API.

### Stage 7: Result Handling (lines 586-592)

`ProcessOps.HandleCaptureResults()` populates the requested output variables
(`-processid`, `-exitcode`, `-stdout`, `-stderr`), applies output
transformations (`-nocarriagereturns`, `-trimall`), and checks exit codes
against the `-success` value. If the exit code doesn't match the expected
success code, `errorCode` is set to `{CHILDSTATUS pid exitcode}` and the
command returns an error with the message "child process exited abnormally".

The `-processid` variable is set **even on failure or even if execution was not
attempted**; its value may be zero to indicate that no process was started.

## 6. The `-dequote` Option

`-dequote` is narrow and precise. `ArgumentList.GetRangeAsStringList(..., bool
dequote)` calls `FormatOps.StripOuter(string, Characters.QuotationMark)` when
`dequote` is true. So Eagle is not running a general shell dequoting pass; it
is stripping **one outer pair of double quotes** from each selected argument
before command-line construction. This is useful when arguments arrive
pre-quoted from script construction and need to be re-quoted by the builder
using its own rules.

It operates in both the `-commandline` and `-escaperanges` branches, and
**not** in the default `ListOps.Concat` branch.

## 7. Command Line Building and Escaping in Detail

The core quoting logic resides in `RuntimeOps.AppendCommandLineArgument()`
(lines 3216-3595 of `RuntimeOps.cs`). It implements **Windows
`CommandLineToArgvW`-compatible quoting**, which is the standard convention for
how the Windows C runtime parses command line strings. This is building a
command-line string, not a Tcl list — a deliberately Windows-style rule set.

### 7.1 Special Characters

Three characters are treated as "special" and trigger wrapping an argument in
double quotes:

```csharp
char[] specials = {
    Characters.Space, Characters.QuotationMark, Characters.Backslash
};
```

An argument is wrapped (surrounded with `"..."`) if:
- `-quoteall` is active, **or**
- The argument contains any of: space, double quote, backslash.

### 7.2 Character-by-Character Escaping Rules

For each character in the argument:

1. **Caret (`^`)** with `-forprocessor`: Doubled to `^^` (because `cmd.exe`
   treats `^` as an escape character).

2. **Double quote (`"`)**: Escaped as `\"`. With `-forprocessor`, escaped as
   `\^"` (the caret protects the quote from `cmd.exe` interpretation while the
   backslash protects it from `CommandLineToArgvW` parsing).

3. **Backslash sequences (`\`)**: Follows the `CommandLineToArgvW` convention:
   - A run of `N` backslashes followed by a double quote becomes
     `(2N+1)` backslashes followed by a quote (i.e., each backslash is doubled,
     plus one more to escape the quote). With `-forprocessor`, a caret is also
     inserted before the quote.
   - A run of `N` backslashes **not** followed by a quote passes through as
     `N` backslashes (followed by the next character).
   - A run of `N` backslashes at the **end of an argument** (which will be
     followed by the closing `"`) is doubled to `2N` backslashes in normal
     mode, but **not** doubled in `-forprocessor` mode (since `cmd.exe` does
     not apply `CommandLineToArgvW` doubling rules).

4. **All other characters**: Passed through unchanged.

This is much more explicit than native Tcl's "the platform quoting is done for
you" model.

### 7.3 The `-escapesubstring` Callback

At three points during argument processing — **start** (before the opening
quote), **middle** (each character), and **end** (before the closing quote) —
the method calls `MaybeEscapeSubString()`. If `-escapesubstring` specifies a
command, that command is evaluated with the following appended arguments:

```tcl
<command> <argument_value> <start_index> <stop_index> <escape_mode>
```

The command's return code controls behavior:

| Return Code | Effect |
|-------------|--------|
| `Ok` | Use the result as the replacement text; skip default handling |
| `Error` | Record a warning; continue with default handling |
| `Return` | Stop all further processing immediately |
| `Break` | Append result, then finalize this argument |
| `Continue` | Use default handling (the default) |

This hook is not just advisory; it is a real control point in the escaping
pipeline.

The `EscapeMode` flags passed to the callback indicate context:

```csharp
[Flags]
internal enum EscapeMode
{
    None         = 0x0,
    Start        = 0x100,   // Before the opening quote
    Middle       = 0x200,   // Processing a character within the argument
    End          = 0x400,   // Before the closing quote
    QuoteAll     = 0x1000,  // -quoteall was specified
    ForProcessor = 0x2000,  // -forprocessor was specified
    NoComplain   = 0x4000   // Suppress warnings
}
```

### 7.4 Index Range-Based Selective Escaping

The `-escaperanges` option accepts a comma-separated list of index ranges (e.g.,
`"0,2-4,6"`) specifying which arguments (by zero-based position) should be
processed through the quoting/escaping logic. Arguments whose indices are not in
any range are appended verbatim with only a space separator.

The implementation:
1. `ParseIndexRanges()` parses the range string into an `IndexRangeList` using
   a regex-validated, comma-separated format.
2. `MarkIndexRanges()` builds an `IndexDictionary` mapping each argument index
   to a boolean (true = should be escaped).
3. `AppendCommandLine()` iterates through arguments: marked indices go through
   `AppendCommandLineArgument()`; unmarked indices are appended raw.

## 8. Process Execution Details

### 8.1 ProcessStartInfo Creation

A `ProcessStartInfo` object is constructed with:
- `FileName` and `Arguments` from the resolved values.
- `WorkingDirectory` from the resolved directory (if `-directory` is specified,
  the path is resolved to a full path; otherwise, the current directory of the
  process is used).
- `UseShellExecute` from the `-shell` flag.
- `RedirectStandardInput/Output/Error` based on capture settings.
- `StandardOutputEncoding/StandardErrorEncoding` set to Unicode (UTF-16) when
  `-unicode` is specified; otherwise uses the .NET default encoding.
- `WindowStyle` from the `-windowstyle` option.
- `Domain`, `UserName`, `Password` from authentication options.

The `-shell` option maps directly to `UseShellExecute = true`. This opens
documents, URLs, or folders with the associated application. Using the shell
prevents some other features, especially output capture. This differs from
native Tcl's model, where shell built-ins are reached by explicitly invoking
`cmd.exe /c ...`, not by an option that flips the process-launch mechanism.

### 8.2 I/O Capture and Redirection

`ProcessOps.HandleCaptureOptions()` implements the input/callback setup layer:

- If `-stdin varName` is used, Eagle reads the variable value and later writes
  it to the child's standard input.
- If `-stdinobject varName` is used, Eagle creates an object handle, stores the
  object name back into the variable, and later assigns the child
  `StandardInput` writer into that object.
- The same helper validates `-startcallback`, `-stdoutcallback`, and
  `-stderrcallback`.

The redirection policy in `CreateStartInfo` sets `RedirectStandardOutput` only
when not using the shell and when either the process is foregrounded or a log
path is in use. `RedirectStandardError` is similar, except it is also disabled
by `-ignorestderr`. In other words, Eagle's implementation of `-ignorestderr`
is not just "don't complain later"; it **avoids redirecting/capturing stderr in
the first place**. That achieves a Tcl-like user-facing effect by a different
internal mechanism.

### 8.3 Output Capture Architecture

Eagle uses .NET's asynchronous output reading (`BeginOutputReadLine` /
`BeginErrorReadLine`) with `DataReceivedEventHandler` delegates:

1. **Pre-start setup** (`PreSetupForCapture`): Initializes capture buffers and
   attaches event handlers before the process starts.
2. **Post-start setup** (`PostSetupForCapture`): Begins async reading and
   writes stdin data after the process starts. The standard input stream is
   closed after writing to allow the child process to proceed.
3. **Wait loop**: For foreground processes, processes Eagle events while waiting
   for exit (unless `-noevents`). The process is waited on synchronously to
   ensure all output is captured.
4. **Result collection** (`GetCaptureData`): Retrieves accumulated stdout and
   stderr from the capture buffers. Unless `-keepnewline` is set, a trailing
   newline is stripped from both stdout and stderr.

### 8.4 Callback Integration

Three callback hooks are available, each accepting an Eagle `ICallback` object:

- **`-startcallback`**: Invoked as an `EventHandler` after the process starts
  and I/O redirection is fully set up.
- **`-stdoutcallback`**: Invoked as a `DataReceivedEventHandler` for each line
  of stdout.
- **`-stderrcallback`**: Invoked as a `DataReceivedEventHandler` for each line
  of stderr.

When `-overridecapture` is set, the custom handlers **replace** the built-in
capture handlers rather than wrapping them.

### 8.5 Result Post-Processing

`HandleCaptureResults()` performs the following in order:

1. **Process ID variable**: Always set (even on failure or if execution was not
   attempted); value may be zero.
2. **Carriage return removal** (`-nocarriagereturns`): Strips `\r` from stdout
   and stderr, leaving only `\n` as line separators.
3. **Whitespace trimming** (`-trimall`): Trims all surrounding whitespace from
   stdout and stderr.
4. **Variable population**: Sets `-exitcode`, `-stdout`, and `-stderr` variables
   (only for foreground, non-shell, captured executions). With `-setall`, these
   variables are set even on error.
5. **Exit code checking**: If `-success` was specified and the actual exit code
   differs, sets `errorCode` to `{CHILDSTATUS processId exitCode}`, sets the
   error message to "child process exited abnormally", and returns an error.
   This deliberately adopts Tcl-style signaling, which is why helpers like
   `maybeGetExitCode` work naturally with Eagle.
6. **Error propagation**: On failure, the result is set to the error output.

## 9. Key Differences from Native Tcl's `[exec]`

### 9.1 No Pipeline Syntax

**Tcl:**
```tcl
exec ls -la | grep ".txt" | wc -l
```

**Eagle:** Pipelines are **not supported**. The `|` and `|&` characters have
no special meaning. Each `[exec]` call launches exactly one subprocess. To
achieve pipelines, use the shell:
```tcl
exec -commandline cmd /c "ls -la | grep .txt | wc -l"
# or on Unix:
exec -commandline /bin/sh -c "ls -la | grep .txt | wc -l"
```

### 9.2 No I/O Redirection Operators

**Tcl:**
```tcl
exec program < input.txt > output.txt 2>&1
exec program << "inline input"
exec program >& /dev/null
exec program 2> errors.txt
```

**Eagle:** The `<`, `>`, `>>`, `2>`, `2>>`, `>&`, `>@`, `2>@`, `<@`, and `<<`
redirection operators are **not recognized**. Instead, Eagle provides structured
options:

| Tcl Syntax | Eagle Equivalent |
|------------|------------------|
| `< file` | `-stdin varName` (read file into variable first) |
| `<< string` | `-stdin varName` (set variable to the string) |
| `> file` | Capture result, then write to file |
| `2> file` | `-stderr varName`, then write to file |
| `2>&1` | `-ignorestderr` (to suppress stderr errors), or capture both separately |
| `>@ channel` | `-stdoutcallback` with custom handler |
| `<@ channel` | `-stdinobject varName` for stream access |

### 9.3 Option-Driven vs. Syntax-Driven

Tcl's `[exec]` has three user-facing options: `-ignorestderr`, `-keepnewline`, and `--`. All
I/O control is done through positional redirection operators and the pipeline
syntax.

Eagle's `[exec]` has **45+ options** organized into categories (output control,
capture control, variable storage, execution control, authentication, callbacks,
logging, argument processing, debugging, event processing, and miscellaneous).
Tcl `[exec]` is centered on pipeline execution; Eagle `[exec]` exposes the
underlying process-launch object model.

### 9.4 Command Line Building Model

**Tcl** on Unix: Each argument in the Tcl list becomes a separate element in the
`argv` array passed to `execvp()`. No quoting or escaping is needed because Unix
process creation preserves argument boundaries natively.

**Tcl** on Windows: Tcl's `[exec]` builds a Windows command line string from the
argument list, applying its own quoting rules to preserve argument boundaries
through the `CommandLineToArgvW` parsing step. This is transparent to the user.

**Eagle**: Arguments are assembled into a single command line string passed to
`ProcessStartInfo.Arguments`. By default (without `-commandline`), arguments are
concatenated via `ListOps.Concat` — **no quoting is applied**, whitespace is
trimmed, and empty arguments are dropped. The `-commandline` option must be
explicitly used to get proper Windows-style quoting. This is a significant
behavioral difference:

```tcl
# Tcl: argument boundaries are preserved automatically
exec program "arg with spaces"
# -> program receives one argument: "arg with spaces"

# Eagle (default): arguments are concatenated via ListOps.Concat
exec program "arg with spaces"
# -> ProcessStartInfo.Arguments = "arg with spaces"
# -> program may see three arguments: "arg", "with", "spaces"

# Eagle (with -commandline): proper quoting
exec -commandline program "arg with spaces"
# -> ProcessStartInfo.Arguments = "\"arg with spaces\""
# -> program receives one argument: "arg with spaces"
```

This is the single most important behavioral fact for wrapper scripts. If you
call Eagle `[exec]` in its default mode, the command-line text is not built from
a raw argv array; it is built by a `[concat]`-like pass over the remaining words.
That is why literal quotes or placeholder text can be useful data in Eagle
wrappers in ways that would look suspicious if you were reasoning from native
Tcl alone.

### 9.5 The `-forprocessor` Escaping

Eagle provides explicit support for escaping arguments destined for a command
processor (`cmd.exe`). The `cmd.exe` shell interprets `^` as an escape character
and `"` has special meaning. With `-forprocessor`:

- Carets are doubled: `^` -> `^^`
- Quotes are escaped with both backslash and caret: `"` -> `\^"`
- Trailing backslashes at end of argument are **not** doubled (since `cmd.exe`
  does not apply `CommandLineToArgvW` doubling rules).

This is a feature with no equivalent in Tcl, which handles `cmd.exe` escaping
internally and transparently on Windows.

### 9.6 Exit Code Handling

**Tcl**: A non-zero exit code causes `[exec]` to return `TCL_ERROR`. The error
code is set to `CHILDSTATUS pid exitcode`. There is no way to specify an
alternative "success" exit code.

**Eagle**: By default, exit codes are captured but a non-zero exit code does
**not** automatically cause an error — unless `-success` is used. With
`-success 0`, behavior matches Tcl: a non-zero exit code produces an error
with `errorCode` set to `{CHILDSTATUS pid exitcode}`. The `-exitcode varName`
option allows capturing the exit code into a variable regardless of whether
it's considered a success or failure.

### 9.7 stderr Handling

**Tcl**: Any output on stderr causes `[exec]` to return an error (unless `2>`
or `2>@` redirects it).

**Eagle**: stderr output does **not** automatically cause an error. The
`-ignorestderr` option is available but works differently from Tcl internally:
rather than just suppressing the complaint, it actually **prevents
redirecting/capturing stderr in the first place** (as visible in the
`CreateStartInfo` source, marked `COMPAT: Tcl`). The `-stderr varName` option
captures stderr content separately into a variable.

### 9.8 Background Processes

**Tcl**: `exec program &` returns the process ID(s) of the pipeline.

**Eagle**: `exec program &` (or `exec -background program`) returns the
process ID. The `-processid varName` option can also capture it into a
variable. Eagle additionally supports:
- `-timeout` to kill the process after a specified time.
- `-killonerror` to kill the process if the interpreter encounters an error.
- Background log paths (`-stdoutlogpath`, `-stderrlogpath`) that continue
  logging on a thread-pool thread after the `[exec]` call returns.

### 9.9 Shell Model

**Tcl** tells you to invoke `cmd.exe /c` yourself when you want shell
built-ins.

**Eagle** gives you both explicit shell invocation in the arguments **and** a
separate `-shell` option that flips `UseShellExecute`, primarily for opening
associated documents/URLs, at the cost of output capture.

### 9.10 .NET-Specific Features (No Tcl Equivalent)

| Feature | Description |
|---------|-------------|
| `-shell` | Uses `ShellExecute` to open documents/URLs with associated apps |
| `-windowstyle` | Controls window appearance (Normal, Hidden, Minimized, Maximized) |
| `-domainname/-username/-password` | Run process under different credentials |
| `-unicode` | Use Unicode encoding for captured output |
| `-startcallback/-stdoutcallback/-stderrcallback` | .NET event-based callbacks |
| `-stdinobject` | Direct access to the stdin `StreamWriter` object |
| `-eventflags` | Control Eagle event processing during wait |
| `-userinterface` | Process window messages while waiting (for UI threads) |
| `-objectflags` | Control .NET object handle behavior for stdin stream |
| `-timeout` | Kill process after specified milliseconds |
| `-killonerror` | Kill process on interpreter error |
| `-stdoutlogpath/-stderrlogpath` | Log captured output to files |

### 9.11 Script-Level Extension Hooks

Eagle provides two script-level extension points with no Tcl equivalent:

1. **`-escapesubstring command`**: A Tcl/Eagle command invoked at each phase
   (start, middle, end) during argument escaping. It can override, modify, or
   abort the default escaping behavior. This enables application-specific
   quoting conventions.

2. **`-preprocessarguments command`**: A Tcl/Eagle command invoked after
   argument assembly but before process execution. It receives the executable
   name, working directory, and assembled argument string, and can modify or
   replace the arguments entirely.

### 9.12 Argument Preservation

Native Tcl starts from already-parsed words and maps them to subprocess
arguments/pipeline words, preserving argument boundaries through the process
creation mechanism.

Eagle's default path performs a `[concat]`-style reconstruction that trims each
argument and drops empty/whitespace-only ones entirely. The default Eagle path
is **not argv-preserving** in the same sense. Quote characters in Eagle can be
deliberate **input to Eagle's command-line builder**, not just Tcl syntax. This
is especially true when shaping the default `ListOps.Concat` result or
intentionally feeding the `BuildCommandLine` logic. A review based only on
native Tcl instincts would miss this, because native Tcl `[exec]` does not have
Eagle's second-stage command-line construction model.

## 10. The `exec.eagle` Script Library

The `Eagle.Execute` package (`lib/Eagle1.0/exec.eagle`) provides script-level
utilities for cross-runtime execution:

### `getShellExecutableName`

Returns the correct shell executable path depending on the runtime:
- **.NET Framework**: `[info nameofexecutable]` (the Eagle EXE directly).
- **Mono**: `[lindex [info assembly true] 1]` (the managed assembly, to be
  invoked via `mono`).
- **.NET Core**: `[lindex [info assembly true] 1]` (the managed assembly, to be
  invoked via `dotnet exec`).
- **Native Tcl**: `[info nameofexecutable]`.

### `getRuntimeCommandLine fileName`

Builds the correct prefix for running a managed executable:
- **Mono**: `mono "filename"`
- **.NET Core**: `dotnet exec "filename"`
- **.NET Framework / Tcl**: `"filename"`

### `execShell options args`

Executes a sub-shell (Eagle or Tcl) with proper runtime-specific invocation.
Includes a workaround for .NET Core's issue with empty string arguments
(dotnet/cli#8892): empty `""` arguments are replaced with `" "` (a single
space).

### `maybeGetExitCode value {default ""}`

Extracts the numeric exit code from an `errorCode` value in the
`CHILDSTATUS pid exitcode` format. Works naturally with Eagle because Eagle
adopts Tcl's `CHILDSTATUS` error code convention.

## 11. Practical Rules of Thumb

1. **If you want Eagle's intentional quoting/escaping algorithm**, use
   `-commandline` or `-escaperanges`. These are the code paths designed for
   proper argument boundary preservation.

2. **If you do not use those options**, Eagle falls back to `ListOps.Concat`,
   and then leading/trailing whitespace is trimmed and empty/whitespace-only
   arguments are dropped.

3. **`-dequote`, `-quoteall`, `-forprocessor`, and `-escapesubstring` are only
   effective** when one of the `BuildCommandLine` paths is active. In the
   default `ListOps.Concat` path, they are inert.

4. **Literal double quotes can be deliberate input** to Eagle's command-line
   builder, not just Tcl parser syntax. Wrapper code that looks odd from a
   native Tcl perspective can nevertheless be correct in Eagle.

5. **For pipelines or complex shell commands**, invoke a shell explicitly:
   `exec -commandline /bin/sh -c "..."` or
   `exec -commandline cmd /c "..."`.

## 12. Quick Reference: Decision Guide

| Scenario | Tcl Approach | Eagle Approach |
|----------|-------------|----------------|
| Simple command | `exec ls -la` | `exec ls -la` |
| Arguments with spaces | `exec program "arg with spaces"` (auto-quoted) | `exec -commandline program "arg with spaces"` |
| Pipeline | `exec cmd1 \| cmd2` | `exec -commandline /bin/sh -c "cmd1 \| cmd2"` |
| Input from string | `exec program << "data"` | `set data "data"; exec -stdin data program` |
| Input from file | `exec program < file.txt` | `set d [readFile file.txt]; exec -stdin d program` |
| Output to file | `exec program > file.txt` | `set out [exec program]; writeFile file.txt $out` |
| Stderr capture | `exec program 2> err.txt` | `exec -stderr errVar program` |
| Merge stderr to stdout | `exec program 2>@1` | `exec -ignorestderr program` |
| Background with PID | `set pid [exec program &]` | `exec -processid pid -background program` |
| Timeout | Not built-in | `exec -timeout 5000 program` |
| Open URL | Not built-in | `exec -shell https://example.com` |
| Custom credentials | Not built-in | `exec -username u -password p program` |
| Window style | Not built-in | `exec -windowstyle Hidden program` |
| Selective arg escaping | Not built-in | `exec -escaperanges "1,3" program arg0 arg1 arg2 arg3` |
| Custom escape logic | Not built-in | `exec -commandline -escapesubstring myCmd program args` |
| Argument pre-processing | Not built-in | `exec -preprocessarguments myCmd program args` |

## 13. References

### Eagle Source Files
- `Library/Commands/Exec.cs` — Main command implementation
- `Library/Components/Private/RuntimeOps.cs` — Command line building and argument escaping
- `Library/Components/Private/ProcessOps.cs` — Process creation, capture, and result handling
- `Library/Components/Private/ObjectOps.cs` — Option definitions (`GetExecOptions`)
- `Library/Components/Private/Enumerations.cs` — `EscapeMode` flags enum
- `lib/Eagle1.0/exec.eagle` — Script-level execution utilities

### Eagle Documentation
- [`core_language.md`](core_language.md#cmd-exec) — `[exec]` command syntax and options reference
- [`core_script_library.md`](core_script_library.md#execution-utilities-execeagle) — `Eagle.Execute` package (`exec.eagle` procedures)
- [`core_examples.md`](core_examples.md#ex-exec) — `[exec]` usage examples

### Tcl Reference
- [Tcl 8.5 exec manual](https://www.tcl-lang.org/man/tcl8.5/TclCmd/exec.htm)
- [Tcl 8.6 exec manual](https://www.tcl-lang.org/man/tcl8.6/TclCmd/exec.htm)
