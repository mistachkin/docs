# Eagle `[namespace]` Command — Deep-Dive Analysis

## 1. Executive Summary

The Eagle `[namespace]` command provides **22 sub-commands** for hierarchical
namespace management with a unique dual-implementation architecture. Eagle
ships two parallel implementations: **Namespace1** (a compatibility stub
that simulates namespace support using only the global namespace) and
**Namespace2** (a full implementation with real `INamespace` objects,
parent-child hierarchy, reference counting, and per-namespace variable
frames). This dual approach allows scripts that simply wrap code in
`[namespace eval]` to work immediately, while providing full namespace
functionality that can be turned on per interpreter. **Whether it is on by
default is build/embedding-dependent — verify with `[namespace enable]`, do not
assume** (see §3).

Key differentiators from Tcl:

| Area | Tcl | Eagle |
|------|-----|-------|
| Implementation | Single, always-on | Dual: stub (Namespace1) + full (Namespace2) |
| Enable/disable | Always enabled | `[namespace enable]` toggles support |
| Namespace rename | Not supported | `[namespace rename]` with safety flags |
| Descendants | Manual recursion | `[namespace descendants]` (recursive) |
| Namespace info | `[info]` command only | `[namespace info]` sub-command |
| Namespace mappings | None | `[namespace mappings]` for name remapping |
| Unknown handler | Global only | Per-namespace unknown handler |
| Variable storage | Namespace-scoped | Per-namespace `ICallFrame` (VariableFrame) |
| Reference counting | None | Tracked for lifecycle management |
| Scope integration | None | `[scope attach]`/`detach`/`export`/`import` |

---

## 2. Why the Eagle `[namespace]` Command Differs from Tcl

Eagle's namespace system was designed with several constraints that Tcl
does not face:

- **Backward compatibility** — Many Eagle scripts were written before
  namespace support existed. The dual-implementation approach ensures
  these scripts continue to work with the Namespace1 stub.
- **Optional activation** — Namespace support can be toggled on/off via
  `[namespace enable]`, allowing embedders to control whether the overhead
  of full namespace management is incurred.
- **Call frame integration** — Eagle namespaces are deeply integrated
  with the call frame stack. Each namespace owns an `ICallFrame`
  (its `VariableFrame`) where namespace-scoped variables reside. The
  current namespace is tracked per-frame via the frame's `ResolveData`.
- **Resolver architecture** — Eagle uses an `IResolve` interface per
  namespace, enabling pluggable name resolution strategies beyond Tcl's
  fixed lookup rules.
- **.NET embedding** — Namespace mappings (`[namespace mappings]`) allow
  remapping namespace names for interoperability. By default, `::Eagle`
  redirects to the global namespace for backward compatibility.

### Source files

| File | Role |
|------|------|
| `Commands/Namespace1.cs` (~876 lines) | Compatibility stub: global-only namespace support |
| `Commands/Namespace2.cs` (~918 lines) | Full implementation: real namespace objects |
| `Components/Private/NamespaceOps.cs` (~4,241 lines) | Core operations: lookup, resolution, import/export, traversal |
| `Components/Private/Namespace.cs` (~1,770 lines) | Namespace object: hierarchy, children, imports, reference counting |
| `Components/Public/NamespaceData.cs` (~172 lines) | Data holder: name, parent, resolver, variable frame, unknown |
| `Interfaces/Public/Namespace.cs` (~114 lines) | `INamespace` interface definition |
| `Interfaces/Public/NamespaceData.cs` (~24 lines) | `INamespaceData` interface definition |

---

## 3. Dual-Implementation Architecture

Eagle's most distinctive namespace feature is its two parallel command
implementations. Understanding when and why each is active is essential.

### Namespace1 — Compatibility stub

**Flags**: `CommandFlags.Safe | CommandFlags.Standard | CommandFlags.Initialize`

Namespace1 exists for source code compatibility with scripts that use
`[namespace eval]` as a simple organizational wrapper. Its behavior:

- `[namespace current]` always returns `::` (global)
- `[namespace children]` and `[namespace descendants]` return empty lists
- `[namespace export]`, `[namespace import]`, and `[namespace forget]` are
  no-ops (silently succeed without effect)
- `[namespace eval]` creates a tracking call frame with
  `CallFrameFlags.Namespace | CallFrameFlags.Evaluate` but does not
  bind a real namespace object
- `[namespace rename]` returns "not implemented" error
- `[namespace exists]` returns true only for the global namespace

This allows scripts like:

```tcl
# `namespace eval` here is only an organizational wrapper: with namespaces
# disabled the eval does not qualify, so the proc lands in the GLOBAL namespace.
namespace eval mylib { proc greet {name} { return "Hello, $name!" } }
greet World          ;# Works (call it unqualified; `mylib::greet` would NOT resolve)

# A qualified command name works too — the "::" is just literal characters:
proc mylib::greet {name} { return "Hello, $name!" }
mylib::greet World   ;# Works — a flat command literally named "mylib::greet"
```

### Namespace2 — Full implementation

**Flags**: `CommandFlags.Safe | CommandFlags.Standard | CommandFlags.Initialize | CommandFlags.NoAdd`

Namespace2 provides real namespace support with `INamespace` objects.
**Whether it is active by default is build/embedding-dependent — verify with
`namespace enable` rather than assume.** It has been observed returning `True` on
some builds and `False` on others (e.g. a netcoreapp2.0 build reported `False`
here, while other builds and CI report `True`). `namespace enable true` activates
it; `namespace enable false` reverts to the Namespace1 stub. The disabled default
preserves backward compatibility with pre-namespace scripts (§2).

When active:

- `[namespace current]` queries the actual current namespace via
  `GetCurrentNamespaceViaResolvers()`
- `[namespace children]` and `[namespace descendants]` enumerate the real
  hierarchy via `INamespace.GetChildren()` / `GetDescendants()`
- `[namespace export]` and `[namespace import]` create real command aliases
  with `NamespaceImport` flags
- `[namespace eval]` creates a namespace call frame with
  `CallFrameFlags.Evaluate | CallFrameFlags.UseNamespace` and binds
  the real namespace object
- `[namespace rename]` calls `interpreter.RenameNamespace()` with
  configurable safety flags

### Switching between implementations

```tcl
namespace enable          ;# Query: returns current state
namespace enable true     ;# Activate Namespace2
namespace enable false    ;# Revert to Namespace1
namespace enable true true  ;# Force enable despite constraints
```

The `enable` sub-command calls `NamespaceOps.Enable(interpreter,
clientData, enabled, force)` which swaps the active command
implementation.

---

## 4. Sub-Command Reference

Eagle's 22 `[namespace]` sub-commands are organized below by functional
category. Sub-commands marked **(Eagle)** have no Tcl equivalent.

### 4.1 Creating and Managing Namespaces

#### `namespace eval name arg ?arg ...?`

Evaluates the concatenated arguments as a script in namespace `name`.
Creates the namespace if it does not exist.

**Call frame behavior:**

| Implementation | Frame flags | Namespace binding |
|----------------|-------------|-------------------|
| Namespace1 | `Namespace \| Evaluate` | Tracking frame only (no real namespace) |
| Namespace2 | `Evaluate \| UseNamespace` | Real `INamespace` bound via `PushNamespaceCallFrame()` |

On error, context information is appended:
`(in namespace eval "name" script line N)`

```tcl
namespace eval mylib {
    variable version 1.0
    proc greet {name} {
        return [appendArgs "Hello from mylib, " $name !]
    }
}
mylib::greet World   ;# "Hello from mylib, World!"
```

#### `namespace delete ?name name ...?`

Deletes the specified namespaces and all their contents (commands,
variables, child namespaces).

Calls `interpreter.DeleteNamespace()` for each name. The namespace
object is marked as deleted (`MarkDeleted()`) and its reference count
is managed for safe cleanup.

```tcl
namespace eval temp { proc helper {} { return "temp" } }
namespace delete temp
namespace exists temp   ;# 0
```

#### `namespace exists name`

Returns `1` if namespace `name` exists, `0` otherwise.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Returns true only for the global namespace |
| Namespace2 | Uses `NamespaceOps.Lookup()` for real existence check |

```tcl
namespace exists ::mylib   ;# 1 (if created)
namespace exists ::nosuch  ;# 0
```

#### `namespace enable ?enabled? ?force?` **(Eagle)**

Enables or disables full namespace support by swapping between
Namespace1 and Namespace2 implementations.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `enabled` | — | Boolean: `true` to enable, `false` to disable |
| `force` | `false` | Boolean: force enable despite constraints |

Without arguments, returns the current enabled state.

```tcl
namespace enable           ;# Query state
namespace enable true      ;# Enable full namespaces
namespace enable false     ;# Revert to compatibility stub
namespace enable true true ;# Force enable
```

#### `namespace rename oldName newName` **(Eagle)**

Renames a namespace. Not available in Tcl.

Namespace2 implements this via `interpreter.RenameNamespace()` with two
internal safety flags:

| Flag | Default | Description |
|------|---------|-------------|
| `RenameGlobalOk` | `false` | Allow renaming the global namespace |
| `RenameInUseOk` | `false` | Allow renaming namespaces currently in use |

These flags can be modified via reflection for advanced use cases.
Namespace1 returns "not implemented" error.

```tcl
namespace eval oldns { proc test {} { return "hello" } }
namespace rename ::oldns ::newns
newns::test   ;# "hello"
```

### 4.2 Namespace Information

#### `[namespace current]`

Returns the fully-qualified name of the current namespace.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Always returns `::` (global) |
| Namespace2 | Queries `GetCurrentNamespaceViaResolvers()` for actual current namespace |

```tcl
namespace eval myns {
    namespace current   ;# ::myns
}
namespace current       ;# ::
```

#### `namespace parent ?name?`

Returns the fully-qualified name of the parent namespace. Without
`name`, uses the current namespace.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Hardcoded logic for global namespace only |
| Namespace2 | Delegates to `NamespaceOps.Parent()` |

```tcl
namespace eval a::b::c {}
namespace eval a::b::c { namespace parent }   ;# ::a::b
namespace parent ::a::b::c                    ;# ::a::b
namespace parent ::                           ;# "" (global has no parent)
```

#### `namespace children ?name? ?pattern?`

Returns a list of child namespaces of `name` matching `pattern`.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Returns empty list for global |
| Namespace2 | Uses `NamespaceOps.Children()` to enumerate real children |

```tcl
namespace eval parent {
    namespace eval child1 {}
    namespace eval child2 {}
}
namespace children ::parent   ;# {::parent::child1 ::parent::child2}
```

#### `namespace descendants ?name? ?pattern?` **(Eagle)**

Returns all descendant namespaces recursively (not just direct
children). Not available in Tcl, where recursive enumeration requires
manual traversal.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Returns empty list |
| Namespace2 | Uses `NamespaceOps.Descendants()` for deep traversal |

```tcl
namespace eval a { namespace eval b { namespace eval c {} } }
namespace descendants ::a    ;# {::a ::a::b ::a::b::c}
```

#### `namespace info name` **(Eagle)**

Returns detailed information about a namespace, including its
properties and metadata.

Delegates to `NamespaceOps.InfoSubCommand()`.

```tcl
namespace info ::mylib   ;# Detailed namespace metadata
```

#### `[namespace mappings]` **(Eagle)**

Returns the namespace mapping table as key-value pairs. Mappings allow
remapping namespace names to other names (e.g., `::Eagle` -> `::` for
backward compatibility).

Thread-safe: uses `lock (interpreter.InternalSyncRoot)`.

```tcl
namespace mappings   ;# {::Eagle :: ...}
```

### 4.3 Path and Name Manipulation

#### `namespace qualifiers string`

Returns the namespace qualifiers portion of `[string]` — everything
before the last `::` separator.

Uses `NamespaceOps.SplitName()` internally.

```tcl
namespace qualifiers ::foo::bar::baz   ;# ::foo::bar
namespace qualifiers ::foo             ;# (empty — no qualifiers)
namespace qualifiers baz               ;# (empty — no qualifiers)
```

#### `namespace tail string`

Returns the tail portion of `[string]` — everything after the last `::`
separator.

```tcl
namespace tail ::foo::bar::baz   ;# baz
namespace tail ::foo              ;# foo
namespace tail baz                ;# baz
```

#### `namespace name name`

Converts a non-qualified name to an absolute (fully-qualified) name
in the context of the current namespace.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Uses `NamespaceOps.MakeAbsoluteName()` |
| Namespace2 | Uses `NamespaceOps.MakeQualifiedName()` with interpreter context |

```tcl
namespace eval myns {
    namespace name myproc   ;# ::myns::myproc
}
```

#### `namespace origin name`

Returns the fully-qualified name of the original command if `name` is
an imported alias. Traces through the import chain to find the
original source.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Uses `InternalDoesIExecuteExistViaResolvers()` |
| Namespace2 | Delegates to `NamespaceOps.Origin()` |

```tcl
namespace eval src { namespace export greet; proc greet {} { return "hi" } }
namespace import src::greet
namespace origin greet   ;# ::src::greet
```

#### `namespace which ?-command? ?-variable? name`

Determines where `name` resolves to. Returns the fully-qualified name
if found, empty string otherwise.

**Options** (mutually exclusive):

| Option | Description |
|--------|-------------|
| `-command` | Look up as command (default) |
| `-variable` | Look up as variable |

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Uses resolver methods: `InternalDoesIExecuteExistViaResolvers()` for commands, `GetVariableViaResolversWithSplit()` for variables |
| Namespace2 | Uses `NamespaceOps.Which()` with `NamespaceFlags` (Command or Variable) |

```tcl
namespace which -command puts    ;# ::puts
namespace which -variable env    ;# ::env
namespace which -command nosuch  ;# (empty string)
```

### 4.4 Exporting and Importing Commands

#### `namespace export ?-clear? ?pattern pattern ...?`

Specifies which commands in the current namespace can be imported by
other namespaces.

| Option | Description |
|--------|-------------|
| `-clear` | Clear existing export list before adding patterns |

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | No-op (silently succeeds) |
| Namespace2 | Calls `NamespaceOps.Export()`, stores in `namespace.ExportNames` |

Patterns must be simple (non-qualified) names.

```tcl
namespace eval mylib {
    namespace export greet farewell   ;# Allow import
    namespace export -clear add       ;# Clear previous, export only add
}
```

#### `namespace import ?-force? ?pattern pattern ...?`

Imports commands from other namespaces into the current namespace.

| Option | Description |
|--------|-------------|
| `-force` | Overwrite existing commands on conflict |

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | No-op |
| Namespace2 | Calls `NamespaceOps.Import()`, creates `IAlias` with `NamespaceImport` flag |

**Import mechanism (Namespace2):**

1. Resolve the source namespace from the qualified pattern
2. Match the pattern tail against the source namespace's `ExportNames`
3. For each match, create an `IAlias` in the current namespace:
   - `alias.SourceNamespace` = importing namespace
   - `alias.TargetNamespace` = exporting namespace
   - Store in namespace's `imports` dictionary
4. Register the alias in the interpreter's command table

```tcl
namespace eval mathlib {
    namespace export add subtract
    proc add {a b} { expr {$a + $b} }
    proc subtract {a b} { expr {$a - $b} }
    proc internal {} { return "not exported" }
}
namespace import mathlib::*
add 3 4   ;# 7 (no qualifier needed)
```

#### `namespace forget ?pattern pattern ...?`

Removes previously imported commands matching the patterns.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | No-op |
| Namespace2 | Calls `NamespaceOps.Forget()`, removes aliases |

```tcl
namespace forget mathlib::*
add 3 4   ;# Error: invalid command name "add"
```

### 4.5 Script Execution in Namespace Context

#### `namespace code script`

Returns a script that, when evaluated, will execute `script` in the
current namespace context. Useful for creating callbacks that preserve
namespace context.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Wraps with global namespace (always `::`) |
| Namespace2 | Wraps with actual current namespace |

```tcl
namespace eval myns {
    variable data secret
    proc showData {} { variable data; return $data }
    set callback [namespace code {showData}]
}
eval $myns::callback   ;# "secret" (executes in ::myns context)
```

#### `namespace inscope name arg ?arg...?`

Evaluates a script in namespace `name` with additional arguments
appended. Similar to `[namespace eval]` but handles argument concatenation
differently.

**Call frame behavior:**

| Implementation | Frame flags |
|----------------|-------------|
| Namespace1 | `Namespace \| InScope` |
| Namespace2 | `InScope \| UseNamespace` |

**Debugger integration**: When compiled with `DEBUGGER &&
DEBUGGER_BREAKPOINTS`, calls `ScriptOps.GetLocation()` for breakpoint
support.

On error, context information is appended:
`(in namespace inscope "name" script line N)`

```tcl
namespace eval myns {
    proc showArgs {args} { return $args }
}
namespace inscope ::myns showArgs a b c   ;# {a b c}
```

### 4.6 Unknown Command Handler

#### `namespace unknown ?script?`

Gets or sets the unknown command handler for the current namespace.

| Implementation | Behavior |
|----------------|----------|
| Namespace1 | Gets/sets `interpreter.NamespaceUnknown` (single global handler) |
| Namespace2 | Gets/sets per-namespace `currentNamespace.Unknown` property; falls back to `interpreter.GlobalUnknown` |

The per-namespace unknown handler in Namespace2 is a significant
extension over Tcl, which only supports a single global `unknown`
handler.

```tcl
namespace eval myns {
    namespace unknown {apply {{cmd args} {
        return "Unknown in myns: $cmd $args"
    }}}
}
```

---

## 5. Namespace Object Model

### INamespace interface

The `INamespace` interface (`Interfaces/Public/Namespace.cs`) defines
the namespace object contract:

| Property | Type | Description |
|----------|------|-------------|
| `Parent` | `INamespace` | Parent namespace (null for global) |
| `Resolve` | `IResolve` | Pluggable name resolver |
| `VariableFrame` | `ICallFrame` | Call frame holding namespace variables |
| `Unknown` | `[string]` | Per-namespace unknown command handler |
| `QualifiedName` | `[string]` | Cached fully-qualified name (`::parent::child`) |
| `ReferenceCount` | `int` | Reference count for lifecycle management |
| `Deleted` | `bool` | Deletion flag |
| `ExportNames` | `StringDictionary` | Exported command names |

### Namespace hierarchy

Namespaces form a tree via parent-child relationships:

```tcl
:: (global)
+-- ::mylib
|   +-- ::mylib::utils
|   +-- ::mylib::internal
+-- ::app
    +-- ::app::ui
```

**Child management methods** (Namespace.cs):

| Method | Description |
|--------|-------------|
| `GetChild(name)` | Lookup child by local name |
| `AddChild(namespace)` | Register a child namespace |
| `RenameChild(oldName, newName)` | Rename in children dictionary |
| `RemoveChild(name)` | Unregister a child |
| `GetAllChildren()` | Return all direct children |
| `ClearAllChildren()` | Clear the children dictionary |
| `MoveAllChildren(target)` | Move all children to another namespace |
| `GetChildren(pattern, deleted)` | Get children matching glob pattern |
| `GetDescendants(pattern, deleted)` | Get all descendants matching pattern |
| `Traverse(callback)` | Depth-first traversal |

### Reference counting

Namespaces track a reference count for lifecycle management:
- `IsNamespaceInUse()` checks whether the namespace is still referenced
- This prevents premature deletion of namespaces that are still on the
  call stack

### Qualified name caching

The `QualifiedName` property is computed once from the parent chain and
cached in a private field. It is reset via `ResetQualifiedName()` when
the namespace's parent or name changes, and this reset propagates to
all children via `ResetChildNames()`.

---

## 6. Name Resolution Algorithm

Eagle's namespace resolution is implemented in `NamespaceOps.cs` and
differs from Tcl's in its use of pluggable resolvers and call
frame integration.

### Resolution steps

1. **Determine the base namespace** (`GetBase()`):
   - If the name is absolute (starts with `::`) -> use GlobalNamespace
   - Otherwise -> use current namespace from the call frame's
     `ResolveData` via `GetCurrentNamespaceViaResolvers()`

2. **Descend by components** (`GetDescendant()`):
   - Split the name by `::` delimiter via `SplitName()`
   - For each component, look up the child in the current namespace
     via `parentNamespace.GetChild(localName)`
   - If `create=true` and child not found: create new namespace and
     add as child
   - Check deletion status against the `deleted` parameter

3. **Return result**:
   - Success: the resolved `INamespace` object
   - Failure: error with descriptive message

### Name classification

`NamespaceOps` provides utility methods for name analysis:

| Method | Description | Example |
|--------|-------------|---------|
| `IsQualifiedName()` | Contains `::` | `::foo::bar` -> true |
| `IsAbsoluteName()` | Starts with `::` | `::foo` -> true, `foo::bar` -> false |
| `IsGlobalName()` | Empty or only `::` | `::` -> true, `""` -> true |
| `SplitName()` | Parse into qualifiers and tail | `::a::b::c` -> (`::a::b`, `c`) |
| `MakeAbsoluteName()` | Add `::` prefix if needed | `foo` -> `::foo` |
| `MakeQualifiedName()` | Resolve relative to current namespace | `foo` in `::bar` -> `::bar::foo` |

### Variable resolution

`GetVariableFrame()` resolves the correct call frame for variable
access in a namespace context:

1. Check for `GlobalOnly` flag -> use `CurrentGlobalFrame`
2. Split variable name into qualifiers and tail
3. If qualified name:
   - Absolute path: lookup namespace from qualifiers, use its
     `VariableFrame`
   - Relative path: get descendant from current namespace, use its
     `VariableFrame`
4. If unqualified:
   - Check if current frame supports variables
     (`CallFrameOps.IsVariable`)
   - Check for `UseNamespace` flag: use `namespace.VariableFrame`
   - Fall back to namespace's `VariableFrame` if not global
   - Fall back to the interpreter's variable call frame

This layered approach ensures that variables are resolved in the
correct scope regardless of how deeply nested the namespace or call
frame context is.

---

## 7. Call Frame Integration

Eagle's namespaces are deeply integrated with the call frame stack.
This is a significant architectural difference from Tcl.

### Per-frame namespace context

Each call frame has a `ResolveData` property that stores the current
namespace context via a `ResolverClientData` wrapper:

```tcl
CallFrame.ResolveData -> ResolverClientData -> INamespace
```

**Getting the current namespace from a frame:**
```tcl
NamespaceOps.GetCurrent(interpreter, frame)
  -> frame.ResolveData -> ResolverClientData.Data -> INamespace
```

**Setting the current namespace on a frame:**
```tcl
NamespaceOps.SetCurrent(interpreter, frame, namespace)
  -> frame.ResolveData = new ResolverClientData(namespace)
```

### Frame types

| Frame flags | Usage |
|-------------|-------|
| `Namespace \| Evaluate` | Namespace1: `[namespace eval]` (no real binding) |
| `Evaluate \| UseNamespace` | Namespace2: `[namespace eval]` (real binding) |
| `Namespace \| InScope` | Namespace1: `[namespace inscope]` |
| `InScope \| UseNamespace` | Namespace2: `[namespace inscope]` |

### Frame lifecycle

| Implementation | Push | Pop |
|----------------|------|-----|
| Namespace1 | `NewTrackingCallFrame()` + `PushAutomaticCallFrame()` | `PopScopeCallFramesAndOneMore()` |
| Namespace2 | `NewNamespaceCallFrame()` + `PushNamespaceCallFrame()` | `PopNamespaceCallFrame()` |

### Cleanup on namespace disposal

When a namespace is disposed, `ClearCurrentForAll()` iterates through
the entire call stack removing references to the disposed namespace
from all frames. This prevents dangling references and ensures safe
cleanup.

---

## 8. Import/Export Mechanism

### Export

`NamespaceOps.Export()` stores export patterns in the namespace's
`ExportNames` dictionary. Only simple (non-qualified) names are
accepted as export patterns.

```tcl
namespace eval mylib {
    namespace export greet farewell
    proc greet {name} { return "Hello, $name!" }
    proc farewell {name} { return "Goodbye, $name!" }
    proc internal {} { return "not exported" }
}
```

With `-clear`, the existing export list is replaced entirely.

### Import

`NamespaceOps.Import()` performs a multi-step process:

1. **Resolve source namespace** from the qualified import pattern
2. **Match exported names** — the pattern tail is matched against the
   source namespace's `ExportNames`
3. **Create aliases** — for each match, an `IAlias` is created:
   - `alias.SourceNamespace` = the importing (current) namespace
   - `alias.TargetNamespace` = the exporting (source) namespace
   - The alias is stored in the importing namespace's `imports`
     dictionary
   - The alias is registered in the interpreter's command table with
     the `NamespaceImport` flag
4. **Conflict handling** — without `-force`, existing commands cause
   an error; with `-force`, they are overwritten

### Forget

`NamespaceOps.Forget()` reverses the import process:
- Removes aliases from the importing namespace's `imports` dictionary
- Unregisters the alias commands from the interpreter

### Origin tracing

`[namespace origin]` traces through the import chain to find the
original command. For deeply chained imports (A imports from B which
imports from C), it resolves all the way to the original source.

---

## 9. Namespace Mappings

Namespace mappings (`[namespace mappings]`) are an Eagle-specific feature
that provides a name remapping layer. The mapping table is stored in
`interpreter.NamespaceMappings` (a `StringDictionary`).

The primary use case is backward compatibility: the default mapping
redirects `::Eagle` to `::` (global namespace), allowing scripts that
reference `::Eagle::*` to work even when the Eagle namespace is not
explicitly created.

Access is thread-safe via `lock (interpreter.InternalSyncRoot)`.

```tcl
namespace mappings   ;# Returns the current mapping table
```

---

## 10. Per-Namespace Resolver

Each namespace has an `IResolve` property that provides a pluggable
name resolution strategy. This is queried via methods like
`GetCurrentNamespaceViaResolvers()` which walk the resolver chain.

The resolver architecture allows:
- Custom command lookup per namespace
- Custom variable resolution per namespace
- Integration with the interpreter's resolver infrastructure

This is more flexible than Tcl's fixed resolution rules and supports
advanced use cases like dynamic command loading, lazy evaluation, and
security-based filtering.

---

## 11. Scope Integration

Eagle's `[scope]` command provides four sub-commands for
namespace-scope interoperability (documented in `scope.md`):

| Sub-command | Description |
|-------------|-------------|
| `scope attach name namespace` | Associate a scope's variables with a namespace |
| `scope detach name namespace` | Disassociate a scope from a namespace |
| `scope export name namespace` | Move variables from a scope into a namespace |
| `scope import name namespace` | Move variables from a namespace into a scope |

This allows scopes (persistent named variable environments) to be
linked with namespaces, combining Eagle's unique scope persistence
with standard namespace organization.

---

## 12. Safe Interpreter Behavior

The `[namespace]` command is marked `CommandFlags.Safe`, meaning it is
available in safe interpreters. However, certain sub-commands have
restricted behavior:

- Option parsing error messages are sanitized in safe interpreters
  (`!interpreter.InternalIsSafe()` check)
- `[namespace enable]` requires explicit parameters — a safe interpreter
  cannot accidentally enable full namespaces
- `[namespace rename]` safety flags (`RenameGlobalOk`, `RenameInUseOk`)
  both default to `false`, preventing dangerous renames

The namespace command does not expose filesystem or network resources,
so the primary security concern is denial-of-service through excessive
namespace creation. This is bounded by interpreter resource limits.

---

## 13. Practical Patterns

### Pattern 1 — Basic namespace organization

```tcl
namespace eval mylib {
    variable version 1.0

    proc greet {name} {
        return [appendArgs "Hello from mylib v" \
            [set [namespace current]::version] ", " $name !]
    }

    proc getVersion {} {
        variable version
        return $version
    }
}

mylib::greet World      ;# "Hello from mylib v1.0, World!"
mylib::getVersion       ;# "1.0"
```

### Pattern 2 — Export/import for clean APIs

```tcl
namespace eval mathlib {
    namespace export add subtract multiply
    proc add {a b} { expr {$a + $b} }
    proc subtract {a b} { expr {$a - $b} }
    proc multiply {a b} { expr {$a * $b} }
    proc _internal {x} { expr {$x * $x} }  ;# Not exported
}

namespace import mathlib::*
add 3 4        ;# 7
multiply 5 6   ;# 30

# Clean up
namespace forget mathlib::*
```

### Pattern 3 — Namespace callbacks preserving context

```tcl
namespace eval myns {
    variable state 0

    proc increment {} {
        variable state
        incr state
    }

    proc getCallback {} {
        return [namespace code {increment}]
    }
}

set cb [myns::getCallback]
eval $cb   ;# Increments myns::state in ::myns context
```

### Pattern 4 — Hierarchical namespaces

```tcl
namespace eval app {
    namespace eval ui {
        proc render {} { return "rendering" }
    }
    namespace eval core {
        proc process {} { return "processing" }
    }
}

# Enumerate hierarchy
namespace children ::app       ;# {::app::ui ::app::core}
namespace descendants ::app    ;# {::app ::app::ui ::app::core}
```

### Pattern 5 — Per-namespace unknown handler

```tcl
namespace eval plugin {
    namespace unknown {apply {{cmd args} {
        # Auto-load plugin commands on first use
        puts "Auto-loading: $cmd"
        # ... load the command ...
        return "loaded $cmd"
    }}}
}
```

### Pattern 6 — Name manipulation utilities

```tcl
set fullName "::app::ui::render"
set ns   [namespace qualifiers $fullName]   ;# ::app::ui
set cmd  [namespace tail $fullName]          ;# render
set abs  [namespace eval ::app { namespace name myproc }]  ;# ::app::myproc
```

### Pattern 7 — Scope-namespace integration

```tcl
# Create a persistent scope and attach to namespace
scope create -open mystate
scope set mystate counter 0

namespace eval myns {}
scope attach mystate ::myns
# Now myns has access to the scope's variables
```

### Pattern 8 — Detecting namespace support

```tcl
# Check if full namespaces are enabled
set nsEnabled [namespace enable]
if {!$nsEnabled} {
    namespace enable true   ;# Activate full support
}
```

---

## 14. Comparison with Tcl

| Feature | Tcl `[namespace]` | Eagle `[namespace]` |
|---------|----------------|-------------------|
| Sub-commands | 19 | 22 |
| Enable/disable | Always enabled | `[namespace enable]` toggles |
| Implementation | Single | Dual: stub + full |
| eval / inscope | Create namespace + execute | Same + call frame binding |
| delete / exists | Standard | Same |
| current / parent / children | Standard | Same + `descendants` (recursive) |
| export / import / forget | Standard | Same (no-op in Namespace1) |
| code | Standard | Same |
| qualifiers / tail | Standard | Same |
| origin / which | Standard | Same |
| unknown | Global handler only | Per-namespace handler |
| rename | Not supported | `[namespace rename]` with safety flags |
| info | Not a sub-command | `[namespace info]` for metadata |
| mappings | None | Namespace name remapping table |
| ensemble | `namespace ensemble` | Not script-accessible |
| path | `namespace path` | Not supported |
| upvar | Standard cross-namespace | Supported via qualified names |
| Scope integration | None | `scope attach/detach/export/import` |
| Resolver | Fixed rules | Pluggable `IResolve` per namespace |
| Variable storage | Namespace-scoped | Per-namespace `ICallFrame` |
| Reference counting | None | Tracked for safe lifecycle |

**Notable Tcl features not in Eagle:**
- `namespace ensemble create` — Eagle has ensembles internally but
  does not expose script-level ensemble creation
- `namespace path` — not supported; use `[namespace import]` instead

---

## 15. Security Considerations

### Denial of service

Excessive namespace creation could consume memory. Interpreter resource
limits (iteration limits, recursion limits) bound the damage, but
embedders should be aware of this vector.

### Rename safety

The `[namespace rename]` command defaults to blocking global namespace
renames and in-use namespace renames. The `RenameGlobalOk` and
`RenameInUseOk` flags must be explicitly set (via reflection) to
permit these dangerous operations.

### Import shadowing

`namespace import -force` can overwrite existing commands. Without
`-force`, conflicts are detected and reported as errors. Scripts
should be cautious with wildcard imports (`namespace import ns::*`)
in shared environments.

### Mapping manipulation

Namespace mappings affect name resolution globally for the interpreter.
Modifying mappings could redirect namespace lookups in unexpected ways.
The mappings table is accessed under a lock for thread safety.

---

## 16. References

- **Source (Namespace1)**: `eagle/Eagle/Library/Commands/Namespace1.cs`
- **Source (Namespace2)**: `eagle/Eagle/Library/Commands/Namespace2.cs`
- **Namespace operations**: `eagle/Eagle/Library/Components/Private/NamespaceOps.cs`
- **Namespace object**: `eagle/Eagle/Library/Components/Private/Namespace.cs`
- **Namespace data**: `eagle/Eagle/Library/Components/Public/NamespaceData.cs`
- **INamespace interface**: `eagle/Eagle/Library/Interfaces/Public/Namespace.cs`
- **Core language reference**: `core_language.md` § Namespaces ->
  `[namespace]` command
- **Examples**: `core_examples.md` § namespace
- **Scope integration**: `scope.md` § Namespace Integration
- **Tcl reference**: [Tcl `[namespace]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/namespace.htm)
