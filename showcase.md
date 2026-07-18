# Eagle Showcase -- Things You Can Do in Eagle That You Cannot Do in Tcl

> **For AI agents**: This is a curated "greatest hits" gallery, not a reference
> manual. Each section is a self-contained demonstration of a capability that is
> unique to Eagle (or that Eagle does very differently from stock Tcl). For the
> full command syntax behind any example, follow the cross-reference links. Core
> language: [core_language.md](core_language.md). CLR interop:
> [object.md](object.md). Sandboxing: [safe.md](safe.md). Databases:
> [sql.md](sql.md). Native Tcl bridge: [tcl.md](tcl.md). Eagle-inside-Tcl:
> [garuda.md](garuda.md). A gentle guided path is [tutorial.md](tutorial.md).

Eagle (Extensible Adaptable Generalized Logic Engine) is a Tcl-compatible
scripting language that runs on the .NET CLR. Because it *is* a .NET program,
and because it keeps Tcl's semantics rather than merely imitating its syntax, it
can do a class of things that a stock `tclsh` cannot do at all. This document
collects the most striking of them.

Results shown with `;# =>` in sections 1 through 6 were executed against a live
interpreter and pasted back in. The Harpy signing examples (section 7) are quoted
from Harpy's own test suite -- the `SignedOk` / `VerifiedOk` tokens and keyring
output shown are exactly what those tests assert. The cross-runtime bridge
examples (section 8) use the exact command surface documented in
[tcl.md](tcl.md) and [garuda.md](garuda.md).

---

## 1. One Engine, Two Worlds

The thesis of everything below: a single Eagle interpreter speaks **Tcl** to your
scripts and **CLR** to the rest of .NET, at the same time, with no marshalling
layer you have to write. A list is a Tcl list *and* it is a value the CLR can
see. A command can be a Tcl proc *or* a C# method you compiled thirty
milliseconds ago. That duality is what makes each of the following possible.

```tcl
puts [expr {2 ** 10}]                                  ;# => 1024      (Tcl world)
puts [object invoke System.Math Sqrt 144.0]            ;# => 12        (CLR world)
```

Same interpreter, same line of thinking, two universes.

---

## 2. Call the Entire .NET Framework From a Script

Stock Tcl reaches the outside world through `exec`, `load`-ed C extensions, and
channels. Eagle reaches it through the [`object`](object.md) command, which is a
live gateway to every type the CLR can load -- the base class library, your own
assemblies, third-party NuGet packages, anything.

```tcl
# Create a StringBuilder and drive it as if it were a Tcl command.
set sb [object create -alias System.Text.StringBuilder]
$sb Append "Hello, "
$sb Append "Eagle!"
puts [$sb ToString]                                    ;# => Hello, Eagle!
puts [$sb Length]                                      ;# => 13

# Call a static method directly -- no instance required.
puts [object invoke System.Math Sqrt 144.0]            ;# => 12

# Work with real .NET value types.
set now [object invoke -create System.DateTime Now]
puts [object invoke $now Year]                         ;# => 2026
```

The `-alias` option is the idiom worth remembering: it binds the object handle to
a command so that method calls read like ordinary Tcl -- `$sb Append ...` instead
of `object invoke $sb Append ...`. Aliased commands still accept every
`[object invoke]` option; they are merged in automatically. See
[object.md](object.md) for the complete surface (properties, indexers, events,
delegates, generics, `-marshalflags`, and lifetime management).

Why this matters: there is no glue code, no SWIG, no P/Invoke signatures to hand
-author. If .NET can express it, an Eagle script can call it.

---

## 3. Compile C# at Runtime and Call It Immediately

Eagle ships a C# compiler bridge in its script library. A script can hand it a
block of C# source, get back a loaded assembly, and invoke the freshly minted
type in the very next command -- all in-memory, no build step, no files on disk.

```tcl
set code {
  public static class Widget {
    public static int Triple(int x) { return x * 3; }
  }
}

# compileCSharp: source, in-memory?, symbols?, strict?, resultsVar, errorsVar
set rc [compileCSharp $code true false true results errors]
puts [lindex $rc 0]                                    ;# => Ok

# The type is now loadable like any other CLR type.
puts [object invoke Widget Triple 14]                  ;# => 42
```

This is genuine runtime metaprogramming across a language boundary: a Tcl-style
script generating, compiling, and executing C#. It is the foundation for Eagle's
test tooling and for scenarios where the fast path needs to drop into statically
typed, JIT-compiled code. The dispatcher (`compileCSharp`) automatically targets
the desktop CodeDom provider or the .NET Core command-line compiler as
appropriate, so the same script works on .NET Framework, .NET Core, and .NET 5+.

---

## 4. Arithmetic That Behaves, and Math Notation You Can Read

Two things set Eagle's `[expr]` apart: it computes in **base-10 decimal**, and it
accepts a palette of operators, functions, and even Unicode symbols that Tcl
never had.

### 4.1 Decimal money math

```tcl
puts [expr {0.1 + 0.2}]                                ;# => 0.3      (not 0.30000000000000004)
puts [expr {0.1 + 0.2 == 0.3}]                         ;# => True
puts [expr {19.99 * 3}]                                ;# => 59.97    (exact)
```

Because Eagle's floating literals are `System.Decimal`, the classic binary-float
surprises simply do not happen. For anything that touches currency, this is the
difference between a correct ledger and a rounding bug. (See
[tutorial.md](tutorial.md) Lesson 3 for the full treatment, including 32-bit
integer wrap and the absence of automatic bignum promotion.)

### 4.2 Operators Tcl does not have

Eagle adds a set of operators that error out in a stock `tclsh`:

```tcl
puts [expr {1 ^^ 0}]                                   ;# => True     (logical XOR)
puts [expr {12 -> 10}]                                 ;# => -5       (bitwise implication)
puts [expr {12 <-> 10}]                                ;# => -7       (bitwise equivalence)
puts [expr {1 <<< 1}]                                  ;# => 2        (bit rotate-left)
puts [expr {"y" := 5}]                                 ;# => 5        (in-expression assignment)
```

The full Eagle-only set: logical `^^` / `=>` / `<=>` (xor / implication /
equivalence), bitwise `->` / `<->`, rotates `<<<` / `>>>`, string-ordering
`lt` / `gt` / `le` / `ge`, and the in-expression assignment `:=` (whose target is
a quoted name). See [core_language.md](core_language.md) for the precedence table.

### 4.3 Functions Tcl does not have

```tcl
puts [expr {log2(8)}]                                   ;# => 3
puts [expr {sign(-5)}]                                  ;# => -1
puts [expr {logx(1000, 10)}]                            ;# => 2.9999999999999996
```

Genuinely Eagle-only functions include `log2`, `logx`, `sign`, `truncate`,
`pi()`, `e()`, the cryptographically strong `random` / `randstr`, and the type
helpers `typeof` / `decimal` / `datetime` / `timespan`. (Note that the IEEE
classifiers `isnan` / `isinf` / `isfinite` / `isnormal` / `issubnormal` /
`isunordered` are *not* Eagle inventions -- they entered Tcl via TIP 521 in
Tcl 8.7 -- so they are omitted from the "unique" list here.)

### 4.4 Unicode math symbols as first-class values

This is pure Eagle: three Unicode mathematical constants are recognized directly
inside `[expr]`.

```tcl
# (obtain the literal symbols; typed inline they are just characters)
set inf [format %c 0x221E]   ;# INFINITY
set pi  [format %c 0x03C0]   ;# GREEK SMALL LETTER PI
set eul [format %c 0x2107]   ;# EULER CONSTANT

puts [expr "$inf > 1000000"]                            ;# => True
puts [expr "$inf + 1"]                                  ;# => ∞      (still infinity)
puts [expr "$pi * 2"]                                   ;# => 6.283185307179586
puts [expr "$pi == pi()"]                               ;# => True
puts [expr "$eul * 2"]                                  ;# => 5.43656365691809
puts [expr "$eul == e()"]                               ;# => True
```

A lone symbol is preserved *as the symbol*; the moment it enters arithmetic it
takes its numeric value -- exactly the way the numeric literals in §4.1 behave.
No other Tcl-family language lets you write `π * 2` in an expression.

---

## 5. A Real Sandbox in Three Lines

Eagle's [safe interpreter](safe.md) is a genuine capability-based sandbox, not a
convention. A safe child interpreter starts with every dangerous command removed;
you then hand back exactly the capabilities you choose, as aliases into the
parent. Untrusted code runs with precisely the authority you granted and no more.

```tcl
# A capability the sandbox is allowed to use, implemented in the trusted parent.
proc auditLog {msg} { return "LOGGED: $msg" }

set safe [interp create -safe]
interp alias $safe log {} auditLog                     ;# expose ONE capability

puts [interp eval $safe {log {sandboxed event}}]       ;# => LOGGED: sandboxed event

# Everything dangerous is already gone:
catch {interp eval $safe {exec ls}} m
puts $m         ;# => permission denied: safe interpreter cannot use command "exec"
catch {interp eval $safe {open /etc/passwd}} m
puts $m         ;# => permission denied: safe interpreter cannot use command "open"

interp delete $safe
```

The pattern -- *deny by default, grant explicitly via aliases* -- is the same
mechanism Eagle uses for multi-tenant hosting: each tenant gets its own safe
interpreter (optionally in its own AppDomain via `-isolated`), sees only the
commands you aliased in, and cannot reach the filesystem, the process table, or
another tenant's state.

Pair it with Eagle's rich input validators to police what crosses the boundary:

```tcl
puts [string is guid   3F2504E0-4F89-41D3-9A0C-0305E82C3301]   ;# => True
puts [string is base64 SGVsbG8=]                               ;# => True
puts [string is number 6.022e23]                               ;# => True
puts [string is inetaddr 10.0.0.1]                             ;# => True
puts [string is uri http://example.com/]                       ;# => True
```

Eagle extends `[string is]` well past Tcl's classes -- `guid`, `base64`,
`inetaddr`, `uri`, `path`, `version`, `list`, `dict`, and more -- so validating
untrusted input is a one-liner rather than a regex you have to get right.

---

## 6. Talk to a Database Without Leaving the Script

The [`sql`](sql.md) command is a full ADO.NET bridge. Any provider the CLR can
load -- SQLite, SQL Server, ODBC, a custom `DbProviderFactory` -- is reachable
with the same handful of verbs.

```tcl
set db [sql open -type SQLite "Data Source=:memory:"]

sql execute -execute NonQuery $db "CREATE TABLE t (n INTEGER);"
sql execute -execute NonQuery $db "INSERT INTO t VALUES (7), (35);"

puts [sql execute -execute Scalar $db {SELECT SUM(n) FROM t}]         ;# => 42
puts [sql execute -execute Reader -format list $db {SELECT n FROM t ORDER BY n}]
                                                                     ;# => 7 35

sql close $db
```

Parameterized queries, transactions, and several result shapes (`list`,
`nestedlist`, `dictionary`, `array`, plus `sql foreach` for streaming) are all
documented in [sql.md](sql.md). No native `.so`, no separate driver package to
compile -- if a .NET data provider exists, Eagle can drive it.

---

## 7. Sign and Verify Scripts (Harpy)

Eagle's Enterprise Edition ships **Harpy**, a plugin that brings public-key
digital signatures to scripts: you can prove a script has not been tampered with,
and refuse to run one that fails verification. There are two tiers -- a simple
detached-signature path and a full script-certificate subsystem.

> Harpy is loaded via `package require Licensing.Enterprise`. The examples in this
> section are taken from Harpy's own test suite
> (`Plugins/Commercial/Enterprise/Harpy/Tests/basic.eagle`) and signing tool
> (`Tools/b64sign.eagle`); the success tokens shown (`SignedOk`, `VerifiedOk`)
> are the literal strings those operations return. The core signing primitives
> here are also live-verified: `certificate signhash` followed by
> `certificate verifyhash` returns `VerifiedOk`, tampered data makes
> `verifyhash` raise `could not verify hash`, and `keyring clear` returns the
> empty string -- all confirmed against a running interpreter.

### 7.1 Tier 1 -- detached signatures with `b64sign` and `[ksource]`

The simplest workflow: sign a script file, producing a **detached** `.b64sig`
sidecar next to it, then load the script with [`ksource`](load.md) -- the signed
analog of `[source]`, which reads the file, verifies its signature, and only then
evaluates it.

The signing tool `b64sign.eagle` hashes the file's bytes and RSA-signs the hash:

```tcl
# --- excerpt from Tools/b64sign.eagle ---
set data      [object invoke -create System.IO.File ReadAllBytes $scriptFileName]
set signature [certificate signhash -create $privateKey $data]
set signatureText [object invoke Convert ToBase64String $signature InsertLineBreaks]
object invoke System.IO.File WriteAllText $signatureFileName \
    [appendArgs $signatureText \r\n]
```

It writes `<scriptName>.b64sig`, a self-describing file: a header comment block
that names the file and the signing key's public-key token, followed by the
base-64 signature body. A produced signature file begins:

```
###############################################################################
#
# use_ksource.eagle.b64sig -- 26f17c3a1a544324
#
# Extensible Adaptable Generalized Logic Engine (Eagle)
# Enterprise Edition Script Signature File (Harpy)
# ...
###############################################################################

  U2CnCSDBeCowCFgqXKkII7iHYbfwOrwkKzVlbYhGy3kUWhQHOZF+rLRBU4zdiH/dSiB...
```

Consuming a signed script is then one command -- if the signature does not verify,
the script never runs:

```tcl
# --- excerpt from Tests/data/use_ksource.eagle ---
ksource -withcommands -useplugin -usecontext -- \
    [file join [file dirname [info script]] dump_sandbox.eagle]
```

`ksource` derives the `.b64sig` filename automatically, reads the detached
signature, verifies the script bytes against it, and evaluates the script only on
success. This is the ideal building block for "load only code we signed."

### 7.2 Tier 2 -- the full script-certificate subsystem

For richer policy -- expiry dates, vendor identity, revocation, hash-algorithm
choice, embedded metadata -- Harpy provides the `[certificate]` command ensemble
and full `.harpy` certificate files. A certificate is an XML document carrying the
signature plus its governing fields:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Eagle Enterprise Edition Script Certificate ... -->
<Certificate xmlns="https://eagle.to/2011/harpy">
  <Vendor>Mistachkin Systems</Vendor>
  <Id>cb217cac-f09e-4ff8-b651-56aad890ec74</Id>
  <HashAlgorithm>SHA512</HashAlgorithm>
  <EntityType>Script</EntityType>
  <TimeStamp>2023-03-09T17:23:56.1586190Z</TimeStamp>
  <Duration>-1.00:00:00</Duration>          <!-- unlimited -->
  <Key>0x9559f6017247e3e2</Key>
  <Signature>o3CGnMWIHV51ZWNSzQsKgkQ2O84xC4OxNEaJBRX/plq...</Signature>
</Certificate>
```

The canonical import / sign / verify flow, straight from the test suite:

```tcl
# --- Tests/basic.eagle, test harpy-2.4 ---
package require Licensing.Enterprise

set publicKey   [keypair open -alias -public $publicKeyFile(1)]
set privateKey  [keypair open -alias -public -private $privateKeyFile(1)]
set certificate [certificate import -alias -validate $importFile]

certificate sign -setid -settimestamp -setkey $certificate $privateKey
                                                       ;# => SignedOk
certificate verify $certificate $publicKey             ;# => VerifiedOk
```

`sign` returns the literal token `SignedOk`; `verify` returns `VerifiedOk` on
success and *raises an error* on failure (an expired key, for instance, produces
`public key token "0x..." is expired as of "..."`). The ensemble is broad --
`sign` / `signfile` / `signhash` / `signstring`, the matching `verify*` verbs,
`import` / `export`, `hashfile` / `hashstring`, and a full policy subsystem
(`defaultpolicy`, `scriptflags`, `networkflags`, ...). `certificate source` is the
full-form equivalent of `[ksource]`.

### 7.3 Managing trust with `[keyring]`

Verification needs the *right public keys* on hand. The `[keyring]` command
manages the in-memory set of trusted key pairs -- load them from a file, merge
several sources, inspect what is trusted, clear it out:

```tcl
# --- Tests/basic.eagle, test harpy-16.1 ---
keyring clear                          ;# empty the keyring        -> {}
keyring merge $keyRingFile(1)          ;# load + merge a key file  -> {}
keyring script                         ;# dump name/token pairs:
        ;# => EagleEnterprisePluginRootPublic.snk 8bf43b4749e46a0b
        ;#    TestPrivate1.snk 9c6c559394030af1 ...
keyring clear                          ;# start clean again        -> {}
```

`keyring merge` folds a keyring file's key pairs into the active set (returning
empty on success); `keyring clear` empties it; `keyring script` reports the
trusted keys as a flat `name token name token ...` list. Other subcommands cover
embedded/assembly keys, persistence (`save` / `restore`), and metadata. Together
with the signing verbs above, the keyring is how you decide *whose* signatures
your interpreter will accept.

---

## 8. Bridge Native Tcl and Eagle -- Both Directions

Eagle and a native `tclsh` are not rivals; they can run in the same process and
call each other. This is unique to Eagle: it is the only Tcl-family engine that
sits on the CLR *and* can host, or be hosted by, a stock Tcl interpreter.

### 8.1 Eagle calling native Tcl -- the `[tcl]` command

From inside Eagle, the [`tcl`](tcl.md) command loads a native Tcl library and
evaluates Tcl code in it. Useful when you need a genuine Tcl extension (Tk, an
old package with no .NET equivalent) while keeping Eagle as the driver.

```tcl
tcl load                               ;# locate + load a native libtcl
set i [tcl primary]                    ;# the primary native interpreter
puts [tcl eval $i {expr 3 * 9}]        ;# 27, computed by native Tcl
puts [tcl eval $i {info patchlevel}]   ;# the native Tcl version, e.g. 8.6.x
tcl unload
```

`tcl find` reports which native libraries Eagle can see; `tcl create`, `tcl set`,
`tcl expr`, `tcl queue`, and the rest of the ensemble round out a full embedding
API. (Requires a compatible native Tcl installation; see [tcl.md](tcl.md) for
discovery flags and threading rules.)

### 8.2 Native Tcl calling Eagle -- Garuda

The mirror image is **Garuda**, a native Tcl package that loads *Eagle* into a
stock `tclsh`. Now a plain Tcl script gains a bridge to the entire CLR:

```tcl
package require Garuda

# A brand-new command, "eagle", now evaluates Eagle script from Tcl:
set now [eagle {object invoke System.DateTime Now}]
puts "the CLR says it is [eagle {clock format [clock seconds]}]"

# The "garuda" ensemble controls the bridge:
puts [garuda clrversion]                       ;# e.g. v4.0.30319 or a Core version
garuda control require Licensing.Enterprise    ;# pull in an Eagle package
```

So a legacy Tcl application can adopt .NET incrementally -- no rewrite, just
`package require Garuda` and an `eagle` command. See [garuda.md](garuda.md) for
the full ensemble (`clrload` / `clrstart` / `clrexecute` / `startup` / `control`
/ `detach` / ...), the two-way nesting model, and the build layout.

Two engines, one process, calls flowing both ways. That symmetry is the clearest
statement of what Eagle is: Tcl and .NET, all the way down, in either direction.

---

## Where to Go Next

- **Learn it in order** -- [tutorial.md](tutorial.md) (for Tcl programmers) and
  the [quick_start_guide.md](quick_start_guide.md).
- **Embed it in C#** -- [embedding.md](embedding.md): interpreters, threading,
  sandboxing, and rule sets from the host side.
- **Go deep on a command** -- [object.md](object.md), [sql.md](sql.md),
  [safe.md](safe.md), [tcl.md](tcl.md), [garuda.md](garuda.md).
- **Reference everything** -- [core_language.md](core_language.md) and
  [core_examples.md](core_examples.md).
