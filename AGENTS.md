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
| `core_language.md` | Eagle command catalog (built-ins), organized by category; includes advanced topics | When you need command syntax, options, behavior, or Eagle-only extensions |
| `core_script_library.md` | 580+ library procedures (script-level utilities), organized by package and source file | When you need helper procedures, test utilities, file helpers, platform detection, etc. |
| `AGENTS.md` | You are here | How to navigate and answer accurately |

---

## Fast lookup workflow

### Step 1 — Identify the thing you need
Ask yourself:

- “Is this a **built-in command** like `exec`, `object`, `info`, `string`?”
  → Go to `core_language.md`.

- “Is this a **procedure** like `getDictionaryValue`, `readFile`,
  `execShell`, `isWindows`?”
  → Go to `core_script_library.md`.

If you’re unsure:
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
- Eagle’s `exec` is more featureful than Tcl’s:
  - variable-based stdin
  - separate stdout/stderr capture
  - exit code capture
  - timeouts
  - background execution
  - shell execution mode
  - callbacks for streaming output

> Important: Eagle does not use Tcl’s pipeline / redirection syntax. Use `exec`
> options instead.

#### Testing primitives
If you’re writing or understanding tests:
- Look at the **Testing** section and `test1`/`test2`.
- Then cross-reference the script library’s test framework procedures.

#### Security and safe execution
If the question touches sandboxing or safe interpreters:
- Look at:
  - Interpreter Management
  - Built-in Virtual Scripts
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
| key-value list helpers (dict-like) | `auxiliary.eagle` (e.g., `getDictionaryValue`) |
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

- **No Tcl `dict` command.**
  Use key-value lists and library helpers like `getDictionaryValue`.

- **No `fileevent`.**
  Use polling with `after` / event processing, or CLR async patterns.

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
- Look for options:
  - `-stdout varName`
  - `-stderr varName`
  - `-exitcode varName`
  - `-timeout milliseconds`
  - `-setall` when you want variables set even on error

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

### Recipe: Implement “dict-like” data access
- Go to: `core_script_library.md`
- Search for: `getDictionaryValue`
- Use key-value lists (`{name1 value1 name2 value2 ...}`), not Tcl dicts.

---

## How to answer questions with high fidelity

When asked “How do I…?” or “Does Eagle support…?”:

1. **Find the relevant command/procedure entry** by name.
2. **Confirm syntax** (positional args vs options, option names, return values).
3. **Check for Eagle-specific notes** (unsupported Tcl behavior, enhanced flags).
4. **Include a minimal working example** only if it is directly supported by the
   documentation section you read.
5. If the question is cross-cutting (e.g., “safe interpreter + exec + object”),
   **link together the exact relevant sections** rather than guessing behavior.

---

## If you need examples beyond these documents

This repository is the reference, but deeper examples (especially for testing
and real-world harness patterns) often live in the Eagle source repository,
including its test suites.

When you move from “what is the syntax?” to “what is the idiomatic pattern?”:
- Start here in the documentation,
- then consult the Eagle source repo’s `Library/Tests/` and other examples.

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
