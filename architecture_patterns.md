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

Eagle uses `goto` extensively outside of `[switch]` statements -- roughly
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

```csharp
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

The phases are implemented as discrete `DisposePhase1`..`DisposePhase5`
methods (phase 0 work runs first within the disposal entry point), and the
disposal logic distinguishes the interpreter it actually created from a
caller-owned parent so it never disposes a parent the caller still holds.

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

**Concrete hosts**: `Default` (the abstract base implementing the common
surface), `Console` (full interactive console), `File` (stream-backed),
`Diagnostic`, `Null` and `Fake` (do-nothing/stub hosts for tests and headless
use), `Shell`, and `Wrapper` (forwards every interface member to a wrapped
inner host -- the same forwarding-wrapper technique as pattern 44). Each picks exactly the
sub-interfaces and `HostFlags` it needs; the do-nothing hosts implement the
full surface but return inert results.

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
from/to `[string]`, `int`, `long`, `double`, `decimal`, `DateTime`,
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
demonstrates this: an `[apply]` lambda evaluated via `-anyFile` during
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

```tcl
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

## Coding Conventions

> The entries above are architectural. The conventions below are
> prescriptive, codebase-wide C# style rules. They exist for readability,
> reliability, and bulk auditability rather than for any one subsystem's
> behavior -- but they are applied just as deliberately. They were recently
> applied wholesale while refactoring `CompletionOps.cs` in the Featherlight
> plugin, which is a good worked example of all three together.

---

<details>
<summary><strong>18. Defensive Parameter Validation</strong></summary>

Methods validate their reference-type parameters for `null` at entry and
fail fast -- returning a sentinel (`false`, `null`, or an error
`ReturnCode`) -- instead of risking a `NullReferenceException` deep inside
the body.

```csharp
private static bool TryCompleteCommand(
    CompletionRequest request /* in */
    )
{
    if (request == null)
        return false;

    // ...the body can now use 'request' without re-checking...
}
```

**Rationale**: A `NullReferenceException` thrown several frames into a
method is opaque -- the stack trace points at the dereference site, not at
the caller that passed `null`. An explicit guard at the top turns a
"mystery NRE" into a predictable, traceable outcome and documents the
method's contract (which parameters are required). In a system where
callers span plugins, AppDomain boundaries, and script-driven dispatch,
inputs cannot be assumed well-formed. Pairs with pattern 19 (the guard is
where the extracted local gets its null-check).

</details>

---

<details>
<summary><strong>19. Extract, Null-Check, and Cache Before Dereferencing</strong></summary>

When a method will dereference a parameter -- or any shared field or
property -- more than trivially, it must first copy that reference into a
local variable, null-check the local, and then use the local everywhere.
Do not repeatedly dereference `request.Interpreter`, `request.Matches`,
etc. inline.

```csharp
// NO -- repeated dereference, null contract scattered (or absent):
if (request.Interpreter.IsExpressionCommand(request.CommandName, ...))
    request.Interpreter.ListFunctions(..., ref request.Error);

// YES -- extract once, check once, use the local:
Interpreter interpreter = request.Interpreter;

if (interpreter == null)
    return false;

if (interpreter.IsExpressionCommand(request.CommandName, ...))
    interpreter.ListFunctions(..., ref request.Error);
```

**Rationale**: Three reasons.

1. **Readability.** `interpreter.X` reads far better than
   `request.Interpreter.X` repeated down a method, and the null contract
   lives in exactly one obvious place instead of being implied at every
   use (or, worse, nowhere).
2. **Correctness.** A field or property may be mutable, lazily computed, or
   touched from multiple threads; re-reading it can yield a different value
   (or `null`) between uses. Caching once gives the method a stable,
   self-consistent view for its whole duration.
3. **It localizes the check.** Extraction is the natural home for the
   null-check from pattern 18, so the two conventions reinforce each other.

</details>

---

<details>
<summary><strong>20. <code>String.Format</code> Over the <code>+</code> Operator</strong></summary>

Build composite strings with `String.Format("{0}{1}", a, b)` rather than
the `+` concatenation operator.

```csharp
// NO:
argument = Characters.Comment + list[0];
newName = name + Characters.Space + "(command)";

// YES:
argument = String.Format("{0}{1}", Characters.Comment, list[0]);
newName = String.Format("{0}{1}(command)", name, Characters.Space);
```

**Rationale**:

- **Less null/coercion fuss.** Every operand reaches the result the same
  way -- through `{0}`-style substitution -- so there is no need to reason
  about how `+` coerces each operand or what a `null` operand does mid-chain.
- **Avoids the `char` arithmetic footgun.** With `+`, two `char` operands
  do *integer* addition (`'a' + 'b'` is `195`, not `"ab"`); mixing `char`
  and `string` silently switches between numeric and textual behavior.
  `String.Format` always formats, never adds.
- **Simpler.** One call instead of a chain of `+` with mixed `char`/`string`
  operands.
- **Bulk auditability.** String construction becomes findable and reviewable
  as a class -- grep for `String.Format`, or for the format strings
  themselves -- which matters for audits, localization sweeps, and
  refactors. `+`-built strings are scattered and hard to enumerate.

</details>

---

<details>
<summary><strong>21. Named Constants, Not Magic Numbers or Literals</strong></summary>

Non-trivial literal values -- counts, limits, indices, sentinel and format
strings -- are declared as named `private const` (or `static readonly`)
members in the `Private Constants` region, each with its own doc comment,
rather than written inline at the point of use.

```csharp
private const int MaximumAutoComplete = 30;
private const int MaximumArgumentCount = 2;
private const int CommandNameIndex = 0;
private const int SubCommandNameIndex = 1;
private const string TooManyMatches = "... <MORE THAN {0} MATCHES> ...";
```

**Rationale**: A bare `2` or `30` at a call site carries no meaning and no
searchability; `MaximumArgumentCount` carries both. The constant is a
single point of change, the name documents intent at every use, the value
is greppable, and the constant's own doc comment is the natural home for
the *why* of the number. Inline literals are also where off-by-one bugs and
"two places that must stay in sync" bugs hide.

</details>

---

<details>
<summary><strong>22. Region Ordering and Naming</strong></summary>

Every type partitions its members into `#region` blocks drawn from a fixed,
standard vocabulary, in a consistent order. Ad-hoc or semantic groupings are
**not** introduced as new top-level regions; they nest *inside* the
appropriate standard region. A nested helper type gets its own
`Private <Name> Helper Class` region.

Canonical top-level order:

```
(Private <Name> Helper Class)   // nested helper type(s), if any
Private Constants
Private Data
Public Constructors
Public Methods / Private Methods / I<Interface> Members
IDisposable Members
IDisposable "Pattern" Members
Destructor
```

**Rationale**: With a fixed region vocabulary and order, a reader opening
any of thousands of files knows where to look -- constants at the top,
disposal at the bottom, interface implementations grouped by interface.
Inventing a new top-level region name (e.g. `Completion Strategies`) erodes
that predictability. The fix is to nest it: in `CompletionOps.cs` the
`Completion Strategies` grouping lives *inside* `Private Methods`, which
preserves both the uniform top-level skeleton and the semantic sub-grouping.
A nested helper type, by contrast, does warrant its own region (the
`CompletionRequest` type sits in `Private CompletionRequest Helper Class`).

</details>

---

<details>
<summary><strong>23. Minimal Visibility</strong></summary>

Every type and member uses the **narrowest access modifier that satisfies
an actual, demonstrated need**. The default is `private`; `internal`, then
`protected`, then `public` are each a step that must be earned. If something
has no need for wider visibility, it does not get it.

```csharp
// Private, sealed nested helper type; its methods are private static.
private sealed class CompletionRequest { ... }
private static bool TryComplete(CompletionRequest request) { ... }
```

**Rationale**: A smaller surface is easier to reason about, refactor, and
secure -- the compiler guarantees nothing outside the intended scope can
touch the member, so invariants hold by construction. It also makes intent
legible: because the default is `private`, a reader who sees `public` or
`internal` can trust it was a deliberate choice rather than an oversight.

**Subtlety**: accessibility composes. A `public` field inside a `private`
nested type is still reachable only from the enclosing class, because the
type's own `private`-ness caps it. Making the *type* private is the
visibility control; the field modifiers inside it are bounded by that.

Any widening beyond the minimum is a deviation, and is documented per
convention 24.

</details>

---

<details>
<summary><strong>24. Document Every Deviation</strong></summary>

Any departure from a standard convention or a best practice -- a
wider-than-default access modifier, a literal that genuinely cannot be
named, a skipped null-check, an unusual region, a non-obvious algorithm --
is documented at the site with a `// NOTE:` or `// HACK:` comment that
explains *why*.

**Rationale**: The conventions in this document, and the architectural
patterns above them, are the assumed baseline. A reader trusts that
baseline, so the only thing that needs explaining is where the code steps
off it. An undocumented deviation is indistinguishable from a bug; a
documented one carries its own justification and review trail. This is the
governing rule behind the `HACK` comment doctrine (pattern 11): the comment
is not an apology for bad code -- it is the record that a deviation was
deliberate, and the place its rationale lives.

</details>

---

<details>
<summary><strong>25. Comprehensive XML Documentation</strong></summary>

Every type and member -- public *or* private, including fields, constants,
properties, delegates, and nested types -- carries an XML documentation
comment. Documentation tags each occupy their own line (a `<summary>` is
never collapsed onto a single line with its text); every method documents
each parameter with a `<param>` block and, when non-void, its `<returns>`;
doc text wraps within the file's column limit and stays ASCII.

```csharp
/// <summary>
/// Gets a localized string resource for the plugin.
/// </summary>
/// <param name="name">
/// The name of the string resource to retrieve.
/// </param>
/// <returns>
/// The requested string resource, or null upon failure.
/// </returns>
public override string GetString( ... ) { ... }
```

**Rationale**: The documentation is the contract. Because *every* member is
documented -- not just the public API -- a reader never has to
reverse-engineer intent from a method body, and tooling can surface help for
any symbol across AppDomain and plugin boundaries. Keeping each tag on its
own line makes the comments diffable, greppable, and mergeable, and gives
them a uniform shape the eye can skim. Leaving a member undocumented is
itself a deviation (convention 24).

</details>

---

<details>
<summary><strong>26. Bounds-Check Before Indexing</strong></summary>

Before indexing a collection or array, verify the index is in range
(`index < collection.Count`) -- exactly as a reference is null-checked
before it is dereferenced. The two guards travel together.

```csharp
StringList newArguments = request.NewArguments;

if ((newArguments != null) && (CommandNameIndex < newArguments.Count))
    newArguments[CommandNameIndex] = ...;
```

**Rationale**: An out-of-range index is the array-shaped sibling of a null
dereference -- an exception thrown far from its cause. Guarding the index at
the point of use, alongside the null-check of convention 18 and the
extract-and-cache of convention 19, keeps the failure local and the contract
explicit. It matters most where the index is a named constant (e.g.
`CommandNameIndex`) and the collection's length is data-dependent: the
constant says nothing about whether the collection is actually that long.

</details>

---

<details>
<summary><strong>27. Parameter-Direction Markers</strong></summary>

Multi-line parameter lists annotate each parameter with a trailing
`/* in */`, `/* out */`, or `/* in, out */` comment indicating its data-flow
direction, aligned one space past the longest parameter declaration.

```csharp
public override ReturnCode Initialize(
    Interpreter interpreter, /* in */
    IClientData clientData,  /* in */
    ref Result result        /* out */
    )
```

**Rationale**: C# offers only `ref`/`out` keywords, and `ref` conflates "I
read this" with "I write this." The markers record the *intended* data flow
for every parameter -- plain by-value inputs, `out` results, and `ref`
parameters used purely as outputs alike -- so a signature is self-describing
at a glance: which arguments are consumed, which are produced, which are
both, without reading the body. The column alignment lets the markers be
scanned as a single vertical strip.

</details>

---

## Script-Level Patterns

The patterns and conventions above describe the C# internals and house coding style. The Eagle script libraries
(`lib/Eagle1.0/`, `lib/Test1.0/`, `Library/Tests/`) demonstrate equally
distinctive patterns at the scripting level.

---

<details>
<summary><strong>28. Dual Tcl/Eagle Compatibility Scripting</strong></summary>

The entire script library is designed to run in both vanilla Tcl and
Eagle. Bootstrap procedures like `isEagle` detect the runtime, and the
library conditionally loads Eagle-specific modules. System aliases are
created differently for each engine via `[interp alias]`. This means the
same test suite can validate both Tcl compatibility and Eagle-specific
features.

The `::no()` global array acts as a compile-time feature flag system at
the script level -- setting `::no(someFile)` before initialization skips
loading that file. This is the script equivalent of `#if` guards.

**Where**: `lib/Eagle1.0/init.eagle`, `lib/Eagle1.0/platform.eagle`

</details>

---

<details>
<summary><strong>29. Procedure Factories with Hidden Instrumentation</strong></summary>

`s_proc` (stub procedure) and `f_proc` (flexible procedure) are
factories that create procedures with optional debugger instrumentation
injected into their bodies. The generated procedure body can include
code from `::eagle_debugger(stubProcedureBody)` or
`::eagle_debugger(flexibleProcedureBody)`, enabling transparent
debugging hooks without modifying the original procedure definitions.

`f_proc` also chooses between `[proc]` and `[nproc]` (native procedure)
based on runtime capabilities -- the caller doesn't know which
implementation backs their procedure.

**Where**: `lib/Eagle1.0/test.eagle` (lines 60-107)

</details>

---

<details>
<summary><strong>30. Self-Destructing Procedures</strong></summary>

The `[apply]` compatibility shim for Tcl 8.4 creates a temporary
procedure with a unique name, executes it, then the procedure body
includes a `[rename]` command that deletes itself after first invocation.
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
<summary><strong>31. Multi-Level Upvar for Cross-Frame Variable Access</strong></summary>

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
<summary><strong>32. Thread-Safe Script State via Variable Locks</strong></summary>

The test framework uses `vwaitLocked` to safely manage shared script
state across threads. Global arrays like `::test_puts_state` and
`::test_log_queue` are modified inside locked sections, preventing
concurrent modification. This implements thread-safe queues and state
machines entirely at the script level, without any C# involvement.

`tlog` (test log) uses this to safely queue log entries from multiple
threads, processing the queue by iterating `[array names]` and deleting
entries after processing.

**Where**: `lib/Eagle1.0/test.eagle` (lines 3114-3442)

</details>

---

<details>
<summary><strong>33. Test Constraint System</strong></summary>

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
<summary><strong>34. Unknown Command Handler as Object Dispatch</strong></summary>

Eagle's `unknown` command handler can intercept unrecognized commands
and attempt to resolve them as .NET type names. When
`eagleUnknownObjectInvoke` is enabled, typing a .NET class name at the
interactive prompt automatically delegates to `[object invoke]`. This
turns the Eagle shell into a dynamic .NET REPL where any .NET type is
a first-class command.

**Where**: `lib/Eagle1.0/init.eagle` (lines 482-541)

</details>

---

<details>
<summary><strong>35. Test Hook Architecture</strong></summary>

The test framework provides optional hook points at every stage of test
execution: `beforeRunTest`, `beforeTest`, `afterTest`, `testSuccess`,
`testFailure`. These are user-defined procedures that, if they exist,
are called at the appropriate points. This enables test infrastructure
customization (custom logging, CI integration, performance measurement)
without modifying the test framework code.

`runTest` dynamically discovers hooks via `[info commands]` and invokes
them if present. The hook mechanism is entirely convention-based -- no
registration required.

**Where**: `lib/Eagle1.0/test.eagle` (lines 6318-6523)

</details>

---

<details>
<summary><strong>36. Multi-Runtime Command Line Building</strong></summary>

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
<summary><strong>37. Self-Referential Introspection</strong></summary>

Eagle scripts routinely use `[info level [info level]]` to discover
their own procedure name at runtime, `[info script]` to find their own
file path, and `[object invoke ... CurrentFrame Name]` to inspect the
call frame stack. This self-referential introspection is used for
logging, statistics tracking, and dynamic behavior based on calling
context.

**Where**: `lib/Eagle1.0/test.eagle`, `lib/Test1.0/prologue.eagle`

</details>

---

<details>
<summary><strong>38. Runtime C# Compilation from Script (<code>csharp.eagle</code>)</strong></summary>

`csharp.eagle` provides a complete C# compilation subsystem accessible
from Eagle scripts. The `compileCSharp` procedure accepts C# source code
as a string and compiles it into a .NET assembly at runtime, using one of
two strategies:

- **Desktop .NET Framework**: Uses `Microsoft.CSharp.CSharpCodeProvider`
  for in-process compilation via the CodeDOM API.
- **.NET Core / .NET 5+**: Invokes the command-line compiler (`csc.dll`)
  via `dotnet exec`, since CodeDOM is not available on .NET Core.

The subsystem handles complex .NET Standard reference assembly path
resolution, SDK version detection, target framework moniker mapping,
and compiler error/warning extraction. It supports both in-memory and
disk-based assembly output.

An extensive hook system via `::compileCSharp(*)` array variables allows
callers to customize compiler parameters, reference assemblies, and
output paths. The `doesCompileCSharpWork` procedure validates that
compilation is functional on the current platform before tests depend
on it.

This enables patterns like compiling a C# class from a test script,
loading it into the interpreter, and invoking its methods -- all within
a single test case. The SQLite .NET test suite uses this extensively for
testing custom type handlers and callback delegates.

**Where**: `lib/Eagle1.0/csharp.eagle`

</details>

---

<details>
<summary><strong>39. Remote Package Repository Client (<code>pkgt.eagle</code>)</strong></summary>

`pkgt.eagle` (Package Toolset) provides tools for downloading,
extracting, and managing Eagle packages from remote repositories. It
acts as Eagle's package manager client, handling:

- **Package Client Toolset** download and extraction
- **Native Tcl/Tk DLL** downloads for Garuda bridging
- **Security Toolset** (Harpy and Badge plugins) acquisition
- **License certificate** requests
- **Remote script evaluation** in sandboxed environments
- **Package index** downloads and forced re-scanning

The system uses a URI template pattern with Tcl variable substitution
(`${baseUri}/${urn}`) and distributes requests across multiple server
endpoints for load balancing. Environment variable overrides
(`$::env(...)`) allow runtime reconfiguration for testing.

Platform-specific downloads use `machineToPlatform` and
`$::tcl_platform(machine)` to select the correct architecture. ZIP
archive extraction integrates with `Eagle.Unzip`. Remote servers
return Tcl dictionaries with standardized keys (`returnCode`, `result`,
`errorLine`).

The `loadPackageClientToolset` procedure loads the repository client
with optional security features, and `forceScanOfPackages` triggers
package index re-scanning by requesting a known-nonexistent package
name -- a deliberate hack that exploits the package system's scan-on-
miss behavior.

**Where**: `lib/Eagle1.0/pkgt.eagle`

</details>

---

<details>
<summary><strong>40. Shell Unknown Handler as .NET Type Dispatch</strong></summary>

Eagle's `unknown` command handler (`init.eagle`) forms a multi-level
resolution chain:

1. **Entry**: Unrecognized command name → `unknown` procedure
2. **Type resolution**: If `eagleUnknownObjectInvoke` option is enabled,
   `unknownObjectInvoke` (in `unkobj.eagle`) attempts to resolve the
   command as a .NET type name via `isManagedType()` / `canGetManagedType()`
3. **Method invocation**: If a type is found, arguments are merged with
   `[object invoke]` options via `MergeArguments()` on the active
   interpreter, and the command is re-dispatched as a .NET static method call
4. **Chaining**: If resolution fails, `[continue]` is returned to chain to
   the next handler (package unknown, namespace unknown, etc.)
5. **Package fallback**: `tclPkgUnknown` forces package index re-scanning
   with `-host`, `-bundle`, and optionally `-plugins` flags

Nested member access uses NUL byte (`\x00`) as a separator:
`System.String.IsNullOrEmpty` becomes `System.String\x00IsNullOrEmpty`
internally, which the Eagle marshaller interprets as nested member
resolution.

**Safe interpreters** get a restricted `unknown` handler (defined in
`safe.eagle`) that only reports errors -- no .NET type resolution is
allowed. This is a critical security boundary: untrusted scripts cannot
invoke arbitrary .NET methods through the unknown handler.

The `uplevel [expr {$level + 1}]` pattern in `unknownObjectInvoke`
skips the intermediate `unknown` call frame so that the resolved
command executes in the original caller's context, preserving variable
scope and call frame semantics.

When `eagle_shellUnknown` is enabled (see pattern 41), the resolution
chain becomes: shell dispatch → .NET type resolution → package fallback.
The shell handler saves the original `::unknown` as `::savedUnknown` and
falls back to it on failure, creating a layered resolution system where
each handler can chain to the next.

**Where**: `lib/Eagle1.0/init.eagle`, `lib/Eagle1.0/unkobj.eagle`,
`lib/Eagle1.0/safe.eagle`

</details>

---

<details>
<summary><strong>41. Transparent OS Shell Bridge (<code>eagle_shellUnknown</code>)</strong></summary>

The `eagle_shellUnknown` system transforms Eagle's interactive prompt
into a transparent OS shell. When enabled via `eagle_enableShellUnknown`,
it hot-swaps the `unknown` handler: the original `::unknown` is saved as
`::savedUnknown`, and `::eagle_shellUnknown` takes its place.

When a command isn't found, `eagle_shellUnknown` checks whether the
input is coming from the interactive loop (via `eagle_isShellScriptLevel`,
which compares `ScriptLevels` against `InteractiveScriptLevels` plus a
known procedure depth offset). If so, it delegates to
`eagle_shellBuildCommand` to construct an `[exec]` invocation targeting
the OS shell.

`eagle_shellBuildCommand` is the most sophisticated part. It detects the
current shell (`cmd.exe`, `/bin/bash`, PowerShell, `4nt.exe`, `tcc.exe`)
and adjusts argument construction accordingly:

- **cmd.exe**: Uses `/C` prefix, `-commandline` for `CommandLineToArgvW`
  quoting, `-forprocessor` for command processor awareness
- **PowerShell**: Uses `-Command` prefix, wraps arguments in single
  quotes with escape-by-doubling (`'` → `'\''`), collapses arguments
  into a single string
- **Unix shells**: Uses `-c` flag, optional single-quote wrapping for
  nested shell invocations
- **Configurable**: 20+ runtime options (`shellUnknown_ForceShell`,
  `shellUnknown_ForceDequote`, `shellUnknown_NoCommandProcessor`, etc.)
  control every aspect of command construction

The system has 8 hook points (`initialShellBuildCommand`,
`optionsShellBuildCommand`, `beforeShellBuildCommand`,
`afterShellBuildCommand`, `beforeShellUnknown`, `afterShellUnknown`,
`shellUnknownError`, `finalShellBuildCommand`) allowing external code
to intercept and modify command construction at every stage.

If the shell command fails, the error can either propagate or fall back
to `::savedUnknown` (the original .NET type resolver), controlled by
`shellUnknown_ErrorFallback` and `shellUnknown_OkFallback` options.
This creates a resolution chain: try shell → try .NET types → error.

The net effect: typing `ls -la` or `DIR /S` at the Eagle prompt "just
works" on any platform, with correct quoting for the detected shell.

**Where**: `lib/Eagle1.0/test.eagle` (lines 10390-10781)

</details>

---

## Additional Patterns (C# Internals)

> The patterns below were surfaced or confirmed during the full-codebase XML
> documentation pass -- after which every type and member in `Eagle/Library/`
> (public *and* private) carries a doc comment. They are pervasive C# internals
> patterns that complement the architecture and conventions above. Numbering
> continues past the script-level section so the existing cross-references stay
> stable.

---

<details>
<summary><strong>42. The <code>*Ops</code> Static Helper Organization</strong></summary>

The core library's primary unit of decomposition is the static "operations"
class: roughly eighty `XxxOps` types -- `MarshalOps`, `ScriptOps`, `PathOps`,
`RuntimeOps`, `FormatOps`, `StringOps`, `ConversionOps`, `EnumOps`, `HelpOps`,
`FileOps`, `SocketOps`, `ObjectOps`, `EntityOps`, and many more -- each owning one
domain and exposing only static methods. Several are among the largest files in
the tree (MarshalOps, ScriptOps, PathOps, RuntimeOps each run to thousands of
lines and hundreds of members).

**Rationale**: Eagle has one giant stateful object (`Interpreter`) surrounded by a
constellation of stateless operation bundles. Grouping domain logic into static
`*Ops` classes keeps `Interpreter` from absorbing everything, gives each concern a
single obvious home, and lets the engine call `PathOps.X(...)` or
`MarshalOps.Y(...)` without threading helper instances through every call. A
method's membership in `FooOps` is itself documentation -- it declares the
concern (path handling, marshalling, formatting) the method belongs to.

</details>

---

<details>
<summary><strong>43. The <code>ReturnCode</code> + <code>ref Result</code> Calling Convention</strong></summary>

The engine's universal method contract: an operation returns a `ReturnCode`
(`Ok`, `Error`, `Return`, `Break`, `Continue`) and writes its output -- or its
error message -- into a `ref Result`. Success and failure frequently use distinct
sinks (`ref Result result` for the value, a separate `ref Result error` for the
message); a common boolean-returning variant pairs a `bool` with a
`ref Result error`. The convention runs through `Engine`, `Interpreter`, every
command's `Execute`, and the `*Ops` classes.

```csharp
public override ReturnCode Execute(
    Interpreter interpreter, /* in */
    IClientData clientData,  /* in */
    ArgumentList arguments,  /* in */
    ref Result result        /* out */
    )
```

**Rationale**: Tcl-style evaluation has five completion codes, not two, and every
step must carry both a value and a human-readable error through one channel. A C#
`return` of a single typed value cannot express that. `ReturnCode` + `ref Result`
makes the full completion state explicit and identical at every call site -- and
it is precisely what pattern 7's implicit `Result` conversions exist to feed.

</details>

---

<details>
<summary><strong>44. The <code>IWrapper</code> Entity Wrapper Layer</strong></summary>

Every first-class entity the interpreter tracks -- commands, sub-commands,
procedures, lambdas, functions, operators, plugins, packages, aliases, objects,
object types, callbacks, traces, and modules -- is held through a thin
`IWrapper`-derived forwarding wrapper (the `Eagle._Wrappers` namespace) rather
than directly. The wrapper forwards the entity's interface to the wrapped instance
while adding token identity, hidden/active state, reference counts, and lifetime
bookkeeping.

**Rationale**: the interpreter needs uniform per-entity metadata -- a stable
token, a hidden flag, usage counts, a kill switch -- for entities of wildly
different types authored by different parties (including plugins). Keeping that
metadata on a wrapper rather than on the entities themselves gives each registry
one consistent handle type, and lets the engine hide, disable, or reference-count
any entity without the entity's cooperation.

</details>

---

<details>
<summary><strong>45. Ensemble Commands and Sub-Command Dispatch</strong></summary>

Multi-function commands (`[debug]`, `[object]`, `[interp]`, `[file]`, `[string]`,
`[array]`, `[package]`, ...) are *ensembles*: the command holds a `subCommands`
`EnsembleDictionary` mapping each sub-command name to its handler, plus optional
`allowedSubCommands` / `disallowedSubCommands` `IPolicyEnsemble` lists that gate
which sub-commands a given interpreter may invoke.

**Rationale**: this turns a large command into a data-driven table instead of a
hand-written mega-`switch`, lets policy restrict individual sub-commands (for
example in a safe interpreter) without touching dispatch logic, and gives every
ensemble uniform introspection and uniform "unknown/ambiguous sub-command" error
reporting. It is the command-level counterpart to the host-capability composition
of pattern 5.

</details>

---

<details>
<summary><strong>46. <code>IClientData</code> -- Opaque Context Threading</strong></summary>

Callbacks, commands, policies, traces, and host operations receive an
`IClientData` -- an opaque carrier of arbitrary caller context -- alongside their
typed parameters. A family of concrete carriers (`ClientData`, `AnyClientData`,
and many domain-specific `*ClientData` types) wraps specific payloads, and a
`GetData`/`SetData` surface reads them back.

**Rationale**: the engine invokes user and plugin code through fixed delegate and
interface signatures; those signatures cannot grow a typed parameter for every
caller's needs. `IClientData` is the sanctioned escape hatch that threads caller
state through an otherwise fixed contract without resorting to `static` state. It
is the managed mirror of Tcl's native `ClientData` and of the interop-identity
handle in pattern 9.

</details>

---

<details>
<summary><strong>47. Three-Tier Method Layering (Public / Private / Core)</strong></summary>

Many operations are a small layered stack: a `public`/`internal` entry method that
validates arguments and acquires locks, a `PrivateX` method that holds the actual
logic and assumes its preconditions, and sometimes an even lower `XCore` or a
dedicated dispatcher beneath that. The large `*Ops` classes and `Interpreter` use
this shape repeatedly.

**Rationale**: it separates the guarded, documented public contract from the inner
implementation, so validation and locking live in exactly one place while the core
can be reused by several entry points -- and called recursively -- without
re-checking preconditions or re-entering a lock. It is the structural complement
to conventions 18 and 19 (validate and extract once, at the boundary).

</details>

---

<details>
<summary><strong>48. Optional Cache Instrumentation (<code>ICacheCounts</code> / <code>CACHE_STATISTICS</code>)</strong></summary>

The cache-bearing collections -- `CacheDictionary`, the various `*Cache*`
dictionaries, and the parse/argument caches -- implement `ICacheCounts` and carry
hit/miss/insert counters that are compiled in only under `#if CACHE_STATISTICS`.

**Rationale**: cache effectiveness must be measurable to be tuned, but
per-access counters are not free. Gating them behind a build symbol yields a
zero-overhead production build and a fully instrumented diagnostic build from a
single source -- pattern 12 (conditional compilation as architecture) applied at
the level of an individual data structure.

</details>

---

<details>
<summary><strong>49. Uniform Stringification (<code>IToString</code> / <code>ToString(ToStringFlags)</code>)</strong></summary>

Beyond `Object.ToString()`, the value-like and collection types implement an
`IToString`/`IStringList` surface with `ToString(ToStringFlags, ...)` overloads
that take explicit formatting flags (and often a separator or pattern). The list
containers render in canonical Tcl list format.

**Rationale**: a scripting engine needs one canonical, flag-controlled way to turn
any internal value into a script-visible string -- independent of, and richer
than, the default .NET `ToString()`. This is the *producing* side of the result
pipeline whose *consuming* side is the implicit `Result` conversion saturation of
pattern 7.

</details>

---

<details>
<summary><strong>50. The <code>Maybe*</code> Conditional-Action Naming Convention</strong></summary>

A method whose name begins with `Maybe` performs its action only when a runtime
condition warrants it, and is otherwise a deliberate no-op: `MaybeSet`,
`MaybeAdd`, `MaybeAddRange`, `MaybeDispose` (and the related `TryDispose`),
`MaybeEnableOrDisable`, `MaybeNewWrapperWith`. The prefix is a contract: "this may
do nothing, and that is a normal, expected outcome."

**Rationale**: a great deal of engine code is idempotent or best-effort -- set a
value if it is not already set, dispose an object if it is disposable, add an item
if it is non-null. Encoding the conditionality in the name, instead of making
every caller wrap the call in an `if`, keeps call sites clean and tells the reader
at a glance that the no-op path is intended rather than a bug. It is the
counterpart to the `Try*` idiom, distinguished by "did nothing" being success.

</details>

---

<details>
<summary><strong>51. Named Sentinels Instead of Magic <code>-1</code></strong></summary>

Out-of-band results -- "not found", "no index", "invalid count or length" -- are
named constants drawn from the `_Constants` types (`Index.Invalid`,
`Count.Invalid`, `Length.Invalid`, and their peers), not bare `-1` literals. They
are returned and compared by name throughout the engine.

**Rationale**: a bare `-1` says nothing about which axis it is invalid on or why;
`Index.Invalid` says both, is greppable, and gives the sentinel a single point of
definition. This is convention 21 (named constants over magic numbers) applied to
the specific, ubiquitous case of sentinel values, and it travels with the null-
and bounds-guards of conventions 18 and 26 -- the guard tests for the sentinel by
name before the value is trusted.

</details>

---

<details>
<summary><strong>52. <code>#if DEAD_CODE</code> -- Preserve, Don't Delete</strong></summary>

Superseded or experimental implementations are not deleted; they are retained,
compiled out, under `#if DEAD_CODE` (occasionally `#if false`), sitting beside the
current code that replaced them.

**Rationale**: in a codebase that prizes maximum compatibility and reversibility,
the previous implementation is documentation -- it records what was tried, why it
was replaced, and a ready fallback if a regression later surfaces. A
never-defined symbol guarantees the block never ships and never breaks a build,
while keeping it in plain view in the source rather than only in version-control
history. It is the code-block form of the document-every-deviation doctrine
(convention 24); these blocks are intentionally skipped when documenting members
(they are not part of any shipping build).

</details>

---

## References

- **Source code**: `Eagle/Library/` -- the complete Eagle core library
- **Key C# files**: `Interpreter.cs` (by far the largest file), `Engine.cs`,
  `Default.cs`, `Console.cs`, `ShellOps.cs`, `InteractiveOps.cs`,
  `ScriptOps.cs`, `MarshalOps.cs`, `HelpOps.cs`, `SyntaxOps.cs`,
  `DelegateOps.cs`, `DataOps.cs`, `ObjectOps.cs`, `CommandOptions.cs`,
  `NativeConsole.cs`, `AnsiConsole.cs`, `LineEditor.cs`
- **API documentation**: every type and member in `Eagle/Library/` carries an
  XML documentation comment (see convention 25); the generated XML doc file is
  the authoritative per-symbol reference and complements the patterns here.
- **Key script files**: `lib/Eagle1.0/init.eagle`, `test.eagle`,
  `object.eagle`, `platform.eagle`, `exec.eagle`, `auxiliary.eagle`,
  `lib/Test1.0/constraints.eagle`, `prologue.eagle`, `epilogue.eagle`
- **Related documentation**: [`options.md`](options.md) -- command option
  system architecture
