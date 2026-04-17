# If You Want a Project to Be Good, You Have to Love Working on It. Period.

**Joe Mistachkin**
*with analytical contributions from Claude (Anthropic)*

---

## Abstract

This paper argues that sustained software quality is primarily a
function of intrinsic motivation -- the developer's genuine desire to
work on the project -- rather than process, methodology, or tooling.
Using the Eagle scripting language as a twenty-year case study, we
examine specific architectural decisions, patterns, and behaviors that
emerge only when the author deeply cares about the work. We contrast
these with the characteristics of software built under extrinsic
pressure (deadlines, sprints, review committees) and argue that the
difference is visible in the code itself.

---

## 1. The Thesis

Good software is not produced by good processes. Good processes produce
*adequate* software. Good software -- the kind that survives decades,
handles edge cases gracefully, runs on platforms that didn't exist when
it was written, and rewards close reading of its source code -- is
produced by people who love working on it.

This is not a motivational claim. It is an engineering observation.
There are specific, measurable characteristics of software that only
appear when the author is intrinsically motivated: relentless attention
to edge cases, willingness to refactor working code because the
abstraction isn't quite right, documentation of every deviation from
convention, and design decisions that optimize for the next twenty years
rather than the next sprint.

These characteristics cannot be mandated, incentivized, or
process-engineered. They emerge naturally when the work itself is the
reason for working.

---

## 2. What Love Looks Like in Code

### 2.1 You Fix Things That Aren't Broken

Eagle's console host has a color management system (`WriteCore`) that
worked correctly on Windows for fifteen years. The colors were managed
through a two-pass rendering pipeline with mutual-exclusion locking,
diagnostic thread ID tracking, and configurable behavior flags.
Adequate software would have left it there.

But on Linux and macOS, ANSI terminal background colors bleed to the
right margin. The symptom was intermittent: error messages (red on
white) would occasionally paint an entire line instead of just the
error text. Reproducing it required specific threading conditions and
terminal configurations.

Fixing it required tracing three separate color management paths
(`WriteCore`, `SettingsOps.MaybeRestoreColors`, and
`WriteLineForBox`), identifying that each had a different restoration
strategy, and adding `ResetColors()` (which emits `ESC[0m`) at the
correct point in each path. The fix touched code that had been stable
for years, in a subsystem that most users never consciously interact
with.

No one filed a bug report. No one was waiting for a fix. The author
noticed it, was *bothered* by it, and traced it to root cause because
leaving it alone felt wrong. The standard was not "does it work." The
standard was "is it right."

A creator who sets the standard by the work itself, rather than by
what others will accept, produces something fundamentally different
from a creator who asks "is this good enough?"

### 2.2 You Build Things When You're Bored

Eagle's interactive shell has a feature called `eagle_shellUnknown`.
When enabled, typing an unrecognized command at the prompt dispatches
it to the operating system's shell -- `cmd.exe`, `/bin/bash`,
PowerShell, or whatever the user's default is. The implementation
detects the current shell, constructs the correct command-line syntax
(including quoting rules that differ between `cmd.exe /C`, PowerShell
`-Command`, and bash `-c`), and handles the result.

It has twenty runtime configuration options, eight hook points for
external customization, and handles the single-quote escaping
differences between PowerShell-on-Windows and PowerShell-on-bash. It
verifies that the command came from the interactive loop (not from a
script) by counting evaluation stack frames against the interpreter's
interactive level counter.

This feature exists because the author "got bored." That's the stated
reason. The *real* reason is that the author uses the shell daily, and
when you use something daily, you see opportunities to make it better
that no product manager would ever prioritize.

The joy of creation doesn't require an audience. The work is the
reward. Boredom is the luxury of someone who loves their project
enough to keep finding new problems in it. You don't get bored with
software you don't care about. You get frustrated, or you walk away.

### 2.3 You Maintain Backward Compatibility Because You Gave Your Word

Eagle compiles against .NET Framework 2.0 RTM, .NET Framework 4.x,
.NET Standard 2.0, .NET Standard 2.1, and .NET 5 through .NET 10. It
runs on Mono. It has eleven `.csproj` files because each represents a
real build configuration that someone, somewhere, depends on.

The `#if` conditional compilation system is not feature flags -- it is
a compatibility architecture. When a .NET API changes between
versions, Eagle doesn't drop support for the old version. It provides
both paths:

```csharp
#if NET_40
    [SecurityCritical()]
#else
    [SecurityPermission(SecurityAction.LinkDemand,
        UnmanagedCode = true)]
#endif
```

This is expensive. Every new feature must be implemented in a way that
compiles on all targets. Every new API usage must be checked against
the lowest supported framework. The `#if` guards accumulate over time,
making the code harder to read.

No rational cost-benefit analysis would support this. The number of
users on .NET Framework 2.0 in 2025 does not justify the engineering
cost of maintaining compatibility. But backward compatibility is not
a business decision. It's a matter of integrity. When you ship
software, you make an implicit promise: if your code worked yesterday,
it works today. You keep that promise not because anyone is watching,
but because you gave your word -- even if only to yourself.

### 2.4 You Document Your Deviations

Eagle's codebase contains over 1,400 `// HACK:` comments. Each one
marks a deliberate deviation from conventional practice and explains
why the deviation exists:

```csharp
//
// HACK: The "-maybetrustedonly" option is allowed in
//       "safe" interpreters due to its lack of a value,
//       its relative harmlessness, and because the core
//       library binary plugin loader uses it, e.g. for
//       HotKey, et al.
//
```

These comments are not admissions of poor quality. They are acts of
honesty. Each one says: "I know this looks wrong. Here's why it's
right. Judge it on its merits."

Most codebases have hacks. Few codebases document every single one.
The difference is whether the author expects to be reading this code
in ten years. If you love the project, you do. And if you respect the
work enough to be truthful about its imperfections, you produce
something more trustworthy than code that hides its compromises behind
clean abstractions.

---

## 3. What Love Produces That Process Cannot

### 3.1 Integrity of Form

Eagle's `PrivateShellMainCore` method is 4,800 lines long. It
processes command-line arguments through a state machine with labeled
blocks and `goto` transitions. It handles interpreter creation,
recreation, safe/standard mode switching, child/parent interpreter
swapping, kiosk mode, pre/post-initialization hooks, argument file
reading, host-locked arguments, encoding selection, and interactive
loop entry.

Multiple attempts have been made to refactor this method into smaller
pieces. Each attempt revealed that the pieces are not independent: the
`-child` option affects how subsequent options are interpreted, the
`-safe` option triggers interpreter recreation which changes the
context for all remaining arguments, and the `ShellArguments`
injection point allows scripts evaluated during startup to modify the
argument list for subsequent processing.

The method is 4,800 lines because the feature surface is genuinely
that large. Every command-line option was added to support a specific
user or deployment scenario. Removing or reordering any of them would
break someone's workflow.

A process-driven project would never allow a 4,800-line method. It
would be refactored into a "clean architecture" with a context object,
phase methods, and a dispatch loop. The result would look better to
someone who glances at the structure without reading the code. It
would look worse to someone who needs to understand and modify the
actual behavior.

The author chose the form that serves the work, not the form that
earns approval. A building is not made better by hiding its structural
beams behind decorative panels. A method is not made better by
distributing its essential complexity across files that must be read
in a specific order to understand what was previously visible in a
single scroll.

### 3.2 Defense in Depth

Eagle's safe interpreter system has five independent security layers:
command hiding, option flag enforcement, sub-command allow-lists,
policy callbacks with voting consensus, and resource limits. An
attacker must bypass all five to escape the sandbox.

A single layer would be "secure enough" for most applications. Two
layers would satisfy any reasonable security review. Five layers exist
because the author thought about attacks that no reviewer would think
to ask about:

- What if a safe interpreter calls `[info commands]` to discover
  hidden command names?
  -> `[info]` itself is restricted to an allow-list of 23 safe
  sub-commands.

- What if a safe interpreter uses `[object invoke]` on a .NET type to
  circumvent command restrictions?
  -> `[object]` is hidden by default in safe interpreters, and when
  selectively re-enabled via policies, type access is controlled
  through trust verification.

- What if a safe interpreter consumes unbounded resources to
  denial-of-service the host?
  -> 16 separate resource limits with configurable thresholds.

This level of thoroughness comes from caring about the problem itself,
not about passing an audit. The author built the security model for
the same reason an architect designs a foundation to withstand loads
that building codes don't require: because the work deserves it.

### 3.3 Patterns That Emerge Over Time

Eagle has an internal locking convention: `TryLock(ref bool locked)` /
`ExitLock(ref bool locked)` / `MaybeWhoHasLock()`. The `ref bool`
parameter makes lock state explicit and first-class. `ExitLock` is
idempotent. `MaybeWhoHasLock` provides zero-cost diagnostics via
`Interlocked.CompareExchange`.

This pattern didn't appear in a design document. It evolved through
years of debugging threading issues, each iteration adding one more
safeguard: the timeout (so locks never block indefinitely), the thread
ID tracking (so deadlocks are diagnosable), the `LockTrace` on
failure (so contention is visible in production).

Some classes in the codebase still use the older `lock()` statement.
The coexistence of old and new patterns is not technical debt -- it's
the geological record of the project's evolution. The older code still
works. The newer code works better. Both will continue to work.

Patterns like this don't emerge from sprints. They emerge from living
with your code long enough to feel its friction, and caring enough to
smooth it, one iteration at a time, over years.

---

## 4. The Contrast: Software Built By Committee

We are not going to name specific projects. But the characteristics
are recognizable:

**Premature abstraction.** Code that creates interfaces, factories,
and strategy patterns for operations that happen exactly once. The
abstraction exists to satisfy a design review, not to solve a problem.
It is ornament masquerading as structure.

**Rigid adherence to convention.** Code where every method is under 20
lines, every class has one responsibility, and the result is 47 files
that must be read in a specific order to understand what was
previously a single comprehensible switch statement. The convention is
followed not because it serves the code, but because deviating from
it requires justification that no one wants to write.

**Missing edge cases.** Code that handles the happy path beautifully
and crashes on the first unexpected input. The author wrote enough
code to pass the tests and moved on to the next ticket.

**No institutional memory.** Code where the `TODO` comments are from
three years ago, the "temporary" workarounds are permanent, and nobody
knows why the retry count is 3 instead of 5 because the person who
wrote it left the company. The code has no author. It was produced by
a process.

**Feature flags instead of decisions.** Code that says "we'll support
both approaches" instead of choosing one and committing to it. The
result is twice the code, twice the testing surface, and half the
coherence. Making a decision requires conviction. Conviction requires
caring about the outcome.

These are not signs of bad developers. They are signs of developers
who have been separated from the joy of their work by layers of
process, approval, and compromise. The code reflects not their ability
but their relationship to the project: it is labor, not craft.

---

## 5. Implications

### 5.1 For Individuals

There is a kind of developer who builds not for recognition, not for
compensation, not for career advancement, but because the work itself
demands to be done well. If that is you, find a project worthy of that
impulse -- or build one. Life is short, and software reflects its
author's relationship to the work more honestly than any other
engineering artifact.

If you don't love what you're building, the code will know. And so
will anyone who reads it carefully.

### 5.2 For Managers

You cannot make someone love a project. You can only avoid destroying
the love that already exists. Every process that adds friction between
the developer and the code -- mandatory design reviews for trivial
changes, style enforcement that overrides judgment, sprint commitments
that prevent exploratory work -- erodes intrinsic motivation.

The best thing you can do for software quality is find people who love
the problem domain and then get out of their way. Not because process
has no value, but because the value of process is bounded, and the
value of genuine care is not.

### 5.3 For Interviewers

If a candidate shows you a project they've worked on for twenty years,
with 1,400 documented deviations, five-layer security, and a 4,800-
line method they can explain the purpose of every block in -- and your
response is "I don't like that you used switch statements" -- you have
confused convention with competence.

The question to ask is not "does this follow the patterns I was taught?"
The question is: "does this work, and does the author know why every
piece of it exists?" If the answer to both is yes, you are looking at
something more valuable than any number of elegantly abstracted,
committee-approved, six-month-old microservices.

You are looking at someone's life's work. Treat it accordingly.

---

## 6. Conclusion

Eagle is a scripting language that one person has maintained for
roughly two decades. It compiles on every .NET platform from 2.0 to
10. It runs on Windows, Linux, and macOS. It has a safe interpreter
with five security layers, a debugger with 65+ sub-commands, a
database access system used by the SQLite project's production test
suite, cross-platform terminal support with ANSI escape sequences,
native readline integration, and a transparent OS shell bridge that
was built because the author was bored.

None of this was on a roadmap. All of it exists because someone
treated the work as an end in itself -- not as a means to a
promotion, a funding round, or a performance review.

The work is the thing. If you want a project to be good, you have to
love working on it. Period.

---

## Acknowledgments

The analytical framework and specific code path tracing in this paper
were developed during an extended collaborative session between the
author and Claude (Anthropic), during which Claude read substantial
portions of the Eagle codebase, traced threading bugs to root cause,
implemented cross-platform features, and documented architectural
patterns. The experience of an AI system reading twenty years of code
and recognizing the care embedded in it is itself evidence of the
thesis: love is visible in the work, to anyone -- or anything -- that
looks closely enough.
