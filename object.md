# Eagle `object` Command — Deep-Dive Analysis

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `object` command internals, including all 44 sub-commands, the opaque object handle system (`ObjectDictionary` → `ObjectWrapper` → `ObjectData`), handle naming (`Type#N` format), the `FixupReturnValue` pipeline (decides handle creation vs. string return, alias attachment, reference counting), method overload resolution via `FindMethodsAndFixupArguments` (parameter type matching, params arrays, by-ref arguments), the `ObjectFlags` enum (40+ flags controlling disposal, aliasing, naming, references), `MarshalFlags` (30+ flags controlling method resolution and type conversion), `ByRefArgumentFlags`, command alias dispatch, `IObject`/`IObjectData` interfaces, assembly loading with trust verification, namespace imports, type aliases, reference counting (permanent and temporary), and the `Default` → `Engine` → `File` → `Profile` → `Shell` → `Core` → `Console` host integration. For basic command syntax, see [`core_language.md`](core_language.md#cmd-object). For usage examples, see [`core_examples.md`](core_examples.md#ex-object). For workflow patterns, see [`tips_and_tricks.md`](tips_and_tricks.md).

## 1. Executive Summary

The Eagle `object` command is the gateway to the entire .NET Common
Language Runtime (CLR) from script level. It provides **44 sub-commands**
for creating .NET objects, invoking methods and properties, managing
object lifecycle, loading assemblies, importing namespaces, and
performing reflection — all through a system of opaque string handles
that bridge the managed/.NET world and the script world.

Tcl has no built-in .NET integration (Tcl uses extensions like `tclOO`
for object orientation, and separate packages for .NET bridging). Eagle's
`object` command is a first-class, deeply integrated .NET interop system
with sophisticated method overload resolution, reference counting,
automatic disposal, and command alias creation.

The command carries `CommandFlags.Unsafe | CommandFlags.Critical |
CommandFlags.NonStandard` and belongs to the `"managedEnvironment"` object group.
**It is not available in safe interpreters by default**, though the
policy subsystem may grant access to it in specific contexts.

Key differentiators from Tcl:

| Area | Tcl | Eagle |
|------|-----|-------|
| .NET object creation | None (requires extension) | `object create` with constructor overload resolution |
| Method invocation | None | `object invoke` with 40+ options, overload resolution |
| Object lifecycle | None | Reference counting, auto-disposal, `IDisposable` support |
| Assembly loading | None | `object load` with trust/strong-name verification |
| Type resolution | None | Namespace imports, type aliases, assembly scanning |
| Reflection | None | `object members`, `object search`, `object interfaces` |
| Collection iteration | None | `object foreach` / `object lmap` over `IEnumerable` |
| Command aliases | None | Objects usable as commands via `-alias` option |
| By-ref parameters | None | Automatic output parameter → variable mapping |
| Static members | None | `object invoke TypeName StaticMember` |
| Remote objects | None | `object get` via `Activator.GetObject()` |
| Assembly verification | None | `object verifyall`, `object certificate`, `object strongname` |

---

## 2. Architecture Overview

### 2.1 The Opaque Handle System

Eagle bridges .NET and script worlds through **opaque string handles**.
When a .NET object enters the script world (via `object create`, return
values from `object invoke`, etc.), the `FixupReturnValue` pipeline:

1. Wraps the .NET object in an `ObjectData` → `_Objects.Default` →
   `ObjectWrapper` three-layer structure
2. Stores it in the interpreter's `ObjectDictionary` under a generated
   handle name
3. Returns the handle string to the script

Handle names follow the format `Type#N` where dots in the type name are
replaced with `#`:

```
System.Text.StringBuilder  →  System#Text#StringBuilder#1
System.DateTime            →  System#DateTime#2
System.Int32               →  Int32#3
```

For types from the Eagle runtime assembly, short type names are used
(e.g., `StringBuilder#1`). Types from other assemblies use the fully
qualified name (e.g., `System#Text#StringBuilder#1`).

The special handle `"null"` is a read-only opaque object handle that resolves
to an internal value of null. An empty string `""` does not represent null —
when passed where an `Interpreter`-typed parameter is expected, it is
converted to the active interpreter instance.

### 2.2 The FixupReturnValue Pipeline

`FixupReturnValue` in `MarshalOps.cs` is the central decision point for
every .NET value entering the script world. Its decision tree:

1. **Null value** → return the special `"null"` handle name (unless
   `-create` forces handle creation)
2. **String value** → return as-is (unless `-create` forces handle)
3. **Enum or simple type** → return string representation (unless
   `-create`)
4. **Complex object** →
   a. Check if an existing handle already references this object
   b. If reusable handle found → return existing handle name
   c. Otherwise → create new handle via `AddObject()`
   d. If `-alias` requested → create command alias via
      `AddObjectAlias()`
   e. Return handle name (or alias name if `ReturnAlias` flag set)

Key decisions are controlled by `ObjectFlags`:

| Flag | Effect on FixupReturnValue |
|------|---------------------------|
| `ForceNew` | Always create new handle, never reuse |
| `AllowExisting` | Reuse existing handle if no specific name given |
| `Alias` | Create a command alias for this handle |
| `StickAlias` | Automatically create alias on every return |
| `NoDispose` | Mark handle as non-disposable |
| `AddReference` | Start reference count at 1 instead of 0 |
| `NoAttribute` | Skip `ObjectFlagsAttribute` on the type |

### 2.3 Command Alias Dispatch

When an object is created with `-alias`, a command is registered whose
name is the handle (or a custom name via `-objectname`). Invoking the
alias command dispatches to `[object invoke]` with the handle pre-filled:

```tcl
object create -alias System.Text.StringBuilder
# Creates handle "System#Text#StringBuilder#1" AND a command of that name

# These are equivalent:
object invoke System#Text#StringBuilder#1 Append "Hello"
System#Text#StringBuilder#1 Append "Hello"
```

Aliases support namespace mapping via `object aliasnamespaces` — assembly
names can be mapped to Eagle namespace prefixes.

### 2.4 Method Overload Resolution

`FindMethodsAndFixupArguments` in `MarshalOps.cs` (~1,500 lines) is the
method overload resolution engine. For each candidate method:

1. **Name matching** — filter by method name
2. **Parameter count** — check argument count fits min/max (accounting
   for optional parameters and `params` arrays)
3. **Type hint matching** — if `-parametertypes` provided, verify
   against method signature
4. **Argument conversion** — for each formal parameter:
   - **Pointer types** → reject (forbidden)
   - **`params` array** → collect remaining arguments, convert each to
     element type
   - **By-ref parameters** → verify variable exists, create
     `ArgumentInfo` for post-call variable update
   - **Regular parameters** → call `FixupArgument` for type conversion
     (includes opaque handle lookup)
5. **Success criteria** — all arguments converted, return type matches

Multiple successful matches are ordered by `ReorderFlags` preferences
(parameter count, type specificity, etc.) and the first (or indexed)
match is selected.

### Source files

| File | Role |
|------|------|
| `Commands/Object.cs` (~5,575 lines) | Command implementation: 44 sub-commands |
| `Components/Private/MarshalOps.cs` (~11,000+ lines) | Marshalling: `FixupReturnValue`, `FindMethodsAndFixupArguments`, type resolution, handle naming |
| `Components/Private/ObjectOps.cs` (~7,177 lines) | Option definitions, defaults, disposal helpers |
| `Components/Public/ObjectData.cs` | `IObjectData` implementation: handle metadata |
| `Containers/Public/ObjectDictionary.cs` | Handle storage: `Dictionary<string, object>` |
| `Components/Public/Interpreter.cs` | `AddObject`, `RemoveObject`, `AddObjectAlias`, reference counting |
| `Components/Public/Enumerations.cs` | `ObjectFlags`, `MarshalFlags`, `ObjectOptionType`, `ValueFlags`, `ByRefArgumentFlags` |
| `Interfaces/Public/Object.cs` | `IObject` interface |
| `Interfaces/Public/ObjectData.cs` | `IObjectData` interface |

---

## 3. Sub-Command Reference — Core Lifecycle

These are the most important sub-commands. They form the fundamental
create → use → dispose workflow.

### 3.1 `object create` — Instantiate a .NET Type

```
object create ?options? typeName ?arg ...?
```

**Purpose:** Create a new instance of a .NET type by resolving the type
name, finding a matching constructor, converting arguments, and returning
an opaque object handle.

**Options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-objectname` | string | Explicit handle name (instead of auto-generated) |
| `-type` | Type | Explicit type hint |
| `-objecttypes` | TypeList | Type list for object value resolution |
| `-methodtypes` | TypeList | Type list for method matching |
| `-parametertypes` | TypeList | Constructor parameter types for overload resolution |
| `-parametermarshalflags` | MarshalFlags list | Per-parameter marshalling control |
| `-marshalflags` | MarshalFlags | Method resolution flags |
| `-reorderflags` | ReorderFlags | Method match ordering |
| `-objectvalueflags` | ValueFlags | Value interpretation flags |
| `-argumentflags` | ByRefArgumentFlags | By-ref argument handling |
| `-flags` / `-bindingflags` | BindingFlags | .NET reflection binding flags |
| `-objectflags` | ObjectFlags | Handle creation flags |
| `-byrefobjectflags` | ObjectFlags | Flags for by-ref output handles |
| `-limit` | integer | Maximum candidate methods to consider |
| `-index` | integer | Force selection of Nth matching constructor |
| `-alias` | switch | Create command alias for the handle |
| `-aliasraw` | switch | Alias dispatches to `invokeraw` |
| `-aliasall` | switch | Alias dispatches to `invokeall` |
| `-aliasreference` | switch | Alias holds an object reference |
| `-nocreate` | switch | Don't create (return constructor info only) |
| `-noinvoke` | switch | Don't invoke constructor |
| `-noargs` | switch | Ignore constructor arguments |
| `-nodispose` | switch | Mark handle as non-disposable |
| `-noforcedelete` | switch | Don't force-delete on removal |
| `-tostring` | switch | Convert result to string instead of handle |
| `-arrayasvalue` | switch | Use handles for managed array outputs |
| `-arrayaslink` | switch | Link to underlying array element |
| `-nomutatebindingflags` | switch | Don't modify binding flags |
| `-stricttype` | switch | Strict type name matching |
| `-strictmember` | switch | Strict constructor matching |
| `-strictargs` | switch | Strict argument matching |
| `-nocase` | switch | Case-insensitive type/member matching |
| `-nobyref` | switch | Skip by-ref argument handling |
| `-default` | switch | Use default type resolution |
| `-verbose` | switch | Verbose error messages |
| `-debug` | switch | Debug output |
| `-trace` | switch | Trace output |
| `-tcl` | TclInterpreter | Tcl bridge target (requires `NATIVE && TCL`) |

**Implementation flow:**

1. Resolve `typeName` to a .NET `Type` via `Value.GetAnyType()` — searches
   imported namespaces, type aliases, loaded assemblies
2. If the type is a simple/value type with no arguments, use
   `Activator.CreateInstance(type)`
3. Otherwise, get all constructors via reflection
4. Call `FindMethodsAndFixupArguments()` to find matching constructors
   and convert script arguments to .NET types
5. Select the best match (by index, limit, or automatic ordering)
6. If `-noinvoke` is not set, invoke the constructor
7. Pass result through `FixupReturnValue` to create handle and
   optional alias
8. Fix up any by-ref argument variables

```tcl
# Basic creation
set sb [object create System.Text.StringBuilder]

# With constructor arguments
set sb [object create System.Text.StringBuilder "Initial text"]

# With explicit parameter types for overload resolution
set dt [object create -parametertypes {int int int} \
    System.DateTime 2024 1 15]

# With alias (creates a command)
object create -alias System.Collections.ArrayList

# With custom handle name
set obj [object create -objectname myObj System.Object]

# Non-disposable handle
set cfg [object create -nodispose System.Configuration.Something]
```

### 3.2 `object invoke` — Call Methods, Properties, and Fields

```
object invoke ?options? object member ?arg ...?
```

**Purpose:** Invoke a method, get/set a property, or access a field on
a .NET object or type. This is the primary sub-command for all .NET
interaction after object creation.

**Options (combined from InvokeOnly + InvokeShared + FixupReturnValue):**

| Option | Type | Purpose |
|--------|------|---------|
| `-type` | Type | Override object type |
| `-objecttype` | Type | Explicit object type |
| `-proxytype` | Type | Proxy type for transparent proxies |
| `-objecttypes` | TypeList | Type list for object resolution |
| `-methodtypes` | TypeList | Type list for method matching |
| `-parametertypes` | TypeList | Parameter types for overload resolution |
| `-parametermarshalflags` | MarshalFlags list | Per-parameter marshalling |
| `-marshalflags` | MarshalFlags | Method resolution control |
| `-reorderflags` | ReorderFlags | Match ordering |
| `-objectvalueflags` | ValueFlags | Value interpretation |
| `-membervalueflags` | ValueFlags | Member name interpretation |
| `-argumentflags` | ByRefArgumentFlags | By-ref argument handling |
| `-flags` / `-bindingflags` | BindingFlags | .NET binding flags |
| `-objectflags` | ObjectFlags | Return value handle flags |
| `-byrefobjectflags` | ObjectFlags | By-ref output handle flags |
| `-membertypes` | MemberTypes | Filter: Method, Property, Field, etc. |
| `-returntype` | Type | Expected return type |
| `-objectname` | string | Explicit handle name for return value |
| `-limit` | integer | Max candidate methods |
| `-index` | integer | Force Nth match |
| `-alias` | switch | Alias the return value |
| `-aliasraw` | switch | Return alias dispatches to `invokeraw` |
| `-aliasall` | switch | Return alias dispatches to `invokeall` |
| `-aliasreference` | switch | Return alias holds reference |
| `-create` | switch | Force handle creation for return value |
| `-nodispose` | switch | Return handle is non-disposable |
| `-noforcedelete` | switch | Don't force-delete return handle |
| `-tostring` | switch | Convert return value to string |
| `-noinvoke` | switch | Don't invoke (return member info only) |
| `-noargs` | switch | Ignore arguments |
| `-nobyref` | switch | Skip by-ref handling |
| `-nonestedmember` | switch | Don't navigate nested members (e.g., `Prop.SubProp`) |
| `-nonestedobject` | switch | Don't navigate nested object handles |
| `-stricttype` | switch | Strict type matching |
| `-strictmember` | switch | Strict member matching |
| `-strictargs` | switch | Strict argument matching |
| `-nocase` | switch | Case-insensitive matching |
| `-default` | switch | Use default type resolution |
| `-verbose` | switch | Verbose errors |
| `-debug` | switch | Debug output |
| `-trace` | switch | Trace output |
| `-identity` | switch | Return the object itself (no member access) |
| `-typeidentity` | switch | Return the object's type |
| `-invokeraw` | switch | Redirect to `invokeraw` |
| `-invokeall` | switch | Redirect to `invokeall` |
| `-arrayasvalue` | switch | Use handles for array outputs |
| `-arrayaslink` | switch | Link to array elements |
| `-datetimekind` | DateTimeKind | DateTime interpretation |
| `-datetimestyles` | DateTimeStyles | DateTime parsing style |
| `-datetimeformat` | string | DateTime format string |
| `-tcl` | TclInterpreter | Tcl bridge target |

**Member resolution:**

The `object` argument can be either an opaque handle (for instance
members) or a type name (for static members). The `member` argument
names the method, property, or field. Nested member navigation is
supported: `Prop.SubProp.Method`.

**Member types:**

| Member type | Read (0 extra args) | Write (1 extra arg) |
|-------------|--------------------|--------------------|
| Field | Get field value | Set field value |
| Property | Get property value | Set property value |
| Method | Invoke with 0 args | Invoke with args |
| Event | Get event info | Add/remove handler |

**By-ref argument handling:**

When a method has `out` or `ref` parameters, Eagle automatically:
1. Creates `ArgumentInfo` tracking for each by-ref parameter
2. After invocation, writes output values back to script variables
3. Output values pass through `FixupReturnValue` (creating handles
   for complex types)

```tcl
# Instance method
set sb [object create System.Text.StringBuilder]
object invoke $sb Append "Hello"
set result [object invoke $sb ToString]

# Static method
set sqrt [object invoke System.Math Sqrt 144.0]

# Static property
set now [object invoke System.DateTime Now]
set nl [object invoke System.Environment NewLine]

# Property get/set
set len [object invoke $sb Length]
object invoke $sb Length 10         ;# Set property

# By-ref / out parameter
object invoke System.Int32 TryParse "42" result
# $result now contains the parsed integer handle

# With explicit parameter types
object invoke -parametertypes {string int} $obj Method "hello" 42

# Return value as alias
set list [object invoke -alias $obj GetList]
$list Add "item"                    ;# Use alias directly

# Nested member navigation
object invoke $obj Config.Settings.Value

# Type identity
set type [object invoke -typeidentity $obj ignored]
```

### 3.3 `object invokeraw` — Raw Reflection Invocation

```
object invokeraw ?options? object member ?arg ...?
```

**Purpose:** Invoke a member via `Type.InvokeMember()` directly, without
Eagle's argument conversion pipeline. Useful when you need exact control
over the reflection call.

Has the same options as `object invoke` except `-invokeraw` is ignored
(since you're already using it) and `-invoke` redirects back to
`object invoke`.

```tcl
# Direct invocation without type conversion
object invokeraw $obj MethodName arg1 arg2
```

### 3.4 `object invokeall` — Chained Member Invocation

```
object invokeall ?options? object memberAndArgs ?memberAndArgs ...?
```

**Purpose:** Invoke multiple members on the same object in sequence.
Each `memberAndArgs` is a list where the first element is the member
name and the rest are arguments.

**Additional options (beyond invoke):**

| Option | Type | Purpose |
|--------|------|---------|
| `-chained` | switch | Each result becomes the next invocation's object |
| `-lastresult` | switch | Return only the last result |
| `-keepresults` | switch | Keep all results as a list |
| `-nocomplain` | switch | Ignore invocation errors |
| `-invoke` | switch | Use `object invoke` for each call |
| `-invokeraw` | switch | Use `object invokeraw` for each call |

```tcl
# Multiple method calls
set sb [object create System.Text.StringBuilder]
object invokeall $sb {Append Hello} {Append " "} {Append World}
set result [object invoke $sb ToString]

# Chained calls (result of each becomes object for next)
set result [object invokeall -chained $obj \
    {GetBuilder} {Append Hello} {ToString}]
```

### 3.5 `object dispose` — Dispose and Release

```
object dispose ?options? object ?object ...?
```

**Purpose:** Call `Dispose()` on `IDisposable` objects and remove their
handles from the interpreter. Accepts multiple objects.

**Options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-synchronous` | switch | Synchronous disposal (no deferred GC) |
| `-nodispose` | switch | Remove handle but don't call `Dispose()` |
| `-nocomplain` | switch | Ignore errors during disposal |

**Disposal pipeline:**

1. For each object argument, calls `MaybeRemoveObject()`
2. Checks if object is locked (locked objects cannot be removed)
3. If `dispose=true` and `ObjectFlags.NoDispose` is not set:
   - Calls `IDisposable.Dispose()` on the wrapped .NET object
4. Removes the command alias (if one exists)
5. Removes from `ObjectDictionary`
6. Returns `{disposed N removed M}` counts

**Disposal control flags:**

| ObjectFlag | Effect |
|------------|--------|
| `NoDispose` | `Dispose()` is never called on this object |
| `NoAutoDispose` | Automatic disposal is suppressed (object may not be owned) |
| `AutoDispose` | Force automatic disposal |
| `Locked` | Object cannot be removed or disposed at all |

```tcl
# Basic disposal
object dispose $stream

# Dispose multiple objects
object dispose $obj1 $obj2 $obj3

# Remove handle without calling Dispose()
object dispose -nodispose $handle

# Ignore errors
object dispose -nocomplain $maybeDisposed

# Canonical try/finally pattern
try {
    set stream [object create System.IO.FileStream test.txt Create]
    # ... use stream ...
} finally {
    if {[info exists stream]} then {
        object dispose $stream
    }
}
```

---

## 4. Sub-Command Reference — Invocation Variants and Iteration

### 4.1 `object foreach` / `object lmap` — Collection Iteration

```
object foreach ?options? varName object body
object lmap ?options? varName object body
```

**Purpose:** Iterate over any `IEnumerable` .NET object. `foreach`
evaluates the body for each element; `lmap` collects results.

**Options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-collect` | boolean | Collect results (default: true for `lmap`, false for `foreach`) |
| `-synchronous` | switch | Synchronous disposal of iteration handles |
| `-objectname` | string | Custom handle name for each element |
| `-type` | Type | Expected element type |
| `-objectflags` | ObjectFlags | Flags for element handles |
| `-nocreate` | switch | Don't create handles for simple types |
| `-nodispose` | switch | Don't dispose element handles after body |
| `-nocase` | switch | Case-insensitive type matching |
| `-alias` | switch | Alias each element handle |
| `-aliasraw` | switch | Element alias uses `invokeraw` |
| `-aliasall` | switch | Element alias uses `invokeall` |
| `-aliasreference` | switch | Element alias holds reference |
| `-noforcedelete` | switch | Don't force-delete element handles |
| `-tostring` | switch | Convert elements to string |
| `-tcl` | TclInterpreter | Tcl bridge target |

**Implementation:**

1. Gets `IEnumerable` interface from the object
2. Calls `GetEnumerator()` to obtain `IEnumerator`
3. Loops calling `MoveNext()`:
   - Each element passes through `FixupReturnValue`
   - Sets `varName` in the caller's scope
   - Evaluates `body`
   - Handles `break`, `continue`, `return`, `error`
4. Respects interpreter iteration limit
5. For `lmap`: collects body results into a list

```tcl
set list [object create System.Collections.ArrayList]
object invoke $list Add "one"
object invoke $list Add "two"
object invoke $list Add "three"

# Iterate
object foreach item $list {
    puts "Item: $item"
}

# Collect transformed results
set upper [object lmap item $list {
    string toupper $item
}]
;# Returns: {ONE TWO THREE}
```

### 4.2 `object fromvar` — Handle from Variable

```
object fromvar ?options? varName
```

**Purpose:** Create an object handle from a variable's value. Useful
when a variable already contains a handle string and you need to
re-wrap or re-alias it.

Options include the standard return-value options (`-alias`, `-objectflags`,
`-objectname`, `-tostring`, etc.).

---

## 5. Sub-Command Reference — Assembly and Type Management

### 5.1 `object load` — Load Assembly

```
object load ?options? assembly
```

**Purpose:** Load a .NET assembly into the current AppDomain, optionally
importing its namespaces and declaring its interfaces.

**Options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-loadtype` | LoadType | How to load: `PartialName`, `FullName`, `File`, `Bytes`, `Stream` |
| `-namespace` | string | Alias namespace for assembly |
| `-reflectiononly` | switch | Reflection-only load (no execution) |
| `-fromobject` | switch | Load from object stream |
| `-trustedonly` | switch | Require trust verification |
| `-maybetrustedonly` | switch | Trust verification if available |
| `-verifiedonly` | switch | Require strong name verification |
| `-maybeverifiedonly` | switch | Strong name verification if available |
| `-import` | switch | Import namespaces from assembly |
| `-importnonpublic` | switch | Include non-public namespaces |
| `-importmode` | MatchMode | Import pattern matching mode |
| `-importpattern` | string | Namespace filter pattern |
| `-importnocase` | switch | Case-insensitive import |
| `-declare` | switch | Declare interfaces from assembly |
| `-declarenonpublic` | switch | Include non-public interfaces |
| `-declaremode` | MatchMode | Declare pattern matching mode |
| `-declarepattern` | string | Interface filter pattern |
| `-declarenocase` | switch | Case-insensitive declare |
| `-objectflags` | ObjectFlags | Handle flags (default includes `Assembly`) |
| `-objectname` | string | Custom handle name |
| `-alias` | switch | Create alias for assembly handle |
| `-aliasraw` / `-aliasall` / `-aliasreference` | switch | Alias options |
| `-create` | switch | Force handle creation |
| `-nodispose` | switch | Non-disposable handle |
| `-noforcedelete` | switch | Don't force-delete |
| `-tostring` | switch | Convert to string |
| `-tcl` | TclInterpreter | Tcl bridge target |

**Load types:**

| LoadType | Method | Security |
|----------|--------|----------|
| `PartialName` | `Assembly.LoadWithPartialName()` | None |
| `FullName` | `Assembly.Load()` | None |
| `File` | `Assembly.LoadFrom()` | Trust + strong name verification available |
| `Bytes` | `Assembly.Load(byte[])` | None |
| `Stream` | Load from object stream | None |

```tcl
# Load by name
object load System.Data

# Load from file with verification
object load -loadtype File -trustedonly -verifiedonly MyPlugin.dll

# Load and import namespaces
object load -import System.Data
set dt [object create DataTable]     ;# Short name works

# Load and declare interfaces
object load -declare -import System.Data
```

### 5.2 `object import` / `object unimport` — Namespace Management

```
object import ?options? ?name name ...?
object unimport ?options?
```

**Purpose:** Import .NET namespaces so types can be referenced by short
names (e.g., `StringBuilder` instead of `System.Text.StringBuilder`).

**`object import` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-matchmode` | MatchMode | Pattern matching mode |
| `-container` | string | Container namespace |
| `-pattern` | string | Namespace filter pattern |
| `-eagle` | switch | Import Eagle internal namespaces |
| `-clr` | switch | Import standard CLR namespaces |
| `-nocase` | switch | Case-insensitive matching |

**`object unimport` options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-matchmode` | MatchMode | Pattern matching mode |
| `-pattern` | string | Namespace filter pattern |
| `-nocase` | switch | Case-insensitive matching |
| `-values` | switch | Match by values instead of keys |

```tcl
# Import specific namespaces
object import System.Text System.IO System.Collections.Generic

# Now use short names
set sb [object create StringBuilder "Hello"]

# Import Eagle namespaces
object import -eagle

# Remove imports
object unimport -pattern "System.Text"
```

### 5.3 `object type` / `object untype` — Type Aliases

```
object type ?options? ?fromName toName ...? fromName toName
object untype ?options?
```

**Purpose:** Register custom type name mappings. Takes pairs of
`fromName toName` arguments.

```tcl
# Register short names
object type SB System.Text.StringBuilder
object type AL System.Collections.ArrayList

set sb [object create SB]          ;# Uses the alias

# Remove aliases
object untype -pattern "SB"
```

### 5.4 `object declare` / `object undeclare` — Interface Declarations

```
object declare ?options? ?name name ...?
object undeclare ?options?
```

**Purpose:** Declare interfaces that the type resolution system should
be aware of.

### 5.5 `object search` — Type Search

```
object search ?options? typeName
```

**Purpose:** Search for a type by name across all loaded assemblies.
Returns the resolved type information.

**Options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-objecttypes` | TypeList | Type list to search |
| `-stricttype` | switch | Strict matching |
| `-nocase` | switch | Case-insensitive |
| `-noshowname` | switch | Don't show name in results |
| `-nonamespace` | switch | Omit namespace |
| `-noassembly` | switch | Omit assembly |
| `-noexception` | switch | Omit exceptions |
| `-fullname` | switch | Use fully qualified names |

```tcl
object search System.Text.StringBuilder
object search -nocase stringbuilder
```

### 5.6 `object resolve` — Assembly Resolution

```
object resolve assembly
```

**Purpose:** Resolve an assembly reference to its full name.

### 5.7 `object assemblies` — List Loaded Assemblies

```
object assemblies ?pattern?
```

**Purpose:** List all assemblies loaded in the current AppDomain,
optionally filtered by pattern.

---

## 6. Sub-Command Reference — Object Information

### 6.1 Query Sub-Commands

| Sub-command | Syntax | Returns |
|-------------|--------|---------|
| `object exists object` | Check handle validity | Boolean |
| `object isnull ?options? object` | Check if null or disposed | Boolean |
| `object isdisposed ?options? object` | Check if value is disposed | Boolean |
| `object isoftype ?options? object type` | Instance-of check | Boolean |
| `object list ?pattern?` | List all handles | Handle list |
| `object flags object ?flags?` | Get/set `ObjectFlags` | Flags value |
| `object referencecount object` | Get reference count | Integer |

**`object isnull` options:**

| Option | Purpose |
|--------|---------|
| `-nocomplain` | Don't error if handle not found |
| `-objectdisposed` | Check wrapper disposal state |
| `-valuedisposed` | Check wrapped value disposal state |
| `-force` | Force disposal check |
| `-cannotcheck` | Default value if check impossible |
| `-caughtexception` | Default value if exception caught |

**`object isdisposed` options:** Same as `isnull` disposal options.

**`object isoftype` options:**

| Option | Purpose |
|--------|---------|
| `-objecttypes` | Type list to check |
| `-stricttype` | Strict type matching |
| `-nocase` | Case-insensitive |
| `-nocomplain` | Ignore type resolution errors |
| `-assignable` | Check assignable compatibility (not just exact type) |

```tcl
if {[object exists $obj]} {
    if {![object isnull $obj]} {
        if {[object isoftype $obj System.IDisposable]} {
            object dispose $obj
        }
    }
}
```

### 6.2 `object members` — Reflection

```
object members ?options? object
```

**Purpose:** List members (methods, properties, fields, events) of an
object or type via reflection.

**Options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-membertypes` | MemberTypes | Filter: Method, Property, Field, Event, etc. |
| `-mode` | MatchMode | Pattern matching mode |
| `-pattern` | string | Member name filter |
| `-flags` / `-bindingflags` | BindingFlags | .NET binding flags |
| `-attributes` | switch | Include attribute information |
| `-signatures` | switch | Include method signatures |
| `-qualified` | switch | Use fully qualified type names |
| `-nameonly` | switch | Return names only |
| `-matchnameonly` | switch | Match against name only |
| `-stricttype` | switch | Strict type matching |
| `-nocase` | switch | Case-insensitive matching |
| `-verbose` | switch | Verbose output |

```tcl
# List all members
object members $obj

# List methods only
object members -membertypes Method $obj

# List with signatures
object members -signatures -membertypes Method $obj

# Filter by pattern
object members -pattern "Get*" $obj
```

### 6.3 `object interfaces` / `object namespaces` / `object types`

```
object interfaces ?pattern?    ;# List declared interfaces
object namespaces ?pattern?    ;# List imported namespaces
object types ?pattern?         ;# List type aliases
```

---

## 7. Sub-Command Reference — Aliases and References

### 7.1 `object alias` / `object unalias`

```
object alias ?options? object
object unalias object
```

**Purpose:** Create or remove a command alias for an existing object
handle.

**`object alias` options:**

| Option | Purpose |
|--------|---------|
| `-objecttypes` | Type list for matching |
| `-aliasname` | Custom alias name |
| `-verbose` | Verbose output |
| `-stricttype` | Strict matching |
| `-nocase` | Case-insensitive |
| `-aliasraw` | Raw formatting |
| `-aliasall` | Alias all matches |
| `-aliasreference` | Create reference alias |

```tcl
# Create alias for existing handle
object alias -aliasname myObj $handle

# Use alias
myObj ToString
myObj SomeMethod arg1 arg2

# Remove alias
object unalias myObj
```

### 7.2 `object aliasnamespaces` / `object unaliasnamespace`

```
object aliasnamespaces ?pattern?
object unaliasnamespace ?options?
```

**Purpose:** Manage namespace mappings for object aliases. When an alias
is created, the assembly name can be mapped to an Eagle namespace prefix.

### 7.3 `object addreference` / `object removereference` / `object referencecount`

```
object addreference object
object removereference object
object referencecount object
```

**Purpose:** Manually manage reference counts. Adding a reference
prevents automatic cleanup; removing allows it.

**Reference types** (internal `ObjectReferenceType`):

| Type | When used |
|------|-----------|
| `Create` | Initial handle creation |
| `Demand` | `object addreference` |
| `Trace` | `[set]` trace on variable containing handle |
| `Return` | `[return]` of handle value |
| `Command` | Alias command creation |

```tcl
# Prevent cleanup
object addreference $longLived

# ... much later ...
object removereference $longLived
object dispose $longLived
```

---

## 8. Sub-Command Reference — Cleanup and Verification

### 8.1 `object cleanup` — Bulk Object Cleanup

```
object cleanup ?options?
```

**Options:**

| Option | Type | Purpose |
|--------|------|---------|
| `-pattern` | string | Match handles by pattern |
| `-referencecount` | integer | Only clean up objects with this reference count |
| `-references` | switch | Clean up references too |
| `-noremove` | switch | Don't remove from dictionary |
| `-nodispose` | switch | Don't dispose objects |
| `-synchronous` | switch | Synchronous cleanup |
| `-nocomplain` | switch | Ignore errors |

Returns `{disposed N removed M}`.

```tcl
# Clean up all unreferenced objects
object cleanup -referencecount 0

# Clean up matching pattern
object cleanup -pattern "*StringBuilder*"

# Full cleanup
object cleanup -references -synchronous
```

### 8.2 `object verifyall` — Assembly Verification

```
object verifyall ?options?
```

**Purpose:** Verify all loaded assemblies for strong names, signatures,
and certificates.

### 8.3 `object certificate` — Assembly Certificate

```
object certificate ?options? assembly
```

**Purpose:** Get X.509 certificate information for an assembly.

**Options:**

| Option | Purpose |
|--------|---------|
| `-chain` | Verify certificate chain |
| `-x509verificationflags` | X.509 verification flags |
| `-x509revocationmode` | Certificate revocation mode |
| `-x509revocationflag` | Revocation flag |

### 8.4 `object hash` / `object strongname`

```
object hash assembly
object strongname assembly
```

**Purpose:** Get hash or strong name information for an assembly.
Requires `CAS_POLICY` compile flag.

---

## 9. Sub-Command Reference — Callbacks and Remote Objects

### 9.1 `object callbackflags` / `object removecallback`

```
object callbackflags name ?flags?
object removecallback name
```

**Purpose:** Get/set callback flags or remove a named callback. Callbacks
are created when Eagle wraps script procedures as .NET delegates.

### 9.2 `object get` — Remote Object Activation

```
object get ?options? type url ?state?
```

**Purpose:** Get a proxy to a remote .NET object via URL using
`Activator.GetObject()`. Not available on .NET Standard 2.0.

---

## 10. The `ObjectFlags` Enum

`ObjectFlags` is a `[Flags]` `ulong` with 40+ values controlling every
aspect of handle behavior.

### 10.1 Lifecycle Flags

| Flag | Purpose |
|------|---------|
| `NoDispose` | `Dispose()` is never called |
| `AutoDispose` | Force automatic disposal when handle removed |
| `NoAutoDispose` | Prevent automatic disposal (object may not be owned) |
| `ForceDelete` | Force removal from dictionary |
| `Locked` | Cannot be removed or disposed |

### 10.2 Alias Flags

| Flag | Purpose |
|------|---------|
| `Alias` | Object has a command alias |
| `StickAlias` | Automatically create alias on every return |
| `UnstickAlias` | Forbid creating alias even if `StickAlias` set |
| `ReturnAlias` | Return the alias name instead of handle name |

### 10.3 Reference Flags

| Flag | Purpose |
|------|---------|
| `AddReference` | Start reference count at 1 |
| `NoReturnReference` | Don't add reference on `[return]` |
| `TemporaryReturnReference` | `[return]` references are temporary |

### 10.4 Naming Flags

| Flag | Purpose |
|------|---------|
| `ForceNew` | Always create new handle (never reuse) |
| `AllowExisting` | Allow reusing existing handle |
| `ForceAutomaticName` | Always use auto-generated name |
| `ForceManualName` | Always use explicit name |

### 10.5 Type Handling Flags

| Flag | Purpose |
|------|---------|
| `NoBinder` | Don't use custom binder |
| `NoAttribute` | Skip `ObjectFlagsAttribute` on type |
| `NoComObjectLookup` | Don't look up COM types |
| `NoComObjectReturn` | Don't wrap COM return values |
| `AllowProxyGetType` | Allow `GetType()` on transparent proxies |
| `ForceProxyGetType` | Force `GetType()` on transparent proxies |

### 10.6 Categorization Flags

| Flag | Purpose |
|------|---------|
| `Safe` | Safe for use in safe interpreters |
| `WellKnown` | Well-known system object |
| `Assembly` | Loaded assembly handle |
| `Runtime` | Runtime-created object |
| `Application` | Application-level object |
| `Interpreter` | Interpreter-owned object |

---

## 11. The `MarshalFlags` Enum

`MarshalFlags` controls method overload resolution and type conversion.

### 11.1 Method Resolution

| Flag | Purpose |
|------|---------|
| `StrictMatchCount` | Parameter count must match exactly |
| `StrictMatchType` | Parameter types must match exactly |
| `ForceParameterType` | Force use of specified parameter types |
| `SelectMethodIndex` | Force selection of specific method index |
| `ReorderMatches` | Reorder matches by `ReorderFlags` criteria |
| `SortMembers` | Sort candidates by name and parameter count |
| `ReverseOrder` | Prefer methods with more parameters |
| `MinimumOptionalCount` | Prefer methods with more optional parameters |
| `AllowAnyMethod` | Skip method access checks |

### 11.2 Type Conversion

| Flag | Purpose |
|------|---------|
| `NoByRefArguments` | Skip output parameter handling |
| `UseInOnly` | Use only `ParameterInfo.IsIn` for input determination |
| `UseByRefOnly` | Use only `Type.IsByRef` for output determination |
| `HandleByValue` | Resolve opaque handles to values |
| `ByValHandleByValue` | By-value handles resolve to values |
| `ByRefHandleByValue` | By-ref handles resolve to values |
| `ForceHandleByValue` | Force all handles to resolve to values |

### 11.3 Callback and Delegate

| Flag | Purpose |
|------|---------|
| `NoDelegateCallback` | Don't create delegate callbacks |
| `NoGenericCallback` | Don't create generic callbacks |
| `DynamicCallback` | Use dynamic method for callback |
| `SimpleCallback` | Look up pre-existing method |
| `ReturnICallback` | Return `ICallback` instead of `Delegate` |

### 11.4 Default

`MarshalFlags.Default = StrictMatchCount | StrictMatchType | ThrowOnBindFailure`

---

## 12. The `ByRefArgumentFlags` Enum

Controls how by-ref (output/ref) parameters are handled.

| Flag | Purpose |
|------|---------|
| `Fast` | Skip traces, watches, notifications |
| `Direct` | Bypass `SetVariableValue` |
| `Strict` | Strict type handling |
| `Create` | Object creation expected |
| `Dispose` | Dispose if creation fails |
| `Alias` | Create command alias for output |
| `AliasRaw` | Alias uses `invokeraw` |
| `AliasAll` | Alias uses `invokeall` |
| `AliasReference` | Alias holds object reference |
| `ToString` | Convert to string and discard handle |
| `ArrayAsValue` | Use handles for managed arrays |
| `ArrayAsLink` | Link to underlying array elements |
| `NoSetVariable` | Skip setting the output variable |

---

## 13. Practical Patterns

### 13.1 Core Workflow

```tcl
# 1. Load assembly (if not already loaded)
object load System.Data

# 2. Import namespaces for short names
object import System.Text System.IO

# 3. Create instance
set sb [object create StringBuilder "Hello"]

# 4. Call methods and properties
object invoke $sb Append ", World!"
set result [object invoke $sb ToString]
;# Returns: Hello, World!

# 5. Clean up
object dispose $sb
```

### 13.2 Alias-Based Natural Syntax

```tcl
# Create with alias
object create -alias System.Collections.ArrayList

# Use alias as command (dispatches to [object invoke])
ArrayList#1 Add "item1"
ArrayList#1 Add "item2"
set count [ArrayList#1 Count]

# Custom alias name
object create -alias -objectname myList System.Collections.ArrayList
myList Add "hello"
```

### 13.3 Static Members

```tcl
# Static methods (use type name as object)
set sqrt [object invoke System.Math Sqrt 144.0]
set guid [object invoke System.Guid NewGuid]

# Static properties
set now [object invoke System.DateTime Now]
set nl [object invoke System.Environment NewLine]
set cores [object invoke System.Environment ProcessorCount]
```

### 13.4 Try/Finally Disposal

```tcl
# Single resource
try {
    set stream [object create System.IO.MemoryStream]
    object invoke $stream WriteByte 65
    object invoke $stream WriteByte 66
} finally {
    if {[info exists stream]} then {
        object dispose $stream
    }
}

# Multiple resources
try {
    set resources [list]
    lappend resources [object create System.IO.FileStream \
        $inputFile Read]
    lappend resources [object create System.IO.FileStream \
        $outputFile Write]
    # ... use resources ...
} finally {
    if {[info exists resources]} then {
        foreach resource $resources {
            catch {object dispose $resource}
        }
    }
}
```

### 13.5 Constructor Overload Resolution

```tcl
# Let Eagle resolve automatically
set dt [object create System.DateTime 2024 1 15]

# Explicit parameter types when ambiguous
set dt [object create -parametertypes {int int int} \
    System.DateTime 2024 1 15]

# Force specific constructor index
set obj [object create -index 2 MyType arg1 arg2]
```

### 13.6 Collection Iteration

```tcl
set list [object create System.Collections.ArrayList]
object invoke $list Add "alpha"
object invoke $list Add "beta"
object invoke $list Add "gamma"

# Iterate
object foreach item $list {
    puts "Item: $item"
}

# Collect transformed results
set upper [object lmap item $list {
    string toupper $item
}]

# Iterate with alias for each element
object foreach -alias item $list {
    $item ToString    ;# Use alias on each element
}
```

### 13.7 By-Ref / Out Parameters

```tcl
# Int32.TryParse has an 'out' parameter
object invoke System.Int32 TryParse "42" result
# $result now contains the parsed value

# Dictionary.TryGetValue
object invoke $dict TryGetValue "key" value
# $value contains the result if key found
```

### 13.8 Generic Types

```tcl
# Create generic List<string>
set list [object create -alias \
    "System.Collections.Generic.List\`1\[System.String\]"]
$list Add "hello"
$list Add "world"
set count [$list Count]
```

---

## 14. Safe Interpreter Behavior

The `object` command is marked `CommandFlags.Unsafe | CommandFlags.Critical |
CommandFlags.NonStandard` and **is not available in safe interpreters by default**.
However, the policy subsystem may grant access to it, subject to heavy restrictions:

- Only types and members explicitly allowed by active policies can be
  accessed
- Assembly loading may be restricted or forbidden
- Certain `ObjectFlags` are marked `Unsafe` in option definitions and
  are unavailable in safe interpreters
- Options marked `Unsafe` in the option dictionary (shown with `Unsafe`
  flag) are silently ignored or rejected in safe mode

The policy system uses `PolicyOps` to check every type resolution,
member invocation, and assembly load against registered policies.

---

## 15. Tcl Comparison

| Feature | Tcl approach | Eagle `object` approach |
|---------|-------------|----------------------|
| Object creation | `tclOO`: `oo::class create` | `object create TypeName ?args?` (any .NET type) |
| Method calls | `$obj method args` | `object invoke $obj method args` |
| Properties | Manual getter/setter | `object invoke $obj Prop` / `object invoke $obj Prop val` |
| Static members | N/A | `object invoke TypeName Member` |
| Type checking | N/A | `object isoftype $obj Type` |
| Reflection | `info class` (limited) | `object members -signatures $obj` |
| Disposal | N/A | `object dispose` with `IDisposable` support |
| Assembly loading | `package require` | `object load` with trust verification |
| Namespace import | N/A | `object import` for short type names |
| Collection iteration | Manual | `object foreach` / `object lmap` over `IEnumerable` |
| Type aliases | N/A | `object type shortName fullName` |
| By-ref parameters | N/A | Automatic output → variable mapping |
| Reference counting | N/A | `object addreference` / `object removereference` |
| Command aliases | N/A | `-alias` creates callable command from handle |
| Remote objects | N/A | `object get type url` via `Activator.GetObject()` |
| Certificate verification | N/A | `object certificate -chain assembly` |

---

## 16. Security Considerations

- The command is `Unsafe` but can be policy-granted — policies control which
  types, members, and assemblies are accessible
- `object load -trustedonly -verifiedonly` enforces trust and strong
  name verification on file-loaded assemblies
- `ObjectFlags.Locked` prevents script-level disposal of critical objects
- `ObjectFlags.NoDispose` prevents accidental disposal of shared objects
- By-ref argument handling can modify script variables — ensure output
  variable names are intended
- `object invokeraw` bypasses Eagle's type conversion safety, exposing
  raw .NET reflection
- `object get` (remote activation) connects to external services —
  validate URLs
- Command aliases execute with the creating interpreter's privileges
- Assembly verification via `object verifyall` can audit loaded code
