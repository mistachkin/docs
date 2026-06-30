# Commands: Dictionaries

`dict create` · `get` · `set` · `unset` · `exists` · `keys` · `values` · `size` ·
`foreach` · `map` · `filter` · `merge` · `append` · `lappend` · `incr` ·
`replace` · `remove` · `update` · `with` · `info` — the full **`dict`** ensemble
(20 sub-commands).

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).

> `dict` is a Tcl **8.5+** command — Tcl **8.4 has no `[dict]` at all** (Eagle,
> though it reports an 8.4 patchlevel, includes it). Two ensemble-wide traps:
> **`dict exists` — like every boolean — returns `True`/`False`, not `1`/`0`**
> (gotcha #1), and the **variable-mutating** sub-commands do **not** auto-create
> a missing variable (gotcha #7) — see the callout under [`dict set`](#dict-set).
> Sub-command names accept **unique prefixes** (`dict ke` = `dict keys`); `dict s`
> is *ambiguous* (`set`/`size`).

A dictionary is just a list with an even number of elements (alternating
key/value); keys are returned in **insertion order**.

---

## `dict create`

`dict create ?key value ...?` — build a dictionary value (an even-length list).
Empty with no args; an odd arg count is an error.

```tcl
puts [dict create a 1 b 2]              ;# => a 1 b 2
puts "[dict create]<"                   ;# => <          (empty)
catch {dict create a} m; puts $m        ;# => wrong # args: should be "dict create ?key value ...?"
```

## `dict get`

`dict get dictionaryValue ?key ...?` — value for a key; **no key** returns the
whole dict; **multiple keys** traverse nested sub-dictionaries. A missing key is
an error (use [`dict exists`](#dict-exists) to probe first).

```tcl
set d [dict create a 1 b 2]
puts [dict get $d a]                    ;# => 1
puts [dict get $d]                      ;# => a 1 b 2
set n [dict create x [dict create y 9]]
puts [dict get $n x y]                  ;# => 9
catch {dict get $d zzz} m; puts $m      ;# => cannot find final dictionary key ["zzz"]
```

> The missing-key message differs from Tcl 8.5/8.6 (`key "zzz" not known in
> dictionary`); only the wording differs — both raise.

## `dict exists`

`dict exists dictionaryValue key ?key ...?` — does the key path exist? Returns
**`True`/`False`** (never errors on a missing key). Multiple keys descend nested
dicts.

```tcl
set d [dict create a 1 b 2]
puts [dict exists $d a]                 ;# => True
puts [dict exists $d q]                 ;# => False
set n [dict create x [dict create y 9]]
puts [dict exists $n x y]               ;# => True
```

> Tcl returns `1`/`0` here; Eagle's `True`/`False` work identically as
> conditions but **never** string-compare them to `"1"` (gotcha #1).

## `dict keys` / `dict values` / `dict size`

`dict keys dict ?glob?` · `dict values dict ?glob?` · `dict size dict` — the
keys, the values (each optionally glob-filtered), and the top-level pair count.

```tcl
set d [dict create a 1 b 2 c 3]
puts [dict keys $d]                     ;# => a b c
puts [dict values $d]                   ;# => 1 2 3
puts [dict size $d]                     ;# => 3
puts [dict keys {apple 1 avocado 2 berry 3} a*]   ;# => apple avocado
puts [dict values {a 1 b 2 c 10} 1*]              ;# => 1 10
puts [dict size {}]                     ;# => 0
```

<a id="dict-set"></a>
## `dict set`

`dict set dictionaryVariable key ?key ...? value` — store into a dict held in a
**variable**. Extra keys create/traverse nested sub-dicts. Updates in place and
returns the new value.

```tcl
set d [dict create a 1]
dict set d b 2 ; puts $d                ;# => a 1 b 2
dict set d a 9 ; puts $d                ;# => a 9 b 2
set e [dict create]
dict set e x y z ; puts $e              ;# => x {y z}   (nested)
```

> **Gotcha (by design): the variable must already exist.** Unlike Tcl 8.5/8.6
> (which auto-creates), every `dict` sub-command that mutates a *variable* —
> `set`, `unset`, `append`, `lappend`, `incr`, `update`, `with` — raises on a
> missing variable. This is the same anti-footgun as `[incr]` (gotcha #7).
>
> ```tcl
> catch {dict set noVar k v} m; puts $m  ;# => variable not found in call frame
> ```
>
> Fix: initialize first — `set d [dict create]` (or `set d {}`), *then* mutate.
> (Keys *within* an existing variable are still created as needed, as above.)

## `dict unset`

`dict unset dictionaryVariable key ?key ...?` — remove a key from a dict
variable; nested keys descend. Removing a non-existent **key** is *not* an error
(but a missing **variable** is — see the callout above).

```tcl
set d [dict create a 1 b 2]
dict unset d a ; puts $d                ;# => b 2
set n [dict create x [dict create y 9 z 8]]
dict unset n x y ; puts $n              ;# => x {z 8}
```

## `dict append` / `dict lappend`

`dict append var key ?string ...?` — string-append to a key's value.
`dict lappend var key ?value ...?` — list-append elements. Both create the
*key* if absent (but the *variable* must already exist — see callout).

```tcl
set d [dict create a foo]
dict append d a bar ; puts $d           ;# => a foobar
set l [dict create a {1 2}]
dict lappend l a 3 4 ; puts $l          ;# => a {1 2 3 4}
```

> Tcl auto-creates the variable for these; Eagle does not
> (`catch {dict append noVar k hi}` → `variable not found in call frame`).

## `dict incr`

`dict incr dictionaryVariable key ?increment?` — add `increment` (default `1`)
to a key's integer value; creates the key (value = increment) if absent.

```tcl
set d [dict create n 5]
dict incr d n ; puts $d                 ;# => n 6
dict incr d n 10 ; puts $d              ;# => n 16
set e [dict create]
dict incr e new ; puts $e               ;# => new 1
```

## `dict merge`

`dict merge ?dictionaryValue ...?` — return a new dict combining the arguments;
**later dicts win** on duplicate keys. No args → empty.

```tcl
puts [dict merge {a 1 b 2} {b 9 c 3}]           ;# => a 1 b 9 c 3
puts [dict merge {a 1} {a 2 b 2} {b 3 c 3}]     ;# => a 2 b 3 c 3
```

## `dict replace` / `dict remove`

`dict replace dict ?key value ...?` — new dict with pairs added/replaced.
`dict remove dict ?key ...?` — new dict with keys removed (missing keys ignored).
Both are **value-based**: they take a value and return a new one, leaving any
source variable untouched.

```tcl
set d [dict create a 1 b 2]
puts [dict replace $d b 9 c 3]          ;# => a 1 b 9 c 3
puts $d                                 ;# => a 1 b 2   (original unchanged)
puts [dict remove {a 1 b 2 c 3} a c]    ;# => b 2
```

## `dict foreach` — Eagle's name (Tcl uses `dict for`)

`dict foreach {keyVar valueVar} dictionaryValue body` — iterate pairs; supports
`break`/`continue`; returns the empty string.

```tcl
dict foreach {k v} {a 1 b 2} {puts $k=$v}   ;# => a=1   then   b=2
```

> **Naming is reversed from Tcl.** Eagle's canonical sub-command is `foreach`
> (Tcl 8.5/8.6 has `dict for` and **no** `dict foreach`). `dict for` still works
> in Eagle — but only because `for` is a *unique prefix* of `foreach`. For code
> that must run on both, write **`dict for`** (real in Tcl, prefix-matched in
> Eagle); for Eagle-only code, `dict foreach` is clearest.

## `dict map` — differs from Tcl 8.6 on empty results

`dict map {keyVar valueVar} dictionaryValue body` — build a new dict by
evaluating `body` per pair; the body's result becomes the new value.

```tcl
puts [dict map {k v} {a 1 b 2} {expr {$v * 10}}]      ;# => a 10 b 20
puts [dict map {k v} {a 1 b 2} {string repeat $k $v}] ;# => a a b bb
```

> **Eagle drops a key whose body returns empty; Tcl 8.6 keeps it with value
> `{}`** (Tcl 8.5 has no `dict map`):
>
> ```tcl
> dict map {k v} {a 1 b 2 c 3} {expr {$v==2 ? {} : $v}}
> ;# => Eagle:   a 1 c 3
> ;# => Tcl 8.6: a 1 b {} c 3
> ```

## `dict filter`

`dict filter dict key ?glob ...?` · `... value ?glob ...?` · `... script
{kVar vVar} body` — return a new dict of matching entries. `key`/`value` keep
entries matching **any** glob; `script` keeps entries for which `body` is true.

```tcl
puts [dict filter {apple 1 banana 2 cherry 3} key a* c*]  ;# => apple 1 cherry 3
puts [dict filter {a 1 b 2 c 3} value 2]                  ;# => b 2
puts [dict filter {a 1 b 2 c 3} script {k v} {expr {$v > 1}}]  ;# => b 2 c 3
```

## `dict update`

`dict update dictionaryVariable key varName ?key varName ...? body` — bind keys
to local variables, run `body`, then write the variables back into the dict.
**Unsetting** a bound variable removes its key; assigning a *new* bound variable
adds its key. (Variable must exist — see [`dict set`](#dict-set) callout.)

```tcl
set d [dict create a 1 b 2]
dict update d a x b y {set x [expr {$x+100}]; set y [expr {$y+100}]}
puts $d                                 ;# => a 101 b 102

set d [dict create a 1]
dict update d a x {unset x} ; puts "$d<" ;# => <          (key removed)

set d [dict create a 1]
dict update d b x {set x 99} ; puts $d   ;# => a 1 b 99   (key added)
```

## `dict with`

`dict with dictionaryVariable ?key ...? body` — unpack **all** keys (of the dict,
or of a nested sub-dict named by the key path) into like-named local variables,
run `body`, then write them back. Returns the empty string.

```tcl
set d [dict create a 1 b 2]
dict with d {set a [expr {$a+5}]} ; puts $d   ;# => a 6 b 2

set rec [dict create person [dict create name Joe age 40]]
dict with rec person {set age 41} ; puts $rec ;# => person {name Joe age 41}
```

## `dict info` — Eagle-specific format

`dict info dictionaryValue` — a human-readable description of the dict's internal
structure. **Eagle's wording is its own** (Tcl reports hash-bucket statistics);
treat the exact text — especially the trailing hash code — as build-specific and
do not parse it.

```tcl
puts [dict info {a 1 b 2 c 3}]
;# => 3 root entries in table, 3 nested entries in table, hash code 0x1E88916
```

---

## Not present in Eagle

- **`dict for`** as a *real* sub-command — it only works as a prefix of
  `dict foreach` (above). The authoritative name is `foreach`.
- **`dict getdef` / `dict getwithdefault`** — the Tcl 8.7 "default value"
  accessors are absent (and not in Tcl 8.5/8.6 either):

  ```tcl
  catch {dict getdef {a 1} b 99} m; puts $m
  ;# => bad option "getdef": must be append, create, exists, filter, foreach,
  ;#    get, incr, info, keys, lappend, map, merge, remove, replace, set, size,
  ;#    unset, update, values, or with
  ```

  Emulate with `expr {[dict exists $d k] ? [dict get $d k] : $default}`.
