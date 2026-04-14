# Eagle Architecture: Experimental and Unorthodox Design Patterns

> **For AI agents**: This document catalogs the deliberate, non-obvious design
> patterns found throughout the Eagle codebase. These are not accidents or
> technical debt -- they are intentional architectural decisions with specific
> rationale. Understanding them is essential for making changes that don't
> fight the system's design philosophy.

## Design Philosophy

Eagle's architecture is governed by three principles that explain most of
the patterns below:

1. **Everything should be introspectable and customizable.** The system
   should be able to describe itself to anything that asks, and anything
   that asks should be able to change what it finds.

2. **Maximum backward compatibility.** The same codebase targets .NET
   Framework 2.0 RTM through .NET 9+, Mono, and .NET Standard 2.0/2.1.
   Eleven `.csproj` files exist because each represents a real build
   configuration that someone depends on.

3. **Reliability over elegance.** When a choice exists between a pattern
   that looks clean and one that works correctly under all conditions
   (threading, disposal, platform differences, AppDomain boundaries),
   correctness wins.

---

<details>
<summary><strong>1. Intentionally Mutable Static Fields</strong></summary>

Throughout the codebase, private static fields are marked with comments
like `"purposely not read-only"`. This violates the standard .NET
convention that static fields should be `readonly` when possible.

**Rationale**: These fields are ambient configuration knobs that allow
runtime behavior changes without method-level parameters. A test harness,
host application, or interactive session can adjust defaults (help
verbosity, buffer sizes, matching behavior) without recompilation or
method signature changes.

**Examples**: `HelpOps.DefaultShowTopics`, `ChannelOps.DefaultBufferSize`,
`ScriptOps.SubCommandNoCase`, `StringOps.DefaultMatchMode`

**Where**: HelpOps.cs, ChannelOps.cs, ScriptOps.cs, StringOps.cs,
Default.cs, and others. Grep for `"purposely not read-only"`.

</details>

---

<details>
<summary><strong>2. The <code>goto</code> State Machine Pattern</strong></summary>

Eagle uses `goto` extensively outside of `switch` statements -- roughly
240 occurrences, primarily in `PrivateShellMainCore` (command-line
argument processing), `ScriptOps` (script evaluation), and
`InteractiveOps` (interactive command dispatch).

**Rationale**: These methods are finite state machines where the states
and transitions are easier to reason about as labeled blocks with explicit
jumps than as nested loops with state variables. The alternative --
extracting each state into a method and passing 30+ shared variables via
a context object -- would obscure the state machine topology without
reducing complexity.

**Key instances**:
- `PrivateShellMainCore`: `retryArgv:`, `readArgv:`, `option:`,
  `haveArgv:`, `kiosk:`, `done:`, `doneArgs:`
- `ScriptOps`: `execute:`, `retry:`, `done:`

</details>

---

<details>
<summary><strong>3. Runtime Immutability Enforcement</strong></summary>

Rather than relying on C#'s compile-time `readonly` semantics, Eagle
enforces immutability at runtime via a boolean flag checked in every
property setter:

```
private bool immutable;
public Lexeme Lexeme {
    set { if (immutable) throw new InvalidOperationException(); ... }
}
public void MakeImmutable() { immutable = true; }
```

**Rationale**: Objects like `ParseState`, `ExpressionState`, `Token`,
`BundleData`, and `Script` start mutable (populated during parsing/
construction) and become immutable when cached. Compile-time immutability
can't express "mutable during construction, immutable after caching."
The `IReadOnly` interface standardizes this pattern.

</details>

---

<details>
<summary><strong>4. Six-Phase Interpreter Disposal</strong></summary>

`Interpreter.Dispose` executes six ordered phases (Phase 0 through
Phase 5), each disposing a specific category of resources:

| Phase | Resources |
|-------|-----------|
| 0 | Stop vwait, unblock events, utility threads, child interpreters |
| 1 | Bundle manager, callbacks, plugins, functions, operators |
| 2 | Database connections, object handles, channels |
| 3 | Event manager, scopes, aliases, procedures |
| 4 | Plugin/command cleanup (user and system) |
| 5 | Final cleanup, threading resources |

**Rationale**: Plugins may hold references to interpreter resources
(channels, variables, objects). Disposing in the wrong order causes
use-after-dispose exceptions in plugin cleanup code. The six phases
ensure that plugins are torn down before the resources they depend on,
and system commands before user commands.

</details>

---

<details>
<summary><strong>5. Trait-Based Host Interface Composition</strong></summary>

The `IHost` interface aggregates 10+ smaller interfaces (`IColorHost`,
`IBoxHost`, `IPositionHost`, `ISizeHost`, `IStreamHost`, `IDebugHost`,
`IReadHost`, `IWriteHost`, etc.) rather than using deep inheritance.

**Rationale**: Host implementations vary wildly -- a console host needs
color and positioning, a file host needs streams, a null host needs
nothing. Composition via interfaces lets each host implement exactly the
capabilities it supports. The `HostFlags` enum (60+ flags) provides
runtime capability queries: `DoesSupport(HostFlags.Color)`.

</details>

---

<details>
<summary><strong>6. Polymorphic Variable Storage Backends</strong></summary>

Eagle variables are not just name-value pairs. The `IVariable` interface
supports transparent delegation to external storage:

- `DatabaseVariable` -- rows in SQL databases
- `RegistryVariable` -- Windows registry keys
- `NetworkVariable` -- HTTP-based remote storage
- `ElementDictionary` -- standard in-memory (default)
- `System.Array` -- .NET arrays
- Thread, environment, and test backends

**Rationale**: Script code like `set myVar "hello"` should work
identically whether `myVar` is stored in memory, a database, or the
registry. The variable trace system (`IVariable.Traces`) fires callbacks
on every read/write/unset, enabling transparent persistence without
script-level awareness.

</details>

---

<details>
<summary><strong>7. Implicit Conversion Operator Saturation</strong></summary>

The `Result` class has 30+ implicit conversion operators, converting
from/to `string`, `int`, `long`, `double`, `decimal`, `DateTime`,
`TimeSpan`, `Guid`, `Uri`, `byte[]`, `Version`, `Exception`,
`StringList`, `BigInteger`, and more.

**Rationale**: In a scripting language, everything flows through the
result pipeline. A .NET method returning `int` needs to become a script
result. An exception needs to become a script result. A list needs to
become a script result. The implicit operators make this automatic --
any .NET return value can be assigned to `Result` without explicit
conversion at every call site across the entire engine.

</details>

---

<details>
<summary><strong>8. Dynamic Delegate Generation via Reflection.Emit</strong></summary>

`DelegateOps.cs` generates .NET delegates at runtime by emitting IL
instructions directly. When a script procedure needs to be passed as a
.NET callback (e.g., an event handler), Eagle creates a dynamic method
whose IL body marshals between the delegate's typed signature and Eagle's
untyped evaluation pipeline.

**Rationale**: Eagle scripts are untyped; .NET delegates are strongly
typed. Bridging requires generating a method with the exact parameter
types the delegate expects, which marshals those parameters into Eagle
arguments and invokes the interpreter. This can't be done with generics
or expression trees in .NET 2.0 -- Reflection.Emit is the only portable
option across all target frameworks.

On .NET 4.0+, uses `AssemblyBuilderAccess.RunAndCollect` so dynamic
assemblies are garbage-collected. On earlier frameworks, uses
`AssemblyBuilderAccess.Run` (leaked but unavoidable).

</details>

---

<details>
<summary><strong>9. GCHandle Pinning for Native Interop Identity</strong></summary>

When passing managed Eagle objects through native Tcl callbacks,
`GCHandle.Alloc(this, GCHandleType.Normal)` creates a stable handle
that survives garbage collection. The handle's `IntPtr` representation
is passed as `clientData` through native C boundaries, then recovered
via `GCHandle.FromIntPtr()` in the callback.

**Rationale**: Native Tcl callbacks receive a `ClientData` pointer that
must survive GC and identify the originating managed object. Without
pinning, the GC could move or collect the object between the native call
and the callback. `GCHandle` provides identity-stable references across
the managed/native boundary.

</details>

---

<details>
<summary><strong>10. ObjectId GUID on Every Type</strong></summary>

Every class, interface, struct, enum, and delegate in the codebase has an
`[ObjectId("guid")]` attribute with a unique GUID.

**Rationale**: Enables type identification across AppDomain boundaries,
plugin versioning, and serialization identity. When an interpreter runs
in an isolated AppDomain, type references can't be compared by identity
(`typeof()` yields different objects in different domains). The GUID
provides a stable, domain-independent identifier. It also enables tooling
to track type additions/removals/renames across releases.

</details>

---

<details>
<summary><strong>11. <code>HACK</code> Comment Doctrine (1,400+ Instances)</strong></summary>

The codebase uses `// HACK:` comments to mark every deliberate deviation
from conventional practice. This is not an admission of poor quality --
it's a documentation convention. Each HACK comment explains *why* the
deviation exists and often names the specific platform, runtime version,
or edge case it addresses.

**Categories**:
- Platform workarounds (Mono, .NET Core, Windows Terminal)
- Security model accommodations
- Performance optimizations that sacrifice readability
- Backward compatibility shims
- Known limitations with defensive handling

</details>

---

<details>
<summary><strong>12. Conditional Compilation as Architecture</strong></summary>

The `#if` guard system is not just feature flags -- it's a compatibility
architecture. Key defines include:

| Define | Purpose |
|--------|---------|
| `CONSOLE` | Console host support |
| `NATIVE` | Native P/Invoke code |
| `WINDOWS` / `UNIX` | Platform-specific code |
| `DEBUGGER` | Script debugger |
| `DATA` | ADO.NET database support |
| `HISTORY` | Line history |
| `SHELL` | Interactive shell |
| `ISOLATED_PLUGINS` | AppDomain isolation |
| `XML && SERIALIZATION` | XML serialization |
| `NATIVE && TCL` | Native Tcl integration |
| `CALLBACK_QUEUE` | Async callback infrastructure |
| `PREVIOUS_RESULT` | Previous result tracking |
| `PARSE_CACHE` | Parse state caching |
| `NET_40`, `NET_STANDARD_20`, `NET_STANDARD_21` | Framework targeting |
| `MONO`, `MONO_HACKS` | Mono compatibility |

The same C# file can compile for .NET 2.0, .NET 4.8, .NET Standard 2.1,
and Mono -- with platform-appropriate behavior at each target. The `#if`
guards are the mechanism that makes this possible without maintaining
separate codebases.

</details>

---

<details>
<summary><strong>13. TSV-Based Syntax Data (Script Metadata as Data Files)</strong></summary>

Command syntax information is stored in `Library/Resources/syntax.tsv`,
a tab-separated file loaded at runtime. Plugins contribute their own
`Resources/syntax.tsv` files that are merged into the global syntax
database.

**Rationale**: Decouples documentation from compiled code. Syntax help
can be updated without recompilation. Plugins extend the help system by
simply including a TSV file. The `#` prefix convention in the TSV denotes
entries containing only sub-command lists, distinguishing them from full
syntax descriptions.

</details>

---

<details>
<summary><strong>14. The <code>Utility</code> Facade Pattern</strong></summary>

The `Utility` class (`Components/Public/Utility.cs`) is a public static
class marked `/* FOR EXTERNAL USE ONLY */`. It exposes a curated surface
of internal functionality through methods that accept public interfaces
(`IFormatDataValue`, `IDbConnectionParameters`, `IDataTable`) and
decompose them into individual parameters for delegation to internal
classes.

**Rationale**: External consumers (plugins, Kapok, host applications)
cannot access `internal` classes like `DataOps`, `MarshalOps`, or
`CommandOptions`. The `Utility` facade provides stable public entry
points that survive internal refactoring. The interface-based parameters
ensure plugins don't need to reference internal types.

</details>

---

<details>
<summary><strong>15. Script-Level Meta-Programming</strong></summary>

Eagle scripts can modify their own interpreter's initialization pipeline
before the interpreter is fully initialized. The `Makefile.eagle` helper
demonstrates this: an `apply` lambda evaluated via `-anyFile` during
startup reaches into the interpreter's private `ShellArguments` list to
inject `-preInitialize`, `-initialize`, and `-postInitialize` arguments
that control the boot sequence.

**Rationale**: Deployment environments need to customize interpreter
startup without modifying Eagle source code. The `ShellArguments`
injection point, combined with `PrivateShellMainCore`'s argument
prepending at `retryArgv:`, creates a fully programmable initialization
pipeline accessible from script.

</details>

---

<details>
<summary><strong>16. The TryLock / ExitLock Contract</strong></summary>

Every class that uses synchronization follows a three-method pattern:
`TryLock(ref bool locked)`, `ExitLock(ref bool locked)`, and
`MaybeWhoHasLock()`. The `ref bool` makes lock state explicit and
first-class. `ExitLock` is idempotent. `MaybeWhoHasLock` provides
zero-cost diagnostics via `Interlocked.CompareExchange` on a thread ID
field.

**Rationale**: Raw `Monitor.Enter`/`Exit` is error-prone (forgetting to
release, releasing without acquiring). The `lock()` statement can't time
out or trace failures. The TryLock pattern provides non-blocking
acquisition with configurable timeouts, diagnostic thread ID tracking,
and `LockTrace` on failure -- all without deadlock risk.

</details>

---

<details>
<summary><strong>17. The StorageOps Command Composition Tree</strong></summary>

The Kapok enterprise storage system uses a command pattern with
composable logic operators:

```
BaseCommand → TraceCommand → NopCommand
                            → ScriptCommand
                            → UnaryCommand → NotCommand
                            → BinaryCommand → AndCommand (short-circuit)
                                            → OrCommand (short-circuit)
                            → MaybeValuesCommand → MaybeWriteCommand
                            → IfThenElseCommand
```

**Rationale**: Database access policies are complex combinatorial
decisions (is the API key valid AND (is the variable public OR does the
user have admin access)). Expressing these as composable command objects
with short-circuit evaluation allows policies to be configured
declaratively via settings, not hard-coded in procedural logic.

</details>

---

## Script-Level Patterns

The patterns above describe the C# internals. The Eagle script libraries
(`lib/Eagle1.0/`, `lib/Test1.0/`, `Library/Tests/`) demonstrate equally
distinctive patterns at the scripting level.

---

<details>
<summary><strong>18. Dual Tcl/Eagle Compatibility Scripting</strong></summary>

The entire script library is designed to run in both vanilla Tcl and
Eagle. Bootstrap procedures like `isEagle` detect the runtime, and the
library conditionally loads Eagle-specific modules. System aliases are
created differently for each engine via `interp alias`. This means the
same test suite can validate both Tcl compatibility and Eagle-specific
features.

The `::no()` global array acts as a compile-time feature flag system at
the script level -- setting `::no(someFile)` before initialization skips
loading that file. This is the script equivalent of `#if` guards.

**Where**: `lib/Eagle1.0/init.eagle`, `lib/Eagle1.0/platform.eagle`

</details>

---

<details>
<summary><strong>19. Procedure Factories with Hidden Instrumentation</strong></summary>

`s_proc` (stub procedure) and `f_proc` (flexible procedure) are
factories that create procedures with optional debugger instrumentation
injected into their bodies. The generated procedure body can include
code from `::eagle_debugger(stubProcedureBody)` or
`::eagle_debugger(flexibleProcedureBody)`, enabling transparent
debugging hooks without modifying the original procedure definitions.

`f_proc` also chooses between `proc` and `nproc` (native procedure)
based on runtime capabilities -- the caller doesn't know which
implementation backs their procedure.

**Where**: `lib/Eagle1.0/test.eagle` (lines 60-107)

</details>

---

<details>
<summary><strong>20. Self-Destructing Procedures</strong></summary>

The `apply` compatibility shim for Tcl 8.4 creates a temporary
procedure with a unique name, executes it, then the procedure body
includes a `rename` command that deletes itself after first invocation.
This is self-modifying code: the procedure destroys itself as its last
act.

```tcl
proc ::apply_shim_$suffix {lambda args} {
    # ... execute lambda ...
    rename ::apply_shim_$suffix ""  ;# self-destruct
}
```

**Where**: `lib/Eagle1.0/init.eagle` (lines 659-724)

</details>

---

<details>
<summary><strong>21. Multi-Level Upvar for Cross-Frame Variable Access</strong></summary>

Eagle scripts routinely use `upvar 1` (one level up) and `upvar 2` (two
levels up) to link variables across call frames without passing them as
arguments. `getParameterFromAny` reaches up two levels to access the
caller's caller's variables. This enables transparent parameter
extraction from deeply nested call chains.

Combined with `uplevel 1 $script`, procedures can execute scripts in
the caller's context, reading and writing the caller's local variables
as if the procedure boundary didn't exist.

**Where**: `lib/Eagle1.0/test.eagle`, `lib/Eagle1.0/exec.eagle`

</details>

---

<details>
<summary><strong>22. Thread-Safe Script State via Variable Locks</strong></summary>

The test framework uses `vwaitLocked` to safely manage shared script
state across threads. Global arrays like `::test_puts_state` and
`::test_log_queue` are modified inside locked sections, preventing
concurrent modification. This implements thread-safe queues and state
machines entirely at the script level, without any C# involvement.

`tlog` (test log) uses this to safely queue log entries from multiple
threads, processing the queue by iterating `array names` and deleting
entries after processing.

**Where**: `lib/Eagle1.0/test.eagle` (lines 3114-3442)

</details>

---

<details>
<summary><strong>23. Test Constraint System</strong></summary>

The test framework uses a constraint system where each test declares
prerequisites like `{eagle command.object compile.CONFIGURATION
monoBug22}`. Constraints are dynamically set during prologue execution
based on platform detection, feature availability, and known bug
workarounds.

`addConstraint` / `removeConstraint` modify the constraint set at
runtime. `haveConstraint` checks if all prerequisites are met before
running a test. Bug constraints like `monoBug22`, `knownBug`, and
`noBug` document known issues directly in the test definitions.

The constraint system in `lib/Test1.0/constraints.eagle` (~7,700 lines,
~207 procedures) programmatically detects capabilities by probing the
runtime -- checking for commands, compilation flags, platform features,
and .NET type availability.

**Where**: `lib/Test1.0/constraints.eagle`, `lib/Test1.0/prologue.eagle`

</details>

---

<details>
<summary><strong>24. Unknown Command Handler as Object Dispatch</strong></summary>

Eagle's `unknown` command handler can intercept unrecognized commands
and attempt to resolve them as .NET type names. When
`eagleUnknownObjectInvoke` is enabled, typing a .NET class name at the
interactive prompt automatically delegates to `object invoke`. This
turns the Eagle shell into a dynamic .NET REPL where any .NET type is
a first-class command.

**Where**: `lib/Eagle1.0/init.eagle` (lines 482-541)

</details>

---

<details>
<summary><strong>25. Test Hook Architecture</strong></summary>

The test framework provides optional hook points at every stage of test
execution: `beforeRunTest`, `beforeTest`, `afterTest`, `testSuccess`,
`testFailure`. These are user-defined procedures that, if they exist,
are called at the appropriate points. This enables test infrastructure
customization (custom logging, CI integration, performance measurement)
without modifying the test framework code.

`runTest` dynamically discovers hooks via `info commands` and invokes
them if present. The hook mechanism is entirely convention-based -- no
registration required.

**Where**: `lib/Eagle1.0/test.eagle` (lines 6318-6523)

</details>

---

<details>
<summary><strong>26. Multi-Runtime Command Line Building</strong></summary>

`getRuntimeCommandLine` in `exec.eagle` builds different command lines
depending on whether the target is Mono, .NET Core, or .NET Framework.
`execShell` uses this to execute Eagle scripts in sub-processes with
the correct runtime prefix (`mono`, `dotnet exec`, or direct execution).
This enables test infrastructure that spans multiple .NET runtimes from
a single test script.

**Where**: `lib/Eagle1.0/exec.eagle` (lines 48-151)

</details>

---

<details>
<summary><strong>27. Self-Referential Introspection</strong></summary>

Eagle scripts routinely use `[info level [info level]]` to discover
their own procedure name at runtime, `[info script]` to find their own
file path, and `[object invoke ... CurrentFrame Name]` to inspect the
call frame stack. This self-referential introspection is used for
logging, statistics tracking, and dynamic behavior based on calling
context.

**Where**: `lib/Eagle1.0/test.eagle`, `lib/Test1.0/prologue.eagle`

</details>

---

## References

- **Source code**: `Eagle/Library/` -- the complete Eagle core library
- **Key C# files**: `Interpreter.cs` (~125,000 lines), `Engine.cs`,
  `Default.cs`, `Console.cs`, `ShellOps.cs`, `InteractiveOps.cs`,
  `ScriptOps.cs`, `HelpOps.cs`, `SyntaxOps.cs`, `DelegateOps.cs`,
  `DataOps.cs`, `ObjectOps.cs`, `CommandOptions.cs`, `NativeConsole.cs`,
  `AnsiConsole.cs`, `LineEditor.cs`
- **Key script files**: `lib/Eagle1.0/init.eagle`, `test.eagle`,
  `object.eagle`, `platform.eagle`, `exec.eagle`, `auxiliary.eagle`,
  `lib/Test1.0/constraints.eagle`, `prologue.eagle`, `epilogue.eagle`
- **Related documentation**: [`options.md`](options.md) -- command option
  system architecture
