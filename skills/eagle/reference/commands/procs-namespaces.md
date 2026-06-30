# Commands: Procedures & Namespaces

`proc` · `apply` · `nproc` · `napply` · `rename` · `uplevel` · `downlevel` ·
`namespace` · `scope`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
Loop/branch control commands are in [`control-flow.md`](control-flow.md); the
deep-dives are [`../../../../namespace.md`](../../../../namespace.md) and
[`../../../../scope.md`](../../../../scope.md).

> Eagle adds four commands with **no Tcl equivalent** — `nproc`, `napply`,
> `downlevel`, and `scope` (verified absent in Tcl 8.4/8.5/8.6:
> `info commands nproc` → empty in all three). `namespace` adds sub-commands
> too. Treat the named-argument calling convention and the namespace
> dual-implementation as the two big surprises.

---

## `proc`

`proc name args body` — defines a procedure; returns the empty string.

- `args` is a list of formal parameters: bare names are required; `{name
  default}` gives a default; a trailing `args` collects the rest as a list.
- The body may carry annotations (`#<<fast>>`, `<<private>>`, `<<atomic>>`,
  `<<inline>>`) on their own comment lines; they tune execution, not results.

```tcl
proc greet {name} {return "Hello, $name!"}
greet World                              ;# => Hello, World!

proc sum {args} {set t 0; foreach n $args {incr t $n}; return $t}
sum 1 2 3 4                              ;# => 10

proc f {a {b 9} args} {return "$a/$b/$args"}
f 1                                      ;# => 1/9/      (b defaulted, args empty)
f 1 2 3 4                                ;# => 1/2/3 4   (args collects 3 4)
```

A `#<<fast>>` annotation line is accepted and the proc still runs normally:

```tcl
proc dbl {x} {#<<fast>>
return [expr {$x * 2}]}
dbl 21                                   ;# => 42
```

## `apply`

`apply lambdaExpr ?arg ...?` — applies an anonymous procedure (lambda).

- A lambda is a 2- or 3-element list: `{args body}` or `{args body namespace}`.
  The optional **third element** is the namespace the body runs in — it is part
  of the lambda, **not** a trailing argument.

```tcl
apply {{x y} {expr {$x + $y}}} 3 4       ;# => 7
set double {{x} {expr {$x * 2}}}
apply $double 5                          ;# => 10
apply {{a {b 10}} {expr {$a + $b}}} 5    ;# => 15   (default arg)
```

Namespace context as the lambda's third element:

```tcl
namespace eval myns {variable counter 5}
apply {{} {variable counter; incr counter} ::myns}   ;# => 6
```

> The namespace goes **inside** the lambda list. Passing it as an extra argument
> (`apply {{} {...}} {} ::myns`) fails:
> `wrong # args: should be "apply lambdaExpr "`.

## `nproc` — Eagle extension (named-argument `proc`)

`nproc name args body` — like `proc`, but the resulting procedure takes its
arguments **by name** instead of by position.

- Call it as `name argName value argName value ...` using the **bare** formal
  names — **no leading dash**. Pairs may appear in any order. Defaults from the
  `{name default}` form fill in omitted names.
- An unknown name (when the proc has no `args` catch-all) errors:
  `procedure "..." unsupported argument named "..."`.
- Defined nprocs are tracked by `[info nprocs]`.

```tcl
nproc connect {host port timeout} {return "$host:$port/$timeout"}
connect host localhost port 8080 timeout 60   ;# => localhost:8080/60
connect timeout 60 host localhost port 8080   ;# => localhost:8080/60  (any order)

nproc c2 {host {port 80}} {return "$host:$port"}
c2 host localhost                             ;# => localhost:80  (port defaulted)

lsort [info nprocs]                            ;# => c2 connect  (names of defined nprocs)
```

## `napply` — Eagle extension (named-argument `apply`)

`napply lambdaExpr ?argName value ...?` — `apply` with by-name arguments, same
bare-name convention as `nproc`.

```tcl
napply {{x y} {expr {$x + $y}}} x 3 y 4   ;# => 7
```

## `rename`

`rename ?options? oldName newName` — renames an identifier; an **empty**
`newName` deletes it. Eagle's `rename` is option-bearing (Tcl's is not).

- Options: `-nodelete` (forbid the empty-newName delete), `-newnamevar var`
  (store the resulting name in `var`), `-kind <IdentifierKind>` (e.g.
  `Command`, `Function`, `Object`, `Variable`; unsafe), `-hidden`/`-hiddenonly`
  (unsafe), and `--` to end options.

```tcl
proc foo {} {return bar}
rename foo baz
baz                                      ;# => bar

rename baz {}                            ;# delete
catch {baz} m; set m                     ;# => invalid command name "baz"

proc foo {} {return bar}
catch {rename -nodelete foo {}} m; set m ;# => can't rename to <empty>: invalid name

rename -newnamevar nn foo qux; set nn    ;# => qux
```

## `uplevel`

`uplevel ?level? arg ?arg ...?` — runs a script in an enclosing call frame.

- `level` defaults to `1` (the immediate caller). A bare integer *n* means *n*
  frames up; `#n` is an **absolute** level (`#0` = global).

```tcl
proc setInCaller {n v} {uplevel 1 [list set $n $v]}
setInCaller x 42; set x                  ;# => 42

proc p {} {uplevel #0 {set g 99}}
p; set g                                 ;# => 99
```

## `downlevel` — Eagle extension (no Tcl equivalent)

`downlevel arg ?arg ...?` — runs a script back in the frame that was active
**before** the most recent `[uplevel]`. It lets code inside an upleveled script
hop back into the original (lower) context.

```tcl
proc deepdown {} {
  lappend a 1                ;# deepdown's frame (level 1)
  uplevel 1 {
    lappend a 2              ;# caller's frame (level 0)
    downlevel {
      lappend a 3            ;# back in deepdown's frame
      uplevel #0 {
        lappend a 4          ;# global frame
        downlevel { lappend a 5 }   ;# back in deepdown's frame
      }
    }
  }
  return $a
}
set a [list]
list [deepdown] $a           ;# => {1 3 5} {2 4}
                             ;# {1 3 5} = deepdown's local a; {2 4} = global a
```

## `namespace` — 22-sub-command ensemble

`namespace subcommand ?arg ...?`. The full sub-command set (an unknown name
echoes it verbatim):

```
children · code · current · delete · descendants · enable · eval · exists ·
export · forget · import · info · inscope · mappings · name · origin · parent ·
qualifiers · rename · tail · unknown · which
```

> **Dual implementation.** Eagle ships a compatibility stub (Namespace1) and a
> full implementation (Namespace2), toggled by `namespace enable`. In this build
> full namespaces are **enabled by default** — `namespace enable` returns
> `True`, and `current`/`children`/`descendants` reflect the real hierarchy
> without any opt-in. `namespace enable false` reverts to the stub (where
> `current` is always `::`, `children` of a script-made namespace errors as "not
> found", etc.). See [`../../../../namespace.md`](../../../../namespace.md) for the
> architecture.

> **No `namespace path`** (a Tcl 8.5 feature). It is not in the list above:
> `namespace path {}` → `bad option "path": must be children, code, current,
> delete, descendants, enable, eval, exists, export, forget, import, info,
> inscope, mappings, name, origin, parent, qualifiers, rename, tail, unknown, or
> which`. Use `namespace import` instead.

> **`namespace exists` returns `1`/`0`**, not `True`/`False` (same as
> `info exists`). Note `scope exists` differs — it returns `True`/`False`.

### Common sub-commands (Tcl-compatible)

```tcl
namespace eval mylib {proc greet {n} {return "Hi $n"}}
mylib::greet World                       ;# => Hi World

namespace eval myns {namespace current}  ;# => ::myns   (real, not stub ::)
namespace current                        ;# => ::

namespace eval parent {namespace eval child1 {}; namespace eval child2 {}}
namespace children ::parent              ;# => ::parent::child1 ::parent::child2
namespace children ::parent ::parent::child1*   ;# => ::parent::child1  (glob)

namespace eval a::b::c {}
namespace parent ::a::b::c               ;# => ::a::b
namespace parent ::                      ;# => (empty — global has no parent)

namespace qualifiers ::foo::bar::baz     ;# => ::foo::bar
namespace tail ::foo::bar::baz           ;# => baz

namespace eval mylib {}
namespace exists ::mylib                 ;# => 1
namespace exists ::nope                  ;# => 0

namespace eval temp {proc h {} {return t}}
namespace delete temp
namespace exists temp                    ;# => 0

namespace which -command puts            ;# => ::puts
namespace which -variable tcl_platform   ;# => ::tcl_platform
namespace which -command nosuchcmd       ;# => (empty string)
```

Export / import / origin / forget:

```tcl
namespace eval m {namespace export add; proc add {a b} {expr {$a + $b}}}
namespace import m::*
add 3 4                                  ;# => 7
namespace origin add                     ;# => ::m::add   (traces the import)
namespace forget m::*
catch {add 3 4} r; set r                 ;# => invalid command name "add"
```

Callback that remembers its namespace (`namespace code`) and `inscope`:

```tcl
namespace eval myns {
  variable d secret
  proc show {} {variable d; return $d}
  set ::cb [namespace code show]
}
eval $::cb                               ;# => secret

namespace eval myns {proc showArgs {args} {return $args}}
namespace inscope ::myns showArgs a b c  ;# => a b c
```

### Eagle-only sub-commands

```tcl
# descendants — recursive; INCLUDES the named namespace itself
namespace eval a {namespace eval b {namespace eval c {}}}
namespace descendants ::a                ;# => ::a ::a::b ::a::b::c
namespace children ::a                   ;# => ::a::b   (direct children only)

# enable — query / toggle full namespaces; returns the resulting state
namespace enable                         ;# => True
namespace enable false                   ;# => False
namespace enable true                    ;# => True

# rename — rename a whole namespace (Tcl cannot)
namespace eval oldns {proc t {} {return hello}}
namespace rename ::oldns ::newns
newns::t                                 ;# => hello

# mappings — name-remap table; ::Eagle -> :: by default
namespace mappings                       ;# => ::Eagle ::

# name — qualify a name against the current namespace
namespace eval myns {namespace name myproc}   ;# => ::myns::myproc

# unknown — per-namespace unknown handler (Tcl has only a global one)
namespace eval myns {namespace unknown {apply {{cmd args} {return "unk:$cmd"}}}}
namespace eval myns {namespace unknown}  ;# => apply {{cmd args} {return "unk:$cmd"}}

# info — metadata dictionary for a namespace (abridged)
namespace eval mylib {}
namespace info ::mylib
;# => NormalizeName Ok Normalized ::mylib SplitName Ok Qualifiers {} Tail mylib
;#    Flags {Absolute, Global} ... INamespace mylib ParentINamespace <null> ...
```

## `scope` — Eagle-only (persistent named variable environments)

`scope subcommand ?arg ...?`. A scope is a **named call frame** whose variables
survive across calls — Tcl has no equivalent. 19 sub-commands (an unknown name
echoes them): `attach · close · create · current · destroy · detach · eval ·
exists · export · global · import · list · lock · open · set · unlock · unset ·
update · vars`. Full treatment in [`../../../../scope.md`](../../../../scope.md).

- Lifecycle: `create` → `open` (push onto the call stack) → use → `close` (pop)
  → `destroy`. `create` is **idempotent** unless `-strict`. Opening a scope
  raises `[info level]` by 1; a procedure return auto-closes scopes it opened.
- `create` options include `-open`, `-clone` (snapshot current vars), `-args`
  (copy the enclosing proc's args), `-procedure` (auto-name from the proc),
  `-global`, `-byref`, `-shared`, `-fast`, `-strict`.
- `scope set/unset/vars` read or write a scope **without** opening it.

The canonical persistent-counter pattern:

```tcl
proc counter {name} {
  scope create -open -clone -args $name
  if {![info exists count]} {set count 0}
  incr count
  return $count   ;# scope auto-closes on return; vars persist
}
counter c                                ;# => 1
counter c                                ;# => 2
counter c                                ;# => 3
scope destroy c
```

Evaluate / inspect without opening; existence and listing:

```tcl
scope create config
scope eval config {set db prod; set timeout 30}
scope set config db                      ;# => prod
lsort [scope vars config]                ;# => db timeout

scope create foo
scope exists foo                         ;# => True
scope exists bar                         ;# => False
lsort [scope list]                       ;# => config foo  (all scope names)
scope current                            ;# => (empty — no scope currently open)
```

`info level` tracks open/close; scopes survive an error in the proc that made
them:

```tcl
info level                               ;# => 0
scope create -open lf; info level        ;# => 1
scope close;          info level         ;# => 0
scope destroy lf

proc mayFail {n} {scope create -open -clone $n; error oops}
catch {mayFail t}
scope exists t                           ;# => True   (survives the error)
scope destroy t
```

Thread-safe access via `scope eval -lock`, and global-frame redirection
(sandboxing) via `scope global`:

```tcl
scope create s; scope eval s {set n 0}
scope eval -lock true s {incr n}
scope set s n                            ;# => 1

scope create sandbox
scope eval sandbox {set x 100}
scope global sandbox                     ;# redirect the global frame
set ::x                                  ;# => 100   (reads sandbox's x)
scope global -unset                      ;# restore the real global frame
scope destroy sandbox
```

Scope↔namespace bridge (`attach` shares a variable; `export` moves it):

```tcl
scope create st
scope set st counter 7
namespace eval myns {}
scope attach st ::myns                    ;# => counter   (attached var names)
namespace eval ::myns {variable counter; set counter}   ;# => 7
```
