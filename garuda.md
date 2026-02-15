# Eagle Native Package for Tcl (Garuda) -- Command and Architecture Reference

> **For AI agents**: This document covers the Garuda native Tcl package. For core Eagle command syntax, see [core_language.md](core_language.md). For worked examples, see [core_examples.md](core_examples.md). For script library procedures, see [core_script_library.md](core_script_library.md). For integration sub-projects, see [integrations.md](integrations.md).

This document provides a comprehensive reference for the Eagle Native Package
for Tcl, known as **Garuda**. It covers all sub-commands and their semantics,
the managed-side bridge architecture, the build system, platform support,
configuration, and the test infrastructure. This document is intended to be
used by AI agents and developers working with the Garuda codebase.

Copyright (c) 2007-2012 by Joe Mistachkin. All rights reserved.

Source files referenced:
- Native C implementation: `Eagle/Native/Package/src/generic/Garuda.c`
- CLR hosting (.NET Framework): `Eagle/Native/Package/src/generic/GarudaClr.c`
- CLR hosting (.NET Core): `Eagle/Native/Package/src/generic/GarudaCoreClr.c`
- Platform abstraction: `Eagle/Native/Package/src/generic/GarudaPal.c`
- String conversion: `Eagle/Native/Package/src/generic/GarudaStr.c`
- Managed bridge: `Eagle/Library/Components/Public/NativePackage.cs`
- Tcl package scripts: `Eagle/Native/Package/lib/`
- Outer tests: `Eagle/Library/Tests/package.eagle`
- Inner tests: `Eagle/Library/Tests/tcl-load.eagle`
- Tcl-side test runner: `Eagle/Native/Package/Tests/all.tcl`

---

## Table of Contents

1.  [Overview](#1-overview)
2.  [Architecture](#2-architecture)
    - 2.1 [High-Level Data Flow](#21-high-level-data-flow)
    - 2.2 [Component Diagram](#22-component-diagram)
3.  [Package Loading and Initialization](#3-package-loading-and-initialization)
    - 3.1 [Tcl Package Names](#31-tcl-package-names)
    - 3.2 [Package Loading Flow](#32-package-loading-flow)
    - 3.3 [Garuda_Init Entry Point](#33-garuda_init-entry-point)
    - 3.4 [Garuda_SafeInit Entry Point](#34-garuda_safeinit-entry-point)
    - 3.5 [Garuda_Unload and Cleanup](#35-garuda_unload-and-cleanup)
4.  [The garuda Ensemble Command](#4-the-garuda-ensemble-command)
    - 4.1 [garuda packageid](#41-garuda-packageid)
    - 4.2 [garuda clrrunning](#42-garuda-clrrunning)
    - 4.3 [garuda clrbridgerunning](#43-garuda-clrbridgerunning)
    - 4.4 [garuda clrversion](#44-garuda-clrversion)
    - 4.5 [garuda clrappdomainid](#45-garuda-clrappdomainid)
    - 4.6 [garuda clrload](#46-garuda-clrload)
    - 4.7 [garuda clrstart](#47-garuda-clrstart)
    - 4.8 [garuda clrstop](#48-garuda-clrstop)
    - 4.9 [garuda clrexecute](#49-garuda-clrexecute)
    - 4.10 [garuda startup](#410-garuda-startup)
    - 4.11 [garuda shutdown](#411-garuda-shutdown)
    - 4.12 [garuda control](#412-garuda-control)
    - 4.13 [garuda detach](#413-garuda-detach)
    - 4.14 [garuda dumpstate](#414-garuda-dumpstate)
5.  [The eagle Command (Tcl-to-Eagle Bridge)](#5-the-eagle-command-tcl-to-eagle-bridge)
6.  [Managed Side: NativePackage.cs](#6-managed-side-nativepackagecs)
    - 6.1 [Public Entry Points](#61-public-entry-points)
    - 6.2 [Protocol and Argument Passing](#62-protocol-and-argument-passing)
    - 6.3 [Eagle Interpreter Lifecycle](#63-eagle-interpreter-lifecycle)
    - 6.4 [TclBridge and Script Evaluation](#64-tclbridge-and-script-evaluation)
    - 6.5 [Control Operations](#65-control-operations)
    - 6.6 [Error Handling Patterns](#66-error-handling-patterns)
    - 6.7 [Thread Safety](#67-thread-safety)
7.  [Configuration Variables](#7-configuration-variables)
8.  [MethodFlags Enum](#8-methodflags-enum)
9.  [Key Data Structures](#9-key-data-structures)
    - 9.1 [ClrTclStubs](#91-clrtclstubs)
    - 9.2 [ClrMethodInfo](#92-clrmethodinfo)
    - 9.3 [ClrConfigInfo](#93-clrconfiginfo)
    - 9.4 [CoreClrFunctions](#94-coreclrfunctions)
10. [CLR Method Invocation Protocol](#10-clr-method-invocation-protocol)
11. [Build System](#11-build-system)
    - 11.1 [Two Build Variants](#111-two-build-variants)
    - 11.2 [Source File Organization](#112-source-file-organization)
    - 11.3 [Supported Platforms and Architectures](#113-supported-platforms-and-architectures)
    - 11.4 [Preprocessor Configuration](#114-preprocessor-configuration)
    - 11.5 [Build Tools](#115-build-tools)
12. [Platform Abstraction Layer](#12-platform-abstraction-layer)
    - 12.1 [Windows Types on POSIX](#121-windows-types-on-posix)
    - 12.2 [String and Unicode Handling](#122-string-and-unicode-handling)
    - 12.3 [Recursive Mutex Emulation](#123-recursive-mutex-emulation)
13. [Global State](#13-global-state)
14. [Thread Safety (Native)](#14-thread-safety-native)
15. [Error Handling (Native)](#15-error-handling-native)
16. [Memory Management](#16-memory-management)
17. [Test Infrastructure](#17-test-infrastructure)
    - 17.1 [Two-Layer Test Architecture](#171-two-layer-test-architecture)
    - 17.2 [Outer Tests: package.eagle](#172-outer-tests-packageeagle)
    - 17.3 [Inner Tests: tcl-load.eagle](#173-inner-tests-tcl-loadeagle)
    - 17.4 [Tcl-Side Test Runner: all.tcl](#174-tcl-side-test-runner-alltcl)
    - 17.5 [Garuda Binary Location Strategy](#175-garuda-binary-location-strategy)
    - 17.6 [Helper Procedures in tcl-load.eagle](#176-helper-procedures-in-tcl-loadeagle)
18. [Test Reference](#18-test-reference)
19. [Version and Package Metadata](#19-version-and-package-metadata)
20. [Directory Structure](#20-directory-structure)

---

## 1. Overview

**Garuda** (formerly "Eagle Package for Tcl") is a stubs-enabled native C
package/extension for Tcl that bridges Tcl applications to the .NET Common
Language Runtime (CLR). It provides any application embedding Tcl 8.4 or higher
with full access to the Eagle scripting engine (Extensible Adaptable
Generalized Logic Engine), which is a managed Tcl-like scripting language
written in C# that runs on .NET.

Garuda enables bidirectional communication between Tcl and Eagle:

- **Tcl to Eagle**: The `eagle` Tcl command (registered by Garuda) evaluates
  Eagle scripts within a managed Eagle interpreter.
- **Eagle to Tcl**: Eagle's `tcl` command family allows Eagle scripts to call
  back into native Tcl interpreters.

Garuda supports both the .NET Framework (v2.0 and v4.0) and .NET Core/.NET 5+
(via CoreCLR), and runs on Windows, Linux, and macOS.

---

## 2. Architecture

### 2.1 High-Level Data Flow

```
+---------------------+       +------------------------+       +---------------------+
|     Tcl Script      |       |   Garuda Native DLL    |       |   Eagle Managed     |
|                     |       |   (Garuda.c + CLR)     |       |   (NativePackage.cs)|
|                     |       |                        |       |                     |
|  [eagle <script>]  ----->  GarudaObjCmd dispatches  ----->  StartupClr/          |
|                     |       to bridge method         |       ControlClr/          |
|                     |       via CLR hosting API      |       ShutdownClr          |
|                     |       |                        |       |                     |
|  result <----------  <-----  return code + result   <-----  Eagle interpreter    |
|                     |       |                        |       evaluates script     |
|                     |       |                        |       |                     |
|  [garuda subcmd]   ----->  GarudaObjCmd switch      |       |                     |
|                     |       handles 14 sub-commands  |       |                     |
+---------------------+       +------------------------+       +---------------------+
```

### 2.2 Component Diagram

```
Native Layer (C)                    Managed Layer (C#)
================                    ==================

Garuda.c                            NativePackage.cs
  - Garuda_Init()                     - StartupClr()
  - Garuda_Unload()                   - ControlClr()
  - GarudaObjCmd()                    - DetachClr()
  - ExecuteClrMethod()                - ShutdownClr()
  |                                   |
  +-- GarudaClr.c (.NET Fx)           +-- TclBridge
  |     ICLRRuntimeHost               |     [eagle] cmd -> Eagle [eval]
  |     ExecuteInDefaultAppDomain     |
  |                                   +-- TclApi
  +-- GarudaCoreClr.c (.NET Core)     |     Wraps native Tcl C API
  |     hostfxr / nethost             |     via ClrTclStubs pointers
  |     load_assembly_and_get_fn_ptr  |
  |                                   +-- Interpreter
  +-- GarudaPal.c (POSIX)                  Eagle scripting engine
  |     dlopen/dlsym/dladdr
  |     pthread mutex wrapper
  |
  +-- GarudaStr.c (UTF conversion)
        UTF-8 <-> UTF-16 <-> UTF-32
```

---

## 3. Package Loading and Initialization

### 3.1 Tcl Package Names

Garuda registers five package names in `pkgIndex.tcl`:

| Package Name | Version | Behavior |
|---|---|---|
| `GarudaHelper` | 1.0 | Sources `helper.tcl` only; does not load the native extension |
| `dotnet` | 1.0 | Auto-detects runtime; does **not** start CLR or bridge by default |
| `Garuda` | 1.0 | Auto-detects runtime; starts CLR and bridge immediately |
| `GarudaDotNetFx` | 1.0 | Forces .NET Framework runtime; starts CLR and bridge |
| `GarudaDotNetCore` | 1.0 | Forces .NET Core runtime; starts CLR and bridge |

Usage:
```tcl
package require Garuda       ;# Full bridge startup
package require dotnet       ;# Load only, manual startup later
package require GarudaHelper ;# Helper scripts only
```

### 3.2 Package Loading Flow

1. `package require Garuda` triggers `pkgIndex.tcl` which sources `garuda.tcl`.
2. `garuda.tcl` sets `setupAndLoad = true` and sources `helper.tcl`.
3. `helper.tcl` (~90 KB) performs the main setup:
   - Detects the .NET runtime (Framework vs. Core) based on platform and
     configuration variables.
   - Locates the appropriate native binary (`Garuda.dll`, `GarudaCore.dll`,
     `libGarudaCore.so`, or `libGarudaCore.dylib`).
   - Sets configuration variables in the `::Garuda` namespace (assembly path,
     type name, method names, etc.).
   - Calls `[load <path> Garuda]` to load the native extension, which
     triggers `Garuda_Init`.

The `dotnet` package variant uses `dotnet.tcl` which sets `startClr = false`
and `startBridge = false` before sourcing `helper.tcl`, resulting in CLR
loading without bridge startup.

### 3.3 Garuda_Init Entry Point

`Garuda_Init` (Garuda.c) is the primary initialization function called by
Tcl's `[load]` command. It performs these steps:

1. Validates the Tcl interpreter and initializes Tcl stubs (private or
   standard).
2. Increments the atomic `lTclStubs` counter and acquires `packageMutex`.
3. Queries the package module file name via `GetPackageModuleFileName`.
4. Detects Tcl version and checks for TIP #285 (script cancellation),
   TIP #335, and TIP #336 support.
5. Populates the `ClrTclStubs` structure with 42 Tcl C API function
   pointers via `SetClrTclStubs`.
6. Reads configuration from Tcl variables via `GetClrConfigInfo`.
7. Obtains the Tcl library module handle (Windows: `TclWinGetTclInstance`;
   POSIX: `get_tcl_module_handle` using `dladdr`/`dlopen`).
8. Registers the `GarudaExitProc` exit handler.
9. Loads and optionally starts the CLR based on configuration
   (`bLoadClr`, `bStartClr`).
10. If configured (`bStartBridge`), executes the startup CLR method to
    establish the Eagle-Tcl bridge.
11. Creates the `garuda` Tcl command via `Tcl_CreateObjCommand`.
12. Provides four package names: `Garuda`, `dotnet`, `GarudaDotNetFx`,
    `GarudaDotNetCore` (all version 1.0).
13. On any failure, calls `Garuda_Unload` to clean up.

### 3.4 Garuda_SafeInit Entry Point

`Garuda_SafeInit` simply delegates to `Garuda_Init`. All safe interpreter
awareness is handled within the individual sub-commands -- those that are
unsafe check for safe interpreters and return "permission denied: safe interp".

### 3.5 Garuda_Unload and Cleanup

`Garuda_Unload` handles both per-interpreter detach and full process shutdown:

1. Checks that `lTclStubs` is initialized.
2. Reads configuration for CLR stop behavior (`bStopClr`).
3. Deletes the `garuda` command from the Tcl interpreter.
4. If the bridge is running, executes the detach method (per-interpreter)
   or shutdown method (process-wide).
5. On process-level shutdown, optionally stops and releases the CLR.
6. Clears the Tcl stubs table and frees the package file name.
7. Removes the exit handler and finalizes `packageMutex`.

Additional cleanup entry points:
- **`Garuda_SafeUnload`**: Delegates to `Garuda_Unload`.
- **`GarudaExitProc`**: Called during Tcl process exit; calls `Garuda_Unload`
  with `TCL_UNLOAD_DETACH_FROM_PROCESS`.
- **`GarudaObjCmdDeleteProc`**: Called when the `garuda` command is deleted
  (e.g., interpreter destruction); calls `Garuda_Unload` with
  `TCL_UNLOAD_FROM_CMD_DELETE | TCL_UNLOAD_DETACH_FROM_INTERPRETER`.

---

## 4. The garuda Ensemble Command

The package registers a single Tcl command named `garuda` with 14
sub-commands. The dispatch is implemented in the `GarudaObjCmd` function
in Garuda.c using `Tcl_GetIndexFromObj` and a `switch` statement. The
entire command handler holds the `packageMutex` lock.

### Sub-command Summary

| Sub-command | Safe Interp | Arguments | Description |
|---|---|---|---|
| `packageid` | Allowed | None | Returns package identification string |
| `clrrunning` | Allowed | None | Returns whether CLR is running (0/1) |
| `clrbridgerunning` | Allowed | None | Returns whether bridge is running (0/1) |
| `clrversion` | Allowed | None | Returns CLR version string |
| `clrappdomainid` | Allowed | None | Returns current AppDomain ID |
| `clrload` | **Forbidden** | None | Loads the CLR without starting it |
| `clrstart` | **Forbidden** | None | Starts a previously loaded CLR |
| `clrstop` | **Forbidden** | None | Stops the CLR (irreversible) |
| `clrexecute` | **Forbidden** | 4 required | Executes an arbitrary CLR method |
| `startup` | **Forbidden** | None | Starts the Eagle-Tcl bridge |
| `shutdown` | **Forbidden** | None | Shuts down the Eagle-Tcl bridge |
| `control` | **Forbidden** | 0+ optional | Issues a control directive to the bridge |
| `detach` | **Forbidden** | None | Detaches current Tcl interp from bridge |
| `dumpstate` | **Forbidden** | None | Returns internal debugging state |

### 4.1 garuda packageid

**Syntax**: `garuda packageid`

**Safe Interp**: Allowed

**Description**: Returns the package identification string containing the
package name, version, source control identifier, and source timestamp.

**Return Value**: String in the format:
```
Garuda 1.0 <sourceId> {<timestamp>}
```
Example: `Garuda 1.0 932a6f56ba76f8fd66376e6b7fad45541c19eaa1 {2026-01-17 03:33:52 UTC}`

**Error Conditions**: Wrong number of arguments.

### 4.2 garuda clrrunning

**Syntax**: `garuda clrrunning`

**Safe Interp**: Allowed

**Description**: Returns whether the CLR has been started in this process
by this package.

**Return Value**: Integer boolean (`0` or `1`).

**Error Conditions**: Out of memory creating result object.

### 4.3 garuda clrbridgerunning

**Syntax**: `garuda clrbridgerunning`

**Safe Interp**: Allowed

**Description**: Returns whether the bridge between Eagle and Tcl has been
started and is currently running.

**Return Value**: Integer boolean (`0` or `1`).

**Error Conditions**: Out of memory creating result object.

### 4.4 garuda clrversion

**Syntax**: `garuda clrversion`

**Safe Interp**: Allowed

**Description**: Queries version information for the loaded CLR.

For .NET Framework (CLR v4): calls `ICLRRuntimeInfo_GetVersionString`.
For .NET Framework (CLR v2): calls `GetCORVersion`.
For .NET Core: calls `hostfxr_get_dotnet_environment_info` (if
`HAVE_DOTNET_ENVIRONMENT_INFO` is defined).

**Return Value**: String containing the CLR version information. Examples:
- `.NET Framework v2`: `v2.0.50727`
- `.NET Framework v4`: `v4.0.30319`
- `.NET Core`: `version X.Y.Z commit_hash <hex>`

**Error Conditions**: CLR not loaded; version query HRESULT failure;
`E_NOTIMPL` if `HAVE_DOTNET_ENVIRONMENT_INFO` is unavailable.

### 4.5 garuda clrappdomainid

**Syntax**: `garuda clrappdomainid`

**Safe Interp**: Allowed

**Description**: Queries the integer identifier for the current CLR
application domain. For CoreCLR, always returns `1`. For .NET Framework,
calls `ICLRRuntimeHost_GetCurrentAppDomainId`.

**Return Value**: Integer AppDomain ID on success.

**Error Conditions**: CLR not loaded or not started; HRESULT failure.

### 4.6 garuda clrload

**Syntax**: `garuda clrload`

**Safe Interp**: Forbidden (returns "permission denied: safe interp").

**Description**: Loads the CLR into the current process without starting it.
For .NET Framework, this involves `CorBindToRuntimeEx` or
`CLRCreateInstance`/`ICLRMetaHost`. For CoreCLR, this calls
`get_hostfxr_path` and loads the hostfxr shared library.

**Return Value**: Empty string on success.

**Error Conditions**: Safe interpreter; configuration failure; CLR already
loaded (strict mode); hostfxr path failure; library load failure.

### 4.7 garuda clrstart

**Syntax**: `garuda clrstart`

**Safe Interp**: Forbidden.

**Description**: Starts the CLR, which must already be loaded via
`garuda clrload` or package initialization. For .NET Framework, calls
`ICLRRuntimeHost_Start`. For CoreCLR, initializes the runtime config
and obtains the `load_assembly_and_get_function_pointer` delegate.

**Return Value**: Empty string on success.

**Error Conditions**: Safe interpreter; configuration failure; CLR not
loaded; CLR already started (strict mode); runtime config init failure.

### 4.8 garuda clrstop

**Syntax**: `garuda clrstop`

**Safe Interp**: Forbidden.

**Description**: Stops the CLR within this process. This is an
**irreversible** operation -- the CLR cannot be restarted once stopped.
Sets the `EAGLE_CLR_STOPPING` environment variable during the stop
operation.

**Return Value**: Empty string on success.

**Error Conditions**: Safe interpreter; configuration failure; CLR not
loaded; CLR not started (strict mode); stop failure HRESULT.

### 4.9 garuda clrexecute

**Syntax**: `garuda clrexecute assemblyPath typeName methodName argument`

**Safe Interp**: Forbidden.

**Description**: Executes an arbitrary CLR method on-demand. The four
arguments specify the assembly path, fully qualified type name, method
name, and argument string. The method must conform to the
`static int MethodName(string argument)` signature (.NET Framework) or
the `component_entry_point_fn` signature (.NET Core).

Uses `METHOD_TYPE_DEMAND | METHOD_VIA_DEMAND` flags.

**Return Value**: Integer return value from the CLR method.

**Error Conditions**: Wrong number of arguments; safe interpreter;
configuration failure; CLR not loaded/started; method execution failure;
out of memory.

### 4.10 garuda startup

**Syntax**: `garuda startup`

**Safe Interp**: Forbidden.

**Description**: Starts the Eagle-Tcl bridge. Calls the configured
startup CLR method (typically `NativePackage.StartupClr`) via
`GetAndExecuteClrMethod` with `METHOD_TYPE_STARTUP | METHOD_VIA_COMMAND`
flags. On success, marks the bridge as started, enabling the `eagle`
command for script evaluation.

**Return Value**: Empty string on success.

**Error Conditions**: Safe interpreter; configuration failure; CLR not
loaded/started; method execution failure.

### 4.11 garuda shutdown

**Syntax**: `garuda shutdown`

**Safe Interp**: Forbidden.

**Description**: Shuts down the Eagle-Tcl bridge entirely. Calls the
configured shutdown CLR method (typically `NativePackage.ShutdownClr`)
via `GetAndExecuteClrMethod` with `METHOD_TYPE_SHUTDOWN | METHOD_VIA_COMMAND`
flags. On success, marks the bridge as no longer started.

**Return Value**: Empty string on success.

**Error Conditions**: Safe interpreter; configuration failure; CLR not
loaded/started; method execution failure.

### 4.12 garuda control

**Syntax**: `garuda control ?arg ...?`

**Safe Interp**: Forbidden.

**Description**: Issues a control directive to the bridge between Eagle
and Tcl. Zero or more optional arguments are concatenated into a Tcl list
and passed as the argument string to the configured control CLR method.
Uses `METHOD_TYPE_CONTROL | METHOD_VIA_COMMAND` flags.

Currently supports the `Require` control type, which calls
`interpreter.PkgRequire()` on the managed side.

**Return Value**: Empty string on success.

**Error Conditions**: Safe interpreter; configuration failure; CLR not
loaded/started; method execution failure.

### 4.13 garuda detach

**Syntax**: `garuda detach`

**Safe Interp**: Forbidden.

**Description**: Detaches the current Tcl interpreter from the Eagle
bridge. This makes the bridge "forget" about this specific Tcl
interpreter. Uses `METHOD_TYPE_DETACH | METHOD_VIA_COMMAND` flags.

In isolated mode, this disposes the entire Eagle interpreter associated
with the Tcl interpreter. In shared mode, this removes only the bridge
commands associated with the specific Tcl interpreter while preserving
the shared Eagle interpreter.

**Return Value**: Empty string on success.

**Error Conditions**: Safe interpreter; configuration failure; CLR not
loaded/started; method execution failure.

### 4.14 garuda dumpstate

**Syntax**: `garuda dumpstate`

**Safe Interp**: Forbidden (explicitly checked).

**Description**: Returns internal debugging information about the
package state, including: mutex address, package module handle, package
file name, Tcl stubs status, Tcl module handle, Tcl stubs pointer, CLR
runtime host pointer (or CoreCLR module/context/function pointers), CLR
started status, and bridge started status.

**Return Value**: A key-value formatted string of internal state. Example
fields include `packageMutex`, `hPackageModule`, `packageFileName`,
`lTclStubs`, `hTclModule`, `pTclStubs`, `bClrStarted`,
`bClrBridgeStarted`, and CLR-specific fields.

**Error Conditions**: Safe interpreter; pointer validation failure;
HRESULT failure from `DumpClrState`/`DumpCoreClrState`.

---

## 5. The eagle Command (Tcl-to-Eagle Bridge)

When the bridge is started (via `garuda startup` or automatic startup
during package loading), Garuda registers an additional Tcl command
named `eagle` in the Tcl interpreter. This command provides the primary
mechanism for evaluating Eagle scripts from Tcl.

**Syntax**: `eagle arg ?arg ...?`

**Description**: Evaluates the concatenated arguments in the Eagle interpreter
associated with the current Tcl interpreter (following standard Tcl `eval`
concatenation rules). The result of the Eagle evaluation is returned as the
Tcl result.

The `eagle` command is implemented via the `TclBridge` mechanism on the
managed side. When invoked, the native bridge callback fires, which
calls through to the Eagle `[eval]` command (`_Commands.Eval`) in the
managed Eagle interpreter. The evaluation result flows back through the
bridge to the Tcl interpreter.

**Bridge nesting**: The bridge supports multiple levels of nesting.
For example, from Tcl: `eagle tcl eval [eagle tcl primary] clock seconds`
performs Tcl -> Eagle -> Tcl (three-level crossing). Tests verify up to
four levels of nesting work correctly.

**Safe interpreter behavior**: In a safe Tcl interpreter, the `eagle`
command is available but enforces safety. Eagle scripts that attempt
unsafe operations (like `pwd`) are denied by the safe Eagle interpreter.

---

## 6. Managed Side: NativePackage.cs

The `NativePackage` class (`Eagle._Components.Public.NativePackage`) is
a `public static` class that serves as the managed-side gateway for the
Garuda native Tcl package. It is compiled at
`Eagle/Library/Components/Public/NativePackage.cs` (2654 lines).

### 6.1 Public Entry Points

#### Desktop .NET Framework Methods

These methods conform to the `static int MethodName(String argument)`
signature required by `ICLRRuntimeHost.ExecuteInDefaultAppDomain`:

| Method | Purpose |
|---|---|
| `StartupClr(string argument)` | Create/attach Eagle interpreter, establish bridge |
| `ControlClr(string argument)` | Issue control directives (e.g., package require) |
| `DetachClr(string argument)` | Detach a Tcl interpreter from the bridge |
| `ShutdownClr(string argument)` | Dispose all Eagle interpreters, full shutdown |

#### .NET Core Methods

These methods are compiled under `NET_STANDARD_20` and conform to the
CoreCLR `component_entry_point_fn` signature. Under `NET_CORE_50`, they
carry `[UnmanagedCallersOnly]` attributes:

| Method | Signature |
|---|---|
| `StartupCoreClr` | `int (IntPtr arg, int arg_size_in_bytes)` |
| `ControlCoreClr` | `int (IntPtr arg, int arg_size_in_bytes)` |
| `DetachCoreClr` | `int (IntPtr arg, int arg_size_in_bytes)` |
| `ShutdownCoreClr` | `int (IntPtr arg, int arg_size_in_bytes)` |

Each CoreCLR method marshals the `IntPtr` argument into a string (via
`MarshalArgument`) and delegates to the corresponding `*Clr` method.

### 6.2 Protocol and Argument Passing

The native Garuda DLL passes all information as a single string argument
encoded as a Tcl-formatted list. The `ParseArgument` method splits this
list and extracts:

**Protocol V1R0/V1R1** (minimum 4 arguments):
```
protocolId module interp safe [additional...]
```

**Protocol V1R2** (minimum 6 arguments):
```
protocolId module stubs interp isolated safe [additional...]
```

Where:
- `protocolId`: `"Garuda_v1.0"`, `"Garuda_v1.0_r1.0"`, or `"Garuda_v1.0_r2.0"`
- `module`: `IntPtr` -- native Tcl library DLL/shared-object handle
- `stubs`: `IntPtr` (V1R2 only) -- pointer to `ClrTclStubs` structure
- `interp`: `IntPtr` -- native `Tcl_Interp*` pointer
- `isolated`: `bool` (V1R2 only) -- whether Tcl interp gets own Eagle interp
- `safe`: `bool` -- whether the Tcl interpreter is "safe"

#### CoreCLR String Marshaling

On CoreCLR, the `MarshalArgument` method handles platform differences:
- **Windows**: Uses `Marshal.PtrToStringUni` (2-byte `wchar_t`)
- **Linux/macOS**: Uses `MarshalOps.PtrToStringUTF32` (4-byte `wchar_t`)

#### Return Value Convention

All entry-point methods return `int` (cast of `ReturnCode`: `Ok = 0`,
`Error = 1`). Since the CLR hosting API only supports an int return,
error details are reported via the `Complain` helper method to
console/trace output.

### 6.3 Eagle Interpreter Lifecycle

#### Creation (StartupClr)

1. The argument string is parsed to extract the Tcl interp pointer,
   module handle, safety/isolation flags.
2. In **isolated mode**, each Tcl interpreter gets a new, dedicated
   Eagle interpreter. In **shared mode**, all Tcl interpreters share
   a single "primary" Eagle interpreter (keyed by `IntPtr.Zero`).
3. If no suitable interpreter exists, one is created via
   `Interpreter.Create()` with computed flags:
   - `CreateFlags.NativeUse` as the base
   - `CreateFlags.SafeAndHideUnsafe` added if Tcl interp is safe
   - Startup options from defaults and optional arguments
4. A `TclApi` object is created wrapping the native Tcl library module
   handle and stubs pointer.
5. The Tcl interpreter is registered in the `tclInterps` dictionary
   with a generated name (e.g., `nativeParentInterp0`,
   `nativeSafeInterp1`).
6. A `TclBridge` is created linking the Tcl `eagle` command to the
   Eagle `eval` command.
7. The interpreter is stored in the static `interpreters` dictionary.

#### Detach (DetachClr)

- **Isolated mode**: Calls `DisposeInterpreter()` which disposes the
  Eagle interpreter and removes it from the static dictionary.
- **Shared mode**: Removes only the bridge commands associated with
  the specific Tcl interpreter. The shared Eagle interpreter is NOT
  disposed. Also unregisters the Tcl interp from tracking.

#### Shutdown (ShutdownClr)

- Calls `DisposeInterpreters()` which iterates over all Eagle
  interpreters, disposing each one.
- Clears and nulls out the `tclInterps` dictionary.

#### Ownership Tracking

The `StartupClr` method uses a `bool[] created` array (4 elements)
to track resource ownership during creation:
- `created[0]`: Eagle interpreter
- `created[1]`: TclApi object
- `created[2]`: TclBridge object
- `created[3]`: Tcl read-only flag

If the method fails, the `finally` block disposes still-owned resources
in reverse order, preventing resource leaks on partial failure.

### 6.4 TclBridge and Script Evaluation

The script evaluation path:

1. A Tcl script calls `[eagle <script>]`.
2. The `TclBridge` callback fires (native Tcl command procedure).
3. The `TclBridge` translates Tcl command arguments into Eagle
   arguments and invokes the `IExecute` interface of Eagle's `[eval]`
   command (looked up via `InternalGetIExecuteViaResolvers`).
4. The Eagle interpreter evaluates the script.
5. The result flows back through the bridge to the Tcl interpreter.

The bridge is bidirectional: since the Eagle interpreter has a `TclApi`
object wrapping the native Tcl library, Eagle scripts can call back
into Tcl through Eagle's `[tcl]` command family.

Safety is enforced: if the Tcl interpreter is safe, the Eagle
interpreter is also safe (or verified safe if reusing an existing one).

### 6.5 Control Operations

The `ControlClr` method supports a `PackageControlType` enum with at
least a `Require` case that calls `interpreter.PkgRequire()` to require
an Eagle package. The control type and arguments (package name, version)
are extracted from the remaining argument list.

### 6.6 Error Handling Patterns

1. **ReturnCode propagation**: Errors accumulate in `Result result`
   threaded through call chains via `ref` parameters.
2. **Complain on failure**: Since CLR hosting returns only `int`, error
   details go to `DebugOps.Complain()` (console/debug output).
3. **Try/finally with ownership tracking**: `StartupClr` uses
   `bool[] created` and a `finally` block for reverse-order cleanup.
4. **Per-interpreter exception isolation**: `DisposeInterpreters` wraps
   each disposal in try/catch to prevent cascade failures.
5. **Structured error messages**: Constants define templated errors
   (`ParseArgumentErrorV1R1`, `SafeUnsafeError`, etc.).
6. **Pervasive trace logging**: Every entry/exit and decision point
   is logged via `TraceOps.DebugTrace` with `TracePriority.NativeDebug`.

### 6.7 Thread Safety

- **Static lock object**: `private static readonly object syncRoot`
  protects access to the static `interpreters` and `tclInterps`
  dictionaries.
- **Active count tracking**: `Interlocked.Increment`/`Decrement` on
  `activeCount` at every public entry point. Used by
  `IsTclInterpreterActive()` to prevent premature disposal.
- **Lock Reform**: Outer locks around entire method bodies were removed
  to prevent deadlock. Locks are held only during modifications to
  the class's own static data.
- **TryLock pattern**: `FindTclInterpreterThreadId` uses non-blocking
  `Monitor.TryEnter` to avoid deadlock.
- **Per-interpreter Tcl sync root**: Tcl API access synchronized on
  `interpreter.TclSyncRoot`.

---

## 7. Configuration Variables

All configuration is read from Tcl variables in the `::Garuda` namespace.
These are set by the companion Tcl scripts (`helper.tcl`, `garuda.tcl`,
`dotnet.tcl`) before the native extension is loaded.

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `::Garuda::verbose` | Boolean | `false` | Enable extra diagnostic output |
| `::Garuda::logCommand` | String | `noLog` | Tcl command for logging |
| `::Garuda::noNormalize` | Boolean | `false` | Disable `[file normalize]` on assembly path |
| `::Garuda::runtimeConfigPath` | String | auto | Path to `.runtimeconfig.json` (CoreCLR) |
| `::Garuda::assemblyPath` | String | auto | Path to the managed assembly |
| `::Garuda::typeName` | String | auto | Fully qualified .NET type name |
| `::Garuda::startupMethodName` | String | auto | Method name for bridge startup |
| `::Garuda::controlMethodName` | String | auto | Method name for control directives |
| `::Garuda::detachMethodName` | String | auto | Method name for interpreter detach |
| `::Garuda::shutdownMethodName` | String | auto | Method name for bridge shutdown |
| `::Garuda::methodArguments` | String | empty | Extra arguments for CLR methods |
| `::Garuda::methodFlags` | Integer | `0` | Extra `MethodFlags` combined with per-call flags |
| `::Garuda::loadClr` | Boolean | `true` | Load CLR on package load |
| `::Garuda::startClr` | Boolean | varies | Start CLR on package load |
| `::Garuda::startBridge` | Boolean | varies | Start bridge on package load |
| `::Garuda::stopClr` | Boolean | `true` | Stop CLR when unloading from process |
| `::Garuda::useCoreClr` | Boolean | auto | Use CoreCLR instead of .NET Framework |
| `::Garuda::useMinimumClr` | Boolean | `false` | Force minimum supported CLR version |
| `::Garuda::useIsolation` | Boolean | `false` | Create isolated Eagle interpreter per Tcl interp |
| `::Garuda::useSafeInterp` | Boolean | `false` | Create "safe" Eagle interpreter |
| `::Garuda::setupAndLoad` | Boolean | `true` | Load the native extension during setup |

Notes:
- The `Garuda` package sets `startClr = true` and `startBridge = true`.
- The `dotnet` package sets `startClr = false` and `startBridge = false`.
- `useCoreClr` is auto-detected based on platform (always true on
  non-Windows; configurable on Windows).

---

## 8. MethodFlags Enum

Defined in `GarudaInt.h`, the `MethodFlags` enum controls how CLR
methods are invoked:

| Flag | Value | Description |
|---|---|---|
| `METHOD_NONE` | `0x0` | No flags |
| `METHOD_TYPE_DEMAND` | `0x1` | On-demand method execution |
| `METHOD_TYPE_STARTUP` | `0x2` | Bridge startup method |
| `METHOD_TYPE_CONTROL` | `0x4` | Bridge control directive |
| `METHOD_TYPE_DETACH` | `0x8` | Interpreter detach |
| `METHOD_TYPE_SHUTDOWN` | `0x10` | Bridge shutdown |
| `METHOD_TYPE_MASK` | `0x1F` | Mask for type values |
| `METHOD_PROTOCOL_V1R1` | `0x20` | Pass protocol ID, module handle, interp, safe flag |
| `METHOD_PROTOCOL_V1R2` | `0x40` | V1R1 + stubs pointer and isolation flag |
| `METHOD_LOG_EXECUTE` | `0x80` | Log method execution |
| `METHOD_STRICT_CLR` | `0x100` | Fail if CLR not started |
| `METHOD_STRICT_RETURN` | `0x200` | Fail if method return value is not `TCL_OK` |
| `METHOD_PROTOCOL_LEGACY` | `0x400` | Use legacy protocol version indicator |
| `METHOD_USE_ISOLATION` | `0x800` | Request isolated Eagle interpreter |
| `METHOD_USE_SAFE_INTERP` | `0x1000` | Request "safe" Eagle interpreter |

Standard combinations:

| Name | Composition |
|---|---|
| `METHOD_VIA_DEMAND` | `LOG_EXECUTE \| STRICT_CLR` |
| `METHOD_VIA_LOAD` | `PROTOCOL_V1R1 \| LOG_EXECUTE \| STRICT_CLR \| STRICT_RETURN \| PROTOCOL_LEGACY` |
| `METHOD_VIA_COMMAND` | `PROTOCOL_V1R1 \| LOG_EXECUTE \| STRICT_CLR \| STRICT_RETURN \| PROTOCOL_LEGACY` |
| `METHOD_VIA_UNLOAD` | `PROTOCOL_V1R1 \| LOG_EXECUTE \| STRICT_RETURN \| PROTOCOL_LEGACY` |

---

## 9. Key Data Structures

### 9.1 ClrTclStubs

Defined in `GarudaInt.h`, this structure contains 42 Tcl C API function
pointers that are passed to the managed bridge code so Eagle can call
back into the native Tcl library. The layout **must** match the managed
`NativeStubs` structure in `Eagle/Library/Components/Private/TclApi.cs`.

Key function pointers include:

| Category | Functions |
|---|---|
| Interpreter lifecycle | `Tcl_CreateInterp`, `Tcl_DeleteInterp`, `Tcl_Init`, `Tcl_MakeSafe` |
| Evaluation | `Tcl_EvalObjEx`, `Tcl_EvalFile`, `Tcl_ExprObj`, `Tcl_SubstObj`, `Tcl_CancelEval` |
| Object system | `Tcl_NewObj`, `Tcl_NewUnicodeObj`, `Tcl_NewStringObj`, `Tcl_NewByteArrayObj` |
| Variable access | `Tcl_ObjGetVar2`, `Tcl_ObjSetVar2`, `Tcl_UnsetVar2` |
| Command management | `Tcl_CreateObjCommand`, `Tcl_DeleteCommandFromToken` |
| Result handling | `Tcl_ResetResult`, `Tcl_GetObjResult`, `Tcl_SetObjResult` |
| Lifecycle | `Tcl_CreateExitHandler`, `Tcl_FinalizeThread`, `Tcl_Finalize` |

### 9.2 ClrMethodInfo

Contains the four strings needed to invoke a CLR method:
- `assemblyPath` (`LPCWSTR`) -- path to the managed assembly
- `typeName` (`LPCWSTR`) -- fully qualified .NET type name
- `methodName` (`LPCWSTR`) -- method name
- `argument` (`LPCWSTR`) -- argument string

### 9.3 ClrConfigInfo

Caches all configuration read from Tcl variables:
- Pointers to startup/control/detach/shutdown `ClrMethodInfo` structures
- All boolean and string configuration settings
- Computed from `::Garuda::*` variables via `GetClrConfigInfo`

### 9.4 CoreClrFunctions

Defined in `GarudaCoreClr.h`, a function pointer table for CoreCLR hosting:
- `pGetDotNetEnvInfo` -- `hostfxr_get_dotnet_environment_info`
- `pInitForRuntimeConfig` -- `hostfxr_initialize_for_runtime_config`
- `pGetRuntimeDelegate` -- `hostfxr_get_runtime_delegate`
- `pClose` -- `hostfxr_close`
- `pLoadAssemblyAndGetFuncPtr` -- `load_assembly_and_get_function_pointer`

---

## 10. CLR Method Invocation Protocol

When Garuda invokes a CLR method, it constructs a single wide-string
argument. The format depends on the protocol version and `MethodFlags`:

**Protocol V1R0 (legacy)**:
```
Garuda_v1.0 <hTclModule> <interp> <safe> <configArgs> <extraArgs>
```

**Protocol V1R1**:
```
Garuda_v1.0_r1.0 <hTclModule> <interp> <safe> <configArgs> <extraArgs>
```

**Protocol V1R2** (superset of V1R1):
```
Garuda_v1.0_r2.0 <hTclModule> <pTclStubs> <interp> <isolation> <safe> <configArgs> <extraArgs>
```

Where:
- `<hTclModule>` = hex pointer to the Tcl library module handle
- `<pTclStubs>` = hex pointer to the `ClrTclStubs` structure
- `<interp>` = hex pointer to the current Tcl interpreter
- `<safe>` = `0` or `1` for safe interpreter flag
- `<isolation>` = `0` or `1` for Eagle interpreter isolation flag
- `<configArgs>` = arguments from `::Garuda::methodArguments`
- `<extraArgs>` = additional arguments from the caller

#### .NET Framework Invocation

Uses `ICLRRuntimeHost_ExecuteInDefaultAppDomain` which takes the assembly
path, type name, method name, and a single wide string argument, returning
a DWORD.

#### .NET Core Invocation

Uses `load_assembly_and_get_function_pointer` which returns a
`component_entry_point_fn` that accepts `(const wchar_t*, int32_t)` where
the `int32_t` is the size in **bytes** (not code units) of the wide string.

---

## 11. Build System

### 11.1 Two Build Variants

The build system produces two distinct DLLs for the two .NET runtimes:

| Property | .NET Framework Build | .NET Core Build |
|---|---|---|
| Project File | `Garuda2022.vcxproj` | `GarudaNetStandard21.vcxproj` |
| Output Name | `Garuda.dll` | `GarudaCore.dll` (Windows) |
| Unix Output | N/A | `libGarudaCore.dylib` (macOS), `libGarudaCore.so` (Linux) |
| Module Def | `src/win/Garuda.def` | `src/win/GarudaCore.def` |
| Linked Library | `MSCorEE.lib` | `nethost.lib` |
| Compile Defines | `CLR_40` | `CORE_CLR; HAVE_DOTNET_ENVIRONMENT_INFO` |

Both variants export the same four functions:
```
Garuda_Init
Garuda_SafeInit
Garuda_Unload
Garuda_SafeUnload
```

The compile-time selection is handled by `GarudaPre.h`:
```c
#if defined(CORE_CLR)
#  define USE_CORE_CLR
#elif defined(CLR_40)
#  if defined(_MSC_VER) && _MSC_VER >= 1600
#    define USE_CLR_40
#  endif
#endif
```

### 11.2 Source File Organization

| File | Purpose |
|---|---|
| `src/generic/Garuda.c` | Main implementation: package init/unload, `garuda` command, CLR method execution |
| `src/generic/GarudaClr.c` | .NET Framework CLR hosting via COM interfaces |
| `src/generic/GarudaCoreClr.c` | .NET Core CLR hosting via hostfxr/nethost APIs |
| `src/generic/GarudaPal.c` | Platform Abstraction Layer (POSIX implementations) |
| `src/generic/GarudaStr.c` | UTF-8/UTF-16/UTF-32 string conversion wrappers |
| `src/external/generic/ConvertUTF_v2.c` | Unicode reference UTF conversion functions |
| `src/win/DllMain.c` | Windows DLL entry point |

### 11.3 Supported Platforms and Architectures

**Windows (Visual Studio)**:
- Visual Studio versions: 2003 through 2022
- Platform toolsets: v80 through v143
- Architectures: Win32 (x86), x64, ARM
- Configurations: DebugDll, ReleaseDll
- Base addresses: x86/ARM = `0x5F000000`, x64 = `0x5F00000000000000`
- Control Flow Guard (CFG) enabled

**Unix/macOS (GCC)**:
- macOS: arm64 and x86_64, produces `libGarudaCore.dylib`
- Linux: x86_64, produces `libGarudaCore.so`
- Only CoreCLR variant is built on Unix
- Links: `tclstub8.6`, `nethost`, `-ldl` (Linux)
- Build scripts: `Tools/compile-debug.sh`, `Tools/compile-release.sh`

### 11.4 Preprocessor Configuration

Common defines (from `Garuda.props`):
```
COMMON_DEFINES = _CRT_SECURE_NO_WARNINGS;WIN32_LEAN_AND_MEAN;COBJMACROS;
                 CINTERFACE;CLR_40
CORECLR_DEFINES = CORE_CLR;HAVE_DOTNET_ENVIRONMENT_INFO
TCL_DEFINES = TCL_THREADS;USE_TCL_STUBS
```

Unix GCC flags:
```
-fPIC -shared -Wl,-rpath,$dncdir
-DUSE_TCL_STUBS=1 -DTCL_THREADS=1 -DCORE_CLR=1 -DUSE_GARUDA_STR=1
```

### 11.5 Build Tools

| Tool/Script | Platform | Purpose |
|---|---|---|
| `Garuda2022.vcxproj` | Windows | Build `Garuda.dll` (.NET Framework) |
| `GarudaNetStandard21.vcxproj` | Windows | Build `GarudaCore.dll` (.NET Core) |
| `Tools/compile-debug.sh` | macOS/Linux | Build debug shared library (GCC) |
| `Tools/compile-release.sh` | macOS/Linux | Build release shared library (GCC) |
| `src/win/tea/makefile.vc` | Windows | TEA-based nmake build alternative |
| `Tools/bake.bat` | Windows | Inno Setup installer packaging |
| `Tools/release.bat` | Windows | Release preparation |
| `Tools/signViaBuild.bat` | Windows | Code signing post-build step |

---

## 12. Platform Abstraction Layer

### 12.1 Windows Types on POSIX

`GarudaPal.h` provides Windows-like type definitions for non-Windows
platforms: `BOOL`, `DWORD`, `HRESULT`, `HMODULE`, `LPWSTR`, `LPCWSTR`,
etc. It also provides:
- COM-style `HRESULT` macros: `SUCCEEDED`, `FAILED`,
  `HRESULT_FROM_WIN32`, `HRESULT_FROM_ERRNO`
- Interlocked operation macros using C11 `<stdatomic.h>`
- `S_OK`, `E_FAIL`, `E_NOTIMPL`, `E_OUTOFMEMORY` constants

### 12.2 String and Unicode Handling

`GarudaStr.h` and `GarudaStr.c` handle the critical difference that
`wchar_t` is 4 bytes (UTF-32) on POSIX but 2 bytes (UTF-16) on Windows,
while `Tcl_UniChar` is always 2 bytes (UTF-16) for Tcl 8.x.

On Windows, Tcl Unicode functions (`Tcl_NewUnicodeObj`, etc.) can be
called directly. On non-Windows, wrapper functions (`Cvt_NewUnicodeObj`,
`Cvt_GetUnicode`, etc.) perform UTF-32 to UTF-16 conversions using the
`ConvertUTF_v2` library.

For CoreCLR on POSIX, the `hostfxr` API uses `char*` (UTF-8) rather
than `wchar_t*`, requiring additional UTF-32-to-UTF-8 conversion
(`Cvt_pInitForRuntimeConfig`, `Cvt_pLoadAssemblyAndGetFuncPtr`).

### 12.3 Recursive Mutex Emulation

`GarudaPal.c` provides a recursive mutex wrapper for non-Windows
platforms because Tcl 8.x mutexes are not recursive. The
`pthread_owner_t` structure tracks ownership via `pthread_self()` and
a `recursionDepth` counter protected by a separate inner mutex. The
`Pal_MutexLock`/`Pal_MutexUnlock` functions implement recursive
locking semantics.

---

## 13. Global State

### Garuda.c (shared)

| Variable | Type | Purpose |
|---|---|---|
| `packageMutex` | `Tcl_Mutex` | Global lock protecting all static state |
| `packageOwner` | `pthread_owner_t` | Recursive mutex tracking (non-Windows + CoreCLR) |
| `packageFileName` | `LPWSTR` | Package DLL/shared library file path |
| `lTclStubs` | `volatile LONG` | Atomic flag: non-zero when Tcl stubs initialized |
| `hTclModule` | `volatile HMODULE` | Handle to the loaded Tcl shared library |
| `uTclStubs` | `ClrTclStubs` | Cached Tcl API function pointer table |
| `packageNames[]` | `const char*[]` | `{"Garuda", "dotnet", "GarudaDotNetFx", "GarudaDotNetCore", NULL}` |

### GarudaClr.c (.NET Framework)

| Variable | Type | Purpose |
|---|---|---|
| `pClrMetaHost` | `ICLRMetaHost*` | CLR v4 meta-host interface |
| `pClrRuntimeInfo` | `ICLRRuntimeInfo*` | CLR v4 runtime info interface |
| `pClrRuntimeHost` | `ICLRRuntimeHost*` | CLR runtime host (v2 or v4) |
| `bClrStarted` | `volatile BOOL` | Whether `ICLRRuntimeHost_Start` succeeded |
| `bClrBridgeStarted` | `volatile BOOL` | Whether the bridge is running |

### GarudaCoreClr.c (.NET Core)

| Variable | Type | Purpose |
|---|---|---|
| `pCoreClrModule` | `volatile HMODULE` | Handle to the hostfxr shared library |
| `uCoreClrFunctions` | `volatile CoreClrFunctions` | CoreCLR function pointer table |
| `pCoreClrContext` | `volatile hostfxr_handle` | CoreCLR runtime context handle |
| `bCoreClrBridgeStarted` | `volatile BOOL` | Whether the bridge is running |

### DllMain.c (Windows only)

| Variable | Type | Purpose |
|---|---|---|
| `hPackageModule` | `volatile HMODULE` | DLL instance handle from `DllMain` |
| `globalMutex` | `volatile HANDLE` | Named global mutex (`Global\Garuda_Setup`) |
| `mutex` | `volatile HANDLE` | Named local mutex (`Garuda_Setup`) |

---

## 14. Thread Safety (Native)

- All global state access is protected by `packageMutex`.
- On Windows with `TCL_THREADS`: standard `Tcl_MutexLock`/`Tcl_MutexUnlock`.
- On non-Windows with CoreCLR: custom recursive mutex wrapper
  (`Wrp_MutexLock`/`Wrp_MutexUnlock`) using `pthread_self()` and
  `recursionDepth`.
- `lTclStubs` is accessed atomically via `InterlockedIncrement`/
  `InterlockedCompareExchange` (native or POSIX atomic emulation).
- `GarudaObjCmd` acquires `packageMutex` for the entire duration of
  sub-command dispatch.
- On Windows, `DllMain.c` creates named mutexes (`Global\Garuda_Setup`
  and `Garuda_Setup`) to block concurrent installer operations during
  package setup.

---

## 15. Error Handling (Native)

1. **Standard Tcl result codes**: All public functions return `TCL_OK`
   or `TCL_ERROR`.
2. **HRESULT checking**: CLR/COM calls use `SUCCEEDED()`/`FAILED()`
   macros.
3. **Error messages**: Set via `Tcl_AppendResult`,
   `Tcl_AppendUnicodeToObj`, or `GetClrErrorMessage`/
   `GetTclErrorMessage`.
4. **Goto cleanup**: Nearly all functions use `goto done` / `goto
   cvt_exit` for cleanup before return.
5. **NULL pointer checks**: Every function validates all pointer
   arguments.
6. **Out-of-memory**: All `attemptckalloc` calls checked for NULL
   with explicit error messages.
7. **Strict mode**: `bStrict` parameter controls whether "already
   loaded"/"already started" is an error.
8. **PACKAGE_PANIC**: Debug builds call `Tcl_Panic`; release builds
   use `printf`.
9. **PACKAGE_TRACE**: Diagnostic output to debugger
   (`OutputDebugStringA`) or `stderr`.

---

## 16. Memory Management

- **Tcl memory API**: `attemptckalloc` for allocation, `ckfree` for
  deallocation.
- **Tcl_Obj reference counting**: Consistent use of
  `Tcl_IncrRefCount`/`Tcl_DecrRefCount`.
- **ClrMethodInfo**: Allocated via `attemptckalloc`, freed via
  `FreeClrMethodInfo` (frees each string field then the struct).
- **ClrConfigInfo**: Similarly via `GetClrConfigInfo`/`FreeClrConfigInfo`.
- **String values from variables**: `GetStringVariableValue` and
  `GetStringObjectValue` allocate copies; callers must free via `ckfree`.
- **Conversion contexts** (`Cvt_Context_*`): `cvt_ctx_cleanup` frees
  owned buffers and resets pointers.

---

## 17. Test Infrastructure

### 17.1 Two-Layer Test Architecture

The Garuda test suite uses a two-layer architecture for strong
process-level isolation:

**Layer 1: Outer tests** (`Eagle/Library/Tests/package.eagle`) --
Orchestrates test execution by spawning child processes and verifying
results via exit codes and sentry strings in a shared log file.

**Layer 2: Inner tests** (`Eagle/Library/Tests/tcl-load.eagle`) --
Contains the actual Garuda sub-command tests. These run inside child
processes spawned by the outer tests.

This separation ensures that Garuda's CLR hosting, bridge creation,
and Tcl integration are tested in isolated process contexts, preventing
test interference.

### 17.2 Outer Tests: package.eagle

#### garuda-1.1 -- Eagle Package for Tcl (Garuda) via Tcl

Runs the full Garuda test suite by launching a **native Tcl shell**
(`$test_tclsh`) as a child process, which sources the test runner
at `Native/Package/Tests/all.tcl`. That runner discovers and loads
the Garuda package, then runs `tcl-load.eagle`.

Steps:
1. Records a sentry string position in the log file.
2. Builds a pre-test script setting `DefaultQuiet`, test run IDs,
   and .NET Core configuration if needed.
3. Invokes `testExec` with the native Tcl shell.
4. Verifies the sentry string position advanced (inner tests ran).
5. Special macOS workaround: Apple tclsh segfault (exit code 139) is
   treated as success.

Constraints: `eagle dotNetOrDotNetCore native logFile tclShell compile.NATIVE compile.TCL compile.NATIVE_PACKAGE testExec file_pkgAll.tcl` + Garuda binary must exist.

#### garuda-1.2 -- Eagle Package for Tcl (Garuda) via Eagle

Runs `tcl-load.eagle` from within a **child Eagle process** via
`execTestShell`. This exercises the opposite direction of the bridge.

Steps:
1. Same sentry-string checking.
2. Pre-test script loads Tcl, defines `lprepend`, prepends Garuda DLL
   directory to `auto_path`, sets up logging.
3. Post-test script validates the exact count of passed tests using a
   25-constraint formula.
4. Invokes `execTestShell` pointing at `tcl-load.eagle`.

Constraints: `eagle dotNetOrDotNetCore native logFile garudaLibrary tclLibrary command.tcl compile.NATIVE compile.TCL compile.NATIVE_PACKAGE testExec`

### 17.3 Inner Tests: tcl-load.eagle

The core Garuda integration test file. It sources `prologue.eagle` and
`epilogue.eagle` for setup/teardown. Line 32 emits the critical sentry
`"---- running Tcl integration tests."`.

Tests are organized by feature area:

| Test ID | Description |
|---|---|
| `tclLoad-1.1` | Load and unload Tcl/Tk: loads Tcl, creates interp, loads Tk, runs event loop |
| `tclLoad-1.2` | Cannot unload Tcl while in-use: verifies error when Tcl library unload attempted during active evals |
| `tclLoad-2.1` | Leak test: single Tcl interp create/delete cycle |
| `tclLoad-2.2` | Leak test: 10 repeated Tcl interp create/delete cycles |
| `tclLoad-3.1` | TclThread: create, queue events, add/remove commands, delete |
| `tclLoad-3.2` | TclThread: cancel running script (requires TIP #285) |
| `tclLoad-3.3` | TclThread (generic): same as 3.1 with Generic creation flag |
| `tclLoad-3.4` | TclThread (generic): same as 3.2 with Generic creation flag |
| `tclLoad-4.1.1` | `garuda packageid` from Tcl |
| `tclLoad-4.1.2` | `garuda packageid` from Eagle |
| `tclLoad-5.1.1` | `garuda clrrunning` from Tcl |
| `tclLoad-5.1.2` | `garuda clrrunning` from Eagle |
| `tclLoad-6.1.1` | `garuda clrbridgerunning` from Tcl |
| `tclLoad-6.1.2` | `garuda clrbridgerunning` from Eagle |
| `tclLoad-7.1.1` | `garuda clrappdomainid` from Tcl |
| `tclLoad-7.1.2` | `garuda clrappdomainid` from Eagle |
| `tclLoad-8.1.1` | `garuda clrversion` from Tcl |
| `tclLoad-8.1.2` | `garuda clrversion` from Eagle |
| `tclLoad-9.1.1` | `garuda control` from Tcl |
| `tclLoad-9.1.2` | `garuda control` from Eagle |
| `tclLoad-10.1.1` | Tcl-to-Eagle: `eagle clock seconds` from Tcl |
| `tclLoad-10.1.2` | Tcl-to-Eagle: same from Eagle (roundtrip) |
| `tclLoad-10.1.3` | Triple bridge crossing: Tcl -> Eagle -> Tcl |
| `tclLoad-10.1.4` | Quadruple bridge crossing: Eagle -> Tcl -> Eagle -> Tcl |
| `tclLoad-11.1.1` | `garuda dumpstate` from Tcl |
| `tclLoad-11.1.2` | `garuda dumpstate` from Eagle |
| `tclLoad-12.1` | Safe interpreter: auto-start with SafeBase, security verification |
| `tclLoad-12.2` | Safe interpreter: sub-command permissions (allowed vs denied) |
| `tclLoad-13.1.1` | `garuda clrexecute` from Tcl (calls TestClrMethod/TestCoreClrMethod) |
| `tclLoad-13.1.2` | `garuda clrexecute` from Eagle |
| `tclLoad-14.1.1` | `haveEagle` helper procedure from Tcl |
| `tclLoad-14.1.2` | `haveEagle` helper procedure from Eagle |

### 17.4 Tcl-Side Test Runner: all.tcl

Located at `Eagle/Native/Package/Tests/all.tcl` (~1008 lines), this is
the Tcl-side test driver used by the `garuda-1.1` test:

1. Requires Tcl 8.4+ and rejects Eagle.
2. Defines shared procedures in `::Garuda` namespace (duplicated from
   `helper.tcl` because they are needed before the package loads).
3. Defines `findPackagePath` which searches environment variables,
   build directories, and deployment directories for the binary.
4. `setupTestVariables` initializes test configuration variables.
5. `runPackageTests` parses command-line arguments, locates the binary,
   adds it to `auto_path`, does `package require Garuda`, and sources
   the Eagle test suite entry point.

### 17.5 Garuda Binary Location Strategy

The binary location follows a multi-step search:

1. **`getGarudaDll` procedure** (in `test.eagle`): Uses `$::base_path`,
   test configuration, suffix, and machine architecture to construct a
   path under build output directories.
2. **`findPackagePath` procedure** (in `all.tcl`): Searches environment
   variables (`Garuda_Dll`, `Garuda`, `GarudaLkg`, `Lkg` with suffixes),
   then build output directories, then deployment directories.
3. **Constraint checking**: `checkForGarudaDll` calls `getGarudaDll`
   and verifies architecture match. `checkForGaruda` calls `haveGaruda`
   to verify `garuda packageid` succeeds.

### 17.6 Helper Procedures in tcl-load.eagle

Four helper procedures defined for the inner tests:

| Procedure | Purpose |
|---|---|
| `unloadForGarudaTest` | Unloads Garuda from Tcl interp; sets `::Garuda::stopClr false` to prevent CLR shutdown between tests |
| `getTypeAndMethodNamesForGarudaTest` | Returns type/method names for CLR method execution tests (differs for CoreCLR vs .NET Framework) |
| `isDotNetCoreForGarudaTest` | Detects .NET Core; can force-load GarudaHelper; checks `FORCE_DOTNET_CORE` env var |
| `shutdownForGarudaTest` | Calls `garuda shutdown` to shut down the bridge |

---

## 18. Test Reference

### Sub-command Test Coverage

Every Garuda sub-command is tested from **both Tcl and Eagle** perspectives
(paired `.1`/`.2` tests):

| Sub-command | Tests |
|---|---|
| `garuda packageid` | 4.1.1, 4.1.2, 12.2 |
| `garuda clrrunning` | 5.1.1, 5.1.2, 12.2 |
| `garuda clrbridgerunning` | 6.1.1, 6.1.2, 12.1, 12.2 |
| `garuda clrappdomainid` | 7.1.1, 7.1.2, 12.2 |
| `garuda clrversion` | 8.1.1, 8.1.2, 12.2 |
| `garuda control` | 9.1.1, 9.1.2, 12.2 |
| `garuda dumpstate` | 11.1.1, 11.1.2, 12.2 |
| `garuda clrexecute` | 13.1.1, 13.1.2, 12.2 |
| `garuda startup` | 12.1, 12.2, 14.x |
| `garuda shutdown` | 12.1, 12.2, 14.x |
| `garuda clrstart` | 12.2 (denied in safe interp) |
| `garuda clrstop` | 12.2 (denied in safe interp) |
| `garuda detach` | 12.2 (denied in safe interp) |
| `eagle` (command) | 10.1.1-10.1.4, 12.1 |
| `haveEagle` (proc) | 14.1.1, 14.1.2 |

### Safe Interpreter Security Tests

Test `tclLoad-12.2` verifies safe interpreter permissions:

| Sub-command | Expected |
|---|---|
| `garuda packageid` | Allowed |
| `garuda clrrunning` | Allowed |
| `garuda clrbridgerunning` | Allowed |
| `garuda clrversion` | Allowed |
| `garuda clrappdomainid` | Allowed |
| `garuda clrload` | **Denied** (permission denied: safe interp) |
| `garuda clrexecute` | **Denied** (permission denied: safe interp) |
| `garuda clrstart` | **Denied** (permission denied: safe interp) |
| `garuda clrstop` | **Denied** |
| `garuda dumpstate` | **Denied** |
| `garuda startup` | **Denied** |
| `garuda control` | **Denied** |
| `garuda detach` | **Denied** |
| `garuda shutdown` | **Denied** |

---

## 19. Version and Package Metadata

From `pkgVersion.h`:

| Constant | Value |
|---|---|
| `PACKAGE_NAME` | `"Garuda"` |
| `PACKAGE_NAME_1` | `"dotnet"` |
| `PACKAGE_NAME_2` | `"GarudaDotNetFx"` |
| `PACKAGE_NAME_3` | `"GarudaDotNetCore"` |
| `COMMAND_NAME` | `"garuda"` |
| `PACKAGE_VERSION` | `"1.0"` |
| `PACKAGE_PROTOCOL_V1R0` | `"v1.0"` |
| `PACKAGE_PROTOCOL_V1R1` | `"v1.0_r1.0"` |
| `PACKAGE_PROTOCOL_V1R2` | `"v1.0_r2.0"` |
| `PACKAGE_TCL_VERSION` | `"8.4"` |
| `SOURCE_ID` | `"932a6f56ba76f8fd66376e6b7fad45541c19eaa1"` |
| `SOURCE_TIMESTAMP` | `"2026-01-17 03:33:52 UTC"` |

From `rcVersion.h`:

| Constant | Value |
|---|---|
| `PACKAGE_PATCH_LEVEL` | `1.0.9526.19232` |
| `RC_VERSION` | `1,0,9526,19232` |

Windows resource metadata:
- **CompanyName**: "Eagle Development Team"
- **FileDescription**: "Eagle Package for Tcl 8.4+ (Garuda)"
- **LegalCopyright**: "Copyright (c) 2007-2012 by Joe Mistachkin.
  All rights reserved."
- **ProductName**: "Eagle"

---

## 20. Directory Structure

```
Eagle/Native/Package/
  +-- Garuda2022.vcxproj              (.NET Framework VS 2022 project)
  +-- GarudaNetStandard21.vcxproj     (.NET Core VS 2022 project)
  +-- README
  +-- props/
  |     +-- Garuda.props              (MSBuild property sheet)
  |     +-- Garuda.vsprops            (Legacy VS property sheet)
  +-- rc/
  |     +-- Garuda.rc                 (Windows resource file)
  +-- src/
  |     +-- generic/
  |     |     +-- Garuda.c            (Main implementation, ~87 KB)
  |     |     +-- Garuda.h            (Public API exports)
  |     |     +-- GarudaClr.c         (.NET Framework CLR hosting)
  |     |     +-- GarudaClr.h         (CLR version definitions)
  |     |     +-- GarudaCoreClr.c     (.NET Core CLR hosting)
  |     |     +-- GarudaCoreClr.h     (CoreCLR structures)
  |     |     +-- GarudaDecls.h       (Internal function declarations)
  |     |     +-- GarudaInt.h         (Internal types and enums)
  |     |     +-- GarudaPal.c         (Platform Abstraction Layer)
  |     |     +-- GarudaPal.h         (PAL types and macros)
  |     |     +-- GarudaPre.h         (Pre-include setup)
  |     |     +-- GarudaStr.c         (String conversion)
  |     |     +-- GarudaStr.h         (UTF conversion macros)
  |     |     +-- pkgVersion.h        (Version information)
  |     |     +-- rcVersion.h         (RC version)
  |     |     +-- stubs.h             (Tcl stubs compatibility)
  |     +-- external/
  |     |     +-- generic/
  |     |           +-- ConvertUTF_v2.c  (Unicode UTF conversions)
  |     |           +-- ConvertUTF_v2.h
  |     +-- win/
  |           +-- DllMain.c           (Windows DLL entry point)
  |           +-- Garuda.def          (.NET Framework exports)
  |           +-- GarudaCore.def      (.NET Core exports)
  |           +-- fakeSal.h           (SAL annotation stubs)
  |           +-- tea/                (TEA build files)
  +-- lib/
  |     +-- pkgIndex.tcl              (Package index)
  |     +-- garuda.tcl                (Primary loader)
  |     +-- dotnet.tcl                (Secondary loader, no auto-bridge)
  |     +-- helper.tcl                (Main helper script, ~90 KB)
  +-- Tcl/
  |     +-- include/                  (Tcl 8.6 headers)
  |     +-- lib/                      (Pre-compiled Tcl stub libraries)
  |           +-- Win32/tclstub86.lib
  |           +-- x64/tclstub86.lib
  |           +-- ARM/ (per-toolset)
  +-- Tools/
  |     +-- compile-debug.sh          (Unix/macOS debug build)
  |     +-- compile-release.sh        (Unix/macOS release build)
  |     +-- bake.bat                  (Inno Setup packaging)
  |     +-- release.bat               (Release preparation)
  |     +-- signViaBuild.bat          (Code signing)
  +-- Tests/
  |     +-- all.tcl                   (Tcl-side test runner)
  +-- Scripts/
  |     +-- ex_winForms.tcl           (WinForms example)
  +-- images/
        +-- logo.png                  (Package logo)

Eagle/Library/
  +-- Components/Public/
  |     +-- NativePackage.cs          (Managed bridge, 2654 lines)
  +-- Tests/
        +-- package.eagle             (Outer test orchestrator)
        +-- tcl-load.eagle            (Inner Garuda integration tests)
```
