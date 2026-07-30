# Commands: I/O, Files & Processes

`open` · `close` · `read` · `gets` · `puts` · `seek` · `tell` · `eof` ·
`flush` · `fconfigure` · `fblocked` · `fcopy` · `file` · `fileevent` · `glob` · `cd` ·
`pwd` · `socket` · `truncate` · `exec`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
The full path-manipulation reference is [`../../../../file.md`](../../../../file.md); the
`[exec]` command-line internals are in [`../../../../exec.md`](../../../../exec.md).

> **Channel defaults bite (verified).** A freshly `[open]`ed channel reports
> `-blocking False -encoding iso-8859-1 -translation auto` — **not** Tcl's
> Unix defaults of `utf-8` / `lf`. Worse, Eagle's `auto` translation is
> **CRLF-oriented**: it *writes* `\r\n` and on input only treats `\r\n` as a
> line terminator, so `[gets]` on a Unix LF-only file reads the **whole file**
> as one "line". For predictable byte counts and line splitting, set
> `fconfigure $ch -translation lf -encoding utf-8` right after `[open]` (or
> `-translation binary` for raw bytes). Every channel example below does this.

---

## Channels — the model

`[open]` returns a **channel name** (`file#NNNN`, e.g. `file#1207` — not Tcl's
`fileN`). Pass it to `puts`/`gets`/`read`/`seek`/`tell`/`eof`/`flush`/
`fconfigure`/`fileevent`/`close`. Use `[fileevent]` for readable and writable
events on socket and seekable file channels; `[vwait]` pumps the queued handler.

A round trip exercising the core verbs:

```tcl
set p /tmp/eagle-demo.txt
set ch [open $p w]
fconfigure $ch -translation lf
puts $ch "line1"
puts $ch "line2"
puts -nonewline $ch "tail"
close $ch
file size $p                                  ;# => 16   (6+6+4, LF endings)

set ch [open $p r]
fconfigure $ch -translation lf
gets $ch                                       ;# => line1
tell $ch                                       ;# => 6     (consumed "line1\n")
eof $ch                                         ;# => False
string length [read $ch]                        ;# => 10    ("line2\ntail")
eof $ch                                         ;# => True
seek $ch 0
read $ch 5                                       ;# => line1
seek $ch -4 end
read $ch                                          ;# => tail
close $ch
```

## `open`

`open name ?access? ?permissions?` — `access` is a Tcl access string
(`r` `r+` `w` `w+` `a` `a+`) **or** a POSIX flag list (`{WRONLY CREAT TRUNC}`).
Eagle adds options *before* the file name: `-channelid`, `-buffersize`,
`-encoding`, `-translation`, `-autoflush`, `-nullencoding`, `-share`, and the
standard-stream selectors `-stdin`/`-stdout`/`-stderr`.

```tcl
set ch [open /tmp/a w]; close $ch              ;# create/truncate
set ch [open /tmp/a a]                          ;# append
set ch [open /tmp/a {WRONLY CREAT TRUNC}]       ;# POSIX flag list
```

> **No `open "|cmd"` pipe form.** Eagle treats `|echo hi` as a literal file
> name and fails (`Could not find file '.../|echo hi'`); Tcl would spawn the
> command. Use [`exec`](#exec) for subprocess I/O.

## `close`

`close channel ?direction?` — closes (and flushes) the channel. Closing an
already-closed channel errors: `can not find channel named "file#1207"`.

## `puts`

`puts ?-nonewline? ?channel? string` — channel defaults to `stdout`.
`-nonewline` suppresses the trailing newline.

```tcl
puts -nonewline "x"; puts -nonewline "y"; puts ""    ;# => xy
```

## `gets`

`gets channel ?varName?` — one-arg form returns the line (sans terminator);
two-arg form **stores** the line in `varName` and **returns the character
count** (`-1` at EOF). Eagle adds `gets -keepeol true ...` to retain the
terminator.

```tcl
# file contains "alpha\nbeta\n" (LF)
set ch [open /tmp/g r]; fconfigure $ch -translation lf
gets $ch line                                   ;# => 5      (line = alpha)
read $ch                                          ;# nothing left after ...
set n [gets $ch other]                            ;# => -1     (EOF)
close $ch
```

## `read`

`read channel ?numChars?` / `read ?-nonewline? channel` — slurp the rest of the
channel, an exact count, or the rest minus one trailing newline.

```tcl
read $ch 5            ;# read exactly 5 chars
read -nonewline $ch   ;# read all, drop a single trailing newline
```

## `seek` / `tell`

`seek channel offset ?origin?` (origin `start` *(default)* / `current` / `end`);
`tell channel` returns the current byte position.

```tcl
seek $ch 0           ;# rewind
seek $ch 0 end       ;# to EOF;  tell $ch then == file size
seek $ch -4 end      ;# 4 bytes before EOF
```

## `eof`

`eof channel` — returns **`True`/`False`** (not `1`/`0`), `True` once a read has
hit end-of-file.

## `flush`

`flush channel` — forces buffered output to the underlying file/socket.

```tcl
puts -nonewline $ch "hello world"; flush $ch    ;# bytes now on disk
```

## `fconfigure`

`fconfigure channel ?option? ?value? ...` — query/set channel options.
Queryable: `-encoding`, `-translation` (and the whole dict via `fconfigure $ch`
with no option). Settable: `-blocking`, `-buffer`, `-encoding`, `-translation`.

```tcl
fconfigure $ch                                  ;# => -blocking False -encoding iso-8859-1 -translation auto
fconfigure $ch -encoding                         ;# => iso-8859-1
fconfigure $ch -translation                       ;# => auto
fconfigure $ch -translation lf -encoding utf-8    ;# set both (common fix)
```

> **`-blocking` is set-only.** Querying it alone — `fconfigure $ch -blocking` —
> errors with `"-blocking" option must be followed by boolean`, even though it
> shows up in the full `fconfigure $ch` dump. Read it from the dump; set it with
> a value (`fconfigure $ch -blocking true`).

## `fblocked`

`fblocked channel` — returns **`True`/`False`**; `True` when the last input
operation returned short because a non-blocking channel had no data ready.

```tcl
fblocked $ch          ;# => False   (after a complete read)
```

## `fcopy`

`fcopy input output ?-size n? ?-command cb?` — copies bytes between channels;
synchronous form returns the **byte count** copied.

```tcl
set in [open /tmp/src r]; set out [open /tmp/dst w]
fcopy $in $out                                  ;# => 11   (bytes copied)
close $in; close $out
```

## `file`

`[file]` is a 53-sub-command ensemble. The complete set (authoritative names
from `command_inventory.md`):

```
atime · attributes · channels · cleanup · copy · ctime · delete · dirname ·
drive · executable · exists · extension · glob · information · isdirectory ·
isfile · join · list · lstat · magic · mkdir · mtime · nativename · normalize ·
objectid · owned · pathtype · readable · rename · rights · rmdir · rootname ·
rootpath · same · sddl · separator · size · split · stat · system · tail ·
tempname · temppath · tildeexpand · touch · trusted · type · under · validname ·
verified · version · volumes · writable
```

**Path manipulation** (pure string work — no filesystem access):

```tcl
file join /a/b c d            ;# => /a/b/c/d
file dirname /a/b/c.txt       ;# => /a/b
file tail /a/b/c.txt          ;# => c.txt
file extension /a/b/c.txt     ;# => .txt
file rootname /a/b/c.txt      ;# => /a/b/c
file split /a/b/c.txt         ;# => / a b c.txt
file pathtype /a/b            ;# => absolute
file pathtype a/b             ;# => relative
file separator                 ;# => /
file normalize /tmp/a/../b/./c ;# => /tmp/b/c   (collapses . and ..)
file nativename /tmp/x         ;# => /tmp/x      (native separators)
```

> **`file join` does NOT honour an absolute later component.** Eagle:
> `file join a /b c` → `a/b/c`. Tcl (8.4/8.5/8.6) resets at the absolute part:
> `file join a /b c` → `/b/c`. Eagle simply joins with separators.

**Filesystem queries** — the boolean tests return **`True`/`False`**, not
`1`/`0` (gotcha #1):

```tcl
file exists /tmp              ;# => True
file isdirectory /tmp         ;# => True
file isfile /tmp/x.txt        ;# => True   (a regular file)
file size /tmp/x.txt          ;# => 5      (bytes)
file type /tmp                 ;# => directory   (only file/directory; no "link" type)
file mtime /tmp/x.txt          ;# => integer epoch seconds, e.g. 1751200000
file readable /tmp/x.txt       ;# => True
file writable /tmp/x.txt       ;# => True
```

**Mutation** — `mkdir`, `copy`, `rename`, `delete`:

```tcl
file mkdir /tmp/d/sub                  ;# makes intermediate dirs
file copy   /tmp/d/a.txt /tmp/d/b.txt  ;# add -force to overwrite
file rename /tmp/d/b.txt /tmp/d/c.txt  ;# add -force to overwrite
file delete -recursive -force /tmp/d   ;# removes a whole directory tree
```

> **`file delete` errors on a missing target.** `file delete /no/such/path`
> raises `error deleting "...": no such file or directory` (Tcl silently
> ignores missing paths). Pass **`-nocomplain`** for Tcl-like quiet behavior:
> `file delete -nocomplain /maybe/missing`.

The long tail — `attributes`, `stat`/`lstat`, `atime`/`ctime`, `touch`,
`tempname`/`temppath` (temp files), `magic` (content sniffing), `sddl`/`rights`/
`owned` (Windows ACLs), `under`/`same`/`verified`/`trusted`, `volumes`/`drive`/
`system`, `tildeexpand`, `channels`, `validname` — is documented in
[`../../../../file.md`](../../../../file.md). (`file channels` lists open channel names;
`file tempname`/`file temppath` yield a temp file path and the temp directory.)

## `glob`

`glob ?options? pattern ?pattern ...?` — options include `-directory dir`,
`-tails`, `-types`, `-path`, `-join`, `-nocomplain`. Like Tcl, a non-matching
pattern is an **error** unless `-nocomplain` is given, and a plain `*`
**excludes dot-files**.

```tcl
# dir holds a.txt b.txt c.log .hidden
glob -directory $d -tails *.txt    ;# => a.txt b.txt
glob -directory $d *                ;# => .../a.txt .../b.txt .../c.log   (no .hidden)
glob -directory $d *.zzz           ;# => error: no files matched glob pattern "*.zzz"
glob -directory $d -nocomplain *.zzz ;# => (empty)
```

## `cd` / `pwd`

`cd ?dir?` changes the working directory (no arg → home); `pwd` returns it.

```tcl
set old [pwd]
cd /tmp
pwd                  ;# => /private/tmp   (macOS resolves /tmp symlink)
cd $old
```

## `socket`

Basic note — `socket ?options? host port` opens a **client** TCP channel;
`socket -server command ?options? port` opens a **listening server** that calls
`command chan addr port` per connection. Both return a channel usable with the
verbs above. Eagle wraps .NET `TcpClient`/`TcpListener` and adds a broad option
set (`-async`, `-myaddr`, `-myport`, `-timeout`, `-nodelay`, `-keepalive`,
`-buffer`, `-addressfamily`, ...). For asynchronous connect, install a writable
`[fileevent]`, wait for it, then query `fconfigure $socket -error`; empty means
success and a non-empty stable message means failure.

```tcl
# client (sketch):
set s [socket 127.0.0.1 8080]
fconfigure $s -translation crlf
puts $s "GET / HTTP/1.0"; puts $s ""; flush $s
set reply [read $s]
close $s
```

```tcl
# asynchronous client connect:
set s [socket -async 127.0.0.1 8080]
fileevent $s writable {
  fileevent $::s writable {}
  set ::connected true
}
vwait ::connected

if {[set message [fconfigure $s -error]] ne ""} then {
  close $s
  error $message
}
```

## `truncate` — Eagle extension (no Tcl equivalent)

`truncate channel ?length?` — operates on an **open channel** (not a path).
With `length`, sets the file to that many bytes; without, truncates at the
current seek position.

```tcl
set ch [open /tmp/t w]; puts -nonewline $ch "0123456789"; flush $ch
truncate $ch 4                                  ;# file is now 4 bytes
close $ch
file size /tmp/t                                ;# => 4
truncate /tmp/t 2   ;# error: can not find channel named "/tmp/t"  (needs a channel)
```

## `exec`

`exec ?options? arg ?arg ...? ?&?` — the first non-option argument is the
executable; a trailing `&` (or `-background`) runs it detached. Eagle's `[exec]`
is **not** a Tcl pipeline parser: there is no `|`, `<`, `>`, or `2>&1` grammar.
It assembles **one** command line and launches a single .NET process. Use the
option surface (`-stdin`/`-stdout`/`-stderr`/`-exitcode`/`-success`/`-timeout`/
`-directory`/...) instead of shell redirection. Full internals in
[`../../../../exec.md`](../../../../exec.md).

```tcl
exec echo hello world          ;# => hello world
```

> **Gotcha 1 — non-zero exit is NOT an error by default.** Unlike Tcl, a failing
> child does not raise:
> ```tcl
> catch {exec false}                       ;# => 0    (no error!)   Tcl: 1
> catch {exec -success Success false} m    ;# => 1    m = child process exited abnormally
> exec -exitcode ec false; set ec          ;# => Failure   (an ExitCode enum, not an int)
> exec -exitcode ec true;  set ec          ;# => Success
> ```
> Pass **`-success Success`** to get Tcl-style "error on failure"; capture the
> outcome with **`-exitcode <var>`** (yields `Success`/`Failure`, not a number).

> **Gotcha 2 — `sh -c {...}` does NOT pass through.** Because Eagle re-serializes
> the argument words into one command line, the script never reaches `sh -c` as a
> single argument:
> ```tcl
> exec sh -c {echo hi}     ;# => (empty)   NOT "hi"
> exec sh -c "echo hi"     ;# => (empty)   NOT "hi"
> ```
> Prefer direct argv (`exec echo hi`). When you genuinely need a shell pipeline,
> build and pass the command yourself per the quoting rules in
> [`../../../../exec.md`](../../../../exec.md) (e.g. the `-commandline` / `-forprocessor`
> escaping paths), rather than assuming Tcl's `sh -c` idiom.
