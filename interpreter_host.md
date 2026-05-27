# Eagle Interpreter Host Subsystem: Formal Specification

## Table of Contents

1. [Overview](#1-overview)
2. [Interface Hierarchy](#2-interface-hierarchy)
3. [IInteractiveHost — The Foundational Interface](#3-iinteractivehost--the-foundational-interface)
4. [IDebugHost — Debugging and Diagnostics Output](#4-idebughost--debugging-and-diagnostics-output)
5. [IFileSystemHost — Virtual File System](#5-ifilesystemhost--virtual-file-system)
6. [IStreamHost — Standard Stream Management](#6-istreamhost--standard-stream-management)
7. [IReadHost — Low-Level Input](#7-ireadhost--low-level-input)
8. [IWriteHost — Colored Output](#8-iwritehost--colored-output)
9. [IColorHost — Color Theme Management](#9-icolorhost--color-theme-management)
10. [IPositionHost — Cursor Positioning](#10-ipositionhost--cursor-positioning)
11. [ISizeHost — Terminal Sizing](#11-isizehost--terminal-sizing)
12. [IBoxHost — Formatted Box Output](#12-iboxhost--formatted-box-output)
13. [IDisplayHost — Composite Display Interface](#13-idisplayhost--composite-display-interface)
14. [IInformationHost — Introspection and State Dump](#14-iinformationhost--introspection-and-state-dump)
15. [IThreadHost — Thread Lifecycle](#15-ithreadhost--thread-lifecycle)
16. [IProcessHost — Process Exit Control](#16-iprocesshost--process-exit-control)
17. [IHost — The Master Composite Interface](#17-ihost--the-master-composite-interface)
18. [Supporting Interfaces and Types](#18-supporting-interfaces-and-types)
19. [Host Class Hierarchy (Reference Implementation)](#19-host-class-hierarchy-reference-implementation)
20. [The Interactive Loop — How the Host Drives the REPL](#20-the-interactive-loop--how-the-host-drives-the-repl)
21. [The Virtual File System — Resource Resolution Pipeline](#21-the-virtual-file-system--resource-resolution-pipeline)
22. [Key Enumerations Reference](#22-key-enumerations-reference)
23. [Writing a Compatible Host from Scratch](#23-writing-a-compatible-host-from-scratch)
24. [Appendix A: Box Drawing and Formatted Output](#appendix-a-box-drawing-and-formatted-output)
25. [Appendix B: Color Theme Architecture](#appendix-b-color-theme-architecture)
26. [Appendix C: Thread Safety Requirements](#appendix-c-thread-safety-requirements)
27. [Appendix D: The Featherlight WPF Window Host](#appendix-d-the-featherlight-wpf-window-host)
28. [Appendix E: Featherlight Interactive Usability Features](#appendix-e-featherlight-interactive-usability-features)
29. [Appendix F: The Demo Plugin — Playback-Driven Host](#appendix-f-the-demo-plugin--playback-driven-host)

---

## 1. Overview

The Eagle interpreter host subsystem provides a formal abstraction layer between
the script interpreter engine and its external environment.  The host is the
interpreter's sole conduit for:

- **Interactive I/O** — reading user input, displaying prompts, writing results.
- **File system access** — resolving script files, loading embedded resources.
- **Debugging/introspection** — dumping interpreter state, breakpoint announcements.
- **Thread management** — creating threads, queueing work items.
- **Process lifecycle** — controlling whether the interpreter may exit.
- **Display formatting** — colors, cursor positioning, box-drawing, sizing.

The host abstraction enables the same interpreter core to run unchanged in
radically different environments: a Windows console, an embedded GUI application,
a headless test harness, a TUI on Linux, or a remote debugging session over a
network socket.

### Design Philosophy

1. **IInteractiveHost is the bare minimum.**  Any object implementing only this
   interface can drive the interactive loop (REPL).  The interpreter checks for
   richer interfaces at runtime via `as` casts and degrades gracefully.

2. **Composite interface pattern.**  The full `IHost` interface composes 10+
   sub-interfaces.  Implementors can choose which capabilities to support.

3. **Bool-return convention.**  Most I/O methods return `bool` (true = success,
   false = failure/not-supported).  The host is never required to throw; it may
   silently return false for any unsupported operation.

4. **ReturnCode-return convention.**  Lifecycle and data-retrieval methods return
   `ReturnCode` with a `ref Result error` parameter for structured error
   reporting.

5. **Host flags for capability advertisement.**  The `GetHostFlags()` method
   returns a bitmask describing what the host can actually do, so callers can
   skip unsupported operations without trial-and-error.

### Source Locations

All public interfaces reside in:
```tcl
Library/Interfaces/Public/
```

The reference implementation class hierarchy resides in:
```tcl
Library/Hosts/
```

---

## 2. Interface Hierarchy

```tcl
IIdentifier
  |
  +-- IInteractiveHost                    [foundational]
        |
        +-- IDebugHost                    [debug/error output, clone, cancel/exit]
        +-- IFileSystemHost               [virtual file system: GetStream, GetData]
        +-- IStreamHost                   [stdin/stdout/stderr management]
        +-- IReadHost                     [low-level char/key reading]
        +-- IWriteHost                    [colored text output]
        +-- IColorHost                    [color get/set/reset, themes]
        +-- IPositionHost                 [cursor position get/set]
        +-- ISizeHost                     [terminal window/buffer sizing]
        +-- IBoxHost                      [formatted boxed output]
        +-- IInformationHost              [introspection: WriteXxxInfo methods]
        +-- IThreadHost                   [thread creation, sleep, yield]
        +-- IProcessHost                  [CanExit, CanForceExit, Exiting]

IDisplayHost = IBoxHost + IColorHost + IPositionHost + ISizeHost + IWriteHost

IHost = IDisplayHost + IInteractiveHost + IFileSystemHost + IThreadHost
      + IProcessHost + IStreamHost + IDebugHost + IReadHost + IWriteHost
      + IInformationHost
```

Every sub-interface extends `IInteractiveHost`, which itself extends
`IIdentifier`.  This means every host — no matter how minimal — always has
an identity (Name, Group, Description, Id, etc.) and the core interactive
loop methods.

---

## 3. IInteractiveHost — The Foundational Interface

**File:** `Library/Interfaces/Public/InteractiveHost.cs`
**ObjectId:** `8eba5a3b-6a51-465b-b0a4-32cdfd568970`

This interface defines the **absolute minimum** set of members required to drive
a fully functional interactive REPL.  The comment in the source code explicitly
warns: *do not add members to this interface without careful consideration.*

### 3.1 Processing Lifecycle Hooks

```csharp
ReturnCode BeginProcessing(int levels, ref string text, ref Result error);
ReturnCode EndProcessing(int levels, ref string text, ref Result error);
ReturnCode DoneProcessing(int levels, ref Result error);
```

These three methods form a lifecycle bracket around each iteration of the
interactive loop:

| Method | When Called | Purpose |
|--------|-----------|---------|
| `BeginProcessing` | After input is read, before evaluation | Pre-process or modify the input text; return Error to abort evaluation |
| `EndProcessing` | After evaluation completes | Post-process the text; return Error to signal loop termination |
| `DoneProcessing` | Once, after the loop exits entirely | Final cleanup when the interactive session ends |

**Parameters:**
- `levels` — the current count of active (nested) interactive loops.
- `text` — the script text about to be (or just) evaluated; passed by ref
  so the host can modify it.
- `[error]` — set to a descriptive error message if returning non-Ok.

**Semantics for a minimal host:** Return `ReturnCode.Ok` and leave `text`
unchanged.  The reference implementation (`Default`) does exactly this.

### 3.2 Title Management

```csharp
string Title { get; set; }
bool RefreshTitle();
```

- `Title` — the host's display title (e.g., the console window title bar text).
  The interpreter sets this to show the current script file, debug state, etc.
- `RefreshTitle()` — force the host to update its title display.  Return true
  if the title was successfully refreshed, false otherwise.

### 3.3 Input Redirection Detection

```csharp
bool IsInputRedirected();
```

Returns true if the host's input is being fed from a pipe or file rather than
an interactive terminal.  This controls whether prompts are displayed (they are
typically suppressed when input is redirected, unless `HostFlags.ForcePrompt`
is set).

### 3.4 Prompt Display

```csharp
ReturnCode Prompt(PromptType type, ref PromptFlags flags, ref Result error);
```

Called by the interactive loop to display the command prompt.

- `type` — `PromptType.Start` for the initial prompt, `PromptType.Continue`
  for the continuation prompt (when the user has entered an incomplete script).
- `flags` — `PromptFlags` bitmask; set `PromptFlags.Done` on output to indicate
  the prompt was successfully displayed.
- Returns `ReturnCode.Ok` on success; `ReturnCode.Error` to abort input.

**Reference implementation behavior (Shell layer):**
The `Shell.Prompt()` method looks up a Tcl-style prompt variable (e.g.,
`tcl_prompt1` for start, `tcl_prompt2` for continue) and evaluates its value
as a script.  The output of that script becomes the prompt text.  If no
variable is set, a default prompt like `% ` is used.  Debug mode uses
different variable names (`tcl_prompt3`/`tcl_prompt4`), and queue mode uses
yet another pair (`tcl_prompt5`/`tcl_prompt6`).  This yields up to 8 distinct
prompt variable names, all configurable from script.

### 3.5 Host State

```csharp
bool IsOpen();
bool Pause();
bool Flush();
```

- `IsOpen()` — returns true if the host is ready to accept I/O.  The
  interactive loop checks this before every read/write cycle.
- `Pause()` — pause output (e.g., "Press any key to continue").
- `Flush()` — flush any buffered output to the display.

### 3.6 Flags

```csharp
HeaderFlags GetHeaderFlags();
HostFlags GetHostFlags();
```

- `GetHeaderFlags()` — returns a bitmask controlling which sections of the
  debug header to display (see Section 14).
- `GetHostFlags()` — returns a bitmask advertising the host's capabilities
  (color support, sizing, positioning, etc.).  See Section 22.

### 3.7 Read/Write Levels

```csharp
int ReadLevels { get; }
int WriteLevels { get; }
```

Thread-safe counters tracking the nesting depth of read and write operations.
Used to prevent closing the host while I/O is in progress.  A host
implementation must increment these on entry to read/write operations and
decrement them on exit (typically in a `try/finally` block).

### 3.8 Input

```csharp
bool ReadLine(ref string value);
```

Read one line of text from the user.  Returns true on success (with the line
stored in `value`), false on failure or EOF.  When false is returned with
redirected input, the interactive loop interprets this as end-of-file and
sets the exit flag.

**Critical contract:** This method must block until input is available (or
EOF/cancel occurs).  It must NOT return an incomplete line.

### 3.9 Output

```csharp
bool Write(char value);
bool Write(string value);
bool WriteLine();
bool WriteLine(string value);
bool WriteResultLine(ReturnCode code, Result result);
bool WriteResultLine(ReturnCode code, Result result, int errorLine);
```

Basic text output.  `WriteResultLine` is called after each command evaluation
to display the result to the user.  The `code` parameter indicates success
(`ReturnCode.Ok`) or error (`ReturnCode.Error`), and `errorLine` (if non-zero)
indicates the line number where an error occurred.

---

## 4. IDebugHost — Debugging and Diagnostics Output

**File:** `Library/Interfaces/Public/DebugHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `56c86c61-db4e-43ba-8bc9-938247ec95e6`

### 4.1 Host Cloning

```csharp
IHost Clone();
IHost Clone(Interpreter interpreter);
```

Create a copy of the host, optionally associated with a different interpreter.
Used when spawning child interpreters or creating isolated debugging sessions.

### 4.2 Test Flags

```csharp
HostTestFlags GetTestFlags();
```

Returns test-mode capability flags for the host.

### 4.3 Cancel and Exit

```csharp
ReturnCode Cancel(bool force, ref Result error);
ReturnCode Exit(bool force, ref Result error);
```

- `Cancel` — request cancellation of the current operation.  With `force=true`,
  the cancellation is immediate and non-negotiable.
- `Exit` — request that the host/interpreter exit.  With `force=true`, the exit
  cannot be vetoed.

### 4.4 Debug and Error Output

```csharp
bool WriteDebugLine();
bool WriteDebugLine(string value);
bool WriteDebug(string value);
bool WriteDebug(string value, bool newLine);
bool WriteDebug(string value, bool newLine, ConsoleColor foregroundColor);
bool WriteDebug(string value, bool newLine, ConsoleColor fg, ConsoleColor bg);
bool WriteDebug(char value);
bool WriteDebug(char value, bool newLine);
bool WriteDebug(char value, int count, bool newLine, ConsoleColor fg, ConsoleColor bg);
```

Write diagnostic output.  The `WriteDebug` family is used by `DebugOps.Write()`
internally and directs output to a debug-specific channel (which may differ from
standard output).

The `WriteError` family has an identical signature set and directs output to the
error channel.

### 4.5 Result Output

```csharp
bool WriteResult(ReturnCode code, Result result, bool newLine);
bool WriteResult(ReturnCode code, Result result, bool raw, bool newLine);
bool WriteResult(ReturnCode code, Result result, int errorLine, bool newLine);
bool WriteResult(ReturnCode code, Result result, int errorLine, bool raw, bool newLine);
bool WriteResult(string prefix, ReturnCode code, Result result, int errorLine,
                 bool newLine);
bool WriteResult(string prefix, ReturnCode code, Result result, int errorLine,
                 bool raw, bool newLine);
```

Write evaluation results with formatting appropriate to the return code.
The `raw` parameter bypasses result formatting (replacement of newlines,
truncation with ellipsis, etc.).  The `prefix` parameter prepends a label.

---

## 5. IFileSystemHost — Virtual File System

**File:** `Library/Interfaces/Public/FileSystemHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `052aa850-a9aa-4034-9709-2f43871e99a7`

This interface is the gateway to Eagle's sophisticated virtual file system,
which enables scripts to be loaded from embedded assembly resources, plugins,
resource managers, or the physical file system — all through a single unified
API.

### 5.1 Stream Access

```csharp
HostStreamFlags StreamFlags { get; set; }

ReturnCode GetStream(
    string path,
    FileMode mode,
    FileAccess access,
    FileShare share,
    int bufferSize,
    FileOptions options,
    ref HostStreamFlags hostStreamFlags,
    ref string fullPath,
    ref Stream stream,
    ref Result error);
```

Opens a stream for the given path.  The `hostStreamFlags` parameter is both
input (controlling where to search) and output (indicating where the stream
was actually found: `FoundViaPlugin`, `FoundViaAssembly`, `FoundViaFileSystem`).

The `fullPath` output parameter receives the resolved absolute path of the
resource.

### 5.2 Data Retrieval

```csharp
ReturnCode GetData(
    string name,
    DataFlags dataFlags,
    ref ScriptFlags scriptFlags,
    ref IClientData clientData,
    ref Result result);
```

This is the primary method for the virtual file system.  Given a logical
resource name (e.g., `"init.eagle"`, `"pkgIndex.eagle"`), it searches through
a multi-stage pipeline to locate and return the resource's content.

**Parameters:**
- `name` — the logical name of the resource to find.
- `dataFlags` — controls whether to return `Bytes` or `Text`, and fine-tunes
  the search behavior (`NoStream`, `NoString`, `Verbose`, `Quiet`, etc.).
- `scriptFlags` — (in/out) controls which stages of the search pipeline are
  active and which are skipped.
- `clientData` — (out) receives metadata about the found resource (source
  location, original name, etc.).
- `result` — (out) receives the script text (for `DataFlags.Text`) or error
  message.

See Section 21 for the complete resource resolution pipeline.

---

## 6. IStreamHost — Standard Stream Management

**File:** `Library/Interfaces/Public/StreamHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `9180bb9e-b41a-4d17-be3a-4e8f75313020`

Manages the three standard I/O streams, analogous to stdin/stdout/stderr.

### Properties

```csharp
Stream DefaultIn { get; }     // Original (un-redirected) input stream
Stream DefaultOut { get; }    // Original (un-redirected) output stream
Stream DefaultError { get; }  // Original (un-redirected) error stream

Stream In { get; set; }       // Current input stream (may be redirected)
Stream Out { get; set; }      // Current output stream (may be redirected)
Stream Error { get; set; }    // Current error stream (may be redirected)

Encoding InputEncoding { get; set; }
Encoding OutputEncoding { get; set; }
Encoding ErrorEncoding { get; set; }
```

### Methods

```csharp
bool ResetIn();               // Restore In to DefaultIn
bool ResetOut();              // Restore Out to DefaultOut
bool ResetError();            // Restore Error to DefaultError

bool IsOutputRedirected();    // Is Out different from DefaultOut?
bool IsErrorRedirected();     // Is Error different from DefaultError?

bool SetupChannels();         // Initialize all channels for the interpreter
```

**SetupChannels** is called during interpreter initialization to register the
host's streams as Tcl-style channels (`stdin`, `stdout`, `stderr`).

---

## 7. IReadHost — Low-Level Input

**File:** `Library/Interfaces/Public/ReadHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `fc97d189-df06-4f49-800d-cca84ae0bf32`

```csharp
bool Read(ref int value);
bool ReadKey(bool intercept, ref IClientData value);
```

- `Read` — read a single character (as an int, -1 for EOF).
- `ReadKey` — read a single keypress.  If `intercept` is true, the key is not
  echoed.  The `IClientData` wraps key information (key code, modifiers, etc.)
  in a host-agnostic manner.

Both methods are marked `RECOMMENDED` — a host that only implements
`IInteractiveHost.ReadLine()` is still functional, but these methods enable
richer interactive behavior (e.g., key-by-key processing).

---

## 8. IWriteHost — Colored Output

**File:** `Library/Interfaces/Public/WriteHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `6232cc30-2233-4248-9b4e-4e8bb71bb66a`

Extends the basic Write/WriteLine from `IInteractiveHost` with color support:

```csharp
bool Write(char value, bool newLine);
bool Write(char value, int count);
bool Write(char value, int count, bool newLine);
bool Write(char value, int count, bool newLine, ConsoleColor fg, ConsoleColor bg);
bool Write(char value, ConsoleColor fg, ConsoleColor bg);

bool Write(string value, ConsoleColor fg);
bool Write(string value, ConsoleColor fg, ConsoleColor bg);
bool Write(string value, bool newLine);
bool Write(string value, bool newLine, ConsoleColor fg);
bool Write(string value, bool newLine, ConsoleColor fg, ConsoleColor bg);

bool WriteFormat(StringPairList list, bool newLine, ConsoleColor fg, ConsoleColor bg);

bool WriteLine(string value, ConsoleColor fg);
bool WriteLine(string value, ConsoleColor fg, ConsoleColor bg);
```

The `WriteFormat` method writes a list of name-value pairs in a formatted
manner with the specified colors.

---

## 9. IColorHost — Color Theme Management

**File:** `Library/Interfaces/Public/ColorHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `1532fb48-6373-450a-b1d8-d60b3295ff64`

### Properties

```csharp
bool NoColor { get; set; }    // When true, suppress all color output
```

### Methods

```csharp
bool ResetColors();
bool GetColors(ref ConsoleColor foregroundColor, ref ConsoleColor backgroundColor);
bool AdjustColors(ref ConsoleColor foregroundColor, ref ConsoleColor backgroundColor);
bool SetForegroundColor(ConsoleColor foregroundColor);
bool SetBackgroundColor(ConsoleColor backgroundColor);
bool SetColors(bool foreground, bool background,
               ConsoleColor foregroundColor, ConsoleColor backgroundColor);
```

### Theme-Based Color Management

```csharp
ReturnCode GetColors(string theme, string name, bool foreground, bool background,
                     ref ConsoleColor fg, ref ConsoleColor bg, ref Result error);
ReturnCode SetColors(string theme, string name, bool foreground, bool background,
                     ConsoleColor fg, ConsoleColor bg, ref Result error);
```

The theme/name pair allows looking up colors by category.  The reference
implementation defines comprehensive color themes with categories including:

- **General:** Banner, Box, Debug, Default, Disabled, Enabled, Error, Fatal,
  Footer, Header, Help, Legal, Official, Result, Stable, Trusted, etc.
- **Section-specific:** AnnouncementInfo, ArgumentInfo, CallFrameInfo,
  DebuggerInfo, EngineInfo, HostInfo, etc.
- **Return-code-specific:** Ok, Error, Return, Break, Continue, Exception, etc.
- **Call-frame-specific:** GlobalCallFrame, ProcedureCallFrame,
  CurrentCallFrame, etc.

See Appendix B for the full color theme architecture.

---

## 10. IPositionHost — Cursor Positioning

**File:** `Library/Interfaces/Public/PositionHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `30810314-8094-406d-a023-21c785b4681e`

```csharp
bool ResetPosition();
bool GetPosition(ref int left, ref int top);
bool SetPosition(int left, int top);
bool GetDefaultPosition(ref int left, ref int top);
bool SetDefaultPosition(int left, int top);
```

The position is in character-cell coordinates (0-based, left=column, top=row).
The value `-1` (`_Position.Invalid`) for either coordinate means "do not change
this axis" — for example, `SetPosition(-1, 5)` moves to row 5 without changing
the column.

`GetDefaultPosition`/`SetDefaultPosition` manage a saved "home" position that
can be restored with `ResetPosition`.

---

## 11. ISizeHost — Terminal Sizing

**File:** `Library/Interfaces/Public/SizeHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `9d10e1ab-e22b-4f51-acd7-4328dbc42889`

```csharp
bool ResetSize(HostSizeType hostSizeType);
bool GetSize(HostSizeType hostSizeType, ref int width, ref int height);
bool SetSize(HostSizeType hostSizeType, int width, int height);
```

`HostSizeType` is a flags enum with these relevant combinations:

| Value | Meaning |
|-------|---------|
| `Any` | Let the host decide buffer vs. window, current vs. maximum |
| `BufferCurrent` | Current scroll-back buffer dimensions |
| `BufferMaximum` | Maximum possible scroll-back buffer |
| `WindowCurrent` | Current visible window dimensions |
| `WindowMaximum` | Largest possible window on this display |

The reference implementation uses window dimensions (both width AND height)
to determine the size category (`HostFlags`):

| Min Width | Min Height | Size Category |
|-----------|------------|--------------|
| < 40 | < 10 | `ZeroSize` |
| 40 | 10 | `MinimumSize` |
| 80 | 25 | `CompactSize` |
| 120 | 40 | `FullSize` |
| 160 | 60 | `SuperFullSize` |
| 200 | 75 | `JumboSize` |
| 230 | 90 | `SuperJumboSize` |

Both width and height must meet their respective thresholds for a given
size category to apply.

---

## 12. IBoxHost — Formatted Box Output

**File:** `Library/Interfaces/Public/BoxHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `cafcf71f-cd71-4d10-9658-8862b231815a`

Provides structured, bordered output panels for presenting diagnostic
information.  Used extensively by the debug header display.

### Session Management

```csharp
bool BeginBox(string name, StringPairList list, IClientData clientData);
bool EndBox(string name, StringPairList list, IClientData clientData);
```

### Box Writing (String Content)

```csharp
bool WriteBox(string name, string value, IClientData clientData,
              bool newLine, bool restore, ref int left, ref int top);
bool WriteBox(string name, string value, IClientData clientData,
              int minimumLength, bool newLine, bool restore,
              ref int left, ref int top,
              ConsoleColor fg, ConsoleColor bg);
bool WriteBox(string name, string value, IClientData clientData,
              int minimumLength, bool newLine, bool restore,
              ref int left, ref int top,
              ConsoleColor fg, ConsoleColor bg,
              ConsoleColor boxFg, ConsoleColor boxBg);
```

### Box Writing (Key-Value Pairs)

```csharp
bool WriteBox(string name, StringPairList list, IClientData clientData,
              bool newLine, bool restore, ref int left, ref int top);
// ... (same overload pattern with colors)
```

**Parameters:**
- `name` — logical name of the box (e.g., "DebuggerInfo", "HostInfo").
- `value` or `[list]` — content to display inside the box.
- `restore` — if true, restore the cursor position after drawing.
- `left`, `top` — (in/out) cursor position tracking for layout.
- `minimumLength` — minimum width of the box content area.
- Color parameters — separate colors for content text and box border.

The reference implementation draws boxes using Unicode box-drawing characters
(or ASCII fallbacks), with platform-specific character set selection.  See
Appendix A for details.

---

## 13. IDisplayHost — Composite Display Interface

**File:** `Library/Interfaces/Public/DisplayHost.cs`
**Extends:** `IBoxHost`, `IColorHost`, `IPositionHost`, `ISizeHost`, `IWriteHost`
**ObjectId:** `63e4c2f5-f4f9-4eed-b17e-dae050d790e5`

This is a pure composition interface with **no additional members**.  It exists
to group all display-related capabilities into a single type for convenience.

---

## 14. IInformationHost — Introspection and State Dump

**File:** `Library/Interfaces/Public/InformationHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `38c00d90-386c-4ff5-a9c6-05e572717fd9`

This is the most extensive interface in the host subsystem, providing methods
to dump virtually all internal interpreter state to the user.  Each method
writes a formatted section of diagnostic information.

### 14.1 Position Save/Restore

```csharp
bool SavePosition();
bool RestorePosition(bool newLine);
```

Used to save and restore the cursor position around diagnostic output.

### 14.2 Announcement

```csharp
bool WriteAnnouncementInfo(Interpreter interpreter,
    BreakpointType breakpointType, string value, bool newLine);
```

Writes a breakpoint announcement (e.g., "STOPPED AT BREAKPOINT",
"ENTERING INTERACTIVE LOOP", "LEAVING INTERACTIVE LOOP").

### 14.3 Per-Category Write Methods

Each of the following methods writes one section of diagnostic information.
All follow the same pattern: they accept an `Interpreter`, a `DetailFlags`
bitmask controlling verbosity, a `bool newLine`, and optional foreground/
background colors.

| Method | What It Displays |
|--------|-----------------|
| `WriteArgumentInfo` | Breakpoint argument values |
| `WriteCallFrame` | A single call frame's details |
| `WriteCallFrameInfo` | The current call frame in a box |
| `WriteCallStack` | Traversal of the entire call stack |
| `WriteCallStackInfo` | Call stack summary in a box |
| `WriteDebuggerInfo` | Debugger state (breakpoints, watches, settings) |
| `WriteFlagInfo` | Engine, substitution, event, expression, header flags |
| `WriteHostInfo` | Host properties (dimensions, formatting, colors, names) |
| `WriteInterpreterInfo` | Interpreter properties and statistics |
| `WriteEngineInfo` | Script engine state and counters |
| `WriteEntityInfo` | Counts of commands, procedures, variables, etc. |
| `WriteStackInfo` | Native stack space remaining |
| `WriteControlInfo` | Control flow state (levels, nesting) |
| `WriteTestInfo` | Test framework state (pass/fail counts, etc.) |
| `WriteTokenInfo` | Details of a specific script token |
| `WriteTraceInfo` | Variable/command trace information |
| `WriteVariableInfo` | Variable details (value, links, searches, elements) |
| `WriteObjectInfo` | Opaque object handle details |
| `WriteComplaintInfo` | Accumulated complaint messages |
| `WriteHistoryInfo` | Command history entries (conditional on HISTORY) |
| `WriteCustomInfo` | Host-specific custom diagnostic data |
| `WriteAllResultInfo` | Current and previous result values |
| `WriteResultInfo` | A single named result value |

### 14.4 Header and Footer

```csharp
void WriteHeader(Interpreter interpreter, IInteractiveLoopData loopData,
                 Result result);
void WriteFooter(Interpreter interpreter, IInteractiveLoopData loopData,
                 Result result);
```

These are the master orchestration methods called by the interactive loop in
debug mode.  `WriteHeader` iterates through the enabled `HeaderFlags` and calls
the appropriate `WriteXxxInfo` method for each enabled section, laying them out
with proper sizing and positioning.  `WriteFooter` writes a closing
announcement.

**WriteHeader algorithm:**

1. Check `BeginSection("Header", ...)`.
2. Extract `HeaderFlags` from `loopData`.
3. Convert `HeaderFlags` to `DetailFlags`.
4. If `AutoSize` is set, initialize host flags to determine available space.
5. For each enabled section (StopPrompt, AnnouncementInfo, DebuggerInfo,
   EngineInfo, ControlInfo, EntityInfo, StackInfo, FlagInfo, HostInfo,
   ArgumentInfo, TestInfo, TokenInfo, TraceInfo, VariableInfo, ObjectInfo,
   CallStackInfo, CallFrameInfo, HistoryInfo, OtherInfo, CustomInfo,
   ComplaintInfo, PreviousResultInfo, ResultInfo):
   - Check if the section fits (`DoesHeaderFit`).
   - Call the corresponding `WriteXxxInfo` method.
   - Track position for multi-column layout.
6. If `AutoRetry` is set and sections failed due to space, retry with
   `EmptySection` mode (which uses minimal formatting).
7. Call `EndSection("Header", ...)`.

---

## 15. IThreadHost — Thread Lifecycle

**File:** `Library/Interfaces/Public/ThreadHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `22fdbff0-f93d-4d29-8bd9-1d2707ef3d15`

```csharp
ReturnCode CreateThread(ThreadStart start, int maxStackSize,
    bool userInterface, bool isBackground, bool useActiveStack,
    ref Thread thread, ref Result error);

ReturnCode CreateThread(ParameterizedThreadStart start, int maxStackSize,
    bool userInterface, bool isBackground, bool useActiveStack,
    ref Thread thread, ref Result error);

ReturnCode QueueWorkItem(ThreadStart callback, QueueFlags flags,
    ref Result error);

ReturnCode QueueWorkItem(WaitCallback callback, object state,
    QueueFlags flags, ref Result error);

bool Sleep(int milliseconds);
bool Yield();
```

The host controls thread creation to allow for environment-specific thread
policies (e.g., setting apartment state for UI threads, enforcing stack size
limits, using custom thread pools).

---

## 16. IProcessHost — Process Exit Control

**File:** `Library/Interfaces/Public/ProcessHost.cs`
**Extends:** `IInteractiveHost`
**ObjectId:** `64ebb0dc-03a6-4860-8b85-350af13bd36d`

```csharp
bool CanExit { get; set; }
bool CanForceExit { get; set; }
bool Exiting { get; set; }
```

- `CanExit` — whether the `[exit]` command is permitted.
- `CanForceExit` — whether forced exit (bypassing cleanup) is permitted.
- `Exiting` — set to true when the interpreter is in the process of exiting.

An embedded host can set `CanExit = false` to prevent scripts from terminating
the hosting application.

---

## 17. IHost — The Master Composite Interface

**File:** `Library/Interfaces/Public/Host.cs`
**ObjectId:** `0b056d8f-c52e-4cb9-a92d-ddc478a00be7`

Combines all sub-interfaces into a single comprehensive type:

```csharp
public interface IHost :
    IDisplayHost, IInteractiveHost, IFileSystemHost,
    IThreadHost, IProcessHost, IStreamHost, IDebugHost,
    IReadHost, IWriteHost, IInformationHost
```

### Additional Members

```csharp
string Profile { get; set; }
string DefaultTitle { get; set; }
HostCreateFlags HostCreateFlags { get; set; }

bool UseAttach { get; set; }     // Attach to existing console (vs. alloc new)
bool UseForce { get; set; }      // Force console open/attach
bool NoTitle { get; set; }       // Suppress title changes
bool NoIcon { get; set; }        // Suppress icon changes
bool NoProfile { get; set; }     // Skip profile loading
bool NoCancel { get; set; }      // Skip Ctrl-C handler setup
bool Echo { get; set; }          // Echo typed input

StringList QueryState(DetailFlags detailFlags);

bool Beep(int frequency, int duration);
bool IsIdle();
bool Clear();
bool ResetHostFlags();

ReturnCode ResetHistory(ref Result error);
ReturnCode GetMode(ChannelType channelType, ref uint mode, ref Result error);
ReturnCode SetMode(ChannelType channelType, uint mode, ref Result error);

ReturnCode Open(ref Result error);
ReturnCode Close(ref Result error);
ReturnCode Discard(ref Result error);
ReturnCode Reset(ref Result error);

bool BeginSection(string name, IClientData clientData);
bool EndSection(string name, IClientData clientData);
```

### Key Methods

- **`QueryState`** — returns a `StringList` of key-value pairs describing the
  host's internal state: flags, read/write levels, console dimensions, colors,
  redirection status, reference counts, etc.  Invaluable for debugging.

- **`Open`/`Close`** — manage the host's I/O resources.  On Windows, `Open`
  can allocate or attach to a console window.  `Close` releases it.

- **`BeginSection`/`EndSection`** — bracket a named output section for layout
  management.  The header writer uses these to manage multi-column display.

- **`GetMode`/`SetMode`** — get/set the raw console mode (Windows console mode
  flags) for a given channel (input, output, error).

---

## 18. Supporting Interfaces and Types

### 18.1 IHostData

**File:** `Library/Interfaces/Public/HostData.cs`

```csharp
public interface IHostData : IIdentifier, IHaveInterpreter, ITypeAndName
{
    ResourceManager ResourceManager { get; set; }
    string Profile { get; set; }
    HostCreateFlags HostCreateFlags { get; set; }
}
```

Configuration data passed to host constructors.  Contains the interpreter
reference, resource manager for embedded resources, profile name, and creation
flags.

### 18.2 INewHostCallback

**File:** `Library/Interfaces/Public/NewHostCallback.cs`

```csharp
public interface INewHostCallback
{
    IHost NewHost(IHostData hostData);
}
```

Factory interface for custom host creation.  Implement this to provide a
custom host when an interpreter is created.

### 18.3 IInteractiveLoopData

**File:** `Library/Interfaces/Public/InteractiveLoopData.cs`

State container for each interactive loop invocation:

```csharp
public interface IInteractiveLoopData : IIdentifier, IHaveClientData
{
    bool Debug { get; set; }
    IEnumerable<string> Args { get; set; }
    ReturnCode Code { get; set; }
    BreakpointType BreakpointType { get; set; }
    string BreakpointName { get; set; }
    IToken Token { get; set; }
    ITraceInfo TraceInfo { get; set; }
    EngineFlags EngineFlags { get; set; }
    SubstitutionFlags SubstitutionFlags { get; set; }
    EventFlags EventFlags { get; set; }
    ExpressionFlags ExpressionFlags { get; set; }
    HeaderFlags HeaderFlags { get; set; }
    ArgumentList Arguments { get; set; }
    bool Exit { get; set; }

    void SetExit();
    void SetCode(ReturnCode code);
}
```

### 18.4 IInteractiveLoopCallback

```csharp
public interface IInteractiveLoopCallback
{
    ReturnCode InteractiveLoop(Interpreter interpreter,
        IInteractiveLoopData loopData, ref Result result);
}
```

Allows external code to provide a custom interactive loop implementation.

### 18.5 IInteractiveLoopManager

```csharp
public interface IInteractiveLoopManager
{
    InteractiveLoopCallback InteractiveLoopCallback { get; set; }
}
```

Manages the interactive loop callback registration on the interpreter.

---

## 19. Host Class Hierarchy (Reference Implementation)

The reference implementation in `Library/Hosts/` uses a layered abstract base
class design.  Each layer adds specific capabilities:

```tcl
Default (abstract, ~11,500 lines)
  |  Base implementation of all IHost interface members.
  |  Box drawing, color theme, section management, output formatting.
  |  BeginProcessing/EndProcessing/DoneProcessing (return Ok, no-op).
  |  WriteHeader/WriteFooter orchestration.
  |  All WriteXxxInfo methods with StringPairList formatting.
  |
  +-- Engine (abstract, ~370 lines)
  |     Threading support: CreateThread, QueueWorkItem, Sleep, Yield.
  |     Adds HostFlags: Thread, WorkItem, Sleep, Yield.
  |
  +-- File (abstract, ~4,300 lines)
  |     Virtual file system implementation.
  |     GetStream (delegates to RuntimeOps.NewStream).
  |     GetData (full multi-stage resource pipeline).
  |     Resource manager setup: Library, Packages, Kit, Application.
  |     Plugin resource loading.
  |     Assembly manifest resource loading.
  |     Adds HostFlags: Stream, Data.
  |
  +-- Profile (abstract, ~270 lines)
  |     Host profile file loading.
  |     HostProfileFileName, HostProfileFileEncoding.
  |     Loads settings via SettingsOps.LoadForHost().
  |     Adds HostFlags: Profile.
  |
  +-- Shell (abstract, ~760 lines)
  |     Prompt variable name mapping (8 prompt types).
  |     Console title building from assembly metadata.
  |     Theme-based color management (GetColors/SetColors by name).
  |     Prompt() implementation using prompt variables.
  |     Adds HostFlags: Prompt, Title.
  |
  +-- Core (abstract, ~300 lines)
        Read/write level tracking (thread-safe Interlocked).
        EnterReadLevel/ExitReadLevel, EnterWriteLevel/ExitWriteLevel.
        SafeGetInterpreter().
        Clone() implementation.
        |
        +-- Console (concrete, ~5,900 lines)
        |     Full System.Console integration.
        |     ReadLine via System.Console.ReadLine().
        |     Write via System.Console.Write/WriteLine().
        |     Native Win32 WriteConsoleW support (Windows).
        |     Console cancel (Ctrl-C) handler.
        |     Console icon/title management.
        |     Color save/restore via System.Console.
        |     Cursor positioning via System.Console.
        |     Window/buffer sizing.
        |     Input/output redirection detection.
        |     Console mode get/set (native Windows).
        |     Open/Close/Reset for console lifecycle.
        |     QueryState with comprehensive state dump.
        |
        +-- Diagnostic (concrete, ~1,100 lines)
              Trace-based I/O (no interactive console).
              WriteDebug via DebugOps.
              WriteError via TraceOps.
              Returns 0 bytes for all reads.
              Used for automated/headless scenarios.
```

### Standalone Implementations (not in Default hierarchy)

| Class | Purpose | Lines |
|-------|---------|-------|
| `Null` | No-op host. Most methods throw `NotImplementedException` or return error. Used when no I/O is needed. | ~2,400 |
| `Wrapper` | Decorator pattern. Wraps another `IHost` and delegates all calls. Supports optional ownership (disposal). | ~2,900 |
| `Fake` | Test host. Throws `NotImplementedException` for most methods. Virtual properties for test customization. | ~2,600 |

### External Host Implementations

The host abstraction is designed for extension beyond the reference
implementations.  A notable example is the Featherlight WPF Window host,
which extends `Core` with a full WPF-based windowed environment featuring
multiple managed windows, stream-wrapped I/O, and trace listener integration.
See [Appendix D](#appendix-d-the-featherlight-wpf-window-host) for a
comprehensive analysis of this implementation.

---

## 20. The Interactive Loop — How the Host Drives the REPL

**Source:** `Library/Components/Public/Interpreter.cs` (methods `InteractiveLoop`
and `PrivateInteractiveLoop`, approximately lines 95875-97488)

### 20.1 Entry Point

```tcl
Interpreter.InteractiveLoop(IInteractiveLoopData loopData)
  -> Pushes interpreter onto global active stack
  -> Manages global interactive loop levels
  -> Calls PrivateInteractiveLoop(loopData)
```

### 20.2 Initialization Phase

1. **Validate** interpreter and loopData; check exit flag.
2. **Verify** same AppDomain (cross-domain support exists).
3. **Retrieve** the IInteractiveHost from the interpreter.
4. **Check** native stack space.
5. **Push** interactive loop level via `PushLocalInteractiveLoopLevel()`:
   - Save current InteractiveLoopData.
   - Set `InternalInteractive = true`.
   - Enable interactive input.
   - Increment `ActiveInteractiveLoops` and `TotalInteractiveLoops`.

### 20.3 Shell Startup

On the first loop iteration:
- Initialize shell startup files.
- Set debugger active level (if debug mode).
- Evaluate interactive shell initialization scripts.
- Check exit flag after initialization.

### 20.4 Header Display

If in debug mode:
- Call `IInformationHost.WriteHeader(interpreter, loopData, result)`.
- This outputs the complete debugger state display (see Section 14).

### 20.5 Main REPL Loop

```tcl
while (!IsInteractiveLoopDone(interpreter, done)):

    1. TRACK iteration count.
    2. DUMP debugger commands (if enabled).
    3. WAIT on paused interactive loop.

    4. GET INPUT via GetInteractiveInput():
       a. Reset script cancellation and debugger halt flags.
       b. Display start prompt: interactiveHost.Prompt(PromptType.Start, ...).
       c. Input reading loop:
          i.   Check for saved text from previous iteration.
          ii.  Check for injected debugger commands.
          iii. Call interactiveHost.ReadLine(ref value).
          iv.  Handle EOF (set exit flag if redirected input ends).
          v.   Handle cancellation.
          vi.  Check completeness: Parser.IsComplete().
          vii. If incomplete, display continue prompt and loop.
       d. Return the complete, validated input.

    5. CALL interactiveHost.BeginProcessing(levels, ref text, ref error).
       - If returns Error, exit the loop (sets done = true).

    6. CHECK interactive command dispatch:
       - If input starts with '#', dispatch via InteractiveOps.DispatchCommand().
       - Commands: #go, #run, #break, #halt, #done, #exit, #reset, etc.
       - If dispatched, skip evaluation and continue loop.

    7. EVALUATE script:
       - Start script timeout thread (if enabled).
       - Call Engine.EvaluateScript(text, flags...).
       - Stop timeout thread.

    8. MANAGE halt flag:
       - If halted at outermost loop with zero eval nesting, reset halt.
       - If still halted, exit loop.

    9. DISPLAY RESULT:
       - Call interactiveHost.WriteResultLine(code, result, errorLine).

   10. CALL interactiveHost.EndProcessing(levels, ref text, ref error).
       - If returns Error, exit loop.
```

### 20.6 Cleanup Phase

1. Call `interactiveHost.DoneProcessing(levels, ref error)`.
2. Restore saved engine flags.
3. Stop GC test thread (if started).
4. Write footer: `IInformationHost.WriteFooter(interpreter, loopData, result)`.
5. Pop interactive loop level via `PopLocalInteractiveLoopLevel()`.
6. Reset halt flag.

### 20.7 Nested Interactive Loops

The interactive loop supports arbitrary nesting.  When the debugger breaks
into the interactive loop, it creates a new `InteractiveLoopData` with
`Debug = true` and the breakpoint context, then calls `InteractiveLoop`
recursively.  The `levels` parameter passed to `BeginProcessing`/
`EndProcessing`/`DoneProcessing` reflects the nesting depth.

---

## 21. The Virtual File System — Resource Resolution Pipeline

**Source:** `Library/Hosts/File.cs` (method `GetData`, approximately lines
3614-4241)

### 21.1 Overview

When the interpreter needs a script file (e.g., `init.eagle`), it calls
`IFileSystemHost.GetData(name, dataFlags, ref scriptFlags, ref clientData,
ref result)`.  The `File` host implementation searches through up to 12
subsystems in a defined order, stopping at the first successful match.

### 21.2 Search Pipeline

The pipeline uses two tracking arrays:
- `bool[] @checked` (12 elements) — which subsystems were checked.
- `int[] counts` (12 elements) — how many lookups each subsystem performed.

**Stage 1: Bundle Manager** (indices 0-1)
- Security-critical check via `IBundleManager`.
- Only active when the DATA compile flag is set.

**Stage 2: Snippet Manager** (indices 2-3)
- Checks the interpreter's snippet manager.
- Marked as **SECURITY critical** in the source code.
- Returns bytes, XML, or text based on snippet flags.

**Stage 3: File System** (indices 4-5)
- Calls `PathOps.Search()` to find the file on disk.
- Optionally searches parent directories (`PathOps.SearchParents()`).
- Skipped if `ScriptFlags.NoFileSystem` is set.

**Stage 4: Plugin Resources** (indices 6-7)
- Iterates through loaded plugins (excluding system plugins).
- For each plugin, tries:
  - Plugin-qualified name: `"{pluginName}.{resourceName}"`
  - Raw resource name: `"{resourceName}"`
- Tries both `IPlugin.GetStream()` (binary) and `IPlugin.GetString()` (text).
- Skipped if `ScriptFlags.NoPlugins` is set.

**Stage 5: Resource Managers** (indices 8-9)
- Searches through up to 6 resource managers in this order:
  1. **Host ResourceManager** — extension/custom (null base name).
  2. **Application ResourceManager** — `application.resources`.
  3. **Kit ResourceManager** — `kit.resources`.
  4. **Packages ResourceManager** — `packages.resources`.
  5. **Library ResourceManager** — `library.resources` (core scripts).
  6. **Interpreter ResourceManager** — interpreter-associated resources.
- Each manager is individually skippable via `ScriptFlags.NoHostResourceManager`,
  `NoApplicationResourceManager`, `NoLibraryResourceManager`,
  `NoPackagesResourceManager`, `NoKitResourceManager`.
- The entire stage is skipped if `ScriptFlags.NoResourceManager` is set.

**Stage 6: Assembly Manifest Resources** (indices 10-11)
- Direct access to embedded assembly manifest resources.
- Tries `Assembly.GetManifestResourceStream()` for binary data.
- Falls back to `GetString()` if stream fails.
- Skipped if `ScriptFlags.NoAssemblyManifest` is set.

### 21.3 Resource Name Generation

The `GetDataResourceNames()` method generates up to 16 candidate resource
names for each search, covering variations:
- Qualified vs. non-qualified names.
- Full path vs. file name only.
- Library path mappings (`library/` to `lib/`, `tests/` to `lib/`).
- Package type prefixes (Loader, Library, Test, Kit, Automatic).

### 21.4 Embedded Script Library

Eagle embeds its core script library as .NET resources.  The key resource
files and their base names:

| Base Name | Resource File | Contains |
|-----------|--------------|----------|
| `[library]` | `library.resources` | Core library scripts (`init.eagle`, etc.) |
| `packages` | `packages.resources` | Core script packages (`pkgIndex.eagle`, etc.) |
| `kit` | `kit.resources` | Kit packages |
| `application` | `application.resources` | Vendor/application packages |

The `HaveResourceBaseName()` method checks if a resource file exists in the
assembly's manifest by looking for `"{baseName}.resources"` in the cached
`resourceNames` dictionary.

### 21.5 Isolation Support

When running in an isolated AppDomain (e.g., for sandboxed plugins), the host
returns `null` for its resource manager and assembly references to prevent
cross-AppDomain marshalling issues.  The `MaybeGetResourceManager()` and
`MaybeGetAssembly()` methods check `AppDomainOps.IsIsolated()` before
returning these references.

---

## 22. Key Enumerations Reference

### 22.1 HostCreateFlags

Controls host creation behavior.  Key values:

| Flag | Meaning |
|------|---------|
| `Disable` | Do not create an interpreter host |
| `Clone` | Clone the provided host instead of using it directly |
| `NoConsole` | Do not create a console-based host |
| `NoDiagnostic` | Do not create a diagnostic host |
| `UseWrapper` | Wrap the host in a Wrapper |
| `NoColor` | Suppress color output |
| `NoTitle` | Do not change the console title |
| `NoIcon` | Do not change the console icon |
| `NoProfile` | Do not load the host profile |
| `NoCancel` | Do not setup Ctrl-C handling |
| `Echo` | Echo typed input |
| `CanExit` | Allow `[exit]` command |
| `CanForceExit` | Allow forced exit |
| `UseLibrary` | Prefer embedded scripts over file system |
| `ResourceManager` | Initialize resource managers |
| `ForShellUse` | Preset for shell (REPL) usage |
| `ForEmbeddedUse` | Preset for embedded usage |
| `ForTestUse` | Preset for test framework usage |

### 22.2 HostFlags

Advertises host capabilities.  Key categories:

**Capability flags:**
`Complain`, `Verbose`, `Debug`, `Test`, `Prompt`, `ForcePrompt`, `Title`,
`Thread`, `Exit`, `WorkItem`, `Stream`, `Data`, `Profile`, `Sleep`, `Yield`,
`CustomInfo`, `Resizable`, `Sizing`, `Positioning`, `QueryState`,
`Recording`, `Playback`, `MultipleLineInput`.

**Environment flags:**
`HighLatency`, `LowBandwidth`, `Text`, `Graphical`, `Virtual`.

**Color flags:**
`Monochrome`, `Color`, `TrueColor`, `ReversedColor`, `AdjustColor`,
`NoColorNewLine`, `NoSetForegroundColor`, `NoSetBackgroundColor`.

**Size flags:**
`ZeroSize`, `MinimumSize`, `CompactSize`, `FullSize`, `SuperFullSize`,
`JumboSize`, `SuperJumboSize`, `UnlimitedSize`.

**Auto-flush flags:**
`AutoFlushHost`, `AutoFlushWriter`, `AutoFlushOutput`, `AutoFlushError`.

**Error flags:**
`ReadException`, `WriteException`, `TreatAsFatalError`.

### 22.3 HeaderFlags

Controls which sections appear in the debug header.  Individual sections:

`StopPrompt`, `GoPrompt`, `AnnouncementInfo`, `DebuggerInfo`, `EngineInfo`,
`ControlInfo`, `EntityInfo`, `StackInfo`, `FlagInfo`, `ArgumentInfo`,
`TokenInfo`, `TraceInfo`, `InterpreterInfo`, `CallStack`, `CallStackInfo`,
`VariableInfo`, `ObjectInfo`, `HostInfo`, `TestInfo`, `CallFrameInfo`,
`ResultInfo`, `PreviousResultInfo`, `ComplaintInfo`, `HistoryInfo`,
`OtherInfo`, `CustomInfo`.

**Composite presets:**
- `Level1` — AnnouncementInfo, DebuggerInfo, ResultInfo.
- `Level2` — ControlInfo, OtherInfo.
- `Level3` — ArgumentInfo, TokenInfo, TraceInfo, VariableInfo, ObjectInfo, CallFrameInfo, PreviousResultInfo, ComplaintInfo, CustomInfo.
- `Level4` — InterpreterInfo, CallStackInfo.
- `Level5` — EngineInfo, FlagInfo.
- `AllInfo` — all individual section flags (includes EntityInfo, StackInfo, HostInfo, TestInfo, CallStack, HistoryInfo, and others not in any Level).
- `Show` — Level1 | Level2 | Level3 | Level4 | Level5 (all levels combined).

**Control flags:**
- `AutoSize` — automatically determine content sizing.
- `AutoRetry` — retry failed sections with relaxed constraints.
- `EmptySection` / `EmptyContent` — allow empty sections/content.

### 22.4 DetailFlags

Fine-grained control over information dump verbosity.  Over 60 individual
flags controlling specific diagnostic subsystems including:
`CallFrameLinked`, `CallFrameVariables`, `CallStackAllFrames`,
`DebuggerBreakpoints`, `HostDimensions`, `HostFormatting`, `HostColors`,
`HostNames`, `HostState`, `EngineNative`, `TraceCached`, `VariableLinks`,
`VariableSearches`, `VariableElements`, and many subsystem-specific flags
for ListOps, HashOps, ProcessOps, ThreadOps, etc.

### 22.5 QueueFlags

Controls behavior of `IThreadHost.QueueWorkItem()`:

```tcl
None           = 0x0     // No special behavior
Invalid        = 0x1     // Do not use
Asynchronous   = 0x10    // For test use only
WaitForStart   = 0x20    // Wait for the pool thread to actually start running
```

### 22.6 HostStreamFlags

Controls the virtual file system search behavior in `IFileSystemHost.GetStream()`
and `GetData()`.  Key values:

| Flag | Meaning |
|------|---------|
| `LoadedPlugins` | Search loaded plugin assemblies |
| `EntryAssembly` | Search the entry assembly manifest |
| `ExecutingAssembly` | Search the executing assembly manifest |
| `ResolveFullPath` | Resolve the resource to a full file system path |
| `AssemblyQualified` | Use assembly-qualified resource names |
| `PreferFileSystem` | Check the file system before embedded resources |
| `SkipFileSystem` | Do not check the file system at all |
| `Script` | Resource is a script (affects name generation) |
| `Open` | Resource is being opened via the `[open]` command |
| `FoundViaPlugin` | (Output) Resource was found in a plugin |
| `FoundViaAssembly` | (Output) Resource was found in an assembly manifest |
| `FoundViaFileSystem` | (Output) Resource was found on the file system |

The `FoundMask` (`FoundViaPlugin | FoundViaAssembly | FoundViaFileSystem`)
indicates the source of a successfully resolved resource.

### 22.7 PromptType

```tcl
Invalid = -1    // Do not use
None    =  0    // No prompt
Start   =  1    // Initial input prompt (e.g., "% ")
Continue =  2   // Continuation prompt (e.g., "> ")
```

### 22.8 PromptFlags

```tcl
Debug        // Prompt is for the interactive debugger
Queue        // Prompt is for queued (async) input mode
CommandCount // Show total interactive command count in prompt
ActiveLoops  // Show number of active interactive loops in prompt
Interpreter  // Show interpreter ID in prompt
Done         // (Output) Prompt was successfully displayed
Partial      // (Output) Part of prompt was displayed
Trace        // Emit trace output during prompt
```

---

## 23. Writing a Compatible Host from Scratch

This section provides a practical guide for implementing a new Eagle
interpreter host — for example, a TUI-based host for Linux using a library
like `Terminal.Gui` or raw ANSI escape sequences.

### 23.1 Minimum Viable Host (IInteractiveHost only)

The fastest path to a working host is to implement only `IInteractiveHost`.
The interpreter will check for richer interfaces at runtime and degrade
gracefully.

```csharp
using Eagle._Attributes;
using Eagle._Interfaces.Public;

[ObjectId("your-guid-here")]
public class MyTuiHost : IInteractiveHost
{
    // --- IIdentifier members ---
    public long Id { get; set; }
    public string Name { get; set; } = "MyTuiHost";
    public string Group { get; set; }
    public string Description { get; set; }
    // ... other IIdentifier members ...

    // --- Processing lifecycle (no-op is valid) ---
    public ReturnCode BeginProcessing(
        int levels, ref string text, ref Result error)
    {
        return ReturnCode.Ok;  // Accept all input as-is
    }

    public ReturnCode EndProcessing(
        int levels, ref string text, ref Result error)
    {
        return ReturnCode.Ok;  // No post-processing
    }

    public ReturnCode DoneProcessing(int levels, ref Result error)
    {
        return ReturnCode.Ok;  // No final cleanup
    }

    // --- Title ---
    public string Title { get; set; }
    public bool RefreshTitle() => true;  // Update your TUI title bar

    // --- Redirection detection ---
    public bool IsInputRedirected() => false;  // Or check actual state

    // --- Prompt ---
    public ReturnCode Prompt(
        PromptType type, ref PromptFlags flags, ref Result error)
    {
        string prompt = (type == PromptType.Start) ? "% " : "> ";
        Write(prompt);
        flags |= PromptFlags.Done;
        return ReturnCode.Ok;
    }

    // --- Host state ---
    public bool IsOpen() => true;
    public bool Pause() => true;
    public bool Flush() => true;

    // --- Flags ---
    public HeaderFlags GetHeaderFlags() => HeaderFlags.Default;
    public HostFlags GetHostFlags() => HostFlags.Text;

    // --- Read/Write levels ---
    private int readLevels, writeLevels;
    public int ReadLevels => readLevels;
    public int WriteLevels => writeLevels;

    // --- Input ---
    public bool ReadLine(ref string value)
    {
        Interlocked.Increment(ref readLevels);
        try
        {
            string line = Console.ReadLine();  // Or your TUI input method
            if (line == null) return false;     // EOF
            value = line;
            return true;
        }
        finally
        {
            Interlocked.Decrement(ref readLevels);
        }
    }

    // --- Output ---
    public bool Write(char value) { Console.Write(value); return true; }
    public bool Write(string value) { Console.Write(value); return true; }
    public bool WriteLine() { Console.WriteLine(); return true; }
    public bool WriteLine(string value) { Console.WriteLine(value); return true; }

    public bool WriteResultLine(ReturnCode code, Result result)
    {
        if (result != null)
            WriteLine(result.ToString());
        return true;
    }

    public bool WriteResultLine(ReturnCode code, Result result, int errorLine)
    {
        return WriteResultLine(code, result);
    }
}
```

### 23.2 Registering Your Host

To use your custom host with an interpreter:

```csharp
// Method 1: Via INewHostCallback at creation time
Interpreter.Create(
    new NewHostCallback(hostData => new MyTuiHost()),
    ref result);

// Method 2: Via HostCreateFlags and IHostData
var hostData = new HostData(
    "MyTuiHost", null, null, null, typeof(MyTuiHost),
    interpreter, null, null, HostCreateFlags.None);
IHost host = new MyTuiHost(hostData);
interpreter.Host = host;
```

### 23.3 Extending to Full IHost

To support the full range of interpreter features, extend the Default base
class or implement IHost directly.  The recommended approach for a TUI host:

**Option A: Extend the class hierarchy**

```csharp
// Inherit from Core (or any layer above it) and override
// the abstract/virtual methods for your TUI framework.
public class MyTuiHost : Eagle._Hosts.Core
{
    public MyTuiHost(IHostData hostData) : base(hostData)
    {
        // Initialize your TUI framework here
    }

    // Override ReadLine for TUI input
    public override bool ReadLine(ref string value) { ... }

    // Override Write methods for TUI output
    public override bool Write(string value) { ... }
    public override bool WriteLine(string value) { ... }

    // Override color methods for TUI colors
    // Override position methods for TUI cursor control
    // Override size methods for TUI window sizing
    // etc.
}
```

**Option B: Use the Wrapper pattern**

```csharp
// Wrap an existing host and override specific behaviors
public class MyTuiHost : Eagle._Hosts.Wrapper
{
    public MyTuiHost(IHost baseHost) : base(baseHost)
    {
        // Your TUI-specific initialization
    }

    // Override only the methods you want to customize
    public override bool ReadLine(ref string value) { ... }
    public override bool Write(string value) { ... }
}
```

### 23.4 TUI Host Implementation Checklist

For a fully functional TUI-based host on Linux, implement these capabilities:

**Essential (for basic REPL):**

- [ ] `ReadLine()` — read a line from TUI input widget.
- [ ] `Write()`/`WriteLine()` — write to TUI output area.
- [ ] `WriteResultLine()` — display command results.
- [ ] `Prompt()` — display the prompt string.
- [ ] `IsOpen()`/`Flush()` — host state management.
- [ ] `Title` property — update the TUI window/title bar.
- [ ] `GetHostFlags()` — return appropriate capability flags.
- [ ] `IsInputRedirected()` — return false for interactive TUI.

**Important (for debugging support):**

- [ ] `WriteDebug()`/`WriteError()` — colored debug/error output.
- [ ] `WriteResult()` — formatted result display.
- [ ] Color support: `GetColors()`, `SetColors()`, `ResetColors()`.
- [ ] `Clone()` — create a copy for child interpreters.
- [ ] `Cancel()`/`Exit()` — handle Ctrl-C and exit requests.

**Recommended (for full experience):**

- [ ] Position support: `GetPosition()`, `SetPosition()`.
- [ ] Size support: `GetSize()`, `SetSize()`.
- [ ] Box drawing: `WriteBox()` — use Unicode box chars.
- [ ] All `WriteXxxInfo()` methods (inherited from Default if extending).
- [ ] Stream management: `In`, `Out`, `Error`, `SetupChannels()`.
- [ ] `GetData()`/`GetStream()` — virtual file system (inherited from File).
- [ ] Thread support: `CreateThread()`, `Sleep()`, `Yield()`.
- [ ] `QueryState()` — diagnostic state dump.
- [ ] `GetMode()`/`SetMode()` — terminal mode management.

### 23.5 Critical Implementation Details for TUI Hosts

**1. Thread Safety:**
All I/O methods must be thread-safe.  Use `Interlocked` operations for
read/write level counters.  Protect shared state (colors, position) with
locks.  See Appendix C.

**2. Read Level / Write Level Tracking:**
Always increment the level before the operation and decrement in a `finally`
block.  The interpreter checks these levels before closing the host.

```csharp
public bool ReadLine(ref string value)
{
    Interlocked.Increment(ref readLevels);
    try
    {
        // ... actual read logic ...
    }
    finally
    {
        Interlocked.Decrement(ref readLevels);
    }
}
```

**3. Cancellation Support:**
Implement a mechanism to cancel a pending `ReadLine()` — e.g., via a
`CancellationToken`, a shared flag, or by interrupting the reading thread.
The `Cancel()` method should trigger this mechanism.

**4. Box Drawing Character Selection:**
On Linux terminals with UTF-8 support, use the Unicode box-drawing characters:

```tcl
┌ (U+250C)  ─ (U+2500)  ┐ (U+2510)
│ (U+2502)               │ (U+2502)
└ (U+2514)  ─ (U+2500)  ┘ (U+2518)
```

The reference implementation (`Default.InitializeBoxCharacterSets()`) selects
the appropriate character set based on the output encoding capability.

**5. Color Mapping:**
Map `ConsoleColor` values to your TUI framework's color system.  The 16
standard `ConsoleColor` values should map naturally to ANSI 16-color codes:

| ConsoleColor | ANSI Code |
|-------------|-----------|
| Black | 30/40 |
| DarkBlue | 34/44 |
| DarkGreen | 32/42 |
| DarkCyan | 36/46 |
| DarkRed | 31/41 |
| DarkMagenta | 35/45 |
| DarkYellow | 33/43 |
| Gray | 37/47 |
| DarkGray | 90/100 |
| Blue | 94/104 |
| Green | 92/102 |
| Cyan | 96/106 |
| Red | 91/101 |
| Magenta | 95/105 |
| Yellow | 93/103 |
| White | 97/107 |

Note: `_ConsoleColor.None` (value -1) means "do not change the current color."

**6. Profile Loading:**
If extending from the `Profile` layer or above, the host will attempt to load
a profile file named after the host type (e.g., `MyTuiHost.ini`).  To skip
this, set `HostCreateFlags.NoProfile`.

**7. GetData Implementation:**
If you extend from `File` or above, you inherit the complete virtual file
system implementation.  If implementing from scratch, you must at minimum
support returning the core library scripts from embedded resources, or the
interpreter will fail to initialize.  The critical scripts are:

- `lib/Eagle1.0/init.eagle` — library initialization
- `lib/Eagle1.0/pkgIndex.eagle` — package index

**8. Return Value Semantics:**
- Return `true` from I/O methods to indicate success.
- Return `false` to indicate failure or "not supported" — never throw.
- Return `ReturnCode.Ok` from lifecycle methods for success.
- Return `ReturnCode.Error` with a descriptive `[error]` message for failures.

**9. Disposal:**
Implement `IDisposable` and clean up TUI resources.  The reference
implementation uses a `CheckDisposed()` guard at the top of every public
method.

---

## Appendix A: Box Drawing and Formatted Output

### Box Character Sets

The reference implementation supports multiple box-drawing character sets,
initialized by `Default.InitializeBoxCharacterSets()`.  The character set is
selected based on the output encoding's ability to encode the characters.

**Unicode character set (preferred on Linux/UTF-8):**
```tcl
Index 0: TopLeft      '┌' (U+250C)
Index 1: Horizontal   '─' (U+2500)
Index 2: TopRight     '┐' (U+2510)
Index 3: BottomLeft   '└' (U+2514)
Index 4: Vertical     '│' (U+2502)
Index 5: BottomRight  '┘' (U+2518)
```

**Fallback (ASCII):**
```tcl
+---+
|   |
+---+
```

### Output Styles

The `OutputStyle` property controls formatting:

| Style | Behavior |
|-------|----------|
| `None` | No formatting or boxing |
| `Formatted` | Line-based formatting with newlines |
| `Boxed` | Content enclosed in Unicode box borders |
| `Normal` | Standard output mode |
| `Reversed` | Colors swapped (reverse video) |

### Section Layout

The `WriteHeader` method uses `BeginSection`/`EndSection` to lay out
information sections.  In `Boxed` mode, sections can be placed side-by-side
(multi-column) if there is sufficient horizontal space.  In `Formatted` mode,
each section occupies its own line(s).

### Size-Based Content Selection

Each header section has a minimum size requirement stored in the
`sectionSizes` dictionary.  The `DoesHeaderFit()` method compares the
section's required size (e.g., `CompactSize`) against the host's current
size category.  Sections that don't fit are skipped entirely.

**Default section size requirements:**
- `AnnouncementInfo`, `StopPrompt`, `GoPrompt`: `CompactSize`
- `EngineInfo`, `ControlInfo`, `FlagInfo`, `HostInfo`: `FullSize`
- `DebuggerInfo`, `EntityInfo`, `StackInfo`, `TestInfo`: `FullSize`
- `ArgumentInfo`, `TokenInfo`, `TraceInfo`: `FullSize`
- `CallStackInfo`, `CallFrameInfo`, `ResultInfo`: `JumboSize`
- `VariableInfo`, `ObjectInfo`, `ComplaintInfo`: `JumboSize`
- `InterpreterInfo`, `HistoryInfo`, `OtherInfo`, `CustomInfo`: `SuperJumboSize`
- `PreviousResultInfo`: `ZeroSize` (always shown if enabled)

---

## Appendix B: Color Theme Architecture

### Color Categories

The reference implementation (`Default.InitializeColors()`) defines colors
across four categories:

**1. General Colors (16+ pairs):**
Used for overall UI elements — banners, boxes, debug output, error messages,
headers, footers, help text, legal notices, results, etc.

**2. Section Colors (19+ pairs):**
Each `WriteXxxInfo` method has its own foreground/background color pair
(e.g., `AnnouncementInfoForegroundColor`, `AnnouncementInfoBackgroundColor`).

**3. Return Code Colors (12+ pairs):**
Color-coded display of results by return code: Ok (typically green),
Error (typically red), Return, Break, Continue, Exception, etc.

**4. Call Frame Colors (17+ pairs):**
Different colors for different call frame types: Global, Procedure, Lambda,
Scope, Tracking, Engine, Namespace, etc.  This enables visual call stack
differentiation.

### Color Swapping

The `MaybeSwapTextColors()` and `MaybeSwapBorderColors()` methods swap
foreground/background colors when `OutputStyle.ReversedText` or
`OutputStyle.ReversedBorder` is active, enabling reverse-video display modes.

### The `_ConsoleColor.None` Convention

The special value `_ConsoleColor.None` (typically -1) means "use the current
color, don't change it."  When the host has `HostFlags.SavedColorForNone`
set, `None` is mapped to the originally saved colors instead.

---

## Appendix C: Thread Safety Requirements

### Required Thread-Safe Operations

1. **Read/Write level counters:** Use `Interlocked.Increment`/`Decrement`.
2. **Saved colors:** Protect with a lock object.
3. **Host flags:** Use `Interlocked` for flag reads/writes, or protect with
   a lock if compound read-modify-write is needed.
4. **Console I/O:** All reads and writes should be serialized to prevent
   interleaved output.
5. **Cancel state:** Use `Interlocked` for cancel flag management.

### Reference Implementation Patterns

The Console host uses:
- `syncRoot` (instance lock) for instance-level state.
- `staticSyncRoot` (static lock) for shared static state.
- `Interlocked` operations for all counters.
- `TryLockWithWait`/`ExitLock` via the `ISynchronize` interface.
- Reference counting for setup/teardown coordination across multiple
  Console instances sharing the same physical console.

### Deadlock Prevention

- Never call `ReadLine()` while holding a write lock.
- Never call back into the interpreter while holding a host lock.
- Use `TryLock` with timeouts rather than unconditional `Monitor.Enter`.

---

## Appendix D: The Featherlight WPF Window Host

This appendix provides a comprehensive analysis of the WPF-based interpreter
host implementation in the Featherlight plugin.  It demonstrates how the host
abstraction layer can be extended to support a full graphical windowed
environment, serving as a reference for building non-console host
implementations.

**Source:** `Plugins/Commercial/Enterprise/Featherlight/Hosts/Window.cs`
**ObjectId:** `9372a55b-ebc4-4745-a4e0-ce73fdc1fe39`

### D.1 Class Declaration and Inheritance

```csharp
public class Window : _Hosts.Core, IHostWindowManager, IDisposable
```

The Window host extends the `Core` layer of the reference implementation
hierarchy (Section 19), inheriting the complete host interface stack —
from `Default`'s full `IHost` implementation through `Engine`'s threading,
`File`'s virtual file system, `Profile`'s settings loading, `Shell`'s prompt
handling, and `Core`'s read/write level tracking.

In addition to the standard Eagle host interfaces inherited from `Core`, the
Window class implements Featherlight-specific interfaces for window management:

| Interface | Purpose |
|-----------|---------|
| `IHostWindowManager` | Window creation, activation, positioning, input injection |
| `IHostWindowIdentifier` | Window identity (ID, name, type) and window type properties |
| `IHostEventManager` | Event handler management (window opened/closed events) |
| `IHostWindowRegistrar` | Window registry: find, register, unregister, shutdown |
| `IDisposable` | Deterministic cleanup of windows, streams, and trace listeners |

### D.2 Window Architecture

The host manages a collection of WPF windows, each serving a distinct I/O
role.  Windows are tracked in a `IDictionary<string, IHostWindow>` registry
keyed by a composite name (logical name + window ID).

**Window Types:**

| WindowType Flag | Purpose | Interface |
|----------------|---------|-----------|
| `Input` | Receives user keyboard input | `IHostInputWindow` |
| `Output` | Displays standard output | `IHostOutputWindow` |
| `Error` | Displays error output | `IHostOutputWindow` |
| `Trace` | Displays `System.Diagnostics.Trace` output | `IHostOutputWindow` |
| `Box` | Temporary dialog for boxed debug/error output | `IHostOutputWindow` |
| `Interactive` | Combined read/write window for REPL | `IHostInteractiveWindow` |

The `WindowType` enumeration is a flags enum, allowing composite types (e.g.,
`WindowType.Box | WindowType.Output`).  The default window type is
`WindowType.Interactive`.

**Window Creation Flow:**

Window creation is necessarily asynchronous because WPF windows must run on
their own STA threads with message pumps.  The creation sequence is:

1. Client calls `GetWindow(name, type, create: true)`.
2. The method checks `MaybeUseSpecialWindow()` for pre-existing special
   windows (box, interactive) that can serve the request.
3. If not found in the registry and `create` is true, a new thread is
   created via `Engine.CreateThread()`.
4. The thread executes `CreateWindow()`, which:
   a. Obtains a `IHostWindowFactory` from the interactive window.
   b. Calls `windowFactory.CreateWindow()` with the window metadata.
   c. Sets the window title and calls `window.Refresh()`.
   d. Registers the window via `AddOrUpdateWindow()`.
   e. Signals a `ManualResetEvent` to wake the calling thread.
   f. Calls `window.ShowDialog()` — this blocks until the window closes.
   g. On window close, calls `CommonOps.Shutdown()`.
5. The calling thread waits up to 20 seconds (`CreateWindowTimeout`) for
   the event signal, then returns the created window.

This design ensures each WPF window has its own dispatcher thread with a
full message loop, while the host thread receives a reference as soon as
the window is initialized.

**Special Window Routing:**

The `MaybeUseSpecialWindow()` method implements routing logic for two
special window types:

- **Box windows:** If a `boxWindow` reference is currently set (between
  `BeginBox()` and `EndBox()` calls), it is returned directly.  Otherwise,
  the output window is used if available, falling back to the interactive
  window.
- **Interactive windows:** If the requested name matches the interactive
  window and it exists, it is returned directly.

### D.3 Stream Wrapping via HostStream

The Window host bridges the WPF window system with Eagle's stream-based I/O
model using `HostStream` adapter objects.  Each stream wraps a window
reference and presents it as a standard `System.IO.Stream`:

```tcl
Input stream  = new HostStream(inputWindow,  readable: true,  writable: false)
Output stream = new HostStream(outputWindow, readable: false, writable: true)
Error stream  = new HostStream(errorWindow,  readable: false, writable: true)
```

**Two operating modes are supported:**

1. **Separate windows** (`createOutput = true`): Dedicated Input, Output,
   and Error windows are created.  Each gets its own `HostStream` wrapper.
   If `traceToHost` is also true, a Trace window is additionally created.

2. **Shared interactive window** (`createOutput = false`): Both the output
   and error streams wrap the single interactive window.  All output appears
   in the same window where input is read.

The `SetupChannels()` method configures the stream translation modes for
Eagle's channel system:
- Input: `StreamTranslation.auto` (automatic line-ending translation).
- Output/Error: `StreamTranslation.binary` (no translation — the WPF text
  controls handle line endings natively).

The `DefaultIn`, `DefaultOut`, and `DefaultError` properties track whether
each stream has been accessed by the interpreter, using boolean flags
(`useDefaultIn`, `useDefaultOut`, `useDefaultError`).  These flags control
whether `SetupChannels()` actually registers the streams as interpreter
channels.

**Stream disposal** is handled by `MaybeDisposeStreams()`, which disposes
streams in reverse order (error, output, input), sets each to null, and
continues cleanup even if individual disposals throw exceptions.

### D.4 Host Flags and Capability Advertisement

The Window host advertises its capabilities via `GetHostFlags()`, which
returns a lazily-initialized bitmask combining:

```tcl
HostFlags.ForcePrompt         // Always display prompt (no terminal detection)
HostFlags.Graphical           // Identifies as a WPF-based graphical host
HostFlags.UnlimitedSize       // No inherent size constraints on windows
HostFlags.MultipleLineInput   // WPF text boxes support multi-line input
HostFlags.AutoFlushHost       // Auto-flush host I/O operations
HostFlags.AutoFlushOutput     // Auto-flush standard output stream
HostFlags.AutoFlushError      // Auto-flush error output stream
| base.MaybeInitializeHostFlags()   // Include all base class flags
```

Key differences from the Console host:

- **`ForcePrompt`** is required because, unlike a console where redirected
  input naturally suppresses prompts, the WPF window always appears
  interactive.  Without this flag, commands that produce no output would
  leave the user with no visual feedback.
- **`Graphical`** (instead of `Text`) signals to the interpreter that the
  host is a windowed GUI application, not a character-cell terminal.
- **`UnlimitedSize`** indicates that the host has no fixed character-cell
  dimensions.  This affects the debug header layout algorithm (Section 14):
  all sections are considered to "fit" regardless of their size requirements.
- **Auto-flush flags** are critical because the underlying `HostStream.Flush()`
  triggers the WPF text box to scroll to the end of its content, ensuring
  new output is always visible to the user.

The flags are lazily initialized on first access and cached.  The
`ResetHostFlags()` method invalidates the cache by setting the field to
`HostFlags.Invalid`, forcing re-initialization on the next access.

### D.5 Interface Implementation Details

#### D.5.1 IInteractiveHost — Processing Lifecycle

The Window host overrides the three processing lifecycle methods to provide
visual busy-state feedback in the interactive window's status area:

- **`BeginProcessing()`** — Increments the nesting level and sets the
  interactive window's status to `"busy: current N, previous N-1"`.
- **`EndProcessing()`** — Decrements the nesting level and updates the
  status to `"busy: N, N+1"`.
- **`DoneProcessing()`** — Decrements the nesting level.  If it reaches
  zero, clears the status display entirely (sets to `null`).

All three methods gate their status updates on whether the current
interpreter matches the interactive window's primary interpreter.  This
prevents child interpreter operations from corrupting the parent's status
display.

The `Title` property setter calls `SetupTitle(true)` after assigning the
base value.  `SetupTitle()` formats the window title as
`DefaultTitle + " " + CustomTitle`, with the window ID appended, and
pushes it to the interactive window via `window.SetTitle(title)`.

**`ReadLine()`** delegates to the configured input window's `ReadLine()`
method, protected by `EnterReadLevel()` / `ExitReadLevel()`.

**`IsInputRedirected()`** returns `true` — because input comes from a WPF
text box rather than a standard input stream, it is technically "redirected"
from the interpreter's perspective.  However, the `ForcePrompt` flag ensures
prompts are still displayed.

**`IsOpen()`** returns `true` unconditionally — WPF windows are always
considered open once initialized.

**`Flush()`** obtains the current box window (or output window) and calls
its `Flush()` method, protected by write level tracking.

#### D.5.2 IDebugHost — Debug Output via Box Dialogs

The Window host routes debug and error output through the box dialog system
rather than writing to the standard output stream:

- **`WriteDebugLine(string)`** — Closes any existing "Debug" box window,
  then opens a new one via `WriteBox("Debug", value)`.
- **`WriteErrorLine(string)`** — Closes any existing "Complain" box window,
  then opens a new one via `WriteBox("Complain", value)`.
- **`WriteDebugLine()`** (parameterless), **`WriteDebug(char/string)`** —
  Return `false` (not implemented for the WPF host).

The protected `WriteBox()` method creates a named box output window and
writes the content to it.  The protected `CloseBox()` method retrieves
the box window by name and calls `Close()` on it.

**`Clone()`** captures all host state under a lock (synchronized snapshot)
and constructs a new `Window` instance with the same interactive window,
event handlers, window types, and configuration.  The clone shares the
interactive window reference but gets its own `HostData` with the current
interpreter.

**`Cancel()`** obtains the interactive window under lock, resets its input
buffer via `SetInput(null)`, and signals cancellation via
`SignalCanceled()`.  This interrupts any pending `ReadLine()` operation.

**`Exit()`** closes the interactive window via
`CommonOps.CloseWindow(window, true, true)`, which triggers the WPF
application shutdown sequence.

#### D.5.3 IStreamHost — Stream Management

Stream properties (`DefaultIn`, `DefaultOut`, `DefaultError`, `In`, `Out`,
`Error`) are all lock-protected.  The `Default*` properties track access
via boolean flags.

**Encoding properties** all return `null` — the WPF text controls handle
encoding internally and do not expose an `Encoding` object.

**Reset methods** (`ResetIn`, `ResetOut`, `ResetError`) all return `false` —
the Window host does not support resetting streams to their original values
once initialized.

**`IsOutputRedirected()`** and **`IsErrorRedirected()`** both return
`false` — output goes directly to WPF windows and is not considered
"redirected."

#### D.5.4 IColorHost — Not Implemented

All color methods return `false`:

- `ResetColors()`, `GetColors()`, `AdjustColors()`,
  `SetForegroundColor()`, `SetBackgroundColor()`.

The WPF text controls use their own styling system (WPF brushes, styles,
templates) rather than `ConsoleColor` values.  Color management is handled
at the WPF layer, outside the host interface abstraction.

#### D.5.5 IPositionHost — Not Implemented

`GetPosition()` and `SetPosition()` both return `false`.  Character-cell
cursor positioning does not have a direct analog in the WPF text control
model, where content is laid out by the WPF layout engine.

#### D.5.6 ISizeHost — Partial Implementation

- **`GetSize()`** — Queries both the output window's pixel dimensions and
  its character cell size, then calculates character counts:
  `width = windowWidth / charWidth`, `height = windowHeight / charHeight`.
  This provides an approximation of the character-cell grid for the debug
  header layout algorithm.
- **`SetSize()`** — Delegates to `outputWindow.SetSize(hostSizeType, width,
  height)`.
- **`ResetSize()`** — Returns `false` (not implemented).

#### D.5.7 IBoxHost — Box Dialog Sessions

The box dialog system provides a stateful session model for structured
output:

1. **`BeginBox(name)`** — Gets or creates a named output window of type
   `WindowType.Box`.  Clears the window's content and position.  Stores
   the reference in the volatile `boxWindow` field under lock.  All
   subsequent write operations (via `Write()`, `WriteBox()`, etc.) are
   routed to this window until `EndBox()` is called.

2. **`EndBox(name)`** — Writes a final newline, calls `Refresh()` on the
   box window, and clears the `boxWindow` reference under lock.  The
   window remains open and visible — it is not destroyed.

The `boxWindow` field acts as a transient routing target: while set, the
`MaybeUseSpecialWindow()` method returns it for all box-type window
requests, ensuring that `WriteDebugLine()`, `WriteErrorLine()`, and
other output methods write to the correct dialog.

#### D.5.8 IReadHost — Key Input

- **`Read(ref int)`** — Obtains the input window, calls `ReadKey()` on it,
  and converts the result to an integer character value via
  `CommonOps.ReadKey()`.  Protected by read level tracking.
- **`ReadKey(bool intercept, ref IClientData)`** — Wraps the input window's
  `ReadKey()` result in a `ClientData` object.  The `intercept` parameter
  controls whether the keypress is echoed.

#### D.5.9 IWriteHost — Window Output

- **`Write(char, bool newLine)`** — Routes to the current box window (or
  output window).  If `newLine` is true, appends the configured line
  separator.  Passes `BufferClearSize` (2MB) as the buffer threshold.
- **`Write(string, bool newLine)`** — Same routing, with string content.

Both methods are protected by `EnterWriteLevel()` / `ExitWriteLevel()`.
The `BufferClearSize` parameter tells the output window to auto-clear its
buffer if it exceeds 2MB, preventing unbounded memory growth in
long-running sessions.

#### D.5.10 IInformationHost — Suppressed

- **`WriteAnnouncementInfo()`** — Returns `true` (success) but does nothing.
  The comment in the source explains that an announcement alone "looks
  strange" in the WPF context without the full header display context.
- **`WriteCustomInfo()`** — Returns `true` (no custom info provided).

#### D.5.11 IHost — Core Operations

- **`QueryState()`** — Returns a `StringList` containing: `HeaderFlags`,
  `HostFlags`, `ReadLevels`, `WriteLevels`, `WindowId`, `WindowName`,
  `WindowType`, `ExitCode`, and `WindowCount`.  This provides
  comprehensive diagnostic state for debugging the host itself.
- **`Clear()`** — Clears the output window and resets position.
- **`Beep()`** — Returns `false` (not implemented).
- **`IsIdle()`** — Returns `true` (stub; no better idle detection
  mechanism available).
- **`ResetHistory()`** — Delegates to
  `interactiveWindow.ResetHistory()`.
- **`GetMode()`/`SetMode()`** — Return error ("not implemented").  Console
  modes are not applicable to WPF windows.
- **`Open()`/`Close()`/`Discard()`** — Return error ("not implemented").
  Window lifecycle is managed through the WPF framework, not through the
  host interface.
- **`Reset()`** — Delegates to `base.Reset()`, then resets host flags.
- **`BeginSection()`/`EndSection()`** — Return `true` (no-op).

### D.6 Interpreter Reset Handling

The Window host has specialized behavior when the interpreter is being
detached (set to null):

```csharp
set /* Interpreter property */
{
    if (value == null)
    {
        Interpreter localInterpreter = base.InternalSafeGetInterpreter(false);
        Shell.Window.MaybeResetPluginInterpreter(localInterpreter);
        interactiveWindow.MaybeResetInteractiveInterpreter(localInterpreter);
        // NOTE: Does NOT set base interpreter to null
    }
    else
    {
        base.Interpreter = value;
    }
}
```

When a null interpreter is assigned (indicating reset/detach), the host:
1. Captures the current interpreter reference.
2. Cleans up the plugin's interpreter reference.
3. Cleans up the interactive window's interpreter reference.
4. Does **not** actually null out the base interpreter — this preserves
   the host's ability to function during shutdown sequences where the
   interpreter is being disposed but the host windows are still visible.

### D.7 Thread Safety

The Window host uses a single `syncRoot` object for all shared state
synchronization, with `lock (syncRoot) /* TRANSACTIONAL */` annotations
throughout.

**Fields protected by the lock:**
- Window registry (`windows` dictionary)
- All window references (`interactiveWindow`, `boxWindow`)
- All stream references (`input`, `output`, `[error]`)
- Configuration state (`windowId`, `inputWindowType`, `outputWindowType`,
  `createOutput`, `traceToHost`, `newLine`)
- Event handlers (`openedHandler`, `closedHandler`)
- Access tracking flags (`useDefaultIn`, `useDefaultOut`, `useDefaultError`)
- Exit code

**Thread-safe disposal** uses `Interlocked.Increment(ref disposeCount)` to
ensure only the first thread to initiate disposal actually executes the
cleanup logic.

**The `IsLocked` property** uses `Monitor.TryEnter(syncRoot)` to probe
whether the lock is currently held (for external monitoring purposes).
If the lock is not held, it immediately exits.

**Deadlock prevention during shutdown:** The `GetWindow()` method returns
null if `IsExiting()` returns true, preventing window creation attempts
during disposal from blocking on the lock while the disposal thread
holds it.

### D.8 Trace Listener Integration

When both `createOutput` and `traceToHost` are true, the Window host
creates a dedicated trace output pipeline:

1. A Trace window is created via `GetWindow(WindowType.Trace, true)`.
2. A `WindowTraceListener` is instantiated with:
   - The trace window reference.
   - The configured line separator.
   - `BufferWriteSize` (1MB) — the write buffer threshold.
   - `WriteMilliseconds` (10 seconds) — the write timeout.
3. The listener is registered with `Trace.Listeners.Add(traceListener)`.

All `System.Diagnostics.Trace.Write*()` calls throughout the application
are captured and routed to the trace window.

During disposal, the trace listener is removed from `Trace.Listeners` and
disposed, with error handling to prevent cleanup failures from interrupting
the shutdown sequence.

### D.9 Window Registry and Lifecycle

**Registration:**
- `AddOrUpdateWindow(name, window, initialize)` — Adds a window to the
  registry under lock.  If a different window already exists under the same
  name, the old window is closed first.  The `initialize` flag controls
  whether the dictionary is created if it does not yet exist.
- `RegisterWindow()` logs via `DebugTrace()` and delegates to
  `AddOrUpdateWindow()`.

**Unregistration:**
- `RemoveWindow(name, windowType, interpreter, channels)` — Removes a
  window from the registry.  If `channels` is true, calls
  `MaybeRemoveChannels()` to clean up any interpreter channels associated
  with the window's streams.
- `MaybeRemoveChannels()` iterates over Input, Output, and Error streams,
  checking if each is registered as an interpreter channel.  For each
  registered channel, it calls `interpreter.RemoveChannel()` with force-close
  and notify flags.

**Shutdown:**
- `Shutdown(bool shutdown)` — Makes a snapshot of the window dictionary under
  lock, then iterates all windows: unregisters each (removing channels) and
  calls `window.CloseAsync()` (non-blocking close).  Clears the dictionary.
  Returns false if the dictionary was null.

**Lifecycle diagram:**
```tcl
CreateWindow() → AddOrUpdateWindow() → window.ShowDialog()
                                                 |
                                         [window closes]
                                                 |
                                      CommonOps.Shutdown()

Dispose() → Shutdown(false) → UnregisterWindow() → MaybeRemoveChannels()
                             → window.CloseAsync()
                             → Trace.Listeners.Remove()
                             → traceListener.Dispose()
                             → MaybeDisposeStreams()
```

### D.10 Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `BufferWriteSize` | 1,048,576 (1 MB) | Trace listener write buffer threshold |
| `BufferClearSize` | 2,097,152 (2 MB) | Output window auto-clear threshold |
| `WriteMilliseconds` | 10,000 (10 sec) | Trace listener write timeout |
| `CreateWindowTimeout` | 20,000 (20 sec) | Window creation thread join timeout |
| `StatusFormat` | `"busy: current {0}, previous {1}"` | Interactive status display |
| `TitleFormat` | `"{0} {1}"` | Window title (DefaultTitle + custom) |
| `DebugBoxName` | `"Debug"` | Box window name for debug output |
| `ComplainBoxName` | `"Complain"` | Box window name for error output |

### D.11 Comparison with Console Host

| Aspect | Console Host | Window Host |
|--------|-------------|-------------|
| **Base class** | `Core` | `Core` |
| **I/O target** | `System.Console` | WPF text controls via `HostStream` |
| **Color support** | Full (`ConsoleColor` via `System.Console`) | Not implemented (WPF styling) |
| **Cursor positioning** | Full (`System.Console` cursor) | Not implemented |
| **Size detection** | Console buffer/window dimensions | Calculated from pixel/char ratios |
| **Input model** | `Console.ReadLine()` blocking | `IHostInputWindow.ReadLine()` |
| **Cancel mechanism** | Ctrl-C console handler | `SignalCanceled()` on interactive window |
| **Debug output** | Inline colored text to console | Separate box dialog windows |
| **Trace output** | Not captured | Dedicated trace window via `TraceListener` |
| **Multiple windows** | Single console | Multiple typed windows (6 types) |
| **Thread model** | Main thread I/O | Separate STA thread per window |
| **IsInputRedirected** | Checks `Console.IsInputRedirected` | Always returns `true` |
| **ForcePrompt** | Not typically needed | Required (always "redirected") |
| **Mode get/set** | Native Win32 console modes | Not applicable |
| **Open/Close** | Console alloc/free (Windows) | WPF lifecycle (not exposed) |
| **Stream reset** | Restores original streams | Not supported |
| **History** | Console input history (Windows) | Interactive window history |

### D.12 Implementation Guidance for Similar Hosts

Developers building new graphical host implementations (e.g., GTK, Qt,
Avalonia, web-based) can use the Window host as a reference.  Key patterns
to replicate:

1. **Extend `Core`** (not `Default`) to inherit the full layered
   implementation including threading, VFS, profiles, prompts, and
   read/write level tracking.

2. **Wrap UI controls as streams** using adapter objects analogous to
   `HostStream`.  This bridges the gap between Eagle's stream-based channel
   system and UI framework I/O models.

3. **Set `HostFlags.ForcePrompt`** for any host where `IsInputRedirected()`
   returns `true` (which it should for non-console hosts, since input does
   not come from a standard input stream).

4. **Set `HostFlags.Graphical`** to signal the windowed environment.

5. **Create windows on dedicated threads** with message pumps.  Use
   synchronization primitives (events, semaphores) to coordinate between
   the host thread and the UI threads.

6. **Implement `Cancel()` with UI-thread-safe signaling** — the cancel
   signal must interrupt a blocking `ReadLine()` on the input window.

7. **Route debug/error output to box dialogs** (or equivalent modal/popup
   UI) rather than mixing it with standard output, for clearer visual
   separation.

8. **Guard against shutdown races** by checking `IsExiting()` before
   creating new windows and using atomic disposal counters.

9. **Register a `TraceListener`** if diagnostic tracing to the UI is
   desired — this captures all `System.Diagnostics.Trace` output without
   requiring code changes elsewhere.

10. **Handle interpreter reset carefully** — clean up interpreter references
    in windows and plugins without nulling the base interpreter, to avoid
    crashes during shutdown sequences.

---

## Appendix E: Featherlight Interactive Usability Features

This appendix documents the interactive usability enhancements provided by
the Featherlight WPF window system.  These features transform the raw host
interface into a polished graphical REPL experience with tab-completion,
command history, automatic multi-window layout, and comprehensive thread
safety.

**Source files:**
- `Windows/BaseWindow.cs` — shared window infrastructure
- `Windows/InteractiveWindow.xaml` / `.xaml.cs` — primary REPL window
- `Windows/InputWindow.xaml` / `.xaml.cs` — dedicated input window
- `Windows/OutputWindow.xaml` / `.xaml.cs` — dedicated output window
- `Components/Private/CommonOps.cs` — utility library
- `Components/Private/Shell.cs` — plugin lifecycle coordinator
- `Components/Private/HostStream.cs` — stream adapter
- `Components/Private/WindowTraceListener.cs` — async trace capture
- `Components/Private/WindowRegistrar.cs` — window registry

### E.1 Window Interface Hierarchy

The Featherlight window system is built on a layered interface hierarchy
that separates concerns between identification, events, stream I/O,
management, registration, and factory creation:

```tcl
IHostWindowIdentifier          [WindowId, WindowName, WindowType]
IHostEventManager              [OpenedHandler, ClosedHandler]

IHostWindow                    [extends: IHostWindowIdentifier, IHostEventManager]
  |  Close, CloseAsync, Activate, Refresh, Position
  |  GetSize, SetSize, GetTitle, SetTitle, Show, ShowDialog
  |
  +-- IHostInputWindow         [extends: IHostWindow, IHostStreamManager]
  |
  +-- IHostOutputWindow        [extends: IHostWindow, IHostStreamManager]
  |     GetCharacterSize
  |
  +-- IHostStreamWindow        [extends: IHostInputWindow, IHostOutputWindow]

IHostStreamManager             [standalone]
  |  Invoke, BeginInvoke (UI thread marshaling)
  |  SignalReadKey, SignalReadLine, SignalCanceled (event signaling)
  |  WaitReadKey, WaitReadLine (blocking waits)
  |  ReadKey, ReadLine, GetKey, SetKey
  |  GetInput, AddInput, InsertInput, SetInput
  |  Write, WriteAsync, Flush, Clear, AddOutputLine
  |  AutoFlush property

IHostWindowFactory             [standalone]
  |  NewHost, DisposeHosts, CreateWindow (2 overloads)

IHostWindowRegistrar           [standalone]
  |  IsLocked, ExitCode, WindowCount
  |  FindWindow, RegisterWindow, UnregisterWindow, Close, Shutdown

IHostWindowManager             [extends: IHostWindowIdentifier + IHostEventManager
  |                             + IHostWindowRegistrar]
  |  IsDisposing, InjectInput
  |  GetWindow (4 overloads), ActivateWindow, PositionWindow

IHostInteractiveWindow         [extends: IHostStreamWindow + IHostWindowFactory]
     HaveInteractiveInterpreter, MatchInteractiveInterpreter
     ResetInteractiveInterpreter, MaybeResetInteractiveInterpreter
     StartupInteractiveLoop, ShutdownInteractiveLoop
     SetStatus, ResetHistory
```

The `IHostStreamManager` interface is central to the cross-thread I/O model.
It provides both synchronous and asynchronous write methods, blocking read
methods with cancellation support, and UI thread marshaling via `Invoke()`
and `BeginInvoke()`.  The signal/wait methods (`SignalReadKey`,
`WaitReadLine`, etc.) implement a producer-consumer pattern using
`ManualResetEvent` objects for cross-thread coordination.

### E.2 BaseWindow — Shared Window Infrastructure

**Class:** `BaseWindow : System.Windows.Window, IHostWindow, IHostStreamManager`
**ObjectId:** `cd4723e2-c701-462f-a128-e1b2d827f1ee`

`BaseWindow` is the abstract base class for all Featherlight WPF windows.
It provides reusable infrastructure that the `InputWindow`, `OutputWindow`,
and `InteractiveWindow` classes inherit, promoting code reuse and consistent
behavior.

#### E.2.1 Cross-Thread I/O via ManualResetEvent

The core I/O mechanism uses three `ManualResetEvent` objects to coordinate
between the interpreter thread (which calls `ReadLine()` / `ReadKey()`) and
the WPF UI thread (which handles keyboard events):

```tcl
keyEvent    — signaled when a key press is available
lineEvent   — signaled when a complete input line is ready
cancelEvent — signaled when the user requests cancellation
```

**Blocking read pattern:**

```tcl
ReadLine():
  1. Activate the window (bring to foreground)
  2. Call WaitReadLine():
     a. Lock: build array [lineEvent, cancelEvent]
     b. Release lock
     c. Reset all events in array
     d. Call EventWaitHandle.WaitAny([lineEvent, cancelEvent])
     e. Return true if lineEvent was signaled, false if cancelEvent
  3. Call GetInput() to retrieve the text
  4. Echo input to output via AddOutputLine()
  5. Return the input text
```

The lock is held only during event array construction — never during the
blocking wait itself — which prevents deadlocks between the interpreter
thread and the UI thread.

#### E.2.2 Text Buffer Management

All output is managed through a `TextBox` control.  The `WriteCore()` static
method provides the core text-append logic:

- **Buffer size enforcement:** If a `length` parameter is specified (e.g.,
  `BufferClearSize` = 2MB), and the new text would exceed the limit, the
  TextBox's entire content is replaced rather than appended.  This prevents
  unbounded memory growth in long-running sessions.
- **Line ending normalization:** All text passes through `MaybeMutateValue()`,
  which detects CR/LF characters and normalizes them via
  `Utility.NormalizeLineEndings()`.
- **Auto-scroll:** When `[flush]` is true (or `autoFlush` is enabled), the
  method selects the end of the text and calls `ScrollToEnd()`, ensuring
  new output is always visible.

**Synchronous vs. asynchronous writes:**

- `Write(value, length, flush)` — Uses `Invoke()` (synchronous dispatch to
  the UI thread).  Blocks until the write completes.
- `WriteAsync(value, length, flush)` — Uses `BeginInvoke()` (asynchronous
  dispatch).  Returns immediately; the write is queued on the dispatcher.

#### E.2.3 Smart Input Insertion

The `InsertInput()` method provides intelligent text insertion at the caret
position:

1. Retrieves the current caret position in the input TextBox.
2. Scans backward from the caret to find the start of the current word
   (delimited by whitespace).
3. Scans forward to find the end of the current word.
4. If a word is found at the caret, replaces it with the new value.
5. If no word is found, appends the value.
6. Adds a trailing space and positions the caret after the insertion.

This is used by the tab-completion system to replace partial tokens with
their completed forms.

#### E.2.4 Automatic Window Cascading

`BaseWindow` maintains static state for automatic window positioning:

```csharp
private static object staticSyncRoot = new object();
private static WindowPosition nextWindowPosition = WindowPosition.First;
```

The `GetNextWindowPosition()` method cycles through the nine named positions
defined in the `WindowPosition` enum:

```tcl
TopLeft → TopCenter → TopRight → MiddleLeft → MiddleRight →
BottomLeft → BottomCenter → BottomRight → (wrap to TopLeft)
```

Position cycling is thread-safe (protected by `staticSyncRoot`) and skips
non-automatic positions via the `AutomaticMask`.  Note that `MiddleCenter`
is excluded from the automatic mask — it is reserved for explicit centering.

When a window is loaded, `PositionWindow()` calculates its actual position
relative to the factory (parent) window using
`CommonOps.CalculatePosition()`, which applies horizontal and vertical
margins (10 pixels each) to prevent exact overlap.

#### E.2.5 Window Lifecycle Events

`BaseWindow` registers four lifecycle event handlers:

| Event | Handler | Action |
|-------|---------|--------|
| `Initialized` | `Window_Initialized` | Invokes `openedHandler` delegate |
| `Loaded` | `Window_Loaded` | Calls `Refresh()` to apply size and position |
| `Closing` | `Window_Closing` | Sets `isClosing = true`; unregisters from window manager |
| `Closed` | `Window_Closed` | Invokes `closedHandler` delegate |

The `Window_Closing` handler checks `windowManager.IsDisposing()` before
attempting to unregister, preventing re-entrant cleanup during shutdown.

#### E.2.6 Diagnostic Integration

Three trace/error methods are available to all window subclasses:

- **`Complain(interpreter, code, result)`** — Routes errors through Eagle's
  `Utility.Complain()` system.  Marked `[NoInlining]` for clean stack traces.
- **`DebugTrace(message)`** — Emits trace output at `MediumLow` priority
  with `ViaWrapperFromPlugin` classification.
- **`DebugTraceMe(message)`** — Enhanced variant that appends window
  metadata (windowId, windowName, windowType) to the trace message.

### E.3 InteractiveWindow — The Primary REPL

**Class:** `InteractiveWindow : BaseWindow, IHostInteractiveWindow`
**Size:** ~2,400 lines

The `InteractiveWindow` is the flagship window of the Featherlight plugin,
providing a full interactive REPL with IDE-like usability features.

#### E.3.1 XAML Layout

```tcl
Window (500x400 minimum, centered)
└── Grid (2 columns, 4 rows, background: #485D7C)
    ├── Row 0: TextBox "txtOutput" (read-only, Courier New 14px, #485D7C)
    ├── Row 1: GridSplitter "splitInputOutput" (5px, cursor: SizeNS)
    ├── Row 2: TextBox "txtInput" (editable, Courier New 16px, #232D3C)
    └── Row 3 (43px):
        ├── Label "lblStatus" (white, 16px, left-aligned)
        ├── Button "btnEnter" (right-aligned, "Enter")
        └── Button "btnCancel" (right-aligned, "Cancel")
```

The resizable `GridSplitter` between the output and input panels allows the
user to adjust the proportion of screen space devoted to output vs. input.
The input TextBox uses a larger font (16px vs. 14px) for readability, and
both panels use the `Courier New` fixed-width font for proper alignment of
tabular output.

#### E.3.2 Tab-Completion Engine

The tab-completion system is the most complex usability feature, implemented
in the `txtInput_KeyDown` handler (~600 lines).  It supports five distinct
completion contexts:

**1. Interactive commands** (when input starts with `#`):
```tcl
#<pattern>  →  matches Eagle interactive commands (e.g., #show, #check)
```
Uses `CommonOps.GetMatchingInteractiveCommands()` with glob pattern matching.
Only available when compiled with `SHELL` and `INTERACTIVE_COMMANDS`.

**2. Commands, procedures, and IExecute objects** (single argument):
```tcl
<pattern>  →  matches commands, procedures, and IExecute implementations
```
Searches three namespaces in order:
- `interpreter.ListCommands()` — built-in and plugin commands
- `interpreter.ListProcedures()` — user-defined procedures
- `interpreter.ListIExecutes()` — IExecute implementations

**3. Sub-commands and expression functions** (two arguments):
```tcl
<command> <pattern>  →  matches sub-commands of the given command
expr <pattern>       →  matches expression functions (sin, cos, etc.)
```
Uses `CommonOps.IsSubCommand()` for sub-command matching, which searches
the command's `EnsembleDictionary` with glob pattern support.

**4. Type names** (three arguments with object commands):
```tcl
object <subcommand> <type-pattern>  →  matches .NET type names
```
Uses `CommonOps.GetMatchingTypes()`, which searches all loaded assemblies
in the current `AppDomain`.  Results are cached on first use (thread-safe
via `staticSyncRoot`).  Matches against both short names and fully-qualified
names.

**5. Type members** (four arguments with object commands):
```tcl
object <subcommand> <type> <member-pattern>  →  matches type members
```
Uses `CommonOps.GetMatchingMembers()`, which reflects on the resolved type
to find matching fields, properties, and methods.

**Completion display:**

Results are shown in a separate "completions" box window (not inline):
- Results are sorted alphabetically.
- A header shows the original input, expanded input, match type, and count.
- Maximum 30 results (`MaximumAutoComplete`); if exceeded, a
  `"... <MORE THAN 30 MATCHES> ..."` message is appended.
- The completion window is activated (brought to front) on success.
- Errors are reported via `CommonOps.WriteError()`.

**Argument expansion:**

Before matching, each argument passes through `CommonOps.ExpandArgument()`,
which handles:
- Variable substitution (standard Eagle `$variable` expansion)
- Interactive command prefix expansion (`#pattern` → command list)
- Wildcard appendix (a trailing `*` is added for glob matching)

#### E.3.3 Command History

Command history is maintained in a `StringList` (`historyList`) with an
integer index (`historyIndex`).  Both are protected by the `syncRoot` lock.

| Key | Action |
|-----|--------|
| **Ctrl-Up** | Navigate to the previous history entry (wraps to end) |
| **Ctrl-Down** | Navigate to the next history entry (wraps to start) |
| **Enter** (or Enter button) | Add current input to history, signal ReadLine |

History navigation clamps at boundaries: pressing Ctrl-Up past the first
entry stays at the first entry, and Ctrl-Down past the last entry stays at
the last entry.  The history is session-only — it
is not persisted to disk.

The `ResetHistory()` method (exposed via `IHostInteractiveWindow`) clears
the history list and resets the index.

#### E.3.4 Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **F1** | Display keyboard shortcut help (MessageBox) |
| **F2** | Toggle single-line entry mode; displays status |
| **Ctrl-Up** | Previous history entry |
| **Ctrl-Down** | Next history entry |
| **Ctrl-N** | Spawn a new interactive window (new interpreter thread) |
| **Tab** | Trigger tab-completion |
| **Enter** | Submit input (immediate in single-line mode) |

The **F2 single-line mode** toggle changes the Enter key behavior: in
single-line mode, pressing Enter immediately submits the input without
requiring the Enter button.  This is useful for rapid command entry.  In
multi-line mode (the default), Enter inserts a newline, and the Enter
button (or a future keyboard shortcut) submits.

**Ctrl-N** spawns a new interactive session by creating a new thread
running `InteractiveWindowStart()`, which creates a fresh
`InteractiveWindow` via the window factory, followed by `ShowDialog()`.

#### E.3.5 Cancel Button and Script Interruption

The Cancel button calls `interpreter.CancelAnyEvaluate()` with:
```csharp
CancelFlags.UnwindAndNotify | CancelFlags.AllInterpreters
```

This immediately cancels any in-progress script evaluation across all child
interpreters, unwinds the call stack, and notifies the host.  The cancel
result is reported to the user via a MessageBox if it fails.

#### E.3.6 Interactive Thread Management

The `InteractiveWindow` runs the Eagle interactive loop on a dedicated
background thread, separate from the WPF UI thread.  Two startup paths
are supported:

**Path 1: Create new interpreter** (`InteractiveThreadStartWithCreate`):
1. Parses startup flags (CreateFlags, HostCreateFlags, library path, etc.)
2. Creates a new interpreter via `CommonOps.CreateInterpreter()`
3. Creates a host via `NewHost()` and assigns it to the interpreter
4. Calls `Interpreter.ShellMainCore()` with `initialize=true, loop=true`
5. Cleans up via `InteractiveThreadStartEpilogue()`

**Path 2: Use existing interpreter** (`InteractiveThreadStartWithExisting`):
1. Gets the plugin interpreter via `Shell.Window.GetPluginInterpreter()`
2. Acquires the interpreter lock via `TryLockWithWait()`
3. Saves and replaces the current host
4. Calls `ShellMainCore()` with `initialize=false, loop=true`
5. Restores the original host in a `finally` block

#### E.3.7 Graceful Shutdown

`ShutdownInteractiveLoop()` implements a multi-phase shutdown:

1. **Guard against re-entrancy:** Uses `Interlocked.Increment(ref
   shutdownLevels)` — only the first caller (level == 1) proceeds.
2. **Set exit flags:** `localInterpreter.ExitNoThrow = true`
3. **Unblock ReadLine:** `SetInput(String.Empty)` + `SignalReadLine()` —
   forces any pending `ReadLine()` to return an empty string, which causes
   the interactive loop to check the exit flag and terminate.
4. **Pump dispatcher messages:** Creates a new `DispatcherFrame` and calls
   `Dispatcher.PushFrame()` to keep the UI responsive while waiting.
5. **Join thread:** Waits up to 2 seconds (`ThreadJoinTimeout`) for the
   interactive thread to exit gracefully.
6. **Abort if necessary:** If the thread is still alive and
   `!interpreter.NoThreadAbort`, calls `Thread.Abort()` as a last resort.
7. **Cleanup:** Decrements `shutdownLevels`.

The dispatcher frame pump in step 4 is critical for deadlock prevention:
without it, the UI thread would block waiting for the interactive thread
to exit, but the interactive thread might be waiting for a UI operation
(e.g., `SignalReadLine()` via `Invoke()`) to complete — a classic deadlock.

#### E.3.8 Processing Status Display

The interactive window shows busy-state feedback in the status label
(`lblStatus`):

- **`BeginProcessing()`** — Sets status to `"busy: current N, previous N-1"`
- **`EndProcessing()`** — Updates to `"busy: N, N+1"`
- **`DoneProcessing()`** — Clears status when nesting reaches zero
- **`SetStatus(value)`** — Sets arbitrary status text (thread-safe via
  dispatcher `Invoke()`)

Status updates are gated on `MatchInteractiveInterpreter()` to ensure
only the primary interpreter's operations affect the display.

#### E.3.9 Host Factory

The `InteractiveWindow` implements `IHostWindowFactory`, serving as the
factory for all child windows:

- **`NewHost(interpreter, hostData, primary)`** — Creates a new
  `Hosts.Window` instance.  Non-primary hosts are tracked in a `hosts`
  dictionary for disposal.
- **`CreateWindow(windowType, ...)`** — Dispatches to the appropriate
  window constructor based on type:
  - `WindowType.Input` → `InputWindow`
  - `WindowType.Output/Error/Trace/Box` → `OutputWindow`
  - `WindowType.Interactive` → `InteractiveWindow`
- **`DisposeHosts()`** — Iterates the secondary hosts dictionary and
  disposes each one, logging errors but continuing cleanup.

### E.4 InputWindow and OutputWindow

These are simpler specialized windows that inherit most behavior from
`BaseWindow`.

#### E.4.1 InputWindow

**Class:** `InputWindow : BaseWindow, IHostInputWindow`
**Size:** ~150 lines

A single `TextBox` (`txtInput`) with `AcceptsReturn=True` for multi-line
input.  Styled with Courier New 16px on a dark blue background (#232D3C).

**Key behavior:**
- **Auto-focus on activation:** The `Window_Activated` handler focuses the
  input TextBox via dispatcher `Invoke()`, ensuring immediate input
  readiness when the window receives focus.
- **Size queries:** `GetSize()` supports both window-level and buffer-level
  queries — buffer sizes are measured from `ViewportWidth`/`ViewportHeight`.

#### E.4.2 OutputWindow

**Class:** `OutputWindow : BaseWindow, IHostOutputWindow`
**Size:** ~200 lines

A single read-only `TextBox` (`txtOutput`) with `IsUndoEnabled=False`.
Styled with Courier New 14px on a medium blue background (#FF485D7C).

**Key behavior:**
- **Double-click line injection:** The `MouseDoubleClick` handler extracts
  the text of the clicked line using `GetCharacterIndexFromPoint()` and
  `GetLineIndexFromCharacterIndex()`, then injects it into the input
  stream via `windowManager.InjectInput(value)`.  This allows users to
  re-execute previous output lines (e.g., command results, error messages)
  by double-clicking them.
- **Character size measurement:** `GetCharacterSize()` measures the
  fixed-width font dimensions using `CommonOps.MeasureTextWidth()` and
  `CommonOps.MeasureTextHeight()`, dividing by a divisor constant.  This
  is used by the Window host's `GetSize()` method to convert pixel
  dimensions to character-cell counts.

### E.5 CommonOps — Utility Library

**Class:** Static utility class (~1,100 lines)

`CommonOps` provides the shared infrastructure used by all window classes
and the host implementation.

#### E.5.1 Command and Procedure Introspection

These methods power the tab-completion engine:

| Method | Purpose |
|--------|---------|
| `IsCommand(interpreter, name, ...)` | Check if a name matches an executable command (excluding procedures/IExecute) |
| `IsSubCommand(interpreter, name, subName, ...)` | Search a command's `EnsembleDictionary` for matching sub-commands |
| `IsProcedure(interpreter, name, ...)` | Check if a name matches a defined procedure |
| `IsInteractiveCommand(interpreter, name, ...)` | Match interactive commands (when `INTERACTIVE_COMMANDS` defined) |
| `IsExpressionCommand(interpreter, name)` | Check if a command is `[expr]` |
| `IsObjectCommand(interpreter, name)` | Check if a command is `[object]` |
| `ExpandArgument(interpreter, name, ...)` | Expand variables, wildcards, and `#` prefixes |
| `GetMatchingTypes(interpreter, pattern, ...)` | Find .NET types matching a glob pattern (cached) |
| `GetMatchingMembers(interpreter, type, pattern, ...)` | Find type members matching a pattern |

#### E.5.2 Window Positioning

| Method | Purpose |
|--------|---------|
| `CalculatePosition(position, parentRect)` | Compute child window left/top relative to parent |
| `IsAutomaticPosition(position)` | Check if position is in the `AutomaticMask` |
| `RectFromIHostWindow(window)` | Extract bounds from an `IHostWindow` |
| `HasFlags(position, flags)` | Check window position flags |

The `CalculatePosition()` method implements all nine named positions
(TopLeft through BottomRight) with 10-pixel horizontal and vertical margins.

#### E.5.3 UI Thread Marshaling

| Method | Purpose |
|--------|---------|
| `Invoke(dispatcherObject, delegate, args)` | Synchronous dispatch to UI thread |
| `BeginInvoke(dispatcherObject, delegate, args)` | Asynchronous dispatch to UI thread |

These wrap WPF's `Dispatcher.Invoke()` / `Dispatcher.BeginInvoke()` with
null-safety and exception handling.

#### E.5.4 Text Measurement

| Method | Purpose |
|--------|---------|
| `MeasureTextWidth(control, text)` | Measure rendered text width in pixels |
| `MeasureTextHeight(control, text)` | Measure rendered text height in pixels |

Used by `OutputWindow.GetCharacterSize()` to compute character-cell
dimensions for the ISizeHost interface.

### E.6 Thread Safety Architecture

The Featherlight window system employs multiple complementary thread safety
strategies:

#### E.6.1 Lock Hierarchy

| Lock Object | Scope | Protects |
|------------|-------|----------|
| `BaseWindow.syncRoot` | Per-window instance | Window fields, event handles, key cache, isClosing |
| `BaseWindow.staticSyncRoot` | Shared across all windows | `nextWindowPosition` for auto-cascading |
| `InteractiveWindow.syncRoot` | Per-interactive-window | Interpreter, host, thread, history, dispatcherFrame |
| `WindowRegistrar.syncRoot` | Per-registrar instance | Window dictionary, exit code |
| `WindowTraceListener.syncRoot` | Per-listener instance | Trace buffer, write timer |
| `CommonOps.syncRoot` | Shared static | Cached type dictionary |

No method acquires more than one of these locks simultaneously, eliminating
the possibility of lock-ordering deadlocks.

#### E.6.2 Interlocked Atomic Operations

Several counters use `Interlocked.Increment` / `Interlocked.Decrement`
rather than locks, for higher performance and simpler semantics:

| Counter | Class | Purpose |
|---------|-------|---------|
| `activeInteractiveLoops` | InteractiveWindow | Track nested shell loop depth |
| `shutdownLevels` | InteractiveWindow | Re-entrancy guard for shutdown |
| `startupCount` | Shell.Window | Ensure one-time Main() execution |
| `shutdownCount` | Shell.Window | Ensure one-time Shutdown() execution |
| `windowCount` | Shell.Window | Track active windows for app shutdown |

#### E.6.3 ManualResetEvent Signaling

The `BaseWindow` I/O model uses `ManualResetEvent` objects for cross-thread
coordination:

```tcl
Interpreter Thread                UI Thread
      |                               |
      |  ReadLine()                   |
      |  → WaitReadLine()             |
      |     lock: build event array   |
      |     release lock              |
      |     ResetEvents()             |
      |     WaitAny([line, cancel])   |
      |     ... BLOCKED ...           |
      |                               |  User presses Enter
      |                               |  → btnEnter_Click()
      |                               |     → SignalReadLine()
      |     ... UNBLOCKED ...         |        lock: lineEvent.Set()
      |  GetInput()                   |
      |  return text                  |
      |                               |
```

The lock is never held during the blocking `WaitAny()` call.  Events are
reset before waiting to prevent stale signals.

#### E.6.4 Dispatcher Frame Pump

During `ShutdownInteractiveLoop()`, the UI thread must wait for the
interactive thread to exit.  A naive `Thread.Join()` would deadlock if the
interactive thread is blocked on a UI operation.  The solution is to push a
new `DispatcherFrame`:

```csharp
dispatcherFrame = new DispatcherFrame();
Dispatcher.PushFrame(dispatcherFrame);
```

This keeps the WPF message pump running while the shutdown code waits,
allowing pending `Invoke()` calls from the interactive thread to complete.
When the interactive thread exits and calls
`InteractiveThreadStartEpilogue()`, it sets
`dispatcherFrame.Continue = false`, which exits the `PushFrame()` call and
allows the shutdown to proceed.

#### E.6.5 Registrar Lock Probing

The `WindowRegistrar.IsLocked` property provides a non-blocking lock test:

```csharp
public bool IsLocked
{
    get
    {
        if (Monitor.TryEnter(syncRoot))
        {
            Monitor.Exit(syncRoot);
            return false;  // Not locked
        }
        return true;  // Currently locked
    }
}
```

`BaseWindow.Window_Closing` checks `windowRegistrar.IsLocked` before
attempting to unregister, returning early if the registrar is locked.  This
prevents a window close operation from blocking indefinitely on a contended
registrar lock (e.g., during a coordinated multi-window shutdown).

### E.7 Multi-Window Layout System

#### E.7.1 WindowPosition Enum

```tcl
None = 0x0         (no positioning)
Automatic = 0x2    (next in cascade sequence)
TopLeft = 0x4      TopCenter = 0x8      TopRight = 0x10
MiddleLeft = 0x20  MiddleCenter = 0x40  MiddleRight = 0x80
BottomLeft = 0x100 BottomCenter = 0x200 BottomRight = 0x400

AutomaticMask = all except None, Invalid, Automatic, MiddleCenter
```

#### E.7.2 WindowPositionInfo

The `WindowPositionInfo` class stores the `WindowPosition` enum value
plus a `Rect` with left, top, width, and height.  Three factory methods
produce instances:

- `WindowPositionInfo.None()` — Invalid position sentinel.
- `WindowPositionInfo.Automatic()` — Triggers automatic cascading.
- `WindowPositionInfo.FromWindow(position, window)` — Captures the
  current position and actual size of an existing WPF window (executed
  on the UI thread via `CommonOps.Invoke()`).

Each window tracks its `WindowPositionInfo` and updates it on
`LocationChanged` and `SizeChanged` events, enabling position persistence
across window restarts.

#### E.7.3 Automatic Cascading Algorithm

When `WindowPosition.Automatic` is specified:

1. `GetNextWindowPosition()` returns the next position in the cascade
   sequence (TopLeft → TopCenter → ... → BottomRight → TopLeft).
2. `CommonOps.CalculatePosition()` computes the actual pixel coordinates
   relative to the parent (factory) window's rectangle, applying 10-pixel
   margins.
3. The new window's `Left` and `Top` are set, placing it at the computed
   position.

This ensures that each new window appears at a different screen location,
preventing complete overlap.

#### E.7.4 Window Registry Coordination

The `WindowRegistrar` class manages the lifecycle of all windows:

- **Registration:** `RegisterWindow(name, window, owned)` — Adds a window
  to the dictionary.  If a different window already exists under the same
  name, the old window is closed (if owned) before the new one is added.
- **Ownership:** The `owned` flag controls whether the registrar is
  responsible for closing the window during shutdown.  Unowned windows may
  be managed externally.
- **Discovery:** `FindWindow(name, windowType)` — Linear search by name
  and/or type.  Either parameter can be null for wildcard matching.
- **Coordinated shutdown:** `Shutdown(application)` — Closes all registered
  windows in order: for each window, calls `UnregisterWindow()` (which
  removes interpreter channels) then `Close()`.  Respects the ownership
  flag — unowned windows are only force-closed if the application was
  created by the plugin.

#### E.7.5 Application Lifecycle

`Shell.Window` manages the WPF `Application` lifecycle:

- **`Main()`** — Creates the WPF `Application` singleton (or uses an
  existing one), creates the primary `InteractiveWindow`, registers it,
  and runs the message loop via `Application.Run()` or `ShowDialog()`.
- **Window counting:** `Window_Opened` increments `windowCount` via
  `Interlocked.Increment`; `Window_Closed` decrements it.  When the count
  reaches zero, `Shutdown()` is triggered automatically.
- **One-time execution:** Both `Main()` and `Shutdown()` use
  `Interlocked.Increment` guards to ensure they execute exactly once,
  even under concurrent access.

### E.8 HostStream — Stream Adapter

**Class:** `sealed class HostStream : Stream`

`HostStream` bridges the gap between Eagle's `System.IO.Stream`-based
channel system and the Featherlight window system's `IHostStreamManager`
interface.

**Read path:**
1. `Read(byte[], offset, count)` calls `streamManager.GetInput()` to
   get the current text content.
2. Converts the string to bytes and copies them into the buffer.
3. Tracks the read position (`int position`) for sequential reads.
4. Returns the number of bytes actually read.

**Write path:**
1. `Write(byte[], offset, count)` converts the byte range to a string
   via `StringBuilder`.
2. Calls `streamManager.Write(text)` to append to the output TextBox.
3. Throws `IOException` if the write fails.

**Seek support:** Only supports seeking to the beginning of the stream
(`SeekOrigin.Begin`, offset 0), which resets the read position.

**Auto-flush:** Handled by the `IHostStreamManager.AutoFlush` property
rather than by the stream itself.

### E.9 WindowTraceListener — Asynchronous Trace Capture

**Class:** `sealed class WindowTraceListener : TraceListener`

Captures `System.Diagnostics.Trace` output and routes it to a dedicated
trace window without blocking the calling thread.

**Buffering strategy:**
- A `StringBuilder` accumulates trace messages.
- A `System.Threading.Timer` fires at the configured interval
  (`writeMilliseconds`, default 10 seconds) and drains the buffer.
- If the buffer exceeds `bufferWriteSize` (1MB), a manual flush is
  triggered immediately within the `Write()` call.

**Async semantics:** The buffer drain calls `streamManager.WriteAsync()`
(which uses `BeginInvoke()` internally), ensuring that trace output never
blocks the thread generating the trace messages.

**Thread safety:** All buffer access is protected by a `syncRoot` lock.
The lock is held only during buffer manipulation — never during the
`WriteAsync()` call's actual UI dispatch.

### E.10 Visual Theme

All Featherlight windows share a consistent dark-blue color theme:

| Element | Background | Text | Font |
|---------|-----------|------|------|
| Input TextBox | #232D3C (dark navy) | White | Courier New 16px |
| Output TextBox | #485D7C (slate blue) | White | Courier New 14px |
| Buttons | #76869D (light blue-gray) | White | Default |
| Grid/Window | #485D7C (slate blue) | — | — |
| Status Label | Transparent | White | 16px |

The input area uses a larger font than the output area, making the active
editing area more prominent.  All borders are white for contrast against
the dark backgrounds.  The fixed-width `Courier New` font ensures proper
alignment of tabular output, box-drawing characters, and indented code.

---

*This specification was generated by analyzing the Eagle source code in its
entirety, covering all public interfaces in `Library/Interfaces/Public/`,
all host implementations in `Library/Hosts/`, the interactive loop in
`Library/Components/Public/Interpreter.cs`, the interactive command dispatch
in `Library/Components/Private/InteractiveOps.cs`, all supporting
enumerations in `Library/Components/Public/Enumerations.cs`, the
Featherlight WPF Window host in
`Plugins/Commercial/Enterprise/Featherlight/Hosts/Window.cs`, the
Featherlight interactive window system in
`Plugins/Commercial/Enterprise/Featherlight/Windows/`, and the Demo
plugin in `Plugins/Commercial/Enterprise/Demo/`.*

---

## Appendix F: The Demo Plugin — Playback-Driven Host

This appendix documents the Demo plugin, which demonstrates a fundamentally
different host integration pattern from the Featherlight WPF host (Appendix D).
While Featherlight creates an entirely new graphical environment, the Demo
plugin **replaces the interpreter's existing console host** with a
playback-aware variant that can simulate interactive sessions from
pre-recorded scripts.

**Source:** `Plugins/Commercial/Enterprise/Demo/`

### F.1 Architecture Overview

The Demo plugin consists of three main components working together:

```tcl
 Demo  (Plugin)               Demo (Host)                Demo (Command)
  |                            |                          |
  | Initialize():              | ReadLine():              | startup:
  |   save original host       |   if playback active:    |   open script file
  |   create Demo host         |     read from TextReader |   configure timing
  |   replace interpreter host |   else:                  |   call Play()
  |                            |     fall back to Console |
  | Terminate():               |                          | stop:
  |   restore original host    | Play():                  |   call Stop()
  |   dispose Demo host        |   queue worker thread    |
  |                            |   write char-by-char     | shutdown:
  |                            |                          |   stop + exit
```

### F.2 Plugin Entry Point

**File:** `Plugins/Enterprise.cs` (~794 lines)
**ObjectId:** `1d54ed5b-9276-49d8-b4c4-4e44b86ed21f`

```csharp
[PluginFlags(
    PluginFlags.Primary | PluginFlags.User |
    PluginFlags.Commercial | PluginFlags.Host |
    PluginFlags.NoFunctions | PluginFlags.NoPolicies |
    PluginFlags.NoTraces)]
internal sealed class Enterprise : _Plugins.Default, IDemoPlugin, IDisposable
```

The `PluginFlags.Host` flag is significant — it signals to the interpreter
that this plugin participates in host management.

#### F.2.1 Host Replacement Pattern

The most distinctive architectural feature of the Demo plugin is its
**host replacement** strategy.  Unlike Featherlight (which provides a host
to a new interpreter), Demo **swaps out** the host on an existing interpreter:

**Initialization sequence (`Initialize`):**

1. Verify the current host type is supported (`Console` or `Wrapper`).
2. Acquire the interpreter lock (transactional).
3. Create or retrieve the Demo host instance.
4. Save the original host reference in `savedHost`.
5. Set `interpreter.Host = demoHost`.
6. Call base plugin initialization.

**Termination sequence (`Terminate`):**

1. Acquire the interpreter lock.
2. Verify the current host is the Demo host.
3. Restore `interpreter.Host = savedHost`.
4. Dispose the Demo host if the plugin created it.
5. Clear all references.
6. Call base plugin termination.

**Supported host types:**

The plugin explicitly validates the host type before initialization.  Only
`Eagle._Hosts.Console` and `Eagle._Hosts.Wrapper` (and their subclasses)
are accepted.  Any other host type causes initialization to fail with a
descriptive error message.

### F.3 Host Implementation

**File:** `Hosts/Demo.cs` (~1,244 lines)
**ObjectId:** `49581ca5-a689-4638-8562-d708d7e70ca1`

```csharp
public class Demo : _Hosts.Console, IDemoHost, IDisposable
```

The Demo host extends `Console` (the concrete bottom of the reference
implementation hierarchy — Section 19), inheriting the complete host
interface stack.  It overrides specific methods to inject playback behavior
while falling back to `Console` for everything else.

#### F.3.1 Host Flags

```csharp
HostFlags.ForcePrompt | HostFlags.Recording |
HostFlags.Playback | base.MaybeInitializeHostFlags()
```

- **`ForcePrompt`** — ensures prompts are displayed even though playback
  makes the input appear "redirected."
- **`Recording`** — signals that the host supports recording sessions.
- **`Playback`** — signals that the host supports playback of recorded input.

These are combined with all base `Console` host flags.

#### F.3.2 ReadLine Override — Dual Input Mode

The `ReadLine()` override is the heart of the playback system:

```tcl
ReadLine():
  1. Check PlayInput (TextReader)
     |
     +-- non-null: Read next line from playback stream
     |     |
     |     +-- line != null:
     |     |     Reset stop/done events
     |     |     Call Play(line, milliseconds, stopEvent, doneEvent)
     |     |     Wait for doneEvent (playback of line complete)
     |     |     If PlayUsePause && non-comment: Pause()
     |     |     Return the line as input
     |     |
     |     +-- line == null (EOF):
     |           If StopOnEndOfStream: ShutdownAndStop()
     |           Clear PlayInput
     |           Fall through to base ReadLine
     |
     +-- null (no playback):
           If FailOnBaseReadLine: return false
           Else: call base.ReadLine() (standard Console input)
```

This dual-mode design means the Demo host behaves identically to a standard
Console host when playback is not active — the interpreter cannot
distinguish between "real" and "demo" input.

#### F.3.3 IsInputRedirected and IsOpen

Two additional overrides support the dual-mode behavior:

- **`IsInputRedirected()`** — returns `true` when `PlayActive` (playback
  stream is set), otherwise delegates to `base.IsInputRedirected()`.
- **`IsOpen()`** — when `ClosedOnInactive` is true, returns `PlayActive`
  (false when playback ends, causing the interactive loop to exit).
  Otherwise delegates to `base.IsOpen()`.

#### F.3.4 Pause Override

The `Pause()` override adds an optional beep before the standard console
pause, controlled by the `PlayPauseBeep` flag.  This provides an audible
cue during demonstrations that a pause point has been reached.

### F.4 Playback Engine

The playback system uses a worker thread to output script content
character-by-character with configurable timing.

#### F.4.1 Play Method

`Play(string value, int timeout, ref Result error)` queues a playback
operation:

1. Creates a `PlayThreadStart` worker delegate with the line to play.
2. Queues it via `QueueWorkItem()`.
3. The worker thread writes each character via `Write(char)`, sleeping
   `PlayMilliseconds` between characters.
4. Monitors `stopEvent` between characters for cancellation.
5. Signals `doneEvent` when the line is complete.

The caller (`ReadLine`) waits on `doneEvent` before returning, ensuring
the playback of each line is visually complete before the interpreter
processes it.

#### F.4.2 Stop Method

`Stop(int timeout, ref Result error)` signals the playback to halt:

1. Sets the `stopEvent`, interrupting the character-by-character loop.
2. Waits up to `StopMilliseconds` for `doneEvent` to confirm the worker
   thread has finished.

#### F.4.3 Pause Detection

`PlayNeedsPause(string value)` determines whether a line warrants a pause.
Comment lines (starting with `#`) are excluded from pausing — the pause
feature is intended for command lines that the audience should read before
execution proceeds.

### F.5 Timeout Auto-Shutdown

The Demo host includes an optional auto-shutdown mechanism to prevent
demo sessions from running indefinitely:

- **`RefreshTimeout()`** — creates (or refreshes) a background timeout
  thread.  The thread sleeps for `TimeoutMilliseconds` and then calls
  `ShutdownAndStop()`.
- **`TimeoutMilliseconds = -1`** (default) disables the timeout entirely.
- Each call to `RefreshTimeout()` replaces any existing timeout thread,
  effectively resetting the countdown.

### F.6 Ctrl-C Handling

The Demo host installs a custom `ConsoleCancelEventHandler` via
`SetupDemoCancelKeyPressHandler()`.  When Ctrl-C is pressed:

- If `StopOnCancel` is true, the handler signals the stop event and
  calls `ShutdownAndStop()`.
- The event is marked as handled (`e.Cancel = true`) to prevent the
  default process termination behavior.

### F.7 Command Interface

**File:** `Commands/Demo.cs` (~1,125 lines)
**ObjectId:** `90a4ec5c-ef8c-46e4-aceb-a19a09d839f2`

```csharp
[CommandFlags(CommandFlags.Unsafe)]
[ObjectGroup("managedEnvironment")]
```

The `demo` command provides 18 sub-commands for controlling the playback
system.

#### F.7.1 Session Lifecycle Commands

| Sub-command | Purpose |
|-------------|---------|
| `startup` | Open a script file and begin playback |
| `stop` | Signal current playback to halt |
| `shutdown` | Stop playback and optionally exit the interpreter |
| `reset` | Reset all settings to defaults |

**`demo startup` options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `-path` | string | `demo.eagle` | Script file to play |
| `-playmilliseconds` | int | 50 | Delay between characters (ms) |
| `-stopmilliseconds` | int | 2000 | Timeout for stop operation (ms) |
| `-timeoutmilliseconds` | int | -1 | Auto-shutdown timeout (ms); -1 disables |
| `-pause` | bool | false | Pause after each non-comment line |
| `-beep` | bool | false | Beep before each pause |
| `-cancel` | bool | false | Stop on Ctrl-C |
| `-endofstream` | bool | true | Stop when script ends |
| `-basereadline` | bool | false | Allow fallback to real console input |
| `-closed` | bool | false | Report host as closed when inactive |
| `-native` | bool | false | Use native keyboard API (Windows only) |

#### F.7.2 Property Commands

Individual sub-commands allow querying and modifying each playback
parameter at runtime:

| Sub-command | Property |
|-------------|----------|
| `active` | `PlayActive` (read-only when no argument) |
| `playmilliseconds` | `PlayMilliseconds` |
| `stopmilliseconds` | `StopMilliseconds` |
| `timeoutmilliseconds` | `TimeoutMilliseconds` |
| `pause` | `PlayUsePause` |
| `beep` | `PlayPauseBeep` |
| `cancel` | `StopOnCancel` |
| `endofstream` | `StopOnEndOfStream` |
| `basereadline` | `FailOnBaseReadLine` |
| `closed` | `ClosedOnInactive` |
| `debuglevel` | `PlayDebugLevel` |

#### F.7.3 Informational Commands

| Sub-command | Purpose |
|-------------|---------|
| `about` | Plugin version and description |
| `certificate` | Licensing certificate file path |
| `isolated` | Whether the plugin is loaded in an isolated AppDomain |
| `options` | Compile-time configuration options |

### F.8 IDemoHost and IDemoPlugin Interfaces

**IDemoHost** (`Interfaces/Public/DemoHost.cs`)
**ObjectId:** `150d744f-6532-4272-9125-a7f6dbd5e7b5`

Extends `IHost` with all playback-specific properties and methods.  Key
members:

```csharp
public interface IDemoHost : IHost
{
    // Synchronization
    object PlaySyncRoot { get; set; }
    object TimeoutSyncRoot { get; set; }

    // Playback state
    TextReader PlayInput { get; set; }
    bool PlayActive { get; }

    // Timing configuration
    int PlayMilliseconds { get; set; }
    int StopMilliseconds { get; set; }
    int TimeoutMilliseconds { get; set; }

    // Behavior flags
    bool PlayUsePause { get; set; }
    bool PlayPauseBeep { get; set; }
    bool StopOnCancel { get; set; }
    bool StopOnEndOfStream { get; set; }
    bool FailOnBaseReadLine { get; set; }
    bool ClosedOnInactive { get; set; }

    // Thread coordination
    EventWaitHandle PlayStopEvent { get; set; }
    EventWaitHandle PlayDoneEvent { get; set; }

    // Operations
    bool PlayNeedsPause(string value);
    bool RefreshTimeout();
    ReturnCode Play(string value, int timeout, ref Result error);
    ReturnCode Stop(int timeout, ref Result error);
}
```

**IDemoPlugin** (`Interfaces/Public/DemoPlugin.cs`)
**ObjectId:** `5e8c2e7c-96b0-4368-b25d-90f027a00147`

Extends `IPlugin` with host management:

```csharp
public interface IDemoPlugin : IPlugin
{
    IHost SavedHost { get; set; }
    IDemoHost DemoHost { get; set; }
}
```

### F.9 Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `PlayMilliseconds` | 50 ms | Default delay between characters |
| `StopMilliseconds` | 2,000 ms | Default stop operation timeout |
| `TimeoutMilliseconds` | -1 (infinite) | Default auto-shutdown timeout (disabled) |
| `PlayUsePause` | false | Default: no pause after lines |
| `PlayPauseBeep` | false | Default: no beep before pause |
| `PlayDebugLevel` | -1 (invalid) | Default: no debug tracing |
| `StopOnCancel` | false | Default: don't stop on Ctrl-C |
| `StopOnEndOfStream` | true | Default: stop when script ends |
| `FailOnBaseReadLine` | false | Default: allow fallback to Console input |
| `ClosedOnInactive` | false | Default: host stays open |
| `Native` | false | Default: don't use native keyboard API |
| `Exit` | false | Default: don't exit after shutdown |
| `FileName` | `"demo.eagle"` | Default script file name |
| `ErrorLevel` | 1 | Debug level for exceptions |
| `TraceLevel` | 2 | Debug level for key trace points |

### F.10 Thread Safety

The Demo plugin uses three separate lock objects:

| Lock Object | Scope | Protects |
|------------|-------|----------|
| `Enterprise.syncRoot` | Plugin instance | `savedHost`, `demoHost`, `created`, licensing state |
| `Demo.playSyncRoot` | Host instance | `playInput`, play timing fields, play events, play behavior flags |
| `Demo.timeoutSyncRoot` | Host instance | `timeoutThread`, `timeoutMilliseconds` |

`EventWaitHandle` objects (`playStopEvent`, `playDoneEvent`) coordinate
between the `ReadLine` caller, the playback worker thread, and the stop
mechanism.

### F.11 Comparison with Featherlight Window Host

| Aspect | Demo Host | Featherlight Window Host |
|--------|-----------|--------------------------|
| **Base class** | `Console` | `Core` |
| **Integration pattern** | Replaces existing host | Provides host to new interpreter |
| **I/O target** | Same `System.Console` | WPF text controls via `HostStream` |
| **Input source** | `TextReader` playback stream | `IHostInputWindow.ReadLine()` |
| **Primary use case** | Automated demonstrations | Interactive windowed REPL |
| **Color support** | Full (inherited from Console) | Not implemented (WPF styling) |
| **Cursor positioning** | Full (inherited from Console) | Not implemented |
| **Multiple windows** | Single console | Multiple typed windows (6 types) |
| **Thread model** | Worker threads for play/timeout | STA thread per WPF window |
| **Fallback behavior** | Falls back to real Console input | No fallback (always windowed) |
| **Plugin flags** | `Host \| NoFunctions \| NoPolicies \| NoTraces` | (Plugin-level) |
| **IsInputRedirected** | `true` during playback, else delegates | Always `true` |
| **ForcePrompt** | Yes (during playback) | Yes (always) |

### F.12 Implementation Guidance

The Demo plugin demonstrates several patterns valuable for building
host-replacing plugins:

1. **Save and restore the original host** — always store the original
   `interpreter.Host` and restore it during `Terminate()`, even if
   errors occur during the plugin's operation.

2. **Validate host type compatibility** — check the current host type
   before attempting replacement to provide clear error messages.

3. **Use `PluginFlags.Host`** — this flag signals the interpreter that
   the plugin participates in host management.

4. **Fall back gracefully** — when playback is inactive, delegate to
   the base class so the host behaves identically to a standard Console
   host.

5. **Separate synchronization concerns** — use distinct lock objects for
   playback state and timeout state to minimize contention.

6. **Coordinate threads with events** — `ManualResetEvent` objects
   provide clean signaling between the ReadLine caller, playback worker,
   and stop/timeout threads.
