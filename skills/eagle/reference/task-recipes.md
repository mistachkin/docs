# Eagle Task Recipes

Goal-oriented, copy-pasteable recipes for the most common tasks. Every recipe
below was **executed** against Eagle 1.0 (`info patchlevel` `8.4.21`; see
[`verification.md`](verification.md)) and the `;# =>` annotations show the
**real** result. These recipes deliberately respect the cross-cutting Eagle/Tcl
differences in [`tcl-gotchas.md`](tcl-gotchas.md) — booleans print `True`/`False`,
`[exec]` does not error on a non-zero exit by default, `[object]` is denied in
safe interpreters, and there is no `{*}` expansion. For the per-command depth
behind each recipe, follow the links into [`commands/index.md`](commands/index.md).

Multi-line recipes are meant to be saved to a file and run with the bundled
harness:

```sh
scripts/eval-eagle.sh -file recipe.eagle
```

---

## Recipe: Read and write a whole text file

`[open]` → `[read]` → `[close]`. **Always** `fconfigure` the channel right after
opening: a fresh Eagle channel defaults to `-encoding iso-8859-1 -translation
auto` (which writes CRLF on output), **not** Tcl's `utf-8`/`lf` — so set them
explicitly for predictable byte counts.

```tcl
set path /tmp/recipe-rw.txt

# write
set ch [open $path w]
fconfigure $ch -translation lf -encoding utf-8
puts $ch "line 1"
puts $ch "line 2"
close $ch

# read it all back
set ch [open $path r]
fconfigure $ch -translation lf -encoding utf-8
set data [read $ch]
close $ch

file size $path                                  ;# => 14   (two 7-byte LF lines)
llength [split [string trimright $data \n] \n]   ;# => 2    ($data is "line 1\nline 2\n")
```

Depth: [`commands/io-files.md`](commands/io-files.md) (the channel-defaults bite,
`open`/`read`/`gets`/`seek`, the `[file]` ensemble).

## Recipe: Run an external program, capture output, detect failure

`[exec]` launches one process (it is **not** a Tcl pipeline parser — no `|` `<`
`>` grammar). Two things bite: it **keeps the child's trailing newline** (Tcl
strips it), and a non-zero exit is **not** an error unless you pass
`-success Success`. Capture the outcome with `-exitcode` (an `ExitCode` enum,
not an int).

```tcl
# capture stdout (trim the trailing newline Eagle leaves on)
set out [string trimright [exec echo hello world] \n]
puts "<$out>"                                ;# => <hello world>

# default: a failing child does NOT raise
catch {exec false}                           ;# => 0    (no error!)   Tcl: 1

# opt in to Tcl-style error-on-failure
catch {exec -success Success false} m        ;# => 1    m = child process exited abnormally

# or just capture the exit status as an enum
exec -exitcode ec true ;  set ec             ;# => Success
exec -exitcode ec false ; set ec             ;# => Failure
```

Depth: [`commands/io-files.md`](commands/io-files.md#exec) and the deep dive
[`../../../exec.md`](../../../exec.md) (quoting/escaping, `-stdout`/`-stderr`/`-timeout`,
why `sh -c {...}` does not pass through).

## Recipe: Call a .NET BCL type and clean up

The `[object]` bridge is Eagle's signature feature. Static members need no
handle; instance objects return an **opaque handle** whose lifecycle you own —
release it with `[object dispose]` inside a `try`/`finally`.

```tcl
# static members -- nothing to dispose
object invoke System.Math Sqrt 144.0         ;# => 12
object invoke System.Math PI                 ;# => 3.141592653589793

# instance object with explicit cleanup
try {
    set sb [object create System.Text.StringBuilder]
    object invoke $sb Append "Hello"
    object invoke $sb Append ", World!"
    object invoke $sb ToString                ;# => Hello, World!
    object invoke $sb Length                  ;# => 13
} finally {
    if {[info exists sb]} then { object dispose $sb }
}
object exists $sb                             ;# => False   (handle is gone)
```

`StringBuilder` is not `IDisposable`, so `dispose` just **removes** the handle; a
`MemoryStream` (or other `IDisposable`) is **disposed** then removed. Note
`[object]` is unavailable in safe interpreters (see the sandbox recipe).

Depth: [`commands/objects-dotnet.md`](commands/objects-dotnet.md) (handles,
aliases, overload resolution, `out`/`ref`, generics) and
[`../../../object.md`](../../../object.md).

## Recipe: Parse and format dates

`[clock scan]` parses a date string to epoch seconds; `[clock format]` renders
seconds back to a string. Use **`-gmt 1`** on both to pin results to UTC
(otherwise they depend on the machine's local time zone). There is **no
`clock add`** and **no free-form / natural-language** dates — do calendar math on
the integer seconds.

```tcl
set t [clock scan {2009-02-13 23:31:30} -gmt 1]   ;# => 1234567890

clock format $t -gmt 1 -format {%Y-%m-%d %H:%M:%S} ;# => 2009-02-13 23:31:30
clock format $t -gmt 1 -format %A                  ;# => Friday
clock format $t -gmt 1 -iso -full                  ;# => 2009-02-13T23:31:30.0000000Z

# parse with an explicit input format
clock scan {Jan 15, 2024} -format {%b %d, %Y} -gmt 1   ;# => 1705276800

# "+1 day" is arithmetic on the seconds (no clock add)
expr {$t + 86400}                                  ;# => 1234654290
```

Depth: [`commands/time.md`](commands/time.md) (every specifier, custom `-epoch`,
`clock start`/`stop` timing) and [`../../../clock.md`](../../../clock.md).

## Recipe: Sandbox / evaluate untrusted script

`interp create -safe` gives a child interpreter with every unsafe command hidden
— file I/O, `[exec]`, and the whole `[object]` CLR bridge. Untrusted code runs
in it; calls to unsafe commands are **denied** rather than executed.

```tcl
set safe [interp create -safe]

# untrusted arithmetic / string work is fine
interp eval $safe {expr {2 ** 10 + 1}}        ;# => 1025

# unsafe commands are denied -- the whole point
interp eval $safe {catch {object create System.Object} m; set m}
;# => permission denied: safe interpreter cannot use command "object create"
interp eval $safe {catch {exec echo hi} m; set m}
;# => permission denied: safe interpreter cannot use command "exec"
interp eval $safe {catch {open /etc/passwd} m; set m}
;# => permission denied: safe interpreter cannot use command "open"

interp delete $safe
```

To grant a *controlled* capability, wire a cross-interpreter alias
(`interp alias $safe safeCmd {} trustedParentCmd`); to cap CPU/memory use the
`interp recursionlimit`/`iterationlimit`/`timeout` family.

Depth: [`commands/interp-events.md`](commands/interp-events.md) (lifecycle,
hidden commands, aliases, limits) and [`../../../safe.md`](../../../safe.md).

## Recipe: XML handling (Eagle has no `json` command)

There is **no `[json]` command** in this build (`info commands json` is empty);
for structured data use the `[xml]` command (it wraps `System.Xml`) or reach into
the BCL via `[object]`. `xml foreach` walks nodes by XPath, binding the var to an
**opaque .NET node handle** — invoke members with `[object invoke]`.

```tcl
set doc {<config><item key="a">1</item><item key="b">2</item></config>}

xml foreach -xpaths //item node $doc {
    puts "[object invoke $node GetAttribute key] = [object invoke $node InnerText]"
}
;# => a = 1
;#    b = 2

# validate a document against an XSD (empty string = valid; raises on mismatch)
set xsd {<?xml version="1.0"?>
  <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <xs:element name="note" type="xs:string"/>
  </xs:schema>}
expr {[catch {xml validate $xsd {<?xml version="1.0"?><note>hi</note>}}] == 0}   ;# => True
```

Depth: [`commands/data-net.md`](commands/data-net.md#xml) (`serialize`/
`deserialize`/`foreach`/`validate`).

## Recipe: Iterate a dictionary and build a dict result

A dict is a list of alternating key/value pairs (keys kept in insertion order).
`dict foreach` reads; build a result with `dict set` — but **initialize the
variable first**: Eagle's `dict set` does not auto-create a missing variable
(gotcha #7).

```tcl
set prices [dict create apple 3 banana 2 cherry 5]

dict foreach {name price} $prices {puts "$name -> $price"}
;# => apple -> 3
;#    banana -> 2
;#    cherry -> 5

# build a derived dict (note the dict create init)
set doubled [dict create]
dict foreach {name price} $prices {dict set doubled $name [expr {$price * 2}]}
set doubled                                   ;# => apple 6 banana 4 cherry 10

# the same, declaratively
dict map {name price} $prices {expr {$price * 2}}   ;# => apple 6 banana 4 cherry 10

# lookup with a default (Eagle has no dict getdef)
expr {[dict exists $prices pear] ? [dict get $prices pear] : 0}   ;# => 0
```

Depth: [`commands/dict.md`](commands/dict.md) (every sub-command, the
auto-create gotcha, `dict map` empty-result behavior).

## Recipe: Hash a string / base64 encode-decode

`[hash normal]` produces a digest as **UPPERCASE hex**; `[hash mac]` is keyed
HMAC with the argument order `algorithm data ?key?`. `[base64]` round-trips text.
(Neither command exists in stock Tcl — both wrap the .NET BCL.)

```tcl
hash normal sha256 "abc"        ;# => BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD
hash normal md5    "abc"        ;# => 900150983CD24FB0D6963F7D28E17F72

# HMAC: algorithm, then DATA, then KEY (easy to swap)
hash mac HMACSHA256 "message" "key"
;# => 6E9EF29B75FFFC5B7ABAE527D58FDADB2FE42E7219011976917343065F58ED4A

# base64 round-trip
set enc [base64 encode "Hello, Eagle!"]   ;# => SGVsbG8sIEVhZ2xlIQ==
base64 decode $enc                          ;# => Hello, Eagle!
```

Depth: [`commands/data-net.md`](commands/data-net.md#hash) (algorithms list,
`-raw`/`-filename`, the HMAC argument-order trap).

## Recipe: HTTP GET (requires network)

The `[uri]` command's network operations (`get`, `download`, `post`, `upload`,
`ping`) need an Eagle built with the `NETWORK` flag **and** live connectivity, so
the transfer below is **not executed here** — the idiom is shown verbatim, with
no faked output:

```tcl
# requires network -- NOT run in this offline verification
set body [uri get https://example.com/]            ;# inline GET, returns the body
uri download https://example.com/file.zip /tmp/file.zip   ;# GET to a file
uri post -data {key value other thing} -- https://example.com/submit
```

The URI **utility** ops are always available and *are* verified offline, which
confirms the command surface without a network round-trip:

```tcl
info commands uri                            ;# => uri
uri isvalid https://example.com/ Absolute    ;# => True
uri scheme https                             ;# => True
uri offline                                  ;# => False   (reference-counted switch)
```

Depth: [`commands/data-net.md`](commands/data-net.md#uri) and the deep dive
[`../../../uri.md`](../../../uri.md) (inline vs file mode, `-callback` async transfers,
retry/offline infrastructure).

## Recipe: Simple regex extract and replace

`[regexp]` matches/extracts; `[regsub]` substitutes. Both use the .NET engine but
default to `.`-matches-newline (**Singleline**) — same as every Tcl version, the
opposite of .NET's own default. Pass `-linestop` (or `-line`) to make `.` stop at
newlines.

```tcl
regexp -inline -all {\d+} "a1b22c333"        ;# => 1 22 333

# capture groups into variables
regexp {(\w+)@(\w+)} "user@host.com" all user host
list $user $host                             ;# => user host

regsub -all {[aeiou]} "Hello World" *        ;# => H*ll* W*rld
regsub {(\w+) (\w+)} "John Doe" {\2, \1}     ;# => Doe, John

# '.' spans the newline by default ...
regexp -inline {.+} "line1\nline2"           ;# => {line1<newline>line2}  (the whole string)
# ... unless you ask it not to
regexp -inline -linestop {.+} "line1\nline2" ;# => line1
```

Depth: [`commands/strings.md`](commands/strings.md#regexp) (Eagle switches,
`-eval`/`-command`/`-extra`, `***=` literal prefix) and
[`../../../regexp.md`](../../../regexp.md).

## Recipe: Build, split, and join strings

`[split]` turns a string into a list; `[join]` turns a list back into a string;
`[append]` grows a string in place; `[string cat]` and `[format]` compose. (Empty
fields are preserved by `split`, like Tcl.)

```tcl
set parts [split "a,b,c,d" ,]                ;# => a b c d
llength $parts                               ;# => 4
join $parts |                                ;# => a|b|c|d

# grow a string with append
set s ""; foreach p $parts {append s "<$p>"}; set s   ;# => <a><b><c><d>

string cat foo bar baz                       ;# => foobarbaz
format "%s has %d items" cart 3              ;# => cart has 3 items
```

Depth: [`commands/strings.md`](commands/strings.md) (`string`/`format`/`subst`/
`encoding`) and [`commands/lists.md`](commands/lists.md) (`split`/`join`/`concat`).

## Recipe: Define a proc with defaults and `args`, organize with namespaces

`proc name args body`: bare names are required, `{name default}` supplies a
default, and a trailing `args` collects the rest as a list. Group related
commands in a `namespace` and `export`/`import` them.

```tcl
proc greet {name {greeting Hello} args} {
    set extra ""
    if {[llength $args]} then {set extra " ([join $args {, }])"}
    return "$greeting, $name!$extra"
}
greet World                                  ;# => Hello, World!
greet World Hi                               ;# => Hi, World!
greet World Hi a b c                         ;# => Hi, World! (a, b, c)

namespace eval math {
    namespace export square
    proc square {x} {expr {$x * $x}}
    proc cube   {x} {expr {$x * $x * $x}}
}
math::square 9                               ;# => 81   (fully qualified)
namespace import math::*
square 12                                    ;# => 144  (after import)
math::cube 3                                 ;# => 27   (not exported; call qualified)
```

To splat a list into a proc's arguments, remember Eagle has **no `{*}`** — use
`eval` + `list` (`eval greet [list World Hi]`).

Depth: [`commands/procs-namespaces.md`](commands/procs-namespaces.md) (`apply`,
named-argument `nproc`/`napply`, `uplevel`, `scope`, the full `namespace`
ensemble).
