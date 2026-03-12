# Eagle `[scope]` Command: Deep-Dive Analysis of Persistent Variable Environments

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `scope` command internals. For basic command syntax and options, see [`core_language.md`](core_language.md#cmd-scope). For usage examples, see [`core_examples.md`](core_examples.md#ex-scope). For tips and patterns, see [`tips_and_tricks.md`](tips_and_tricks.md#persistent-state-with-scope).

## 1. Executive Summary

Eagle's `[scope]` command provides **persistent named variable environments**
(call frames) that survive across procedure calls. A scope is a first-class
variable dictionary that can be independently created, populated, pushed onto
the call stack, popped off, locked, cloned, attached to namespaces, and
destroyed — all under explicit script control.

This is a concept **unique to Eagle**. Native Tcl has no equivalent command.
Tcl procedures get a fresh local frame on every call; when the procedure
returns, that frame is destroyed. Tcl provides `global`, `upvar`, and
`variable` to reach variables in other frames, but it has no mechanism to
name a frame, preserve it across calls, and push it back later. Eagle's
`[scope]` fills that gap.

The core idea is simple: **a scope is a reusable call frame with a name.**
Once created, a scope's variables persist until the scope is explicitly
destroyed. Opening a scope pushes it onto the call stack so its variables
become the current local variables. Closing it (or returning from a
procedure) pops it. The same scope can be opened and closed any number of
times, and its variables accumulate state across those uses.

**Key source files:**

| File | Role |
|------|------|
| `Eagle/Library/Commands/Scope.cs` | Main command implementation (1,661 lines, 19 sub-commands) |
| `Eagle/Library/Components/Private/CallFrameOps.cs` | Scope creation, cloning, naming, and frame utilities |
| `Eagle/Library/Components/Private/NamespaceOps.cs` | Scope–namespace integration (attach/detach/export/import) |
| `Eagle/Library/Components/Public/Interpreter.cs` | Scope storage, locking, call stack management, global scope |
| `Eagle/Library/Components/Public/Enumerations.cs` | `CallFrameFlags` (Scope, GlobalScope, Fast, etc.) |

**Command flags:** `Safe | NonStandard` — the command is available in safe
interpreters and is explicitly marked as a non-standard Eagle extension.

**Object group:** `variable` — classified alongside other variable-management
commands.

## 2. Why Scopes Exist: The Problem They Solve

### The Tcl Limitation

In native Tcl, procedure-local state is ephemeral. Every call to a procedure
creates a fresh variable frame; when the procedure returns, that frame is
destroyed. If you want state to persist across calls, your options are:

1. **Global variables** — work but pollute the global namespace.
2. **Namespace variables** — better isolation but still require `variable`
   declarations and are visible to any code in the namespace.
3. **`upvar` to a caller's frame** — ties the callee to the caller's variable
   naming, creating fragile coupling.
4. **Object-oriented extensions** (TclOO, Itcl) — heavyweight for simple state.

All of these share a limitation: the state is either globally accessible, tied
to a specific call chain, or requires an object system.

### The Eagle Solution

A scope is a **named, private variable environment** that:

- Persists independently of the call stack.
- Can be opened (pushed) by any procedure that knows its name.
- Provides local-variable semantics while open (no `variable` or `global`
  declarations needed).
- Can be cloned from existing state, locked for thread safety, or attached to
  namespaces.
- Is automatically closed when a procedure returns (no resource leak on error).

This makes scopes ideal for:

- **Persistent counters and accumulators** without globals.
- **Coroutine-like patterns** where a procedure resumes from where it left off.
- **Per-procedure private state** via the `-procedure` auto-naming option.
- **Thread-safe shared state** via locking.
- **Sandboxed global environments** via `scope global`.
- **Variable exchange with namespaces** via attach/detach/export/import.

## 3. The Scope Lifecycle

A scope progresses through four phases:

```
  create ──► open (push) ──► use (read/write variables) ──► close (pop) ──► destroy
    │             │                                              │              │
    │             └──── can be repeated any number of times ─────┘              │
    │                                                                           │
    └────────────── scope persists across open/close cycles ────────────────────┘
```

### Phase 1: Create (`scope create`)

Creates a named call frame with `CallFrameFlags.Scope` (0x2000) and registers
it in the interpreter's scope dictionary. The frame gets its own empty (or
cloned) `VariableDictionary`. Key behaviors:

- If `name` already exists and `-strict` is not set, the existing scope is
  returned without modification — this is the **idempotent create** pattern
  that makes `scope create -open -clone -args $name` safe to call repeatedly.
- If `-strict` is set and the scope already exists, an error is returned.
- If no name is provided, an automatic name is generated via
  `CallFrameOps.GetAutomaticScopeName()` (format: `scopeN`).
- The interpreter enforces a **scope limit** (`ScopeLimit` property): 50 in
  safe interpreters, unlimited in unsafe interpreters.

### Phase 2: Open (`scope open` or `scope create -open`)

Pushes the scope's call frame onto the interpreter's call stack via
`PushCallFrame()`. This makes the scope's variables accessible as local
variables. Each open:

- Increments `[info level]` by 1.
- Can be nested — the same scope can be opened multiple times, stacking
  additional frames.
- Optionally copies procedure arguments into the scope (with `-args`).

### Phase 3: Use

While a scope is open, its variables behave like ordinary local variables.
`set`, `unset`, `info exists`, `incr`, `append`, `lappend`, `array`, and all
other variable commands work directly on the scope's variable dictionary.

Variables can also be accessed **without opening** the scope, via `scope set`,
`scope unset`, and `scope vars`. This is useful for inspection or
configuration outside the scope's execution context.

### Phase 4: Close (`scope close` or implicit on procedure return)

Pops the scope's call frame from the call stack. The scope and its variables
continue to exist — only the stack position is removed. Key behaviors:

- Without a name, closes the innermost open scope.
- With `-all`, closes all currently open scopes.
- **Implicit close**: When a procedure returns (normally or via error), Eagle's
  procedure-return machinery calls `PopScopeCallFrames()`, which pops all scope
  frames that were opened within that procedure. This is the safety net that
  prevents scope leaks on error paths.

### Phase 5: Destroy (`scope destroy`)

Removes the scope from the interpreter's scope dictionary and releases its
variable dictionary. If the scope is currently open, it is closed first. Any
opaque object handles stored in scope variables are released. After destroy,
the scope name can be reused.

## 4. Sub-Command Reference

The `[scope]` ensemble has **19 sub-commands**:

### 4.1 Core Lifecycle Sub-Commands

#### `scope create ?options? ?name?`

Creates a new scope or returns an existing one (idempotent unless `-strict`).

**Options:**

| Option | Effect |
|--------|--------|
| `-args` | Copy procedure arguments from the enclosing procedure frame into the scope |
| `-clone` | Clone variables from the current variable frame into the new scope |
| `-byref` | Clone variables by reference instead of by value (unsafe) |
| `-global` | Clone from the global frame instead of the current frame |
| `-open` | Immediately open (push) the scope after creation |
| `-procedure` | Auto-generate scope name from enclosing procedure (cannot specify `name`) |
| `-shared` | Use shared naming for cross-thread scenarios |
| `-strict` | Error if scope already exists |
| `-fast` | Enable fast local variable access (disables variable tracing/debug) |

**Returns:** The scope name (auto-generated or as provided).

**Implementation details** (`Scope.cs`, lines 123-316):
1. If `-procedure` is set, calls `CallFrameOps.GetAutomaticScopeName(frame,
   shared)` to derive the name from the enclosing procedure or lambda frame.
   The procedure's name is embedded in the scope name, with an optional
   thread ID for non-shared scopes.
2. If the scope already exists (checked via `interpreter.GetScope()`):
   - With `-strict`: returns error.
   - Without `-strict`: returns the existing name (no modification).
3. For new scopes:
   - Calls `interpreter.NewScopeCallFrame()` to create the call frame.
   - If `-clone`: calls `CallFrameOps.CloneToNewScope()` to copy variables.
   - If `-fast`: calls `CallFrameOps.SetFast()` to set `CallFrameFlags.Fast`.
   - Calls `interpreter.AddScope()` to register.
4. If `-open`: pushes the frame via `interpreter.PushCallFrame()`.
5. If `-args`: calls `interpreter.CopyProcedureArgumentsToFrame()`.

#### `scope open ?options? ?name?`

Pushes an existing scope onto the call stack.

**Options:** `-procedure`, `-shared`, `-args` (same behavior as in `create`).

**Returns:** Empty string.

**Implementation** (`Scope.cs`, lines 585-669):
1. Resolves the scope name (direct or via `-procedure`).
2. Retrieves the scope via `interpreter.GetScope()`.
3. Pushes via `interpreter.PushCallFrame()`.
4. If `-args`: copies procedure arguments.

#### `scope close ?options? ?name?`

Pops the current or named scope from the call stack.

**Options:**
- `-all` — Close all open scopes, not just the innermost.

**Returns:** The name of the closed scope.

**Implementation** (`Scope.cs`, lines 317-370):
1. Without `-all`: calls `interpreter.PopScopeCallFrames()` or
   `interpreter.GetScopeCallFrame(name, ..., pop=true, remove=false)`.
2. With `-all`: uses `interpreter.PopScopeCallFrames()` in a loop until no
   more scope frames remain.
3. Only pops scope frames — non-scope frames on the stack are left in place.

#### `scope destroy name`

Destroys a scope and releases its resources.

**Returns:** List containing cleanup information (variable names, etc.).

**Implementation** (`Scope.cs`, lines 371-414):
1. Calls `interpreter.RemoveScope(name)`.
2. Inside `RemoveScope`: if the scope is the current global scope, unsets it
   first. If the scope is on the call stack, pops it. Detaches from any
   namespaces via `NamespaceOps.DetachScope()`. Removes from the scope
   dictionary.

### 4.2 Evaluation

#### `scope eval ?options? name arg ?arg ...?`

Evaluates a script in the context of a named scope.

**Options:**

| Option | Effect |
|--------|--------|
| `-lock` | Acquire lock on scope during evaluation |
| `-timeout milliseconds` | Timeout for lock acquisition (unsafe) |
| `-eventwaitflags flags` | Event wait flags for lock (unsafe) |

**Returns:** The result of the evaluated script.

**Implementation** (`Scope.cs`, lines 415-584):
1. Retrieves the scope via `interpreter.GetScope()`.
2. Concatenates script arguments.
3. If `-lock`: acquires the scope lock (with optional timeout/wait flags).
4. Pushes the scope frame onto the call stack.
5. Evaluates the script via `interpreter.EvaluateScript()`.
6. In the `finally` block: pops all scope call frames that were pushed
   during evaluation, then unlocks if locked.

The finally-block cleanup ensures scopes are properly unwound even when
errors, `return`, `break`, or `continue` interrupt the script.

### 4.3 Variable Access Without Opening

These sub-commands manipulate variables in a scope **without** pushing it onto
the call stack:

#### `scope set name varName ?value?`

Gets or sets a variable within the named scope. Uses
`interpreter.SetVariableValue2()` or `interpreter.GetVariableValue2()` with
the scope's frame directly.

#### `scope unset name varName`

Removes a variable from the scope. Uses `interpreter.UnsetVariable2()` with
the scope's frame.

#### `scope vars name ?pattern?`

Lists variable names defined in the scope, optionally filtered by glob pattern.
Iterates the scope's `VariableDictionary` directly.

### 4.4 Query Sub-Commands

#### `scope exists name`

Returns boolean `True` if the named scope exists, `False` otherwise. Calls
`interpreter.GetScope()` with `LookupFlags.NoUsable` to avoid side effects.

#### `scope current`

Returns the name of the currently open (topmost) scope on the call stack, or
empty string if no scope is open. Walks the call stack looking for frames
with `CallFrameFlags.Scope`.

#### `scope list ?pattern?`

Returns a list of all defined scope names, optionally filtered by glob pattern.
Queries the interpreter's internal scope dictionary.

### 4.5 Thread-Safety Sub-Commands

#### `scope lock ?options? name`

Acquires a lock on the named scope, preventing concurrent modification.

**Options:** `-nocomplain` — don't error if scope doesn't exist.

**Returns:** Empty string on success.

**Implementation:** Calls `interpreter.LockScope()`, which internally calls
`frame.Lock()`. The lock is a .NET `Monitor`-style lock on the call frame
object.

#### `scope unlock ?options? name`

Releases a previously acquired lock.

**Options:** `-nocomplain` — don't error if scope doesn't exist.

**Returns:** Empty string on success.

**Implementation:** Calls `interpreter.UnlockScope()`, which internally calls
`frame.Unlock()`.

The lock/unlock mechanism is distinct from the `-lock` option on `scope eval`.
Manual lock/unlock gives the script fine-grained control over when the lock is
held, while `scope eval -lock` provides automatic lock management scoped to
the evaluation.

### 4.6 Update Sub-Command

#### `scope update ?options? ?name?`

Refreshes a scope's variables by cloning from the current or global frame.

**Options:** `-global` — clone from the global frame instead of the current
frame.

**Returns:** Empty string on success.

**Implementation** (`Scope.cs`, lines 827-896):
1. Resolves the target scope (by name or current open scope).
2. Calls `CallFrameOps.CloneToExistingScope()` to merge variables from the
   source frame into the scope.
3. Existing variables in the scope are updated; new variables from the
   source are added.

This is useful for refreshing a scope's snapshot of local or global variables
after they have changed.

### 4.7 Global Scope Redirection

#### `scope global ?options? ?name?`

Gets or sets the interpreter's **global scope**. When a global scope is active,
variable operations that would normally target the true global frame are
redirected to the designated scope instead.

**Options:**

| Option | Effect |
|--------|--------|
| `-unset` | Clear the global scope (cannot specify `name`) |
| `-force` | Force setting even if a global scope is already set |

**Returns:** The current global scope name (may be empty).

**Implementation** (`Scope.cs`, lines 670-771):
1. Without arguments: returns the current `GlobalScopeFrame` name.
2. With `-unset`: calls `interpreter.UnsetGlobalScopeCallFrame()`, which
   restores normal global-frame behavior.
3. With `name`: calls `interpreter.SetGlobalScopeCallFrame(name)`, which:
   - Retrieves the scope.
   - Calls `CallFrameOps.MarkGlobalScope()` to change its flags from
     `CallFrameFlags.Scope` to `CallFrameFlags.GlobalScopeMask`
     (`NoFree | GlobalScope`).
   - Sets the `GlobalScopeFrame` property.
   - Pushes a global call frame.
   - Marks the original global frame as invisible to prevent `[uplevel 1]`
     from accidentally reaching it.

This effectively creates a **sandboxed global environment**: scripts that
use `global varName` or `set ::varName` will operate on the scope's variables
instead of the true global frame.

### 4.8 Namespace Integration Sub-Commands

These sub-commands require the interpreter's namespace support to be enabled.
They bridge the scope and namespace variable systems.

#### `scope attach name namespace`

Associates a scope's variables with a namespace. Variables from the scope are
added to the namespace's variable dictionary and marked as namespace-owned.

**Returns:** List of attached variable names.

**Implementation:** Calls `NamespaceOps.AttachScope()`, which iterates the
scope's variables and, for each one not already in the namespace: marks it
with namespace ownership, adds it to the namespace's dictionary, and resets
its frame reference to the namespace frame.

#### `scope detach name namespace`

Disassociates a scope's variables from a namespace. Reverses the effect of
`scope attach`.

**Returns:** List of detached variable names.

**Implementation:** Calls `NamespaceOps.DetachScope()`, which iterates the
scope's variables and, for each one matching the namespace: removes namespace
marks, removes from namespace dictionary, and resets frame reference back to
the scope frame.

#### `scope export name namespace`

**Moves** variables from a scope into a namespace. Unlike `attach`, the
variables are removed from the scope's dictionary and added to the namespace's
dictionary.

**Returns:** List of exported variable names.

**Implementation:** Calls `NamespaceOps.ExportScope()`, which creates a
defensive copy of scope variables, filters out read-only/invariant/system
variables, and for each eligible variable: removes from scope, adds to
namespace.

#### `scope import name namespace`

**Moves** variables from a namespace into a scope. The inverse of `export`.

**Returns:** List of imported variable names.

**Implementation:** Calls `NamespaceOps.ImportScope()`, which creates a
defensive copy of namespace variables, filters the same way as export, and
for each eligible variable: removes from namespace, adds to scope.

**Attach vs. Export distinction:** `attach` creates a **shared reference** —
the variable exists in both the scope and the namespace. `export` performs a
**move** — the variable leaves the scope and enters the namespace exclusively.

## 5. The Call Frame Stack Model

Understanding scopes requires understanding Eagle's call frame stack.

### 5.1 What Is a Call Frame?

Every execution context in Eagle has a call frame (`ICallFrame`). Call frames
are stacked: the global frame is at the bottom, and each procedure call,
lambda application, scope open, or engine evaluation pushes a new frame on
top. The topmost frame is the "current" frame and determines where unqualified
variable operations go.

Each call frame has:

- A **name** (scope name, procedure name, or auto-generated).
- A **VariableDictionary** (the variables owned by this frame).
- An **ArgumentList** (the arguments, if any).
- **CallFrameFlags** (a `[Flags]` enum indicating the frame's type and properties).
- A **level** (its position in the stack).

### 5.2 Frame Type Flags

The `CallFrameFlags` enum (64-bit unsigned) includes these scope-relevant
flags:

| Flag | Value | Meaning |
|------|-------|---------|
| `Scope` | 0x2000 | Frame is a scope created by `[scope]` |
| `GlobalScope` | 0x40 | Frame is the redirected global scope |
| `Global` | 0x20 | The outermost (true) global frame |
| `Procedure` | 0x80 | Frame for a procedure body evaluation |
| `Lambda` | 0x800 | Frame for `[apply]` (lambda) |
| `Fast` | 0x800000000 | Disables variable tracing/debug for this frame |
| `NoFree` | 0x8 | Frame should not be freed on pop |
| `Invisible` | 0x80000000 | Frame is skipped by `[uplevel]` |
| `Engine` | 0x10 | Frame pushed by the engine itself |

The `Variables` composite mask includes: `Global | Procedure | Lambda |
Namespace | Scope | GlobalScope` — these are all the frame types that may own
variables.

### 5.3 How Scope Open/Close Interacts with the Stack

When `scope open` pushes a scope frame:
1. The scope frame becomes the current frame.
2. `[info level]` increments by 1.
3. Variable lookups resolve against the scope's variable dictionary.
4. `[upvar]` and `[uplevel]` can reach frames beneath the scope.

When `scope close` pops a scope frame:
1. The frame below becomes current again.
2. `[info level]` decrements by 1.
3. The scope's variables remain in the scope — they are not destroyed.

Multiple opens of the same scope create multiple stack entries pointing to the
same variable dictionary. This means:

```tcl
scope create foo
scope open foo       ;# level +1
scope open foo       ;# level +2 (same variables!)
scope close          ;# level +1
scope close          ;# level +0
```

Both opens share the same `VariableDictionary`, so a variable set at level +2
is visible at level +1 when the top frame is closed.

### 5.4 Implicit Close on Procedure Return

Eagle's procedure-return code path calls `PopScopeCallFramesAndOneMore()`,
which pops all frames with `CallFrameFlags.Scope` from the top of the stack,
plus the procedure's own frame. This guarantees that scopes opened inside a
procedure are properly closed even on error, `return`, `break`, or `continue`.

The key code path:
1. Procedure call pushes a `Procedure` frame.
2. Script inside the procedure calls `scope open`, pushing a `Scope` frame.
3. Procedure returns (normally or via error).
4. `PopScopeCallFramesAndOneMore()` pops the `Scope` frame(s), then pops the
   `Procedure` frame.
5. The scope itself (in the scope dictionary) is untouched — only the stack
   position is removed.

## 6. Clone Modes

The `-clone` option on `scope create` (and the `scope update` sub-command)
copies variables from a source frame into the scope. Three clone modes are
available:

### 6.1 Clone by Value (default)

```tcl
scope create -clone myScope
```

Calls `CallFrameOps.CloneToNewScope()` with `byRef=false`. Each variable in
the source frame is duplicated: a new `Variable` object is created via
`VariableDictionary.Create()` with `CloneFlags.ScopeMask`. The new variable
is independent — changes to the clone do not affect the original, and vice
versa.

**Implementation detail:** The source variables are first copied to a
defensive copy (to avoid trace side-effects during iteration), then each
variable is cloned and re-parented to the new scope frame.

### 6.2 Clone by Reference (`-byref`, unsafe)

```tcl
scope create -clone -byref myScope
```

Calls `CloneToNewScope()` with `byRef=true`. Instead of creating new `Variable`
objects, the scope receives **references to the original variables**. Changes
to a variable through the scope are visible in the original frame, and vice
versa. This is marked as an unsafe option because it breaks frame isolation.

### 6.3 Clone from Global (`-global`)

```tcl
scope create -clone -global myScope
```

Uses the global frame as the clone source instead of the current variable
frame. Combined with `-byref`, this creates a scope with live references to
global variables.

### 6.4 Update (Re-clone)

```tcl
scope update myScope
scope update -global myScope
```

Calls `CallFrameOps.CloneToExistingScope()` to refresh an existing scope's
variables from the current or global frame. Existing scope variables are
updated; new variables from the source are added. This is useful for
re-snapshotting state after it has changed.

## 7. Procedure-Based Auto-Naming

The `-procedure` option provides automatic scope naming based on the enclosing
procedure:

```tcl
proc myProc {x} {
  scope create -open -procedure -args
  # scope name is automatically derived from "myProc"
  ...
}
```

### 7.1 Name Generation Algorithm

`CallFrameOps.GetAutomaticScopeName(ICallFrame frame, bool shared)`:

1. Walks up the call stack to find the enclosing procedure or lambda frame.
2. For **procedures**: uses the procedure name.
3. For **lambdas**: uses the frame's hash code (since lambdas have no name).
4. Appends a thread-specific suffix:
   - With `-shared`: uses ID 0 (constant across threads), producing the same
     name regardless of which thread calls the procedure.
   - Without `-shared`: uses the current system thread ID, producing
     thread-specific scope names.

### 7.2 The `-shared` Option

By default, each thread gets its own scope (because the thread ID is part of
the name). With `-shared`, all threads share the same scope. This is useful
for shared state but requires locking to be thread-safe:

```tcl
proc sharedCounter {} {
  scope create -open -procedure -shared -args
  scope lock [scope current]
  if {![info exists count]} {set count 0}
  incr count
  set result $count
  scope unlock [scope current]
  return $result
}
```

Or more concisely with `scope eval -lock`:

```tcl
proc sharedCounter {} {
  scope create -procedure -shared
  scope eval -lock $::scope {
    if {![info exists count]} {set count 0}
    incr count
  }
}
```

## 8. Thread-Safe Locking

Eagle scopes support two locking mechanisms:

### 8.1 Manual Lock/Unlock

```tcl
scope lock myScope
# ... exclusive access to scope variables ...
scope unlock myScope
```

`scope lock` calls `interpreter.LockScope()` → `frame.Lock()`, which acquires
a .NET `Monitor`-style lock on the call frame object. `scope unlock` releases
it. The `-nocomplain` option on both suppresses errors if the scope doesn't
exist.

**Caution:** Manual lock/unlock requires careful coding to ensure the lock is
always released, even on error. Consider using `scope eval -lock` instead.

### 8.2 Automatic Locking with `scope eval -lock`

```tcl
scope eval -lock myScope {
  # lock is held during this script
  # automatically released on completion (success or error)
}
```

The `-lock` option on `scope eval` acquires the lock before pushing the scope,
evaluates the script, and releases the lock in the `finally` block. This is
the recommended approach for thread-safe scope access because it guarantees
lock release.

The `-timeout` option (unsafe) specifies how long to wait for the lock in
milliseconds. The `-eventwaitflags` option (unsafe) controls event processing
during the wait.

### 8.3 Lock Scope vs. Frame Isolation

Locking a scope prevents **other lock-respecting code** from modifying it.
It does not prevent non-locking access — `scope set`, `scope unset`, or
direct variable access from a frame where the scope is open will still work
without holding the lock. Locking is cooperative, not enforced.

## 9. Global Scope Redirection

The `scope global` sub-command provides a powerful mechanism for redirecting
the interpreter's global variable frame:

```tcl
scope create sandbox
scope eval sandbox {set x 100; set y 200}
scope global sandbox
# Now: global x → sandbox's x (100)
# Now: set ::x  → sandbox's x (100)
# The true global frame is hidden
scope global -unset
# Normal global frame restored
scope destroy sandbox
```

### 9.1 How It Works Internally

When `scope global sandbox` is called:

1. The scope is retrieved from the scope dictionary.
2. `CallFrameOps.MarkGlobalScope()` changes its flags:
   - Removes `CallFrameFlags.Scope`.
   - Applies `CallFrameFlags.GlobalScopeMask` = `NoFree | GlobalScope`.
3. The scope is stored as `interpreter.GlobalScopeFrame`.
4. A new global call frame is pushed.
5. The original global frame is marked `Invisible` (0x80000000), preventing
   `[uplevel 1]` from reaching it directly.

When `scope global -unset` is called:

1. The current `GlobalScopeFrame` is retrieved.
2. Its flags are converted back to normal scope flags via
   `GetNonGlobalScopeFlags()`.
3. The `GlobalScopeFrame` property is cleared.
4. The original global frame's visibility is restored.

### 9.2 Use Cases

- **Sandboxing**: Isolate untrusted scripts from the real global environment.
- **Testing**: Create a clean global environment for test scripts without
  affecting the real global state.
- **Multi-tenant interpreters**: Give different contexts their own "global"
  variable spaces.

### 9.3 Limitations

- Only one global scope can be active at a time (unless `-force` is used to
  override).
- The `-force` option is required to replace an already-set global scope.
- The true global frame still exists — it is hidden, not removed.

## 10. Comparisons to Other Languages

Eagle's `[scope]` has no direct equivalent in Tcl or most other scripting
languages, but it shares concepts with features in several languages:

### 10.1 vs. Tcl: No Equivalent

Tcl has no mechanism to name, preserve, and restore a procedure's local
variable frame. The closest Tcl idioms:

| Tcl Approach | Limitation | Eagle Scope Advantage |
|-------------|-----------|----------------------|
| Global variables | Namespace pollution | Scopes are named and private |
| Namespace variables | Require `variable` decl, visible to all ns code | Scopes need no declarations |
| `upvar` to caller | Tight coupling to caller's naming | Scopes are independent |
| TclOO instance variables | Requires object system overhead | Scopes are lightweight |
| Coroutines (8.6+) | Single entry/exit point | Scopes can be opened from any procedure |

### 10.2 vs. JavaScript Closures

JavaScript closures capture the enclosing scope's variables by reference.
Eagle scopes are explicitly named and opened/closed — there is no automatic
capture.

```javascript
// JavaScript: closure captures 'count' automatically
function makeCounter() {
  let count = 0;
  return () => ++count;
}
```

```tcl
# Eagle: scope preserves 'count' explicitly
proc counter {name} {
  scope create -open -clone -args $name
  if {![info exists count]} {set count 0}
  incr count
  return $count
}
```

Key difference: JavaScript closures are created implicitly at function
definition time. Eagle scopes are created and opened explicitly at call time.

### 10.3 vs. Python Instance Variables

Python uses `self.varName` to access instance state. Eagle scopes provide
similar persistent state but without requiring an object system:

```python
# Python: requires a class
class Counter:
    def __init__(self):
        self.count = 0
    def increment(self):
        self.count += 1
        return self.count
```

```tcl
# Eagle: no class needed
proc counter {name} {
  scope create -open -clone -args $name
  if {![info exists count]} {set count 0}
  incr count
  return $count
}
```

### 10.4 vs. Perl `local` / `my`

Perl's `local` provides dynamically-scoped variables, and `my` provides
lexically-scoped variables. Neither persists across calls. Eagle scopes
are closest to Perl's "closure over a lexical variable" pattern, but more
explicit and controllable.

### 10.5 vs. Ruby Binding Objects

Ruby's `Binding` class captures the execution context (local variables, self,
block). Eagle's scopes are similar in that they capture and preserve a variable
environment, but scopes are more controllable — they can be explicitly
populated, updated, locked, and destroyed.

### 10.6 vs. Lua Upvalues

Lua's upvalues allow closures to reference variables from enclosing scopes.
Like JavaScript closures, this is an automatic capture mechanism. Eagle scopes
require explicit creation and management but offer features Lua upvalues
don't: naming, independent lifecycle, locking, and namespace integration.

## 11. The Underlying Infrastructure

### 11.1 CallFrameOps (Private)

| Method | Purpose |
|--------|---------|
| `GetAutomaticScopeName(Interpreter)` | Generates `scopeN` names using interpreter's NextId |
| `GetAutomaticScopeName(ICallFrame, bool)` | Generates procedure/lambda-based scope names |
| `IsScope(ICallFrame)` | Checks `CallFrameFlags.Scope` flag |
| `IsGlobalScope(ICallFrame)` | Checks `CallFrameFlags.GlobalScope` flag |
| `MarkGlobalScope(ICallFrame, ref Result)` | Converts scope to global scope (changes flags) |
| `SetFast(ICallFrame, bool)` | Sets/clears `CallFrameFlags.Fast` |
| `NewEngineScope(Interpreter)` | Creates a scope with `Scope \| Engine` flags |
| `CloneToNewScope(...)` | Clones variables into a new scope (by value or by reference) |
| `CloneToExistingScope(...)` | Merges variables into an existing scope |

### 11.2 Interpreter (Public/Internal)

| Method | Purpose |
|--------|---------|
| `HasScopes(ref Result)` | Checks if any scopes exist |
| `GetScope(name, flags, ...)` | Retrieves a named scope |
| `AddScope(frame, clientData, ...)` | Registers a new scope (enforces scope limit) |
| `RemoveScope(name, clientData, ...)` | Unregisters and cleans up a scope |
| `LockScope(name, ...)` | Acquires lock on a scope's frame |
| `UnlockScope(name, ...)` | Releases lock on a scope's frame |
| `PushCallFrame(frame, automatic)` | Pushes any call frame onto the stack |
| `PopScopeCallFrames()` | Pops all scope frames from the top of the stack |
| `PopScopeCallFramesAndOneMore()` | Pops scope frames plus one more (procedure return) |
| `GetScopeCallFrame(name, ..., pop, remove, ...)` | Gets scope frame with optional pop/remove |
| `NewScopeCallFrame(name, flags, vars, args)` | Creates a new scope call frame |
| `SetGlobalScopeCallFrame(name, ...)` | Sets a scope as the global scope |
| `UnsetGlobalScopeCallFrame(strict, ...)` | Restores normal global frame |
| `EvaluateScriptWithScopeFrame(text, ...)` | Evaluates script in a scope context |
| `ScopeLimit { get; set; }` | Maximum number of scopes (50 in safe mode) |
| `GlobalScopeFrame { get; set; }` | Current global scope frame |
| `CopyProcedureArgumentsToFrame(...)` | Copies procedure args into a frame (for `-args`) |

### 11.3 NamespaceOps (Private)

| Method | Purpose |
|--------|---------|
| `AttachScope(interp, ns, frame, ...)` | Shares scope variables with a namespace |
| `DetachScope(interp, ns, frame, ...)` | Reverses attach, restores variables to scope |
| `ExportScope(interp, ns, frame, system, ...)` | Moves variables from scope to namespace |
| `ImportScope(interp, ns, frame, system, ...)` | Moves variables from namespace to scope |

All four namespace operations:
- Require the interpreter lock to be held.
- Create defensive copies before iterating to avoid modification during
  traversal.
- Filter out read-only, invariant, and (optionally) system variables.
- Return lists of affected variable names for feedback.

## 12. Practical Patterns

### 12.1 The Idempotent Counter

The canonical scope pattern — a procedure that maintains state across calls:

```tcl
proc counter {name} {
  scope create -open -clone -args $name
  if {![info exists count]} {set count 0}
  incr count
  return $count
  # scope close implied on return
}

counter myCounter  ;# 1
counter myCounter  ;# 2
counter myCounter  ;# 3
scope destroy myCounter
```

**Why it works:** The first call creates the scope and clones the current
frame (which has no `count`). The `if` initializes `count` to 0, then `incr`
makes it 1. On subsequent calls, `scope create` is idempotent (returns the
existing scope), `-open` pushes it, and `count` is already there from last
time.

### 12.2 Per-Procedure Private State

Using `-procedure` for automatic scope naming:

```tcl
proc accumulate {value} {
  scope create -open -procedure -args
  if {![info exists total]} {set total 0}
  incr total $value
  return $total
}

accumulate 10   ;# 10
accumulate 20   ;# 30
accumulate 5    ;# 35
```

Each procedure gets its own scope without needing to manage names manually.

### 12.3 Scoped Configuration

Using `scope eval` to configure and query a scope without leaving it open:

```tcl
scope create config
scope eval config {
  set database "production"
  set timeout 30000
  set retries 3
}

# Later, query without opening:
set db [scope set config database]   ;# "production"
scope set config timeout 60000       ;# update a value
scope destroy config
```

### 12.4 Global Sandboxing

Isolating a script from the real global environment:

```tcl
scope create sandbox
scope global sandbox

# Everything below sees sandbox as "global"
source untrusted_script.tcl

# Restore and inspect
scope global -unset
scope vars sandbox  ;# see what the script defined
scope destroy sandbox
```

### 12.5 Thread-Safe Shared State

Using `scope eval -lock` for thread-safe access:

```tcl
scope create sharedState
scope eval sharedState {
  set connections 0
  set errors 0
}

# Called from multiple threads:
proc recordConnection {} {
  scope eval -lock sharedState {
    incr connections
  }
}

proc recordError {} {
  scope eval -lock sharedState {
    incr errors
  }
}
```

### 12.6 Scope with upvar for Persistent References

Combining scopes with `upvar` for persistent variable linkage:

```tcl
proc accumulator {scopeName varName} {
  set c 9
  scope create -open -clone -args $scopeName
  if {![info exists sum]} then {
    upvar 2 $varName sum
    set sum 0
  }
  incr sum $c
  return $sum
}

set total 0
accumulator myScope total  ;# total = 9
accumulator myScope total  ;# total = 18
accumulator myScope total  ;# total = 27
scope destroy myScope
```

## 13. Quick Reference: Decision Guide

| Scenario | Approach |
|----------|----------|
| Persistent counter across calls | `scope create -open -clone -args $name` |
| Per-procedure private state | `scope create -open -procedure -args` |
| Evaluate script in isolated context | `scope eval name { script }` |
| Thread-safe shared state | `scope eval -lock name { script }` |
| Read/write scope variable without opening | `scope set name var ?value?` |
| Redirect global frame | `scope global name` |
| Sandbox untrusted script | `scope create s; scope global s; source ...; scope global -unset` |
| Share variables with namespace | `scope attach name ns` |
| Move variables to namespace | `scope export name ns` |
| Snapshot current state | `scope create -clone name` |
| Live reference to original vars | `scope create -clone -byref name` (unsafe) |
| Check if scope exists | `scope exists name` |
| List all scopes | `scope list ?pattern?` |
| Clean up | `scope destroy name` |

## 14. Error Handling and Safety

### 14.1 Automatic Cleanup

Scopes are automatically closed (popped from the call stack) when a procedure
returns, whether normally or via error. This prevents scope leaks:

```tcl
proc mayFail {scopeName} {
  scope create -open -clone $scopeName
  error "something went wrong"
  # scope close still implied — scope remains intact
}
catch {mayFail testScope}
scope exists testScope  ;# True — scope survives the error
scope destroy testScope
```

### 14.2 Scope Limit

The interpreter enforces a maximum number of scopes:
- **Safe interpreters**: 50 scopes maximum.
- **Unsafe interpreters**: Unlimited (configurable via `ScopeLimit` property).

Exceeding the limit causes `scope create` to return an error.

### 14.3 Impact on `[info level]`

Each `scope open` increases `[info level]` by 1. Code that uses `[info level]`
to compute `upvar`/`uplevel` depths must account for scope frames:

```tcl
info level                ;# 0
scope create -open foo
info level                ;# 1
scope open foo
info level                ;# 2
scope close
info level                ;# 1
scope close
info level                ;# 0
scope destroy foo
```

## 15. References

### Eagle Source Files
- `Library/Commands/Scope.cs` — Main command implementation (19 sub-commands)
- `Library/Components/Private/CallFrameOps.cs` — Scope creation, cloning, naming
- `Library/Components/Private/NamespaceOps.cs` — Scope–namespace integration
- `Library/Components/Public/Interpreter.cs` — Scope storage and call stack management
- `Library/Components/Public/Enumerations.cs` — `CallFrameFlags` enum

### Eagle Documentation
- [`core_language.md`](core_language.md#cmd-scope) — `scope` command syntax and options reference
- [`core_examples.md`](core_examples.md#ex-scope) — `scope` usage examples
- [`tips_and_tricks.md`](tips_and_tricks.md#persistent-state-with-scope) — Scope tips and patterns
