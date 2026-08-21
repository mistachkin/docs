# Eagle Command Option System: Architecture, Patterns, and Reference

> **For AI agents**: This document provides a deep-dive analysis of Eagle's
> internal command option infrastructure. For individual command options, see
> the per-command deep-dive files (`exec.md`, `object.md`, `interp.md`, etc.)
> or `core_language.md`. For common option patterns shared across commands, see
> the [Common Option Patterns](#common-option-patterns-across-commands) section
> below.

## 1. Executive Summary

Eagle commands parse named options through a centralized infrastructure built
around the `OptionDictionary` class and its supporting types. Every command or
sub-command that accepts options declares its available options as an
`OptionDictionary`, then hands that dictionary and the raw argument list to one
of the interpreter's option-parsing methods (`GetOptions`, `CheckOptions`, or
`ScanOptions`). The parser walks the argument list, matches option names,
validates values against type constraints, and records which options are
present and what values they carry.

As of the `CommandOptions` refactoring, all option dictionary creation in the
core library is centralized in a single internal class (`CommandOptions`) with
an enum-based dispatch (`CommandOptionType`). This makes every command's
option surface discoverable, testable, and amenable to tooling.

**The primary motivation** for this centralization is to enable external
consumers of the core library -- especially **Language Server Protocol (LSP)
implementations** -- to provide **auto-completion of option names and their
values** for any command or sub-command.

The LSP completion flow works as follows: the LSP receives the current
command invocation arguments from the line being completed -- either **1
argument** for a top-level command (e.g., `[exit]`) or **2 arguments** for an
ensemble sub-command (e.g., `[interp create]`). It maps these argument strings
to a `CommandOptionType` enum value, then calls
`CommandOptions.GetCommandOptions()` to obtain the full `OptionDictionary`.
From there it can enumerate available option names and inspect each option's
`OptionFlags` to determine what kind of value it expects (e.g., suggesting
enum members for `MustHaveEnumValue` options, or offering boolean completions
for `MustHaveBooleanValue` options).

The **string-to-enum mapping** is built into the `CommandOptionType` naming
convention itself. The overload `GetCommandOptions(ArgumentList arguments)`
joins the argument strings with underscores and parses the result as a
`CommandOptionType` enum value. For example, the arguments `["interp",
"create"]` become the string `"interp_create"`, which parses to
`CommandOptionType.Interp_Create`. This eliminates the need for a separate
lookup dictionary -- the enum names serve double duty as both programmatic
identifiers and the mapping keys.

**Key source files:**

| File | Role |
|------|------|
| `Eagle/Library/Components/Private/CommandOptions.cs` | Centralized option dictionary factory<br>methods and dispatch (~5,000 lines) |
| `Eagle/Library/Components/Private/Enumerations.cs` | `CommandOptionType` enum (~200 values) |
| `Eagle/Library/Components/Private/ObjectOps.cs` | Remaining object-interop option factories<br>(migrating to CommandOptions) |
| `Eagle/Library/Containers/Public/OptionDictionary.cs` | The dictionary container; implements<br>option parsing and lookup |
| `Eagle/Library/Components/Public/Option.cs` | Individual option definition<br>(`IOption` implementation) |
| `Eagle/Library/Components/Public/Enumerations.cs` | `OptionFlags` and `ObjectOptionType` enums |

---

## 2. Core Architecture

### 2.1 The Option Definition Pipeline

Every option-bearing command follows the same three-step pattern:

1. **Define**: Create an `OptionDictionary` containing one `Option` entry per
   recognized option name.
2. **Parse**: Call `interpreter.GetOptions(options, arguments, ...)` to scan
   the argument list against the dictionary.
3. **Query**: Use `options.IsPresent("-name")` or
   `options.IsPresent("-name", ref value)` to test and retrieve results.

```tcl
[Define]                   [Parse]                      [Query]
OptionDictionary    --->   interpreter.GetOptions   --->   options.IsPresent
  new Option(...)             matches names                  returns bool/value
  new Option(...)             validates types
  EndOfOptions                records presence
```

### 2.2 The `Option` Class

Each option is an `Option` instance (implementing `IOption`) constructed with:

```csharp
new Option(
    Type type,             /* .NET type for enum validation, or null */
    OptionFlags flags,     /* behavioral and type-constraint flags */
    int groupIndex,        /* mutual-exclusion group, or Index.Invalid */
    int index,             /* positional tracking, or Index.Invalid */
    string name,           /* the option name including "-" prefix */
    IVariant value         /* default value as Variant, or null */
)
```

**Parameters explained:**

| Parameter | Purpose | Common Values |
|-----------|---------|---------------|
| `type` | The .NET `Type` used for enum parsing<br>when `MustHaveEnumValue` is set | `typeof(EventFlags)`,<br>`typeof(MatchMode)`, `null` |
| `flags` | Bitfield controlling parsing behavior<br>(see Section 3) | `OptionFlags.None`,<br>`OptionFlags.MustHaveValue`, etc. |
| `groupIndex` | Mutual-exclusion group number;<br>options sharing a group are exclusive | `1`, `2`, `3`, or<br>`Index.Invalid` (no group) |
| `index` | Tracks position after parsing;<br>usually starts at `Index.Invalid` | `Index.Invalid` |
| `name` | Option name starting with `-`;<br>case-sensitive unless `NoCase` flag | `"-nocase"`, `"-timeout"`,<br>`"-encoding"` |
| `value` | Default `IVariant` value;<br>`null` means no default | `new Variant(EventFlags.None)`,<br>`null` |

### 2.3 `Option.CreateEndOfOptions()`

Most option dictionaries end with `Option.CreateEndOfOptions()`, which adds the
`--` end-of-options marker. This allows users to pass arguments beginning with
`-` after the `--` marker.

**Notable exceptions that omit EndOfOptions:**
- `[fconfigure]` (both set and query modes) -- uses positional name/value pairs
- `[clock clicks]`, `[clock filetime]`, `[clock format]`, `[clock now]`,
  `[clock scan]` -- simple option sets where `--` is not needed
- `[puts]` -- compatibility with Tcl's positional syntax
- `[subst]` -- deliberately commented out (compatibility)

### 2.4 The `OptionDictionary` Class

`OptionDictionary` is a specialized dictionary that:
- Stores options keyed by name
- Supports option parsing via `GetOptions`, `CheckOptions`, `ScanOptions`
- Tracks which options were present and their parsed values
- Supports mutual-exclusion groups
- Supports composition (two-collection constructor for combining option sets)

**Constructors:**
```csharp
new OptionDictionary(IEnumerable<IOption> collection)
new OptionDictionary(IEnumerable<IOption> collection1,
                     IEnumerable<IOption> collection2)  // composition
```

The two-collection constructor is used when a command's options are composed
from its own specific options plus a shared set (e.g., `[xml foreach]` combines
its XML-specific options with the common `FixupReturnValue` options).

---

## 3. OptionFlags Reference

The `OptionFlags` enum controls option parsing behavior. Flags combine with
bitwise OR. Key flags and their semantics:

### 3.1 Value Requirement Flags

These flags control whether and how the parser expects a value after the option
name. They are mutually exclusive in intent (an option either has a value or it
does not).

| Flag | Meaning |
|------|---------|
| `None` | Boolean/switch option -- presence alone is meaningful |
| `MustHaveValue` | Next argument is consumed as the option's string value |
| `MustHaveBooleanValue` | Value must parse as boolean (`true`/`false`/`1`/`0`/`yes`/`no`) |
| `MustHaveIntegerValue` | Value must parse as a 32-bit integer |
| `MustHaveWideIntegerValue` | Value must parse as a 64-bit integer |
| `MustHaveUnsignedWideIntegerValue` | Value must parse as an unsigned 64-bit integer |
| `MustHaveNarrowIntegerValue` | Value must parse as a 16-bit integer |
| `MustHaveEnumValue` | Value must parse as a member of the `Type` specified in the constructor |
| `MustHaveTypeValue` | Value must resolve to a .NET `Type` |
| `MustHaveTypeListValue` | Value must resolve to a list of .NET `Type` names |
| `MustHaveEncodingValue` | Value must resolve to a character `Encoding` |
| `MustHaveDateTimeValue` | Value must parse as a `DateTime` |
| `MustHaveReturnCodeValue` | Value must parse as a `ReturnCode` |
| `MustHaveReturnCodeListValue` | Value must parse as a list of `ReturnCode` values |
| `MustHaveMatchModeValue` | Value must parse as a `MatchMode` |
| `MustHaveRuleSetValue` | Value must resolve to an `IRuleSet` |
| `MustHaveObjectValue` | Value must resolve to an opaque object handle |
| `MustHaveInterpreterValue` | Value must resolve to a child interpreter path |
| `MustHaveAbsoluteNamespaceValue` | Value must be a fully-qualified namespace name |
| `MustHaveListValue` | Value must parse as a Tcl-style list |
| `MustHaveDictionaryValue` | Value must parse as a key-value dictionary |
| `MustHaveByteArrayValue` | Value must parse as a byte array |
| `MustHaveCultureInfoValue` | Value must resolve to a `CultureInfo` |
| `MustHaveVersionValue` | Value must parse as a version number |

### 3.2 Safety and Visibility Flags

| Flag | Meaning |
|------|---------|
| `Unsafe` | Option is hidden in safe interpreters.<br>If a safe interpreter encounters this option, parsing fails<br>with an error. This is Eagle's primary mechanism for<br>restricting dangerous operations in sandboxed environments. |
| `Restricted` | Stronger than `Unsafe`; used for<br>especially sensitive operations |

### 3.3 Behavioral Flags

| Flag | Meaning |
|------|---------|
| `NoCase` | Option name matching is case-insensitive<br>(e.g., `-whatIf` matches `-whatif`).<br>Used sparingly -- most options are case-sensitive. |
| `Unsupported` | Option is recognized but immediately rejected<br>with an error. Used for platform-specific options on<br>unsupported platforms (e.g., `-isolated` when<br>`ISOLATED_PLUGINS` is not compiled in). |
| `Ignored` | Option is recognized but its value is silently<br>discarded. Used in two-pass option processing where an<br>option was already consumed in an earlier pass. |
| `Nullable` | For typed values, allows the value to be null/empty |
| `CouldBePath` | Hint that the value might be a file path (affects validation) |

### 3.4 Common Flag Combinations

| Combination | Typical Use |
|-------------|-------------|
| `OptionFlags.None` | Simple boolean switch (`-force`, `-nocase`, `-verbose`) |
| `OptionFlags.MustHaveValue` | String-valued option (`-pattern`, `-variable`) |
| `OptionFlags.MustHaveIntegerValue` | Numeric option (`-timeout`, `-count`) |
| `OptionFlags.MustHaveEnumValue` | Enum-valued option (requires `typeof(T)` in constructor) |
| `OptionFlags.MustHaveValue`<br>`\| OptionFlags.Unsafe` | Unsafe string option<br>(`-message`, `-text`) |
| `OptionFlags.Unsafe` | Unsafe boolean switch<br>(`-force`, `-debug`, `-security`) |
| `OptionFlags.Unsafe`<br>`\| OptionFlags.Unsupported` | Conditionally unavailable<br>unsafe option |
| `OptionFlags.MustHaveBooleanValue`<br>`\| OptionFlags.Nullable` | Optional boolean (`-bundle`) |
| `OptionFlags.NoCase`<br>`\| OptionFlags.MustHaveBooleanValue` | Case-insensitive boolean<br>(`-breakOk`, `-noCancel`) |

---

## 4. Mutual-Exclusion Groups

The `groupIndex` parameter creates mutual-exclusion groups. When two options
share the same positive `groupIndex`, only the last one specified takes effect.
The earlier one's "present" flag is cleared.

**Example from `[lsort]`:**
```tcl
Group 1 (sort type):    -ascii, -dictionary, -integer, -random, -real
Group 2 (sort order):   -increasing, -decreasing
```

When a user writes `lsort -integer -decreasing $list`, the parser records
`-integer` from group 1 and `-decreasing` from group 2. If they wrote
`lsort -ascii -integer $list`, only `-integer` would be "present" (it
overwrites `-ascii` in the same group).

**Commands using mutual-exclusion groups:**
- `[lsort]`: sort type (group 1), sort order (group 2)
- `[lsearch]`: value type (group 1), sort order (group 2), match mode (group 3)
- `[switch]`: match mode (groups 1, 2, 3)
- `[open]`: standard stream selection (group 1: `-stdin`/`-stdout`/`-stderr`)

---

## 5. The Three Parsing Methods

The interpreter provides three option-parsing methods with different behaviors:

### 5.1 `interpreter.GetOptions()`

The standard, full-featured parser. It:
- Walks the argument list from `startIndex` to `stopIndex`
- Matches option names against the dictionary
- Validates and stores values
- Enforces mutual-exclusion groups
- Respects `Unsafe`/`Unsupported`/`Ignored` flags
- Sets `argumentIndex` to the first non-option argument
- Returns `ReturnCode.Error` with a descriptive message on failure

This is used by ~95% of commands.

### 5.2 `interpreter.CheckOptions()`

A lightweight pre-scanner. It:
- Checks which options are present without full validation
- Does NOT consume values (just checks names)
- Used in two-pass option processing to determine which code path to take
  before the full parse

**Example: `[package scan]`** uses `CheckOptions` to detect if `-interpreter`
is present, which changes whether to look up a child interpreter before doing
the full `GetOptions` pass.

### 5.3 `interpreter.ScanOptions()`

The lightest-weight scanner. It:
- Only determines where options end and positional arguments begin
- Sets `argumentIndex` to the first non-option argument
- Does NOT validate values or record presence
- Used when you need argument boundaries before option values are known

**Example: `[interp readorgetscriptfile]`** uses `ScanOptions` to find the
child interpreter path (a positional argument), then looks up that interpreter
to compute default values for `-scriptflags` and `-engineflags`, then calls
`GetOptions` with those defaults set.

---

## 6. The CommandOptions Centralization

### 6.1 Architecture

All option dictionary creation is centralized in the `CommandOptions` internal
static class. Each command/sub-command has a private factory method that returns
its `OptionDictionary`, and a public dispatch method routes requests by enum
value:

```csharp
// Simple dispatch (most commands)
OptionDictionary options = CommandOptions.GetCommandOptions(
    CommandOptionType.Exit);

// Interpreter-dependent dispatch (computed defaults)
OptionDictionary options = CommandOptions.GetCommandOptions(
    CommandOptionType.Vwait, interpreter);

// Special-case public methods (complex parameters)
OptionDictionary options = CommandOptions.GetStringIsOptions(not);
OptionDictionary options = CommandOptions.GetPackageScanOptions(oldFlags);
OptionDictionary options = CommandOptions.GetSqlOpenOptions(valueFlags);
OptionDictionary options = CommandOptions.GetInterpServiceOptions(
    serviceEventFlags);
OptionDictionary options =
    CommandOptions.GetInterpReadOrGetScriptFileOptions(
        oldScriptFlags, oldEngineFlags);
```

### 6.2 CommandOptionType Enum

The `CommandOptionType` enum has ~200 sequential values organized alphabetically
by command. Values use `Command_SubCommand` naming for ensemble commands and
plain `Command` names for top-level commands. Examples:

```tcl
After_Idle, After_Info
Debug_Break, Debug_Emergency, Debug_Trace
Exit, Gets, Glob, Kill
File_Cleanup, File_Copy, File_Delete
Interp_Create, Interp_ReadOrGetScriptFile
Object_Create, Object_Invoke, Object_Load
String_Equal, String_Format, String_Is
Tcl_Create, Tcl_Find, Tcl_InterpCreate
```

### 6.3 Relationship to ObjectOps

The original `ObjectOps` class contains ~40 factory methods for options related
to `[object]` sub-commands and shared object-interop patterns. These are
accessible through the `CommandOptions` dispatch via delegation:

```tcl
CommandOptions.GetCommandOptions(CommandOptionType.Object_Create)
  --> delegates to ObjectOps.GetCreateOptions()
```

`ObjectOps` also has its own dispatch via `ObjectOptionType` (a flags enum)
and `GetObjectOptions(ObjectOptionType)`. This older dispatch remains for
backward compatibility with code that uses `ObjectOptionType` masks.

---

## 7. Special Patterns and Tricky Cases

### 7.1 Two-Pass Option Processing

Some commands process options in two passes: a pre-scan with a small
`OptionDictionary`, followed by the full parse with the complete dictionary.
The pre-scan determines which code path to take.

**Pattern:**
```tcl
1. Create preOptions dictionary (few options)
2. CheckOptions(preOptions, ...) to detect path-deciding options
3. Compute values based on pre-scan results
4. Create full options dictionary (may include pre-scanned options with Ignored flag)
5. GetOptions(options, ...) for the full parse
```

**Commands using this pattern:**
- **`[package scan]`**: Pre-scans for `-interpreter` to determine which
  interpreter's `PackageIndexFlags` to use as the default for `-flags`.
  The `-interpreter` option appears in the full dictionary with
  `OptionFlags.Ignored` so that `GetOptions` does not reject it if present.
- **`[sql open]`**: Pre-scans for `-stricttype`, `-verbose`, `-nocase` to
  determine `ValueFlags` for type resolution. All three appear in the full
  dictionary with `OptionFlags.Ignored`.

### 7.2 Scan-Then-Get (Deferred Defaults)

A variant of two-pass processing where `ScanOptions` is used first to find
positional arguments, then default values are computed, then `GetOptions` is
called with those defaults set.

**`[interp readorgetscriptfile]`** is the canonical example:
1. `ScanOptions` with null defaults to find the child interpreter path
2. Look up the child interpreter and read its current `ScriptFlags` and
   `EngineFlags`
3. Create a new `OptionDictionary` with those values as defaults for
   `-scriptflags` and `-engineflags`
4. `GetOptions` on the new dictionary

The two dictionaries are independent (no shared `IOption` objects). This is
safe because `ScanOptions` only cares about option names and flags for
boundary detection, not default values.

### 7.3 Interpreter-Dependent Defaults

Many options have defaults that come from the current interpreter's state.
These factory methods accept an `Interpreter` parameter:

| Command | Options with interpreter defaults |
|---------|-----------------------------------|
| `[fcopy]` | `-eventflags` from `interpreter.EngineEventFlags` |
| `[parse command]`, `[parse expression]`, `[parse script]` | `-engineflags`, `-substitutionflags` |
| `[scope eval]` | `-eventwaitflags` from `interpreter.EventWaitFlags` |
| `[string format]` | `-datetimekind` from `interpreter.DateTimeKind` |
| `[tcl find]`, `[tcl select]`, `[tcl versionrange]` | `-flags` / `-findflags` from `interpreter.TclFindFlags` |
| `[tcl load]` | `-findflags`, `-loadflags` from interpreter |
| `[vwait]` | `-eventwaitflags`, `-variableflags` from interpreter |
| `[interp service]` | `-eventflags` from child interpreter's `ServiceEventFlags` |
| `[exec]` | `-eventflags` from `interpreter.EngineEventFlags` |

### 7.4 Computed Local Defaults

Some options have defaults that depend on values computed earlier in the
command's execution, which cannot be derived from the interpreter alone:

| Command | Option | Computed From |
|---------|--------|---------------|
| `[string is]` | `-not` | Boolean toggled by parsing `"not"` prefix words |
| `[package scan]` | `-flags` | `PackageIndexFlags` from interpreter or child interpreter |
| `[sql open]` | `-valueflags` | `ValueFlags` computed from pre-options analysis |

These use named public methods on `CommandOptions` with typed parameters
rather than the standard dispatch.

### 7.5 Composed Option Dictionaries

Some commands compose their options from multiple sources using the
two-collection `OptionDictionary` constructor:

- **`[object verifyall]`**: Own options + `ObjectOps.GetCertificateOptions()`
- **`[xml foreach]`**: Own XML options + `ObjectOps.GetFixupReturnValueOptions()`
- **`[sql execute]`**: SQL-specific options + `GetFixupReturnValueOptions()`
- **`[object invoke]`**: `GetInvokeOnlyOptions()` + `GetInvokeSharedOptions()`
- **`[read]`**: `GetReadOnlyOptions()` + `GetFixupReturnValueOptions()`

This composition pattern allows shared option sets (like the "fixup return
value" options for object handle management) to be reused across commands
without duplication.

### 7.6 Conditional Compilation Guards

Many options exist only when specific features are compiled in. The factory
methods and dispatch cases use `#if` guards matching the source feature:

| Guard | Affected Options |
|-------|------------------|
| `#if DEBUGGER` | All `Debug_*` except `Debug_Exception` |
| `#if PREVIOUS_RESULT` | `Debug_Exception` |
| `#if SHELL` | `Debug_Shell` |
| `#if TEST` | `Debug_Hook`, `Test_CreateWithRules`, `-captureTrace` in `[test2]` |
| `#if NATIVE && TCL` | All `Tcl_*` options |
| `#if DATA` | `Sql_Execute`, `Sql_Transaction`, `-bundle`/`-bundleflags` in `[source]` |
| `#if NETWORK` | `Uri_Get`, `Uri_Post` |
| `#if CALLBACK_QUEUE` | `Callback_Dequeue` |
| `#if XML && SERIALIZATION` | `Xml_Deserialize`, `Xml_Serialize` |
| `#if CONSOLE && NATIVE && WINDOWS` | `Host_Font` |
| `#if ISOLATED_PLUGINS` | `-isolated`/`-noisolated` in `[load]`, `[interp create]` |
| `#if !NET_STANDARD_20 && !MONO` | `File_Sddl` |

When a guarded feature is not compiled in, the corresponding options typically
still appear in the dictionary with `OptionFlags.Unsupported`, causing a clear
error message if a script tries to use them. This is preferable to silently
ignoring the option.

### 7.7 The `-nocase` / `NoCase` Distinction

There are two unrelated uses of "nocase" in the option system:

1. **`-nocase` as a script-level option**: A boolean switch that tells the
   command to perform case-insensitive matching (e.g., `string equal -nocase`).
   This is `OptionFlags.None` -- just a regular switch option.

2. **`OptionFlags.NoCase` as a flag on the option definition**: Makes the
   option *name itself* match case-insensitively. For example,
   `new Option(null, OptionFlags.NoCase, ..., "-whatIf", null)` means the
   parser will accept `-whatif`, `-WhatIf`, `-WHATIF`, etc.

   This is used primarily for options that follow .NET naming conventions
   (PascalCase) rather than Tcl conventions (lowercase):
   `-returnCodes`, `-errorOutput`, `-exitCode`, `-breakOk`, `-noCancel`,
   `-ruleSet`, `-regExOptions`, `-visibleSpace`, etc.

### 7.8 Missing EndOfOptions

Most option dictionaries include `Option.CreateEndOfOptions()` to allow
`--` as an end-of-options marker. A few intentionally omit it:

- **`[fconfigure]`** (both set and query modes): Uses positional name/value
  pair syntax where `--` would not make sense.
- **`[puts]`**: Compatibility with Tcl's positional `puts ?-nonewline? ?channelId? string` syntax.
- **`[subst]`**: EndOfOptions is commented out -- `/* , Option.CreateEndOfOptions() */` --
  for Tcl compatibility where `[subst]` does not support `--`.

---

## 8. Common Option Patterns Across Commands

Many options appear across 10-30+ commands with identical semantics.
This section consolidates them into named groups so per-command entries
(Section 13) can reference the group instead of re-explaining every
option. When a Section 13 entry says "includes the standard
[object handle options](#81-object-handle-management-the-fixupreturnvalue-set),"
it means every option in that group is present with the behavior
described here.

Occurrence counts reflect the total number of distinct
command/sub-command option sets (across both `CommandOptions.cs` and
`ObjectOps.cs`) that include the option. The count tells you how
"universal" an option is.

### 8.1 Object Handle Management (the FixupReturnValue Set)

<a id="fixupreturnvalue-options"></a>

These 13 options form a canonical set defined in
`ObjectOps.GetFixupReturnValueOptions()`. They appear in any command
that creates or returns .NET opaque object handles via the
`MarshalOps.FixupReturnValue` or `Utility.FixupReturnValue` pipeline.

| Option | Value | Unsafe | Description |
|--------|-------|--------|-------------|
| `-objectname` | string | yes | Explicit name for the created handle;<br>without this, an auto-generated name is used |
| `-returntype` | Type | yes | Expected return type; influences how<br>the return value is interpreted |
| `-objecttype` | Type | yes | Override the resolved type of<br>the returned object |
| `-create` | -- | -- | Allow automatic opaque object handle<br>creation (default depends on command) |
| `-nodispose` | -- | yes | Prevent `Dispose()` from being called<br>when the handle is removed |
| `-alias` | -- | -- | Create a command alias for the handle<br>(invoke dispatch) |
| `-aliasraw` | -- | -- | Create a raw alias<br>(invokeraw dispatch) |
| `-aliasall` | -- | -- | Create a comprehensive alias<br>(invokeall dispatch) |
| `-aliasreference` | -- | yes | Create a reference-counted alias<br>(prevents premature disposal) |
| `-tcl` | TclInterpreter | yes | Bridge the handle to a native Tcl<br>interpreter (requires `NATIVE && TCL`) |
| `-noforcedelete` | -- | yes | Don't force-delete the command alias<br>when there is a name collision |
| `-tostring` | -- | -- | Return `ToString()` representation<br>instead of an opaque handle |
| `-objectflags` | ObjectFlags | yes | Override default object handle<br>behavior flags |

**Commands that include the full canonical set** (via composition with
`GetFixupReturnValueOptions()`):

- `[object invoke]`, `[object invokeraw]`, `[object invokeall]`
  (via `GetInvokeSharedOptions()`)
- `[sql execute]` (via `GetSqlExecuteOptions()`)
- `[read]` (via `GetReadOptions()`)
- `[xml foreach]` (via `GetXmlForEachOptions()`)

**Commands that include a subset** of handle management options
(defined inline rather than via composition):

- `[object create]` -- includes `-objectname`, `-nocreate`,
  `-nodispose`, `-alias`, `-aliasraw`, `-aliasall`, `-aliasreference`,
  `-tcl`, `-noforcedelete`, `-tostring`, `-objectflags`,
  `-byrefobjectflags`
- `[object foreach]` -- includes `-objectname`, `-nocreate`,
  `-nodispose`, `-alias`, `-aliasraw`, `-aliasall`, `-aliasreference`,
  `-tcl`, `-noforcedelete`, `-tostring`, `-objectflags`
- `[object get]` -- includes `-objectname`, `-nocreate`, `-nodispose`,
  `-alias`, `-aliasraw`, `-aliasall`, `-aliasreference`, `-tcl`,
  `-noforcedelete`, `-tostring`, `-objectflags`, `-byrefobjectflags`
- `[object load]` -- includes `-objectname`, `-create`, `-nodispose`,
  `-alias`, `-aliasraw`, `-aliasall`, `-aliasreference`, `-tcl`,
  `-noforcedelete`, `-tostring`, `-objectflags`
- `[library call]` -- includes `-objectname`, `-create`, `-nodispose`,
  `-alias`, `-aliasraw`, `-aliasall`, `-aliasreference`, `-tcl`,
  `-noforcedelete`, `-tostring`, `-objectflags`, `-byrefobjectflags`
- `[callback dequeue]` -- includes `-objectname`, `-nodispose`,
  `-alias`, `-aliasraw`, `-aliasall`, `-aliasreference`, `-tcl`,
  `-noforcedelete`, `-tostring`, `-objectflags`
- `[xml deserialize]` -- includes `-objectname`, `-create`,
  `-nodispose`, `-alias`, `-aliasraw`, `-aliasall`,
  `-aliasreference`, `-tcl`, `-noforcedelete`, `-tostring`,
  `-objectflags`
- `[debug exception]` -- includes `-objectname`, `-create`,
  `-nodispose`, `-alias`, `-aliasraw`, `-aliasall`,
  `-aliasreference`, `-tcl`, `-noforcedelete`, `-tostring`,
  `-objectflags`

### 8.2 Error and Output Control

These options control diagnostic output and error suppression. They
always have the same meaning regardless of which command they appear in.

| Option | Count | Description |
|--------|-------|-------------|
| `-nocomplain` | 28 | Suppress errors; the operation returns<br>success (empty string) instead of raising an error |
| `-verbose` | 21 | Enable detailed diagnostic output<br>during the operation |
| `-debug` | 9 | Enable debug-level diagnostics<br>(more targeted than `-verbose`) |
| `-trace` | 9 | Enable trace-level diagnostics<br>(finest granularity) |
| `-noerror` | 3 | Don't set the error return code on failure;<br>the error message is still available but<br>the return code is `Ok` |

**Usage notes:**

- `-nocomplain` is the most common cross-cutting option. It appears in
  object lifecycle commands (`[object dispose]`, `[object cleanup]`),
  type resolution, information queries, and more.
- `-verbose`, `-debug`, and `-trace` form a diagnostic hierarchy but
  are not always present together. Some commands offer only `-verbose`;
  reflection-heavy commands (create, invoke) offer all three.
- In safe interpreters, `-debug` and `-trace` are sometimes marked
  `Unsafe` because their output could leak implementation details.

### 8.3 Type Resolution

These options appear in commands that need to resolve .NET type names
to `System.Type` objects.

| Option | Count | Description |
|--------|-------|-------------|
| `-type` | 31 | .NET type name to resolve<br>(fully-qualified or simple name) |
| `-objecttypes` | 10 | List of type categories to search<br>(e.g., `AssemblyQualified`, `Simple`) |
| `-stricttype` | 15 | Fail if the type cannot be resolved exactly,<br>instead of returning a best-effort match or warning |
| `-nocase` | 36 | Case-insensitive name matching |

**Note on `-nocase`:** This is the single most common cross-cutting
option (36 occurrences). It appears in four distinct contexts -- type
name matching, member/method name matching, string/pattern matching,
and file path matching -- but always means "case-insensitive." The
context determines *what* is matched case-insensitively.

### 8.4 Method Invocation and Reflection

These options appear in commands that invoke .NET methods or access
members via reflection. They are concentrated in `[object invoke]`,
`[object invokeraw]`, `[object invokeall]`, `[object create]`, and
`[library call]`.

| Option | Count | Description |
|--------|-------|-------------|
| `-marshalflags` | 13 | Control value conversion between<br>Eagle and .NET types (Unsafe) |
| `-argumentflags` | 7 | Control by-reference argument<br>handling behavior (Unsafe) |
| `-bindingflags` | 7 | .NET reflection `BindingFlags`<br>for member lookup |
| `-flags` | 20 | Alias for `-bindingflags` in most contexts;<br>also used for `EventFlags`, `ScriptFlags`,<br>etc. in non-reflection commands |
| `-reorderflags` | 4 | Control method overload reordering<br>during resolution |
| `-nobyref` | 5 | Disable by-reference parameter handling |
| `-noargs` | 5 | Don't pass arguments to<br>the method/constructor |
| `-noinvoke` | 5 | Resolve the member without invoking it<br>(metadata inspection) |
| `-help` | 3 | Resolve the member without invoking it and<br>return help for the matching overload(s) |
| `-limit` | 9 | Maximum number of method/constructor<br>overloads to consider |
| `-index` | 8 | Select a specific overload<br>by zero-based index |

**Usage notes:**

- `-marshalflags` and `-argumentflags` are almost always `Unsafe`
  because they can alter how values cross the managed/unmanaged
  boundary.
- `-flags` is overloaded: in reflection commands it means
  `BindingFlags`; in event commands it means `EventFlags`; in
  `[source]` it means `ScriptFlags`. The value type is always
  appropriate to the context.
- `-limit` and `-index` work together: `-limit` narrows the candidate
  set, `-index` picks one from it.

### 8.5 DateTime and Encoding

These options control temporal value interpretation and character
encoding for I/O operations.

**DateTime options** (6 occurrences each, concentrated in
`[library call]`, `[object invoke]`, `[object invokeraw]`,
`[sql execute]`, `[clock]` sub-commands):

| Option | Value | Description |
|--------|-------|-------------|
| `-datetimekind` | DateTimeKind | UTC, Local, or Unspecified<br>interpretation |
| `-datetimestyles` | DateTimeStyles | Parsing styles<br>(e.g., `AllowWhiteSpaces`,<br>`AssumeUniversal`) |
| `-datetimeformat` | string | Custom DateTime format string<br>(e.g., `"yyyy-MM-dd HH:mm:ss"`) |

**Encoding option** (18 occurrences across I/O commands):

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for byte-to-string<br>or string-to-byte conversion |

Commands using `-encoding`: `[gets]`, `[puts]`, `[source]`,
`[base64 encode]`, `[base64 decode]`, `[hash normal]`,
`[hash keyed]`, `[hash mac]`, `[read]`, `[xml serialize]`,
`[xml deserialize]`, and others.

In safe interpreters, `-encoding` is sometimes marked `Unsafe`
(e.g., in `[gets]` and `[puts]`) because it could affect
security-sensitive I/O operations.

### 8.6 Execution Control

These options control timing, safety overrides, and execution mode.

| Option | Count | Description |
|--------|-------|-------------|
| `-time` | 26 | Measure and report execution time;<br>often paired with `-timevar` to store the result |
| `-timeout` | 15 | Operation timeout in milliseconds;<br>the operation raises an error or is cancelled<br>if the timeout expires |
| `-force` | 16 | Override safety checks (e.g., allow removal<br>of a locked variable, force-close a channel) |
| `-synchronous` | 4 | Force synchronous execution; prevents<br>the operation from being dispatched to<br>a thread pool or event queue |

**Usage notes:**

- `-time` is very common (26 occurrences) and always has the same
  behavior: wraps the operation in a stopwatch and reports elapsed
  time. Many commands also support `-timevar` to store the timing
  result in a variable.
- `-timeout` appears in network operations (`[uri download]`,
  `[uri upload]`), database operations (`[sql execute]`), and
  synchronization (`[object wait]`). The unit is always milliseconds.
- `-force` semantics vary slightly by command but always mean "proceed
  despite a condition that would normally prevent the operation."

### 8.7 Matching and Filtering

These options appear in commands that filter or search by pattern.

| Option | Count | Description |
|--------|-------|-------------|
| `-nocase` | 36 | Case-insensitive matching<br>(see Section 8.3 for full discussion) |
| `-pattern` | 4 | Filter pattern string |
| `-mode` / `-match` | 4 / 7 | `MatchMode` value controlling the pattern<br>type (Glob, Regexp, Exact, etc.) |

Commands that support matching often accept a trailing pattern
argument rather than a `-pattern` option. The `-mode` or `-match`
option then specifies how to interpret that pattern. Typical
combinations:

- `-nocase` + trailing pattern: `[info commands ?pattern?]`
- `-match` + argument: `[lsearch -match regexp $list $pattern]`
- `-mode` + `-pattern` + `-nocase`: `[object members]`

### 8.8 Security Options

Many commands include options restricted to unsafe interpreters.
These options are hidden (not visible in option enumeration) in safe
interpreters and raise an error if used.

| Pattern | Meaning |
|---------|---------|
| `OptionFlags.Unsafe` | Hidden in safe interpreters |
| `OptionFlags.Unsafe`<br>`\| OptionFlags.MustHaveValue` | Unsafe string parameter |
| `OptionFlags.MustHaveRuleSetValue`<br>`\| OptionFlags.CouldBePath`<br>`\| OptionFlags.Unsafe` | Rule set for security validation<br>(unsafe because it could reference<br>filesystem paths) |

Common unsafe options across commands: `-interpreter`, `-sdk`,
`-security`, `-nosecurity`, `-debug`, `-thread`, `-timeout`,
`-ruleset`, `-objectname`, `-returntype`, `-objecttype`, `-nodispose`,
`-aliasreference`, `-tcl`, `-noforcedelete`, `-objectflags`,
`-marshalflags`, `-argumentflags`.

---

## 9. Option Processing Idioms in Command Implementations

### 9.1 Standard Pattern (Simple Command)

```csharp
OptionDictionary options =
    CommandOptions.GetCommandOptions(
        CommandOptionType.Exit);

int argumentIndex = Index.Invalid;

code = interpreter.GetOptions(
    options, arguments, 0, 1, Index.Invalid,
    false, ref argumentIndex, ref result);

if (code == ReturnCode.Ok)
{
    if (options.IsPresent("-force"))
        force = true;

    IVariant value = null;
    if (options.IsPresent("-message", ref value))
        message = value.ToString();
}
```

### 9.2 Two-Pass Pattern (Pre-Options)

```csharp
// Phase 1: Check for path-deciding option
OptionDictionary preOptions =
    CommandOptions.GetCommandOptions(
        CommandOptionType.Package_ScanPreOptions);

code = interpreter.CheckOptions(
    preOptions, arguments, 0, 2, Index.Invalid,
    ref argumentIndex, ref result);

if ((code == ReturnCode.Ok) &&
    preOptions.IsPresent("-interpreter"))
{
    oldFlags = interpreter.PackageIndexFlags;
}

// Phase 2: Full parse with computed defaults
OptionDictionary options =
    CommandOptions.GetPackageScanOptions(oldFlags);

code = interpreter.GetOptions(
    options, arguments, 0, 2, Index.Invalid,
    true, ref argumentIndex, ref result);
```

### 9.3 Scan-Then-Get Pattern (Deferred Defaults)

```csharp
// Phase 1: Find positional argument boundaries
OptionDictionary scanOptions =
    CommandOptions.GetInterpReadOrGetScriptFileOptions(
        null, null);

code = interpreter.ScanOptions(
    scanOptions, arguments, 0, 2, Index.Invalid,
    false, ref scanArgumentIndex, ref result);

// Phase 2: Look up child interpreter, compute defaults
ScriptFlags oldScriptFlags = ScriptOps.GetFlags(...);
EngineFlags oldEngineFlags = childInterpreter.EngineFlags;

// Phase 3: Full parse with computed defaults
OptionDictionary options =
    CommandOptions.GetInterpReadOrGetScriptFileOptions(
        oldScriptFlags, oldEngineFlags);

code = interpreter.GetOptions(
    options, arguments, 0, 2, Index.Invalid,
    false, ref getArgumentIndex, ref result);
```

---

## 10. Inventory of All Centralized Options

The following table lists every `CommandOptionType` value, its source command/
sub-command, and the category of option handling:

| Category | Count | Description |
|----------|-------|-------------|
| Simple (S) | ~120 | Standard factory method, no parameters |
| Interpreter-dependent (A) | ~12 | Factory accepts `Interpreter` for computed defaults |
| Static defaults (B) | ~3 | Factory calls static methods for defaults |
| Computed defaults (C) | ~5 | Named public method with typed parameters |
| Two-pass (D) | ~4 | PreOptions + main options (separate dicts) |
| Scan+mutate (E) | ~1 | ScanOptions then GetOptions with deferred defaults |
| Multi-path (F) | ~2 | Multiple independent dicts in different code paths |
| ObjectOps delegation | ~35 | Dispatches to ObjectOps factory methods |
| **Total** | **~182** | |

---

## 11. Appendix: Complete OptionFlags Enum Values

For reference, the full set of `OptionFlags` values (from
`Eagle/Library/Components/Public/Enumerations.cs`):

| Value | Hex | Meaning |
|-------|-----|---------|
| `None` | `0x0` | No special behavior (boolean switch) |
| `System` | | System-level option |
| `Unsafe` | | Hidden in safe interpreters |
| `Restricted` | | More restricted than Unsafe |
| `Ignored` | | Silently consumed (for two-pass processing) |
| `Unsupported` | | Recognized but rejected (platform not available) |
| `NoCase` | | Option name matching is case-insensitive |
| `Nullable` | | Typed value may be null/empty |
| `CouldBePath` | | Value might be a filesystem path |
| `MustHaveValue` | | Requires string value argument |
| `MustHaveBooleanValue` | | Requires boolean value |
| `MustHaveIntegerValue` | | Requires 32-bit integer |
| `MustHaveWideIntegerValue` | | Requires 64-bit integer |
| `MustHaveUnsignedWideIntegerValue` | | Requires unsigned 64-bit integer |
| `MustHaveNarrowIntegerValue` | | Requires 16-bit integer |
| `MustHaveEnumValue` | | Requires enum value (needs `Type` in constructor) |
| `MustHaveTypeValue` | | Requires .NET Type name |
| `MustHaveTypeListValue` | | Requires list of Type names |
| `MustHaveEncodingValue` | | Requires encoding name |
| `MustHaveDateTimeValue` | | Requires DateTime value |
| `MustHaveReturnCodeValue` | | Requires ReturnCode |
| `MustHaveReturnCodeListValue` | | Requires list of ReturnCodes |
| `MustHaveMatchModeValue` | | Requires MatchMode |
| `MustHaveRuleSetValue` | | Requires IRuleSet |
| `MustHaveObjectValue` | | Requires object handle |
| `MustHaveInterpreterValue` | | Requires interpreter path |
| `MustHaveAbsoluteNamespaceValue` | | Requires absolute namespace path |
| `MustHaveListValue` | | Requires Tcl list value |
| `MustHaveDictionaryValue` | | Requires key-value dictionary |
| `MustHaveByteArrayValue` | | Requires byte array |
| `MustHaveCultureInfoValue` | | Requires CultureInfo |
| `MustHaveVersionValue` | | Requires Version |

---

## 12. The `DataTable` Result Format

Eagle's `[sql execute]` command supports a `DataTable` result format that
materializes query results as a custom `DataTable` object (derived from
`System.Data.DataTable`) with value-added methods for Eagle scripting.

### 12.1 Usage

```tcl
set table [sql execute -execute reader -format datatable $db \
    "SELECT id, name, age FROM users;"]
```

The returned opaque handle wraps a `DataOps.DataTable` object that inherits
all standard `System.Data.DataTable` functionality (Rows, Columns, Select,
etc.) and adds Eagle-specific convenience methods.

### 12.2 Value-Added Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `ToList` | IStringList | All rows as value lists |
| `ToList(int limit)` | IStringList | First N rows as value lists |
| `ToList(string filter, string sort)` | IStringList | Filtered/sorted rows as value lists |
| `ToList(string filter, string sort, int limit)` | IStringList | Filtered/sorted with limit |
| `ToDictionary` | IStringList | All rows as key-value lists |
| `ToDictionary(int limit)` | IStringList | First N rows as key-value lists |
| `ToDictionary(string filter, string sort)` | IStringList | Filtered/sorted as key-value lists |
| `ToDictionary(string filter, string sort, int limit)` | IStringList | Filtered/sorted with limit |
| `GetColumnNames` | IStringList | Column names |

### 12.3 Inherited .NET Functionality

Since the class derives from `System.Data.DataTable`, all standard members
are accessible via `[object invoke]`:

```tcl
# Row count
puts [$table Rows.Count]

# Named column access on individual rows
object foreach -alias row [$table Rows] {
    puts [$row Item "name"]
}

# In-memory filtering via DataTable.Select
set filtered [$table Select "age > 30"]

# Schema inspection
object foreach -alias col [$table Columns] {
    puts "[$col ColumnName]: [$col DataType]"
}
```

### 12.4 Comparison with Other Formats

| Format | Memory | Reusable | Named Columns | .NET Object |
|--------|--------|----------|---------------|-------------|
| `Array` (default) | Script variable | Yes | Via `$rows(names)` | No |
| `List` | Script string | Yes | No (positional) | No |
| `DataReader` | Streaming | No (forward-only) | Yes (GetOrdinal) | Yes |
| `DataTable` | Materialized | Yes | Yes (Item, ToDict) | Yes |

Use `DataTable` when you need to iterate results multiple times, access
columns by name, pass data to .NET APIs, or filter in memory. Use
`DataReader` for large result sets where streaming is preferred. Use
`Array`/`List` for simple script-level processing.

---

## 13. Per-Command Option Reference

This section documents every option for every command and sub-command,
organized alphabetically. For each option: its name, value type (if any),
and what it controls.

<details>
<summary><code>[after idle]</code> and <code>[after &lt;milliseconds&gt;]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-thread` | int64 | Thread ID for event execution;<br>controls which thread runs the scheduled script |
| `-priority` | EventPriority | Scheduling priority relative to other events;<br>defaults to `Idle` for idle events, `After` for timed events |
| `-flags` | EventFlags | Event behavior flags (e.g., error handling);<br>defaults to `None` |

</details>

<details>
<summary><code>[array copy]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-deep` | -- | Perform deep copy: for System.Array-backed variables,<br>creates a new array instance with copied data;<br>without this, both variables share the same underlying storage |
| `-nosignal` | -- | Suppress the variable "dirty" signal<br>(`EntityOps.SignalDirty`) that normally notifies<br>observers of the change |

</details>

<details>
<summary><code>[array random]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-strict` | -- | Return error if array is empty<br>instead of empty string |
| `-pair` | -- | Return a two-element list `{name value}`<br>instead of just the name |
| `-valueonly` | -- | Return only the value of<br>the randomly selected element |
| `-matchname` | -- | When a pattern argument is given,<br>match it against element names/keys |
| `-matchvalue` | -- | When a pattern argument is given,<br>match it against element values |

</details>

<details>
<summary><code>[base64 decode]</code> and <code>[base64 encode]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for byte-to-string<br>conversion (decode) or string-to-byte<br>conversion (encode); defaults to binary encoding |

</details>

<details>
<summary><code>[clock days]</code> / <code>[clock buildnumber]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Date format string for parsing<br>the input date value |
| `-epoch` | DateTime | Reference point for calculating elapsed days;<br>defaults to start of year (`days`) or<br>`TimeOps.BuildEpoch` (`buildnumber`) |
| `-gmt` | boolean | When true, interpret times as UTC;<br>when false, use local time |

</details>

<details>
<summary><code>[clock clicks]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-microseconds` | -- | Return high-resolution CPU tick count<br>in microseconds via `PerformanceOps.GetMicroseconds()` |
| `-milliseconds` | -- | Return system tick count in milliseconds<br>via `PerformanceOps.GetTickCount()` |

When neither flag is specified, returns the highest-resolution counter available
via `PerformanceOps.GetCount()`.

</details>

<details>
<summary><code>[clock duration]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | DurationFlags | Controls output format; when<br>`DurationFlags.Human` is set, returns<br>human-readable text like "2 days, 3 hours";<br>otherwise returns raw TimeSpan |

</details>

<details>
<summary><code>[clock filetime]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Output format string; when present, formats<br>via `FormatOps.TclClockDateTime()`;<br>when absent, returns raw DateTime |
| `-epoch` | DateTime | Reference epoch;<br>defaults to `TimeOps.UnixEpoch` |
| `-gmt` | boolean | When true, uses `DateTime.FromFileTimeUtc()`;<br>when false, uses `DateTime.FromFileTime()` |

</details>

<details>
<summary><code>[clock format]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Custom format string; when present,<br>formats via `FormatOps.TclClockDateTime()` |
| `-kind` | DateTimeKind | Interpretation of the input clock value<br>(UTC vs Local vs Unspecified) |
| `-ticks` | -- | Interpret input as .NET ticks<br>instead of Unix seconds |
| `-epoch` | DateTime | Reference epoch for calculations;<br>defaults to `TimeOps.UnixEpoch` |
| `-gmt` | boolean | When true, interpret and format as UTC |
| `-iso` | -- | Return ISO 8601 format |
| `-full` | -- | With `-iso`, use full ISO format instead of compact |
| `-isotimezone` | -- | With `-iso`, include timezone designator |

</details>

<details>
<summary><code>[clock now]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-gmt` | boolean | When true, return UTC DateTime ticks;<br>when false, return local DateTime ticks |

</details>

<details>
<summary><code>[clock scan]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Date format string for parsing input |
| `-base` | int64 | Legacy Tcl compatibility;<br>accepted but **not used** in Eagle |
| `-epoch` | DateTime | Reference epoch for converting parsed<br>DateTime to seconds;<br>defaults to `TimeOps.UnixEpoch` |
| `-gmt` | boolean | When true, treat input as UTC;<br>when false, treat as local time |

</details>

<details>
<summary><code>[debug break]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Target a specific child interpreter<br>for the breakpoint |
| `-ignoreenabled` | -- | Break even if the debugger<br>is currently disabled |
| `-complain` | -- | Show detailed error information<br>on break failure |
| `-nocomplain` | -- | Suppress error information<br>on break failure |
| `-noerror` | -- | Don't set error return code<br>on break failure |

</details>

<details>
<summary><code>[debug emergency]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Target a specific child interpreter |
| `-ignoreenabled` | -- | Proceed even if the debugger<br>is currently disabled |
| `-nocomplain` | -- | Suppress error information |
| `-noerror` | -- | Don't set error return code on failure |

</details>

<details>
<summary><code>[debug hook]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-type` | TestHookType | Which test hook type to install;<br>defaults to `TestHookType.Default` |
| `-unset` | boolean | When true, remove the hook<br>instead of installing it |

</details>

<details>
<summary><code>[debug iqueue]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-dump` | -- | Dump the interactive command queue contents |
| `-clear` | -- | Clear the interactive command queue |

</details>

<details>
<summary><code>[debug log]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-level` | int | Log severity level |
| `-category` | string | Log category name for filtering |

</details>

<details>
<summary><code>[debug secureeval]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-timeout` | int | Timeout in milliseconds<br>for the sandboxed evaluation |
| `-nocancel` | boolean | Don't honor cancellation requests<br>during evaluation |
| `-globalcancel` | boolean | Use global cancellation flag<br>instead of per-interpreter |
| `-stoponerror` | boolean | Stop execution on first error |
| `-file` | boolean | Treat the script argument<br>as a file path |
| `-trusted` | boolean | Evaluate in a trusted context |
| `-events` | boolean | Process events during evaluation |
| `-noisolatedplugins` | boolean | Disable isolated plugin loading<br>in the sandbox |

</details>

<details>
<summary><code>[debug set]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-reference` | int | Reference count adjustment<br>for the object |
| `-convert` | boolean | Convert the value before setting |

</details>

<details>
<summary><code>[debug shell]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Which interpreter runs<br>the debug shell |
| `-initialize` | boolean | Initialize the shell environment<br>before entering |
| `-loop` | boolean | Enter the interactive loop<br>(vs. single evaluation) |
| `-asynchronous` | boolean | Run the debug shell asynchronously<br>on a separate thread |

</details>

<details>
<summary><code>[debug subst]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nobackslashes` | -- | Don't process backslash substitutions |
| `-nocommands` | -- | Don't process `[command]` substitutions |
| `-novariables` | -- | Don't process `$variable` substitutions |

</details>

<details>
<summary><code>[debug trace]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-noresult` | boolean | Suppress result display<br>in trace output |
| `-default` | boolean | Reset trace listeners to defaults |
| `-console` | boolean | Enable/disable console<br>trace listener |
| `-native` | boolean | Enable/disable native (OS)<br>trace listener |
| `-statusform` | boolean | Enable/disable status form<br>trace listener |
| `-debug` | boolean | Enable/disable debug<br>trace listener |
| `-raw` | boolean | Raw trace output<br>without formatting |
| `-log` | boolean | Enable/disable log file<br>trace output |
| `-resetsystem` | boolean | Reset the system trace source |
| `-resetlisteners` | boolean | Reset all trace listeners |
| `-forceenabled` | boolean | Force trace output even<br>if normally disabled |
| `-overrideenvironment` | boolean | Override environment-based<br>trace configuration |
| `-enabledcategories` | list | List of trace categories<br>to enable |
| `-disabledcategories` | list | List of trace categories<br>to disable |
| `-penaltycategories` | list | Categories that receive<br>penalty scoring |
| `-bonuscategories` | list | Categories that receive<br>bonus scoring |
| `-statetypes` | TraceStateType | Which trace state types to configure;<br>defaults to `TraceCommand` |
| `-priority` | TracePriority | Minimum priority level for trace output;<br>defaults to `TraceOps.GetTracePriority()` |
| `-priorities` | TracePriority | Combined priority flags;<br>defaults to `TraceOps.GetTracePriorities()` |
| `-category` | string | Set the default trace category |
| `-logname` | string | Log file name (TEST builds only) |
| `-logfilename` | string | Log file path (TEST builds only) |
| `-logflags` | LogFlags | Log behavior flags (TEST builds only);<br>defaults to `LogFlags.Default` |

</details>

<details>
<summary><code>[debug variable]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-searches` | -- | Include variable search information<br>in output |
| `-elements` | -- | Include array element information |
| `-links` | -- | Include variable link/alias information |
| `-empty` | -- | Include empty/unset variables |

</details>

<details>
<summary><code>[exit]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-message` | string | Exit message displayed to the user |
| `-force` | -- | Force exit even if normally<br>prevented by the host |
| `-fail` | -- | Mark exit as a failure<br>(affects exit code handling) |
| `-nodispose` | -- | Skip interpreter disposal on exit |
| `-nocomplain` | -- | Suppress warning/error messages<br>during exit |
| `-current` | -- | Use the interpreter's current exit code<br>instead of the default success code |

</details>

<details>
<summary><code>[fconfigure]</code> (set mode)</summary>

Used when 4+ arguments: `fconfigure channelId -option value ...`

| Option | Value | Description |
|--------|-------|-------------|
| `-blocking` | boolean | Set channel blocking mode |
| `-buffer` | boolean | When true, enable buffering<br>(`channel.NewBuffered()`);<br>when false, disable it<br>(`channel.ResetBuffered()`) |
| `-encoding` | Encoding | Set the channel's character encoding |
| `-translation` | list | One or two `StreamTranslation` values<br>controlling line-ending translation<br>(input and/or output) |

</details>

<details>
<summary><code>[fconfigure]</code> (query mode)</summary>

Used when exactly 3 arguments: `fconfigure channelId -option`

| Option | Value | Description |
|--------|-------|-------------|
| `-blocking` | -- | Query current blocking mode (returns boolean) |
| `-encoding` | -- | Query current encoding<br>(returns encoding WebName or null marker) |
| `-error` | -- | Query the asynchronous connection error for a socket channel;<br>empty while pending or after success, stable and non-empty after failure |
| `-translation` | -- | Query current translation mode |

Note: In query mode, `-buffer` is not available. Option flags differ from set
mode (e.g., `-encoding` uses `OptionFlags.None` instead of
`MustHaveEncodingValue`).

</details>

<details>
<summary><code>[fcopy]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-size` | int | Maximum bytes to copy; when negative<br>or absent, copies until end-of-file |
| `-command` | string | Callback command for async copy;<br>currently **accepted but not implemented** |
| `-eventflags` | EventFlags | Controls event processing during<br>the copy loop;<br>defaults to `interpreter.EngineEventFlags` |

</details>

<details>
<summary><code>[file cleanup]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-type` | PathType | Type of paths to clean up;<br>defaults to `PathType.Cleanup` |
| `-pattern` | string | Filter cleanup paths by<br>wildcard/regex pattern |
| `-nocase` | -- | Case-insensitive pattern matching |
| `-recursive` | -- | Recursively clean subdirectories |
| `-force` | -- | Force cleanup even if paths are in use |
| `-nocomplain` | -- | Suppress errors for missing paths |
| `-now` | -- | Execute cleanup immediately<br>instead of deferring |

</details>

<details>
<summary><code>[file copy]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-force` | -- | Overwrite destination if it already exists |

</details>

<details>
<summary><code>[file delete]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-recursive` | -- | Delete directories recursively |
| `-force` | -- | Ignore access errors during deletion |
| `-nocomplain` | -- | Suppress "file not found" errors |

</details>

<details>
<summary><code>[file glob]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nocomplain` | -- | Don't error if no files match |
| `-noresolve` | -- | Don't resolve paths to absolute form |
| `-novalidate` | -- | Don't validate that the directory exists |
| `-match` | MatchMode | Matching mode (Glob, Exact, Regexp,<br>SubString); defaults to<br>`StringOps.DefaultMatchMode` |
| `-nocase` | -- | Case-insensitive pattern matching |
| `-directory` | string | Search in this directory instead<br>of current working directory |
| `-searchpattern` | string | Pattern for the initial<br>filesystem enumeration |

</details>

<details>
<summary><code>[file information]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-directory` | boolean | Explicitly specify whether the path<br>is a directory (Windows) |
| `-reparse` | boolean | Follow reparse points such as<br>junctions and symlinks (Windows) |

</details>

<details>
<summary><code>[file normalize]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-legacy` | boolean | Use legacy path normalization<br>for Eagle beta compatibility |

</details>

<details>
<summary><code>[file objectid]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-directory` | boolean | Explicitly specify whether the path<br>is a directory (Windows) |
| `-create` | boolean | Create the object ID if it does<br>not already exist (Windows) |

</details>

<details>
<summary><code>[file rename]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-force` | -- | Overwrite destination if it already exists |

</details>

<details>
<summary><code>[file sddl]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | SddlFlags | Controls which ACL entries to include<br>and output format; supports<br>`IncludeExplicit`, `IncludeInherited`,<br>`SkipBadRights`, `Remove`, `ToList`;<br>defaults to `SddlFlags.Default` |

</details>

<details>
<summary><code>[file under]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-mode` | MatchMode | How to match paths;<br>defaults to `MatchMode.None` |
| `-searchoption` | SearchOption | `TopDirectoryOnly` or `AllDirectories`;<br>defaults to `AllDirectories` |
| `-pathtype` | PathType | How to interpret/normalize paths;<br>defaults to `PathType.Under` |
| `-contains` | -- | Return list of matching items<br>under the path instead of a boolean |
| `-failonerror` | -- | Treat filesystem enumeration errors<br>as failures |

</details>

<details>
<summary><code>[file version]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-full` | -- | Return the complete<br>`FileVersionInfo` string |
| `-fixed` | -- | Return the fixed version number<br>(major.minor.build.revision) |

</details>

<details>
<summary><code>[fileevent]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-priority` | EventPriority | Event-manager priority for a newly installed non-empty script;<br>defaults to `QueueScript` and is invalid for query or clear mode |

</details>

<details>
<summary><code>[gets]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for channel I/O |
| `-usecount` | -- | Read a count-prefixed record<br>(first N bytes specify data length) |
| `-noblock` | -- | Non-blocking read; return immediately<br>if no data is available |
| `-keepeol` | boolean | Keep end-of-line characters<br>in the result |
| `-count` | int | Read exactly N bytes/characters |

</details>

<details>
<summary><code>[glob]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-path` | string | Prepend this path prefix to all results;<br>conflicts with `-directory` |
| `-directory` | string | Search in this directory;<br>conflicts with `-path` |
| `-types` | list | File type filter dictionary |
| `-join` | -- | Join multiple pattern arguments<br>before matching |
| `-tails` | -- | Return only filenames, not full paths<br>(requires `-path` or `-directory`) |
| `-nocomplain` | -- | Don't error if no files match<br>the pattern |
| `-noerror` | -- | Return empty on glob errors<br>instead of raising an error |

</details>

<details>
<summary><code>[hash keyed]</code>, <code>[hash mac]</code>, <code>[hash normal]</code></summary>

All three sub-commands share identical options:

| Option | Value | Description |
|--------|-------|-------------|
| `-object` | -- | Input is an opaque object handle<br>(byte array) instead of a string |
| `-raw` | -- | Return hash as raw ByteList<br>instead of hexadecimal string |
| `-filename` | -- | Treat the input argument as a file path<br>and hash the file contents |
| `-encoding` | Encoding | Character encoding for string-to-bytes<br>conversion; cannot combine with `-object` |

</details>

<details>
<summary><code>[host beep]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-frequency` | int | Beep frequency in Hz |
| `-duration` | int | Beep duration in milliseconds |

</details>

<details>
<summary><code>[host color]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-fg` / `-foreground` | ConsoleColor | Set foreground console color |
| `-bg` / `-background` | ConsoleColor | Set background console color |

</details>

<details>
<summary><code>[host font]</code></summary>

Only available when `CONSOLE && NATIVE && WINDOWS` is compiled in.

| Option | Value | Description |
|--------|-------|-------------|
| `-facename` | string | Font face name for the console window |
| `-fontsize` | short | Font size in points |
| `-save` | boolean | Save font settings before changing |
| `-restore` | boolean | Restore previously saved font settings |

</details>

<details>
<summary><code>[host namedcolor]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-theme` | string | Color theme name |
| `-name` | string | Named color within the theme |
| `-fg` / `-foreground` | ConsoleColor | Override foreground color |
| `-bg` / `-background` | ConsoleColor | Override background color |

</details>

<details>
<summary><code>[host position]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-x` | int | Set absolute cursor X position |
| `-relx` | int | Adjust X position relative to current |
| `-y` | int | Set absolute cursor Y position |
| `-rely` | int | Adjust Y position relative to current |

</details>

<details>
<summary><code>[host reset]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-sizetype` | HostSizeType | Which size dimension to reset<br>(Default, Buffer, Window) |
| `-all` | -- | Reset all host state |
| `-channels` | -- | Reset standard I/O channels |
| `-flags` | -- | Reset host flags |
| `-history` | -- | Reset command history |
| `-interface` | -- | Reset host interface |
| `-input` | -- | Reset input channel |
| `-output` | -- | Reset output channel |
| `-error` | -- | Reset error channel |
| `-size` | -- | Reset window size |
| `-position` | -- | Reset cursor position |
| `-colors` | -- | Reset console colors |

</details>

<details>
<summary><code>[host size]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-sizetype` | HostSizeType | Which size to get/set<br>(Default, Buffer, Window) |
| `-norestore` | -- | Don't restore original size<br>if setting a new size fails |
| `-width` | int | Set absolute width in columns |
| `-relwidth` | int | Adjust width relative to current |
| `-height` | int | Set absolute height in rows |
| `-relheight` | int | Adjust height relative to current |

</details>

<details>
<summary><code>[host writebox]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-theme` | string | Color theme for box rendering |
| `-name` | string | Box style/layout name |
| `-x` / `-relx` | int | Absolute / relative X position<br>for the box |
| `-y` / `-rely` | int | Absolute / relative Y position<br>for the box |
| `-fg` / `-foreground` | ConsoleColor | Text foreground color |
| `-bg` / `-background` | ConsoleColor | Text background color |
| `-boxfg` / `-boxforeground` | ConsoleColor | Box border foreground color |
| `-boxbg` / `-boxbackground` | ConsoleColor | Box border background color |
| `-nohandle` | -- | Don't interpret the argument<br>as an object handle |
| `-multiple` | -- | Treat the argument as a list of items;<br>write each one |
| `-noposition` | -- | Don't query current cursor position;<br>use (0,0) |
| `-noboxcolors` | -- | Don't apply box-specific colors |
| `-nocolors` | -- | Don't apply any colors |
| `-pairs` | -- | Parse the list as key-value pairs |
| `-newline` | -- | Write a newline after the box |
| `-separator` | -- | Convert "null" strings<br>to actual nulls |
| `-norestore` | -- | Don't restore original colors<br>after drawing |

</details>

<details>
<summary><code>[info commands]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Query a specific child interpreter |
| `-sdk` | SdkType | SDK filter (Default, Tcl, Snit, etc.);<br>defaults to `SdkType.Default` |
| `-breakpoint` | -- | Include breakpoint commands |
| `-core` | -- | Include core/system commands |
| `-library` | -- | Include library-defined commands |
| `-nocore` | -- | Exclude core/system commands |
| `-nolibrary` | -- | Exclude library-defined commands |
| `-interactive` | -- | Include interactive-only commands |
| `-nocommands` | -- | Exclude regular commands (show only<br>procedures, aliases, etc.) |
| `-noprocedures` | -- | Exclude user-defined procedures |
| `-noexecutes` | -- | Exclude execute-type procedures |
| `-noaliases` | -- | Exclude command aliases |
| `-safe` | -- | Include only commands safe<br>for sandboxed interpreters |
| `-unsafe` | -- | Include only unsafe commands |
| `-standard` | -- | Include only standard commands |
| `-nonstandard` | -- | Include only non-standard<br>(extension) commands |
| `-hidden` | -- | Include hidden commands |
| `-hiddenonly` | -- | Show only hidden commands |
| `-strict` | -- | Use strict filtering rules |

</details>

<details>
<summary><code>[info functions]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Query a specific child interpreter |
| `-safe` / `-unsafe` | -- | Filter by safe/unsafe<br>classification |
| `-standard` / `-nonstandard` | -- | Filter by standard/non-standard<br>classification |
| `-hidden` | -- | Include hidden functions |

</details>

<details>
<summary><code>[info loaded]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nocore` | -- | Exclude core/system plugins<br>(those with `PluginFlags.System`) |

</details>

<details>
<summary><code>[info operators]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Query a specific child interpreter |
| `-standard` / `-nonstandard` | -- | Filter by standard/non-standard classification |
| `-hidden` | -- | Include hidden operators |

</details>

<details>
<summary><code>[info subcommands]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-hidden` | boolean | When true, search hidden commands;<br>when false, search visible commands |

</details>

<details>
<summary><code>[info vars]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Query a specific child interpreter |

</details>

<details>
<summary><code>[interp addcommands]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-createflags` | CreateFlags | Override interpreter creation flags<br>for command population |
| `-interpreterflags` | InterpreterFlags | Override interpreter flags |
| `-ruleset` | IRuleSet | Custom rule set for security validation<br>of added commands |
| `-safetyoverride` | -- | Override safe interpreter restrictions<br>when adding commands |
| `-repopulate` | -- | Remove existing commands<br>before adding new ones |

</details>

<details>
<summary><code>[interp cancel]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-global` | -- | Cancel all interpreters,<br>not just the target |
| `-nolocal` | -- | Skip canceling the local interpreter |
| `-unwind` | -- | Unwind the call stack<br>during cancellation |

</details>

<details>
<summary><code>[interp create]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-creationflagtypes` | CreationFlagTypes | Which sets of creation flags to apply;<br>defaults to `Defaults.CreationFlagTypes` |
| `-ruleset` | IRuleSet | Security rule set<br>for the new interpreter |
| `-peer` | PeerType | Peer relationship type;<br>defaults to `PeerType.Default` |
| `-namespaces` | -- | Enable namespace support<br>in the new interpreter |
| `-nocommands` | -- | Don't populate standard commands |
| `-nofunctions` | -- | Don't populate standard functions |
| `-nonamespaces` | -- | Don't create default namespaces |
| `-novariables` | -- | Don't create standard variables |
| `-noloader` | -- | Don't initialize<br>the script/plugin loader |
| `-noinitialize` | -- | Skip interpreter initialization entirely |
| `-alias` | -- | Create a command alias<br>for the new interpreter |
| `-safe` | -- | Create a safe (sandboxed) interpreter |
| `-sdk` | SdkType | SDK type for the interpreter<br>(DEBUG builds only) |
| `-nohidden` | -- | Don't hide unsafe commands<br>in the new interpreter |
| `-standard` | -- | Use standard command set only |
| `-unsafeinitialize` | -- | Allow unsafe initialization steps |
| `-isolated` | -- | Create in an isolated AppDomain<br>(requires `ISOLATED_INTERPRETERS`) |
| `-debug` | -- | Enable debugger in the new interpreter<br>(requires `DEBUGGER`) |
| `-test` | -- | Enable test mode<br>(requires `TEST_PLUGIN` or `DEBUG`) |
| `-monitor` | -- | Enable notification monitoring<br>(requires `NOTIFY && NOTIFY_ARGUMENTS`) |
| `-probing` | -- | Enable assembly probing paths<br>(requires `APPDOMAINS`) |
| `-noprobing` | -- | Disable assembly probing paths |
| `-security` | -- | Enable security subsystem |
| `-nosecurity` | -- | Disable security subsystem |
| `-nocorepolicies` | -- | Don't install core security policies |
| `-nopluginpolicies` | -- | Don't install plugin<br>security policies |

</details>

<details>
<summary><code>[interp invokehidden]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-global` | -- | Invoke in the global namespace |
| `-namespace` | string | Invoke in the specified<br>fully-qualified namespace |

</details>

<details>
<summary><code>[interp policy]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-type` | Type | .NET type of the policy callback |
| `-token` | int64 | Security token for policy authorization |
| `-flags` | PolicyFlags | Policy behavior flags;<br>defaults to `PolicyFlags.Script` |

</details>

<details>
<summary><code>[interp queue]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-when` | DateTime | Schedule the queued script<br>for a specific time |

</details>

<details>
<summary><code>[interp readorgetscriptfile]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for reading<br>the script file |
| `-variable` | string | Store the script content in this<br>variable instead of evaluating |
| `-package` | boolean | Treat the file as a package script |
| `-scriptflags` | ScriptFlags | Override script evaluation flags;<br>defaults to child interpreter's current flags |
| `-engineflags` | EngineFlags | Override engine flags;<br>defaults to child interpreter's current flags |

This is the most complex option processing pattern in the library. See
[Section 7.2](#72-scan-then-get-deferred-defaults) for the scan-then-get
architecture.

</details>

<details>
<summary><code>[interp rename]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nodelete` | -- | Keep the original name<br>(create a copy, not a rename) |
| `-all` | -- | Rename all matching identifiers |
| `-hidden` | -- | Make the new name hidden from enumeration |
| `-hiddenonly` | -- | Make both old and new names hidden |
| `-kind` | IdentifierKind | Type of identifier to rename<br>(Command, Function, Variable, etc.);<br>defaults to `None` |
| `-newnamevar` | string | Store the actual new name<br>in this variable |

</details>

<details>
<summary><code>[interp resetcancel]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-global` | -- | Reset cancellation<br>for all interpreters |
| `-nolocal` | -- | Skip resetting the local interpreter |
| `-force` | -- | Force reset even if cancellation<br>is locked |

</details>

<details>
<summary><code>[interp service]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-dedicated` | -- | Use a dedicated service thread |
| `-nocancel` | -- | Don't honor cancellation<br>during servicing |
| `-noglobalcancel` | -- | Ignore global cancellation flag |
| `-erroronempty` | -- | Return error when the event queue<br>is empty |
| `-userinterface` | -- | Process user interface events |
| `-nocomplain` | -- | Suppress service errors |
| `-thread` | int64 | Target thread for event servicing |
| `-limit` | int | Maximum number of events<br>to process per call |
| `-eventflags` | EventFlags | Event processing flags; defaults to<br>child interpreter's `ServiceEventFlags` |
| `-priority` | EventPriority | Minimum event priority to process;<br>defaults to `EventPriority.Service` |

</details>

<details>
<summary><code>[interp source]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| (only `--`) | | End-of-options marker is the sole option |

</details>

<details>
<summary><code>[interp stub]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-ensemble` | -- | Create an ensemble stub (with sub-command dispatch) |
| `-external` | -- | Create an external command stub |

</details>

<details>
<summary><code>[interp subcommand]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | SubCommandFlags | Sub-command registration flags;<br>defaults to `SubCommandFlags.Default` |

</details>

<details>
<summary><code>[interp subst]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nobackslashes` | -- | Don't process backslash substitutions |
| `-nocommands` | -- | Don't process `[command]` substitutions |
| `-novariables` | -- | Don't process `$variable` substitutions |

</details>

<details>
<summary><code>[kill]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-all` | -- | Kill all processes matching<br>the given name, not just one |
| `-force` | -- | Force termination<br>without graceful shutdown |
| `-whatIf` | -- | Show what would be killed<br>without actually terminating<br>(case-insensitive option name) |
| `-verbose` | -- | Display detailed information<br>about the operation |

</details>

<details>
<summary><code>[library declare]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-alias` | -- | Create an alias<br>for the declared function |
| `-module` | string | Module containing<br>the native function |
| `-functionname` | string | Override the function name |
| `-address` | int64 | Direct memory address<br>of the function |
| `-returntype` | Type | .NET return type of the function |
| `-parametertypes` | Type list | .NET types of all function parameters |
| `-callingconvention` | CallingConvention | Calling convention<br>(Cdecl, StdCall, etc.) |
| `-assemblyname` | string | Assembly name<br>for the generated delegate |
| `-modulename` | string | Module builder name |
| `-typename` | string | Type name for the generated<br>delegate wrapper |
| `-bestfitmapping` | boolean | Enable best-fit character mapping<br>for Unicode conversion |
| `-charset` | CharSet | Character set<br>for P/Invoke marshaling |
| `-setlasterror` | boolean | Preserve Windows<br>`GetLastError()` codes |
| `-throwonunmappablechar` | boolean | Throw on unmappable<br>Unicode characters |
| `-delegatename` | string | Name for the created delegate type |

</details>

<details>
<summary><code>[library load]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-modulename` | string | Native library module name |
| `-locked` | -- | Lock the module in memory,<br>preventing unloading |
| `-maybetrustedonly` | -- | Only load if verified trusted<br>(lenient) |
| `-trustedonly` | -- | Only load modules verified<br>as trusted |
| `-flags` | ModuleFlags | Module loading behavior flags;<br>defaults to `ModuleFlags.None` |

</details>

<details>
<summary><code>[library resolve]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-module` | string | Which loaded module contains<br>the function |
| `-functionname` | string | Function name to resolve<br>within the module |

</details>

<details>
<summary><code>[library unresolve]</code></summary>

No options (only end-of-options marker).

</details>

<details>
<summary><code>[load]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-ruleset` | IRuleSet | Custom rule set for plugin<br>security validation |
| `-needclientdata` | -- | Auto-create client data<br>if not provided by caller |
| `-anythread` | -- | Allow loading on any thread,<br>not just the main thread |
| `-nocommands` | -- | Don't register commands<br>defined by the plugin |
| `-nofunctions` | -- | Don't register functions<br>defined by the plugin |
| `-nopolicies` | -- | Don't install security policies<br>from the plugin |
| `-notraces` | -- | Don't install trace callbacks<br>from the plugin |
| `-noprovide` | -- | Don't call the plugin's<br>`Provide` method |
| `-noresources` | -- | Don't load resource definitions |
| `-verifiedonly` | -- | Only load plugins with verified<br>digital signatures |
| `-maybeverifiedonly` | -- | Verified-only (lenient;<br>allowed in safe interpreters) |
| `-trustedonly` | -- | Only load plugins<br>in the trusted set |
| `-maybetrustedonly` | -- | Trusted-only (lenient;<br>allowed in safe interpreters) |
| `-publickeytoken` | string | Verify the plugin's public key<br>token matches |
| `-isolated` / `-noisolated` | -- | Load into isolated /<br>default AppDomain |
| `-preview` / `-nopreview` | -- | Enable/disable plugin metadata<br>preview for update checking |
| `-update` / `-noupdate` | -- | Check/skip checking for<br>updated plugin version |
| `-clientdata` | object | Supply custom client data object |
| `-data` | object | Additional data to associate<br>with the plugin |
| `-viaresource` | -- | Load from embedded resource<br>instead of file |

</details>

<details>
<summary><code>[lsearch]</code></summary>

**Mutual-exclusion groups:**

| Group | Options | Description |
|-------|---------|-------------|
| 1 (value type) | `-ascii`, `-dictionary`, `-integer`, `-real` | How to interpret list elements<br>for comparison |
| 2 (sort order) | `-decreasing`, `-increasing` | Sort direction for<br>`-sorted` mode |
| 3 (match mode) | `-exact`, `-substring`, `-glob`, `-regexp`, `-sorted` | How to match the pattern<br>against elements |

| Option | Value | Description |
|--------|-------|-------------|
| `-variable` | -- | First argument is a variable name<br>containing the list |
| `-inverse` | -- | Return indices of<br>non-matching elements |
| `-subindices` | -- | Return sub-indices when<br>searching nested lists |
| `-all` | -- | Return all matching indices<br>instead of just the first |
| `-inline` | -- | Return matched elements<br>instead of their indices |
| `-nocase` | -- | Case-insensitive matching |
| `-not` | -- | Logical inversion of the match result |
| `-start` | string | Start searching from this index |
| `-index` | string | Search within sub-elements at this index |

</details>

<details>
<summary><code>[lsort]</code></summary>

**Mutual-exclusion groups:**

| Group | Options | Description |
|-------|---------|-------------|
| 1 (sort type) | `-ascii`, `-dictionary`, `-integer`, `-random`, `-real` | How to compare elements |
| 2 (sort order) | `-increasing`, `-decreasing` | Sort direction |

| Option | Value | Description |
|--------|-------|-------------|
| `-nocase` | -- | Case-insensitive sorting |
| `-unique` | -- | Remove duplicate elements after sorting |
| `-command` | string | Custom comparison command/procedure |
| `-index` | string | Sort by sub-elements at this index in nested lists |

</details>

<details>
<summary><code>[namespace export]</code> (Namespace1 and Namespace2)</summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-clear` | -- | Clear existing exports before adding new ones |

</details>

<details>
<summary><code>[namespace import]</code> (Namespace1 and Namespace2)</summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-force` | -- | Overwrite existing commands with imported names |

</details>

<details>
<summary><code>[namespace which]</code> (Namespace1 and Namespace2)</summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-command` | -- | Search for command names |
| `-variable` | -- | Search for variable names |

</details>

<details>
<summary><code>[object alias]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-objecttypes` | Type list | Resolve the object against<br>these .NET types |
| `-aliasname` | string | Name for the command alias |
| `-aliasraw` | -- | Use raw dispatch for the alias |
| `-aliasall` | -- | Use invokeall dispatch for the alias |
| `-aliasreference` | -- | Use reference-counted handle<br>for the alias |
| `-nocase` | -- | Case-insensitive type name matching |
| `-stricttype` | -- | Require exact type match<br>during object resolution |
| `-verbose` | -- | Enable verbose type resolution<br>diagnostics |

</details>

<details>
<summary><code>[object cleanup]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-pattern` | string | Match object names<br>against this pattern |
| `-referencecount` | int | Only clean up objects with this<br>specific reference count |
| `-references` | -- | Include reference-counted objects<br>in cleanup |
| `-noremove` | -- | Keep objects in the table<br>(dispose but don't remove) |
| `-synchronous` | -- | Perform disposal synchronously |
| `-nodispose` | -- | Don't call `Dispose()` on the objects |
| `-nocomplain` | -- | Suppress errors during cleanup |

</details>

<details>
<summary><code>[object create]</code></summary>

Includes [object handle management](#fixupreturnvalue-options) options
(subset), [type resolution](#83-type-resolution) options, and
[method invocation](#84-method-invocation-and-reflection) options.

| Option | Value | Description |
|--------|-------|-------------|
| `-objectname` | string | Name for the created<br>opaque object handle |
| `-type` | Type | .NET type to instantiate |
| `-objecttypes` | Type list | Additional types for resolution |
| `-methodtypes` | Type list | Constructor method<br>type constraints |
| `-parametertypes` | Type list | Constructor parameter<br>type constraints |
| `-parametermarshalflags` | MarshalFlags list | Per-parameter marshaling flags |
| `-debug` | -- | Enable debug diagnostics<br>for the creation |
| `-trace` | -- | Enable trace output<br>for the creation |
| `-argumentflags` | ByRefArgumentFlags | By-reference argument<br>handling flags |
| `-objectvalueflags` | ValueFlags | Value conversion flags<br>for object resolution |
| `-marshalflags` | MarshalFlags | Marshaling behavior flags |
| `-reorderflags` | ReorderFlags | Constructor overload<br>reordering flags |
| `-nocreate` | -- | Don't create an opaque<br>object handle |
| `-nodispose` | -- | Don't mark the object<br>for automatic disposal |
| `-noinvoke` | -- | Don't invoke the constructor<br>(type resolution only) |
| `-help` | -- | Don't invoke; return help for the<br>matching constructor overload(s) |
| `-noargs` | -- | Don't pass constructor arguments |
| `-limit` | int | Maximum number of constructor<br>overloads to consider |
| `-index` | int | Select a specific constructor<br>overload by index |
| `-alias` | -- | Create a command alias<br>for the new object |
| `-aliasraw` | -- | Use raw dispatch for the alias |
| `-aliasall` | -- | Use invokeall dispatch for the alias |
| `-aliasreference` | -- | Use reference-counted handle<br>for the alias |
| `-tcl` | TclInterpreter | Bridge the object to a Tcl interpreter<br>(requires `NATIVE && TCL`) |
| `-noforcedelete` | -- | Don't force-delete the alias<br>on cleanup |
| `-tostring` | -- | Return the `ToString()` representation<br>instead of an opaque handle |
| `-arrayasvalue` | -- | Treat array results as values<br>rather than opaque handles |
| `-arrayaslink` | -- | Link array results<br>to Eagle variables |
| `-nomutatebindingflags` | -- | Don't automatically adjust binding<br>flags for primitive/value types |
| `-stricttype` | -- | Require exact type match<br>during resolution |
| `-strictmember` | -- | Require exact constructor match |
| `-strictargs` | -- | Require exact argument count match |
| `-nocase` | -- | Case-insensitive type and<br>member name matching |
| `-default` | -- | Use default value when constructor<br>argument is missing |
| `-verbose` | -- | Enable verbose diagnostics |
| `-nobyref` | -- | Don't use by-reference<br>parameter handling |
| `-flags` | BindingFlags | .NET reflection binding flags |
| `-bindingflags` | BindingFlags | Alias for `-flags` |
| `-objectflags` | ObjectFlags | Object handle behavior flags |
| `-byrefobjectflags` | ObjectFlags | Object flags for<br>by-reference parameters |

</details>

<details>
<summary><code>[object dispose]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-synchronous` | -- | Perform disposal synchronously |
| `-nodispose` | -- | Remove the handle without<br>calling `Dispose()` |
| `-nocomplain` | -- | Suppress errors if the object<br>is not found or disposal fails |

</details>

<details>
<summary><code>[object foreach]</code></summary>

Includes [object handle management](#fixupreturnvalue-options) options
(subset).

| Option | Value | Description |
|--------|-------|-------------|
| `-synchronous` | -- | Perform disposal synchronously<br>after iteration |
| `-objectname` | string | Name for the per-iteration<br>opaque object handle |
| `-type` | Type | Expected .NET type of elements |
| `-collect` | boolean | Force garbage collection<br>after iteration |
| `-nocreate` | -- | Don't create opaque object handles<br>for elements |
| `-nodispose` | -- | Don't dispose element handles<br>after each iteration |
| `-alias` | -- | Create a command alias<br>for each element |
| `-aliasraw` | -- | Use raw dispatch<br>for element aliases |
| `-aliasall` | -- | Use invokeall dispatch<br>for element aliases |
| `-aliasreference` | -- | Use reference-counted handles<br>for element aliases |
| `-tcl` | TclInterpreter | Bridge elements to a Tcl interpreter<br>(requires `NATIVE && TCL`) |
| `-noforcedelete` | -- | Don't force-delete aliases<br>on cleanup |
| `-tostring` | -- | Use `ToString()` representation<br>for elements |
| `-nocase` | -- | Case-insensitive type name matching |
| `-objectflags` | ObjectFlags | Object handle behavior flags<br>for elements |

</details>

<details>
<summary><code>[object invoke]</code></summary>

This command's options are composed from three groups: InvokeOnly (unique to
`[object invoke]`), InvokeShared (shared with `[object invokeraw]` -- includes
[method invocation](#84-method-invocation-and-reflection),
[type resolution](#83-type-resolution), and
[DateTime](#85-datetime-and-encoding) options), and
[FixupReturnValue](#fixupreturnvalue-options)
(shared with all handle-producing commands).

**InvokeOnly options (unique to `[object invoke]`):**

| Option | Value | Description |
|--------|-------|-------------|
| `-reorderflags` | ReorderFlags | Method overload reordering flags |
| `-limit` | int | Maximum number of method<br>overloads to consider |
| `-index` | int | Select a specific method<br>overload by index |
| `-invoke` | -- | *(Ignored)* Marker for invoke mode<br>(active in `[object invokeall]`) |
| `-invokeraw` | -- | Switch to raw invoke mode |
| `-membervalueflags` | ValueFlags | Value conversion flags<br>for member resolution |
| `-nonestedmember` | -- | Don't resolve nested member paths<br>(e.g., `Prop.SubProp`) |
| `-strictmember` | -- | Require exact member match |
| `-strictargs` | -- | Require exact argument count match |
| `-membertypes` | MemberTypes | Filter by member type<br>(Method, Property, Field, etc.) |
| `-identity` | -- | Return the object identity<br>rather than invoking |
| `-typeidentity` | -- | Return the type identity<br>rather than invoking |

**InvokeShared options (shared with `[object invokeraw]`):**

| Option | Value | Description |
|--------|-------|-------------|
| `-datetimekind` | DateTimeKind | DateTime interpretation<br>for arguments |
| `-datetimestyles` | DateTimeStyles | DateTime parsing styles<br>for arguments |
| `-datetimeformat` | string | DateTime format string<br>for arguments |
| `-type` | Type | Target .NET type for static<br>member invocation |
| `-objecttype` | Type | Override the object's resolved type |
| `-proxytype` | Type | Proxy type for member dispatch |
| `-objecttypes` | Type list | Additional types for resolution |
| `-methodtypes` | Type list | Method type constraints |
| `-parametertypes` | Type list | Parameter type constraints |
| `-parametermarshalflags` | MarshalFlags list | Per-parameter marshaling flags |
| `-debug` | -- | Enable debug diagnostics |
| `-trace` | -- | Enable trace output |
| `-argumentflags` | ByRefArgumentFlags | By-reference argument<br>handling flags |
| `-marshalflags` | MarshalFlags | Marshaling behavior flags |
| `-noinvoke` | -- | Don't invoke the member<br>(resolution only) |
| `-help` | -- | Don't invoke; return help for the<br>matching member(s) |
| `-noargs` | -- | Don't pass arguments to the member |
| `-arrayasvalue` | -- | Treat array results as values |
| `-arrayaslink` | -- | Link array results<br>to Eagle variables |
| `-verbose` | -- | Enable verbose diagnostics |
| `-nocase` | -- | Case-insensitive member<br>name matching |
| `-default` | -- | Use default value when<br>argument is missing |
| `-objectvalueflags` | ValueFlags | Value conversion flags<br>for object resolution |
| `-nonestedobject` | -- | Don't resolve nested object paths |
| `-stricttype` | -- | Require exact type match |
| `-nobyref` | -- | Don't use by-reference<br>parameter handling |
| `-flags` | BindingFlags | .NET reflection binding flags |
| `-bindingflags` | BindingFlags | Alias for `-flags` |
| `-byrefobjectflags` | ObjectFlags | Object flags for<br>by-reference parameters |

Plus [FixupReturnValue](#fixupreturnvalue-options) options: `-objectname`,
`-returntype`, `-objecttype`, `-create`, `-nodispose`, `-alias`, `-aliasraw`,
`-aliasall`, `-aliasreference`, `-tcl`, `-noforcedelete`, `-tostring`,
`-objectflags`.

</details>

<details>
<summary><code>[object isoftype]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-objecttypes` | Type list | Additional types for resolution |
| `-objectvalueflags` | ValueFlags | Value conversion flags<br>for object resolution |
| `-marshalflags` | MarshalFlags | Marshaling behavior flags |
| `-nocase` | -- | Case-insensitive type name matching |
| `-stricttype` | -- | Require exact type match |
| `-verbose` | -- | Enable verbose type resolution<br>diagnostics |
| `-nocomplain` | -- | Suppress errors if the object handle<br>is invalid |
| `-assignable` | -- | Check assignability (base class/interface)<br>instead of exact type match |

</details>

<details>
<summary><code>[object load]</code></summary>

Includes [object handle management](#fixupreturnvalue-options) options
(subset).

| Option | Value | Description |
|--------|-------|-------------|
| `-namespace` | string | Target namespace<br>for imported types |
| `-objectname` | string | Name for the loaded assembly's<br>opaque object handle |
| `-type` | Type | Expected .NET type<br>within the assembly |
| `-create` | -- | Create an opaque object handle<br>for the loaded assembly |
| `-nodispose` | -- | Don't mark the assembly handle<br>for automatic disposal |
| `-alias` | -- | Create a command alias<br>for the assembly |
| `-aliasraw` | -- | Use raw dispatch for the alias |
| `-aliasall` | -- | Use invokeall dispatch for the alias |
| `-aliasreference` | -- | Use reference-counted handle<br>for the alias |
| `-tcl` | TclInterpreter | Bridge the assembly to a Tcl<br>interpreter (requires `NATIVE && TCL`) |
| `-reflectiononly` | -- | Load assembly in<br>reflection-only context |
| `-fromobject` | -- | Load assembly from an existing<br>opaque object handle |
| `-noforcedelete` | -- | Don't force-delete the alias<br>on cleanup |
| `-tostring` | -- | Return the `ToString()` representation |
| `-import` | -- | Import public types from the assembly<br>into the current namespace |
| `-importnonpublic` | -- | Also import non-public types |
| `-importmode` | MatchMode | Matching mode for import<br>type filtering |
| `-importpattern` | string | Pattern for filtering<br>imported type names |
| `-importnocase` | -- | Case-insensitive import<br>pattern matching |
| `-declare` | -- | Declare types from the assembly<br>for simplified access |
| `-declarenonpublic` | -- | Also declare non-public types |
| `-declaremode` | MatchMode | Matching mode for declare<br>type filtering |
| `-declarepattern` | string | Pattern for filtering<br>declared type names |
| `-declarenocase` | -- | Case-insensitive declare<br>pattern matching |
| `-loadtype` | LoadType | Assembly loading strategy<br>(e.g., File, Name) |
| `-objectflags` | ObjectFlags | Object handle behavior flags |
| `-trustedonly` | -- | Only load trusted assemblies |
| `-maybetrustedonly` | -- | Trusted-only (lenient) |
| `-verifiedonly` | -- | Only load assemblies with<br>verified digital signatures |
| `-maybeverifiedonly` | -- | Verified-only (lenient) |

</details>

<details>
<summary><code>[object members]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-mode` | MatchMode | Pattern matching mode<br>(Glob, Exact, Regexp, SubString) |
| `-type` | Type | .NET type to enumerate members from |
| `-objecttypes` | Type list | Additional types for resolution |
| `-pattern` | string | Filter member names by pattern |
| `-attributes` | -- | Include custom attribute information<br>in output |
| `-nocase` | -- | Case-insensitive pattern matching |
| `-stricttype` | -- | Require exact type match<br>during resolution |
| `-verbose` | -- | Enable verbose diagnostics |
| `-signatures` | -- | Include full method signatures<br>in output |
| `-qualified` | -- | Use fully qualified type names<br>in output |
| `-matchnameonly` | -- | Match the pattern against member<br>names only (not signatures) |
| `-nameonly` | -- | Return member names only<br>(not full details) |
| `-membertypes` | MemberTypes | Filter by member type<br>(Method, Property, Field, Event, etc.) |
| `-flags` | BindingFlags | .NET reflection binding flags |
| `-bindingflags` | BindingFlags | Alias for `-flags` |
| `-objectvalueflags` | ValueFlags | Value conversion flags<br>for object resolution |
| `-marshalflags` | MarshalFlags | Marshaling behavior flags |

</details>

<details>
<summary><code>[object search]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-objecttypes` | Type list | Filter results by<br>these .NET types |
| `-objectvalueflags` | ValueFlags | Value conversion flags<br>for object resolution |
| `-marshalflags` | MarshalFlags | Marshaling behavior flags |
| `-noshowname` | -- | Don't include object names in output |
| `-nonamespace` | -- | Don't include namespace information |
| `-noassembly` | -- | Don't include assembly information |
| `-noexception` | -- | Suppress exceptions during search |
| `-fullname` | -- | Use fully qualified names in output |
| `-nocase` | -- | Case-insensitive matching |
| `-stricttype` | -- | Require exact type match |
| `-verbose` | -- | Enable verbose diagnostics |

</details>

<details>
<summary><code>[open]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-stdin` / `-stdout` / `-stderr` | -- | Open the corresponding standard stream<br>(mutually exclusive; requires `CONSOLE`) |
| `-channelid` | string | Assign a custom identifier<br>to the opened channel |
| `-buffersize` | int | Internal buffer size for the channel |
| `-nullencoding` | -- | Use null encoding mode |
| `-autoflush` | -- | Automatically flush after every write |
| `-rawendofstream` | -- | Raw end-of-stream behavior<br>without platform filtering |
| `-streamflags` | HostStreamFlags | Stream behavior flags;<br>defaults to `HostStreamFlags.Default` |
| `-options` | FileOptions | File opening options;<br>defaults to `FileOptions.None` |
| `-share` | FileShare | File sharing mode;<br>defaults to `FileShare.Read` |

</details>

<details>
<summary><code>[package absent]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-exact` | -- | Require exact version match |

</details>

<details>
<summary><code>[package alias]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-overwrite` | -- | Overwrite an existing package alias |
| `-disabled` | -- | Create the alias in a disabled state |
| `-exact` | -- | Exact name matching |

</details>

<details>
<summary><code>[package present]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-exact` | -- | Require exact version match |

</details>

<details>
<summary><code>[package require]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-exact` | -- | Require exact version match<br>(no "compatible" version resolution) |
| `-autoscan` | boolean | Automatically scan for packages<br>if not already found |

</details>

<details>
<summary><code>[package scan]</code></summary>

See [Section 7.1](#71-two-pass-option-processing) for the two-pass
architecture. Pre-options and main options are separate dictionaries.

**Pre-options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | -- | Use the specified child interpreter's<br>flags as defaults |

**Main options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | PackageIndexFlags | Override package index scanning flags;<br>defaults to interpreter's `PackageIndexFlags` |
| `-reset` | -- | Reset package index before scanning |
| `-autopath` | -- | Include auto-path directories<br>in the scan |
| `-whatIf` | -- | Show what would be scanned without<br>actually scanning (disables Host, Bundle,<br>Plugin flags; adds WhatIf) |
| `-preferfilesystem` | -- | Prefer filesystem over<br>host-provided packages |
| `-preferhost` | -- | Prefer host-provided packages over filesystem |
| `-host` / `-nohost` | -- | Enable/disable host-provided package scanning |
| `-bundle` / `-nobundle` | -- | Enable/disable bundle-based package scanning |
| `-plugin` / `-noplugin` | -- | Enable/disable plugin-based package<br>scanning (requires `APPDOMAINS`) |
| `-temporary` | -- | Mark scanned packages as temporary |
| `-primary` / `-noprimary` | -- | Enable/disable primary package flag |
| `-tagged` / `-notagged` | -- | Enable/disable tagged package index support |
| `-normal` / `-nonormal` | -- | Enable/disable normal package indexing |
| `-dump` / `-nodump` | -- | Enable/disable dump output during scanning |
| `-recursive` | -- | Recursively scan subdirectories |
| `-refresh` | -- | Force re-scan even if index is cached |
| `-resolve` | -- | Resolve package paths during scanning |
| `-trace` | -- | Enable trace output during scanning |
| `-verbose` | -- | Enable verbose output during scanning |
| `-notrusted` | -- | Skip trusted-only verification |
| `-noverified` | -- | Skip signature verification |
| `-nocomplain` | -- | Suppress scanning errors |
| `-fileerror` | -- | Don't suppress file I/O errors<br>during scanning |

</details>

<details>
<summary><code>[parse command]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-engineflags` | EngineFlags | Override engine flags;<br>defaults to `interpreter.EngineFlags` |
| `-substitutionflags` | SubstitutionFlags | Override substitution flags;<br>defaults to<br>`interpreter.SubstitutionFlags` |
| `-startindex` | int | Start parsing from this<br>character index |
| `-characters` | int | Maximum characters to parse |
| `-nested` | boolean | Parse as a nested command<br>(within `[...]`) |
| `-noready` | boolean | Skip the interpreter<br>readiness check |

</details>

<details>
<summary><code>[parse expression]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-engineflags` | EngineFlags | Override engine flags |
| `-substitutionflags` | SubstitutionFlags | Override substitution flags |
| `-startindex` | int | Start parsing from this character index |
| `-characters` | int | Maximum characters to parse |
| `-noready` | boolean | Skip the interpreter readiness check |

</details>

<details>
<summary><code>[parse options]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | OptionBehaviorFlags | Option parsing behavior;<br>defaults to `OptionBehaviorFlags.Default` |
| `-optionsvar` | string | Store parsed options dictionary<br>in this variable |
| `-indexes` | -- | Return option index positions |
| `-allowinteger` | -- | Allow integer values for options |
| `-strict` | -- | Strict option validation |
| `-verbose` | -- | Verbose parsing output |
| `-nocase` | -- | Case-insensitive option name matching |
| `-novalue` | -- | Don't assign values to options |
| `-noset` | -- | Don't set option "present" flags |
| `-noready` | boolean | Skip interpreter readiness check |
| `-simple` | -- | Use simplified parsing mode |

</details>

<details>
<summary><code>[parse script]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-engineflags` | EngineFlags | Override engine flags |
| `-substitutionflags` | SubstitutionFlags | Override substitution flags |
| `-filename` | string | Associate a filename with the parsed<br>script (for error reporting) |
| `-currentline` | int | Starting line number<br>for error reporting |
| `-startindex` | int | Start parsing from this character index |
| `-characters` | int | Maximum characters to parse |
| `-nested` | boolean | Parse as nested script |
| `-syntax` | boolean | Syntax-check only (don't evaluate) |
| `-strict` | boolean | Strict parsing mode |
| `-roundtrip` | boolean | Preserve enough information<br>for round-trip reconstruction |
| `-noready` | boolean | Skip interpreter readiness check |

</details>

<details>
<summary><code>[puts]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for output |
| `-usecount` | -- | Prepend byte count before the output string |
| `-useobject` | -- | Use object-aware output with automatic type detection |
| `-nonewline` | -- | Suppress automatic trailing newline |

Note: No `Option.CreateEndOfOptions()` -- `--` is not supported, for Tcl
compatibility.

</details>

<details>
<summary><code>[regexp]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-options` | RegexOptions | .NET regex options; defaults to<br>`StringOps.DefaultRegExSyntaxOptions` |
| `-all` | -- | Find all non-overlapping matches |
| `-global` | -- | Controls whether variable indices reset<br>between match groups;<br>independent of `-all` |
| `-debug` | -- | Enable debug trace output |
| `-about` | -- | Show regex engine info (**unsupported**) |
| `-ecma` | -- | Use ECMAScript regex syntax |
| `-compiled` | -- | Compile regex for faster<br>repeated execution |
| `-explicit` | -- | Require all capturing groups<br>to be named |
| `-reverse` | -- | Reverse search direction |
| `-expanded` | -- | Allow whitespace and comments<br>in the pattern |
| `-indexes` / `-indices` | -- | Return start/end positions<br>instead of matched strings |
| `-inline` | -- | Return matched strings directly |
| `-skip` | int | Skip the first N matches |
| `-limit` | int | Maximum number of matches to return |
| `-line` | -- | Single-line mode<br>(dot does not match newline) |
| `-lineanchor` | -- | `^` and `$` match<br>line boundaries |
| `-linestop` | -- | Stop matching at line boundaries |
| `-nocase` | -- | Case-insensitive matching |
| `-noempty` | -- | Skip empty matches |
| `-noculture` | -- | Culture-independent matching |
| `-start` | string | Start matching at this position |
| `-length` | int | Maximum length of input to examine |

</details>

<details>
<summary><code>[regsub]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-options` | RegexOptions | .NET regex options; defaults to<br>`StringOps.DefaultRegExSyntaxOptions` |
| `-all` | -- | Replace all occurrences<br>(default is first only) |
| `-count` | int | Maximum number of replacements<br>to perform |
| `-ecma` | -- | ECMAScript regex syntax |
| `-compiled` | -- | Compile regex |
| `-explicit` | -- | Require named groups |
| `-quote` | -- | Quote regex metacharacters<br>in the pattern |
| `-nostrict` | -- | Non-strict substitution mode |
| `-reverse` | -- | Reverse replacement direction |
| `-eval` | string | Evaluate this script for each match<br>to compute replacement |
| `-command` | -- | Use TIP #463 command-based<br>replacement |
| `-literal` | -- | Treat replacement as a literal string<br>(no backslash substitution) |
| `-verbatim` | -- | Verbatim replacement |
| `-extra` | -- | Enable extended `\P`, `\I`, `\S`,<br>`\M#`, `\N<name>` substitutions |
| `-expanded` | -- | Allow whitespace and comments<br>in pattern |
| `-line` | -- | Single-line regex mode |
| `-lineanchor` | -- | `^`/`$` match line boundaries |
| `-linestop` | -- | Stop at line boundaries |
| `-nocase` | -- | Case-insensitive matching |
| `-noculture` | -- | Culture-independent matching |
| `-start` | string | Start replacement at this position |

</details>

<details>
<summary><code>[rename]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nodelete` | -- | Keep the original name (creates a copy) |
| `-hidden` | -- | Make the new name hidden |
| `-hiddenonly` | -- | Make both old and new names hidden |
| `-kind` | IdentifierKind | Type of identifier<br>(Command, Function, etc.);<br>defaults to `None` |
| `-newnamevar` | string | Store the actual new name<br>in this variable |

</details>

<details>
<summary><code>[return]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-code` | ReturnCode | Return code<br>(Ok, Error, Return, Break, Continue) |
| `-errorinfo` | string | Error stack trace information |
| `-errorcode` | string | Machine-readable error code |

</details>

<details>
<summary><code>[scope close]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-all` | -- | Close all open scopes,<br>not just the current one |

</details>

<details>
<summary><code>[scope create]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-args` | -- | Pass arguments to the scope constructor |
| `-clone` | -- | Clone variables<br>from an existing scope |
| `-byref` | -- | Create by-reference scope<br>(variables are shared, not copied) |
| `-global` | -- | Create in the global scope context |
| `-open` | -- | Automatically open the scope after creation |
| `-procedure` | -- | Create a procedure-scoped scope |
| `-shared` | -- | Create a shared scope accessible across interpreters |
| `-strict` | -- | Strict scope mode (error on undefined variables) |
| `-fast` | -- | Fast/optimized scope mode |

</details>

<details>
<summary><code>[scope eval]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-eventwaitflags` | EventWaitFlags | Event waiting behavior during evaluation;<br>defaults to `interpreter.EventWaitFlags` |
| `-lock` | boolean | Acquire the scope lock during evaluation |
| `-timeout` | int | Timeout in milliseconds for the evaluation |

</details>

<details>
<summary><code>[scope global]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-unset` | -- | Unset variables in the global scope |
| `-force` | -- | Force the operation |

</details>

<details>
<summary><code>[scope lock]</code> / <code>[scope unlock]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nocomplain` | -- | Suppress errors if the lock/unlock<br>operation fails |

</details>

<details>
<summary><code>[scope open]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-procedure` | -- | Open in procedure scope context |
| `-shared` | -- | Open with shared access |
| `-args` | -- | Pass arguments to the open operation |

</details>

<details>
<summary><code>[scope update]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-global` | -- | Update the global scope data |

</details>

<details>
<summary><code>[socket]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-timeouttype` | TimeoutType | Timeout semantics<br>(Infinite, Default) |
| `-addressfamily` | AddressFamily | IPv4, IPv6, or other<br>address family |
| `-keepalive` | boolean | Enable TCP keep-alive |
| `-server` | string | Server callback command; presence<br>makes this a server socket |
| `-maxpendingclients` | int | Maximum accepted clients whose callbacks<br>have not yet started (default 64);<br>server only, must be positive |
| `-buffer` | int | Socket buffer size in bytes |
| `-timeout` | int | General operation timeout<br>in milliseconds |
| `-sendtimeout` | int | Send operation timeout |
| `-receivetimeout` | int | Receive operation timeout |
| `-availabletimeout` | int | Total data-availability wait budget;<br>depleted in small poll chunks by<br>reads that find no data |
| `-connecttimeout` | int | Finite deadline for the connection<br>attempt in milliseconds (-1 = unlimited);<br>client only |
| `-readtimeout` | int | Read operation timeout |
| `-writetimeout` | int | Write operation timeout |
| `-myaddr` | string | Local address to bind to |
| `-myport` | string | Local port to bind to |
| `-async` | -- | Start a client connection asynchronously and return its channel immediately;<br>use writable `[fileevent]` plus `fconfigure -error` for completion |
| `-channelid` | string | Custom channel identifier |
| `-nodelay` | -- | Disable Nagle algorithm<br>(TCP_NODELAY); client only |
| `-nobuffer` | -- | Disable socket buffering;<br>client only |
| `-noexclusive` | -- | Allow multiple listeners on<br>the same port; server only |
| `-trace` | -- | Enable socket operation tracing |

</details>

<details>
<summary><code>[source]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding<br>for the source file |
| `-withinfo` | boolean | Return source file metadata<br>along with result |
| `-time` | boolean | Measure and return execution time |
| `-password` | byte[] | Decryption password<br>for encrypted script files |
| `-library` | boolean | Treat the file as library code |
| `-bundle` | boolean | Load from a script bundle resource<br>instead of a file (requires `DATA`) |
| `-bundleflags` | BundleFlags | Bundle loading behavior;<br>defaults to `BundleFlags.Default`<br>(requires `DATA`) |

</details>

<details>
<summary><code>[split]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-string` | -- | Use string split semantics instead<br>of character-based splitting |

</details>

<details>
<summary><code>[sql execute]</code></summary>

> Requires `DATA`. Includes [DateTime](#85-datetime-and-encoding)
> and [execution control](#86-execution-control) options.

**SQL execution options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-execute` | DbExecuteType | Execution mode (None, NonQuery, Scalar,<br>Reader, ReaderAndCount) |
| `-format` | DbResultFormat | Result format (None, List, Dictionary,<br>DataReader, DataTable, etc.) |
| `-transaction` | string | Variable name containing the<br>transaction object to use |
| `-commandtype` | CommandType | ADO.NET command type<br>(Text, StoredProcedure, TableDirect) |
| `-behavior` | CommandBehavior | ADO.NET command behavior flags |
| `-time` | -- | Measure and report execution time |
| `-timevar` | string | Store timing information<br>in this variable |
| `-timeout` | int | Command timeout in milliseconds |
| `-limit` | int | Maximum number of result rows<br>to return |
| `-rowsvar` | string | Store the affected row count<br>in this variable |
| `-rowvar` | string | Store per-row data<br>in this variable |
| `-nested` | boolean | Enable nested result set handling |
| `-allownull` | boolean | Allow null values in results |
| `-nullvalue` | string | String representation for null values |
| `-dbnullvalue` | string | String representation<br>for `DBNull` values |
| `-errorvalue` | string | String representation<br>for error values |
| `-pairs` | boolean | Return results as key-value pairs |
| `-names` | boolean | Include column names in results |
| `-nofixup` | boolean | Skip result fixup processing |
| `-nocreate` | -- | Don't create opaque object handles<br>for results |
| `-verbatim` | -- | Return values without<br>formatting conversion |
| `-changed` | callback | Callback for row change notifications |
| `-culture` | CultureInfo | Culture for value formatting |

**Value formatting options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-datetimekind` | DateTimeKind | DateTime interpretation<br>for result values |
| `-datetimestyles` | DateTimeStyles | DateTime parsing styles |
| `-datetimeformat` | string | DateTime format string |
| `-datetimebehavior` | DateTimeBehavior | DateTime handling behavior |
| `-numberformat` | string | Number format string |
| `-valueformat` | string | General value format string |
| `-blobbehavior` | BlobBehavior | BLOB column handling behavior |
| `-valueflags` | ValueFlags | Value conversion flags |

Plus [FixupReturnValue](#fixupreturnvalue-options) options: `-objectname`,
`-returntype`, `-objecttype`, `-create`, `-nodispose`, `-alias`, `-aliasraw`,
`-aliasall`, `-aliasreference`, `-tcl`, `-noforcedelete`, `-tostring`,
`-objectflags`.

</details>

<details>
<summary><code>[sql open]</code> (pre-options)</summary>

> Requires `DATA`. Uses two-pass option processing (see
> [Section 7.1](#71-two-pass-option-processing)).

| Option | Value | Description |
|--------|-------|-------------|
| `-stricttype` | -- | Require exact type match<br>during type resolution |
| `-verbose` | -- | Enable verbose type resolution<br>diagnostics |
| `-nocase` | -- | Case-insensitive type name matching |

</details>

<details>
<summary><code>[sql open]</code> (main options)</summary>

> Requires `DATA`.

| Option | Value | Description |
|--------|-------|-------------|
| `-type` | DbConnectionType | Database connection type<br>(e.g., SQLite, SqlServer) |
| `-type1` | DbConnectionType | Primary connection type<br>for fallback resolution |
| `-type2` | DbConnectionType | Secondary connection type<br>for fallback resolution |
| `-variable` | string | Store the connection object<br>in this variable |
| `-assemblyfilename` | string | Assembly file containing<br>the ADO.NET provider |
| `-typename` | string | Short type name<br>of the connection class |
| `-typefullname` | string | Fully qualified type name<br>of the connection class |
| `-valueflags` | ValueFlags | Value conversion flags<br>for type resolution |
| `-trustedonly` | -- | Only load trusted<br>provider assemblies |
| `-maybetrustedonly` | -- | Trusted-only (lenient) |
| `-publickeytoken1` | string | Primary public key token<br>for assembly verification |
| `-publickeytoken2` | string | Secondary public key token<br>for assembly verification |
| `-stricttype` | -- | *(Ignored)* Carried over<br>from pre-options pass |
| `-verbose` | -- | *(Ignored)* Carried over<br>from pre-options pass |
| `-nocase` | -- | *(Ignored)* Carried over<br>from pre-options pass |

</details>

<details>
<summary><code>[sql transaction]</code></summary>

> Requires `DATA`.

| Option | Value | Description |
|--------|-------|-------------|
| `-isolation` | IsolationLevel | Transaction isolation level<br>(e.g., ReadCommitted, Serializable) |
| `-variable` | string | Store the transaction object<br>in this variable |

</details>

<details>
<summary><code>[string equal]</code> / <code>[string compare]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-culture` | CultureInfo | Culture for locale-aware comparison<br>(requires `NET_20_SP2` or `NET_40`) |
| `-options` | CompareOptions | Fine-grained comparison control<br>(requires `NET_20_SP2` or `NET_40`) |
| `-nocase` | -- | Case-insensitive comparison |
| `-comparison` | StringComparison | .NET `StringComparison` enum value |
| `-length` | int | Compare only the first N characters |

</details>

<details>
<summary><code>[string ends]</code> / <code>[string starts]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-culture` | CultureInfo | Culture for locale-aware comparison |
| `-nocase` | -- | Case-insensitive matching |
| `-comparison` | StringComparison | .NET comparison type |

</details>

<details>
<summary><code>[string first]</code> / <code>[string last]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nocase` | -- | Case-insensitive search |
| `-comparison` | StringComparison | .NET comparison type |

</details>

<details>
<summary><code>[string format]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-valueformat` | string | Custom format specification<br>for values |
| `-datetimekind` | DateTimeKind | DateTime interpretation;<br>defaults to `interpreter.DateTimeKind` |
| `-datetimestyles` | DateTimeStyles | DateTime parsing styles; defaults to<br>`ObjectOps.GetDefaultDateTimeStyles()` |
| `-culture` | CultureInfo | Culture for formatting |
| `-verbatim` | -- | Pass format string verbatim<br>to `String.Format` |
| `-valueflags` | ValueFlags | Value conversion flags;<br>defaults to `ValueFlags.AnyNonCharacter` |

</details>

<details>
<summary><code>[string is]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-strict` | -- | Return false (instead of true)<br>for empty strings |
| `-nocomplain` | -- | Suppress detailed error messages |
| `-not` | boolean | Invert the test result; default comes<br>from parsing `"not"` prefix words |
| `-any` | boolean | Match if any character satisfies<br>the test (vs. all characters) |
| `-via` | boolean | Use alternate checking path |
| `-count` | int | Check only the first N characters |
| `-good` | string | Store the count of passing<br>characters in this variable |
| `-bad` | string | Store the count of failing<br>characters in this variable |
| `-failindex` | string | Store the index of the first<br>failing character |

</details>

<details>
<summary><code>[string map]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-multipass` | -- | Apply mapping repeatedly until<br>no more substitutions occur |
| `-regexp` | -- | Use regex patterns instead of<br>literal strings |
| `-subspec` | -- | Allow sub-specifications<br>in replacement patterns |
| `-eval` | -- | Evaluate replacement strings<br>as scripts |
| `-maximum` | int | Maximum number of replacements |
| `-countvar` | string | Store the replacement count<br>in this variable |
| `-comparison` | StringComparison | .NET comparison type for matching |
| `-regexpoptions` | RegexOptions | Regex options when `-regexp` is active;<br>defaults to `StringOps.DefaultRegExOptions` |
| `-nocase` | -- | Case-insensitive mapping |

</details>

<details>
<summary><code>[string match]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-mode` | MatchMode | Matching mode (Exact, Glob, Regexp,<br>SubString, etc.); defaults to<br>`StringOps.DefaultMatchMode` |
| `-nocase` | -- | Case-insensitive matching |

</details>

<details>
<summary><code>[string toupper]</code> / <code>[string tolower]</code> / <code>[string totitle]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-culture` | CultureInfo | Culture for locale-aware<br>case conversion |

</details>

<details>
<summary><code>[subst]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nobackslashes` | -- | Don't process backslash substitutions |
| `-nocommands` | -- | Don't process `[command]` substitutions |
| `-novariables` | -- | Don't process `$variable` substitutions |

Note: `Option.CreateEndOfOptions()` is deliberately commented out for Tcl
compatibility.

</details>

<details>
<summary><code>[switch]</code></summary>

**Mutual-exclusion groups:**

| Group | Options | Description |
|-------|---------|-------------|
| 1 | `-exact`, `-glob`, `-regexp` | Primary match mode |
| 2 | `-subst` | Substitution mode |
| 3 | `-integer`, `-substring` | Extended match modes |

| Option | Value | Description |
|--------|-------|-------------|
| `-nocase` | -- | Case-insensitive matching for all modes |

</details>

<details>
<summary><code>[tcl cancel]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-unwind` | -- | Unwind the call stack during cancellation |

</details>

<details>
<summary><code>[tcl create]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-alias` | -- | Create a command alias<br>for the new Tcl interpreter |
| `-noinitialize` | -- | Skip Tcl interpreter initialization |
| `-memory` | -- | Enable memory debugging<br>in the Tcl interpreter |
| `-safe` | -- | Create a safe (sandboxed)<br>Tcl interpreter |
| `-nobridge` | -- | Don't create the<br>Eagle-to-Tcl bridge |
| `-noforcedelete` | -- | Don't force-delete the interpreter<br>on cleanup |
| `-nocomplain` | -- | Suppress errors during creation |

</details>

<details>
<summary><code>[tcl eval]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-time` | -- | Measure and report evaluation time |
| `-exceptions` | boolean | Control exception propagation behavior |

</details>

<details>
<summary><code>[tcl expr]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-time` | -- | Measure and report expression evaluation time |
| `-exceptions` | boolean | Control exception propagation behavior |

</details>

<details>
<summary><code>[tcl find]</code> and <code>[tcl available]</code></summary>

> Requires `NATIVE && TCL`. The `-flags` default is interpreter-dependent
> (`interpreter.TclFindFlags`).

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | FindFlags | Tcl library search flags;<br>defaults to `interpreter.TclFindFlags` |
| `-robustify` | -- | Apply robustness heuristics<br>to the search |
| `-architecture` | -- | Filter by processor architecture |
| `-trustedonly` | -- | Only find trusted Tcl libraries |
| `-maybetrustedonly` | -- | Trusted-only (lenient) |
| `-verbose` | -- | Enable verbose search diagnostics |
| `-eval` | string | Script to evaluate<br>for each candidate found |
| `-full` | -- | Return full path and<br>version information |
| `-minimumversion` | Version | Minimum acceptable Tcl version |
| `-maximumversion` | Version | Maximum acceptable Tcl version |
| `-unknownversion` | Version | Version to use when the actual<br>version cannot be determined |
| `-errorsvar` | string | Store search errors<br>in this variable |

</details>

<details>
<summary><code>[tcl interp create]</code></summary>

> Requires `NATIVE && TCL`. This is the `[tcl command create]` alias.

| Option | Value | Description |
|--------|-------|-------------|
| `-noforcedelete` | -- | Don't force-delete the Tcl command<br>on cleanup |
| `-nocomplain` | -- | Suppress errors during creation |

</details>

<details>
<summary><code>[tcl load]</code></summary>

> Requires `NATIVE && TCL`. The `-findflags` and `-loadflags` defaults are
> interpreter-dependent (`interpreter.TclFindFlags` and
> `interpreter.TclLoadFlags`).

| Option | Value | Description |
|--------|-------|-------------|
| `-findflags` | FindFlags | Tcl library search flags;<br>defaults to `interpreter.TclFindFlags` |
| `-loadflags` | LoadFlags | Tcl library loading flags;<br>defaults to `interpreter.TclLoadFlags` |
| `-robustify` | -- | Apply robustness heuristics<br>to the load |
| `-trustedonly` | -- | Only load trusted Tcl libraries |
| `-maybetrustedonly` | -- | Trusted-only (lenient) |
| `-eval` | string | Script to evaluate after loading |
| `-bridge` | -- | Create the Eagle-to-Tcl bridge<br>after loading |
| `-noforcedelete` | -- | Don't force-delete on cleanup |
| `-nocomplain` | -- | Suppress errors during loading |
| `-minimumversion` | Version | Minimum acceptable Tcl version |
| `-maximumversion` | Version | Maximum acceptable Tcl version |
| `-unknownversion` | Version | Version to use when the actual<br>version cannot be determined |

</details>

<details>
<summary><code>[tcl queue]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-eventtype` | EventType | Type of event to queue; defaults to `EventType.Evaluate` |
| `-eventflags` | EventFlags | Event behavior flags; defaults to `EventFlags.None` |
| `-exceptions` | boolean | Control exception propagation behavior |
| `-synchronous` | boolean | Wait for the queued event to complete before returning |
| `-data` | object | Additional data to associate with the event |

</details>

<details>
<summary><code>[tcl recordandeval]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-time` | -- | Measure and report evaluation time |
| `-exceptions` | boolean | Control exception propagation behavior |

</details>

<details>
<summary><code>[tcl resetcancel]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-children` | -- | Reset cancellation for child interpreters as well |
| `-force` | -- | Force reset even if cancellation is locked |

</details>

<details>
<summary><code>[tcl select]</code></summary>

> Requires `NATIVE && TCL`. The `-flags` default is interpreter-dependent
> (`interpreter.TclFindFlags`).

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | FindFlags | Tcl library search flags;<br>defaults to `interpreter.TclFindFlags` |
| `-robustify` | -- | Apply robustness heuristics to the search |
| `-architecture` | -- | Filter by processor architecture |
| `-trustedonly` | -- | Only select trusted Tcl libraries |
| `-maybetrustedonly` | -- | Trusted-only (lenient) |
| `-verbose` | -- | Enable verbose diagnostics |
| `-eval` | string | Script to evaluate for each candidate |
| `-minimumversion` | Version | Minimum acceptable Tcl version |
| `-maximumversion` | Version | Maximum acceptable Tcl version |
| `-unknownversion` | Version | Version to use when the actual<br>version cannot be determined |
| `-errorsvar` | string | Store search errors in this variable |
| `-allerrors` | -- | Include all errors (not just the first)<br>in the errors variable |

</details>

<details>
<summary><code>[tcl source]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-time` | -- | Measure and report source evaluation time |
| `-exceptions` | boolean | Control exception propagation behavior |

</details>

<details>
<summary><code>[tcl subst]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-nobackslashes` | -- | Don't process backslash substitutions |
| `-nocommands` | -- | Don't process `[command]` substitutions |
| `-novariables` | -- | Don't process `$variable` substitutions |
| `-time` | -- | Measure and report substitution time |
| `-exceptions` | boolean | Control exception propagation behavior |

</details>

<details>
<summary><code>[tcl update]</code></summary>

> Requires `NATIVE && TCL`.

| Option | Value | Description |
|--------|-------|-------------|
| `-timeout` | int | Timeout in milliseconds for the update operation |
| `-wait` | -- | Wait for idle before returning |
| `-all` | -- | Process all pending events |
| `-nocomplain` | -- | Suppress errors during update |

</details>

<details>
<summary><code>[tcl versionrange]</code></summary>

> Requires `NATIVE && TCL`. The `-flags` default is interpreter-dependent
> (`interpreter.TclFindFlags`).

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | FindFlags | Tcl library search flags;<br>defaults to `interpreter.TclFindFlags` |
| `-robustify` | -- | Apply robustness heuristics |
| `-trustedonly` | -- | Only consider trusted Tcl libraries |
| `-maybetrustedonly` | -- | Trusted-only (lenient) |
| `-minimumversion` | Version | Minimum version in the range |
| `-maximumversion` | Version | Maximum version in the range |
| `-majorincrement` | int | Major version increment step |
| `-minorincrement` | int | Minor version increment step |
| `-intermediateminimum` | int | Minimum intermediate<br>version number |
| `-intermediatemaximum` | int | Maximum intermediate<br>version number |

</details>

<details>
<summary><code>[test2]</code></summary>

**Standard test options (tcltest-compatible):**

| Option | Value | Description |
|--------|-------|-------------|
| `-constraints` | string | Constraint expression that must be<br>true for the test to run |
| `-setup` | string | Script to run before the test body |
| `-body` | string | The test script to evaluate |
| `-cleanup` | string | Script to run after the test<br>(always runs) |
| `-result` | string | Expected result to compare against |
| `-output` | string | Expected stdout output |
| `-errorOutput` | string | Expected stderr output<br>(case-insensitive option name) |
| `-returnCodes` | list | Acceptable return codes<br>(case-insensitive) |
| `-execReturnCodes` | list | Acceptable execution return codes<br>(case-insensitive) |
| `-exitCode` | ExitCode | Expected exit code (case-insensitive) |
| `-execExitCode` | ExitCode | Expected execution exit code (case-insensitive) |
| `-match` | MatchMode | How to compare actual vs. expected result;<br>defaults to `StringOps.DefaultResultMatchMode` |

**Eagle-specific options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-debug` | boolean | Enable debug mode during test execution |
| `-trace` | boolean | Enable trace output during test |
| `-captureTrace` | boolean | Capture trace output for comparison<br>(TEST builds only) |
| `-time` | boolean | Measure and report<br>test execution time |
| `-once` | boolean | Run the test only once<br>(skip repeat logic) |
| `-text` | string | Additional text to display with test results |
| `-argv` | list | Additional arguments for the test |
| `-timeout` | int | Timeout in milliseconds |
| `-ruleSet` | IRuleSet | Security rule set for the test<br>(case-insensitive) |
| `-noCase` | boolean | Case-insensitive result comparison<br>(case-insensitive option name) |
| `-visibleSpace` | boolean | Make whitespace visible in output<br>(case-insensitive) |
| `-regExOptions` | RegexOptions | Regex options for `-match regexp`;<br>defaults to `TestOps.RegExOptions` |
| `-constraintExpression` | string | Additional constraint expression<br>(case-insensitive) |
| `-repeatCount` | int | Number of times to repeat the test |
| `-noCleanup` | boolean | Skip cleanup even if defined |
| `-noCancel` / `-globalCancel` | boolean | Cancellation control |
| `-noData` | boolean | Don't store test data |
| `-noEvent` / `-noExit` / `-noHalt` | boolean | Event/exit/halt suppression |
| `-noProcessId` | boolean | Don't record process ID |
| `-noStatistics` | boolean | Don't record statistics |
| `-noSecurity` | boolean | Disable security checks |
| `-noTrack` | boolean | Don't track test execution |
| `-ignoreMatch` | MatchMode | Match mode for ignore patterns |
| `-ignorePatterns` | list | Patterns for output to ignore in comparison |
| `-libraryPath` | string | Override library search path |
| `-isolationLevel` | IsolationLevel | Test isolation level;<br>defaults to `IsolationLevel.Default` |
| `-isolationPassDetail` / `-isolationFailDetail` | IsolationDetail | Detail level for pass/fail<br>in isolation mode |
| `-isolationPathType` | TestPathType | Path type for isolated<br>test execution |
| `-isolationUnicode` | boolean | Unicode mode for isolated tests |
| `-isolationTemplate` | string | Template for isolated<br>test execution |
| `-isolationOtherArguments` / `-isolationLastArguments` | list | Additional arguments<br>for isolated execution |
| `-isolationFileName` / `-isolationLogFile` | string | File paths for isolated<br>test output |
| `-noChangeReturnCode` | boolean | Don't modify the return code<br>based on test outcome |
| `-stopOnHookError` | boolean | Stop test execution if a hook<br>reports an error |

</details>

<details>
<summary><code>[time]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-timeout` | int | Timeout in milliseconds<br>for the timed command |
| `-statistics` | boolean | Return detailed execution statistics<br>instead of simple timing |
| `-breakOk` | boolean | Allow `[break]` return code without<br>error (case-insensitive) |
| `-errorOk` | boolean | Allow `[error]` return code without<br>error (case-insensitive) |
| `-noCancel` | boolean | Don't honor cancellation during<br>timing (case-insensitive) |
| `-globalCancel` | boolean | Use global cancellation<br>(case-insensitive) |
| `-noHalt` | boolean | Don't halt on timeout<br>(case-insensitive) |
| `-noEvent` | boolean | Don't process events during<br>timing (case-insensitive) |
| `-noExit` | boolean | Don't allow exit during<br>timing (case-insensitive) |

</details>

<details>
<summary><code>[unload]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-clientdata` | object | Client data for the unload operation |
| `-data` | object | Additional data for unload |
| `-nocase` | -- | Case-insensitive plugin name matching |
| `-keeplibrary` | -- | Keep the underlying library loaded<br>after plugin unload |
| `-nocomplain` | -- | Suppress errors if the plugin<br>is not found |
| `-match` | MatchMode | Plugin name matching mode;<br>defaults to<br>`StringOps.DefaultUnloadMatchMode` |

</details>

<details>
<summary><code>[unset]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nocomplain` | -- | Don't error if the variable<br>does not exist |
| `-unlinkonly` | -- | Only unlink from parent scope;<br>don't delete the underlying variable |
| `-remove` | -- | Remove the variable entirely<br>from all scopes |
| `-notrace` | -- | Don't fire variable trace callbacks<br>during unset |
| `-purge` | -- | Purge the variable<br>from internal caches |
| `-zerostring` | -- | Zero out the string memory before<br>freeing (Windows native only;<br>security feature) |
| `-maybezerostring` | -- | Conditionally zero memory<br>(Windows native; silently ignored<br>on other platforms) |

</details>

<details>
<summary><code>[uri compare]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-kind` | UriKind | URI kind constraint (Absolute,<br>Relative, RelativeOrAbsolute) |
| `-components` | UriComponents | Which URI components to compare;<br>defaults to `AbsoluteUri` |
| `-format` | UriFormat | How to format components<br>before comparison |
| `-comparison` | StringComparison | .NET string comparison type |
| `-nocase` | -- | Case-insensitive comparison |

</details>

<details>
<summary><code>[uri create]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-username` | string | Username component |
| `-password` | string | Password component |
| `-port` | int | Port number |
| `-path` | string | Path component |
| `-query` | string | Query string |
| `-fragment` | string | Fragment identifier |

</details>

<details>
<summary><code>[uri get]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-timeouttype` | TimeoutType | Timeout semantics |
| `-retries` | int | Number of retry attempts on failure |
| `-timeout` | int | Timeout in milliseconds per attempt |
| `-callback` | list | Async callback script |
| `-callbackflags` | CallbackFlags | Callback behavior flags;<br>defaults to `CallbackFlags.Default` |
| `-inline` / `-noinline` | -- | Control inline result handling |
| `-trusted` | -- | Trust the remote server's certificate |
| `-yesprotocol` / `-noprotocol` | -- | Protocol selection control<br>(TEST builds only) |
| `-obsolete` | -- | Allow obsolete protocols<br>(TEST builds only) |
| `-encodingtype` | EncodingType | Response encoding type |
| `-encoding` | Encoding | Character encoding<br>for the response |
| `-webclientdata` | object | Custom WebClient<br>configuration object |

</details>

<details>
<summary><code>[uri post]</code></summary>

Same as `[uri get]` plus:

| Option | Value | Description |
|--------|-------|-------------|
| `-method` | string | HTTP method to use (e.g., "POST", "PUT") |
| `-data` | list | Request body data |
| `-raw` | -- | Send data without encoding transformation |

</details>

<details>
<summary><code>[vwait]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-handle` | object | Wait on a specific event<br>handle object |
| `-eventwaitflags` | EventWaitFlags | Event waiting behavior;<br>defaults to `interpreter.EventWaitFlags` |
| `-variableflags` | VariableFlags | Variable watch flags; defaults to<br>`interpreter.EventVariableFlags` |
| `-thread` | int64 | Target thread for event processing |
| `-limit` | int | Maximum number of events<br>to process |
| `-timeout` | int | Timeout in milliseconds |
| `-clear` | -- | Clear pending events<br>before waiting |
| `-force` | -- | Force wait even if no events<br>are pending |
| `-nocomplain` | -- | Suppress timeout errors |
| `-leaveresult` | -- | Don't clear the interpreter result<br>after waiting |
| `-resetcancel` | -- | Reset cancellation flag after<br>wait completes (restricted) |
| `-locked` | string | Lock name to acquire<br>during the wait |

</details>

<details>
<summary><code>[xml deserialize]</code></summary>

> Requires `XML && SERIALIZATION`. Includes
> [object handle management](#fixupreturnvalue-options) options (subset)
> and [type resolution](#83-type-resolution) options.

| Option | Value | Description |
|--------|-------|-------------|
| `-objectname` | string | Name for the deserialized<br>opaque object handle |
| `-type` | Type | .NET type to deserialize into |
| `-nocreate` | -- | Don't create an opaque object handle<br>for the result |
| `-nodispose` | -- | Don't mark the object<br>for automatic disposal |
| `-tostring` | -- | Return the `ToString()` representation<br>instead of an opaque handle |
| `-stricttype` | -- | Require exact type match<br>during object resolution |
| `-verbose` | -- | Enable verbose type resolution<br>diagnostics |
| `-nocase` | -- | Case-insensitive type name matching |
| `-alias` | -- | Create a command alias<br>for the deserialized object |
| `-aliasraw` | -- | Use raw dispatch for the alias |
| `-aliasall` | -- | Use invokeall dispatch for the alias |
| `-aliasreference` | -- | Use reference-counted handle<br>for the alias |
| `-tcl` | TclInterpreter | Bridge the object to a Tcl interpreter<br>(requires `NATIVE && TCL`) |
| `-noforcedelete` | -- | Don't force-delete the alias on cleanup |
| `-encoding` | Encoding | Character encoding<br>for deserialization |
| `-objectflags` | ObjectFlags | Object handle behavior flags |

</details>

<details>
<summary><code>[xml foreach]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-file` | -- | Treat the XML argument as a file path |
| `-namespaces` | dictionary | XML namespace prefix-to-URI mappings<br>for XPath evaluation |
| `-xpaths` | list | List of XPath expressions<br>to iterate over |

Plus all [FixupReturnValue](#fixupreturnvalue-options) options: `-objectname`,
`-returntype`, `-objecttype`, `-create`, `-nodispose`, `-alias`, `-aliasraw`,
`-aliasall`, `-aliasreference`, `-tcl`, `-noforcedelete`, `-tostring`,
`-objectflags`.

</details>

<details>
<summary><code>[xml serialize]</code></summary>

> Requires `XML && SERIALIZATION`.

| Option | Value | Description |
|--------|-------|-------------|
| `-stricttype` | -- | Require exact type match<br>during object resolution |
| `-verbose` | -- | Enable verbose type resolution<br>diagnostics |
| `-nocase` | -- | Case-insensitive type name matching |
| `-encoding` | Encoding | Character encoding<br>for serialization output |

</details>

---

## 14. Shell Command-Line Options

The options documented above are *command* options: named switches parsed by
the `OptionDictionary` infrastructure when a script invokes a command. This
section documents a separate option surface entirely -- the **shell startup
command-line options** processed by the `EagleShell` host *before* (and around)
the interactive loop, as it walks the process argument vector.

These are not parsed through `OptionDictionary`. They are matched directly in
the argument-processing loop of `Interpreter.ShellMainCore()` in
`Interpreter.cs` (the long `else if` chain beginning around line 87662), each
arm calling `StringOps.MatchSwitch()` against a name constant from the
`CommandLineOption` class in `Constants.cs` (around line 883). The built-in
usage text that these descriptions are derived from lives in `HelpOps.cs`
(the "Command Line Options" section, around line 4056) and is displayed by the
`-help` option.

> [!NOTE]
> A handful of these options are also referenced in `Interpreter.cs` source
> comments (e.g. `-child` near line 86886, `-safe`/`-standard` near 87122,
> `-recreate` near 87147, `-encoding` near 87198).

### 14.1 Switch Syntax and Processing Order

Option names are matched by `StringOps.MatchSwitch()` (`StringOps.cs`, around
line 1736), which performs a **case-insensitive** comparison after
`StringOps.TrimSwitchChars()` (around line 1711) strips any leading run of
*switch characters*. The switch character set is `-` and `/` (`StringOps.cs`,
around line 211: `Characters.MinusSign` and `Characters.Slash`). Because the
entire leading run is trimmed, all of the following are equivalent:

```text
-safe
--safe
/safe
-SAFE
```

Key processing rules (from the "Command Line Notes" usage section in
`HelpOps.cs`, around line 4028):

- Option names are **case-insensitive**.
- Most options are processed **precisely in the order they are encountered**,
  left to right. Order matters: e.g. `-preFile` must appear before the script
  library is initialized, while `-postFile` must appear after.
- Options whose names begin with `-startup` (e.g. `-startupLibrary`,
  `-startupPreInitialize`, `-startupLogFile`) may be processed **prior to
  interpreter creation**.
- If a file named `argv.txt` (or supported per-user, per-machine, or per-domain
  variations) exists in the executable directory, its entire contents are read
  and processed as if passed via `-arguments`, inserted *before* any preexisting
  arguments. Use `-noArgumentsFileNames` to skip this.
- Any **unrecognized** argument is passed to the shell argument callback if one
  is registered; otherwise an error is generated.
- If no arguments are supplied, or once no arguments remain, the **interactive
  loop is entered** (unless it has been disabled).

> [!TIP]
> Most value-bearing options report `wrong # args: should be "-<name> <value>"`
> when their required value argument is missing. Boolean options taking
> `<enable>` accept the usual Eagle boolean spellings (e.g. `true`/`false`,
> `1`/`0`, `yes`/`no`).

### 14.2 The Init Pipeline (file and script options)

The most commonly used shell options drive the **initialization pipeline**:
running files or inline scripts relative to whether the script library has been
initialized. The file-based and script-based options are parallel families.

File options (each takes a `<fileName>`):

| Option | When it runs | On wrong phase |
|--------|--------------|----------------|
| `-anyFile` | Whether or not the library is initialized | -- |
| `-preFile` | Before the library is initialized | Error if library already initialized |
| `-file` | Evaluates the file and then **exits** (terminal) | -- |
| `-postFile` | After the library is initialized | Error if library not yet initialized |

Script options (each takes a `<script>` string; `#if !ENTERPRISE_LOCKDOWN`):

| Option | When it runs | On wrong phase |
|--------|--------------|----------------|
| `-anyInitialize` | Whether or not the library is initialized | -- |
| `-preInitialize` | Before the library is initialized | Error if library already initialized |
| `-postInitialize` | After the library is initialized | Error if library not yet initialized |
| `-startupPreInitialize` | Before the library is initialized, processed **prior to interpreter creation** | Error if library already initialized |

The `-anyFile`/`-anyInitialize`/`-preFile`/`-preInitialize`/`-postFile`/`-postInitialize`
options **continue processing** the remaining arguments after running. The
`-file` option is **terminal**: after evaluating the named file (consuming any
trailing `[argument ...]` as the script's arguments) the shell exits.

> [!NOTE]
> The `-anyInitialize`, `-evaluate`, `-evaluateEncoded`, `-preInitialize`,
> `-postInitialize`, and `-startupPreInitialize` options are compiled only when
> `ENTERPRISE_LOCKDOWN` is **not** defined (see `Constants.cs`). Under
> enterprise lockdown builds these inline-script options are unavailable.

Related initialization control:

| Option | Value | Description |
|--------|-------|-------------|
| `-initialize` | -- | Immediately attempt to initialize the script library, then continue processing arguments |
| `-setInitialize` | `<enable>` | Enable or disable script-library initialization, then continue |
| `-forceInitialize` | -- | Enable forced initialization of the script library, then continue |
| `-startupLibrary` | `<directory>` | Set the script-library location (processed prior to interpreter creation), then continue |
| `-runtimeOption` | `<optionName>` | Add, remove, or reset runtime option(s), then continue (errors if library not initialized) |

### 14.3 Inline Evaluation and Exit

| Option | Value | Description | Build guard |
|--------|-------|-------------|-------------|
| `-evaluate` | `[string ...]` | Evaluate the specified string(s), then **exit** | `!ENTERPRISE_LOCKDOWN` |
| `-evaluateEncoded` | `[string ...]` | Evaluate base64-encoded string(s), then **exit** (useful when OS command-line quoting conflicts with script quoting) | `!ENTERPRISE_LOCKDOWN` |
| `-file` | `<fileName> [argument ...]` | Evaluate the file, then **exit** | -- |

> [!WARNING]
> `-evaluate`, `-evaluateEncoded`, and `-file` are **terminal**: the shell exits
> after they run rather than continuing to process arguments or entering the
> interactive loop.

### 14.4 Interpreter Mode and Security

| Option | Value | Description |
|--------|-------|-------------|
| `-safe` | -- | Enable "safe" mode; all "unsafe" commands are hidden |
| `-standard` | -- | Enable "standard" mode; all "non-standard" commands are hidden |
| `-namespaces` | `<enable>` | Enable/disable Tcl 8.4 compatible namespace support (note: the native "dangers of creative writing" caveat does *not* apply) |
| `-security` | `<enable>` | Enable/disable script-signing policies and core script certificates (requires the Harpy/Badge security plugins; errors if unavailable) |
| `-isolated` | `<enable>` | Enable/disable plugin isolation (`#if ISOLATED_PLUGINS`) |
| `-recreate` | -- | Copy interpreter settings, recreate the interpreter from (mostly) the old settings, then continue |
| `-reconfigure` | `<settings>` | Load the specified interpreter settings, recreate the interpreter from them, then continue |
| `-setCreate` | `<enable>` | Arrange for the interpreter to be recreated the next time its available commands would be modified |
| `-child` | -- | Switch to the child interpreter, if available, then continue |
| `-parent` | -- | Switch to the parent interpreter, if available, then continue |

### 14.5 Interactive Loop Control

| Option | Value | Description |
|--------|-------|-------------|
| `-interactive` | -- | Enable interactive mode for the interpreter, then continue |
| `-noExit` | -- | Arrange for the interactive loop to be entered instead of the process exiting, then continue |
| `-kiosk` | -- | Arrange for the interactive loop to be *reentered* instead of the process exiting, then continue |
| `-setLoop` | `<enable>` | Enable/disable entering the interactive loop, then continue |
| `-stopOnUnknown` | `<enable>` | Enable/disable relaxed unknown-argument handling for the interactive loop, then continue |
| `-quiet` | `<enable>` | Enable/disable quiet mode for the shell itself, then continue |
| `-profile` | `<profile>` | Load the specified interpreter host profile, then continue |
| `-lockHostArguments` | -- | Replace all arguments with those returned from the interpreter host and ignore `argv.txt` (processed prior to standard argument processing; no effect if the host returns none) |

### 14.6 Diagnostics, Tracing, and Debugging

| Option | Value | Description | Build guard |
|--------|-------|-------------|-------------|
| `-debug` | -- | Enable debug mode (emits strategically placed startup diagnostics), then continue | -- |
| `-step` | -- | Enable single-step mode for the script debugger, then continue | -- |
| `-break` | -- | Wait for a key press, then trigger a managed debugger break (useful for attaching a debugger), then continue | -- |
| `-pause` | -- | Wait for a key press, then continue (attach a managed debugger before any scripts run) | -- |
| `-setupTrace` | -- | Set up trace listeners appropriate to the current debug mode, then continue | -- |
| `-clearTrace` | -- | Clear all trace listeners, then continue | -- |
| `-traceToHost` | -- | Allow trace-listener output to be written to the interpreter host, then continue (intended for custom shells; the default shell ignores it) | -- |
| `-scriptTrace` | `<value>` | Use the value to create and add a trace listener, then continue | `TEST` |
| `-startupLogFile` | `<fileName>` | Set up tracing to the file (processed prior to interpreter creation), then continue | `TEST` |

> [!NOTE]
> There is no `-verbose` or `-trace` shell option (the `Prompt.Verbose` string
> is commented out in `Constants.cs`). `-verbose` exists only as a *command*
> option on certain commands (e.g. `[object]` and `[xml serialize]`); for shell
> startup diagnostics use `-debug` and the trace options above.

### 14.7 Argument Source and Plugin Options

| Option | Value | Description |
|--------|-------|-------------|
| `-arguments` | `<fileName>` | Read the file, interpret each line as a list of arguments, splice them in place of `-arguments <fileName>`, then continue. The literals for standard input may be used as the file name |
| `-noArgumentsFileNames` | -- | Skip processing arguments from files such as `argv.txt` (processed prior to standard argument processing) |
| `-noAppSettings` | -- | Skip processing arguments from application settings (processed prior to standard argument processing) |
| `-noTrim` | -- | Disable automatic trimming of surrounding whitespace for all subsequent arguments |
| `-encoding` | `<encodingName>` | Set the encoding used for script files, then continue |
| `-vendorPath` | `<path>` | Set the vendor path (extra sub-directory searched for user/application-specific files), then continue |
| `-pluginArguments` | `<pluginName> <arguments>` | Store arguments to pass into the named plugin if/when it is later loaded, then continue |

### 14.8 Test Harness Options

| Option | Value | Description |
|--------|-------|-------------|
| `-test` | `[pattern] [all] [argument ...]` | Run the matching test(s), or the full suite if no pattern is given, then **exit** |
| `-pluginTest` | `[pattern] [all] [argument ...]` | Run the matching plugin test(s), or the full plugin suite, then **exit** |
| `-testDirectory` | `<directory>` | Set the base directory used when searching for test files matching a pattern |

These tie into the test-suite entry point; see [`build_system.md`](build_system.md)
for how `make test` invokes them.

### 14.9 Help and Version

| Option | Equivalent | Description |
|--------|-----------|-------------|
| `-help` | `-?` | Display version and syntax (usage) information, then **exit** |
| `-?` | -- | About (`CommandLineOption.About`) |
| `-??` | -- | Command help (`CommandLineOption.CommandHelp`) |
| `-???` | -- | Environment help (`CommandLineOption.EnvironmentHelp`) |
| `-????` | -- | Full help (`CommandLineOption.FullHelp`) |
| `-version` | -- | Display detailed version information, then **exit** |

### 14.10 Usage in the POSIX Build System

The official POSIX `Makefile` (`Eagle/Makefile`) exercises two of these options
directly. Its `run` and `[test]` targets invoke the shell as:

```sh
# make run
dotnet exec --roll-forward Major EagleShell.dll -anyFile Makefile.eagle

# make test  (SHELL_DLL_ARGS plus the suite entry point and TEST_ARGS)
dotnet exec ... EagleShell.dll -anyFile Makefile.eagle \
    -file Library/Tests/all.eagle $(TEST_ARGS)
```

- `-anyFile Makefile.eagle` loads the build-time init helper regardless of
  library-initialization state (see section 14.2), then **continues** so the
  next arguments can be processed.
- `-file Library/Tests/all.eagle` then evaluates the suite entry point and
  **exits** (the terminal `-file` behavior from section 14.3), with any
  `TEST_ARGS` consumed as that script's arguments.

For the full build/test target reference and how `SHELL_DLL_ARGS`/`TEST_ARGS`
are assembled, see [`build_system.md`](build_system.md).
