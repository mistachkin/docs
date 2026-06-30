# Eagle Test Harness

Eagle ships a full unit-test framework — the **`Eagle.Test`** package (on disk:
the `Test1.0` library) — built around the `test1`/`test2`/`test` commands and a
`runTest` wrapper. Everything below was **executed** against Eagle 1.0 (see
[`verification.md`](verification.md)); `;# =>` and the fenced *output* blocks show
the verified result. For the commands used inside test bodies, see
[`commands/index.md`](commands/index.md).

> The interpreter is the final word. The exact output strings, return codes, and
> "you must do X first" facts in this file were all confirmed by running them
> through `scripts/eval-eagle.sh`.

---

## Two layers

1. **Built-in commands** — `test1`, `test2`, and the `test` dispatcher exist in a
   bare shell with **no package require**:

   ```tcl
   puts [info commands test*]      ;# => test1 test2 test
   ```

   `test1`/`test2` are C# commands (`Library/Commands/Test1.cs`, `Test2.cs`);
   `test` is a thin library proc that picks between them.

2. **The `Eagle.Test` library** — `runTest`, the prologue/epilogue, and the
   constraint helpers (`addConstraint`, `getConstraints`, `haveConstraint`, …)
   are **not** auto-loaded. You must require the package first:

   ```tcl
   runTest {test x-1.1 {y} -body {expr 1} -result 1}
   ;# => Error, line 1: invalid command name "runTest"

   package require Eagle.Test    ;# => 1.0.9675.37713  (a version, not an error)
   ```

   The package is **`Eagle.Test`**. There is no `Test1.0` package name —
   `package require Test1.0` fails with `can't find package "Test1.0"`
   (`Test1.0` is the *directory*, whose `pkgIndex.eagle` provides
   `Eagle.Test.Constraints`).

---

## The minimal incantation

A test only runs if its name matches the configured match patterns. In a bare
interpreter that list is empty, so **every test is skipped**:

```tcl
test2 foo-1.1 {add} -body {expr {1 + 1}} -result 2
;# => Break: ++++ foo-1.1 SKIPPED: userSpecifiedNonMatch
```

Set the match list (the suite prologue normally does this from `-match`, default
`*`) and the test runs. The two pieces you need by hand are therefore:

```tcl
package require Eagle.Test
set eagle_tests(MatchNames) [list *]      ;# run all tests; without it: all SKIPPED
```

A built-in `test2` returns its formatted report as the command **result** (it
does not print on its own), so capture it to see it — or use `runTest`, which
logs it for you:

```tcl
set eagle_tests(MatchNames) [list *]
puts [test2 foo-1.1 {add} -body {expr {1 + 1}} -result 2]
```
```text
++++ foo-1.1 PASSED
```

---

## The test commands

### `test2` — option form (preferred)

`test2 name description ?options?`

The name is conventionally `group-N.M` (e.g. `catch-1.1`). The common options
behave like Tcl's `tcltest`:

| Option | Meaning (verified) |
|---|---|
| `-body script` | The script under test. Its result/return code are what get checked. |
| `-setup script` | Runs **before** the body (failures here fail the test). |
| `-cleanup script` | Runs **after** the body, always. |
| `-result value` | Expected result, compared per `-match`. |
| `-constraints list` | Names that must be satisfied for the test to run (logical AND). A `!name` entry requires that constraint to be **absent**. |
| `-returnCodes codes` | Accepted completion codes. **Default `Ok Return`** — a body that errors *fails* unless you list `error`/`1`. Accepts names (`error`) or integers (`1`). |
| `-match mode` | `exact` (default), `glob`, or `regexp`. |
| `-noCase boolean` | Case-insensitive matching. **Takes a value** — write `-noCase true`, not a bare `-noCase`. |
| `-time boolean` | Time the phases; prints `body completed in N microseconds per iteration`. |
| `-output pattern` / `-errorOutput pattern` | Match the test's captured stdout/stderr. (Capture needs the full suite host; see note below.) |

There are many more (`-constraintExpression`, `-repeatCount`, `-once`,
`-isolationLevel`, the `-no*` toggles, isolated-process matching). The full,
authoritative set is parsed in `Test2.cs`; per-option semantics live in
[`../../../core_language.md`](../../../core_language.md) (Test Functions) and
`options.md#test2`.

> **`-output`/`-errorOutput` caveat (verified):** in the lightweight runner above
> (no full prologue), a body's `puts` goes straight to the console and the
> capture comes back empty, so an `-output` test *fails*. Output/error matching
> needs the test host that the suite prologue installs — run those tests through
> the real suite (below).

### `test1` — positional (old) form

`test1 name description ?constraints? body result`

```tcl
test1 old-1.1 {old style} {} {expr {1 + 1}} 2     ;# => ++++ old-1.1 PASSED
```

The empty `{}` is the constraints slot. Use `test1` for a plain body+result;
reach for `test2` whenever you need setup/cleanup, output matching, timing, or
non-default return codes.

### `test` — the dispatcher

`test` is a library proc (loaded with `Eagle.Test`). It inspects the **first
trailing argument**: if it begins with `-` it forwards to `test2`, otherwise to
`test1`.

```tcl
test demo {add} -body {expr {1 + 1}} -result 2    ;# -> test2
test demo {add} {} {expr {1 + 1}} 2               ;# -> test1
```

(Both real test files and the worked example below typically call `test`
directly, wrapped in `runTest`.)

---

## Constraints gate tests

An unsatisfied constraint skips the test (it is *not* a failure); a satisfied one
lets it run:

```tcl
package require Eagle.Test
set eagle_tests(MatchNames) [list *]

runTest {test con-1.1 {needs missing constraint} -constraints {neverDefined} \
    -body {error "should never run"} -result {}}

addConstraint unix
runTest {test con-1.2 {gated on unix} -constraints {unix} -body {expr {2 * 3}} \
    -result 6}
```
```text
++++ con-1.1 SKIPPED: neverDefined
++++ con-1.2 PASSED
```

`addConstraint name` registers one; `getConstraints` lists them; `haveConstraint
name` tests for one. A `!`-prefixed constraint passes when the name is **absent**:

```tcl
runTest {test d-1.1 {absent} -constraints {!neverDefined} -body {expr {3+4}} \
    -result 7}                                    ;# => ++++ d-1.1 PASSED
```

In the **real suite**, `constraints.eagle` auto-registers a large catalog (387+
`addConstraint` calls) during the prologue: an engine constraint (`eagle` when
running under Eagle, `tcl` under native Tcl), platform constraints (`unix`,
`windows`, `mac`), framework/feature constraints, and `knownBug`-style markers.
That is why a real test such as `basic-1.0.2` carries `-constraints {eagle}` (run
under Eagle, skipped under Tcl) and its sibling carries `-constraints {tcl}`.

---

## `runTest` — the wrapper you actually call

Test files almost never call `test`/`test2` bare; they wrap each one in
`runTest {…}`. `runTest` runs the test in the caller's frame and adds the suite
bookkeeping: it records resource counts before/after for **leak detection**, logs
the result to the test channel (so you see `PASSED`/`FAILED` without a `puts`),
normalizes the special return codes (`Break` = skipped, `Continue` = failure
ignored), promotes a result containing the `FAILED` marker to an actual failure,
and honors stop-on-failure. It returns the empty string.

---

## A complete, verified example

Write this to `/tmp/mytest.eagle`:

```tcl
package require Eagle.Test

set eagle_tests(MatchNames) [list *]

runTest {test demo-1.1 {one plus one} -body {
  expr {1 + 1}
} -result 2}

runTest {test demo-1.2 {deliberately wrong} -body {
  expr {1 + 1}
} -result 3}

runTest {test demo-1.3 {gated on a missing constraint} -constraints {neverDefined} -body {
  error "never runs"
} -result {}}
```

Run it through the harness:

```sh
scripts/eval-eagle.sh -file /tmp/mytest.eagle
```

Verified output — a pass, a fail (with the diagnostic block), and a skip:

```text
++++ demo-1.1 PASSED

==== demo-1.2 deliberately wrong FAILED
==== Contents of test case:

  expr {1 + 1}

---- Result was:
2
---- Result should have been (Exact matching):
3
==== demo-1.2 FAILED
++++ demo-1.3 SKIPPED: neverDefined
```

A failing **return code** (body errored, but `-returnCodes` left at the default)
reports the codes too:

```tcl
runTest {test rc-1.2 {error without returnCodes} -body {error "boom"} -result boom}
```
```text
==== rc-1.2 error without returnCodes FAILED
==== Contents of test case:
error "boom"
---- Test generated error; Return code was: Error
---- Return code should have been one of: Ok Return
---- errorInfo(body): boom
    while executing
"error "boom""
---- errorCode(body): NONE
==== rc-1.2 FAILED
```

Add `-returnCodes error` (or `-returnCodes 1`) to make that an expected error and
the test passes.

---

## How the real suite is structured

A real test file (e.g. `Eagle/Library/Tests/basic.eagle`, `catch.eagle`,
`switch.eagle`) is a *prologue → tests → epilogue* sandwich. Form-feed-free
`####…` separator lines (full-width comment rules) divide the sections; each test
is a `runTest {test … }` block:

```tcl
###############################################################################
# catch.eagle (abridged)
###############################################################################

source [file join [file normalize [file dirname [info script]]] prologue.eagle]

###############################################################################

runTest {test catch-1.1 {simple catch} -body {
  list [catch {error "this is an error."} foo] $foo
} -cleanup {
  unset foo
} -result {1 {this is an error.}}}

###############################################################################

source [file join [file normalize [file dirname [info script]]] epilogue.eagle]
```

Conventions for the on-disk suite:

- **Location.** Tests live in `Eagle/Library/Tests/*.eagle`. The per-file
  `prologue.eagle`/`epilogue.eagle` next to them are tiny **stubs** that locate
  the `lib/Test1.0` package and then `source` its real prologue/epilogue.
- **Naming.** Files group commands (`list.eagle`, `string-map.eagle`,
  `object*.eagle`); tests are `group-N.M` and same-body language/platform variants
  use `base.N.1` / `base.N.2` with identical descriptions.
- **`all.eagle` + `runAllTests`.** `Eagle/Library/Tests/all.eagle` runs the whole
  suite: it sources the prologue, discovers the test files with `getTestFiles`,
  runs them via `runAllTests`, then sources the epilogue. The
  `-file`/`-notFile`/`-startFile`/`-stopFile` flags select subsets.
- **Self-cleaning.** Each test must leave interpreter state unchanged and release
  every resource — the suite reports leaks. `unset` your vars (including helpers),
  `rename` temp procs, and save/restore any flags you toggle.

You can drive the full prologue/epilogue yourself instead of the stubs:

```tcl
package require Eagle.Test
runTestPrologue
runTest {test foo-1.1 {one plus one} -body {expr {1 + 1}} -result 2}
runTest {test foo-1.2 {deliberately wrong} -body {expr {1 + 1}} -result 3}
runTestEpilogue
```

The prologue emits a large diagnostic header (platform, channel, constraint
checks, …) and the epilogue prints the **run summary** — verified tail of the
run above:

```text
LEAKED: 0
PASSED: 1
FAILED: 1
FAILED: foo-1.2
TOTAL: 2
PASS PERCENTAGE: 50%
OVERALL RESULT: script /tmp/harness_probe.eagle, suite Eagle Test Suite for Eagle
OVERALL RESULT: FAILURE
```

Note the process **exit code is non-zero** on any failure, so the suite is
CI-friendly. (The lightweight `runTest`-only form above exits `0` regardless;
it is for quick, interactive checks.)

---

## Running the suite from the command line

Run the whole suite, one file, or a filtered subset (each test file sources its
own prologue/epilogue, so a single file runs standalone):

```sh
eagle.sh -file Library/Tests/all.eagle          # whole suite (Makefile: make test)
eagle.sh -file Library/Tests/string-map.eagle   # one file
```

### Test-runner options (`test_flags`)

The runner is configured by command-line options that the prologue parses into a
`test_flags(...)` array and commits to the `eagle_tests(...)` globals. Pass them
**after the test file**, separated from the shell's own options by `--`:

```sh
# run only tests whose NAME matches a glob (the rest skip as userSpecifiedNonMatch):
eagle.sh -file Library/Tests/basic.eagle -- -match "basic-1.20*"
```

| Option | Default | Effect |
|--------|---------|--------|
| `-match {pat …}` | `*` | run only tests whose **name** matches a glob. **NB:** different from `[test2]`'s `-match` (which selects the *result*-comparison mode `exact`/`glob`/`regexp`). |
| `-skip {pat …}` | (none) | skip tests whose name matches a glob. |
| `-file {glob …}` | `*.eagle` | which test **files** `all.eagle`/`runAllTests` run. |
| `-notFile {glob …}` | `l.*.eagle` | test files to exclude. |
| `-startFile {f …}` / `-stopFile {f …}` | (none) | begin / stop the file run at these files. |
| `-constraints {name …}` | (none) | force-add constraints so gated tests run. |
| `-verbose <spec>` | `pass body skip start error` | which event classes are logged. |
| `-threshold N` | all | minimum passing count for an overall SUCCESS. |
| `-randomOrder` | off | randomize test order. |
| `-stopOnFailure` / `-stopOnLeak` / `-breakOnLeak` | off | halt (or break into the debugger) on the first failure / leak. |
| `-exitOnComplete` | off | exit the process when the run finishes. |
| `-preTest <script>` / `-postTest <script>` | (none) | evaluate a script before / after the run. |
| `-logFile` / `-logPath` / `-logId` | standard | test-log file name / directory / id. |
| `-suite` / `-machine` / `-platform` / `-configuration` / `-suffix` / `-namePrefix` | empty | run metadata recorded in the result header. |
| `-tclsh <path>` | (none) | native Tcl shell to use for cross-checks. |

Authoritative list and defaults: `setupTestArguments` / `makeUseOfTestArguments`
in `Eagle/lib/Eagle1.0/test.eagle`. Note that `-match` still *iterates* every
test in a file (non-matching ones are skipped, not bypassed), so to run just a
few tests quickly, drive the prologue/epilogue with your own `runTest` blocks
(the `runTestPrologue` form above) rather than filtering a large file.

---

## Sources & deep dives

- **Test commands & options:** [`../../../core_language.md`](../../../core_language.md)
  (Test Functions: `test1`, `test2`) and `options.md#test2`; C# source
  `Eagle/Library/Commands/Test1.cs`, `Test2.cs`.
- **Worked examples:** [`../../../core_examples.md`](../../../core_examples.md)
  (Testing Examples).
- **The framework itself:** `Eagle/lib/Test1.0/` —
  `constraints.eagle` (the constraint catalog), `prologue.eagle`,
  `epilogue.eagle`, `all.eagle`; and `Eagle/lib/Eagle1.0/test.eagle`
  (`runTest`, `runAllTests`, `getTestFiles`, `addConstraint`, …).
- **Real test corpus:** `Eagle/Library/Tests/*.eagle`.
- **Running anything:** [`verification.md`](verification.md) for `eval-eagle.sh`
  and the verify-everything protocol.
</content>
</invoke>
