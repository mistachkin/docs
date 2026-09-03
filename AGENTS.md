# AGENTS.md — Eagle Documentation Navigation Guide

This repository contains the canonical Markdown documentation for the **Eagle
scripting language** and its **core script library**.

This file is written for AI agents (and humans) who need to **answer questions
accurately**, **locate the right reference quickly**, and **avoid Tcl-assumption
pitfalls** when working with Eagle.

---

## Golden rules for working in this repo

1. **Retrieve first, then answer.**
   Do not rely on memory for Eagle command/procedure syntax. Use the documentation.

2. **Decide: command vs procedure.**
   - Core language **commands** (built-ins): use `core_language.md`.
   - Script library **procedures** (from `.eagle` packages): use
     `core_script_library.md`.

3. **Eagle is Tcl-compatible, not Tcl-identical.**
   Many Tcl idioms work, but some classic Tcl features are intentionally missing
   or different. If you find yourself “assuming Tcl”, stop and verify in the
   documentation.

4. **Prefer documentation anchors, not scrolling.**
   Both main documents are structured for fast lookup by name.

---

## Repository map

| File | What it contains | When you use it |
|------|------------------|-----------------|
| `why_eagle.md` | Feature overview, language comparisons, security model, and use-case guidance | When explaining Eagle's advantages, comparing it to other languages, or making a case for adoption |
| `innovation.md` | Evidence-based audit of Eagle's distinctive algorithms, language and CLR boundaries, security architecture, integration model, testing practices, documentation feedback loop, coding conventions, and first-party ecosystem | When answering “What is unique or innovative about Eagle?” or when a claim must distinguish original implementation, unusual integration, and systematic practice |
| `whitepaper.md` | "Two Languages, On Purpose" — the dual-language architecture thesis: a scripting layer over typed .NET (extends Ousterhout's scripting essay) | When making the design/philosophy case for Eagle's two-language model, or explaining *why* it pairs a script engine with the CLR |
| `paper_love_and_software.md` | Essay by Joe Mistachkin — "If You Want a Project to Be Good, You Have to Love Working on It" | When you want the author's philosophy on software quality and craftsmanship |
| `quick_start_guide.md` | Getting started guide: obtaining Eagle, running the shell, language basics, .NET interop intro | When new users need to get up and running or when explaining Eagle basics |
| `tutorial.md` | The Eagle Tutorial for Tcl programmers — a paced, contrast-driven course that assumes the reader did the official Tcl Tutorial first and teaches only the Eagle deltas (booleans render `True`/`False`, base-10 decimal literals, integer wrap/no bignum promotion, no namespace "creative reading/writing", no `{*}` expansion, .NET regex, `exec` non-zero-exit, etc.) plus Eagle-only features (`[object]` .NET interop, sandboxing, plugins, hosts, testing); links back to each Tcl Tutorial lesson and forward to the reference docs | When teaching Eagle to someone who knows Tcl, or when you need a differences-focused learning path (vs. the reference catalogs) |
| `showcase.md` | A curated "greatest hits" gallery of capabilities unique to Eagle (or done very differently from stock Tcl): full .NET/CLR interop via `[object]`, runtime C# compilation (`compileCSharp`), base-10 decimal `[expr]` plus Eagle-only operators/functions and the Unicode math symbols (∞/π/ℇ), capability-based safe-interpreter sandboxing, the `[sql]` ADO.NET bridge, Harpy script signing (`[ksource]`/`b64sign`/`[certificate]`/`[keyring]`), and the two-way native-Tcl bridges (`[tcl]` and Garuda). Non-Harpy examples are execution-verified; Harpy examples are drawn from its test suite | When you want to demonstrate or motivate Eagle's distinctive strengths, pick an impressive worked example, or answer "what can Eagle do that Tcl can't?" |
| `embedding.md` | How to embed Eagle in a C# application: the `Interpreter`/`ReturnCode`/`Result` model, creating/evaluating/disposing interpreters, exchanging data (variables, linked variables), adding custom commands/functions/plugins, calling .NET from scripts and injecting live C# objects, custom hosts, sandboxing untrusted scripts, cancellation/timeouts/resource limits, the threading model, AppDomain isolation, and deployment/NuGet | When you need to host Eagle inside a .NET application, drive the interpreter from C#, extend it with native commands, or sandbox untrusted scripts programmatically |
| `core_language.md` | Eagle command catalog (built-ins), organized by category; includes advanced topics | When you need command syntax, options, behavior, or Eagle-only extensions |
| `core_examples.md` | Contains 500+ worked examples for every command and sub-command, organized by category | When you need usage examples, idiomatic patterns, or practical demonstrations |
| `core_script_library.md` | Contains 580+ library procedures (script-level utilities), organized by package and source file | When you need helper procedures, test utilities, file helpers, platform detection, etc. |
| `tips_and_tricks.md` | Eagle-unique features, advanced idioms, and best practices not found in standard Tcl | When looking for Eagle-specific patterns, performance tips, or unique capabilities |
| `exec.md` | Deep-dive analysis of the `[exec]` command: argument processing, command-line building, escaping, and differences from native Tcl | When you need to understand exec's quoting/escaping algorithm, the three argument assembly paths, or why Eagle exec behaves differently from Tcl exec |
| `scope.md` | Deep-dive analysis of the `[scope]` command: persistent named variable environments, call frame stack model, cloning, locking, namespace integration, and global scope redirection | When you need to understand how scopes work, implement persistent state across procedure calls, or use thread-safe shared state |
| `tcl.md` | Deep-dive analysis of the `[tcl]` command: native Tcl library loading, interpreter management, command bridging, function pointer marshalling, and bidirectional Eagle/Tcl integration | When you need to understand how Eagle embeds native Tcl, bridge commands between runtimes, or use native Tcl packages from Eagle |
| `library.md` | Deep-dive analysis of the `[library]` command: P/Invoke-style FFI, dynamic delegate creation via Reflection.Emit, module lifecycle/reference counting, marshalling, architecture and certificate verification | When you need to understand how Eagle calls native C functions, the dynamic delegate type creation mechanism, or module lifecycle management |
| `interp.md` | Deep-dive analysis of the `[interp]` command: interpreter lifecycle, safe interpreter security model, command hiding, policy-based access control, resource limits, execution timeouts, and cross-interpreter communication | When you need to understand interpreter management, the safe interpreter security model, policy callbacks, resource limits, or how to sandbox untrusted code |
| `load.md` | Deep-dive analysis of the `[load]`/`[unload]` commands: .NET plugin loading infrastructure, security verification chain (strong name, Authenticode, public key token), AppDomain isolation, built-in plugins, enterprise plugins (Harpy, Badge, HotKey, Zeus, Demo, Featherlight, Aquila, Kapok), and plugin lifecycle management | When you need to understand how Eagle loads/unloads .NET plugins, the security verification pipeline, AppDomain isolation, PluginFlags, or the enterprise plugin ecosystem |
| `harpy.md` | **Harpy** (Eagle Enterprise Edition) — security & licensing: license certificates, script signing/verification, execution policies (`[harpy]`) | When you need Harpy's sub-commands, the certificate/signing model, or license verification |
| `badge.md` | **Badge** (EEE) — signed script certificate resources + a runtime string-override mechanism (`[badge]`) | When you need `[badge]` sub-commands or embedded signed-script certificate management |
| `kapok.md` | **Kapok** (EEE) — web server with sandboxed script evaluation, API-key token access control, and request throttling (`[kapok]`) | When you need the `[kapok]` web-server commands, sandboxed evaluation, or rate limiting |
| `zeus.md` | **Zeus** (EEE) — managed environment, cryptographic operations, CLR method hooking, and script encryption (`[zeus]`) | When you need `[zeus]` sub-commands, method hooking, RFC 2898 key derivation, or script encryption |
| `demo.md` | **Demo** (EEE) — the worked example of a host-swapping plugin (`[demo]`) | When you need a reference host-swapping plugin implementation or the `[demo]` commands |
| `hotKey.md` | **HotKey** (EEE) — system-wide (global) hot-key registration that runs scripts, plus a WinForms management UI (`[hotkey]`) | When you need the `[hotkey]` commands or the global hot-key / GUI subsystem |
| `sql.md` | Deep-dive analysis of the `[sql]` command: ADO.NET database access, `-variable` options with DbTraceCallback for automatic resource cleanup, script bundle databases (signed SQLite-based script containers), query execution pipeline, parameter binding, result formatting, transaction management, and performance profiling | When you need to understand database operations, automatic connection/transaction cleanup, the script bundle system, parameterized queries, or provider type resolution |
| `regexp.md` | Deep-dive analysis of the `[regexp]`/`[regsub]` commands: .NET `System.Text.RegularExpressions` integration, default `Singleline` behavior (dot matches newlines, like Tcl — opposite of .NET's own default), Tcl-to-.NET substitution translation (`TranslateSubSpec`), three replacement modes (normal, `-eval`, `-command`/TIP #463), `-extra` extended substitutions (`\P`, `\I`, `\S`, `\M#`, `\N<name>`), pattern mutation prefixes (`***=`, `***:`), and all Eagle-specific options | When you need to understand regex behavior differences from Tcl, substitution translation, the three regsub modes, named group references, or the many Eagle-specific regex options |
| `uri.md` | Deep-dive analysis of the `[uri]` command: 18 sub-commands for URI construction/parsing/validation, HTTP download/upload (sync and async), four per-interpreter web callbacks (`PreWebClientCallback`, `NewWebClientCallback`, `WebTransferCallback`, `WebErrorCallback`), custom `WebClient`-derived classes (`TagAndTimeoutWebClient`, `ScriptWebClient`), async transfers with `CommandCallback` script evaluation, retry infrastructure, offline mode, and security protocol management | When you need to understand HTTP operations, async downloads/uploads with callbacks, custom WebClient configuration, the web callback chain, retry logic, or URI utility operations |
| `package.md` | Deep-dive analysis of the `[package]` command: 23 sub-commands, multi-source index discovery pipeline (host, filesystem, plugin, bundle), tagged package indexes (`pkgIndex_XXXX.eagle` with `$tag` variable), auto-path system and interpreter initialization, package aliases with circular-reference detection, security verification (Authenticode, StrongName, locked/rejected packages), the four-stage `[package require]` fallback chain, `PackageFallback` delegate, `.noPkgIndex` disable markers, and all `PackageFlags`/`PackageIndexFlags` | When you need to understand package management, index discovery, tagged indexes, auto-path construction, package aliases, security verification during scanning, the require fallback chain, or package lifecycle (provide/withdraw/forget) |
| `clock.md` | Deep-dive analysis of the `[clock]` command: 15 sub-commands, Tcl-to-.NET format string translation (static mappings + `ClockTransformCallback` delegates for `%s`, `%j`, `%V`, `%Z`, `%Q`), custom epoch support (Unix, Build, PE, user-defined), high-resolution performance counters (`[clock start]`/`stop`), ISO 8601 formatting, .NET ticks, `ClockData`/`IClockData` interface, fake time injection, and safe interpreter timing restrictions | When you need to understand time formatting/parsing, format specifier translation, custom epochs, high-resolution timing, build numbering, or calendar operations |
| `string.md` | Deep-dive analysis of the `[string]` command: 29 sub-commands, 64-class `[string is]` type-checking system (18 per-character + 46 whole-string), culture-aware comparison via `CultureInfo`/`CompareOptions`, extended `[string map]` with `-regexp`/`-eval`/`-multipass`/`-maximum`/`-countvar`, `[string format]` .NET `String.Format` integration, `MatchMode` enumeration, character classification callbacks (`CharIsWord`, `CharIsAscii`, `CharIsGraph`, `CharIsReserved`), and `StringBuilderFactory`/`StringBuilderCache` optimization | When you need to understand string operations, the type-checking system, culture-aware comparison, extended mapping/substitution, format string integration, or character classification |
| `file.md` | Deep-dive analysis of the `[file]` command: 54 sub-commands, Windows ACL/SDDL security descriptors, PE file magic number inspection, three-tier access verification (`VerifyReadable`/`VerifyWritable`/`AccessCheck`), advanced globbing with `MatchMode` (Exact, Glob, Regexp, SubString), cryptographic temporary path generation, interpreter cleanup management, `[file under]` containment checks, `[file validname]` path validation, `GetDateTimeCallback`/`SetDateTimeCallback` delegates, and platform-specific P/Invoke (`stat`/`lstat` on Unix, `BY_HANDLE_FILE_INFORMATION` on Windows) | When you need to understand file operations, path validation, Windows security descriptors, access control, temporary file infrastructure, globbing, or platform-specific file behavior |
| `info.md` | Deep-dive analysis of the `[info]` command: 85 sub-commands, safe interpreter sub-command filtering via `PolicyOps.AllowedInfoSubCommandNames`, obfuscated procedure protection (`ProcedureFlags.Obfuscated`), .NET reflection integration (`Assembly`, `FileVersionInfo`, assembly attributes), engine metadata (9 `EngineAttribute` values), `[info commands]` with 18+ filtering options (`-safe`, `-unsafe`, `-hidden`, `-sdk`, `-core`, `-library`), `[info cmdtype]` (proc/alias/object/ensemble/native), platform variable caching with refresh restrictions, `[info culture]`/`[info cultures]` for localization, Windows window enumeration (`[info hwnd]`/`[info windows]`/`[info windowtext]`), database introspection (`[info connections]`/`[info transactions]`), and processor count masking in safe interpreters | When you need to understand interpreter introspection, command/procedure/variable queries, safe interpreter restrictions on info, engine version metadata, .NET reflection from scripts, or platform/environment queries |
| `namespace.md` | Deep-dive analysis of the `[namespace]` command: 22 sub-commands, dual-implementation architecture (Namespace1 compatibility stub vs. Namespace2 full implementation), `INamespace` object model with parent-child hierarchy and reference counting, name resolution algorithm (`GetBase` → `GetDescendant` traversal), call frame integration (`VariableFrame`, `ResolveData` per frame), import/export mechanism via `IAlias` with `NamespaceImport` flag, per-namespace unknown handler, namespace mappings for name remapping, pluggable `IResolve` resolver per namespace, `[namespace enable]`/`[rename]`/`descendants`/`[info]`/`mappings` Eagle extensions, and `[scope attach]`/`detach`/`export`/`import` integration | When you need to understand namespace management, the dual-implementation architecture, name resolution, call frame binding, import/export, per-namespace unknown handlers, or scope-namespace interoperability |
| `array.md` | Deep-dive analysis of the `[array]` command: 17 sub-commands, 8 polymorphic storage backends (`ElementDictionary`, environment, `System.Array`, thread, database, network, registry, tests), `[array copy]` with `-deep` option, `[array default]` (TIP #508) for missing-key defaults, `[array random]` with 5 options (`-strict`, `-pair`, `-valueonly`, `-matchname`, `-matchvalue`), `[array for]`/`[foreach]`/`[lmap]` iteration, per-element flags via `VariableFlagsDictionary`, `VariableFlags` enum (Array, ReadOnly, Virtual, System, Dirty, BreakOnGet/Set/Unset), `ArraySearch` stateful iteration, trace integration (`FireArraySetTraces`), and thread-safe locking | When you need to understand array operations, storage backends, default values, deep copy, random access, iteration patterns, per-element flags, or variable trace integration |
| `host.md` | Deep-dive analysis of the `[host]` command: 33 primary sub-commands + 8 nested `[host screen]` sub-commands, 15-interface host hierarchy (`IHost` aggregating `IInteractiveHost`, `IStreamHost`, `IColorHost`, `IBoxHost`, `IPositionHost`, `ISizeHost`, `IReadHost`, `IWriteHost`, `IDebugHost`, `IThreadHost`, `IFileSystemHost`, `IProcessHost`, `IInformationHost`, `IDisplayHost`), `Default` → `Shell` → `Core` → `Console` class hierarchy, console lifecycle safety interlocks (`closeCount`/`referenceCount`/`mustBeOpenCount` atomic counters, `SystemConsoleMustBeOpen()` guards, read/write level tracking, `CheckActiveReadsAndWrites()`, kiosk mode lock, `ConsoleOps.IsShared()` cross-AppDomain detection), Windows-native screen buffer management (push/pop stack via `CreateConsoleScreenBuffer`/`SetConsoleActiveScreenBuffer` P/Invoke, standard handle redirection, `BreakpointDictionary`-style `IntPtrDictionary` storage), `HostFlags` (60+ capability flags), `HostCreateFlags` (30+ creation flags), `HostSizeType` for buffer/window sizing, `OutputStyle` for formatting modes, `[host writebox]` with theme/color/position control, `[host font]` Windows console font, and `[host color]`/`[host namedcolor]` themed color management | When you need to understand the host system, console lifecycle, safety interlocks, screen buffer management, color/box/position/size control, capability flags, stream redirection, or any of the 41 host sub-commands |
| `interpreter_host.md` | Formal specification of the interpreter **host subsystem** — the `IHost` abstraction between the engine and its environment (complements the `[host]` command) | When you need the host-interface architecture, a custom host implementation, or the engine↔environment boundary (vs. the `[host]` command in `host.md`) |
| `object.md` | Deep-dive analysis of the `[object]` command: 44 sub-commands, opaque handle system (`ObjectDictionary` → `ObjectWrapper` → `ObjectData`), `FixupReturnValue` pipeline, `FindMethodsAndFixupArguments` method overload resolution (~1,500 lines), `ObjectFlags` (40+ flags: `NoDispose`/`AutoDispose`/`Alias`/`Locked`/`ForceNew`/`AllowExisting`), `MarshalFlags` (30+ flags: `StrictMatchCount`/`StrictMatchType`/`ReorderMatches`/`HandleByValue`), `ByRefArgumentFlags`, reference counting (`ReferenceCount`/`TemporaryReferenceCount` with `ObjectReferenceType`), command alias dispatch, assembly trust/strong-name verification, type aliases, namespace imports, and comprehensive practical patterns | When you need to understand .NET interop architecture, object lifecycle, handle management, method resolution, marshalling, assembly loading, or any of the 44 object sub-commands |
| `debug.md` | Deep-dive analysis of the `[debug]` command: 65+ sub-commands, dual-context suspend/resume debugger architecture (every property stored as Current/Saved pair with reference-counted suspend/resume), `BreakpointType` enum (40+ flags covering token, command, variable, cancel, error, exit, procedure, expression phases with composite presets: Common, Standard, Express, Default), `DebugEmergencyLevel` lifecycle control (create/dispose/reset/enable/disable/break with feature flags for tokens, isolated interpreters, verbosity), `HeaderFlags` display control (25+ information sections), `InteractiveLoopData` breakpoint context, `BreakpointDictionary` two-level file→location lookup, `[debug break]` demand breakpoints, `[debug secureeval]` sandboxed child evaluation with timeout/trust/event controls, `[debug invoke]` call-frame-level execution, `[debug watch]` variable watchpoints (`BreakOnGet`/`BreakOnSet`/`BreakOnUnset`), `[debug token]` file/line breakpoints, `[debug trace]` with 20+ configuration options, script bundling (`bundle`/`mount`/`unmount`), and re-entry prevention mechanisms | When you need to understand the debugger architecture, breakpoint management, variable watchpoints, emergency recovery, secure evaluation, trace configuration, script bundling, or any of the 65+ debug sub-commands |
| `safe.md` | Safe interpreter security model: five-layer defense-in-depth (command hiding, option flags, sub-command allow-lists, policy callbacks, resource limits), 16 resource limit categories, cross-interpreter aliases for capability delegation, .NET type access control, script signature verification, enterprise lockdown mode, comparison with Tcl Safe Tcl, and practical use cases (plugin sandboxing, config evaluation, multi-tenant execution) | When you need to understand how to sandbox untrusted code, the safe interpreter security guarantees, how policies work, resource limits, cross-interpreter communication, or how Eagle's model compares to Tcl |
| `architecture_patterns.md` | Eagle's experimental and unorthodox design patterns: intentionally mutable statics, goto state machines, runtime immutability enforcement, six-phase disposal, trait-based host composition, polymorphic variable backends, 30+ implicit Result conversions, Reflection.Emit delegate generation, GCHandle pinning, ObjectId GUID tracking, 1400+ HACK comments, conditional compilation architecture, TSV syntax data, Utility facade, script-level meta-programming, TryLock/ExitLock contract, and StorageOps command composition trees | When you need to understand WHY Eagle's code looks the way it does, or before making changes that might fight the existing design philosophy |
| `options.md` | Command option system architecture: `OptionDictionary`, `OptionFlags` enum (30+ value-constraint and safety flags), `CommandOptions` centralized factory (200 enum values), `CommandOptionType` dispatch, three parsing methods (`GetOptions`/`CheckOptions`/`ScanOptions`), mutual-exclusion groups, two-pass and scan-then-get patterns, interpreter-dependent defaults, composed option dictionaries, conditional compilation guards, and the `Unsafe`/`Unsupported`/`Ignored` safety model | When you need to understand the option parsing infrastructure, how commands define and consume options, the `CommandOptions` centralization architecture, option flag semantics, special parsing patterns (two-pass, deferred defaults), or the relationship between `CommandOptions` and `ObjectOps` |
| `garuda.md` | The Eagle Native Package for Tcl (Garuda) reference | When you need to integrate with Eagle via a native Tcl environment |
| `integrations.md` | Eagle's four official integration sub-projects: MSBuild, WiX, PowerShell, MonoDevelop | When you need to use Eagle from MSBuild builds, WiX installers, PowerShell, or MonoDevelop |
| `updater.md` | Eagle Updater (Hippogriff) architecture and design analysis | When you need to understand the update mechanism, its security model, or its configuration |
| `build_system.md` | Eagle Build System (POSIX) reference — building, testing, and installing Eagle on Linux/macOS with the official `Makefile`, plus the native (Garuda/Spilornis) build | When you build/test/install Eagle from source on POSIX systems, or need the build-time configuration |
| `index.md` | Documentation index / landing page for the whole doc set (mirrors `README.md`) | When you want a top-level table of contents for the documentation |
| `AGENTS.md` | You are here | How to navigate and answer accurately |

---

## Fast lookup workflow

### Step 1 — Identify the thing you need
Ask yourself:

- "Is this a **built-in command** like `[exec]`, `[object]`, `[info]`, `[string]`?"
  → Go to `core_language.md` for syntax; `core_examples.md` for usage examples.

- "Is this a **procedure** like `getDictionaryValue`, `readFile`,
  `execShell`, `isWindows`?"
  → Go to `core_script_library.md`.

- "How do I use Eagle from **MSBuild**, **WiX**, **PowerShell**, or
  **MonoDevelop**?"
  → Go to `integrations.md`.

- "How does the Eagle **updater** work?" or "What is **Hippogriff**?"
  → Go to `updater.md`.

If you're unsure:
- Search both by name. Commands are typically shorter / more Tcl-like; library
  procedures are usually more descriptive and live in named `.eagle` modules.

### Step 2 — Use the documentation’s built-in navigation
#### For commands
`core_language.md` is explicitly designed for AI-agent lookup:

- Use anchors of the form: `#cmd-NAME`
  - Example: `core_language.md#cmd-exec`
  - Example: `core_language.md#cmd-object`
- Use the **Alphabetical Command Index** in that file.

#### For procedures
`core_script_library.md` is also designed for name-based lookup:

- Use the **Alphabetical Procedure Index**.
- Each procedure is documented under a `#### procedureName` heading inside its
  source file section.

If a Table-of-Contents link appears broken (rare, but possible), use text search
for the heading (e.g., search for `### Database Utilities` or `#### getRowColumnValue`).

### Step 3 — Cross-check for Eagle-specific options and caveats
Many Tcl-compatible commands have **Eagle extension options** or enhanced
behavior. In `core_language.md`, those are called out explicitly.

If an option list is long (e.g., `[exec]`), resist summarizing from memory:
quote or paraphrase only what you confirmed in the documentation.

---

## Core language documentation orientation

### What `core_language.md` is
- A comprehensive catalog of Eagle commands (built-ins), organized by functional
  category (Control Flow, Variables, Strings, Objects, Testing, etc.).
- Includes “advanced topics” sections that explain important interpreter
  subsystems and security behavior.

### Where the “Eagle-unique” pieces are called out
In `core_language.md`, use:
- **Eagle Extensions Quick Reference**
- **Eagle-enhanced Tcl commands** notes (e.g., `[exec]`, `[regexp]`, `[vwait]`, `[load]`)

### Big features you’ll reach for often

#### .NET / CLR integration
If the task involves .NET types, assemblies, reflection, or runtime control:
- Start at: `[object]` command and the **Objects / .NET Interop** section.
- For a deep-dive on the opaque handle system, FixupReturnValue pipeline,
  method overload resolution, ObjectFlags, MarshalFlags, and all 44 sub-commands,
  see [`object.md`](object.md).
- **No Tcl equivalent** — Tcl has no built-in .NET interop; Eagle's `[object]`
  command is the primary bridge between scripts and the CLR.
- Typical workflow:
  - `[object load]` to load an assembly (if needed)
  - `[object import]` to shorten type names
  - `[object create]` to instantiate
  - `[object invoke]` to call members
  - `[object dispose]` for lifecycle cleanup
- Key patterns:
  - `object create -alias System.Text.StringBuilder` — alias-based method dispatch
  - `object invoke -flags +Static System.IO.File ReadAllText $path` — static method call
  - `object foreach -alias item in $list { $item ToString }` — collection iteration
  - `object create -objectflags +NoDispose System.Guid $str` — suppress auto-disposal
  - `object invoke -marshalflags +ReorderMatches $obj Method $args` — flexible overload resolution
  - `object invoke -parametertypes [list Int32 String] $obj Method 42 hello` — explicit overload selection
  - `object dispose -flags +Force $handle` — force disposal of locked objects

#### External processes and tooling
If you need to run compilers, formatters, linters, test runners, etc.:
- Start at: `[exec]` in the **Native Environment** section.
- For a deep-dive on argument processing, quoting, escaping, and Tcl
  differences, see [`exec.md`](exec.md).
- Eagle’s `[exec]` is more featureful than Tcl’s:
  - variable-based stdin
  - separate stdout/stderr capture
  - exit code capture
  - timeouts
  - background execution
  - shell execution mode
  - callbacks for streaming output
  - command-line building with `-commandline`, `-forprocessor`, `-escaperanges`
  - custom escape and pre-processing hooks

> Important: Eagle does not use Tcl’s pipeline / redirection syntax. Use `[exec]`
> options instead. See [`exec.md`](exec.md) for the full comparison.

#### Persistent state and variable scopes
If the task involves persistent state across procedure calls, coroutine-like
patterns, thread-safe shared state, or sandboxed global environments:
- Start at: `[scope]` in the **Variables / Data** section of `core_language.md`.
- For a deep-dive on the call frame stack model, cloning, locking, namespace
  integration, and global scope redirection, see [`scope.md`](scope.md).
- Key patterns:
  - `scope create -open -clone -args $name` — idempotent persistent counter
  - `scope create -open -procedure -args` — per-procedure private state
  - `scope eval -lock name { script }` — thread-safe shared access
  - `scope global name` — sandboxed global environment

#### Native library FFI (P/Invoke)
If the task involves calling native C functions, loading shared libraries,
or P/Invoke-style foreign function interface:
- Start at: `[library]` in the **Native Environment** section of `core_language.md`.
- For a deep-dive on dynamic delegate creation, module lifecycle, marshalling,
  and architecture verification, see [`library.md`](library.md).
- Typical workflow:
  - `[library load]` to load a native shared library
  - `[library declare]` to define a function signature (creates delegate type via Reflection.Emit)
  - `[library call]` to invoke the native function
  - `[library undeclare]` / `[library unload]` for cleanup
- Key patterns:
  - `library declare -module $m -functionname F -returntype IntPtr` — combined declare+resolve
  - `library load -trustedonly signed.dll` — certificate-verified loading
  - `library matcharchitecture mylib.dll` — architecture compatibility check

#### Plugin loading and management
If the task involves loading .NET plugins, extending the interpreter with
compiled assemblies, or understanding the plugin security model:
- Start at: `[load]` / `[unload]` in the **Native Environment** section of `core_language.md`.
- For a deep-dive on the plugin infrastructure, security verification,
  AppDomain isolation, and enterprise plugins, see [`load.md`](load.md).
- Typical workflow:
  - `load /path/to/Plugin.dll` to load a plugin (auto-discovers `IPlugin` type)
  - `load -verifiedonly -trustedonly Plugin.dll` for security-verified loading
  - `load -isolated Plugin.dll` for AppDomain-isolated loading
  - `unload /path/to/Plugin.dll` to unload
- Key patterns:
  - `load -ruleset $rs Plugin.dll` — filter which commands/policies are registered
  - `load -viaresource "Plugin.dll.compressed"` — load from embedded resource
  - `load -publickeytoken "..." Plugin.dll` — require specific publisher
  - `unload -nocomplain -match Glob Plugin.dll *Enterprise*` — flexible unloading

#### Enterprise (EEE) plugins
The eight **Eagle Enterprise Edition** plugins live in
`Eagle/Plugins/Commercial/Enterprise/`. **By default they require a valid license
certificate to load; however, they are now also open source.** Six have a
dedicated command reference:

- [`harpy.md`](harpy.md) — **Harpy**: security & licensing (certificates, script
  signing/verification, execution policies)
- [`badge.md`](badge.md) — **Badge**: signed script certificate resources and a
  string-override mechanism
- [`kapok.md`](kapok.md) — **Kapok**: web server with sandboxed script evaluation,
  token access control, and throttling
- [`zeus.md`](zeus.md) — **Zeus**: managed environment, cryptography, CLR method
  hooking, and script encryption
- [`demo.md`](demo.md) — **Demo**: the worked example of a host-swapping plugin
- [`hotKey.md`](hotKey.md) — **HotKey**: global hot-key registration with a
  WinForms management UI

For the loading/verification infrastructure itself (the security chain, AppDomain
isolation, and `PluginFlags`), see [`load.md`](load.md). Aquila and Featherlight
are also enterprise plugins but do not yet have dedicated command docs.

#### Database operations (ADO.NET)
If the task involves database access, SQL queries, transactions, or
script bundle databases:
- Start at: `[sql]` in the **Database** section of `core_language.md`.
- For a deep-dive on the query execution pipeline, `-variable` auto-cleanup,
  script bundles, and provider types, see [`sql.md`](sql.md).
- Typical workflow:
  - `sql open -variable conn -type SQLite "connStr"` — auto-cleanup connection
  - `sql execute $conn "SELECT ..." {param Type value}` — parameterized query
  - `sql foreach $conn "SELECT ..." { body }` — iterate results
  - `sql transaction -variable trans begin $conn` — auto-cleanup transaction
- Key patterns:
  - `-variable` option for automatic resource cleanup via DbTraceCallback
  - Parameterized queries with `{name Type value}` lists to prevent SQL injection
  - `-time` option for performance profiling
  - Script bundle databases for secure script distribution

#### Package management and discovery
If the task involves package loading, discovery, versioning, auto-path,
or understanding the package index system:
- Start at: `[package]` in the **Packages** section of `core_language.md`.
- For a deep-dive on the index discovery pipeline, tagged indexes,
  auto-path, aliases, and security, see [`package.md`](package.md).
- **Key extension**: Eagle adds multi-source discovery (host, filesystem,
  plugin, bundle), tagged indexes (`pkgIndex_XXXX.eagle`), aliases, and
  security verification.
- Typical workflow:
  - `package require MyPackage 1.0` — load a package
  - `package scan -host -normal -primary -tagged -recursive -- $dir` — full scan
  - `package alias shortname realpackage 2.0` — create alias
  - `package info MyPackage` — query metadata
- Key patterns:
  - `package ifneeded name ver script {Core, Locked}` — locked package registration
  - `package scan -whatif -normal -primary -- $dir` — preview discovery
  - `lappend auto_path /new/dir` — triggers automatic rescan via trace
  - `PackageFallback` delegate for on-demand package downloading
  - `.noPkgIndex` markers to disable indexing

#### Regular expressions
If the task involves regex matching, substitution, or understanding
differences between Eagle and Tcl regex behavior:
- Start at: `[regexp]` / `[regsub]` in the **String Processing** section of `core_language.md`.
- For a deep-dive on .NET integration, substitution translation, the three
  replacement modes, and Eagle-specific options, see [`regexp.md`](regexp.md).
- **Watch out**: Eagle defaults to `RegexOptions.Singleline` (`.` matches
  `\n`) — this matches Tcl's default but is the opposite of .NET's own
  default. Use `-linestop` or `-line` to make `.` stop at newlines.
- Key patterns:
  - `regexp -linestop {pattern} $text` — make `.` stop at newlines (.NET-style)
  - `regexp -compiled -nocase {pattern} $text` — IL-compiled, case-insensitive
  - `regexp -all -global -skip 1 {(\w+)=(\w+)} $input k0 v0 k1 v1` — extract groups sequentially
  - `regsub -all -command {\d+} $input {string length}` — TIP #463 command replacement
  - `regsub -extra {(?<name>...)} $input {\N<name>}` — named group substitution
  - `regexp {***=literal.text} $input` — safe literal matching

#### HTTP operations and URI handling
If the task involves HTTP requests, downloads, uploads, URI parsing, or
network operations:
- Start at: `[uri]` in the **Network and URI** section of `core_language.md`.
- For a deep-dive on the web callback chain, async transfers, custom
  WebClient classes, and retry infrastructure, see [`uri.md`](uri.md).
- **No Tcl equivalent** — the `[uri]` command is Eagle-only; Tcl uses
  `package require http` with a different token-based API.
- Typical workflow:
  - `uri get $url` — inline HTTP GET (returns response body)
  - `uri post -data {key value ...} -- $url` — form-encoded POST
  - `uri download -retries 3 -timeout 30000 -- $url /tmp/file` — download with retries
  - `uri upload -inline -raw -method PUT -data $bytes -- $url` — raw PUT
- Key patterns:
  - `-callback {script}` for async transfers with completion notification
  - `-webclientdata $obj` for custom WebClient configuration
  - `WebTransferCallback` for intercepting transfers (caching, mocking)
  - `WebErrorCallback` for custom retry logic with `Ok`/`Error`/`Return`/`Break`/`Continue` semantics
  - `uri offline true` to disable all network operations

#### Time operations and formatting
If the task involves date/time formatting, parsing, timing measurement,
or epoch calculations:
- Start at: `[clock]` in the **Time and Clock** section of `core_language.md`.
- For a deep-dive on format translation, epochs, performance counters,
  and Eagle-specific sub-commands, see [`clock.md`](clock.md).
- **Key difference from Tcl**: Format specifiers (`%Y`, `%m`, etc.) are
  translated from Tcl to .NET format patterns via a dual-layer system.
- Typical workflow:
  - `clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"` — format time
  - `clock scan "2025-01-15" -format "%Y-%m-%d"` — parse date string
  - `set start [clock start]; ...; clock stop $start` — high-res timing
- Key patterns:
  - `-epoch` option for custom epoch on most sub-commands
  - `-ticks` for .NET tick interpretation in `[clock format]`
  - `-iso -full -isotimezone` for ISO 8601 output
  - `clock duration -flags Human` for human-readable durations
  - `[clock buildnumber]` for MSBuild-compatible version numbers
  - Dynamic delegates for `%s`, `%j`, `%V`, `%Z`, `%Q` specifiers

#### String operations and type checking
If the task involves string manipulation, type validation, pattern matching,
culture-aware comparison, or format string generation:
- Start at: `[string]` in the **String Processing** section of `core_language.md`.
- For a deep-dive on all 29 sub-commands, the 64-class type-checking system,
  extended `[string map]`, and .NET format integration, see [`string.md`](string.md).
- **Key extension**: Eagle adds 46 whole-string `[string is]` classes beyond Tcl’s
  18 per-character classes, culture-aware comparison, `-regexp`/`-eval` mapping,
  and `[string format]` with .NET `String.Format` via reflection.
- Typical workflow:
  - `string is integer -strict $val` — type validation
  - `string match -nocase {*.dll} $path` — glob matching
  - `string map -regexp -eval -- {{(\d+)} {expr {$1 * 2}}} $text` — regex-based substitution
  - `string compare -culture en-US -options OrdinalIgnoreCase $a $b` — culture-aware comparison
- Key patterns:
  - `string is list $val` — validate Tcl list structure
  - `string is type $val` — test against .NET types, paths, URIs, GUIDs, etc.
  - `string map -multipass` for cascading substitutions
  - `string map -maximum N -countvar c` for counted replacements
  - `string format {0:C2} 1234.5` — .NET composite format strings
  - `MatchMode` enum for switching between Glob, Regex, and SubString

#### File operations, security, and path management
If the task involves file I/O, path manipulation, file attributes, access
control, temporary files, or filesystem queries:
- Start at: `[file]` in the **File System** section of `core_language.md`.
- For a deep-dive on all 54 sub-commands, access control, SDDL, globbing,
  and platform-specific behavior, see [`file.md`](file.md).
- **Key extensions**: Eagle adds Windows ACL/SDDL manipulation, PE magic
  number inspection, `[file validname]` path validation, `[file under]`
  containment checks, `[file cleanup]` interpreter lifecycle management,
  advanced globbing with `MatchMode`, and cryptographic temp paths.
- Typical workflow:
  - `file exists $path` / `file isfile $path` — test before operating
  - `file copy -force $src $dst` — copy with overwrite
  - `file delete -force -recursive $dir` — remove directory tree
  - `file attributes $path -readonly false` — clear read-only
  - `file normalize $path` — resolve to absolute path
- Key patterns:
  - `[file tempname]` / `[file temppath]` — crypto-random temp files with env precedence
  - `file cleanup $path` — register for automatic interpreter cleanup
  - `file sddl -flags ToList $path` — structured ACL inspection (Windows)
  - `file glob -match Regexp -directory $dir {pattern}` — regex file search
  - `file under /safe/base $userPath` — directory containment validation
  - `file trusted $dll && file verified $dll` — assembly verification before `[load]`
  - `file validname $input Component` — validate user-supplied filenames

#### Interpreter introspection
If the task involves querying interpreter state, inspecting procedures,
commands, variables, engine metadata, or runtime environment:
- Start at: `[info]` in the **Introspection** section of `core_language.md`.
- For a deep-dive on all 85 sub-commands, safe interpreter filtering,
  obfuscation, and .NET reflection integration, see [`info.md`](info.md).
- **Key extensions**: Eagle adds 60+ sub-commands beyond Tcl, including
  .NET/CLR queries, security/policy introspection, plugin/module inspection,
  database connection tracking, culture support, and Windows window enumeration.
- Typical workflow:
  - `info commands ?pattern?` — list commands with extensive filtering
  - `info cmdtype $cmd` — determine command type (proc/alias/ensemble/native)
  - `info exists $var` / `info exists $var val` — check-and-read variables
  - `info engine PatchLevel` — query engine version
  - `[info framework]` — query .NET version
- Key patterns:
  - `info commands -safe -standard` — find safe commands
  - `info commands -hiddenonly` — find hidden commands (unsafe only)
  - `info subcommands $ensemble` — list ensemble sub-commands
  - `[info policies]` / `[info decision]` — inspect security policy state
  - `[info culture]` / `[info cultures]` — query/set localization
  - `[info connections]` / `[info transactions]` — monitor database state
  - `info assembly true` — query host application assembly metadata
  - Safe interpreters: restricted to ~25 sub-commands, no refresh, no hidden visibility

#### Namespace management and organization
If the task involves namespace creation, hierarchical code organization,
command import/export, or namespace-scoped variables:
- Start at: `[namespace]` in the **Namespaces** section of `core_language.md`.
- For a deep-dive on the dual-implementation architecture, object model,
  name resolution, and call frame integration, see [`namespace.md`](namespace.md).
- **Key extensions**: Eagle has a dual implementation (Namespace1 stub
  vs. Namespace2 full), `[namespace enable]` to toggle support, `namespace
  rename`, `namespace descendants`, per-namespace unknown handlers,
  namespace mappings, and `[scope]` command integration.
- Typical workflow:
  - `namespace eval name { ... }` — create namespace and define contents
  - `namespace export pattern` — declare exportable commands
  - `namespace import ns::*` — import exported commands
  - `[namespace current]` — query current namespace
- Key patterns:
  - `namespace enable true` — activate full namespace support (Namespace2)
  - `namespace descendants ::parent` — recursive child enumeration
  - `namespace rename ::old ::new` — rename namespace (Eagle-only)
  - `namespace unknown {script}` — per-namespace unknown handler
  - `[namespace mappings]` — inspect namespace name remapping table
  - `namespace code {script}` — create namespace-preserving callback
  - `scope attach scopeName ::namespace` — link scope variables to namespace

#### Array operations and virtual backends
If the task involves associative arrays, array iteration, default values,
copying, random selection, or virtual arrays (env, database, registry):
- Start at: `[array]` in the **Variables / Data** section of `core_language.md`.
- For a deep-dive on all 17 sub-commands, storage backends, and
  per-element flags, see [`array.md`](array.md).
- **Key extensions**: Eagle adds `[array copy]` (deep copy), `[array default]`
  (TIP #508), `[array random]`, `[array values]`, `[array foreach]`/`[lmap]`,
  8 polymorphic backends, and per-element flags.
- Typical workflow:
  - `array set data {key val ...}` — create/populate array
  - `array get data ?pattern?` — retrieve as key-value list
  - `array names data -glob pattern` — filtered key listing
  - `array for {k v} data { ... }` — iterate key-value pairs
- Key patterns:
  - `array default set arr 0` — auto-default for counters (`incr arr(key)`)
  - `array copy -deep src dst` — independent deep copy
  - `array random -pair data` — random key-value pair
  - `array values data -regexp {pattern}` — filtered value listing
  - `array names env` — list environment variables via virtual backend
  - `array lmap key data { expr }` — map over array elements

#### Host management, console lifecycle, and screen buffers
If the task involves console control, screen buffers, color theming,
cursor positioning, window sizing, box drawing, font control, host
lifecycle, or stream redirection:
- Start at: `[host]` in the **Managed Environment** section of `core_language.md`.
- For a deep-dive on the interface hierarchy, lifecycle safety interlocks,
  and screen buffer management, see [`host.md`](host.md).
- **No Tcl equivalent** — Tcl has no built-in host command; Eagle exposes
  the full console subsystem including Win32 screen buffers.
- Typical workflow:
  - `[host isopen]` — check if host is ready
  - `host color -foreground Green -background Black` — set colors
  - `host position -x 10 -y 5` — position cursor
  - `host writebox "message"` — draw decorative box
  - `host screen create` / `host screen push` / `host screen pop` — screen buffer management
- Key patterns:
  - `[host flags]` — query 60+ capability flags to adapt to host
  - `host screen create` + `push` + `pop` + `delete` — independent screen buffers (Windows)
  - `[host close]` — 5 layers of safety checks (kiosk, active I/O, shared console)
  - `host size -width W -height H` — resize with auto-rollback on failure
  - `host font -facename Consolas -fontsize 14 -save true` — font with save/restore
  - `host writebox -fg White -bg Blue -boxfg Yellow "text"` — themed box drawing
  - `host redirected Output` — check channel redirection state
  - `host reset -all` — reset all host components to defaults

#### Debugging and diagnostics
If the task involves debugging scripts, setting breakpoints, variable
watchpoints, single-stepping, trace configuration, memory diagnostics,
or emergency recovery:
- Start at: `[debug]` in the **Debugging** section of `core_language.md`.
- For a deep-dive on all 65+ sub-commands, the dual-context debugger
  architecture, and emergency recovery, see [`debug.md`](debug.md).
- **No Tcl equivalent** — Tcl has no built-in debug command; Eagle
  integrates the debugger directly into the interpreter.
- Typical workflow:
  - `debug setup true true` — initialize isolated debugger
  - `debug enable true` — enable debugging
  - `debug types Standard` — set breakpoint types
  - `debug onerror true` — break on errors
  - `debug token file.eagle 42 42 true` — set line breakpoint
  - `debug watch myVar {BreakOnSet}` — set variable watchpoint
  - `[debug break]` — programmatic break into debugger
- Key patterns:
  - `debug run { script }` — execute without debugger overhead (suspend/resume)
  - `debug emergency {Created, Enabled, Reset, Break}` — emergency recovery
  - `debug secureeval -timeout 5000 child { script }` — sandboxed evaluation
  - `debug invoke 2 info vars` — inspect variables at specific call level
  - `debug trace -console true -enabledcategories "Engine"` — configure tracing
  - `debug watch var {BreakOnGet, BreakOnSet, BreakOnUnset}` — full watchpoint
  - `debug token file start end true` — source-level breakpoint
  - `[debug status]` — query debugging state across all layers

#### Testing primitives
If you’re writing or understanding tests:
- Look at the **Testing** section and `test1`/`test2`.
- Then cross-reference the script library’s test framework procedures.

#### Security and safe execution
If the question touches sandboxing or safe interpreters:
- Start at: `[interp]` in the **Interpreter Management** section of `core_language.md`.
- For a deep-dive on the security model, command hiding, policy callbacks,
  resource limits, and execution timeouts, see [`interp.md`](interp.md).
- For the policy subsystem architecture, see the **Security Policy Subsystem**
  section in `core_language.md`.
- Key patterns:
  - `interp create -safe` — create a sandboxed interpreter
  - `[interp makesafe]` — convert an existing interpreter to safe mode
  - `interp policy -type T path script` — install a custom policy
  - `[interp recursionlimit]` / `iterationlimit` / `timeout` — set resource limits
  - `[interp invokehidden]` — run trusted operations in a safe interpreter
  - `[interp alias]` — create controlled communication channels
- Also see:
  - Built-in Virtual Scripts (`safe.eagle`, `removeCommands`, `removeVariables`)
  - Safe-interpreter related packages in `core_script_library.md`

---

## Script library documentation orientation

### What `core_script_library.md` is
- Documentation for **script-level helper packages** shipped with Eagle.
- Procedures are organized by **package** and **source file** (e.g.,
  `auxiliary.eagle`, `exec.eagle`, `platform.eagle`).
- Most procedures live in the `::Eagle` namespace and are typically exported for
  convenient global use.

### The two major library groupings
- `Eagle1.0` library: general utilities (platform detection, file helpers,
  process helpers, object helpers, etc.)
- `Test1.0` library: test framework and constraints utilities

### Common “where do I look?” map

| You need… | Likely section / module |
|-----------|--------------------------|
| dictionary operations | `[dict]` command (built-in); also `getDictionaryValue` in `auxiliary.eagle` |
| platform detection (Windows/Unix/Mono/.NET) | `platform.eagle` (e.g., `isWindows`, `isMono`, `isDotNetCore`) |
| file read/write helpers | `file1.eagle`, `file2.eagle`, `file2u.eagle` |
| recursive file discovery | `file3.eagle` |
| external command helpers | `exec.eagle` |
| object / reflection helpers | `object.eagle` |
| process listing/waiting | `process.eagle` |
| runtime option toggles | `runopt.eagle` |
| test logging to queues | `testlog.eagle` |
| test framework utilities | `test.eagle` + `constraints.eagle` |
| safe interpreter helpers | `safe.eagle` |
| interactive shell helpers / downloads / remote eval | `shell.eagle` |
| Tcl compatibility shims | `compat.eagle`, `shim.eagle` |
| C# compilation support | `csharp.eagle` |

---

## Known Tcl-to-Eagle pitfalls to watch for

These are common sources of “looks like Tcl but isn’t” errors.

- **No `{*}` argument expansion operator.**
  Use `[eval]` + `[list]` patterns for controlled argument expansion.

- **`fileevent` exists, but `chan event` does not.**
  Use `[fileevent]` for readable/writable events on socket and seekable file
  channels. Eagle also adds `-priority` when installing a handler.

- **No `namespace path`.**
  Not supported in Eagle.

- **No user-facing `namespace ensemble` creation.**
  Eagle has ensembles internally; verify what is supported at script level.

- **Try/catch dialect differences.**
  Eagle supports `try { ... } finally { ... }` patterns; verify any “try on error”
  structures you might otherwise assume from Tcl variants.

When in doubt: use `core_language.md` as the source of truth for command
availability and exact syntax.

---

## Practical recipes for agents

These are **navigation-oriented** recipes: they show what to search for and
where, rather than duplicating full reference content.

### Recipe: Run a tool and capture stdout, stderr, and exit code
- Go to: `core_language.md#cmd-exec`
- For quoting/escaping details and Tcl differences: [`exec.md`](exec.md)
- Look for options:
  - `-stdout varName`
  - `-stderr varName`
  - `-exitcode varName`
  - `-timeout milliseconds`
  - `-setall` when you want variables set even on error
  - `-commandline` when arguments contain spaces (see [`exec.md`](exec.md) §5)

### Recipe: Implement persistent state across procedure calls
- Go to: `core_language.md#cmd-scope`
- For internals and advanced patterns: [`scope.md`](scope.md)
- Look for patterns:
  - `scope create -open -clone -args $name` for named persistent state
  - `scope create -open -procedure -args` for per-procedure auto-named state
  - `scope eval name { script }` for scoped execution
  - `scope eval -lock name { script }` for thread-safe access
  - `scope global name` for sandboxed global redirection

### Recipe: Use native Tcl packages or evaluate Tcl code from Eagle
- Go to: `core_language.md#cmd-tcl`
- For internals and architecture: [`tcl.md`](tcl.md)
- For the reverse direction (Tcl → Eagle): [`garuda.md`](garuda.md)
- Look for:
  - `[tcl load]` to load the native Tcl library
  - `[tcl create]` / `[tcl delete]` for interpreter lifecycle
  - `tcl eval interp { script }` for evaluation
  - `tcl command create` for bridging Eagle commands into Tcl
  - `[tcl set]` / `[tcl unset]` for variable exchange
  - `loadGarudaForUseByEagle` for full bidirectional setup

### Recipe: Call native C functions via P/Invoke-style FFI
- Go to: `core_language.md#cmd-library`
- For internals and architecture: [`library.md`](library.md)
- Look for:
  - `library load fileName` to load a native shared library
  - `library declare -module $m -functionname F -returntype T -parametertypes {T1 T2}` to declare
  - `library call $delegate arg1 arg2` to invoke
  - `library undeclare $delegate` and `library unload $module` for cleanup
  - `library info module $m` / `library info delegate $d` for introspection
  - `library certificate -chain fileName` for signature verification

### Recipe: Create a safe sandbox for untrusted code
- Go to: `core_language.md#cmd-interp`
- For internals and security model: [`interp.md`](interp.md)
- For the policy architecture: `core_language.md` → Security Policy Subsystem
- Look for:
  - `interp create -safe` to create a sandboxed interpreter
  - `[interp recursionlimit]` / `iterationlimit` / `varlimit` / `timeout` for resource limits
  - `interp watchdog path true` for timeout enforcement
  - `interp alias $child safeCmd {} parentCmd` for controlled access
  - `interp invokehidden $child source trusted.eagle` for trusted initialization
  - `interp policy -type T path script` for custom policy callbacks

### Recipe: Load a .NET plugin with security verification
- Go to: `core_language.md#cmd-load`
- For internals and architecture: [`load.md`](load.md)
- Look for:
  - `load fileName` to load a plugin (auto-discovers IPlugin type)
  - `load -verifiedonly -trustedonly fileName` for full security verification
  - `load -isolated fileName` for AppDomain isolation
  - `load -publickeytoken "hex" fileName` to require a specific publisher
  - `load -ruleset $rs fileName` to filter commands/policies
  - `load -nocommands -nofunctions fileName` for selective entity loading
  - `unload fileName` / `unload -nocomplain fileName` for plugin removal

### Recipe: Use an enterprise (EEE) plugin's commands
- The eight Eagle Enterprise Edition plugins live in
  `Eagle/Plugins/Commercial/Enterprise/`; **each requires a license certificate
  by default, but is now also open source.**
- For the loading/verification model itself, see [`load.md`](load.md).
- For a specific plugin's commands, go to its dedicated reference (each has a
  Command Summary and `#cmd-NAME` anchors):
  - **Harpy** — security & licensing (`[harpy]`) → [`harpy.md`](harpy.md)
  - **Badge** — signed script certificates (`[badge]`) → [`badge.md`](badge.md)
  - **Kapok** — sandboxed web server (`[kapok]`) → [`kapok.md`](kapok.md)
  - **Zeus** — cryptography / CLR hooking / script encryption (`[zeus]`) → [`zeus.md`](zeus.md)
  - **Demo** — host-swapping example (`[demo]`) → [`demo.md`](demo.md)
  - **HotKey** — global hot-keys + WinForms UI (`[hotkey]`) → [`hotKey.md`](hotKey.md)
- Aquila and Featherlight are enterprise plugins without dedicated command docs yet.

### Recipe: Execute database queries with auto-cleanup
- Go to: `core_language.md#cmd-sql`
- For internals and architecture: [`sql.md`](sql.md)
- Look for:
  - `sql open -variable conn -type SQLite "connStr"` for auto-cleanup connections
  - `sql execute -execute Reader -format NestedList $conn "SELECT ..."` for queries
  - `sql foreach $conn "SELECT ..." { body }` for row iteration
  - `sql transaction -variable trans begin $conn` for auto-cleanup transactions
  - `{paramName Type value}` parameter lists for SQL injection prevention
  - `-time` option for performance profiling (prepare + execute timing)
  - Script bundle databases for signed, encrypted script distribution

### Recipe: Manage packages and package discovery
- Go to: `core_language.md#cmd-package`
- For internals and architecture: [`package.md`](package.md)
- Look for:
  - `package require name ?version?` for loading packages
  - `package scan -host -normal -primary -tagged -recursive -- $dir` for full index discovery
  - `package alias shortname realpackage 2.0` for package aliasing
  - `package ifneeded name ver script {Locked, Rejected}` for locked packages
  - `package scan -whatif` for previewing discovery without state changes
  - `package withdraw name ?ver?` to unload without removing registration
  - `lappend auto_path /dir` triggers automatic rescan via `AutoPathTraceCallback`
  - `.noPkgIndex` marker files to disable indexing for files/directories
  - `PackageFallback` delegate for programmatic package resolution

### Recipe: Format and parse dates, measure elapsed time
- Go to: `core_language.md#cmd-clock`
- For internals and format translation: [`clock.md`](clock.md)
- Look for:
  - `clock format $secs -format "%Y-%m-%d %H:%M:%S"` — Tcl format specifiers
  - `clock scan "2025-01-15"` — parse date strings
  - `clock format $secs -iso -full -isotimezone` — ISO 8601 output
  - `set start [clock start]; ...; set us [clock stop $start]` — high-res timing
  - `clock buildnumber -epoch [clock scan "2023-01-01"]` — build numbering
  - `clock duration -flags Human start end` — human-readable durations
  - `-epoch` option for custom epoch on `seconds`, `[format]`, `scan`, etc.
  - Dynamic delegates for `%s`, `%j`, `%V`, `%Z`, `%Q` format specifiers

### Recipe: Manipulate strings and validate types
- Go to: `core_language.md#cmd-string`
- For internals and architecture: [`string.md`](string.md)
- Look for:
  - `string is integer -strict $val` — strict type validation (empty string fails)
  - `string is list $val` / `string is dict $val` — structure validation
  - `string match -nocase {pattern} $str` — glob-style matching
  - `string map -regexp -eval -- {{pattern} {script}} $text` — regex substitution with evaluation
  - `string map -multipass -maximum N -countvar c -- {mapping} $text` — cascading counted replacements
  - `string compare -culture name -options flags $a $b` — culture-aware comparison
  - `string format {0:C2} 1234.5` — .NET composite format strings via `String.Format`
  - `string reverse $str` / `string totitle $str` — Eagle-only sub-commands
  - 64 `[string is]` classes: 18 per-character (alpha, digit, etc.) + 46 whole-string (list, dict, type, uri, guid, etc.)

### Recipe: Work with files, paths, and filesystem security
- Go to: `core_language.md#cmd-file`
- For internals and architecture: [`file.md`](file.md)
- Look for:
  - `file normalize $path` — resolve to absolute path
  - `file join $dir $name` — portable path construction
  - `file validname $input Component` — validate user-supplied filenames
  - `file copy -force $src $dst` — copy with overwrite
  - `file delete -force -recursive $dir` — remove directory tree with read-only handling
  - `file attributes $path -readonly false -hidden true` — get/set 12 FileAttributes
  - `[file tempname]` / `[file temppath]` — cryptographic temp files with env var precedence
  - `file cleanup $path` — register for automatic interpreter cleanup on dispose
  - `file sddl -flags ToList $path` — Windows ACL inspection as structured list
  - `file rights $path` — effective access rights (GenericRead, GenericWrite, etc.)
  - `file glob -match Regexp -directory $dir {pattern}` — regex-based file search
  - `file under /allowed/base $userPath` — directory containment check
  - `file trusted $dll` / `file verified $dll` — assembly trust verification
  - `file magic $exe` — PE file header inspection
  - `file version -full $dll` — FileVersionInfo as dictionary

### Recipe: Introspect interpreter state and runtime environment
- Go to: `core_language.md#cmd-info`
- For internals and architecture: [`info.md`](info.md)
- Look for:
  - `info commands ?options? ?pattern?` — list commands with 18+ filters (-safe, -hidden, -sdk, etc.)
  - `info cmdtype $cmd` — returns proc, alias, object, ensemble, or native
  - `info cmdcount ?path? ?type?` — detailed execution counters (OperationCount, CommandCount, UnknownCount)
  - `info args $proc` / `info body $proc` / `info default $proc arg var` — procedure introspection
  - `info exists $var ?valVar?` — Eagle extension: atomic check-and-read
  - `[info vars]` / `[info globals]` / `[info locals]` / `[info sysvars]` — variable listing by scope
  - `info engine ?attribute? ?refresh?` — 9 engine attributes (Name, Version, PatchLevel, Configuration, etc.)
  - `[info framework]` / `[info runtime]` / `[info runtimeversion]` — .NET version queries
  - `info assembly ?entry?` — assembly FullName and Location via reflection
  - `info subcommands $ensemble ?pattern?` — enumerate ensemble sub-commands
  - `[info policies]` / `[info decision]` — security policy introspection
  - `info culture ?name?` / `info cultures ?pattern?` — localization queries
  - `[info connections]` / `[info transactions]` — database state monitoring
  - `[info os]` / `[info hostname]` / `[info pid]` / `[info processors]` — system information

### Recipe: Organize code with namespaces and imports
- Go to: `core_language.md#cmd-namespace`
- For internals and architecture: [`namespace.md`](namespace.md)
- Look for:
  - `namespace eval name { ... }` — create namespace and define contents
  - `namespace export -clear pattern ...` — declare exportable commands
  - `namespace import -force ns::*` — import exported commands (force overwrites)
  - `namespace forget ns::*` — remove imported commands
  - `namespace enable true` — activate full namespace support (Namespace2)
  - `namespace children ?name? ?pattern?` — list direct child namespaces
  - `namespace descendants ?name? ?pattern?` — recursive child enumeration (Eagle-only)
  - `namespace rename ::old ::new` — rename namespace (Eagle-only)
  - `namespace code {script}` — create callback preserving namespace context
  - `namespace inscope ::ns script args` — execute in namespace with arguments
  - `namespace unknown {handler}` — per-namespace unknown command handler
  - `namespace which -command name` / `namespace which -variable name` — resolve qualified name
  - `namespace origin importedCmd` — trace import chain to original command
  - `[namespace mappings]` — inspect namespace name remapping table

### Recipe: Work with arrays, default values, and virtual backends
- Go to: `core_language.md#cmd-array`
- For internals and architecture: [`array.md`](array.md)
- Look for:
  - `array set data {key val ...}` — create/populate array from list
  - `array get data ?pattern?` — retrieve as flat key-value list
  - `array names data -glob|-regexp|-exact|-substring pattern` — filtered key listing
  - `array values data ?mode? ?pattern?` — filtered value listing (Eagle-only)
  - `array default set arr 0` — default value for missing keys (TIP #508)
  - `array copy -deep src dst` — deep copy with independent elements
  - `array random -pair -strict data ?pattern?` — random element selection
  - `array for {k v} data { body }` — key-value iteration
  - `array foreach key data { body }` — key-only iteration (Eagle-only)
  - `array lmap key data { body }` — mapped iteration returning list (Eagle-only)
  - `array names env` — list environment variables via virtual backend
  - 8 backends: ElementDictionary, env, System.Array, thread, database, network, registry, tests

### Recipe: Control the console host, screen buffers, and display
- Go to: `core_language.md#cmd-host`
- For internals and architecture: [`host.md`](host.md)
- Look for:
  - `[host isopen]` to check host readiness before operations
  - `[host open]` / `[host close]` for lifecycle control (close has 5 safety layers)
  - `host color -foreground Color -background Color` for console colors
  - `host namedcolor -theme name -name color` for themed color management
  - `host position -x col -y row` / `-relx N -rely N` for cursor positioning
  - `host size -width W -height H` for window sizing (auto-rollback on failure)
  - `host writebox ?options? string` for decorative box drawing with colors
  - `host screen create` + `push name` + `pop` + `delete name` for Win32 screen buffers
  - `host font -facename name -fontsize N` for console font control (Windows)
  - `[host readchar]` / `[host readkey]` / `[host readline]` for input
  - `[host inchan]` / `[host outchan]` / `[host errchan]` for stream redirection
  - `host redirected channel` to check channel redirection state
  - `[host flags]` to query 60+ host capability flags
  - `host reset -all` to reset all host components
  - `host sleep N` for thread-level sleep (requires HostFlags.Sleep)

### Recipe: Debug scripts with breakpoints, watchpoints, and stepping
- Go to: `core_language.md#cmd-debug`
- For internals and architecture: [`debug.md`](debug.md)
- Look for:
  - `debug setup true true` to initialize an isolated debugger
  - `debug enable true` / `debug enable false` to toggle the debugger
  - `debug types Standard` to set breakpoint types (Common + Token)
  - `debug onerror true` / `debug oncancel true` to break on specific events
  - `debug token file startLine endLine true` to set line-level breakpoints
  - `debug watch varName {BreakOnGet, BreakOnSet}` to set variable watchpoints
  - `debug step true` / `debug steps N` for single-stepping
  - `[debug break]` to programmatically enter the debugger
  - `debug run { script }` to execute without debugger overhead
  - `debug emergency {flags}` for emergency recovery with lifecycle control
  - `debug secureeval -timeout N path { script }` for sandboxed evaluation
  - `debug invoke level cmd args` to execute at a specific call frame
  - `debug trace -console true -enabledcategories "cat"` for trace configuration
  - `[debug status]` to query debugging state across all layers
  - `[debug memory]` / `[debug gcmemory]` for memory diagnostics

### Recipe: Perform HTTP downloads and uploads with customization
- Go to: `core_language.md#cmd-uri`
- For internals and architecture: [`uri.md`](uri.md)
- Look for:
  - `uri get $url` — inline GET (shorthand for `uri download -inline`)
  - `uri post -data {key value} -- $url` — form-encoded POST
  - `uri download -retries 3 -timeout 30000 -- $url /path` — download with retries
  - `uri upload -inline -raw -method PUT -data $bytes -- $url` — raw PUT
  - `-callback {script}` for async transfers with completion notification
  - `-webclientdata $obj` for custom WebClient headers/timeout/proxy
  - `WebTransferCallback` / `WebErrorCallback` for per-interpreter interception and retry control
  - `uri offline true/false` to toggle network access

### Recipe: Use regex matching and substitution with Eagle-specific features
- Go to: `core_language.md#cmd-regexp` and `core_language.md#cmd-regsub`
- For internals and Tcl differences: [`regexp.md`](regexp.md)
- Look for:
  - `-linestop` or `-line` to get Tcl-compatible dot behavior (Eagle defaults to `.` matching `\n`)
  - `-compiled` for IL compilation when reusing patterns
  - `-all -global -skip 1` for sequential extraction of capture groups
  - `-command` (TIP #463) or `-eval` for programmatic replacement
  - `-extra` with `\N<name>` for .NET named group substitution
  - `***=` prefix for safe literal pattern matching
  - `-options {IgnoreCase, Multiline}` for direct .NET RegexOptions control

### Recipe: Use .NET types safely and clean up resources
- Go to: `core_language.md#cmd-object`
- For full architecture, handle lifecycle, method resolution, and all 44 sub-commands,
  see [`object.md`](object.md).
- Look for:
  - `[object create]` — instantiation with 37 options (aliases, flags, type resolution)
  - `[object invoke]` — member invocation with 48 options (static, by-ref, marshalling)
  - `[object dispose]` — disposal pipeline (reference counting, force, locked objects)
  - `[object foreach]` / `[object lmap]` — collection iteration with auto-alias
  - `[object load]` — assembly loading with trust/strong-name verification
  - `[object import]` / `[object type]` — namespace imports and type aliases
  - `[object cleanup]` — batch cleanup with configurable scope
- Key architectural concepts:
  - **Opaque handles**: `ObjectDictionary` → `ObjectWrapper` → `ObjectData` three-layer system
  - **FixupReturnValue**: pipeline that decides whether to create a handle or return a string
  - **Command alias dispatch**: `-alias` flag creates commands that delegate to `[object invoke]`
  - **Method overload resolution**: `FindMethodsAndFixupArguments` engine with scoring
- Then cross-reference:
  - `core_script_library.md` → `Object Utilities (object.eagle)`

### Recipe: Write tests in the standard Eagle test harness style
- Go to: `core_language.md` → Testing section (`test1`, `test2`)
- Go to: `core_script_library.md` → Test framework (`test.eagle`) and constraints
  (`constraints.eagle`)

### Recipe: Use dictionary data structures
- Go to: `core_language.md#cmd-dict`
- Use the `[dict]` command: `[dict create]`, `[dict get]`, `[dict set]`, `[dict exists]`, `[dict keys]`, etc.
- For simple lookups with defaults, also see `getDictionaryValue` in `core_script_library.md`.

### Recipe: Evaluate an Eagle script from an MSBuild target
- Go to: `integrations.md` → MSBuild Integration → Examples
- Look for: EvaluateScript task with Text parameter
- Key detail: use `__task` object for BuildEngine access

### Recipe: Understand the Eagle update workflow and security model
- Go to: `updater.md` → Update Workflow (section 4) for the full flow
- Go to: `updater.md` → Security Model (section 5) for verification layers
- Key detail: multi-layer verification (Authenticode + strong name + triple hash)

---

## How to answer questions with high fidelity

When asked “How do I…?” or “Does Eagle support…?”:

1. **Find the relevant command/procedure entry** by name.
2. **Confirm syntax** (positional args vs options, option names, return values).
3. **Check for Eagle-specific notes** (unsupported Tcl behavior, enhanced flags).
4. **Include a minimal working example** from `core_examples.md` (use `#ex-NAME`
   anchors) or from the documentation section you read.
5. If the question is cross-cutting (e.g., “safe interpreter + exec + object”),
   **link together the exact relevant sections** rather than guessing behavior.

---

## Examples

`core_examples.md` contains **500+ worked examples** covering every command and
sub-command in the Eagle language. Examples are organized by category (mirroring
`core_language.md`) and use `#ex-NAME` anchors for fast lookup.

When you need a usage example:
- Go to: `core_examples.md#ex-COMMAND` (e.g., `core_examples.md#ex-exec`,
  `core_examples.md#ex-object`, `core_examples.md#ex-string`)
- Browse the **Table of Contents** for category-based navigation.
- The **Practical Patterns** section at the end shows idiomatic multi-command
  recipes combining commands with script library procedures.

For deeper examples beyond this repository (especially for testing and
real-world harness patterns), consult the Eagle source repo's `Library/Tests/`
and other examples.

---

## Maintenance note for contributors

When editing these documents:

- Keep headings stable where practical (anchors are used heavily by agents).
- Prefer small, correct examples over long examples.
- When a behavior differs from Tcl, explicitly call it out as a **compatibility
  note** to reduce downstream agent confusion.
- If you add new commands/procedures:
  - Update the relevant index sections
  - Add anchors consistently (commands: `#cmd-NAME`, procedures under `#### name`)
