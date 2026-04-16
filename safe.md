# Eagle Safe Interpreters: Secure Script Execution for Untrusted Code

> **For AI agents**: This document describes Eagle's safe interpreter
> security model. For the `[interp]` command reference, see
> [`core_language.md`](core_language.md#cmd-interp). For the deep-dive
> on interpreter management, see [`interp.md`](interp.md). For
> architectural patterns, see
> [`architecture_patterns.md`](architecture_patterns.md).

## Why Safe Interpreters?

Applications that embed a scripting language face a fundamental tension:
scripts need enough power to be useful, but untrusted scripts must not
be able to damage the host system, exfiltrate data, or consume unbounded
resources.

Eagle's safe interpreter system resolves this by providing a
**sandboxed execution environment** where untrusted scripts can run
with full access to the language's computational features (variables,
procedures, control flow, string manipulation, list operations,
expressions) while being completely cut off from dangerous operations
(file I/O, network access, process execution, .NET reflection, host
manipulation).

This is not a "best effort" sandbox. It is a **multi-layered security
architecture** with defense in depth: command hiding, option flag
enforcement, sub-command allow-lists, policy callbacks, resource limits,
and script signature verification. Each layer independently blocks
different attack vectors, so a flaw in any single layer does not
compromise the sandbox.

---

## Creating a Safe Interpreter

```tcl
# Create an isolated safe interpreter
set child [interp create -safe myChild]

# Evaluate untrusted code in the sandbox
interp eval myChild {
    # String operations work
    set greeting [string toupper "hello world"]

    # Math works
    set result [expr {2 ** 32}]

    # Procedures work
    proc fibonacci {n} {
        if {$n <= 1} {return $n}
        return [expr {[fibonacci [expr {$n-1}]] + [fibonacci [expr {$n-2}]]}]
    }

    fibonacci 10  ;# returns 55
}

# These would fail inside the safe interpreter:
# [exec rm -rf /]        → command not found (hidden)
# [file delete important] → command not found (hidden)
# [socket localhost 80]   → command not found (hidden)
# [object invoke System.IO.File Delete "important"] → command not found (hidden)
```

---

## What's Available in the Sandbox

<details>
<summary><strong>Safe Commands (available to untrusted code)</strong></summary>

The following command categories are fully available in safe
interpreters:

**Control flow**: `if`, `else`, `elseif`, `for`, `foreach`, `while`,
`switch`, `break`, `continue`, `return`, `catch`, `try`, `throw`,
`error`

**Variables**: `set`, `unset`, `append`, `lappend`, `incr`, `array`,
`global`, `variable`, `upvar`, `uplevel`

**Strings**: `string` (all sub-commands), `format`, `scan`, `regexp`,
`regsub`, `split`, `join`, `concat`, `subst`, `base64`

**Lists**: `list`, `lindex`, `llength`, `lrange`, `lreplace`,
`linsert`, `lsearch`, `lsort`, `lset`, `lmap`, `lassign`, `lget`,
`lremove`, `lreverse`

**Math**: `expr` (all operators and functions), `incr`

**Procedures**: `proc`, `nproc`, `apply`, `rename`

**I/O** (on shared channels only): `puts`, `gets`, `read`, `close`,
`fconfigure`, `fcopy`, `eof`, `fblocked`, `flush`

**Evaluation**: `eval`, `uplevel`, `subst`

**Dictionaries**: `dict` (all sub-commands)

**Other**: `after` (limited events), `vwait`, `update`, `namespace`,
`scope`, `hash`, `parse`, `encoding`

</details>

<details>
<summary><strong>Hidden Commands (blocked from untrusted code)</strong></summary>

These commands are hidden when a safe interpreter is created with
`-safe`. They exist in the interpreter but cannot be invoked from
script. The parent interpreter can selectively re-expose them via
policies.

**Filesystem**: `file` (most sub-commands), `cd`, `pwd`, `glob`,
`source`, `open`

**Process execution**: `exec`, `kill`

**Plugin/library loading**: `load`, `unload`, `library`

**Network**: `socket`, `uri`

**Host access**: `host` (all sub-commands)

**.NET interop**: `object` (most sub-commands), `debug`

**Interpreter management**: `interp` (most sub-commands)

**Timing**: `clock` (most sub-commands), `time`

**Information disclosure**: `info` (restricted sub-commands)

</details>

---

## Security Layers

Eagle's safe interpreter uses five independent security layers. An
attacker must bypass ALL of them to escape the sandbox.

<details>
<summary><strong>Layer 1: Command Hiding</strong></summary>

When a safe interpreter is created, every command without the
`CommandFlags.Safe` attribute is automatically hidden. Hidden commands
exist in a separate dictionary (`hiddenExecutes`) that is inaccessible
from script. The command resolver skips hidden commands entirely during
normal lookup.

This is an all-or-nothing mechanism: a command is either fully
available or completely invisible. There is no way for script code to
reference, invoke, or discover a hidden command by name.

```csharp
// During safe interpreter creation (Interpreter.cs)
if (!FlagOps.HasFlags(flags, CommandFlags.Safe, true) ||
    FlagOps.HasFlags(flags, CommandFlags.Unsafe, true))
{
    flags |= CommandFlags.Hidden;
    command.Flags = flags;
}
```

</details>

<details>
<summary><strong>Layer 2: Option Flag Enforcement</strong></summary>

Even for commands that ARE available in safe interpreters, individual
options can be restricted. Options marked with `OptionFlags.Unsafe` are
rejected at parse time when the interpreter is safe:

```
permission denied: safe interpreter cannot use option -timeout
```

This prevents safe interpreters from using dangerous options on
otherwise-safe commands. For example, the `[test2]` command is safe,
but its `-timeout`, `-debug`, and `-trace` options are unsafe.

</details>

<details>
<summary><strong>Layer 3: Sub-Command Allow-Lists</strong></summary>

Ensemble commands (commands with sub-commands) that are partially safe
use allow-lists to restrict which sub-commands are available. Each
ensemble has a pre-defined list of permitted sub-commands:

| Command | Allowed Sub-Commands |
|---------|---------------------|
| `[info]` | `appdomain`, `args`, `body`, `commands`, `complete`, `context`, `default`, `engine`, `ensembles`, `exists`, `functions`, `globals`, `level`, `library`, `locals`, `nprocs`, `objects`, `operands`, `operators`, `patchlevel`, `procs`, `script`, `subcommands`, `tclversion`, `vars` |
| `[interp]` | `alias`, `aliases`, `cancel`, `children`, `exists`, `issafe`, `issdk`, `rename` |
| `[file]` | `channels`, `dirname`, `join`, `split`, `validname` |
| `[object]` | `dispose`, `exists`, `invoke`, `invokeall`, `invokeraw`, `isnull`, `isoftype` |

Sub-commands not in the allow-list produce a "permission denied" error.
The lists are defined in `PolicyOps.cs` and enforced by policy
callbacks at runtime.

</details>

<details>
<summary><strong>Layer 4: Policy Callbacks</strong></summary>

Eagle's policy system provides fine-grained, programmatic access
control. Each restricted command has a policy callback that runs
BEFORE the command executes. The callback receives the command name,
arguments, and interpreter state, and returns an approval or denial
decision.

Eight default policy callbacks enforce the allow-lists:
- `ClockCommandCallback`
- `FileCommandCallback`
- `InfoCommandCallback`
- `InterpCommandCallback`
- `ObjectCommandCallback`
- `PackageCommandCallback`
- `SourceCommandCallback`
- `UriCommandCallback`

**Custom policies**: The parent interpreter can install custom policy
callbacks to implement domain-specific access control. For example, a
web application might allow safe interpreters to read from a specific
directory but block all other file access:

```tcl
# Parent installs a custom file policy
interp policy -type FileCommandCallback myChild {
    # Allow "file exists" on paths under /data/shared/
    # Deny everything else
}
```

Policies execute in the parent interpreter's context with full
privileges, so they can make security decisions based on information
the safe interpreter cannot access.

</details>

<details>
<summary><strong>Layer 5: Resource Limits</strong></summary>

Safe interpreters have hard limits on resource consumption, preventing
denial-of-service attacks:

| Resource | Safe Limit | Unsafe Limit |
|----------|-----------|-------------|
| Child interpreters | **Forbidden** | Unlimited |
| Scope depth | 50 | Unlimited |
| Pending events | 50 | Unlimited |
| Callbacks | 50 | Unlimited |
| Loop iterations | 1,000 | Unlimited |
| Namespaces | 50 | Unlimited |
| Procedures | 100 | Unlimited |
| Variables | 100 | Unlimited |
| Array elements | 100 | Unlimited |
| Operations | 200,000 | Unlimited |
| Command invocations | 100,000 | Unlimited |
| Unknown lookups | 1,000 | Unlimited |
| Dictionary nesting | 5 | Unlimited |
| Dictionary pairs | 100 | Unlimited |
| Result size | 1 MB | Unlimited |
| Nested result size | 1 MB | Unlimited |

When a limit is exceeded, the interpreter returns an error and halts
execution. This guarantees that untrusted scripts cannot consume
unbounded CPU time, memory, or stack depth.

</details>

---

## Cross-Interpreter Communication

Safe interpreters are isolated by default, but the parent can create
controlled communication channels.

<details>
<summary><strong>Aliases (Capability Delegation)</strong></summary>

The `interp alias` command creates a bridge between interpreters. An
alias in the safe child forwards to a command in the parent:

```tcl
# Parent creates a read-only file access alias
interp alias myChild safeReadFile {} readFileChecked

proc readFileChecked {path} {
    # Validate the path is within allowed directory
    if {![string match "/data/shared/*" $path]} {
        error "access denied: $path"
    }
    return [read [open $path r]]
}
```

The safe interpreter can now call `safeReadFile /data/shared/config.txt`
-- the command executes in the PARENT's context with the parent's
privileges, but only the specific capability the parent chose to expose.

This is the **capability delegation** model: the parent grants specific,
controlled capabilities rather than broad permissions.

</details>

<details>
<summary><strong>Shared Channels</strong></summary>

The parent can share I/O channels (files, network connections) with the
safe interpreter. The safe interpreter can read from and write to shared
channels using `[gets]`, `[puts]`, `[read]`, etc. -- but cannot open
new channels.

This allows safe interpreters to process data (read from stdin, write to
stdout) without being able to access the filesystem or network
directly.

</details>

---

## Beyond Safe Tcl: Eagle's Additional Protections

Eagle's safe interpreter model extends Tcl's Safe Tcl with several
capabilities not found in the Tcl implementation:

<details>
<summary><strong>Comprehensive Resource Limits</strong></summary>

Tcl's Safe Tcl has no built-in resource limits. A malicious script can
consume unlimited CPU time, memory, or stack depth. Eagle enforces 16
different resource limits with configurable thresholds, guaranteeing
that untrusted scripts terminate within bounded resource consumption.

</details>

<details>
<summary><strong>.NET Type Access Control</strong></summary>

Eagle's `.NET interop` (`[object invoke]`) is a powerful feature that
could trivially escape any sandbox if unrestricted. In safe
interpreters, the `[object]` command is hidden by default. When
selectively re-enabled via policies, type access is controlled through
`IsTrustedObject()` and `IsTrustedType()` checks that verify objects
have the `ObjectFlags.Safe` flag.

</details>

<details>
<summary><strong>Script Signature Verification</strong></summary>

Eagle supports cryptographic verification of script authenticity:

- **Authenticode signatures** (Windows): Scripts can be signed with
  X.509 certificates and verified via WinTrust APIs
- **Strong name verification**: .NET assemblies are verified via the
  CLR's strong name infrastructure
- **Hash-based verification**: Scripts can be verified against
  pre-computed SHA-256/SHA-512 hashes stored in trusted lists
- **Script bundles**: Signed SQLite databases containing scripts with
  per-script RSA signatures

This enables a trust model where only verified scripts from known
publishers can execute, even in non-safe interpreters.

</details>

<details>
<summary><strong>Enterprise Lockdown Mode</strong></summary>

For high-security deployments, Eagle can be compiled with
`ENTERPRISE_LOCKDOWN` enabled. This mode:

- Enforces script certificate requirements at all times
- Cannot be disabled at runtime (compiled into the binary)
- Blocks startup customization options that could weaken security
- Requires all evaluated scripts to pass certificate verification

This provides a hardware-like security boundary: the restriction is
in the compiled binary, not a runtime flag that could be toggled.

</details>

<details>
<summary><strong>Policy Callback System</strong></summary>

Tcl's Safe Tcl uses a fixed set of allowed/denied commands. Eagle's
policy system allows **programmatic, context-sensitive access
decisions** via callbacks. A policy can:

- Allow a command for specific arguments but deny it for others
- Check external authorization systems before approving access
- Log all access attempts for auditing
- Make decisions based on the calling context (stack depth, script
  source, etc.)

This enables domain-specific security models that go beyond simple
command whitelisting.

</details>

---

## Practical Use Cases

<details>
<summary><strong>Plugin Sandboxing</strong></summary>

Applications that support user-written plugins can evaluate plugin
scripts in a safe interpreter. The plugin gets access to a controlled
API surface (via aliases) without being able to access the filesystem,
network, or host application internals.

```tcl
set plugin [interp create -safe]

# Expose only the plugin API
interp alias $plugin registerHandler {} app::registerHandler
interp alias $plugin getConfig {} app::getPluginConfig
interp alias $plugin log {} app::pluginLog

# Evaluate untrusted plugin code
interp eval $plugin [readPluginScript $pluginPath]
```

</details>

<details>
<summary><strong>Configuration File Evaluation</strong></summary>

Instead of parsing a custom configuration format, evaluate
configuration files as Eagle scripts in a safe interpreter. The
configuration gets the full power of the scripting language
(conditionals, loops, string manipulation) without security risk.

```tcl
set config [interp create -safe]

# Expose only configuration setters
interp alias $config set-option {} app::setConfigOption
interp alias $config include {} app::includeConfig

# Evaluate configuration
interp eval $config [read [open $configFile r]]

# Extract results
set options [interp eval $config {array get options}]
```

</details>

<details>
<summary><strong>Test Isolation</strong></summary>

Run test scripts in safe interpreters to ensure tests cannot
accidentally modify the test harness, corrupt shared state, or
interfere with other tests.

</details>

<details>
<summary><strong>Multi-Tenant Script Execution</strong></summary>

Server applications that execute scripts on behalf of multiple users
can create a safe interpreter per user/request, with resource limits
preventing any single user from consuming excessive resources.

</details>

---

## Security Guarantees

A safe interpreter created with `interp create -safe` provides the
following guarantees:

1. **No filesystem access**: Cannot read, write, create, or delete
   files
2. **No network access**: Cannot open sockets or make HTTP requests
3. **No process execution**: Cannot spawn external processes
4. **No .NET reflection**: Cannot load assemblies, create objects, or
   invoke methods (unless explicitly permitted by policy)
5. **No host manipulation**: Cannot access the console, change colors,
   or modify the host environment
6. **No child interpreters**: Cannot create additional interpreters
7. **No information disclosure**: Cannot discover hidden commands,
   read system variables, or probe the host environment
8. **Bounded resource consumption**: Cannot exceed configured limits
   on CPU, memory, stack depth, or event count
9. **No timing attacks**: High-resolution timing commands are hidden
10. **No dynamic code loading**: Cannot source files, load plugins,
    or require packages with side effects

These guarantees hold even if the untrusted script is adversarial and
specifically crafted to escape the sandbox. The multi-layered security
architecture ensures that no single bypass defeats the entire system.

---

## References

- **Source code**: `Eagle/Library/Components/Public/Interpreter.cs` --
  safe interpreter creation, resource limits, command hiding
- **Source code**: `Eagle/Library/Components/Private/PolicyOps.cs` --
  policy callbacks, allow-lists, default policies
- **Source code**: `Eagle/lib/Eagle1.0/safe.eagle` -- safe interpreter
  initialization script
- **Related documentation**: [`interp.md`](interp.md) -- interpreter
  management deep-dive
- **Related documentation**: [`core_language.md`](core_language.md) --
  command reference
- **Related documentation**:
  [`architecture_patterns.md`](architecture_patterns.md) -- design
  patterns including the TryLock contract and defense-in-depth
  philosophy
