# Eagle `[debug]` Command — Deep-Dive Analysis

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[debug]` command internals, including the 78 sub-commands, the dual-context suspend/resume debugger architecture, `BreakpointType` enum (40+ flags with composite presets), `DebugEmergencyLevel` lifecycle control, `HeaderFlags` display control, the interactive breakpoint loop, variable watchpoints, script evaluation in debugger context, token-level breakpoints, trace configuration, and the command queue system. For basic command syntax, see [`core_language.md`](core_language.md#cmd-debug). For usage examples, see [`core_examples.md`](core_examples.md#ex-debug). For debugging tips, see [`tips_and_tricks.md`](tips_and_tricks.md).

## 1. Executive Summary

The Eagle `[debug]` command is a large ensemble providing **78 sub-commands**
(many gated behind specific compile-time flags, so the count visible in any
given build will be lower) for programmatic interaction with the debugger,
breakpoints, variable watches,
script evaluation in debug context, memory diagnostics, trace configuration,
script bundling, and emergency recovery. Tcl has no built-in `[debug]` command;
debugging in Tcl relies on external tools or simple `[puts]`-based tracing.
Eagle's `[debug]` is a first-class command ensemble that exposes the full
debugger lifecycle from script level.

The command carries `CommandFlags.Unsafe | Critical | NonStandard | Diagnostic`
and belongs to the `"debug"` object group. It is **not** available in safe
interpreters.

Key differentiators from Tcl:

| Area | Tcl | Eagle |
|------|-----|-------|
| Built-in debugger | None (external tools only) | Full debugger with 78 sub-commands |
| Breakpoint types | N/A | 40+ `BreakpointType` flags (command, token, variable, cancel, error, exit, etc.) |
| Variable watchpoints | `trace add variable` (callback-based) | `[debug watch]` with `BreakOnGet`/`BreakOnSet`/`BreakOnUnset` flags |
| Single-step execution | N/A | `[debug step]` / `[debug steps]` with configurable step counts |
| Debugger suspend/resume | N/A | Dual-context architecture with reference-counted suspend/resume |
| Emergency recovery | N/A | `[debug emergency]` with 20+ `DebugEmergencyLevel` flags |
| Interactive debugger loop | N/A | Nested interactive loops with command queuing and header display |
| Token-level breakpoints | N/A | `[debug token]` with file/line-based `BreakpointDictionary` |
| Debug evaluation | N/A | `[debug eval]` / `[debug run]` / `[debug subst]` in isolated debugger interpreter |
| Trace system | Limited | `[debug trace]` with 20+ options for listeners, priorities, categories |
| Memory diagnostics | N/A | `[debug memory]` / `[debug gcmemory]` / `[debug sysmemory]` / `[debug collect]` |
| Script bundling | N/A | `[debug bundle]` / `[debug mount]` / `[debug unmount]` for signed bundle files |
| Secure evaluation | N/A | `[debug secureeval]` with timeout, trust, event control in child interpreter |

---

## 2. Why the Eagle `[debug]` Command Has No Tcl Equivalent

Tcl's debugging story is entirely external — tools like TclPro Debugger,
`Tcl_SetCommandInfoProc`, or manual `[puts]` tracing. Eagle integrates the
debugger into the interpreter itself:

- **IDebugger interface** — a formal interface with suspend/resume, breakpoint
  management, command queuing, and interactive loop entry
- **Dual-context state** — every debugger property is stored as a two-element
  array (Current/Saved), enabling atomic save/restore without locks
- **BreakpointType flags** — 40+ flag values covering every phase of script
  evaluation, from token parsing to variable access to procedure entry/exit
- **InteractiveLoopData** — rich context structure passed to the interactive
  loop, carrying breakpoint type, token, trace info, engine flags, and
  header display control
- **DebugEmergencyLevel** — a flag enum for emergency debugger lifecycle
  control: create, dispose, reset, enable, disable, and break, with feature
  flags for token breakpoints, isolated interpreters, and verbosity

### Source files

| File | Role |
|------|------|
| `Commands/Debug.cs` (~6,272 lines) | Command implementation: 78 sub-commands |
| `Components/Private/Debugger.cs` (~1,429 lines) | `IDebugger` implementation: dual-context state, suspend/resume, breakpoint management |
| `Components/Private/DebuggerOps.cs` (~582 lines) | Static helpers: breakpoint firing, watchpoint entry, command queue, type matching |
| `Interfaces/Private/Debugger.cs` (~98 lines) | `IDebugger` interface definition |
| `Interfaces/Private/DebuggerData.cs` (~59 lines) | `IDebuggerData` property interface |
| `Components/Public/InteractiveLoopData.cs` (~555 lines) | Breakpoint context data for interactive loops |
| `Containers/Private/BreakpointDictionary.cs` (~219 lines) | Hierarchical breakpoint storage: file → location → count |
| `Components/Public/Enumerations.cs` | `BreakpointType`, `HeaderFlags`, `DebugEmergencyLevel` enums |

### Conditional compilation

Many sub-commands require specific compile-time flags:

| Flag | Sub-commands |
|------|-------------|
| `DEBUGGER` | `[break]`, `emergency`, `[eval]`, `run`, `[subst]`, `[invoke]`, `setup`, `status`, `step`, `steps`, `[test]`, `types`, and most others |
| `DEBUGGER && DEBUGGER_BREAKPOINTS` | `breakpoints`, `ontoken`, `token` (each guarded by `#if DEBUGGER && DEBUGGER_BREAKPOINTS`) |
| `SCRIPT_ARGUMENTS` | Execute argument tracking |
| `SHELL` | `lockloop`, `shell` |
| `DATA` | `bundle`, `mount`, `unmount`, `mounts` |
| `NATIVE` | `output`, `sysmemory` (whole sub-command guarded by `#if NATIVE`); `stack` is always compiled, but its `-force` native stack check and `memory`'s native-memory section are `#if NATIVE` only |
| `HISTORY` | `history` |
| `PREVIOUS_RESULT` | `exception`, `result` |
| `TEST` | Some `trace` sub-options |

---

## 3. Debugger Architecture

### 3.1 The Dual-Context Model

The central design pattern of Eagle's debugger is the **dual-context
suspend/resume model**. Every debugger property is stored as a two-element
array indexed by a private `Context` enum:

```tcl
Context.Current = 0   — active state
Context.Saved   = 1   — preserved state during suspension
```

Properties stored with dual context:

| Property | Type | Purpose |
|----------|------|---------|
| `enabled` | `bool[]` | Debugger on/off |
| `loops` | `int[]` | Interactive loop depth |
| `active` | `int[]` | Scripts executing in debugger |
| `singleStep` | `bool[]` | Single-step mode |
| `breakOnToken` | `bool[]` | Break on token breakpoints |
| `breakOnExecute` | `bool[]` | Break on command execution |
| `breakOnCancel` | `bool[]` | Break on script cancel |
| `breakOnError` | `bool[]` | Break on errors |
| `breakOnReturn` | `bool[]` | Break on returns |
| `breakOnTest` | `bool[]` | Break on test conditions |
| `breakOnExit` | `bool[]` | Break on exit |
| `steps` | `long[]` | Step count before break |
| `types` | `BreakpointType[]` | Enabled breakpoint types |
| `breakpoints` | `BreakpointDictionary[]` | File→location breakpoints |
| `command` | `string[]` | One-time command |
| `result` | `Result[]` | Last execution result |
| `queue` | `QueueList<string,string>[]` | Command queue |
| `callbackArguments` | `StringList[]` | Interrupt callback args |

### 3.2 Suspend and Resume

Suspend/resume uses reference counting to support nested calls safely:

```tcl
Suspend():
  suspendCount++
  if suspendCount == 1:     ← first suspend only
    Copy(Current → Saved)   ← save active state
    Reset(Current)          ← clear for isolated operation

Resume():
  suspendCount--
  if suspendCount == 0:     ← final resume only
    Copy(Saved → Current)   ← restore active state
    Reset(Saved)            ← clear saved slot
```

This pattern means:
- Multiple nested `[debug suspend]` / `[debug resume]` pairs are safe
- Only the outermost pair actually transfers state
- `[debug run]` uses this internally to execute scripts without debugger
  instrumentation

### 3.3 Re-Entry Prevention

The debugger uses multiple counters and flags to prevent re-entry:

| Mechanism | Purpose |
|-----------|---------|
| `Active` counter | Tracks scripts executing inside the debugger (>0 = inside debugger) |
| `Loops` counter | Tracks interactive loop nesting depth |
| `SuspendCount` | Prevents state corruption on nested suspend/resume |
| `IsDebuggerExiting` flag | Set by `DebuggerOps.Breakpoint()` to prevent re-entry after loop exit |

### 3.4 Breakpoint Firing Flow

When the engine encounters a breakpoint trigger:

1. Engine detects condition (token, execution, cancel, error, variable access, etc.)
2. Engine creates `InteractiveLoopData` with breakpoint context
3. Engine calls `DebuggerOps.Breakpoint(debugger, interpreter, loopData, ...)`
4. `Breakpoint()` validates interactive support
5. Increments `debugger.EnterLoop()`
6. Calls registered `InteractiveLoopCallback` or `Interpreter.InteractiveLoop()`
7. Sets `IsDebuggerExiting` flag to prevent re-entry
8. Verifies interpreter readiness via `ViaDebugger`
9. Decrements `debugger.ExitLoop()`
10. Returns `ReturnCode` from the interactive loop

---

## 4. Sub-Command Reference — Common Patterns

Many of the 78 sub-commands follow one of a few recurring implementation
patterns. This section documents each pattern once, then lists the
sub-commands that follow it. Sub-commands with unique or complex behavior
receive their own detailed sections (§5).

### 4.1 Flag-Toggle Sub-Commands

These sub-commands toggle a boolean debugger property. Without an argument
they **toggle** (not query) the current state. With a boolean argument they
set the state explicitly. On success they write a status line to the
interactive host.

**Common implementation pattern:**

```tcl
debug <name>              ;# Toggle: true→false, false→true
debug <name> true         ;# Set to true
debug <name> false        ;# Set to false
```

All flag-toggle sub-commands require `DEBUGGER`.

| Sub-command | Property | Purpose |
|-------------|----------|---------|
| `[debug enable]` | `debugger.Enabled` | Master debugger on/off switch |
| `[debug oncancel]` | `debugger.BreakOnCancel` | Break when script is cancelled |
| `[debug onerror]` | `debugger.BreakOnError` | Break when an error occurs |
| `[debug onexecute]` | `debugger.BreakOnExecute` | Break on every command execution |
| `[debug onexit]` | `debugger.BreakOnExit` | Break on exit command |
| `[debug onreturn]` | `debugger.BreakOnReturn` | Break on value return |
| `[debug ontest]` | `debugger.BreakOnTest` | Break on test command |
| `[debug ontoken]` | `debugger.BreakOnToken` | Break on token parsing (requires `DEBUGGER_BREAKPOINTS`) |
| `[debug step]` | `debugger.SingleStep` | Single-step mode (requires interactive mode) |

```tcl
# Enable debugger and set up break-on-error
debug enable true
debug onerror true

# Toggle single-step mode
debug step
```

### 4.2 Getter/Setter Sub-Commands

These sub-commands return the current value with no arguments, or set a
new value with one argument.

| Sub-command | Property | Purpose |
|-------------|----------|---------|
| `debug callback ?{}|arg ...?` | `debugger.CallbackArguments` | Get/set debugger interrupt callback arguments; also calls `CheckCallbacks()` to register/unregister |
| `debug gcmemory ?collect?` | `GC.GetTotalMemory()` | Get GC heap size; optional boolean forces full collection first |
| `debug history ?enabled?` | `interpreter.History` | Get/set command history (requires `HISTORY`) |
| `debug icommand ?command?` | `debugger.Command` | Get/set one-time interactive loop command |
| `debug interactive ?enabled?` | `interpreter.InternalInteractive` | Get/set interactive mode flag (does **not** toggle — returns current value if no arg) |
| `debug iresult ?result?` | `debugger.Result` | Get/set interactive loop result |
| `debug pluginflags ?flags?` | `interpreter.PluginFlags` | Get/set plugin flags |
| `debug testpath ?path?` | `interpreter.TestPath` | Get/set test path |
| `debug types ?types?` | `debugger.Types` | Get/set `BreakpointType` flags for active breakpoint types |
| `debug vout ?channelId? ?enabled?` | Channel virtual output | Get/set virtual output for a channel (returns `StringBuilder` contents) |

```tcl
# Query current breakpoint types
debug types

# Set types to Standard preset (Common + Token)
debug types Standard

# Check GC memory with collection
debug gcmemory true
```

### 4.3 List-Query Sub-Commands

These sub-commands return structured data about debugger or interpreter
state. Most take an optional pattern for filtering.

| Sub-command | Returns | Details |
|-------------|---------|---------|
| `debug breakpoints ?pattern?` | Active breakpoint list | Calls `debugger.GetBreakpointList()` (requires `DEBUGGER_BREAKPOINTS`) |
| `[debug complaint]` | Last error complaint message | Calls `DebugOps.SafeGetComplaint()` |
| `[debug levels]` | Maximum recursion level limits | Returns a name/value list: `maximumLevels`, `maximumScriptLevels`, `maximumScriptFileLevels`, `maximumParserLevels`, `maximumExpressionLevels` |
| `[debug memory]` | GC and native memory statistics | `gcTotalMemory`, `gcMaxGeneration`, per-generation `gcCollectionCount(N)`, `isServerGC`, `gcLatencyMode`; appends a native-memory section under `NATIVE` |
| `debug mounts ?pattern?` | Mounted bundle list | Calls `bundleManager.ListMounts()` (requires `DATA`) |
| `debug paths ?flags?` | Global path list | Supports `GetAll`, `UseFilter`, `ExistingOnly`, `UniqueOnly` flags |
| `debug stack ?force?` | Thread stack information | Returns: `threadId`, `used`, `allocated`, `extra`, `margin`, `maximum`, `reserve`, `commit` via `RuntimeOps.GetStackSize()`. The optional `force` boolean first refreshes native stack pointers and runs a stack-space check (`#if NATIVE`); the sub-command itself is always compiled |
| `[debug status]` | Debugging status across all layers | Managed debugger attached, native debugger (Windows), script debugger available/enabled, header flags, debugger interpreter available (requires `DEBUGGER`) |
| `debug steps ?integer?` | Step count | Get or set `debugger.Steps` (long integer); requires interactive mode for setting |
| `[debug sysmemory]` | System memory status | Calls `NativeOps.GetMemoryStatus()` (requires `NATIVE`) |

```tcl
# List all breakpoints matching a pattern
debug breakpoints "*test*"

# Check debugging status
debug status

# Query memory
debug memory
```

### 4.4 Simple Utility Sub-Commands

These perform a single operation and return a result.

| Sub-command | Syntax | Purpose |
|-------------|--------|---------|
| `debug cleanup ?flags?` | Cleanup call frames, clear caches, force GC | Calls `CallFrameOps.Cleanup()` |
| `debug collect ?flags?` | Trigger garbage collection | Parses `GarbageFlags`, calls `ObjectOps.CollectGarbage()` |
| `debug halt ?result?` | Halt script evaluation | Calls `Engine.HaltEvaluate()` with optional result |
| `[debug keyring]` | Fetch and merge key ring | Calls `ScriptOps.FetchAndMergeKeyRing()` |
| `[debug null]` | Return null to script engine | Sets `ResultFlags.ForceNullMask`; ignores all arguments |
| `[debug purge]` | Purge call frames | Calls `CallFrameOps.Purge()` |
| `debug ready ?isolated?` | Check if debugger is ready | Calls `Engine.CheckDebugger()` |
| `debug refreshautopath ?verbose?` | Refresh auto-path list | Calls `GlobalState.RefreshAutoPathList()` |
| `debug restore ?strict? ?verbose?` | Restore core plugin | Calls `interpreter.RestoreCorePlugin()` |
| `[debug resume]` | Resume debugger after suspension | Calls `debugger.Resume()` |
| `debug runtimeoverride name` | Override runtime name | Parses `RuntimeName` enum, calls `CommonOps.Runtime.SetManualOverride()` |
| `debug self ?debug? ?force?` | Break into managed debugger | Calls `DebugOps.Break()`; defaults to checking `DebugOps.IsAttached()` |
| `[debug suspend]` | Suspend debugger | Calls `debugger.Suspend()` |
| `debug unmount fileName` | Unmount bundle file | Calls `bundleManager.Unmount()` (requires `DATA`) |

```tcl
# Suspend/resume pattern for uninterrupted execution
debug suspend
# ... scripts execute without debugger ...
debug resume

# Force garbage collection
debug collect Default

# Check debugger readiness
debug ready
```

### 4.5 Breakpoint Target Sub-Commands

These sub-commands set or query breakpoints on specific named entities
(commands, functions, operators). They share a common pattern: with one
argument they query the breakpoint state, with two arguments they set it.

| Sub-command | Target | Method |
|-------------|--------|--------|
| `debug execute name ?enabled?` | `IExecute` object | `Engine.SetExecuteBreakpoint()` / `HasExecuteBreakpoint()` |
| `debug function name ?enabled?` | Function | `SetExecuteArgumentBreakpoint()` |
| `debug operator name ?enabled?` | Operator | `SetExecuteArgumentBreakpoint()` |

```tcl
# Set breakpoint on a command
debug execute myProc true

# Query breakpoint state
debug execute myProc       ;# Returns true or false

# Set breakpoint on an operator
debug operator + true
```

---

## 5. Sub-Command Reference — Unique and Complex Sub-Commands

These sub-commands have unique control flow, multi-option parsing, or
complex state manipulation that warrants individual detailed treatment.

### 5.1 `[debug break]` — Enter the Debugger

```tcl
debug break ?options?
```

**Purpose:** Programmatically break into the debugger by entering a nested
interactive loop. This is the script-level equivalent of a breakpoint hit.

**Options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `-interpreter` | string | current | Target interpreter (for child interpreters) |
| `-ignoreenabled` | switch | off | Break even if debugger is disabled |
| `-complain` | switch | on | Report errors to complaint system |
| `-nocomplain` | switch | off | Suppress complaint reporting |
| `-noerror` | switch | off | Never return an error code |

**Implementation (lines 114–308):**

1. Validates debugger availability and the `BreakpointType.Demand` type
2. Optionally resolves a child interpreter via `-interpreter`
3. Checks `debugger.Enabled` (unless `-ignoreenabled`)
4. Calls `interpreter.DebuggerBreak()` which:
   - Creates an `InteractiveLoopData` with `BreakpointType.Demand`
   - Enters a nested interactive loop
5. The interactive loop presents a prompt and accepts debugger commands
6. On return, optionally complains or suppresses errors based on options

**Connection to `[debug emergency]`:** The emergency sub-command can trigger
a break internally by setting the `Break` flag in `DebugEmergencyLevel`,
which generates a `[debug break]` command and re-invokes the ensemble via
an internal `goto redo` mechanism.

```tcl
# Simple break into debugger
debug break

# Break into child interpreter's debugger, ignoring enabled state
debug break -interpreter child1 -ignoreenabled

# Break without error reporting
debug break -nocomplain -noerror
```

### 5.2 `[debug emergency]` — Emergency Recovery System

```tcl
debug emergency ?options? ?level?
```

**Purpose:** Emergency debugger lifecycle control. This sub-command can
create, dispose, reset, enable, disable, and break into the debugger in
a single operation, even when the interpreter is in a degraded state. It
is designed for recovery scenarios where normal debugger operations may
fail.

**Options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `-interpreter` | string | current | Target interpreter |
| `-ignoreenabled` | switch | off | Ignore debugger enabled state |
| `-nocomplain` | switch | off | Suppress complaint reporting |
| `-noerror` | switch | off | Never return an error code |

**The `DebugEmergencyLevel` Flags:**

The `level` argument is a `DebugEmergencyLevel` flag combination that
controls which operations to perform. Operations execute in a defined
order regardless of flag position:

**Lifecycle flags (executed in order):**

| Flag | Purpose |
|------|---------|
| `Disposed` | Dispose existing debugger |
| `Disabled` | Disable the debugger |
| `Enabled` | Enable the debugger |
| `Created` | Create a new debugger if needed |
| `Reset` | Reset debugger state to defaults |
| `Break` | Break into debugger after other operations |

**State reset flags:**

| Flag | Purpose |
|------|---------|
| `ResetCancel` | Clear script cancellation state |
| `ForceResetCancel` | Forcibly clear cancellation (ignores guards) |
| `ResetHalt` | Clear halt flag |
| `ForceResetHalt` | Forcibly clear halt flag |

**Feature flags:**

| Flag | Purpose |
|------|---------|
| `Tokens` | Enable token breakpoints |
| `ScriptArguments` | Enable nested script argument tracking |
| `Isolated` | Create isolated debugger interpreter |
| `IgnoreModifiable` | Ignore interpreter immutability flag |
| `Verbose` | Enable diagnostic output |
| `Quiet` | Silence trace output |
| `IgnoreEnabled` | Ignore debugger enabled status |
| `PopulateResultStack` | Force result stack population |
| `IncludeResultStack` | Include result stack traces in output |
| `NoComplain` | Suppress complaints (passed to `[break]`) |
| `NoError` | Suppress errors (passed to `[break]`) |

**Predefined presets:**

| Preset | Flags | Use case |
|--------|-------|----------|
| `Enabled` | `EnabledFlagsMask \| ForEnabledUse` | Enable the debugger with defaults |
| `Disabled` | `DisabledFlagsMask \| ForDisabledUse` | Disable the debugger with defaults |
| `Override` | `FlagsMask \| ForOverrideUse` | Full on-demand debugging setup |
| `Now` | `Default \| ForNowUse` | Immediate debugging |
| `Later` | `Default \| ForLaterUse` | Deferred debugging setup |
| `Status` | `StatusMask \| ForStatusUse` | Query status only |
| `Full` | `FlagsMask \| ForFullUse` | Full setup with all features |
| `Default` | `ForDefaultUse` | Default behavior |

**Implementation (lines 634–1376):**

The implementation is the most complex in the entire `[debug]` command — over
740 lines of carefully ordered operations:

1. **Lock acquisition** — acquires a hard lock on the interpreter
   (`InternalHardTryLock` / `InternalExitLock`)
2. **Flag parsing** — parses the `DebugEmergencyLevel` enum from the
   level argument
3. **Debugger disposal** — if `Disposed` flag: disposes existing debugger
4. **Debugger creation** — if `Created` flag: calls `Engine.SetupDebugger()`
   with appropriate `CreateFlags`, `InitializeFlags`, `ScriptFlags`
5. **State reset** — if `Reset` flag: resets debugger state, optionally
   resets cancel/halt flags with `ForceResetCancel`/`ForceResetHalt`
6. **Enable/disable** — if `Enabled`/`Disabled` flag: sets
   `debugger.Enabled`
7. **Breakpoint type configuration** — if `Tokens` flag: adds
   `BreakpointType.Token` to active types
8. **Script arguments** — if `ScriptArguments` flag: configures argument
   tracking
9. **Result stack** — if `PopulateResultStack`/`IncludeResultStack`:
   manages result stack traces
10. **Break** — if `Break` flag: generates a `[debug break]` command
    (with `-ignoreenabled`, `-nocomplain`, `-noerror` based on
    corresponding flags) and re-invokes the ensemble via `goto redo`

The `goto redo` mechanism at line 1297 is notable: rather than calling
`[debug break]` as a nested command, the emergency sub-command rewrites
the command arguments and jumps back to the start of the ensemble
dispatch, causing `[debug break]` to execute in the same call frame.

```tcl
# Emergency: create debugger, enable, reset cancellation, and break
debug emergency {Created, Enabled, Reset, ResetCancel, Break}

# Enable with full features
debug emergency Full

# Quick emergency break (ignore everything, just break)
debug emergency {Break, IgnoreEnabled, NoComplain, NoError}

# Dispose and recreate the debugger
debug emergency {Disposed, Created, Enabled, Reset}

# Query status only
debug emergency Status
```

### 5.3 `[debug secureeval]` — Secure Evaluation in Child Interpreter

```tcl
debug secureeval ?options? path arg ?arg ...?
```

**Purpose:** Evaluate a script in a child interpreter with fine-grained
security, timeout, and event controls. This is used for sandboxed
execution where the parent needs control over the child's capabilities.

**Options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `-timeout` | integer | none | Script execution timeout (milliseconds) |
| `-nocancel` | boolean | false | Disable cancel reset after execution |
| `-globalcancel` | boolean | false | Use global cancel flag |
| `-stoponerror` | boolean | false | Stop on first error |
| `-file` | boolean | false | Treat argument as file path (not script text) |
| `-trusted` | boolean | false | Mark interpreter as trusted (adds `IgnoreHidden` engine flag) |
| `-events` | boolean | true | Enable event processing |
| `-noisolatedplugins` | boolean | false | Disable isolated plugins (requires `ISOLATED_PLUGINS`) |

**Implementation (lines 3933–4283):**

This is the second-most complex sub-command, with 7+ levels of nested
`[try]`/`finally` blocks ensuring correct state restoration:

1. **Resolve child interpreter** — looks up interpreter at `path`
2. **Save event state** — saves and optionally disables child's event
   processing (`EventWaitFlags`)
3. **Configure engine flags** — for trusted mode, adds `IgnoreHidden`
   to per-thread engine flags
4. **Configure timeout** — if specified, queues a timeout via
   `RuntimeOps.QueueScriptTimeout()`
5. **Handle isolated plugins** — if `-noisolatedplugins`, modifies
   child interpreter flags
6. **Evaluate** — calls `EvaluateScript()` or `EvaluateFile()` based
   on `-file` flag
7. **Restore** — in nested finally blocks: restore isolated plugin
   state, restore engine flags, restore event processing, handle
   cancel/halt reset
8. **Error propagation** — copies error information from child
   interpreter to parent, preserving line numbers and context

```tcl
# Evaluate script in child interpreter with 5-second timeout
debug secureeval -timeout 5000 child1 {
    # This script runs in child1 with timeout protection
    set result [expensive_operation]
}

# Trusted evaluation (can see hidden commands)
debug secureeval -trusted true child1 {
    info commands -hiddenonly
}

# File evaluation with event processing disabled
debug secureeval -events false -file true child1 /path/to/script.eagle
```

### 5.4 `[debug invoke]` — Execute at Specific Call Frame Level

```tcl
debug invoke ?level? cmd ?arg ...?
```

**Purpose:** Invoke a command at a specific call frame level, enabling
debugger tools to execute in the context of a suspended frame.

**Implementation (lines 1938–2093):**

1. **Get current level** — calls `CallFrameOps.InfoLevelSubCommand`
   to determine the current stack depth
2. **Parse level** — resolves the level specification (absolute or
   relative)
3. **Mark frames** — marks matching call frames' variables for
   accessibility
4. **Create uplevel frame** — creates an uplevel call frame with
   `CallFrameFlags.Variables` to provide variable context
5. **Execute** — calls `Invoke()` with the command and arguments
6. **Cleanup** — in a `finally` block, unmarks frames and pops the
   uplevel frame, with error checking

```tcl
# Execute 'info vars' at call level 1 (global)
debug invoke 1 info vars

# Execute at current level (default)
debug invoke info locals
```

### 5.5 `[debug eval]` / `[debug run]` / `[debug subst]` — Debugger Interpreter Evaluation

These three sub-commands evaluate scripts or perform substitution using
the **debugger's own interpreter**, which is a separate interpreter
instance created alongside the debugger.

#### `debug eval arg ?arg ...?`

Evaluates concatenated arguments as a script in the debugger interpreter.
Creates a tracking call frame, delegates to the debugger interpreter, and
propagates errors with line number information.

#### `debug run arg ?arg ...?`

Evaluates a script in the **current** interpreter but with the debugger
**suspended**. This is the "run at full speed" command — the script
executes without any debugger breakpoint checking.

**Implementation pattern:**

```tcl
1. debugger.Suspend()
2. try:
     evaluate script normally
3. finally:
     debugger.Resume()   ← always resumes, even on error
```

#### `debug subst ?-nobackslashes? ?-nocommands? ?-novariables? string`

Performs Tcl-style substitution using the debugger interpreter. Supports
the standard substitution control flags.

```tcl
# Evaluate in debugger interpreter
debug eval {info commands *debug*}

# Run script without debugger interference
debug run {
    # This long operation won't trigger any breakpoints
    for {set i 0} {$i < 1000000} {incr i} {
        process_item $i
    }
}

# Substitute in debugger context
debug subst {The value is $myVar}
```

### 5.6 `[debug setup]` — Debugger Initialization

```tcl
debug setup ?create? ?isolated? ?createFlags? ?initializeFlags? ?scriptFlags? ?interpreterFlags?
```

**Purpose:** Initialize or tear down the debugger with full control over
creation flags. When `create` is true (or omitted), sets up the debugger;
when false, tears it down.

**Implementation (lines 4409–4536):**

1. **Determine mode** — parses `create` boolean (default: true)
2. **Default flags** — reads current interpreter's `CreateFlags`,
   `PluginFlags`; removes `ThrowOnError` and `DebuggerInterpreter`
   to avoid conflicts
3. **Isolated mode** — if `isolated` is true, adds
   `DebuggerInterpreter` flag (creates a separate interpreter for
   debugger evaluation)
4. **Parse all flag enums** — `CreateFlags`, `InitializeFlags`,
   `ScriptFlags`, `InterpreterFlags`
5. **Setup** — calls `Engine.SetupDebugger()` with all parsed flags
6. **Teardown** — if `create` is false, calls `Engine.SetupDebugger()`
   with teardown semantics

```tcl
# Set up debugger with defaults
debug setup

# Set up isolated debugger (separate interpreter)
debug setup true true

# Tear down the debugger
debug setup false
```

### 5.7 `[debug shell]` — Launch Interactive Shell

```tcl
debug shell ?options? ?arg ...?
```

**Purpose:** Launch a nested interactive shell, either synchronously
(blocking) or asynchronously (in a separate thread).

**Options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `-interpreter` | string | current | Target interpreter |
| `-initialize` | boolean | false | Initialize shell |
| `-loop` | boolean | false | Enable loop mode |
| `-asynchronous` | boolean | false | Run in background thread |

**Implementation (lines 4537–4642):**

- **Synchronous mode**: calls `Interpreter.ShellMainCore()` directly,
  blocking until the shell exits
- **Asynchronous mode**: creates a background thread via
  `ShellOps.CreateInteractiveLoopThread()` (for loop mode) or
  `ShellOps.CreateShellMainThread()` (for full shell)
- Remaining arguments after options are passed as shell arguments

Requires `SHELL` compile flag.

```tcl
# Launch blocking interactive shell
debug shell

# Launch async shell in background
debug shell -asynchronous true

# Launch shell on child interpreter
debug shell -interpreter child1 -loop true
```

### 5.8 `[debug hook]` — Test Hook Management

```tcl
debug hook ?options? ?pattern? ?script?
```

**Purpose:** Set, query, or list test hooks for debugging test execution.

**Modes:**

| Arguments | Behavior |
|-----------|----------|
| No args | List all test hooks |
| Pattern only | Query hooks matching pattern |
| Pattern + script | Set (or unset) hook for pattern |

**Options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `-type` | `TestHookType` | default | Hook type (Before, After, etc.) |
| `-unset` | boolean | false | Unset instead of set |

```tcl
# List all test hooks
debug hook

# Query hooks for tests matching pattern
debug hook "test-*"

# Set a before-hook for specific tests
debug hook -type Before "test-1.*" {
    puts "About to run: $testName"
}

# Remove a hook
debug hook -unset true "test-1.*"
```

### 5.9 `[debug token]` — Token-Level Breakpoints

```tcl
debug token fileName startLine endLine ?enabled?
```

**Purpose:** Set, clear, or query breakpoints at specific source
locations (file + line range). This enables traditional line-level
debugging.

**Implementation (lines 5127–5216):**

- Creates a `ScriptLocation` object from `fileName`, `startLine`,
  `endLine`
- With 5 arguments (enabled specified):
  - `true` → `debugger.SetBreakpoint()` adds to `BreakpointDictionary`
  - `false` → `debugger.ClearBreakpoint()` removes
- With 4 arguments (query): `debugger.MatchBreakpoint()` checks for
  existing breakpoint at location

The `BreakpointDictionary` uses a two-level lookup:
`PathDictionary<ScriptLocationIntDictionary>` — first by normalized file
path, then by `IScriptLocation` (start/end line range).

Requires `DEBUGGER` and `DEBUGGER_BREAKPOINTS`.

```tcl
# Set breakpoint at line 42 of test.eagle
debug token test.eagle 42 42 true

# Query if breakpoint exists
debug token test.eagle 42 42    ;# Returns match status

# Clear breakpoint
debug token test.eagle 42 42 false
```

### 5.10 `[debug watch]` — Variable Watchpoints

```tcl
debug watch ?varName? ?types?
```

**Purpose:** Set, query, or list variable watchpoints. Watchpoints cause
the debugger to break when a variable is read, written, or unset.

**Modes:**

| Arguments | Behavior |
|-----------|----------|
| No extra args | List all active watchpoints |
| `varName` only | Query watchpoint flags on variable |
| `varName types` | Set watchpoint flags on variable |

**Watchpoint flags** (from `VariableFlags`):

| Flag | Purpose |
|------|---------|
| `BreakOnGet` | Break when variable is read |
| `BreakOnSet` | Break when variable is written |
| `BreakOnUnset` | Break when variable is unset |
| `Mutable` | Variable is mutable (can be modified by watchpoint handler) |

**Implementation (lines 6031–6173):**

- Follows variable links via `EntityOps.FollowLinks()`
- Sets flags via `EntityOps.SetWatchpointFlags()`
- Returns the active watchpoint flags as a string

Watchpoints integrate with the engine's variable access hooks: when a
watched variable is accessed, the engine checks `BreakpointType.BeforeVariableGet`,
`BeforeVariableSet`, or `BeforeVariableUnset` and fires a breakpoint
if the type is enabled.

```tcl
# Set read+write watchpoint on a variable
debug watch myVar {BreakOnGet, BreakOnSet}

# Query watchpoint status
debug watch myVar

# List all active watchpoints
debug watch

# Set full watchpoint (break on any access)
debug watch counter {BreakOnGet, BreakOnSet, BreakOnUnset}
```

### 5.11 `[debug trace]` — Trace System Configuration

```tcl
debug trace ?options? ?message?
```

**Purpose:** Configure the trace/diagnostic system and optionally write
a trace message. This is the most option-rich sub-command, with 24
configuration options (defined by `CommandOptions.GetDebugTraceOptions()`
in `CommandOptions.cs`) controlling trace listeners, priorities, categories,
and state.

**The complete option set** (verified against `GetDebugTraceOptions()` and the
`options.IsPresent(...)` handling in the `"trace"` case of `Debug.cs`):

| Option | Value type | Purpose |
|--------|-----------|---------|
| `-noresult` | boolean | Suppress the normal result (return empty string instead of the state type) |
| `-default` | boolean | Add (`true`) or, with `-resetlisteners`, remove the `Default` listener (`Trace.Listeners`) |
| `-console` | boolean | Add/remove the `Console` listener |
| `-native` | boolean | Add/remove the `Native` (`OutputDebugString`) listener |
| `-statusform` | boolean | Add/remove the `StatusForm` listener (requires `TEST && WINFORMS`) |
| `-debug` | boolean | Route to the `Debug.Listeners` collection (via `DebugOps.GetDebugListeners()`) instead of `Trace.Listeners` (`!NET_STANDARD_20`) |
| `-raw` | boolean | Write the message raw (`DebugOps.TraceWrite()` / `DebugOps.DebugWrite()`), bypassing `TraceOps` formatting |
| `-log` | boolean | Set up/tear down a trace log file listener (requires `TEST && SHELL`) |
| `-resetsystem` | boolean | Reset the entire trace system via `TraceOps.ResetStatus()` |
| `-resetlisteners` | boolean | Clear existing listeners (`DebugOps.ClearTraceListeners()`) before adding |
| `-forceenabled` | boolean | Force-enable/disable tracing via `TraceOps.ForceEnabledOrDisabled()` |
| `-overrideenvironment` | boolean | OR `TraceStateType.OverrideEnvironment` into the state, ignoring environment-based settings |
| `-enabledcategories` | list | `TraceOps.SetTraceCategories(TraceCategoryType.Enabled, ...)` |
| `-disabledcategories` | list | `TraceOps.SetTraceCategories(TraceCategoryType.Disabled, ...)` |
| `-penaltycategories` | list | Penalty categories (reduced priority) |
| `-bonuscategories` | list | Bonus categories (increased priority) |
| `-statetypes` | `TraceStateType` | Base state type (default `TraceCommand`) |
| `-priority` | `TracePriority` | Priority used for the message being written |
| `-priorities` | `TracePriority` | Global enabled-priority set, via `TraceOps.SetTracePriorities()` |
| `-category` | string | Category for this message (default `DebugOps.DefaultCategory`) |
| `-logname` | string | Trace log file listener name (requires `TEST`; otherwise `Unsupported`) |
| `-logfilename` | string | Trace log file path (requires `TEST`; otherwise `Unsupported`) |
| `-logflags` | `LogFlags` | Trace log file flags (requires `TEST`; otherwise `Unsupported`) |

> [!NOTE]
> The listeners added by `-default`, `-console`, and `-native` are
> `System.Diagnostics` trace listeners. `DebugOps.GetTraceListeners()` returns
> `Trace.Listeners`; `-debug` switches the target to `Debug.Listeners` via
> `DebugOps.GetDebugListeners()`. These are distinct from the `ITrace`
> objects in `Library/Traces/` (`Core`, `Default`), which implement
> per-entity command/variable trace callbacks, not diagnostic output sinks.

**Implementation (lines 5150–5617):**

Over 450 lines covering 40+ configuration paths, all backed by `TraceOps`:
- **Reset** — `-resetsystem` calls `TraceOps.ResetStatus()`, which resets the
  trace possible/enabled flags, priority and priorities, all four category
  sets (`Enabled`, `Disabled`, `Penalty`, `Bonus`), the format string/flags,
  and the filter callback.
- **Force enable** — `-forceenabled` calls `TraceOps.ForceEnabledOrDisabled()`
  and returns the resulting `TraceStateType`; when present it also re-parses
  `-priorities` because the baseline changed.
- **Listeners** — `-resetlisteners` then `-default`/`-console`/`-native`/
  `-statusform` add/remove listeners on the selected collection via
  `DebugOps.ClearTraceListeners()` / `DebugOps.AddTraceListener()`.
- **With message** (final argument present): writes via
  `TraceOps.DebugTraceAlways()` (normal), `DebugOps.TraceWrite()` (`-raw`),
  `TraceOps.DebugWriteToAlways()` (`-debug`), or `DebugOps.DebugWrite()`
  (`-debug -raw`).
- **Without message**: calls `TraceOps.QueryStatus()` and returns a
  name/value list including `hasDefaultListener`, `hasConsoleListener`
  (`CONSOLE`), and, under `TEST`, `hasTestListener` / `hasBufferedListener` /
  `hasNativeListener`.

```tcl
# Reset trace system and add console listener
debug trace -resetsystem true -console true

# Write a trace message
debug trace -category "MyDebug" -priority High "Something happened"

# Configure enabled categories
debug trace -enabledcategories "Engine,Variable,Command"

# Force tracing on, overriding environment
debug trace -forceenabled true -overrideenvironment true

# Query current trace status (no message)
debug trace
```

### 5.12 `[debug lockloop]` — Interactive Loop Semaphore

```tcl
debug lockloop enabled
```

**Purpose:** Acquire or release the interactive loop semaphore, which
controls exclusive access to the interactive debugger session.

**Implementation (lines 2264–2422):**

- Uses retry logic with timeout to acquire the semaphore
- Cancels pending operations before attempting lock
- Manages per-thread semaphore state
- Returns boolean success/failure

Requires `SHELL` compile flag.

```tcl
# Acquire interactive loop lock
debug lockloop true

# Release lock
debug lockloop false
```

### 5.13 `[debug lockvar]` — Variable Lock Control

```tcl
debug lockvar enabled name
```

**Purpose:** Lock, unlock, or query the lock state of a variable.
Locked variables cannot be modified.

- `enabled` = `true` → calls `variable.Lock()`
- `enabled` = `false` → calls `variable.Unlock()`
- `enabled` = (empty) → returns current lock state

```tcl
# Lock a variable against modification
debug lockvar true importantData

# Query lock state
debug lockvar {} importantData

# Unlock
debug lockvar false importantData
```

### 5.14 `[debug test]` — Test Breakpoint Management

```tcl
debug test ?name? ?enabled?
```

**Purpose:** Manage breakpoints on named tests (used with the test
framework).

| Arguments | Behavior |
|-----------|----------|
| No args | List all test breakpoints via `TestBreakpointsToString()` |
| Name only | Query breakpoint state for named test |
| Name + enabled | Set breakpoint via `SetTestBreakpoint()` |

```tcl
# List all test breakpoints
debug test

# Set breakpoint on specific test
debug test "myTest-1.0" true

# Query test breakpoint
debug test "myTest-1.0"
```

### 5.15 `[debug iqueue]` — Command Queue Management

```tcl
debug iqueue ?options? ?command?
```

**Purpose:** Manage the debugger's command queue, which holds commands
to be executed during the next interactive loop iteration.

**Options:**

| Option | Purpose |
|--------|---------|
| `-dump` | Dump queue contents |
| `-clear` | Clear the queue |

Without options and with a command argument, enqueues the command.

```tcl
# Enqueue a command for the debugger
debug iqueue "info vars"

# Dump all queued commands
debug iqueue -dump

# Clear the queue
debug iqueue -clear
```

### 5.16 `[debug variable]` — Variable Introspection

```tcl
debug variable ?options? varName
```

**Purpose:** Detailed introspection of a variable's internal state,
including searches, elements, links, and formatting.

**Options:**

| Option | Purpose |
|--------|---------|
| `-searches` | Include search state details |
| `-elements` | Include array element details |
| `-links` | Include variable link details |
| `-empty` | Include empty content sections |

Follows links via `EntityOps.FollowLinks()`, uses `DetailFlags` for
display formatting, and returns structured information via
`defaultHost.BuildLinkedVariableInfoList()`.

```tcl
# Basic variable introspection
debug variable myVar

# Full introspection with all details
debug variable -searches -elements -links myVar
```

### 5.17 `[debug runtimeoption]` — Runtime Option Management

```tcl
debug runtimeoption operation ?arg?
```

**Purpose:** Manage runtime options (string-based configuration values
that control interpreter behavior).

**Operations:**

| Operation | Purpose |
|-----------|---------|
| `has` | Check if a specific option exists |
| `get` | Get all runtime options |
| `clear` | Clear all options |
| `add` | Add a single option |
| `remove` | Remove a single option |
| `[set]` | Set the complete option list |

```tcl
# Add a runtime option
debug runtimeoption add "NoTrace"

# Check if option exists
debug runtimeoption has "NoTrace"

# Get all options
debug runtimeoption get

# Clear all
debug runtimeoption clear
```

### 5.18 `[debug readonly]` — Read-Only State Control

```tcl
debug readonly path kind enabled ?pattern?
```

**Purpose:** Lock or unlock identifiers (commands, procedures, variables)
in a child interpreter as read-only.

**Parameters:**
- `path` — child interpreter path
- `kind` — `IdentifierKind`: `Command`, `Procedure`, or `Variable`
- `enabled` — `true` to lock, `false` to unlock, empty to query
- `pattern` — optional glob pattern to filter which identifiers

Each kind uses a different implementation path:
- **Command**: `SetCommandsReadOnly()` / `GetCommandsReadOnly()`
- **Procedure**: `SetProceduresReadOnly()` / `GetProceduresReadOnly()`
- **Variable**: locks sync root, uses variable dictionary
  `SetReadOnly()` / `GetReadOnly()`

```tcl
# Make all commands in child read-only
debug readonly child1 Command true

# Make specific procedures read-only
debug readonly child1 Procedure true "safe_*"

# Query read-only state of variables
debug readonly child1 Variable {} "*"
```

### 5.19 `[debug set]` — Object-to-Variable Assignment

```tcl
debug set ?options? varName object
```

**Purpose:** Set a variable to a .NET object handle with reference
management.

**Options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `-reference` | integer | 0 | Adjust reference count (positive = add, negative = remove) |
| `-convert` | boolean | false | Convert object value to string |

### 5.20 `[debug exception]` — Exception Object Access

```tcl
debug exception ?options?
```

**Purpose:** Create an opaque object handle from the previous result's
exception. Uses `MarshalOps.FixupReturnValue()` to handle the exception
object. Requires `PREVIOUS_RESULT`.

### 5.21 `[debug result]` — Full Result with Stack Traces

```tcl
debug result
```

**Purpose:** Return the full result string including stack traces.
Deep-copies the current or previous result and returns full string
with stack trace information if available. Requires `PREVIOUS_RESULT`.

### 5.22 `[debug procedureflags]` — Procedure Flag Control

```tcl
debug procedureflags procName ?flags?
```

**Purpose:** Get or set the `ProcedureFlags` on a named procedure. This
can be used to mark procedures as obfuscated, hidden, or with other
internal flags.

### 5.23 `[debug bundle]` / `[debug mount]` / `[debug unmount]` — Script Bundling

```tcl
debug bundle fileName ?password? ?pattern?
debug mount fileName ?password?
debug unmount fileName
```

**Purpose:** Work with Eagle script bundles — signed, optionally
encrypted containers of scripts.

> **Why bundles, and how they work:** these sub-commands are the
> command-line surface of the script-bundle subsystem. For *why* bundles
> exist (authentic, tamper-evident, encrypted, sandboxed script
> distribution), the full SQLite `Scripts` table schema, the per-row RSA
> signature/key-ring trust model, isolation/security/rule-set metadata,
> and the mount → verify → evaluate lifecycle, see
> [`sql.md` § 8 "Script Bundle Databases"](sql.md#8-script-bundle-databases).

- `bundle` — extract and list scripts from a bundle file, with optional
  base64-encoded password and pattern filter
- `mount` — mount a bundle file into the interpreter's bundle manager,
  making its scripts available for sourcing
- `unmount` — remove a mounted bundle

All three require the `DATA` compile flag.

```tcl
# List scripts in a bundle
debug bundle myScripts.bundle

# Mount a password-protected bundle
debug bundle myScripts.bundle [base64 encode "mypass"]

# Mount bundle for use
debug mount myScripts.bundle

# Unmount
debug unmount myScripts.bundle
```

### 5.24 `[debug cacheconfiguration]` — Cache Configuration

```tcl
debug cacheconfiguration ?settings? ?level?
```

**Purpose:** Configure and query cache settings for argument, list,
parse, type, and COM type caches. Requires one or more of:
`ARGUMENT_CACHE`, `LIST_CACHE`, `PARSE_CACHE`, `TYPE_CACHE`,
`COM_TYPE_CACHE`.

### 5.25 Logging and Output Sub-Commands

#### `debug log ?options? message`

Write a message to the debug logging system.

| Option | Purpose |
|--------|---------|
| `-level` | Log level (integer) |
| `-category` | Log category (string) |

#### `debug output message ?priority?`

Output a debug message with optional priority. On Windows, uses
`OutputDebugString` (via `DebugOps.Output()`). Requires `NATIVE`.

#### `debug write message ?priority?`

Write a debug message with routing control. Parses optional
`DebugPriority` enum which includes routing flags:

| Flag | Purpose |
|------|---------|
| `NoViaOutput` | Skip `OutputDebugString` |
| `NoViaTrace` | Skip trace system |
| `NoViaHost` | Skip host output |

Calls `DebugOps.WriteWithoutFail()` with the extracted routing flags.

```tcl
# Log with category
debug log -category "Init" -level 3 "Initialization complete"

# Output to native debugger
debug output "Debug message" High

# Write with routing control
debug write "Message" {High, NoViaHost}
```

### 5.26 `[debug undelete]` — Variable Recovery

```tcl
debug undelete ?pattern?
```

**Purpose:** Undelete variables in the current call frame. Variables
marked as undefined (deleted but still in the frame's dictionary)
are restored. Returns the count of recovered variables.

### 5.27 `[debug pluginexecute]` — Plugin Request Execution

```tcl
debug pluginexecute name request
```

**Purpose:** Execute a plugin-specific request by looking up a loaded
plugin by name and calling its `Execute()` method with the request
as a string list. Returns the plugin's response.

### 5.28 Memory and Runtime-State Diagnostics

Several sub-commands form a focused diagnostics group for inspecting and
manipulating runtime memory, garbage collection, and recursion limits. They
are simple query/action sub-commands (no option parsing) but are grouped here
because together they constitute the bulk of Eagle's introspective
diagnostics surface.

#### `[debug memory]` — GC and Native Memory Statistics

Returns a name/value list built directly from `System.GC` (lines 2511–2555):

| Key | Source |
|-----|--------|
| `gcTotalMemory` | `GC.GetTotalMemory(false)` (does **not** force a collection) |
| `gcMaxGeneration` | `GC.MaxGeneration` |
| `gcCollectionCount(N)` | `GC.CollectionCount(N)` for each generation `0..MaxGeneration` |
| `isServerGC` | `GCSettings.IsServerGC` |
| `gcLatencyMode` | `GCSettings.LatencyMode` (`NET_35`/`NET_40`/`NET_STANDARD_20`) |
| `nativeMemory` + error | appended only if `NativeOps.GetMemoryStatus()` fails (`#if NATIVE`) |

Under `NATIVE`, the native memory status keys (from `NativeOps.GetMemoryStatus()`)
are merged into the same list.

#### `debug gcmemory ?collect?` — GC Heap Size

Returns `GC.GetTotalMemory(collect)` (lines 1678–1697). The optional boolean
`collect` is passed straight through: when `true`, the CLR performs a full
blocking collection **before** measuring, so the returned figure reflects
post-collection live memory rather than the current allocation.

#### `[debug sysmemory]` — System Memory Status

Returns the system memory status list from `NativeOps.GetMemoryStatus()`
(lines 4954–4980). Requires `NATIVE`; otherwise returns `"not implemented"`.

#### `debug collect ?flags?` — Force Garbage Collection

Parses an optional `GarbageFlags` value (default `GarbageFlags.ForCommand`)
and calls `ObjectOps.CollectGarbage(flags)` (lines 574–607). Returns an empty
result. Unlike `debug gcmemory true`, this does not report a memory figure —
it only triggers collection.

#### `debug stack ?force?` — Native Thread Stack Information

Returns a name/value list — `threadId`, `used`, `allocated`, `extra`,
`margin`, `maximum`, `reserve`, `commit` — via `RuntimeOps.GetStackSize()`
(lines 4581–4638). When `force` is `true`, the sub-command first calls
`RuntimeOps.RefreshNativeStackPointers(true)` and `RuntimeOps.CheckForStackSpace()`
(both `#if NATIVE`) so the figures reflect a freshly refreshed, validated
stack. The sub-command body itself compiles without `NATIVE`.

#### `[debug levels]` — Recursion Limit Inspection

Returns the five interpreter recursion ceilings (lines 2211–2230):
`maximumLevels`, `maximumScriptLevels`, `maximumScriptFileLevels`,
`maximumParserLevels`, `maximumExpressionLevels`. This is read-only — it
reports the limits but does not change them.

#### `debug history ?enabled?` — Command History Toggle

Gets or sets `interpreter.History` (lines 1719–1748). With no argument it
returns the current state; with a boolean it sets and returns it. Requires
the `HISTORY` compile flag; otherwise returns `"not implemented"`.

```tcl
# Snapshot GC state, force a collection, then re-measure
set before [dict get [debug memory] gcTotalMemory]
debug collect Default
set after [debug gcmemory true]

# Inspect native stack headroom for the current thread
debug stack true

# See the interpreter's recursion ceilings
debug levels

# Enable command history (if compiled with HISTORY)
debug history true
```

### 5.29 Token-Level Breakpoints and Emergency Recovery (Cross-Reference)

These two facilities round out the diagnostics surface and are documented in
detail in their own sections:

- **Token-level breakpoints** — `[debug token]` (§5.9) sets/clears/queries
  breakpoints at a `fileName`/`startLine`/`endLine` location, stored in the
  `BreakpointDictionary` (`PathDictionary<ScriptLocationIntDictionary>`).
  These fire only when the active `BreakpointType` (`[debug types]`) includes
  `Token` and the debugger is enabled. `[debug ontoken]` (§4.1) is the
  per-call toggle for token-break checking, and `[debug breakpoints]` (§4.3)
  lists the current set. All three require `DEBUGGER && DEBUGGER_BREAKPOINTS`.
- **Emergency recovery** — `[debug emergency]` (§5.2) is the recovery path
  when the debugger is missing or the interpreter is wedged. Its `Break` flag
  generates a `[debug break]` command and re-enters the ensemble via the
  `goto redo` mechanism (`redo:` label at line 93, jump at line 1297), so a
  single call can create,
  enable, reset cancel/halt state, and break — even from a degraded state.

> [!TIP]
> When a script is stuck (cancelled or halted) and the debugger may not even
> exist, `debug emergency {Created, Enabled, Reset, ForceResetCancel, ForceResetHalt, Break, IgnoreEnabled}`
> is the most robust single-shot recovery invocation: it builds a debugger if
> needed, clears the blocking state forcibly, and drops into an interactive
> break.

---

## 6. The `BreakpointType` Enum

The `BreakpointType` enum is a `[Flags]` `ulong` with 40+ individual
values. It controls which events trigger debugger breaks.

### 6.1 Core Types

| Type | Value | Purpose |
|------|-------|---------|
| `None` | `0x0` | No breakpoints |
| `SingleStep` | `0x20` | Single-step breakpoint |
| `MultipleStep` | `0x40` | Multiple-step breakpoint |
| `Demand` | `0x80` | Demand-based (`[debug break]`) |
| `Intercept` | `0x100` | Intercept breakpoint |
| `Token` | `0x200` | Token-based (file/line) |
| `Identifier` | `0x400` | Identifier-based |

### 6.2 Engine State Types

| Type | Purpose |
|------|---------|
| `Cancel` | Script cancellation |
| `Unwind` | Stack unwinding |
| `Error` | Error condition |
| `Return` | Return statement |
| `Test` | Test condition |
| `Exit` | Exit call |
| `Evaluate` | Evaluate mode (with Exit) |
| `Substitute` | Substitute mode (with Exit) |

### 6.3 Parsing/Execution Phase Types (Before/After Pairs)

Each phase has a `Before*` and `After*` variant:

| Phase | Triggers on |
|-------|------------|
| `Text` | Text processing |
| `Backslash` | Backslash substitution |
| `Unknown` | Unknown command resolution |
| `Expression` | Expression evaluation |
| `IExecute` | IExecute dispatch |
| `Command` | Command execution |
| `SubCommand` | Sub-command execution |
| `Operator` | Operator evaluation |
| `Function` | Function evaluation |
| `Procedure` | Procedure call |
| `ProcedureBody` | Procedure body execution |
| `LambdaBody` | Lambda body execution |

### 6.4 Variable Access Types

| Type | Purpose |
|------|---------|
| `BeforeVariableGet` | Before variable read |
| `BeforeVariableSet` | Before variable write |
| `BeforeVariableUnset` | Before variable unset |
| `BeforeVariableReset` | Before variable reset |
| `BeforeVariableAdd` | Before variable add |
| `BeforeVariableExist` | Before variable exist check |
| `BeforeVariableCount` | Before variable count |

### 6.5 Composite Presets

| Preset | Composition | Purpose |
|--------|-------------|---------|
| `Common` | `Demand \| Identifier \| EngineCancel \| EngineTest \| EngineExit \| BeforeStep \| VariableStep` | Common debugging types |
| `Standard` | `Common \| Token` | Standard debugging (includes token breakpoints) |
| `Ready` | `Cancel \| Unwind` | Used by `Interpreter.Ready()` |
| `Express` | `Common & ~(Expression \| Operator \| Function)` | Less noisy (no expression/operator/function breaks) |
| `Default` | `Express` | Default breakpoint set |
| `All` | All types combined | Everything |

```tcl
# Query current types
debug types

# Set to Standard (includes token breakpoints)
debug types Standard

# Add variable breakpoints to current types
set current [debug types]
debug types "$current, BeforeVariableGet, BeforeVariableSet"
```

---

## 7. The `HeaderFlags` Enum

`HeaderFlags` is a `[Flags]` `ulong` that controls what information
the debugger displays when entering an interactive break.

### 7.1 Information Sections

| Flag | Display content |
|------|----------------|
| `StopPrompt` | "[Stop]" prompt |
| `GoPrompt` | "[Go]" prompt |
| `AnnouncementInfo` | "Eagle Debugger" banner |
| `DebuggerInfo` | Active debugger properties |
| `EngineInfo` | Engine properties |
| `ControlInfo` | Control properties |
| `EntityInfo` | Entity counts (commands, variables, etc.) |
| `StackInfo` | Native stack information |
| `FlagInfo` | Engine/substitution/notification flags |
| `ArgumentInfo` | Breakpoint reason and arguments |
| `TokenInfo` | Token information |
| `TraceInfo` | Variable trace information |
| `InterpreterInfo` | Interpreter state |
| `CallStack` | Call stack |
| `CallStackInfo` | Call stack (boxed style) |
| `VariableInfo` | Variable properties |
| `ObjectInfo` | Object properties |
| `HostInfo` | Host properties |
| `TestInfo` | Test properties |
| `CallFrameInfo` | Call frame properties |
| `ResultInfo` | Result information |
| `ComplaintInfo` | Complaint storage |
| `HistoryInfo` | Command history |
| `CustomInfo` | Custom host information |

### 7.2 Control Flags

| Flag | Purpose |
|------|---------|
| `Invalid` | Flags not yet explicitly set |
| `User` | Explicitly set by user |
| `AutoSize` | Select info based on host window size |
| `AutoRetry` | Retry failed `WriteBox` calls |
| `EmptySection` | Display sections even if empty |
| `EmptyContent` | Display values even if empty |
| `VerboseSection` | Display verbose-only sections |
| `VerboseContent` | Display verbose content |
| `Debug` | Debugger is currently active |

### 7.3 Extended Information

| Flag | Purpose |
|------|---------|
| `CallStackAllFrames` | Show all frames, not just script-accessible |
| `DebuggerBreakpoints` | Show breakpoint details |
| `EngineNative` | Show native integration info |
| `HostDimensions` | Show host window dimensions |
| `HostFormatting` | Show host formatting details |
| `HostColors` | Show host color scheme |
| `HostNames` | Show host theme names |
| `TraceCached` | Show cached trace info |
| `VariableLinks` | Show variable link chains |
| `VariableSearches` | Show variable search details |
| `VariableElements` | Show array element details |

---

## 8. The `InteractiveLoopData` Structure

`InteractiveLoopData` carries all context needed when the debugger enters
an interactive breakpoint loop.

### 8.1 Properties

| Property | Type | Purpose |
|----------|------|---------|
| `Debug` | `bool` | Whether in debug mode |
| `Args` | `IEnumerable<string>` | Shell arguments |
| `Code` | `ReturnCode` | Return code that triggered break |
| `BreakpointType` | `BreakpointType` | Type of breakpoint hit |
| `BreakpointName` | `[string]` | Name of breakpoint |
| `Token` | `IToken` | Current script token |
| `TraceInfo` | `ITraceInfo` | Variable trace information |
| `EngineFlags` | `EngineFlags` | Engine configuration |
| `SubstitutionFlags` | `SubstitutionFlags` | Substitution flags |
| `EventFlags` | `EventFlags` | Event configuration |
| `ExpressionFlags` | `ExpressionFlags` | Expression flags |
| `HeaderFlags` | `HeaderFlags` | Display header control |
| `ClientData` | `IClientData` | Custom client data |
| `Arguments` | `ArgumentList` | Breakpoint arguments |
| `Exit` | `bool` | Force exit on return |

### 8.2 Construction

`InteractiveLoopData` has multiple constructors for different breakpoint
scenarios:

| Constructor variant | Use case |
|--------------------|----------|
| Default | Empty data for interactive shell |
| Copy | Clone from existing `IInteractiveLoopData` |
| Debug copy | For debugger (sets `Debug = true`) |
| Token/Trace | For token breakpoints and variable traces |
| Command break | For `[debug break]` command |
| Watchpoint | For `Engine.CheckWatchpoints()` |
| Breakpoint | For `Engine.CheckBreakpoints()` |

---

## 9. Practical Patterns

### 9.1 Setting Up a Debug Session

```tcl
# Initialize the debugger
debug setup true true    ;# create=true, isolated=true

# Enable debugging
debug enable true

# Set breakpoint types
debug types Standard

# Enable break on errors
debug onerror true

# Set a breakpoint on line 42
debug token myScript.eagle 42 42 true

# Set watchpoint on a variable
debug watch importantVar {BreakOnSet, BreakOnUnset}
```

### 9.2 Emergency Recovery

```tcl
# Script is stuck/cancelled — emergency recovery
debug emergency {Created, Enabled, Reset, ResetCancel, ForceResetHalt, Break, IgnoreEnabled}

# Simpler: use the Full preset
debug emergency Full
```

### 9.3 Non-Debugged Execution

```tcl
# Run expensive operation without debugger overhead
debug run {
    source bigScript.eagle
}

# Or manually suspend/resume
debug suspend
source bigScript.eagle
debug resume
```

### 9.4 Inspecting State During Break

```tcl
# Inside an interactive debug break:

# Check what triggered the break
debug status

# Inspect a variable's internals
debug variable -elements -links myArray

# Execute at a specific call level
debug invoke 2 info vars

# Check memory usage
debug memory
debug gcmemory true
```

### 9.5 Configuring Trace Output

```tcl
# Set up trace for specific categories
debug trace -resetsystem true
debug trace -forceenabled true -console true
debug trace -enabledcategories "Engine,Command,Variable"
debug trace -priority Medium

# Write a trace message
debug trace -category "MyApp" "Checkpoint reached"
```

---

## 10. Safe Interpreter Restrictions

The `[debug]` command carries `CommandFlags.Unsafe` and is **completely
unavailable** in safe interpreters. This is appropriate given that
the command provides:

- Direct debugger control and state manipulation
- Memory and GC access
- Plugin execution
- Runtime option modification
- Variable locking and read-only control
- Emergency recovery (which can reset cancellation/halt state)
- Shell launching
- Script evaluation in child interpreters

None of these operations are appropriate for sandboxed code.

---

## 11. Tcl Comparison

| Feature | Tcl approach | Eagle `[debug]` approach |
|---------|-------------|----------------------|
| Line breakpoints | External debugger (e.g., TclPro) | `debug token file start end true` |
| Variable watch | `trace add variable name ops cmd` | `debug watch name {BreakOnGet, BreakOnSet}` |
| Single-step | External debugger | `debug step true` |
| Break into debugger | N/A | `[debug break]` |
| Emergency recovery | N/A | `[debug emergency]` with lifecycle flags |
| Run without debug | N/A (no built-in debugger) | `debug run { script }` |
| Memory diagnostics | N/A | `[debug memory]` / `[debug gcmemory]` / `[debug sysmemory]` |
| Script bundles | N/A | `[debug bundle]` / `[debug mount]` / `[debug unmount]` |
| Trace configuration | `trace add execution` (limited) | `[debug trace]` with 20+ options |
| Secure sandbox eval | `[interp eval]` (limited security) | `[debug secureeval]` with timeout, trust, events |
| Plugin interaction | N/A | `[debug pluginexecute]` |
| Command queue | N/A | `[debug iqueue]` |

---

## 12. Security Considerations

- The command is marked `Unsafe | Critical` — never exposed in safe
  interpreters
- `[debug emergency]` acquires a hard lock on the interpreter and can
  reset cancellation/halt states, making it a powerful recovery tool
  but also a potential stability concern if misused
- `[debug secureeval]` provides sandboxed execution but with explicit
  trust and timeout controls that must be configured correctly
- `[debug lockvar]` and `[debug readonly]` can prevent modification of
  critical variables and commands
- `[debug pluginexecute]` allows arbitrary plugin request execution —
  trust the plugin before calling
- `debug shell -asynchronous` creates background threads that share
  the interpreter — concurrent access risks apply
