# Safe Interpreters & Sandboxing

How to run **untrusted Eagle code** with controlled, deny-by-default access
to the host. A child interpreter created with `interp create -safe` is a real
security boundary, not a convention.

All examples below were **executed** against Eagle 1.0 (see
[`verification.md`](verification.md)); `;# =>` shows the verified result. For
the event/cancellation side of `[interp]` (queue, cancel, service, timeouts)
see [`commands/interp-events.md`](commands/interp-events.md). The authoritative
deep-dive on the security model is [`../../../safe.md`](../../../safe.md); the full
`[interp]` reference is [`../../../interp.md`](../../../interp.md).

> Reminder: a denied operation **raises an error** (completion code `1`). The
> examples wrap the call so `;# =>` shows the raised message; in real code you
> catch it with `[catch]` (see [`commands/control-flow.md`](commands/control-flow.md)).

---

## The five-layer model

A safe interpreter stacks five independent layers; an escape must defeat *all*
of them. Concise version (full treatment in [`../../../safe.md`](../../../safe.md)):

1. **Command hiding** — at `-safe` creation, every command lacking the
   `CommandFlags.Safe` attribute is moved to a hidden table. Script in the
   child cannot see, name, or call it. (`exec`, `socket`, `open`, `load`, …)
2. **Option-flag enforcement** — even on a *safe* command, individual options
   tagged `OptionFlags.Unsafe` are rejected at parse time.
3. **Sub-command allow-lists** — partially-safe ensembles (`file`, `info`,
   `clock`, `object`, `interp`, `package`, `source`, `uri`) are themselves
   hidden, but a policy re-permits a fixed set of sub-commands. `file dirname`
   is allowed; `file delete` is not.
4. **Policy callbacks** — a deny-by-default voting system fires before each
   hidden command/sub-command. *Any* denial wins; no vote means denied. This is
   also where `object` type-access and `uri`/`source` target checks live, and
   where you install custom rules ([`../../../safe.md`](../../../safe.md)).
5. **Resource limits** — hard caps on recursion, loop iterations, operations,
   variables, etc., plus execution timeouts/watchdog, prevent denial-of-service.

The parent stays in full control: only an **unsafe** parent may hide/expose
commands, install policies, set limits, or share objects — a safe interpreter
**cannot** modify its own security posture.

---

## Creating a sandbox

`interp create ?options? ?path?` — `-safe` is the flag that builds the sandbox.

```tcl
interp create -safe sandbox      ;# => sandbox   (the new child's path)
interp issafe sandbox            ;# => True
interp issafe                    ;# => False     (the parent is not safe)
```

Omit the name and Eagle assigns one (a number). `interp issafe` is one of the
few `[interp]` sub-commands a sandbox may call on itself.

---

## What is denied (layer 1: command hiding)

The dangerous primitives are gone. Each call below runs *inside* the sandbox
and raises a permission error:

```tcl
interp eval sandbox {object create System.Object}
;# => permission denied: safe interpreter cannot use command "object create"
interp eval sandbox {exec ls}
;# => permission denied: safe interpreter cannot use command "exec"
interp eval sandbox {open /etc/passwd}
;# => permission denied: safe interpreter cannot use command "open"
interp eval sandbox {socket localhost 80}
;# => permission denied: safe interpreter cannot use command "socket"
interp eval sandbox {file delete /tmp/x}
;# => permission denied: safe interpreter cannot use command "file delete"
```

> The message is **`permission denied: safe interpreter cannot use command "…"`** —
> not "invalid command name." Eagle keeps the command present-but-blocked so the
> error is diagnosable, and the failing sub-command (`object create`,
> `file delete`) is named.

---

## What is available

The whole computational core works — variables, math, strings, lists, dicts,
control flow, procedures:

```tcl
interp eval sandbox {set x 42}              ;# => 42
interp eval sandbox {expr {2 ** 10}}        ;# => 1024
interp eval sandbox {string toupper hello}  ;# => HELLO
interp eval sandbox {lsort {c a b}}         ;# => a b c
interp eval sandbox {dict get {a 1 b 2} b}  ;# => 2
```

## Sub-command allow-lists (layer 3)

`file` is hidden, but a policy re-permits its pure path-manipulation
sub-commands while still blocking anything that touches the filesystem:

```tcl
interp eval sandbox {file dirname /a/b/c.txt}  ;# => /a/b
interp eval sandbox {file join a b c}          ;# => a/b/c
interp eval sandbox {file exists /etc/passwd}
;# => permission denied: safe interpreter cannot use command "file exists"
```

`object` shows layers 3 and 4 stacked: the `invoke` *sub-command* is on the
allow-list, but the requested .NET *type* is untrusted, so the type policy
denies it:

```tcl
interp eval sandbox {object invoke System.Math Max 3 7}
;# => permission denied: safe interpreter cannot use type from "System.Math"
```

That is the right escape hatch to grant deliberately (mark a specific object
safe and share it from the parent) — never by exposing `object` wholesale.

---

## Delegating capability with aliases

The clean way to give a sandbox *exactly one* extra power is an alias: a command
in the child that runs a procedure in the **parent**. The parent validates the
arguments and decides what the capability is.

```tcl
# In the parent:
proc hostUpper {s} {return [string toupper $s]}
interp alias sandbox up {} hostUpper

interp eval sandbox {up {hi from the sandbox}}  ;# => HI FROM THE SANDBOX
interp alias sandbox up                         ;# => hostUpper   (query the target)
```

`interp alias child childCmd {} parentCmd ?arg…?` creates it; the same call with
just `childCmd` queries it; an empty target deletes it. The target executes with
the parent's privileges, so **the parent must validate everything the child
passes** (e.g. confirm a path is under an allowed directory before opening it).
See [`../../../safe.md`](../../../safe.md) for the capability-delegation patterns.

---

## Resource limits (layer 5)

A sandbox gets default caps; tighten them for untrusted work. Limits are
per-resource sub-commands (Eagle has **no** Tcl 8.6 `interp limit` command).

```tcl
interp recursionlimit box        ;# => 1000   (safe-interp default)
interp recursionlimit box 20
interp eval box {proc rec {n} {if {$n <= 0} {return done}; rec [expr {$n - 1}]}}
interp eval box {rec 100}
;# => too many nested evaluations (infinite loop?)
```

Loop iterations are capped at 1000 by default in a safe interpreter, so a
runaway loop terminates on its own:

```tcl
interp iterationlimit box        ;# => iteration 1000
interp eval box {set i 0; while {1} {incr i}}
;# => iteration limit 1000 exceeded
```

`execlimit` caps total operations / command invocations / unknown lookups; its
getter reports all three:

```tcl
interp execlimit box
;# => operationLimit 200000 commandLimit 100000 unknownLimit 1000
```

The Tcl-8.6 spelling is rejected — Eagle lists the real sub-commands instead:

```tcl
interp limit box command -value 100
;# => bad option "limit": must be addcommands, alias, aliases, bgerror,
;#    callbacklimit, cancel, childlimit, children, create, delete, enabled,
;#    eval, ... recursionlimit, ... varlimit, or watchdog
```

Other knobs: `varlimit`, `proclimit`, `namespacelimit`, `scopelimit`,
`callbacklimit`, `eventlimit`, `resultlimit`, `childlimit`, and the
wall-clock `timeout`/`finallytimeout`/`watchdog` trio
([`commands/interp-events.md`](commands/interp-events.md),
[`../../../interp.md`](../../../interp.md)).

---

## Hidden commands (administering layer 1)

`interp hidden` lists what is locked away. These 25 commands are hidden in a
fresh safe interpreter:

```tcl
lsort [interp hidden vault]
;# => cd clock debug exec file glob host info interp kill library load object
;#    open package pid pwd socket source sql tcl unload uri version xml
```

(The ensembles in that list — `file`, `clock`, `info`, `object`, `interp`,
`package`, `source`, `uri` — are the partially-safe ones: hidden, but with
allow-listed sub-commands re-permitted by policy, per layer 3.)

A script in the sandbox cannot reach a hidden command, but the parent can
invoke it **privileged** with `interp invokehidden` — this bypasses the policy
layer entirely, so it is how a host runs trusted setup or one-off operations:

```tcl
interp eval vault {pwd}
;# => permission denied: safe interpreter cannot use command "pwd"
expr {[interp invokehidden vault pwd] eq [pwd]}        ;# => True
interp invokehidden vault file exists /etc/hosts       ;# => 1   (policy bypassed)
```

Crucially, the sandbox **cannot expose or hide its own commands** — that is a
hard `InternalIsSafe()` guard, not a policy:

```tcl
interp eval vault {interp expose {} pwd}
;# => permission denied: safe interpreter cannot use command "interp expose"
```

Only the unsafe **parent** can change visibility. `interp expose` lifts a
command into the sandbox; `interp hide` puts it back:

```tcl
interp expose vault pwd
expr {[interp eval vault {pwd}] eq [pwd]}   ;# => True   (now permitted)
interp hide vault pwd
interp eval vault {pwd}
;# => permission denied: safe interpreter cannot use command "pwd"
```

---

## How to sandbox untrusted code

Putting the layers together, the host-side recipe is:

1. **Create safe**: `set s [interp create -safe]`. Prefer creating safe over
   `interp makesafe` on an existing interpreter.
2. **Cap resources**: set `recursionlimit`, `iterationlimit`, `execlimit`,
   `varlimit`, and a `timeout` + `watchdog` for wall-clock runaways.
3. **Delegate, don't expose**: hand over capability through narrow
   `interp alias` targets that validate their arguments in the parent. Avoid
   `interp expose`/`shareobject` unless you have audited exactly what leaks.
4. **Initialize privileged, run untrusted**: use `interp invokehidden` for
   trusted bootstrap, then `interp eval $s $untrustedScript` inside a `[catch]`.
5. **Tear down**: `interp delete $s` (cascades to any children).

```tcl
set s [interp create -safe]
interp recursionlimit $s 100
interp iterationlimit $s 100000
interp alias $s log {} app::sandboxLog        ;# the only capability granted
if {[catch {interp eval $s $untrustedScript} err]} {
    puts "sandbox error: $err"
}
interp delete $s
```

The guarantees this provides — no filesystem, network, process, reflection, or
host access; no child interpreters; bounded resources; no information
disclosure — and the full policy/rule-set machinery for custom access control
are covered in [`../../../safe.md`](../../../safe.md) and
[`../../../interp.md`](../../../interp.md).
