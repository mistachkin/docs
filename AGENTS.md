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
| `quick_start_guide.md` | Getting started guide: obtaining Eagle, running the shell, language basics, .NET interop intro | When new users need to get up and running or when explaining Eagle basics |
| `core_language.md` | Eagle command catalog (built-ins), organized by category; includes advanced topics | When you need command syntax, options, behavior, or Eagle-only extensions |
| `core_examples.md` | Contains 500+ worked examples for every command and sub-command, organized by category | When you need usage examples, idiomatic patterns, or practical demonstrations |
| `core_script_library.md` | Contains 580+ library procedures (script-level utilities), organized by package and source file | When you need helper procedures, test utilities, file helpers, platform detection, etc. |
| `tips_and_tricks.md` | Eagle-unique features, advanced idioms, and best practices not found in standard Tcl | When looking for Eagle-specific patterns, performance tips, or unique capabilities |
| `exec.md` | Deep-dive analysis of the `exec` command: argument processing, command-line building, escaping, and differences from native Tcl | When you need to understand exec's quoting/escaping algorithm, the three argument assembly paths, or why Eagle exec behaves differently from Tcl exec |
| `scope.md` | Deep-dive analysis of the `scope` command: persistent named variable environments, call frame stack model, cloning, locking, namespace integration, and global scope redirection | When you need to understand how scopes work, implement persistent state across procedure calls, or use thread-safe shared state |
| `tcl.md` | Deep-dive analysis of the `tcl` command: native Tcl library loading, interpreter management, command bridging, function pointer marshalling, and bidirectional Eagle/Tcl integration | When you need to understand how Eagle embeds native Tcl, bridge commands between runtimes, or use native Tcl packages from Eagle |
| `library.md` | Deep-dive analysis of the `library` command: P/Invoke-style FFI, dynamic delegate creation via Reflection.Emit, module lifecycle/reference counting, marshalling, architecture and certificate verification | When you need to understand how Eagle calls native C functions, the dynamic delegate type creation mechanism, or module lifecycle management |
| `interp.md` | Deep-dive analysis of the `interp` command: interpreter lifecycle, safe interpreter security model, command hiding, policy-based access control, resource limits, execution timeouts, and cross-interpreter communication | When you need to understand interpreter management, the safe interpreter security model, policy callbacks, resource limits, or how to sandbox untrusted code |
| `load.md` | Deep-dive analysis of the `load`/`unload` commands: .NET plugin loading infrastructure, security verification chain (strong name, Authenticode, public key token), AppDomain isolation, built-in plugins, enterprise plugins (Harpy, Badge, HotKey, Zeus, Demo, Featherlight, Aquila, Kapok), and plugin lifecycle management | When you need to understand how Eagle loads/unloads .NET plugins, the security verification pipeline, AppDomain isolation, PluginFlags, or the enterprise plugin ecosystem |
| `sql.md` | Deep-dive analysis of the `sql` command: ADO.NET database access, `-variable` options with DbTraceCallback for automatic resource cleanup, script bundle databases (signed SQLite-based script containers), query execution pipeline, parameter binding, result formatting, transaction management, and performance profiling | When you need to understand database operations, automatic connection/transaction cleanup, the script bundle system, parameterized queries, or provider type resolution |
| `regexp.md` | Deep-dive analysis of the `regexp`/`regsub` commands: .NET `System.Text.RegularExpressions` integration, default `Singleline` behavior (dot matches newlines — opposite of Tcl), Tcl-to-.NET substitution translation (`TranslateSubSpec`), three replacement modes (normal, `-eval`, `-command`/TIP #463), `-extra` extended substitutions (`\P`, `\I`, `\S`, `\M#`, `\N<name>`), pattern mutation prefixes (`***=`, `***:`), and all Eagle-specific options | When you need to understand regex behavior differences from Tcl, substitution translation, the three regsub modes, named group references, or the many Eagle-specific regex options |
| `uri.md` | Deep-dive analysis of the `uri` command: 18 sub-commands for URI construction/parsing/validation, HTTP download/upload (sync and async), four per-interpreter web callbacks (`PreWebClientCallback`, `NewWebClientCallback`, `WebTransferCallback`, `WebErrorCallback`), custom `WebClient`-derived classes (`TagAndTimeoutWebClient`, `ScriptWebClient`), async transfers with `CommandCallback` script evaluation, retry infrastructure, offline mode, and security protocol management | When you need to understand HTTP operations, async downloads/uploads with callbacks, custom WebClient configuration, the web callback chain, retry logic, or URI utility operations |
| `package.md` | Deep-dive analysis of the `package` command: 23 sub-commands, multi-source index discovery pipeline (host, filesystem, plugin, bundle), tagged package indexes (`pkgIndex_XXXX.eagle` with `$tag` variable), auto-path system and interpreter initialization, package aliases with circular-reference detection, security verification (Authenticode, StrongName, locked/rejected packages), the four-stage `package require` fallback chain, `PackageFallback` delegate, `.noPkgIndex` disable markers, and all `PackageFlags`/`PackageIndexFlags` | When you need to understand package management, index discovery, tagged indexes, auto-path construction, package aliases, security verification during scanning, the require fallback chain, or package lifecycle (provide/withdraw/forget) |
| `garuda.md` | The Eagle Native Package for Tcl (Garuda) reference | When you need to integrate with Eagle via a native Tcl environment |
| `integrations.md` | Eagle's four official integration sub-projects: MSBuild, WiX, PowerShell, MonoDevelop | When you need to use Eagle from MSBuild builds, WiX installers, PowerShell, or MonoDevelop |
| `updater.md` | Eagle Updater (Hippogriff) architecture and design analysis | When you need to understand the update mechanism, its security model, or its configuration |
| `AGENTS.md` | You are here | How to navigate and answer accurately |

---

## Fast lookup workflow

### Step 1 — Identify the thing you need
Ask yourself:

- "Is this a **built-in command** like `exec`, `object`, `info`, `string`?"
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

If an option list is long (e.g., `exec`), resist summarizing from memory:
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
- **Eagle-enhanced Tcl commands** notes (e.g., `exec`, `regexp`, `vwait`, `load`)

### Big features you’ll reach for often

#### .NET / CLR integration
If the task involves .NET types, assemblies, reflection, or runtime control:
- Start at: `object` command and the **Objects / .NET Interop** section.
- Typical workflow:
  - `object load` to load an assembly (if needed)
  - `object import` to shorten type names
  - `object create` to instantiate
  - `object invoke` to call members
  - `object dispose` for lifecycle cleanup

#### External processes and tooling
If you need to run compilers, formatters, linters, test runners, etc.:
- Start at: `exec` in the **Native Environment** section.
- For a deep-dive on argument processing, quoting, escaping, and Tcl
  differences, see [`exec.md`](exec.md).
- Eagle’s `exec` is more featureful than Tcl’s:
  - variable-based stdin
  - separate stdout/stderr capture
  - exit code capture
  - timeouts
  - background execution
  - shell execution mode
  - callbacks for streaming output
  - command-line building with `-commandline`, `-forprocessor`, `-escaperanges`
  - custom escape and pre-processing hooks

> Important: Eagle does not use Tcl’s pipeline / redirection syntax. Use `exec`
> options instead. See [`exec.md`](exec.md) for the full comparison.

#### Persistent state and variable scopes
If the task involves persistent state across procedure calls, coroutine-like
patterns, thread-safe shared state, or sandboxed global environments:
- Start at: `scope` in the **Variables / Data** section of `core_language.md`.
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
- Start at: `library` in the **Native Environment** section of `core_language.md`.
- For a deep-dive on dynamic delegate creation, module lifecycle, marshalling,
  and architecture verification, see [`library.md`](library.md).
- Typical workflow:
  - `library load` to load a native shared library
  - `library declare` to define a function signature (creates delegate type via Reflection.Emit)
  - `library call` to invoke the native function
  - `library undeclare` / `library unload` for cleanup
- Key patterns:
  - `library declare -module $m -functionname F -returntype IntPtr` — combined declare+resolve
  - `library load -trustedonly signed.dll` — certificate-verified loading
  - `library matcharchitecture mylib.dll` — architecture compatibility check

#### Plugin loading and management
If the task involves loading .NET plugins, extending the interpreter with
compiled assemblies, or understanding the plugin security model:
- Start at: `load` / `unload` in the **Native Environment** section of `core_language.md`.
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

#### Database operations (ADO.NET)
If the task involves database access, SQL queries, transactions, or
script bundle databases:
- Start at: `sql` in the **Database** section of `core_language.md`.
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
- Start at: `package` in the **Packages** section of `core_language.md`.
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
- Start at: `regexp` / `regsub` in the **String Processing** section of `core_language.md`.
- For a deep-dive on .NET integration, substitution translation, the three
  replacement modes, and Eagle-specific options, see [`regexp.md`](regexp.md).
- **Critical difference**: Eagle defaults to `RegexOptions.Singleline` (`.`
  matches `\n`). Use `-linestop` or `-line` for Tcl-compatible behavior.
- Key patterns:
  - `regexp -linestop {pattern} $text` — Tcl-compatible dot behavior
  - `regexp -compiled -nocase {pattern} $text` — IL-compiled, case-insensitive
  - `regexp -all -global -skip 1 {(\w+)=(\w+)} $input k0 v0 k1 v1` — extract groups sequentially
  - `regsub -all -command {\d+} $input {string length}` — TIP #463 command replacement
  - `regsub -extra {(?<name>...)} $input {\N<name>}` — named group substitution
  - `regexp {***=literal.text} $input` — safe literal matching

#### HTTP operations and URI handling
If the task involves HTTP requests, downloads, uploads, URI parsing, or
network operations:
- Start at: `uri` in the **Network and URI** section of `core_language.md`.
- For a deep-dive on the web callback chain, async transfers, custom
  WebClient classes, and retry infrastructure, see [`uri.md`](uri.md).
- **No Tcl equivalent** — the `uri` command is Eagle-only; Tcl uses
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

#### Testing primitives
If you’re writing or understanding tests:
- Look at the **Testing** section and `test1`/`test2`.
- Then cross-reference the script library’s test framework procedures.

#### Security and safe execution
If the question touches sandboxing or safe interpreters:
- Start at: `interp` in the **Interpreter Management** section of `core_language.md`.
- For a deep-dive on the security model, command hiding, policy callbacks,
  resource limits, and execution timeouts, see [`interp.md`](interp.md).
- For the policy subsystem architecture, see the **Security Policy Subsystem**
  section in `core_language.md`.
- Key patterns:
  - `interp create -safe` — create a sandboxed interpreter
  - `interp makesafe` — convert an existing interpreter to safe mode
  - `interp policy -type T path script` — install a custom policy
  - `interp recursionlimit` / `iterationlimit` / `timeout` — set resource limits
  - `interp invokehidden` — run trusted operations in a safe interpreter
  - `interp alias` — create controlled communication channels
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
| dictionary operations | `dict` command (built-in); also `getDictionaryValue` in `auxiliary.eagle` |
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
  Use `eval` + `list` patterns for controlled argument expansion.

- **No `fileevent`.**
  Use polling with `after` / event processing, or CLR async patterns.

- **No `scan` command.**
  The Tcl `scan` command (C-style `sscanf` string parsing) is not implemented
  in Eagle. Use `regexp` or `string` operations for equivalent functionality.

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
  - `tcl load` to load the native Tcl library
  - `tcl create` / `tcl delete` for interpreter lifecycle
  - `tcl eval interp { script }` for evaluation
  - `tcl command create` for bridging Eagle commands into Tcl
  - `tcl set` / `tcl unset` for variable exchange
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
  - `interp recursionlimit` / `iterationlimit` / `varlimit` / `timeout` for resource limits
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
- Look for:
  - `object create`
  - `object invoke`
  - `object dispose`
- Then cross-reference:
  - `core_script_library.md` → `Object Utilities (object.eagle)`

### Recipe: Write tests in the standard Eagle test harness style
- Go to: `core_language.md` → Testing section (`test1`, `test2`)
- Go to: `core_script_library.md` → Test framework (`test.eagle`) and constraints
  (`constraints.eagle`)

### Recipe: Use dictionary data structures
- Go to: `core_language.md#cmd-dict`
- Use the `dict` command: `dict create`, `dict get`, `dict set`, `dict exists`, `dict keys`, etc.
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
