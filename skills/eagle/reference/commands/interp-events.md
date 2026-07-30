# Commands: Interpreters & Events

`interp` · `alias` · `ensemble` · `eval` · `nop` · `update` · `vwait` ·
`after` · `fileevent` · `bgerror` · `tcl`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
The deep dives are [`../../../../interp.md`](../../../../interp.md) (child interpreters),
[`../../../../safe.md`](../../../../safe.md) (the safe-interp security model), and
[`../../../../tcl.md`](../../../../tcl.md) (native-Tcl bridge).

> Two recurring bites in this family, both verified below:
> 1. `interp` predicates (`exists`, `issafe`, `isstandard`, `isolated`, ...)
>    return **`True`/`False`**, not `1`/`0`. Use them as conditions; never
>    string-compare to `"1"` (gotcha #1).
> 2. Channel readiness uses `[fileevent]`; Eagle does not expose Tcl 8.5+'s
>    `[chan event]` spelling (gotcha #4). Also, `after idle` callbacks are
>    drained by **`vwait`**, not by
>    `update` — see [`update`](#update) / [`after`](#after).

---

## `interp`

`interp subcommand ?arg ...?` — manage child interpreters: create them, evaluate
code in them, sandbox them (`-safe`), wire cross-interpreter aliases, hide/expose
commands, and cap resources. It is a large ensemble (**60 sub-commands**,
authoritative list from [`../../../../tools/command_inventory.md`](../../../../tools/command_inventory.md)):

```
addcommands  alias  aliases  bgerror  callbacklimit  cancel  childlimit
children  create  delete  enabled  eval  eventlimit  execlimit  exists
expose  exposed  expr  finallytimeout  hide  hidden  immutable  invokehidden
isolated  issafe  issdk  isstandard  iterationlimit  makesafe  makestandard
marktrusted  maybereadorgetscriptfile  namespacelimit  nopolicy  parent
policy  proclimit  queue  readonly  readorgetscriptfile  readylimit
recursionlimit  rename  resetcancel  resultlimit  scopelimit  service  set
shareinterp  shareobject  sleeptime  source  stub  subcommand  subst  target
timeout  unset  varlimit  watchdog
```

For the resource-limit tail (`*limit`), the security configuration
(`policy`, `nopolicy`, `marktrusted`, `makesafe`, ...), and isolated-AppDomain
interpreters, see [`../../../../interp.md`](../../../../interp.md) and
[`../../../../safe.md`](../../../../safe.md).

### Tcl names that do NOT exist here

Eagle uses the modern Tcl 8.6 names `children`/`parent`, **not** `slaves`/`master`,
and it has neither Tcl 8.5's `interp limit` nor the channel-sharing
`interp share`/`interp transfer`:

```tcl
interp slaves    ;# => bad option "slaves": must be addcommands, alias, ... (no slaves)
interp master    ;# => bad option "master": ... (no master)
interp limit a b ;# => bad option "limit": ... (use recursionlimit/iterationlimit/...)
interp transfer  ;# => bad option "transfer": ... (no channel transfer)
```

`interp share` is *ambiguous* — it prefix-matches `shareinterp`/`shareobject`,
which share an **object or the interpreter itself** (not a channel):

```tcl
interp share a b c   ;# => ambiguous option "share": must be shareinterp or shareobject
```

### Lifecycle: create, exists, eval, delete

```tcl
interp create child            ;# => child   (a name; omit it and Eagle generates one)
interp exists child            ;# => True    (NOT 1 — boolean form)
interp issafe child            ;# => False
interp eval child {set x 7}
interp eval child {expr {$x*6}}        ;# => 42
interp delete child
interp exists child            ;# => False
```

The empty path `{}` denotes the current (this) interpreter:

```tcl
interp eval {} {expr {1+1}}    ;# => 2
```

`children` lists child interpreters; `parent` returns the parent's path. Note
Eagle gives the root interpreter a concrete name, so a direct child's `parent`
is that id (e.g. `1`) rather than Tcl's empty string; the root's own `parent`
is empty:

```tcl
interp create kid
interp children                ;# => kid
interp parent kid              ;# => 1     (the root's id; Tcl returns {} here)
interp parent                  ;# => {}    (root has no parent)
interp delete kid
```

### Safe interpreters (the sandbox)

`interp create -safe` hides every unsafe command — file I/O, `exec`, and the
whole `[object]` CLR bridge. Calling a hidden command from inside the sandbox is
**denied**, which is the whole point:

```tcl
set s [interp create -safe sandbox]
interp issafe $s                                 ;# => True
interp eval $s {info commands object}            ;# => (empty: not visible)
catch {interp eval $s {object create System.Object}} m
puts $m
;# => permission denied: safe interpreter cannot use command "object create"
interp delete $s
```

A fresh safe child starts with the unsafe commands *hidden* (here, 25 of them),
including `exec` and `object`:

```tcl
set s [interp create -safe]
llength [interp hidden $s]                        ;# => 25
expr {[lsearch [interp hidden $s] object] >= 0}   ;# => True
interp delete $s
```

### Hidden commands: hide / expose / hidden / exposed / invokehidden

These work on any child (not only safe ones). Hide removes a command from normal
lookup; `invokehidden` still reaches it; expose restores it:

```tcl
set c [interp create]
interp eval $c {proc foo {} {return FOO}}
interp hide $c foo
interp eval $c {info commands foo}    ;# => (empty)
interp hidden $c                      ;# => foo
interp invokehidden $c foo            ;# => FOO
interp expose $c foo
interp eval $c {foo}                  ;# => FOO
interp delete $c
```

### Aliases: alias / aliases / target

An alias is a command in one interpreter that invokes a command (with optional
prepended args) in another. Same-interpreter aliases use `{}` for both paths:

```tcl
interp alias {} ucase {} string toupper    ;# create
ucase abc                                   ;# => ABC
interp alias {} ucase                       ;# => string toupper   (query target)
interp alias {} ucase {}                    ;# delete (empty target)
```

The classic use is letting a *safe* child reach a controlled parent command. The
target path `{}` means "this (the parent) interpreter":

```tcl
set c [interp create]
interp alias $c up {} string toupper        ;# child 'up' -> parent 'string toupper'
interp eval $c {up abc}                      ;# => ABC
interp aliases $c up                         ;# => up        (pattern-filtered list)
interp target $c up                          ;# => {}        (target interp = parent)
interp delete $c
```

> A fresh non-safe child ships with several built-in aliases (`oc`, `oi`,
> `scalar`, `reader`, ...); filter `interp aliases` with a pattern to find yours.

### Cross-interpreter variables: set / unset / expr

```tcl
set c [interp create]
interp set $c myVar hello
interp set $c myVar                  ;# => hello
interp eval $c {set myVar}           ;# => hello
interp unset $c myVar
interp eval $c {info exists myVar}   ;# => 0
interp expr $c {2 + 3}               ;# => 5
interp delete $c
```

### Resource limits

Eagle exposes a separate sub-command per resource (no Tcl `interp limit`
aggregate). Each gets/sets a limit on the named interpreter:

```tcl
set c [interp create]
interp recursionlimit $c             ;# => 1000   (the default)
interp recursionlimit $c 100         ;# set max call depth
interp recursionlimit $c             ;# => 100
interp delete $c
```

Companions: `iterationlimit`, `proclimit`, `varlimit`, `namespacelimit`,
`scopelimit`, `resultlimit`, `callbacklimit`, `eventlimit`, `execlimit`,
`readylimit`, `childlimit`. Execution control lives in `timeout`,
`finallytimeout`, `sleeptime`, `cancel`, `resetcancel`, and `watchdog` — see
[`../../../../interp.md`](../../../../interp.md).

---

## `eval`

`eval arg ?arg ...?` — concatenate the args with spaces and evaluate the result
as a script; returns the last command's result. Because Eagle has **no `{*}`
expansion** (gotcha #3), `eval` + `[list]` is the portable way to splat a list
into a command:

```tcl
set cmd {string length}
eval $cmd [list hello]              ;# => 5

proc f {a b c} {return $a-$b-$c}
set args {1 2 3}
eval f $args                       ;# => 1-2-3   (Tcl 8.5+ would write: f {*}$args)
```

## `alias`

Not a standalone command. `alias` is the internal class behind the aliases you
create with [`interp alias`](#aliases-alias--aliases--target) (it has
`CommandFlags ... Alias`, so it never registers as a callable command itself).
Create, query, and delete aliases through `interp alias` as shown above.

## `ensemble`

Also internal — the machinery that groups sub-commands under one name (`string`,
`array`, `info`, `interp`, `object`, ...). It is not a script-level command, and
unlike Tcl 8.5+ **Eagle has no `namespace ensemble`** to build custom ensembles
from script:

```tcl
namespace ensemble create
;# => bad option "ensemble": must be children, code, current, delete,
;#    descendants, enable, eval, exists, ... which   (no 'ensemble')
```

You can still introspect ensembles and extend them programmatically:

```tcl
llength [info ensembles]                          ;# => 26
expr {[lsearch [info ensembles] string] >= 0}     ;# => True
info subcommands namespace
;# => children code current delete descendants enable eval exists export
;#    forget import info inscope mappings name origin parent qualifiers
;#    rename tail unknown which
```

To add a sub-command to an ensemble or create a minimal ensemble placeholder in
a child interpreter, use `interp subcommand` / `interp stub` (see
[`../../../../interp.md`](../../../../interp.md)).

## `nop`

`nop` — does nothing and returns the empty string; it deliberately leaves the
previous interpreter result untouched. Handy as a placeholder or for measuring
interpreter overhead:

```tcl
puts "[nop]<-empty"        ;# => <-empty
```

---

## The event loop: `after`, `update`, `vwait`

Eagle's event loop combines `after` (time scheduling), `fileevent` (channel
readiness), and `update`/`vwait` (pumping).

### `fileevent`

`fileevent ?-priority priority? channel readable|writable ?script?` queries,
installs, replaces, or removes a readiness handler. An omitted script queries;
an empty script removes; a non-empty script installs or replaces. Handlers are
level-triggered and rearm after successful execution. A handler error removes
that binding and follows the normal `bgerror` path.

```tcl
fileevent $sock readable {
  fileevent $::sock readable {}
  set ::reply [gets $::sock]
  set ::done true
}
vwait ::done
```

The Eagle-only `-priority` option applies when installing a non-empty handler
and defaults to `QueueScript`. Socket channels and seekable file channels are
supported; closing a channel cancels both bindings and stale queued callbacks.

### `after`

```tcl
after 200                              ;# synchronous sleep (~200 ms; blocks)

set id [after 60000 {puts later}]      ;# schedule script; returns an event id
puts $id                               ;# => after#1207
after info $id                         ;# => {puts later} timer
after cancel $id                       ;# cancel by id (or by the exact script)
after info                             ;# => (empty: nothing pending)
```

`after idle script` queues an *idle* callback. **Caveat (verified below):** in
Eagle these are serviced by `vwait`, not by `update`:

```tcl
set id [after idle {set z 1}]
after info $id                         ;# => {set z 1} idle
after cancel $id
```

Eagle adds queue-management sub-commands beyond Tcl: `after clear` cancels every
pending event (also `active`, `counts`, `dump`, `enable`, `flags`):

```tcl
after 99999 {nop}; after 88888 {nop}
llength [after info]                    ;# => 2
after clear
llength [after info]                    ;# => 0
```

### `update`

`update ?idletasks?` — process already-queued events, then return. A zero-delay
timer fires under a plain `update`:

```tcl
after 0 {set ::flag 1}
update
puts $::flag                           ;# => 1
```

> **`update` does not drain `after idle`.** Neither `update` nor
> `update idletasks` runs an idle callback in Eagle — only the real event loop
> (`vwait`) does. `after idle {set z 1}; update; set z` raises
> `can't read "z": no such variable`. Use `vwait` (below) to flush idle work.

### `vwait`

`vwait ?options? varName` — enter the event loop and block until `varName` is
written. This is how you wait for an async result:

```tcl
after 100 {set ::done ready}
vwait ::done
puts $::done                           ;# => ready
```

`vwait` *does* drain idle callbacks (unlike `update`):

```tcl
after idle {set ::z done}
vwait ::z                              ;# => z becomes "done"
```

If nothing pending could ever write the variable, `vwait` refuses up front
rather than hang forever:

```tcl
vwait neverset
;# => can't wait for variable "neverset": would wait forever
```

Eagle adds options including `-timeout ms`, `-nocomplain`, `-force`, `-limit`,
`-clear`, and `-locked script`. Note that `-timeout` only helps when the loop
has *something* to process — the "would wait forever" guard fires first
otherwise, even with `-nocomplain`. With a pending event, the wait times out and
`-nocomplain` reports the timeout as success (result `False`):

```tcl
after 5000 {set other 1}                          ;# keep the loop non-idle
set rc [catch {vwait -timeout 150 -nocomplain target} m]
puts "$rc / $m"                                    ;# => 0 / False  (timed out, no error)
after clear
```

See [`options.md`](../../../../options.md#vwait) (per-option semantics) for the full
set.

---

## `bgerror`

When a script run from the event loop (an `after` callback, a queued event)
raises an error, Eagle reports it through a **background error handler**. Define
a `bgerror` proc to catch and handle it; under `vwait`, the handler runs and the
loop keeps going:

```tcl
proc bgerror {msg} {puts "bg-handler: $msg"}
after 0  {error boom}                  ;# this callback will fail
after 50 {set ::ok 1}                  ;# ... the loop continues to this one
vwait ::ok
;# => bg-handler: boom
;#    (then ::ok becomes 1 and vwait returns normally)
```

`$::errorInfo` inside `bgerror` holds the stack trace. With **no** custom
`bgerror`, the default handler prints the error to stderr. Note a subtlety:
draining the same failing callback with `update` (instead of `vwait`) still
*calls* `bgerror`, but the error also propagates out of `update` (it returns a
non-zero completion code) — prefer `vwait` for robust background-error handling.

---

## `tcl` — native Tcl bridge

`tcl subcommand ?arg ...?` is Eagle's bridge to a **native** Tcl runtime
(load a real `libtcl`/`tclXX.dll`, create Tcl interpreters, eval Tcl, exchange
variables, bridge commands). It is a 37-sub-command ensemble and is itself
always present:

```tcl
info commands tcl                      ;# => tcl
tcl ready                              ;# => False   (no native Tcl loaded yet)
```

Actually using it requires `tcl load` to locate a compatible native Tcl shared
library — via env vars (`Tcl_Dll`, `Tcl_Dir`, ...) or the auto-path. **It may be
unavailable**: where no matching library is found, `tcl load` fails and the rest
of the ensemble cannot run. On the machine used to verify this skill, no library
was locatable:

```tcl
tcl load
;# => ... no Tcl library files found via environment variables
;#    "Eagle_Tcl_Dir", "Eagle_Tcl_Dll", ... or "Tcl_Dll" ...
```

Once `tcl load` succeeds, the normal flow is `tcl create` → `tcl eval` /
`tcl expr` / `tcl set` → `tcl delete` → `tcl unload`, plus `tcl command` to
bridge commands between the two runtimes. For the full sub-command set, library
discovery, threading model, and the Garuda reverse direction, see
[`../../../../tcl.md`](../../../../tcl.md).
