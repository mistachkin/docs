# Verifying Eagle Assertions (the verify-everything harness)

**Doctrine:** Do not state an Eagle behavior from memory. *Run it.* Eagle is
Tcl-compatible but not Tcl-identical, and it is built on the .NET regex/format/
culture engines — so "what Tcl does" and "what .NET does" are both unreliable
priors. Every non-trivial behavioral claim in this skill was confirmed by
executing it, and you should hold yourself to the same bar.

This file explains the two bundled helper scripts, how to run Eagle and the Tcl
oracles directly, the source-of-truth ranking, and the self-check protocol.

---

## The two helper scripts

They live next to this file, in `../scripts/` (i.e. `skills/eagle/scripts/`).
Both are POSIX `sh` (tested with `dash`) and contain **no machine-specific
paths** — they discover what they need and accept environment overrides.

### `eval-eagle.sh` — run an Eagle script, get clean output

```sh
scripts/eval-eagle.sh 'puts [expr {2**10}]'        # evaluate a string  -> 1024
scripts/eval-eagle.sh -file foo.eagle [args...]    # options pass through to the shell
echo 'puts ok' | scripts/eval-eagle.sh -           # read script from stdin
```

By default it: sets `NoStartups=1` to silence startup banners at the source,
merges stderr into stdout, strips CRs (the shell emits CRLF), and **preserves
Eagle's exit code**. Set `EAGLE_RAW=1` for the raw, unfiltered, CRLF stream with
startups enabled.

It locates the Eagle shell via **`EAGLE_SHELL`** (the path to `eagle.sh`), or
`eagle.sh` on `PATH`. `eagle.sh` itself resolves `EagleShell.dll` — co-located
beside it, or via **`EAGLE_DLL`** — exactly per the official contract. (`eagle.sh`
requires `bash`; this wrapper only needs a POSIX shell for its own logic.)

### `tcl-oracle.sh` — run a snippet across native Tcl 8.4 / 8.5 / 8.6

```sh
scripts/tcl-oracle.sh 'puts [string trim " x "]'
echo 'puts [lsort -real {3 1 2}]' | scripts/tcl-oracle.sh -
```

Use this whenever you want to claim "Eagle differs from Tcl." Eagle targets
**Tcl 8.4** compatibility (plus selected 8.5/8.6 features), so the **8.4 column
is the baseline**; 8.5/8.6 show later-Tcl behavior. Interpreters are discovered
generically: env overrides, then `PATH`, then the standard install prefixes for
the OS (macOS Homebrew/MacPorts/framework, Linux, *BSD/pkgsrc). Each unique
interpreter (deduped by inode) is labelled with its detected `[info patchlevel]`.

---

## Local setup (point the harness at a build)

On a machine where `eagle.sh` is **not** co-located with a built `EagleShell.dll`
(e.g. a source checkout), export two variables once per shell. Adjust paths to
your checkout / build:

```sh
export EAGLE_SHELL=/path/to/eagle/Eagle/Shell/Tools/eagle.sh
# newest built shell under the checkout:
export EAGLE_DLL="$(find /path/to/eagle -type f -name EagleShell.dll \
    -exec sh -c 'for f; do printf "%s %s\n" "$(stat -f %m "$f" 2>/dev/null \
    || stat -c %Y "$f")" "$f"; done' _ {} + | sort -rn | head -1 | cut -d" " -f2-)"
```

For the Tcl oracles, 8.5/8.6 are usually found automatically; a custom-built
8.4 is supplied explicitly:

```sh
export TCLSH84=/path/to/tcl/unix/tclsh.sh     # only if 8.4 isn't on PATH
```

If `eagle.sh` and `EagleShell.dll` are deployed together (the normal release
layout), none of this is needed — just put `eagle.sh` on `PATH`.

---

## Source-of-truth ranking (most to least authoritative)

1. **Run it** — `eval-eagle.sh` (and `tcl-oracle.sh` for Tcl comparisons). The
   running interpreter is the final word.
2. **Generated inventory + C# source** — `../../../tools/command_inventory.md`
   (machine-generated from the source; exact command / sub-command / option
   names) and `eagle/Eagle/Library/Commands/*.cs`. Use these for *names and
   surface*, never prose.
3. **Worked examples** — `../../../core_examples.md` (example-backed; still
   re-run anything you depend on).
4. **Prose docs** — `../../../core_language.md`, the per-command deep-dives,
   `../../../tips_and_tricks.md`. Helpful and detailed, but prose can drift —
   confirm behavioral claims by running them.
5. **Memory / Tcl intuition / .NET intuition** — never sufficient on its own.

When a lower source contradicts a higher one, the higher wins — and if it is a
doc error, **fix the doc** (see below).

---

## The verify-everything protocol

When authoring or answering:

1. Draft the claim/snippet from the docs + source.
2. **Extract every behavioral assertion** (a return value, an error, an option
   effect, a "differs from Tcl").
3. Run it: `eval-eagle.sh '<snippet>'`. Keep the exact snippet and its output as
   evidence.
4. If the claim is "differs from Tcl," also run `tcl-oracle.sh '<snippet>'` and
   confirm the divergence; cite *which* Tcl version(s).
5. Reconcile any command/sub-command/option *names* against
   `command_inventory.md` and the C# source.
6. Keep only what executed as stated. Correct or drop the rest — do not ship a
   plausible-but-unverified claim.

### Correct incorrect docs

If a run contradicts the canonical docs, fix the **actual doc text** (precise
edit, preserve voice/structure, keep docs-repo **LF**, no blanket
normalization). `docs/` is a git repo, so corrections are reviewable with
`git diff`.

---

## Running gotchas (so a "failed" verification isn't a false alarm)

- **Output is CRLF.** The shell emits `\r\n`. `eval-eagle.sh` strips CRs;
  raw/manual runs will show `\r` — normalize before comparing.
- **Startup banners.** Without `NoStartups`, the shell prints
  `---- enabled shell [unknown] handler` and `Licensing [package unknown] hook
  setup for interpreter #N.` `NoStartups` is **presence-based**: set (to *any*
  value, even `0`) ⇒ startups disabled; to re-enable you must **unset** it.
- **Exit codes.** `[error]`/uncaught errors exit non-zero; `eval-eagle.sh`
  preserves Eagle's code (it captures output rather than relying on a pipeline
  status, which POSIX does not expose).
- **Runtime roll-forward.** A `netcoreapp3.0` build runs fine on .NET 5+ because
  `eagle.sh` uses `dotnet exec --roll-forward Major`. A bare
  `dotnet EagleShell.dll` against only newer runtimes installed will fail —
  always go through `eagle.sh` / `eval-eagle.sh`.
- **Tcl aliases vs PATH.** Interactive `tclsh8.x` shell *aliases* are invisible
  to scripts; `tcl-oracle.sh` discovers real binaries on `PATH`/standard
  prefixes, or takes `TCLSH84/85/86` overrides.

---

## Worked example — why this matters

The docs long claimed Eagle's default `.`-matches-newline behavior was *"the
opposite of Tcl."* One run settled it:

```sh
eval-eagle.sh 'puts [regexp -inline {.+} "line1\nline2"]'   # {line1\nline2}
tcl-oracle.sh 'puts [regexp -inline {.+} "line1\nline2"]'   # 8.4/8.5/8.6: {line1\nline2}
```

Eagle and *every* Tcl version return the whole string — `.` matches newline by
default in **both**. Eagle's `Singleline` default is opposite of **.NET's** own
default, but it makes Eagle **Tcl-compatible**, not Tcl-divergent. The remembered
"fact" was backwards; the harness caught it and the docs were corrected. Hold
every assertion to this standard.
