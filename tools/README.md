# Documentation Tooling

Maintenance utilities for keeping this documentation in sync with the Eagle
source tree. The tools are written in Eagle, so the documentation set is
verified by the very language it documents.

## `scan_commands.eagle`

Scans the Eagle C# source for commands, sub-commands, and options, then
cross-checks the Markdown docs in this repository for coverage and for stale
"N sub-commands" counts. Sources of truth:

| Aspect | Source file |
|--------|-------------|
| Commands | `Library/Components/Private/BuiltIns.cs` (`typeof(_Commands.X)` list) |
| Sub-commands | each `Library/Commands/*.cs` (`subCommands = new EnsembleDictionary(...)`) |
| Options | `Library/Components/Private/CommandOptions.cs` (`Get<Thing>Options(...)`) |

### Running

The scanner needs the Eagle shell. With an installed `eagle` launcher:

```sh
eagle tools/scan_commands.eagle            # human-readable coverage report
eagle tools/scan_commands.eagle --check    # exit 1 if any documented count is stale
eagle tools/scan_commands.eagle --write    # (re)write tools/command_inventory.md
eagle tools/scan_commands.eagle --json     # machine-readable output
```

Or directly against a build output:

```sh
dotnet exec --roll-forward Major \
  /path/to/EagleShell.dll -file tools/scan_commands.eagle
```

The Eagle source tree defaults to a sibling checkout (`../eagle/Eagle`). Override
it with the `EAGLE_SRC` environment variable or `--eagle-src <path>`.

### What the report means

- **`ok`** — the doc's stated count matches the source sub-command count and
  every sub-command name is mentioned in the doc.
- **`ok (~65+, exact 78)`** — the doc uses an approximate count (e.g. "65+");
  the exact source count is shown for reference.
- **`COUNT MISMATCH`** / **`missing: ...`** — the doc is stale; `--check`
  treats these as failures.
- **`n/a (option-based)`** — the command has no sub-command ensemble (it is
  driven by options, e.g. `[exec]`).

`command_inventory.md` is a generated snapshot (sub-command and option
inventories for every command); do not edit it by hand — re-run with `--write`.

## `restyle.eagle`

Applies the repository's house style to Markdown files, deterministically and
safely. Three independent transforms (all run by default, or pick individually
with `--brackets` / `--fences`):

- **`--brackets`** — inside prose (never inside fenced code blocks), rewrites an
  inline code span that is exactly a registered Eagle command, or a command
  followed by one of its real sub-commands, into bracket form: `` `set` `` →
  `` `[set]` ``, `` `array names` `` → `` `[array names]` ``. The whitelist is
  built from `BuiltIns.cs` + each command's sub-command ensemble, so options
  (`` `-nocase` ``), .NET identifiers (`` `Interpreter` ``), code fragments
  (`` `set x 1` ``), and non-command helper classes are never touched.
- **`--fences`** — gives every untagged opening code fence a language tag
  (`csharp` / `sh` / `text`, else `tcl`).

```sh
eagle tools/restyle.eagle FILE.md [FILE.md ...]   # all transforms
eagle tools/restyle.eagle --dry-run FILE.md        # report only, no write
eagle tools/restyle.eagle --brackets array.md      # one transform
```

Output is written with LF line endings by default (matching `.gitattributes`).
Override per run with `--crlf` or, when operating on signed Eagle script source
outside this repo, `--preserve-eol` (the only safe mode in that case).

> [!NOTE]
> The bracketer cannot know context: a code span that matches a command name is
> always bracketed. In `build_system.md`, `` `test` `` is a **Makefile target**,
> not the `[test]` command, so that file is kept out of the bracketing pass.
> Review `--dry-run` output before styling docs that discuss build targets.

## Editing files outside this docs repo — line-ending rule

> [!IMPORTANT]
> Any tool, script, or ad-hoc helper that **rewrites Eagle script source files**
> (`.eagle` / `.tcl` under the `eagle/`, `pkgd/`, or scratch trees) **MUST
> preserve the file's original line endings** (CRLF is the Eagle script-source
> default). Silently rewriting a CRLF file as LF — for example, Python's
> `Path.write_text()`, which uses the platform default on macOS/Linux —
> changes the bytes of every line and **invalidates any detached Harpy
> signature** issued against the file.
>
> **Python helpers** must read in binary and write in binary with the original
> line endings restored, e.g.:
>
> ```python
> raw  = path.read_bytes()
> eol  = b"\r\n" if b"\r\n" in raw else b"\n"
> text = raw.decode("utf-8")
> # ... mutate text using "\n" internally ...
> path.write_bytes(text.replace("\r\n", "\n").replace("\n", eol.decode()).encode("utf-8"))
> ```
>
> **Eagle/Tcl helpers** must follow the pattern in this directory's
> `scan_commands.eagle` / `restyle.eagle`: detect the file's EOL with the
> `detectEol` proc and pass it explicitly to `writeAll`, e.g.
> `writeAll $path $new auto`. Never rely on the channel's translation default.
>
> This rule exists because a prior bracket-consistency pass silently flipped
> 18 signed Eagle script files from CRLF to LF, invalidating their `.harpy`
> signatures. Both Eagle tools in this directory are now hardened (default
> `--lf` for this docs repo; `--preserve-eol` for any other use).
