# Eagle `host` Command — Deep-Dive Analysis

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `host` command internals, including the 33 primary sub-commands plus 8 nested `host screen` sub-commands, the 15-interface host hierarchy (`IHost` → `IInteractiveHost`, `IStreamHost`, `IColorHost`, `IBoxHost`, `IPositionHost`, `ISizeHost`, `IReadHost`, `IWriteHost`, `IDebugHost`, `IThreadHost`, `IFileSystemHost`, `IProcessHost`, `IStreamHost`, `IInformationHost`, `IDisplayHost`), the console lifecycle state machine (`closeCount`, `referenceCount`, `mustBeOpenCount`), safety interlocks (`SystemConsoleMustBeOpen`, `CheckActiveReadsAndWrites`, read/write level tracking, kiosk mode lock), the Windows-native screen buffer management system (push/pop stack, `CreateConsoleScreenBuffer`/`SetConsoleActiveScreenBuffer` P/Invoke, standard handle redirection), `HostFlags` (60+ capability flags), `HostCreateFlags` (30+ creation flags), box drawing, color theming, font control, and the `Default` → `Shell` → `Core` → `Console` class hierarchy. For basic command syntax, see [`core_language.md`](core_language.md#cmd-host). For usage examples, see [`core_examples.md`](core_examples.md#ex-host).

## 1. Executive Summary

The Eagle `host` command is an ensemble providing **33 primary sub-commands**
plus **8 nested `host screen` sub-commands** for programmatic control of the
interactive console/terminal host. While Tcl provides limited console
interaction through `puts`, `gets`, and the `chan configure` mechanism, Eagle
exposes the full host lifecycle, Windows console API, color theming, box
drawing, cursor positioning, window sizing, font control, screen buffer
management, and stream redirection from script level.

The command carries `CommandFlags.Unsafe | Critical | NonStandard` and
belongs to the `"managedEnvironment"` object group. It is **not** available
in safe interpreters.

Two aspects of this command deserve special attention:

1. **Host lifecycle safety interlocks** — The `host open` / `host close`
   sub-commands interact with a multi-layered state machine involving atomic
   counters (`closeCount`, `referenceCount`, `mustBeOpenCount`), read/write
   level tracking, shared-console detection, and kiosk mode locking. Every
   I/O operation checks host readiness through `SystemConsoleMustBeOpen()`
   before touching `System.Console`, and `host close` cannot proceed while
   any read or write operation is in progress.

2. **Screen buffer management** — The `host screen` sub-commands provide
   push/pop access to multiple Windows console screen buffers via direct
   P/Invoke to `CreateConsoleScreenBuffer` and `SetConsoleActiveScreenBuffer`.
   This enables applications to switch between independent screen contents
   while preserving the original display — a capability that is, to the
   best of our knowledge, unique among scripting languages with interactive
   REPLs. Even languages with extensive terminal libraries (Python's
   `curses`, Ruby's `io/console`, Node.js's `blessed`) do not expose
   native console screen buffer stacking from their standard REPL.

Key differentiators from Tcl:

| Area | Tcl | Eagle |
|------|-----|-------|
| Built-in host command | None | 33 + 8 sub-commands |
| Console lifecycle | Implicit (always available) | Explicit `open`/`close` with safety interlocks |
| Screen buffers | None | Push/pop stack of native Win32 screen buffers |
| Color control | ANSI escape codes (manual) | `host color` / `host namedcolor` with theme support |
| Cursor positioning | ANSI escape codes (manual) | `host position` with absolute and relative coords |
| Window sizing | None | `host size` with auto-rollback on failure |
| Box drawing | None | `host writebox` with named themes and box/text colors |
| Font control | None | `host font` (Windows console font face/size) |
| Input reading | `gets stdin` | `host readchar` / `host readkey` / `host readline` |
| Stream redirection | `chan configure` | `host inchan` / `host outchan` / `host errchan` + `host redirected` |
| Capability flags | None | `host flags` returns 60+ `HostFlags` |
| Host state query | None | `host query` / `host isopen` / `host flags` |
| Beep | None | `host beep` with frequency/duration |
| Sleep | `after N` (event-loop) | `host sleep` (thread-level, capability-gated) |

---

## 2. Why the Eagle `host` Command Has No Tcl Equivalent

Tcl assumes the terminal is always available and relies on the operating
system for console management. Eagle treats the host as a first-class,
pluggable subsystem:

- **Interface hierarchy** — 15 interfaces define host capabilities, from
  the minimal `IInteractiveHost` (prompt, read, write, `IsOpen()`) through
  specialized contracts (`IColorHost`, `IBoxHost`, `ISizeHost`,
  `IPositionHost`) to the full `IHost` which aggregates everything
- **Class hierarchy** — four levels of implementation (`Default` abstract
  base → `Shell` → `Core` → `Console`) with each level adding
  platform-specific behavior
- **Lifecycle management** — the console can be opened, closed, and
  reopened at runtime, with atomic counters preventing use-after-close
  and close-during-I/O races
- **Screen buffers** — direct Win32 API access enables multiple
  independent screen contents with stack-based switching, something no
  other scripting REPL provides natively
- **Capability negotiation** — `HostFlags` advertises what the host
  supports (color, resize, sleep, yield, custom info, etc.), allowing
  scripts to adapt to the host's capabilities

### Source files

| File | Role |
|------|------|
| `Commands/Host.cs` (~6,200+ lines) | Command implementation: 33 + 8 sub-commands |
| `Interfaces/Public/Host.cs` | `IHost` master interface (aggregates all host interfaces) |
| `Interfaces/Public/InteractiveHost.cs` | `IInteractiveHost` base interface (minimum for interactive loop) |
| `Interfaces/Public/StreamHost.cs` | `IStreamHost` — In/Out/Error streams, encodings, redirection |
| `Interfaces/Public/ColorHost.cs` | `IColorHost` — foreground/background colors, themes |
| `Interfaces/Public/PositionHost.cs` | `IPositionHost` — cursor position |
| `Interfaces/Public/SizeHost.cs` | `ISizeHost` — window/buffer sizing |
| `Interfaces/Public/BoxHost.cs` | `IBoxHost` — decorative box drawing |
| `Interfaces/Public/DisplayHost.cs` | `IDisplayHost` — composite: IBoxHost + IColorHost + IPositionHost + ISizeHost + IWriteHost |
| `Interfaces/Public/ReadHost.cs` | `IReadHost` — character/key reading |
| `Interfaces/Public/WriteHost.cs` | `IWriteHost` — colored text output |
| `Interfaces/Public/DebugHost.cs` | `IDebugHost` — debug/error output, cancel/exit, clone |
| `Interfaces/Public/ThreadHost.cs` | `IThreadHost` — thread creation, sleep, yield |
| `Interfaces/Public/FileSystemHost.cs` | `IFileSystemHost` — stream/data access |
| `Interfaces/Public/ProcessHost.cs` | `IProcessHost` — exit control |
| `Interfaces/Public/InformationHost.cs` | `IInformationHost` — debugger info display (40+ WriteXxxInfo methods) |
| `Hosts/Default.cs` | Abstract base host implementation |
| `Hosts/Shell.cs` | Shell-level host (adds interactive shell support) |
| `Hosts/Core.cs` | Core host (adds plugin support) |
| `Hosts/Console.cs` | Console host (full `System.Console` + native Win32 integration) |
| `Components/Private/NativeConsole.cs` | Win32 P/Invoke: screen buffers, handles, fonts |
| `Components/Private/ConsoleOps.cs` | Console utilities: shared reference counting, stream reset |
| `Components/Private/HostOps.cs` | Host utilities: safe host retrieval, prompt generation |

---

## 3. Host Interface Hierarchy

Eagle's host system is built on a layered interface architecture where
`IInteractiveHost` defines the minimum requirements and `IHost` aggregates
everything.

### 3.1 Interface Inheritance Tree

```
IInteractiveHost (base — minimum for interactive loop)
├── IStreamHost        (In/Out/Error streams, encodings, redirection)
├── IColorHost         (foreground/background, themes, named colors)
├── IPositionHost      (cursor position get/set)
├── ISizeHost          (window/buffer sizing)
├── IBoxHost           (decorative box drawing)
├── IReadHost          (character and key reading)
├── IWriteHost         (colored text output)
├── IDebugHost         (debug/error output, cancel, exit, clone)
├── IThreadHost        (thread creation, sleep, yield)
├── IFileSystemHost    (stream/data access by path)
├── IProcessHost       (exit control: CanExit, CanForceExit)
├── IInformationHost   (debugger info: 40+ WriteXxxInfo methods)
│
├── IDisplayHost = IBoxHost + IColorHost + IPositionHost + ISizeHost + IWriteHost
│
└── IHost = IDisplayHost + IInteractiveHost + IStreamHost + IDebugHost
            + IReadHost + IWriteHost + IThreadHost + IFileSystemHost
            + IProcessHost + IInformationHost
```

### 3.2 Key Interface Members

**IInteractiveHost** (the minimum for interactive use):

| Member | Purpose |
|--------|---------|
| `IsOpen()` | **Critical lifecycle check** — returns whether host is usable |
| `Title` | Get/set window title |
| `Prompt()` | Display prompt (Start or Continue) |
| `ReadLine()` | Read a line of input |
| `Write()` / `WriteLine()` | Write text output |
| `Pause()` / `Flush()` | Pause for input / flush output |
| `GetHostFlags()` | Return capability flags |
| `GetHeaderFlags()` | Return debugger header display flags |
| `ReadLevels` / `WriteLevels` | Active I/O operation counts |
| `BeginProcessing()` / `EndProcessing()` / `DoneProcessing()` | Input processing hooks |
| `IsInputRedirected()` | Check if stdin is redirected |

**IHost** (adds on top of all inherited interfaces):

| Member | Purpose |
|--------|---------|
| `Open()` | Open the host for interaction |
| `Close()` | Close the host and release resources |
| `Discard()` | Discard buffered input |
| `Reset()` | Reset host to default state |
| `Clear()` | Clear the display |
| `Beep()` | Produce audible alert |
| `QueryState()` | Return full host state for introspection |
| `GetMode()` / `SetMode()` | Channel mode flags |
| `BeginSection()` / `EndSection()` | Logical output sections |
| `Profile` / `DefaultTitle` | Configuration properties |
| `HostCreateFlags` | Creation-time configuration |
| `Echo` | Input echo toggle |

### 3.3 Implementation Class Hierarchy

```
Default (abstract)
  └── Shell (adds interactive shell support)
       └── Core (adds plugin/host integration)
            └── Console (full System.Console + Win32 native)
```

Each level adds platform-specific behavior:

| Class | Key additions |
|-------|---------------|
| `Default` | Abstract base: box character sets, output style, color management framework, `DetailFlags`-based formatting |
| `Shell` | Interactive loop support, prompt handling, history integration |
| `Core` | Plugin host integration, core command support |
| `Console` | Full `System.Console` implementation, Win32 P/Invoke for native console API, screen buffers, font control, `closeCount` state machine |

---

## 4. Host Lifecycle and Safety Interlocks

This section covers the safety interlock system in detail, as requested.
The interlocks exist to prevent use of a closed console, prevent closing
while I/O is in progress, and coordinate multi-instance/multi-AppDomain
access.

### 4.1 The Three Atomic Counters

The Console host uses three global atomic counters (accessed via
`Interlocked` operations) to manage lifecycle state:

| Counter | Scope | Purpose |
|---------|-------|---------|
| `closeCount` | Static (Windows only) | Tracks whether the console has been closed. >0 means closed. |
| `referenceCount` | Static | Counts active console host instances. Controls setup/teardown. |
| `mustBeOpenCount` | Static | Enables/disables `SystemConsoleMustBeOpen()` exception throwing. |

**`closeCount` state machine:**

```
Normal state:  closeCount == 0  →  WasConsoleClosed() == false
After close:   closeCount > 0   →  WasConsoleClosed() == true
After reopen:  closeCount == 0  →  WasConsoleClosed() == false
```

### 4.2 `host open` — Opening the Console

```
host open
```

**Implementation flow:**

1. `CheckDisposed()` — verify host not disposed
2. `PrivateAttachOrOpen(UseForce, UseAttach, ...)` — call
   `NativeConsole.Open()` to acquire/attach a console window
3. On success:
   - `UnbumpConsoleClosed()` — atomic decrement of `closeCount`
   - Guard: if counter went negative, immediately `BumpConsoleClosed()`
     to restore to 0
   - `Setup(this, true, true)` — force re-initialize console
     customizations (title, icon, mode, Ctrl-C handler)
4. Return result

The guard against negative `closeCount` handles the case where `Open()`
is called without a prior `Close()`.

### 4.3 `host close` — Closing the Console

```
host close
```

**Pre-condition checks (5 layers of safety):**

1. **Disposed check** — `CheckDisposed()` verifies host not disposed
2. **Kiosk lock** — if `interpreter.IsKioskLock()` returns true, Close()
   is refused with error `"cannot close host when a kiosk"` (requires
   `SHELL` compile flag)
3. **Active reads/writes** — `CheckActiveReadsAndWrites()` blocks if
   any I/O is in progress:
   - Local `ReadLevels > 0` → error: "N local reads pending"
   - Shared `SharedReadLevels > 0` → error: "N shared reads pending"
   - Local `WriteLevels > 0` → error: "N local writes pending"
   - Shared `SharedWriteLevels > 0` → error: "N shared writes pending"
   - `ConsoleOps.IsShared()` → error: "may be in use by other
     application domains" (checks `referenceCount > 1`)

**Close flow (after pre-conditions pass):**

4. `Setup(this, false, true)` — force un-setup: remove Ctrl-C handler,
   restore mode, remove icon, restore title
5. `UnhookSystemConsoleControlHandler()` — disable Ctrl-C handling
6. **Nested bump pattern:**
   ```
   BumpConsoleClosed()           ← outer lock (closeCount → 1)
   try:
     PrivateClose()              ← NativeConsole.Close() / FreeConsole()
     if success:
       BumpConsoleClosed()       ← inner lock (closeCount → 2)
   finally:
     UnbumpConsoleClosed()       ← remove outer lock (closeCount → 1)
   ```
   Result: `closeCount` remains at 1 after successful close

The nested bump pattern ensures:
- If `PrivateClose()` is interrupted, the outer lock still protects
- If `PrivateClose()` succeeds, a permanent lock remains
- `WasConsoleClosed()` returns true for all subsequent checks

**NativeConsole.Close() internals:**
- Calls `FreeConsole()` Win32 API
- Zeros `inputHandle` and `outputHandle`
- Calls `ResetScreenBuffers()` and `ResetActiveScreenNames()` to clean
  up screen buffer state
- Calls `ResetHandles()` to synchronize standard handles

### 4.4 Read/Write Level Tracking

Every read and write operation is bracketed by level tracking to prevent
close-during-I/O:

```
EnterReadLevel():
  Interlocked.Increment(ref sharedReadLevels)   ← static/shared
  base.EnterReadLevel()                          ← per-instance

ExitReadLevel():
  base.ExitReadLevel()                           ← per-instance
  Interlocked.Decrement(ref sharedReadLevels)    ← static/shared
```

The same pattern applies to `EnterWriteLevel()` / `ExitWriteLevel()`.

**Usage in every I/O operation:**

```csharp
public override bool ReadLine(ref string value)
{
    CheckDisposed();
    EnterReadLevel();                           // 1. Track
    try
    {
        SystemConsoleInputMustBeOpen(this);      // 2. Check
        // ... actual System.Console.ReadLine()  // 3. I/O
        return true;
    }
    catch (IOException) { SetReadException(true); return false; }
    catch (ScriptException) { return false; }    // console not open
    finally
    {
        ExitReadLevel();                         // 4. Untrack
    }
}
```

This pattern is replicated across **every** read and write method in the
Console host. The `finally` block guarantees level decrements even on
exceptions.

### 4.5 `SystemConsoleMustBeOpen()` — The Central Guard

This family of methods is the primary safety interlock. They are called
at the start of every I/O operation and throw `ScriptException` if the
console is not available.

**Master check:**

```csharp
protected static void SystemConsoleMustBeOpen(bool window)
{
    if (!ThrowOnMustBeOpen)     // gate: only throw if enabled
        return;
    if (!SystemConsoleIsOpen(window))
        throw new ScriptException("system console is not available");
}
```

**`SystemConsoleIsOpen()` logic (Windows):**

1. If `WasConsoleClosed()` returns true → **false** (closeCount > 0)
2. If `window` is true AND `NativeConsole.IsSupported()` AND
   `!NativeConsole.IsOpen()` → **false**
3. Otherwise: return `SystemConsoleInputIsOpen()` which tests
   `System.Console.TreatControlCAsInput` in a try/catch

**Specialized variants:**

| Method | Checks | Error message |
|--------|--------|---------------|
| `SystemConsoleMustBeOpen(window)` | Console window available | "system console is not available" |
| `SystemConsoleInputMustBeOpen(host)` | Input channel available (unless redirected) | "system console input channel is not available" |
| `SystemConsoleOutputMustBeOpen(host)` | Output channel available (unless redirected) | "system console output channel is not available" |
| `SystemConsoleErrorMustBeOpen(host)` | Error channel available (unless redirected) | "system console error channel is not available" |

Each specialized variant checks:
- Is the specific channel redirected? If so, it's usable regardless of
  console state.
- Is `System.Console` functional? Tested by probing a property
  (`TreatControlCAsInput` for input, `CursorVisible` for output).
- Is the system console redirected at the OS level?

### 4.6 `ThrowOnMustBeOpen` — Exception Throwing Control

The `mustBeOpenCount` counter gates whether `SystemConsoleMustBeOpen()`
throws or silently returns:

```
ThrowOnMustBeOpen = (mustBeOpenCount > 0)
```

- The Console constructor calls `EnableThrowOnMustBeOpen()` which
  increments the counter
- `BeginThrowOnMustBeOpen()` / `EndThrowOnMustBeOpen()` allow temporary
  override (save/restore pattern)
- When `ThrowOnMustBeOpen` is false, all I/O operations silently succeed
  even if the console is closed — this is used during shutdown sequences

### 4.7 Cross-Subsystem Host State Checking

Multiple subsystems check host state before interacting:

| Subsystem | Check | Purpose |
|-----------|-------|---------|
| Interpreter | `host != null` check before all host operations | Prevent null reference |
| Interactive loop | `IsOpen()` before entering loop | Prevent loop on closed host |
| Debug system | `IDebugHost` methods check host availability | Prevent debug output to closed host |
| Channel system | `IsInputRedirected()` / `IsOutputRedirected()` / `IsErrorRedirected()` + `WasConsoleClosed()` | Adapt to redirected or closed channels |
| Host command | Every sub-command checks `IHost host = interpreter.InternalHost; if (host != null)` | Universal null guard |
| Stream properties | `DefaultIn`/`DefaultOut`/`DefaultError` call `SystemConsoleMustBeOpen(true)` | Throw before opening dead streams |
| HostOps | `TryGet()` / `TryGetInteractive()` use timeout-based safe retrieval | Prevent deadlock on disposed hosts |

### 4.8 Reference Counting and Setup/Teardown

The `referenceCount` counter ensures console initialization happens
exactly once (on the first Console instance) and teardown happens on the
last:

```
Setup(host, setup=true, force):
  newCount = Interlocked.Increment(ref referenceCount)
  if ShouldSetup(newCount, true, force):     // true if count==1 or force
    SetupTitle(true)
    SetupIcon()
    SetupMode(true)
    SetupCancelKeyPressHandler(true)

Setup(host, setup=false, force):
  newCount = Interlocked.Decrement(ref referenceCount)
  if ShouldSetup(newCount, false, force):    // true if count<=0 or force
    SetupCancelKeyPressHandler(false)
    SetupMode(false)
    SetupIcon(false)
    SetupTitle(false)
```

`ConsoleOps.IsShared()` checks `referenceCount > 1` to detect
multi-instance scenarios, blocking `host close` when the console is
shared.

---

## 5. Screen Buffer Management (Windows-Only)

This section covers the `host screen` sub-commands, which provide direct
access to Windows console screen buffers. This capability is, to the best
of our knowledge, **unique among scripting languages with interactive
REPLs**.

### 5.1 What Makes This Unique

Most scripting languages that provide terminal control do so through
abstraction layers:

| Language | Terminal library | Screen buffer stacking |
|----------|-----------------|----------------------|
| Python | `curses` / `blessed` | No — single logical screen with `curses` windows |
| Ruby | `io/console` | No |
| Node.js | `blessed` / `ink` | No — virtual screens only |
| Perl | `Term::ReadLine` / `Curses` | No |
| Tcl | `Expect` / ANSI escapes | No |
| **Eagle** | **`host screen`** | **Yes — native Win32 screen buffer stack** |

Eagle's `host screen` sub-commands call the Win32 API directly:
- `CreateConsoleScreenBuffer()` creates a new independent screen buffer
  with its own character grid, attributes, and cursor position
- `SetConsoleActiveScreenBuffer()` makes a buffer visible
- The push/pop stack pattern enables arbitrary nesting
- When switching buffers, standard output/error handles are redirected
  to the new buffer and all interpreter channels are reset

This means a script can:
1. Create a fresh screen buffer
2. Push it (switching the visible display)
3. Write arbitrary content to it
4. Pop back to the original (which is perfectly preserved)
5. Delete the temporary buffer

No terminal library emulation is involved — each buffer is a genuine
Win32 console screen buffer with independent content.

### 5.2 State Management

Screen buffer state is maintained in `NativeConsole` using three
synchronized data structures:

| Variable | Type | Purpose |
|----------|------|---------|
| `screenBuffers` | `IntPtrDictionary` (name → handle) | All created screen buffers |
| `activeScreenNames` | `Stack<string>` | Push/pop history for buffer switching |
| `savedActiveScreenName` | `string` | Currently active buffer name |
| `outputHandle` | `IntPtr` | Primary (original) console output handle |

All access is synchronized via `lock (syncRoot)`.

### 5.3 Sub-Command Reference

#### `host screen create`

Creates a new Win32 console screen buffer.

**Implementation:**
1. Calls `MaybeOpenHandles()` to ensure console handles are available
2. Calls `CreateConsoleScreenBuffer()` P/Invoke with:
   - Access: `GENERIC_READ_WRITE`
   - Share: `FILE_SHARE_READ_WRITE`
   - Flags: `CONSOLE_TEXTMODE_BUFFER`
3. Registers process exit handler for cleanup
4. Stores handle in `screenBuffers` dictionary
5. Returns the buffer name (string representation of handle)

```tcl
set buf [host screen create]   ;# Returns buffer name (e.g. "1234")
```

#### `host screen push name`

Switches to a named screen buffer, saving the current one on the stack.

**Implementation:**
1. Looks up `name` in `screenBuffers` dictionary
2. Calls `SetConsoleActiveScreenBuffer()` P/Invoke
3. Calls `ResetHandles()` to redirect stdout/stderr to the new buffer
4. Calls `HostOps.ResetAllInterpreterStandardChannels()` to update all
   interpreter channel objects
5. Pushes `savedActiveScreenName` onto `activeScreenNames` stack
6. Sets `savedActiveScreenName = name`

```tcl
host screen push $buf          ;# Switch to buffer, save current
```

#### `host screen pop`

Returns to the previous screen buffer by popping the stack.

**Implementation:**
1. Pops from `activeScreenNames` stack
2. If popped name is not null: looks up in `screenBuffers`, calls
   `SetConsoleActiveScreenBuffer()`
3. If popped name is null (bottom of stack): restores `outputHandle`
   (the original primary buffer)
4. Resets handles and interpreter channels

```tcl
host screen pop                ;# Return to previous buffer
```

#### `host screen delete name ?active?`

Deletes a screen buffer. By default, refuses to delete the active buffer
(unless `active` is true).

**Safety check:** If `name` equals `savedActiveScreenName` and `active`
is false, returns error: `"cannot close active screen buffer"`.

```tcl
host screen delete $buf        ;# Delete buffer (must not be active)
host screen delete $buf true   ;# Force delete even if active
```

#### `host screen exists name ?primary?`

Checks whether a screen buffer exists. With `primary` true, also checks
the primary output handle.

```tcl
host screen exists $buf        ;# Check created buffers only
host screen exists $buf true   ;# Also check primary buffer
```

#### `host screen list ?pattern? ?primary?`

Lists all created screen buffer names, optionally filtered by pattern.
With `primary` true, includes the primary output handle.

```tcl
host screen list               ;# All created buffers
host screen list "*" true      ;# Include primary buffer
```

#### `host screen active`

Returns whether any screen buffer is currently active (i.e., the stack
is non-empty).

```tcl
host screen active             ;# Returns boolean
```

#### `host screen peek`

Returns the name of the screen buffer at the top of the stack without
modifying the stack.

```tcl
host screen peek               ;# Returns top-of-stack name
```

### 5.4 Lifecycle Integration

Screen buffers are integrated with the console lifecycle:

- **On `host open`** — `MaybeChangeToNewActiveScreenBuffer()` is called
  if `HostCreateFlags` includes `PushConsole`, creating and activating a
  fresh screen buffer
- **On `host close`** — `NativeConsole.Close()` calls `FreeConsole()`,
  then `ResetScreenBuffers()` and `ResetActiveScreenNames()` to clean up
  all state
- **On process exit** — `CleanupScreenBuffers()` iterates all entries in
  `screenBuffers` and calls `CloseHandle()` on each, preventing handle
  leaks

### 5.5 Standard Handle Redirection

When a screen buffer becomes active, `SetActiveScreenBuffer()` does more
than just call `SetConsoleActiveScreenBuffer()`:

1. Calls `ResetHandles()` which uses `SetStdHandle()` P/Invoke to
   redirect `STD_OUTPUT_HANDLE` and `STD_ERROR_HANDLE` to the new buffer
2. Calls `HostOps.ResetAllInterpreterStandardChannels()` which walks all
   interpreters and resets their `stdout` and `stderr` channel objects

This ensures that all output — from Eagle scripts, from .NET
`Console.Write`, and from native code — goes to the active screen buffer.

---

## 6. Sub-Command Reference

### 6.1 Host Lifecycle Sub-Commands

These sub-commands control the host's operational state.

| Sub-command | Purpose | Interface | Key safety checks |
|-------------|---------|-----------|-------------------|
| `host open` | Open host for interaction | `IHost` | `CheckDisposed()` |
| `host close` | Close host and release resources | `IHost` | `CheckDisposed()`, kiosk lock, `CheckActiveReadsAndWrites()` |
| `host isopen` | Query if host is open/ready | `IInteractiveHost` | None beyond host null check |
| `host reset ?options?` | Reset host components to default | `IHost` | Deep nesting prevents partial resets |
| `host flags` | Return host capability flags | `IInteractiveHost` | None |
| `host query` | Query host internal state | `IHost` | Requires `HostFlags.QueryState` capability |

**`host reset` options:**

| Option | Component reset |
|--------|----------------|
| `-all` | Everything below |
| `-interface` | Host interface (`host.Reset()`) |
| `-flags` | Host flags (`host.ResetHostFlags()`) |
| `-history` | Command history (`host.ResetHistory()`) |
| `-input` | Input stream (`host.ResetIn()`) |
| `-output` | Output stream (`host.ResetOut()`) |
| `-error` | Error stream (`host.ResetError()`) |
| `-size` | Window size (`host.ResetSize()`) |
| `-position` | Cursor position (`host.ResetPosition()`) |
| `-colors` | Colors (`host.ResetColors()`) |
| `-channels` | Standard channels (`interpreter.ResetStandardChannels()`) |

Reset operations execute sequentially; a failure in any step aborts the
remaining resets, ensuring no partial state.

```tcl
host reset -all                    ;# Reset everything
host reset -colors -position       ;# Reset specific components
```

### 6.2 Screen Control Sub-Commands

| Sub-command | Purpose | Interface |
|-------------|---------|-----------|
| `host clear` | Clear the display | `IHost` |
| `host position ?options?` | Get/set cursor position | `IPositionHost` |
| `host size ?options?` | Get/set window/buffer size | `ISizeHost` |
| `host title ?title?` | Get/set window title | `IInteractiveHost` |

**`host position` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-x` | integer | Absolute X (column) position |
| `-relx` | integer | Relative X offset from current |
| `-y` | integer | Absolute Y (row) position |
| `-rely` | integer | Relative Y offset from current |

**`host size` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-sizetype` | `HostSizeType` | Size context (Buffer, Window, Current, Maximum) |
| `-width` | integer | Absolute width |
| `-relwidth` | integer | Relative width offset |
| `-height` | integer | Absolute height |
| `-relheight` | integer | Relative height offset |
| `-norestore` | switch | Don't auto-restore on failure |

**Safety feature:** `host size` automatically calls `ResetSize()` to
roll back if `SetSize()` fails, unless `-norestore` is specified.

The `HostSizeType` enum supports:

| Value | Meaning |
|-------|---------|
| `Any` | Let the host decide (default) |
| `BufferCurrent` | Current buffer size |
| `BufferMaximum` | Maximum buffer size |
| `WindowCurrent` | Current window size |
| `WindowMaximum` | Maximum window size |

```tcl
host position -x 10 -y 5          ;# Move cursor to (10, 5)
host position -relx 5             ;# Move 5 columns right
host size -width 120 -height 40   ;# Set window size
host size -sizetype BufferCurrent  ;# Query buffer size
```

### 6.3 Color and Styling Sub-Commands

| Sub-command | Purpose | Interface |
|-------------|---------|-----------|
| `host color ?options?` | Get/set console colors | `IColorHost` |
| `host namedcolor ?options?` | Get/set themed named colors | `IColorHost` |
| `host boxstyle ?style?` | Get/set box drawing character set | `Default` host |
| `host outputstyle ?style?` | Get/set output formatting style | `Default` host |

**`host color` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-fg` / `-foreground` | `ConsoleColor` | Foreground color |
| `-bg` / `-background` | `ConsoleColor` | Background color |

Returns the previous color values when setting.

**`host namedcolor` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-theme` | string | Color theme name |
| `-name` | string | Color name within theme |
| `-fg` / `-foreground` | `ConsoleColor` | Foreground override |
| `-bg` / `-background` | `ConsoleColor` | Background override |

**`OutputStyle` values:**

| Value | Meaning |
|-------|---------|
| `Normal` | Standard output |
| `Debug` | Debug-style output |
| `Error` | Error-style output |
| `Boxed` | Box-enclosed output |
| `Formatted` | Formatted output |
| `ReversedText` | Reversed text colors |
| `ReversedBorder` | Reversed border colors |

```tcl
host color -foreground Green -background Black
host namedcolor -theme dark -name warning -fg Yellow
host boxstyle 1                   ;# Use alternate box characters
host outputstyle {Boxed, Normal}
```

### 6.4 Input Sub-Commands

| Sub-command | Purpose | Interface |
|-------------|---------|-----------|
| `host readchar` | Read single character (integer code) | `IReadHost` |
| `host readkey ?intercept?` | Read key press (optionally without echo) | `IReadHost` |
| `host readline ?nullOk?` | Read a line of text | `IInteractiveHost` |
| `host pause` | Wait for user input | `IInteractiveHost` |
| `host echo ?enabled?` | Get/set input echo mode | `IHost` |

All read operations:
- Call `EnterReadLevel()` before and `ExitReadLevel()` after (in `finally`)
- Call `SystemConsoleInputMustBeOpen()` before the actual read
- Catch `IOException` (sets `ReadException` flag), `ScriptException`
  (console not open), and general exceptions

```tcl
set ch [host readchar]            ;# Read one character (integer)
set key [host readkey true]       ;# Read key without echo
set line [host readline]          ;# Read line of input
host pause                        ;# Press any key to continue
host echo false                   ;# Disable echo (for passwords)
```

### 6.5 Output Sub-Commands

| Sub-command | Purpose | Interface |
|-------------|---------|-----------|
| `host write value ?newLine?` | Write text (optionally with newline) | `IInteractiveHost` |
| `host writebox ?options? string` | Write text in a decorative box | `IDisplayHost` |
| `host beep ?options?` | Produce audible alert | `IHost` |
| `host result code result ?errorLine?` | Display script result | `IDebugHost` |

**`host writebox` options (extensive):**

| Option | Type | Purpose |
|--------|------|---------|
| `-theme` | string | Color theme |
| `-name` | string | Color name |
| `-x`, `-relx`, `-y`, `-rely` | integer | Position control |
| `-fg` / `-foreground` | ConsoleColor | Text foreground |
| `-bg` / `-background` | ConsoleColor | Text background |
| `-boxfg` / `-boxforeground` | ConsoleColor | Box border foreground |
| `-boxbg` / `-boxbackground` | ConsoleColor | Box border background |
| `-nohandle` | switch | Treat data as `StringPairList` object |
| `-multiple` | switch | Parse argument as list of values |
| `-noposition` | switch | Don't auto-retrieve position |
| `-noboxcolors` | switch | Don't auto-retrieve box colors |
| `-nocolors` | switch | Don't auto-retrieve text colors |
| `-pairs` | switch | Convert list to key-value pairs |
| `-newline` | switch | Append newline |
| `-separator` | switch | Convert "null" strings to actual nulls |
| `-norestore` | switch | Don't restore cursor position |

Returns the new cursor position after writing.

**`host beep` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-frequency` | integer | Beep frequency (Hz) |
| `-duration` | integer | Beep duration (ms) |

```tcl
host write "Processing... " false  ;# No newline
host write "Done!"                 ;# With newline (default)
host writebox -fg White -bg Blue "Important Message"
host writebox -multiple -pairs {key1 val1 key2 val2}
host beep -frequency 800 -duration 200
host result 0 "Operation complete"
```

### 6.6 Channel Management Sub-Commands

| Sub-command | Purpose | Interface |
|-------------|---------|-----------|
| `host inchan ?channel?` | Get/set input channel | `IStreamHost` |
| `host outchan ?channel?` | Get/set output channel | `IStreamHost` |
| `host errchan ?channel?` | Get/set error channel | `IStreamHost` |
| `host redirected channel` | Check if channel is redirected | `IStreamHost` |
| `host mode channel ?mode?` | Get/set channel mode flags | `IHost` |

**`host redirected` behavior:**
- Single channel type (Input, Output, Error): returns boolean
- Multiple channel types (via flags): returns paired key-value list

```tcl
host inchan                       ;# Query input channel
host outchan                      ;# Query output channel
host redirected Output            ;# Check if stdout redirected
host redirected {Input, Output}   ;# Check multiple channels
host mode Output                  ;# Get output mode flags
host mode Output 7                ;# Set mode flags
```

### 6.7 Host Control Sub-Commands

| Sub-command | Purpose | Interface | Notes |
|-------------|---------|-----------|-------|
| `host cancel ?force?` | Cancel host operations | `IDebugHost` | |
| `host exit ?force?` | Exit the host | `IDebugHost` | |
| `host sleep milliseconds` | Thread-level sleep | `IThreadHost` | Requires `HostFlags.Sleep` |
| `host font ?options?` | Get/set console font | N/A (native) | Windows only (`CONSOLE && NATIVE && WINDOWS`) |

**`host sleep` safety check:** Before sleeping, verifies
`HostFlags.Sleep` is set in the host's capability flags. This prevents
sleep on hosts that don't support it (e.g., non-interactive hosts).

**`host font` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-facename` | string | Font face (e.g., "Consolas") |
| `-fontsize` | short | Font size in points |
| `-save` | boolean | Save current font before changing |
| `-restore` | boolean | Restore previously saved font |

Option precedence: `-restore` > set > get.

```tcl
host cancel                        ;# Cancel current operation
host exit                          ;# Exit the host
host sleep 1000                    ;# Sleep 1 second
host font                          ;# Query current font
host font -facename Consolas -fontsize 14 -save true
host font -restore true            ;# Restore saved font
```

---

## 7. The `HostFlags` Enum

`HostFlags` is a `[Flags]` `ulong` with 60+ values advertising the
host's capabilities. Scripts can query these via `host flags` to adapt
behavior.

### 7.1 Operational Capabilities

| Flag | Purpose |
|------|---------|
| `Complain` | Enable `DebugOps.Complain()` |
| `Verbose` | Verbose error reporting |
| `Debug` | Enable `DebugOps.Write()` |
| `Test` | Test mode diagnostics |
| `Prompt` | Supports `Prompt()` method |
| `ForcePrompt` | Display prompt even when input redirected |
| `Title` | Supports `DefaultTitle` property |
| `Thread` | Supports thread creation |
| `Exit` | Supports `CanExit`/`CanForceExit` |
| `WorkItem` | Supports work item queuing |
| `Stream` | Supports `GetStream()` method |
| `Data` | Supports `GetData()` method |
| `Profile` | Supports profile loading |
| `Sleep` | Supports `Sleep()` method |
| `Yield` | Supports `Yield()` method |
| `CustomInfo` | Supports custom information display |
| `QueryState` | Supports `QueryState()` method |

### 7.2 Display Characteristics

| Flag | Purpose |
|------|---------|
| `Resizable` | I/O area can be resized |
| `HighLatency` | High-latency connection |
| `LowBandwidth` | Low-bandwidth connection |
| `Monochrome` | Two colors only |
| `Color` | Standard color support |
| `TrueColor` | 24-bit color |
| `ReversedColor` | Supports color reversal |
| `Text` | Text-based (console) |
| `Graphical` | Graphical window |
| `Virtual` | Virtual/simulated I/O |

### 7.3 Size Categories

| Flag | Purpose |
|------|---------|
| `ZeroSize` | No usable area |
| `MinimumSize` | Minimum usable size |
| `CompactSize` | Compact display |
| `FullSize` | Full-size display |
| `SuperFullSize` | Large display |
| `JumboSize` | Jumbo display |
| `SuperJumboSize` | Super jumbo display |
| `UnlimitedSize` | Unlimited display |

### 7.4 Advanced Behavior Flags

| Flag | Purpose |
|------|---------|
| `MultipleLineInput` | Supports multi-line input |
| `AutoFlushHost` | Auto-flush from `WriteCore` |
| `AutoFlushWriter` | Auto-flush writers |
| `AutoFlushOutput` | Auto-flush after `puts` |
| `AutoFlushError` | Auto-flush error output |
| `AdjustColor` | Fine-tune color values |
| `ReadException` | Exception occurred during read |
| `WriteException` | Exception occurred during write |
| `NoColorNewLine` | Don't write newline with color |
| `SavedColorForNone` | Use saved colors for `None` |
| `RestoreColorAfterWrite` | Restore original colors after write |
| `ResetColorForRestore` | Reset colors on restore |
| `TreatAsFatalError` | Errors are unrecoverable |
| `NoSetForegroundColor` | Disable foreground color changes |
| `NoSetBackgroundColor` | Disable background color changes |
| `NormalizeToNewLine` | Convert `\r\n` to `\n` |
| `TreatMissingLineAsEof` | No line = EOF |
| `NativeWindows` | Use `WriteConsoleW` API |

---

## 8. The `HostCreateFlags` Enum

`HostCreateFlags` controls how the host is created at interpreter
initialization time.

### 8.1 Creation Control

| Flag | Purpose |
|------|---------|
| `Disable` | Do not create interpreter host |
| `Clone` | Clone the host rather than use directly |
| `NoDispose` | Don't call `Dispose()` on host |
| `NoConsole` | Skip console host type |
| `NoDiagnostic` | Skip diagnostic host type |
| `NoNull` | Skip null host type |
| `NoFake` | Skip fake host type |
| `UseWrapper` | Wrap the host |
| `OwnWrapper` | Wrapper owns the host |

### 8.2 Console-Specific (Windows)

| Flag | Purpose |
|------|---------|
| `CloseConsole` | Close existing console first |
| `OpenConsole` | Open/attach console window |
| `ForceConsole` | Force open even if already open |
| `AttachConsole` | Allow attaching to parent process console |
| `NoCloseConsole` | Prevent console window close button |
| `FixConsole` | Apply console integration fixes |
| `HookConsole` | Greedily open console handles |
| `PushConsole` | Push screen buffer to stack on open |
| `HistoryConsole` | Configure history buffer |
| `NoNativeConsole` | Avoid `NativeConsole` class |
| `QuietConsole` | Don't complain on `NativeConsole` failures |
| `WriteConsole` | Use Win32 `WriteConsoleW` API |

### 8.3 Behavioral Configuration

| Flag | Purpose |
|------|---------|
| `UseAttach` | Attempt to attach to existing console |
| `UseForce` | Forcibly attach or open |
| `NoColor` | Limit to grayscale |
| `NoTitle` | Don't change console title |
| `NoIcon` | Don't change console icon |
| `NoProfile` | Don't load host profile |
| `NoCancel` | Don't set up script cancellation UI |
| `Echo` | Enable echo for interactive input |
| `CanExit` | Allow exit |
| `CanForceExit` | Allow forced exit |

---

## 9. Practical Patterns

### 9.1 Working with Screen Buffers

```tcl
# Requires: NATIVE, WINDOWS

# Create and use a temporary screen buffer
set buf [host screen create]
host screen push $buf
host clear
host write "=== Temporary Display ===" true
host write "This is on a separate screen buffer."
host pause
host screen pop                       ;# Original screen restored
host screen delete $buf

# Multiple nested buffers
set buf1 [host screen create]
set buf2 [host screen create]
host screen push $buf1
host write "Screen 1"
host screen push $buf2
host write "Screen 2 (nested)"
host screen pop                       ;# Back to buf1
host screen pop                       ;# Back to original
host screen delete $buf2
host screen delete $buf1
```

### 9.2 Color Theming

```tcl
# Save and restore colors
set oldColors [host color]
host color -foreground Green -background Black
host write "Green text on black"
eval host color $oldColors            ;# Restore

# Named color theming
host namedcolor -theme dark -name error -fg Red -bg Black
host namedcolor -theme dark -name success -fg Green -bg Black
```

### 9.3 Checking Host Capabilities

```tcl
# Check if host supports specific features
set flags [host flags]
if {[string match *Sleep* $flags]} {
    host sleep 1000
} else {
    after 1000
}

# Check if host is open before operations
if {[host isopen]} {
    host write "Host is ready"
}
```

### 9.4 Box Drawing

```tcl
# Simple box
host writebox "Important: System ready"

# Colored box with positioning
host writebox -x 5 -y 10 \
    -fg White -bg DarkBlue \
    -boxfg Yellow -boxbg DarkBlue \
    "Status: All systems operational"

# Key-value pairs in a box
host writebox -multiple -pairs {
    Status OK
    Uptime "3 days"
    Memory "128 MB"
}
```

### 9.5 Safe Host Lifecycle

```tcl
# Close and reopen the host
if {[host isopen]} {
    host close
    # ... do work without console ...
    host open
}

# Font customization with save/restore
host font -save true -facename "Lucida Console" -fontsize 16
# ... work with custom font ...
host font -restore true
```

---

## 10. Safe Interpreter Restrictions

The `host` command carries `CommandFlags.Unsafe` and is **completely
unavailable** in safe interpreters. This is appropriate given that the
command provides:

- Direct console lifecycle control (open/close)
- Native Win32 API access (screen buffers, fonts, handles)
- Stream redirection (input/output/error channel reassignment)
- Thread-level sleep
- Cancel and exit operations
- Memory-unsafe handle manipulation

None of these operations are appropriate for sandboxed code.

---

## 11. Tcl Comparison

| Feature | Tcl approach | Eagle `host` approach |
|---------|-------------|----------------------|
| Console output | `puts` | `host write` with color/position control |
| Console input | `gets stdin` | `host readchar` / `host readkey` / `host readline` |
| Console clear | ANSI `\033[2J` (manual) | `host clear` |
| Colors | ANSI escape codes (manual) | `host color` / `host namedcolor` with themes |
| Cursor position | ANSI escape codes (manual) | `host position` with absolute/relative |
| Window size | None | `host size` with auto-rollback |
| Console title | None | `host title` |
| Box drawing | None | `host writebox` with themes and colors |
| Screen buffers | None | `host screen` push/pop stack (Win32 native) |
| Font control | None | `host font` (Windows) |
| Host lifecycle | Implicit | `host open`/`close`/`isopen` with safety interlocks |
| Capability query | None | `host flags` returns 60+ flags |
| Sleep | `after N` (event-loop) | `host sleep` (thread-level, capability-gated) |
| Channel redirect | `chan configure` | `host inchan`/`outchan`/`errchan` + `host redirected` |
| Beep | None | `host beep` with frequency/duration |
| Host state reset | None | `host reset` with per-component granularity |

---

## 12. Security Considerations

- The command is marked `Unsafe | Critical` — never exposed in safe
  interpreters
- `host close` has five layers of safety checks to prevent closing during
  active I/O, in kiosk mode, or when shared across application domains
- Screen buffer operations manipulate Win32 handles directly — invalid
  handle use could destabilize the process
- `host font` modifies the console font for the entire console window,
  affecting all threads
- `host sleep` is capability-gated via `HostFlags.Sleep` to prevent
  misuse on non-interactive hosts
- Stream redirection (`host inchan`/`outchan`/`errchan`) can disconnect
  the interpreter from its expected I/O channels
- `host exit` can terminate the host application
