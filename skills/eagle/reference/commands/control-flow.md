# Commands: Control Flow

`if` · `switch` · `for` · `foreach` · `while` · `do` · `break` · `continue` ·
`catch` · `error` · `throw` · `return` · `try`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
Call-frame commands (`uplevel`, `upvar`, `global`, `variable`) are in
[`procs-namespaces.md`](procs-namespaces.md).

> Reminder: `[expr]`-based conditions return **`True`/`False`**, which work as
> conditions and as `1`/`0` everywhere except string identity — never compare a
> condition's result to the literal `"1"`. See gotcha #1.

---

## `if`

`if cond ?then? body ?elseif cond ?then? body ...? ?else? body`

The `then` and `else` keywords are optional (as in Tcl).

```tcl
if {1 < 2} then {puts yes} else {puts no}      ;# => yes
if {[string length foo] == 3} {puts ok}        ;# => ok
```

## `switch`

`switch ?options? string {pattern body ?pattern body ...?}` — options include
`-exact` (default), `-glob`, `-regexp`, `-nocase`, and `--` to end options. A
`-` body means "fall through to the next pattern's body"; `default` matches
anything.

```tcl
switch -- b {a {puts A} b {puts B} default {puts D}}   ;# => B
switch -glob ab* {a* {puts hit}}                       ;# => hit
switch x {a {puts A} default {puts def}}               ;# => def
```

## `for`

`for start cond next body`

```tcl
set s 0
for {set i 0} {$i < 3} {incr i} {incr s $i}
puts $s                                          ;# => 3   (0+1+2)
```

## `foreach`

`foreach var list body` — supports **multiple variables per list** (consumes
that many elements per iteration) and **multiple parallel lists**.

```tcl
foreach {a b} {1 2 3 4} {puts $a-$b}     ;# => 1-2  then  3-4
foreach x {1 2} y {a b} {puts $x$y}      ;# => 1a   then  2b
```

## `while`

`while cond body`

```tcl
set i 0; while {$i < 3} {incr i}; puts $i        ;# => 3
```

## `do` — Eagle extension (no Tcl equivalent)

`do body while cond` / `do body until cond` — runs the body **at least once**,
then loops while/until the condition holds.

```tcl
set i 0; do {incr i} while {$i < 3}; puts $i     ;# => 3
```

## `break` / `continue`

Standard loop control (also valid completion codes for `return -code`). `break`
exits the innermost loop; `continue` skips to its next iteration.

## `catch` — the primary error-trapping mechanism in Eagle

`catch script ?resultVar? ?optionsVar?` — returns a completion code (`0` = ok,
`1` = error, plus `break`/`continue`/`return` codes). The 3-argument form fills
an **options dictionary** (Tcl 8.5+ style; Eagle adds `-errorline`).

```tcl
puts [catch {error "boom" "" MYCODE} m]        ;# => 1
catch {error oops} m opts
puts $opts
;# => -code 1 -level 0 -errorcode NONE -errorinfo {oops
;#        while executing
;#    "error oops"
;#        ("catch" body line 1)} -errorline 1
```

> In Eagle, prefer `[catch]` for error handling — `[try]` only adds a `finally`
> (see below); it has no `on error` / `trap` clauses.

## `error`

`error message ?info? ?code?` — raises an error; `info` seeds `$errorInfo` and
`code` sets `$errorCode`. This is the portable, well-behaved way to raise.

```tcl
puts [catch {error "boom" "INFO" MYCODE} m]:$m:$::errorCode   ;# => 1:boom:MYCODE
```

## `throw` — Eagle signature differs from Tcl 8.6

In **Tcl 8.6** `throw` is `throw type message`. In **Eagle** the form is
`throw message ?completionCode?` (message first; the optional second argument is
a *completion code* such as `Error`, not an errorCode list). Passing a Tcl-style
`throw {TYPE} message` fails because `message` is read as a completion code:

```tcl
catch {throw {MY ERR} "msg"} m
;# => bad completion code "msg": must be Break, Continue, CustomError, CustomOk,
;#    Error, Exception, Invalid, Ok, Reserved, Return, WhatIf, or an integer
```

For raising errors portably, use `[error]`. Reach for `[throw]` only when you
specifically want Eagle's completion-code semantics.

## `return`

`return ?-code code? ?-level n? ?-errorcode list? ?-options dict? ?result?` —
returns from a proc; `-code error` raises, `-level` controls how many frames the
code propagates.

```tcl
proc p {} {return -code error "custom"}
puts [catch p m]:$m                              ;# => 1:custom
```

## `try` — Eagle supports only the `finally` form

`try body ?finally cleanup?`. Eagle does **not** implement Tcl 8.6's
`on`/`trap`/`catch` handler clauses — use `[catch]` for catching. The `finally`
block always runs.

```tcl
try {set x 1} finally {puts done}                ;# => done

# Catching is done with catch, not a try handler:
if {[catch {error nope} msg]} {puts "caught:$msg"}   ;# => caught:nope
```

Using a handler clause is an error:

```tcl
catch {try {error x} on error {m o} {puts $m}} e
;# => wrong # args: should be "try script ?finally script?"
```
