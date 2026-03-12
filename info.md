# Eagle `info` Command — Deep-Dive Analysis

## 1. Executive Summary

The Eagle `info` command is the interpreter's primary introspection
mechanism, providing **85 sub-commands** for querying every aspect of the
runtime environment. Tcl's `info` offers roughly 25 sub-commands focused
on procedure, variable, and script introspection. Eagle extends this
dramatically with .NET/CLR integration, Windows-specific queries, database
connection tracking, plugin/module inspection, policy and security
introspection, culture/localization support, and detailed engine metadata.

Key differentiators from Tcl:

| Area | Tcl | Eagle |
|------|-----|-------|
| Sub-commands | ~25 | 85 |
| .NET integration | None | assembly, framework, runtime, appdomain, objects, delegates, bindertypes |
| Security introspection | None | policies, decision, administrator |
| Plugin system | `info loaded` (basic) | plugin, pluginflags, loaded, modules |
| Database | None | connections, transactions |
| Windows-specific | None | hwnd, windows, windowtext |
| Culture/i18n | None | culture, cultures |
| Engine metadata | `info patchlevel` | engine (9 attributes), setup, source |
| Process info | `info pid` (only) | pid, ppid, previouspid, ptid, tid, processors |
| Command typing | None | cmdtype, cmdcount (with usage data), ensembles |
| Procedure protection | None | Obfuscated procedure access blocked |

---

## 2. Why the Eagle `info` Command Differs from Tcl

Eagle's `info` command reflects the interpreter's deep .NET/CLR integration
and its role as an embeddable, security-aware scripting engine:

- **Reflection infrastructure** — `info assembly`, `info engine`, and
  `info identifier` use .NET reflection (`Assembly.FullName`,
  `FileVersionInfo`, assembly attributes) to expose metadata
- **Security model** — `info policies`, `info decision`, and safe
  interpreter sub-command filtering give scripts visibility into the
  interpreter's security posture
- **Plugin architecture** — `info plugin`, `info pluginflags`, `info loaded`,
  and `info modules` reflect Eagle's extensible plugin system
- **Embeddable runtime** — `info active`, `info interps`, `info appdomain`,
  and `info context` support multi-interpreter and multi-AppDomain scenarios
- **Platform awareness** — conditional compilation (`#if NATIVE`,
  `#if WINDOWS`, `#if DATA`, `#if SHELL`) enables platform-specific
  sub-commands without runtime overhead on other platforms

### Source files

| File | Role |
|------|------|
| `Commands/Info.cs` (~4,589 lines) | Command implementation: sub-command dispatch, option parsing, policy enforcement |
| `Components/Private/PolicyOps.cs` | `AllowedInfoSubCommandNames` — safe interpreter sub-command filtering |
| `Components/Private/GlobalState.cs` | System paths, active interpreters, process IDs |
| `Components/Private/RuntimeOps.cs` | Runtime introspection utilities |
| `Components/Public/Interpreter.cs` (~124,855 lines) | Introspection methods: `ListCommands`, `VariablesToList`, `ObjectsToString`, etc. |
| `Components/Public/ProcedureData.cs` | Procedure metadata: name, flags, arguments, body, location |
| `Components/Public/CommandData.cs` | Command metadata: name, flags, type, plugin association |

### Architecture note

The `info` command is implemented as a single large switch statement
dispatching on sub-command name (`Info.cs` lines 152–4564). The
developers acknowledge this design limitation in a TODO comment (lines
70–72), noting that a dictionary-of-delegates approach would be
preferable, but the current approach preserves ease of adding
compile-time conditionals (`#if` guards) per sub-command.

---

## 3. Sub-Command Reference

Eagle's 85 `info` sub-commands are organized below by functional category.
Sub-commands marked **(Eagle)** have no Tcl equivalent. Sub-commands
marked **(Enhanced)** extend Tcl's version with additional options or
behavior.

### 3.1 Procedure Introspection

#### `info args procName ?defaults?` **(Enhanced)**

Returns the argument list of procedure `procName`.

- With `defaults` set to true, includes default values using
  `NameAndDefault` formatting
- **Obfuscation protection**: returns an error if the procedure has
  `ProcedureFlags.Obfuscated` set

```tcl
proc greet {name {greeting Hello}} { puts "$greeting, $name" }
info args greet          ;# name greeting
info args greet true     ;# {name {}} {greeting Hello}
```

#### `info body procName ?showLines? ?useLocation?` **(Enhanced)**

Returns the body of procedure `procName`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `showLines` | `false` | Include line numbers in output |
| `useLocation` | `false` | Use script location for start line number |

- **Obfuscation protection**: returns an error if `ProcedureFlags.Obfuscated`
  is set
- Formatted via `FormatOps.ProcedureBody()`

```tcl
proc square {x} { expr {$x * $x} }
info body square             ;#  expr {$x * $x}
info body square true        ;# (with line numbers)
info body square true true   ;# (line numbers from script location)
```

#### `info default procName arg varName`

Returns `1` if argument `arg` of procedure `procName` has a default value,
`0` otherwise. If a default exists, it is stored in `varName`.

- **Obfuscation protection**: blocked for obfuscated procedures

```tcl
proc greet {name {greeting Hello}} { ... }
info default greet greeting defVal   ;# 1 (defVal = "Hello")
info default greet name defVal       ;# 0
```

#### `info procs ?pattern?`

Returns a list of procedures matching `pattern`. Excludes hidden
procedures and named-argument procedures from the listing.

```tcl
info procs           ;# All visible procedures
info procs greet*    ;# Procedures matching "greet*"
```

#### `info nprocs ?interp?` **(Eagle)**

Returns the number of procedures. With `interp`, queries a specific
interpreter.

```tcl
info nprocs   ;# 42
```

#### `info source ?refresh?` **(Eagle)**

Returns the source file location of the current script or the Eagle
library.

```tcl
info source   ;# /path/to/current/script.eagle
```

### 3.2 Variable Introspection

#### `info exists nameVarName ?valueVarName?` **(Enhanced)**

Returns `1` if the variable `nameVarName` exists, `0` otherwise.

Eagle extends Tcl's version with an optional `valueVarName`: if the
variable exists, its value is copied into `valueVarName` and `1` is
returned. This enables atomic check-and-read.

- Thread-safe: uses `lock (interpreter.InternalSyncRoot)`

```tcl
set x 42
info exists x           ;# 1
info exists nosuch       ;# 0

# Eagle extension: check-and-read
info exists x val        ;# 1 (val = "42")
info exists nosuch val   ;# 0 (val unchanged)
```

#### `info globals ?pattern?`

Returns a list of global variables matching `pattern`.

```tcl
info globals          ;# All global variables
info globals tcl_*    ;# Variables matching "tcl_*"
```

Implementation: `interpreter.VariablesToList(VariableFlags.GlobalOnly, ...)`

#### `info locals ?pattern?`

Returns a list of local variables in the current scope matching `pattern`.

```tcl
proc example {a b} {
    set c 3
    info locals   ;# a b c
}
```

#### `info vars ?options? ?pattern?` **(Enhanced)**

Returns all variables in the current scope matching `pattern`.

**Options:**

| Option | Description |
|--------|-------------|
| `-interpreter` | (Unsafe) Query a different interpreter's variables |

Eagle supports an `InterpreterFlags.InfoVarsMayHaveGlobal` flag that
causes `info vars` to include global variables merged with locals,
matching Tcl's behavior where `info vars` at the global level returns
globals.

```tcl
info vars           ;# All variables in current scope
info vars tcl_*     ;# Filtered by pattern
```

#### `info sysvars ?pattern?` **(Eagle)**

Returns a list of system variables (interpreter-internal variables)
matching `pattern`.

```tcl
info sysvars   ;# System-level variables
```

Implementation: `interpreter.VariablesToList(VariableFlags.System, ...)`

#### `info undefined ?pattern?` **(Eagle)**

Returns a list of variables that have been referenced but not yet
defined.

```tcl
info undefined   ;# Variables referenced but not set
```

#### `info varlinks ?pattern?` **(Eagle)**

Returns a list of linked variables (variable aliases created with
`upvar` or similar mechanisms) matching `pattern`.

```tcl
info varlinks   ;# All variable links
```

#### `info linkedname` **(Eagle)**

Returns the linked name of the interpreter (used in multi-interpreter
configurations).

### 3.3 Command Introspection

#### `info commands ?options? ?pattern?` **(Enhanced)**

Returns a list of commands matching criteria. This is the most
feature-rich sub-command, with extensive filtering options.

**Options:**

| Option | Description |
|--------|-------------|
| `-interpreter` | (Unsafe) Query a different interpreter |
| `-sdk type` | Filter by `SdkType`: Default, Initialize, License, Security, NonCritical |
| `-breakpoint` | Include breakpoint commands |
| `-core` | Include core commands |
| `-library` | Include library procedures |
| `-nocore` | Exclude core commands |
| `-nolibrary` | Exclude library procedures |
| `-interactive` | Include interactive procedures |
| `-nocommands` | Skip command listing |
| `-noprocedures` | Skip procedure listing |
| `-noexecutes` | Skip `IExecute` listing |
| `-noaliases` | Skip alias commands |
| `-safe` | Include safe commands |
| `-unsafe` | Include unsafe commands |
| `-standard` | Include standard commands |
| `-nonstandard` | Include non-standard commands |
| `-hidden` | Include hidden commands/procedures |
| `-hiddenonly` | Show only hidden items |
| `-strict` | Compatibility flag (Eagle Beta) |

**Security**: When querying a different interpreter via `-interpreter`,
the calling interpreter's safe status is checked (not the target's).
Safe interpreters cannot see hidden items.

```tcl
info commands              ;# All visible commands
info commands string*      ;# Commands matching "string*"
info commands -safe        ;# Only safe commands
info commands -hidden      ;# Include hidden commands
info commands -nocommands -library  ;# Only library procedures
```

#### `info cmdtype commandName` **(Eagle)**

Returns the type of `commandName` as one of: `proc`, `alias`, `object`,
`ensemble`, or `native`.

The implementation inspects the `IExecute` interface hierarchy:
- Checks for `IAlias` (unwraps `IWrapper` if needed)
- Checks for `ICommand` and inspects for ensemble sub-commands via
  `PolicyOps.GetSubCommandsUnsafe()`

```tcl
info cmdtype puts      ;# native
info cmdtype myProc    ;# proc
info cmdtype myAlias   ;# alias
info cmdtype string    ;# ensemble
```

#### `info cmdcount ?path? ?type?` **(Enhanced)**

Returns command execution counts. Eagle extends Tcl's simple counter
with detailed tracking via `CommandCountType` enum.

| Type | Description |
|------|-------------|
| `OperationCount` | Total operations executed |
| `CommandCount` | Named command invocations |
| `UnknownCount` | Unknown command invocations |

With `path`, queries a nested interpreter. With `type`, returns
specific count types or queries `IUsageData` interfaces for custom
usage tracking.

```tcl
info cmdcount                    ;# Simple count (Tcl-compatible)
info cmdcount {} OperationCount  ;# Specific counter type
```

#### `info complete script`

Returns `1` if `script` is syntactically complete (balanced braces,
quotes, brackets), `0` otherwise.

Implementation: `Parser.IsComplete()` with engine and substitution flags.

```tcl
info complete {set x [expr}   ;# 0 (unbalanced bracket)
info complete {set x 42}      ;# 1
```

#### `info subcommands ?options? name ?pattern?` **(Eagle)**

Returns the sub-commands of ensemble command `name`, optionally filtered
by `pattern`.

**Options:**

| Option | Description |
|--------|-------------|
| `-hidden` | Boolean controlling hidden command lookup |

Lookup behavior:
- `-hidden true`: looks up hidden commands only
- `-hidden false`: looks up regular commands only
- No `-hidden`: tries regular first, falls back to hidden in safe
  interpreters

```tcl
info subcommands string         ;# {compare first index is ...}
info subcommands string is*     ;# Sub-commands matching "is*"
```

#### `info syntax ?name?` **(Eagle)**

Without `name`, returns a list of all known syntax names. With `name`,
returns the syntax values for that specific syntax entry.

```tcl
info syntax              ;# All syntax names
info syntax "string is"  ;# Syntax for "string is"
```

Implementation: `SyntaxOps.GetNames()` / `SyntaxOps.GetValues()`

#### `info ensembles ?pattern?` **(Eagle)**

Returns a list of ensemble commands matching `pattern`.

```tcl
info ensembles   ;# {string file info clock ...}
```

### 3.4 Function and Operator Introspection

#### `info functions ?options? ?pattern?` **(Enhanced)**

Returns a list of expression functions matching criteria.

**Options:**

| Option | Description |
|--------|-------------|
| `-interpreter` | (Unsafe) Query a different interpreter |
| `-safe` | Include safe functions |
| `-unsafe` | Include unsafe functions |
| `-standard` | Include standard functions |
| `-nonstandard` | Include non-standard functions |
| `-hidden` | Include hidden functions |

Safe interpreters cannot see hidden functions.

```tcl
info functions          ;# All visible functions
info functions sin*     ;# Functions matching "sin*"
info functions -safe    ;# Only safe functions
```

#### `info operators ?options? ?pattern?` **(Enhanced)**

Returns a list of expression operators matching criteria.

**Options:**

| Option | Description |
|--------|-------------|
| `-interpreter` | (Unsafe) Query a different interpreter |
| `-standard` | Include standard operators |
| `-nonstandard` | Include non-standard operators |
| `-hidden` | Include hidden operators |

```tcl
info operators          ;# All visible operators
info operators -hidden  ;# Include hidden operators
```

#### `info operands name` **(Eagle)**

Returns the operands (arguments) of a function or operator. Tries as
a function first, then as an operator.

```tcl
info operands sin   ;# Argument info for sin()
info operands +     ;# Operand info for + operator
```

### 3.5 Call Stack Introspection

#### `info level`

Returns the current call level (depth of procedure nesting).

```tcl
proc inner {} { info level }
proc outer {} { inner }
outer   ;# 2 (two levels of procedure nesting)
```

#### `info levelid` **(Eagle)**

Returns the call frame ID for the current level, providing a unique
identifier for the execution frame.

```tcl
info levelid   ;# Unique frame identifier
```

#### `info frame`

**Not implemented.** This sub-command exists as a compatibility stub for
Tcl TIP #280 style stack frame introspection. Returns an error indicating
the feature is not supported.

### 3.6 Script and Interpreter Information

#### `info script ?new?`

Returns the name of the currently executing script file. With `new`,
sets the script name (bidirectional getter/setter).

```tcl
info script                ;# /path/to/current/script.eagle
info script newscript.eagle ;# Set script name
```

#### `info cmdline` **(Eagle)**

Returns the full command-line of the current process.

Implementation: `Environment.CommandLine`

```tcl
info cmdline   ;# "eagle.exe -script test.eagle arg1 arg2"
```

#### `info argv` **(Eagle, conditional: SHELL)**

Returns the saved shell arguments.

```tcl
info argv   ;# {arg1 arg2 arg3}
```

#### `info interactive` **(Eagle)**

Returns `1` if the interpreter is in interactive mode, `0` otherwise.

```tcl
info interactive   ;# 1 (in shell) or 0 (in script)
```

#### `info library ?pattern?` **(Enhanced)**

Returns library path information. Eagle extends this with complex
filtering options and pattern matching.

```tcl
info library   ;# /path/to/eagle/library
```

#### `info context` **(Eagle)**

Returns the current interpreter context information.

```tcl
info context   ;# Context details
```

#### `info lastinput ?new?` **(Eagle)**

Returns the last input string (bidirectional getter/setter). Useful for
interactive shell history.

```tcl
info lastinput         ;# Previous input
info lastinput "new"   ;# Set new input value
```

### 3.7 Environment and System Information

#### `info os ?refresh?` **(Eagle)**

Returns the operating system name and version.

- With `refresh` true, queries `PlatformOps.GetOSVersion()` directly
- Safe interpreters cannot refresh (returns cached platform variable)

```tcl
info os   ;# "Windows NT 10.0.22621.0" or "Unix 5.15.0.0"
```

#### `info hostname ?refresh?`

Returns the machine hostname.

- With `refresh` true, queries `Environment.MachineName`
- Safe interpreters cannot refresh

```tcl
info hostname   ;# "WORKSTATION01"
```

#### `info user` **(Eagle)**

Returns the current user name.

Implementation: `PlatformOps.GetUserName(true)`

```tcl
info user   ;# "jsmith"
```

#### `info administrator` **(Eagle, conditional: NATIVE)**

Returns `1` if the current process is running with administrator/root
privileges. Windows-only via native API check.

```tcl
info administrator   ;# 0 or 1
```

#### `info pid`

Returns the current process ID.

Implementation: `GlobalState.GetCurrentProcessId()`

```tcl
info pid   ;# 12345
```

#### `info ppid` **(Eagle, conditional: NATIVE)**

Returns the parent process ID.

Implementation: `NativeOps.GetParentProcessId()`

```tcl
info ppid   ;# 12340
```

#### `info previouspid ?reset? ?newId?` **(Eagle)**

Returns the process ID of the last process spawned by `[exec]`.
Supports optional reset and explicit ID setting.

| Parameter | Description |
|-----------|-------------|
| `reset` | Boolean — reset the tracking |
| `newId` | Long — set a new value explicitly |

Thread-safe via `lock (interpreter.InternalSyncRoot)`.

```tcl
exec echo hello
info previouspid       ;# PID of "echo" process
info previouspid true  ;# Reset tracking
```

#### `info processors` **(Eagle)**

Returns the number of logical processors.

**Security**: safe interpreters always report `1` to prevent
fingerprinting.

Implementation: `Environment.ProcessorCount`

```tcl
info processors   ;# 8 (or 1 in safe interpreter)
```

#### `info tid ?native?` **(Eagle)**

Returns thread identification.

| Argument | Returns |
|----------|---------|
| (none) | System thread ID |
| `true` | Native thread ID |
| `false` | Managed (.NET) thread ID |

```tcl
info tid         ;# System thread ID
info tid true    ;# Native thread ID
info tid false   ;# Managed thread ID
```

#### `info ptid` **(Eagle)**

Returns a combined process/thread ID pair.

```tcl
info ptid   ;# "12345.67890"
```

#### `info base` **(Eagle)**

Returns the base path of the Eagle installation.

Implementation: `GlobalState.GetBasePath()`

```tcl
info base   ;# /usr/local/lib/Eagle
```

#### `info binary ?forceDefault?` **(Eagle)**

Returns the path to the binary executable. AppDomain-aware: in
non-default AppDomains, returns the entry assembly path instead of
`BaseDirectory`.

```tcl
info binary   ;# /usr/local/bin/eagle.exe
```

#### `info nameofexecutable`

Returns the name of the main executable.

Implementation: `GlobalState.GetNameOfExecutable()`

```tcl
info nameofexecutable   ;# /usr/local/bin/eagle.exe
```

#### `info programextension` **(Eagle)**

Returns the file extension of the executable.

```tcl
info programextension   ;# .exe
```

#### `info sharedlibextension`

Returns the platform-appropriate shared library extension.

```tcl
info sharedlibextension   ;# .dll (Windows), .so (Linux), .dylib (macOS)
```

#### `info shelllibrary ?refresh?` **(Eagle, conditional: SHELL)**

Returns the shell library path information.

#### `info newline` **(Eagle)**

Returns the platform newline character(s).

Implementation: `Environment.NewLine`

```tcl
info newline   ;# \r\n (Windows) or \n (Unix)
```

#### `info whitespace` **(Eagle)**

Returns a string containing all recognized whitespace characters.

Implementation: `Characters.WhiteSpaceChars`

```tcl
info whitespace   ;# All whitespace characters
```

#### `info path`

Returns the library search path.

Implementation: `GlobalState.GetLibraryPath()`

```tcl
info path   ;# /usr/local/lib/Eagle/lib
```

#### `info externals` **(Eagle)**

Returns the externals path (location of external dependencies).

Implementation: `GlobalState.GetExternalsPath()`

```tcl
info externals   ;# /usr/local/lib/Eagle/externals
```

### 3.8 .NET/CLR Information

#### `info framework ?refresh?` **(Eagle)**

Returns the .NET Framework version. The deprecated alias `clr` is
still accepted for backward compatibility.

- With `refresh` true, queries `CommonOps.Runtime.GetFrameworkVersion()`
- Safe interpreters cannot refresh
- Returns cached platform variable when not refreshing

```tcl
info framework   ;# "4.0.30319.42000" or "6.0.11"
info clr          ;# Same (deprecated alias)
```

#### `info frameworkextra ?refresh?` **(Eagle, conditional: !NET_STANDARD_20)**

Returns extra .NET framework version information beyond the base version.

Implementation: `CommonOps.Runtime.GetFrameworkExtraVersion()`

```tcl
info frameworkextra   ;# Additional version details
```

#### `info runtime ?refresh?` **(Eagle)**

Returns the .NET runtime identifier.

```tcl
info runtime   ;# ".NET Framework" or ".NET" or "Mono"
```

#### `info runtimeversion ?refresh?` **(Eagle)**

Returns detailed .NET runtime version information with platform-specific
checks across multiple runtime environments.

```tcl
info runtimeversion   ;# Detailed runtime version string
```

#### `info appdomain` **(Eagle)**

Returns the current AppDomain ID.

Implementation: `AppDomainOps.GetId(interpreter)`

```tcl
info appdomain   ;# 1 (default AppDomain)
```

#### `info assembly ?entry?` **(Eagle)**

Returns assembly information as a list of `{FullName Location}`.

| Parameter | Description |
|-----------|-------------|
| (none) | Eagle core assembly |
| `true` | Entry assembly (host application) |

Uses .NET reflection: `Assembly.FullName`, `Assembly.Location`.

```tcl
info assembly        ;# {Eagle, Version=1.0... /path/to/Eagle.dll}
info assembly true   ;# Entry assembly info
```

### 3.9 Engine and Version Information

#### `info engine ?attribute? ?refresh? ?all?` **(Eagle)**

Returns Eagle engine metadata. This is the most detailed version
information sub-command, supporting 9 named attributes.

**Attributes** (via `EngineAttribute` enum):

| Attribute | Description |
|-----------|-------------|
| `Name` | Package name (`Vars.Package.Name`) |
| `Culture` | Assembly culture info |
| `Version` | Major.minor version |
| `PatchLevel` | Full assembly version |
| `Release` | Assembly release attribute |
| `SourceId` | Source control ID |
| `SourceTimeStamp` | Source timestamp |
| `StrongNameTag` | Strong name tag |
| `Configuration` | Build configuration (Debug/Release) |

| Parameter | Default | Description |
|-----------|---------|-------------|
| `attribute` | — | Specific attribute to query |
| `refresh` | `false` | Force refresh from assembly reflection |
| `all` | `false` | Return all attributes |

**Security**: safe interpreters cannot use `refresh`.

```tcl
info engine                       ;# Default engine info
info engine PatchLevel            ;# "1.0.9999.12345"
info engine Configuration         ;# "Release"
info engine Name false true       ;# All attributes as dictionary
```

#### `info patchlevel ?refresh?`

Returns the Eagle patch level (full version string).

```tcl
info patchlevel   ;# "1.0.9999.12345"
```

#### `info tclversion ?refresh?`

Returns the emulated Tcl version. Eagle reports `"8.4"` as its Tcl
compatibility level.

```tcl
info tclversion   ;# "8.4"
```

#### `info setup` **(Eagle, conditional: !NET_STANDARD_20)**

Returns setup/installation configuration information.

```tcl
info setup   ;# Setup configuration details
```

### 3.10 Object, Type, and Delegate Introspection

#### `info objects ?pattern?` **(Eagle)**

Returns a list of .NET objects currently registered in the interpreter's
object table.

```tcl
info objects          ;# All registered objects
info objects System*  ;# Objects matching "System*"
```

Implementation: `interpreter.ObjectsToString(pattern, false)`

#### `info delegates ?pattern?` **(Eagle, conditional: EMIT && NATIVE && LIBRARY)**

Returns a list of dynamically created delegates (from `library declare`
or Reflection.Emit operations).

```tcl
info delegates   ;# All dynamic delegates
```

#### `info bindertypes ?pattern?` **(Eagle)**

Returns a list of types that the script binder can marshal strings to.
Requires the interpreter to have an `IScriptBinder` with
`HasChangeTypes()` capability.

Thread-safe: locked access to interpreter sync root.

```tcl
info bindertypes          ;# All bindable types
info bindertypes System*  ;# Filtered by pattern
```

#### `info callbacks ?pattern?` **(Eagle)**

Returns a list of registered interpreter callbacks matching `pattern`.

```tcl
info callbacks   ;# All registered callbacks
```

Implementation: `interpreter.CallbacksToString(pattern, false)`

### 3.11 Channel and Database Introspection

#### `info channels ?pattern?`

Returns a list of open I/O channels matching `pattern`.

```tcl
info channels        ;# {stdin stdout stderr ...}
info channels file*  ;# Channels matching "file*"
```

#### `info connections ?pattern?` **(Eagle, conditional: DATA)**

Returns a list of open database connections matching `pattern`.

```tcl
info connections   ;# All database connections
```

Implementation: `interpreter.DbConnectionsToString(pattern, false)`

#### `info transactions ?pattern?` **(Eagle, conditional: DATA)**

Returns a list of active database transactions matching `pattern`.

```tcl
info transactions   ;# All active transactions
```

Implementation: `interpreter.DbTransactionsToString(pattern, false)`

### 3.12 Interpreter and Plugin Management

#### `info active ?pattern?` **(Eagle)**

Returns a list of active interpreters matching `pattern`.

Implementation: `GlobalState.ActiveInterpretersToString(pattern, false)`
— this method is thread-safe.

```tcl
info active   ;# All active interpreters
```

#### `info interps ?pattern?`

Returns a list of existing interpreters matching `pattern`.

```tcl
info interps   ;# All interpreters
```

#### `info loaded ?package? ?interp?` **(Enhanced)**

Returns a list of loaded packages/plugins. With `package`, queries a
specific package. With `interp`, queries a specific interpreter.

```tcl
info loaded           ;# All loaded packages
info loaded MyPkg     ;# Specific package info
```

#### `info modules ?pattern?` **(Eagle, conditional: EMIT && NATIVE && LIBRARY)**

Returns a list of loaded modules (dynamically emitted assemblies).

```tcl
info modules   ;# All loaded modules
```

#### `info plugin name ?subName?` **(Eagle)**

Returns detailed information about a loaded plugin.

```tcl
info plugin MyPlugin       ;# Plugin information
info plugin MyPlugin ver   ;# Specific plugin attribute
```

#### `info pluginflags ?pattern?` **(Eagle)**

Returns plugin flags for plugins matching `pattern`.

```tcl
info pluginflags   ;# All plugin flags
```

### 3.13 Security and Policy Introspection

#### `info policies ?pattern?` **(Eagle)**

Returns a list of registered security policies matching `pattern`.

```tcl
info policies   ;# All registered policies
```

Implementation: `interpreter.PoliciesToString(pattern, false)`

#### `info decision ?types?` **(Eagle)**

Returns policy decision information, optionally filtered by
`PolicyDecisionType` enum.

```tcl
info decision                    ;# All policy decisions
info decision SecurityDecision   ;# Specific decision type
```

Implementation: `PolicyOps.QueryDecisions()`

### 3.14 Culture and Localization

#### `info culture ?name?` **(Eagle)**

Gets or sets the current culture. Bidirectional: without argument
returns the current culture; with argument, sets it.

Supports the string `"null"` to represent a null culture via opaque
object handle.

```tcl
info culture           ;# "en-US"
info culture "fr-FR"   ;# Set to French
info culture "null"    ;# Set to null culture
```

Implementation: `CultureInfo` constructor with exception handling.

#### `info cultures ?pattern?` **(Eagle)**

Returns a list of all available cultures matching `pattern`.

Implementation: `CultureInfo.GetCultures()`

```tcl
info cultures       ;# All available cultures
info cultures en-*  ;# English variants
```

### 3.15 Identifier and Metadata

#### `info identifier name ?kind? ?full?` **(Eagle)**

Returns information about a named identifier (command, function,
operator, etc.).

| Parameter | Default | Description |
|-----------|---------|-------------|
| `name` | — | Identifier name |
| `kind` | `Command` | `IdentifierKind` enum |
| `full` | `false` | Return complete metadata dictionary |

Full output includes: type, kind, id, name, group, description, plugin,
version, release, sourceid, sourcetimestamp, strongnametag, configuration.

```tcl
info identifier puts                    ;# Basic info
info identifier puts Command true       ;# Full metadata dictionary
info identifier sin Function true       ;# Function metadata
```

### 3.16 Windows-Specific

#### `info hwnd handle` **(Eagle, conditional: NATIVE && WINDOWS)**

Returns window information for a window handle as a list:
`{hWnd processId threadId}`.

Platform-aware: handles both 32-bit and 64-bit pointer sizes
(`IntPtr.Size == sizeof(long)`).

```tcl
info hwnd 0x001A02B4   ;# {hWnd processId threadId}
```

#### `info windows ?full? ?pattern?` **(Eagle, conditional: NATIVE && WINDOWS)**

Enumerates windows, optionally filtered by class name or window text.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `full` | `false` | Include full info vs. handle only |
| `pattern` | — | Filter by class name or text |

Implementation: `WindowOps.WindowEnumerator`

```tcl
info windows               ;# All window handles
info windows true          ;# Full window info
info windows true *Eagle*  ;# Windows matching "Eagle"
```

#### `info windowtext handle` **(Eagle, conditional: NATIVE && WINDOWS)**

Returns the title/text of a window by handle.

```tcl
info windowtext 0x001A02B4   ;# "Eagle Interactive Shell"
```

---

## 4. Safe Interpreter Sub-Command Filtering

The `info` command uses `PolicyOps.AllowedInfoSubCommandNames` to
restrict which sub-commands are available in safe interpreters. The
command is marked with `CommandFlags.Unsafe | CommandFlags.Standard`,
and implements `IPolicyEnsemble` for fine-grained sub-command control.

### Allowed in safe interpreters

The following sub-commands are permitted in safe interpreters:

`appdomain`, `args`, `body`, `commands`, `complete`, `context`,
`default`, `engine`, `ensembles`, `exists`, `functions`, `globals`,
`level`, `library`, `locals`, `nprocs`, `objects`, `operands`,
`operators`, `patchlevel`, `procs`, `script`, `subcommands`,
`tclversion`, `vars`

### Blocked in safe interpreters

All other sub-commands are blocked, including:

- **System information**: `os`, `hostname`, `user`, `pid`, `ppid`,
  `processors`, `tid`, `binary`, `path`, `cmdline`, `administrator`
- **Security/policy**: `policies`, `decision`
- **.NET details**: `assembly`, `framework`, `runtime`, `appdomain` (allowed
  but with restricted refresh)
- **Database**: `connections`, `transactions`
- **Windows**: `hwnd`, `windows`, `windowtext`
- **Plugin internals**: `plugin`, `pluginflags`, `modules`

### Refresh restrictions

Even for allowed sub-commands that support a `refresh` parameter
(`engine`, `patchlevel`, `tclversion`), safe interpreters are blocked
from refreshing. They receive cached platform variable values instead,
preventing safe interpreters from triggering reflection operations.

### Hidden item visibility

The security model uses the **calling interpreter's** safe status to
determine visibility of hidden items, not the target interpreter's.
This prevents a safe interpreter from using `-interpreter` to inspect
a parent interpreter's hidden commands:

```
listHidden = hidden && !interpreter.InternalIsSafe()
```

### Processor count masking

`info processors` always returns `1` in safe interpreters to prevent
system fingerprinting.

---

## 5. Obfuscated Procedure Protection

Eagle supports procedure obfuscation via `ProcedureFlags.Obfuscated`.
When this flag is set, the `info` command blocks access to sensitive
procedure internals:

| Sub-command | Blocked behavior |
|-------------|-----------------|
| `info args` | Returns error: "procedure {name} arguments are unavailable" |
| `info body` | Returns error: "procedure {name} body is unavailable" |
| `info default` | Returns error (cannot inspect argument defaults) |

This mechanism protects intellectual property in distributed Eagle
scripts, preventing introspection of procedures that have been
explicitly marked as obfuscated.

---

## 6. .NET Reflection Integration

The `info` command uses .NET reflection extensively for engine and
assembly introspection:

### Assembly metadata

`info assembly` accesses:
- `Assembly.FullName` — fully qualified assembly name
- `Assembly.Location` — filesystem path to the assembly

Entry assembly vs. Eagle assembly selection:
- `GlobalState.GetAssembly()` — Eagle core assembly
- `GlobalState.GetEntryAssembly()` — host application assembly

### Engine attributes

`info engine` uses multiple reflection APIs:
- `AttributeOps.GetAssemblyConfiguration()` — Debug/Release
- `SharedAttributeOps.GetAssemblyRelease()` — release string
- `SharedAttributeOps.GetAssemblySourceId()` — source control ID
- `SharedAttributeOps.GetAssemblySourceTimeStamp()` — build timestamp
- `SharedAttributeOps.GetAssemblyStrongNameTag()` — strong name tag

### Identifier resolution

`info identifier` queries interfaces:
- `IIdentifier` — base metadata (name, group, description)
- `ISyntax` — syntax information
- `IPlugin` — plugin association and metadata

### Command type inspection

`info cmdtype` inspects the interface hierarchy:
- `IExecute` — base execution interface
- `IAlias` → `IWrapper` — alias with target unwrapping
- `ICommand` → `PolicyOps.GetSubCommandsUnsafe()` — ensemble detection

---

## 7. Thread Safety and Caching

### Synchronized access

Several `info` sub-commands require thread-safe access to interpreter
state:

- `info exists` with `valueVarName` — `lock (interpreter.InternalSyncRoot)`
- `info bindertypes` — locked access to script binder
- `info previouspid` — locked access to process tracking
- `info vars` — frame-level locking marked with `TRANSACTIONAL` comment

### Platform variable caching

Many sub-commands implement a lazy caching pattern:

1. Check `interpreter.HavePlatformVariables()` — are values cached?
2. If not cached and `refresh` requested (and not safe interpreter):
   query the actual system value
3. Otherwise: return the cached platform variable via
   `interpreter.GetVariableValue2()`

This pattern appears in: `framework`, `frameworkextra`, `hostname`, `os`,
`patchlevel`, `runtime`, `runtimeversion`, `tclversion`.

The caching reduces overhead for frequently-queried values and provides
a security boundary — safe interpreters always receive cached values
and cannot trigger system queries.

---

## 8. Conditional Compilation

The `info` command uses preprocessor symbols to include platform-specific
sub-commands only when the build supports them:

| Symbol | Sub-commands enabled |
|--------|---------------------|
| `NATIVE` | administrator, ppid, hwnd, windows, windowtext |
| `WINDOWS` | hwnd, windows, windowtext |
| `SHELL` | argv, shelllibrary |
| `DATA` | connections, transactions |
| `EMIT && NATIVE && LIBRARY` | delegates, modules |
| `!NET_STANDARD_20` | setup, frameworkextra |

This ensures no runtime overhead for features not supported by the
current platform build.

---

## 9. Practical Patterns

### Pattern 1 — Procedure introspection

```tcl
# List all procedures and inspect one
set procs [info procs my*]
foreach p $procs {
    puts "Proc: $p"
    puts "  Args: [info args $p]"
    puts "  Type: [info cmdtype $p]"
}
```

### Pattern 2 — Variable existence check-and-read

```tcl
# Eagle extension: atomic check and read
if {[info exists myVar val]} {
    puts "myVar = $val"
} else {
    puts "myVar not set"
}
```

### Pattern 3 — Command type dispatch

```tcl
# Handle commands differently by type
switch [info cmdtype $cmd] {
    proc      { puts "Procedure: [info body $cmd]" }
    alias     { puts "Alias command" }
    ensemble  { puts "Ensemble: [info subcommands $cmd]" }
    native    { puts "Built-in command" }
}
```

### Pattern 4 — Platform-adaptive scripting

```tcl
# Adapt behavior based on runtime environment
set os [info os]
set framework [info framework]
set isAdmin [expr {[catch {info administrator} result] == 0 && $result}]

puts "OS: $os"
puts "Framework: $framework"
puts "Admin: $isAdmin"
```

### Pattern 5 — Engine version checking

```tcl
# Check engine version before using features
set ver [info engine PatchLevel]
set config [info engine Configuration]
puts "Eagle $ver ($config)"
```

### Pattern 6 — Safe interpreter capability detection

```tcl
# Determine available info sub-commands
proc infoHas {subcmd} {
    expr {![catch {info $subcmd}]}
}

if {[infoHas hostname]} {
    puts "Host: [info hostname]"
} else {
    puts "Hostname not available (safe interpreter)"
}
```

### Pattern 7 — Database connection monitoring

```tcl
# List active database connections and transactions
set conns [info connections]
set trans [info transactions]
puts "Open connections: [llength $conns]"
puts "Active transactions: [llength $trans]"
```

### Pattern 8 — Culture-aware operations

```tcl
# Save, change, and restore culture
set saved [info culture]
info culture "de-DE"
# ... German locale operations ...
info culture $saved
```

### Pattern 9 — Command filtering and discovery

```tcl
# Find all safe, standard commands
set safeCmds [info commands -safe -standard]

# Find only library procedures
set libProcs [info commands -nocommands -library]

# Find hidden commands (requires unsafe interpreter)
set hidden [info commands -hiddenonly]
```

### Pattern 10 — Thread and process identification

```tcl
# Get complete process/thread identity
puts "PID:     [info pid]"
puts "PPID:    [info ppid]"
puts "TID:     [info tid]"
puts "Native:  [info tid true]"
puts "Managed: [info tid false]"
puts "PTID:    [info ptid]"
```

---

## 10. Comparison with Tcl

| Feature | Tcl `info` | Eagle `info` |
|---------|-----------|-------------|
| Procedure introspection | args, body, default, procs | Same + nprocs, source, obfuscation protection |
| Variable introspection | exists, globals, locals, vars | Same + sysvars, undefined, varlinks, check-and-read exists |
| Command introspection | commands, complete | Same + cmdtype, cmdcount (detailed), ensembles, subcommands, syntax |
| Functions/operators | functions (Tcl 8.5+) | functions + operators + operands (with filtering options) |
| Call stack | level, frame | level + levelid; frame is stub |
| Script info | script, nameofexecutable | Same + cmdline, argv, interactive, context, lastinput |
| System info | hostname, pid | Same + os, user, administrator, ppid, previouspid, processors, tid, ptid |
| Path info | library, patchlevel, tclversion, sharedlibextension | Same + base, binary, path, externals, programextension, newline, whitespace |
| .NET/CLR | None | framework, frameworkextra, runtime, runtimeversion, appdomain, assembly |
| Engine metadata | patchlevel only | engine (9 attributes), setup, source |
| Objects/types | None | objects, delegates, bindertypes, callbacks |
| Database | None | connections, transactions |
| Plugins | loaded (basic) | loaded + plugin, pluginflags, modules |
| Security | None | policies, decision, safe sub-command filtering |
| Culture | None | culture, cultures |
| Windows | None | hwnd, windows, windowtext |
| Interpreters | interps (Tcl 8.x) | interps + active (thread-safe) |
| Identifiers | None | identifier (with IdentifierKind and full metadata) |

---

## 11. Security Considerations

### Information disclosure

Many `info` sub-commands reveal system details that could aid an
attacker:

- `info os`, `info hostname`, `info user` — system identification
- `info pid`, `info ppid`, `info processors` — process fingerprinting
- `info binary`, `info path`, `info base` — installation paths
- `info assembly`, `info framework` — runtime version fingerprinting
- `info windows`, `info hwnd` — window enumeration

All of these are blocked in safe interpreters via
`PolicyOps.AllowedInfoSubCommandNames`.

### Obfuscation boundary

`ProcedureFlags.Obfuscated` provides a code protection boundary, but
it is enforced only at the `info` command level. Other introspection
mechanisms (direct interpreter API access from .NET code) may bypass
this protection. The obfuscation flag should be considered a
script-level access control, not a cryptographic protection.

### Cross-interpreter queries

The `-interpreter` option on `info commands`, `info functions`,
`info operators`, and `info vars` allows querying other interpreters.
This option is marked `Unsafe` and is blocked in safe interpreters.
Security checks use the calling interpreter's safe status, preventing
privilege escalation.

### Cached vs. live data

The refresh restriction for safe interpreters means they may receive
stale cached values for system information. This is by design — it
prevents safe interpreters from triggering potentially expensive or
information-revealing system queries.

---

## 12. References

- **Source**: `eagle/Eagle/Library/Commands/Info.cs` — command implementation
- **Policy**: `eagle/Eagle/Library/Components/Private/PolicyOps.cs` —
  `AllowedInfoSubCommandNames`
- **Interpreter**: `eagle/Eagle/Library/Components/Public/Interpreter.cs` —
  introspection methods
- **Procedure data**: `eagle/Eagle/Library/Components/Public/ProcedureData.cs`
- **Command data**: `eagle/Eagle/Library/Components/Public/CommandData.cs`
- **Core language reference**: `core_language.md` § Introspection → `info`
  command
- **Examples**: `core_examples.md` § info
- **Tcl reference**: [Tcl `info` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/info.htm)
