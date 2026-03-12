# Eagle `[tcl]` Command: Deep-Dive Analysis of Native Tcl Integration

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `tcl` command internals. For basic command syntax and options, see [`core_language.md`](core_language.md#cmd-tcl). For usage examples, see [`core_examples.md`](core_examples.md#ex-tcl). For the Garuda native package (Tcl-to-Eagle direction), see [`garuda.md`](garuda.md). For the `loadGarudaForUseByEagle` script library procedure, see [`core_script_library.md`](core_script_library.md#initialization-initeagle).

## 1. Executive Summary

Eagle's `[tcl]` command provides **bidirectional integration with native Tcl**
from within an Eagle interpreter. It dynamically loads a native Tcl shared
library (DLL/`.so`/`.dylib`), creates and manages Tcl interpreters, evaluates
Tcl scripts, exchanges variables, bridges commands between the two runtimes,
and manages Tcl threads — all from Eagle script code.

This is a concept **unique to Eagle**. Native Tcl has no mechanism to embed
another Tcl-compatible language inside itself at the command level. While Tcl
supports embedded C extensions and `interp` for child interpreters, those
child interpreters are still native Tcl. Eagle's `[tcl]` command creates a
fundamentally different relationship: a .NET/CLR-hosted scripting engine
(Eagle) dynamically loads and controls a native C runtime (Tcl) through
P/Invoke-style function pointer marshalling.

The **reverse direction** — native Tcl loading Eagle — is handled by
**Garuda**, the Eagle Native Package for Tcl (documented separately in
[`garuda.md`](garuda.md)). Together, `[tcl]` and Garuda form a complete
bidirectional bridge: Eagle can evaluate Tcl code, and Tcl can evaluate
Eagle code.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Tcl.cs` | 2,756 | Main command implementation (37 sub-commands) |
| `Eagle/Library/Components/Private/TclWrapper.cs` | 8,999 | P/Invoke wrappers and native library loading |
| `Eagle/Library/Components/Private/TclApi.cs` | 3,101 | Managed Tcl API wrapper (49 function pointers) |
| `Eagle/Library/Components/Private/TclBridge.cs` | 875 | Bidirectional command bridging |
| `Eagle/Library/Components/Private/TclThread.cs` | 3,020 | Isolated Tcl worker threads |
| `Eagle/Library/Components/Private/TclDelegates.cs` | 1,061 | Native delegate declarations |
| `Eagle/Library/Components/Private/TclModule.cs` | 247 | Native module lifecycle and reference counting |
| `Eagle/Library/Components/Private/TclBuild.cs` | 247 | Tcl build discovery metadata |
| `Eagle/Library/Components/Private/TclStructs.cs` | 176 | Native struct definitions (Tcl_Obj, Tcl_ObjType) |
| `Eagle/Library/Components/Private/TclVars.cs` | 501 | Standard Tcl variable name constants |
| `Eagle/Library/Interfaces/Private/TclApi.cs` | 162 | ITclApi interface definition |

**Command flags:** `NativeCode | Unsafe | Critical | NonStandard` — the
command requires native code access, is not available in safe interpreters,
is critical to system operation, and is explicitly marked as a non-standard
Eagle extension.

**Object group:** `nativeEnvironment` — classified alongside other native
platform interaction commands.

## 2. Why This Command Exists

### The Interoperability Problem

Eagle is Tcl-compatible but runs on the .NET CLR. It can execute most Tcl
scripts, but it cannot run native Tcl extensions (C-coded packages like Tk,
Expect, or database drivers). Conversely, native Tcl cannot access .NET
types, assemblies, or the CLR. This creates a gap for users who need both
worlds.

### The Eagle Solution

The `[tcl]` command solves this by **embedding native Tcl inside Eagle**:

1. **Library Loading**: Dynamically loads the native Tcl shared library
   using platform-specific mechanisms (P/Invoke on Windows, dlopen on
   Unix/macOS).
2. **Interpreter Management**: Creates and manages native Tcl interpreters
   (`Tcl_Interp*`) from Eagle script code.
3. **Script Evaluation**: Evaluates Tcl scripts in the native interpreter,
   returning results to Eagle.
4. **Variable Exchange**: Reads and writes variables across the boundary.
5. **Command Bridging**: Makes Eagle commands callable from Tcl (and
   vice versa via Garuda).
6. **Thread Management**: Creates isolated Tcl threads with their own
   interpreters for concurrent operations.

This means an Eagle script can, for example, use Tk for GUI, call native Tcl
database extensions, or leverage any C-based Tcl package — all while
maintaining access to .NET types and assemblies through Eagle's `[object]`
command.

### Comparison: Eagle `[tcl]` vs. Tcl `[interp]`

| Feature | Eagle `[tcl]` | Tcl `[interp]` |
|---------|--------------|----------------|
| Creates interpreters | Yes (native Tcl `Tcl_Interp*`) | Yes (child Tcl interpreters) |
| Cross-runtime | Yes (CLR ↔ native C) | No (Tcl ↔ Tcl only) |
| Dynamic library loading | Yes (finds and loads `libtcl`) | No (Tcl is already running) |
| Command bridging | Yes (Eagle commands visible in Tcl) | Yes (aliases between interpreters) |
| Variable exchange | Yes (`tcl set`/`tcl unset`) | Yes (`interp eval`) |
| Thread isolation | Yes (`tcl queue`, Tcl threads) | Limited (threaded Tcl builds) |
| Native extension access | Yes (full native Tcl package system) | Yes (native packages) |
| .NET type access | Yes (via Eagle's `[object]`) | No |

## 3. Architecture Overview

### 3.1 The Integration Stack

```
┌─────────────────────────────────────────────┐
│  Eagle Script                               │
│  tcl eval $interp { package require Tk }    │
├─────────────────────────────────────────────┤
│  Tcl.cs (Command Implementation)            │
│  37 sub-commands, option parsing             │
├─────────────────────────────────────────────┤
│  Interpreter (Managed)                      │
│  Tcl interpreter registry, bridges, threads │
├─────────────────────────────────────────────┤
│  TclWrapper.cs (Static Utilities)           │
│  Library discovery, loading, API calls      │
├─────────────────────────────────────────────┤
│  TclApi.cs (ITclApi Implementation)         │
│  49 marshalled function pointers            │
│  NativeStubs structure ←→ GarudaInt.h       │
├─────────────────────────────────────────────┤
│  Native Tcl Library (libtcl8.6.so, etc.)    │
│  Tcl_CreateInterp, Tcl_EvalObjEx, etc.      │
└─────────────────────────────────────────────┘
```

### 3.2 Key Architectural Decisions

1. **Dynamic Loading, Not Linking**: Eagle does not link against the Tcl
   library at compile time. The native library is discovered and loaded at
   runtime via `tcl load`. This means Eagle works with or without Tcl
   installed.

2. **Function Pointer Marshalling**: All Tcl C API calls go through a
   `NativeStubs` structure containing 49 `IntPtr` fields — one per Tcl
   function. These are marshalled into .NET delegates via
   `Marshal.GetDelegateForFunctionPointer()`. The stubs structure layout
   matches the `ClrTclStubs` structure defined in Garuda's `GarudaInt.h`.

3. **Interpreter as IntPtr**: Tcl interpreters are stored as raw `IntPtr`
   values (native `Tcl_Interp*` pointers). Eagle maintains a name-to-pointer
   registry (`IntPtrDictionary`) for managed access.

4. **UTF-8 String Marshalling**: All string exchange between Eagle (.NET
   Unicode) and Tcl (UTF-8) goes through `TclEncoding` (UTF-8). This is
   transparent to the user but is a critical implementation detail.

5. **Reference Counting for Module Safety**: The `TclModule` class uses
   `Interlocked` operations for thread-safe reference counting, preventing
   the native library from being unloaded while interpreters or bridges
   are still active.

## 4. Sub-Command Reference

The `[tcl]` ensemble has **37 sub-commands**, organized into functional
groups:

### 4.1 Library Management

#### `tcl load ?options? ?path?`

Dynamically loads the native Tcl library. This must be called before any
other `tcl` sub-commands that require a Tcl interpreter.

**Options:**

| Option | Effect |
|--------|--------|
| `-findflags flags` | Control library search behavior (FindFlags enum) |
| `-loadflags flags` | Control loading behavior (LoadFlags enum) |
| `-robustify` | Exclude ActiveTcl BasiKits; enable SetDllDirectory on Windows |
| `-trustedonly` | Only load from trusted/signed locations |
| `-maybetrustedonly` | Same as `-trustedonly` in release builds only |
| `-eval script` | Evaluate a script as part of the find process |
| `-bridge` | Automatically add a standard Eagle bridge command |
| `-noforcedelete` | Don't force-delete bridges on cleanup |
| `-nocomplain` | Suppress errors from bridge operations |
| `-minimumversion ver` | Minimum acceptable Tcl version |
| `-maximumversion ver` | Maximum acceptable Tcl version |
| `-unknownversion ver` | Version to assume for unversioned libraries |

**Returns:** The name of the primary Tcl interpreter handle.

**Implementation** (`Tcl.cs`, lines 1325-1545):
1. Parses options and constructs `FindFlags` and `LoadFlags`.
2. If `path` is provided, restricts search to that specific file/directory
   via `FindFlags.SpecificPath`.
3. Calls `interpreter.LoadTcl()`, which delegates to `TclWrapper` for
   platform-specific library discovery and loading.
4. Creates a primary Tcl interpreter (`Tcl_CreateInterp`).
5. Optionally adds a standard bridge command via `AddStandardTclBridge()`.

**Library Discovery Process** (in `TclWrapper.cs`):
1. Searches platform-specific locations: registry (Windows), standard
   library paths, environment variables, and the `path` argument.
2. Pattern-matches filenames (e.g., `tcl86.dll`, `libtcl8.6.so`,
   `libtcl8.6.dylib`).
3. Optionally validates via `NativeOps.TestLoadLibrary()` (especially
   important on macOS).
4. Loads using `NativeOps.LoadLibrary()` → `LoadLibraryW` (Windows) or
   `dlopen` (Unix/macOS).
5. Extracts the `NativeStubs` function pointer structure.
6. Marshals all 49 function pointers into .NET delegates.

#### `tcl unload`

Unloads the native Tcl library and releases all associated resources.

**Returns:** Empty string on success.

**Implementation:** Calls `interpreter.UnloadTcl()` with the configured
unload flags. This calls `Tcl_Finalize()` and releases the native module
handle.

#### `tcl available ?options? ?path? ?pattern?`

Checks whether a Tcl library is available without actually loading it.
Shares the same discovery logic as `tcl find` but returns a boolean.

**Returns:** `1` if Tcl is available, `0` otherwise.

#### `tcl find ?options? ?path? ?pattern?`

Searches for Tcl installations and returns information about what was found.

**Options:** Same as `tcl load` plus `-verbose`, `-full`, `-errorsvar`.

**Returns:** List of found Tcl builds (paths), or with `-full`, detailed
build metadata for each.

#### `tcl select ?options? ?path?`

Finds Tcl installations and selects the "best" one based on version,
platform, and priority criteria.

**Returns:** Detailed build information for the selected Tcl installation.

#### `tcl ready ?interp?`

Checks whether Tcl is loaded and operational.

- Without `interp`: checks if the Tcl API module is loaded.
- With `interp`: performs a full check including interpreter validity and
  thread affinity.

**Returns:** Boolean `1` or `0`.

#### `tcl build`

Returns information about the loaded Tcl library build (version, patch level,
threaded/debug status, etc.).

#### `tcl module ?full?`

Returns the file path of the loaded Tcl native module. With `full`, returns
detailed `TclModule` metadata.

#### `tcl versionrange ?options?`

Returns the range of Tcl versions supported by the current configuration.
Useful for determining compatibility.

**Options:** `-minimumversion`, `-maximumversion`, `-majorincrement`,
`-minorincrement`, `-intermediateminimum`, `-intermediatemaximum`.

### 4.2 Interpreter Lifecycle

#### `tcl create ?options?`

Creates a new native Tcl interpreter.

**Options:**

| Option | Effect |
|--------|--------|
| `-alias` | Create an Eagle alias command for the interpreter handle |
| `-noinitialize` | Don't call `Tcl_Init()` (skip library initialization) |
| `-memory` | Use Tcl's memory debugging subsystem |
| `-safe` | Create a safe (sandboxed) Tcl interpreter via `Tcl_MakeSafe()` |
| `-nobridge` | Don't set up the standard command bridge |
| `-noforcedelete` | Don't force-delete the bridge on cleanup |
| `-nocomplain` | Suppress bridge-related errors |

**Returns:** The interpreter handle name (e.g., `tcl0`).

**Implementation** (`Tcl.cs`, lines 576-731):
1. Constructs `TclCreateFlags` from options.
2. Calls `interpreter.CreateTclInterpreter(createFlags)`, which:
   - Calls `Tcl_CreateInterp()` via the marshalled function pointer.
   - Optionally calls `Tcl_Init()` (unless `-noinitialize`).
   - Optionally calls `Tcl_MakeSafe()` (if `-safe`).
   - Registers the interpreter in Eagle's name-to-pointer registry.
3. If `-alias`: creates an Eagle command alias for the handle.
4. If bridge enabled: calls `AddStandardTclBridge()` to register an
   `eagle` command inside the Tcl interpreter.
5. On failure: automatically cleans up the Tcl interpreter.

#### `tcl delete interp`

Deletes a Tcl interpreter and cleans up all associated resources.

**Implementation:**
1. Removes any Eagle alias for the interpreter handle.
2. Calls `interpreter.DeleteTclInterpreter(interpName)`, which:
   - Removes all bridges associated with this interpreter.
   - Calls `Tcl_DeleteInterp()`.
   - Removes from the name-to-pointer registry.

#### `tcl exists interp`

Tests whether a Tcl interpreter handle is valid.

**Returns:** Boolean `1` or `0`.

#### `tcl interps ?pattern?`

Lists all Tcl interpreter handles, optionally filtered by glob pattern.

**Returns:** List of interpreter handle names.

#### `tcl primary`

Returns the handle of the primary (first-created) Tcl interpreter.

#### `tcl active interp`

Gets or sets the "active" flag on a Tcl interpreter. Implements TIP #335
semantics.

#### `tcl preserve interp`

Increments the Tcl interpreter's reference count via `Tcl_Preserve()`.
This prevents the interpreter from being deleted while it is in use by
external code.

#### `tcl release interp`

Decrements the Tcl interpreter's reference count via `Tcl_Release()`.
When the count reaches zero and deletion has been requested, the interpreter
is actually freed.

### 4.3 Script Evaluation

#### `tcl eval ?options? interp arg ?arg ...?`

Evaluates a Tcl script in the specified native Tcl interpreter.

**Options:**

| Option | Effect |
|--------|--------|
| `-time` | Measure and report evaluation time |
| `-exceptions` | Control .NET exception propagation (boolean) |

**Returns:** The result of the Tcl evaluation.

**Implementation** (`Tcl.cs`, lines 807-875):
1. Resolves the Tcl interpreter from the handle name.
2. If multiple `arg` values: concatenates them (like Tcl's `eval`).
3. Calls `interpreter.EvaluateTclScript()`, which:
   - Marshals the script string to UTF-8.
   - Calls `Tcl_EvalObjEx()` via the function pointer.
   - Retrieves the result via `Tcl_GetObjResult()`.
   - Marshals the result back to .NET Unicode.
4. If `-exceptions` is true and Tcl returns an error, the Tcl error is
   converted to a .NET exception.

#### `tcl expr ?options? interp arg ?arg ...?`

Evaluates a Tcl expression in the specified interpreter. Like `tcl eval`
but calls `Tcl_ExprObj()` instead of `Tcl_EvalObjEx()`.

**Options:** Same as `tcl eval`.

#### `tcl subst ?options? interp string`

Performs Tcl substitution on a string in the specified interpreter.

**Options:** `-nobackslashes`, `-nocommands`, `-novariables` (standard Tcl
`subst` options), plus `-time` and `-exceptions`.

**Implementation:** Calls `Tcl_SubstObj()` with the appropriate
`Tcl_SubstFlags`.

#### `tcl source ?options? interp fileName`

Sources (evaluates) a Tcl file in the specified interpreter.

**Options:** `-time`, `-exceptions`.

**Implementation:** Calls `Tcl_EvalFile()` via the function pointer.

#### `tcl recordandeval ?options? interp arg ?arg ...?`

Evaluates a Tcl script and records it in the interpreter's history.

**Options:** `-time`, `-exceptions`.

**Implementation:** Calls `Tcl_RecordAndEvalObj()`.

#### `tcl result interp`

Returns the current result string from the Tcl interpreter without
evaluating anything.

**Returns:** A two-element list: `{returnCode resultString}`.

#### `tcl complete command`

Tests whether a Tcl command string is syntactically complete (balanced
braces, quotes, etc.).

**Returns:** Boolean `1` or `0`.

**Implementation:** Calls `Tcl_CommandComplete()`.

### 4.4 Variable Access

#### `tcl set interp varName ?newValue?`

Gets or sets a variable in the native Tcl interpreter.

- With two arguments (`interp varName`): gets the variable value via
  `Tcl_ObjGetVar2()`.
- With three arguments (`interp varName newValue`): sets the variable via
  `Tcl_ObjSetVar2()`.

**Returns:** The variable value.

#### `tcl unset interp varName`

Removes a variable from the Tcl interpreter via `Tcl_UnsetVar2()`.

### 4.5 Command Bridging

This is one of the most important features of the `[tcl]` command. Command
bridging allows Eagle commands to be called from within Tcl scripts.

#### `tcl command create ?options? srcCmd interp targetCmd`

Creates a command bridge between Eagle and Tcl.

**Parameters:**
- `srcCmd` — The Eagle command (or procedure) to bridge.
- `interp` — The target Tcl interpreter handle.
- `targetCmd` — The name the command will have inside Tcl.

**Options:**
- `-noforcedelete` — Don't force-delete the bridge on cleanup.
- `-nocomplain` — Suppress errors from the bridge.

**Returns:** The bridge name.

**How bridging works** (in `TclBridge.cs`):

1. Eagle resolves `srcCmd` to an `IExecute` interface (command or procedure).
2. A `TclBridge` object is created, holding:
   - A `GCHandle` pinning it in memory (prevents GC during native callbacks).
   - A `Tcl_ObjCmdProc` delegate (`ObjCmdProc` method).
   - A `Tcl_CmdDeleteProc` delegate (`CmdDeleteProc` method).
3. `Tcl_CreateObjCommand()` is called in the Tcl interpreter, registering
   `targetCmd` with the bridge's `ObjCmdProc` as the callback and the
   `GCHandle` as the `clientData`.
4. When Tcl code calls `targetCmd`:
   - Tcl invokes the native callback with the `clientData`.
   - The `ObjCmdProc` rehydrates the `GCHandle` to get the `TclBridge`.
   - It marshals Tcl arguments to an Eagle `ArgumentList`.
   - It calls `interpreter.Execute()` to run the Eagle command.
   - It marshals the Eagle result back to Tcl via `TclWrapper.SetResult()`.
   - Thread safety is maintained via `BeginExternalExecution()` /
     `EndAndCleanupExternalExecution()`.

**The standard bridge**: When `tcl create` is called without `-nobridge`
(or `tcl load` with `-bridge`), a standard bridge is automatically created.
This registers an `eagle` command in the Tcl interpreter that can evaluate
arbitrary Eagle scripts:

```tcl
# Inside the native Tcl interpreter:
eagle {set x [expr {2 + 3}]}   ;# Evaluates in Eagle, returns "5"
eagle {object invoke System.DateTime Now}  ;# Access .NET from Tcl!
```

#### `tcl command delete interp targetCmd`

Removes a command bridge. Calls `interpreter.RemoveTclBridge()`, which
calls `Tcl_DeleteCommandFromToken()` in the Tcl interpreter.

#### `tcl command exists interp targetCmd`

Tests whether a bridged command exists.

**Returns:** Boolean `1` or `0`.

#### `tcl command list ?pattern?`

Lists all command bridges, optionally filtered by glob pattern.

### 4.6 Execution Control

#### `tcl cancel ?options? interp ?result?`

Cancels script evaluation in a Tcl interpreter. Implements TIP #285
semantics.

**Options:**
- `-time` — Measure cancellation time.
- `-unwind` — Unwind the call stack (stronger cancellation).

**Implementation:** Calls `Tcl_CancelEval()` via the function pointer.

#### `tcl canceled interp`

Checks whether a Tcl interpreter has been canceled.

**Returns:** Empty string if not canceled; error if canceled.

#### `tcl resetcancel ?options? interp`

Resets the canceled state of a Tcl interpreter, allowing it to evaluate
scripts again.

**Options:**
- `-children` — Also reset child interpreters.
- `-force` — Force the reset.

### 4.7 Type System

#### `tcl convert interp string type`

Converts a Tcl value to the specified Tcl object type (e.g., `int`,
`double`, `list`). This triggers Tcl's internal representation conversion.

#### `tcl types interp`

Lists all registered Tcl object types in the interpreter. Calls
`Tcl_AppendAllObjTypes()`.

### 4.8 Thread Management

#### `tcl threads ?pattern?`

Lists all Tcl worker threads, optionally filtered by glob pattern.

**Note:** Requires `TCL_THREADS` compile-time flag.

#### `tcl queue ?options? interp arg ?arg ...?`

Queues a script for execution in a Tcl worker thread.

**Options:**

| Option | Effect |
|--------|--------|
| `-eventtype type` | Type of event to queue (default: Evaluate) |
| `-eventflags flags` | Event flags |
| `-data object` | Custom data object to pass |
| `-exceptions bool` | Control exception propagation |
| `-synchronous bool` | Wait for completion (default: false) |

**Implementation:** Calls `interpreter.QueueTclThreadEvent()`, which posts
an event to the target Tcl thread's event queue.

**Note:** Requires `TCL_THREADS` compile-time flag.

### 4.9 Miscellaneous

#### `tcl errorline interp ?line?`

Gets or sets the error line number in a Tcl interpreter. Implements TIP #336
semantics.

#### `tcl exceptions ?exceptions?`

Gets or sets the global exception handling behavior. When enabled, Tcl errors
are propagated as .NET exceptions.

#### `tcl update ?options?`

Processes pending Tcl events via `Tcl_DoOneEvent()`.

**Options:**
- `-timeout milliseconds` — Maximum time to process events.
- `-wait` — Wait for events if none are pending.
- `-all` — Process all pending events (not just one).
- `-nocomplain` — Suppress errors.

**Returns:** `{eventCount N sleepCount M}` — the number of events processed
and sleep cycles.

## 5. The Function Pointer Marshalling Layer

### 5.1 NativeStubs Structure

The core of the native integration is a structure of 49 `IntPtr` fields that
map one-to-one to Tcl C API functions. This structure matches the
`ClrTclStubs` structure in Garuda's `GarudaInt.h`:

| # | Function | Purpose |
|---|----------|---------|
| 1 | `Tcl_GetVersion` | Get Tcl version numbers |
| 2 | `Tcl_FindExecutable` | Initialize Tcl's path logic |
| 3 | `Tcl_CreateInterp` | Create interpreter |
| 4 | `Tcl_Preserve` | Reference count increment |
| 5 | `Tcl_Release` | Reference count decrement |
| 6 | `Tcl_ObjGetVar2` | Get variable value |
| 7 | `Tcl_ObjSetVar2` | Set variable value |
| 8 | `Tcl_UnsetVar2` | Unset variable |
| 9 | `Tcl_Init` | Initialize interpreter |
| 10 | `Tcl_InitMemory` | Initialize memory debugging |
| 11 | `Tcl_MakeSafe` | Convert to safe interpreter |
| 12 | `Tcl_GetObjType` | Get object type by name |
| 13 | `Tcl_AppendAllObjTypes` | List all object types |
| 14 | `Tcl_ConvertToType` | Convert value to type |
| 15 | `Tcl_CreateObjCommand` | Create command |
| 16 | `Tcl_DeleteCommandFromToken` | Delete command |
| 17 | `Tcl_DeleteInterp` | Delete interpreter |
| 18 | `Tcl_InterpDeleted` | Check if interpreter deleted |
| 19 | `Tcl_InterpActive` | Check if interpreter active |
| 20 | `Tcl_GetErrorLine` | Get error line number |
| 21 | `Tcl_SetErrorLine` | Set error line number |
| 22 | `Tcl_NewObj` | Create empty Tcl object |
| 23 | `Tcl_NewUnicodeObj` | Create Unicode string object |
| 24 | `Tcl_NewStringObj` | Create UTF-8 string object |
| 25 | `Tcl_NewByteArrayObj` | Create byte array object |
| 26 | `Tcl_DbIncrRefCount` | Debug reference count increment |
| 27 | `Tcl_DbDecrRefCount` | Debug reference count decrement |
| 28 | `Tcl_CommandComplete` | Check command completeness |
| 29 | `Tcl_AllowExceptions` | Allow exceptions in next eval |
| 30 | `Tcl_EvalObjEx` | Evaluate script object |
| 31 | `Tcl_EvalFile` | Evaluate script file |
| 32 | `Tcl_RecordAndEvalObj` | Record and evaluate |
| 33 | `Tcl_ExprObj` | Evaluate expression |
| 34 | `Tcl_SubstObj` | Perform substitution |
| 35 | `Tcl_CancelEval` | Cancel evaluation (TIP #285) |
| 36 | `Tcl_Canceled` | Check cancellation status |
| 37 | `Tcl_ResetCancellation` | Reset cancellation |
| 38 | `Tcl_SetInterpCancelFlags` | Set cancellation flags |
| 39 | `Tcl_DoOneEvent` | Process one event |
| 40 | `Tcl_ResetResult` | Clear result |
| 41 | `Tcl_GetObjResult` | Get result object |
| 42 | `Tcl_SetObjResult` | Set result object |
| 43 | `Tcl_GetUnicodeFromObj` | Get Unicode string from object |
| 44 | `Tcl_GetStringFromObj` | Get UTF-8 string from object |
| 45 | `Tcl_CreateExitHandler` | Register exit handler |
| 46 | `Tcl_DeleteExitHandler` | Remove exit handler |
| 47 | `Tcl_FinalizeThread` | Finalize thread-local state |
| 48 | `Tcl_Finalize` | Finalize Tcl subsystem |
| 49 | `Tcl_CreateThread` | Create Tcl thread |

### 5.2 How Function Pointer Marshalling Works

The marshalling process:

1. **Load**: `NativeOps.LoadLibrary()` loads the native Tcl DLL/SO.
2. **Extract**: The `NativeStubs` structure is extracted from the loaded
   module. The layout must exactly match `ClrTclStubs` from Garuda.
3. **Marshal**: `Marshal.PtrToStructure()` copies the 49 `IntPtr` values.
4. **Delegate creation**: For each function pointer,
   `Marshal.GetDelegateForFunctionPointer()` creates a callable .NET delegate.
5. **Caching**: Delegates are stored in a `TypeDelegateDictionary` for
   reuse. Each delegate type (e.g., `Tcl_ObjCmdProc`) has the appropriate
   `[UnmanagedFunctionPointer]` attribute with `CallingConvention.StdCall`
   or `Cdecl`.

This approach avoids compile-time linking and allows Eagle to work with
any compatible Tcl version (8.4+) discovered at runtime.

## 6. Command Bridging in Detail

The command bridge is the mechanism that allows Eagle commands to be called
from Tcl code. It is architecturally significant and worth understanding in
depth.

### 6.1 Bridge Lifecycle

```
Eagle side                           Tcl side
──────────                           ────────
tcl command create myCmd $interp tclName
  │
  ├─► Create TclBridge object
  │     - GCHandle.Alloc(bridge, Pinned)
  │     - Create ObjCmdProc delegate
  │     - Create CmdDeleteProc delegate
  │
  ├─► Tcl_CreateObjCommand(interp,      ──► "tclName" registered
  │     "tclName", objCmdProc,               in Tcl interpreter
  │     clientData=GCHandle)
  │
  │   ... time passes ...
  │
  │                                      Tcl script calls "tclName arg1 arg2"
  │                                        │
  │   ObjCmdProc callback fired  ◄─────────┘
  │     │
  │     ├─► Rehydrate GCHandle → TclBridge
  │     ├─► Marshal Tcl args → Eagle ArgumentList
  │     ├─► interpreter.Execute(myCmd, args)
  │     ├─► Marshal Eagle result → Tcl result
  │     └─► Return TCL_OK / TCL_ERROR
  │
  │   ... eventually ...
  │
  tcl command delete $interp tclName
    │
    ├─► Tcl_DeleteCommandFromToken()    ──► "tclName" removed
    │                                        │
    │   CmdDeleteProc callback fired ◄──────┘
    │     │
    │     ├─► Remove bridge from registry
    │     └─► Free GCHandle
```

### 6.2 Thread Safety in Bridges

The `ObjCmdProc` callback is called from the native Tcl thread, which may
differ from the .NET thread that created the Eagle interpreter. The bridge
handles this via:

1. `BeginExternalExecution()` — marks the Eagle interpreter as being called
   from external (native) code, adjusting thread affinity checks.
2. `interpreter.Execute()` — invoked within this external execution context.
3. `EndAndCleanupExternalExecution()` — restores the previous execution state.

### 6.3 The Standard Bridge

When `tcl create` is called without `-nobridge`, a standard bridge is
automatically created. This bridge registers an `eagle` command in the Tcl
interpreter that can evaluate arbitrary Eagle scripts:

```tcl
# Inside the native Tcl interpreter:
eagle {expr {2 + 3}}                         ;# Returns "5"
eagle {clock seconds}                         ;# Returns current timestamp
eagle {object invoke System.IO.File Exists /tmp/test}  ;# .NET from Tcl!
```

This is the primary mechanism for Tcl code to access Eagle functionality
without Garuda. The standard bridge is simpler but less powerful than
Garuda's full bidirectional integration.

## 7. Tcl Library Discovery

Eagle includes a sophisticated library discovery system for finding
installed Tcl libraries across platforms.

### 7.1 Search Locations

The discovery system searches in platform-specific order:

**Windows:**
1. Windows Registry (`HKLM\SOFTWARE\ActiveTcl`, `Tcl` keys)
2. Common installation directories
3. The `PATH` environment variable
4. User-specified path (via `tcl load path` or `tcl find path`)

**Unix/macOS:**
1. Standard library directories (`/usr/lib`, `/usr/local/lib`, etc.)
2. The `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH` environment variable
3. User-specified path

### 7.2 File Pattern Matching

The library file is matched against platform-specific patterns:

- **Windows**: `tcl86.dll`, `tcl85.dll`, etc.
- **Linux**: `libtcl8.6.so`, `libtcl8.5.so`, etc.
- **macOS**: `libtcl8.6.dylib`, `Tcl.framework/Tcl`, etc.

The `-robustify` option excludes ActiveTcl "BaseKits" (single-file
distributions) that may not embed Tk correctly. On Windows, it also enables
`SetDllDirectory()` to help the Tcl DLL find its dependencies (like
`zlib1.dll`).

### 7.3 Version Filtering

Discovery results are filtered by version range. The defaults accept Tcl
8.4 through the latest available version. Use `-minimumversion` and
`-maximumversion` to constrain the range.

### 7.4 Build Metadata

Each discovered Tcl library is represented by a `TclBuild` object containing:

| Property | Description |
|----------|-------------|
| `fileName` | Full path to the library file |
| `patchLevel` | Tcl patch level (e.g., 8.6.13) |
| `releaseLevel` | Alpha, beta, or final |
| `threaded` | Whether the library was built with thread support |
| `debug` | Whether it's a debug build |
| `priority` | Selection priority |
| `sequence` | Discovery order |
| `operatingSystemId` | Target operating system |
| `magic` | Build magic number |

## 8. Thread Management

Eagle supports creating isolated Tcl worker threads via the `TclThread`
class. Each worker thread owns its own `Tcl_Interp*` and runs independently.

### 8.1 Thread Architecture

```
Main Thread (Eagle + primary Tcl interp)
  │
  ├─► TclThread 1
  │     ├─► Own System.Threading.Thread
  │     ├─► Own Tcl_Interp*
  │     ├─► Event queue (startEvent, doneEvent, idleEvent, queueEvent)
  │     └─► ResultCallback for cross-thread result delivery
  │
  ├─► TclThread 2
  │     ├─► Own System.Threading.Thread
  │     ├─► Own Tcl_Interp*
  │     └─► ...
  │
  └─► ...
```

### 8.2 Thread Lifecycle

1. **Creation**: `CreateTclThread()` spawns a new .NET thread, creates a
   Tcl interpreter on that thread, and waits for initialization.
2. **Queuing**: `tcl queue` posts scripts to the thread's event queue.
3. **Execution**: The worker thread's event loop processes queued scripts
   via `Tcl_DoOneEvent()`.
4. **Results**: Results are delivered back via a `ResultCallback` delegate.
5. **Deletion**: `DeleteTclThread()` signals the thread to finalize and
   waits for it to exit.

### 8.3 Thread Affinity

Tcl interpreters have strict thread affinity — they can only be used from
the thread that created them. Eagle's thread management respects this:

- The primary Tcl interpreter (from `tcl load` / `tcl create`) is bound to
  the thread that loaded the Tcl library.
- Worker thread interpreters are bound to their respective worker threads.
- `tcl ready interp` checks thread affinity as part of its validation.
- Cross-thread access must go through `tcl queue`.

## 9. Relationship with Garuda

Eagle's `[tcl]` command and the Garuda native package are complementary:

| Direction | Mechanism | Entry Point |
|-----------|-----------|-------------|
| Eagle → Tcl | `[tcl]` command | `tcl eval $interp { ... }` |
| Tcl → Eagle | Garuda package | `eagle { ... }` in Tcl |

### 9.1 How They Connect

When both are in use, the data flow looks like:

```
Eagle script
  │
  ├─► tcl eval $interp { eagle {object invoke ...} }
  │     │
  │     ├─► Tcl evaluates "eagle {object invoke ...}"
  │     │     │
  │     │     ├─► Standard bridge → ObjCmdProc
  │     │     │     │
  │     │     │     └─► Eagle evaluates "object invoke ..."
  │     │     │           │
  │     │     │           └─► .NET reflection call
  │     │     │
  │     │     └─► Result returned to Tcl
  │     │
  │     └─► Result returned to Eagle
```

### 9.2 The `loadGarudaForUseByEagle` Procedure

The `loadGarudaForUseByEagle` script library procedure (in `init.eagle`)
automates the full setup:

1. Loads the native Tcl library (`tcl load`).
2. Creates the standard command bridge.
3. Loads the Garuda native package into the Tcl interpreter.

This gives complete bidirectional integration in a single call.

## 10. Comparisons to Other Languages

### 10.1 vs. Python ctypes / cffi

Python's `ctypes` and `cffi` allow calling C functions from Python. Eagle's
`[tcl]` command is similar in spirit but more specialized — it targets
specifically the Tcl C API rather than arbitrary C libraries. However, the
underlying mechanism (dynamic loading + function pointer marshalling) is
analogous.

### 10.2 vs. Ruby FFI

Ruby's FFI gem provides foreign function interface capabilities. Eagle's
approach is comparable but tightly integrated with the Tcl ecosystem,
providing interpreter management, variable exchange, and command bridging
rather than raw function calls.

### 10.3 vs. Lua C API

Lua's C API is designed for embedding Lua in C programs. Eagle's `[tcl]`
inverts this relationship — it embeds a C runtime (Tcl) inside a managed
runtime (Eagle/.NET). Both support bidirectional function calls, but the
direction of embedding is reversed.

### 10.4 vs. Java JNI / JNA

Java's JNI and JNA provide native code access from the JVM. Eagle's
function pointer marshalling via `Marshal.GetDelegateForFunctionPointer()`
is closest to JNA's approach (dynamic binding without compile-time headers).

### 10.5 vs. Node.js N-API / node-ffi

Node.js addons and `node-ffi` allow JavaScript to call native code.
Eagle's `[tcl]` command is similar to `node-ffi` in that it loads shared
libraries dynamically, but it provides a much richer integration layer
(interpreter management, command bridging, thread management) rather than
raw function calls.

## 11. Practical Patterns

### 11.1 Basic Tcl Script Evaluation

```tcl
# Load Tcl and create an interpreter
tcl load
set interp [tcl create]

# Evaluate Tcl code
tcl eval $interp {
  proc greet {name} {
    return "Hello from Tcl, ${name}!"
  }
}
set greeting [tcl eval $interp {greet Eagle}]
puts $greeting  ;# "Hello from Tcl, Eagle!"

# Clean up
tcl delete $interp
```

### 11.2 Using Native Tcl Packages

```tcl
tcl load
set interp [tcl create]

# Load a native Tcl package (e.g., Tk, sqlite3, etc.)
tcl eval $interp {
  package require sqlite3
  sqlite3 db :memory:
  db eval {CREATE TABLE test (id INTEGER, name TEXT)}
  db eval {INSERT INTO test VALUES (1, "Eagle")}
  set result [db eval {SELECT name FROM test WHERE id = 1}]
}
set name [tcl eval $interp {set result}]
puts $name  ;# "Eagle"

tcl delete $interp
```

### 11.3 Variable Exchange

```tcl
tcl load
set interp [tcl create]

# Set variables in Tcl from Eagle
tcl set $interp myVar "Hello from Eagle"
tcl set $interp count 42

# Read variables in Eagle from Tcl
set val [tcl set $interp myVar]   ;# "Hello from Eagle"
set num [tcl set $interp count]   ;# "42"

# Unset a variable
tcl unset $interp myVar

tcl delete $interp
```

### 11.4 Command Bridging

```tcl
tcl load
set interp [tcl create]

# Create an Eagle procedure to bridge
proc eagleAdd {a b} {
  return [expr {$a + $b}]
}

# Bridge it into Tcl
tcl command create eagleAdd $interp tclAdd

# Call the Eagle procedure from Tcl
set result [tcl eval $interp {tclAdd 10 20}]
puts $result  ;# "30"

# Clean up
tcl command delete $interp tclAdd
tcl delete $interp
```

### 11.5 Safe Tcl Interpreter

```tcl
tcl load
set interp [tcl create -safe]

# The Tcl interpreter is sandboxed
# Dangerous commands (exec, file, socket, etc.) are hidden
tcl eval $interp {
  # This works:
  set x [expr {2 + 3}]
}

# This would fail:
# tcl eval $interp {exec ls}  ;# Error: invalid command name "exec"

tcl delete $interp
```

### 11.6 Discovery Without Loading

```tcl
# Check if Tcl is available
if {[tcl available]} then {
  puts "Tcl is available"
} else {
  puts "Tcl is not available"
}

# Find all Tcl installations
set builds [tcl find -full]
puts $builds

# Select the best one
set best [tcl select]
puts "Best Tcl: $best"
```

### 11.7 Accessing .NET from Tcl via the Standard Bridge

```tcl
tcl load
set interp [tcl create]

# The standard bridge gives Tcl an "eagle" command
tcl eval $interp {
  # Call .NET from Tcl through Eagle
  set now [eagle {object invoke System.DateTime Now}]
  set hostname [eagle {object invoke System.Environment MachineName}]
  puts "Time: $now on $hostname"
}

tcl delete $interp
```

## 12. Error Handling

### 12.1 Exception Propagation

By default, Tcl errors are returned as Eagle errors with `ReturnCode.Error`.
The `-exceptions` option controls whether Tcl errors should additionally be
propagated as .NET exceptions:

```tcl
# Default: Tcl errors become Eagle errors
catch {tcl eval $interp {error "Tcl error"}} msg
puts $msg  ;# "Tcl error"

# With -exceptions true: also throws .NET exception
tcl eval -exceptions true $interp {error "Tcl error"}
# This may raise a .NET exception depending on the interpreter configuration
```

### 12.2 The `tcl exceptions` Global Setting

The `tcl exceptions` sub-command controls the global default for exception
propagation. When set to `true`, all Tcl errors are propagated as .NET
exceptions unless overridden by a per-call `-exceptions false`.

### 12.3 Error Line Tracking

The `tcl errorline` sub-command provides access to Tcl's error line
tracking (TIP #336). After a Tcl evaluation error, `tcl errorline $interp`
returns the line number where the error occurred.

## 13. Security Considerations

### 13.1 Command Flags

The `[tcl]` command is marked `Unsafe` — it is not available in safe Eagle
interpreters. This is appropriate because:

- It loads native code (arbitrary shared libraries).
- It creates unsandboxed Tcl interpreters (unless `-safe` is used).
- It provides full access to the native Tcl C API.
- Command bridging exposes Eagle commands across a trust boundary.

### 13.2 Safe Tcl Interpreters

The `-safe` option on `tcl create` calls `Tcl_MakeSafe()`, which hides
dangerous Tcl commands (`exec`, `file`, `socket`, `load`, etc.). This
provides Tcl-side sandboxing, but the Eagle side remains unrestricted.

### 13.3 Trusted Library Loading

The `-trustedonly` option on `tcl load` restricts library loading to
trusted/signed locations. This prevents loading tampered Tcl libraries.

## 14. Quick Reference: Decision Guide

| Scenario | Approach |
|----------|----------|
| Load Tcl for first time | `tcl load` |
| Check Tcl availability | `tcl available` or `tcl ready` |
| Create Tcl interpreter | `set interp [tcl create]` |
| Create safe Tcl interpreter | `set interp [tcl create -safe]` |
| Evaluate Tcl script | `tcl eval $interp { script }` |
| Get/set Tcl variable | `tcl set $interp var ?value?` |
| Bridge Eagle command to Tcl | `tcl command create eagleCmd $interp tclName` |
| Access .NET from Tcl | Use standard bridge: `eagle { object invoke ... }` |
| Use native Tcl packages | `tcl eval $interp { package require pkg }` |
| Cancel long-running Tcl eval | `tcl cancel $interp` |
| Queue script to Tcl thread | `tcl queue $interp { script }` |
| Find Tcl installations | `tcl find ?-full?` |
| Select best Tcl installation | `tcl select` |
| Process Tcl events | `tcl update` |
| Full bidirectional setup | `loadGarudaForUseByEagle` |
| Clean up | `tcl delete $interp` then `tcl unload` |

## 15. References

### Eagle Source Files
- `Library/Commands/Tcl.cs` — Main command implementation (37 sub-commands)
- `Library/Components/Private/TclWrapper.cs` — P/Invoke wrappers and library loading
- `Library/Components/Private/TclApi.cs` — Managed API wrapper (49 function pointers)
- `Library/Components/Private/TclBridge.cs` — Bidirectional command bridging
- `Library/Components/Private/TclThread.cs` — Isolated Tcl worker threads
- `Library/Components/Private/TclDelegates.cs` — Native delegate declarations
- `Library/Components/Private/TclModule.cs` — Native module lifecycle
- `Library/Components/Private/TclBuild.cs` — Build discovery metadata
- `Library/Components/Private/TclStructs.cs` — Native struct definitions
- `Library/Components/Private/TclVars.cs` — Standard Tcl variable constants
- `Library/Interfaces/Private/TclApi.cs` — ITclApi interface
- `Library/Interfaces/Public/TclManager.cs` — ITclManager public interface
- `Library/Interfaces/Public/TclEntityManager.cs` — ITclEntityManager public interface

### Eagle Documentation
- [`core_language.md`](core_language.md#cmd-tcl) — `tcl` command syntax and sub-command reference
- [`core_examples.md`](core_examples.md#ex-tcl) — `tcl` usage examples
- [`garuda.md`](garuda.md) — Garuda native package (Tcl-to-Eagle direction)
- [`core_script_library.md`](core_script_library.md#initialization-initeagle) — `loadGarudaForUseByEagle` and related procedures

### External References
- [Tcl C API Reference](https://www.tcl-lang.org/man/tcl8.6/TclLib/contents.htm)
- [TIP #285 — Cancel Evaluation](http://tip.tcl.tk/285)
- [TIP #335 — Interpreter Activity](http://tip.tcl.tk/335)
- [TIP #336 — Error Line](http://tip.tcl.tk/336)
