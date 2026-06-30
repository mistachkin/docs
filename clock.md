# Eagle `[clock]` Command: Deep-Dive Analysis of Time Operations, Format Translation, and Performance Timing

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[clock]` command internals, including the 15 sub-commands, the Tcl-to-.NET format string translation layer (static mappings and dynamic delegates), custom epoch support, the `ClockData` / `IClockData` interface, high-resolution performance counters, ISO 8601 formatting modes, fake time injection for testing, and the `TimeOps` / `FormatOps` infrastructure. For basic command syntax, see [`core_language.md`](core_language.md#cmd-clock). For usage examples, see [`core_examples.md`](core_examples.md#ex-clock).

## 1. Executive Summary

Eagle's `[clock]` command provides **Tcl-compatible date/time operations**
powered by .NET's `System.DateTime`, `System.TimeZone`, and
`System.Globalization.CultureInfo` infrastructure. It supports the
standard Tcl sub-commands (`[format]`, `scan`, `seconds`, `clicks`) while
adding substantial Eagle-specific extensions for high-resolution timing,
duration calculation, build numbering, and flexible epoch management.

There are three key areas of complexity:

1. **Tcl-to-.NET format string translation** — The `[format]` and `scan`
   sub-commands must translate Tcl's `%`-style format specifiers (e.g.,
   `%Y`, `%m`, `%d`) to .NET's `DateTime` format patterns (e.g.,
   `yyyy`, `MM`, `dd`). This is handled by a dual-layer system in
   `FormatOps`: static string-pair mappings for simple substitutions,
   and `ClockTransformCallback` delegates for specifiers that require
   runtime computation (e.g., `%s` for epoch seconds, `%j` for day of
   year, `%Z` for timezone name, `%Q` for stardate).

2. **Custom epoch support** — Unlike Tcl, which hardcodes the Unix
   epoch (1970-01-01), Eagle supports configurable epochs via the
   `-epoch` option on most sub-commands. Three built-in epochs are
   provided: Unix (1970-01-01 UTC), PE (same as Unix), and Build
   (2000-01-01 local). Custom epochs enable build numbering,
   domain-specific time calculations, and compatibility with non-Unix
   time representations.

3. **High-resolution performance timing** — The `start`/`stop`
   sub-commands use platform-native performance counters
   (`PerformanceOps`) for microsecond-resolution timing, distinct from
   the `clicks` sub-command's multiple resolution modes. The `stop`
   sub-command is explicitly exempted from timing side-channel
   mitigation to ensure accurate measurements.

The command carries `CommandFlags.Unsafe | CommandFlags.Standard` (plus
`CommandFlags.NativeCode` on Windows) and belongs to the `"time"` object
group.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Clock.cs` | 1,054 | Main command implementation (15 sub-commands) |
| `Eagle/Library/Components/Private/TimeOps.cs` | ~2,500 | Time calculations: epoch conversions, duration formatting, calendar math |
| `Eagle/Library/Components/Private/FormatOps.cs` | large | Format string translation: static mappings + dynamic delegates |
| `Eagle/Library/Components/Private/PerformanceOps.cs` | ~500 | High-resolution performance counters |
| `Eagle/Library/Components/Public/ClockData.cs` | ~150 | Clock data container (`IClockData` implementation) |
| `Eagle/Library/Interfaces/Public/ClockData.cs` | ~30 | `IClockData` interface |
| `Eagle/Library/Components/Public/Value.cs` | large | DateTime parsing (`GetDateTime2`) with format translation |

## 2. Why This Command Differs from Tcl

### .NET DateTime integration

Tcl implements its own date/time engine. Eagle delegates to .NET's
`DateTime`, `TimeZone`, and `CultureInfo` classes, which provides:

- Culture-aware formatting and parsing via `CultureInfo`
- DST-aware timezone handling via `TimeZone`
- Native .NET tick resolution (100-nanosecond units)
- Direct interop with .NET DateTime objects

### Format specifier translation

Tcl's `%`-style format specifiers must be translated to .NET's format
patterns. This is not a simple string replacement — some specifiers
like `%s` (seconds since epoch), `%j` (day of year), `%V` (ISO 8601
week number), and `%Z` (timezone name) require runtime computation
because .NET's `DateTime.ToString()` has no direct equivalents.

### Additional sub-commands

Eagle adds 9 sub-commands beyond Tcl's standard set:

| Sub-command | Purpose |
|-------------|---------|
| `buildnumber` | Calculate .NET-style build number (days + revision) |
| `days` | Get elapsed days since an epoch |
| `duration` | Human-readable duration between two dates |
| `filetime` | Convert Windows FILETIME values |
| `isvalid` | Validate date strings |
| `monthdays` | Days in a given month |
| `now` | Current time as .NET ticks |
| `start` / `stop` | High-resolution performance timing pair |

## 3. Sub-Command Reference

### Time querying

#### `[clock seconds]`

```tcl
clock seconds ?epoch?
```

Returns seconds elapsed from the epoch to the current UTC time. The
optional `epoch` parameter overrides the default Unix epoch.

Internally calls `TimeOps.DateTimeToSeconds()` with `TimeOps.GetUtcNow()`
and the specified epoch.

#### `[clock milliseconds]`

```tcl
clock milliseconds ?epoch?
```

Returns milliseconds since the epoch. Same epoch semantics as `seconds`.

#### `[clock microseconds]`

```tcl
clock microseconds ?epoch?
```

Returns microseconds since the epoch. Same epoch semantics as `seconds`.

#### `[clock now]`

```tcl
clock now ?-gmt boolean?
```

Returns the current time as .NET `DateTime.Ticks` (100-nanosecond
intervals since 0001-01-01). With `-gmt true`, returns UTC ticks;
otherwise returns local ticks.

This is an Eagle extension — Tcl has no equivalent. It provides the
highest-resolution time representation available from the .NET runtime.

#### `[clock clicks]`

```tcl
clock clicks ?-milliseconds? ?-microseconds?
```

Returns a high-resolution counter value from `PerformanceOps`:

| Option | Source | Resolution |
|--------|--------|------------|
| (default) | `PerformanceOps.GetCount()` | Platform-native (highest available) |
| `-milliseconds` | `PerformanceOps.GetTickCount()` | Milliseconds |
| `-microseconds` | `PerformanceOps.GetMicroseconds()` | Microseconds |

The default (no option) returns the raw performance counter value, which
is not directly comparable across machines. Use `[clock start]` / `clock
stop` for portable elapsed-time measurement.

### Formatting

#### `[clock format]`

```tcl
clock format clockValue ?options?
```

Converts a clock value (seconds since epoch or .NET ticks) to a
human-readable string.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-format` | string | (interpreter default) | Tcl format string (see §4) |
| `-gmt` | boolean | false | Use UTC instead of local time |
| `-epoch` | DateTime | Unix epoch | Custom epoch for conversion |
| `-kind` | DateTimeKind | (interpreter default) | `Utc`, `Local`, or `Unspecified` |
| `-ticks` | flag | — | Interpret clockValue as .NET ticks instead of seconds |
| `-iso` | flag | — | Use ISO 8601 format |
| `-full` | flag | — | Use full ISO 8601 format (with `-iso`) |
| `-isotimezone` | flag | — | Include timezone in ISO output |

**Processing flow:**

1. Parse `clockValue` as a wide integer (seconds or ticks).
2. Convert to `DateTime`:
   - With `-ticks`: `TimeOps.TicksToDateTime(ticks, kind)`.
   - Without `-ticks`: `TimeOps.SecondsToDateTime(seconds, epoch)`.
3. Apply timezone: if not UTC, convert to local time.
4. Format output:
   - If `-iso`: `FormatOps.Iso8601DateTime(dateTime, isoTimezone)`.
   - If `-iso -full`: `FormatOps.Iso8601FullDateTime(dateTime)`.
   - If `-format` is blank/whitespace: return blank (Tcl compatibility).
   - Otherwise: `FormatOps.TclClockDateTime(culture, timezone, format,
     dateTime, epoch)`.

### Parsing

#### `[clock scan]`

```tcl
clock scan dateString ?options?
```

Parses a date/time string and returns seconds since the epoch.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-format` | string | (none) | Tcl format string for parsing |
| `-base` | clockValue | (none) | Base clock value supplying the date components absent from the input (e.g., a time-only string takes its date from the base) |
| `-epoch` | DateTime | Unix epoch | Custom epoch for output conversion |
| `-gmt` | boolean | false | Interpret result as UTC |

**Processing flow:**

1. Parse `dateString` via `Value.GetDateTime2()`:
   - If `-format` is provided, translate it via
     `FormatOps.TranslateDateTimeFormats()` before parsing.
   - Otherwise, use .NET's default `DateTime.Parse()`.
2. Apply timezone: if `-gmt true`, the input is parsed as UTC (no
   conversion needed); if `-gmt false` (default), the input is parsed
   as local time and then converted to UTC via `ToUniversalTime()`.
3. Convert `DateTime` to seconds since the epoch via
   `TimeOps.DateTimeToSeconds()`.

**`-base` and missing date components:** when `-base` is supplied, the date
components that are *absent* from the input are taken from the base clock
value, contiguously from the day upward (matching Tcl): the day comes from the
input only if present; the month only if month and day are present; the year
only if year, month, and day are present -- otherwise that component comes from
the base.  The time-of-day always comes from the input (an absent time means
midnight).  With `-format`, the date components present in the input are
determined from the format's conversion specifiers.

**Free-form (no `-format`) limitations:** absolute forms -- ISO dates,
`MM/DD/YYYY`, time-only, month-name, and epoch seconds -- parse correctly, but
two behaviors of Tcl's legacy free-form parser are not supported:

- a missing **year** is taken from the current date rather than from `-base`
  when a month and day are present (use the `-format` path for full `-base`
  behavior); and
- **relative / free-form English** strings such as `now`, `+1 day`, `tomorrow`,
  `yesterday`, `2 days ago`, or `next monday` are not accepted by `[clock scan]`
  (it returns an "unable to convert date-time string" error).  Use an absolute
  format, or compute the offset with arithmetic on `[clock seconds]`.

### Validation and calendar

#### `[clock isvalid]`

```tcl
clock isvalid dateString
```

Returns `True` if `dateString` can be parsed as a valid `DateTime`, `False`
otherwise. No options — it uses the interpreter's default culture and
parsing styles.

#### `[clock monthdays]`

```tcl
clock monthdays ?month?
```

Returns the number of days in the specified month (1–12). If no month
is given, returns days in the current month. Leap year handling is
automatic via `TimeOps.GetDaysInMonth()`.

#### `[clock days]`

```tcl
clock days ?options? ?dateString?
```

Returns the number of days elapsed since an epoch.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-format` | string | (none) | Format string for parsing dateString |
| `-epoch` | DateTime | Start of current year | Custom epoch |
| `-gmt` | boolean | false | Use UTC |

### Duration

#### `[clock duration]`

```tcl
clock duration ?options? startDateString endDateString
```

Calculates the duration between two dates.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-flags` | DurationFlags | `Default` | Controls output format |

With `DurationFlags.Human`, returns a human-readable string via
`TimeOps.GetHumanDuration()` (e.g., "2 years, 3 months, 15 days").
Without it, returns a .NET `TimeSpan` representation.

### Build numbering

#### `[clock buildnumber]`

```tcl
clock buildnumber ?options? ?dateString?
```

Calculates a .NET-style build number from a date. Returns a two-element
list: `{days revision}` where `days` is the number of days since the
epoch and `revision` is derived from seconds elapsed since the start of
the day.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-format` | string | (none) | Format string for parsing |
| `-epoch` | DateTime | Build epoch (2000-01-01) | Custom epoch |
| `-gmt` | boolean | false | Use UTC |

This is specific to Eagle and is used for generating .NET assembly
version numbers compatible with MSBuild's auto-versioning scheme.

### Windows file time

#### `[clock filetime]`

```tcl
clock filetime fileTimeValue ?options?
```

Converts a Windows FILETIME (64-bit value representing 100-nanosecond
intervals since 1601-01-01) to a formatted date string.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-format` | string | (none) | Output format string |
| `-epoch` | DateTime | Unix epoch | Custom epoch for formatting |
| `-gmt` | boolean | false | Use UTC (`FromFileTimeUtc`) vs local (`FromFileTime`) |

### Performance timing

#### `[clock start]`

```tcl
clock start
```

Returns the current high-resolution performance counter value via
`PerformanceOps.GetCount()`. This value is only meaningful when passed
to `[clock stop]`.

#### `[clock stop]`

```tcl
clock stop startCount
```

Takes the `startCount` from a previous `[clock start]` and returns the
elapsed time in **microseconds** via
`PerformanceOps.GetMicrosecondsFromCount()`.

**Security note**: The `[clock stop]` sub-command is explicitly exempted
from timing side-channel mitigation. This exemption is necessary to
provide accurate performance measurements — the mitigation would
introduce artificial jitter that defeats the purpose of precise timing.

## 4. The Format String Translation Layer

### Overview

Eagle's format translation converts Tcl's `%`-specifier format strings
into .NET-compatible output. This is handled by
`FormatOps.TranslateDateTimeFormats()`, which applies two passes:

1. **Static mappings** (`tclClockFormats`) — Simple string replacements.
2. **Dynamic delegates** (`tclClockDelegates`) — Runtime-computed values
   via `ClockTransformCallback` functions.

### Static format mappings

These specifiers have direct .NET equivalents and are translated by
simple string substitution:

| Tcl | .NET | Meaning |
|-----|------|---------|
| `%a` | `ddd` | Abbreviated weekday name |
| `%A` | `dddd` | Full weekday name |
| `%b` | `MMM` | Abbreviated month name |
| `%B` | `MMMM` | Full month name |
| `%c` | (culture-specific) | Preferred date and time |
| `%d` | `dd` | Day of month (01–31) |
| `%D` | `MM/dd/yy` | Short date (`%m/%d/%y`) |
| `%h` | `MMM` | Same as `%b` |
| `%H` | `HH` | Hour, 24-hour (00–23) |
| `%i` | `yyyy.MM.ddTHH:mm:ss.fff` | ISO 8601 with milliseconds |
| `%I` | `hh` | Hour, 12-hour (01–12) |
| `%m` | `MM` | Month (01–12) |
| `%M` | `mm` | Minute (00–59) |
| `%n` | `\n` | Newline |
| `%p` | `tt` | AM/PM |
| `%r` | `hh:mm:ss tt` | 12-hour time with AM/PM |
| `%R` | `HH:mm` | 24-hour time without seconds |
| `%S` | `ss` | Second (00–59) |
| `%t` | `\t` | Tab |
| `%T` | `HH:mm:ss` | 24-hour time with seconds |
| `%x` | `M/d/yyyy` | Short date |
| `%X` | `h:mm:ss tt` | Short time |
| `%y` | `yy` | 2-digit year |
| `%Y` | `yyyy` | 4-digit year |
| `%%` | `\%` | Literal percent sign |

### Dynamic format delegates

These specifiers require runtime computation and are implemented as
`ClockTransformCallback` delegates in the `TclClockDelegates` class.
Each delegate receives the `DateTime`, `TimeZone`, `CultureInfo`, and
`epoch` and returns a string:

| Tcl | Delegate | Meaning |
|-----|----------|---------|
| `%C` | `GetCentury` | Century (year / 100) |
| `%e` | `GetDayOfMonthSpacePadded` | Day of month, space-padded to width 2 (` 1`–`31`) |
| `%g` | `GetTwoDigitYearIso8601` | 2-digit ISO 8601 week-based year |
| `%G` | `GetFourDigitYearIso8601` | 4-digit ISO 8601 week-based year |
| `%j` | `GetDayOfYear` | Day of year (001–366) |
| `%k` | `GetHourOfDaySpacePadded` | Hour, 24-hour, space-padded to width 2 (` 0`–`23`) |
| `%l` | `GetHourOfHalfDaySpacePadded` | Hour, 12-hour, space-padded to width 2 (` 1`–`12`) |
| `%Q` | `GetStardate` | Star Trek stardate (Tcl-compatible algorithm from Kevin B. Kenny) |
| `%s` | `GetSecondsSinceEpoch` | Seconds since epoch (calls `TimeOps.DateTimeToSeconds`) |
| `%u` | `GetWeekdayNumberOneToSeven` | Weekday number, Monday=1 through Sunday=7 |
| `%U` | `GetWeekOfYearSundayIsFirstDay` | Week number (Sunday as first day of week) |
| `%V` | `GetWeekOfYearIso8601` | ISO 8601 week number (uses `CalendarWeekRule.FirstFourDayWeek`) |
| `%w` | `GetWeekdayNumberZeroToSix` | Weekday number, Sunday=0 through Saturday=6 |
| `%W` | `GetWeekOfYearMondayIsFirstDay` | Week number (Monday as first day of week) |
| `%Z` | `GetTimeZoneName` | Timezone name (DST-aware, from `TimeZone` object) |

### Translation flow

```tcl
clock format $seconds -format "%Y-%m-%d %H:%M:%S %Z (day %j)"
|
+-- FormatOps.TclClockDateTime(culture, timezone, format, dateTime, epoch)
|   |
|   +-- TranslateDateTimeFormats(culture, timezone, format, dateTime, epoch,
|                                useFormats=true, useDelegates=true)
|       |
|       +-- Pass 1: Static mappings
|       |   %Y -> yyyy, %m -> MM, %d -> dd, %H -> HH, %M -> mm, %S -> ss
|       |
|       +-- Pass 2: Dynamic delegates
|           %Z -> GetTimeZoneName(dateTime, timezone, culture, epoch)
|                 -> "Eastern Standard Time"
|           %j -> GetDayOfYear(dateTime, timezone, culture, epoch)
|                 -> "042"
|
+-- dateTime.ToString(translatedFormat, culture)
    -> "2025-02-11 14:30:00 Eastern Standard Time (day 042)"
```

### The `%Q` stardate specifier

Eagle implements the Tcl-compatible stardate calculation algorithm
(attributed to Kevin B. Kenny). The stardate is computed via
`TimeOps.CalculateStardate()` and formatted as a multi-part value.
This is a novelty feature present in both Tcl and Eagle.

## 5. Epoch Management

### Built-in epochs

| Epoch | Constant | Value | Purpose |
|-------|----------|-------|---------|
| Unix | `TimeOps.UnixEpoch` | 1970-01-01 00:00:00 UTC | Default for all time sub-commands; Tcl compatibility |
| PE | `TimeOps.PeEpoch` | 1970-01-01 00:00:00 UTC | PE file timestamp compatibility (same as Unix) |
| Build | `TimeOps.BuildEpoch` | 2000-01-01 00:00:00 Local | MSBuild-style build number generation |

### Custom epoch usage

Most sub-commands accept an `-epoch` option that overrides the default:

```tcl
# Seconds since a custom epoch
clock seconds "2020-01-01"

# Format relative to a custom epoch
clock format 86400 -epoch "2020-01-01"
# Shows the date one day after 2020-01-01

# Build number relative to project start
clock buildnumber -epoch "2023-06-15"
```

### How epoch conversions work

The `TimeOps` class provides the core conversion methods:

- **`DateTimeToSeconds(ref long seconds, DateTime dateTime, DateTime epoch)`**:
  Computes `(dateTime - epoch).TotalSeconds` as a truncated integer.

- **`DateTimeToMilliseconds(ref long ms, DateTime dateTime, DateTime epoch)`**:
  Computes `(dateTime - epoch).TotalMilliseconds`.

- **`DateTimeToMicroseconds(ref long us, DateTime dateTime, DateTime epoch)`**:
  Computes `(dateTime - epoch).Ticks / 10` (since 1 tick = 100ns = 0.1us).

- **`SecondsToDateTime(long seconds, ref DateTime dateTime, DateTime epoch)`**:
  Computes `epoch.AddSeconds(seconds)`.

All methods handle the case where `dateTime < epoch` correctly,
returning negative values.

## 6. The `ClockData` / `IClockData` Interface

The `IClockData` interface defines the data contract for clock
operations:

```csharp
public interface IClockData : IIdentifier, IHaveCultureInfo
{
    TimeZone TimeZone { get; set; }
    string Format { get; set; }
    DateTime DateTime { get; set; }
    DateTime Epoch { get; set; }
}
```

The `ClockData` class implements this interface and bundles all the
parameters needed for a clock operation:

| Property | Type | Purpose |
|----------|------|---------|
| `Name` | string | Identifier name |
| `CultureInfo` | CultureInfo | Culture for formatting/parsing |
| `TimeZone` | TimeZone | Timezone (null = UTC) |
| `Format` | string | Format string |
| `DateTime` | DateTime | The date/time value |
| `Epoch` | DateTime | The reference epoch |
| `ClientData` | IClientData | Associated client data |

This interface is used when passing clock data through the format
translation pipeline and is available for plugins and custom code that
need to interact with Eagle's time infrastructure.

## 7. The `TimeOps` Utility Class

### Core constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `UnixEpoch` | 1970-01-01 UTC | Default epoch |
| `BuildEpoch` | 2000-01-01 Local | Build numbering epoch |
| `PeEpoch` | 1970-01-01 UTC | PE file compatibility |
| `SecondsInNormalDay` | 86,400 | Time unit conversion |
| `DaysInMonth[]` | {31,28,31,...} | Calendar reference |

### Fake time support

For deterministic testing, `TimeOps` supports fake time injection:

- **`SetFakeNow(DateTime? now)`** — Sets a fake local time. When set,
  `GetNow()` returns the fake time instead of the real system time.
- **`SetFakeUtcNow(DateTime? now)`** — Sets a fake UTC time. When set,
  `GetUtcNow()` returns the fake time.

This allows tests to run with a fixed, known time without modifying
the system clock. The `GetNow()` and `GetUtcNow()` methods check for
fake time first, falling back to the real system time if none is set.

### Duration formatting

`TimeOps.GetHumanDuration()` produces human-readable duration strings:

```tcl
clock duration -flags Human "2020-01-01" "2023-06-15"
# Returns something like: "approximately 3, 166"
```

The method supports extensive customization via `DurationFlags` and
uses `GetDurationName()` to map numeric values to unit labels with
proper pluralization.

### Calendar math

- **`GetDaysInMonth(month, year)`** — Returns days in a month,
  accounting for leap years.
- **`GetDaysInYear(year)`** — Returns 365 or 366.
- **`CountLeapYears(dateTime)`** — Counts leap years before a date.
- **`StartOfYear(dateTime)`** — Returns January 1st of the given year.
- **`ThisThursday(dateTime)`** — Calculates the Thursday of the same
  ISO 8601 week (used for ISO week number computation).

## 8. Performance Counters (`PerformanceOps`)

The `[clock start]` / `[clock stop]` pair uses `PerformanceOps` for
high-resolution timing:

| Method | Resolution | Source |
|--------|-----------|--------|
| `GetCount()` | Platform-native | `Stopwatch.GetTimestamp()` or `QueryPerformanceCounter` |
| `GetTickCount()` | ~15ms | `Environment.TickCount` |
| `GetMicroseconds()` | ~1us | Derived from performance counter |
| `GetMicrosecondsFromCount(start, end)` | ~1us | Elapsed time between two counter values |

### Timing side-channel exemption

The `[clock stop]` sub-command explicitly bypasses timing side-channel
mitigation. This is marked in the source code because Eagle normally
adds small random delays to timing operations to prevent side-channel
attacks. For `[clock stop]`, this would defeat the purpose of precise
measurement, so the exemption is applied.

## 9. Interpreter Configuration

Several interpreter properties affect clock behavior:

| Property | Effect |
|----------|--------|
| `InternalCultureInfo` | Culture used for formatting and parsing |
| `DateTimeStyles` | .NET `DateTimeStyles` flags for parsing |
| `DateTimeFormat` | Default format string when `-format` is not specified |
| `DateTimeKind` | Default `DateTimeKind` (Utc/Local/Unspecified) |

These allow per-interpreter customization of date/time behavior without
modifying global state.

## 10. Safe Interpreter Restrictions

In safe interpreters, the following `[clock]` sub-commands are allowed
(via `PolicyOps.AllowedClockSubCommandNames`):

- `buildnumber`, `days`, `duration`, `filetime`, `[format]`, `isvalid`,
  `monthdays`, `scan`, `seconds`

The following are restricted (not in the allowed list):

- `clicks`, `microseconds`, `milliseconds`, `now`, `start`, `stop`

The high-resolution timing sub-commands are restricted because they
could be used for timing side-channel attacks in sandboxed environments.

## 11. Practical Patterns

### Pattern 1: Basic time operations (Tcl-compatible)

```tcl
# Get current time
set now [clock seconds]

# Format as human-readable
clock format $now -format "%Y-%m-%d %H:%M:%S"
# -> "2025-03-12 14:30:00"

# Format in UTC
clock format $now -gmt true -format "%Y-%m-%d %H:%M:%S UTC"

# Parse a date string
set ts [clock scan "2025-01-15"]
```

### Pattern 2: ISO 8601 formatting

```tcl
set now [clock seconds]

# Standard ISO 8601
clock format $now -iso
# -> "2025.03.12T14:30:00.000"

# Full ISO 8601 with timezone
clock format $now -iso -full -isotimezone
# -> "2025-03-12T14:30:00.0000000-05:00"
```

### Pattern 3: High-resolution elapsed timing

```tcl
# Measure operation duration in microseconds
set start [clock start]
# ... perform operation ...
set elapsed [clock stop $start]
puts "Operation took $elapsed microseconds"
```

### Pattern 4: Custom epoch calculations

```tcl
# Seconds since project start
set projectStart "2023-06-15"
clock seconds $projectStart

# Build number relative to project epoch
clock buildnumber -epoch "2023-01-01"
```

### Pattern 5: Duration between dates

```tcl
# Human-readable duration
clock duration -flags Human "2020-01-01" "2025-03-12"
# -> "approximately 5, 72"

# TimeSpan duration
clock duration "2025-01-01" "2025-03-12"
```

### Pattern 6: Calendar queries

```tcl
# Days in February (handles leap years)
clock monthdays 2
# -> 28 (or 29 in a leap year)

# Validate a date string
clock isvalid "2025-02-29"  ;# -> False (2025 is not a leap year)
clock isvalid "2024-02-29"  ;# -> True (2024 is a leap year)
```

### Pattern 7: Windows FILETIME conversion

```tcl
# Convert a Windows FILETIME to readable date
clock filetime 133540000000000000 -format "%Y-%m-%d %H:%M:%S"

# As UTC
clock filetime 133540000000000000 -gmt true -format "%Y-%m-%d %H:%M:%S UTC"
```

### Pattern 8: .NET ticks

```tcl
# Get current time as .NET ticks
set ticks [clock now]

# Format from ticks instead of seconds
clock format $ticks -ticks -format "%Y-%m-%d %H:%M:%S"
```

### Pattern 9: Format specifiers requiring delegates

```tcl
set now [clock seconds]

# Day of year
clock format $now -format "Day %j of %Y"
# -> "Day 071 of 2025"

# ISO 8601 week number
clock format $now -format "Week %V of %G"
# -> "Week 11 of 2025"

# Timezone name
clock format $now -format "%Y-%m-%d %H:%M:%S %Z"
# -> "2025-03-12 14:30:00 Eastern Daylight Time"

# Seconds since epoch (embedded in format)
clock format $now -format "Epoch: %s"
```

### Pattern 10: MSBuild-compatible build number

```tcl
# Generate build number (days since 2000-01-01, revision from time-of-day)
set buildInfo [clock buildnumber]
# -> "9201 42300" (days revision)

# Use as assembly version: 1.0.9201.42300
```

## 12. Comparison: Tcl vs Eagle Clock Command

| Feature | Tcl | Eagle |
|---------|-----|-------|
| `[clock seconds]` | Unix epoch only | Configurable epoch via `-epoch` |
| `[clock milliseconds]` | Returns milliseconds | Configurable epoch |
| `[clock microseconds]` | Returns microseconds | Configurable epoch |
| `[clock clicks]` | Single resolution | Three modes: default, `-milliseconds`, `-microseconds` |
| `[clock format]` | Tcl format engine | .NET `DateTime.ToString()` with translation layer |
| `[clock scan]` | Tcl parser with natural language | .NET `DateTime.Parse()` with format translation |
| `[clock now]` | Not available | Returns .NET `DateTime.Ticks` |
| `[clock start]` / `stop` | Not available | High-resolution performance counters |
| `[clock buildnumber]` | Not available | .NET-style build number generation |
| `[clock days]` | Not available | Elapsed days since epoch |
| `[clock duration]` | Not available | Human-readable duration calculation |
| `[clock filetime]` | Not available | Windows FILETIME conversion |
| `[clock isvalid]` | Not available | Date string validation |
| `[clock monthdays]` | Not available | Calendar day-in-month query |
| `-epoch` option | Not available | Custom epoch on most sub-commands |
| `-ticks` option | Not available | .NET tick interpretation in `[format]` |
| `-iso` / `-full` | Not available | ISO 8601 formatting modes |
| `-kind` option | Not available | `DateTimeKind` control |
| `%Q` (stardate) | Available | Available (Tcl-compatible algorithm) |
| `%V` (ISO week) | Available | Via `ClockTransformCallback` delegate |
| `%Z` (timezone) | Available | Via `ClockTransformCallback` with DST awareness |
| Fake time injection | Not available | `TimeOps.SetFakeNow()` / `SetFakeUtcNow()` |
| Safe interpreter restrictions | Not applicable | High-res timing sub-commands restricted |
| Culture-aware formatting | Via `-locale` | Via interpreter `CultureInfo` |

## 13. Security Considerations

- **`CommandFlags.Unsafe`** — The command is restricted in safe
  interpreters. Only formatting, parsing, validation, and calendar
  sub-commands are allowed.

- **High-resolution timing restriction** — The `clicks`,
  `microseconds`, `milliseconds`, `now`, `start`, and `stop`
  sub-commands are blocked in safe interpreters to prevent timing
  side-channel attacks.

- **Timing side-channel mitigation exemption** — `[clock stop]` bypasses
  the normal timing mitigation to provide accurate measurements. Code
  that uses `[clock stop]` should be aware that the precise timing values
  could potentially be used for side-channel analysis.

- **Fake time in testing** — The `SetFakeNow()` / `SetFakeUtcNow()`
  mechanism is intended for testing only. In production, these should
  not be set, as they affect all time-dependent operations in the
  interpreter.

## 14. Relationship to Other Commands

| Related command | Relationship |
|----------------|-------------|
| `[time]` | Benchmarking: executes a script N times and returns average microseconds per iteration |
| `[after]` | Event scheduling: uses millisecond delays, not clock values |
| `[info]` | `[info runtime]` returns interpreter runtime duration |
| `[uri time]` | Queries a remote network time server; see [`uri.md`](uri.md) |

## 15. References

- **Source code**: `Eagle/Library/Commands/Clock.cs` — `[clock]` command (15 sub-commands)
- **Source code**: `Eagle/Library/Components/Private/TimeOps.cs` — time calculations, epochs, duration formatting
- **Source code**: `Eagle/Library/Components/Private/FormatOps.cs` — format string translation (static + delegate)
- **Source code**: `Eagle/Library/Components/Private/PerformanceOps.cs` — high-resolution performance counters
- **Source code**: `Eagle/Library/Components/Public/ClockData.cs` — `IClockData` implementation
- **Source code**: `Eagle/Library/Components/Public/Value.cs` — `GetDateTime2` parsing with format translation
- **Command reference**: [`core_language.md`](core_language.md#cmd-clock) — `[clock]` syntax and options
- **Examples**: [`core_examples.md`](core_examples.md#ex-clock) — `[clock]` examples
- **Tcl reference**: [Tcl `[clock]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/clock.htm)
- **.NET reference**: [DateTime Structure](https://docs.microsoft.com/en-us/dotnet/api/system.datetime)
- **.NET reference**: [Custom Date and Time Format Strings](https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings)
