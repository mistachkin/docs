# Eagle `[string]` Command: Deep-Dive Analysis of String Operations, Type Checking, and .NET Integration

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[string]` command internals, including the 29 sub-commands, the 64-class `[string is]` type-checking system (per-character and whole-string validation), culture-aware comparison and casing via `CultureInfo` and `CompareOptions`, the extended `[string map]` with regex/eval/multipass modes, `[string format]` with .NET `String.Format` reflection dispatch, prefix/suffix testing, Unicode character operations, and the `StringOps` infrastructure. For basic command syntax, see [`core_language.md`](core_language.md#cmd-string). For usage examples, see [`core_examples.md`](core_examples.md#ex-string). For string concatenation tips, see [`tips_and_tricks.md`](tips_and_tricks.md).

## 1. Executive Summary

Eagle's `[string]` command provides **Tcl-compatible string operations**
with substantial .NET-powered extensions. It is one of the largest
commands in Eagle, with 29 sub-commands and a `[string is]` type-checking
system that supports 64 character and validation classes.

There are four key areas of complexity:

1. **The `[string is]` type-checking system** — Beyond Tcl's basic
   character classes (`alnum`, `alpha`, `digit`, etc.), Eagle adds 40+
   validation classes that test for .NET types (`decimal`, `single`,
   `[guid]`, `timespan`), file system validity (`directory`, `[file]`,
   `path`, `component`), interpreter objects (`command`, `[object]`,
   `plugin`, `interpreter`), and data formats (`[base64]`, `[uri]`, `[xml]`,
   `cidr`, `inetaddr`). The system distinguishes per-character classes
   (tested via callbacks) from whole-string classes (tested via
   dedicated validators), and supports options like `-not`, `-any`,
   `-good`, `-bad`, and `-failindex`.

2. **Culture-aware operations** — The `compare`, `equal`, `starts`,
   `ends`, `tolower`, `toupper`, and `totitle` sub-commands accept
   `-culture` (a `CultureInfo` value) for culture-sensitive string
   processing. The `compare` and `equal` sub-commands also accept
   `-options` (`CompareOptions` flags). By default `tolower`, `toupper`,
   and `totitle` are locale-independent (invariant culture), matching
   Tcl; `-culture` selects a specific culture and `-invariant false`
   opts into the current thread culture (each invoked via .NET
   reflection, e.g. `String.ToLower(CultureInfo)`).

3. **Extended `[string map]`** — Beyond Tcl's simple key-value mapping,
   Eagle's `[string map]` supports `-regexp` (regex-based matching),
   `-eval` (script evaluation for replacements), `-multipass` (repeated
   application until no changes), `-subspec` (substitution
   specification processing), `-maximum` (replacement count limit), and
   `-countvar` (store replacement count in a variable).

4. **`[string format]` with .NET integration** — Eagle's `[string format]`
   uses .NET's `String.Format` via reflection, supporting `-culture`
   for culture-specific formatting, `-valueformat` for type-specific
   format strings, `-datetimekind` and `-datetimestyles` for date/time
   parsing, and `-verbatim` for literal format strings.

The command carries `CommandFlags.Safe | CommandFlags.Standard |
CommandFlags.Initialize | CommandFlags.SecuritySdk` and belongs to the
`"string"` object group. It is available in safe interpreters.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/String.cs` | 2,737 | Main command implementation (29 sub-commands) |
| `Eagle/Library/Components/Private/StringOps.cs` | 7,534 | String operations: character classification, mapping, encoding, validation |
| `Eagle/Library/Components/Shared/StringOps.cs` | 338 | Shared comparison operations: `Compare`, `Equals`, `StartsWith`, `EndsWith` |

## 2. Why This Command Differs from Tcl

### .NET string infrastructure

Tcl implements its own string operations. Eagle delegates to .NET's
`System.String`, `System.Text.StringBuilder`, `System.Globalization.CultureInfo`,
`System.Globalization.CompareOptions`, and `System.StringComparison`,
which provides:

- Culture-sensitive comparison and casing
- Full Unicode support via .NET's `System.Char` methods
- `StringBuilder` caching for efficient concatenation
- `StringComparison` enum for fine-grained comparison control
- Reflection-based method dispatch for format and casing operations

### Eagle-specific sub-commands

Eagle adds 8 sub-commands beyond Tcl's standard set:

| Sub-command | Purpose |
|-------------|---------|
| `bytelength` | Byte length with configurable encoding |
| `cat` | String concatenation (Tcl 8.6.2+, but Eagle adds it for compatibility) |
| `character` | Integer code point → character conversion |
| `classes` | List all valid `[string is]` class names |
| `ends` | Test if string ends with suffix |
| `ordinal` | Character → Unicode code point conversion |
| `starts` | Test if string starts with prefix |

### Extended `[string is]` classes

Tcl's `[string is]` supports approximately 18 character classes. Eagle
extends this to 64 classes by adding .NET type validation, file system
checks, interpreter object existence checks, and data format
validators.

## 3. Sub-Command Reference

### String measurement and access

#### `[string length]`

```tcl
string length string
```

Returns the number of characters in the string.

#### `[string bytelength]`

```tcl
string bytelength string ?encoding?
```

Returns the byte count of the string in the specified encoding. Without
an encoding argument, returns `length * sizeof(char)` (UTF-16 byte
count). With an encoding, calls `StringOps.AddByteCount()` using the
specified .NET `Encoding` object.

#### `[string index]`

```tcl
string index string charIndex
```

Returns the character at `charIndex`. Supports Eagle's `end-N` index
notation.

#### `[string range]`

```tcl
string range string first last
```

Returns the substring from `first` to `last` (inclusive). Both indices
support `end-N` notation.

#### `[string character]`

```tcl
string character integer
```

Converts an integer Unicode code point to a single character via
`ConversionOps.ToChar()`. Eagle extension — Tcl has no equivalent.

#### `[string ordinal]`

```tcl
string ordinal string charIndex
```

Returns the Unicode code point (ordinal value) of the character at
`charIndex` via `ConversionOps.ToInt()`. Eagle extension — Tcl has no
equivalent.

### String comparison

#### `[string compare]`

```tcl
string compare ?options? string1 string2
```

Compares two strings, returning `-1`, `0`, or `1`.

| Option | Type | Description |
|--------|------|-------------|
| `-nocase` | flag | Case-insensitive comparison |
| `-length` | int | Compare only first N characters |
| `-comparison` | StringComparison | .NET comparison type (Ordinal, CurrentCulture, etc.) |
| `-culture` | CultureInfo | Culture for comparison |
| `-options` | CompareOptions | .NET compare options (IgnoreCase, IgnoreNonSpace, etc.) |

**Note**: .NET's `String.Compare` can return values other than `-1`,
`0`, `1`. Eagle normalizes the result to these three values for Tcl
compatibility.

When `-culture` and `-options` are provided, the comparison uses
`CultureInfo.CompareInfo.Compare()` with the specified `CompareOptions`.
This enables culture-aware comparisons that handle locale-specific
sorting rules (e.g., Turkish dotless-i, German sharp-s).

#### `[string equal]`

```tcl
string equal ?options? string1 string2
```

Same options as `compare`, but returns `1` if the strings are equal,
`0` otherwise.

### String searching

#### `[string first]`

```tcl
string first ?options? needleString haystackString ?startIndex?
```

Returns the index of the first occurrence of `needleString` in
`haystackString`, or `-1` if not found.

| Option | Type | Description |
|--------|------|-------------|
| `-nocase` | flag | Case-insensitive search |
| `-comparison` | StringComparison | .NET comparison type |

#### `[string last]`

```tcl
string last ?options? needleString haystackString ?startIndex?
```

Returns the index of the last occurrence, searching backwards from
`startIndex`.

Same options as `first`.

#### `[string match]`

```tcl
string match ?options? pattern string
```

Tests if `[string]` matches `pattern`. Returns `1` on match, `0` otherwise.

| Option | Type | Description |
|--------|------|-------------|
| `-nocase` | flag | Case-insensitive matching |
| `-mode` | MatchMode | Match mode: `Glob` (default), `RegExp`, `Exact`, etc. |

The `-mode` option is an Eagle extension that allows switching the
pattern matching engine beyond Tcl's default glob matching.

#### `[string wordstart]` / `[string wordend]`

```tcl
string wordstart string index
string wordend string index
```

Returns the index of the start/end of the word at `index`. Word
characters are defined by `StringOps.CharIsWord()` (letters, digits,
or connector punctuation).

### String modification

#### `[string cat]`

```tcl
string cat ?arg ...?
```

Concatenates all arguments. Uses `StringBuilderFactory.Create()` with
pre-calculated capacity for efficiency, and
`StringBuilderCache.GetStringAndRelease()` for memory management.

#### `[string repeat]`

```tcl
string repeat string count
```

Repeats `[string]` the specified number of times. Subject to result size
limits (`RESULT_LIMITS` conditional) to prevent memory exhaustion.

#### `[string replace]`

```tcl
string replace string first last ?newString?
```

Replaces the characters from `first` to `last` (inclusive) with
`newString`. If `newString` is omitted, the range is deleted.

#### `[string reverse]`

```tcl
string reverse string
```

Reverses the string.

#### `[string map]`

```tcl
string map ?options? charMap string
```

Performs string mapping (find/replace) using `charMap` (a list of
old-new pairs).

| Option | Type | Description |
|--------|------|-------------|
| `-nocase` | flag | Case-insensitive matching |
| `-comparison` | StringComparison | .NET comparison type |
| `-multipass` | flag | Repeat mapping until no more changes |
| `-regexp` | flag | Treat patterns as regular expressions |
| `-subspec` | flag | Process substitution specifications in replacements |
| `-eval` | flag | Evaluate replacements as Eagle scripts |
| `-maximum` | int | Maximum number of replacements |
| `-countvar` | varName | Store replacement count in variable |
| `-regexpoptions` | RegexOptions | .NET regex options (when `-regexp` is used) |

**Standard mode** (without `-regexp`): Uses `StringOps.StrMap()` or
`StringOps.StrMultiMap()` (for `-multipass`) with exact string matching.

**Regex mode** (`-regexp`): Treats each key in `charMap` as a regular
expression pattern. Combined with `-subspec` or `-eval`, this provides
powerful regex-based string transformation:

```tcl
# Regex mode: wrap each word in brackets
string map -regexp -subspec {{\w+} {[\0]}} "hello world"
# Result: "[hello] [world]"

# Eval mode: compute replacement via script
string map -regexp -eval {{\d+} {expr {& * 2}}} "a1b2c3"
# Result: "a2b4c6"
```

**Multipass mode** (`-multipass`): Applies the mapping repeatedly until
no more substitutions occur. This is useful for iterative
transformations where one replacement creates new matches:

```tcl
# Single pass:
string map {ab cd cd ef} "abcd"  ;# Result: "cdcd"

# Multipass:
string map -multipass {ab cd cd ef} "abcd"  ;# Result: "efef"
```

#### `[string format]`

```tcl
string format format ?arg ...?
```

Formats a string using .NET's `String.Format` via reflection.

| Option | Type | Description |
|--------|------|-------------|
| `-culture` | CultureInfo | Culture for formatting |
| `-valueformat` | string | Format string for value conversion |
| `-datetimekind` | DateTimeKind | DateTime kind for date parsing |
| `-datetimestyles` | DateTimeStyles | DateTime styles for parsing |
| `-verbatim` | flag | Use format string as-is (no Tcl translation) |
| `-valueflags` | ValueFlags | Value conversion control flags |

The format string uses .NET composite formatting syntax (`{0}`, `{1:N2}`,
etc.), not Tcl's `%`-style format syntax. For Tcl-style formatting, use
the `[format]` command.

```tcl
# .NET-style formatting
string format "{0} has {1:N2} items" "Cart" 42.5
# Result: "Cart has 42.50 items"

# Culture-aware formatting
string format -culture de-DE "{0:C}" 1234.56
# Result: "1.234,56 €"
```

### Case conversion and trimming

#### `[string tolower]` / `[string toupper]` / `[string totitle]`

```tcl
string tolower ?options? string ?first? ?last?
string toupper ?options? string ?first? ?last?
string totitle ?options? string ?first? ?last?
```

Convert case, optionally within a range (`first` to `last`).

| Option | Type | Description |
|--------|------|-------------|
| `-culture` | CultureInfo | Culture for case conversion |
| `-invariant` | boolean | Use invariant (locale-independent) casing; the default. `-invariant false` uses the current thread culture |

Case conversion is locale-independent (invariant culture) by default,
matching Tcl. When `-culture` is provided, Eagle uses .NET reflection to
invoke `String.ToLower(CultureInfo)` or `String.ToUpper(CultureInfo)` for
culture-specific casing (e.g., Turkish dotless-i rules); `-invariant false`
selects the current thread culture instead.

`totitle` converts the first character to uppercase and the rest to
lowercase, optionally within the specified range.

#### `[string trim]` / `[string trimleft]` / `[string trimright]`

```tcl
string trim string ?chars?
string trimleft string ?chars?
string trimright string ?chars?
```

Remove characters from the ends of the string. With `chars`, removes any
of those characters. Without `chars`, removes whitespace.

**Default whitespace set (deviation — by design).** When `chars` is
omitted, the trimmed set is the six **ASCII** whitespace characters —
space, horizontal tab (`\t`), line feed (`\n`), vertical tab (`\v`), form
feed (`\f`), and carriage return (`\r`). Implementation calls
`String.Trim(chars[])` / `TrimStart` / `TrimEnd` with this *explicit* ASCII
set; it deliberately does **not** use the parameterless `String.Trim()`,
which would also strip the full set of Unicode whitespace (e.g. U+00A0
no-break space, U+2003). Consequently:

- Unlike Tcl 8.4 (whose default set is only `" \t\n\r"`), Eagle also trims
  `\v` and `\f`.
- Unlike Tcl 8.6 (which trims all Unicode whitespace), Eagle leaves
  non-ASCII whitespace (such as U+00A0) untouched.

To trim Unicode whitespace, pass an explicit `chars` argument.

### Prefix/suffix testing

#### `[string starts]`

```tcl
string starts ?options? prefix string
```

Returns `1` if `[string]` starts with `prefix`, `0` otherwise.

| Option | Type | Description |
|--------|------|-------------|
| `-nocase` | flag | Case-insensitive comparison |
| `-comparison` | StringComparison | .NET comparison type |
| `-culture` | CultureInfo | Culture for comparison |

Eagle extension — Tcl has no `[string starts]` sub-command.

#### `[string ends]`

```tcl
string ends ?options? suffix string
```

Returns `1` if `[string]` ends with `suffix`, `0` otherwise. Same options
as `starts`.

Eagle extension — Tcl has no `[string ends]` sub-command.

### Utility

#### `[string classes]`

```tcl
string classes
```

Returns the list of all valid class names for `[string is]`. Eagle
extension — Tcl has no equivalent.

## 4. The `[string is]` Type-Checking System

### Overview

The `[string is]` sub-command tests whether a string belongs to a
specified class. It supports 64 classes organized into two categories:

- **Per-character classes** (18): Each character is tested individually
  via a callback function. The string passes if all characters match
  (or any character matches with `-any`).

- **Whole-string classes** (46): The string is tested as a unit via
  dedicated validation logic (parsing, interpreter queries, etc.).

### Syntax

```tcl
string is ?not? class ?options? string
```

| Option | Type | Description |
|--------|------|-------------|
| `-strict` | flag | Empty strings fail (default: empty strings pass) |
| `-nocomplain` | flag | Suppress error messages |
| `-not` | bool | Negate the result |
| `-any` | bool | Pass if ANY character matches (vs all) |
| `-via` | bool | Treat `[string]` as a variable name |
| `-count` | int | Expected character count |
| `-good` | varName | Store passing characters/values |
| `-bad` | varName | Store failing characters/values |
| `-failindex` | varName | Store index of first failing character |

The `not` modifier can be specified either as a positional argument
before the class name or as the `-not` option.

### Per-character classes

These classes test each character individually:

| Class | Test method | Description |
|-------|------------|-------------|
| `alnum` | `Char.IsLetterOrDigit` | Letter or digit |
| `alpha` | `Char.IsLetter` | Letter |
| `ascii` | `StringOps.CharIsAscii` | Code point ≤ 0x7F |
| `asciialnum` | `StringOps.CharIsAsciiAlphaOrDigit` | ASCII letter or digit |
| `asciialpha` | `StringOps.CharIsAsciiAlpha` | ASCII letter (A–Z, a–z) |
| `asciidigit` | `StringOps.CharIsAsciiDigit` | ASCII digit (0–9) |
| `control` | `Char.IsControl` | Control character |
| `digit` | `Char.IsDigit` | Unicode digit |
| `graph` | `StringOps.CharIsGraph` | Printable non-whitespace |
| `hexadecimal` | `StringOps.CharIsAsciiHexadecimal` | Hex digit (0–9, A–F, a–f) |
| `lower` | `Char.IsLower` | Lowercase letter |
| `print` | `StringOps.CharIsPrint` | Printable (letters, digits, punctuation, whitespace) |
| `punct` | `Char.IsPunctuation` | Punctuation |
| `reserved` | `StringOps.CharIsReserved` | Eagle reserved characters (`" # $ ; [ \ ] { }`) |
| `space` | `Char.IsWhiteSpace` | Whitespace |
| `upper` | `Char.IsUpper` | Uppercase letter |
| `wordchar` | `StringOps.CharIsWord` | Letter, digit, or connector punctuation |
| `xdigit` | `Parser.IsHexadecimalDigit` | Hexadecimal digit |

The `ascii*` classes are Eagle extensions that restrict matching to the
ASCII range, unlike `alnum`/`alpha`/`digit` which use Unicode-aware
.NET `Char` methods.

### Whole-string validation classes — Numeric types

| Class | Validator | Description |
|-------|-----------|-------------|
| `boolean` | `Value.GetBoolean5` | Boolean value (true/false, yes/no, on/off, 1/0) |
| `true` | `Value.GetBoolean5` + check | Must evaluate to true |
| `false` | `Value.GetBoolean5` + check | Must evaluate to false |
| `byte` | `Value.GetByte2` | Byte value (0–255) |
| `integer` | `Value.GetInteger2` | 32-bit integer |
| `wideinteger` | `Value.GetWideInteger2` | 64-bit integer |
| `entier` | `BigInteger` parse | Arbitrary-precision integer (.NET 4.0+) |
| `double` | `Value.GetDouble` | 64-bit floating point |
| `single` | `Value.GetSingle` | 32-bit floating point |
| `decimal` | `Value.GetDecimal` | 128-bit decimal |
| `number` | `Value.GetNumber` | Any numeric value |
| `numeric` | `Value.GetNumeric` | Any numeric value |
| `real` | `Value.GetNumber` with `ValueFlags.AnyRealAnyRadix` | Floating-point value |

### Whole-string validation classes — Data types

| Class | Validator | Description |
|-------|-----------|-------------|
| `datetime` | `Value.GetDateTime` | Parseable as .NET `DateTime` |
| `timespan` | `Value.GetTimeSpan` | Parseable as .NET `TimeSpan` |
| `[guid]` | `Value.GetGuid` | Valid GUID format |
| `[version]` | `Value.GetVersion` | Parseable as .NET `Version` |
| `versionrange` | `Value.GetVersionRange` | Two `Version` values |
| `[uri]` | `Value.GetUri` | Valid URI |
| `[base64]` | `StringOps.IsBase64` | Valid Base64 string |
| `[xml]` | `XmlOps.LoadString` | Valid XML (conditional on XML flag) |

### Whole-string validation classes — String structure

| Class | Validator | Description |
|-------|-----------|-------------|
| `[list]` | `ListOps.GetOrCopyOrSplitList` | Valid Tcl list |
| `[dict]` | `ListOps` + even count | Valid dictionary (even element count, TIP #501) |
| `annotation` | `Value.IsAnnotation` | Valid annotation format |
| `identifier` | `StringOps.IsValidIdentifier` | Valid C#-style identifier |
| `idxranges` | `RuntimeOps.ParseIndexRanges` | Valid index range specification |
| `[encoding]` | `interpreter.GetEncoding` | Valid encoding name |

### Whole-string validation classes — File system

| Class | Validator | Description |
|-------|-----------|-------------|
| `directory` | `PathOps.ValidatePathAsDirectory` | Valid directory path |
| `[file]` | `PathOps.ValidatePathAsFile` | Valid file path |
| `path` | `PathOps.ValidatePathAsPath` | Valid generic path |
| `component` | `PathOps.CheckForValid` | Valid path component |

### Whole-string validation classes — Network

| Class | Validator | Description |
|-------|-----------|-------------|
| `cidr` | `SocketOps.IsValidCIDR` | Valid CIDR notation (requires NETWORK) |
| `inetaddr` | `Value.GetWideInteger2` then falls back to `IPAddress.TryParse` | Valid IP address (requires NETWORK) |

### Whole-string validation classes — Interpreter objects

| Class | Validator | Description |
|-------|-----------|-------------|
| `[array]` | Variable resolution + `EntityOps.IsArray` | Existing array variable |
| `command` | `interpreter.InternalDoesIExecuteExistViaResolvers` | Existing command |
| `element` | `EntityOps.IsArray` + `FlagOps.HasFlags` for `VariableFlags.WasElement` + `interpreter.GetVariableValue` | Existing array element |
| `interpreter` | `Value.GetInterpreter` | Existing child interpreter |
| `[object]` | `Value.GetObject` | Existing opaque object handle |
| `plugin` | `interpreter.GetPlugin` + `interpreter.InternalFindPlugin` | Loaded plugin |
| `ruleset` | `RuleSet.Create` to test parseability | Existing rule set |
| `scalar` | `EntityOps.IsScalar` | Existing scalar variable |
| `type` | `Value.GetAnyType` | Known .NET type |
| `value` | `Value.GetValue` to test parseability | Existing value |
| `variant` | `Value.GetVariant` to test parseability | Existing variant |

### Special classes

| Class | Behavior |
|-------|----------|
| `none` | Returns true when string parses as `Index.Invalid` |
| `not` | Modifier only — negates the next class |

### The `-any` vs default behavior

By default, per-character classes require **all** characters to match.
With `-any`, only **one** character needs to match:

```tcl
string is digit "abc123"       ;# 0 (not all are digits)
string is -any digit "abc123"  ;# 1 (at least one digit)
```

### The `-good` and `-bad` options

These Eagle-specific options store the matching and non-matching
portions:

```tcl
string is digit -good g -bad b "a1b2c3"
# g = "123", b = "abc"
```

## 5. The `StringComparison` and `CompareOptions` System

### `StringComparison` enum

The `-comparison` option on `compare`, `equal`, `first`, `last`,
`starts`, and `ends` accepts any .NET `StringComparison` value:

| Value | Description |
|-------|-------------|
| `Ordinal` | Byte-by-byte comparison (fastest, default for most operations) |
| `OrdinalIgnoreCase` | Byte-by-byte, case-insensitive |
| `CurrentCulture` | Current locale rules |
| `CurrentCultureIgnoreCase` | Current locale, case-insensitive |
| `InvariantCulture` | Culture-invariant rules |
| `InvariantCultureIgnoreCase` | Culture-invariant, case-insensitive |

### `CompareOptions` flags

The `-options` flag on `compare` and `equal` accepts .NET
`CompareOptions` flags, which can be combined:

| Flag | Description |
|------|-------------|
| `IgnoreCase` | Case-insensitive |
| `IgnoreNonSpace` | Ignore diacritical marks |
| `IgnoreSymbols` | Ignore symbols |
| `IgnoreKanaType` | Ignore hiragana/katakana distinction |
| `IgnoreWidth` | Ignore full-width/half-width distinction |
| `StringSort` | Use string sort instead of word sort |
| `Ordinal` | Ordinal comparison |
| `OrdinalIgnoreCase` | Ordinal, case-insensitive |

These options are only available when building with .NET 2.0 SP2 or
later (`.NET_20_SP2 || NET_40 || NET_STANDARD_20`).

### How `-nocase` maps to comparison types

The `-nocase` flag is converted to a `StringComparison` value via
`SharedStringOps.GetBinaryComparisonType()`:
- Without `-nocase`: `StringComparison.Ordinal`
- With `-nocase`: `StringComparison.OrdinalIgnoreCase`

If `-comparison` is also specified, it takes precedence over `-nocase`.

## 6. The `MatchMode` Enumeration

The `string match -mode` option selects the matching engine:

| Mode | Description |
|------|-------------|
| `Exact` | Exact string comparison |
| `SubString` | Substring search |
| `Glob` | Tcl-style glob pattern matching (default) |
| `RegExp` | .NET regular expression matching |
| `Integer` | Integer comparison |
| `Double` | Floating-point comparison |
| `Decimal` | Decimal comparison |
| `CIDR` | CIDR network address matching |

Additional flags can modify matching behavior:

| Flag | Description |
|------|-------------|
| `NoCase` | Case-insensitive |
| `ForceCase` | Force case-sensitive |
| `SubPattern` | Sub-pattern matching |
| `StopOnMatch` | Stop on first match |
| `StopOnError` | Stop on first error |
| `Any` | Match any element |
| `All` | Match all elements |

## 7. Character Classification Methods

The `StringOps` class provides the character testing callbacks used by
`[string is]` per-character classes:

### `CharIsWord(char character)`

Returns `true` if the character is a letter, digit, or connector
punctuation (e.g., underscore). Used by `wordchar` class and word
boundary detection (`wordstart`/`wordend`).

### `CharIsAscii(char character)`

Returns `true` if the code point is ≤ 0x7F. Strict ASCII range check.

### `CharIsAsciiAlpha(char character)`

Returns `true` for A–Z and a–z only. Stricter than `Char.IsLetter`,
which includes Unicode letters.

### `CharIsAsciiDigit(char character)`

Returns `true` for 0–9 only. Stricter than `Char.IsDigit`, which
includes Unicode digit characters.

### `CharIsGraph(char character)`

Returns `true` for printable characters that are not whitespace.
Combines letter, digit, punctuation, and symbol categories.

### `CharIsPrint(char character)`

Returns `true` for all printable characters including whitespace.
Combines letters, digits, punctuation, symbols, and whitespace.

### `CharIsReserved(char character)`

Returns `true` for characters that have special meaning in Tcl/Eagle:
`"`, `#`, `$`, `;`, `[`, `\`, `]`, `{`, `}`.

### `CharIsAsciiHexadecimal(char character)`

Returns `true` for 0–9, A–F, and a–f.

### `CharIsIdentifierZero(char character)` / `CharIsIdentifierOnePlus(char character)`

Used by the `identifier` class. `Zero` tests if a character is valid as
the first character of a C#-style identifier. `OnePlus` tests subsequent
characters.

## 8. StringBuilder Optimization

Several sub-commands use `StringBuilderFactory` and
`StringBuilderCache` for memory-efficient string construction:

- **`[string cat]`**: Pre-calculates total capacity from all arguments,
  creates a `StringBuilder` with exact capacity, appends all arguments,
  and releases via `StringBuilderCache.GetStringAndRelease()`.

- **`[string replace]`**: Builds the result by appending the prefix,
  replacement, and suffix to a `StringBuilder`.

- **`[string tolower]`/`toupper`/`totitle` with range**: When applying
  case conversion to a substring range, uses `StringBuilder` to
  assemble the unchanged prefix, converted range, and unchanged suffix.

## 9. Practical Patterns

### Pattern 1: Culture-aware string comparison

```tcl
# Turkish locale: i and I are not case-equivalents
string equal -culture tr-TR -nocase "ISTANBUL" "istanbul"
# May return 0 due to Turkish dotless-i rules

# Ordinal comparison (byte-by-byte, fastest)
string compare -comparison Ordinal "abc" "ABC"
# Returns: 1 (lowercase > uppercase in ordinal)

# Culture-aware with CompareOptions
string compare -culture de-DE -options IgnoreCase "straße" "STRASSE"
```

### Pattern 2: Extended type checking

```tcl
# Check if a string is a valid IP address
string is inetaddr "192.168.1.1"    ;# 1

# Check if a string is valid CIDR notation
string is cidr "10.0.0.0/8"        ;# 1

# Check if a string is a valid GUID
string is guid "550e8400-e29b-41d4-a716-446655440000"  ;# 1

# Check if a string is valid XML
string is xml "<root><child/></root>"  ;# 1

# Check if a variable names an existing command
string is command "puts"            ;# 1
string is command "nonexistent"     ;# 0

# Negate: check that something is NOT a list
string is not list "unbalanced {"   ;# 1
```

### Pattern 3: `-good`, `-bad`, and `-failindex`

```tcl
# Find where digit validation fails
string is digit -failindex idx "abc123"
# idx = 0 (first non-digit character)

# Separate good and bad characters
string is alpha -good g -bad b "Hello World! 123"
# g = "HelloWorld", b = " ! 123"
```

### Pattern 4: Regex-based string map

```tcl
# Replace using regex patterns
string map -regexp {{\d+} N {[A-Z]+} UPPER} "Item42 CODE99"
# Result: "ItemN UPPERN"

# Eval mode: compute replacements dynamically
string map -regexp -eval {{\d+} {expr {& + 1}}} "a1b2c3"
# Result: "a2b3c4"

# Multipass mapping
string map -multipass {A B B C} "AAA"
# Pass 1: "BBB", Pass 2: "CCC" → Result: "CCC"
```

### Pattern 5: Prefix and suffix testing

```tcl
# Check if a URL starts with https
string starts -nocase "https://" $url

# Check file extension
string ends ".eagle" $filename

# Culture-aware prefix test
string starts -culture de-DE "Straß" "Straße"
```

### Pattern 6: .NET String.Format

```tcl
# Composite formatting
string format "{0} is {1} years old" "Alice" 30
# Result: "Alice is 30 years old"

# Numeric formatting
string format "{0:N2}" 1234.5
# Result: "1,234.50"

# Date formatting
string format "{0:yyyy-MM-dd}" [clock scan "2025-03-12"]

# Culture-specific currency
string format -culture ja-JP "{0:C}" 1234
# Result: "¥1,234"
```

### Pattern 7: Unicode operations

```tcl
# Get Unicode code point
string ordinal "A" 0         ;# 65
string ordinal "€" 0         ;# 8364

# Create character from code point
string character 65           ;# "A"
string character 8364         ;# "€"
```

### Pattern 8: Map with count and maximum

```tcl
# Count replacements
string map -countvar n {a X b Y} "aabbcc"
# Result: "XXYYcc", n = 4

# Limit replacements
string map -maximum 2 {a X} "aaaa"
# Result: "XXaa"
```

## 10. Comparison: Tcl vs Eagle String Command

| Feature | Tcl | Eagle |
|---------|-----|-------|
| `[string bytelength]` with encoding | Not available | Configurable encoding |
| `[string character]` | Not available | Code point → character |
| `[string ordinal]` | Not available | Character → code point |
| `[string classes]` | Not available | List all `[string is]` classes |
| `[string starts]` | Not available | Prefix testing |
| `[string ends]` | Not available | Suffix testing |
| `string compare -culture` | Not available | Culture-aware comparison |
| `string compare -options` | Not available | `CompareOptions` flags |
| `string compare -comparison` | Not available | `StringComparison` enum |
| `string map -regexp` | Not available | Regex-based mapping |
| `string map -eval` | Not available | Script-evaluated replacements |
| `string map -multipass` | Not available | Iterative mapping |
| `string map -maximum` | Not available | Replacement count limit |
| `string map -countvar` | Not available | Replacement count tracking |
| `[string format]` | Tcl `%`-style | .NET `String.Format` composite style |
| `string tolower -culture` | Not available | Culture-specific casing |
| `string match -mode` | Glob only | `Glob`, `RegExp`, `Exact`, `CIDR`, etc. |
| `[string is]` classes | ~18 | 64 (18 per-character + 46 whole-string) |
| `string is -not` | Not available | Negation option |
| `string is -any` | Not available | Any-character matching |
| `string is -good / -bad` | Not available | Separate good/bad results |
| `string is -nocomplain` | Not available | Suppress errors |
| `string is -via` | Not available | Variable name indirection |
| `string is -count` | Not available | Expected count validation |
| `string is cidr/inetaddr` | Not available | Network address validation |
| `string is guid/uri/xml` | Not available | Data format validation |
| `string is datetime/timespan` | Not available | .NET type validation |
| `string is command/object/plugin` | Not available | Interpreter object checks |
| `string is directory/file/path` | Not available | File system validation |

## 11. Security Considerations

- **`CommandFlags.Safe`** — The command is available in safe
  interpreters. However, some `[string is]` classes that query
  interpreter state (`command`, `[object]`, `plugin`, `interpreter`)
  may reveal information about the interpreter's internal state.

- **Result size limits** — `[string repeat]` is subject to result size
  limits (when compiled with `RESULT_LIMITS`) to prevent denial-of-service
  via memory exhaustion.

- **Reflection usage** — `[string format]` and culture-aware casing use
  .NET reflection to invoke `String` methods. This is an internal
  implementation detail and does not expose reflection to scripts.

## 12. Relationship to Other Commands

| Related command | Relationship |
|----------------|-------------|
| `[format]` | Tcl-style `%` formatting; `[string format]` uses .NET composite formatting |
| `[regexp]` / `[regsub]` | Full regex operations; `string match -mode RegExp` is simpler; see [`regexp.md`](regexp.md) |
| `[split]` / `[join]` | List-oriented string operations |
| `[append]` / `[lappend]` | Variable-modifying string/list operations |
| `[scan]` | Parse a string against a format specification (the inverse of `[format]`); see `core_language.md` |
| `[encoding]` | Encoding operations; `[string bytelength]` uses encodings |
| `binary` | Binary string operations |
| `[info]` | `[info complete]` tests if a string is a complete Tcl command |

## 13. References

- **Source code**: `Eagle/Library/Commands/String.cs` — `[string]` command (29 sub-commands, 2,737 lines)
- **Source code**: `Eagle/Library/Components/Private/StringOps.cs` — string operations (7,534 lines)
- **Source code**: `Eagle/Library/Components/Shared/StringOps.cs` — shared comparison operations (339 lines)
- **Command reference**: [`core_language.md`](core_language.md#cmd-string) — `[string]` syntax and options
- **Examples**: [`core_examples.md`](core_examples.md#ex-string) — `[string]` examples
- **Tips**: [`tips_and_tricks.md`](tips_and_tricks.md) — String Handling section (`appendArgs`)
- **Related**: [`regexp.md`](regexp.md) — full regex operations
- **Tcl reference**: [Tcl `[string]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/string.htm)
- **.NET reference**: [String Class](https://docs.microsoft.com/en-us/dotnet/api/system.string)
- **.NET reference**: [StringComparison Enum](https://docs.microsoft.com/en-us/dotnet/api/system.stringcomparison)
- **.NET reference**: [CompareOptions Enum](https://docs.microsoft.com/en-us/dotnet/api/system.globalization.compareoptions)
