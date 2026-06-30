# Eagle Core Script Library

This covers Eagle's **core script library** — the `.eagle` files shipped under
`lib/Eagle1.0/` that are auto-loaded as the `Eagle.Library` package and define
helper **procedures** (e.g. `appendArgs`, `getDictionaryValue`, `lshuffle`,
`readFile`, `isWindows`). These are *script-level* helpers, distinct from the
**built-in commands** documented under [`commands/index.md`](commands/index.md)
(`set`, `lindex`, `dict`, `object`, …, implemented in C#).

All examples below were **executed** against Eagle 1.0 (see
[`verification.md`](verification.md)); `;# =>` shows the verified result. Some
outputs are **host-dependent** (platform, environment, runtime) — those were run
on macOS / .NET Core (a non-interactive shell) and are labelled as such.
Cross-cutting Tcl differences live in [`tcl-gotchas.md`](tcl-gotchas.md). For the
full 580+ procedure catalog (every proc, by file, with anchors), see
[`../../../core_script_library.md`](../../../core_script_library.md) — this page is the
orientation map plus verified examples of the highest-value procedures.

---

## How the library is packaged and loaded

The native engine itself is the package **`Eagle`** (its version is the engine
patch level). Each `.eagle` file under `lib/Eagle1.0/` provides its own
sub-package (`Eagle.Auxiliary`, `Eagle.List`, `Eagle.Platform`, …), and
`init.eagle` provides the umbrella **`Eagle.Library`** that pulls them in at
startup. So in a normal shell session the common helpers are **already loaded** —
no `package require` needed.

```tcl
puts [package require Eagle]            ;# => 1.0.9675.37713   (engine version; host build)
puts [info procs appendArgs]           ;# => appendArgs        (auto-loaded, exported global)
puts [info procs getDictionaryValue]   ;# => getDictionaryValue
```

Procedures are defined in the `::Eagle` namespace and exported into the global
namespace, so you call them unqualified. A handful of files are **load-on-demand**
and their procs are *not* present until you require them — most importantly the
**test framework**:

```tcl
puts [info commands haveConstraint]    ;# => (empty)           before requiring the test pkg
package require Eagle.Test             ;# => 1.0.9675.37713
puts [info commands haveConstraint]    ;# => haveConstraint    now available
```

> Verify availability before relying on a proc: `info commands <name>` (or
> `info procs <name>`). If it is empty, it lives in a load-on-demand package
> (`Eagle.Test`, `Eagle.Test.Constraints`, …) — `package require` it first.

A few entries in the directory are not procedure libraries at all:
`embed.eagle` (application-embedding init hook) and `vendor.eagle` (vendor
customization hook) are intentionally empty extension points; `word.tcl` sets
Tcl's `tcl_wordchars`/`tcl_nonwordchars` for word-boundary compatibility;
`pkgIndex.eagle`/`pkgIndex.tcl` are the package indexes that register everything.

---

## Source-file map (`lib/Eagle1.0/`)

Each file is the named package; `init.eagle` (`Eagle.Library`) requires the rest.

| File | Package | Role |
|------|---------|------|
| `init.eagle` | `Eagle.Library` | Interpreter initialization; umbrella package that loads the others; core predicates (`isEagle`, …) |
| `auxiliary.eagle` | `Eagle.Auxiliary` | Small everyday helpers: `appendArgs`, `getDictionaryValue`, `getEnvironmentVariable` |
| `compat.eagle` | `Eagle.Tcl.Compatibility` | Native-Tcl compatibility shims (e.g. `getHostSize`) |
| `shim.eagle` | `Eagle.Tcl.Shim` | Tcl-side shims so the same scripts run under native Tcl (e.g. `[debug]`, `getLengthModifier`) |
| `list.eagle` | `Eagle.List` | List utilities: `lappendArgs`, `lshuffle`, `ldifference`, `filter`, `map`, `reduce` |
| `platform.eagle` | `Eagle.Platform` | Platform/runtime predicates: `isWindows`, `isMacOS`, `isMono`, `isDotNetCore`, `isAdministrator`, `isInteractive`, `isSameFileName`, `addToPath` |
| `file1.eagle` | `Eagle.File` | Basic binary file I/O: `readFile`, `writeFile`, `appendFile`, `makeBinaryChannel` |
| `file2.eagle` | `Eagle.File.Types` | Typed/log/shared file I/O: `readAsciiFile`, `writeAsciiFile`, `appendLogFile`, shared (locked) read/append |
| `file2u.eagle` | `Eagle.File.Utf8` | UTF-8 / Unicode-aware file I/O variants |
| `file3.eagle` | `Eagle.File.Finder` | File/directory discovery and copy: `findFiles`, `findFilesRecursive`, `findDirectories`, `copyFilesRecursive` |
| `exec.eagle` | `Eagle.Execute` | External/nested execution helpers: `execShell`, `getShellExecutableName`, `getRuntimeCommandLine` |
| `info.eagle` | `Eagle.Information` | Environment/introspection: `getPlatformInfo`, `getCompileInfo`, `getBasePath`, plugin/Garuda info |
| `object.eagle` | `Eagle.Object` | CLR/reflection helpers: `combineFlags`, `getReturnType`, `getDefaultValue`, `isObjectHandle`, `evalAsync` |
| `process.eagle` | `Eagle.Process` | Process listing/ownership: `getProcesses`, `getOwnerForProcess` |
| `runopt.eagle` | `Eagle.Runtime.Option` | Runtime-option toggles: `hasRuntimeOption`, `addRuntimeOption`, `toggleRuntimeOption` |
| `csharp.eagle` | `Eagle.CSharp` | In-process C# compilation (CodeDom / .NET Core SDK): `compileViaCSharpCodeProvider`, `doesCompileCSharpWork` |
| `database.eagle` | `Eagle.Database` | ADO.NET row/column helpers: `getColumnValue`, `getRowColumnValue`, `haveColumnValue` |
| `unkobj.eagle` | `Eagle.Unknown.Object` | Unknown-object handler (`unknownObjectInvoke`) for fluent CLR member access |
| `unzip.eagle` | `Eagle.Unzip` | ZIP archive extraction: `extractZipArchive` |
| `update.eagle` | `Eagle.Update` | Software/self-update machinery: `checkForUpdate`, `checkForEngine`, `getUpdateFileName` |
| `pkgt.eagle` | `Eagle.Package.Toolset` | Package toolset: download/extract native Tcl/Tk, client/security toolsets; package index rescans |
| `safe.eagle` | `Eagle.Safe` | Safe-interpreter initialization helpers (e.g. `help` for sandboxed interps) |
| `shell.eagle` | `Eagle.Shell` | Interactive-shell helpers: downloads, `getExternalIpAddress`, remote/sandbox eval |
| `testlog.eagle` | `Eagle.Test.Log` | Test-log queue helpers |
| `test.eagle` | `Eagle.Test` (and `tcltest`) | The test framework (load-on-demand): `runTest`, `addConstraint`, `haveConstraint`, prologue/epilogue |
| `embed.eagle` | — | Application-embedding init hook (empty extension point) |
| `vendor.eagle` | — | Vendor customization hook (empty extension point) |
| `word.tcl` | — | Tcl word-boundary char-class compatibility |

The companion **`Test1.0/`** directory holds the rest of the test harness:
`constraints.eagle` (`Eagle.Test.Constraints`), plus `prologue.eagle`,
`epilogue.eagle`, and `all.eagle` (test-suite driver scaffolding).

---

## Most-used procedures (verified)

### Platform / runtime predicates (`platform.eagle`)

Return Eagle booleans (`True`/`False`); use them directly as conditions — never
string-compare to `"1"` (see [`tcl-gotchas.md`](tcl-gotchas.md) #1). The values
below reflect **this host** (macOS, .NET Core, non-interactive); `isEagle` is
always `True` under Eagle.

```tcl
puts [isEagle]          ;# => True
puts [isWindows]        ;# => False   (host: macOS)
puts [isMacOS]          ;# => True    (host: macOS)
puts [isMono]           ;# => False   (host: .NET Core, not Mono)
puts [isDotNetCore]     ;# => True    (host: .NET Core)
puts [isInteractive]    ;# => False   (non-interactive shell)
puts [isAdministrator]  ;# => False   (unprivileged)
puts [isSameFileName foo.txt foo.txt] ;# => True
```

> There is **no** `isUnix` / `isLinux` proc — the predicates are exactly the eight
> above. Detect non-Windows with `[expr {![isWindows]}]`; distinguish OSes with
> `isMacOS` and `getPlatformInfo` (`info.eagle`).

### String & dictionary helpers (`auxiliary.eagle`)

`appendArgs` concatenates its arguments verbatim (no separators) — the library's
go-to for building strings/messages without quoting surprises.

```tcl
puts [appendArgs a b c]          ;# => abc
puts [appendArgs {x = } 1 + 2]   ;# => x = 1+2     (each arg appended as-is)
```

`getDictionaryValue` looks up a name in a flat `{name value …}` list, with an
optional default and an optional wrap string applied **only to a found value**:

```tcl
puts [getDictionaryValue {a 1 b 2 c 3} b]     ;# => 2
puts [getDictionaryValue {a 1} z NONE]        ;# => NONE   (default; not found)
puts [getDictionaryValue {a 1 b 2} b ?? <>]   ;# => <>2<>  (found value wrapped)
```

`getEnvironmentVariable` reads an environment variable (returns empty if unset):

```tcl
puts [getEnvironmentVariable HOME]   ;# => /Users/mistachkin   (host-dependent)
```

### List helpers (`list.eagle`)

`lshuffle` returns a random permutation (so verify it by a stable derivation, not
a fixed value); `lappendArgs` builds a proper list; `ldifference` is the
**symmetric** difference (elements in either list but not both):

```tcl
puts [lsort [lshuffle {1 2 3 4 5}]]  ;# => 1 2 3 4 5   (permutation; contents preserved)
puts [lappendArgs a {b c} d]         ;# => a {b c} d
puts [ldifference {a b c} {b d}]     ;# => a c d        (symmetric difference)
```

`filter`, `map`, and `reduce` are the functional trio. Each takes a **command
prefix** (not a `$x` body): the element is appended as the final argument, and the
script runs in the **caller's** frame. `reduce` seeds its accumulator with the
**empty string**, so the script must tolerate that on the first call.

```tcl
proc gt2 {x} {expr {$x > 2}}
puts [filter {1 2 3 4 5} gt2]        ;# => 3 4 5

proc dbl {x} {expr {$x * 2}}
puts [map {1 2 3} dbl]               ;# => 2 4 6

proc add {a b} {expr {($a eq "" ? 0 : $a) + $b}}
puts [reduce {1 2 3 4} add]          ;# => 10   (empty-string seed handled by add)
```

### File I/O (`file1.eagle`)

`writeFile`/`readFile` are the basic binary round-trip (`appendFile` to append):

```tcl
set f [file join [getEnvironmentVariable TMPDIR] demo.txt]
writeFile $f "hello\nworld"
puts [readFile $f]
;# => hello
;#    world
file delete $f
```

For text/log/shared and UTF-8 variants see `file2.eagle` / `file2u.eagle`
(`readAsciiFile`, `appendLogFile`, `readSharedFile`, …).

### File discovery (`file3.eagle`)

`findFiles` takes a **single glob pattern** (a path glob), *not* a directory plus
a pattern; `findFilesRecursive` walks subdirectories:

```tcl
set d [getEnvironmentVariable TMPDIR]
writeFile [file join $d ff-demo.txt] x
puts [llength [findFiles [file join $d ff-*.txt]]]   ;# => 1
file delete [file join $d ff-demo.txt]
```

### CLR / object helpers (`object.eagle`)

`combineFlags` merges .NET enum flag strings (comma/space separated); a non-empty
third argument names flags to **remove**:

```tcl
puts [combineFlags {Public, Static} NonPublic]   ;# => Public,Static,NonPublic
puts [combineFlags {Public Static} {} Static]    ;# => Public   (Static removed)
```

### Nested-shell execution (`exec.eagle`)

`getShellExecutableName` returns the file used to launch Eagle (the managed DLL
under .NET Core/Mono, the native exe under .NET Framework). `execShell` runs a
**fresh nested Eagle shell** (it prepends the runtime command line and shell name
itself, so pass only `[exec]` options plus the child's arguments):

```tcl
puts [file tail [getShellExecutableName]]   ;# => EagleShell.dll   (host: .NET Core)
# execShell {exec-options} -evaluate {script...}  -> launches a child EagleShell
```

### Test constraints (`test.eagle` — requires `package require Eagle.Test`)

`addConstraint` registers a named capability; `haveConstraint` tests for one.
Constraints are empty until the test prologue (or you) register them, so
`haveConstraint` of an unregistered name is `False`:

```tcl
package require Eagle.Test
addConstraint myFeature
puts [haveConstraint myFeature]   ;# => True
puts [haveConstraint nope]        ;# => False   (never registered)
```

---

## The full catalog

This page covers the highest-value procedures. For the complete inventory —
**580+ procedures**, organized by source file with per-proc anchors, an
alphabetical index, and "Eagle only" markers — see
[`../../../core_script_library.md`](../../../core_script_library.md). As always, treat
prose as a starting point and **re-run** anything you depend on with
[`../scripts/eval-eagle.sh`](verification.md).
</content>
</invoke>
