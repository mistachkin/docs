# Commands: Packages & Sourcing

`package` (23-sub-command ensemble) · `source`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
The full package-management deep-dive — the `auto_path` system, the four-source
index **discovery pipeline**, **tagged indexes**, and the **security model** —
is [`../../../../package.md`](../../../../package.md).

> Reminder: several `package` sub-commands return **`True`/`False`**
> (`vsatisfies`, `pending`, …), not `1`/`0`. They work as conditions and as
> `1`/`0` in arithmetic, but never string-compare one to `"1"`. See gotcha #1.

---

## `package`

`package` is a **23-sub-command ensemble**. The authoritative set
(`tools/command_inventory.md`, confirmed by `info subcommands package`) is:

```tcl
info subcommands package
;# => absent alias aliases forget ifneeded indexes info loaded names pending
;#    present provide relativefilename require reset scan unknown vcompare
;#    versions vloaded vsatisfies vsort withdraw
```

Nine map to Tcl (`require`, `provide`, `ifneeded`, `forget`, `names`,
`versions`, `vcompare`, `vsatisfies`, `unknown`); the other 14 are Eagle
extensions (`absent`, `alias`, `aliases`, `indexes`, `info`, `loaded`,
`vloaded`, `pending`, `present`, `relativefilename`, `reset`, `scan`, `vsort`,
`withdraw`).

### Requiring, presence, and absence

```tcl
package require Eagle             ;# => 1.0.9675.37713   (loaded version; build-specific)
package present Tcl               ;# => 8.4.21   (Eagle's Tcl-compat baseline)
package require NoSuchPkg         ;# => can't find package "NoSuchPkg"   (raises)
package require -exact Eagle 9.9
;# => attempt to provide package "Eagle 9.9" failed:
;#    package "Eagle 1.0.9675.37713" provided instead   (raises)
puts [catch {package present -exact Eagle 9.9} m]:$m
;# => 1:package "Eagle 9.9" is not present
puts [catch {package absent Eagle} m]:$m
;# => 1:package "Eagle" is not absent: package "Eagle 1.0.9675.37713" provided
package pending                  ;# => False   (no package mid-load right now)
```

`require` runs a **multi-stage fallback chain** (direct → auto-scan →
`PackageFallback` delegate → `unknown` handler); `-autoscan` toggles the rescan
stage, `-exact` demands an exact version. `present` and `absent` are
post/pre-condition checks that never load anything.

### Providing & registration — the load lifecycle

```tcl
package ifneeded demo 1.0 {package provide demo 1.0}
package versions demo            ;# => 1.0   (versions registered via ifneeded)
package require demo             ;# => 1.0   (runs the ifneeded script, loads it)
package present demo             ;# => 1.0
package provide demo             ;# => 1.0   (no version arg => returns provided version)
package forget demo
expr {[lsearch [package names] demo] >= 0}   ;# => False   (gone after forget)
```

Note the contrast: `versions` lists only versions registered through
`ifneeded`, so a **statically provided** package has none:

```tcl
package versions Eagle           ;# => (empty)   statically provided, no ifneeded
```

Eagle extends `ifneeded` with an optional trailing `flags` argument
(`PackageFlags`, e.g. `{Core, Locked}`); see [`../../../../package.md`](../../../../package.md).

### Querying

```tcl
expr {[lsearch [package names] Eagle] >= 0}   ;# => True
package loaded                   ;# => list of loaded package NAMES
package vloaded                  ;# => list of per-package dicts (verbose loaded)
foreach e [package vloaded] {if {[dict get $e name] eq "Tcl"} {puts $e}}
;# => name Tcl loaded 8.4.21 flags {Static, Core, Automatic} ifNeeded 0
package info Eagle
;# => kind Package id <guid> name Eagle description {} indexFileName {} \
;#    provideFileName {} flags {Static, Core, Automatic} \
;#    loaded 1.0.9675.37713 ifNeeded {} wasNeeded {}
package indexes                  ;# => list of discovered pkgIndex.eagle paths
```

`names`, `loaded`, and `vloaded` accept an optional glob `pattern` — but note
the pattern matches the **whole element**, so `package vloaded Eagle` is empty
(the element is a dict, not the bare name); filter with `[dict get]` as above,
or `package vloaded *Eagle*`.

### Version math

```tcl
package vcompare 1.0 1.1         ;# => -1   (1.0 < 1.1)
package vcompare 1.1 1.0         ;# => 1
package vcompare 1.0 1.0         ;# => 0
package vsort    2.0 1.0         ;# => 1    (orders two versions; like vcompare)
package vsatisfies 1.5 1.0       ;# => True   (1.5 >= 1.0)
package vsatisfies 0.9 1.0       ;# => False  (0.9 <  1.0)
```

All three take **exactly two versions** (`version1 version2`) — Eagle's
`vsatisfies`/`vsort` are not Tcl 8.5 requirement-range matchers:

```tcl
package vsort 1.0                ;# => wrong # args: should be "package vsort version1 version2"
```

> **Tcl gotcha — `vsatisfies` drops the major-version cap.** Tcl returns true
> only when `version >= requirement` **and the major versions match**; Eagle
> applies just the `>=` test:
>
> ```tcl
> package vsatisfies 2.0 1.0      ;# => True   (Eagle)   vs   0 in Tcl 8.4/8.5/8.6
> ```
>
> Verified across native Tcl 8.4/8.5/8.6 with `../../scripts/tcl-oracle.sh`.

### Aliases

```tcl
package alias eg Eagle
package require eg               ;# => 1.0.9675.37713   (alias resolves to Eagle)
package aliases eg               ;# => eg
```

`alias` accepts `-overwrite`, `-disabled`, and `-exact`.

### Removal — `forget` vs `withdraw`

`forget` deletes the registration entirely; `withdraw` only unloads while
keeping the `ifneeded` registration so the package can be required again. **A
version argument is required to actually withdraw** — without one, `withdraw`
just returns the currently-loaded version (a getter):

```tcl
package ifneeded demo 1.0 {package provide demo 1.0}
package require demo            ;# => 1.0
package withdraw demo          ;# => 1.0    (no version => returns loaded version, no unload)
package withdraw demo 1.0      ;# => (empty)  unloads it
puts [catch {package present demo} m]:$m   ;# => 1:package "demo" is not present
expr {[lsearch [package names] demo] >= 0} ;# => True   (registration preserved)
```

### Discovery, reset, and the unknown handler

```tcl
package unknown
;# => ::tcl::tm::UnknownHandler ::tclPkgUnknown   (preset fallback handler)
package reset                   ;# => (empty)  clears discovered index info;
                                 #             loaded packages remain
package scan -whatif            ;# previews discovery without changing state
```

`scan` is the heavy sub-command (30+ options across source control
`-host`/`-plugin`/`-bundle`/`-normal`, index types `-primary`/`-tagged`,
search `-recursive`/`-refresh`, security `-notrusted`/`-noverified`, and
diagnostics `-trace`/`-verbose`/`-dump`/`-whatIf`). It and `indexes`, `reset`,
`relativefilename`, and the index-file format drive Eagle's package machinery.
For the full treatment — the **four-source discovery pipeline**
(FindHost / FindFile / FindPlugin / Bundle), **tagged indexes**
(`pkgIndex_<16-hex>.eagle` with the per-file `$tag` variable), the
`pkgIndex.eagle` (not `pkgIndex.tcl`) format, and the **security tail**
(Authenticode / StrongName verification, `Locked`/`Rejected` packages,
`.noPkgIndex` markers, safe-mode path scrubbing) — see
[`../../../../package.md`](../../../../package.md).

---

## `source`

`source ?options? fileName` — evaluates a script file and returns the value of
its last command (or an explicit `[return]`). Beyond Tcl's bare
`source fileName`, Eagle adds several options.

Given `/tmp/x.eagle` containing `proc double {x} {expr {$x*2}}` then
`return [double 21]`:

```tcl
source /tmp/x.eagle             ;# => 42   (value returned by the file)
double 5                        ;# => 10   (side effects persist: proc is defined)
```

Eagle-specific options (verified via the bad-option error — full set is
`--, ---, -bundle, -bundleflags, -encoding, -library, -password, -time,
-withinfo`):

```tcl
source -encoding utf-8 /tmp/x.eagle  ;# => 42   (-encoding takes an encoding name)
source -time true /tmp/x.eagle       ;# => 42   (-time / -withinfo take a BOOLEAN, not the file)
source -nope /tmp/x.eagle
;# => bad option "-nope": must be --, ---, -bundle, -bundleflags, -encoding,
;#    -library, -password, -time, or -withinfo
```

A missing file raises:

```tcl
source /tmp/does_not_exist.eagle
;# => couldn't read or get file "/tmp/does_not_exist.eagle": no such file or directory
```

`-password` / `-bundle` / `-bundleflags` source encrypted or bundle-embedded
scripts; `-library` marks the file as a library load. See
[`../../../../package.md`](../../../../package.md) for how `source` underpins
`pkgIndex.eagle` index evaluation.
