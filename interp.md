# Eagle `[interp]` Command: Deep-Dive Analysis of Interpreter Management and Security

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `interp` command internals, with particular emphasis on the security model. For basic command syntax and options, see [`core_language.md`](core_language.md#cmd-interp). For usage examples, see [`core_examples.md`](core_examples.md#ex-interp). For the policy subsystem architecture, see the [Security Policy Subsystem](core_language.md#security-policy-subsystem) section. For safe interpreter script library helpers, see [`core_script_library.md`](core_script_library.md).

## 1. Executive Summary

Eagle's `[interp]` command provides **complete interpreter lifecycle
management** — creating, configuring, securing, and destroying child
interpreters from script code. With 60 sub-commands, it is the largest
ensemble command in Eagle, covering interpreter hierarchy management,
cross-interpreter communication, hidden command administration, security
policy configuration, resource limit enforcement, execution timeout
control, and object sharing.

The command's most important role is as Eagle's **primary security
mechanism**. Safe interpreters — created via `interp create -safe` or
converted via `interp makesafe` — form sandboxed execution environments
where untrusted code can run with controlled access to system resources.
The security model is built on three interlocking mechanisms:

1. **Command hiding**: Unsafe commands are moved to a hidden command
   table, inaccessible to scripts running in the safe interpreter.
2. **Policy-based access control**: A deny-by-default policy system
   intercepts command execution, sub-command dispatch, file access,
   and type instantiation, applying configurable security rules.
3. **Resource limits**: Hard caps on recursion depth, loop iterations,
   procedure count, variable count, and other resources prevent
   denial-of-service attacks.

This goes significantly beyond native Tcl's safe interpreter model.
Tcl provides command hiding and aliases but has no policy callback
system, no resource limits, and no .NET type access control. Eagle's
model is closer to a capability-based security system where each
operation must be explicitly authorized.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Interp.cs` | 4,452 | Main command implementation (60 sub-commands) |
| `Eagle/Library/Components/Public/Interpreter.cs` | 124,863 | Interpreter class: state, safety checks, lifecycle |
| `Eagle/Library/Components/Private/PolicyOps.cs` | 2,374 | Policy decision logic, allowed sub-command lists |
| `Eagle/Library/Components/Public/InterpreterHelper.cs` | 524 | Factory methods for interpreter creation |
| `Eagle/Library/Components/Public/InterpreterSettings.cs` | 2,332 | Interpreter configuration and initialization flags |
| `Eagle/Library/Components/Private/EntityOps.cs` | 3,102 | Command/alias hide, expose, and management |
| `Eagle/Library/Components/Private/RuntimeOps.cs` | 10,304 | Interpreter creation, plugin entity population |
| `Eagle/Library/Components/Private/ScriptOps.cs` | 10,805 | Script evaluation, sub-command dispatch |
| `Eagle/Library/Components/Public/Enumerations.cs` | 14,107 | CommandFlags, CreateFlags, InterpreterFlags, etc. |

## 2. Why the Interp Command Exists

### The problem

Any scripting language that evaluates code from external sources faces a
fundamental tension: the language must be powerful enough to be useful,
yet restricted enough to be safe. Without interpreter management, every
script runs with the full privileges of the host process.

### Eagle's approach

Eagle solves this with **child interpreters** — fully independent
execution environments that can be created, configured, and destroyed
from the parent interpreter. Each child has its own:

- Command table (which commands are available)
- Variable table (isolated state)
- Hidden command table (commands accessible only via `invokehidden`)
- Policy collection (security rules)
- Resource limits (caps on recursion, iterations, etc.)
- Timeout configuration (execution time limits)

The parent interpreter retains full control: it can evaluate code in
the child, set/get variables, install policies, adjust limits, and
destroy the child at any time. The child cannot affect the parent
except through explicitly created aliases.

### Comparison to native Tcl

Native Tcl's `interp` command provides a subset of this functionality:

| Feature | Tcl | Eagle |
|---------|-----|-------|
| Child interpreter creation | Yes | Yes |
| `-safe` flag | Yes | Yes |
| Command hiding/exposing | Yes | Yes |
| Cross-interpreter aliases | Yes | Yes |
| Cross-interpreter eval | Yes | Yes |
| Policy callbacks | **No** | **Yes** (deny-by-default, voting) |
| Resource limits | Time limit only | **12 distinct limits** |
| .NET type access control | N/A | **Yes** (trusted type lists) |
| Execution timeouts | **No** | **Yes** (timeout, finallytimeout) |
| Watchdog timers | **No** | **Yes** |
| AppDomain isolation | N/A | **Yes** (`-isolated`) |
| SDK/restricted modes | **No** | **Yes** (`-sdk`, `issdk`) |
| Immutable/readonly modes | **No** | **Yes** |
| Object sharing | **No** | **Yes** (`shareobject`, `shareinterp`) |
| Script cancellation | Limited (`interp cancel`) | **Enhanced** (`cancel`, `resetcancel`, flags) |
| `makesafe` (runtime conversion) | **No** | **Yes** |
| `makestandard` | **No** | **Yes** |
| `marktrusted` | **No** | **Yes** |
| Background error handler | Yes | Yes |
| Event servicing | **No** | **Yes** (`service`) |

## 3. The Security Model in Depth

### 3.1. Three layers of defense

Eagle's safe interpreter security operates through three complementary
layers, each providing defense-in-depth:

```
┌──────────────────────────────────────────────────────┐
│           Layer 1: Command Hiding                    │
│                                                      │
│  Unsafe commands moved to hidden table.              │
│  Scripts in safe interp cannot see or call them.     │
│  Parent can invoke via [interp invokehidden].        │
├──────────────────────────────────────────────────────┤
│           Layer 2: Policy-Based Access Control       │
│                                                      │
│  Commands that remain exposed (file, info, object,   │
│  interp, etc.) are restricted by policy callbacks.   │
│  Each invocation checked against allowed sub-command │
│  lists, trusted types, trusted URIs, trusted dirs.   │
│  Deny-by-default: no policy vote = denied.           │
├──────────────────────────────────────────────────────┤
│           Layer 3: Resource Limits                   │
│                                                      │
│  Hard caps on recursion, iterations, procedures,     │
│  variables, namespaces, scopes, results, callbacks,  │
│  events, exec operations, ready ops, child interps.  │
│  Prevents resource exhaustion / denial-of-service.   │
└──────────────────────────────────────────────────────┘
```

### 3.2. Command hiding

When a safe interpreter is created, commands flagged with
`CommandFlags.Unsafe` are automatically moved from the exposed command
table to the hidden command table. This means:

- Scripts running in the safe interpreter cannot see or call hidden
  commands (they appear to not exist).
- The parent interpreter can invoke hidden commands in the child via
  `interp invokehidden`, bypassing the restriction.
- Commands can be manually hidden (`interp hide`) or exposed
  (`interp expose`) by the parent — but **not** by a safe interpreter
  itself.

**Security invariant**: A safe interpreter cannot hide or expose
commands. The source code enforces this with explicit checks:

```csharp
// From Interp.cs, "expose" sub-command (line 1520):
if (!interpreter.InternalIsSafe())
{
    code = childInterpreter.ExposeCommand(arguments[3], ref result);
}
else
{
    result = "permission denied: safe interpreter cannot expose commands";
    code = ReturnCode.Error;
}
```

The same pattern appears in `hide`, `addcommands`, `stub`,
`subcommand`, `makesafe`, `makestandard`, `marktrusted`, `nopolicy`,
`policy`, `shareobject`, and `shareinterp`.

### 3.3. Policy-based access control

Commands that remain exposed in safe interpreters (like `file`, `info`,
`object`, `interp`, `package`, `source`) are not unrestricted — they
are guarded by **policy callbacks** that filter which sub-commands and
operations are permitted.

When `interp create -safe` or `interp makesafe` is called, eight
default policy callbacks are installed:

| Command | Strategy | Allowed/Denied |
|---------|----------|----------------|
| `clock` | Allow list | `buildnumber`, `days`, `duration`, `filetime`, `format`, `isvalid`, `monthdays`, `scan`, `seconds` |
| `file` | Allow list | `channels`, `dirname`, `join`, `split`, `validname` |
| `info` | Allow list | `appdomain`, `args`, `body`, `commands`, `complete`, `context`, `default`, `engine`, `ensembles`, `exists`, `functions`, `globals`, `level`, `library`, `locals`, `nprocs`, `objects`, `operands`, `operators`, `patchlevel`, `procs`, `script`, `subcommands`, `tclversion`, `vars` |
| `interp` | Allow list | `alias`, `aliases`, `cancel`, `children`, `exists`, `issafe`, `issdk`, `rename` |
| `object` | Allow list | `dispose`, `exists`, `invoke`, `invokeall`, `invokeraw`, `isnull`, `isoftype` |
| `package` | Deny list | Disallowed sub-commands: `alias`, `aliases`, `indexes`, `relativefilename`, `reset`, `scan`, `vloaded` |
| `source` | URI/directory validation | Only trusted URIs and directories |
| `uri` | Allow list | `get`, `isvalid`, `post` |

**Key design principle: Deny by default.** If no policy votes to
approve an operation, it is denied. This means any new command or
sub-command added to the interpreter is automatically restricted until
explicitly allowed by a policy.

**Deny veto**: A single `Denied` vote overrides any number of
`Approved` votes. This ensures that a restrictive policy cannot be
overridden by a permissive one.

### 3.4. The `interp` sub-commands allowed in safe interpreters

Of the 60 total sub-commands, only **8** are permitted in safe
interpreters via the default policy:

| Sub-command | Why it's safe |
|-------------|---------------|
| `alias` | Can query aliases but cannot create cross-interpreter aliases that escape the sandbox |
| `aliases` | Lists aliases (read-only introspection) |
| `cancel` | Can cancel child interpreters (defensive — prevents runaway children) |
| `children` | Lists children (read-only introspection) |
| `exists` | Checks interpreter existence (read-only) |
| `issafe` | Queries safety status (read-only) |
| `issdk` | Queries SDK status (read-only) |
| `rename` | Can rename commands within the safe interpreter |

The remaining 52 sub-commands are **denied** in safe interpreters,
including all commands that could modify the security posture:
`create`, `delete`, `eval`, `expose`, `hide`, `invokehidden`,
`makesafe`, `makestandard`, `marktrusted`, `policy`, `nopolicy`,
`addcommands`, `stub`, `subcommand`, `shareobject`, `shareinterp`,
and all limit/timeout sub-commands.

### 3.5. Resource limits

Safe interpreters can have hard resource limits imposed to prevent
denial-of-service attacks:

| Sub-command | What it limits | Default |
|-------------|---------------|---------|
| `recursionlimit` | Maximum call stack depth | Interpreter default |
| `iterationlimit` | Maximum loop iterations (for, while, foreach) | 0 (unlimited) |
| `proclimit` | Maximum number of procedures | 0 (unlimited) |
| `varlimit` | Maximum variables and array elements | 0 (unlimited) |
| `namespacelimit` | Maximum namespaces | 0 (unlimited) |
| `scopelimit` | Maximum scopes | 0 (unlimited) |
| `resultlimit` | Maximum result size (bytes) | 0 (unlimited) |
| `callbacklimit` | Maximum callbacks in queue | 0 (unlimited) |
| `eventlimit` | Maximum events in queue | 0 (unlimited) |
| `execlimit` | Maximum operation/command/unknown counts | 0 (unlimited) |
| `readylimit` | Maximum ready operations | 0 (unlimited) |
| `childlimit` | Maximum child interpreters | 0 (unlimited) |

A limit of 0 means unlimited. The parent should set appropriate limits
based on the use case.

### 3.6. Execution timeout and watchdog

Two complementary mechanisms prevent long-running or infinite
computations:

**Timeouts:**
- `interp timeout path ms` — Sets the execution timeout in milliseconds.
  After this duration, the interpreter's evaluation is canceled.
- `interp finallytimeout path ms` — Sets a separate timeout for
  `finally` blocks, ensuring cleanup code doesn't run indefinitely.
- `interp sleeptime path ms` — Controls the polling interval between
  timeout checks.

**Watchdog:**
- `interp watchdog path true` — Starts a background thread that
  monitors the interpreter and cancels it if the timeout is exceeded.
  This provides enforcement even when the interpreter is blocked in
  native code.

**Cancellation:**
- `interp cancel ?-unwind? path ?result?` — Cancels script execution
  in the target interpreter. With `-unwind`, the entire call stack is
  unwound. With `-global`, the cancellation applies globally (not just
  locally). With `-nolocal`, only the global cancellation is set.
- `interp resetcancel path` — Resets the cancellation flag after it
  has been handled.

## 4. Interpreter Lifecycle

### 4.1. Creation (`interp create`)

Creating a child interpreter is the most complex sub-command, with
20+ options controlling every aspect of initialization:

```tcl
set child [interp create -safe -namespaces -- myChild]
```

**What happens internally:**

1. Parses options (see table below).
2. Extracts creation flags from the parent interpreter via
   `ScriptOps.ExtractInterpreterCreationFlags`.
3. Modifies flags based on options (`-safe`, `-standard`, `-sdk`, etc.).
4. If `-safe`, sets `CreateFlags.SafeAndHideUnsafe` — which creates
   the interpreter with all commands, then hides unsafe ones.
5. Calls `interpreter.CreateInterpreter(...)` which:
   a. Creates a new `Interpreter` instance.
   b. Populates commands, functions, and variables.
   c. If safe: hides unsafe commands and initializes `safe.eagle`
      instead of `init.eagle`.
   d. If `-safe` without `-nohidden`: unsafe commands go to hidden
      table (available via `invokehidden`).
   e. If `-safe` with `-nohidden`: unsafe commands are simply not
      loaded (no hidden table entry).
   f. Installs default policies if safe.
   g. Registers the child with the parent's child interpreter
      collection.
6. Returns the interpreter path/name.

**Creation options:**

| Option | Flags | Purpose |
|--------|-------|---------|
| `-safe` | Standard | Create a safe (sandboxed) interpreter |
| `-standard` | Unsafe | Create a standard-mode interpreter |
| `-namespaces` | Standard | Enable namespace support |
| `-nonamespaces` | Standard | Disable namespace support |
| `-nocommands` | Standard | Don't load any commands |
| `-nofunctions` | Standard | Don't load math functions |
| `-novariables` | Standard | Don't set built-in variables |
| `-noloader` | Standard | Don't load the binary plugin loader |
| `-noinitialize` | Standard | Don't initialize the script library |
| `-nohidden` | Unsafe | Don't create hidden commands (with `-safe`) |
| `-alias` | Standard | Create a command alias for the child |
| `-sdk sdkType` | Unsafe | Enable SDK restrictions |
| `-isolated` | Unsafe | Create in a separate AppDomain |
| `-debug` | Unsafe | Enable script debugger |
| `-test` | Unsafe | Enable test plugin |
| `-monitor` | Unsafe | Enable trace/notification plugin |
| `-probing` / `-noprobing` | Unsafe | Plugin probing control |
| `-security` / `-nosecurity` | Unsafe | Security context control |
| `-nocorepolicies` | Unsafe | Skip installing default core policies |
| `-nopluginpolicies` | Unsafe | Skip plugin policies |
| `-unsafeinitialize` | Unsafe | Use full init instead of safe init |
| `-peer peerType` | Unsafe | Peer interpreter type |
| `-creationflagtypes` | Unsafe | Flag extraction control |
| `-ruleset ruleSet` | Standard | Rule set for command filtering |

**Safety enforcement**: If the parent interpreter is safe, child
interpreters are always created safe — the `-safe` flag is inherited
and cannot be overridden.

### 4.2. Deletion (`interp delete`)

```tcl
interp delete myChild otherChild
```

Accepts multiple paths and deletes each child interpreter. Deletion:
- Disposes of the child interpreter and all its resources.
- Removes the child from the parent's child collection.
- Cascading: if the child has its own children, they are also deleted.

### 4.3. Runtime conversion (`interp makesafe`)

An existing unsafe interpreter can be converted to safe mode at runtime:

```tcl
interp makesafe $child
```

**What happens internally:**

1. Verifies the parent is not itself safe (only unsafe interpreters
   can modify safety).
2. Calls `childInterpreter.InternalMakeSafe(makeFlags, safe)` which:
   a. Hides all commands flagged `CommandFlags.Unsafe`.
   b. Clears `InterpreterFlags.UnsafeMask` flags.
   c. Sets `CreateFlags.Safe` on the interpreter.
   d. Installs default policy callbacks.
   e. Optionally runs the `safe.eagle` initialization script.

The reverse (making a safe interpreter unsafe) is also possible via
`interp makesafe $child false`, but only from an unsafe parent.

The `interp makestandard` sub-command performs a similar conversion
for "standard" mode, which hides non-standard (Eagle-specific) commands
while leaving standard Tcl-compatible commands exposed.

### 4.4. Marking trusted (`interp marktrusted`)

```tcl
interp marktrusted $child
```

Marks an interpreter as trusted, allowing it to bypass certain policy
checks. This is used when a safe interpreter needs temporary elevated
privileges — for example, during initialization when trusted scripts
need to run. Only an unsafe parent can mark a child as trusted.

## 5. Cross-Interpreter Communication

### 5.1. Evaluation (`interp eval`, `interp expr`, `interp subst`)

```tcl
interp eval $child {set x [expr {2 + 2}]}
set result [interp expr $child {$x * 3}]
set text [interp subst $child {The value is $x}]
```

These sub-commands evaluate scripts, expressions, and substitutions
in the context of the child interpreter. Internally:

1. The child interpreter is looked up via `GetNestedChildInterpreter`.
2. A tracking call frame is pushed (with `CallFrameFlags.Restricted`).
3. The script is evaluated in the child's execution context.
4. Error information is copied from child to parent if an error occurs.
5. The call frame is popped (including any leftover scope frames).

**Security note**: `interp eval` in a safe child is subject to all
of the child's policies. The parent is not granting additional
privileges — the code runs with the child's restrictions.

### 5.2. Aliases (`interp alias`)

Aliases create cross-interpreter command bridges:

```tcl
# Create: when child calls "safeLog", parent's "puts" runs
interp alias $child safeLog {} puts

# Query: what does "safeLog" map to?
interp alias $child safeLog

# Delete: remove the alias (empty target)
interp alias $child safeLog {} {}
```

An alias in the source (child) interpreter creates a command that,
when invoked, executes the target command in the target (parent)
interpreter. Additional arguments can be prepended:

```tcl
# "safeWrite" in child calls "puts -nonewline" in parent
interp alias $child safeWrite {} puts -nonewline
```

**Security implications**: Aliases are the **controlled channel**
through which a safe interpreter gains access to functionality it
wouldn't otherwise have. The parent deliberately creates each alias,
controlling exactly what operations the child can perform. This is the
recommended pattern for granting specific capabilities to safe
interpreters.

### 5.3. Variable access (`interp set`, `interp unset`)

```tcl
interp set $child varName value
set val [interp set $child varName]
interp unset $child varName
```

Direct variable access across interpreter boundaries. No policy
check is performed — the parent has full access to the child's
variable table.

### 5.4. Script queuing (`interp queue`)

```tcl
interp queue $child -when [clock seconds] {puts "deferred"}
```

Queues a script for later evaluation in the child interpreter's
event loop, optionally with a scheduled time.

### 5.5. Object sharing (`interp shareobject`, `interp shareinterp`)

```tcl
set obj [object create System.Text.StringBuilder]
interp shareobject $child $obj
```

Shares a .NET opaque object handle from the parent to the child
interpreter. The object is added to the child's object table
(verbatim, preserving the handle name). Only unsafe parents can share
objects.

```tcl
interp shareinterp $child $interpObj
```

Shares an interpreter object itself, marking it as shared (which
prevents it from being disposed when the child is deleted). Only
unsafe parents can share interpreters.

**Security note**: Shared objects are added to the child's object
table but their `ObjectFlags` are **not** automatically changed. The
parent must manually adjust flags if the object should be usable in
the safe interpreter. This prevents accidental privilege escalation
through shared objects.

## 6. Hidden Commands

### 6.1. The dual command table

Every Eagle interpreter maintains two command tables:

```
┌────────────────────────────┐
│        Interpreter         │
│                            │
│  ┌──────────────────────┐  │
│  │  Exposed Commands    │  │ Scripts can see and call
│  │  (normal command     │  │ these commands.
│  │   table)             │  │
│  └──────────────────────┘  │
│                            │
│  ┌──────────────────────┐  │
│  │  Hidden Commands     │  │ Only accessible via
│  │  (hidden command     │  │ [interp invokehidden]
│  │   table)             │  │ from the parent.
│  └──────────────────────┘  │
└────────────────────────────┘
```

### 6.2. Hiding and exposing

```tcl
# Move "puts" from exposed to hidden in child
interp hide $child puts

# Move "puts" back from hidden to exposed
interp expose $child puts

# List hidden commands
interp hidden $child

# List exposed commands
interp exposed $child
```

Only an unsafe parent can hide or expose commands. A safe interpreter
cannot modify its own command visibility — this is a critical security
invariant.

### 6.3. Invoking hidden commands (`interp invokehidden`)

```tcl
interp invokehidden $child source trusted_script.eagle
interp invokehidden $child -global exec ls
interp invokehidden $child -namespace ::myns someCmd arg1
```

This is how the parent (or host application) performs privileged
operations in a safe interpreter. The hidden command executes within
the child's context but bypasses the normal command lookup that would
fail to find it.

**Options:**
- `-global` — Execute in the child's global scope
- `-namespace ::name` — Execute in a specific namespace

Internally, `invokehidden` uses `EngineFlags.UseHidden` to resolve
the command from the hidden command table, then calls
`childInterpreter.ExecuteHidden(...)` with `BeginExternalExecution`
/ `EndAndCleanupExternalExecution` to properly manage engine flags.

## 7. All Sub-Commands Reference

### Interpreter lifecycle

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `create` | `interp create ?options? ?path?` | Create a child interpreter |
| `delete` | `interp delete ?path ...?` | Delete child interpreter(s) |
| `exists` | `interp exists ?path?` | Check if interpreter exists |
| `children` | `interp children ?path?` | List child interpreters |
| `parent` | `interp parent ?path?` | Get parent interpreter path |

### Cross-interpreter evaluation

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `eval` | `interp eval path arg ?arg ...?` | Evaluate script in child |
| `expr` | `interp expr path arg ?arg ...?` | Evaluate expression in child |
| `subst` | `interp subst ?options? path string` | Perform substitution in child |
| `source` | `interp source ?options? path fileName` | Source file in child |
| `queue` | `interp queue path ?options? arg ?arg ...?` | Queue script for later evaluation |

### Variable access

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `set` | `interp set interp varName ?newValue?` | Get or set variable in child |
| `unset` | `interp unset interp varName` | Unset variable in child |

### Command aliases

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `alias` | `interp alias childPath childCmd ?parentPath parentCmd? ?arg ...?` | Create/query/delete alias |
| `aliases` | `interp aliases ?path? ?pattern? ?all?` | List aliases |
| `target` | `interp target path alias` | Get alias target interpreter |

### Hidden command management

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `hide` | `interp hide path cmdName ?hiddenCmdName?` | Hide a command |
| `expose` | `interp expose path hiddenCmdName ?cmdName?` | Expose a hidden command |
| `hidden` | `interp hidden path` | List hidden commands |
| `exposed` | `interp exposed path` | List exposed commands |
| `invokehidden` | `interp invokehidden path ?options? cmd ?arg ..?` | Invoke a hidden command |

### Security configuration

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `issafe` | `interp issafe ?path?` | Query safe status |
| `makesafe` | `interp makesafe ?path? ?safe? ?flags?` | Convert to/from safe mode |
| `isstandard` | `interp isstandard ?path?` | Query standard status |
| `makestandard` | `interp makestandard ?path? ?standard? ?flags?` | Convert to/from standard mode |
| `marktrusted` | `interp marktrusted path` | Mark as trusted (bypass policies) |
| `policy` | `interp policy ?options? path script` | Install a policy script |
| `nopolicy` | `interp nopolicy path name` | Remove a policy |
| `issdk` | `interp issdk ?path? ?sdkType?` | Query SDK restriction status |
| `isolated` | `interp isolated ?path?` | Query AppDomain isolation |
| `immutable` | `interp immutable ?path? ?immutable?` | Get/set immutability |
| `readonly` | `interp readonly ?path? ?readonly?` | Get/set read-only mode |
| `enabled` | `interp enabled ?path? ?enabled?` | Enable/disable interpreter |

### Resource limits

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `recursionlimit` | `interp recursionlimit path ?limit?` | Max call stack depth |
| `iterationlimit` | `interp iterationlimit path ?limit?` | Max loop iterations |
| `proclimit` | `interp proclimit path ?limit?` | Max procedures |
| `varlimit` | `interp varlimit path ?limit?` | Max variables / array elements |
| `namespacelimit` | `interp namespacelimit path ?limit?` | Max namespaces |
| `scopelimit` | `interp scopelimit path ?limit?` | Max scopes |
| `resultlimit` | `interp resultlimit path ?limit?` | Max result size |
| `callbacklimit` | `interp callbacklimit path ?limit?` | Max callbacks |
| `eventlimit` | `interp eventlimit path ?limit?` | Max events |
| `execlimit` | `interp execlimit path ?limit?` | Max operations/commands/unknowns |
| `readylimit` | `interp readylimit path ?limit?` | Max ready operations |
| `childlimit` | `interp childlimit path ?limit?` | Max child interpreters |

### Timeout and execution control

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `timeout` | `interp timeout ?path? ?newValue?` | Get/set execution timeout (ms) |
| `finallytimeout` | `interp finallytimeout ?path? ?newValue?` | Get/set finally-block timeout |
| `sleeptime` | `interp sleeptime ?path? ?newValue?` | Get/set timeout check interval |
| `cancel` | `interp cancel ?options? ?path? ?result?` | Cancel script execution |
| `resetcancel` | `interp resetcancel path ?options?` | Reset cancellation flag |
| `watchdog` | `interp watchdog ?path? ?enabled? ?flags? ?type?` | Configure watchdog timer |

### Command management

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `addcommands` | `interp addcommands ?options? path pattern` | Add commands to child |
| `rename` | `interp rename ?options? path oldName newName` | Rename a command |
| `stub` | `interp stub ?options? path name` | Create a stub command |
| `subcommand` | `interp subcommand ?options? path cmdName subCmdName ?command?` | Manage ensemble sub-commands |

### Object sharing

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `shareobject` | `interp shareobject interp objectName` | Share .NET object with child |
| `shareinterp` | `interp shareinterp interp objectName` | Share interpreter object |

### Script file operations

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `readorgetscriptfile` | `interp readorgetscriptfile ?options? path fileName` | Read/get script file |
| `maybereadorgetscriptfile` | `interp maybereadorgetscriptfile ?options? path fileName` | Conditionally read/get script file |

### Other

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `bgerror` | `interp bgerror path ?cmdPrefix?` | Get/set background error handler |
| `service` | `interp service path ?options?` | Event servicing operations |

## 8. Security Boundaries and Invariants

### What a safe interpreter CANNOT do

The following operations are **always denied** in a safe interpreter,
regardless of policies:

| Operation | Error message |
|-----------|--------------|
| Add commands | "permission denied: safe interpreter cannot add commands" |
| Expose hidden commands | "permission denied: safe interpreter cannot expose commands" |
| Hide commands | "permission denied: safe interpreter cannot hide commands" |
| Modify safety | "permission denied: safe interpreter cannot modify safety" |
| Modify standardization | "permission denied: safe interpreter cannot modify standardization" |
| Mark as trusted | "permission denied: safe interpreter cannot mark trusted" |
| Add policies | "permission denied: safe interpreter cannot add policy" |
| Remove policies | "permission denied: safe interpreter cannot remove policy" |
| Share objects | "permission denied: safe interpreter cannot share objects" |
| Share interpreters | "permission denied: safe interpreter cannot share interpreters" |
| Add stub commands | "permission denied: safe interpreter cannot add stub commands" |
| Manage sub-commands | "permission denied: safe interpreter cannot manage sub-commands" |

These checks are implemented as hard-coded `interpreter.InternalIsSafe()`
guards in the source code — they cannot be bypassed by policies.

### What a safe interpreter CAN do (by default)

Through the default policy allow lists:

- Query aliases, children, existence, safety, SDK status
- Rename commands within its own scope
- Cancel child interpreters
- Define and call procedures
- Perform math operations
- Manipulate strings, lists, dictionaries
- Use allowed `info`, `file`, `clock` sub-commands
- Use `.NET` objects (if shared and marked safe) via allowed `object` sub-commands
- Use allowed `package` sub-commands

### The `IPolicyEnsemble` mechanism

The `interp` command class implements `IPolicyEnsemble`, which provides
an `AllowedSubCommands` dictionary used by the policy system:

```csharp
// From Interp.cs, line 76-85:
private readonly EnsembleDictionary allowedSubCommands = new EnsembleDictionary(
    PolicyOps.AllowedInterpSubCommandNames);

public override EnsembleDictionary AllowedSubCommands
{
    get { return allowedSubCommands; }
}
```

The `InterpCommandCallback` policy (installed during `makesafe`) calls
`PolicyOps.CheckViaSubCommand` which compares the requested sub-command
against this allow list. If the sub-command is not in the list, the
policy votes `Denied`.

## 9. Practical Patterns

### Pattern 1: Safe sandbox for untrusted code

```tcl
# Create a safe interpreter with resource limits
set sandbox [interp create -safe]
interp recursionlimit $sandbox 50
interp iterationlimit $sandbox 10000
interp varlimit $sandbox 500
interp timeout $sandbox 5000
interp watchdog $sandbox true

# Provide controlled access via aliases
interp alias $sandbox safeLog {} puts
interp alias $sandbox safeTime {} clock seconds

# Evaluate untrusted code
if {[catch {
    interp eval $sandbox $untrustedCode
} err]} {
    puts "Sandbox error: $err"
}

# Cleanup
interp delete $sandbox
```

### Pattern 2: Plugin evaluation with policies

```tcl
set plugin [interp create -safe]

# Install a custom policy for type access
interp policy -type System.String -flags Script $plugin {
    # Allow String operations
    return -code ok
}

# Share a specific object
set builder [object create System.Text.StringBuilder]
interp shareobject $plugin $builder

interp eval $plugin $pluginScript
interp delete $plugin
```

### Pattern 3: Temporary privilege elevation

```tcl
set safe [interp create -safe]

# Initialize with trusted code using invokehidden
interp invokehidden $safe source trusted_init.eagle
interp invokehidden $safe -global set configVar "production"

# Now run untrusted code with the initialized state
interp eval $safe $userScript
interp delete $safe
```

### Pattern 4: Runtime conversion to safe mode

```tcl
# Create a normal interpreter and set it up
set child [interp create]
interp eval $child {
    # Full initialization with all commands available
    proc initialize {} {
        # Complex setup that needs unsafe commands...
    }
    initialize
}

# Now lock it down
interp makesafe $child
interp recursionlimit $child 100
interp timeout $child 10000
interp watchdog $child true

# From this point, only safe operations are allowed
interp eval $child $restrictedCode
```

### Pattern 5: Monitoring and cancellation

```tcl
set worker [interp create -safe]
interp timeout $worker 30000          ;# 30 second timeout
interp watchdog $worker true          ;# Enable watchdog

# Run long task
after 5000 [list interp cancel $worker "Time limit exceeded"]
set code [catch {interp eval $worker $longTask} result]

if {$code != 0} {
    # Check if it was canceled
    interp resetcancel $worker
    puts "Task canceled or errored: $result"
}

interp delete $worker
```

### Pattern 6: Hierarchical interpreters

```tcl
# Create a chain of interpreters
set level1 [interp create -safe]
interp eval $level1 {
    set level2 [interp create -safe]
    interp recursionlimit $level2 25
}

# Nested evaluation
interp eval $level1 {
    interp eval $level2 {
        puts "I'm two levels deep"  ;# Will fail — puts is hidden
    }
}

interp delete $level1  ;# Cascading: level2 is also deleted
```

## 10. Comparisons to Other Languages

### Python — `exec()` with restricted globals

Python provides no built-in sandboxing mechanism. The `exec()` function
can accept restricted `globals` and `locals` dictionaries, but this is
not a security boundary — it can be trivially escaped via attribute
access, `__import__`, etc. Python's `RestrictedPython` library provides
AST-level restrictions but is not part of the standard library.

Eagle's model is fundamentally stronger: the interpreter itself enforces
the restrictions at the command dispatch level.

### JavaScript — Web Workers / `vm` module

JavaScript's Web Workers provide process-level isolation but cannot
share objects. Node.js's `vm` module provides context isolation but is
explicitly documented as "not a security mechanism." Eagle's safe
interpreters provide stronger isolation with controlled communication
channels (aliases, shared objects).

### Java — `SecurityManager` (deprecated)

Java's `SecurityManager` provided fine-grained permission checks but
was deprecated in Java 17 due to complexity and maintenance burden.
Eagle's policy system serves a similar role but is simpler and more
composable (voting callbacks vs. permission hierarchies).

### Lua — Sandboxing via environment manipulation

Lua sandboxing is typically done by setting a restricted environment
table for `load()` or `setfenv()`. This is similar to Eagle's approach
but lacks Eagle's policy callbacks, resource limits, and .NET type
access control.

### Native Tcl — `interp create -safe`

The closest comparison. Tcl's safe interpreters provide command hiding
and aliases, but lack:
- Policy callbacks (deny-by-default voting system)
- 12 distinct resource limits
- .NET type access control
- Execution timeouts with watchdog
- Runtime `makesafe` conversion
- Object sharing
- `marktrusted` for temporary elevation
- SDK/standard/immutable/readonly modes

## 11. Security Considerations

### Threat model

Eagle's safe interpreter model defends against the following threats
from untrusted code:

| Threat | Defense |
|--------|---------|
| File system access | `exec`, `open`, `file` (most sub-commands) hidden; `source` policy-restricted |
| Network access | `socket` hidden; `uri` policy-restricted |
| Process execution | `exec` hidden |
| Native code execution | `library` hidden (NativeCode + Unsafe + Critical) |
| .NET type instantiation | `object create` restricted by trusted types |
| Interpreter escape | `interp` restricted to 8 safe sub-commands |
| Resource exhaustion | 12 resource limits + timeout + watchdog |
| Information disclosure | `info` restricted to safe sub-commands; `env` hidden |
| Policy manipulation | `interp policy`/`nopolicy` denied in safe mode |
| State modification | `immutable` and `readonly` modes |

### Known limitations

1. **The command is marked Unsafe.** The `[interp]` command itself is
   flagged `CommandFlags.Unsafe | CommandFlags.Standard | CommandFlags.Initialize`.
   The source code contains a TODO comment noting it should be made safe,
   with sub-command-level access control (which is partially implemented
   via the policy system).

2. **Shared objects may leak privileges.** Objects shared via
   `interp shareobject` retain their original `ObjectFlags`. The parent
   must manually adjust flags for the object to be usable-but-safe in
   the child.

3. **Policy callbacks can be complex.** Custom policies can inadvertently
   create security holes if they approve operations too broadly. The
   deny-by-default design mitigates this, but embedders must understand
   the voting model.

4. **Cross-interpreter alias targets run in the parent.** An alias
   target executes in the parent interpreter with the parent's
   privileges. Poorly designed aliases can create privilege escalation
   paths.

### Best practices

1. **Always set resource limits** on safe interpreters — unlimited
   resources allow denial-of-service.
2. **Always set a timeout** with a watchdog for untrusted code.
3. **Use aliases** as the only communication channel — don't share
   objects unless absolutely necessary.
4. **Validate alias arguments** — alias targets in the parent should
   validate all arguments from the child.
5. **Use `interp invokehidden`** for trusted initialization rather
   than temporarily exposing commands.
6. **Prefer `interp create -safe`** over `interp makesafe` — creating
   safe from the start is cleaner than converting.

## 12. The `interp create` Options In Depth

The `create` sub-command has the richest option surface in the entire
`[interp]` ensemble. Many options are flagged `OptionFlags.Unsafe`,
meaning they are invisible (and unavailable) when the parent interpreter
is itself safe.

### Options visible to safe interpreters

| Option | Purpose |
|--------|---------|
| `-safe` | Create a safe interpreter |
| `-namespaces` | Enable namespace support |
| `-nonamespaces` | Disable namespace support |
| `-nocommands` | Don't load commands |
| `-nofunctions` | Don't load math functions |
| `-novariables` | Don't set built-in variables |
| `-noloader` | Don't load binary plugin loader |
| `-noinitialize` | Don't initialize script library |
| `-alias` | Create command alias for child |
| `-ruleset ruleSet` | Command filtering rule set |

### Options visible only to unsafe interpreters

| Option | Purpose |
|--------|---------|
| `-standard` | Enable standard mode |
| `-nohidden` | Don't create hidden commands |
| `-unsafeinitialize` | Use full init (not safe init) |
| `-isolated` | Create in separate AppDomain |
| `-debug` | Enable script debugger |
| `-test` | Enable test plugin |
| `-monitor` | Enable notification/trace plugin |
| `-probing` / `-noprobing` | Plugin probing control |
| `-security` / `-nosecurity` | Security context control |
| `-nocorepolicies` | Skip default core policies |
| `-nopluginpolicies` | Skip plugin policies |
| `-sdk sdkType` | SDK restriction mode |
| `-peer peerType` | Peer interpreter type |
| `-creationflagtypes` | Flag extraction mode |

This dual-visibility design ensures that safe interpreters cannot
create children with elevated privileges.

## 13. Event Servicing (`interp service`)

The `service` sub-command processes events in a child interpreter's
event queue:

```tcl
interp service $child -limit 10 -priority Service
```

**Options:**

| Option | Purpose |
|--------|---------|
| `-dedicated` | Run on a dedicated worker thread |
| `-nocancel` | Don't check for cancellation |
| `-noglobalcancel` | Don't check global cancellation |
| `-erroronempty` | Error if no events to process |
| `-userinterface` | Process UI events |
| `-nocomplain` | Don't stop on errors |
| `-thread threadId` | Process events for specific thread |
| `-limit count` | Maximum events to process |
| `-eventflags flags` | Event filtering flags |
| `-priority priority` | Minimum event priority |

When `-dedicated` is specified, event servicing runs on a separate
thread via `Engine.QueueWorkItem`, allowing the parent to continue
executing while the child processes its events asynchronously.

## 14. References

| Resource | Description |
|----------|-------------|
| [`core_language.md#cmd-interp`](core_language.md#cmd-interp) | Command syntax and options reference |
| [`core_examples.md#ex-interp`](core_examples.md#ex-interp) | Usage examples |
| [Security Policy Subsystem](core_language.md#security-policy-subsystem) | Policy architecture, vote aggregation, default policies |
| [Built-in Virtual Scripts](core_language.md#built-in-virtual-scripts) | `safe.eagle`, `removeCommands`, `removeVariables` scripts |
| [`scope.md`](scope.md) | Scope command (persistent state management) |
| [`tcl.md`](tcl.md) | Tcl integration (uses child interpreters internally) |
| [Tcl `interp` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/interp.htm) | Native Tcl `interp` reference for comparison |
