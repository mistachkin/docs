# Commands: Variables

`set` · `unset` · `incr` · `append` · `global` · `variable` · `upvar` · `array`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
The `[array]` ensemble is large; common sub-commands are shown here and the long
tail (8 storage backends, `array default`, `array random`, …) lives in
[`../../../../array.md`](../../../../array.md).

> Reminder: commands that return a *boolean* (`array exists`, `array default
> exists`, `info exists`-style) print **`True`/`False`**, not `1`/`0`. They behave
> as `1`/`0` in every numeric/condition context — never compare to the literal
> `"1"`. See gotcha #1.

---

## `set`

`set varName ?value?` — with `value`, assigns and **returns** it; with one
argument, **reads** the variable. Array elements use `name(index)` syntax.

- Reading an undefined variable is an error (no implicit empty string).
- `set name` on a whole array variable is an error — arrays are read per element
  or via `[array get]`.

```tcl
set x 5; puts $x                 ;# => 5
puts [set x 7]                   ;# => 7   (set returns the value)
set x 5; puts [set x]            ;# => 5   (one-arg read form)
set a(1) one; set a(2) two
puts $a(1)-$a(2)                 ;# => one-two
puts [set nope]                  ;# => can't read "nope": no such variable
array set a {x 1}; puts [set a]  ;# => can't read "a": variable is array
```

## `unset`

`unset ?options? ?varName ...?` — deletes one or more variables (or array
elements). Options: `-nocomplain`, `-unlinkonly`, `-remove`, `-notrace`,
`-purge`, `-zerostring`, `-maybezerostring`.

- Unsetting a non-existent variable is an error unless `-nocomplain` is given.
- Accepts multiple names; `name(index)` removes a single array element.

```tcl
set x 5; unset x; puts [info exists x]      ;# => 0
unset nope                                  ;# => can't unset "nope": no such variable
unset -nocomplain nope; puts done           ;# => done
set a 1; set b 2; unset a b
puts [info exists a][info exists b]          ;# => 00
set a(x) 1; set a(y) 2; unset a(x)
puts [array names a]                          ;# => y
```

## `incr`

`incr varName ?increment?` — adds `increment` (default `1`, may be negative) to
an integer variable and **returns** the new value.

- **Eagle does NOT auto-create a missing variable** (it errors) — this matches
  the **Tcl 8.4** baseline; **Tcl 8.5/8.6** instead create it and return `1`.
  Initialize first (`set n 0; incr n`). This is a deliberate anti-footgun.
- On a missing array *element* it also errors (`no such element in array`)
  unless an `[array default]` is set for that array.
- The error wording uses Eagle's "wide integer" (Tcl says "integer").

```tcl
set n 5; incr n;  puts $n        ;# => 6
set n 5; incr n 3; puts $n       ;# => 8
set n 5; incr n -2; puts $n      ;# => 3
set n 0; puts [incr n 10]        ;# => 10
set n 10; puts [incr n -15]      ;# => -5
incr fresh                       ;# => can't read "fresh": no such variable
                                 ;#    (Eagle = Tcl 8.4; Tcl 8.5/8.6 => 1)
set n abc; incr n                ;# => expected wide integer but got "abc"
                                 ;#    (Tcl: expected integer but got "abc")
```

## `append`

`append varName ?value ...?` — appends each `value` to the variable's string and
**returns** the result.

- Unlike `[incr]`, `[append]` **does auto-create** a missing variable (same as
  Tcl). Works on array elements too.

```tcl
set s foo; append s bar baz; puts $s   ;# => foobarbaz
append fresh hello; puts $fresh         ;# => hello   (auto-created)
set s a; puts [append s b]              ;# => ab
set a(log) start; append a(log) -more
puts $a(log)                            ;# => start-more
```

## `global`

`global ?varName ...?` — inside a proc, links the named variables to the
**global** namespace so reads/writes hit the global scope. No-op at top level.

```tcl
set g 99
proc p {} {global g; return $g}
puts [p]                                 ;# => 99

set g 1
proc bump {} {global g; incr g}
bump; bump; puts $g                      ;# => 3

proc make {} {global created; set created 42}
make; puts $created                      ;# => 42   (global write is visible)
```

## `variable`

`variable ?name value ...? name ?value?` — declares/initializes **namespace**
variables; inside a proc it links a name to the *current* namespace's variable
(the namespace analogue of `[global]`). A trailing bare `name` declares the link
without assigning.

```tcl
namespace eval ns {variable v 42}
puts $ns::v                              ;# => 42

namespace eval ns {
  variable count 0
  proc inc {} {variable count; incr count}
}
ns::inc; ns::inc; puts $ns::count        ;# => 2

namespace eval ns {
  variable v
  proc set_v {x} {variable v; set v $x}
  set_v 7
}
puts $ns::v                              ;# => 7   (bare-name declare, then set)
```

## `upvar`

`upvar ?level? otherVar localVar ?otherVar localVar ...?` — binds a local name
to a variable in another call frame. `level` is relative (default `1` = caller)
or absolute when prefixed with `#` (`#0` = global). The other-name may be an
array element.

```tcl
proc setit {name val} {upvar 1 $name v; set v $val}
setit x hi; puts $x                      ;# => hi

proc readit {name} {upvar $name v; return $v}
set y 33; puts [readit y]                ;# => 33   (level defaults to 1)

set g 5
proc f {} {upvar #0 g local; set local 10}
f; puts $g                               ;# => 10   (#0 = global frame)

set a(k) 1
proc bump {ref} {upvar 1 $ref x; incr x}
bump a(k); puts $a(k)                     ;# => 2    (upvar to an array element)
```

---

## `array`

`array subcommand arrayName ?arg ...?` — an ensemble for associative arrays.
Eagle ships **17** sub-commands (Tcl ~10). The authoritative list:

`anymore` · `copy` · `default` · `donesearch` · `exists` · `for` · `foreach` ·
`get` · `lmap` · `names` · `nextelement` · `random` · `set` · `size` ·
`startsearch` · `unset` · `values`

Sub-commands **not in Tcl**: `copy`, `default` (TIP #508 form), `foreach`,
`lmap`, `random`, `values`. Tcl's `array statistics` is **not** implemented:

```tcl
array set a {x 1}; array statistics a
;# => bad option "statistics": must be anymore, copy, default, donesearch,
;#    exists, for, foreach, get, lmap, names, nextelement, random, set, size,
;#    startsearch, unset, or values
```

### Core operations — `set` / `get` / `names` / `exists` / `size` / `unset`

- `array set arrayName list` — populate from a flat `{k v k v …}` list;
  **creates** the array if missing (unlike `[incr]`); the list must have an even
  length.
- `array get arrayName ?pattern?` — flat `{k v …}`; optional glob on keys.
- `array names arrayName ?mode? ?pattern?` — keys; modes `-glob` (default),
  `-exact`, `-regexp`, `-substring`. (Eagle's `-substring` is a *prefix*
  match — see [`../../../../array.md`](../../../../array.md).)
- `array exists` / `array size` never error on a missing array (`False` / `0`).

```tcl
array set a {name Alice age 30}
puts [array get a]                          ;# => name Alice age 30
array set a {name Alice age 30 city Boston}
puts [array get a a*]                        ;# => age 30

puts [lsort [array names a]]                 ;# => age city name
array set b {apple 1 apricot 2 banana 3}
puts [lsort [array names b a*]]              ;# => apple apricot
puts [lsort [array names b -regexp {^b}]]    ;# => banana

array set c {x 1}
puts [array exists c]-[array exists nope]    ;# => True-False
puts [array size c]                          ;# => 1
puts [array size nope]                        ;# => 0   (no error)

array set d {a 1 b 2 c 3}
array unset d b; puts [lsort [array names d]] ;# => a c
array unset d;   puts [array exists d]        ;# => False

array set e {x 1 y}                           ;# => list must have an even number of elements
```

### Iteration — `array for` (and `foreach` / `lmap`)

```tcl
array set a {a 1 b 2}
set out {}
array for {k v} a {lappend out $k=$v}
puts [lsort $out]                            ;# => a=1 b=2
```

### `array values` (Eagle) — values, with the same match modes as `names`

```tcl
array set a {a 10 b 20 c 30}
puts [lsort -integer [array values a]]       ;# => 10 20 30
puts [array values a -glob 2*]               ;# => 20
```

### `array copy` (Eagle) — shallow by default, `-deep` for independent elements

```tcl
array set src {a 1 b 2}
array copy src dst
puts [array get dst]                         ;# => a 1 b 2
```

### `array default` (Eagle, TIP #508) — `set` / `get` / `exists` / `unset`

A default makes missing-element reads return the default instead of erroring —
ideal for counters (lets `[incr]` work on a never-seen key).

```tcl
array set counts {}
array default set counts 0
incr counts(apples); incr counts(apples)
puts $counts(apples)                         ;# => 2
puts [array default get counts]-[array default exists counts]
                                             ;# => 0-True
```

### Manual search — `startsearch` / `anymore` / `nextelement` / `donesearch`

```tcl
array set a {a 1 b 2 c 3}
set sid [array startsearch a]
set out {}
while {[array anymore a $sid]} {lappend out [array nextelement a $sid]}
array donesearch a $sid
puts [lsort $out]                            ;# => a b c
```

### Virtual-array backends

`array` is polymorphic — `env` exposes process environment variables through the
same interface (plus thread/database/network/registry/System.Array backends):

```tcl
puts [expr {[lsearch -exact [array names env] PATH] >= 0}]   ;# => True
```

For the 8 backends, `array random`'s 5 options, per-element flags, `-deep`
internals, and the `-substring` (prefix) match semantics, see the deep-dive:
[`../../../../array.md`](../../../../array.md).
