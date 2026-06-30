# Commands: .NET Objects & Interop

`object` · `getf` · `setf` · `unsetf` · `delegate` · `callback` · `library` ·
`load` · `unload` · `stub` · `invoke`

All examples below were **executed** against Eagle 1.0 (`info patchlevel`
`8.4.21`; see [`../verification.md`](../verification.md)); `;# =>` shows the
verified result. Cross-cutting Tcl differences live in
[`../tcl-gotchas.md`](../tcl-gotchas.md). The `[object]` deep tail (assemblies,
certificates, remote activation, the full option/flag matrices) is in
[`../../../../object.md`](../../../../object.md); native FFI in
[`../../../../library.md`](../../../../library.md); plugin loading in
[`../../../../load.md`](../../../../load.md).

> .NET interop is **Eagle's signature feature** — there is no Tcl equivalent.
> Three things bite newcomers, all verified below:
> 1. `[object]` (and `[library]`, `[load]`) are **not available in safe
>    interpreters** by default — `interp create -safe` strips them.
> 2. Object handles are **opaque strings**; you manage their lifecycle
>    (`-alias`, `[object dispose]`, reference counts). They are NOT garbage
>    objects you can ignore.
> 3. Predicate sub-commands return **`True`/`False`** (gotcha #1), and many
>    sub-commands **wrap return values as new handles** unless you ask for a
>    string (`-tostring`).

---

## `object` — the .NET bridge (43 sub-commands)

`object subcommand ?arg ...?`. The complete authoritative sub-command set
(from `tools/command_inventory.md`, generated from the C# source):

```
addreference  alias       aliasnamespaces  assemblies  callbackflags
certificate   cleanup     create           declare     dispose
exists        flags       foreach          fromvar     get
hash          import      interfaces       invoke      invokeall
invokeraw     isdisposed  isnull           isoftype    list
lmap          load        members          namespaces  referencecount
removecallback removereference resolve      search      strongname
type          types       unalias          unaliasnamespace  undeclare
unimport      untype      verifyall
```

The everyday workflow uses maybe a dozen of these; the rest are covered in
[`../../../../object.md`](../../../../object.md). The verified core follows.

### Create → use → dispose

`object create ?options? typeName ?arg ...?` resolves a .NET type, picks a
constructor, marshals the arguments, and returns an **opaque handle**:

```tcl
object create System.Text.StringBuilder
;# => System#Text#StringBuilder#N
```

The handle format is `Type#N` with dots replaced by `#`; `N` is a per-interpreter
serial number (it will **not** be `1` in a long-running shell — do not depend on
its value). Eagle-runtime types use the short name (e.g. `StringBuilder#N`);
other assemblies use the fully-qualified name.

`object invoke ?options? handleOrType member ?arg ...?` is the workhorse: it
calls methods, gets/sets properties, and reads/writes fields. The same
sub-command handles instance members (pass a handle) and static members (pass a
type name).

```tcl
set sb [object create System.Text.StringBuilder]
object invoke $sb Append Hello
object invoke $sb Append ", World!"
puts [object invoke $sb ToString]            ;# => Hello, World!
```

```tcl
# Static method, static property, and constant fields (all via [object invoke])
puts [object invoke System.Math Sqrt 144.0]            ;# => 12
puts [object invoke System.Int32 MaxValue]             ;# => 2147483647
puts [object invoke System.Math PI]                    ;# => 3.141592653589793
puts [object invoke -tostring System.IntPtr Zero]      ;# => 0
puts [object invoke -tostring System.DateTime MinValue];# => 01/01/0001 00:00:00
```

Properties are read with zero extra args and written with one:

```tcl
set sb [object create System.Text.StringBuilder Hello]
puts [object invoke $sb Length]          ;# => 5
object invoke $sb Length 3               ;# set property (truncates)
puts [object invoke $sb ToString]        ;# => Hel
```

> **Fields and properties use the same syntax.** `object invoke $obj Name`
> reads; `object invoke $obj Name value` writes. (`Int32 MaxValue`, `Math PI`,
> and `IntPtr Zero` above are constant/`static readonly` *fields*, proving field
> reads go through `[object invoke]` — there is no separate field command. See
> the `getf`/`setf` section for why those are NOT the field accessors.)

Always release handles you own. The canonical pattern is `try`/`finally`:

```tcl
try {
    set ms [object create System.IO.MemoryStream]
    object invoke $ms WriteByte 65
    object invoke $ms WriteByte 66
    puts [object invoke $ms Length]      ;# => 2
} finally {
    if {[info exists ms]} then { object dispose $ms }
}
```

`object dispose ?options? handle ?handle ...?` calls `Dispose()` on
`IDisposable` objects and removes the handle. It returns a one-line summary of
what happened (verified outputs):

```tcl
object dispose [object create System.Object]        ;# => removed
object dispose [object create System.IO.MemoryStream] ;# => disposed removed
set a [object create System.IO.MemoryStream]
set b [object create System.IO.MemoryStream]
object dispose $a $b                                 ;# => disposed 2 removed 2
```

`System.Object` is not `IDisposable`, so it is only `removed`; a `MemoryStream`
is `disposed` then `removed`. After disposal the handle is gone:

```tcl
set sb [object create System.Text.StringBuilder]
object dispose $sb
puts [object exists $sb]                 ;# => False
```

`object cleanup ?pattern?` bulk-removes unreferenced handles and reports counts:

```tcl
object create System.Object
object cleanup                           ;# => disposed 0 removed 1
```

### Aliases — call a handle like a command

`object create -alias` (and `object alias $handle`) register a command **named
after the handle** that dispatches to `[object invoke]`. Combine with
`-objectname` for a friendly name:

```tcl
object create -alias -objectname mySB System.Text.StringBuilder
mySB Append abc                          ;# alias dispatches to [object invoke]
puts [mySB ToString]                     ;# => abc
```

```tcl
# Alias an existing handle in place
set sb [object create System.Text.StringBuilder]
object alias $sb
$sb Append zzz                           ;# the handle IS now a command
puts [$sb ToString]                      ;# => zzz
```

`-alias` on an `[object invoke]` result aliases only **newly created** handles
(a method returning the same object reuses its existing, un-aliased handle):

```tcl
set list [object create System.Collections.ArrayList]
object invoke $list Add a
set e [object invoke -alias $list GetEnumerator]   ;# enumerator is new -> aliased
puts [$e MoveNext]                       ;# => True
puts [$e Current]                        ;# => a
```

`object unalias handle` removes the command; the handle survives.

### Introspection & type identity

```tcl
set sb [object create System.Text.StringBuilder]
puts [object exists $sb]                  ;# => True
puts [object isnull $sb]                  ;# => False
puts [object isdisposed $sb]              ;# => False
puts [object referencecount $sb]          ;# => 1
puts [object flags $sb]                   ;# => Default
```

```tcl
# Instance-of checks (note: True/False)
set l [object create System.Collections.ArrayList]
puts [object isoftype $l System.Collections.IList]                ;# => True
puts [object isoftype -assignable $l System.Collections.IEnumerable] ;# => True
```

`object members` reflects over a handle or type. Filter with `-membertypes`,
`-pattern`, `-nameonly`, `-signatures`:

```tcl
set sb [object create System.Text.StringBuilder]
puts [lsort [lrange [lsort [object members -membertypes Method -nameonly $sb]] 0 4]]
;# => Append AppendFormat AppendJoin AppendLine Clear
```

```tcl
# -signatures yields a structured dict per member
object members -signatures -pattern *ToString* $sb
;# => {memberType Method memberName ToString methodType Method methodName \
;#     ToString callingConvention {Standard, HasThis} returnType System.String \
;#     parameterTypes {}} {... parameterTypes {System.Int32 System.Int32}}
```

`object list ?pattern?` lists live handles; `-objectname` controls the name:

```tcl
object create -objectname myThing System.Object
puts [object list *myThing*]              ;# => myThing
```

### Short names: import namespaces and type aliases

```tcl
object import System.Text
set sb [object create StringBuilder Hi]   ;# no System.Text. prefix needed
puts [object invoke $sb ToString]         ;# => Hi
object unimport                           ;# removes imports (takes no name)
```

```tcl
object type SB System.Text.StringBuilder
set sb [object create SB Hi]
puts [object invoke $sb ToString]         ;# => Hi
puts [object types *SB*]                  ;# => SB System.Text.StringBuilder
object untype                             ;# clears ALL type aliases (takes no name)
```

> Both `object unimport` and `object untype` take **options only, no positional
> name** — `object untype SB` errors with
> `wrong # args: should be "object untype ?options?"`. Call them bare to clear.

### Collection iteration — `object foreach` / `object lmap`

These walk any `IEnumerable`. **By default each element is wrapped as a fresh
object handle**, not its value — use `-tostring` (or `-nocreate`) to get the
underlying value:

```tcl
set l [object create System.Collections.ArrayList]
object invoke $l Add one
object invoke $l Add two

object foreach item $l { puts $item }
;# => System#String#N   (one handle per element — NOT "one"/"two")

object foreach -tostring item $l { puts $item }
;# => one
;#    two

puts [object lmap -tostring item $l { string toupper $item }]   ;# => ONE TWO
```

Without `-tostring`, `string toupper $item` would uppercase the *handle string*,
not the value — a common surprise.

### Overload resolution & generics

Eagle auto-selects a constructor/method by arity and argument types. Disambiguate
with `-parametertypes` (using **real CLR type names**, e.g. `System.Int32` or the
short `Int32` — the C# alias `int` does **not** resolve here) or force a specific
candidate with `-index`:

```tcl
# Auto-resolved:
set dt [object create System.DateTime 2024 1 15]
puts [object invoke -tostring $dt ToString yyyy-MM-dd]              ;# => 2024-01-15

# Explicit overload hint:
set dt [object create -parametertypes {System.Int32 System.Int32 System.Int32} \
    System.DateTime 2024 1 15]
puts [object invoke -tostring $dt ToString yyyy-MM-dd]              ;# => 2024-01-15
```

Generic types use the CLR reflection name — backtick-arity plus a bracketed type
list (escape the brackets/backtick in script):

```tcl
set l [object create System.Collections.Generic.List\`1\[System.String\]]
object invoke $l Add first
object invoke $l Add second
puts [object invoke $l Count]                ;# => 2
puts [object invoke -tostring $l Item 0]     ;# => first
```

### `out` / `ref` parameters

A method with `out`/`ref` parameters writes results back into the named script
variables; simple types come back as **values**, not handles:

```tcl
set ok [object invoke System.Int32 TryParse "42" result]
puts "ok=$ok result=$result"              ;# => ok=True result=42
```

### `invokeall` / `invokeraw`

`object invokeall handle {member arg...} ...` runs several members on one object;
`-chained` feeds each result into the next call. `object invokeraw` calls
`Type.InvokeMember()` directly, bypassing Eagle's argument-conversion pipeline
(use only when you need exact reflection control).

```tcl
set sb [object create System.Text.StringBuilder]
object invokeall $sb {Append Hello} {Append " "} {Append World}
puts [object invoke $sb ToString]         ;# => Hello World
```

### The deep tail

Assembly/type management (`object load`, `assemblies`, `search`, `resolve`,
`declare`/`undeclare`, `interfaces`, `namespaces`), security
(`certificate`, `hash`, `strongname`, `verifyall`), reference management
(`addreference`/`removereference`/`referencecount`), aliasing internals
(`aliasnamespaces`/`unaliasnamespace`/`fromvar`), callback plumbing
(`callbackflags`/`removecallback`), and remote activation (`object get`, an
`Activator.GetObject()` proxy not present on .NET Standard 2.0) are all
documented in [`../../../../object.md`](../../../../object.md).

### Safe interpreters

`[object]` is `Unsafe | Critical | NonStandard`; a safe child interpreter has no
`object` command at all:

```tcl
interp create -safe k
puts [interp issafe k]                     ;# => True
puts [interp eval k {info commands object}];# => (empty)
interp eval k {catch {object create System.Object} m; set m}
;# => permission denied: safe interpreter cannot use command "object create"
```

Policies can re-grant tightly-scoped access; see
[`../../../../object.md`](../../../../object.md) §14.

---

## `getf` / `setf` / `unsetf` — NOT what they sound like

Despite the suggestive names, these are **not** object-field accessors. In the
Eagle source they are *variable* commands (`ObjectGroup("variable")`) that read,
set, and unset a variable together with its **internal interpreter flags** — a
diagnostic facility flagged `Unsafe | NonStandard | Obsolete | Diagnostic`.

They are compiled behind the `OBSOLETE` define and are **absent from standard
builds**, so all three are unavailable in a normal interpreter:

```tcl
catch {getf} m;    puts $m   ;# => invalid command name "getf"
catch {setf} m;    puts $m   ;# => invalid command name "setf"
catch {unsetf} m;  puts $m   ;# => invalid command name "unsetf"
```

To read or write a .NET object's **field**, use `[object invoke]` (see above) —
that is the real field accessor. For ordinary variables use `[set]` / `[unset]`.

---

## `delegate` / `stub` — internal infrastructure, not user commands

Both are core-library command *classes* marked `NoAdd` (and `Delegate`), so they
are never registered as callable top-level commands:

```tcl
catch {delegate} m; puts $m   ;# => invalid command name "delegate"
catch {stub} m;     puts $m   ;# => invalid command name "stub"
```

- **`delegate`** (the `_Delegate` class) wraps a single `System.Delegate` as a
  command; it is created by the interpreter when a .NET delegate must be
  invocable as a script command. The user-facing ways to make delegates are
  `[library declare]` (native function delegates, below) and Eagle's callback
  marshalling that turns a script command into a managed delegate. List live
  delegates with `info delegates`.
- **`stub`** (the `Stub` class) is an ensemble placeholder. You create one with
  `[interp stub]`, not a bare `stub`:

```tcl
interp stub {} myens                     ;# create a stub ensemble in this interp
puts [info commands myens]               ;# => myens
catch {myens} m; puts $m                 ;# => wrong # args: should be "myens option ?arg ...?"
```

---

## `invoke` — invoke a command at a stack level (Eagle extension)

This is **not** `[object invoke]`. `invoke ?level? cmd ?arg ...?` runs a command
at a chosen call-stack level, using the same level syntax as `[uplevel]`
(`#0` = global, a bare integer = that many frames up; default is the current
level):

```tcl
proc p {} { invoke #0 set g 99 }         ;# run [set] at the global frame
p
puts $g                                  ;# => 99
puts [expr {[info level] == [invoke 0 info level]}]   ;# => True
```

---

## `callback` — deferred command queue (6 sub-commands)

`callback enqueue|dequeue|execute|list|count|clear`. It queues named commands for
later execution, decoupling producers from consumers.

```tcl
callback enqueue puts "hello from the queue"
```

> **Verified caveat.** In the standalone shell the queue is **serviced by the
> interpreter's readiness check between commands**, so an enqueued command runs
> almost immediately and `callback count` reads `0` again by the time the next
> command observes it:
>
> ```tcl
> callback enqueue set zzz 99
> puts [info exists zzz]            ;# => 1   (already ran)
> puts [callback count]             ;# => 0   (queue already drained)
> ```
>
> This differs from a naive "enqueue several, then count" reading. `callback` is
> best treated as host/event-loop integration plumbing rather than a synchronous
> data structure; reach for `[after]` for time-based scheduling. The remaining
> sub-commands (`count`, `list`, `clear`, `dequeue`) exist and inspect/empty the
> queue.

---

## `library` — native FFI (P/Invoke from script)

`library` is Eagle-unique: a script-level foreign-function interface that loads a
native shared library, builds a delegate type at runtime via
`System.Reflection.Emit`, resolves the export, and calls it with full
marshalling. It is the conceptual analogue of Python `ctypes` or .NET
`DllImport`. (Requires the `NATIVE`, `EMIT`, and `LIBRARY` build features;
present in this build.) 14 sub-commands:

```
call  certificate  checkload  declare  handle  info  load
matcharchitecture  resolve  test  undeclare  unload  unresolve  verifyarchitecture
```

The verified workflow — calling C `getpid()` on macOS — load → declare (auto-
resolves when `-module`+`-functionname` are given) → call → undeclare → unload:

```tcl
set m [library load /usr/lib/libSystem.B.dylib]
set d [library declare -returntype System.Int32 -functionname getpid -module $m]
set pid [library call $d]
puts [expr {$pid > 0}]                    ;# => True
puts [dict get [library info module $m] fileName]  ;# => /usr/lib/libSystem.B.dylib
library undeclare $d                       ;# release the delegate (decrements refcount)
library unload $m                          ;# unload (only succeeds at refcount 0)
```

Use **real CLR type names** for `-returntype`/`-parametertypes` (`System.Int32`
or `Int32`, not `int`). Modules are reference-counted: a module cannot be
unloaded while any declared delegate still references it. `[library declare]`
also takes `-callingconvention`, `-charset`, `-setlasterror`, and `-alias` (to
call the function as a command). Full FFI details, dynamic delegate emission,
architecture/certificate verification, and by-ref marshalling are in
[`../../../../library.md`](../../../../library.md).

---

## `load` / `unload` — .NET plugin (assembly) loading

`load ?options? fileName ?packageName? ?interp?` loads a **managed .NET
assembly** that implements `IPlugin`, registering its commands, functions,
policies, and traces. This is fundamentally different from Tcl's `[load]` (which
loads native C extensions with a `Tcl_PkgInitProc`): Eagle discovers plugin types
by reflection and verifies them (strong name, Authenticode, public-key token,
policy) before any plugin code runs. The native-code analogue of Tcl's `[load]`
is Eagle's `[library]`, above.

```tcl
load myextension.dll MyPackage            ;# file-based plugin load
```

Key options: `-isolated` (load into a separate AppDomain), `-trustedonly` /
`-verifiedonly` (require Authenticode / strong-name verification), `-preview`
(inspect metadata without committing), `-update`, `-viaresource` (load from an
embedded resource), and `-nocommands` / `-nofunctions` / `-nopolicies` /
`-notraces` (suppress specific entity kinds). `unload ?options? fileName
?packageName? ?interp?` reverses it; `-keeplibrary` removes the package but keeps
the assembly, `-nocomplain` ignores "not loaded". Both are
`Unsafe | Critical | Standard` — unavailable in safe interpreters. The full
loading pipeline, AppDomain isolation, security chain, and built-in/enterprise
plugins are in [`../../../../load.md`](../../../../load.md).

> A concrete load example is not reproduced here because it needs a signed plugin
> assembly on disk; see [`../../../../load.md`](../../../../load.md) for end-to-end recipes.
