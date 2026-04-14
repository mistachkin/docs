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
argument** for a top-level command (e.g., `exit`) or **2 arguments** for an
ensemble sub-command (e.g., `interp create`). It maps these argument strings
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
| `Eagle/Library/Components/Private/CommandOptions.cs` | Centralized option dictionary factory methods and dispatch (~5,000 lines) |
| `Eagle/Library/Components/Private/Enumerations.cs` | `CommandOptionType` enum (~200 values) |
| `Eagle/Library/Components/Private/ObjectOps.cs` | Remaining object-interop option factories (migrating to CommandOptions) |
| `Eagle/Library/Containers/Public/OptionDictionary.cs` | The dictionary container; implements option parsing and lookup |
| `Eagle/Library/Components/Public/Option.cs` | Individual option definition (`IOption` implementation) |
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

```
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
| `type` | The .NET `Type` used for enum parsing when `MustHaveEnumValue` is set | `typeof(EventFlags)`, `typeof(MatchMode)`, `null` |
| `flags` | Bitfield controlling parsing behavior (see Section 3) | `OptionFlags.None`, `OptionFlags.MustHaveValue`, etc. |
| `groupIndex` | Mutual-exclusion group number; options sharing a group are exclusive | `1`, `2`, `3`, or `Index.Invalid` (no group) |
| `index` | Tracks position after parsing; usually starts at `Index.Invalid` | `Index.Invalid` |
| `name` | Option name starting with `-`; case-sensitive unless `NoCase` flag | `"-nocase"`, `"-timeout"`, `"-encoding"` |
| `value` | Default `IVariant` value; `null` means no default | `new Variant(EventFlags.None)`, `null` |

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
| `Unsafe` | Option is hidden in safe interpreters. If a safe interpreter encounters this option, parsing fails with an error. This is Eagle's primary mechanism for restricting dangerous operations in sandboxed environments. |
| `Restricted` | Stronger than `Unsafe`; used for especially sensitive operations |

### 3.3 Behavioral Flags

| Flag | Meaning |
|------|---------|
| `NoCase` | Option name matching is case-insensitive (e.g., `-whatIf` matches `-whatif`). Used sparingly -- most options are case-sensitive. |
| `Unsupported` | Option is recognized but immediately rejected with an error. Used for platform-specific options on unsupported platforms (e.g., `-isolated` when `ISOLATED_PLUGINS` is not compiled in). Prevents silent ignoring. |
| `Ignored` | Option is recognized but its value is silently discarded. Used in two-pass option processing where an option was already consumed in an earlier pass. |
| `Nullable` | For typed values, allows the value to be null/empty |
| `CouldBePath` | Hint that the value might be a file path (affects validation) |

### 3.4 Common Flag Combinations

| Combination | Typical Use |
|-------------|-------------|
| `OptionFlags.None` | Simple boolean switch (`-force`, `-nocase`, `-verbose`) |
| `OptionFlags.MustHaveValue` | String-valued option (`-pattern`, `-variable`) |
| `OptionFlags.MustHaveIntegerValue` | Numeric option (`-timeout`, `-count`) |
| `OptionFlags.MustHaveEnumValue` | Enum-valued option (requires `typeof(T)` in constructor) |
| `OptionFlags.MustHaveValue \| OptionFlags.Unsafe` | Unsafe string option (`-message`, `-text`) |
| `OptionFlags.Unsafe` | Unsafe boolean switch (`-force`, `-debug`, `-security`) |
| `OptionFlags.Unsafe \| OptionFlags.Unsupported` | Conditionally unavailable unsafe option |
| `OptionFlags.MustHaveBooleanValue \| OptionFlags.Nullable` | Optional boolean (`-bundle`) |
| `OptionFlags.NoCase \| OptionFlags.MustHaveBooleanValue` | Case-insensitive boolean (`-breakOk`, `-noCancel`) |

---

## 4. Mutual-Exclusion Groups

The `groupIndex` parameter creates mutual-exclusion groups. When two options
share the same positive `groupIndex`, only the last one specified takes effect.
The earlier one's "present" flag is cleared.

**Example from `[lsort]`:**
```
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

```
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

```
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
```
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

### 8.1 Object Handle Management Options

These options appear in any command that creates or returns .NET object handles:

| Option | Flags | Purpose |
|--------|-------|---------|
| `-objectname` | `MustHaveValue` | Explicit name for the created handle |
| `-create` | configurable | Allow automatic object creation |
| `-nocreate` | configurable | Disallow automatic object creation |
| `-nodispose` | configurable | Prevent disposal when handle is removed |
| `-alias` | configurable | Create command alias for the handle |
| `-aliasraw` | `None` | Create raw (minimal processing) alias |
| `-aliasall` | `None` | Create comprehensive alias |
| `-aliasreference` | `None` | Create reference-tracking alias |
| `-tcl` | `None` | Bridge handle to a native Tcl interpreter |
| `-noforcedelete` | `None` | Don't force-delete the alias on cleanup |
| `-tostring` | `None` | Convert the result to string representation |
| `-objectflags` | `MustHaveEnumValue` | Override default `ObjectFlags` |

These are centralized in `ObjectOps.GetFixupReturnValueOptions()` and composed
into commands via the two-collection constructor.

### 8.2 Type Resolution Options

Commands that resolve .NET types commonly include:

| Option | Purpose |
|--------|---------|
| `-type` | .NET type name to resolve |
| `-objecttypes` | List of `ObjectOps` type categories to search |
| `-nocase` | Case-insensitive type name matching |
| `-stricttype` | Fail if type cannot be resolved (instead of warning) |
| `-verbose` | Show detailed type resolution information |

### 8.3 Method Invocation Options

Commands that invoke .NET methods include:

| Option | Purpose |
|--------|---------|
| `-marshalflags` | Control value conversion between Eagle and .NET |
| `-argumentflags` | Control by-reference argument handling |
| `-bindingflags` | .NET reflection binding flags for member lookup |
| `-objectflags` | Object handle management flags |
| `-byrefobjectflags` | Flags for by-reference return values |
| `-reorderflags` | Control parameter reordering for overload resolution |
| `-nobyref` | Disable by-reference argument passing |
| `-debug` | Enable debug output during invocation |
| `-trace` | Enable trace output during invocation |
| `-limit` / `-index` | Control overload selection when multiple match |

### 8.4 Security Options

Many commands include options restricted to unsafe interpreters:

| Pattern | Meaning |
|---------|---------|
| `OptionFlags.Unsafe` | Hidden in safe interpreters |
| `OptionFlags.Unsafe \| OptionFlags.MustHaveValue` | Unsafe string parameter |
| `OptionFlags.MustHaveRuleSetValue \| OptionFlags.CouldBePath \| OptionFlags.Unsafe` | Rule set for security validation (unsafe because it could reference filesystem paths) |

Common unsafe options across commands: `-interpreter`, `-sdk`, `-security`,
`-nosecurity`, `-debug`, `-thread`, `-timeout`, `-ruleset`.

### 8.5 Encoding Options

Commands dealing with I/O consistently use:

| Option | Flags | Commands |
|--------|-------|----------|
| `-encoding` | `MustHaveEncodingValue` | `gets`, `puts`, `source`, `base64`, `hash`, `read`, etc. |
| `-encoding` | `MustHaveEncodingValue \| Unsafe` | `gets`, `puts` (unsafe because it could affect security-sensitive I/O) |

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

## 13. The `DataTable` Result Format

Eagle's `[sql execute]` command supports a `DataTable` result format that
materializes query results as a custom `DataTable` object (derived from
`System.Data.DataTable`) with value-added methods for Eagle scripting.

### 13.1 Usage

```tcl
set table [sql execute -execute reader -format datatable $db \
    "SELECT id, name, age FROM users;"]
```

The returned opaque handle wraps a `DataOps.DataTable` object that inherits
all standard `System.Data.DataTable` functionality (Rows, Columns, Select,
etc.) and adds Eagle-specific convenience methods.

### 13.2 Value-Added Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `ToList` | StringList | Converts all rows to a Tcl list of row-value lists, applying the same value formatting (`FixupDataValue`) as other `[sql execute]` formats. Each row is a sub-list of formatted values. Replaces the manual `getRowsFromDataTable` pattern. |
| `ToDictionary` | StringList | Like `ToList` but each row is a key-value list: `{colName value colName value ...}`. Enables named column access without positional indexing. |
| `GetColumnNames` | StringList | Returns column names as a Tcl list. |

### 13.3 Inherited .NET Functionality

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

### 13.4 Comparison with Other Formats

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

## 12. Per-Command Option Reference

This section documents every option for every command and sub-command,
organized alphabetically. For each option: its name, value type (if any),
and what it controls.

<details>
<summary><code>[after idle]</code> and <code>[after &lt;milliseconds&gt;]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-thread` | int64 | Thread ID for event execution; controls which thread runs the scheduled script |
| `-priority` | EventPriority | Scheduling priority relative to other events; defaults to `Idle` for idle events, `After` for timed events |
| `-flags` | EventFlags | Event behavior flags (e.g., error handling); defaults to `None` |

</details>

<details>
<summary><code>[array copy]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-deep` | -- | Perform deep copy: for System.Array-backed variables, creates a new array instance with copied data; without this, both variables share the same underlying storage |
| `-nosignal` | -- | Suppress the variable "dirty" signal (`EntityOps.SignalDirty`) that normally notifies observers of the change |

</details>

<details>
<summary><code>[array random]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-strict` | -- | Return error if array is empty instead of empty string |
| `-pair` | -- | Return a two-element list `{name value}` instead of just the name |
| `-valueonly` | -- | Return only the value of the randomly selected element |
| `-matchname` | -- | When a pattern argument is given, match it against element names/keys |
| `-matchvalue` | -- | When a pattern argument is given, match it against element values |

</details>

<details>
<summary><code>[base64 decode]</code> and <code>[base64 encode]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for byte-to-string conversion (decode) or string-to-byte conversion (encode); defaults to binary encoding |

</details>

<details>
<summary><code>[clock days]</code> / <code>[clock buildnumber]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Date format string for parsing the input date value |
| `-epoch` | DateTime | Reference point for calculating elapsed days; defaults to start of year (`days`) or `TimeOps.BuildEpoch` (`buildnumber`) |
| `-gmt` | boolean | When true, interpret times as UTC; when false, use local time |

</details>

<details>
<summary><code>[clock clicks]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-microseconds` | -- | Return high-resolution CPU tick count in microseconds via `PerformanceOps.GetMicroseconds()` |
| `-milliseconds` | -- | Return system tick count in milliseconds via `PerformanceOps.GetTickCount()` |

When neither flag is specified, returns the highest-resolution counter available
via `PerformanceOps.GetCount()`.

</details>

<details>
<summary><code>[clock duration]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | DurationFlags | Controls output format; when `DurationFlags.Human` is set, returns human-readable text like "2 days, 3 hours"; otherwise returns raw TimeSpan |

</details>

<details>
<summary><code>[clock filetime]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Output format string; when present, formats via `FormatOps.TclClockDateTime()`; when absent, returns raw DateTime |
| `-epoch` | DateTime | Reference epoch; defaults to `TimeOps.UnixEpoch` |
| `-gmt` | boolean | When true, uses `DateTime.FromFileTimeUtc()`; when false, uses `DateTime.FromFileTime()` |

</details>

<details>
<summary><code>[clock format]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Custom format string; when present, formats via `FormatOps.TclClockDateTime()` |
| `-kind` | DateTimeKind | Interpretation of the input clock value (UTC vs Local vs Unspecified) |
| `-ticks` | -- | Interpret input as .NET ticks instead of Unix seconds |
| `-epoch` | DateTime | Reference epoch for calculations; defaults to `TimeOps.UnixEpoch` |
| `-gmt` | boolean | When true, interpret and format as UTC |
| `-iso` | -- | Return ISO 8601 format |
| `-full` | -- | With `-iso`, use full ISO format instead of compact |
| `-isotimezone` | -- | With `-iso`, include timezone designator |

</details>

<details>
<summary><code>[clock now]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-gmt` | boolean | When true, return UTC DateTime ticks; when false, return local DateTime ticks |

</details>

<details>
<summary><code>[clock scan]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-format` | string | Date format string for parsing input |
| `-base` | int64 | Legacy Tcl compatibility; accepted but **not used** in Eagle |
| `-epoch` | DateTime | Reference epoch for converting parsed DateTime to seconds; defaults to `TimeOps.UnixEpoch` |
| `-gmt` | boolean | When true, treat input as UTC; when false, treat as local time |

</details>

<details>
<summary><code>[debug break]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Target a specific child interpreter for the breakpoint |
| `-ignoreenabled` | -- | Break even if the debugger is currently disabled |
| `-complain` | -- | Show detailed error information on break failure |
| `-nocomplain` | -- | Suppress error information on break failure |
| `-noerror` | -- | Don't set error return code on break failure |

</details>

<details>
<summary><code>[debug emergency]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Target a specific child interpreter |
| `-ignoreenabled` | -- | Proceed even if the debugger is currently disabled |
| `-nocomplain` | -- | Suppress error information |
| `-noerror` | -- | Don't set error return code on failure |

</details>

<details>
<summary><code>[debug hook]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-type` | TestHookType | Which test hook type to install; defaults to `TestHookType.Default` |
| `-unset` | boolean | When true, remove the hook instead of installing it |

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
| `-timeout` | int | Timeout in milliseconds for the sandboxed evaluation |
| `-nocancel` | boolean | Don't honor cancellation requests during evaluation |
| `-globalcancel` | boolean | Use global cancellation flag instead of per-interpreter |
| `-stoponerror` | boolean | Stop execution on first error |
| `-file` | boolean | Treat the script argument as a file path |
| `-trusted` | boolean | Evaluate in a trusted context |
| `-events` | boolean | Process events during evaluation |
| `-noisolatedplugins` | boolean | Disable isolated plugin loading in the sandbox |

</details>

<details>
<summary><code>[debug set]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-reference` | int | Reference count adjustment for the object |
| `-convert` | boolean | Convert the value before setting |

</details>

<details>
<summary><code>[debug shell]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Which interpreter runs the debug shell |
| `-initialize` | boolean | Initialize the shell environment before entering |
| `-loop` | boolean | Enter the interactive loop (vs. single evaluation) |
| `-asynchronous` | boolean | Run the debug shell asynchronously on a separate thread |

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
| `-noresult` | boolean | Suppress result display in trace output |
| `-default` | boolean | Reset trace listeners to defaults |
| `-console` | boolean | Enable/disable console trace listener |
| `-native` | boolean | Enable/disable native (OS) trace listener |
| `-statusform` | boolean | Enable/disable status form trace listener |
| `-debug` | boolean | Enable/disable debug trace listener |
| `-raw` | boolean | Raw trace output without formatting |
| `-log` | boolean | Enable/disable log file trace output |
| `-resetsystem` | boolean | Reset the system trace source |
| `-resetlisteners` | boolean | Reset all trace listeners |
| `-forceenabled` | boolean | Force trace output even if normally disabled |
| `-overrideenvironment` | boolean | Override environment-based trace configuration |
| `-enabledcategories` | list | List of trace categories to enable |
| `-disabledcategories` | list | List of trace categories to disable |
| `-penaltycategories` | list | Categories that receive penalty scoring |
| `-bonuscategories` | list | Categories that receive bonus scoring |
| `-statetypes` | TraceStateType | Which trace state types to configure; defaults to `TraceCommand` |
| `-priority` | TracePriority | Minimum priority level for trace output; defaults to `TraceOps.GetTracePriority()` |
| `-priorities` | TracePriority | Combined priority flags; defaults to `TraceOps.GetTracePriorities()` |
| `-category` | string | Set the default trace category |
| `-logname` | string | Log file name (TEST builds only) |
| `-logfilename` | string | Log file path (TEST builds only) |
| `-logflags` | LogFlags | Log behavior flags (TEST builds only); defaults to `LogFlags.Default` |

</details>

<details>
<summary><code>[debug variable]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-searches` | -- | Include variable search information in output |
| `-elements` | -- | Include array element information |
| `-links` | -- | Include variable link/alias information |
| `-empty` | -- | Include empty/unset variables |

</details>

<details>
<summary><code>[exit]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-message` | string | Exit message displayed to the user |
| `-force` | -- | Force exit even if normally prevented by the host |
| `-fail` | -- | Mark exit as a failure (affects exit code handling) |
| `-nodispose` | -- | Skip interpreter disposal on exit |
| `-nocomplain` | -- | Suppress warning/error messages during exit |
| `-current` | -- | Use the interpreter's current exit code instead of the default success code |

</details>

<details>
<summary><code>[fconfigure]</code> (set mode)</summary>

Used when 4+ arguments: `fconfigure channelId -option value ...`

| Option | Value | Description |
|--------|-------|-------------|
| `-blocking` | boolean | Set channel blocking mode |
| `-buffer` | boolean | When true, enable buffering (`channel.NewBuffered()`); when false, disable it (`channel.ResetBuffered()`) |
| `-encoding` | Encoding | Set the channel's character encoding |
| `-translation` | list | One or two `StreamTranslation` values controlling line-ending translation (input and/or output) |

</details>

<details>
<summary><code>[fconfigure]</code> (query mode)</summary>

Used when exactly 3 arguments: `fconfigure channelId -option`

| Option | Value | Description |
|--------|-------|-------------|
| `-blocking` | -- | Query current blocking mode (returns boolean) |
| `-encoding` | -- | Query current encoding (returns encoding WebName or null marker) |
| `-translation` | -- | Query current translation mode |

Note: In query mode, `-buffer` is not available. Option flags differ from set
mode (e.g., `-encoding` uses `OptionFlags.None` instead of
`MustHaveEncodingValue`).

</details>

<details>
<summary><code>[fcopy]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-size` | int | Maximum bytes to copy; when negative or absent, copies until end-of-file |
| `-command` | string | Callback command for async copy; currently **accepted but not implemented** |
| `-eventflags` | EventFlags | Controls event processing during the copy loop; defaults to `interpreter.EngineEventFlags` |

</details>

<details>
<summary><code>[file cleanup]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-type` | PathType | Type of paths to clean up; defaults to `PathType.Cleanup` |
| `-pattern` | string | Filter cleanup paths by wildcard/regex pattern |
| `-nocase` | -- | Case-insensitive pattern matching |
| `-recursive` | -- | Recursively clean subdirectories |
| `-force` | -- | Force cleanup even if paths are in use |
| `-nocomplain` | -- | Suppress errors for missing paths |
| `-now` | -- | Execute cleanup immediately instead of deferring |

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
| `-match` | MatchMode | Matching mode (Glob, Exact, Regexp, SubString); defaults to `StringOps.DefaultMatchMode` |
| `-nocase` | -- | Case-insensitive pattern matching |
| `-directory` | string | Search in this directory instead of current working directory |
| `-searchpattern` | string | Pattern for the initial filesystem enumeration |

</details>

<details>
<summary><code>[file information]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-directory` | boolean | Explicitly specify whether the path is a directory (Windows) |
| `-reparse` | boolean | Follow reparse points such as junctions and symlinks (Windows) |

</details>

<details>
<summary><code>[file normalize]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-legacy` | boolean | Use legacy path normalization for Eagle beta compatibility |

</details>

<details>
<summary><code>[file objectid]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-directory` | boolean | Explicitly specify whether the path is a directory (Windows) |
| `-create` | boolean | Create the object ID if it does not already exist (Windows) |

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
| `-flags` | SddlFlags | Controls which ACL entries to include and output format; supports `IncludeExplicit`, `IncludeInherited`, `SkipBadRights`, `Remove`, `ToList`; defaults to `SddlFlags.Default` |

</details>

<details>
<summary><code>[file under]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-mode` | MatchMode | How to match paths; defaults to `MatchMode.None` |
| `-searchoption` | SearchOption | `TopDirectoryOnly` or `AllDirectories`; defaults to `AllDirectories` |
| `-pathtype` | PathType | How to interpret/normalize paths; defaults to `PathType.Under` |
| `-contains` | -- | Return list of matching items under the path instead of a boolean |
| `-failonerror` | -- | Treat filesystem enumeration errors as failures |

</details>

<details>
<summary><code>[file version]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-full` | -- | Return the complete `FileVersionInfo` string |
| `-fixed` | -- | Return the fixed version number (major.minor.build.revision) |

</details>

<details>
<summary><code>[gets]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for channel I/O |
| `-usecount` | -- | Read a count-prefixed record (first N bytes specify data length) |
| `-noblock` | -- | Non-blocking read; return immediately if no data is available |
| `-keepeol` | boolean | Keep end-of-line characters in the result |
| `-count` | int | Read exactly N bytes/characters |

</details>

<details>
<summary><code>[glob]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-path` | string | Prepend this path prefix to all results; conflicts with `-directory` |
| `-directory` | string | Search in this directory; conflicts with `-path` |
| `-types` | list | File type filter dictionary |
| `-join` | -- | Join multiple pattern arguments before matching |
| `-tails` | -- | Return only filenames, not full paths (requires `-path` or `-directory`) |
| `-nocomplain` | -- | Don't error if no files match the pattern |
| `-noerror` | -- | Return empty on glob errors instead of raising an error |

</details>

<details>
<summary><code>[hash keyed]</code>, <code>[hash mac]</code>, <code>[hash normal]</code></summary>

All three sub-commands share identical options:

| Option | Value | Description |
|--------|-------|-------------|
| `-object` | -- | Input is an opaque object handle (byte array) instead of a string |
| `-raw` | -- | Return hash as raw ByteList instead of hexadecimal string |
| `-filename` | -- | Treat the input argument as a file path and hash the file contents |
| `-encoding` | Encoding | Character encoding for string-to-bytes conversion; cannot combine with `-object` |

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
| `-sizetype` | HostSizeType | Which size dimension to reset (Default, Buffer, Window) |
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
| `-sizetype` | HostSizeType | Which size to get/set (Default, Buffer, Window) |
| `-norestore` | -- | Don't restore original size if setting a new size fails |
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
| `-x` / `-relx` | int | Absolute / relative X position for the box |
| `-y` / `-rely` | int | Absolute / relative Y position for the box |
| `-fg` / `-foreground` | ConsoleColor | Text foreground color |
| `-bg` / `-background` | ConsoleColor | Text background color |
| `-boxfg` / `-boxforeground` | ConsoleColor | Box border foreground color |
| `-boxbg` / `-boxbackground` | ConsoleColor | Box border background color |
| `-nohandle` | -- | Don't interpret the argument as an object handle |
| `-multiple` | -- | Treat the argument as a list of items; write each one |
| `-noposition` | -- | Don't query current cursor position; use (0,0) |
| `-noboxcolors` | -- | Don't apply box-specific colors |
| `-nocolors` | -- | Don't apply any colors |
| `-pairs` | -- | Parse the list as key-value pairs |
| `-newline` | -- | Write a newline after the box |
| `-separator` | -- | Convert "null" strings to actual nulls |
| `-norestore` | -- | Don't restore original colors after drawing |

</details>

<details>
<summary><code>[info commands]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Query a specific child interpreter |
| `-sdk` | SdkType | SDK filter (Default, Tcl, Snit, etc.); defaults to `SdkType.Default` |
| `-breakpoint` | -- | Include breakpoint commands |
| `-core` | -- | Include core/system commands |
| `-library` | -- | Include library-defined commands |
| `-nocore` | -- | Exclude core/system commands |
| `-nolibrary` | -- | Exclude library-defined commands |
| `-interactive` | -- | Include interactive-only commands |
| `-nocommands` | -- | Exclude regular commands (show only procedures, aliases, etc.) |
| `-noprocedures` | -- | Exclude user-defined procedures |
| `-noexecutes` | -- | Exclude execute-type procedures |
| `-noaliases` | -- | Exclude command aliases |
| `-safe` | -- | Include only commands safe for sandboxed interpreters |
| `-unsafe` | -- | Include only unsafe commands |
| `-standard` | -- | Include only standard commands |
| `-nonstandard` | -- | Include only non-standard (extension) commands |
| `-hidden` | -- | Include hidden commands |
| `-hiddenonly` | -- | Show only hidden commands |
| `-strict` | -- | Use strict filtering rules |

</details>

<details>
<summary><code>[info functions]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | Interpreter | Query a specific child interpreter |
| `-safe` / `-unsafe` | -- | Filter by safe/unsafe classification |
| `-standard` / `-nonstandard` | -- | Filter by standard/non-standard classification |
| `-hidden` | -- | Include hidden functions |

</details>

<details>
<summary><code>[info loaded]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nocore` | -- | Exclude core/system plugins (those with `PluginFlags.System`) |

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
| `-hidden` | boolean | When true, search hidden commands; when false, search visible commands |

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
| `-createflags` | CreateFlags | Override interpreter creation flags for command population |
| `-interpreterflags` | InterpreterFlags | Override interpreter flags |
| `-ruleset` | IRuleSet | Custom rule set for security validation of added commands |
| `-safetyoverride` | -- | Override safe interpreter restrictions when adding commands |
| `-repopulate` | -- | Remove existing commands before adding new ones |

</details>

<details>
<summary><code>[interp cancel]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-global` | -- | Cancel all interpreters, not just the target |
| `-nolocal` | -- | Skip canceling the local interpreter |
| `-unwind` | -- | Unwind the call stack during cancellation |

</details>

<details>
<summary><code>[interp create]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-creationflagtypes` | CreationFlagTypes | Which sets of creation flags to apply; defaults to `Defaults.CreationFlagTypes` |
| `-ruleset` | IRuleSet | Security rule set for the new interpreter |
| `-peer` | PeerType | Peer relationship type; defaults to `PeerType.Default` |
| `-namespaces` | -- | Enable namespace support in the new interpreter |
| `-nocommands` | -- | Don't populate standard commands |
| `-nofunctions` | -- | Don't populate standard functions |
| `-nonamespaces` | -- | Don't create default namespaces |
| `-novariables` | -- | Don't create standard variables |
| `-noloader` | -- | Don't initialize the script/plugin loader |
| `-noinitialize` | -- | Skip interpreter initialization entirely |
| `-alias` | -- | Create a command alias for the new interpreter |
| `-safe` | -- | Create a safe (sandboxed) interpreter |
| `-sdk` | SdkType | SDK type for the interpreter (DEBUG builds only) |
| `-nohidden` | -- | Don't hide unsafe commands in the new interpreter |
| `-standard` | -- | Use standard command set only |
| `-unsafeinitialize` | -- | Allow unsafe initialization steps |
| `-isolated` | -- | Create in an isolated AppDomain (requires `ISOLATED_INTERPRETERS`) |
| `-debug` | -- | Enable debugger in the new interpreter (requires `DEBUGGER`) |
| `-test` | -- | Enable test mode (requires `TEST_PLUGIN` or `DEBUG`) |
| `-monitor` | -- | Enable notification monitoring (requires `NOTIFY && NOTIFY_ARGUMENTS`) |
| `-probing` | -- | Enable assembly probing paths (requires `APPDOMAINS`) |
| `-noprobing` | -- | Disable assembly probing paths |
| `-security` | -- | Enable security subsystem |
| `-nosecurity` | -- | Disable security subsystem |
| `-nocorepolicies` | -- | Don't install core security policies |
| `-nopluginpolicies` | -- | Don't install plugin security policies |

</details>

<details>
<summary><code>[interp invokehidden]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-global` | -- | Invoke in the global namespace |
| `-namespace` | string | Invoke in the specified fully-qualified namespace |

</details>

<details>
<summary><code>[interp policy]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-type` | Type | .NET type of the policy callback |
| `-token` | int64 | Security token for policy authorization |
| `-flags` | PolicyFlags | Policy behavior flags; defaults to `PolicyFlags.Script` |

</details>

<details>
<summary><code>[interp queue]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-when` | DateTime | Schedule the queued script for a specific time |

</details>

<details>
<summary><code>[interp readorgetscriptfile]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for reading the script file |
| `-variable` | string | Store the script content in this variable instead of evaluating |
| `-package` | boolean | Treat the file as a package script |
| `-scriptflags` | ScriptFlags | Override script evaluation flags; defaults to child interpreter's current flags |
| `-engineflags` | EngineFlags | Override engine flags; defaults to child interpreter's current flags |

This is the most complex option processing pattern in the library. See
[Section 7.2](#72-scan-then-get-deferred-defaults) for the scan-then-get
architecture.

</details>

<details>
<summary><code>[interp rename]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nodelete` | -- | Keep the original name (create a copy, not a rename) |
| `-all` | -- | Rename all matching identifiers |
| `-hidden` | -- | Make the new name hidden from enumeration |
| `-hiddenonly` | -- | Make both old and new names hidden |
| `-kind` | IdentifierKind | Type of identifier to rename (Command, Function, Variable, etc.); defaults to `None` |
| `-newnamevar` | string | Store the actual new name in this variable |

</details>

<details>
<summary><code>[interp resetcancel]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-global` | -- | Reset cancellation for all interpreters |
| `-nolocal` | -- | Skip resetting the local interpreter |
| `-force` | -- | Force reset even if cancellation is locked |

</details>

<details>
<summary><code>[interp service]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-dedicated` | -- | Use a dedicated service thread |
| `-nocancel` | -- | Don't honor cancellation during servicing |
| `-noglobalcancel` | -- | Ignore global cancellation flag |
| `-erroronempty` | -- | Return error when the event queue is empty |
| `-userinterface` | -- | Process user interface events |
| `-nocomplain` | -- | Suppress service errors |
| `-thread` | int64 | Target thread for event servicing |
| `-limit` | int | Maximum number of events to process per call |
| `-eventflags` | EventFlags | Event processing flags; defaults to child interpreter's `ServiceEventFlags` |
| `-priority` | EventPriority | Minimum event priority to process; defaults to `EventPriority.Service` |

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
| `-flags` | SubCommandFlags | Sub-command registration flags; defaults to `SubCommandFlags.Default` |

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
| `-all` | -- | Kill all processes matching the given name, not just one |
| `-force` | -- | Force termination without graceful shutdown |
| `-whatIf` | -- | Show what would be killed without actually terminating (case-insensitive option name) |
| `-verbose` | -- | Display detailed information about the operation |

</details>

<details>
<summary><code>[library declare]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-alias` | -- | Create an alias for the declared function |
| `-module` | string | Module containing the native function |
| `-functionname` | string | Override the function name |
| `-address` | int64 | Direct memory address of the function |
| `-returntype` | Type | .NET return type of the function |
| `-parametertypes` | Type list | .NET types of all function parameters |
| `-callingconvention` | CallingConvention | Calling convention (Cdecl, StdCall, etc.) |
| `-assemblyname` | string | Assembly name for the generated delegate |
| `-modulename` | string | Module builder name |
| `-typename` | string | Type name for the generated delegate wrapper |
| `-bestfitmapping` | boolean | Enable best-fit character mapping for Unicode conversion |
| `-charset` | CharSet | Character set for P/Invoke marshaling |
| `-setlasterror` | boolean | Preserve Windows `GetLastError()` codes |
| `-throwonunmappablechar` | boolean | Throw on unmappable Unicode characters |
| `-delegatename` | string | Name for the created delegate type |

</details>

<details>
<summary><code>[library load]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-modulename` | string | Native library module name |
| `-locked` | -- | Lock the module in memory, preventing unloading |
| `-maybetrustedonly` | -- | Only load if verified trusted (lenient) |
| `-trustedonly` | -- | Only load modules verified as trusted |
| `-flags` | ModuleFlags | Module loading behavior flags; defaults to `ModuleFlags.None` |

</details>

<details>
<summary><code>[library resolve]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-module` | string | Which loaded module contains the function |
| `-functionname` | string | Function name to resolve within the module |

</details>

<details>
<summary><code>[library unresolve]</code></summary>

No options (only end-of-options marker).

</details>

<details>
<summary><code>[load]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-ruleset` | IRuleSet | Custom rule set for plugin security validation |
| `-needclientdata` | -- | Auto-create client data if not provided by caller |
| `-anythread` | -- | Allow loading on any thread, not just the main thread |
| `-nocommands` | -- | Don't register commands defined by the plugin |
| `-nofunctions` | -- | Don't register functions defined by the plugin |
| `-nopolicies` | -- | Don't install security policies from the plugin |
| `-notraces` | -- | Don't install trace callbacks from the plugin |
| `-noprovide` | -- | Don't call the plugin's `Provide` method |
| `-noresources` | -- | Don't load resource definitions |
| `-verifiedonly` | -- | Only load plugins with verified digital signatures |
| `-maybeverifiedonly` | -- | Verified-only (lenient; allowed in safe interpreters) |
| `-trustedonly` | -- | Only load plugins in the trusted set |
| `-maybetrustedonly` | -- | Trusted-only (lenient; allowed in safe interpreters) |
| `-publickeytoken` | string | Verify the plugin's public key token matches |
| `-isolated` / `-noisolated` | -- | Load into isolated / default AppDomain |
| `-preview` / `-nopreview` | -- | Enable/disable plugin metadata preview for update checking |
| `-update` / `-noupdate` | -- | Check/skip checking for updated plugin version |
| `-clientdata` | object | Supply custom client data object |
| `-data` | object | Additional data to associate with the plugin |
| `-viaresource` | -- | Load from embedded resource instead of file |

</details>

<details>
<summary><code>[lsearch]</code></summary>

**Mutual-exclusion groups:**

| Group | Options | Description |
|-------|---------|-------------|
| 1 (value type) | `-ascii`, `-dictionary`, `-integer`, `-real` | How to interpret list elements for comparison |
| 2 (sort order) | `-decreasing`, `-increasing` | Sort direction for `-sorted` mode |
| 3 (match mode) | `-exact`, `-substring`, `-glob`, `-regexp`, `-sorted` | How to match the pattern against elements |

| Option | Value | Description |
|--------|-------|-------------|
| `-variable` | -- | First argument is a variable name containing the list |
| `-inverse` | -- | Return indices of non-matching elements |
| `-subindices` | -- | Return sub-indices when searching nested lists |
| `-all` | -- | Return all matching indices instead of just the first |
| `-inline` | -- | Return matched elements instead of their indices |
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
<summary><code>[open]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-stdin` / `-stdout` / `-stderr` | -- | Open the corresponding standard stream (mutually exclusive; requires `CONSOLE`) |
| `-channelid` | string | Assign a custom identifier to the opened channel |
| `-buffersize` | int | Internal buffer size for the channel |
| `-nullencoding` | -- | Use null encoding mode |
| `-autoflush` | -- | Automatically flush after every write |
| `-rawendofstream` | -- | Raw end-of-stream behavior without platform filtering |
| `-streamflags` | HostStreamFlags | Stream behavior flags; defaults to `HostStreamFlags.Default` |
| `-options` | FileOptions | File opening options; defaults to `FileOptions.None` |
| `-share` | FileShare | File sharing mode; defaults to `FileShare.Read` |

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
| `-exact` | -- | Require exact version match (no "compatible" version resolution) |
| `-autoscan` | boolean | Automatically scan for packages if not already found |

</details>

<details>
<summary><code>[package scan]</code></summary>

See [Section 7.1](#71-two-pass-option-processing) for the two-pass
architecture. Pre-options and main options are separate dictionaries.

**Pre-options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-interpreter` | -- | Use the specified child interpreter's flags as defaults |

**Main options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-flags` | PackageIndexFlags | Override package index scanning flags; defaults to interpreter's `PackageIndexFlags` |
| `-reset` | -- | Reset package index before scanning |
| `-autopath` | -- | Include auto-path directories in the scan |
| `-whatIf` | -- | Show what would be scanned without actually scanning (disables Host, Bundle, Plugin flags; adds WhatIf) |
| `-preferfilesystem` | -- | Prefer filesystem over host-provided packages |
| `-preferhost` | -- | Prefer host-provided packages over filesystem |
| `-host` / `-nohost` | -- | Enable/disable host-provided package scanning |
| `-bundle` / `-nobundle` | -- | Enable/disable bundle-based package scanning |
| `-plugin` / `-noplugin` | -- | Enable/disable plugin-based package scanning (requires `APPDOMAINS`) |
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
| `-fileerror` | -- | Don't suppress file I/O errors during scanning |

</details>

<details>
<summary><code>[parse command]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-engineflags` | EngineFlags | Override engine flags; defaults to `interpreter.EngineFlags` |
| `-substitutionflags` | SubstitutionFlags | Override substitution flags; defaults to `interpreter.SubstitutionFlags` |
| `-startindex` | int | Start parsing from this character index |
| `-characters` | int | Maximum characters to parse |
| `-nested` | boolean | Parse as a nested command (within `[...]`) |
| `-noready` | boolean | Skip the interpreter readiness check |

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
| `-flags` | OptionBehaviorFlags | Option parsing behavior; defaults to `OptionBehaviorFlags.Default` |
| `-optionsvar` | string | Store parsed options dictionary in this variable |
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
| `-filename` | string | Associate a filename with the parsed script (for error reporting) |
| `-currentline` | int | Starting line number for error reporting |
| `-startindex` | int | Start parsing from this character index |
| `-characters` | int | Maximum characters to parse |
| `-nested` | boolean | Parse as nested script |
| `-syntax` | boolean | Syntax-check only (don't evaluate) |
| `-strict` | boolean | Strict parsing mode |
| `-roundtrip` | boolean | Preserve enough information for round-trip reconstruction |
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
| `-options` | RegexOptions | .NET regex options; defaults to `StringOps.DefaultRegExSyntaxOptions` |
| `-all` | -- | Find all non-overlapping matches |
| `-global` | -- | Synonym for `-all` |
| `-debug` | -- | Enable debug output (**unsupported**) |
| `-about` | -- | Show regex engine info (**unsupported**) |
| `-ecma` | -- | Use ECMAScript regex syntax |
| `-compiled` | -- | Compile regex for faster repeated execution |
| `-explicit` | -- | Require all capturing groups to be named |
| `-reverse` | -- | Reverse search direction |
| `-expanded` | -- | Allow whitespace and comments in the pattern |
| `-indexes` / `-indices` | -- | Return start/end positions instead of matched strings |
| `-inline` | -- | Return matched strings directly |
| `-skip` | int | Skip the first N matches |
| `-limit` | int | Maximum number of matches to return |
| `-line` | -- | Single-line mode (dot does not match newline) |
| `-lineanchor` | -- | `^` and `$` match line boundaries |
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
| `-options` | RegexOptions | .NET regex options; defaults to `StringOps.DefaultRegExSyntaxOptions` |
| `-all` | -- | Replace all occurrences (default is first only) |
| `-count` | int | Store the replacement count in a variable |
| `-ecma` | -- | ECMAScript regex syntax |
| `-compiled` | -- | Compile regex |
| `-explicit` | -- | Require named groups |
| `-quote` | -- | Quote regex metacharacters in the pattern |
| `-nostrict` | -- | Non-strict substitution mode |
| `-reverse` | -- | Reverse replacement direction |
| `-eval` | string | Evaluate this script for each match to compute replacement |
| `-command` | -- | Use TIP #463 command-based replacement |
| `-literal` | -- | Treat replacement as a literal string (no backslash substitution) |
| `-verbatim` | -- | Verbatim replacement |
| `-extra` | -- | Enable extended `\P`, `\I`, `\S`, `\M#`, `\N<name>` substitutions |
| `-expanded` | -- | Allow whitespace and comments in pattern |
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
| `-kind` | IdentifierKind | Type of identifier (Command, Function, etc.); defaults to `None` |
| `-newnamevar` | string | Store the actual new name in this variable |

</details>

<details>
<summary><code>[return]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-code` | ReturnCode | Return code (Ok, Error, Return, Break, Continue) |
| `-errorinfo` | string | Error stack trace information |
| `-errorcode` | string | Machine-readable error code |

</details>

<details>
<summary><code>[scope close]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-all` | -- | Close all open scopes, not just the current one |

</details>

<details>
<summary><code>[scope create]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-args` | -- | Pass arguments to the scope constructor |
| `-clone` | -- | Clone variables from an existing scope |
| `-byref` | -- | Create by-reference scope (variables are shared, not copied) |
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
| `-eventwaitflags` | EventWaitFlags | Event waiting behavior during evaluation; defaults to `interpreter.EventWaitFlags` |
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
| `-nocomplain` | -- | Suppress errors if the lock/unlock operation fails |

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
| `-timeouttype` | TimeoutType | Timeout semantics (Infinite, Default) |
| `-addressfamily` | AddressFamily | IPv4, IPv6, or other address family |
| `-keepalive` | boolean | Enable TCP keep-alive |
| `-server` | string | Server callback command; presence makes this a server socket |
| `-buffer` | int | Socket buffer size in bytes |
| `-timeout` | int | General operation timeout in milliseconds |
| `-sendtimeout` | int | Send operation timeout |
| `-receivetimeout` | int | Receive operation timeout |
| `-availabletimeout` | int | Timeout for checking data availability |
| `-readtimeout` | int | Read operation timeout |
| `-writetimeout` | int | Write operation timeout |
| `-myaddr` | string | Local address to bind to |
| `-myport` | string | Local port to bind to |
| `-async` | -- | Asynchronous mode (**unsupported**) |
| `-channelid` | string | Custom channel identifier |
| `-nodelay` | -- | Disable Nagle algorithm (TCP_NODELAY); client only |
| `-nobuffer` | -- | Disable socket buffering; client only |
| `-noexclusive` | -- | Allow multiple listeners on the same port; server only |
| `-trace` | -- | Enable socket operation tracing |

</details>

<details>
<summary><code>[source]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-encoding` | Encoding | Character encoding for the source file |
| `-withinfo` | boolean | Return source file metadata along with result |
| `-time` | boolean | Measure and return execution time |
| `-password` | byte[] | Decryption password for encrypted script files |
| `-library` | boolean | Treat the file as library code |
| `-bundle` | boolean | Load from a script bundle resource instead of a file (requires `DATA`) |
| `-bundleflags` | BundleFlags | Bundle loading behavior; defaults to `BundleFlags.Default` (requires `DATA`) |

</details>

<details>
<summary><code>[split]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-string` | -- | Use string split semantics instead of character-based splitting |

</details>

<details>
<summary><code>[string equal]</code> / <code>[string compare]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-culture` | CultureInfo | Culture for locale-aware comparison (requires `NET_20_SP2` or `NET_40`) |
| `-options` | CompareOptions | Fine-grained comparison control (requires `NET_20_SP2` or `NET_40`) |
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
| `-valueformat` | string | Custom format specification for values |
| `-datetimekind` | DateTimeKind | DateTime interpretation; defaults to `interpreter.DateTimeKind` |
| `-datetimestyles` | DateTimeStyles | DateTime parsing styles; defaults to `ObjectOps.GetDefaultDateTimeStyles()` |
| `-culture` | CultureInfo | Culture for formatting |
| `-verbatim` | -- | Pass format string verbatim to `String.Format` |
| `-valueflags` | ValueFlags | Value conversion flags; defaults to `ValueFlags.AnyNonCharacter` |

</details>

<details>
<summary><code>[string is]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-strict` | -- | Return false (instead of true) for empty strings |
| `-nocomplain` | -- | Suppress detailed error messages |
| `-not` | boolean | Invert the test result; default comes from parsing `"not"` prefix words |
| `-any` | boolean | Match if any character satisfies the test (vs. all characters) |
| `-via` | boolean | Use alternate checking path |
| `-count` | int | Check only the first N characters |
| `-good` | string | Store the count of passing characters in this variable |
| `-bad` | string | Store the count of failing characters in this variable |
| `-failindex` | string | Store the index of the first failing character |

</details>

<details>
<summary><code>[string map]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-multipass` | -- | Apply mapping repeatedly until no more substitutions occur |
| `-regexp` | -- | Use regex patterns instead of literal strings |
| `-subspec` | -- | Allow sub-specifications in replacement patterns |
| `-eval` | -- | Evaluate replacement strings as scripts |
| `-maximum` | int | Maximum number of replacements |
| `-countvar` | string | Store the replacement count in this variable |
| `-comparison` | StringComparison | .NET comparison type for matching |
| `-regexpoptions` | RegexOptions | Regex options when `-regexp` is active; defaults to `StringOps.DefaultRegExOptions` |
| `-nocase` | -- | Case-insensitive mapping |

</details>

<details>
<summary><code>[string match]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-mode` | MatchMode | Matching mode (Exact, Glob, Regexp, SubString, etc.); defaults to `StringOps.DefaultMatchMode` |
| `-nocase` | -- | Case-insensitive matching |

</details>

<details>
<summary><code>[string toupper]</code> / <code>[string tolower]</code> / <code>[string totitle]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-culture` | CultureInfo | Culture for locale-aware case conversion |

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
<summary><code>[test2]</code></summary>

**Standard test options (tcltest-compatible):**

| Option | Value | Description |
|--------|-------|-------------|
| `-constraints` | string | Constraint expression that must be true for the test to run |
| `-setup` | string | Script to run before the test body |
| `-body` | string | The test script to evaluate |
| `-cleanup` | string | Script to run after the test (always runs) |
| `-result` | string | Expected result to compare against |
| `-output` | string | Expected stdout output |
| `-errorOutput` | string | Expected stderr output (case-insensitive option name) |
| `-returnCodes` | list | Acceptable return codes (case-insensitive) |
| `-execReturnCodes` | list | Acceptable execution return codes (case-insensitive) |
| `-exitCode` | ExitCode | Expected exit code (case-insensitive) |
| `-execExitCode` | ExitCode | Expected execution exit code (case-insensitive) |
| `-match` | MatchMode | How to compare actual vs. expected result; defaults to `StringOps.DefaultResultMatchMode` |

**Eagle-specific options:**

| Option | Value | Description |
|--------|-------|-------------|
| `-debug` | boolean | Enable debug mode during test execution |
| `-trace` | boolean | Enable trace output during test |
| `-captureTrace` | boolean | Capture trace output for comparison (TEST builds only) |
| `-time` | boolean | Measure and report test execution time |
| `-once` | boolean | Run the test only once (skip repeat logic) |
| `-text` | string | Additional text to display with test results |
| `-argv` | list | Additional arguments for the test |
| `-timeout` | int | Timeout in milliseconds |
| `-ruleSet` | IRuleSet | Security rule set for the test (case-insensitive) |
| `-noCase` | boolean | Case-insensitive result comparison (case-insensitive option name) |
| `-visibleSpace` | boolean | Make whitespace visible in output (case-insensitive) |
| `-regExOptions` | RegexOptions | Regex options for `-match regexp`; defaults to `TestOps.RegExOptions` |
| `-constraintExpression` | string | Additional constraint expression (case-insensitive) |
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
| `-isolationLevel` | IsolationLevel | Test isolation level; defaults to `IsolationLevel.Default` |
| `-isolationPassDetail` / `-isolationFailDetail` | IsolationDetail | Detail level for pass/fail in isolation mode |
| `-isolationPathType` | TestPathType | Path type for isolated test execution |
| `-isolationUnicode` | boolean | Unicode mode for isolated tests |
| `-isolationTemplate` | string | Template for isolated test execution |
| `-isolationOtherArguments` / `-isolationLastArguments` | list | Additional arguments for isolated execution |
| `-isolationFileName` / `-isolationLogFile` | string | File paths for isolated test output |
| `-noChangeReturnCode` | boolean | Don't modify the return code based on test outcome |
| `-stopOnHookError` | boolean | Stop test execution if a hook reports an error |

</details>

<details>
<summary><code>[time]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-timeout` | int | Timeout in milliseconds for the timed command |
| `-statistics` | boolean | Return detailed execution statistics instead of simple timing |
| `-breakOk` | boolean | Allow `break` return code without error (case-insensitive) |
| `-errorOk` | boolean | Allow `error` return code without error (case-insensitive) |
| `-noCancel` | boolean | Don't honor cancellation during timing (case-insensitive) |
| `-globalCancel` | boolean | Use global cancellation (case-insensitive) |
| `-noHalt` | boolean | Don't halt on timeout (case-insensitive) |
| `-noEvent` | boolean | Don't process events during timing (case-insensitive) |
| `-noExit` | boolean | Don't allow exit during timing (case-insensitive) |

</details>

<details>
<summary><code>[unload]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-clientdata` | object | Client data for the unload operation |
| `-data` | object | Additional data for unload |
| `-nocase` | -- | Case-insensitive plugin name matching |
| `-keeplibrary` | -- | Keep the underlying library loaded after plugin unload |
| `-nocomplain` | -- | Suppress errors if the plugin is not found |
| `-match` | MatchMode | Plugin name matching mode; defaults to `StringOps.DefaultUnloadMatchMode` |

</details>

<details>
<summary><code>[unset]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-nocomplain` | -- | Don't error if the variable does not exist |
| `-unlinkonly` | -- | Only unlink from parent scope; don't delete the underlying variable |
| `-remove` | -- | Remove the variable entirely from all scopes |
| `-notrace` | -- | Don't fire variable trace callbacks during unset |
| `-purge` | -- | Purge the variable from internal caches |
| `-zerostring` | -- | Zero out the string memory before freeing (Windows native only; security feature) |
| `-maybezerostring` | -- | Conditionally zero memory (Windows native; silently ignored on other platforms) |

</details>

<details>
<summary><code>[uri compare]</code></summary>

| Option | Value | Description |
|--------|-------|-------------|
| `-kind` | UriKind | URI kind constraint (Absolute, Relative, RelativeOrAbsolute) |
| `-components` | UriComponents | Which URI components to compare; defaults to `AbsoluteUri` |
| `-format` | UriFormat | How to format components before comparison |
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
| `-callbackflags` | CallbackFlags | Callback behavior flags; defaults to `CallbackFlags.Default` |
| `-inline` / `-noinline` | -- | Control inline result handling |
| `-trusted` | -- | Trust the remote server's certificate |
| `-yesprotocol` / `-noprotocol` | -- | Protocol selection control (TEST builds only) |
| `-obsolete` | -- | Allow obsolete protocols (TEST builds only) |
| `-encodingtype` | EncodingType | Response encoding type |
| `-encoding` | Encoding | Character encoding for the response |
| `-webclientdata` | object | Custom WebClient configuration object |

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
| `-handle` | object | Wait on a specific event handle object |
| `-eventwaitflags` | EventWaitFlags | Event waiting behavior; defaults to `interpreter.EventWaitFlags` |
| `-variableflags` | VariableFlags | Variable watch flags; defaults to `interpreter.EventVariableFlags` |
| `-thread` | int64 | Target thread for event processing |
| `-limit` | int | Maximum number of events to process |
| `-timeout` | int | Timeout in milliseconds |
| `-clear` | -- | Clear pending events before waiting |
| `-force` | -- | Force wait even if no events are pending |
| `-nocomplain` | -- | Suppress timeout errors |
| `-leaveresult` | -- | Don't clear the interpreter result after waiting |
| `-resetcancel` | -- | Reset cancellation flag after wait completes (restricted) |
| `-locked` | string | Lock name to acquire during the wait |

</details>

