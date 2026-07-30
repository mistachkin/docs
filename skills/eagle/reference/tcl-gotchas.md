# Eagle vs Tcl — verified differences (and non-differences)

Eagle is **Tcl-compatible, not Tcl-identical**, and it targets the **Tcl 8.4**
language baseline (with selected 8.5/8.6 features added). Every item below was
**confirmed by execution** with the bundled harness (`../scripts/eval-eagle.sh`
and `../scripts/tcl-oracle.sh` across Tcl 8.4/8.5/8.6) — see
[`verification.md`](verification.md). When in doubt, re-run it.

Notation: `EAGLE` = Eagle result; `8.4 / 8.5 / 8.6` = native Tcl results.

---

## Real differences to watch for

### 1. Boolean results are `True` / `False`, not `1` / `0` (by design)

```
expr {1 < 2}                  EAGLE: True     8.4/8.5/8.6: 1
expr {"a" eq "a"}             EAGLE: True     8.4/8.5/8.6: 1
string is digit -strict 5     EAGLE: True     8.4/8.5/8.6: 1
```

This is **deliberate and generally superior**: returning `True`/`False` keeps
callers from assuming a boolean is the *literal string* `"0"` or `"1"`. In every
context that treats a value as a boolean/number, `True`/`False` behave exactly
like `1`/`0` — verified:

```
expr {(1<2)+(3>4)}            EAGLE: 1        (True=1, False=0 in arithmetic)
lindex {a b c} [expr {0<1}]   EAGLE: b        (True works as the index 1)
if {[string is digit 5]} ...                  (works: True is a valid boolean)
```

The **only** thing that differs is **string identity**:

```
expr {[string is digit 5] eq "1"}   EAGLE: False    8.4/8.5/8.6: 1   # <-- the bite
```

**Rule:** never string-compare an `[expr]` / `[string is]` result to `"1"`/`"0"`.
Use it directly as a condition. If you truly need the literal `1`/`0`, force it:

```
expr {[string is digit 5] ? 1 : 0}   -> 1
expr {(1 < 2) + 0}                    -> 1     ( !! does NOT work: stays True )
```

### 2. `[exec]` does not raise on a non-zero exit code (by default)

```
catch {exec false} m     EAGLE: 0   (no error)   8.4/8.5/8.6: 1  "child process exited abnormally"
```

Eagle treats the run as successful unless you say otherwise. To get Tcl-like
"error on failure", pass **`-success Success`**; capture the outcome with
**`-exitcode <var>`** (it yields an `ExitCode` enum value, e.g. `Success` /
`Failure`, not a raw integer):

```
catch {exec -success Success false} m   EAGLE: 1  "child process exited abnormally"
catch {exec -exitcode ec false};  set ec EAGLE: Failure
```

Also note Eagle's `[exec]` **builds the child command line differently** from Tcl
(it assembles one command-line string; there is no Tcl pipeline/redirection
grammar). Constructs like `exec sh -c {exit 3}` do **not** pass through the way
Tcl programmers expect — prefer direct argv (`exec false`, `exec echo hi`) and
see [`../../../exec.md`](../../../exec.md) for the quoting/escaping rules and the full
option set (`-stdout`/`-stderr`/`-exitcode`/`-success`/`-timeout`/...).

### 3. No `{*}` argument expansion

```
list {*}[list a b] c     EAGLE: error "extra characters after close-brace"   8.5/8.6: a b c   (8.4: error)
```

Eagle follows the 8.4 baseline (no `{*}`). Expand a list into arguments with
`[eval]` + `[list]`:

```
proc f {a b c} {return $a-$b-$c}
set args {1 2 3}
eval f $args             EAGLE: 1-2-3        # Tcl 8.5+ would write:  f {*}$args
```

### 4. `[fileevent]` is available; `[chan event]` is not

```
info commands fileevent  EAGLE: fileevent    8.4/8.5/8.6: fileevent
info commands chan       EAGLE: (empty)      8.4: (empty); 8.5/8.6: chan
```

Use `[fileevent $channel readable|writable ?script?]` for socket and seekable
file channels. Eagle adds `-priority EventPriority` when installing a non-empty
handler. It does not expose the Tcl 8.5+ `[chan event]` spelling.

### 5. No `namespace path`

```
namespace path {}        EAGLE: bad option "path": must be children, code, current, delete,
                                descendants, enable, eval, exists, export, forget, import,
                                info, inscope, mappings, name, origin, parent, qualifiers,
                                rename, tail, unknown, or which
                         8.5/8.6: (ok)       8.4: also unsupported
```

Note Eagle *adds* namespace sub-commands 8.4 lacks (`descendants`, `enable`,
`mappings`, `rename`, `unknown`) — it just doesn't implement 8.5's `path`.

### 6. No automatic promotion to big integers

```
expr {9223372036854775807 + 1}   EAGLE: -9223372036854775808   8.5/8.6: 9223372036854775808   (8.4: wraps)
```

Integer math is 64-bit and **wraps** on overflow (like 8.4); Eagle does not
silently widen to arbitrary precision. This is intentional — be explicit
(`wide(...)`, `entier(...)`, or a `System.Numerics.BigInteger` via `[object]`)
when you need big values.

### 7. `[incr]` and `[dict set]` do not auto-create a missing variable

```
incr noVar               EAGLE: can't read "noVar": no such variable   (8.4: same;  8.5/8.6: 1)
dict set noVar k v        EAGLE: variable not found in call frame        (8.5/8.6 auto-create -> "k v")
```

But `[append]` and `[lappend]` **do** auto-create (in Eagle and Tcl):

```
append noVar x   -> x        lappend noVar a   -> a
```

Deliberate anti-footgun for `incr`/`dict set`. Initialize first:
`set d [dict create]; dict set d k v` → `k v`.

### 8. No `link` file type; a dangling symlink reads as a `file`

```
exec ln -s /no/such/target /tmp/dangling
file exists /tmp/dangling        EAGLE: True    8.5/8.6: 0       (Tcl follows the link)
file type /tmp/dangling          EAGLE: file    8.5/8.6: link
file isfile /tmp/dangling         EAGLE: True    8.5/8.6: 0
file isdirectory /tmp/dangling    EAGLE: False   8.5/8.6: 0
```

Eagle has **no `link` file type** — an entry is either a directory or a file. A symlink is
reported as its *target's* type, and a **dangling** symlink (target missing) falls back to
`file`: so `exists`, `type`, and `isfile` all say file / `True`, and only `isdirectory`
returns `False` (it genuinely is not a directory). Tcl instead has a distinct `link` type
and treats a dangling link as nonexistent (`exists` / `isfile` / `isdirectory` all `0`).
Consequence: across a possible symlink, **`[file isdirectory]` is the reliable
discriminator** ("does this resolve to a directory?"); `exists` / `isfile` / `type` will
not distinguish a dangling (or any) link from a real file. Guard on the predicate your next
step depends on, not on mere presence.

### 9. Namespace support is toggleable — default varies, qualify your globals

```
namespace enable      EAGLE: build-dependent (False here, True on CI)   Tcl: no such sub-command (always on)
```

Unlike Tcl (always-on namespaces, no way to disable), Eagle runs namespaces
**disabled** — a compatibility stub where `namespace eval` is ~a no-op, so procs/vars
land **global** and unqualified names resolve globally — or **enabled** (real scoping),
toggled per interpreter with `namespace enable ?enabled? ?force?`. **The default is
build-dependent** (verified `False` on a netcoreapp2.0 build, `True` on the build this
skill was first checked and on CI), so query it, don't assume. The runtime bite: when
**enabled**, an unqualified name inside `namespace eval` is namespace-relative, so a
global needs `$::name` (or `[global name]`) — `namespace eval ::X { run $argv }` works
only while disabled; write `run $::argv`. Toggling is non-destructive; Eagle also adds
`descendants`/`mappings`/`rename`/`name` sub-commands Tcl lacks. Full treatment:
[`commands/procs-namespaces.md`](commands/procs-namespaces.md).

---

## Looks like a gotcha, but ISN'T (Eagle matches Tcl — do not "fix")

The harness disproves several widely-assumed "differences". Confirmed identical
to Tcl:

| Behavior | Result (Eagle == Tcl 8.4/8.5/8.6) |
|----------|-----------------------------------|
| `regexp -inline {.+} "a\nb"` | `{a\nb}` — `.` **matches** newline by default (Eagle's `Singleline` default = Tcl; opposite of *.NET's* default). Use `-linestop`/`-line` to change, in both. |
| `expr {-7/2}` | `-4` — integer division **floors** (Tcl semantics, not .NET truncation) |
| `expr {7 % -3}` | `-2` — modulo takes the sign of the divisor (Tcl, not .NET) |
| `expr {int(-2.9)}` | `-2` — `int()` truncates toward zero |
| `lsort {B a C b A c}` | `A B C a b c` — default ASCII sort; `-dict` works too |
| `string trim {  hi  }` | `hi`; `string index abc end` → `c`; `clock format 0 -gmt 1 ...` matches |

Don't assume a difference because Eagle runs on .NET — verify first.

---

## "Based on 8.4" does NOT mean 8.5/8.6 features are missing

Eagle selectively includes later-Tcl features. **Verified present** in Eagle even
though Tcl 8.4 lacks them:

`try` / `finally` / `throw`, `dict`, `lassign`, `lmap`, the `**` exponent
operator, the `in` / `ni` expr operators, the `bool()` math function,
`string reverse`, and more.

So assume nothing in *either* direction: some 8.5/8.6 things are present
(above), others are deliberately absent (`{*}`, `namespace path`, bignum
promotion, `incr`/`dict set` auto-create). The only reliable answer is to run it
— `eval-eagle.sh 'puts [info commands <name>]'` and a behavior check.
