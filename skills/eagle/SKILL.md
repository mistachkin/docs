---
name: eagle
description: >
  Authoritative, execution-verified reference for the Eagle scripting language —
  a Tcl-compatible interpreter implemented in C#/.NET (Extensible Adaptable
  Generalized Logic Engine). Use when writing, running, debugging, or reviewing
  Eagle scripts (.eagle files) or embedded-Eagle host code. Use for Eagle's
  .NET/CLR interop (the `object` command), safe-interpreter sandboxing, the `sql`
  ADO.NET bridge, the test harness, packages, or plugins (Harpy, Badge, Kapok,
  …). Use when Tcl code must run under Eagle, or when an Eagle command behaves
  differently from Tcl. Bundles a harness to verify any Eagle behavior by running
  it against a real interpreter.
---

# Eagle (Tcl-compatible .NET scripting)

Eagle runs Tcl-style scripts on the CLR. It is **Tcl-compatible, not
Tcl-identical**, targets the **Tcl 8.4** language baseline (plus selected
8.5/8.6 features), and is built on .NET's regex/format/culture engines — so both
"what Tcl does" and "what .NET does" are unreliable priors. Everything in this
skill was confirmed by executing it.

## Non-negotiable doctrine

1. **Verify, don't recall.** Do not state an Eagle behavior from memory — *run
   it* (see Harness below). The running interpreter is the final word.
2. **Eagle ≠ Tcl.** Before relying on a Tcl idiom, check
   [`reference/tcl-gotchas.md`](reference/tcl-gotchas.md). Top traps: booleans
   print `True`/`False` (not `1`/`0`); `exec` does not error on a non-zero exit
   by default; no `{*}` expansion; `incr`/`dict set` don't auto-create a missing
   variable; no bignum promotion (64-bit wrap).
3. **Command vs. procedure.** Built-in **commands** →
   [`reference/commands/index.md`](reference/commands/index.md). Script-library
   **procedures** (e.g. `getDictionaryValue`, `readFile`, `isWindows`) →
   [`reference/library.md`](reference/library.md).
4. **Fix bad docs.** If a run contradicts the canonical docs in `../../` (the
   `docs/` repo), correct the doc text precisely (preserve voice; LF endings).

## Harness — verify any behavior

Two bundled POSIX scripts (no machine-specific paths):

```sh
scripts/eval-eagle.sh 'puts [expr {2**10}]'          # run Eagle -> 1024 (clean output)
scripts/tcl-oracle.sh 'puts [string trim " x "]'     # same snippet across Tcl 8.4/8.5/8.6
```

Point them at a build once per shell (`EAGLE_SHELL` → `eagle.sh`; `EAGLE_DLL` →
a built `EagleShell.dll`); full instructions and the source-of-truth ranking are
in [`reference/verification.md`](reference/verification.md). For a "differs from
Tcl" claim, confirm with `tcl-oracle.sh` and name the version(s).

## Task router

| I want to… | Go to |
|------------|-------|
| Look up a built-in command / find its file | [`reference/commands/index.md`](reference/commands/index.md) |
| Avoid Tcl-assumption bugs | [`reference/tcl-gotchas.md`](reference/tcl-gotchas.md) |
| Verify/run Eagle (and the Tcl oracle) | [`reference/verification.md`](reference/verification.md) + `scripts/` |
| Get idiomatic code for a common task | [`reference/task-recipes.md`](reference/task-recipes.md) |
| Call .NET / manage objects | [`reference/commands/objects-dotnet.md`](reference/commands/objects-dotnet.md) |
| Sandbox untrusted code | [`reference/safe-interp.md`](reference/safe-interp.md) |
| Use script-library procedures | [`reference/library.md`](reference/library.md) |
| Write/run tests | [`reference/testing.md`](reference/testing.md) |
| Load plugins; use an Enterprise plugin's commands (Harpy/Badge/Kapok/Zeus/Demo/HotKey) | [`reference/plugins.md`](reference/plugins.md) |
| Files / channels / run a process | [`reference/commands/io-files.md`](reference/commands/io-files.md) |
| Databases (ADO.NET / SQLite) | [`reference/commands/data-net.md`](reference/commands/data-net.md) |
| Strings / regex / format | [`reference/commands/strings.md`](reference/commands/strings.md) |
| Lists / dicts | [`reference/commands/lists.md`](reference/commands/lists.md) · [`dict.md`](reference/commands/dict.md) |
| Expr / math | [`reference/commands/expr-math.md`](reference/commands/expr-math.md) |
| Procs / namespaces / scopes | [`reference/commands/procs-namespaces.md`](reference/commands/procs-namespaces.md) |
| Interpreters / events / native Tcl | [`reference/commands/interp-events.md`](reference/commands/interp-events.md) |
| Language basics / getting started | [`../../quick_start_guide.md`](../../quick_start_guide.md) |

## Layers

- **Layer 0 — this file:** doctrine, harness, routing.
- **Layer 1 — `reference/`:** distilled, **execution-verified** material —
  `tcl-gotchas.md`, `verification.md`, `task-recipes.md`, `library.md`,
  `plugins.md`, `safe-interp.md`, `testing.md`, and `commands/` (every built-in
  command, verified examples).
- **Layer 2 — canonical docs** in `../../` (the `docs/` repo): the full catalogs
  (`core_language.md`, `core_examples.md`, `core_script_library.md`), the
  per-command deep-dives (`object.md`, `regexp.md`, `sql.md`, `safe.md`,
  `load.md`, …), and the machine-generated roster
  [`../../tools/command_inventory.md`](../../tools/command_inventory.md). The
  `commands/` files link straight to the relevant deep-dive for each long tail.
- **Source of last resort:** the C# in `eagle/Eagle/Library/Commands/*.cs`.

## Quick facts

- **Version:** Eagle 1.0 (beta). `info engine PatchLevel` gives the build;
  `info patchlevel` reports the Tcl-compat level (`8.4.x`).
- **Targets:** .NET Framework 2.0→4.8.1, .NET Standard 2.0/2.1, .NET Core/5–10,
  Mono.
- **Run from a script:** `eagle.sh -evaluate '<script>'` or `-file <path>`
  (it uses `dotnet exec --roll-forward Major`). `NoStartups=1` silences startup
  banners (presence-based: set to disable, unset to re-enable).
- **EOL:** Eagle source is **CRLF** (preserve it — signed `.eagle`/`.tcl` files
  break if rewritten as LF); this `docs/` repo (incl. this skill) is **LF**.
- **Built-ins live in** `eagle/Eagle/Library/Commands/`; the script library in
  `eagle/Eagle/lib/Eagle1.0/`; plugins in `eagle/Eagle/Plugins/`.
