# Commands: Strings

`string` · `format` · `scan` · `subst` · `encoding` · `regexp` · `regsub`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
Deep dives: the full `[string]` reference is [`../../../../string.md`](../../../../string.md);
`[regexp]`/`[regsub]` internals are in [`../../../../regexp.md`](../../../../regexp.md).

> Reminder (gotcha #1): the boolean-ish sub-commands — `string equal`,
> `string match`, `string starts`, `string ends`, and every `string is` —
> return **`True`/`False`**, not `1`/`0`. They behave as `1`/`0` in every
> condition and arithmetic context; the only bite is string identity (never
> compare the result to the literal `"1"`). `string compare`, `string first`,
> `string last` return real integers (`-1`/`0`/`1`, or an index).

---

## `string`

`string subcommand ?arg ...?` — the largest ensemble in the language. All **29**
sub-commands (authoritative names from `tools/command_inventory.md`):

`bytelength` · `cat` · `character` · `classes` · `compare` · `ends` · `equal` ·
`first` · `format` · `index` · `is` · `last` · `length` · `map` · `match` ·
`ordinal` · `range` · `repeat` · `replace` · `reverse` · `starts` · `tolower` ·
`totitle` · `toupper` · `trim` · `trimleft` · `trimright` · `wordend` ·
`wordstart`

Eagle adds eight beyond Tcl's set: `bytelength` (encoding-aware), `cat`,
`character` (code point → char), `ordinal` (char → code point), `classes`,
`starts`, `ends`, plus the .NET-powered `string format` (distinct from the
top-level `[format]` command — see below). The long tail — the **64**-class
`string is` system, culture-aware `compare`/`equal`/casing (`-culture`,
`-comparison`, `-options`), and the extended `string map` modes — is documented
in [`../../../../string.md`](../../../../string.md).

### Measurement & access

```tcl
string length "hello world"     ;# => 11
string index abcde 1            ;# => b
string index abcde end          ;# => e
string index abcde end-1        ;# => d
string index abc 99             ;# => (empty: out of range, no error)
string range abcdef 1 3         ;# => bcd
string range abcdef 2 end       ;# => cdef
string character 65             ;# => A      (Eagle-only: code point -> char)
string ordinal A 0              ;# => 65     (Eagle-only: char -> code point)
string bytelength "héllo"       ;# => 10     (no encoding: UTF-16, len*2)
string bytelength "héllo" utf-8 ;# => 6      (encoding-aware)
```

### Compare, equal, match, search

```tcl
string compare abc abd          ;# => -1
string compare abd abc          ;# => 1
string compare abc abc          ;# => 0
string compare -nocase ABC abc  ;# => 0
string compare -length 3 abcXXX abcYYY  ;# => 0   (first 3 chars only)
string equal abc abc            ;# => True
string equal -nocase ABC abc    ;# => True
string match {a*c} abc          ;# => True
string match {a*c} abd          ;# => False
string match -nocase {A*C} abc  ;# => True
string first o "foo boo"        ;# => 1
string first o "foo boo" 2      ;# => 2   (start index)
string first xyz hello          ;# => -1
string last o "foo boo"         ;# => 6
string starts foo foobar        ;# => True (Eagle-only)
string ends bar foobar          ;# => True (Eagle-only)
```

### Modify

```tcl
string map {a A b B} abcabc     ;# => ABcABc
string map {ab AB} ababab       ;# => ABABAB
string map {ab cd cd ef} abcd   ;# => cdef   (single left-to-right pass)
string map -multipass {ab cd cd ef} abcd ;# => efef  (re-scans until stable)
string map -maximum 2 {a X} aaaa         ;# => XXaa
string map -countvar n {a X b Y} aabbcc  ;# => XXYYcc  (and sets n => 4)
string replace abcdef 1 3       ;# => aef
string replace abcdef 1 3 XY    ;# => aXYef
string reverse abcdef           ;# => fedcba
string repeat ab 3              ;# => ababab
string repeat x 0               ;# => (empty)
string cat foo bar baz          ;# => foobarbaz
```

> `string map -regexp` / `-eval` / `-subspec` exist but are not plain `-all`
> replacers (they apply to the **first** regex match per scan unless combined
> with other flags); their behavior is subtle — see
> [`../../../../string.md`](../../../../string.md). For "replace every regex match", use
> `[regsub -all]`.

### Case & trim

```tcl
string tolower "Hello WORLD"    ;# => hello world
string toupper "Hello world"    ;# => HELLO WORLD
string totitle "hello world"    ;# => Hello world   (first char only, like Tcl)
string trim "  hi  "            ;# => hi
string trimleft  "  hi  "       ;# => "hi  "
string trimright "  hi  "       ;# => "  hi"
string trim "xxhixx" x          ;# => hi    (explicit char set)
```

**Default trim set (verified deviation, by design).** With no `chars`, Eagle
trims exactly the **six ASCII whitespace** characters — space, `\t`, `\n`, `\v`,
`\f`, `\r`:

```tcl
string length [string trim "\v\fhi\v\f"]   ;# => 2   (\v and \f are trimmed)
set nb [format %c 160]                      ;# U+00A0 NO-BREAK SPACE
string length [string trim "$nb\hi$nb"]     ;# => 4   (NBSP is NOT trimmed)
```

Versus native Tcl (`tcl-oracle.sh`): Tcl **8.4.20 / 8.5.9** leave `\v`/`\f`
(`"\v\fhi\v\f"` stays length 6) — Eagle trims more than 8.4; Tcl **8.6.18**
trims the full Unicode whitespace set including U+00A0 (the NBSP string trims
to length 2) — Eagle trims less than 8.6. Eagle sits between them: ASCII only. To
trim Unicode whitespace, pass an explicit `chars`.

### `string is` — type/class testing

`string is ?not? class ?options? string` — tests a string against a class
(64 total; `string classes` lists them). Returns `True`/`False`.

```tcl
string is digit 12345           ;# => True
string is digit abc123          ;# => False  (not ALL chars are digits)
string is alpha Hello           ;# => True
string is integer " 42 "        ;# => True   (surrounding whitespace ok)
string is double 3.14           ;# => True
string is boolean off           ;# => True
string is list "a {b c} d"      ;# => True
string is guid 550e8400-e29b-41d4-a716-446655440000  ;# => True
llength [string classes]        ;# => 64
```

Empties **pass** by default; `-strict` makes them fail:

```tcl
string is alpha ""              ;# => True
string is alpha -strict ""      ;# => False
```

Options come **after** the class. `not` (positional) negates; the `-not` /
`-any` options take a **boolean value**; `-failindex` reports the first failing
position:

```tcl
string is not digit 12345       ;# => False  (it IS all digits)
string is digit -not true 12345 ;# => False  (option form, takes a boolean)
string is digit -any true abc123 ;# => True  (>=1 char matches; -any needs a value)
string is digit -failindex i "12a45"; set i  ;# => 2
```

> Pitfalls: `string is -any digit ...` (option before the class) errors with
> `bad class "-any"`; and bare `string is digit -any abc123` errors because
> `-any` consumes `abc123` as its boolean. Always put options after the class
> and give `-any`/`-not` an explicit `true`/`false`. The full class catalogue
> (numeric/.NET types, file-system, interpreter-object, network, and data-format
> validators) plus `-good`/`-bad`/`-via`/`-count` are in
> [`../../../../string.md`](../../../../string.md).

### `string format` is .NET composite formatting (NOT `[format]`)

The `string format` sub-command dispatches to .NET `String.Format` — `{0}`,
`{1:N2}` placeholders, not `%` specifiers. Use the top-level `[format]` command
(below) for Tcl-style `%` formatting.

```tcl
string format "{0} has {1:N2} items" Cart 42.5  ;# => Cart has 42.50 items
string format "{0:X4}" 255                       ;# => 00FF
```

## `format`

`format formatString ?arg ...?` — Tcl-style `sprintf`. Each `%` specifier
consumes one argument. Eagle is `%`-compatible with Tcl (including `%b` binary
and XPG3 positional `%n$`).

```tcl
format "Name: %s, Age: %d" Alice 30  ;# => Name: Alice, Age: 30
format "%08x" 255                    ;# => 000000ff
format "%#x" 255                     ;# => 0xff
format "%.2f" 3.14159                ;# => 3.14
format "%-10s|" Hi                   ;# => "Hi        |"
format "%05d" 42                     ;# => 00042
format "%+d" 42                      ;# => +42
format "%o" 64                       ;# => 100
format "%e" 31415.9                  ;# => 3.141590e+04
format "%b" 10                       ;# => 1010   (binary; Tcl 8.5+)
format "%c" 65                       ;# => A
format {%2$s %1$s} a b               ;# => b a    (positional args)
```

Numeric conversions are strict (Tcl-like), not silently coerced:

```tcl
catch {format %d 3.0} m; set m  ;# => expected integer but got "3.0"
```

## `scan`

`scan string format ?varName ...?` — the inverse of `[format]`. With `varName`s
it assigns and returns the conversion count (`-1` if input is exhausted before
any conversion); with none, it returns the scanned values as a list (inline
mode). Supports `%d %i %o %x %u %b %c %e %f %g %s %[...] %n %%`, a max field
width, `*` to suppress assignment, and positional `%n$`.

```tcl
scan "12 34" "%d %d" a b   ;# => 2    (a=12, b=34)
scan "ff" %x n             ;# => 1    (n=255)
scan "12 34 56" "%*d %d" x ;# => 1    (x=34; %*d skips the first)
scan "0x1F" "%x"           ;# => 31   (inline: returns the value)
scan "abc123" {%[a-z]}     ;# => abc  (character-set scan; {} avoids [] subst)
scan "hello world" "%s %s" ;# => hello world   (inline list)
scan "" "%d" v             ;# => -1   (input exhausted)
scan "x" "%d" v            ;# => 0    (no conversion; v left unset)
```

> **Eagle note (verified):** an integral `%f` renders with no trailing `.0`:
> `scan "314" "%f"` => `314` in Eagle, but `314.0` in Tcl 8.4/8.5/8.6
> (`tcl-oracle.sh`). This follows Eagle's general number formatting.

## `subst`

`subst ?-nobackslashes? ?-nocommands? ?-novariables? string` — performs `$var`,
`[cmd]`, and backslash substitutions on a string **without** running it as a
script. Each flag disables one substitution kind.

```tcl
set name World
subst {Hello, $name!}            ;# => Hello, World!
subst {Value: [expr {2+2}]}      ;# => Value: 4
subst -novariables {$name}       ;# => $name
subst -nocommands {a[expr {1+1}]b}  ;# => a[expr {1+1}]b
subst -nobackslashes {Tab:\tEnd} ;# => Tab:\tEnd   (\t kept literal)
set x 5
subst {x is $x and [incr x]}     ;# => x is 5 and 6   (command subst has effects)
```

## `encoding`

`encoding convertfrom|convertto|getstring|names|system ...` — five sub-commands.
`convertto enc str` returns the external byte string; `convertfrom enc bytes`
decodes back to Unicode; `getstring` (Eagle extension) decodes a byte-array
object; `names` lists encodings; `system` gets/sets the system encoding.

```tcl
encoding system                  ;# => utf-16   (Eagle's default)
string length [encoding convertto utf-8 "héllo"] ;# => 6  (é is 2 bytes)
string length [encoding convertto utf-8 "é"]     ;# => 2  (bytes 0xC3 0xA9)
encoding convertfrom utf-8 [encoding convertto utf-8 "héllo"]  ;# => héllo
encoding convertto ascii ABC     ;# => ABC
llength [encoding names]         ;# => 21
```

`encoding names` is a small **named** set, not Tcl's codepage catalogue:
`Identity OneByte Tcl TwoByte binary channelDefault default iso-8859-1 null
scriptDefault snippetEncoding systemDefault tclDefault textDefault us-ascii
utf-16 utf-16BE utf-32 utf-32BE utf-8 xmlDefault`.

> Differs from Tcl: Eagle's `encoding system` is **`utf-16`** (Tcl 8.4/8.5/8.6
> report `utf-8`, per `tcl-oracle.sh`). Also note Eagle has **no `binary`
> command** (`info commands binary` => empty) — round-trip bytes with
> `encoding convertto`/`convertfrom` (or `[base64]`/`[hash]`) instead.

## `regexp`

`regexp ?switches? exp string ?matchVar? ?subVar ...?` — .NET-engine regex
matching. Returns `1`/`0` (or a count with `-all`, a list with `-inline`).

```tcl
regexp {^[A-Z]} Hello                ;# => 1
regexp {(\d+)-(\d+)} 123-456 all a b ;# => 1  (all=123-456, a=123, b=456)
regexp -nocase {hello} "HELLO world" ;# => 1
regexp -all {\d+} a1b2c3             ;# => 3   (count)
regexp -inline -all {\d+} a1b2c3     ;# => 1 2 3
regexp -all -inline -- {-?\d+} "a-1b2"          ;# => -1 2   (-- ends switches)
regexp -indices -inline {\d+} ab123cd           ;# => {2 4}
regexp -inline -all -indices {\d+} ab12cd34      ;# => {2 3} {6 7}
```

**`.` matches newline by default — same as Tcl** (verified): Eagle defaults to
`RegexOptions.Singleline`, which makes `.` match `\n`, matching every Tcl
version. This is the **opposite of .NET's own default**, *not* the opposite of
Tcl. Use `-linestop` (or `-line`) to make `.` stop at newlines.

```tcl
regexp -inline {.+} "line1\nline2"           ;# => {line1<newline>line2}  (whole string)
regexp -inline -linestop {.+} "line1\nline2" ;# => line1   (stops at \n)
```

`tcl-oracle.sh`: `regexp -inline {.+} "line1\nline2"` returns the whole string
in Tcl 8.4/8.5/8.6 too — confirming the default is Tcl-compatible.

Literal-pattern prefix `***=` (escapes the remainder) is supported:

```tcl
regexp {***=a.b} a.b   ;# => 1   (. is literal)
regexp {***=a.b} axb   ;# => 0
regexp {a.b} axb       ;# => 1   (. is a metachar without ***=)
```

Eagle-specific switches (full list + semantics in
[`../../../../regexp.md`](../../../../regexp.md)): `-options <RegexOptions>`, `-ecma`,
`-compiled`, `-explicit`, `-reverse` (RightToLeft), `-global` (sequential
variable fill across matches), `-skip N`, `-limit N`, `-length N`, `-noempty`,
`-noculture`, `-debug`.

## `regsub`

`regsub ?switches? exp string subSpec ?varName?` — regex replace. With
`varName`, stores the result and returns the replacement count; without it,
returns the new string. In `subSpec`: `&` or `\0` = whole match, `\1`–`\9` =
groups, `\\` = literal backslash.

```tcl
regsub {world} "Hello world" Eagle        ;# => Hello Eagle
regsub -all {[aeiou]} Hello *             ;# => H*ll*
regsub {(\w+) (\w+)} "John Doe" {\2, \1}  ;# => Doe, John
regsub {&} "a&b" AND                      ;# => aANDb
regsub -all {(\w)(\w)} abcd {\2\1}        ;# => badc
regsub -all {\d} a1b2c3 X result          ;# => 3   (result => aXbXcX)
```

`-literal` makes the *subSpec* literal (the **pattern** is still a regex — `.`
matches the first char, position 0):

```tcl
regsub {\.} a.b X            ;# => aXb
regsub -literal {.} a.b {$1} ;# => $1.b   (. matched 'a'; subSpec used verbatim)
```

`-command` (TIP #463): the *subSpec* is a command prefix; the match is appended:

```tcl
regsub -all -command {\d+} a1b22c333 {string length} ;# => a1b2c3
regsub -all -command {\d+} a1b22c333 {format %04d}   ;# => a0001b0022c0333
```

`-eval`: **the script is the option's value**, and a positional `subSpec`
placeholder (e.g. `{}`) is **still required**. `&` / `\N` expand into the script:

```tcl
regsub -all -eval {expr {& * 2}} {\d+} a1b22c333 {}        ;# => a2b44c666
regsub -all -eval {string toupper &} {\w+} "hello world" {} ;# => HELLO WORLD
```

`-extra` enables extended substitutions, notably `\N<name>` for .NET named
groups:

```tcl
regsub -extra {(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})} 2025-03-15 {\N<d>/\N<m>/\N<y>} r
set r  ;# => 15/03/2025
```

Other Eagle switches — `-count N`, `-quote`, `-nostrict`, `-verbatim`, `-ecma`,
`-compiled`, `-explicit`, `-reverse`, `-noculture`, plus the `-line`/`-lineanchor`/
`-linestop` triad and `***=`/`***:` prefixes shared with `regexp` — are detailed
in [`../../../../regexp.md`](../../../../regexp.md), including the `TranslateSubSpec`
Tcl→.NET translation layer.
