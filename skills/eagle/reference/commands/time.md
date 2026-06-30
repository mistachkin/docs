# Commands: Time & Clocks

`clock` · `time`

All **fixed-input** examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Wall-clock values (`clock seconds`, `clock now`, `[time]` timings, ...) change
on every run, so those are **described**, never pinned to a `;# =>`. Every fixed
example uses a deterministic input — epoch `0`, a fixed Unix time, or a fixed
date string with **`-gmt 1`** — so the output does not depend on the machine's
local time zone. Cross-cutting Tcl differences live in
[`../tcl-gotchas.md`](../tcl-gotchas.md). For the internals (the Tcl→.NET format
translation layer, every delegate specifier, epoch management, performance
counters, fake-time injection), see the deep-dive [`../../../../clock.md`](../../../../clock.md).

> Reminder: `clock isvalid` returns **`True`/`False`**, not `1`/`0` (gotcha #1).
> It works fine as a condition; just never string-compare it to `"1"`.

---

## `clock` — a 15-sub-command ensemble

`clock` is an ensemble. The **complete** sub-command set (authoritative, from the
generated inventory) is:

```
buildnumber  clicks   days      duration  filetime
format       isvalid  microseconds        milliseconds
monthdays    now      scan      seconds   start   stop
```

Only `seconds`, `milliseconds`, `microseconds`, `clicks`, `format`, `scan` are
"standard Tcl"; the rest are **Eagle extensions** (`now`, `start`/`stop`,
`buildnumber`, `days`, `duration`, `filetime`, `isvalid`, `monthdays`). An
unknown sub-command lists the legal set:

```tcl
catch {clock add 0 1 day} m ; set m
;# => bad option "add": must be buildnumber, clicks, days, duration, filetime,
;#    format, isvalid, microseconds, milliseconds, monthdays, now, scan,
;#    seconds, start, or stop
```

> **No `clock add`.** Unlike Tcl 8.5+, Eagle has **no `clock add`** sub-command.
> Do calendar arithmetic on the integer seconds from `[clock scan]` /
> `[clock seconds]` (e.g. `expr {$t + 86400}` for "+1 day"), or build a
> `System.DateTime` via `[object]` and call `AddMonths` / `AddDays`.

### Current time (wall-clock — described, not pinned)

```tcl
clock seconds ?epoch?          ;# whole seconds since the Unix epoch (1970-01-01 UTC)
clock milliseconds ?epoch?     ;# milliseconds since the epoch
clock microseconds ?epoch?     ;# microseconds since the epoch
clock now ?-gmt boolean?       ;# Eagle ext: current time as .NET DateTime.Ticks
clock clicks ?-milliseconds? ?-microseconds?   ;# high-resolution counter
```

Each returns a wide integer (verified: `string is wideinteger [clock seconds]`
→ `True`, likewise for the others). Their *magnitude* depends on the moment you
call them, so they have no fixed output. `clock now` returns .NET ticks
(100-ns units since 0001-01-01), a much larger number than `clock seconds`.
`clock clicks` with no option is a raw performance-counter value that is only
meaningful as a *difference* — for portable elapsed timing use `clock start` /
`clock stop` (below).

### `clock format` — value → string

`clock format clockValue ?-format str? ?-gmt bool? ?-epoch date? ?-kind k? ?-ticks? ?-iso? ?-full? ?-isotimezone?`

The clock value is **seconds since the epoch** (or .NET ticks with `-ticks`).
`-gmt 1` formats in UTC; the default is local time. Pinning the input to epoch
`0` (1970-01-01 00:00:00 UTC) and a fixed Unix time keeps every result
deterministic:

```tcl
clock format 0 -gmt 1 -format %Y-%m-%d            ;# => 1970-01-01
clock format 0 -gmt 1 -format {%H:%M:%S}          ;# => 00:00:00
clock format 0 -gmt 1 -format %A                  ;# => Thursday
clock format 1234567890 -gmt 1 -format {%Y-%m-%d %H:%M:%S}
                                                  ;# => 2009-02-13 23:31:30
clock format 1234567890 -gmt 1 -format %A         ;# => Friday
```

A **blank** `-format` returns the empty string (Tcl compatibility):

```tcl
clock format 0 -gmt 1 -format {}                  ;# => (empty)
```

#### Format specifiers (Tcl `%`-style → .NET)

Eagle translates Tcl's `%`-specifiers to .NET `DateTime` patterns. Simple ones
(`%Y %m %d %H %M %S %A %B %a %b %p %T %R %D %x %X` ...) are static substitutions;
"computed" ones (`%s %j %V %G %u %w %U %W %C %e %k %l %Z %Q`) run through
callbacks. The full table is in [`../../../../clock.md`](../../../../clock.md). A verified
sampling (all at epoch 0, UTC):

```tcl
clock format 0 -gmt 1 -format %j                  ;# => 001   (day of year)
clock format 0 -gmt 1 -format %V                  ;# => 01    (ISO 8601 week)
clock format 0 -gmt 1 -format {%u %w}             ;# => 4 4   (see note below)
clock format 0 -gmt 1 -format %s                  ;# => 0     (seconds since epoch)
clock format 0 -gmt 1 -format {%I%p}              ;# => 12AM  (12-hour clock)
clock format 0 -gmt 1 -format {%e/%m}             ;# =>  1/01 (%e is space-padded)
clock format 0 -gmt 1 -format %Q                  ;# => Stardate 24000.0
```

`%u` is the ISO weekday (Monday=1 … Sunday=7); `%w` is Sunday=0 … Saturday=6 —
they coincide at 4 only because 1970-01-01 was a **Thursday**. `%Q` is the
Tcl-compatible Star Trek stardate (a genuine, novelty Tcl feature).

#### Verified Tcl parity / divergence (`tcl-oracle.sh`, fixed inputs)

The common specifiers are **identical** to Tcl 8.4/8.5/8.6 — verified for
`%Y %m %d %H %M %S %A %B %j %V %u %w %T` and the full
`clock format 1234567890 -gmt 1 -format {%Y-%m-%d %H:%M:%S %A}` →
`2009-02-13 23:31:30 Friday`. A few specifiers track Eagle's **Tcl 8.4 baseline**
and so differ from 8.5/8.6:

| Fixed input | Eagle | Tcl 8.4 | Tcl 8.5 / 8.6 |
|-------------|-------|---------|---------------|
| `clock format 0 -gmt 1 -format %Z` | `UTC` | `UTC` | `GMT` |
| `clock format 0 -gmt 1 -format %D` | `01/01/70` | `01/01/70` | `01/01/1970` |
| `clock format 0 -gmt 1 -format %s` | `0` | *local-offset*¹ | `0` |

¹ Tcl 8.4's `%s` ignored `-gmt` and added the machine's *local* offset (so the
value varies by time zone — e.g. `18000` at UTC−5); Eagle honors `-gmt` and
matches 8.5/8.6 with `0`. `%Z`/`%D` follow the 8.4 form. There is
**no `-locale` option** on `clock format` (despite some prose suggesting one):
the legal options are `-format -kind -ticks -epoch -gmt -iso -full -isotimezone`;
culture comes from the interpreter's `CultureInfo`.

### `clock scan` — string → seconds

`clock scan dateString ?-format str? ?-base clockVal? ?-epoch date? ?-gmt bool?`

Returns seconds since the epoch. With `-gmt 1` the input is read as UTC, so the
result is fixed:

```tcl
clock scan 1970-01-01 -gmt 1                       ;# => 0
clock scan {2009-02-13 23:31:30} -gmt 1            ;# => 1234567890
clock scan 2020-01-01 -gmt 1                       ;# => 1577836800
clock scan 02/13/2009 -gmt 1                       ;# => 1234483200
clock scan {Jan 15, 2024} -format {%b %d, %Y} -gmt 1
                                                  ;# => 1705276800
```

`scan` round-trips `format`: `clock scan {2009-02-13 23:31:30} -gmt 1` →
`1234567890` (identical in Eagle and Tcl 8.4/8.5/8.6).

> **No free-form / natural-language dates.** Eagle's `[clock scan]` parses
> **absolute** forms only (ISO, `MM/DD/YYYY`, time-of-day, month-name, epoch
> seconds). Tcl's legacy relative grammar is **not** supported:
>
> ```tcl
> catch {clock scan tomorrow} m ; set m
> ;# => unable to convert date-time string "tomorrow"
> catch {clock scan {+1 week}} m ; set m
> ;# => unable to convert date-time string "+1 week"
> ```
>
> Compute relative times with arithmetic on `[clock seconds]` instead
> (`expr {[clock seconds] + 7*86400}`). The `-base` option supplies the
> date components *absent* from the input (e.g. a time-only string takes its
> date from the base); for full `-base` semantics use the `-format` path.

### `clock isvalid` / `monthdays` / `days`

```tcl
clock isvalid 2024-02-29                           ;# => True   (2024 is a leap year)
clock isvalid 2025-02-29                           ;# => False  (2025 is not)
clock monthdays 2                                  ;# => 28     (current/Feb, leap-aware)
clock days -epoch 1970-01-01 -gmt 1 2020-01-01     ;# => 18262  (elapsed days)
```

`clock monthdays` with no argument uses the *current* month, so that form is
not fixed; `clock monthdays 2` is February. `clock days` counts whole days from
its `-epoch` (here the Unix epoch) to the date.

### `clock duration` — span between two dates

`clock duration ?-flags durationFlags? startDate endDate`

The default renders a .NET `TimeSpan`; `-flags Human` renders an approximate
human string. The dates are parsed in **local** time (no `-gmt` option), so use a
DST-free, whole-day span to stay deterministic:

```tcl
clock duration 2020-01-01 2020-01-02               ;# => 1.00:00:00   (TimeSpan: 1 day)
```

`clock duration -flags Human 2020-01-01 2023-06-15` returns an approximate
phrase (observed `approximately 3, 166`) — its exact wording is informal and
not worth pinning; reach for the default `TimeSpan` form when you need an exact,
parseable value.

### `clock buildnumber` / `filetime` (Eagle extensions)

```tcl
clock buildnumber -epoch 2000-01-01 -gmt 1 2020-01-01   ;# => 7305 0
clock filetime 116444736000000000 -gmt 1 -format %Y-%m-%d
                                                        ;# => 1970-01-01
```

`buildnumber` returns `{days revision}` — days since the (default 2000-01-01)
build epoch plus a revision derived from the time of day — suitable for MSBuild
`major.minor.build.revision` versioning. `filetime` converts a Windows FILETIME
(100-ns units since 1601-01-01); `116444736000000000` is the Unix epoch.

### ISO 8601 and .NET ticks

```tcl
clock format 1234567890 -gmt 1 -iso                ;# => 2009.02.13T23:31:30.000
clock format 1234567890 -gmt 1 -iso -full          ;# => 2009-02-13T23:31:30.0000000Z
clock format 621355968000000000 -ticks -gmt 1 -format %Y-%m-%d
                                                  ;# => 1970-01-01
```

`-iso` uses dotted-date, millisecond precision; `-iso -full` uses dashed-date,
100-ns precision with a trailing `Z` for UTC. `-ticks` reinterprets the input as
.NET ticks (`621355968000000000` is the tick count for 1970-01-01), so it pairs
with `clock now`.

### Custom epochs

`-epoch` takes a **date string** (not a seconds value) and shifts the zero point.
The clock value is then measured from that epoch:

```tcl
clock format 0 -epoch 2020-01-01 -gmt 1 -format {%Y-%m-%d %H:%M:%S}
                                                  ;# => 2020-01-01 00:00:00
clock format 86400 -epoch 2020-01-01 -gmt 1 -format %Y-%m-%d
                                                  ;# => 2020-01-02   (one day later)
```

> Passing **seconds** to `-epoch` (e.g. `-epoch [clock scan ...]`) is a common
> mistake: the integer is parsed as a date near year 1, not the date you meant.
> Give `-epoch` a date string.

### High-resolution timing — `clock start` / `clock stop` (Eagle extension)

`clock start` returns an opaque performance-counter token; `clock stop` takes
that token and returns the **elapsed microseconds** since it was taken (verified:
the result `string is wideinteger` → `True`). There is no fixed output — it is a
live measurement:

```tcl
set t [clock start]
# ... work to measure ...
set us [clock stop $t]      ;# elapsed microseconds (a wide integer)
puts "took $us us"
```

`clock stop` is deliberately exempt from timing side-channel mitigation so the
measurement stays accurate. In **safe** interpreters the high-resolution / live
sub-commands (`clicks`, `microseconds`, `milliseconds`, `now`, `start`, `stop`)
are blocked; `format`, `scan`, `seconds`, `isvalid`, `monthdays`, `days`,
`duration`, `filetime`, `buildnumber` remain allowed.

---

## `time` — micro-benchmark a script

`time script ?count? ?options?`

Runs `script` `count` times (default `1`) and returns the **average** as the
string `"N microseconds per iteration"`. `N` is a live timing, so it changes
every run and is fractional when `count > 1` (the total is divided by `count`):

```tcl
time {expr {1 + 1}} 1000     ;# => e.g. "30.34 microseconds per iteration"
time {set x 1}               ;# => e.g. "119 microseconds per iteration" (count defaults to 1)
```

Because the number is wall-clock dependent, never pin it with `;# =>`; treat
only the *shape* `"<number> microseconds per iteration"` as guaranteed. Pull the
number out for comparisons with `lindex`:

```tcl
lindex [time {expr {1 + 1}} 1000] 0   ;# the numeric average alone
```

Eagle adds options (e.g. `-statistics`, `-timeout`, `-errorOk`, `-noCancel`) for
richer benchmarking; for one-off relative timing the plain `time script count`
form is what you want. For measuring a region of code rather than a repeatable
script, use the `clock start` / `clock stop` pair above.
