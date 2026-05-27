# Eagle `[package]` Command: Deep-Dive Analysis of Package Management, Indexing, and Security

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[package]` command internals, including the 23 sub-commands, the multi-source package index discovery pipeline (host, filesystem, plugin, bundle), tagged package indexes, the auto-path system and its integration with interpreter initialization, package aliases with circular-reference detection, the security verification chain (Authenticode, StrongName, locked/rejected packages), the package require fallback chain, and the `.noPkgIndex` disable mechanism. For basic command syntax, see [`core_language.md`](core_language.md#cmd-package). For usage examples, see [`core_examples.md`](core_examples.md#ex-package). For package toolset procedures, see [`core_script_library.md`](core_script_library.md).

## 1. Executive Summary

Eagle's `[package]` command provides **Tcl-compatible package management**
with substantial extensions for security, multi-source discovery, and
enterprise deployment. It manages the full lifecycle of packages —
registering, discovering, loading, versioning, aliasing, and withdrawing
reusable collections of commands and procedures.

There are four key areas of complexity beyond standard Tcl:

1. **Multi-source index discovery pipeline** — Package indexes are
   discovered from four sources in configurable order: the interpreter
   host (built-in library packages), the filesystem (primary and tagged
   index files), plugin assemblies (embedded resources), and script
   bundle databases. The `FindAll` orchestrator coordinates these
   sources with deduplication and configurable precedence via
   `PreferFileSystem` / `PreferHost`.

2. **Tagged package indexes** — Beyond the standard `pkgIndex.eagle`
   file, Eagle supports tagged index files named
   `pkgIndex_XXXXXXXXXXXXXXXX.eagle` (16 hex digits). During
   evaluation, the tag is available via the `$tag` variable, enabling
   a single index script to handle multiple package variants, versions,
   or configurations.

3. **Auto-path integration** — The `auto_path` variable is built from
   multiple sources (environment variables, assembly location, platform
   paths) and is deeply integrated with the package subsystem. Changes
   to `auto_path` automatically trigger a full package index rescan via
   a variable trace callback, and the auto-path is initialized in two
   phases during interpreter creation.

4. **Security verification during discovery** — Package scanning can
   enforce Authenticode signature validation and StrongName verification
   on assemblies found during index discovery. Packages can be locked
   (preventing replacement) or locked+rejected (generating errors on
   replacement attempts). The `.noPkgIndex` marker file disables
   indexing for individual files or entire directory trees.

The command carries `CommandFlags.Unsafe | CommandFlags.Standard |
CommandFlags.Initialize | CommandFlags.SecuritySdk |
CommandFlags.LicenseSdk` and belongs to the `"scriptEnvironment"` object
group.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Package.cs` | ~1,450 | Main command implementation (23 sub-commands) |
| `Eagle/Library/Components/Private/PackageOps.cs` | 4,767 | Package operations: index discovery, version comparison, security checks, script generation |
| `Eagle/Library/Components/Public/Interpreter.cs` | 124,855 | Package storage, alias resolution, fallback chain, auto-path management |
| `Eagle/Library/Components/Public/PackageData.cs` | ~191 | Package metadata implementation (IPackageData) |
| `Eagle/Library/Components/Private/PackageContextClientData.cs` | ~250 | State management during index evaluation |
| `Eagle/Library/Containers/Private/PackageIndexDictionary.cs` | ~71 | Index file → flags mapping |
| `Eagle/Library/Containers/Private/PackageAliasDictionary.cs` | ~100 | Alias name → (package, version, flags) mapping |
| `Eagle/Library/Components/Public/Enumerations.cs` | large | PackageFlags, PackageIndexFlags, PackageType enums |
| `Eagle/Library/Components/Private/GlobalState.cs` | large | Auto-path list construction and caching |

## 2. Why This Command Differs from Tcl

### Tcl compatibility

Eagle's `[package]` supports the core Tcl sub-commands (`require`,
`provide`, `ifneeded`, `forget`, `names`, `versions`, `vcompare`,
`vsatisfies`, `unknown`) with compatible semantics. Tcl scripts that
use standard package management patterns work unchanged.

### Eagle extensions

Eagle adds 14 sub-commands beyond Tcl's standard set:

| Sub-command | Purpose |
|-------------|---------|
| `absent` | Pre-condition: verify package is NOT loaded |
| `alias` / `aliases` | Package name aliasing with version and flag overrides |
| `indexes` | List discovered package index files |
| `[info]` | Detailed package metadata (flags, paths, loaded status) |
| `loaded` / `vloaded` | Query loaded packages (with/without version info) |
| `pending` | Check if packages are currently being loaded |
| `present` | Post-condition: verify package IS loaded |
| `relativefilename` | Convert paths relative to package directory |
| `reset` | Clear all package index information |
| `scan` | Multi-source index discovery with 30+ options |
| `vsort` | Version sorting |
| `withdraw` | Unload a package without removing its registration |

### No `pkgIndex.tcl` — Eagle uses `pkgIndex.eagle`

Eagle's package index files are named `pkgIndex.eagle` (not
`pkgIndex.tcl`). They contain Eagle scripts that register packages via
`[package ifneeded]`, just like Tcl, but the scripts can use Eagle's
full feature set including .NET interop.

## 3. Sub-Command Reference

### Package loading and requiring

#### `[package require]`

```tcl
package require ?options? package ?version?
```

| Option | Type | Description |
|--------|------|-------------|
| `-exact` | flag | Require exact version match (Tcl-compatible) |
| `-autoscan` | bool | Enable/disable auto-scanning on failure |

The `require` sub-command implements a **multi-stage fallback chain**
when a package is not immediately available:

```tcl
1. interpreter.RequirePackage(name, version, exact)
   └─ If fails:
2. PkgAutoScan() — rescan package indexes (if -autoscan enabled)
   └─ RequirePackage() again
      └─ If fails:
3. PackageFallback delegate — custom callback (if configured)
   └─ RequirePackage() again
      └─ If fails:
4. PackageUnknown script — evaluate unknown handler
   └─ RequirePackage() again
      └─ If fails: return combined error list
```

Each stage is gated by interpreter flags:
- `InterpreterFlags.NoPackageFallback` — skip stage 3
- `InterpreterFlags.NoPackageUnknown` — skip stage 4

Returns the version of the loaded package on success.

#### `[package present]`

```tcl
package present ?-exact? package ?version?
```

Checks if a package is already loaded without attempting to load it.
Returns the version if present; raises an error otherwise. Useful as a
post-condition check.

#### `[package absent]`

```tcl
package absent ?-exact? package ?version?
```

Checks that a package is NOT loaded. Returns success if absent; raises
an error if present. Useful as a pre-condition check before loading a
specific version.

### Package providing and registration

#### `[package provide]`

```tcl
package provide package ?version?
```

Declares that the current script provides a package at a version. Without
a version argument, returns the currently provided version.

**Special behavior**: If the `PackageFlags.NoProvide` flag is set on the
interpreter, `[package provide]` silently does nothing and returns an
empty string. This is used during security package initialization.

#### `[package ifneeded]`

```tcl
package ifneeded package version ?script? ?flags?
```

Registers a script to execute when `[package require]` needs a specific
version. Without a script argument, returns the currently registered
script.

Eagle extends Tcl's `ifneeded` with an optional `flags` parameter
(`PackageFlags` enum) that controls package behavior:

```tcl
# Register with flags
package ifneeded mypackage 1.0 \
    [list source [file join $dir mypackage.eagle]] \
    {Core, Locked}
```

**Locked package behavior**: If a package has the `Locked` flag:
- `Locked` alone: `ifneeded` silently succeeds without modifying the
  registration.
- `Locked | Rejected`: `ifneeded` returns an error: `"rejected: package
  <name> is locked"`.

### Package discovery and scanning

#### `[package scan]`

```tcl
package scan ?options? ?dir dir ...?
```

This is the most complex sub-command, with 30+ options controlling
multi-source package index discovery. See §5 for the full pipeline
description.

**Key option groups:**

| Category | Options | Effect |
|----------|---------|--------|
| Source control | `-host`, `-nohost`, `-bundle`, `-nobundle`, `-plugin`, `-noplugin`, `-normal`, `-nonormal` | Which sources to search |
| Index types | `-primary`, `-noprimary`, `-tagged`, `-notagged` | Which index file types to include |
| Search behavior | `-recursive`, `-refresh`, `-resolve` | How to search |
| Precedence | `-preferfilesystem`, `-preferhost` | Source priority order |
| Security | `-notrusted`, `-noverified` | Skip signature checks |
| Output | `-trace`, `-verbose`, `-dump`, `-whatif` | Diagnostics |
| State | `-reset`, `-autopath`, `-temporary` | State management |
| Error handling | `-nocomplain`, `-fileerror` | Error behavior |
| Flags | `-flags` | Direct `PackageIndexFlags` enum value |
| Scope | `-interpreter` | Use interpreter-specific vs global defaults |

**What-if mode** (`-whatif`): Runs the discovery pipeline without
modifying interpreter state, returning a preview of what would be
found. Cannot be combined with `-host`, `-bundle`, or `-plugin`.

#### `[package indexes]`

```tcl
package indexes ?pattern?
```

Returns the list of discovered package index files, optionally filtered
by a glob pattern.

#### `[package reset]`

```tcl
package reset
```

Clears all package index information, forcing a full rediscovery on the
next `[package require]` or `[package scan]`.

### Package aliases

#### `[package alias]`

```tcl
package alias ?options? name ?package? ?version?
```

| Option | Type | Description |
|--------|------|-------------|
| `-overwrite` | flag | Overwrite existing alias |
| `-disabled` | flag | Create a disabled alias |
| `-exact` | flag | Require exact version match |

Creates an alias `name` that redirects to `[package]` at `[version]`. When
`package require name` is called, the alias is transparently resolved
to the target package.

**Alias resolution** uses a while-loop with **circular reference
detection**: a `found` dictionary tracks visited aliases, and if an
alias is encountered twice, the loop terminates to prevent infinite
recursion.

**Disabled aliases**: The `-disabled` flag creates an alias entry that
exists but is skipped during resolution. This can be used to temporarily
disable an alias without removing it.

#### `[package aliases]`

```tcl
package aliases ?pattern?
```

Returns all package aliases matching the optional glob pattern.

### Package information

#### `[package info]`

```tcl
package info name
```

Returns detailed metadata about a package as a key-value list:

| Key | Value | Notes |
|-----|-------|-------|
| `kind` | IdentifierKind | Package type identifier |
| `id` | Guid | Unique package ID |
| `name` | string | Package name |
| `description` | string | Package description |
| `indexFileName` | string | Path to index file (scrubbed in safe mode) |
| `provideFileName` | string | Path to provide script (scrubbed in safe mode) |
| `flags` | PackageFlags | Current package flags |
| `loaded` | Version | Currently loaded version |
| `ifNeeded` | dict | Version → script mapping (hidden in safe mode) |
| `wasNeeded` | string | Version that was last requested |

#### `[package names]`, `[package loaded]`, `[package vloaded]`, `[package versions]`

```tcl
package names ?pattern?
package loaded ?pattern?
package vloaded ?pattern?
package versions package
```

Query commands for listing known packages, loaded packages (with or
without version info), and available versions of a specific package.

#### `[package pending]`

```tcl
package pending ?name?
```

Without a name: returns `true` if any package is currently being loaded
(`PackageLevels > 0`). With a name: checks if a specific package has
the `PackageFlags.Loading` flag set. Useful for dependency cycle
detection.

### Package removal

#### `[package forget]`

```tcl
package forget ?package package ...?
```

Completely removes packages from the interpreter. The package entry is
deleted, and all associated metadata is discarded. This is a permanent
removal.

#### `[package withdraw]`

```tcl
package withdraw package ?version?
```

Marks a package as unloaded by setting `package.Loaded = null`, but
preserves the package's registration and `ifNeeded` scripts. The
package can be loaded again via `[package require]`. This is a
temporary unload — the distinction from `forget` is that withdraw
preserves the package entry while forget deletes it.

### Version utilities

#### `[package vcompare]`, `[package vsatisfies]`, `[package vsort]`

```tcl
package vcompare version1 version2
package vsatisfies version1 version2
package vsort version1 version2
```

Standard Tcl version operations. `vcompare` returns `-1`, `0`, or `1`.
`vsatisfies` returns a boolean. `vsort` sorts two versions.

**Fallback behavior**: If version strings fail to parse as .NET
`Version` objects, `vcompare` raises an error while `vsort` falls back to string
comparison rather than raising an error.

**AlwaysSatisfy flag**: If `PackageFlags.AlwaysSatisfy` is set on the
interpreter, `vsatisfies` always returns `true`. This is used during
security package initialization to prevent version conflicts.

### Utility

#### `[package unknown]`

```tcl
package unknown ?command?
```

Gets or sets the unknown package handler script, evaluated as the last
resort in the `[package require]` fallback chain.

#### `[package relativefilename]`

```tcl
package relativefilename fileName ?type?
```

Converts a file path to be relative to the package index directory.
The optional `type` parameter (`PathComparisonType` enum) controls
the comparison strategy.

## 4. The Auto-Path System

### What is `auto_path`?

The `auto_path` variable is a Tcl list of directories that the package
subsystem searches for package index files. Eagle extends this concept
with multi-source path construction, environment variable integration,
and an automatic rescan mechanism via variable traces.

### Auto-path construction

The auto-path is built by `GlobalState.GetAutoPathList()`, which
combines **interpreter-specific paths** and **shared global paths**:

#### Interpreter-specific paths

- `interpreterLibraryPath` — The interpreter's library path override
- `interpreterAutoPathList` — Paths explicitly set on the interpreter

#### Shared global paths (from environment and assembly location)

The shared auto-path is populated from these sources, in this priority
order:

| Source | Environment Variable | Description |
|--------|---------------------|-------------|
| Eagle library | `EAGLE_LIBRARY` | Explicit Eagle library path |
| Assembly location | (computed) | Directory containing Eagle.dll |
| Tcl library | `TCL_LIBRARY` | Tcl library path (for compatibility) |
| Eagle lib paths | `EAGLELIBPATH` | Additional search directories (space-separated list) |
| Tcl lib paths | `TCLLIBPATH` | Tcl library paths (space-separated list) |
| Unix package paths | (computed) | `/usr/local/lib/eagle<ver>`, `/usr/lib/eagle<ver>` |
| Binary directory | (computed) | Package subdirectories under the binary location |
| Assembly directory | (computed) | Package subdirectories under the assembly location |
| Peer directories | (computed) | Sibling directories of the binary/assembly location |
| Root directories | (computed) | Root-level package paths |

#### Path filtering

A path is only added to the auto-path if:
1. It is not null or empty.
2. It is not already in the list (no duplicates).
3. If strict mode is enabled: the directory must exist on the filesystem.
4. If a `No_<pathName>` environment variable exists: the path is skipped
   (allows selective disabling of individual paths).

#### Caching

The shared auto-path list is cached in `GlobalState` for efficiency.
It is only rebuilt when:
- First accessed (lazy initialization).
- Explicitly refreshed via `GlobalState.RefreshAutoPathList()`.
- The `-autopath` flag is used with `[package scan]`.

### Auto-path initialization during interpreter creation

The auto-path is initialized in **two phases** during interpreter
creation:

**Phase 1 — Early initialization** (before script library loading):
- Calls `PrivateInitializeAutoPath(null, true, true, true)`.
- Sets a minimal auto-path to bootstrap the interpreter.
- Does not load the full global auto-path list yet.

**Phase 2 — Final initialization** (after script library loading):
- Calls `PrivateInitializeAutoPath(autoPathList, false, false, false)`.
- If `InitializeFlags.SetAutoPath` is set:
  - If `InitializeFlags.GlobalAutoPath` is set: calls
    `GlobalState.GetAutoPathList(interpreter)` to build the full path
    list.
  - If `InitializeFlags.MergeAutoPath` is set: merges new paths with
    any existing paths.
  - Calls `SetAutoPathList()` to set the `auto_path` variable.
  - Attaches the **AutoPathTraceCallback** to monitor future changes.

### The `AutoPathTraceCallback`

After initialization, a variable trace is attached to `auto_path` that
automatically triggers package index rescanning whenever the variable
is modified:

**On `auto_path` SET (BeforeVariableSet)**:
1. Parses the new `auto_path` value as a Tcl list of directories.
2. In safe interpreters: validates that all directories are under the
   interpreter's base path (security constraint).
3. Calls `PackageOps.FindAll()` with `PackageIndexFlags.AutoPath` flags
   to perform a full index rescan of the new directories.
4. Updates `interpreter.PackageIndexes` with the discovery results.

**On `auto_path` UNSET (BeforeVariableUnset)**:
1. Clears the `NoRemove` flag to allow the variable to be unset.
2. Calls `interpreter.ResetPkgIndexes()` to clear all package index
   information.

This means that simply appending a directory to `auto_path` triggers
automatic discovery of any packages in that directory — no explicit
`[package scan]` is needed.

### The `PackageIndexFlags.AutoPath` composite flag

The `AutoPath` flag is a composite that configures the rescan triggered
by auto-path changes:

```tcl
AutoPath = Host | Bundle | Normal | Primary | Tagged
         | NoNormal | Recursive | NoSort | Dump
```

In DEBUG builds, it also includes `MaybeNoTrusted | MaybeNoVerified`
to relax security checks during development.

### Auto-path and `package scan -autopath`

The `-autopath` flag on `[package scan]` triggers a special mode:
1. Calls `GlobalState.GetAutoPathList(interpreter, true)` with `refresh=true` to
   re-read environment variables and rebuild the path list.
2. Updates the `auto_path` variable with the refreshed paths via
   `interpreter.SetAutoPathList()`.
3. Uses the refreshed paths for the scan operation.

This is useful after environment changes to force the interpreter to
pick up new package directories.

## 5. The Package Index Discovery Pipeline

### Overview

The `PackageOps.FindAll()` method orchestrates multi-source package
index discovery. It searches four sources and can be configured to
search them in different orders:

```tcl
FindAll(interpreter, paths, flags, ...)
├─ ShouldPreferFileSystem() → determines order
│
├─ Path A: FileSystem-First (PreferFileSystem = true)
│   ├─ FindFile()     — filesystem pkgIndex.eagle files
│   ├─ FindPlugin()   — plugin assembly embedded indexes
│   └─ FindHost()     — built-in host/library indexes
│
└─ Path B: Host-First (default)
    ├─ FindHost()     — built-in host/library indexes
    ├─ FindPlugin()   — plugin assembly embedded indexes
    └─ FindFile()     — filesystem pkgIndex.eagle files
│
└─ RemoveLogicalDuplicates() — deduplicate across sources
```

### Source 1: FindHost — Built-in library indexes

Discovers package indexes embedded in the Eagle runtime:

| PackageType | Index path | Purpose |
|-------------|-----------|---------|
| `Loader` | `lib/Loader1.0/pkgIndex.eagle` | Plugin loader package |
| `Library` | `lib/Eagle1.0/pkgIndex.eagle` | Core script library |
| `Test` | `lib/Test1.0/pkgIndex.eagle` | Test framework |
| `Kit` | `lib/Kit1.0/pkgIndex.eagle` | Kit packages |
| `Bundle` | (from BundleManager) | Bundle-embedded indexes |
| `Host` | (from host list file) | Host-defined packages |

Bundle indexes are gathered via `DataOps.GatherBundleScripts()` from
mounted bundle databases. Host indexes are read from a host list file
in the interpreter's script library.

### Source 2: FindFile — Filesystem indexes

Searches specified directories for two types of index files:

**Primary indexes** (`-primary` flag):
- Pattern: `pkgIndex.eagle`
- Standard package index files, one per directory.

**Tagged indexes** (`-tagged` flag):
- Pattern: `pkgIndex_XXXXXXXXXXXXXXXX.eagle` (16 hex digits)
- Regex: `^pkgIndex_([0-9a-f]{16})\.eagle$`
- Multiple tagged indexes can coexist in a single directory.
- The tag is extracted and made available as the `$tag` variable
  during script evaluation.

For each directory:
1. Check if disabled via `.noPkgIndex` (see §7).
2. Search for primary and/or tagged index files.
3. Extract tags from tagged filenames via regex.
4. Call `InvokeCallback()` for each file found.

The `-recursive` flag enables subdirectory searching.

### Source 3: FindPlugin — Plugin assembly indexes

Searches for `.dll` files in plugin directories and extracts embedded
`pkgIndex.eagle` resources:

1. Find `.dll` files matching plugin patterns (default: `*.dll`).
2. For each assembly:
   - Check if disabled via `.noPkgIndex`.
   - Skip the Eagle core assembly itself.
   - Verify it is a managed assembly (`RuntimeOps.IsManagedAssembly()`).
   - If not `-notrusted`: verify Authenticode signature.
   - If not `-noverified`: verify StrongName signature.
3. Call `InvokeCallback()`, which uses
   `RuntimeOps.PreviewPluginResources()` to extract and evaluate
   embedded `pkgIndex.eagle` resources.

### Source 4: Bundle indexes

When `PackageIndexFlags.Bundle` is set, the discovery pipeline queries
the interpreter's `BundleManager` for mounted bundle databases
containing package index scripts. See [`sql.md`](sql.md) for details
on the bundle system.

### The `InvokeCallback` state manager

Each discovered index file is processed through `InvokeCallback()`,
which manages interpreter state during script evaluation:

1. **Set context**: If what-if mode, swap the interpreter's
   `ContextClientData` to track discoveries without modifying state.
2. **Begin pending**: Call `interpreter.BeginPendingPackageIndexes()` to
   prevent recursive package index evaluation.
3. **Set temporary mode**: If `-temporary`, call
   `interpreter.SetTemporaryPackages()` to mark any packages added
   during evaluation as temporary.
4. **Execute callback**: Call the `IndexCallback` delegate, which:
   - Sets the `$dir` variable to the directory containing the index
     file.
   - Sets the `$tag` variable to the extracted tag (for tagged indexes).
   - Evaluates the index script.
   - Restores `$dir` and `$tag` to their previous values.
5. **Clean up**: Restore all interpreter state in `finally` blocks.

## 6. Tagged Package Indexes

### What are tagged indexes?

Tagged package indexes are files named `pkgIndex_XXXXXXXXXXXXXXXX.eagle`
where `XXXXXXXXXXXXXXXX` is exactly 16 hexadecimal digits. They allow
multiple index files to coexist in a single directory, each identified
by a unique tag.

### Tag extraction

The tag is extracted from the filename using a compiled regex:

```tcl
^pkgIndex_([0-9a-f]{16})\.eagle$
```

The regex is case-insensitive and captures the 16-hex-digit tag as
group 1. Tags that don't match this exact pattern are ignored.

### The `$tag` variable

When a tagged index script is evaluated, the `$tag` variable is set to
the extracted tag value. The script can use this to make decisions:

```tcl
# In pkgIndex_00000000deadbeef.eagle
package ifneeded mypackage-$tag 1.0 \
    [list source [file join $dir mypackage_$tag.eagle]]
```

The `$tag` variable is automatically set before evaluation and restored
(or unset) after evaluation. For non-tagged (primary) index files,
`$tag` is not set.

### Use cases

- **Variant packages**: Multiple builds or configurations of the same
  package in one directory, distinguished by tag.
- **Plugin identification**: Tags derived from assembly public key
  tokens (which are also 16 hex digits), linking index files to
  specific signed assemblies.
- **Version-specific indexes**: Different index files for different
  deployment contexts.

### Enabling tagged index discovery

Tagged indexes are only discovered when the `PackageIndexFlags.Tagged`
flag is set. This can be controlled via:
- `package scan -tagged` — enable tagged index discovery.
- `package scan -notagged` — disable tagged index discovery.
- The `PackageIndexFlags.AutoPath` composite flag includes `Tagged` by
  default, so auto-path rescans always discover tagged indexes.

## 7. Security Features

### Authenticode and StrongName verification

During `FindPlugin` and `IsDirectory` checks, assemblies can be
verified for code signing:

- **Authenticode verification** (`RuntimeOps.IsFileTrusted()`): Checks
  that the assembly has a valid Authenticode signature from a trusted
  certificate authority.
- **StrongName verification** (`RuntimeOps.IsStrongNameVerified()`):
  Checks that the assembly's strong name signature is valid and the
  assembly has not been tampered with.

Both checks can be skipped individually:
- `package scan -notrusted` — Skip Authenticode verification.
- `package scan -noverified` — Skip StrongName verification.

### Locked and rejected packages

The `Locked` and `Rejected` flags in `PackageFlags` protect packages
from modification:

| Flags | `[package ifneeded]` behavior |
|-------|-----------------------------|
| (none) | Normal: registers or updates the package script |
| `Locked` | Silent no-op: returns success without modifying the registration |
| `Locked \| Rejected` | Error: returns `"rejected: package <name> is locked"` |

These flags prevent untrusted code from overriding critical package
registrations.

### Public key token verification

Plugin-based packages can include public key token verification in
their `[load]` commands. The token (16 hex digits) is extracted from
the assembly and embedded in the generated `[package ifneeded]` script:

```tcl
package ifneeded MyPlugin 1.0 \
    [list load -publickeytoken "00000000deadbeef" MyPlugin.dll]
```

### Safe mode restrictions

In safe interpreters:
- `[package info]` scrubs file paths via `PathOps.ScrubPath()` for
  `indexFileName` and `provideFileName`.
- The `ifNeeded` dictionary is hidden entirely.
- Certain sub-commands may be disallowed via
  `PolicyOps.DisallowedPackageSubCommandNames`.

### The `.noPkgIndex` disable mechanism

Package indexing can be disabled for individual files or entire
directory trees using marker files:

- **Disable a specific index file**: Create a sibling file named
  `<fileName>.noPkgIndex` (e.g., `pkgIndex.eagle.noPkgIndex`).
- **Disable an entire directory**: Create a file or directory named
  `.noPkgIndex` within the directory.

The `IsDisabled()` method checks recursively up the directory tree, so
a `.noPkgIndex` in a parent directory disables all descendants.

## 8. The `PackageFlags` Enumeration

### Instance flags (package state)

| Flag | Value | Description |
|------|-------|-------------|
| `System` | 0x2 | System package (do not modify) |
| `Loading` | 0x4 | Currently being loaded via `[package require]` |
| `Static` | 0x8 | Provided statically |
| `Core` | 0x10 | Included with the Eagle runtime |
| `Plugin` | 0x20 | Provided by a loaded plugin |
| `Library` | 0x40 | Part of the script library |
| `Interactive` | 0x80 | From the interactive shell |
| `Automatic` | 0x100 | Added automatically |
| `Locked` | 0x200 | Cannot be replaced via `[package ifneeded]` |
| `Rejected` | 0x400 | With `Locked`, generates error on replacement |
| `Temporary` | 0x800 | Added via core script file evaluation |

### Action flags (behavior modifiers)

| Flag | Value | Description |
|------|-------|-------------|
| `NoUpdate` | 0x1000 | Skip updating flags on provide |
| `NoProvide` | 0x2000 | `[package provide]` does nothing |
| `AlwaysSatisfy` | 0x4000 | `[package vsatisfies]` always returns true |
| `KeepExisting` | 0x8000 | `[package ifneeded]` preserves existing info |
| `FailExisting` | 0x10000 | `[package ifneeded]` fails if info exists |
| `NoAttributes` | 0x20000 | Skip querying managed type flags |
| `AutoScan` | 0x1000000 | Enable auto-scan on `[package require]` failure |

### Alias flags

| Flag | Value | Description |
|------|-------|-------------|
| `NoAlias` | 0x100000 | Disable alias resolution for this package |
| `Overwrite` | 0x200000 | Overwrite existing alias entry |
| `Disabled` | 0x400000 | Alias exists but is skipped during resolution |
| `Exact` | 0x800000 | Require exact version match |

### Special masks

| Mask | Composition | Purpose |
|------|-------------|---------|
| `SecurityPackageMask` | `NoProvide \| AlwaysSatisfy` | Security package initialization |
| `InstanceMask` | All instance flags | Identify package state flags |
| `ActionMask` | All action flags | Identify behavior modifier flags |
| `AliasMask` | `Disabled \| Exact` | Identify alias-related flags |

## 9. The `PackageIndexFlags` Enumeration

### Source control flags

| Flag | Value | Description |
|------|-------|-------------|
| `PreferFileSystem` | 0x4 | Search filesystem before host |
| `PreferHost` | 0x8 | Search host before filesystem |
| `Host` | 0x10 | Search interpreter host resources |
| `Bundle` | 0x20 | Search bundle databases |
| `Plugin` | 0x40 | Search plugin assemblies |
| `Normal` | 0x80 | Search external filesystem |
| `NoNormal` | 0x100 | Forbid filesystem search |

### Index type flags

| Flag | Value | Description |
|------|-------|-------------|
| `Primary` | 0x10000000 | Include primary `pkgIndex.eagle` files |
| `Tagged` | 0x20000000 | Include tagged `pkgIndex_XXXX.eagle` files |

### Behavior flags

| Flag | Value | Description |
|------|-------|-------------|
| `Recursive` | 0x200 | Search subdirectories |
| `Refresh` | 0x400 | Force re-discovery and re-evaluation |
| `Resolve` | 0x800 | Resolve fully qualified names |
| `Temporary` | 0x8000000 | Mark discovered packages as temporary |
| `WhatIf` | 0x4000000 | Preview without modifying state |
| `Safe` | 0x10000 | Evaluate index scripts in safe mode |

### Security flags

| Flag | Value | Description |
|------|-------|-------------|
| `NoTrusted` | 0x200000 | Skip Authenticode verification |
| `NoVerified` | 0x400000 | Skip StrongName verification |

### Diagnostic flags

| Flag | Value | Description |
|------|-------|-------------|
| `Trace` | 0x1000 | Enable operation tracing |
| `Verbose` | 0x2000 | Enable verbose output |
| `Dump` | 0x40000000 | Dump all indexes at end |
| `NoFileError` | 0x80000 | Don't fail on GetFiles exceptions |

## 10. The Package Require Fallback Chain

The `[package require]` fallback chain is Eagle's most important
extension to Tcl's package loading:

### Stage 1: Direct require

Calls `interpreter.RequirePackage(name, version, exact)`. This checks
if the package is already provided or if an `ifNeeded` script is
registered.

**Alias resolution** happens first: `MaybeUsePackageAliases()` resolves
any alias chain (with circular reference detection) before the actual
require.

### Stage 2: Auto-scan

If stage 1 fails and auto-scan is enabled (via `-autoscan true` or the
`PackageFlags.AutoScan` flag):

1. Calls `Interpreter.PkgAutoScan()`.
2. This generates and evaluates a `[package scan]` command with the
   interpreter's auto-path directories.
3. Retries `RequirePackage()`.

### Stage 3: PackageFallback delegate

If stage 2 fails and `InterpreterFlags.NoPackageFallback` is not set:

1. Retrieves `interpreter.PackageFallback` (a `PackageCallback`
   delegate).
2. Calls the delegate with the interpreter, package name, version,
   flags, and exact flag.
3. The delegate is responsible for making the package available (e.g.,
   downloading it, extracting it, registering it).
4. If the delegate returns `Ok`, retries `RequirePackage()`.

The delegate signature:

```csharp
ReturnCode PackageCallback(
    Interpreter interpreter,
    string name,
    Version version,
    string text,
    PackageFlags flags,
    bool exact,
    ref Result result
);
```

### Stage 4: PackageUnknown script

If stage 3 fails and `InterpreterFlags.NoPackageUnknown` is not set:

1. Retrieves `interpreter.PackageUnknown` (a script string).
2. Constructs a command via `ScriptOps.GetPackageUnknownScript()`.
3. Evaluates the script.
4. Retries `RequirePackage()`.

This is equivalent to Tcl's `[package unknown]` handler.

### Error aggregation

If all stages fail, errors from each stage are collected into a
`ResultList` and returned as a combined error message.

## 11. The `PackageFallback` Delegate

The `PackageFallback` delegate is a per-interpreter callback that
provides a programmatic hook for package resolution. It is stored as a
thread-safe property on the interpreter:

```csharp
// C# code to install a package fallback
interpreter.PackageFallback = delegate(
    Interpreter interp, string name, Version version,
    string text, PackageFlags flags, bool exact,
    ref Result result)
{
    // Download the package from a repository
    if (DownloadPackage(name, version, out string path))
    {
        // Register the package
        interp.PkgIfNeeded(name, version,
            $"source {path}", null, PackageFlags.None,
            ref result);
        return ReturnCode.Ok;
    }
    result = $"package {name} not found in repository";
    return ReturnCode.Error;
};
```

The corresponding `IPackageCallback` interface allows the same
functionality via interface implementation rather than delegates:

```csharp
public interface IPackageCallback
{
    ReturnCode PackageFallback(
        Interpreter interpreter, string name,
        Version version, string text,
        PackageFlags flags, bool exact,
        ref Result result);
}
```

## 12. The `PackageType` Enumeration

The `PackageType` enum classifies packages by their origin:

| Type | Value | Description |
|------|-------|-------------|
| `None` | 0x0 | Unspecified |
| `Invalid` | 0x1 | Invalid package type |
| `Loader` | 0x2 | Plugin loader package |
| `Library` | 0x4 | Script library package (Eagle1.0) |
| `Test` | 0x8 | Test suite package (Test1.0) |
| `Kit` | 0x10 | Kit packages |
| `Host` | 0x20 | Host-defined package |
| `Bundle` | 0x40 | Bundle-defined package |
| `Automatic` | 0x80 | Auto-determine type |
| `Default` | 0x100 | Internal use only |

Each type maps to a specific index file location:
- `Loader` → `lib/Loader1.0/pkgIndex.eagle`
- `Library` → `lib/Eagle1.0/pkgIndex.eagle`
- `Test` → `lib/Test1.0/pkgIndex.eagle`
- `Kit` → `lib/Kit1.0/pkgIndex.eagle`
- `Host`, `Bundle`, `None` → `pkgIndex.eagle` (generic)

## 13. Practical Patterns

### Pattern 1: Standard package loading

```tcl
# Load a package (with auto-scan fallback)
package require Eagle.Library

# Require exact version
package require -exact MyPackage 2.0

# Check if loaded without loading
if {[catch {package present MyPackage}]} {
    puts "MyPackage not loaded"
}
```

### Pattern 2: Creating a package

```tcl
# In mypackage.eagle
package provide mypackage 1.0

namespace eval ::mypackage {
    proc hello {} { return "Hello from mypackage" }
    namespace export hello
}
```

```tcl
# In pkgIndex.eagle (same directory)
package ifneeded mypackage 1.0 \
    [list source [file join $dir mypackage.eagle]]
```

### Pattern 3: Tagged package index

```tcl
# In pkgIndex_00000000deadbeef.eagle
# The $tag variable is "00000000deadbeef"
package ifneeded mypackage-$tag 1.0 \
    [list source [file join $dir mypackage_$tag.eagle]]
```

### Pattern 4: Package aliases

```tcl
# Create an alias
package alias json-parser json 2.0

# Now this loads json 2.0:
package require json-parser

# List all aliases
package aliases

# Disable an alias temporarily
package alias -disabled json-parser json 2.0
```

### Pattern 5: Scanning with security checks

```tcl
# Full security scan
package scan -host -normal -plugin -primary -tagged \
    -recursive -- /usr/local/lib/eagle

# Skip security verification (development)
package scan -notrusted -noverified -normal -primary \
    -recursive -- /tmp/dev-packages

# Preview what would be found
package scan -whatif -normal -primary -tagged \
    -recursive -- /usr/local/lib/eagle
```

### Pattern 6: Locking a critical package

```tcl
# Register and lock a package
package ifneeded critical-pkg 1.0 \
    [list source [file join $dir critical.eagle]] \
    {Core, Locked, Rejected}

# This now raises an error:
catch {
    package ifneeded critical-pkg 1.0 {evil script}
} err
# err = "rejected: package critical-pkg is locked"
```

### Pattern 7: Dynamic auto-path modification

```tcl
# Adding to auto_path triggers automatic package discovery
lappend auto_path /new/package/directory

# The package is now available without explicit scanning:
package require newly-discovered-package
```

### Pattern 8: Disabling package indexing

```tcl
# Disable indexing for a specific directory
# Create: /packages/untested/.noPkgIndex

# Disable a specific index file
# Create: /packages/stable/pkgIndex.eagle.noPkgIndex

# The disable marker is checked recursively up the tree
```

### Pattern 9: Package withdrawal and re-loading

```tcl
# Load a package
package require mypackage 1.0

# Withdraw it (unload, but keep registration)
package withdraw mypackage 1.0

# Load it again (re-evaluates ifneeded script)
package require mypackage 1.0

# Permanently remove it
package forget mypackage
```

### Pattern 10: Custom package fallback (C#)

```csharp
// Install a fallback that downloads packages on demand
interpreter.PackageFallback = delegate(
    Interpreter interp, string name, Version version,
    string text, PackageFlags flags, bool exact,
    ref Result result)
{
    string url = $"https://packages.example.com/{name}/{version}";
    string dir = Path.Combine(tempDir, name);

    if (DownloadAndExtract(url, dir))
    {
        // Scan the downloaded directory
        interp.EvaluateScript(
            $"package scan -normal -primary -- {dir}");
        return ReturnCode.Ok;
    }

    result = $"failed to download package {name}";
    return ReturnCode.Error;
};
```

## 14. Comparison: Tcl vs Eagle Package Management

| Feature | Tcl | Eagle |
|---------|-----|-------|
| Index file name | `pkgIndex.tcl` | `pkgIndex.eagle` |
| Tagged indexes | Not available | `pkgIndex_XXXXXXXXXXXXXXXX.eagle` with `$tag` variable |
| Index sources | Filesystem only | Host, filesystem, plugin assemblies, bundle databases |
| Discovery order | Fixed | Configurable (`PreferFileSystem`/`PreferHost`) |
| Auto-path rescan | Manual | Automatic via variable trace callback |
| Package aliases | Not available | `[package alias]` with circular reference detection |
| Locked packages | Not available | `Locked` / `Locked+Rejected` flags |
| Signature verification | Not available | Authenticode + StrongName on plugin assemblies |
| `.noPkgIndex` disable | Not available | Recursive disable markers |
| `[package absent]` | Not available | Pre-condition: verify not loaded |
| `[package present]` | Not available | Post-condition: verify loaded |
| `[package withdraw]` | Not available | Unload without removing registration |
| `[package info]` | Not available | Detailed metadata query |
| `[package scan]` options | Basic | 30+ options with what-if mode |
| `[package ifneeded]` flags | Not available | `PackageFlags` parameter |
| Package fallback delegate | Not available | Programmatic `PackageCallback` hook |
| `[package indexes]` | Not available | List discovered index files |
| `[package pending]` | Not available | Loading cycle detection |
| `[package reset]` | Not available | Clear all index information |
| What-if scanning | Not available | Preview discovery without state changes |

## 15. Security Considerations

- **`CommandFlags.Unsafe`** — The command is restricted in safe
  interpreters. The `DisallowedSubCommands` policy controls which
  sub-commands are available.

- **Safe mode scrubbing** — In safe interpreters, `[package info]`
  scrubs file paths and hides the `ifNeeded` script dictionary to
  prevent information disclosure.

- **Authenticode and StrongName** — Plugin assemblies can be verified
  during `[package scan]`. Use `-notrusted` and `-noverified` to skip
  these checks during development, but keep them enabled in production.

- **Locked packages** — Use `Locked | Rejected` to protect critical
  packages from being overridden by untrusted code.

- **`.noPkgIndex` markers** — Can be used as a security control to
  prevent specific directories from being indexed.

- **Auto-path in safe interpreters** — The `AutoPathTraceCallback`
  validates that all directories in `auto_path` are under the
  interpreter's base path, preventing sandbox escapes via path
  manipulation.

- **`SecurityPackageMask`** (`NoProvide | AlwaysSatisfy`) — Used during
  security package initialization to prevent version conflicts and
  ensure security packages load correctly.

## 16. Relationship to Other Commands

| Related command | Relationship |
|----------------|-------------|
| `[source]` | Evaluates package scripts discovered via `[package ifneeded]` |
| `[load]` | Loads .NET plugin assemblies registered by package indexes; see [`load.md`](load.md) |
| `[interp]` | Safe interpreter policies control package sub-command access; see [`interp.md`](interp.md) |
| `[library]` | Native library loading; separate from package system; see [`library.md`](library.md) |
| `[sql]` | Script bundle databases can contain package indexes; see [`sql.md`](sql.md) |
| `[info]` | `[info loaded]` shows loaded packages from a different angle |
| `[uri]` | Package toolset uses `[uri]` for downloading packages; see [`uri.md`](uri.md) |
| `[tcl]` | Tcl packages can be used via `[tcl eval]`; see [`tcl.md`](tcl.md) |

## 17. References

- **Source code**: `Eagle/Library/Commands/Package.cs` — `[package]` command (23 sub-commands)
- **Source code**: `Eagle/Library/Components/Private/PackageOps.cs` — package operations (4,767 lines)
- **Source code**: `Eagle/Library/Components/Public/Interpreter.cs` — package storage, alias resolution, auto-path
- **Source code**: `Eagle/Library/Components/Public/PackageData.cs` — package metadata
- **Source code**: `Eagle/Library/Components/Private/PackageContextClientData.cs` — index evaluation state
- **Source code**: `Eagle/Library/Components/Private/GlobalState.cs` — auto-path construction and caching
- **Source code**: `Eagle/Library/Components/Public/Enumerations.cs` — PackageFlags, PackageIndexFlags, PackageType
- **Source code**: `Eagle/Library/Containers/Private/PackageAliasDictionary.cs` — alias storage
- **Command reference**: [`core_language.md`](core_language.md#cmd-package) — `[package]` syntax and options
- **Examples**: [`core_examples.md`](core_examples.md#ex-package) — `[package]` examples
- **Script library**: [`core_script_library.md`](core_script_library.md) — Package Toolset (pkgt.eagle) procedures
- **Related**: [`load.md`](load.md) — plugin loading (often triggered by package indexes)
- **Related**: [`sql.md`](sql.md) — script bundle databases (package index source)
- **Tcl reference**: [Tcl `[package]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/package.htm)
