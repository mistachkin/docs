# Eagle `[regexp]` / `[regsub]` Commands: Deep-Dive Analysis of Regular Expression Operations

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[regexp]` and `[regsub]` command internals, including .NET `System.Text.RegularExpressions` integration, the Tcl-to-.NET substitution translation layer (`TranslateSubSpec`), three replacement modes (normal, `-eval`, `-command`), pattern mutation prefixes, and the many Eagle-specific options. For basic command syntax, see [`core_language.md`](core_language.md#cmd-regexp) and [`core_language.md`](core_language.md#cmd-regsub). For usage examples, see [`core_examples.md`](core_examples.md#ex-regexp) and [`core_examples.md`](core_examples.md#ex-regsub). For tips on `-compiled`, `-command`/`-eval`, and `-options`, see [`tips_and_tricks.md`](tips_and_tricks.md).

## 1. Executive Summary

Eagle's `[regexp]` and `[regsub]` commands provide **Tcl-compatible regular
expression matching and substitution** powered by .NET's
`System.Text.RegularExpressions.Regex` engine. They support the standard
Tcl switches (`-nocase`, `-all`, `-inline`, `-indices`, `-line`, `-start`,
etc.) while adding a substantial set of Eagle-specific options that expose
the full power of the .NET regex engine.

There are three key areas of complexity:

1. **Default dot/newline behavior** — Eagle defaults to
   `RegexOptions.Singleline`, meaning `.` matches newlines. This *matches*
   Tcl's default (Tcl treats newline as an ordinary character, so `.`
   matches it there too); it is the **opposite** of .NET's *own* default,
   where `.` does not match `\n`. Eagle enables `Singleline` on purpose to
   stay Tcl-compatible. Use `-linestop` (or `-line`) to make `.` stop
   matching newlines — in Eagle exactly as in Tcl.

2. **Substitution translation layer** — `[regsub]` must translate
   Tcl-style substitution syntax (`&`, `\0`–`\9`, `\\`) into .NET's
   replacement syntax (`$&`, `$0`–`$9`, `\`), handled by the
   `TranslateSubSpec` method in `RegExOps`. This translation also
   supports extended substitution sequences (`\P`, `\I`, `\S`, `\M#`,
   `\N<name>`) when `-extra` is enabled.

3. **Three replacement modes** — `[regsub]` supports normal substitution,
   `-eval` (evaluate a script for each match), and `-command` (TIP #463:
   pass each match to a command prefix). Each mode uses a different
   `MatchEvaluator` callback with distinct semantics.

Both commands carry `CommandFlags.Safe | CommandFlags.Standard` and belong
to the `"string"` object group. They are available in safe interpreters.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Regexp.cs` | 593 | `[regexp]` command implementation |
| `Eagle/Library/Commands/Regsub.cs` | ~430 | `[regsub]` command implementation |
| `Eagle/Library/Components/Private/RegExOps.cs` | 1,159 | Regex operations: pattern creation, substitution translation, match callbacks |
| `Eagle/Library/Components/Private/RegsubClientData.cs` | 183 | Callback state for `[regsub]` match evaluators |

## 2. Why These Commands Differ from Tcl

### The .NET regex engine

Tcl implements its own regex engine (Henry Spencer's Advanced Regular
Expressions, or ARE). Eagle instead delegates to .NET's
`System.Text.RegularExpressions.Regex` class. While both engines support
Perl-compatible regex syntax, there are semantic differences:

- **Default dot behavior (kept Tcl-compatible)** — .NET's *own* default is
  that `.` does not match `\n` (only `RegexOptions.Singleline` makes it
  match). Eagle enables `Singleline` by default so `.` matches `\n` just
  like Tcl, whose default also treats newline as an ordinary character;
  `-linestop`/`-line` turn this off in both.
- **No ARE-specific features** — Tcl's ARE supports features like
  collating elements, character class shortcuts (`[[:alpha:]]`), and
  embedded flags (`(?b)`, `(?q)`). The .NET engine has its own feature
  set (named groups `(?<name>...)`, lookahead/lookbehind, balancing
  groups).
- **ECMAScript mode** — The .NET engine offers an ECMAScript compatibility
  mode (`-ecma`) with no Tcl equivalent.
- **Compilation to IL** — The .NET engine can compile regex patterns to
  IL code (`-compiled`) for significantly faster repeated matching, a
  capability Tcl lacks entirely.

### The substitution translation problem

Tcl's `[regsub]` uses `&` for the full match and `\1`–`\9` for capture
groups in the substitution string. .NET's `Regex.Replace` uses `$&` for
the full match and `$1`–`$9` for capture groups. Eagle's `TranslateSubSpec`
method bridges this gap, translating Tcl-style substitution syntax into
the equivalent .NET replacement strings at runtime.

### Pattern mutation prefixes

Eagle recognizes two special pattern prefixes borrowed from Tcl's ARE
syntax, but implements them via .NET mechanisms:

- **`***=`** — Literal prefix. The rest of the pattern is treated as a
  literal string. Implemented by passing the remainder through
  `Regex.Escape()`.
- **`***:`** — Advanced prefix. The prefix is stripped and the rest is
  used as-is. In Tcl this switches to ARE mode; in Eagle it simply
  removes the prefix since .NET always uses its own engine.

## 3. The `[regexp]` Command in Detail

### Syntax

```tcl
regexp ?switches? exp string ?matchVar? ?subMatchVar subMatchVar ...?
```

### How matching works

1. **Pattern creation** — The pattern string is passed through
   `RegExOps.Create()`, which handles pattern mutation (see §2) and
   applies the accumulated `RegexOptions`. If `ForceCompiled1` is true
   (the default for single-argument pattern creation), the pattern is
   always compiled to IL.

2. **Search start and input windowing** — `-start index` sets where the
   search begins (supporting Eagle's `end-n` index notation) WITHOUT
   windowing the input, so the `^` / `$` anchors still bind to the true
   string boundaries (only the search start position moves).  `-length n`
   additionally limits matching to the window `[start, start + n)`; within
   that explicit window the `^` / `$` anchors bind to the window.

3. **Match loop** — The command enters a `while(true)` loop:
   - On the first iteration call `regEx.Match(input, matchIndex)` (start
     index only, so `^`/`$` bind to the true boundaries) — or, when
     `-length` was given, `regEx.Match(input, matchIndex, matchLength)` to
     honor the explicit window; on subsequent iterations call
     `match.NextMatch()`.
   - If `match.Success` is false, break.
   - Process the match (store in variables or collect for `-inline`).
   - If `-all` is not set, break after the first match.
   - **Zero-width match advancement**: If the match (group zero) ends
     at the same position as `matchIndex`, increment `matchIndex` by 1
     to prevent an infinite loop on zero-width matches.

4. **Variable population** — For each match, capture groups are stored
   in the provided match variables:
   - Without `-indices`: stores the matched text as a string.
   - With `-indices` (or `-indexes`): stores a two-element list
     `{start end}` representing the character positions.
   - The `-skip N` option skips the first N capture groups.
   - The `-noempty` option skips empty matches.
   - Without `-global`: remaining variables (beyond what the match
     provides) are filled with `""` or `"-1 -1"` (for `-indices`), and
     the variable index resets between matches.
   - With `-global`: the variable index does **not** reset between
     matches — variables fill sequentially across all matches.

5. **Return value**:
   - Without `-all` or `-inline`: returns `1` if a match was found, `0`
     otherwise.
   - With `-all` (no `-inline`): returns the total match count.
   - With `-inline`: returns a list of all matched strings (or index
     pairs with `-indices`). The `-inline` option is mutually exclusive
     with match variables.

### The `-line` / `-lineanchor` / `-linestop` triad

These three options control newline sensitivity and map to combinations
of `RegexOptions.Singleline` and `RegexOptions.Multiline`:

| Option | Singleline (`.` matches `\n`) | Multiline (`^`/`$` match line boundaries) |
|--------|-------------------------------|-------------------------------------------|
| Default (no options) | **ON** (`.` matches `\n`) | OFF |
| `-linestop` | OFF (`.` does NOT match `\n`) | (unchanged) |
| `-lineanchor` | (unchanged) | ON |
| `-line` | OFF | ON |

**Note on Tcl compatibility**: In Tcl, newline is not special by default,
so `.` **does** match `\n` — the same as Eagle's default (`Singleline`
ON). It is .NET's *own* default that has `.` not match `\n` (Eagle's
`Singleline` OFF, reached via `-linestop`). So Eagle's default already
behaves like Tcl; use `-linestop` or `-line` when you want `.` to stop at
newlines.

### The `-global` vs `-all` distinction

Both `-all` and `-global` affect multi-match behavior, but they control
different things:

- **`-all`** controls **how many matches** to find. Without `-all`, only
  the first match is returned. With `-all`, all non-overlapping matches
  are found.

- **`-global`** controls **how match variables are populated** across
  multiple matches. Without `-global`, the variable index resets to zero
  for each match — so match variables contain only the *last* match's
  groups. With `-global`, variables fill sequentially: the first match's
  groups go into the first set of variables, the second match's groups
  into the next set, and so on.

Example illustrating the difference:

```tcl
# Without -global: only last match's groups are in vars
regexp -all {(\w+)} "hello world" all word
# all = "world", word = "world" (overwritten by second match)

# With -global: vars fill sequentially
regexp -all -global {(\w+)} "hello world" m0 m1 m2 m3
# m0 = "hello", m1 = "hello", m2 = "world", m3 = "world"
# (m0/m1 from first match's group0/group1, m2/m3 from second)
```

### The `-skip` and `-limit` options

- **`-skip N`** — Start populating match variables from capture group N
  instead of group 0. This is useful when you want to ignore the overall
  match and only capture subgroups: `-skip 1` stores only the
  parenthesized groups, not the full match.

- **`-limit N`** — Cap the total match count at N. After N matches, the
  loop stops even if `-all` is set. The `-limit` option interacts with
  `-all`: without `-all`, only one match is attempted regardless of
  `-limit`.

## 4. The `[regsub]` Command in Detail

### Syntax

```tcl
regsub ?switches? exp string subSpec ?varName?
```

### Return value semantics

`[regsub]` has two return modes:

- **With `varName`**: Stores the modified string in the variable and
  returns the number of replacements made.
- **Without `varName`**: Returns the modified string directly.

### Replacement count control

- Without `-all`: Replaces only the first match. The `-count` option
  (default 1) controls how many replacements to make.
- With `-all`: Replaces all matches. Internally uses
  `regEx.Replace(input, callback)` with no count limit.
- Without `-all` and with explicit `-count N`: Uses
  `regEx.Replace(input, callback, count, startIndex)` to limit
  replacements.

### The three replacement modes

`[regsub]` supports three mutually exclusive replacement modes, each
implemented as a different `MatchEvaluator` delegate:

#### Mode 1: Normal substitution (`RegsubNormalMatchCallback`)

This is the default mode. The substitution string (`subSpec`) is
processed through `TranslateSubSpec` to translate Tcl-style references
into matched text:

```tcl
regsub {(\w+) (\w+)} "John Doe" {\2, \1} result
# result = "Doe, John"
```

The `-literal` and `-verbatim` options modify this mode:
- **`-literal`**: The substitution string is used as-is, with no
  translation of `&`, `\0`–`\9`, or any other special sequences.
- **`-verbatim`**: When true, the callback returns the matched text
  (`match.Value`) instead of processing the substitution spec.

#### Mode 2: Script evaluation (`RegsubEvaluateMatchCallback`, `-eval`)

With `-eval`, the substitution string is treated as a script body. For
each match, the script is parsed as a Tcl list, each element is
translated through `TranslateSubSpec` (so `&` and `\0`–`\9` expand to
matched text), and the resulting list is evaluated as a script. The
script's return value becomes the replacement text.

```tcl
# Double every number found
regsub -all -eval {\d+} "a1b22c333" {
    expr {[string range & 0 end] * 2}
}
# Result: "a2b44c666"
```

In `-eval` mode:
- Each word of the script is individually translated.
- `&` expands to the full match text within each word.
- `\1`–`\9` expand to capture group text.
- The translated words are re-assembled and evaluated.

#### Mode 3: Command prefix (`RegsubCommandMatchCallback`, `-command`)

With `-command` (implementing Tcl TIP #463), the substitution string is
treated as a command prefix. For each match, the matched text (as a list
of all groups) is appended to the command prefix and evaluated. The
command's return value becomes the replacement text.

```tcl
# Replace each number with its string length
regsub -all -command {\d+} "a1b22c333" {string length}
# Result: "a1b2c3"

# Custom transformation via a procedure
proc doubleIt {match} { expr {$match * 2} }
regsub -all -command {\d+} "a1b22c333" doubleIt
# Result: "a2b44c666"
```

In `-command` mode:
- The command prefix can be a single command name or a multi-word list.
- The match text (all groups as a list) is appended as additional arguments.
- The result of the command evaluation replaces the matched text.
- `-command` and `-eval` are mutually exclusive — specifying both is an error.

### The `-quote` option

When `-quote` is enabled, the replacement result (after substitution or
callback evaluation) is processed through Tcl list quoting. This is
useful when building lists from regex matches — each replacement is
guaranteed to be a valid Tcl list element.

## 5. The Substitution Translation Layer (`TranslateSubSpec`)

The `TranslateSubSpec` method in `RegExOps` is the heart of Tcl-to-.NET
substitution compatibility. It processes the substitution string
character by character, translating Tcl conventions into text that .NET's
regex engine can use (or directly expanding match references).

### Standard translation

| Tcl syntax | Meaning | Translation |
|------------|---------|-------------|
| `&` | Entire matched text | Expanded to `match.Value` (or `$&` in verbatim mode) |
| `\0` | Same as `&` | Expanded to `match.Value` (or `$0`) |
| `\1`–`\9` | Capture group N | Expanded to `match.Groups[N].Value` (or `$1`–`$9`) |
| `\\` | Literal backslash | `\` |
| `\&` | Literal `&` | `&` |
| Other `\X` | See strict/nostrict | Depends on mode |

### Processing flow

The translation walks each character through a chain of handlers:

1. **`HandleSubSpecChar`** — Dispatches `&` to the match handler, `\` to
   the escape handler, and all other characters pass through unchanged.

2. **`HandleSubSpecEscapeOrMetaChar`** — Handles the character following
   `\`:
   - `&` → literal `&`
   - `\` → literal `\`
   - `0`–`9` → capture group value
   - If `-extra` is enabled, delegates to the extended handler.
   - Otherwise, falls through to the "other" handler.

3. **`HandleSubSpecOtherEscapeOrMetaChar`** — Handles unrecognized
   escape sequences based on the strict mode:
   - **Strict mode** (default): Keeps both the backslash and the
     character (e.g., `\x` → `\x`). This preserves Tcl's behavior
     where unrecognized escapes are kept verbatim.
   - **`-nostrict`**: Strips the backslash, keeping only the character
     (e.g., `\x` → `x`). This can be useful when substitution strings
     contain backslashes that should not be treated as escape
     introducers.

### The `-extra` extended substitutions

When `-extra` is enabled, `TranslateSubSpec` recognizes additional escape
sequences beyond the standard Tcl set:

| Sequence | Meaning |
|----------|---------|
| `\P` | The regex pattern itself |
| `\I` | The original input string |
| `\S` | The original substitution specification (subSpec) |
| `\M#` | Capture group by index (e.g., `\M0`, `\M12`) — supports multi-digit group numbers |
| `\N<name>` | Capture group by name (e.g., `\N<year>`) — for .NET named groups `(?<name>...)` |

The `-extra` option is particularly useful with .NET's named capture
groups, which have no equivalent in Tcl's substitution syntax:

```tcl
# Using named groups with -extra
regexp {(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})} \
    "2025-03-15" all

regsub -extra \
    {(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})} \
    "2025-03-15" \
    {\N<day>/\N<month>/\N<year>} result
# result = "15/03/2025"
```

The `\M#` syntax supports multi-digit group indices, making it possible
to reference capture groups beyond `\9`:

```tcl
# Referencing group 10+ with -extra
regsub -extra {(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)(k)} \
    "abcdefghijk" {\M10-\M0} result
# result = "k-abcdefghijk"
```

## 6. Complete `[regexp]` Options Reference

All options for the `[regexp]` command, organized by category:

### Tcl-compatible options

| Option | Type | Description |
|--------|------|-------------|
| `-nocase` | flag | Case-insensitive matching (`RegexOptions.IgnoreCase`) |
| `-indices` | flag | Store index pairs `{start end}` instead of matched text |
| `-indexes` | flag | Synonym for `-indices` |
| `-all` | flag | Find all non-overlapping matches; return count |
| `-inline` | flag | Return matches as a list; mutually exclusive with match variables |
| `-line` | flag | Newline-sensitive: clears `Singleline` AND sets `Multiline` |
| `-lineanchor` | flag | `^`/`$` match at line boundaries (sets `Multiline` only) |
| `-linestop` | flag | `.` does not match `\n` (clears `Singleline` only) |
| `-start index` | index | Start matching at this position; supports `end-n` notation |
| `-expanded` | flag | Allow whitespace and comments in pattern (`IgnorePatternWhitespace`) |
| `--` | flag | End of switches |

### Eagle-specific options

| Option | Type | Description |
|--------|------|-------------|
| `-options value` | RegexOptions | Direct .NET `RegexOptions` enum value (e.g., `{IgnoreCase, Multiline}`) |
| `-debug` | flag | Enable debug output showing match attempts and results |
| `-ecma` | flag | ECMAScript-compliant regex behavior (`RegexOptions.ECMAScript`) |
| `-compiled` | flag | Compile regex to IL for faster repeated matching (`RegexOptions.Compiled`) |
| `-explicit` | flag | Explicit capture mode: only named groups capture (`ExplicitCapture`) |
| `-reverse` | flag | Match right-to-left (`RegexOptions.RightToLeft`) |
| `-global` | flag | Don't reset variable index between matches (sequential fill) |
| `-skip N` | int | Skip first N capture groups when populating variables |
| `-limit N` | int | Maximum number of matches to return |
| `-length N` | int | Limit input string length to consider |
| `-noempty` | flag | Skip empty matches when populating variables |
| `-noculture` | flag | Culture-invariant matching (`RegexOptions.CultureInvariant`) |
| `-about` | flag | **(Unsupported)** — reserved, raises an error if used |

## 7. Complete `[regsub]` Options Reference

All options for the `[regsub]` command, organized by category:

### Tcl-compatible options

| Option | Type | Description |
|--------|------|-------------|
| `-all` | flag | Replace all matches (not just the first) |
| `-nocase` | flag | Case-insensitive matching |
| `-start index` | index | Start matching at this position; supports `end-n` notation |
| `-line` | flag | Newline-sensitive: clears `Singleline` AND sets `Multiline` |
| `-lineanchor` | flag | `^`/`$` match at line boundaries |
| `-linestop` | flag | `.` does not match `\n` |
| `-expanded` | flag | Allow whitespace and comments in pattern |
| `--` | flag | End of switches |

### Eagle-specific options

| Option | Type | Description |
|--------|------|-------------|
| `-options value` | RegexOptions | Direct .NET `RegexOptions` enum value |
| `-count N` | int | Maximum number of replacements (default: 1 without `-all`) |
| `-ecma` | flag | ECMAScript-compliant regex behavior |
| `-compiled` | flag | Compile regex to IL for faster repeated matching |
| `-explicit` | flag | Explicit capture mode (only named groups capture) |
| `-reverse` | flag | Match right-to-left |
| `-noculture` | flag | Culture-invariant matching |
| `-quote` | flag | Quote the replacement result for Tcl list safety |
| `-literal` | flag | Treat subSpec as literal text (no `&`/`\N` expansion) |
| `-verbatim` | flag | When true, the callback returns the matched text (`match.Value`) instead of processing the substitution spec |
| `-nostrict` | flag | Strip backslash from unrecognized `\X` escapes |
| `-extra` | flag | Enable extended substitution sequences (`\P`, `\I`, `\S`, `\M#`, `\N<name>`) |
| `-eval script` | script | Evaluate script for each match; result becomes replacement |
| `-command` | flag | TIP #463 command mode: subSpec is a command prefix |

## 8. Pattern Mutation Prefixes

Eagle recognizes two special prefixes in regex pattern strings. These
are processed by `RegExOps.MaybeMutatePattern()` before pattern
compilation:

### `***=` — Literal pattern

The `***=` prefix causes the remainder of the pattern to be treated as
a literal string. Internally, the prefix is stripped and the rest is
passed through `Regex.Escape()`, which backslash-escapes all regex
metacharacters.

```tcl
# Match a literal string containing regex metacharacters
regexp {***=file.txt} "file.txt"    ;# Matches: 1
regexp {***=file.txt} "filextxt"    ;# No match: 0
# Without ***=, the . would match any character
regexp {file.txt} "filextxt"        ;# Matches: 1
```

### `***:` — Advanced pattern

The `***:` prefix is stripped and the remainder is used as-is. In Tcl,
this prefix switches to the ARE (Advanced Regular Expression) engine.
In Eagle, since the .NET engine is always used, this prefix simply
removes itself — it exists for Tcl compatibility.

```tcl
# These are equivalent in Eagle:
regexp {***:(\d+)} "abc123"
regexp {(\d+)} "abc123"
```

## 9. RegexOptions and the `-options` Switch

The `-options` switch accepts a .NET `RegexOptions` enum value, giving
direct access to all .NET regex engine flags. This can be combined with
other switches — the individual switches (like `-nocase`) set their
corresponding flags, and `-options` merges additional flags in.

Common `RegexOptions` values:

| Value | Effect |
|-------|--------|
| `None` | No special options |
| `IgnoreCase` | Case-insensitive matching |
| `Multiline` | `^` and `$` match at line boundaries |
| `Singleline` | `.` matches `\n` (Eagle's default) |
| `IgnorePatternWhitespace` | Allow whitespace and `#` comments in pattern |
| `ExplicitCapture` | Only named groups `(?<name>...)` capture |
| `Compiled` | Compile to IL for performance |
| `RightToLeft` | Match right-to-left |
| `ECMAScript` | ECMAScript-compliant behavior |
| `CultureInvariant` | Culture-invariant comparisons |

Multiple values can be combined with commas:

```tcl
regexp -options {IgnoreCase, Multiline} {^hello} $multilineText
```

**Note**: The individual switches modify the options incrementally. For
example, `-nocase` adds `IgnoreCase`, `-line` clears `Singleline` and
adds `Multiline`. If you use `-options`, it merges with any
flags already set by other switches.

## 10. The Callback Infrastructure (`RegsubClientData`)

Each of the three `[regsub]` replacement modes uses a `MatchEvaluator`
delegate that receives match information from the .NET regex engine. The
`RegsubClientData` class carries the state needed by these callbacks:

| Field | Purpose |
|-------|---------|
| `regEx` | The compiled `Regex` object |
| `pattern` | The original pattern string |
| `input` | The original input string |
| `replacement` | The substitution specification (subSpec) |
| `text` | The eval script text from the `-eval` option (`[string]`) |
| `count` | The replacement count (incremented by each callback) |
| `quote` | Whether to quote the replacement for list safety |
| `extra` | Whether extended substitution sequences are enabled |
| `strict` | Whether strict backslash handling is enabled |
| `verbatim` | Whether verbatim (.NET-native) replacement is used |
| `literal` | Whether literal (no-translation) replacement is used |

The callback accesses the interpreter through
`GlobalState.PushActiveInterpreter()` / `PopActiveInterpreter()`, which
is necessary because .NET's `MatchEvaluator` delegate has no provision
for passing custom state beyond what `RegsubClientData` carries.

### Callback execution flow

1. The `MatchEvaluator` is invoked by .NET for each match.
2. The callback increments the replacement count.
3. Depending on the mode:
   - **Normal**: Calls `TranslateSubSpec` on the subSpec, handling
     `-literal`, `-verbatim`, or standard translation.
   - **Eval**: Parses the subSpec as a list, translates each element
     through `TranslateSubSpec`, evaluates the translated script.
   - **Command**: Builds a command by appending the match (all groups as
     a list) to the command prefix, then evaluates the command.
4. If `-quote` is set, the result is passed through list quoting.
5. The callback returns the replacement string to the .NET engine.

## 11. Regex Compilation and Caching

Eagle's regex infrastructure has two compilation behaviors controlled by
internal flags in `RegExOps.Create()`:

- **`ForceCompiled1`** (default: `true`) — When a regex is created with
  a single argument (pattern only, no explicit options), it is **always**
  compiled to IL. This means that even without the `-compiled` switch,
  patterns created through the standard path get compiled.

- **`ForceCompiled2`** (default: `false`) — When a regex is created with
  two arguments (pattern and regExOptions), the `Compiled` flag is only
  added if the caller explicitly requested it (via `-compiled` or
  `-options Compiled`).

Both `[regexp]` and `[regsub]` use the two-argument
`Create(pattern, regExOptions)` form, which uses `ForceCompiled2 = false`.
This means patterns are **not** compiled to IL by default. The `-compiled`
switch or `-options Compiled` must be specified explicitly to enable IL
compilation.

The .NET runtime itself caches compiled regex patterns internally (up to
`Regex.CacheSize` entries, default 15). Eagle does not add a separate
caching layer.

## 12. Zero-Width Match Handling

When `[regexp -all]` encounters a zero-width match (e.g., from patterns
like `\b`, `(?=...)`, or `^`), the match loop must advance past the
current position to prevent an infinite loop. Eagle handles this by
checking whether group zero's end position equals the current
`matchIndex`:

- If the match ends at `matchIndex` (zero-width), `matchIndex` is
  incremented by 1.
- If the match ends beyond `matchIndex` (non-zero-width), `matchIndex`
  advances to the end of the match.

This ensures that patterns containing zero-width assertions work
correctly with `-all` without entering an infinite loop.

## 13. Practical Patterns

### Pattern 1: Controlling whether `.` matches newlines

```tcl
# Eagle default: . matches newlines (Singleline mode) -- same as Tcl's default
regexp {.+} "line1\nline2"  ;# Matches: "line1\nline2" (entire string)

# To make . STOP at newlines (like .NET's own default), use -linestop:
regexp -linestop {.+} "line1\nline2"  ;# Matches: "line1" (stops at \n)

# Or use -line for full line-sensitive mode (. stops at \n; ^/$ per line):
regexp -line {^.+$} "line1\nline2"  ;# Matches line-by-line
```

### Pattern 2: Named capture groups with `-extra` substitution

```tcl
# Parse a log entry with named groups
set pattern {(?<time>\d{2}:\d{2}:\d{2}) \[(?<level>\w+)\] (?<msg>.+)}
set input "14:30:05 [ERROR] Connection failed"

regexp $pattern $input all
# all = "14:30:05 [ERROR] Connection failed"

# Reformat with -extra to reference named groups
regsub -extra $pattern $input {\N<level>: \N<msg> (at \N<time>)} result
# result = "ERROR: Connection failed (at 14:30:05)"
```

### Pattern 3: High-performance compiled matching in a loop

```tcl
# When matching the same pattern against many strings,
# use -compiled for IL compilation
foreach line $lines {
    if {[regexp -compiled {^ERROR:\s+(.+)} $line _ msg]} {
        lappend errors $msg
    }
}
```

### Pattern 4: Command-based replacement (TIP #463)

```tcl
# Transform matched text through a command
proc capitalize {match} {
    string toupper [string index $match 0][string range $match 1 end]
}
regsub -all -command {\w+} "hello world" capitalize
# Result: "Hello World"

# Use a multi-word command prefix
regsub -all -command {\d+} "a1b22c333" {format %04d}
# Result: "a0001b0022c0333"
```

### Pattern 5: Sequential variable fill with `-global`

```tcl
# Extract all key-value pairs into sequential variables
set input "name=Alice age=30 city=NYC"
regexp -all -global {(\w+)=(\w+)} $input \
    m0 k0 v0 m1 k1 v1 m2 k2 v2
# k0=name, v0=Alice, k1=age, v1=30, k2=city, v2=NYC
```

### Pattern 6: Skip the full match, keep only groups

```tcl
# Use -skip 1 to ignore group 0 (full match)
regexp -all -global -skip 1 {(\w+)=(\w+)} "x=1 y=2" \
    k0 v0 k1 v1
# k0=x, v0=1, k1=y, v1=2
# (without -skip 1, the first var would receive the full match "x=1")
```

### Pattern 7: Literal pattern matching with `***=`

```tcl
# Safely match strings that contain regex metacharacters
set searchTerm "file(1).txt"
regexp "***=$searchTerm" $input
# Equivalent to: regexp {file\(1\)\.txt} $input
# but without manually escaping
```

### Pattern 8: Direct .NET RegexOptions control

```tcl
# Combine multiple .NET options directly
regexp -options {IgnoreCase, Multiline, CultureInvariant} \
    {^hello\s+world$} $text

# ECMAScript mode for JavaScript-compatible behavior
regexp -ecma {\d+} $input
```

### Pattern 9: Right-to-left matching

```tcl
# Find the last occurrence of a pattern
regexp -reverse {\d+} "abc123def456ghi"
# Matches "456" (rightmost match)
```

### Pattern 10: Eval-mode replacement with computation

```tcl
# Increment every number in a string
regsub -all -eval {\d+} "item1 has 5 widgets and 12 gadgets" {
    expr {& + 1}
}
# Result: "item2 has 6 widgets and 13 gadgets"
```

## 14. Comparison: Tcl vs Eagle Regular Expressions

| Feature | Tcl | Eagle |
|---------|-----|-------|
| Regex engine | Henry Spencer ARE | .NET `System.Text.RegularExpressions` |
| Default `.` behavior | **Matches** `\n` (newline not special) | **Matches** `\n` (`Singleline` on; same as Tcl) |
| Named groups | `(?:...)` only (ARE has no named captures) | `(?<name>...)` with `\N<name>` substitution |
| Compile to native code | Not available | `-compiled` (IL generation) |
| ECMAScript mode | Not available | `-ecma` |
| Right-to-left matching | Not available | `-reverse` |
| Explicit capture mode | Not available | `-explicit` |
| Culture-invariant matching | Not available | `-noculture` |
| Direct engine options | Not available | `-options` (full `RegexOptions` enum) |
| Balancing groups | Not available | Supported by .NET engine |
| Collating elements | `[.ch.]` syntax in ARE | Not available |
| Character class shortcuts | `[[:alpha:]]` in ARE | Not available (use `\p{L}` instead) |
| Embedded flags | `(?b)`, `(?q)` in ARE | Not available |
| `***=` literal prefix | ARE feature | Implemented via `Regex.Escape()` |
| `***:` advanced prefix | Switches to ARE mode | Stripped (no-op, .NET engine always used) |
| `-eval` replacement | Tcl 8.7+ (TIP #463 variant) | Supported |
| `-command` replacement | Tcl 8.7+ (TIP #463) | Supported |
| `-extra` substitutions | Not available | `\P`, `\I`, `\S`, `\M#`, `\N<name>` |
| `-global` variable fill | Not available | Sequential variable fill across matches |
| `-skip` / `-limit` | Not available | Control group skipping and match capping |
| `-length` input windowing | Not available | Limit input string length |
| Debug output | Not available | `-debug` |
| `-about` introspection | Returns engine info in Tcl | **(Unsupported)** in Eagle |

## 15. Security Considerations

Both `[regexp]` and `[regsub]` are marked `CommandFlags.Safe` and are
available in safe interpreters. However, there are resource-usage
considerations:

- **Catastrophic backtracking** — Complex patterns with nested
  quantifiers (e.g., `(a+)+$`) can cause exponential time complexity in
  the .NET regex engine. This is a general regex concern, not specific to
  Eagle. Consider using `-options` with a timeout-aware configuration,
  or validate patterns before use.

- **`-compiled` memory usage** — Each compiled regex generates a .NET
  `DynamicMethod`. Compiling thousands of unique patterns can consume
  significant memory. Use `-compiled` for patterns that are reused, not
  for one-off matches.

- **`-eval` and `-command` in safe interpreters** — The `-eval` and
  `-command` modes execute arbitrary scripts. In a safe interpreter, the
  evaluated scripts are subject to the same restrictions as any other
  code in that interpreter. However, the combination of regex matching
  and script evaluation creates a powerful code execution path that
  should be considered when designing sandboxing policies.

- **Resource limits** — In interpreters with `iterationlimit` or
  `timeout` configured, regex operations count against those limits.
  Long-running regex matches (especially with `-all` on large inputs)
  may trigger resource limit violations.

## 16. Relationship to Other Commands

| Related command | Relationship |
|----------------|-------------|
| `[string match]` | Glob-style pattern matching; simpler but less powerful than `[regexp]` |
| `[string map]` | Fixed-string substitution; faster than `[regsub]` for literal replacements |
| `[string first]` / `[string last]` | Find substrings by position; no regex support |
| `[split]` | Split strings on literal characters; for regex-based splitting, combine `regexp -all -inline` with list processing |
| `[scan]` | Parse a string against a format specification (the inverse of `[format]`); see `core_language.md` |

## 17. References

- **Source code**: `Eagle/Library/Commands/Regexp.cs` — `[regexp]` command
- **Source code**: `Eagle/Library/Commands/Regsub.cs` — `[regsub]` command
- **Source code**: `Eagle/Library/Components/Private/RegExOps.cs` — regex operations and substitution translation
- **Source code**: `Eagle/Library/Components/Private/RegsubClientData.cs` — callback state
- **Command reference**: [`core_language.md`](core_language.md#cmd-regexp) — `[regexp]` syntax and options
- **Command reference**: [`core_language.md`](core_language.md#cmd-regsub) — `[regsub]` syntax and options
- **Examples**: [`core_examples.md`](core_examples.md#ex-regexp) — `[regexp]` examples
- **Examples**: [`core_examples.md`](core_examples.md#ex-regsub) — `[regsub]` examples
- **Tips**: [`tips_and_tricks.md`](tips_and_tricks.md) — Regular Expression Enhancements section
- **.NET reference**: [System.Text.RegularExpressions.Regex](https://docs.microsoft.com/en-us/dotnet/api/system.text.regularexpressions.regex)
- **.NET reference**: [RegexOptions Enum](https://docs.microsoft.com/en-us/dotnet/api/system.text.regularexpressions.regexoptions)
- **Tcl reference**: [Tcl `[regexp]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/regexp.htm)
- **Tcl reference**: [Tcl `[regsub]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/regsub.htm)
- **TIP #463**: [Tcl TIP #463 — `regsub -command`](https://core.tcl-lang.org/tips/doc/trunk/tip/463.md)
