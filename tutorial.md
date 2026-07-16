# The Eagle Tutorial (for Tcl Programmers)

> **For AI agents**: This is a paced, contrast-driven tutorial that teaches Eagle
> to someone who already knows Tcl. It assumes the reader has completed the
> official [Tcl Tutorial](https://urn.to/r/tcltutorial)
> and covers only where Eagle *differs* from Tcl, plus the features Eagle adds.
> For reference material, see [core_language.md](core_language.md),
> [tips_and_tricks.md](tips_and_tricks.md), and the per-command deep-dives. To
> embed Eagle in a C# host, see [embedding.md](embedding.md).

Eagle (Extensible Adaptable Generalized Logic Engine) is a Tcl-compatible
scripting language implemented in managed .NET code. If you know Tcl, you already
know most of Eagle — so this tutorial does not re-teach `set`, `if`, `proc`, or
`list`. Instead it walks the same ground the Tcl tutorial covers and stops only
where Eagle behaves differently, then goes on to the capabilities Eagle adds on
top (deep .NET interop, sandboxing, plugins, and more).

---

## Prerequisite: the Tcl Tutorial

Please work through the official **[Tcl Tutorial](https://urn.to/r/tcltutorial)**
first. This document is written as a *delta* on top of it: each lesson in the
first half links back to the matching Tcl tutorial lesson and then describes only
what changes in Eagle. Eagle targets the **Tcl 8.4** language baseline (plus
selected 8.5/8.6 features), so the Tcl tutorial's fundamentals apply directly.

## How this tutorial works

- **Contrast first.** Each lesson in *Arc 1* opens with a **Prereq** deep-link to
  the Tcl tutorial lesson it parallels, then covers just the difference.
- **Everything is verified.** Every snippet was executed in an Eagle shell; where
  Eagle and Tcl differ, both outputs are shown. Expected output appears as a
  `;# =>` comment.
- **Follow the links for depth.** Lessons point forward to the reference docs
  (e.g. [object.md](object.md), [safe.md](safe.md), [regexp.md](regexp.md)) when
  you want the full story.
- **Status: complete.** All lessons are written — Arc 1 (the core-language deltas
  from Tcl) and Arc 2 (the Eagle-only capabilities), plus a capstone.

## Running the examples

Start the interactive shell (a REPL) and type at the `%` prompt, or run a script:

```sh
EagleShell                       # interactive REPL
EagleShell -evaluate 'puts hi'   # evaluate one script string
EagleShell -file script.eagle    # run a script file
```

Everything below can be pasted into the REPL. (When embedding Eagle in a C#
application instead, see [embedding.md](embedding.md).)

---

## Roadmap

### Arc 1 — You already know most of this (the deltas)

Each lesson parallels one or more Tcl tutorial lessons and covers only the change.
Every lesson below is written in full.

| Lesson | Parallels (Tcl Tutorial) | The Eagle delta |
|--------|--------------------------|-----------------|
| **1. Meet Eagle, and running it** | [Intro / Running / Output](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl0.html) | It's .NET; Tcl 8.4 baseline; the shell, `-evaluate`, `-file`; version introspection |
| **2. Values, variables, True/False** | [Variables & substitution](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl2.html) | Computed booleans render **`True`/`False`**, not `1`/`0` |
| **3. Numbers and `[expr]`** | [Math 101](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl6.html) / [Computers and Numbers](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl6a.html) | Base-10 `decimal` literals; **integer overflow wraps** (no bignum promotion); `entier()`/`wide()`/`double()` |
| **4. `if` and `switch`** | [if](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl7.html) / [switch](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl8.html) | True/False conditions; `switch` matching modes |
| **5. Loops (and `do`)** | [while](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl9.html) / [for & incr](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl10.html) | `incr` does **not** auto-create a missing variable; Eagle's `do`/`while`-`until` |
| **6. Procedures and scope** | [proc](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl11.html) / [args](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl12.html) / [scope](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl13.html) | Named arguments (`nproc`/`napply`), `apply`, and the `[scope]` command |
| **7. Lists** | [lists](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl14.html)–[lsort](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl16.html) | Largely identical; `lindex`/`lset` index-list gather; `lmap`, `lget`, `lremove` |
| **8. Strings and `[format]`** | [string](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl17.html)–[format](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl19.html) | Culture-aware comparison; 64-class `string is`; .NET `String.Format`; extended `string map`; `format` conversions use `int` width (`%ld` for wides) |
| **9. Regular expressions** | [regexp](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl20.html)–[102](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl21.html) | Backed by the **.NET regex engine**; `-eval`/`-command` regsub modes; `-options` |
| **10. Arrays and dicts** | [arrays](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl22.html) / [dicts](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl23a.html) | `dict set` doesn't auto-create; ordering/backends; array storage backends |
| **11. Files, `exec`, channels** | [files](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl24.html) / [exec](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl26.html) | **`exec` does not error on a non-zero exit** by default; .NET-backed `file`; channels |
| **12. `info`, `source`, packages & namespaces** | [info](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl27.html) / [packages & namespaces](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl31.html) | Extended `info`; **no "creative reading/writing"** — a namespace body's unqualified names are namespace-local (reach globals via `::`/`global`), so Tcl's silent global fallback footgun is gone; and namespace support can be **enabled/disabled at runtime** (`namespace enable`), which Tcl cannot do |
| **13. Building commands: `eval`, `subst`, `format`** | [eval](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl32.html)–[subst](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl34.html) | **No `{*}` argument expansion** (an 8.5 feature outside the 8.4 baseline); use `eval`/`concat` idioms |
| **14. Errors, `catch`, and `try`** | [errors](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl36.html) / [trace](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl37.html) | `catch`/`error`/`errorInfo` as Tcl; **`try` is `finally`-only** (no Tcl-8.6 `on`/`trap`); .NET exceptions carry detail; the large Eagle-only `[debug]` command |
| **15. `clock`, args/env, leftovers** | [args & env](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl38.html) / [clock](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl41.html) | `clock` uses .NET format translation; free-form relative date parsing is not implemented |
| **16. Child interpreters** | [child interpreters](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl43.html) | `[interp]` create/eval/alias; `-safe` children — the on-ramp to Arc 2 |

### Arc 2 — The Eagle-only powers (no Tcl parallel)

These have no counterpart in the Tcl tutorial — they are the reasons to reach for
Eagle.

| Lesson | What it covers |
|--------|----------------|
| **17. Talking to .NET: the `[object]` command** | Create/invoke .NET types, opaque handles, `-alias`, overload resolution with `-parametertypes`, disposal → [object.md](object.md) |
| **18. The two-language model** | Dropping to CLR types; the `[library]` P/Invoke FFI; compiling C# from script; the `[tcl]` bridge to a real Tcl runtime |
| **19. Safety and sandboxing** | Safe interpreters, hidden commands, policy callbacks, resource limits, `[debug secureeval]` → [safe.md](safe.md), [interp.md](interp.md) |
| **20. Packages and plugins** | `[package]`, `[load]`/`[unload]`, the plugin model, and the Enterprise Edition plugins → [load.md](load.md) |
| **21. Events, `after`, threads, async** | The event loop, timers, background work, and Eagle's concurrency model |
| **22. Hosts and I/O** | The `[host]` command and the `IHost` abstraction that routes console I/O → [host.md](host.md) |
| **23. Testing your scripts** | The built-in `[test]` framework (`test1`/`test2`), constraints, and suites |
| **Capstone** | A small end-to-end script combining .NET interop with a sandboxed child interpreter |

---

## Lesson 1 — Meet Eagle, and running it

> **Prereq:** Tcl Tutorial — [Introduction](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl0.html),
> [Running Tcl](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl0a.html),
> [Simple Text Output](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl1.html).

Eagle is Tcl for the .NET Common Language Runtime. The language you type is Tcl;
the engine underneath is managed code, and every value can cross into the .NET
world when you want it to. Your first program is exactly what you'd expect:

```tcl
puts "hello, world"      ;# => hello, world
```

The difference from Tcl is not in this script — it's in *what is running it*. Two
practical consequences show up immediately:

**Eagle announces itself as Eagle, and reports its Tcl-compatibility level
separately from its own version.**

```tcl
puts $::tcl_platform(engine)     ;# => Eagle          (Tcl reports "Tcl")
puts [info tclversion]           ;# => 8.4            (the language baseline)
puts [info patchlevel]           ;# => 8.4.21         (Tcl-compat patch level)
puts [info engine PatchLevel]    ;# => 1.0.9692.29848 (Eagle's own build number)
```

`info tclversion`/`info patchlevel` describe the *Tcl language level* Eagle
implements (8.4-based); `info engine` describes the *Eagle build*. When you need
to branch on "am I running under Eagle?", test `$::tcl_platform(engine)` — the
script-library helper `isEagle` does exactly this.

That is the whole of Lesson 1: same language, different engine, and the engine is
happy to tell you so. The rest of Arc 1 is about the handful of places where
"same language" has an asterisk.

---

## Lesson 2 — Values, variables, and the first surprise: `True` / `False`

> **Prereq:** Tcl Tutorial — [Assigning values to variables](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl2.html)
> and [Evaluation & Substitutions 1–3](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl3.html).

Values, variables, word grouping, and the three substitutions (`$`, `[ ]`, `\`)
work **exactly** as they do in Tcl. `set` and `unset` are unchanged:

```tcl
set greeting "hello"
puts $greeting           ;# => hello
```

Here is the first real difference, and it is one you will notice constantly:

> **Any operation that *computes* a boolean renders it as `True` or `False`,
> not `1` or `0`.**

```tcl
puts [expr {1 == 1}]         ;# Eagle => True     (Tcl => 1)
puts [expr {2 > 3}]          ;# Eagle => False    (Tcl => 0)
puts [string equal abc abc]  ;# Eagle => True     (Tcl => 1)
puts [expr {1 && 1}]         ;# Eagle => True     (Tcl => 1)
puts [string is integer 42]  ;# Eagle => True     (Tcl => 1)
```

Comparisons, logical operators, `string equal`, `string match`, and the
`string is` classifiers all produce `True`/`False`. This is a *rendering* choice
for computed booleans — a boolean *literal* is preserved verbatim, just like a
numeric literal (more on that in Lesson 3):

```tcl
puts [expr {true}]           ;# => true   (the literal is passed through unchanged)
```

**Does this break anything?** In practice, almost never — because `True`/`False`
are still perfectly good boolean *inputs*, and Eagle still accepts `1`/`0`/`yes`/
`no`/`true`/`false` everywhere a boolean is expected. Conditions just work:

```tcl
if {3 < 5} {
    puts "yes"               ;# => yes
}
```

Two habits keep you out of trouble:

- **Use a boolean result directly as a condition** (`if {[string equal $a $b]} …`)
  rather than comparing it to a literal. That said, Eagle is forgiving if you do
  compare — `True` equals `1` numerically and the string `"True"` as you'd expect:

  ```tcl
  puts [expr {(5 > 3) == 1}]        ;# => True
  puts [expr {(5 > 3) eq {True}}]   ;# => True
  ```

- **Don't hand-parse output that "should be `1`."** If a script pipes a computed
  boolean somewhere that later does a literal `== 1` string match, prefer the
  boolean directly.

This is a specific instance of a broader Eagle trait you'll see throughout: it
favors the explicit, human-readable form. Keep going — the next lesson has the
other big surprise.

---

## Lesson 3 — Numbers and `[expr]`: a base-10 (.NET) numeric model

> **Prereq:** Tcl Tutorial — [Results of a command — Math 101](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl6.html)
> and [Computers and Numbers](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl6a.html).

`[expr]` is the same command, and simple arithmetic is unremarkable:

```tcl
puts [expr {2 + 2}]          ;# => 4
```

But the numbers underneath are .NET numbers, and that produces two differences
worth understanding well.

### 3.1 Decimal literals are base-10 and exact

Tcl evaluates `0.1 + 0.2` with binary IEEE-754 doubles, so it famously yields
`0.30000000000000004`. Eagle evaluates decimal *literals* using .NET's
`System.Decimal` — a base-10 type with ~28–29 significant digits — so the result
is exactly what you wrote:

```tcl
puts [expr {0.1 + 0.2}]          ;# Eagle => 0.3   (Tcl => 0.30000000000000004)
puts [expr {0.1 + 0.2 == 0.3}]   ;# Eagle => True  (Tcl => 0)
puts [expr {1.0 / 3.0}]          ;# Eagle => 0.3333333333333333333333333333
```

When you genuinely want binary floating point (for speed, or to match another
system's IEEE behavior), ask for it explicitly with `double()`:

```tcl
puts [expr {double(0.1) + double(0.2)}]   ;# => 0.30000000000000004
```

Functions that are inherently irrational still return IEEE doubles — there is no
exact base-10 value for them:

```tcl
puts [expr {sqrt(2)}]            ;# => 1.4142135623730951
```

### 3.2 Integers have a fixed width and wrap (no bignum promotion)

In Tcl 8.5+, an integer that overflows is silently promoted to an arbitrary-
precision "bignum." **Eagle does not do this.** An integer literal is a 32-bit
`int`; a value that needs more range is a 64-bit `wide`; and arithmetic that
exceeds the type **wraps around**, exactly as it would in C#:

```tcl
puts [expr {2147483647 + 1}]              ;# Eagle => -2147483648
                                           ;# (Tcl  => 2147483648)
puts [expr {9223372036854775807 + 1}]     ;# Eagle => -9223372036854775808
                                           ;# (Tcl  => 9223372036854775808)
```

This is deliberate: Eagle is explicit about width rather than silently changing a
value's type behind your back. When you *want* a wider or arbitrary-precision
result, you say so:

```tcl
puts [expr {wide(2147483647) + 1}]                 ;# => 2147483648        (64-bit)
puts [expr {entier(9223372036854775807) + 1}]      ;# => 9223372036854775808 (big integer)
```

- `wide(x)` forces the 64-bit path (use it before an operation that would
  otherwise overflow a 32-bit `int`).
- `entier(x)` promotes to an arbitrary-precision integer — this is the explicit
  equivalent of Tcl's automatic bignum promotion.
- `int(x)` truncates toward a 32-bit `int`; `double(x)` gives binary float.

```tcl
puts [expr {int(3.9)}]       ;# => 3
puts [expr {double(5)}]      ;# => 5
```

### 3.3 Literals are preserved

Like Tcl, Eagle keeps a numeric literal in the form you wrote it when no
arithmetic forces a conversion — so a hex literal stays hex:

```tcl
puts [expr {0x1F}]           ;# => 0x1F   (not 31)
```

The theme of this lesson is the same as the last one: Eagle prefers to do exactly
what you asked and make you name any change of kind (width or base) explicitly,
rather than promote or reinterpret values silently. That single idea — *explicit
over auto-magic* — explains most of Arc 1's remaining surprises.

---

## Lesson 4 — `if` and `switch`

> **Prereq:** Tcl Tutorial — [Numeric Comparisons — if](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl7.html)
> and [Textual Comparison — switch](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl8.html).

`if`, `elseif`, `else`, and the fact that a condition is an `[expr]` are all
exactly as in Tcl. The only thing to carry over from Lesson 2 is that a
comparison evaluates to `True`/`False` — and `if` accepts those (and `1`/`0`)
equally:

```tcl
if {5 > 3} {
    puts "bigger"                 ;# => bigger
}
```

Like Tcl, `if` is an ordinary command that returns the value of the branch it
runs, so you can use it as an expression:

```tcl
set label [if {5 > 3} {expr 10} else {expr 20}]    ;# label => 10
```

`switch` is likewise familiar — exact matching by default, plus `-glob` and
`-regexp` modes and a `--` end-of-options marker — and it returns the value of
the matched body:

```tcl
puts [switch 2 {
    1 {expr 100}
    2 {expr 200}
}]                                                 ;# => 200

switch -glob   abc { a*      { puts "starts with a" } }   ;# => starts with a
switch -regexp abc { {^a.c$} { puts "matched" } }        ;# => matched
```

Nothing here should surprise you — which is the point. Control flow is one of the
areas where Eagle and Tcl are essentially identical.

---

## Lesson 5 — Loops, and the `incr` footgun that isn't

> **Prereq:** Tcl Tutorial — [While loop](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl9.html)
> and [For and incr](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl10.html).

`while`, `for`, and `foreach` behave as in Tcl, including `foreach`'s multi-
variable and parallel-list forms:

```tcl
set sum 0
for {set i 1} {$i <= 3} {incr i} { incr sum $i }
puts $sum                                     ;# => 6

foreach {a b} {1 2 3 4} { puts "$a-$b" }      ;# => 1-2  then  3-4
```

Here is the delta, and it is a deliberate one:

> **`incr` does not create the variable if it doesn't exist.**

In Tcl, `incr count` on an undefined `count` treats it as `0` and creates it.
Eagle refuses — silently creating a variable is treated as a footgun (a typo'd
name would spring into existence):

```tcl
unset -nocomplain count
incr count        ;# Eagle: error -> can't read "count": no such variable
                   ;# Tcl:   silently creates count = 1
```

The fix is one line, and it makes the intent explicit:

```tcl
set count 0
incr count        ;# => 1
incr count 5      ;# => 6
```

You'll meet this same "no silent creation" rule again with `[dict set]` and
inside namespaces (Lesson 12). It is Lesson 3's "no silent promotion" applied to
variables: Eagle does what you said, not what it guessed you meant.

**A small addition:** Eagle has a `do` loop, for when the body must run at least
once — in both `while` (repeat while true) and `until` (repeat until true) forms:

```tcl
set n 0
do { incr n } while {$n < 3}      ;# n => 3

set n 0
do { incr n } until {$n >= 3}     ;# n => 3
```

---

## Lesson 6 — Procedures, named arguments, and persistent scope

> **Prereq:** Tcl Tutorial — [proc](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl11.html),
> [proc arguments](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl12.html), and
> [Variable scope](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl13.html).

`proc`, default arguments, the `args` catch-all, `global`, and `upvar` are all as
in Tcl, and Eagle also supports `apply` (anonymous procedures):

```tcl
proc square {x} { return [expr {$x * $x}] }
puts [square 6]                                    ;# => 36

puts [apply {{x} {expr {$x * 2}}} 21]              ;# => 42
```

### Named (keyword) arguments: `nproc` and `napply`

Eagle adds `nproc`/`napply`, which define a proc/lambda whose arguments are
passed **by name, as `name value` pairs** — in any order, with defaults filling
in the rest. (The pairs use bare names, not `-name` options.)

```tcl
nproc connect {host {port 80} {timeout 30}} {
    return "$host:$port (timeout $timeout)"
}

connect host example.com timeout 5    ;# => example.com:80 (timeout 5)
connect host localhost                ;# => localhost:80 (timeout 30)
```

`napply` is the anonymous form:

```tcl
napply {{name} { return "hi $name" }} name bob     ;# => hi bob
```

### Persistent state: `[scope]`

Sometimes a procedure should *remember* state between calls without resorting to
a global. Eagle's `[scope]` command provides a named, persistent variable
environment you can open inside a proc:

```tcl
proc counter {name} {
    scope create -open -clone -args $name
    if {![info exists count]} { set count 0 }
    incr count
}

counter myCounter     ;# => 1
counter myCounter     ;# => 2
counter myCounter     ;# => 3
scope destroy myCounter
```

The variables live in the named scope rather than the call frame, so they survive
across invocations. See [core_language.md](core_language.md) for the full
`[scope]` model (cloning, locking, namespace integration).

---

## Lesson 7 — Lists

> **Prereq:** Tcl Tutorial — [The list](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl14.html)
> through [lsearch, lsort, lrange](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl16.html).

The list commands you know — `list`, `lappend`, `lindex`, `lrange`, `llength`,
`lsearch`, `lsort`, `lreplace`, `linsert`, `split`, `join` — are all present and
behave as in Tcl, along with the 8.5-era `lrepeat`, `lreverse`, and `lassign`:

```tcl
puts [lrepeat 3 x]              ;# => x x x
puts [lreverse {1 2 3}]         ;# => 3 2 1
lassign {1 2 3} p q            ;# p => 1, q => 2   (returns the leftover: 3)
```

Eagle adds a few functional/utility commands:

```tcl
puts [lmap x {1 2 3} {expr {$x * 2}}]   ;# => 2 4 6   (transform → new list)

set matrix {a {b c d}}
puts [lget matrix 1 2]                  ;# => d       (deep index into a *variable*)

puts [lremove {a b c d} 1]              ;# => a c d   (remove the element at index 1)
```

Note `lget` takes a **variable name** (like `lindex` on a variable), whereas
`lindex` takes a value.

**One genuine difference to know.** When `lindex` (or `lset`) is given a *single
argument that is itself a list of indices*, Eagle treats it as a **gather** —
projecting the elements at those indices — whereas Tcl treats it as a *deep*
index:

```tcl
puts [lindex {a b c d e} {1 3}]      ;# Eagle => b d   (elements 1 and 3)
                                      ;# Tcl   => (empty; it deep-indexes "b" at 3)
```

The Tcl-style deep index is unchanged in the **multi-argument** form:

```tcl
puts [lindex {a {b c d} e} 1 2]      ;# => d   (element 1, then its element 2)
```

---

## Lesson 8 — Strings and `[format]`

> **Prereq:** Tcl Tutorial — [String Subcommands](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl17.html),
> [String comparisons](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl18.html), and
> [Modifying Strings — format](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl19.html).

The `string` command's core subcommands (`length`, `index`, `range`, `compare`,
`match`, `first`, `last`, `tolower`, `toupper`, `trim`, `map`, and the 8.5-era
`reverse`/`repeat`/`totitle`) all work as expected:

```tcl
puts [string reverse abc]           ;# => cba
puts [string repeat ab 3]           ;# => ababab
puts [string totitle hello]         ;# => Hello
puts [string map {a A o O} foobar]  ;# => fOObAr
```

Two Eagle characteristics are worth flagging:

- **`string is` is much richer** — Eagle ships ~64 classifier classes (integer,
  double, boolean, alpha, and many more), and they render `True`/`False`
  (Lesson 2):

  ```tcl
  puts [string is double 1.5]       ;# => True
  ```

- **Comparisons are culture-aware** — `string compare`/`equal`/`match` run on
  .NET's culture and comparison-option machinery (see [string.md](string.md)).

### `[format]` uses the platform integer width

`[format]` is the C-`printf`-style command you know, but a *bare* integer
conversion (`%d`, `%x`, `%o`, …) uses Eagle's 32-bit `int` — the same
width-specifier semantics C and Tcl have on a 32-bit-`int` platform. Use the `l`
length modifier (`%ld`, `%lx`) for 64-bit **wides**:

```tcl
puts [format %d 4294967296]     ;# => 0            (2^32, truncated to 32 bits)
puts [format %ld 4294967296]    ;# => 4294967296   (wide)

puts [format %x -1]             ;# => ffffffff           (32-bit)
puts [format %lx -1]            ;# => ffffffffffffffff   (64-bit)
```

This is the string-side echo of Lesson 3: widths are explicit. If you may be
formatting values beyond 32 bits, reach for `%ld`/`%lx`. The extended `string
map` (`-nocase`, `-regexp`, `-eval`, …) and the full `format`/`scan` behavior are
covered in [string.md](string.md).

---

## Lesson 9 — Regular expressions

> **Prereq:** Tcl Tutorial — [Regular Expressions 101](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl20.html)
> through [Regular Expressions 102](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl21.html).

`regexp` and `regsub` work the way you expect, and the patterns you know port
over — but the engine underneath is **.NET's `System.Text.RegularExpressions`**,
not Tcl's ARE engine. Eagle configures it to behave like Tcl where it matters —
most visibly, `.` matches a newline by default (Tcl's behavior, and the *opposite*
of raw .NET):

```tcl
regexp {(\d+)} "abc123" m n
puts "$m / $n"                                   ;# => 123 / 123

puts [regexp -all -inline {\d+} "a1b22c333"]     ;# => 1 22 333
puts [regexp {a.b} "a\nb"]                        ;# => 1   (dot matches newline, as in Tcl)
puts [regsub -all {\d} "a1b2" X]                  ;# => aXbX
```

The differences are additive — `regsub` gains **dynamic replacement modes** on
top of literal substitution. The cleanest is **`-command`** (Tcl TIP #463): the
replacement is a command prefix, the matched text is appended, and the command's
result becomes the replacement:

```tcl
proc doubleIt {m} { expr {$m * 2} }
puts [regsub -all -command {\d+} "a1b22c333" doubleIt]         ;# => a2b44c666
puts [regsub -all -command {\d+} "a1b22c333" {string length}]  ;# => a1b2c3
```

There is also **`-eval`** (run a script per match) and **`-options`** (pass .NET
`RegexOptions` directly), plus `-compiled`, `-line`, and more. Because these
interact with the .NET engine — and a few advanced constructs (named captures,
some class shorthands) follow .NET syntax — see [regexp.md](regexp.md) for the
full treatment and the Tcl→.NET substitution translation.

---

## Lesson 10 — Arrays and dictionaries

> **Prereq:** Tcl Tutorial — [Associative Arrays](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl22.html),
> [More On Arrays](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl23.html), and
> [Dictionaries](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl23a.html).

Arrays and `dict` behave as in Tcl — dictionaries include the 8.5 command and,
like Tcl, iterate in insertion order:

```tcl
array set a {x 1 y 2}
puts "[lsort [array names a]] ([array size a])"    ;# => x y (2)

puts [dict get {a 1 b 2} a]                         ;# => 1
puts [dict keys [dict create c 3 a 1 b 2]]          ;# => c a b   (insertion order)
```

The one delta is the rule you met in Lesson 5: **`dict set` won't create the
variable for you.** In Tcl, `dict set d k v` creates `d` when it's undefined;
Eagle requires it to exist first:

```tcl
unset -nocomplain d
dict set d k v          ;# Eagle: error -> variable not found in call frame
                         ;# Tcl:   silently creates d = {k v}

set d [dict create]      ;# create it explicitly, then...
dict set d k v
puts [dict get $d k]     ;# => v
```

Eagle also offers extra array storage backends (environment variables, databases,
and more) behind the familiar `array` interface — see [array.md](array.md).

---

## Lesson 11 — Files, `exec`, and channels

> **Prereq:** Tcl Tutorial — [File Access](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl24.html),
> [Invoking Subprocesses](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl26.html), and
> [Channel I/O](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl40.html).

File and channel operations — `open`, `close`, `gets`, `read`, `puts`, `file`,
`glob` — behave as in Tcl (backed by .NET I/O underneath):

```tcl
puts [file join a b c]                 ;# => a/b/c
puts [file tail /x/y/z.txt]            ;# => z.txt
puts [file extension archive.tar.gz]   ;# => .gz
```

The behavior to internalize is `exec`:

> **By default, `exec` does not raise an error when the child process exits with
> a non-zero status.**

```tcl
puts [exec echo hello]                 ;# => hello

set rc [catch {exec sh -c {exit 3}} output]
puts $rc                               ;# Eagle => 0  (no error)
                                        ;# Tcl   => 1  (exec raises an error)
```

In Tcl, a non-zero exit is an error you must `catch`; Eagle treats the exit code
as data rather than an exception by default, and you inspect it explicitly when
you care. See [exec.md](exec.md) for retrieving the exit code and for Eagle's
argument-quoting rules (which also differ from Tcl's).

---

## Lesson 12 — `info`, `source`, packages, and namespaces

> **Prereq:** Tcl Tutorial — [info](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl27.html)
> through [packages & namespaces](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl31.html).

`info`, `source`, and `package` work as in Tcl — and Eagle's `info` adds many
subcommands (`info engine`, richer `info commands` filters, and more). Note that
`info exists` returns `1`/`0`, **not** `True`/`False`: the boolean *rendering*
from Lesson 2 applies to *computed* booleans, while `info exists` keeps Tcl's
predicate convention.

```tcl
set v 1
puts "[info exists v] / [info exists nope]"    ;# => 1 / 0
```

The lesson's real content is **namespaces**, where Eagle deliberately removes one
of Tcl's classic footguns — the ["dangers of creative writing"](https://wiki.tcl.tk/1030).

In Tcl, code inside `namespace eval` that uses an unqualified variable which does
*not* exist in that namespace silently **falls back to a like-named global** —
reading it ("creative reading") or writing/clobbering it ("creative writing").
Eagle does neither: inside a namespace an unqualified name refers to a namespace
variable only (just as a proc's unqualified names are its locals). To reach a
global, use `::` or the `global` command.

```tcl
set x 1

# Creative READING — Tcl returns the global's value; Eagle refuses:
namespace eval ns { set x }
  ;# Eagle => error: can't read "x": no such variable
  ;# Tcl   => 1

# Creative WRITING — Tcl clobbers the global; Eagle makes a namespace variable:
namespace eval ns2 { set x 99 }
puts "global=$x  ns2=[set ns2::x]"
  ;# Eagle => global=1  ns2=99      (the global is untouched)
  ;# Tcl   => the global becomes 99, and ns2::x was never created
```

Declaring namespace variables works the usual way:

```tcl
namespace eval foo { variable y 5 }
puts [set foo::y]                              ;# => 5
```

This is Lessons 3 and 5's principle — no silent, surprising action — applied to
name resolution. See [namespace.md](namespace.md) for the full model.

---

## Lesson 13 — Building commands: `eval`, `subst`, and no `{*}`

> **Prereq:** Tcl Tutorial — [Creating Commands — eval](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl32.html)
> through [subst](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl34.html).

`eval` and `subst` are as in Tcl:

```tcl
puts [subst {1 + 1 = [expr {1 + 1}]}]          ;# => 1 + 1 = 2
```

The difference is a *missing* feature, because Eagle tracks the **Tcl 8.4**
baseline: there is **no `{*}` argument expansion** (that arrived in Tcl 8.5).
Attempting it is a parse error, not silent misbehavior:

```tcl
set args {a b c}
list {*}$args         ;# Eagle => error: extra characters after close-brace
                       ;# Tcl   => a b c
```

Use the pre-8.5 idiom instead — `eval` with the list spliced into the command:

```tcl
proc greet {a b c} { return "$a-$b-$c" }
puts [eval greet $args]                        ;# => a-b-c
```

When the elements may contain spaces or special characters, build the command
safely with `list`/`linsert` so each element stays a single word, then `eval` it:

```tcl
puts [eval [linsert $args 0 greet]]            ;# => a-b-c
```

---

## Lesson 14 — Errors, `catch`, and `try`

> **Prereq:** Tcl Tutorial — [Debugging & Errors](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl36.html)
> and [More Debugging — trace](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl37.html).

`catch`, `error`, `return -code`, and the `errorInfo`/`errorCode` variables all
work as in Tcl. `catch` returns the completion code and captures the result (and,
optionally, an options dictionary):

```tcl
set code [catch {error "boom"} result]
puts "$code: $result"                    ;# => 1: boom

proc failing {} { return -code error "custom fail" }
puts [catch {failing} r]                 ;# => 1   (r is "custom fail")
```

The options dictionary carries the full error detail, including Eagle's
`-errorline`:

```tcl
catch {error "oops" "stack info" "MY CODE"} result options
puts $options
;# => -code 1 -level 0 -errorcode {MY CODE} -errorinfo {stack info} -errorline 0
```

Two differences are worth knowing.

**1. `try` supports `finally`, but not `on`/`trap` handlers.** Eagle's `try` is
`try body ?finally script?` — the cleanup form. It does *not* have Tcl 8.6's
`on <code> {...}` / `trap <pattern> {...}` handler clauses. Use `catch` to
*handle* an error and `try`/`finally` to *clean up*:

```tcl
try {
    error "inner"
} finally {
    puts "cleanup always runs"           ;# runs, then the error propagates
}

# To HANDLE an error, use catch:
if {[catch { riskyThing } err]} {
    puts "handled: $err"
}
```

(Writing `try {...} on error {...} {...}` raises
`wrong # args: should be "try script ?finally script?"`.)

**2. Errors from the .NET layer carry .NET detail.** Where Tcl reports a terse
`divide by zero`, Eagle surfaces the underlying exception:

```tcl
catch {expr {1 / 0}} msg
puts $msg
;# Eagle => caught math exception: System.DivideByZeroException: Attempted to
;#          divide by zero. ...   (includes the .NET exception type and trace)
;# Tcl   => divide by zero
```

Finally, Eagle ships a large, first-class **`[debug]` command** — an interactive
debugger with breakpoints, variable watchpoints, single-stepping, sandboxed
evaluation, and script bundling. It has no Tcl equivalent; see
[debug.md](debug.md).

---

## Lesson 15 — `clock`, arguments, and the environment

> **Prereq:** Tcl Tutorial — [Command line arguments & environment](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl38.html),
> [Leftovers — time, unset](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl39.html), and
> [Time and Date — clock](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl41.html).

`$argv`/`$argc`, the `env` array, `unset`, and `time` all behave as in Tcl:

```tcl
puts [info exists env(PATH)]             ;# => 1   (the environment is in env(...))
puts [time {expr {1 + 1}} 1000]          ;# => e.g. "0.03 microseconds per iteration"
```

`clock` formats and scans dates, and Tcl's `%` format specifiers work — Eagle
translates them onto the underlying .NET date/time engine:

```tcl
clock format 0 -format "%Y-%m-%d %H:%M:%S" -gmt true      ;# => 1970-01-01 00:00:00

set t [clock scan "2020-06-15" -gmt true]
clock format $t -format "%Y-%m-%d" -gmt true              ;# => 2020-06-15
```

The one delta: **`clock scan` handles absolute date/time strings, but not the
free-form relative expressions** Tcl's parser accepts (`now`, `tomorrow`,
`+1 day`, `next monday`). Those raise a clean error rather than guessing:

```tcl
clock scan "now"        ;# Eagle => error: unable to convert date-time string "now"
                         ;# Tcl   => (the current time, as an integer)
```

Compute relative times from `clock seconds` instead — e.g.
`[expr {[clock seconds] + 86400}]` for "tomorrow." Eagle also adds
high-resolution timing (`clock milliseconds`/`microseconds`, `clock start`/`stop`)
and custom epochs; see [clock.md](clock.md).

---

## Lesson 16 — Child interpreters (and a first look at safety)

> **Prereq:** Tcl Tutorial — [Child interpreters](https://www.tcl-lang.org/man/tcl8.5/tutorial/Tcl43.html).

`interp` creates and drives nested interpreters, exactly as in Tcl:

```tcl
interp create child
interp eval child {expr {2 + 2}}         ;# => 4
puts [interp exists child]               ;# => True
interp delete child
puts [interp exists child]               ;# => False
```

The reason this lesson is the bridge into the second half of the tutorial is
`-safe`. A **safe** child interpreter has every dangerous command removed, so
untrusted code can run inside it without reaching the filesystem, processes, the
network, or .NET:

```tcl
interp create -safe sc
puts [interp issafe sc]                  ;# => True

interp eval sc { exec echo hi }
;# => permission denied: safe interpreter cannot use command "exec"
```

You grant a safe child *exactly* the capabilities you choose by installing an
**alias** — a command in the child that runs a trusted procedure in the parent:

```tcl
proc parentLog {msg} { return "logged: $msg" }
interp alias sc log {} parentLog         ;# create "log" in sc -> parentLog here
interp eval sc {log "hello"}             ;# => logged: hello
```

That is the core idea behind Eagle's sandboxing — and there is much more:
command hiding, policy callbacks, resource limits, execution timeouts, and
per-tenant isolation. That is exactly where **Arc 2** begins; see
[safe.md](safe.md) and [interp.md](interp.md).

---

## Lesson 17 — Talking to .NET: the `[object]` command

Arc 2 has no counterpart in the Tcl tutorial — these lessons are the capabilities
that make Eagle *Eagle*. We start with the big one: **`[object]`**, which lets a
script create and drive arbitrary .NET objects.

An object is referenced by an opaque **handle**. Create one with `-alias` and the
handle becomes a command you call directly:

```tcl
set sb [object create -alias System.Text.StringBuilder]
$sb Append "Hello"
$sb Append ", world"
puts [$sb ToString]                       ;# => Hello, world
```

**Static** members are invoked on the type name; instance members on the handle:

```tcl
puts [object invoke System.Math Sqrt 144.0]         ;# => 12

set list [object create -alias System.Collections.ArrayList]
$list Add one ; $list Add two
puts "[$list Count]: [$list Item 0]"                ;# => 2: one
```

When a method is overloaded, pin the one you mean with `-parametertypes` — which
works on the alias form too (the option is merged into the call):

```tcl
$sb -parametertypes {System.Char} Append 65         ;# appends the char 'A' (65)
```

Handles are disposed automatically at cleanup, or explicitly with
`object dispose $handle` (`-nodispose` at creation opts out). `[object]` has
40-plus sub-commands (`create`, `invoke`, `load`, `members`, `foreach`,
`dispose`, …) and is **unsafe by default** (unavailable in safe interpreters).
Full reference: [object.md](object.md); the idiom of choosing the *simplest
unambiguous* call form is in [tips_and_tricks.md](tips_and_tricks.md).

---

## Lesson 18 — The two-language model

Eagle's design thesis is that a **loosely-typed scripting layer** and a
**strongly-typed .NET layer** are better together than either alone: script the
flow, drop to typed .NET where you need types, speed, or an existing library.
Lesson 17 showed the main bridge — `[object]` — which turns any CLR type into
something a script can use.

Eagle offers three further ways to reach other languages and runtimes:

- **`[library]`** — a P/Invoke-style foreign-function interface for calling
  native C functions directly, via dynamically generated delegates. See
  [library.md](library.md).
- **`[tcl]`** — a bridge to a *real* Tcl interpreter: load an actual Tcl runtime
  and evaluate native Tcl, marshaling values both ways. Where Eagle deliberately
  omits a Tcl 8.5/8.6 feature, you can reach the genuine article. See
  [tcl.md](tcl.md).
- **Compiling C# at runtime** — Eagle can compile and run C# on the fly (through
  the .NET compiler / CodeDOM, via the `compileCSharp` family of library
  helpers), so a script can generate typed code when it needs to.

The through-line: stay in script for as long as it's the clearest tool, and step
into a typed or native layer precisely when it earns its keep — *minimal
sufficient explicitness* applied across languages.

---

## Lesson 19 — Safety and sandboxing

Lesson 16 introduced the safe child interpreter; this is the fuller picture of how
Eagle runs untrusted code with confidence.

A **safe interpreter** has every command lacking the "safe" attribute removed, so
a script cannot reach the filesystem, processes, the network, the host, or .NET:

```tcl
interp create -safe sc
interp eval sc { exec echo hi }
;# => permission denied: safe interpreter cannot use command "exec"
```

Beneath that headline are several independent layers you control:

- **Command hiding** — any command can be hidden or exposed per interpreter;
  hidden commands are unreachable from the child's scripts but still callable by
  the parent:

  ```tcl
  interp create c
  interp hide c pwd
  interp eval c { pwd }        ;# => permission denied: ... hidden command "pwd"
  interp expose c pwd
  interp eval c { pwd }        ;# works again
  ```

- **Capability grants via aliases** — the parent installs exactly the trusted
  operations the child may call (Lesson 16).
- **Policy callbacks** — decide, per invocation, whether a specific command is
  allowed.
- **Resource limits** — cap recursion depth, script size, and other resources so
  a runaway script cannot exhaust the host.
- **Execution timeouts and cancellation** — abort a long-running script from
  outside.

Together these make Eagle a practical multi-tenant sandbox. The full model —
including `[debug secureeval]` for trusted/signed evaluation — is in
[safe.md](safe.md) and [interp.md](interp.md).

---

## Lesson 20 — Packages and plugins

Eagle has Tcl's package system and adds a .NET plugin system on top.

**Packages** (script level) work as in Tcl — `package provide`, `package
require`, `package ifneeded`:

```tcl
package provide myPkg 1.2
puts [package require myPkg]                              ;# => 1.2
puts [expr {[lsearch -exact [package names] myPkg] >= 0}] ;# => True
```

**Plugins** are the .NET extension mechanism: a compiled assembly that adds
commands, functions, policies, and resources to an interpreter, loaded with
`[load]` and removed with `[unload]`:

```tcl
# load   ?options? fileName ?typeName?
# unload ?options? fileName ?typeName?
```

Loading runs a security-verification pipeline (strong name, Authenticode,
public-key token), and a plugin can optionally be isolated in its own AppDomain
(`load -isolated`). The Eagle Enterprise Edition ships several plugins on this
mechanism (Harpy, Badge, Kapok, Zeus, and more). See [load.md](load.md) for the
loading/verification model and plugin lifecycle, and each plugin's own doc for
its commands.

---

## Lesson 21 — Events, `after`, and threads

Eagle has Tcl's event loop and timers:

```tcl
after 50 { set ::done yes }
vwait ::done                                ;# waits for the event; ::done => yes

set id [after 10000 { cleanup }]
after cancel $id                            ;# cancel a pending timer
```

`after`, `vwait`, and `update` behave as in Tcl. On top of that, Eagle exposes the
CLR's threading: an `Interpreter` is thread-safe and supports genuine
**concurrent** script evaluation — multiple threads can run scripts in one
interpreter at once, with only shared state (globals, the command/object tables)
serialized under a lock. Use per-thread interpreters for isolation; to cancel a
script from another thread, use the engine's thread-safe cancel entry point. The
concurrency model is covered from the embedding side in [embedding.md](embedding.md).

---

## Lesson 22 — The host and I/O

Every bit of console-style I/O a script performs — what `puts` writes, what `gets`
reads, the prompt, the colors, the title — is routed through a **host** object,
which the `[host]` command queries and controls:

```tcl
host title "My Application"       ;# set the window/console title
```

Because I/O flows through the host rather than straight to `System.Console`, an
embedding application can redirect it anywhere — a GUI text box, a log, a socket,
or nowhere at all (a headless service). That is what makes Eagle embeddable in
environments with no console. The `[host]` command and the `IHost` abstraction are
documented in [host.md](host.md) and [interpreter_host.md](interpreter_host.md);
the C# side — writing a custom host, with a worked WinForms example — is in
[embedding.md](embedding.md).

---

## Lesson 23 — Testing your scripts

Eagle ships a full test framework — the same one its own test suite uses — built
around the `test` command (with `test1`/`test2` variants). A test names itself,
describes itself, runs a body, and compares the result:

```tcl
test myFeature-1.0 {addition works} -body {
    expr {2 + 2}
} -result 4
```

Tests support `-setup`/`-cleanup` scripts, `-constraints` (skip a test unless a
named capability is present, e.g. `windows` or `tcl86`), `-match` modes
(exact/glob/regexp), and expected-error checking. They are normally run inside the
test harness, which selects tests and reports results; a lone `test` in a bare
shell reports `SKIPPED` until the harness selects it. See the Testing section of
[tips_and_tricks.md](tips_and_tricks.md#testing).

---

## Capstone — .NET interop inside a sandbox

One script that uses nearly everything: a trusted parent helper that reaches into
.NET cryptography, exposed to a **safe** child interpreter through a single
alias, so untrusted code can hash but cannot touch the system.

```tcl
# A trusted helper (parent interpreter) that uses .NET cryptography.
proc sha256 {text} {
    set sha  [object create -alias System.Security.Cryptography.SHA256Managed]
    set enc  [object create -alias System.Text.UTF8Encoding]
    set hash [$sha ComputeHash [$enc GetBytes $text]]
    return [object invoke System.Convert ToBase64String $hash]
}

# A sandbox for untrusted code: a safe interpreter + exactly one granted capability.
interp create -safe sandbox
interp alias sandbox sha256 {} sha256

# The untrusted script can hash (via the alias) but cannot touch the system:
puts [interp eval sandbox {sha256 "hello"}]
;# => LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=

interp eval sandbox {catch {exec rm important.txt} err; puts $err}
;# => permission denied: safe interpreter cannot use command "exec"

interp delete sandbox
```

This one script draws on the whole tutorial: `[object]` to reach .NET (Lesson 17),
the two-language split (Lesson 18 — the crypto is a typed .NET library driven from
script), a **safe** child interpreter (Lessons 16 and 19), and an `interp alias`
that grants exactly one trusted capability into the sandbox. That is Eagle's value
in miniature — a scripting language that can reach the entire .NET platform, and
sandbox untrusted use of it.

---

## What's next

You've now been through the whole language — Arc 1's deltas from Tcl and Arc 2's
Eagle-only powers. That's the tutorial. For depth on any topic, the reference docs
are the next stop:

- Language reference: [core_language.md](core_language.md)
- Eagle-specific idioms and best practices: [tips_and_tricks.md](tips_and_tricks.md)
- .NET interop: [object.md](object.md) · Sandboxing: [safe.md](safe.md) ·
  Interpreters: [interp.md](interp.md) · Plugins: [load.md](load.md)
- Embedding Eagle in a C# application: [embedding.md](embedding.md)
