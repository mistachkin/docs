# Eagle Built-in Command Index

Every built-in Eagle command, mapped to the reference file that documents it.
Coverage was audited against a running interpreter (`info commands` minus
`info procs`): **112 of 114** user-facing built-ins are documented here; the two
omitted (`Eagle_Nop`, a no-op alias of `nop`; and `unsupported`, an internal
option handler) are not user-facing.

Not built-in *commands* (covered elsewhere in the skill):
- Script-library **procedures** (`getDictionaryValue`, `readFile`, `isWindows`,
  `lshuffle`, …) → [`../library.md`](../library.md)
- The **test harness** (`test`, `test1`, `test2`, constraints) → [`../testing.md`](../testing.md)
- **Sandboxing** → [`../safe-interp.md`](../safe-interp.md) · **Plugins** → [`../plugins.md`](../plugins.md) · **Recipes** → [`../task-recipes.md`](../task-recipes.md)

> Routing tip: have a command name and want the file? Search this page for the
> name, or grep the `commands/` dir: `grep -rl '`<cmd>`' .`. Ensembles list a
> sub-command count; the deep-dive doc (`../../../../<cmd>.md`) holds the long tail.

---

## By category

### [control-flow.md](control-flow.md)
`if` · `switch` · `for` · `foreach` · `while` · `do` (Eagle) · `break` ·
`continue` · `catch` · `error` · `throw` · `return` · `try` (finally-only)

### [variables.md](variables.md)
`set` · `unset` · `incr` · `append` · `global` · `variable` · `upvar` ·
`array` (17 sub-commands → [`../../../../array.md`](../../../../array.md))

### [lists.md](lists.md)
`list` · `lindex` · `llength` · `lrange` · `linsert` · `lreplace` ·
`lremove` (Eagle) · `lset` · `lsearch` · `lsort` · `lassign` · `lrepeat` ·
`lreverse` · `lmap` · `lget` (Eagle) · `concat` · `join` · `split`

### [strings.md](strings.md)
`string` (29 sub-commands → [`../../../../string.md`](../../../../string.md)) ·
`format` · `scan` · `subst` · `encoding` ·
`regexp` · `regsub` (→ [`../../../../regexp.md`](../../../../regexp.md))

### [dict.md](dict.md)
`dict` (20 sub-commands)

### [expr-math.md](expr-math.md)
`expr` (38 operators + 54 math functions) · `fpclassify` (Eagle)

### [io-files.md](io-files.md)
`open` · `close` · `read` · `gets` · `puts` · `seek` · `tell` · `eof` ·
`flush` · `fconfigure` · `fblocked` · `fcopy` ·
`file` (53 sub-commands → [`../../../../file.md`](../../../../file.md)) ·
`glob` · `cd` · `pwd` · `socket` · `truncate` ·
`exec` (→ [`../../../../exec.md`](../../../../exec.md))

### [procs-namespaces.md](procs-namespaces.md)
`proc` · `apply` · `nproc` (Eagle) · `napply` (Eagle) · `rename` · `uplevel` ·
`downlevel` (Eagle) ·
`namespace` (22 sub-commands → [`../../../../namespace.md`](../../../../namespace.md)) ·
`scope` (Eagle, 19 sub-commands → [`../../../../scope.md`](../../../../scope.md))

### [objects-dotnet.md](objects-dotnet.md)
`object` (43 sub-commands → [`../../../../object.md`](../../../../object.md)) ·
`invoke` · `callback` · `library` (→ [`../../../../library.md`](../../../../library.md)) ·
`load` · `unload` (→ [`../../../../load.md`](../../../../load.md)) ·
`getf` · `setf` · `unsetf` · `delegate` · `stub` (mostly obsolete/internal — see file)

### [interp-events.md](interp-events.md)
`interp` (60 sub-commands → [`../../../../interp.md`](../../../../interp.md)) ·
`alias` · `ensemble` · `eval` · `nop` · `update` · `vwait` · `after` · `bgerror` ·
`tcl` (native Tcl → [`../../../../tcl.md`](../../../../tcl.md))

### [package.md](package.md)
`package` (23 sub-commands → [`../../../../package.md`](../../../../package.md)) · `source`

### [data-net.md](data-net.md)
`sql` (→ [`../../../../sql.md`](../../../../sql.md)) ·
`uri` (18 sub-commands → [`../../../../uri.md`](../../../../uri.md)) ·
`xml` · `base64` · `hash` · `guid`

### [time.md](time.md)
`clock` (15 sub-commands → [`../../../../clock.md`](../../../../clock.md)) · `time`

### [introspection.md](introspection.md)
`info` (86 sub-commands → [`../../../../info.md`](../../../../info.md)) ·
`debug` (78 sub-commands → [`../../../../debug.md`](../../../../debug.md)) ·
`host` (33 sub-commands → [`../../../../host.md`](../../../../host.md)) ·
`version` · `parse` · `pid` · `kill` · `exit`

---

## Alphabetical lookup

after→interp-events · alias→interp-events · append→variables · apply→procs-namespaces ·
array→variables · base64→data-net · bgerror→interp-events · break→control-flow ·
callback→objects-dotnet · catch→control-flow · cd→io-files · clock→time · close→io-files ·
concat→lists · continue→control-flow · debug→introspection · delegate→objects-dotnet ·
dict→dict · do→control-flow · downlevel→procs-namespaces · encoding→strings ·
ensemble→interp-events · eof→io-files · error→control-flow · eval→interp-events ·
exec→io-files · exit→introspection · expr→expr-math · fblocked→io-files ·
fconfigure→io-files · fcopy→io-files · file→io-files · flush→io-files · for→control-flow ·
foreach→control-flow · format→strings · fpclassify→expr-math · getf→objects-dotnet ·
gets→io-files · glob→io-files · global→variables · guid→data-net · hash→data-net ·
host→introspection · if→control-flow · incr→variables · info→introspection ·
interp→interp-events · invoke→objects-dotnet · join→lists · kill→introspection ·
lappend→variables · lassign→lists · lget→lists · library→objects-dotnet · lindex→lists ·
linsert→lists · list→lists · llength→lists · lmap→lists · load→objects-dotnet ·
lrange→lists · lremove→lists · lrepeat→lists · lreplace→lists · lreverse→lists ·
lsearch→lists · lset→lists · lsort→lists · namespace→procs-namespaces · napply→procs-namespaces ·
nop→interp-events · nproc→procs-namespaces · object→objects-dotnet · open→io-files ·
package→package · parse→introspection · pid→introspection · proc→procs-namespaces ·
puts→io-files · pwd→io-files · read→io-files · regexp→strings · regsub→strings ·
rename→procs-namespaces · return→control-flow · scan→strings · scope→procs-namespaces ·
seek→io-files · set→variables · setf→objects-dotnet · socket→io-files · source→package ·
split→lists · sql→data-net · string→strings · stub→objects-dotnet · subst→strings ·
switch→control-flow · tcl→interp-events · tell→io-files · test/test1/test2→../testing.md ·
throw→control-flow · time→time · truncate→io-files · try→control-flow · unload→objects-dotnet ·
unset→variables · unsetf→objects-dotnet · update→interp-events · uplevel→procs-namespaces ·
upvar→variables · uri→data-net · variable→variables · version→introspection · vwait→interp-events ·
while→control-flow · xml→data-net
