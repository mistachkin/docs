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
# [exec rm -rf /]        → permission denied: safe interpreter cannot use command "exec"
# [file delete important] → permission denied: safe interpreter cannot use command "file delete"
# [socket localhost 80]   → permission denied: safe interpreter cannot use command "socket"
# [object invoke System.IO.File Delete "important"] → permission denied: safe interpreter cannot use type from "System.IO.File"
```

---

## What's Available in the Sandbox

<details>
<summary><strong>Safe Commands (available to untrusted code)</strong></summary>

The following command categories are fully available in safe
interpreters:

**Control flow**: `[if]`, `else`, `elseif`, `[for]`, `[foreach]`, `[while]`,
`[switch]`, `[break]`, `[continue]`, `[return]`, `[catch]`, `[try]`, `[throw]`,
`[error]`

**Variables**: `[set]`, `[unset]`, `[append]`, `[lappend]`, `[incr]`, `[array]`,
`[global]`, `[variable]`, `[upvar]`, `[uplevel]`

**Strings**: `[string]` (all sub-commands), `[format]`, `scan`, `[regexp]`,
`[regsub]`, `[split]`, `[join]`, `[concat]`, `[subst]`, `[base64]`

**Lists**: `[list]`, `[lindex]`, `[llength]`, `[lrange]`, `[lreplace]`,
`[linsert]`, `[lsearch]`, `[lsort]`, `[lset]`, `[lmap]`, `[lassign]`, `[lget]`,
`[lremove]`, `[lreverse]`

**Math**: `[expr]` (all operators and functions), `[incr]`

**Procedures**: `[proc]`, `[nproc]`, `[apply]`, `[rename]`

**I/O** (on shared channels only): `[puts]`, `[gets]`, `[read]`, `[close]`,
`[fconfigure]`, `[fcopy]`, `[eof]`, `[fblocked]`, `[flush]`

**Evaluation**: `[eval]`, `[uplevel]`, `[subst]`

**Dictionaries**: `[dict]` (all sub-commands)

**Other**: `[after]` (limited events), `[vwait]`, `[update]`, `[namespace]`,
`[scope]`, `[hash]`, `[parse]`, `[encoding]`

</details>

<details>
<summary><strong>Hidden Commands (blocked from untrusted code)</strong></summary>

These commands are hidden when a safe interpreter is created with
`-safe`. They exist in the interpreter but cannot be invoked from
script. The parent interpreter can selectively re-expose them via
policies.

**Filesystem**: `[file]` (most sub-commands), `[cd]`, `[pwd]`, `[glob]`,
`[source]`, `[open]`

**Process execution**: `[exec]`, `[kill]`

**Plugin/library loading**: `[load]`, `[unload]`, `[library]`

**Network**: `[socket]`, `[uri]`

**Host access**: `[host]` (all sub-commands)

**.NET interop**: `[object]` (most sub-commands), `[debug]`

**Interpreter management**: `[interp]` (most sub-commands)

**Timing**: `[clock]` (most sub-commands), `[time]`

**Information disclosure**: `[info]` (restricted sub-commands)

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

```tcl
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
| `[info]` | `appdomain`, `args`, `body`, `commands`, `complete`, `context`, `default`, `engine`, `ensembles`, `exists`, `functions`, `globals`, `level`, `[library]`, `locals`, `nprocs`, `objects`, `operands`, `operators`, `patchlevel`, `procs`, `script`, `subcommands`, `tclversion`, `vars` |
| `[interp]` | `alias`, `aliases`, `cancel`, `children`, `exists`, `issafe`, `issdk`, `[rename]` |
| `[file]` | `channels`, `dirname`, `[join]`, `[split]`, `validname` |
| `[object]` | `dispose`, `exists`, `[invoke]`, `invokeall`, `invokeraw`, `isnull`, `isoftype` |

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

The `[interp alias]` command creates a bridge between interpreters. An
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

## The Policy System In Depth

Eagle's policy system is the primary mechanism for selectively exposing
unsafe functionality to safe interpreters. It extends Safe Tcl's
alias-based approach with a formal voting protocol, multiple policy
types, and integration points throughout the evaluation engine.

### Historical Context: Safe Tcl

In Tcl's Safe Tcl model, the parent interpreter creates `[interp alias]`
commands that bridge specific operations from the safe child to the
parent. For example, to let a safe interpreter read files from one
directory:

```tcl
# Safe Tcl approach: alias in child calls proc in parent
interp alias child safeSource {} safeSourceImpl
proc safeSourceImpl {path} {
    if {![string match "/allowed/*" $path]} { error "denied" }
    source $path
}
```

This works but has limitations: every controlled operation requires a
hand-written alias procedure, there's no standard protocol for access
decisions, and sub-command filtering requires reimplementing ensemble
dispatch in the alias.

Eagle retains the alias mechanism (it's still the right tool for
capability delegation) and adds a formal policy layer on top.

### Policy Architecture

<details>
<summary><strong>The IPolicyContext Contract</strong></summary>

Every policy check creates an `IPolicyContext` that carries the full
execution context to the policy callback:

| Property | Type | Description |
|----------|------|-------------|
| `Execute` | `IExecute` | The command or procedure being evaluated |
| `Arguments` | `ArgumentList` | The command arguments |
| `Script` | `IScript` | The script being evaluated (for script policies) |
| `FileName` | `[string]` | Source file name (for file policies) |
| `Bytes` | `byte[]` | Raw content bytes |
| `Text` | `[string]` | Text content |
| `Encoding` | `Encoding` | Content encoding |
| `AssemblyName` | `AssemblyName` | Assembly identity (for type policies) |
| `HashValue` | `byte[]` | Cryptographic hash of the content |
| `HashAlgorithmName` | `[string]` | Hash algorithm used (default: SHA-512) |

The context also provides a **voting interface**:

- `Undecided()` -- abstain (let other policies decide)
- `Denied(reason)` -- block execution
- `Approved(reason)` -- allow execution

</details>

<details>
<summary><strong>The Voting Protocol</strong></summary>

Multiple policies can be registered for the same command. When a
protected command is invoked, ALL matching policies are consulted and
their votes are aggregated:

1. **Any denial wins**: If any policy votes `Denied`, the decision is
   `Denied` regardless of other votes.
2. **Approval requires majority**: If approvals outnumber undecided
   votes, the decision is `Approved`.
3. **Undecided is conservative**: If undecided votes equal or exceed
   approvals, the decision is `Undecided` (which defaults to denial).

This is a **pessimistic consensus** model: it's easy to block access
(one denial suffices) and harder to grant it (majority approval
required). This design prevents a permissive policy from overriding
a restrictive one.

**Return code mapping for policy callbacks:**

| Callback Returns | Vote Cast |
|-----------------|-----------|
| `ReturnCode.Ok` | `Approved` |
| `ReturnCode.Error` | `Denied` |
| `ReturnCode.Continue` | `Undecided` |
| `ReturnCode.Break` | No vote (skip) |

</details>

<details>
<summary><strong>Policy Firing Points</strong></summary>

Policies fire at specific points in the evaluation pipeline, controlled
by `PolicyFlags`:

| Flag | When it fires |
|------|--------------|
| `BeforeCommand` | Before a hidden command executes |
| `BeforeSubCommand` | Before a sub-command of an ensemble |
| `BeforeProcedure` | Before a procedure call |
| `BeforeScript` | Before a script is evaluated |
| `BeforeFile` | Before a file is read (source, etc.) |
| `BeforeStream` | Before a stream is read |
| `AfterFile` | After a file has been read |
| `AfterStream` | After a stream has been read |

The `Before*` hooks can prevent execution entirely. The `After*` hooks
can reject already-read content (e.g., rejecting a file after hashing
it and finding it's not in a trusted list).

**Critical detail**: Policy checks only fire for **hidden commands** in
safe interpreters. Commands that are fully visible (safe commands)
execute without policy checks. This means policies control the
boundary between "safe" and "unsafe" -- they don't add overhead to
normal safe operations.

</details>

### Policy Types

<details>
<summary><strong>C# Callback Policies</strong></summary>

The most common policy type. A C# delegate receives the `IPolicyContext`
and casts a vote:

```csharp
private static ReturnCode FileCommandCallback(
    Interpreter interpreter,
    IClientData clientData,
    ArgumentList arguments,
    ref Result result
    )
{
    IPolicyContext policyContext =
        (clientData != null) ?
            clientData.Data as IPolicyContext : null;

    if (policyContext == null)
        return ReturnCode.Break; // Skip (no context)

    // Extract the sub-command from arguments
    string subCommand = PolicyOps.GetSubCommandName(
        policyContext, arguments);

    // Check against allow-list
    if (AllowedFileSubCommands.Contains(subCommand))
    {
        policyContext.Approved("allowed sub-command");
        return ReturnCode.Ok;
    }

    policyContext.Denied("sub-command not allowed");
    return ReturnCode.Error;
}
```

Eagle registers 8 default callback policies for the core ensemble
commands (`[clock]`, `[file]`, `[info]`, `[interp]`, `[object]`,
`[package]`, `[source]`, `[uri]`), each enforcing the sub-command
allow-lists shown in Security Layer 3.

</details>

<details>
<summary><strong>Script Policies</strong></summary>

Policies can be defined as Eagle scripts, registered via the
`[interp policy]` command. The script receives arguments and returns
a decision via its return code:

```tcl
# Parent installs a script policy on the child interpreter
# that allows [clock format] but denies [clock scan]
interp policy -type Clock -flags Script myChild {
    if {[lindex $args 1] eq "format"} {
        return   ;# Ok = Approved
    }
    error "denied"  ;# Error = Denied
}
```

By default, script policies evaluate in the **parent interpreter** --
the one that called `[interp policy]`. This gives the policy script
access to the parent's full capabilities for making security decisions
while keeping it isolated from the safe child interpreter's state.

With the `-isolated` flag, the policy script evaluates in a
**dedicated interpreter** created and owned by the `ScriptPolicy`
object. This provides complete isolation: the policy script cannot
read or modify the parent's variables, procedures, or state. The
isolated interpreter is automatically disposed when the child
interpreter (or the policy itself) is disposed.

The `-file` option allows full customization of the isolated
interpreter via an INI or XML settings file. Without `-file`, the
isolated interpreter uses `CreateFlags.EmbeddedUse` defaults.

The `[interp policy]` command accepts:

| Option | Description |
|--------|-------------|
| `-type type` | The .NET command type being guarded |
| `-token token` | Numeric token of the specific command |
| `-flags flags` | `PolicyFlags` controlling when the policy fires |
| `-isolated` | Create a dedicated interpreter for policy evaluation (opt-in) |
| `-file path` | Load interpreter settings from an INI or XML file for the isolated interpreter |

Only non-safe interpreters can register policies. A safe interpreter
cannot install, modify, or remove its own policies.

**Examples:**

```tcl
# Default: policy evaluates in the parent interpreter
interp policy -type Clock myChild {
    if {[lindex $args 1] eq "format"} { return }
    error "denied"
}

# Isolated: policy gets its own interpreter
interp policy -type Clock -isolated myChild {
    if {[lindex $args 1] eq "format"} { return }
    error "denied"
}

# Isolated with custom settings file
interp policy -type Clock -isolated -file /etc/eagle/policy.ini myChild {
    if {[lindex $args 1] eq "format"} { return }
    error "denied"
}
```

</details>

<details>
<summary><strong>Sub-Command Policies</strong></summary>

A specialized policy type (`PolicyOps.CheckViaSubCommand`) that filters
ensemble sub-commands against an allow-list or deny-list. This is the
mechanism behind the sub-command whitelists in Layer 3.

The implementation:
1. Extracts the sub-command name from `arguments[1]`
2. Checks against allowed list (if provided) → approve if found
3. Checks against disallowed list (if provided) → deny if found
4. Otherwise → no vote (let other policies decide)

For `[package]`, the policy uses a **deny-list** instead of an
allow-list: most sub-commands are allowed, but `alias`, `aliases`,
`indexes`, `relativefilename`, `reset`, `scan`, and `vloaded` are
blocked.

</details>

<details>
<summary><strong>Type and URI Policies</strong></summary>

Two additional policy types control .NET type access and URI access:

- **Type policies** (`PolicyOps.CheckViaType`): Validate that a .NET
  type is permitted for use. Controls which types can be instantiated
  or invoked via `[object]` when selectively re-enabled.

- **URI policies** (`PolicyOps.CheckViaUri`): Validate URI targets for
  `[uri get]` and `[uri post]`. Can restrict network access to specific
  hosts, protocols, or paths.

- **Directory policies** (`PolicyOps.CheckViaDirectory`): Validate
  filesystem paths for `[source]` and file operations.

</details>

### Integration with the Evaluation Engine

<details>
<summary><strong>Engine Policy Check Flow</strong></summary>

When a hidden command is invoked in a safe interpreter, the engine
performs this sequence (in `Engine.cs`, `EvaluateCommand`):

```tcl
1. Resolve command name → found in hidden command dictionary
2. Check: is interpreter safe? AND are policies enabled?
3. If yes:
   a. Get initial decision from interpreter.CommandInitialDecision
   b. Call interpreter.CheckCommandPolicies(
        PolicyFlags.EngineBeforeCommand, command, arguments)
   c. All matching policies are invoked, votes collected
   d. Compute final decision via PolicyOps.FinalDecision()
   e. If Approved → execute the hidden command
   f. If Denied → return "permission denied" error
4. If no → "invalid command name" error (command is hidden)
```

**Recursion prevention**: Policy checks set a `PolicyLevels` counter.
If a policy callback triggers another command that itself has a policy,
the nested check is skipped (returns Ok). This prevents infinite loops
where policy A triggers command B which triggers policy A.

</details>

<details>
<summary><strong>File and Stream Policy Integration</strong></summary>

File and stream policies fire during `[source]` and related operations:

```tcl
1. Before reading: CheckBeforeFilePolicies()
   - Computes SHA-512 hash of the file path
   - All BeforeFile policies vote
   - If Denied → file is not read
2. Read the file content
3. After reading: CheckAfterFilePolicies()
   - Computes SHA-512 hash of the file CONTENT
   - All AfterFile policies vote
   - If Denied → content is discarded, error returned
```

The two-phase check enables both path-based and content-based security:
the "before" phase can reject known-bad paths without reading them, and
the "after" phase can reject files whose content hash doesn't match a
trusted list.

</details>

### Rule Sets

<details>
<summary><strong>IRuleSet: Declarative Access Control</strong></summary>

For applications that need more structured access control than ad-hoc
policies, Eagle provides the `IRuleSet` interface. A rule set contains
ordered `IRule` objects, each with:

- `RuleType`: `Allow` or `Deny`
- `IdentifierKind`: What type of identifier the rule matches
  (command, procedure, variable, etc.)
- `MatchMode`: How to match names (`Exact`, `Glob`, `Regexp`,
  `SubString`)
- Pattern string

Rules are evaluated in order (first match wins). Rule sets can be
applied during interpreter creation via the `-ruleset` option:

```tcl
# Create a safe interpreter with a custom rule set
interp create -safe -ruleset $myRuleSet myChild
```

Rule sets integrate with the policy system: they provide the access
control specification, and policies provide the enforcement mechanism.

</details>

### Practical Policy Patterns

<details>
<summary><strong>Pattern 1: Exposing Controlled File Access</strong></summary>

```tcl
# Parent creates safe interpreter with controlled file reading
set child [interp create -safe myChild]

# Define a safe file reader in the parent
proc safeRead {child path} {
    # Validate path is under allowed directory
    set allowed [file normalize /data/shared]
    set actual [file normalize $path]
    if {![string match "${allowed}/*" $actual]} {
        error "access denied: $path"
    }
    # Read and return (executes in parent context)
    set fd [open $actual r]
    try {
        return [read $fd]
    } finally {
        close $fd
    }
}

# Expose it to the child via alias
interp alias myChild readShared {} safeRead myChild
```

</details>

<details>
<summary><strong>Pattern 2: Script-Based Policy for [clock]</strong></summary>

```tcl
# Allow [clock format] and [clock seconds] but deny [clock scan]
interp policy -type Clock myChild {
    set sub [lindex $args 1]
    if {$sub in {format seconds}} {
        return  ;# Approved
    }
    error "clock $sub not permitted"  ;# Denied
}
```

</details>

<details>
<summary><strong>Pattern 3: Auditing Policy</strong></summary>

```tcl
# Log all file access attempts (approve everything but record it)
interp policy -type File -flags Script myChild {
    set sub [lindex $args 1]
    set path [lindex $args 2]
    puts stderr "AUDIT: [clock format [clock seconds]]: \
        file $sub $path"
    return  ;# Approved (audit only)
}
```

</details>

<details>
<summary><strong>Pattern 4: Time-Limited Access</strong></summary>

A C# policy callback can implement time-based access control:

```csharp
private static ReturnCode TimeBasedPolicy(
    Interpreter interpreter,
    IClientData clientData,
    ArgumentList arguments,
    ref Result result
    )
{
    IPolicyContext context =
        (clientData != null) ?
            clientData.Data as IPolicyContext : null;

    if (context == null)
        return ReturnCode.Break;

    // Allow during business hours only
    int hour = DateTime.Now.Hour;
    if (hour >= 9 && hour < 17)
    {
        context.Approved("business hours");
        return ReturnCode.Ok;
    }

    context.Denied("outside business hours");
    return ReturnCode.Error;
}
```

</details>

<details>
<summary><strong>Pattern 5: Isolated Policy with No Parent State</strong></summary>

```tcl
# The isolated policy interpreter cannot see parent variables
# or procedures, providing complete separation of concerns
set sensitiveApiKey "sk-secret-12345"

interp policy -type Uri -isolated myChild {
    # $sensitiveApiKey does NOT exist here
    # Only the args variable (command arguments) is available
    set sub [lindex $args 1]
    if {$sub in {isvalid}} {
        return  ;# Approved
    }
    error "uri $sub not permitted"
}
```

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
