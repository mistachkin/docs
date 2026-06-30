# Commands: Introspection & Runtime

`info` · `debug` · `host` · `version` · `parse` · `pid` · `kill` · `exit`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Values that are **machine-, build-, or time-dependent** — a PID, the build
version, the host size — are described by *shape*, never pinned to a fixed
`;# =>`. Cross-cutting Tcl differences live in
[`../tcl-gotchas.md`](../tcl-gotchas.md). `info`, `debug`, and `host` are huge
ensembles (86 / 78 / 33 sub-commands); every name is listed here, the popular
ones are shown, and the deep-dive tails live in [`../../../../info.md`](../../../../info.md),
[`../../../../debug.md`](../../../../debug.md), and [`../../../../host.md`](../../../../host.md).

> Reminder: `[info exists]` and `[namespace exists]` return **`1`/`0`**, but the
> *other* predicates (`expr`, `string is`, `dict exists`, `file exists`,
> `array exists`) return **`True`/`False`**. The `True`/`False` convention is
> **not universal** — verified below; see gotcha #1.

---

## `info` — 86 sub-commands

`info subcommand ?arg ...?` — the central introspection ensemble. It covers the
Tcl 8.4 surface (commands, vars, procs, the call stack, version) **plus** a large
set of Eagle-only sub-commands for the engine, the CLR host, objects, and
security. The popular ones are shown first; the full roster is at the end.

### Existence & completeness — `1`/`0`, not `True`/`False`

```tcl
set x 1
info exists x                     ;# => 1
info exists nope                  ;# => 0
```

`[info exists]` returns the literal **`1`/`0`** — and so does `[namespace
exists]` — whereas most other Eagle predicates return `True`/`False`. Verified
side by side:

```tcl
info exists x                     ;# => 1       (info exists)
namespace exists ::               ;# => 1       (namespace exists)
dict exists {a 1} a               ;# => True    (everything else...)
file exists /                     ;# => True
array set A {a 1}; array exists A ;# => True
string is digit 5                 ;# => True
expr {1 < 2}                      ;# => True
```

`[info complete]` (used by REPLs to detect a half-typed command) does return
`True`/`False`:

```tcl
info complete {set x 1}           ;# => True
info complete "set x \{"          ;# => False  (unbalanced brace)
```

### `info commands` — names + Eagle filter options

```tcl
info commands info                ;# => info
lsort [info commands rege*]       ;# => regexp regexpEscapeAll
```

Beyond a glob `pattern`, Eagle adds boolean **filter options** that Tcl has no
equivalent for — `-core`, `-library`, `-safe`, `-unsafe`, `-hidden`,
`-hiddenonly`, `-nocommands`, `-noprocs`, and more. Counts are build-dependent,
so the *relationships* are what's verified:

```tcl
# -safe lists only commands a safe interp may run -> fewer than the full set:
expr {[llength [info commands -safe]] < [llength [info commands]]}    ;# => True
# -hidden folds in hidden commands -> at least as many as the full set:
expr {[llength [info commands -hidden]] >= [llength [info commands]]} ;# => True
```

`[info procs ?pattern?]` is the proc-only counterpart; `[info subcommands ens]`
lists an ensemble's sub-commands:

```tcl
proc add {a b} {return [expr {$a + $b}]}
lsort [info procs add]                            ;# => add
expr {[lsearch [info subcommands info] exists] >= 0}   ;# => True
```

### `info cmdtype` (Eagle) — classify a command

```tcl
info cmdtype puts                 ;# => native
proc p {} {}; info cmdtype p      ;# => proc
info cmdtype string               ;# => ensemble
```

(Other results include `alias`, `hidden`, etc.)

### Call-frame introspection — `level`, `body`, `args`, `vars`, `locals`, `globals`

```tcl
proc add {a b} {set sum [expr {$a + $b}]; return $sum}
info args add                     ;# => a b
info body add                     ;# => set sum [expr {$a + $b}]; return $sum
                                  ;#    (the body is returned VERBATIM as defined;
                                  ;#    a multi-line proc keeps its newlines/indent)
```

`[info level]` is the current stack depth; `[info level 0]` is the **command +
args** that invoked the current frame. Note that `info level 0` is only legal
*inside* a proc:

```tcl
info level                        ;# => 0   (at top level)
proc showlevel {} {return [info level]}
showlevel                         ;# => 1   (one frame deep)
proc showframe {x} {return [info level 0]}
showframe 42                      ;# => showframe 42
catch {info level 0} m; set m     ;# => bad level "0"   (top level: no frame 0)
```

`[info vars]` / `[info locals]` / `[info globals]` enumerate visible variables
(`vars` = locals + visible globals; `locals` = local only):

```tcl
set g1 ok
proc inner {} {set loc1 a; set loc2 b; lsort [info locals]}
inner                                          ;# => loc1 loc2
expr {[lsearch [info globals] g1] >= 0}        ;# => True
```

### Version & engine metadata — read the shapes carefully

Eagle reports a **Tcl-compatibility** version through the standard sub-commands,
and its **own** build version through Eagle-specific ones. Do not confuse them:

```tcl
info tclversion                   ;# => 8.4      (the emulated Tcl level)
info patchlevel                   ;# => 8.4.21   (Tcl-compat PATCH level, NOT
                                  ;#    Eagle's build number)
```

Eagle's real build identity comes from `[info engine]` (Eagle) or `[version]`:

```tcl
info engine Name                  ;# => Eagle
info engine Version               ;# => 1.0
info engine PatchLevel            ;# => e.g. 1.0.9675.37713  (build-dependent)
info engine Configuration         ;# => Debug | Release      (build-dependent)
info engine                       ;# => Eagle                (default attribute)
```

`info engine` (Eagle) takes `?attribute? ?refresh? ?all?`; valid attributes are
`Name`, `Culture`, `Version`, `PatchLevel`, `Release`, `SourceId`,
`SourceTimeStamp`, `StrongNameTag`, `Configuration`. (Safe interpreters may not
pass `refresh true`.)

### Process, host, and script identity

```tcl
expr {[pid] == [info pid]}        ;# => True    (info pid mirrors [pid])
expr {[lsearch [info subcommands info] hostname] >= 0}   ;# => True
```

- `[info nameofexecutable]` — the **hosting executable**. Because Eagle runs as a
  managed assembly, this is typically the .NET muxer path (e.g.
  `/usr/local/share/dotnet/dotnet`), not an `eagle.exe` — shape: an absolute
  path string.
- `[info hostname]` — the machine host name (shape: a non-empty string).
- `[info script]` — the path of the file currently being evaluated; **empty**
  when running a `-evaluate` string, and the file path when running with `-file`
  (verified: `file tail [info script]` returns the script's base name).
- `[info cmdcount]` — a monotonically increasing command counter (shape: a
  positive integer that grows as more commands run).

### All 86 `info` sub-commands

`active` · `administrator` · `appdomain` · `args` · `argv` · `assembly` ·
`base` · `binary` · `bindertypes` · `body` · `callbacks` · `channels` · `clr` ·
`cmdcount` · `cmdline` · `cmdtype` · `commands` · `complete` · `connections` ·
`context` · `culture` · `cultures` · `decision` · `default` · `delegates` ·
`engine` · `ensembles` · `exists` · `externals` · `frame` · `framework` ·
`frameworkextra` · `functions` · `globals` · `hostname` · `hwnd` · `identifier` ·
`interactive` · `interps` · `lastinput` · `level` · `levelid` · `library` ·
`linkedname` · `loaded` · `locals` · `modules` · `nameofexecutable` · `newline` ·
`nprocs` · `objects` · `operands` · `operators` · `os` · `patchlevel` · `path` ·
`pid` · `plugin` · `pluginflags` · `policies` · `ppid` · `previouspid` ·
`processors` · `procs` · `programextension` · `ptid` · `runtime` ·
`runtimeversion` · `script` · `setup` · `sharedlibextension` · `shelllibrary` ·
`source` · `subcommands` · `syntax` · `sysvars` · `tclversion` · `tid` ·
`transactions` · `undefined` · `user` · `varlinks` · `vars` · `whitespace` ·
`windows` · `windowtext`

Deep dive: [`../../../../info.md`](../../../../info.md).

---

## `debug` — 78 sub-commands (Eagle extension; mostly unsafe)

`debug subcommand ?arg ...?` — the engine/debugger control surface. There is **no
Tcl equivalent**: it exposes the script debugger, breakpoints, the call/parse
stacks, memory and GC introspection, interpreter mounts, runtime options, and
diagnostic hooks. Most sub-commands are unsafe (a safe interp cannot use them).
A few read-only ones are deterministic enough to show:

```tcl
debug ready                       ;# => True   (interpreter ready to run?)
debug levels
;# => maximumLevels 15 maximumScriptLevels 18 maximumScriptFileLevels 2 \
;#    maximumParserLevels 11 maximumExpressionLevels 6
expr {[debug gcmemory] > 0}       ;# => True   (GC heap bytes; value varies)
debug enable                      ;# => debugger disabled   (toggles the script
                                  ;#    debugger; ?bool? sets it)
```

`[debug memory]` returns a multi-field memory report (values are
machine-dependent). Many sub-commands (`break`, `step`, `watch`, `eval`,
`icommand`, `iqueue`, …) only do something meaningful from inside an **interactive
debugger session**; outside one they no-op or report state (e.g. `debug stack`
returns `thread stack size is invalid` when no managed stack size is known).

### All 78 `debug` sub-commands

`break` · `breakpoints` · `bundle` · `cacheconfiguration` · `callback` ·
`cleanup` · `collect` · `complaint` · `emergency` · `enable` · `eval` ·
`exception` · `execute` · `function` · `gcmemory` · `halt` · `hook` · `history` ·
`icommand` · `interactive` · `invoke` · `iqueue` · `iresult` · `keyring` ·
`levels` · `lockloop` · `lockvar` · `log` · `memory` · `mount` · `mounts` ·
`null` · `oncancel` · `onerror` · `onexecute` · `onexit` · `onreturn` ·
`ontest` · `ontoken` · `operator` · `output` · `paths` · `pluginexecute` ·
`pluginflags` · `purge` · `procedureflags` · `resume` · `restore` · `readonly` ·
`ready` · `refreshautopath` · `result` · `run` · `runtimeoption` ·
`runtimeoverride` · `secureeval` · `self` · `set` · `setup` · `shell` · `stack` ·
`status` · `step` · `steps` · `subst` · `suspend` · `sysmemory` · `test` ·
`testpath` · `token` · `trace` · `types` · `undelete` · `unmount` · `variable` ·
`vout` · `watch` · `write`

Deep dive: [`../../../../debug.md`](../../../../debug.md).

---

## `host` — 33 sub-commands (Eagle extension)

`host subcommand ?arg ...?` — the interactive-host (console/terminal) interface:
size, colors, cursor position, key/line input, the title bar, beeps, and box
drawing. There is no Tcl equivalent (Tcl uses bare `puts`/`gets` + platform
extensions). Behavior depends on whether a real console is attached; the
representative read-only ones below were verified headless:

```tcl
host isopen                       ;# => True
host size                         ;# => 80 24   (shape: "width height"; depends
                                  ;#    on the actual terminal)
host title foo                    ;# => foo     (sets + echoes the window title)
host flags
;# => Complain, Debug, Prompt, Title, Thread, Exit, WorkItem, Stream, Data,
;#    Profile, Sleep, Yield, Resizable, Color, ReversedColor, Text, Sizing,
;#    Positioning, MinimumSize, QueryState, NoColorNewLine,
;#    RestoreColorAfterWrite, ResetColorForRestore
```

`host flags` reports the host's capability set (a `HostFlags` enum list; the
exact members are build/host-dependent). Input sub-commands (`readchar`,
`readkey`, `readline`) and visual ones (`color`, `position`, `clear`, `writebox`)
need an attached console to be useful.

### All 33 `host` sub-commands

`beep` · `boxstyle` · `cancel` · `clear` · `close` · `color` · `echo` ·
`errchan` · `exit` · `flags` · `font` · `inchan` · `isopen` · `mode` ·
`namedcolor` · `open` · `outchan` · `outputstyle` · `pause` · `position` ·
`query` · `readchar` · `readkey` · `readline` · `redirected` · `reset` ·
`result` · `screen` · `size` · `sleep` · `title` · `write` · `writebox`

Deep dive: [`../../../../host.md`](../../../../host.md).

---

## `version`

`version ?flags?` — returns Eagle's full self-description string. The base call's
output is **build- and time-dependent**, so only its shape is given:

```tcl
version
;# => Eagle <ver> {} genuine unofficial unstable beta {} <runtime> <config> \
;#    {Tcl <tclver>} {<build-timestamp>} {} {} {<.NET ver>} <os> <arch>
;# e.g. Eagle 1.0.9675.37713 {} genuine ... {Tcl 8.4.21} {2026...} ... Darwin arm64
```

`flags` come from the `VersionFlags` enum — verified by the error on a bad value:

```tcl
catch {version bogus} m; set m
;# => bad "...VersionFlags" value "bogus": must be AllowNull, Core, Default,
;#    ForDefault, ForSetup, Invalid, None, Plugins, Setup, or Vendor
```

For programmatic version checks prefer the structured `[info engine ...]`,
`[info patchlevel]`, and `[info tclversion]` above.

---

## `parse` — Eagle's script-parser introspection (Eagle extension)

`parse kind ?options? text ...` exposes Eagle's parser, returning the **token
structure** of a command, expression, script, or option list (no Tcl
equivalent). Kinds:

- `parse command ?options? text` — parse `text` as one command.
- `parse expression ?options? text` — parse `text` as an `[expr]` expression.
- `parse script ?options? text` — parse `text` as a full script (≥0 commands).
- `parse options ?options? optionList argumentList` — parse argv-style options
  against the definitions in `optionList`.

The result is a flat Tcl list: a leading **header** dict (parser state +
overall command extent) followed by one dict **per token**. Verified, smallest
case:

```tcl
parse command x
;# => {NotReady False} {IsImmutable False} {EngineFlags None} \
;#    {SubstitutionFlags Default} {FileName {}} {CurrentLine 1} \
;#    {CommentStart -1} {CommentLength 0} {CommandStart 0} {CommandLength 1} \
;#    {CommandWords 1} {Tokens 2} \
;#    {IsImmutable False} {Type SimpleWord} {SyntaxType None} {Flags None} \
;#      {FileName {}} {StartLine 1} {EndLine 1} {ViaSource False} {Start 0} \
;#      {Length 1} {Components 1} {Text x} {ClientData {}} \
;#    {IsImmutable False} {Type Text} ... {Start 0} {Length 1} {Text x} ...
```

Header fields name the parse state (`Tokens` = token count, `CommandStart` /
`CommandLength` = byte extent of the command). Each token dict carries its
`Type` (`SimpleWord`, `Text`, `Separator`, `Operator`, `SubExpression`, …),
`Start`/`Length` (position), and `Text`. `parse expression {1 + 2}` adds a
`Lexeme` field per token (`Plus`, `Literal`, …); `parse script {set x 1}` yields
a `Separator` token plus the command's word tokens. `parse options {} {-foo bar}`
returns empty when `optionList` defines no options. For "is this a complete
command?" use the lighter `[info complete]` (above).

---

## `pid`

`pid ?channelId?` — with no argument, the current process id; with a `channelId`
(e.g. from `open |...`), the pid of the process behind that channel. The value
is machine-dependent (shape: a positive integer); `[info pid]` returns the same
number:

```tcl
expr {[pid] > 0 && [string is integer [pid]]}    ;# => True
expr {[pid] == [info pid]}                        ;# => True
```

---

## `kill` — Eagle extension (unsafe)

`kill ?options? process` — terminate a process by **numeric PID** or by a **glob
name pattern**. Options: `-all` (every match — name patterns only, not a PID),
`-force` (hard `Process.Kill()` instead of a graceful `CloseMainWindow()`),
`-whatIf` (dry run), `-verbose`. Returns the list of killed/closed processes.

```tcl
catch {kill -whatIf 999999} m; set m   ;# => could not open process 999999
```

It is marked **unsafe** — a safe interpreter is refused:

```tcl
interp create -safe s
interp eval s {catch {kill 1} m; set m}
;# => permission denied: safe interpreter cannot use command "kill"
interp delete s
```

There is no Tcl `kill`; in Tcl you would shell out (`exec kill`).

---

## `exit`

`exit ?options? ?returnCode?` — terminate the interpreter (and, in the shell,
the process) with `returnCode` (default `0`). Option `-force` exits immediately,
skipping cleanup. The code propagates to the OS — verified via the shell's exit
status:

```tcl
exit 3            ;# process exit code => 3
exit              ;# process exit code => 0
exit -force 2     ;# immediate exit, code => 2
```

Inside an embedded interpreter, `[exit]` unwinds the interpreter rather than
killing the host process; in the standalone shell it ends the process.
