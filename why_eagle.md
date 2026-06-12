# Why Eagle?

> **For AI agents**: This document provides a high-level overview of Eagle's capabilities and comparisons with other languages. For command syntax, see [core_language.md](core_language.md). For worked examples, see [core_examples.md](core_examples.md). For script library procedures, see [core_script_library.md](core_script_library.md). For getting started, see [quick_start_guide.md](quick_start_guide.md). For tips and idioms, see [tips_and_tricks.md](tips_and_tricks.md). For the Garuda native Tcl package, see [garuda.md](garuda.md).

Eagle (Extensible Adaptable Generalized Logic Engine) is a scripting
language built from the ground up for the Common Language Runtime (CLR).
It speaks Tcl, lives inside your C# applications, and runs everywhere
the CLR does -- Windows, Linux, and macOS.

Architecturally, Eagle is a clean instance of what John Ousterhout called
the *dual-language model* in his 1998 essay *Scripting: Higher-Level
Programming for the 21st Century*: a small-kernel scripting layer (Tcl
semantics) driving a strongly typed primitive layer (the .NET CLR),
with the boundary between them made syntactically explicit via the
`[object]` command. The architectural rationale and the conventions
that fall out of it are developed at length in the companion
[whitepaper](whitepaper.md); this document gives the practical
orientation.

This document explains what makes Eagle different from other scripting
languages and where it excels.

---

## Core Strengths at a Glance

- **Deep .NET integration** -- create objects, call methods, access
  properties, subscribe to events, and link variables directly between
  scripts and C# code, all without writing a single line of glue.
- **Security first** -- safe interpreters, script signing, policy-based
  execution, and no JIT compiler to exploit.
- **Cross-platform** -- a single script runs on .NET Framework 2.0
  through .NET 10+, Mono, and every major operating system.
- **Embeddable** -- add a scriptable extension point to any C#
  application in a handful of lines.
- **Bidirectional native Tcl integration** -- the `[tcl]` command
  lets Eagle load and use native Tcl libraries; conversely, the
  Garuda package lets native Tcl load the CLR and use Eagle.
- **Multiple UI toolkits** -- WinForms, WPF, WinUI, Xamarin, and Tk
  (via the `[tcl]` command) are all usable, even simultaneously.
- **Universal Option Parser with typed flag enums** -- every command
  that takes a `[Flags]`-typed option (`-flags`, `-objectflags`,
  `-marshalflags`, `-bindingflags`, ...) accepts the same declarative
  mini-language for adding, removing, replacing, and masking flag
  values (`{+NonPublic +Static -DeclaredOnly}`), implemented once and
  shared across the entire command surface.
- **Runtime C# compilation** -- the `csharp.eagle` library compiles
  C# source into a loadable .NET assembly at runtime, so a script
  can extend its own primitive layer without redeploying the
  interpreter.

---

## Design Philosophy

Three principles, articulated at length in
[`architecture_patterns.md`](architecture_patterns.md), explain most
of the unusual choices in Eagle's codebase.

1. **Everything should be introspectable and customizable.** The
   system should be able to describe itself to anything that asks,
   and anything that asks should be able to change what it finds.
   This is why interpreter state is queryable as runtime data
   (`[info]` has eighty-six sub-commands), why the `# <help>`
   convention makes documentation a live runtime feature, and why
   hooks are named procedures discovered by `[info commands]` rather
   than registered through an API.
2. **Maximum backward compatibility.** A single codebase targets
   .NET Framework 2.0 RTM through .NET 10+, Mono, and .NET Standard
   2.0/2.1. Eleven `.csproj` files exist because each represents a
   real build configuration that someone depends on. The `#if`
   conditional-compilation system is a *compatibility architecture*,
   not feature flags: when a .NET API changes between versions,
   Eagle provides both paths rather than dropping support for the
   older one.
3. **Reliability over elegance.** When a choice exists between a
   pattern that looks clean and one that works correctly under all
   conditions (threading, disposal, platform differences, AppDomain
   boundaries), correctness wins. The 4,800-line
   `PrivateShellMainCore` method, the goto-based state machines, the
   six-phase interpreter disposal protocol, and the runtime
   immutability flags are all instances of this principle.

---

## How Eagle Compares

Each section below compares Eagle with another language ecosystem across
the three use cases where Eagle is strongest:

1. **Automating C# applications** -- embedding a scripting engine in
   your own .NET software.
2. **Automating native applications** -- scripting C and Tcl programs
   via the `[tcl]` command or the Garuda bridge.
3. **Standalone tools and test suites** -- writing utilities, CI
   pipelines, and comprehensive test harnesses.

### vs. Python / IronPython

Python is a general-purpose language with a vast library ecosystem.
IronPython brings Python syntax to .NET but has struggled to keep pace
with CPython releases.

| Area | Eagle | Python / IronPython |
|---|---|---|
| .NET embedding | First-class: `Interpreter.Create()`, add commands, link variables, enforce policies -- all with a stable, public API designed for embedding. | IronPython can be embedded, but the hosting API is heavier and IronPython 3.x lags behind CPython, creating a fragmented ecosystem. |
| Security | Safe interpreters restrict commands at a granular level. Script signing via Harpy/Badge ensures only approved code runs. No scripting-engine bytecode/JIT surface. | Python's `[exec]` / `[eval]` are difficult to sandbox. There is no built-in safe interpreter or script-signing infrastructure. |
| Cross-platform | One script, one engine: .NET Framework 2.0 through .NET 10+, Mono, Windows, Linux, macOS. | CPython is portable, but IronPython is limited to specific .NET versions and may lack packages that depend on CPython C extensions. |
| Native interop | The `[tcl]` command loads native Tcl libraries directly from Eagle; the Garuda package enables the reverse direction.  Both work cross-platform. | ctypes and cffi are powerful but require manual structure definitions and are outside the managed safety net. |
| Startup overhead | The Eagle interpreter is lightweight and designed for rapid instantiation inside a host process. | Python's import machinery and IronPython's DLR compilation add measurable startup latency. |

**Choose Eagle when** you need a scripting layer inside a C#
application with strong security guarantees.  **Choose Python when**
you need access to Python's enormous third-party library ecosystem
(data science, machine learning, etc.).

---

### vs. Ruby / IronRuby

Ruby is prized for its developer experience.  IronRuby targeted .NET
but has been effectively abandoned since 2012.

| Area | Eagle | Ruby / IronRuby |
|---|---|---|
| .NET integration | Actively maintained with support from .NET Framework 2.0 through .NET 10+. New .NET APIs are adopted as they ship. | IronRuby is unmaintained.  MRI Ruby has no native .NET integration. |
| Security model | Policy-based execution, safe interpreters, script signing. | Ruby lacks a built-in sandbox.  `$SAFE` levels were removed in Ruby 3.0. |
| Embeddability | Designed to be embedded: create an interpreter, register custom commands, and evaluate scripts in three lines of C#. | MRI Ruby's C API is not designed for .NET embedding; IronRuby's DLR-based API is complex and unsupported. |
| Testing | Built-in test framework (`[test]` command, `runTest` library procedure) with constraints, setup/cleanup blocks, and deep .NET introspection. | Ruby has excellent test tooling (RSpec, Minitest), but none of it can introspect or drive a .NET application natively. |

**Choose Eagle when** your target is .NET and you need a maintained,
embeddable engine.  **Choose Ruby when** you are building web
applications with Rails or need Ruby-specific gems.

---

### vs. JavaScript / TypeScript

JavaScript dominates the web.  Node.js brought it to the server.
However, neither was designed for .NET embedding or systems automation.

| Area | Eagle | JavaScript / TypeScript |
|---|---|---|
| .NET embedding | Purpose-built for it.  No bridge layer, no serialization boundary -- scripts manipulate .NET objects directly. | Embedding V8 or another JS engine in .NET requires a bridge (e.g., ClearScript, Jint) that introduces serialization overhead and API impedance. |
| Security | Safe interpreters remove dangerous commands entirely.  Script signing prevents unauthorized code.  No scripting-engine bytecode/JIT surface. | V8's JIT compiler has been a recurring source of security vulnerabilities.  Node.js has no built-in sandboxing (`vm` module is explicitly not a security mechanism). |
| Type system access | Eagle can reflect over any loaded .NET assembly, discover types, and invoke members -- including generics. | TypeScript types are erased at runtime.  JS engines have no knowledge of .NET types without an explicit binding layer. |
| Cross-platform | Runs on every platform the CLR supports, including legacy .NET Framework 2.0. | Node.js is portable, but embedding a JS engine in a .NET application adds a large native dependency. |

**Choose Eagle when** your application is .NET and you want scripts
that feel like a natural extension of your C# code.  **Choose
JavaScript when** you are building for the browser or the Node.js
ecosystem.

---

### vs. Bash / Zsh

Shell scripting is the default automation tool on Unix-like systems.

| Area | Eagle | Bash / Zsh |
|---|---|---|
| Platform support | Windows, Linux, and macOS with identical behavior. | Bash and Zsh are POSIX-only.  Windows support requires WSL, Cygwin, or MSYS2 -- all adding friction and subtle incompatibilities. |
| .NET integration | Scripts create .NET objects, call APIs, and link variables without leaving the language. | Shell scripts can invoke `dotnet` CLI tools but cannot interact with .NET APIs or objects in-process. |
| Security | Safe interpreters, script signing, and policy enforcement.  Scripts can be cryptographically verified before execution. | Shell scripts run with the full privileges of the invoking user.  There is no built-in signing or sandboxing mechanism. |
| Error handling | Structured return codes, exception interception from .NET, `[catch]` for error trapping, and `[try]`/`finally` for cleanup guarantees. | `set -e` and trap-based error handling are fragile and difficult to compose. |
| Data structures | Lists, dictionaries (`[dict]` command), arrays, and full access to .NET collections. | Arrays and associative arrays are limited and have inconsistent syntax across Bash versions. |
| Testability | Built-in test framework with constraints, setup, cleanup, and expected-result matching. | Testing shell scripts typically requires external frameworks (bats, shunit2) and is inherently brittle. |

**Choose Eagle when** you need cross-platform automation that works
identically on Windows and POSIX, or when your automation target is a
.NET application.  **Choose Bash when** you are writing short, Unix-
only glue scripts that primarily compose command-line tools.

---

### vs. PowerShell

PowerShell is Microsoft's task automation framework.  It is the
closest mainstream competitor to Eagle in the .NET scripting space.

| Area | Eagle | PowerShell |
|---|---|---|
| Embeddability | Embedding is a core design goal.  The API is small, stable, and well-documented.  Multiple interpreters can coexist in one process with independent security policies. | PowerShell can be hosted via `System.Management.Automation`, but the API surface is large, and the engine carries significant overhead. |
| Security | Safe interpreters remove commands at a granular level.  Script signing is built into the Harpy/Badge plugin system.  No scripting-engine bytecode/JIT surface. | Execution policies are advisory and easily bypassed.  Constrained Language Mode is coarse-grained.  The PowerShell JIT (via the DLR) has been a target for attacks. |
| Startup / footprint | The Eagle interpreter is compact and starts quickly -- suitable for short-lived automation tasks and high-frequency embedding. | PowerShell's startup cost is significant, making it less suitable for rapid, repeated invocations from a host process. |
| Cross-platform consistency | The same script on .NET Framework 2.0 and .NET 10+ on every OS.  Behavior differences are minimized by design. | PowerShell 5.1 (Windows-only) and PowerShell 7+ (cross-platform) have meaningful behavioral differences, creating a split ecosystem. |
| Native interop | The `[tcl]` command lets Eagle load and call into native Tcl libraries; the Garuda package lets native Tcl load and call into Eagle.  Both directions work cross-platform. | PowerShell can call native code via `Add-Type` and P/Invoke, but there is no equivalent bidirectional bridge for Tcl. |
| Tcl compatibility | Full Tcl 8.4 compatibility with selected 8.5/8.6 features.  Existing Tcl scripts and knowledge transfer directly. | No Tcl compatibility. |

**Choose Eagle when** you are embedding a scripting engine in your own
product, need fine-grained security, or want bidirectional integration
between .NET and native Tcl/C codebases.  **Choose PowerShell when** you need the built-in
cmdlet ecosystem for system administration tasks (Active Directory,
Exchange, Azure, etc.).

---

### vs. Tcl

Eagle is a Tcl implementation, so this comparison is about choosing
between Eagle and native Tcl (the C-based reference implementation).

| Area | Eagle | Native Tcl |
|---|---|---|
| .NET integration | Native and seamless -- Eagle *is* a .NET library.  Scripts create .NET objects, call methods, link variables, and catch .NET exceptions as first-class operations. | Requires a bridge (e.g., tclclr, SWIG bindings) that adds complexity and limits what is accessible. |
| Security | Safe interpreters (inherited from Tcl's model) plus script signing, policy enforcement, and no JIT compiler. | Safe interpreters exist but there is no built-in script signing or policy framework. |
| C/Native interop | Eagle's `[tcl]` command loads a native Tcl library directly, gaining access to Tk, Expect, and any C library reachable through Tcl.  In the reverse direction, the Garuda package lets native Tcl load the CLR and use Eagle via the `[eagle]` command. | Native by definition.  All Tcl extensions and C libraries are directly available. |
| Platform reach | Everywhere the CLR runs, including constrained environments where installing a native Tcl distribution is impractical. | Requires a native build for each platform.  Pre-built distributions are available for major platforms but not all. |
| Enterprise features | Harpy/Badge licensing and security plugins, AppDomain isolation, .NET assembly strong-name verification. | No built-in enterprise licensing or assembly verification. |
| Language level | Tcl 8.4 with selected 8.5/8.6 features and entirely new Eagle-specific commands for .NET integration. | Full Tcl 8.6+ with coroutines, `{*}` expansion, OO system (TclOO), and the complete standard library. |
| Performance | Interpreted (no bytecode).  Slower than native Tcl for pure computation.  Faster for workloads that would otherwise require crossing a managed/native boundary. | Tcl's bytecode compiler makes pure-Tcl code faster.  .NET interop requires a bridge with marshalling overhead. |

**Choose Eagle when** your application is .NET, you want Tcl's
language semantics with deep CLR integration, or you need enterprise
security features.  **Choose native Tcl when** you need maximum script
execution speed, the full TclOO object system, or the complete Tcl
extension ecosystem without a bridge.

---

## Security in Depth

Security is not an afterthought in Eagle.  It is a design principle
that influences every layer of the architecture.

### No JIT Compiler -- by Design

Eagle deliberately does not include a bytecode compiler or JIT.
Scripts are parsed and interpreted directly.

> Note: This refers to Eagle's *scripting engine* itself (i.e., scripts are not compiled to bytecode or native code by Eagle). The underlying CLR may still use a JIT to execute Eagle's C# implementation.

This is a **security feature**.  Historically, a large proportion of
scripting-language exploits have targeted bugs in internal compilers
and JIT engines -- buffer overflows in bytecode generation, type
confusion in JIT-compiled code paths, and speculative execution
side-channels in optimizing compilers.  By not having a compiler,
Eagle eliminates this entire attack surface.

Eagle is written in C# -- a memory-safe, managed language -- which
further reduces the risk of memory-corruption vulnerabilities in the
interpreter itself.

### Safe Interpreters

Eagle inherits and extends Tcl's safe-interpreter model.  A safe
interpreter is a restricted execution environment where dangerous
commands (file I/O, network access, process execution, etc.) are
removed entirely -- not merely permission-checked, but absent from
the command table.  This makes it impossible for untrusted scripts
to access resources that have not been explicitly granted.

Commands are classified via `CommandFlags` as safe or unsafe.  New
sub-commands and options added to safe commands must be explicitly
vetted before they are allowed in safe interpreters.

### Script Signing and Policy Enforcement

The Harpy and Badge plugins provide enterprise-grade script signing
and verification.  Scripts can be cryptographically signed, and the
interpreter can be configured to refuse execution of unsigned or
tampered scripts.  This closes the gap between "we reviewed this
script" and "this exact script is what ran in production."

Policy callbacks give the host application fine-grained control over
what scripts and commands are permitted at runtime, enabling dynamic
security decisions based on context.

### AppDomain Isolation

On .NET Framework, Eagle interpreters can run in isolated AppDomains,
providing an additional layer of separation between the host
application and the scripted code.  Plugins can also be loaded in
isolation, limiting the blast radius of a misbehaving extension.

---

## User Interface Capabilities

Eagle is not limited to headless automation.  Scripts can create and
drive graphical user interfaces through several toolkits:

- **WinForms** -- available on .NET Framework and Mono.  Load the
  assembly with `object load -import System.Windows.Forms` and create
  forms, controls, and dialogs from script.
- **WPF** -- available on .NET Framework and .NET 5+ on Windows.
  XAML-based UI definitions can be loaded and manipulated.
- **WinUI** -- available on .NET 6+ with the Windows App SDK.
- **Xamarin** -- for mobile and cross-platform desktop applications
  via Mono and .NET MAUI.
- **Tk** -- the classic Tcl/Tk toolkit is accessible through the
  `[tcl]` command, making it possible to use Tk on any platform
  where a native Tcl/Tk installation is available.

These toolkits can even be combined -- for example, a Windows
application can use WinForms for its main interface while using Tk
for specialized dialogs, or a Mono application on Linux can use
WinForms alongside Tk.

---

## Cross-Platform by Default

Eagle targets .NET Framework 2.0 as its baseline and supports every
subsequent .NET release through .NET 10+ and .NET Standard 2.0/2.1.
It also runs on Mono.

This means a single Eagle script can run on:

- Windows (x86, x64, ARM64)
- Linux (x64, ARM, ARM64)
- macOS (x64, ARM64)

without modification.  Platform-specific behavior is handled
internally, and the test infrastructure includes platform constraints
to validate behavior across environments.

This is a significant advantage over languages that are tied to a
single operating system family (Bash, Zsh) or that have platform-
specific behavioral differences (PowerShell 5.1 vs. 7+).

---

## Native Tcl Integration

Eagle and native Tcl can interoperate in two directions.  Both work
on all supported operating systems (Windows, Linux, macOS).

### Eagle to Native Tcl -- the `[tcl]` Command

Starting from the Eagle side, the `[tcl]` ensemble command
dynamically finds, loads, and uses a native Tcl library.  This
gives Eagle scripts access to:

- **Native Tcl extensions** -- Tk, Expect, and any Tcl package.
- **C libraries** -- anything reachable through Tcl's FFI
  (e.g., via `critcl` or `cffi`).
- **Bidirectional communication** -- commands and variables can
  be shared between the Eagle and native Tcl interpreters.

The native Tcl library can be unloaded when no longer needed.

### Native Tcl to Eagle -- the Garuda Package

Starting from the native Tcl side, the Eagle Native Package for
Tcl (Garuda) loads the CLR (or CoreCLR), dynamically finds and
loads the managed Eagle assembly, and makes it available via the
`[eagle]` command.  This enables:

- **Adding .NET capabilities to existing Tcl applications** --
  a native Tcl program can call into .NET APIs, create managed
  objects, and evaluate Eagle scripts without rewriting.
- **Incremental migration** -- existing Tcl codebases can adopt
  Eagle and .NET features gradually while the bulk of the code
  remains in native Tcl.
- **Optional cleanup** -- the managed Eagle assembly can be
  unloaded and the CLR shut down when finished.  (The CoreCLR
  cannot be fully unloaded once started; this is a .NET design
  limitation, not an Eagle limitation.)

---

## Why Not Eagle?

Eagle is not the right tool for every job.  Here are situations where
another language may be a better fit:

### Raw Script Execution Speed

Eagle is a pure interpreter with no bytecode compilation or JIT.  For
CPU-bound scripts that perform heavy computation in pure script code
(tight numeric loops, large-scale string processing), native Tcl,
Python, or JavaScript will be faster.

However, Eagle scripts that delegate computation to .NET APIs --
which is the common pattern for real-world automation -- spend most of
their time in compiled .NET code and are not meaningfully slower than
the alternatives.

### No .NET Runtime Available

Eagle requires the .NET CLR.  On embedded systems, bare-metal
environments, or platforms where .NET is not available, Eagle cannot
run.  In these cases, native Tcl, Lua, or Python may be appropriate.

### Python / JS Library Ecosystem

If your primary need is access to the Python data-science ecosystem
(NumPy, pandas, TensorFlow) or the npm/Node.js ecosystem, Eagle does
not provide equivalents.  Use the language whose ecosystem matches
your requirements.

### Full Tcl 8.6+ Features

Eagle is compatible with Tcl 8.4 and incorporates selected features
from 8.5 and 8.6, but it does not implement the complete Tcl 8.6+
feature set.  Notably, TclOO, `{*}` argument expansion, and
coroutines are not available.  If your project depends on these
features, native Tcl is the right choice.

---

## Getting Started

| Resource | Link |
|---|---|
| Source Code | https://urn.to/r/code |
| Documentation | https://urn.to/r/docs |
| Package Client Toolset | https://urn.to/r/pkgt |
| Live Demo | https://urn.to/r/demo |
| Discord Community | https://urn.to/r/discord |

Eagle is freely available open-source software.  See the
`license.terms` file in the repository for details.

### Further Reading

The following companion documents go deeper than this overview:

- **[`whitepaper.md`](whitepaper.md)** -- the long-form
  architectural argument: the dual-language model, the explicit
  boundary, the conventions that fall out, the divergences from
  mainstream "best practice," the costs, and the aesthetic case for
  why the conventions produce code that is more likely to be
  correct.
- **[`architecture_patterns.md`](architecture_patterns.md)** -- a
  catalog of thirty-one deliberate, non-obvious design patterns
  found throughout the Eagle codebase, each with its rationale.
  Read this when a piece of the source code looks like it shouldn't
  work that way and you want to know why it does.
- **[`paper_love_and_software.md`](paper_love_and_software.md)** --
  a companion paper to the whitepaper, arguing that the
  characteristics described in the architecture documents emerge
  only under sustained intrinsic motivation. The architectural
  argument and the motivational argument describe the same
  phenomenon from different sides.
- **[`core_language.md`](core_language.md)** -- the full command
  catalog with syntax, options, and worked examples.
- **[`core_script_library.md`](core_script_library.md)** -- the
  five-hundred-plus script-library procedures organized by
  package.
- **[`safe.md`](safe.md)** -- the safe-interpreter security model
  in detail: command hiding, option flag enforcement, sub-command
  allow-lists, policy callbacks, and resource limits.
