# Commands: Lists

`list` · `lindex` · `llength` · `lrange` · `linsert` · `lreplace` · `lremove` ·
`lset` · `lsearch` · `lsort` · `lassign` · `lrepeat` · `lreverse` · `lmap` ·
`lget` · `concat` · `join` · `split`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
The list-iteration commands `foreach` / `lmap` overlap with control flow — see
also [`control-flow.md`](control-flow.md).

> Eagle ships several list commands that are **8.5/8.6 in Tcl** (`lassign`,
> `lrepeat`, `lreverse`, `lmap`) plus two with **no Tcl equivalent** (`lremove`,
> `lget`). Three behaviors intentionally **differ from Tcl** and are flagged
> below: `lindex` with a single index-*list* (a projection), `lremove`/`lset`'s
> anti-footgun strictness, and `lsearch -substring` (a **prefix** match).
> `lsearch`/`lsort` return numeric indices or sorted elements — never
> `True`/`False`.

---

## `list`

`list ?arg ...?` — build a properly quoted list; each argument becomes exactly
one element. Always prefer this over string concatenation when composing lists
or commands.

```tcl
list a b c                ;# => a b c
list a {b c} d            ;# => a {b c} d
list "hello world" foo    ;# => {hello world} foo
list                      ;# => (empty string)
```

## `lindex`

`lindex list ?index ...?` — element at *index*; out-of-range yields the **empty
string** (no error). Multiple index arguments do nested descent
(`lindex $l i j` == `lindex [lindex $l i] j`). With no index, returns the whole
list.

```tcl
lindex {a b c d e} 0            ;# => a
lindex {a b c d e} end          ;# => e
lindex {a b c d e} end-1        ;# => d
lindex {{1 2} {3 4} {5 6}} 1 0  ;# => 3      (nested descent, multi-arg form)
lindex {a b c} 99               ;# => (empty string; no error)
lindex {a b c}                  ;# => a b c  (no index = whole list)
```

**Eagle-specific (differs from Tcl):** a *single* index argument that is itself
a list of indices is a **projection** — each index resolved against the
top-level list — not nested descent as in Tcl. An empty index list errors.

```tcl
lindex {{1 2} {3 4} {5 6}} {0 2}  ;# => {1 2} {5 6}   (Eagle: elements 0 and 2)
                                  ;# Tcl 8.4/8.5/8.6: "" (nested: lindex "1 2" 2)
catch {lindex {a b c} {}} m; set m  ;# => invalid index string  (Tcl returns whole list)
```

For descent that is portable to Tcl, use the multi-argument form
(`lindex $l i j`), never a single list argument.

## `llength`

`llength list` — number of elements. A nested list counts as one element.

```tcl
llength {a b c d}     ;# => 4
llength {}            ;# => 0
llength {{a b} c}     ;# => 2   (the {a b} sublist is one element)
```

## `lrange`

`lrange list first last` — sublist from *first* to *last* inclusive; indices
accept `end` / `end-n`. Returns a new list.

```tcl
lrange {a b c d e} 1 3     ;# => b c d
lrange {a b c d e} 2 end   ;# => c d e
lrange {a b c} 0 end-1     ;# => a b
```

## `linsert`

`linsert list index value ?value ...?` — new list with *value*s inserted
**before** *index*. Index `0` prepends; `end` inserts before the last element;
an index past the end appends. The original list is unchanged.

```tcl
linsert {a b c} 1 X Y    ;# => a X Y b c
linsert {a b c} 0 X      ;# => X a b c
linsert {a b c} end X    ;# => a b c X
linsert {a b c} 99 Z     ;# => a b c Z   (past end appends)
```

## `lreplace`

`lreplace list first last ?value ...?` — new list with elements `first..last`
replaced by the *value*s. With no values it **deletes** that range; with
`first > last` it **inserts** (nothing removed).

```tcl
lreplace {a b c d e} 1 2 X Y Z   ;# => a X Y Z d e
lreplace {a b c d e} 1 2         ;# => a d e     (deletion)
lreplace {a b c} 1 0 X           ;# => a X b c   (insertion: first > last)
lreplace {a b c d} end end Z     ;# => a b c Z
```

## `lremove` — Eagle extension (no Tcl equivalent)

`lremove list index ?index ...?` — returns *list* with **one** element removed.
A single index removes that top-level element. **Multiple indices are a nested
path** (descent to the element to remove), *not* a list of top-level positions —
mirror image of Tcl `lindex`'s descent. An index-list passed as one argument is
**not** accepted (it is parsed as a single bad index).

```tcl
lremove {a b c d e} 1            ;# => a c d e          (remove top-level index 1)
lremove {{a b c} {d e f}} 1 0    ;# => {a b c} {e f}    (remove element at path 1,0 = "d")
lremove {a {b c d} e} 1 1        ;# => a {b d} e        (remove path 1,1 = "c")
catch {lremove {a b c d e} 1 3} m; set m
;# => list index out of range   (NOT multi-remove: index 1 = "b", then descends to "b"[3])
catch {lremove {a b c d e} {1 3}} m; set m
;# => bad index "1 3": must be start|end|count|integer?[+-*/%]start|end|count|integer?
```

> To delete several top-level positions, sort the indices high-to-low and call
> `lremove` (or `lreplace`) once per index, or use `lsearch`/`lmap` to filter.

## `lset`

`lset varName ?index ...? value` — modify the list in *varName* in place,
replacing the element at the (possibly nested) index. Returns the new list.

**Eagle-specific (anti-footgun, differs from Tcl):** `lset` **modifies only** —
it will not create the variable, will not grow the list, and rejects an index
equal to the length (`end+1` / `<len>`). Use `set` to create and
`lappend`/`linsert` to grow. The empty-index whole-list replace **is**
supported.

```tcl
set mylist {a b c d}
lset mylist 1 X            ;# => a X c d   (mylist is now {a X c d})
set nested {{1 2} {3 4}}
lset nested 0 1 9          ;# => {1 9} {3 4}   (nested set)
set wl {a b c}
lset wl {} {x y z}         ;# => x y z   (empty index = wholesale replace)
catch {set l {a b c}; lset l 3 X} m; set m       ;# => list index out of range  (no grow)
catch {set l {a b c}; lset l end+1 X} m; set m   ;# => list index out of range
```

## `lsearch`

`lsearch ?options? list pattern` — returns the **index** of the first match, or
`-1` if none (it returns an index, *not* a boolean). Key options:

- Match mode: `-exact`, `-glob` (default), `-regexp`, `-sorted` (binary search,
  list must be sorted), `-substring` (Eagle extension — **prefix** match; see
  trap below).
- Comparison type: `-ascii` (default), `-dictionary`, `-integer`, `-real`,
  `-nocase`.
- Result shaping: `-all` (all match indices), `-inline` (return the matched
  *values* instead of indices), `-not` (invert), `-start n` (begin at index n),
  `-index n` (match within element *n* of each sublist), `-subindices` (with
  `-index`, return full nested paths).

```tcl
lsearch {a b c d} c                       ;# => 2
lsearch {a b c d} x                       ;# => -1   (not found)
lsearch -exact {abc abcd ab} abc          ;# => 0
lsearch -glob {apple banana cherry} b*    ;# => 1
lsearch -regexp {cat dog bird} {^d}       ;# => 1
lsearch -nocase {Apple Banana} banana     ;# => 1
lsearch -integer {1 2 3 4} 3              ;# => 2
lsearch -sorted -integer {1 3 5 7 9} 7    ;# => 3   (binary search)
lsearch -all {1 2 3 2 1} 2                ;# => 1 3
lsearch -all -inline {1 2 3 2 1} 2        ;# => 2 2
lsearch -inline -glob {apple banana} a*   ;# => apple
lsearch -all -inline -not {a b a c} a     ;# => b c
lsearch -start 2 {a b a c a} a            ;# => 2
lsearch -index 0 {{a 1} {b 2}} b          ;# => 1
lsearch -subindices -index 0 -all {{a 1} {b 2} {a 3}} a   ;# => {0 0} {2 0}
```

**Trap — `-substring` is a PREFIX (StartsWith) match, not contains-anywhere**
(verified; `-substring` is an Eagle extension — no Tcl version has it). A
substring that begins an element matches; one in the middle/end does not.

```tcl
lsearch -substring {alpha beta gamma} al   ;# => 0    ("al" is a prefix of "alpha")
lsearch -substring {alpha beta gamma} ph   ;# => -1   ("ph" is mid-string, NOT a prefix)
lsearch -substring {hello world} wor       ;# => 1    ("wor" is a prefix of "world")
lsearch -substring {hello world} orl       ;# => -1   ("orl" is mid-string)
```

## `lsort`

`lsort ?options? list` — returns a sorted **copy** (original unchanged). Key
options:

- Compare type (mutually exclusive): `-ascii` (default), `-dictionary`,
  `-integer`, `-real`, `-command cmdPrefix`.
- Order: `-increasing` (default), `-decreasing`.
- Modifiers: `-nocase`, `-unique`, `-index indexList` (sort by an element within
  each sublist), `-random` (shuffle — non-deterministic output).

```tcl
lsort {banana Apple cherry}              ;# => Apple banana cherry   (ASCII: caps first)
lsort -ascii {B a C b A c}               ;# => A B C a b c
lsort -nocase {banana Apple cherry}      ;# => Apple banana cherry
lsort -integer {10 2 5 1}                ;# => 1 2 5 10
lsort -real {3.5 1.2 2.8}                ;# => 1.2 2.8 3.5
lsort -dictionary {x10 x2 x1}            ;# => x1 x2 x10   (embedded numbers compare numerically)
lsort -decreasing {1 3 2}                ;# => 3 2 1
lsort -unique {a b a c b}                ;# => a b c
lsort -index 1 {{a 2} {b 1} {c 3}}       ;# => {b 1} {a 2} {c 3}
lsort -index 1 -decreasing {{a 2} {b 1} {c 3}}   ;# => {c 3} {a 2} {b 1}
lsort -command {apply {{x y} {expr {[string length $x] - [string length $y]}}}} {aaa b cc}
;# => b cc aaa   (custom comparator: by length)
```

**Eagle-specific (differs from Tcl 8.5/8.6):** Eagle's `lsort` has **no
`-indices` and no `-stride`** option — only the options above.

```tcl
catch {lsort -indices {c a b}} m; set m
;# => bad option "-indices": must be --, ---, -ascii, -command, -decreasing,
;#    -dictionary, -increasing, -index, -integer, -nocase, -random, -real, or -unique
```

## `lassign` — (Tcl 8.5+; present in Eagle)

`lassign list varName ?varName ...?` — assign successive elements to the
variables; **returns the leftover** elements. Extra variables get the empty
string.

```tcl
lassign {a b c d e} x y z   ;# => d e   (returns leftovers; x=a y=b z=c)
set rest [lassign {a b c d e} p q]
set rest                    ;# => c d e
lassign {1 2} m n o         ;# => (empty); m=1 n=2 o="" (extra var emptied)
```

## `lrepeat` — (Tcl 8.5+; present in Eagle)

`lrepeat count value ?value ...?` — a list of *value*(s) repeated *count* times.

```tcl
lrepeat 3 a       ;# => a a a
lrepeat 2 x y z   ;# => x y z x y z
```

**Differs from Tcl 8.6:** a count of `0` is an **error** in Eagle (same as Tcl
**8.5**); Tcl 8.6 relaxed it to return an empty list.

```tcl
catch {lrepeat 0 a} m; set m   ;# => must have a count of at least 1
                               ;# Tcl 8.5.9: same error.  Tcl 8.6.18: "" (no error)
```

## `lreverse` — (Tcl 8.5+; present in Eagle)

`lreverse list` — the list reversed.

```tcl
lreverse {a b c d}   ;# => d c b a
lreverse {1 2 3}     ;# => 3 2 1
lreverse {}          ;# => (empty string)
```

## `lmap` — (Tcl 8.6+; present in Eagle)

`lmap varList list ?varList list ...? script` — like `foreach`, but **collects**
the result of each iteration into a new list. Supports multiple variables per
list and multiple parallel lists. Use `continue` to drop an element (a filter)
and `break` to stop early.

```tcl
lmap x {1 2 3 4} {expr {$x * 2}}                 ;# => 2 4 6 8
lmap x {-1 2 -3 4} {if {$x < 0} continue; set x} ;# => 2 4   (continue filters)
lmap {a b} {1 2 3 4} {expr {$a + $b}}            ;# => 3 7   (two vars per iteration)
lmap a {1 2 3} b {10 20 30} {expr {$a + $b}}     ;# => 11 22 33   (parallel lists)
```

## `lget` — Eagle extension (no Tcl equivalent)

`lget varName ?index ...?` — read an element from the list stored in a
**variable** (it takes a variable *name*, like `lset`, not a value like
`lindex`); combines `set` + `lindex` with nested-descent indices. No index
returns the whole list.

```tcl
set data {a {c d} e}
lget data 1 0     ;# => c        (descend to element 1, then 0)
set m {a b {c d e}}
lget m 0          ;# => a
lget m end        ;# => c d e
```

## `concat`

`concat ?arg ...?` — merge arguments into one list, **trimming** leading/
trailing whitespace from each and joining with a single space. Primarily for
merging lists (for plain string joining use `append` or quotes).

```tcl
concat {a b} {c d}      ;# => a b c d
concat a {b c} d        ;# => a b c d
concat "  a  " "  b  "  ;# => a b   (whitespace trimmed)
```

## `join`

`join list ?joinString?` — concatenate the **top-level** elements of *list* into
a string separated by *joinString* (default: a single space).

```tcl
join {a b c}             ;# => a b c
join {a b c} {, }        ;# => a, b, c
join {a b c} {}          ;# => abc
join {1 2 3} -           ;# => 1-2-3
join {{a b} {c d}} -     ;# => a b-c d   (only top-level elements are joined)
```

## `split`

`split string ?splitChars?` — split *string* into a list. Default *splitChars*
is whitespace; an **empty** *splitChars* splits into individual characters; each
character of *splitChars* is its own separator.

```tcl
split {a b c}        ;# => a b c
split a,b,c ,        ;# => a b c
split abc {}         ;# => a b c   (empty splitChars = per character)
split a.b,c .,       ;# => a b c   (multiple separator characters)
```

**Empty fields are preserved** (consecutive/edge separators produce empty
elements) — identical to Tcl 8.4/8.5/8.6, not collapsed:

```tcl
split a::b :         ;# => a {} b
split {a  b}         ;# => a {} b   (two spaces -> empty middle element; llength 3)
```
