# Two Languages, On Purpose: The Dual-Language Architecture in Practice

## Abstract

Ousterhout's 1998 essay *Scripting: Higher-Level Programming for the 21st
Century* made an irreducible architectural observation: primitive operations and
their composition have distinct optimization gradients, and a single language
cannot serve both well without paying the cost on at least one side. A
quarter-century later, mainstream commentary treats the observation as
historically interesting but practically obsolete — Python, JavaScript, and Ruby
"won" by absorbing systems-language features and dissolving the boundary the
original argument depended on.

This whitepaper argues that the mainstream did not refute the dichotomy; it
*abandoned* the scripting half of it. The languages most often cited as evidence
that the dual-language model is dead are precisely the languages that walked
away from what made scripting languages scripting languages: small kernels,
runtime malleability, and a clean primitive/policy split. The cost-curve
argument is unchanged, and the model remains the most defensible answer for
large, long-lived, security-sensitive systems.

The whitepaper grounds the argument in a working instance of the model: Eagle, a
Tcl-semantics scripting language hosted on the .NET CLI, deployed via a
signed-source trust chain (Harpy) and a runtime mutable security model. Coding
conventions in this stack that appear idiosyncratic in isolation — pervasive
override patterns, sensitive-data hygiene in scripts, CRLF-load-bearing files,
large flat library files, conditional-compilation as architecture — are the
inevitable consequences of taking the dual-language model seriously. They are
not eccentric; they are entailed.

The audience is technical architects, language designers, security-conscious
developers, and practitioners weighing the cost of "best practice" against the
cost of being honest about a system's actual structure.

## Table of contents

1. [The dichotomy, restated](#1-the-dichotomy-restated)
2. [Why the mainstream "won the argument" by abandoning it](#2-why-the-mainstream-won-the-argument-by-abandoning-it)
3. [What the dual-language model actually buys you](#3-what-the-dual-language-model-actually-buys-you)
4. [Eagle as a case study](#4-eagle-as-a-case-study)
5. [The conventions that fall out](#5-the-conventions-that-fall-out)
6. [Where this diverges from "best practice" — and why](#6-where-this-diverges-from-best-practice--and-why)
7. [What the model costs](#7-what-the-model-costs)
8. [Beauty and correctness: an aesthetic argument](#8-beauty-and-correctness-an-aesthetic-argument)
9. [Conclusion: the boundary is the feature](#9-conclusion-the-boundary-is-the-feature)
10. [Appendices](#appendices)
11. [Drafting plan](#drafting-plan)

---

## §1 The dichotomy, restated

**Section thesis.** Ousterhout's 1998 paper made an irreducible architectural
observation, not a language preference. The observation has not been refuted —
it has been *forgotten*.

### 1.1 What Ousterhout actually said (and what he didn't)

John Ousterhout's *Scripting: Higher-Level Programming for the 21st Century*
appeared in *IEEE Computer* in March 1998. The paper was provocative at the
time because it asserted that scripting languages were not just convenient but
*architecturally distinct* — they occupied a role that systems programming
languages could not fill, and the field needed to recognize the role rather
than treat it as a temporary inconvenience.

The central claim was an operational one. Programming work, Ousterhout argued,
falls into two categories that scale differently and need different tools.
The first is building algorithms and data structures — the work that turns
specifications into running primitives. The second is connecting those
primitives into applications — the work of composition, configuration, and
policy. The two have different optimization gradients, different tolerance
for ambiguity, different patterns of change.

A systems programming language, he proposed, is optimal for the first
category: typed, compiled, performance-tuned, designed to surface errors at
the earliest possible stage. A scripting language is optimal for the second:
untyped or loosely typed, interpreted, designed for malleability rather than
performance, expressive at the cost of being lenient.

What the paper explicitly did *not* claim was equally important to its
reception. It did not claim that scripting languages were always better. It
did not predict that scripting languages would stay small. It did not argue
that typing was bad. It did not even claim that the two-language division
was permanent — only that it was real, structural, and useful to recognize.

In the decade after publication, the paper was sometimes read as a manifesto
for Tcl (Ousterhout was Tcl's creator). It was not — Tcl was the example, not
the topic. The topic was the dichotomy, and Tcl was simply a clean instance.

### 1.2 Primitives and policies as distinct roles

The roles Ousterhout named have not changed in twenty-eight years.

A **primitive** is a piece of code whose correctness has to hold under every
circumstance the program could put it in. It encodes an invariant — a data
structure's representation, a cryptographic algorithm's contract, a network
protocol's framing. Its consumers depend on it being right. Its cost of being
wrong is high. Its rate of change is low.

A **policy** is a piece of code that says what to do, when, with which
primitives. It encodes a choice — whether to retry, which encryption mode to
use, when to fall back, which configuration value applies. Its correctness is
*contextual*. Its rate of change is high. Its consumers are usually humans
deciding "how should this run today?"

The distinction is empirically observable. Pick any non-trivial production
system and ask, for each module, "would I expect this to change three times
this quarter, or once this decade?" The answers separate cleanly. The modules
that change rarely are primitives; the modules that change constantly are
policies. Single-language systems hide the distinction behind a uniform
syntax, but the two roles remain.

The implications for language design are direct. A primitive benefits from
being expressed in a language that catches errors at compile time,
monomorphizes for performance, and surfaces invariant violations as type
errors. A policy benefits from being expressed in a language that allows
reconfiguration without rebuild, hot reload without restart, and runtime
introspection without ceremony. The two benefits trade off against each
other; a language that maximizes one penalizes the other.

### 1.3 The cost-curve argument

The cost-curve formulation is what makes the argument irreducible.

Consider any property a language can offer — static typing, terse syntax,
runtime hot reload, fast compilation, late binding, ahead-of-time
optimization. Each property has a cost (in language complexity, performance,
ergonomics, or all three). And each property pays off differently for
primitive code than for policy code.

Static typing pays off enormously for primitives. A cryptographic key,
mis-typed, surfaces as a compile error rather than a key-derivation failure
at three a.m. Static typing pays off marginally for policies — most policy
errors are "wrong value" rather than "wrong type," and static typing does
not catch wrong values.

Terse syntax pays off marginally for primitives — a sort algorithm that is
two lines shorter is not noticeably more correct. Terse syntax pays off
enormously for policies — a policy is usually read more than written, and
read by people scanning for what changes between deployments.

Runtime hot reload is invisible cost for primitives — primitives are rarely
changed in flight, so the machinery to reload them is overhead. Runtime hot
reload is critical for policies — the entire point of policy code is to
change without redeploying everything around it.

This pattern holds for every property a language could choose to optimize.
Each property has a different value to primitives and to policies, and the
difference is large enough that no single language can be optimal for both.
A language can be optimal for one or *compromise* for both — but optimal for
both is structurally impossible.

That is the core observation. Ousterhout did not invent it. He named it.

### 1.4 The historical pattern

Every long-lived large system has the split, even when it is not advertised.

Unix shells are a scripting language sitting above a primitive library of
utilities (`grep`, `sed`, `awk`, `find`). The shell glues utilities together;
the utilities do the work. The boundary is the process model and the pipe
abstraction. The boundary is enormously productive.

Lisp Machines had a Lisp environment driving C and microcode primitives in
the hardware. The Lisp layer was the policy and exploration layer; the
primitives were the kernel and the device drivers. The arrangement was so
productive that a generation of artificial-intelligence research depended on
it.

Smalltalk was a single language but with a clear primitive/policy split
internally: the virtual machine and its built-in classes were one layer; the
user-extensible application code was another. The two layers had the same
syntax but very different change rates and very different testing
disciplines.

Tcl + C was Ousterhout's own example. The primitive layer was C extensions
exposed through Tcl commands. The scripting layer was Tcl. The model was so
successful inside Sun Microsystems that other research groups copied it for
unrelated work.

Lua + game engines is the modern continuation. Lua scripts encode gameplay
policy (item rules, enemy behavior, level scripting); the C++ engine is the
primitive layer (rendering, physics, audio). Lua won this niche specifically
because it kept the small-kernel character.

Excel formulas + the spreadsheet runtime is the most successful scripting
environment in history by sheer user count. The formulas are policy; the
runtime (the cell graph, the recalculation engine, the built-in functions)
is the primitive layer. Most users never realize they are programming, let
alone in a dual-language system.

PostgreSQL functions, Snowflake stored procedures, eBPF programs running
over kernel primitives, AWS Lambda functions composing service primitives,
Kubernetes manifests driving the kube-apiserver primitive set — all
instances of the model. None of them describes itself this way. All of them
are.

The pattern is so pervasive that one can predict it: systems that live long
enough end up with two languages, whether they meant to or not. The only
question is whether the boundary is honest or hidden.

### 1.5 Why the model gets called "obsolete"

If the pattern is so robust, why is the model widely treated as outdated?

Two reasons account for most of it.

The first is that the high-profile *scripting* languages — Tcl, awk, Perl —
fell out of fashion through the 2000s and 2010s. They were displaced not by
single-language replacements but by Python, JavaScript, and Ruby. Those
languages started as scripting languages and grew systems-language features
over time. By the late 2010s, none of them was a clean instance of the
original model — they had each absorbed enough systems-language machinery
to look like general-purpose alternatives to C++ or Java.

A reader looking at modern Python in 2026 sees type hints, async runtimes,
dataclasses, pattern matching, a package manager more complex than CPAN
ever was, and a CI ecosystem heavier than most C++ projects. It does not
look like a scripting language anymore. The reader naturally concludes that
"scripting languages" were a passing phase. The truth is subtler: scripting
languages were a phase, and Python, JavaScript, and Ruby chose to leave it.

The second reason is that the systems languages also changed. C++ acquired
smart pointers, lambdas, ranges, modules. Rust shipped a borrow checker
that catches a category of errors C never could. Java added `var`, records,
pattern matching. Each of these moved systems languages slightly toward the
scripting end of the spectrum — not as far as the scripting languages moved
toward the systems end, but enough to make the two ends feel closer than
they used to.

The combined effect is that the *gap* — the thing Ousterhout was naming —
looks smaller. The two roles look like a single continuum that one language
can serve.

The continuum perception is wrong, but it is understandable. It rests on
observing the languages, not on observing the work. The languages
converged; the work did not. The two roles still have different
optimization gradients. The two roles still favor different language
properties. The two roles still appear in every long-lived large system.
The dichotomy is still real. Only the visibility of the dichotomy changed.

The rest of this whitepaper is an argument that the visibility matters —
that an honest boundary between primitive code and policy code produces
measurably better outcomes than a hidden one, and that the conventions
required to maintain that visibility are worth their cost.

**The cost-curve argument, visualized:**

```text
                    SCRIPTING LANGUAGE         SYSTEMS LANGUAGE
                    (e.g., Tcl / Eagle)        (e.g., C / C#)
                    ───────────────────        ───────────────

    PRIMITIVE       expensive                  cheap
    WORK
    (algorithms,    runtime errors,            types catch errors,
    invariants,     no AOT optimization,       optimizer works,
    correctness     slow hot paths             fast hot paths
    load-bearing)


    POLICY          cheap                      expensive
    WORK
    (composition,   terse, malleable,          rigid, verbose,
    configuration,  fast to change,            slow to change,
    change-heavy)   runtime malleability       awkward composition


    Neither language is optimal for both kinds of work.  This is the
    dichotomy.  A single-language system pays the cost on its weak
    side.  A dual-language system uses each language on its strong
    side and lets the boundary mediate the difference.
```

---

## §2 Why the mainstream "won the argument" by abandoning it

**Section thesis.** The languages most often cited as evidence that the
dichotomy is dead are precisely the languages that walked away from what made
scripting languages scripting languages. They absorbed every reasonable
demand and, in doing so, lost the small-kernel character that gave them their
distinctive role. The "obsolete" verdict is not a refutation of the dichotomy;
it is the observation that the languages championing one half of the dichotomy
defected to the other.

### 2.1 Scope creep: Python 1.0 to 3.13

Python 1.0 shipped in 1994. It was advertised as a small, dynamically typed
scripting language with a clean syntax, an interactive shell, and a foreign
function interface to C. The standard library was modest. The language fit
on a printed cheat sheet.

By Python 3.13, the language ships type hints (PEP 484), an async/await
runtime (PEP 492), dataclasses (PEP 557), pattern matching (PEP 634),
structural subtyping (PEP 544), positional-only and keyword-only parameters,
frozen modules, and the `typing` module's progressive overload of features
(`Protocol`, `Final`, `Literal`, `ParamSpec`, `TypedDict`, `NewType`,
`TypeVarTuple`), among dozens of other extensions added over three decades
of PEPs.

Each addition was reasonable in isolation. Type hints catch many bugs.
Dataclasses reduce boilerplate. Pattern matching simplifies branching logic.
Async/await models I/O concurrency cleanly.

The cumulative effect is that Python is no longer a small scripting
language. It is a typed, multi-paradigm, general-purpose programming
language with a scripting heritage. The cheat sheet does not fit on one
page; a senior Python developer in 2026 acknowledges corners of the
language they have never had to use. Each addition was justified by the
immediate problem it solved; the cumulative direction was away from the
small-kernel character that made scripting languages distinctive. The
same trajectory repeats across every "winning" scripting language.

### 2.2 The TypeScript turn

JavaScript started as a browser scripting language: a hundred lines of code
in a `<script>` tag, animating a button. It was designed for
non-programmers. The language model was deliberately permissive — type
coercions everywhere, undefined-is-okay, silent failures.

TypeScript launched in 2012 as a typed superset of JavaScript that compiles
to JavaScript. Within ten years, it became the default. Most "JavaScript"
code in 2026 is TypeScript that has been compiled to JavaScript at build
time. The language that is actually written is typed. The language that the
browser runs is the build artifact.

The implications are dramatic. JavaScript is no longer the language anyone
chooses; it is the target of a compiler. TypeScript is in practice a
systems language with first-class types, generics, structural subtyping,
conditional types, mapped types, and an ecosystem of tooling that rivals
what C# and Java provide. A modern TypeScript project has more compile-time
machinery than a 2010 C++ project did.

The original JavaScript — the small scripting language that ran in the
browser — is now an implementation detail. The language a developer writes
is a systems language. The boundary that Ousterhout's argument depended on
has dissolved on the language side as well as the systems side.

### 2.3 Why this happened

A generation of programmers wanted scripting without the constraints.

The constraints — loose typing, late binding, runtime-only error reporting,
limited tooling, restricted ecosystem — were precisely the costs that made
scripting languages cheap to write and easy to learn. They were also the
costs that produced runtime errors, refactoring pain, and the "it works on
my machine" failure mode. The generation that adopted Python in the 2000s
and 2010s adopted it for its strengths and gradually demanded the language
fix its weaknesses.

Each weakness, when fixed, made the language a bit larger and a bit less
scripting-like. Type hints made refactoring safer at the cost of a
separate type system to learn. Async runtimes made concurrency tractable
at the cost of "what color is your function" complexity. Package managers
made dependency management work at the cost of ten different package
managers competing for dominance.

The cumulative direction was determined by the population of users, not by
language design. Each generation of refugees from another language pushed
for the feature it missed: safety, performance, concurrency, packaging.
The language responded to each constituency.

The result was not a better scripting language. It was a systems language
with a scripting heritage — a duck-typed dynamic core wrapped in
increasingly thick layers of optional static infrastructure.

A few languages resisted this drift. Lua stayed small. Tcl stayed small.
The shell stayed shell-shaped. But each of these became niche specifically
because they refused the demands that grew the mainstream languages. The
mainstream defined "successful" as "absorbs every demand"; the languages
that stayed small lost the popularity contest by definition.

### 2.4 What was lost

The trade-off was not free.

**The small-kernel character.** A language that can be summarized on one
page is a language whose semantics fit in a developer's head. The
complexity budget of modern Python or modern TypeScript no longer fits. A
senior developer in either language acknowledges substantial corners of
the language they have never had to use; the language exists but their
working model is partial.

**Runtime malleability.** Modern Python supports runtime introspection in
theory, but the static type system pushes against it in practice. A
library that uses `__getattr__` aggressively for dynamic dispatch is
treated as a problem to be solved (with `Protocol` or `TypedDict`), not as
a feature to be used. The malleability is still possible, but the tools
encourage you not to use it.

**The "glue" character — and the script-as-configuration mental model.**
Early scripts were configurations expressed in code. A Python script that
wired together three libraries was a few lines that said *what to do*;
the language ran them. The same wiring in 2026, done idiomatically,
involves dataclasses to model the inputs, type-annotated functions to
compose them, an async context to handle I/O, and a test suite that
exercises the composition. The script is no longer the configuration;
the script is the loader, and the configuration is somewhere else — in
YAML, in environment variables, in argparse parsers, in `.env` files.

### 2.5 The price

The mainstream languages absorbed every reasonable demand. The result is
operationally complex in ways the original scripting languages were not.

**Toolchain complexity.** The tools named in §2.1 — mypy, ruff, black,
pytest, poetry, pre-commit, tox, coverage, and type stubs for every
unannotated dependency — together have a configuration surface and a
combined cognitive cost that approximates a small operating system.

**Slow CI.** A scripting project's CI used to be "run the tests." A modern
Python project's CI is type-check, lint, format-check, dependency-audit,
test, coverage-check, build-wheel, smoke-test the wheel, publish. Each
step is a build. Each build takes minutes. A change that the original
scripting language would have validated in seconds takes a quarter of an
hour.

**Performance still requires C extensions.** The languages absorbed type
systems and async runtimes but did not gain native performance. A hot loop
in pure Python is still one to two orders of magnitude slower than the
same loop in C. The high-performance machine-learning,
scientific-computing, and data-engineering ecosystems are all built on
C/C++/Rust extensions wrapped in Python. The dual-language model is still
present; it is just hidden behind the `import` statement.

**The implicit boundary returns.** A modern Python application has a
primitive layer (C extensions, system calls, network I/O) and a policy
layer (the application logic that composes them). The boundary is
invisible because the language hides it. Auditing the cross-layer attack
surface is harder; profiling the boundary cost is harder; replacing a
primitive with a faster variant is harder. The model exists; the language
refuses to acknowledge it.

The mainstream did not refute Ousterhout. It built systems where
Ousterhout's dichotomy still applies but is no longer visible.

### 2.6 The model abandoned in plain sight: Bash and templated YAML

Two ecosystems make the abandonment most visible — and the failure mode
most acute. Neither was ever a real scripting language. Both ended up
doing programming-language work because no real scripting language was
adopted for the policy layer. Both produce code that is harder to write,
harder to read, and harder to maintain than the same work done in a
small, well-designed scripting language with a real boundary. Both have
nonetheless become the default in their domains.

**Bash as a scripting language.** The Bourne shell and its descendants
were designed as command languages — type a command, get a result, move
on. The scripting affordances accreted around that core: variables,
conditionals, loops, functions. Each addition was reasonable in
isolation; cumulatively the result is a language whose semantics defy
reasoning at any nontrivial scale.

Word splitting depends on `IFS`. Quoting rules differ between single
and double quotes, between command substitution and parameter
expansion, between arithmetic context and string context. Unquoted
variable references silently lose word boundaries; quoted references
preserve them but suppress glob expansion; quoted references with array
indices do something else again. Error handling defaults to "continue
and hope" unless `set -euo pipefail` is set early. Conditional tests
have at least four syntactic flavors (`[ ... ]`, `[[ ... ]]`,
`(( ... ))`, `test`), each with its own quoting and operator semantics.
Numeric vs. string comparison is a runtime question.

The result is that Bash scripts of any size become exercises in
defensive coding against the language itself. A senior shell
developer's working knowledge is largely a catalog of quoting traps
avoided. The existence of `shellcheck` is itself evidence: no community
builds a dedicated linter for a language unless the language's quoting
rules are so error-prone that a separate tool is needed to catch the
common mistakes.

This is not the trade-off Ousterhout had in mind. A scripting language
is supposed to be *cheaper* than a systems language for composition
work. Bash is, in practice, *more* expensive — every variable use
requires careful escaping, and an error at any quoting boundary can
corrupt the entire script's behavior. A real scripting language (Tcl,
Lua, Python before the type-system additions) costs less per line of
policy code than Bash does, because the language does not require
constant defense against its own evaluation model. The lesson is not
that Bash is bad. The lesson is that the shell-as-scripting-language
model is not a substitute for the dual-language model. Bash works
admirably as a command language. When it is pressed into service as a
policy layer for systems of any complexity, the cost compounds until
the shell script becomes a system in its own right — with all the
maintenance burden of a program but none of the language affordances.

**Templated YAML as a programming language.** §3.6 will argue that
configuration should be expressed in a real scripting language. The
mainstream alternative is a configuration language (YAML, JSON, TOML,
HCL) plus a templating system (Jinja2 for Ansible, Go templates for
Helm, Mustache for various, Sprig for the brave). The result is, in
practice, a programming language; but a programming language assembled
by accretion rather than designed.

Consider Helm. A Helm chart is YAML processed through Go's
`text/template` with the Sprig function library. The template syntax
is not YAML; it embeds *into* YAML through delimited substitutions,
evaluated before the YAML parser sees them, so a template error
surfaces as a YAML syntax error somewhere downstream. The Sprig
library provides hundreds of functions, each with its own semantics.
Conditional rendering, looping, scope inheritance, variable
assignment, and recursion are all available. The result is
Turing-complete. The only thing missing is the design of an actual
language.

A real scripting language with a small custom DSL — `[helmRelease
$name { values { ... } }]` style, where `helmRelease` is a command,
`values` is a sub-command, and the body is real script code — would
be radically simpler. The DSL commands are the structure; the script
body is the policy code. Syntax is uniform; errors point at the
source rather than at the post-expansion artifact; the type system,
the scoping rules, and the error model are properties of the
language rather than emergent properties of the templating layer.
This is precisely what the dual-language model offers and what
templated YAML reinvents badly.

The same pattern recurs in Ansible (YAML with Jinja2), in Kubernetes
manifests with Kustomize patches, in GitLab CI YAML with included
templates, in GitHub Actions with expression syntax embedded in YAML
strings. In each case, the underlying realization is the same: a
configuration language was not enough; the project needed a
programming language; rather than adopt one, the ecosystem invented
one inside the configuration language, badly.

**The shared lesson.** Bash and templated YAML are different failures
of the same design choice. Bash is a command language strained into a
scripting language. Templated YAML is a configuration language
strained into a programming language. Both reach the same outcome —
an ad-hoc, accreted, hard-to-reason-about substrate doing work that a
small, well-designed scripting language could have done cleanly. The
mainstream alternative to the dual-language model is, in plain sight,
this: pretend you do not need a scripting language, then accidentally
build one anyway. Each shellcheck, each helm-lint, each ansible-lint
is a confession that the underlying language was not designed for the
work it is doing.

The dual-language model, by contrast, treats the boundary as a feature.
The remainder of this whitepaper argues that visibility is worth its
costs.

---

## §3 What the dual-language model actually buys you

**Section thesis.** When the boundary is explicit and the two layers are kept
distinct, several properties fall out automatically that single-language systems
have to work hard to fake.

### 3.1 The boundary as a feature, not a leak

A scripting language that does not mark its cross-layer calls makes those
calls disappear. In Python, the line `from numpy import array` looks
identical to the line `from pathlib import Path`. Both are imports. Only one
of them is crossing a language boundary; the cost is dramatically different;
the reader cannot tell.

The cost is not aesthetic. When the boundary is invisible, several things
become difficult that should be easy. Auditing the cross-layer attack
surface requires inferring which imports cross to native code. Profiling a
slowdown requires knowing where the marshalling happens. Replacing a
primitive with a faster variant requires finding all of its call sites,
which the language has actively hidden. Understanding why two
seemingly-identical operations have very different memory behavior requires
reading the source of the upstream package.

When the boundary is explicit, all of these become trivial. Eagle's
`[object create]` and `[object invoke]` calls are searchable; you can grep
for them. The set of cross-layer calls in a given module is enumerable. The
cost of each is annotated by its visibility — a reader sees the call and
knows it is expensive in a way a script-internal call is not.

The honest boundary is not just a nicety. It is a feature that pays off in
every long-lived activity the policy layer needs to support: audit,
optimization, replacement, debugging.

### 3.2 Performance separation

Hot paths belong in the primitive layer. The reason is not ideological — it
is that compilers can do work on primitive code that they cannot do on
policy code, and that work pays off proportionally to call frequency.

A primitive sort routine, written in C# and compiled with optimization,
achieves throughput within a factor of two of hand-written C. The same sort,
expressed at the script level, is one to two orders of magnitude slower
depending on the language and the input shape. For code on a hot path, that
gap matters.

Critically, the model does not require the *policy* code to pay any of that
performance cost. The policy code calls into primitives that are already
optimized. The policy code's cost is dominated by the boundary cost, not by
its own execution. As long as the boundary is crossed at a frequency that
does not dominate runtime — typically thousands of calls per second is fine,
millions of calls per second is not — the cost is irrelevant.

This is why the model works: the optimization wedge between primitive and
policy code is large enough that policy code can be lavishly expressive
without paying for the expressiveness. A policy expression in Eagle that
takes thirty microseconds to execute is calling primitives that took
milliseconds of CLR optimization to produce. The policy gets the benefit
without the cost.

Single-language systems can only achieve this by hiding their primitives —
by inlining C-extension calls under "regular function calls" — which brings
the implicit-boundary problem back from §3.1.

### 3.3 Safety surfaces

Trust enforcement, sandboxing, and audit logging want to live at a boundary.
They are properties of a transition, not properties of a function. The
primitive-policy boundary is the natural transition to enforce.

In the Eagle/Harpy model, the loading of a script is the audit event. The
`[interp eval]` call into a sandboxed child is the trust boundary. The
`[object invoke]` call is the privileged operation. Each of these is a
marked syntactic event; instrumenting them is straightforward.

In a single-language system without an explicit boundary, the same
enforcement requires instrumenting every call — every method invocation
could potentially be the call that loads untrusted code, accesses the file
system, or makes a network request. The instrumentation is either pervasive
(and expensive) or selective (and incomplete). The dual-language model gives
you a smaller, well-defined surface to enforce on.

This is one of the reasons the model recurs in security-sensitive
deployments. Embedded SQL functions, WebAssembly sandboxes, eBPF policies —
all of them are dual-language deployments specifically because the boundary
is a useful place to put the security enforcement.

### 3.4 Testability

Each layer has its own test discipline, and they do not interfere with each
other.

The primitive layer is tested as a library. Unit tests, integration tests,
benchmarks. The discipline is conventional: well-known frameworks, common
idioms, mature tooling.

The policy layer is tested as a script suite. In Eagle's case, the `[test]`
and `[test2]` commands implement a constraint-driven test framework: each
test declares which constraints it requires (a runtime version, a plugin,
an environment property), and the framework dispatches accordingly. Tests
can be skipped on platforms where they do not apply without being marked
failed; tests can be added without rebuilding the primitives.

The two test disciplines do not contaminate each other. A change to a
primitive is exercised by primitive tests *and* by any policy test that
exercises that primitive — providing two independent paths to detection.
A change to a policy is exercised only by policy tests, which is fine
because the policy change does not affect the primitives.

Single-language systems usually end up with a single test discipline, which
means either over-testing what does not change much or under-testing what
changes constantly. The dual-language model lets each layer pay only its
own test cost.

### 3.5 Signed-artifact trust chains

When the policy layer is source, it can be signed.

This is a structural property of having a source-level scripting layer. The
deliverable is a script file (or a directory of script files). The file can
be signed before deployment and verified at load. The signature attaches to
the actual bytes the interpreter will read.

Compiled artifacts can be signed too, but the signature is over the
artifact, not the source. Reproducing the source from the artifact is an
extra step that introduces drift. A signed source artifact is directly
verifiable against version control; a signed binary artifact requires the
deployment pipeline to be trusted as well.

The Harpy chain in Eagle implements this in detail. A script file
`foo.eagle` is signed by some authority, producing `foo.eagle.harpy`. The
interpreter, on `[source foo.eagle]`, reads the script bytes, fetches the
signature, verifies it against trusted keys, and either runs the script or
refuses. The trust chain is end-to-end: from authoring to execution, no
compilation step intervenes.

This is what makes the dual-language model deployable in environments with
strong audit requirements. The policy is text. The text is signed. The
verifier verifies the text. There is no machinery between source and
execution that could be subverted.

### 3.6 Configuration-as-code

The policy layer is the configuration layer. This is not a metaphor; it is
literally true in any dual-language deployment.

In a single-language system, configuration is a separate concern. The
application code is one language; configuration is YAML or JSON or HCL; the
application reads the configuration into a structured representation; the
application checks the configuration for validity; the application uses the
configuration to dispatch its logic.

Each of those steps is a thing that has to be designed, documented, tested,
and maintained. YAML parser quirks become production incidents. Schema
migrations require careful versioning. Configuration validation has to
duplicate the logic that consumes the configuration.

In a dual-language system, configuration *is* policy code. The script is
the configuration. The script syntax is the configuration syntax. The
script's runtime is the configuration's runtime. There is no parser to
design, no schema to migrate, no validation step distinct from execution.

The cost is that the configuration syntax is more powerful than a typical
YAML file — a malicious or buggy configuration can do anything a script
can do. The dual-language model addresses this with the trust chain from
§3.5: configurations are signed, the signature is verified, untrusted
configurations are refused. The combined system is simpler than a
single-language application plus its YAML parser plus its schema validator
plus its versioning machinery.

### 3.7 Hot reload of policy

Because policy lives in source files that the interpreter reads at runtime,
policy can be reloaded without rebuilding anything else.

This is not the same as "hot reloading code in a dev loop." It is
operationally important: a production deployment can update its policy
without redeploying the primitives. A new test scenario can be added by
writing a script. A new configuration can be applied by replacing a file
(with a fresh signature) and asking the interpreter to re-source it.

The redeployment friction for policy changes drops from "build, package,
deploy, restart" to "write, sign, copy." That gap is the difference between
policy changes that happen weekly and policy changes that happen
continuously. Systems that need continuous policy change — security
gateways, fraud detection, A/B testing — usually end up with a dual-language
model because it is the only way to keep the change rate sustainable.

Single-language systems can simulate hot reload through plugin loading,
code generation, or runtime metaprogramming, but the result is invariably
more complex than the dual-language baseline. The dual-language model
achieves hot reload as a side effect; everything else achieves it as a
feature.

The same property extends, with a twist, to the primitive layer
itself. Eagle's `csharp.eagle` script library exposes a procedure
called `[compileCSharp]` that accepts C# source as a string,
compiles it into a .NET assembly at runtime (via
`Microsoft.CSharp.CSharpCodeProvider` on Framework, or by invoking
`csc.dll` through `dotnet exec` on .NET Core), and returns a handle
the script can load via `[object load]`. The policy layer can,
deliberately and explicitly, *generate new primitive code* at
runtime and bring it into the same interpreter that produced it.
The dual-language boundary, in this case, loops back on itself:
script-side policy code reaches into the primitive-language design
space, produces a typed primitive, and the boundary the rest of
this whitepaper describes mediates between the script that asked
and the primitive that resulted. This is hot reload extended to
its most extreme form — not merely "the policy can be changed
without rebuilding," but "the set of available primitives can be
changed without rebuilding either."

**The boundary as the place where seven properties intersect:**

```text
   ┌─────────────────────────────────────────────────────────┐
   │              PRIMITIVE LAYER (C# / .NET)                │
   │             typed, compiled, optimized                  │
   └──────────────────────────┬──────────────────────────────┘
                              │
                    ╔═════════╧═════════╗
                    ║                   ║
                    ║   THE BOUNDARY    ║
                    ║                   ║
                    ║  [object create]  ║
                    ║  [object invoke]  ║
                    ║  [object dispose] ║
                    ║                   ║
                    ╚═════════╤═════════╝
                              │
   ┌──────────────────────────┴──────────────────────────────┐
   │              POLICY LAYER (Eagle / Tcl)                 │
   │             small-kernel, malleable, terse              │
   └─────────────────────────────────────────────────────────┘

   When the boundary is explicit, seven properties fall out:

     1. Auditability             every cross-call is grep-able
     2. Performance separation   hot paths in compiled primitives
     3. Safety surfaces          trust enforced at the bridge
     4. Testability              each layer tested in its own style
     5. Signed-artifact trust    source-level signatures (Harpy)
     6. Configuration-as-code    policy IS configuration
     7. Hot reload of policy     re-source without rebuilding
```

### 3.8 The boundary is fractal: mini-languages as embedded boundaries

The argument so far has treated the boundary as a top-level
architectural property — primitive layer on one side, policy layer on
the other, `[object]` in the middle. The same boundary discipline
recurs at smaller scales. Anywhere a host language embeds a string
that gets interpreted as a domain-specific grammar, there is a
*mini-language* with its own primitive / policy split. The pattern is
the policy (what to match, what to compute, what to format); the
engine that interprets it is the primitive (how to match, compute,
format).

The examples are everywhere. Regular expressions in nearly every
language. Glob patterns with braced alternation (`*.{txt,md}`) in
shells and in `[glob]` / `[string match]`. Mathematical expressions
in `[expr]`, in SQL `WHERE` clauses, in spreadsheet formulas. Format
strings in `[format]`, `printf`, `strftime`, `[clock format]`. SQL
itself embedded via parameterized queries. XPath and CSS selectors
embedded in DOM traversal. JSONPath in JSON tooling. Cron
expressions in schedulers. Semver constraints in package managers.
CIDR notation in network configurations. Host-specific primitive
layers add their own: Eagle, for instance, ships an attribute-flags
mini-language for per-entity flag markers and a flag-enum
mini-language for `[Flags]`-typed parameters (with a table-selection
extension) — both discussed below. Each is a small grammar for a
specific domain; each lives inside a host language as a string that
gets compiled and interpreted by an engine.

The mini-language and its host obey the same boundary properties §3.1
through §3.7 named at the top level. The pattern is auditable (grep
for regex literals, lint them, test them in isolation). Performance
separation holds (the regex engine compiles once and matches many;
the host string operations do not). The safety surface is the
engine's parser (a malformed regex is a parse error before it does
any harm). Testability is real (each pattern is its own artifact).
Configuration-as-code applies (the pattern *is* the configuration,
expressed in a small domain-specific syntax rather than a generic
data structure that has to be parsed twice).

**Mini-languages are data domains, not strings.** A regular
expression is not just a string. It is a string in the well-defined
sub-domain of *valid regex patterns* — the strings that the host's
regex engine recognizes as a parseable pattern. Similarly, a cron
expression is a string in the sub-domain of cron-grammar-valid
strings; a CIDR notation is a string in the IPv4-or-IPv6
prefix-syntax sub-domain; a semver constraint is a string in the
version-constraint sub-domain. Each mini-language defines what
counts as a valid value, and the set of valid values is a *data
domain* — a type-like restriction over the broader string type that
the host language exposes.

The distinction matters because string types in most host languages
are wide open. A function whose signature says "takes a string"
accepts every string the host can produce, including the many
strings that are not valid regex patterns / cron expressions /
CIDRs / semver constraints. The data domain is invisible to the
host's type system; if it is enforced at all, it is enforced *at
the boundary* — when the regex engine parses the pattern, when the
cron scheduler validates the expression, when the IP library
parses the CIDR notation. This is the §3.3 safety-surface argument
at a smaller scale: the mini-language's engine is the type
checker, and the parse step is where type errors get caught.

What varies across host languages is two things at once: how
visible the data domain is at the host level, and what *integration
design* the host uses to bind the mini-language's outputs back into
host-level values. Some hosts treat mini-language strings
opaquely until use (Tcl, Eagle, shell scripts). Some give the
mini-language its own syntactic category distinct from strings
(Perl's `m/.../`). Some expose the parsed form as its own host type
(`System.Text.RegularExpressions.Regex` in .NET,
`re.Pattern` in Python). Each choice is a different answer to the
same question: how much should the host's type system know about
the mini-language's domain? And once parsed, how should the
mini-language's outputs — matches, captures, computed values —
re-enter host-level code?

The two questions are independent in principle but coupled in
practice. A host that exposes the parsed form as a type tends also
to expose match results as typed objects (`Match.Groups[1]`). A
host that treats the pattern as a string tends also to expose
matches as strings (with the binding to host variables done by some
other mechanism). The integration design is where those choices
land. The choice reveals what the host considers important.

**Tcl's and Eagle's `[regexp]` as a study in integration.** The
integration uses three mechanisms in concert, each chosen to fit the
rest of the host language.

*Return value names the question.* `[regexp $pattern $string]`
returns the number of matches found — zero for no match, positive
integer otherwise. This composes naturally with the §8.3 predicate
convention (`if {[regexp $pattern $string] > 0]}`), reads as "did
anything match?", and degrades cleanly when the caller does not care
about captures.

*Output variable names pass captures by name.* `[regexp $pattern
$string fullVar group1Var group2Var ...]` writes captured groups
into caller-named variables via `[upvar]`. The convention is uniform
with how the host handles output parameters elsewhere — see also
`[regsub]`, `[binary scan]`, the `[lassign]` form. The caller chooses
the variable names at the call site, so a regex extracting an HTTP
method, path, and version writes them into `method`, `path`,
`version` rather than into indexed positions in a returned array.
The names at the call site document what the captures mean; a reader
does not need to consult the pattern to know what each group
represents.

*Eagle adds per-match script callbacks on the substitution path.*
The script-side `[regsub]` accepts a backreference template (`\1`,
`\2`) for the replacement. Eagle extends this with a per-match
script callback: each match runs a script that has access to the
captures and returns the replacement string. The callback is policy
code executing inside what would otherwise be a single primitive
operation; the mini-language and the host language interleave at
every match boundary. A regex substitution that wants to perform
arbitrary computation per match — case conversion, validation,
lookup, conditional replacement — does not have to fall back to
manual loop-and-match.

The three mechanisms compose. A complex regex over text, where each
match needs computed replacement and the captures need to flow into
named variables, would in most languages require splitting into
match → extract → compute → substitute steps. In Eagle it can be
one `[regsub]` call whose script callback reads captures from named
variables and returns the replacement. The design is consistent with
the rest of the host: pass-by-name matches `[upvar]` and the broader
output-parameter convention, and the script callback matches the
§5.4 "hooks as named procs" pattern of putting extension points
where the language already extends.

**Eagle's flag-enum mini-language and its table-selection
extension.** Beyond `[regexp]`, Eagle's primitive layer ships two
further mini-languages that show what well-designed integration
looks like at the small scale. The first, in
`Eagle._Components.Private.AttributeFlags`, parses per-entity
attribute markers identified by hexadecimal keys and modified by a
small set of operator characters: `+` adds a flag, `-` removes one,
`=` sets one. Beyond the operators, the syntax defines character-class
wildcards — `*` for all flags, `#` for digit-named flags, `!` for
alphabetic, `$` for upper-case, `@` for lower-case — so an expression
like `+*` enables every flag in the namespace and `-#` removes every
digit-keyed one.

The second, in `Eagle._Components.Private.EnumOps`, parses values
for `[Flags]`-typed enumeration parameters. The base operator set is
similar but tuned for declarative manipulation of typed bit-fields:
`+` adds (bitwise OR), `-` removes (bitwise AND NOT), `=` sets
(replace), `:` sets-then-adds (the default if no operator is given,
so a bare `{NonPublic Static}` reads as `{:NonPublic +Static}`), and
`&` keeps (bitwise AND). A value like `{+NonPublic +Static
-DeclaredOnly}` reads as a sequence of declarative mutations against
the parameter's current or default value, and Eagle's *Universal
Option Parser* dispatches the syntax automatically wherever a command
option is typed as a `[Flags]` enum — so `[object invoke -flags
{+NonPublic +Static} $obj Method]` and dozens of similar call sites
all share the same mini-language without each command having to
re-implement it.

The interesting design choice in this second mini-language is the
**table-selection extension**: a `/` operator that switches the
*active table* the subsequent operators apply to. When an enum
decorates its members with `[ParameterIndex(N)]` attributes, EnumOps
can partition the enum into multiple sub-enumerations grouped by
parameter index. A single mini-language expression then drives all
of them at once: `{/0 +ReadOnly +SignedScript /1 +AllowAlias}`
switches to table 0, adds two flags, then switches to table 1, adds
one. The host call ends up with multiple typed enum values populated
from a single string — without the script-side having to thread
the values through separate calls.

The extension is interesting precisely because the design of the
base operator set anticipated it. The operator characters
(`+`, `-`, `=`, `:`, `&`) are all reserved at start-of-token
position; `/` joins that set without colliding with anything in the
base syntax. The "active table" state is purely lexical — it
persists across tokens within a single expression and resets per
call — so the mini-language stays declarative even with the
state-switching operator. A script call to a primitive that takes
multiple flag-typed parameters becomes one expression instead of one
call per parameter, and the call site documents which flags belong
to which parameter through the `/N` markers.

This is the same integration discipline `[regexp]`'s pass-by-name
captures use. The mini-language's syntactic conventions (operator
characters, lexical state, brace-quoted token lists) compose with
the host's existing conventions (brace-quoted bodies, declarative
options). A reader who has internalized the host's idioms recognizes
the mini-language as following the same shape, just specialized for
the flag-mutation domain. The dual-language model recurs: the
mini-language is a sub-policy syntax; the parser is its primitive;
the design choice was to make the syntax extend the host rather than
colonize it.

These two Eagle mini-languages are also, in their own right, worked
examples of the §8.4 thesis. The base operator sets are cohesive,
symmetric, and minimal; the table-selection extension was anticipated
by the base design rather than retrofitted into it (the `/` operator
joined a five-character reserved start-of-token set without colliding
with anything); the syntax composes with the host's existing
conventions rather than fighting them. Both subsystems have shipped
across years of Eagle development with effectively zero substantive
defects in either the parsers or the integration surfaces — their
beauty by the §8.2 criteria and their correctness by the criterion of
"no audit found a bug" are not independent facts.

**Other languages' choices, briefly.** Python returns a `Match`
object queried by group index or group name (`m.group("year")` when
named groups are used). Perl uses implicit globals (`$1`, `$2`,
`$&`, `$+`) and a successful match returns true. JavaScript returns
an array or `null`. Ruby uses a magic variable (`$~`) plus indexed
access. Each choice fits the surrounding language: Python's
named-group access matches its affinity for named arguments;
Perl's implicit globals match its terse pipeline aesthetic;
JavaScript's array-or-null matches its conditional-shortcut
idioms. There is no universally right choice; there are only
choices that integrate well with the rest of the language and
choices that don't.

**Why this matters for the dual-language argument.** The boundary
§§3.1–3.7 named is not a single boundary at the top of the system; it
is a discipline that recurs at every scale. A primitive layer that
exposes mini-languages well — with consistent capture mechanisms, a
callback story, parser-level error reporting — is one whose §3
benefits compound; the regex engine is tested independently of the
script that uses it, the cron expression is auditable independently
of the scheduler, the format string is parseable independently of
the I/O call. A primitive layer that exposes mini-languages badly —
stringly typed escapes, no consistent capture mechanism, no callback
story — leaks complexity into every call site.

The dual-language model is, in this sense, fractal. A scripting
language that drives a primitive layer at the top level also drives
mini-languages at every operation that touches a domain-specific
grammar. The discipline that makes the top-level boundary work makes
the mini-language boundaries work too, and the §5 conventions —
override patterns, defensive guards, the predicate idioms of §8.3 —
apply at this scale the same way they apply to cross-layer calls.
The fractal is not a metaphor; it is a property of how the model
scales.

---

## §4 Eagle as a case study

**Section thesis.** Eagle is interesting not as an end in itself but as a
working instance of the model — a Tcl-semantics scripting layer on a .NET
primitive layer, with an explicit boundary and a designed trust chain. The
unusual conventions in the Eagle ecosystem are not eccentric; once the model
is taken seriously, they are entailed.

### 4.1 Eagle's lineage

Eagle (Extensible Adaptable Generalized Logic Engine) is a Tcl-semantics
scripting language hosted on the .NET CLI, in continuous development since the
late 2000s. It is not a Tcl interpreter for .NET in the sense of a
re-implementation of `tclsh` — it is a separate scripting layer that took Tcl's
semantic model (command-language kernel, brace-quoted bodies,
everything-is-a-string substrate, first-class commands) and built it natively on
top of the .NET type system.

Why Tcl semantics specifically? Because Tcl's small-kernel character is the
load-bearing property. The entire core language is a handful of byte-level
rules — substitution, brace-quoting, bracket evaluation — and everything else is
a command, addable at runtime. That property is exactly what Ousterhout was
pointing at: a scripting language that lets the primitives define the policies,
not the other way around. A Lisp-on-CLI or a Python-on-CLI would inherit each
of those languages' opinions about what counts as a useful idiom; Tcl-on-CLI
inherits a minimum.

Why .NET specifically? Three reasons. First, the .NET type system gives
Eagle an enormous primitive layer for free — every .NET class is available
as an Eagle primitive via the `[object]` command (which offers
forty-three sub-commands, from `[object create]` through `[object emit]`
to `[object verifyall]`). Second, .NET's strong-name and Authenticode
infrastructure gives Eagle a working trust model out of the box. Third,
.NET has mature cross-language interop (CLI metadata, reflection,
ECMA-335 standardization) — exactly the surface a scripting layer needs
to reach into a primitive layer.

Eagle's actual deployment surface is large. The same codebase compiles
against .NET Framework 2.0 RTM, every 4.x point release, .NET Standard
2.0 and 2.1, and .NET 5 through .NET 10+; it runs on Mono; it targets
Windows, Linux, and macOS. The cross-version support is not a happy
accident — it is enforced by an eleven-project `.csproj` matrix, with
each project representing a real build configuration that some
deployment depends on. The dual-language model would be less defensible
in a language whose primitive layer fragmented across runtime versions;
Eagle deliberately accepted the maintenance cost of staying portable so
that the dual model itself stays portable.

Eagle also closes the loop in the other direction. The `[tcl]` command
lets an Eagle script load a native Tcl library and drive it; the Garuda
package lets a native Tcl interpreter load the CLR and drive Eagle. The
bidirectional bridge means an Eagle deployment can interoperate with
existing Tcl ecosystems in both directions — Tcl as a primitive layer
to Eagle's policy code when there is a useful Tcl library to call, Eagle
as a CLR-bridged scripting layer to existing native Tcl programs when
the Tcl side is the primary host.

The combination is unusual. There is no "the scripting language for
.NET" — F# and PowerShell aimed at parts of the space but neither is a
clean instance of the dual-language model. F# is a systems language.
PowerShell is a shell with some scripting affordances bolted on. Eagle
is the scripting layer Ousterhout's thesis predicts you would build if
you took the dichotomy seriously and the host was the CLI.

### 4.2 The `object` command: the boundary made visible

In Eagle, every cross-layer call is a marked syntactic event. The `[object]`
command is the bridge:

```tcl
set algorithm [object create -alias \
    System.Security.Cryptography.Rfc2898DeriveBytes \
    $password $saltBytes $iterations $hashAlgorithmName]

set keyBytes [$algorithm GetBytes $keyLength]
$algorithm -type IDisposable Dispose
```

Three things are visible in this snippet that would not be visible in a typical
FFI binding.

First, the .NET class name appears in full:
`System.Security.Cryptography.Rfc2898DeriveBytes`. There is no `using`
statement that quietly determined the namespace; the script names the type it
wants. This is verbose, but it makes the boundary auditable — a reader can grep
for class names and find every cross-layer call site.

Second, the call style is explicit. `[object create]` allocates and constructs.
The returned handle is opaque to the script — it is a string-shaped reference
to a CLR object, not a script-side value. Calls into the object are
syntactically dispatched through the handle, not through method-call syntax.
The script never confuses a script value with a CLR reference.

Third, disposal is the script's responsibility. The
`[$algorithm -type IDisposable Dispose]` form is verbose by design — it makes
the resource-release call as visible as the construction call. The
dual-language model puts lifetime management at the boundary; Eagle exposes
that responsibility rather than hiding it.

Compare this to a typical FFI binding in a more modern language:

```python
from Crypto.Hash import HMAC   # what type? what cost? hidden
h = HMAC.new(key, msg, algo)   # boundary crossed twice, both invisible
mac = h.digest()               # boundary crossed again, still invisible
```

Both styles produce the same result. Only one of them makes the cost visible
to the reader.

### 4.3 Brace-quoted bodies as a contract

Eagle proc bodies are conventionally brace-quoted:

```tcl
proc encryptScript { script password salt } {
    # ... body ...
}
```

The opening and closing braces around the body delimit a verbatim region —
Tcl's brace-quoting suppresses all substitution. The bytes between the braces
are the bytes that get executed. There is no string interpolation, no escape
processing, no normalization step.

This is a contract, not a stylistic preference. Because the body bytes are
verbatim, they can be (a) signed independently of the surrounding file,
(b) extracted by introspection commands like `[info body]`, (c) parsed as XML
when they contain embedded `# <help>` blocks, and (d) compared byte-for-byte
for equality. Every one of those properties depends on the body being a
sequence of unprocessed bytes.

The cost is that any unbalanced brace inside the body — including a literal
open or close brace in a comment — breaks parsing. The `# <help>` discipline
therefore prohibits literal braces in help text; the conventional description
is in prose ("open brace", "curly braces") or in escaped form. This is the
kind of constraint that looks ugly until you notice it pays for the four
properties above.

### 4.4 First-class introspection

Eagle scripts can ask the questions a debugger asks, *while running*, and act
on the answers. The relevant commands are part of the language kernel, not a
separate library:

| Primitive | What it returns |
|---|---|
| `[info level]` | The call stack depth at the current site. |
| `[info level $n]` | The arguments to frame `$n`. Note: `[info level [info level]]` returns the *current* frame, not the caller — a Tcl convention that surprises newcomers. |
| `[info commands]` | Every command currently defined in the interpreter. |
| `[info procs]` | Every proc, with bodies retrievable via `[info body]`. |
| `$::eagle_platform(...)` | A global array variable (not a command) holding runtime properties — framework version, runtime engine, build options, processor architecture. |
| `[info script]` | The script file currently sourcing. |
| `[info engine]` | The hosting engine (Eagle vs. native Tcl), with sub-keys for vendor, version, compile options. |

The result is a scripting layer that is fully reflective on itself and on the
primitive layer simultaneously. A script can discover at runtime which .NET
framework version it is running on (`$::eagle_platform(frameworkVersion)`),
which compile options the primitive layer was built with
(`$::eagle_platform(compileOptions)`), whether a particular primitive is
available (`[llength [info commands ...]]`), and dispatch accordingly. The
policy layer does not have to be re-deployed for every primitive-layer
variant; it can adapt.

This is the property that makes the `[checkFor*]` constraint system in the
test suite work — every test gates on dynamic queries against the actual
running interpreter, not against a compile-time configuration matrix. A test
that needs Mono can ask whether the runtime is Mono; a test that needs a
specific .NET Framework build can probe the version; a test that needs a
plugin can check whether the plugin is loaded. The constraint system is a
small protocol on top of these introspection primitives, and it works because
the primitives exist.

### 4.5 The `# <help>` block discipline

Every Eagle script library procedure carries a documentation block embedded in
its body:

```tcl
proc lshuffle { list } {
    # <help>
    # This procedure returns a new list whose elements are a uniformly
    # random permutation of the input list.  ...
    #
    # How it works: ...
    #
    # Arguments:
    #   list -- The list to shuffle; the original is not modified.
    #
    # Results:
    #   A new list containing the same elements as the input, in
    #   randomized order.
    # </help>

    # ... body ...
}
```

The `# <help>...# </help>` markers form an XML-shaped block, parsed by the
`HelpOps` component of the primitive layer and exposed to scripts via the
interactive `#help <proc>` command. A user at an Eagle shell can type
`#help lshuffle` and the matching help block renders, with the leading `# `
prefixes stripped.

Three observations about this convention.

First, the documentation lives *inside the procedure*. It cannot be separated,
lost, deleted, or skipped in a CI pipeline. The procedure body is the
artifact; the documentation is part of the artifact. This is structurally
different from external documentation (manpages, wikis, docstrings extracted
to a separate file). It cannot drift in the same way, because drifting
requires editing the proc.

Second, the documentation is *queried at runtime*. There is no `man
eagle-lshuffle` step. The user asks the interpreter, which knows. This is the
dual-language model applied to documentation: the scripting layer answers
questions about itself.

Third, the discipline is *maintained by humans* and *audited periodically*.
The audit work that produced the case study material for this whitepaper —
roughly a thousand procedures cross-checked against their implementations,
nineteen documentation fixes applied, three code defects surfaced as a
byproduct — is a real ongoing cost. The convention pays for itself by
collapsing documentation, source, and runtime help into one artifact; it does
not pay *itself*. Someone has to write and maintain the blocks. The systems
that succeed at this discipline budget for it as a permanent line item, not
as an occasional cleanup pass. (Appendix C presents a complete worked
example: the `[lshuffle]` procedure with its `# <help>` block, annotated
and accompanied by the rules the block illustrates.)

### 4.6 The Harpy trust chain

Eagle script files are deployed alongside detached cryptographic signatures.
A file `foo.eagle` typically has a sibling `foo.eagle.harpy` containing a
signature over the script's bytes. The signature is verified by the Harpy
plugin when the script is loaded; an unsigned or mis-signed script in a
security-enabled interpreter is refused.

Several design choices in this trust chain are load-bearing.

**Detached by default; inline supported.** The default deployment shape is
a detached signature alongside the artifact: editing a signed script does
not corrupt the script, it only invalidates the signature. The script
remains a readable, executable artifact; only its trust status changes.
This means signed and unsigned variants of the same script can coexist,
and unsigned variants can be tested before signing. Harpy also supports
*embedded* signatures — the signature can be carried inside the script
file rather than alongside it — for deployments where a single artifact
is operationally preferable. The detached form is the default because it
preserves the source as a directly editable, directly readable artifact;
the embedded form remains available where deployment constraints prefer a
single file over a pair.

**Source-based, not bytecode-based.** The signed artifact is the script
*bytes*, not a compiled form. There is no compile-link-sign cycle. The
artifact is what the human wrote and what the interpreter reads. This
eliminates an entire class of supply-chain attacks where a compiler could be
subverted between source and signature.

**CRLF as part of the contract.** Eagle script files conventionally use CRLF
line endings (the .NET ecosystem default). Once a file is signed, those line
endings are part of the signed payload. A tool that re-normalizes the file to
LF invalidates the signature — not because LF is wrong, but because the bytes
changed. The documentation tooling in the sibling docs repo includes an
explicit EOL preservation rule for tools that edit `.eagle` files outside the
docs repo itself; the rule is not about line endings, it is about what gets
signed.

**Key rings, not single keys.** Trust in Harpy is mediated by key rings —
collections of trusted keys, each with policy attached. A deployment can
trust the vendor's key for distributed scripts, the operator's key for
site-specific scripts, the developer's key for in-development work, and
revoke any of them independently. The model maps directly to organizational
trust boundaries.

The whole arrangement is what allows Eagle to be deployed as a *script-first*
system. The deliverable is signed source. The interpreter reads, verifies,
and runs. There is no separate binary distribution step for policy code.
This is the dual-language model's deployment story.

### 4.7 Security as runtime state

The primitive layer exposes security policy as mutable interpreter state.
A script can query the current security state of its interpreter, gate
behavior on it, and (with appropriate authorization) construct child
interpreters with different security settings:

```tcl
if {[interp issafe]} then {
  # restricted command set, sandboxed file system, no network
} else {
  # unrestricted; may create sandboxed children for untrusted work
  set sandbox [interp create -safe child-name]
  interp eval $sandbox $untrustedScript
}
```

But `[interp create -safe]` is only the entry-level mechanism. The
canonical Eagle safe-interpreter model is *five independent security
layers*; an attacker has to bypass all five to escape the sandbox:

1. **Command hiding.** When a safe interpreter is created, every
   command without the `CommandFlags.Safe` attribute is automatically
   hidden. Hidden commands exist in a separate dictionary
   (`hiddenExecutes`) that is inaccessible from script. The command
   resolver skips hidden commands entirely during normal lookup.
2. **Option flag enforcement.** Even for commands that *are* available
   in safe interpreters, individual options can be restricted. Options
   marked with `OptionFlags.Unsafe` are rejected at parse time. The
   `[test2]` command, for example, is safe but its `-timeout`,
   `-debug`, and `-trace` options are not.
3. **Sub-command allow-lists.** Ensemble commands that are partially
   safe enumerate which sub-commands are permitted. The `[info]`
   ensemble exposes twenty-five sub-commands in safe interpreters;
   `[interp]` exposes nine; `[file]` exposes five; `[object]`, when
   policy grants it any access at all, exposes seven (including
   `[object invoke]` with reduced flag surface). Sub-commands outside
   the allow-list produce a "permission denied" error.
4. **Policy callbacks.** Each restricted command has a policy callback
   that runs *before* the command executes. Eight default callbacks
   ship — `ClockCommandCallback`, `FileCommandCallback`,
   `InfoCommandCallback`, `InterpCommandCallback`,
   `ObjectCommandCallback`, `PackageCommandCallback`,
   `SourceCommandCallback`, `UriCommandCallback` — and any number of
   custom callbacks (in C# or in Eagle) can be installed by the parent
   interpreter. Policy callbacks execute in the parent's context with
   full privileges, so they make decisions on information the safe
   child cannot access.
5. **Resource limits.** Sixteen hard limits cap consumption to prevent
   denial of service: child interpreters forbidden; scope depth 50;
   pending events 50; callbacks 50; loop iterations 1,000; namespaces
   50; procedures 100; variables 100; array elements 100; operations
   200,000; command invocations 100,000; unknown lookups 1,000;
   dictionary nesting 5; dictionary pairs 100; result size 1 MB; nested
   result size 1 MB. Exceeding any limit halts the interpreter.

Layered above the safe-interpreter mechanism is the **rule set system**.
A rule set is a policy artifact — a `.ruleSet` file deployed alongside
the scripts, containing `rule` blocks of the form `rule { type Include
kind Command mode {Include Exact} patterns nop }` plus optional
`includeRuleSet` directives for composition. Every rule set file has a
sibling `.ruleSet.harpy` detached signature, so the policy itself is a
signed artifact whose authenticity is verified by the same trust chain
that verifies the scripts. Eagle ships a layered library — `common`
(permits only `[nop]`, the safest baseline), `expr`, `event`,
`control`, `entity`, `fileSystem`, `configuration`, `critical`,
`full`, and others — and a deployment selects or composes them by name.
A script may operate under a permissive rule set during development and
a restrictive rule set in production without any change to the script.

Rule sets express the policy callback layer (layer 4) in a composable,
signable, declarative form. The five layers and the rule set system
compose. An action denied by any layer is denied overall; the
composition is by design, because the layered model matches the layered
trust requirements of real deployments where a single binary policy is
rarely sufficient.

A complementary security property is that **Eagle has no JIT compiler**.
The interpreter evaluates parsed scripts directly; there is no separate
code-generation stage that could be subverted, no bytecode cache whose
contents might bypass policy, no expression compilation path that could
produce code that did not go through the policy callbacks. The
single-stage evaluation surface is part of what makes the five-layer
model audit-tractable.

Security flags affect which commands are available, whether file system
operations are permitted, whether the network can be reached, whether
unsigned scripts can be loaded. A script running in a security-enabled
interpreter cannot escalate to an unrestricted one without explicit
policy permission; a script running in a security-disabled interpreter
can dynamically introduce a security-enabled child for sandboxed
evaluation.

This is structurally different from compile-time security models. There
is no separate "secure build" and "debug build." The same binary, the
same scripts, the same interpreter — but the security state is
interpreter-scoped runtime data, queryable from script, settable by
policy, mediated by callbacks the parent controls.

The pattern recurs throughout the system. Runtime options
(`[hasRuntimeOption logExtraTestResults]`), trust state, debug
instrumentation, performance flags — all are interpreter state, not
compile-time configuration. This is what scripts mean when they say
`[hasRuntimeOption ...]` instead of `#if SOMETHING`: the dual-language
model puts the gating where it belongs, in the policy layer, where it
can be changed without re-deploying primitives.

### 4.8 The shell core: `PrivateShellMainCore` and `PrivateInteractiveLoop`

The shell itself is the most visible instance of the dual-language model
in Eagle: a C# scaffolding that prepares an interpreter, dispatches
command-line work, and hands control to a script-driven interactive
loop. The two methods in the primitive layer that carry this work are
`PrivateShellMainCore` and `PrivateInteractiveLoop`, both defined in
`Library/Components/Public/Interpreter.cs`. Together they are
approximately six thousand lines of C#; together they implement
roughly the entire surface that the user interacts with when running
`EagleShell`.

**`PrivateShellMainCore` (≈4,800 lines).** This is the shell's main
dispatcher. Its responsibilities, in order:

1. Initialize the active interpreter and the parent / child interpreter
   relationship. The shell supports `-child` and `-parent` command-line
   options that switch the *active* interpreter between an original and a
   child; the method owns the bookkeeping that keeps the switch
   consistent across command-line arguments and evaluated scripts.
2. Walk the argument vector, dispatching each recognized option to its
   handler. Many options have parameters; many options affect state that
   subsequent options will read. The walk is order-preserving and stop-
   sensitive: an option that requests a `-stop` (or that causes a fatal
   error) halts further processing.
3. Decide whether the shell should enter interactive mode. The decision
   is contextual: a script supplied via `-file` does not enter the loop;
   an explicit `-interactive` does; the absence of either may, depending
   on host capability.
4. If interactive, hand off to `PrivateInteractiveLoop` with the
   appropriate loop data.
5. On exit, dispose the child interpreter (if one was created) and
   propagate the result through `ref` parameters to the caller.

The method is large, and its size is honest about what it has to
coordinate: every shell-level concern that a user can touch from the
command line is handled here. The structure is `#region`-delimited
throughout, *and* the method is internally organized as a finite-state
machine using labeled `goto` blocks: `retryArgv:`, `readArgv:`,
`option:`, `haveArgv:`, `kiosk:`, `done:`, `doneArgs:`. Each label is
a state in the argv-processing automaton, and the transitions are the
explicit `goto`s. The labeled-goto pattern is unusual in modern C# and
is a deliberate choice: the alternative — extracting each state into a
method and threading thirty-plus shared variables through a context
object — would obscure the state-machine topology without reducing
complexity. A reader navigating to a specific concern (interpreter
switching, option parsing, exit handling, child interpreter cleanup)
finds the relevant `#region` and follows the `goto` transitions
between states. The `#region` system handles spatial navigation; the
`goto` labels handle behavioral navigation; the combination makes the
4,800-line method tractable in a way that a "clean architecture"
decomposition would not. This is the §6.3 large-file argument made
concrete: cohesion within a single artifact, with structural and
behavioral navigation rather than file-level decomposition.

**`PrivateInteractiveLoop` (≈1,600 lines).** This is the read-eval-print
loop. Its structure, again `#region`-delimited:

- **Setup.** Parameter checks, cross-AppDomain checks, native stack
  checks, save/push of the interactive-loop level. The setup ensures
  that the loop is being entered in a state where it can operate safely.
- **Initialization (optional).** When the loop is being entered for the
  first time, an "initialize interactive loop" region handles
  one-time setup (debugger active level, hooks, banner text).
- **Header.** The "Write Interactive Header" region produces the
  banner the user sees on entry.
- **Save / push engine flags.** The loop saves the calling engine flags
  and pushes its own. The saved values are restored on exit, so the
  loop's mutation of flag state is bounded.
- **Local variable declarations.** Multiple regions declare the locals
  the loop will use, grouped by concern (flag variables, Tcl shell
  emulation variables, GC test thread variables, input variables,
  loop variables). The decomposition lets a reader find any local by
  the concern it belongs to.
- **Reset interactive loop event.** A region that ensures the loop's
  signalling event is in the expected state.
- **The interactive loop itself.** A large `#region` containing the
  main loop. Within it, further `#region`s for: per-iteration flag
  bookkeeping, debugger command dump, paused-loop waiting, input and
  result processing variables, input processing, input buffering check,
  host-begin-processing hook callback, done/input flags check, input
  buffering, command-hook callback, empty-input check, debugger active
  level entry, error-line reset, and so on. Each concern is its own
  `#region`; each `#region` is the smallest scope that meaningfully
  isolates the concern.

The total method is large. The internal structure is fine-grained. The
combination is exactly the §6.3 argument made concrete: large files (or
large methods) are not a defect when the cohesion is real and the
internal navigation is good. A reader who wants to understand "what
happens when the user pauses the interactive loop" goes to the
"Wait On Paused Interactive Loop" region; they do not have to read the
other 1,500 lines first.

What the case study illustrates:

- **The C# shell core hands control to the Eagle script layer
  ([eagle_shellUnknown] and the prompt-setup procedures from §4.5) at
  the right moments.** The C# layer does not implement the
  interactive shell's "personality" — it implements the loop. The
  personality is in Eagle: which commands are dispatched to a system
  shell, what the prompt looks like, how unknown commands are
  handled. This is the dual-language model expressing itself in the
  most user-visible component of the system.
- **The C# layer's complexity is contained.** A user who wants a
  different prompt does not modify `PrivateInteractiveLoop`; they
  redefine the Eagle prompt-setup procedures. A user who wants
  different unknown-command behavior does not modify the C# loop;
  they replace `[eagle_shellUnknown]`. The C# layer provides the
  scaffolding; the Eagle layer provides the policy.
- **The trust boundary is in the right place.** The C# layer
  enforces the security state of the active interpreter, the rule
  set, and the policy callbacks (see §4.7). The Eagle layer can
  observe security state and adapt, but cannot escape it. A script
  that wants to perform a privileged action goes through the
  primitive layer, which checks the policy before performing the
  action. The shell's user-visible surface is in the script layer;
  the trust enforcement is in the primitive layer; the boundary is
  the `[object]` command.

The shell is, in this sense, the cleanest instance of the entire
whitepaper's argument: a substantial, complex piece of software whose
*architecture* is the dual-language model and whose *behavior* is
explained, end to end, by following the boundary between the two
layers.

### 4.9 Summary of the case

Eagle is a working instance of the dual-language model. Its boundary is
explicit (the `[object]` command). Its scripts are first-class introspective
artifacts (`[info ...]`, `eagle_platform`). Its documentation is queried at
runtime (`#help`). Its deployment is signed source with a key-ring trust
model (Harpy). Its security policy is interpreter-scoped runtime state.

Every one of these properties is the dual-language model taken seriously. The
conventions described in §5 fall out of these properties; the divergences
from "best practice" described in §6 are the price of taking the properties
seriously; the costs described in §7 are what the discipline charges to keep
the properties true.

The case is not that Eagle is the right answer for every system. The case is
that systems with Eagle's design pressures — long lifetime, security
sensitivity, deployment in environments the original developer does not
control, policy code that changes faster than the primitive code — benefit
from a design that names the boundary and pays its costs deliberately.

> **Code excerpts to add when expanded:** a full `[lshuffle]` block with help,
> the Harpy verify-on-load flow, an `[checkFor*]` constraint definition that
> shows the introspection-driven gating, an `[object invoke]` call site that
> drives a `Eagle._Components.Private.*` primitive.
>
**The Harpy verify-on-load flow:**

```text
   AUTHOR SIDE
   ┌─────────────────────────────────────────────────────────┐
   │                                                         │
   │   foo.eagle ────── sign with private key ──────►        │
   │   (source)                                              │
   │                                       foo.eagle.harpy   │
   │                                       (detached sig)    │
   │                                                         │
   └───────────────────────────┬─────────────────────────────┘
                               │
                               │  distribute (git, copy, package)
                               │  source + signature travel together
                               ▼
   RUNTIME SIDE
   ┌─────────────────────────────────────────────────────────┐
   │                                                         │
   │   [source foo.eagle]                                    │
   │           │                                             │
   │           ▼                                             │
   │   ┌────────────────┐         ┌──────────────────┐       │
   │   │  Interpreter   │         │   Key ring       │       │
   │   │  reads bytes   │ ◄────── │   (trusted       │       │
   │   │  from disk     │         │    public keys)  │       │
   │   └────────┬───────┘         └──────────────────┘       │
   │            │                                            │
   │            ▼                                            │
   │   ┌─────────────────────────────────────────────┐       │
   │   │      Harpy plugin                           │       │
   │   │      verify(script bytes, signature,        │       │
   │   │             trusted key ring)               │       │
   │   └─────────────┬──────────────────┬────────────┘       │
   │                 │                  │                    │
   │           valid │                  │ invalid            │
   │                 ▼                  ▼                    │
   │       ┌─────────────────┐  ┌─────────────────┐          │
   │       │  evaluate the   │  │  refuse and     │          │
   │       │  script bytes   │  │  raise an error │          │
   │       └─────────────────┘  └─────────────────┘          │
   │                                                         │
   └─────────────────────────────────────────────────────────┘
```

---

## §5 The conventions that fall out

**Section thesis.** The Eagle / Harpy / Kapok / Zeus coding conventions look
idiosyncratic in isolation. Each one is the inevitable consequence of taking
the model seriously. The conventions are not stylistic preferences; they are
the operational responses to problems the dual-language model creates and the
single-language model hides.

### 5.1 Override patterns: scripts as configuration

The Eagle codebase has three orthogonal override mechanisms that combine in
every procedure that might be configured. The `::no(<feature>)` global flags
are script-side opt-outs. Environment variables are process-level
configuration. Runtime options (queried by `[hasRuntimeOption ...]`) are
interpreter-level configuration.

Each layer has its own purpose and its own precedence. The `::no(...)` flags
are typically set by the current script or by a sourced configuration file —
they reflect what the author of this particular run wants. Environment
variables reflect the deployment — what the operator wants. Runtime options
reflect the interpreter state — what the policy framework has decided is
appropriate.

A typical proc might check all three:

```tcl
proc maybeDoExpensiveThing {} {
    if {[info exists ::no(expensiveThing)]} then {return false}
    if {[info exists ::env(SKIP_EXPENSIVE)]} then {return false}
    if {![hasRuntimeOption allowExpensive]} then {return false}

    # actually do the thing
}
```

A mainstream developer would look at this and ask why dependency injection is
not used. The answer is that DI assumes the wiring graph is known at
construction time — at the place where the application boots, you know which
implementations to plug in and you plug them in. Scripts do not have a
construction site. A script is sourced into an interpreter that was
constructed elsewhere, possibly by code in another language, possibly weeks
earlier, possibly with no knowledge of what this script wanted.

The override pattern is what dependency injection looks like when you cannot
reach the construction site. It is also what configuration looks like when
there is no separate configuration system. Both observations point at the
same thing: in the dual-language model, the script layer is *both* the
application code *and* the configuration, and overrides are how
configuration gets passed in.

### 5.2 Defensive programming: every call crosses a boundary

The script layer crosses many trust boundaries. A file system call might
fail because the file does not exist, because permissions changed, because
the volume disappeared. A network call might fail because DNS is down,
because the certificate expired, because the peer rebooted. A cross-language
call might fail because the .NET method threw, because the runtime
garbage-collected something unexpectedly, because a security policy denied
the request. A script-internal call might fail because a hook procedure was
redefined, because a global was unset, because the interpreter is being
shut down.

Most of these failures should not abort the script. The script *is* the
policy layer; aborting means the policy stops applying. A test that fails
to download a fixture should record the failure and continue with other
tests. A configuration that fails to load one of its inputs should fall
back to defaults. A logging call that fails to write to its preferred
channel should write to stderr.

This is why Eagle scripts are full of patterns like:

```tcl
if {[info exists ::env(SOMETHING)]} then {
    set value $::env(SOMETHING)
} else {
    set value $defaultValue
}
```

and

```tcl
if {[catch {expensiveOperation} result] == 0} then {
    # success path
} else {
    # error path with $result
}
```

and

```tcl
try {
    set handle [acquireResource]
    # use the handle
} finally {
    catch {disposeResource $handle}
}
```

The mainstream alternative is exception propagation: let failures bubble up,
catch them at a higher level. That works in a single-language application
where the higher level exists and knows what to do. It does not work in a
script that *is* policy code — there is no higher level except the
interpreter, and the interpreter's "what to do" is "abort the script,"
which is exactly what the policy wanted to avoid.

The defensive style is not over-engineering. It is the natural response to
being the policy layer in a system whose failure modes are real and
continuous.

### 5.3 Sensitive-data hygiene

Scripts hold key material. The Harpy signing tool reads private keys; the
Kapok license tool processes certificates; the Zeus encryption library
handles passwords and salts. The script layer is where the cryptographic
primitives are *configured* — which means the script layer is where the
configuration *values* live, which include the keys.

This is structurally different from a typical cryptographic library, where
the keys are constructed at the call site and passed in by reference. In a
dual-language system, the script holds the values long enough to call the
primitive. The value lifetime in the script *is* memory lifetime — there
is no garbage collection event that necessarily clears the bytes between
the script holding them and the primitive being done with them.

The convention is to clear sensitive locals explicitly:

```tcl
unset -nocomplain -maybezerostring -purge -- \
    password salt iterationCount key derived
debug collect
```

The `-maybezerostring` flag tells the Eagle runtime to zero the underlying
byte storage before releasing the reference. The `-purge` flag forces the
variable's storage to be released immediately rather than waiting for the
namespace teardown. The `[debug collect]` then asks the .NET GC to compact,
increasing the chance that any holding references are dropped.

This is not paranoia. It is the natural extension of "do not log passwords"
to a layer that holds them. Mainstream advice — "use a `SecureString`,"
"use the operating system's keystore," "do not handle keys in user space at
all" — assumes a single-language application where the key never leaves the
cryptographic provider. The dual-language model has the key transiting the
script layer by construction. The hygiene convention is what makes that
transit safe.

### 5.4 Hooks as named procs

Extension points in Eagle are typically implemented as named procedures
whose existence is checked at the call site:

```tcl
proc invokeWithHook { phase args } {
    set hookName [appendArgs $phase _hook]
    if {[llength [info commands $hookName]] > 0} then {
        if {[catch {uplevel 1 [linsert $args 0 $hookName]} result]} then {
            # log the failure but do not abort
        }
    }
    # main work happens here
}
```

A mainstream developer would model this as callback registration: an
`addEventListener`-style API where extensions register handlers that the
framework dispatches. The objection to the Eagle style would be that named
procedures are global state, that they can be redefined accidentally, that
there is no signature checking.

The defense is that the extension mechanism should look like the language
it extends. In a scripting language whose main extensibility mechanism is
`proc`, extensions are procedures. Discoverability is the discoverability
of any other procedure — `[info commands *_hook]` enumerates all hooks. The
redefinition risk is the redefinition risk of any other proc — addressed
by namespace conventions and by audit. The signature checking is
`[catch]`-mediated — a hook that does not match the expected signature
errors, and the caller logs the failure without aborting.

A callback registration model would require a registry, a registration
API, a deregistration API, a query API, and a dispatch system. The
named-proc model uses one feature — the existence of a proc by a particular
name — to do all of these. The reduction is not a hack; it is the
dual-language model applied to extensibility.

### 5.5 Save/restore state patterns

Tests in Eagle mutate global state — environment variables, runtime
options, security flags, key rings, policy settings. Tests also need to be
composable: running test A followed by test B should not leak A's state
into B.

The convention is the save/restore pair:

```tcl
proc savePolicy { varName } {
    upvar 1 $varName savedPolicy
    # snapshot the current policy state into savedPolicy
}

proc restorePolicy { varName args } {
    upvar 1 $varName savedPolicy
    # restore the policy state from savedPolicy
}

# usage:
savePolicy myPolicy
try {
    # mutate the policy
    # run a test that depends on the mutation
} finally {
    restorePolicy myPolicy
}
```

A mainstream developer would use a test fixture: a class that sets up
state in `setUp` and tears it down in `tearDown`. That works in a
single-language test framework where each test method has its own fixture
instance. It does not work in a scripting language whose tests are
procedures and whose global state is real global state.

The save/restore pair is the script-layer equivalent of RAII (resource
acquisition is initialization). The state is the resource; the save is
the acquisition; the restore is the release. The pair is explicit because
there is no scope-based destruction to make it implicit. The convention
scales: each kind of state has its own save/restore pair; they nest
cleanly because each pair is responsible for its own state; they do not
interact because each pair manages a disjoint subset.

The cost is the discipline of writing the pairs. The benefit is that tests
are composable in a language whose runtime does not enforce composability.

### 5.6 Fail-safe vs. fail-closed: explicit per-proc decision

Some operations should fail open: if the security check is unavailable,
allow the operation. Other operations should fail closed: if the security
check is unavailable, refuse the operation.

A mainstream developer would want a uniform rule — usually "fail closed
for security, fail open for everything else." That rule is wrong, because
the security/non-security distinction is too coarse. Encryption in Zeus is
a security feature, but it deliberately falls back to plaintext when the
encryption provider is unavailable (with a warning) so that the network
protocol can degrade gracefully. Signature verification in Harpy is also a
security feature, but it deliberately refuses to load when the
verification cannot be performed.

The two procs make opposite choices, and both are correct for their
context. Zeus is a transport-encryption layer where the security property
(confidentiality from passive observers) is desirable but not load-bearing;
the alternative to fail-open is to make the system non-functional in
environments where Zeus is not provisioned. Harpy is a trust-chain layer
where the security property (integrity of policy code) is load-bearing;
the alternative to fail-closed is to silently allow unsigned policy code
to run, which defeats the entire trust chain.

The convention is to document the choice in each procedure's help block,
with the rationale. The Eagle audit that produced this whitepaper's case
study found procedures where the choice was not explicit; those were
fixed during this work. The convention is the discipline of being
explicit, not a particular policy.

A single-language system could adopt the same discipline. The reason it
usually does not is that single-language systems do not have a layered
security model where the choice has to be made per-procedure. A library
that throws on missing crypto and a CLI tool that asks the user are
answering different questions; both are reasonable; the convention is to
say which is which.

### 5.7 The `# NOTE:` / `# HACK:` / `# TODO:` / `# BUGFIX:` taxonomy

Eagle code uses prefixed comments to mark intent. The prefixes are
grep-able and conventional:

- `# NOTE:` — design rationale. Why this code is the way it is.
- `# HACK:` — known-imperfect-but-deliberate. This works but it has a
  reason to be replaced.
- `# TODO:` — deferred work. Something that should be done but is not yet.
- `# BUGFIX:` — workaround. The behavior here exists because of a specific
  bug elsewhere.
- `# BUGBUG:` — known issue. The code has a defect that is not yet fixed.

Mainstream advice is that comments rot, are out of sync with code, and
should be replaced by self-documenting code. The advice is half-right.
Comments that describe *what* the code does rot because the code itself
does that better. Comments that describe *why* the code is the way it is
do not rot, because they describe a decision that does not change when
the code changes.

The prefixed taxonomy is what makes these comments tractable. A `# HACK:`
comment, ten years later, is still useful — it tells the reader "this
works but there is a reason to revisit." A `# BUGFIX:` comment is still
useful — it tells the reader "if you are tempted to simplify this, do
not, because it works around a specific failure mode." A `# TODO:` is a
debt acknowledgment that grep can audit. A `# NOTE:` is a design record
that survives the original author.

The Eagle codebase contains over 1,400 `// HACK:` comments in its C#
layer (the `# HACK:` form is the Eagle-script equivalent). Each one
marks a deliberate deviation from conventional practice and explains
why the deviation exists. A typical example, from the safe-interpreter
option-flag enforcement code: `// HACK: The "-maybetrustedonly" option
is allowed in "safe" interpreters due to its lack of a value, its
relative harmlessness, and because the core library binary plugin
loader uses it, e.g. for HotKey, et al.` These comments are not
admissions of poor quality; they are acts of honesty. Each one says:
"I know this looks wrong; here is why it is right; judge it on its
merits." The volume of HACK comments in Eagle is a feature, not a
defect — it is the visible signature of an author who documents every
deviation rather than hiding compromises behind clean abstractions.

The convention costs effort to maintain. It pays off in a codebase that
survives its original developers. In a system whose lifetime is measured
in decades — which is the system Ousterhout's argument is about — the
cost is dwarfed by the benefit.

---

## §6 Where this diverges from "best practice" — and why

**Section thesis.** Each of these is a deliberate departure from mainstream
advice. Each has a load-bearing reason. The departures are listed, defended,
and the costs acknowledged honestly — but no point that does not need
conceding is conceded.

### 6.1 Global overrides vs. dependency injection

The dependency-injection community has spent twenty years arguing that
hard-coded dependencies are bad and that wiring should be externalized. The
argument is correct for the systems where it was developed: object-oriented
applications with construction-time wiring, where each component has a
well-defined set of collaborators, where the graph of collaboration is
known when the application boots.

The dual-language model does not have that structure. A script is sourced
into an interpreter whose state was established by code in another
language, possibly in another process generation, possibly under
conditions the script's author could not anticipate. There is no
construction site to inject at. There is no application bootstrap that
knows the graph of collaboration. There is only the interpreter and the
script.

In this setting, the override pattern is what dependency injection looks
like. The interpreter's environment — globals, env vars, runtime options —
is the injection container. The script's overrides are the injection
points. The wiring is done at the moment the script runs, not at a
construction site that does not exist.

The cost is that the injection container is implicit and unbounded. A
script that wants to know which dependencies it has must read its own
code. A test that wants to verify that no unexpected dependencies are
injected must enumerate the global state. A mainstream DI framework would
solve this by making the container explicit.

The defense is that explicit containers add machinery without solving the
underlying problem. A script that depends on an environment variable still
depends on the environment; declaring that dependency in an
injection-style configuration block does not change what the script does,
only adds a layer of indirection. The dual-language model accepts the
implicit-container cost in exchange for not adding the layer.

### 6.2 Mutation as a feature

Functional-programming advocates have argued for a quarter-century that
mutable state is the root of most concurrency bugs, most aliasing bugs,
and most reasoning failures. The argument is correct. Immutable data
structures do simplify reasoning. Pure functions are easier to test.

The dual-language model accepts this and disagrees with the conclusion.
Policy code describes a world that mutates. A configuration changes when
the deployment changes. A test environment changes when a test sets up
its fixtures. A security policy changes when the operator updates it.
Forcing this mutation through immutable-data idioms — copy-on-write,
lenses, immutable updates — does not make the underlying change go away;
it makes the change harder to write.

Eagle is pervasively mutable. `[set]`, `[unset]`, `[lset]`, `[dict set]`,
`[interp eval]` — all of these are mutation primitives. The convention is
to use them, not to fight them. Tests mutate global state and restore it.
Configurations are loaded as side effects, not as returned values. Hook
procedures mutate the dispatch by being defined.

The cost is that careless mutation produces bugs. The defense is that the
careful mutation produces simpler code than the careful immutability. A
test that saves the policy, mutates it, runs the test, and restores it is
four lines. The same test expressed through an immutable policy graph
would require defining the graph type, defining the update operation,
threading the updated graph through the test, and restoring the original
— twenty lines and a type-system commitment.

The dual-language model is honest about this trade. Primitive code, where
invariants are load-bearing, benefits from immutability; the Eagle
primitive layer (in C#) uses immutability where appropriate. Policy code,
where invariants are local and contextual, benefits from mutation; the
Eagle script layer uses mutation freely. The two halves agree to
disagree, and the boundary between them is exactly where the disagreement
is mediated.

### 6.3 Large flat files vs. micro-modules

Industry advice is to keep files small. One class per file, one concept
per file, one responsibility per file. The advice has roots in Java's
compilation-unit model and has spread to most modern languages as best
practice.

Eagle's test library is one 25,000-line file. Its constraints library is
12,000 lines. Its main script library is split across roughly two dozen
files of varying sizes, but the biggest of them are large.

The defense is cohesion. The procs in `test.eagle` share dozens of
invariants: a common channel convention (`[tputs $channel ...]`), a common
hook registry (`[getNameForDebugHook]`, `[announceForDebugHook]`), a
common namespace expectation (`::eagle_tests(...)`), a common
error-message format. Splitting these procs into smaller files would
scatter the invariants and force them into explicit contracts where
implicit ones suffice. A small-file structure would have a
`channels.eagle` defining channel conventions, a `hooks.eagle` defining
hook conventions, a `namespaces.eagle` defining namespace conventions —
and every other file would have to source all three and obey their
contracts. The implicit cohesion of "everything that uses this convention
is in this file" is a real benefit; the explicit modularity of "every
dependency is named" is a real cost.

The cost of the large-file approach is navigation. A reader scrolling
through `test.eagle` cannot easily find related procs. The mitigation is
grep, the `# <help>` system, and the convention that related procs are
placed near each other. A reader of `[getCurrentTestName]` will find
`[getTestName]` and `[getTestFile]` within a few hundred lines.

The mainstream advice is right for languages where files are compilation
units and cross-file references are cheap. It is less right for scripting
languages where files are sourcing units and cross-file references
introduce dependencies. The dual-language model picks the trade-off that
fits the policy layer.

### 6.4 Conditional compilation as architecture, not debt

C# tradition treats `#if SOMETHING` blocks as code smell. The reasoning
is that conditional compilation creates code paths that are not
exercised in every build, that may rot silently, that complicate
testing.

Eagle's primitive layer uses conditional compilation extensively, and
does so for *two distinct architectural reasons* — both of which are
defensible, and neither of which is "debt."

**Subsystem gating.** `NATIVE`, `HISTORY`, `DEBUGGER`,
`DEBUGGER_BREAKPOINTS`, `SECURITY`, `EMIT`, `THREADING`, and roughly
eighty other feature-flag properties define which subsystems are
present in a given build. A build with `DEBUGGER` enabled has a
script-level debugger; a build without it does not. A build with
`NATIVE` enabled can call native libraries; a build without it cannot.
The alternative — runtime feature flags — leaks complexity into every
code path: every place the debugger could be invoked has to check
whether the flag is set; the check is constant runtime cost; the check
is a place where the wrong answer (debugger thinks it is enabled when
it is not) leads to a crash; the check creates a dependency between
the debugger and every consumer. Compile-time gating is honest about
what is and is not in the binary. A `NATIVE`-disabled build literally
does not contain the code that calls native libraries; you cannot
accidentally invoke it; you cannot test it because it does not exist.

**Multi-version compatibility.** This is the second use, and it is the
more load-bearing one. Eagle compiles against .NET Framework 2.0 RTM,
every 4.x point release, .NET Standard 2.0 and 2.1, and .NET 5
through .NET 10+. It runs on Mono. When a .NET API changes between
versions, Eagle does not drop support for the old version; it provides
both paths under `#if`. The conditional compilation system is not a
collection of feature flags — it is a *compatibility architecture*.
Every new feature must be implemented in a way that compiles on all
targets; every new API usage must be checked against the lowest
supported framework. The `#if` guards accumulate, and accumulating is
the point: each one is a guarantee that "if your code worked on this
framework yesterday, it works on this framework today."

The mechanism by which the two uses cohere is the `EagleBuildType`
preset selector. The build system defines eleven `.csproj` files, each
representing a real deployment target; each project selects an
`EagleBuildType` preset that sets dozens of feature-flag properties to
a tested, validated combination. There are roughly eighty individual
flag properties; the eleven presets are the curated combinations that
have been verified to compile, test, and run end-to-end. A deployment
chooses a preset; the preset is the architecture. Appendix D enumerates
the canonical conditional-compilation flags Eagle defines (`NATIVE`,
`HISTORY`, `DEBUGGER`, `SECURITY`, `EMIT`, `THREADING`, and others) and
the build-system mechanisms by which they are composed into presets.

The cost is that the build matrix is real. Each combination of flags
is a different binary, and the test matrix multiplies accordingly. The
Eagle build system addresses this by supporting all the combinations
as first-class build configurations and by running tests under each.
The mainstream alternative — a single binary with runtime flags —
appears simpler but moves the matrix into the runtime, where it is
harder to audit. The mainstream alternative also does not address
multi-version compatibility at all; it either picks one framework and
abandons the rest, or it picks a lowest-common-denominator API surface
that gives up the features the newer frameworks added. Eagle's
approach gives up neither.

### 6.5 CRLF as a contract

Standard Unix advice is to use LF line endings. The advice has held for
decades and is the basis for `.gitattributes` defaults, editor
configurations, and the explicit conventions of most open-source projects.

Eagle script files use CRLF. The reason is the trust chain. A signed
`.eagle` file has its bytes — including line endings — included in the
signed payload. Re-normalizing the file from CRLF to LF changes the
bytes, which invalidates the signature, which means the file no longer
loads in a security-enabled interpreter.

The convention is not about line endings. It is about what gets signed.
Once any policy-code distribution is signed, the bytes are the contract,
and the line endings are part of the bytes. The choice of CRLF reflects
the .NET ecosystem default; the choice would be defensible at LF if the
ecosystem were Unix-rooted. The point is that the choice cannot be
revisited casually after the chain is established.

The cost is that tools written outside the Eagle ecosystem can corrupt
files by re-normalizing them. The documentation tooling in the sibling
docs repo includes an explicit EOL preservation rule for tools that edit
`.eagle` files outside the docs repo itself; the rule is enforced by
`scan_commands.eagle` and `restyle.eagle`, both of which have a
`detectEol` helper and a `writeAll` that takes an explicit EOL mode. A
Python helper that silently rewrites a CRLF file as LF — for example,
`Path.write_text()` on macOS — invalidates the signature of every file
it touches; this has happened, has been fixed, and is documented as a
load-bearing rule.

The mainstream advice would be to migrate the chain to LF. The defense
is that the chain already exists, the migration would require re-signing
every script in every deployment, and the benefit (alignment with Unix
convention) is purely aesthetic. The model prefers the existing chain
over the aesthetic improvement.

### 6.6 "Comments are bad" — except when they are documentation

Modern style guides argue that code should be self-documenting and that
comments should be rare. The argument is: comments rot, code does not;
comments describe what the reader can read in the code; comments
encourage sloppy naming.

The argument is right about a specific kind of comment — the kind that
paraphrases the code. `i += 1; // increment i` is bad and the style
guides are right to discourage it.

The argument is wrong about a different kind of comment — documentation.
The `# <help>` blocks in Eagle scripts are not paraphrasing the code.
They are answering questions that the code cannot answer: What is this
for? Why does it exist? How is it intended to be called? What does it
return? What can go wrong?

A self-documenting proc still needs all of these answers. A proc named
`[getRequestLicenseCertificateUri]` tells the reader what it returns but
not why a separate procedure exists for this URI, not what test
infrastructure depends on it, not what fallback behavior applies when the
request fails. The body tells the reader the implementation but not the
contract.

The mainstream conflation of "comments" with "documentation" is what
makes the style guides wrong on this point. The Eagle convention is to
distinguish them: code-internal comments (`# NOTE:`, `# HACK:`) are
rationale that lives next to the code; `# <help>` blocks are contract
documentation that lives inside the proc body but addresses callers, not
implementers.

The cost is the discipline of writing and maintaining the blocks. The
audit that produced this whitepaper's case study fixed nineteen blocks
and added several hundred. The discipline is permanent. The benefit is a
codebase that can be navigated by `#help` rather than by source reading,
which is exactly what makes the dual-language model habitable at scale.

### 6.7 Long parameter lists vs. options dicts

A common refactoring suggestion is to replace long parameter lists with
an options dictionary or a configuration object. The motivation is that
long lists are hard to read at the call site, hard to extend without
breaking callers, and hard to default cleanly.

Many Eagle procs have eight, ten, or twelve positional parameters. The
convention is to keep them positional, not to refactor to dicts.

The defense rests on two observations. First, positional parameters with
optional defaults — Tcl's standard mechanism — express the common
patterns cleanly: required parameters first, optional parameters with
defaults at the end, variadic `args` if needed. The call sites read as
a sequence of values, which matches the human reading order of "do this,
with these inputs." A dict-based call requires the reader to translate
keys to positions before understanding the call.

Second, signature changes are visible. Adding a parameter to a positional
list is a breaking change that surfaces immediately — every caller fails
to parse. Adding a key to a dict-based interface is a silent change —
old callers continue to work with the missing key being defaulted. The
visibility of the breaking change is a feature: it forces a coordinated
update across the codebase, which is what you want when the meaning of a
procedure changes.

The cost is that very long parameter lists become genuinely hard to read.
The mitigation is to use `args` and command-line-style parsing for
parameter sets that exceed about ten items. The convention is not
"always positional" but "positional until it stops scaling," and the
threshold is high because Tcl call sites scale well.

### 6.8 Static-context resolution (`Interpreter.GetActive`)

Modern API design prefers explicit context passing. A method that needs
to know which interpreter it is operating on should take the interpreter
as a parameter, not look it up from thread-local state.

Eagle's C# primitive layer uses `Interpreter.GetActive()` — a static call
that returns the interpreter currently active on the calling thread. The
convention is widespread; many primitives never receive an interpreter
parameter and never need to.

The defense is that the dual-language model already establishes the
context. There is one interpreter active per call site, by construction —
the interpreter that called into the primitive. Passing it as a parameter
would be redundant because the primitive could not be reached except by
that interpreter. The static resolution is a recognition of the
structural property, not a shortcut around it.

The cost is that the convention forbids primitives that operate across
interpreters. A primitive that wanted to compare two interpreters would
have to take both as parameters; the convention does not preclude this,
but the common case is single-interpreter and the convention optimizes
for it.

The mainstream alternative — always pass the interpreter — adds a
parameter to every primitive signature and adds a value to every call
site. The cost compounds across the API surface. The defense is that
the convention buys uniform call-site simplicity in exchange for the
rare case of cross-interpreter primitives, and the trade is worth it
because cross-interpreter primitives are genuinely rare.

### 6.9 The `_Components.Private` namespace convention

Eagle's C# code uses namespaces like `Eagle._Components.Private.X`,
`Eagle._Components.Public.X`, `Eagle._Components.Internal.X`. The
leading-underscore convention is unusual in C#, where namespaces
typically use no special prefix.

The defense is that namespace prefixes make the public/internal boundary
visible at every import. A `using Eagle._Components.Private.X` is honest
about what it is doing — reaching into the private implementation of the
runtime. A `using Eagle.X` would be ambiguous between public and private
intent. The convention forces the import to declare its intent at the
import site.

The cost is the visual weight of the underscore prefix. Mainstream C#
style guides would not approve.

The defense is that C#'s standard mechanism for the same goal — the
`internal` keyword — only operates at the type level, not at the
namespace level, and only within a single assembly. A type declared
`internal` is invisible outside its assembly. A namespace cannot be
declared internal at all. The leading-underscore convention is a
namespace-level visibility marker that C# does not natively provide; the
convention is the way to express the distinction the language does not
have a keyword for.

The model could also be expressed through assembly partitioning — one
assembly per visibility class. The Eagle codebase does some of this; the
residue is the namespace convention. The trade is between assembly count
and namespace prefix; the project chose the prefix. (Appendix D gives
the full taxonomy of the `_Components.Public` / `_Components.Private` /
`_Components.Internal` split, with examples.)

---

## §7 What the model costs

**Section thesis.** The model is not free. The costs are real, persistent,
and worth naming explicitly — both for the reader weighing adoption and for
the author's credibility. A whitepaper that pretends a design philosophy is
costless is a whitepaper that cannot be trusted. The costs below are the ones
that experienced practitioners encounter; readers should expect to encounter
others that experience will reveal.

### 7.1 Tooling thinness

There is no Visual Studio Code extension for Eagle that rivals the support
for TypeScript or Rust. There is no Eagle equivalent of IntelliJ's deep
navigation. The LSP work in progress (a community implementation backed by
the Eagle docs and command reference) helps; it offers completion, hover
documentation, signature help, and basic navigation. It does not yet offer
the integrated debugger, project-wide refactoring, or symbol search that
mainstream tools provide.

The cost is real. A developer accustomed to modern IDE support faces a
productivity tax when working in Eagle. The tax is paid in lookup time
(grepping for definitions that an IDE would jump to), in editing friction
(fewer autocompletions, fewer error-as-you-type signals), and in onboarding
(newer developers cannot lean on the IDE to teach them the codebase).

The mitigation is the `#help` system. An Eagle developer can query the
interpreter for any procedure's documentation while running. This is
structurally different from IDE support — it is documentation-by-introspection
rather than navigation-by-symbol — but it covers some of the same surface.
A developer at an Eagle shell who needs to know what
`[getRequestLicenseCertificateUri]` does can type
`#help getRequestLicenseCertificateUri` and read its `# <help>` block. An
IDE could do the same lookup, but the IDE would also have to be told about
the procedure; the shell already knows.

The cost is asymmetric. For developers who like IDE-driven workflows, the
tooling thinness is a substantial daily friction. For developers who prefer
shell-driven workflows, the tooling is unusually good — the language's
introspection primitives turn the shell itself into the IDE. Whether the
trade is worth it depends on the developer, not on the language.

### 7.2 Hiring difficulty

Most candidates do not know Tcl, let alone Eagle. The dual-language skill
set — fluency in both a typed primitive language and a small-kernel
scripting language, plus comfort with the boundary between them — is rare.
The candidates who possess it tend to be senior developers with unusual
career paths; the candidates available out of a typical CS program do not.

The cost is paid in three places: in the time to find candidates, in the
time to onboard them, and in the breadth of the pool. A team writing Java
can hire from a deep pool with predictable skills. A team writing Eagle
hires from a shallow pool and assumes substantial onboarding regardless of
seniority.

The mitigation is that the underlying skills generalize. A developer who
understands the dual-language model in Eagle can apply it in any
dual-language deployment. A developer who has internalized the `# <help>`
discipline can apply it anywhere documentation lives in code. The skills
are portable even if the language is not.

The honest assessment: a team that adopts the model is committing to
longer hiring cycles, longer onboarding, and a smaller pool of candidates.
The commitment is rational if the project's lifetime is long enough to
amortize the cost; it is irrational if the project will be deprecated
before the team is fully staffed.

### 7.3 Documentation as discipline, not luxury

The `# <help>` model only works if the blocks stay accurate. An accurate
block is a contract between the procedure and its callers; an inaccurate
block is worse than no block, because it misleads.

The audit work that produced this whitepaper's case study — roughly a
thousand procedures cross-checked against their implementations, nineteen
documentation fixes applied, three code defects surfaced as a byproduct —
is the ongoing cost. The audit is not a one-time exercise; it has to be
repeated as the code evolves. Each new procedure needs a block. Each
refactor needs the affected blocks updated. Each fix needs to be reflected
in the documentation.

The mainstream alternative — generated documentation from type signatures,
or documentation generated from natural-language comments by an LLM — does
not solve the problem; it moves the problem. Generated documentation can
be wrong in the same ways human documentation can be wrong (because the
type signature does not encode the contract, because the comment was wrong)
without offering the cure (a human pass that catches inaccuracies). The
discipline of accurate documentation is irreducible.

The cost is permanent. It is also smaller than it looks: the documentation
pass that found nineteen bugs in a thousand procedures took roughly
fifteen `/loop` iterations of an LLM-assisted audit. The cost per
procedure is manageable when the volume is amortized.

### 7.4 Cognitive load: two languages, one boundary

Developers in a dual-language system have to be fluent in both languages
and understand the boundary between them. Single-language developers do
not.

The fluency is the cost of admission. A developer who can write Tcl but
not C# cannot extend the primitive layer; a developer who can write C# but
not Tcl cannot script the system. Both halves are required; neither alone
suffices.

The boundary understanding — knowing which operations are cheap inside
each language and which are expensive at the cross — is the cost of
working at the seam. It is bounded: senior developers internalize the
boundary in weeks; the marginal cost for someone fluent in both
languages is small. It does compound in small teams, however. The model
favors teams that share the skill set, not teams that specialize within
it — a team where one developer is C#-only and two are Tcl-only pays
coordination cost on every cross-language change.

### 7.5 Trust chain operational overhead

Harpy's signing infrastructure works. It also requires a signing identity
(key pair, certificate, vendor name), a signing pipeline (scripts that
sign on commit or release), a verification configuration (deployments
configure which keys to trust), a re-signing discipline (every change to
a signed file invalidates the signature; re-signing is required before
deployment), key rotation (signing keys have lifetimes; the chain has to
be ready for rotation), and revocation (compromised keys have to be
removable from the trust set quickly).

Each of these is a piece of operational machinery. The audit work in this
whitepaper's case study touched dozens of signed files; every touch
invalidated a signature; every signature has to be re-issued. This is the
routine cost of the model in active development.

The payoff is supply-chain defense. A signed script cannot be modified
between authoring and execution without detection. A signed deployment
can be audited end-to-end. A compromised key can be revoked without
changing the application code. The defenses are real and matter in
environments with audit requirements.

The cost is real and matters in environments where supply-chain attacks
are out of scope. A small team building a non-security-critical
application is paying the trust-chain overhead without getting the
trust-chain benefit. The model is calibrated for systems where the benefit
is load-bearing; smaller systems should pick a less expensive deployment
story.

### 7.6 Migration cost from mainstream

A team running on Python with C extensions has, in some sense, an implicit
dual-language model. Migrating that team to an explicit dual-language
model (Eagle on .NET, or any other pairing) is not incremental.

The cost is paid in several places. The team has to learn the new
languages. The codebase has to be rewritten — the Python composition layer
becomes an Eagle composition layer; the C extension layer becomes a .NET
primitive layer; the boundary becomes the `[object]` command. The tooling
has to be replaced. The hiring criteria have to change.

The model rewards committed adoption. Hybrid systems — some scripts
signed and some not, some boundaries marked and some not — combine the
discipline costs of the dual-language model with the brittleness of the
single-language model, and so are worse than either pure choice. New
projects that adopt the model from the start pay no migration cost.
Existing projects face a multi-quarter migration with no useful
half-measure.

### 7.7 Performance ceiling at the boundary

The script layer is slower than the primitive layer. Cross-layer calls
have marshalling cost. A loop that crosses the boundary thousands of
times per second is fine; a loop that crosses millions of times per
second is not.

The cost surfaces when developers do not internalize the boundary. A
naive script that calls `[object invoke]` inside a tight loop will
discover, when profiled, that almost all of the runtime is in the
boundary cross. The solution is to push the loop into the primitive
layer — to do the work in C# and return a result — rather than to do the
work in Eagle and call C# for each iteration.

This is not a defect of the model; it is the model's natural shape. The
primitive layer is where hot paths live. A script that does not push hot
paths into primitives is using the model wrong.

The cost is paid in developer time. The lesson is permanent but the
initial mistake is recurring — every new developer learns the same
boundary the same way. When the model is used correctly, policy code
stays as expressive as the developer wants and primitives stay as fast
as they need to be; the ceiling only exists when the model is misapplied.

### 7.8 Onboarding curve

A new developer faces a steep "what is happening" period. The conventions
of the model — override patterns, defensive programming, sensitive-data
hygiene, save/restore pairs, the `# NOTE:` taxonomy, brace-quoted bodies,
CRLF preservation, conditional compilation — are mutually reinforcing and
do not make sense in isolation.

A developer who reads a single procedure sees an `[info exists]` guard, a
`[catch]` wrapper, a `try`/`finally` block, an
`unset -maybezerostring -purge`, and a `# NOTE:` comment. Each of these
is reasonable but only obviously reasonable in context. The new developer
has to construct the context — has to see enough procedures that the
conventions cohere — before the model becomes natural.

The cost is paid in weeks of confused onboarding. This whitepaper, if it
works, addresses the cost by providing the context up front: a new
developer can read §§4–6 and arrive at a working procedure already
understanding why the conventions look the way they do. Without such a
document, the onboarding cost is paid procedure by procedure, in repeated
questions of "why is this written this way?"

The whitepaper is the response to the cost. The cost remains real; the
whitepaper is a way to make it bearable.

---

## §8 Beauty and correctness: an aesthetic argument

**Section thesis.** Beautiful code is significantly more likely to be correct
than ugly code. The relationship is probabilistic, not deterministic — but it
is real, mechanistically explicable, and useful as a design discipline. The
properties that make code beautiful (cohesion, symmetry, minimality, clear
abstraction, predictable control flow, consistent naming) are the same
properties that reduce the entry of bugs and improve the chance of catching
the ones that enter. The Eagle codebase is a working illustration of the
correlation.

### 8.1 The thesis

The claim is empirical, not aesthetic. Code that is judged beautiful — by a
small set of testable metrics or by the considered opinion of expert peers —
is significantly more likely to be correct than code that is not. The
relationship is probabilistic: beautiful code can still contain bugs, and
ugly code can still work. But across a large sample of procedures, the
correlation between beauty and correctness is strong enough to be useful as
a design heuristic.

This is a working hypothesis, not a theorem. It can be tested by exhibit
(here is beautiful code that turned out to be wrong) or by counter-exhibit
(here is ugly code that ran reliably for a decade). The hypothesis survives
such tests because it is about correlation, not necessity.

The hypothesis is also not novel in its weakest form. Knuth argued for
literate programming on essentially this basis. Dijkstra wrote that
"elegance is not a dispensable luxury but a quality that decides between
success and failure." The 2007 anthology *Beautiful Code* collected expert
essays defending variants of the claim. Hoare's observation — that one
builds either a system so simple it has no obvious bugs, or so complicated
it has no obvious bugs, and trusts the first to be more correct than the
second — is the same argument in older clothing.

What is potentially new is the strength of the empirical phrasing. "Highly
likely to be correct" is a probabilistic claim, available for testing,
that resists the rhetorical drift of aesthetic discussions. The claim says
that beauty is a measurable signal of correctness with predictive value.
The claim does not say beauty *is* correctness, or that ugly code is
unsalvageable, or that any expert can recognize beauty reliably. It says,
given two pieces of code with similar specifications, the more beautiful
one is more likely to be correct.

The remainder of this section defines what "beautiful" means in this
context, argues for the correlation by mechanism, illustrates with Eagle
examples, addresses counterexamples honestly, and discusses the
consequences for code-writing discipline.

### 8.2 What "beautiful" means in code

Aesthetic judgments of code converge on a small number of testable
properties.

**Cohesion.** Each unit (procedure, class, module) does one thing. The
thing is namable. The name fits.

**Symmetry.** Parallel ideas have parallel expressions. A `[save*]`
procedure has a matching `[restore*]` procedure; an `[encrypt*]` matches
a `[decrypt*]`; an `[add*]` matches a `[remove*]`. The match is visible
at the call site.

**Minimality.** Nothing extra. No vestigial parameters. No commented-out
alternatives. No dead branches. No fields that are never read. The
procedure is exactly as large as it needs to be.

**Clear abstraction.** The abstraction matches the domain. A procedure
named `[saveKeyRing]` saves a key ring; it does not also configure the
encryption provider. A class named `Certificate` represents a
certificate; it does not also wrap network I/O.

**Predictable control flow.** A reader can hold the procedure in their
head. The cyclomatic complexity is low. The nesting is shallow. The
exits are at the top and the bottom; not scattered through the middle.

**Consistent naming.** Similar things have similar names. Plural names
for collections, singular names for items. The same verb for the same
action. The same preposition for the same relationship.

These properties are not entirely subjective. Cohesion is testable by
asking "could you name this in one phrase?" Symmetry is testable by
grep. Minimality is testable by deleting things and seeing what breaks.
Clear abstraction is testable by trying to write the documentation.
Predictable control flow is testable by tracing. Consistent naming is
testable by reading several pieces of the codebase in sequence and
noting any surprises.

When all six properties are present, peers tend to call the code
beautiful. When several are absent, peers tend to call it ugly. The
judgment is not arbitrary; it is the integration of several testable
properties into a single label.

### 8.3 Eagle's specific beauty standards

The general properties of §8.2 are language-agnostic. Eagle
operationalizes them through a set of specific, recognizable
conventions that experienced readers of the codebase spot within
seconds of opening any file. The conventions are not enforced by
tooling; they are enforced by *consistency*, which is what makes them
load-bearing rather than decorative. A new procedure that follows the
conventions is immediately readable. A new procedure that breaks them
is immediately noticeable. The standards fall into seven categories.

**Whitespace and indentation.**

Eagle scripts use two-space indentation. The C# primitive layer uses
four-space indentation. Tabs are absent from both. Every nested level
adds exactly its indentation step; nothing is "shortened" because the
nesting got deep. A reader can count nesting levels by counting
indentation steps without consulting the code.

Vertical whitespace separates logical blocks at consistent intervals.
A `# NOTE:` block is preceded by one blank line. A new logical phase
within a procedure begins on a new blank line. Procedures are
separated by exactly one blank line; classes by exactly two. The
pattern is rigid because rigidity is what makes the pattern useful —
a reader skimming a file finds phase boundaries by visual rhythm, not
by careful parsing. A file that varies its blank-line discipline
forces the reader to *decide* where each phase ends; a file that
maintains the discipline lets the reader *see* where each phase ends.

**Parameter list splitting.**

Single-line parameter lists are used when the parameters fit cleanly:
`proc foo { a b c }`. The braces have a space inside; the parameters
are separated by single spaces. Default values appear in nested
braces: `proc foo { a {b ""} {c false} }`. The convention is uniform
and grep-able.

When the list does not fit, every parameter goes on its own indented
line:

```tcl
proc compileCSharp {
        codeText assembly assemblyName resultVarName errorsVarName
        {createExecutable false} {flagsOnly false} {memory true}
        {strict true} {types null} {extra ""} } {
```

The opening brace stays on the first line. The closing brace sits
adjacent to the body's opening brace. Each parameter sits on its own
line, eight-space indented. Required parameters come before optional
ones; the visual order matches the call-site order.

C# parameter splitting follows the same pattern. A method whose
signature does not fit on one line splits at the parenthesis, with
each parameter on its own line:

```csharp
private static ReturnCode PrivateInteractiveLoop(
    Interpreter interpreter,
    IInteractiveLoopData loopData,
    ref Result result
    )
```

Method overload resolution is a related concern. Eagle's `[object
invoke]` performs runtime resolution against the .NET reflection API
when a script calls into the primitive layer; the C# layer relies on
compile-time overload resolution. The convention that keeps both
tractable is *uniform overload semantics*: when `Foo(int)` and
`Foo(string)` both exist, they answer the same conceptual question
with different input types, never different conceptual questions with
different signatures. Overloads that would have semantically different
meanings get different names. A script that calls `Foo` with an `int`
gets the int-handling overload, not a semantically different one. The
convention keeps the script-to-primitive binding predictable.

**Visual cues.**

The Eagle codebase uses a few recurring visual markers, each with a
stable meaning.

- **Horizontal separator lines.** A line of seventy-six `#`
  characters in Eagle scripts (and a corresponding `//` form of the
  same width in the C# layer) marks a major section boundary in a
  file. The width is wide enough to be visually unmistakable in any
  reasonable terminal.
- **Block comments at file head.** Every `.eagle` script begins with
  a fixed seven-line block comment: a separator, the file name with
  a `-- short description` annotation, the project name (`Extensible
  Adaptable Generalized Logic Engine (Eagle)`), the copyright line,
  the license-terms reference, the RCS Id line, and a closing
  separator. The block is identical across hundreds of files. The
  uniformity is the point: a reader opening any Eagle file knows
  where the actual code starts and what license it claims.
- **ALL CAPS for emphasis inside comments.** Words like `IMPORTANT`,
  `WARNING`, `NOTE`, `HACK`, `TODO`, `BUGBUG`, `BUGFIX`,
  `SECURITY` are written in capitals inside comments. The all-caps
  form is rare enough elsewhere that it functions as a high-attention
  marker. A reader scanning a file's comments registers the caps
  before reading the surrounding text.
- **Prefixed comments with grep-able taxonomy.** Discussed in §5.7.
  The prefixes (`# NOTE:`, `# HACK:`, `# TODO:`, `# BUGFIX:`,
  `# BUGBUG:`) make intent searchable. The prefixes are always
  followed by a colon and a space; never abbreviated; never combined.
- **Hanging-indent multi-line `[appendArgs]` calls.** When a string
  is built from many fragments, the call wraps with each fragment on
  its own line, indented to align under the first argument. The
  shape of the construction is visible at a glance — the reader sees
  the assembled string without parsing the substitution syntax.

The visual cues are not decoration. They are part of the codebase's
grammar. A reader reads the cues alongside the code.

**Names: one combination, one concept.**

The strongest naming convention in Eagle is that *a given combination
of name prefix, base name, and suffix maps to exactly one concept,
subsystem, or data domain across the entire codebase*. This is the
rule that makes everything else possible. A few representative
patterns:

- **`eagle_*` prefix.** Procedures with the `eagle_` prefix are
  Eagle-specific extensions to the test framework that have no native
  Tcl analog: `[eagle_shellUnknown]`, `[eagle_shellBuildCommand]`,
  `[eagle_isShellScriptLevel]`, `[eagle_getShellPromptScript]`. A
  reader seeing `eagle_` knows this is Eagle-only territory.
- **`have*` predicates.** `[haveConstraint]`, `[haveSecurity]`,
  `[havePluginLicenseEnvironmentVariableNames]`, `[haveCaches]`,
  `[haveModernNetFx]` answer a boolean question: does the named thing
  currently exist or apply? The pattern is uniform; the return is
  always boolean.
- **`get*` accessors.** `[getTestRunId]`,
  `[getRequestLicenseCertificateUri]`,
  `[getDotNetCoreRuntimeVersions]` return a value. The pattern
  matches the .NET property-getter convention. The return is never
  void; the procedure is referentially transparent in any context
  with a result.
- **`set*` mutators.** `[setKeyName]`, `[setApprovedDataPolicy]`
  update state. The return is conventionally the empty string (the
  side effect is the point).
- **`is*` predicates.** `[isEagle]`, `[isMono]`, `[isDotNetCore]`,
  `[isValidKeyRing]`, `[isOsWindows11]` answer a boolean question
  about a current property. The pattern matches the .NET `bool Is*`
  property convention.
- **`save*` / `restore*` pairs.** Discussed in §5.5. Every `save*`
  has a matching `restore*`; the pair is the atomic unit of mutable
  composability.
- **`add*` / `remove*` pairs.** `[addConstraint]` has a matching
  `[removeConstraint]`; `[addToArgv]` has a matching
  `[removeFromArgv]`; `[addRuntimeOption]` has a matching
  `[removeRuntimeOption]`. The convention is uniform.
- **`checkFor*` probes.** Test-framework conventions for runtime
  feature detection. Discussed in §8.5.3.
- **`maybe*` for conditional actions.** `[maybeInvokeHook]`,
  `[maybeAddToAutoPath]`, `[maybeKillProcessGroup]` perform the named
  action *conditionally* — typically when some override flag is
  unset and the precondition holds. The pattern signals to the caller
  that the procedure is safe to call unconditionally; the conditional
  logic is internal.
- **`try*` for fallible actions.** `[tryToLoadZeus]`,
  `[tryDetectFossilRoot]`, `[tryTestRunCommand]` attempt the named
  action and report success or failure via return value rather than
  via exception. The pattern matches the .NET `TryGetValue` /
  `TryParse` convention.

The patterns compose. `[tryDetectFossilRoot]` is a `try*` (fallible
action) about `Fossil` (the subsystem). `[checkForTestExec]` is a
`checkFor*` (test-framework probe) about `TestExec` (the subsystem). A
reader who has internalized the prefixes and suffixes can predict what
a procedure does from its name, with high accuracy, before reading
the body.

The strictness of the convention is what makes it useful. A `have*`
that returned a non-boolean would break the reader's mental model. A
`get*` with side effects would break the convention. An `add*`
without a matching `remove*` would be an asymmetry that demanded
explanation. The Eagle codebase, across roughly six hundred script
procedures and tens of thousands of C# methods, maintains the
convention almost without exception — and where exceptions exist,
they are documented inline.

**Nouns and verbs aligned with .NET.**

Eagle's script-level vocabulary is calibrated to match .NET's
vocabulary where the concepts are shared. The alignment makes the
cross-language boundary easier to cross.

| Eagle verb | .NET equivalent | Examples |
|---|---|---|
| `Create` | factory methods | `[interp create]`, `[object create]`, `Interpreter.Create()` |
| `Dispose` | `IDisposable.Dispose()` | `[object dispose]`, the six-phase interpreter teardown |
| `Get` / `Set` | property accessors | `[getRuntimeVersion]`, `[setKeyName]`, `Interpreter.GetActive()` |
| `Try*` | `TryParse` / `TryGetValue` | `[tryToLoadZeus]`, `Try*` C# helpers |
| `Has*` | `bool Has*` properties | `[hasRuntimeOption]`, `[hasInterpreterFlags]`, `Interpreter.HasSecurity` |
| `Is*` | `bool Is*` properties | `[isEagle]`, `[isSafe]`, `Interpreter.IsSafe()` |
| `To` / `From` | conversion methods | `[publicKeyTokenToBytes]`, `[getStringFromObjectHandle]` |

The alignment has a structural reason. A script call that names a
.NET method by its conventional name binds correctly without mental
translation. When the script says `[object invoke $obj Dispose]`, the
script author thinks "dispose the object" and the .NET layer responds
with the `IDisposable.Dispose()` method. The vocabulary is unified
across the boundary. The boundary remains visible (because the call
goes through `[object invoke]`), but the vocabulary does not change
as it crosses.

**Predicates: name the question, not the boundary.**

A comparison operator is not just an arithmetic test; it is a
statement of what the surrounding code thinks is meaningful. The Eagle
codebase consistently prefers `$len > 0` over `$len >= 1`, even though
for integer `$len` the two expressions evaluate to the same boolean.
The preference is communicative, not computational, and it illustrates
a deeper standard: an expression should name the question it is
asking, not merely produce the right answer.

`$len > 0` says "is there *anything*?" The reader sees zero as the
boundary between "empty" and "non-empty," because zero *is* that
boundary in every numeric domain. `$len >= 1` says "is there at least
*one*?" — a threshold predicate that introduces the magic number `1`
and asks the reader to recover the "any" semantics from a
"threshold-of-one" formulation. When the actual question is "do we
have any?", the first form names it; the second describes a different
question that happens to produce the same answer.

Four reasons reinforce the preference. *Intent*: `> 0` matches the
natural mathematical sense of "positive"; `>= 1` requires the reader
to translate. *Robustness to refactoring*: if `$len` is ever
recomputed to a non-integer — a duration, a ratio, a floating-point
measurement — `> 0` continues to mean "is there any of it?" while
`>= 1` silently changes meaning, because `0.5` is positive but fails
the threshold. In a scripting language whose substrate is
everything-is-a-string, this kind of silent type drift is not caught
by a compiler. *Negation symmetry*: the natural negation of `> 0` is
`== 0`, which reads cleanly as "empty"; the natural negation of
`>= 1` is `< 1`, which reads as "less than the threshold" — awkward
when the threshold was never the point. *Convention alignment*: the
.NET layer writes `list.Count > 0` (or `list.Any()`) for the same
question; keeping the script-side expression aligned with the
primitive-side expression keeps the boundary easy to cross.

The convention reserves `>= N` for cases where `N` is a *real domain
value* — batch sizes, retry counts, minimum-required-version checks,
pagination limits. There the threshold *is* the point, and naming it
explicitly is what the reader wants to see. The discipline of using
`> 0` for the "any?" question and `>= N` only when `N` matters keeps
the two patterns visually distinct: a reader who sees `>= 1` in the
codebase pauses, because the appearance of `1` as a threshold is
anomalous; a reader who sees `> 0` glides past it as the obvious
phrasing of "any?". This is the §8.2 *clear abstraction* property
applied at the level of an expression rather than a procedure: the
form of the code should match the form of the question it is asking.

**Consistency, consistency, consistency.**

The deepest beauty standard is that conventions, once adopted, are
applied uniformly. A convention that is applied "most of the time" is
worse than no convention at all, because the exceptions force readers
to *verify* rather than *trust*. A codebase whose conventions are
consistent admits readers without ceremony. A codebase whose
conventions are sometimes-this, sometimes-that requires every reader
to decide which convention applies in any given case. The decision
overhead compounds across the codebase's lifetime; over decades, the
difference between consistent and almost-consistent is the difference
between a codebase that survives its original author and one that
does not.

Eagle's conventions are applied near-uniformly. A new contributor can
learn the indentation rules in five minutes; the consistency takes
years to build and is paid for one procedure at a time. The audit
work that produced this whitepaper's case study found, in practice,
that the consistency was near-total across the codebase. Procedures
that had been edited by multiple authors over decades still followed
the original conventions, because each editor read the surrounding
code before making changes and matched the style they found.

This is the part of the beauty discipline that most resists shortcut.
It cannot be added later. It cannot be enforced retroactively. It can
only be built by every contributor, every edit, choosing the
convention over their own preference. The codebase that emerges is
one where any reader, anywhere in the file, can predict the shape of
the next ten lines before reading them.

**What this gives the §8 thesis.**

These standards are how the §8.2 properties get from "abstract design
principles" to "concrete, recognizable, enforceable conventions that
a reader can verify in seconds." Consistency makes symmetry visible.
Naming conventions make cohesion visible. Visual cues make
predictable control flow visible. The standards are not the beauty
themselves; they are the *vocabulary* through which the beauty is
expressed. A codebase that follows them produces code whose beauty is
*recognizable*, which is the necessary precondition for the
beauty-correctness correlation in §8.4 to operate at all.

### 8.4 Why beauty correlates with correctness

The correlation is real because the properties that produce beauty also
reduce the entry of bugs and increase the chance of catching the ones
that enter.

**Mechanism 1: shared causes.** Each of the beauty properties
independently reduces the bug rate. Cohesion means each unit does one
thing, so the unit's correctness is locally checkable; non-cohesive units
harbor bugs in the unstated interactions between their multiple
responsibilities. Symmetry means related operations are written
similarly, so an asymmetry — a parameter present in `[encrypt*]` but
missing from `[decrypt*]` — is a visible smell. Minimality means there
are fewer places for bugs to hide. Clear abstraction means the
implementation matches what the caller expected, so the bug surface is
small. Predictable control flow means the reader can simulate the
procedure in their head; bugs in simulatable code are easier to find.
Consistent naming means the reader can navigate the codebase without
surprises; surprising names lead to misreadings that lead to bugs.

**Mechanism 2: review.** Beautiful code is easier to review. A reviewer
who can hold the procedure in their head can verify it. A reviewer who
cannot hold the procedure in their head approves it on faith. Beautiful
code receives meaningful review; ugly code receives ritual review. Bugs
that survive review are bugs in deployed code.

**Mechanism 3: selection.** Beautiful code attracts careful authors. A
developer who values beauty rewrites until the code is beautiful, which
usually means rewriting until the bugs are gone. A developer who does
not value beauty stops rewriting when the code works, which may be
before the bugs are gone. The correlation between author values and
code quality is well-established; beauty is one of the proxies.

**Mechanism 4: copy-paste resistance.** Ugly code rewards copy-paste —
the copying author cannot understand the original well enough to
abstract it, so they duplicate it. The duplicate inherits all the
original's bugs, and any fix to the original does not propagate to the
duplicate. Beautiful code is easier to abstract, so duplication is
rarer; bugs that would have been duplicated are fixed once and stay
fixed.

The mechanisms compound. A beautiful procedure is harder to break,
easier to review when it changes, written by an author who is paying
attention, and harder to copy-paste into other places. The cumulative
effect is a measurably lower bug rate.

The mechanisms also explain why the correlation is not perfect.
Mechanism 1 fails when the beauty properties are present but applied to
the wrong abstraction (cohesive code that does the wrong thing
cohesively). Mechanism 2 fails when the reviewers do not actually
review. Mechanism 3 fails when external pressure forces shipping before
rewriting. Mechanism 4 fails when the codebase is small and duplication
is not an issue. Each mechanism is one of several independent inputs to
correctness; beauty is the conjunction of these inputs, but the
conjunction is not deterministic.

### 8.5 Examples from Eagle

The Eagle codebase contains procedures and small systems that
experienced peers tend to call beautiful. The criteria of §8.2 can be
applied to each; the resulting beauty correlates, in practice, with the
procedure's track record of correctness. Six examples follow. For each,
the structure is: (a) the code excerpt or shape, (b) the beauty
properties from §8.2 that it exhibits, (c) the correctness properties
that fall out, and (d) the historical defect record from the audit work
that produced this whitepaper's case study.

#### 8.5.1 The `[appendArgs]` foundational primitive

The primitive is two lines:

```tcl
set result ""; eval append result $args
```

That is the entire implementation. The procedure has one job —
concatenate its arguments verbatim into a string — and it does that job
without a single line of ceremony.

*What makes it beautiful.* **Cohesion** is total. The procedure does
exactly one thing. Its name describes the thing. There is no alternate
behavior, no special case, no flag. **Minimality** is near-absolute,
with one informative exception: the initial `[set result ""]` is not
*strictly* required (Tcl's `[append]` will create the variable on its
own), but the explicit initialization expresses intent — the author
wants a fresh, empty result regardless of any later refactoring that
might introduce a `result` use earlier in the procedure body. The
two-line shape is therefore not the shortest possible body; it is the
shortest body that documents what it means. **Clear abstraction.** The
signature matches the semantics: take any number of arguments; return
their concatenation. The mental model fits in one phrase. **Consistent
naming.** The verb is `append`, which matches the underlying Tcl
primitive. The plural noun `Args` matches the variadic parameter.
**Predictable control flow.** There is no control flow.

*What follows for correctness.* Zero defects in the audit history;
there is nothing in the body that could be wrong. The procedure is used
thousands of times across the Eagle codebase, and each call site is
shorter and more readable than the equivalent double-quoted string
would be (the procedure does not perform substitution). A bug in
`[appendArgs]` would propagate everywhere; the absence of bugs means
that thousands of call sites can rely on it without verification. The
primitive's correctness amortizes over its uses in a way that compounds.

The beauty property that pays off most here is *disciplined* minimality
— as short as the body can be *while still expressing the author's
intent*, not as short as it could possibly be. No place for a bug to
hide; no missing context for a future maintainer to recover.

#### 8.5.2 The `list.eagle` functional core

`list.eagle` contains six procedures: `[lappendArgs]`, `[lshuffle]`,
`[ldifference]`, `[filter]`, `[map]`, and `[reduce]`. Together they
form a small functional-programming toolkit, comparable in scope to the
`Data.List` core in Haskell or the `functools` essentials in Python —
but expressed in roughly thirty lines of Tcl per procedure.

The body of `[filter]` is representative:

```tcl
set result [list]

foreach item $list {
  if {[uplevel 1 $script [list $item]]} then {
    lappend result $item
  }
}
```

Six lines of body. Three lines if the braces are not counted.

*What makes the collection beautiful.* **Symmetry.** Every procedure
follows the same pattern: iterate the input, apply a callback,
accumulate a result. The callback is evaluated with `[uplevel 1]` so it
runs in the caller's frame; the element is passed via `[list $item]` so
it arrives correctly quoted. The same pattern recurs in `[map]`, in
`[reduce]`, and in the higher-arity helpers. **Cohesion.** Each
procedure does one thing. `[filter]` selects; `[map]` transforms;
`[reduce]` folds. The names match the semantics and match the
convention of every other functional-programming toolkit.
**Minimality.** Each procedure's body is the shortest expression of
its semantics. There are no optional parameters, no fast paths for
empty lists, no special cases for one-element lists. The general case
handles all cases. **Consistent naming.** The verbs match the
Haskell/ML tradition. The argument names (`list`, `script`) match
across procedures.

*What follows for correctness.* The audit found that all six
procedures' help blocks were already substantially accurate when first
read. The procedures' beauty correlated with documentation accuracy —
a careful author wrote the body, and a careful author wrote the
documentation, and they agreed because both reflect the same clean
understanding. The procedures compose. A pipeline of `[filter]` then
`[map]` then `[reduce]` is a common idiom in user-level scripts; it
works because each procedure respects the others' calling conventions.
The composability is a property of the symmetry — a procedure that
broke the pattern would not compose with the rest. Zero defects in
the audit history.

The beauty property that pays off most here is symmetry. The toolkit
is consistent because every procedure follows the same pattern; the
consistency is what makes it usable as a toolkit rather than as six
separate procedures.

#### 8.5.3 The constraint system

The Eagle test framework's constraint system consists of three core
procedures — `[haveConstraint]`, `[addConstraint]`,
`[removeConstraint]` — and a family of `[checkFor*]` probes that
populate the constraint set.

`[haveConstraint]` is the query:

```tcl
if {[isEagle]} then {
  return [expr {
      [info exists ::eagle_tests(Constraints)] && \
      [lsearch -exact $::eagle_tests(Constraints) $name] != -1}]
} else {
  return [expr {
      [info exists ::tcltest::testConstraints($name)] && \
      $::tcltest::testConstraints($name)}]
}
```

`[addConstraint]` is the mutator. `[removeConstraint]` is the inverse.
Each is roughly ten lines. The three together are the entire protocol.

*What makes the system beautiful.* **Cohesion.** Each procedure does
one thing. The protocol has exactly the operations that are needed:
query, add, remove. There is no `[updateConstraint]`, no
`[mergeConstraints]`, no batch mutator — those would be conveniences
that compose from the three primitives. **Symmetry.** `[addConstraint]`
and `[removeConstraint]` are exact inverses. The same data structure is
queried by `[haveConstraint]` and mutated by the other two. The Eagle
backend and the Tcl backend are kept separate within each procedure,
with the same structure on both sides (engine check, then guarded
mutation). **Minimality.** The protocol could not be smaller and still
be useful. Each procedure could not be shorter and still be correct.
**Clear abstraction.** A constraint is a named runtime condition.
Tests gate on the presence of the constraint. The query, the
assertion, the retraction. The model is exactly what the test suite
needs and nothing more.

*What follows for correctness.* The constraint system has supported
thousands of tests across many years. The defect rate is, per the
audit, exceptionally low — no substantive defects found in the family
during a careful review. The system composes with the `[checkFor*]`
probe family. Each probe is its own procedure that calls
`[addConstraint]` if the probed condition holds; the probes can be
added without modifying the core protocol, because the protocol is
closed under composition. New probes plug in cleanly; that property
is a consequence of the protocol's minimality. The Eagle/Tcl
divergence — different storage representations on the two engines —
is handled per-procedure with parallel branches. The two branches are
kept symmetric so the engines behave the same at the protocol level.
The asymmetry in `[addConstraint]` (Eagle silently drops false
values; Tcl records them) is documented in the help block; it is the
kind of detail that would cause bugs if undocumented, and the
documentation is what makes it not cause bugs.

The beauty property that pays off most here is cohesion. The protocol
does exactly what tests need; nothing more, nothing less. The closure
under composition is the dividend.

#### 8.5.4 Shell argument processing

The test framework's argv handling decomposes into three stages:
`[augmentTestArguments]`, `[processTestArguments]`,
`[makeUseOfTestArguments]`. Each has one responsibility.

`[augmentTestArguments]` safely appends list-valued additions to an
argument list. It validates the value as a proper list before
appending; a malformed value is rejected rather than corrupting the
list. It is roughly thirty lines, and the core of its body is:

```tcl
if {[isEagle]} then {
  if {[string is list -strict $value]} then {
    set result true
  }
} else {
  if {[catch {llength $value}] == 0} then {
    set result true
  }
}

if {$result} then {
  eval lappend args $value
}
```

`[processTestArguments]` walks the argument list against a fixed table
of known option names. It optionally augments the list from environment
variables first (calling the previous procedure). It produces a
recognized-options array for the caller and returns the unrecognized
arguments. It is roughly two hundred lines.

`[makeUseOfTestArguments]` applies the recognized options to the live
test framework state. It is the side-effect step.

*What makes the trio beautiful.* **Cohesion.** Each procedure does
exactly its named thing. `[augmentTestArguments]` extends;
`[processTestArguments]` parses; `[makeUseOfTestArguments]` applies.
The names are imperative and accurate. **Symmetry.** All three take a
variable name as their first argument and update the variable in the
caller's frame. All three log in the same format. All three respect
the same set of override flags. A reader who understands one
understands the others' shape. **Clear abstraction.** The decomposition
matches the natural stages of command-line processing: gather, parse,
apply. The decomposition could not be different without combining
responsibilities that the protocol keeps separate for good reason —
the apply step has irreversible side effects, so isolating it makes
the prior stages reusable. **Predictable control flow.** Each
procedure has one loop and a handful of guard clauses. The cyclomatic
complexity is low for the size; a reader can hold each procedure in
their head.

*What follows for correctness.* The audit found no substantive defects
in the family. The decomposition is the reason: each stage's
correctness is locally verifiable, and the composition cannot
introduce bugs that are not bugs in one stage. The strict/non-strict
resynchronization in `[processTestArguments]` — backing up one element
when an option appears in value position — is subtle, and the help
block documents it explicitly. The documentation is what makes the
subtlety navigable; without it, a maintainer encountering the backup
logic might "fix" it and break the strict-mode contract. The trio is
extensible. Adding a new recognized option means extending one table
in `[processTestArguments]` and (if it has side effects) one branch in
`[makeUseOfTestArguments]`. The shape of the change is predictable
because the shape of the code is predictable.

The beauty property that pays off most here is clear abstraction. The
three-stage decomposition matches the domain perfectly; that fit is
what makes each stage simple and the composition straightforward.

#### 8.5.5 The interactive command loop

The Eagle interactive shell is the cleanest available example of the
dual-language model expressing itself in user-visible behavior. It is
also the example where the beauty argument has the most surface to
land on, because the shell is *two* cooperating pieces of code in two
different languages: the C# scaffolding (`PrivateShellMainCore` and
`PrivateInteractiveLoop`, both in `Interpreter.cs`) and the Eagle
policy layer (`[eagle_shellUnknown]`, the prompt-setup procedures,
the security-aware command parsing). The pieces are beautiful
*together* in a way that neither would be alone.

**The C# scaffolding.** `PrivateShellMainCore` is approximately 4,700
lines; `PrivateInteractiveLoop` is approximately 1,600. Both are
large. Both are organized internally by `#region` blocks at a
fine-grained scale: a reader navigating to "Wait On Paused Interactive
Loop" or "Interactive Host Begin-Processing Hook Callback" goes to a
single region and finds everything that concerns that subject. The
two methods exhibit the §8.2 beauty properties at the C# scale:

- **Cohesion within each region.** Every region does one thing. The
  region names are the thing they do. A reader who is wondering
  whether the loop saves engine flags before entry finds a "Save /
  Push Engine Flags" region and reads the answer in twenty lines.
- **Symmetry across regions.** Save/restore pairs are always in
  matched regions ("Save / Push" with "Restore / Pop"). Entry hooks
  ("Interactive Host Begin-Processing Hook Callback") are paired
  with exit hooks ("Interactive Host End-Processing Hook
  Callback"). The internal structure mirrors the §5.5 save/restore
  convention from the Eagle script layer.
- **Predictable control flow at the method scale.** Each method has
  a setup phase, a working phase, and a teardown phase. Within the
  working phase, the per-iteration structure is the same on every
  iteration. A reader who wants to know "what happens for each
  command the user types" reads one iteration's worth of regions.
- **Clear abstraction.** `PrivateShellMainCore` does the work of
  preparing the shell and dispatching command-line arguments; it
  hands off to `PrivateInteractiveLoop` for the read-eval-print
  loop. The decomposition matches the natural shape of a shell:
  one method for the launch, one for the loop. The boundary
  between them is at the right place.

**The Eagle policy layer.** The C# methods provide the scaffolding;
they do not implement the shell's *personality*. That work is in
Eagle: `[eagle_shellUnknown]` decides whether an unrecognized
command should be dispatched to a system shell, and how;
`[eagle_getShellPromptScript]` and `[eagle_setupPromptScript]`
control what the prompt looks like; runtime options control
which sub-behaviors are active. A user who wants a different
prompt does not modify `PrivateInteractiveLoop`; they redefine the
Eagle prompt-setup procedures. A user who wants different
unknown-command behavior does not modify the C# loop; they
replace `[eagle_shellUnknown]`.

The procedure that most rewards close reading on the Eagle side is
`[eagle_shellUnknown]` — the script-level `[unknown]` handler that
gives the interactive shell its ability to dispatch operating-system
commands (`DIR`, `Get-Process`, `ls`) as if they were Eagle commands.

The dispatcher's structure:

```tcl
if {![info exists ::no(shellUnknown)] && \
    [string range $name 0 1] ne "::" && \
    [eagle_isShellScriptLevel 3] && [eagle_haveShell shell]} then {
  set skipped false
  set command [eval \
      eagle_shellBuildCommand [list $shell] [list $name] $args]

  if {[llength $command] > 0} then {
    # ... dispatch what-if / execute / error paths ...
  } else {
    set skipped true
    maybeInvokeForTester ::shellUnknownNoCommand
  }
} else {
  set skipped true
}

# delegation to ::savedUnknown when skipped or ok-fallback set
```

Roughly a hundred lines including the help block.

*What makes the procedure beautiful.* **Predictable control flow.**
Four guard conditions at the top decide whether to attempt shell
dispatch. Three execution paths (what-if, success, error) inside the
dispatch. One delegation path at the bottom for the skipped case. The
reader can sketch the procedure's behavior in a single sentence per
path. **Clear abstraction.** The `[unknown]` handler is the natural
extension point for "what to do when a command is not recognized." The
procedure does that and only that. The decision to dispatch to a shell
is one of the possible responses; the delegation to a previously saved
handler is another. The shape of the procedure matches the shape of
the responsibility. **Symmetry.** Every observable event (the decision
to attempt shell dispatch, the decision to abort, the success path,
the error path) is announced via `[maybeInvokeForTester]`. The hook
names are uniform: `::beforeShellUnknown`, `::afterShellUnknown`,
`::shellUnknownError`, `::shellUnknownNoCommand`. A test that wants to
observe any of these events knows the hook name without consulting
documentation. **Cohesion.** Each part of the procedure does its own
work. The guards are guards. The dispatcher is the dispatcher. The
delegation is the delegation. There is no commingling of concerns.

*What follows for correctness.* The audit found one substantive issue
in this family: the delegation precondition in `[eagle_shellUnknown]`
was originally documented as "error-fallback or ok-fallback," but the
code delegates only on `skipped || OkFallback`. The fix was a
documentation correction, not a code change — the code was right and
the documentation was wrong. The procedure's beauty caught the bug,
because the code was simple enough to read carefully. The "magic
offset of three" — the number of `EvaluateScript` frames between the
interactive loop and this procedure — is documented explicitly, with
a `# HACK:` comment pointing the maintainer to
`[eagle_isShellScriptLevel]` where the accounting is explained;
load-bearing context that survives distant changes. The hook system
means test code can observe and influence every phase of the dispatch
without modifying the procedure — extensibility as a consequence of
symmetric hook placement.

The beauty property that pays off most here is symmetry. The hook
system, the guard structure, the delegation precondition — each is
uniform with the rest of the procedure, and the uniformity is what
makes both the documentation correction and the test observability
possible.

**What the C# and Eagle pieces look like together.** Reading
`PrivateShellMainCore` and `PrivateInteractiveLoop` alongside
`[eagle_shellUnknown]` is what makes the shell example land as a
beauty argument rather than as two unrelated case studies. The C#
scaffolding is beautiful in the §8.2 sense — large but cohesive,
fine-grained in its regions, predictable in its control flow,
clearly abstracted into the launch/loop pair. The Eagle handler is
beautiful in the same sense — small and focused, with symmetric
guards and a uniform hook placement. Both pieces would be smaller
and weaker if forced into a single language. The C# layer would
have to embed personality decisions that are properly the
deployment's concern; the Eagle layer would have to reach into
process-level scaffolding that is properly the runtime's concern.
The boundary between them is the same boundary the rest of this
whitepaper has been about. The boundary is where the beauty lives.

That last claim is worth stating directly. The §8 argument is that
beauty correlates with correctness. The shell example shows that
the beauty is not in either layer alone — it is in the *fit* between
them. The C# scaffolding fits because it knows what to leave to
Eagle. The Eagle handler fits because it knows what the C# layer is
going to do around it. The fit is the design. The audit found one
substantive issue in the entire family — a documentation correction
in `[eagle_shellUnknown]` — and zero substantive code defects across
either layer. The correlation between the §8.2 properties and the
correctness record is, in this example, total.

#### 8.5.6 The `# <help>` block convention

The convention itself — embedded XML-shaped documentation inside
brace-quoted procedure bodies, parsed at runtime by the `HelpOps`
component, queried via `#help <proc>` — is the most distinctive design
choice in the Eagle codebase. It is also, by the criteria of §8.2, the
most beautiful.

The mechanism uses no new syntax. It depends on the language's
existing brace-quoting contract: the body is verbatim, so anything
that looks like an XML comment inside `# ` prefixes is preserved
exactly. The parser strips the `# ` prefix and interprets the contents
as XML. No new lexer, no new parse phase, no new artifact.

The query is a single command. `#help foo` at the Eagle shell finds
the procedure named `foo`, extracts its `# <help>` block, and prints
it. The mechanism does not depend on a build step, a documentation
server, or an index. The interpreter is the index.

*What makes the convention beautiful.* **Minimality.** No new syntax.
No new file format. No new tooling. The convention reuses the
language's existing primitives — comment syntax, brace-quoted bodies,
runtime introspection — and gets a documentation system for free.
**Cohesion.** The documentation lives inside the procedure. The
procedure is the artifact. The two cannot be separated. **Clear
abstraction.** Documentation is what callers need to know. The block
describes the contract from the caller's point of view. The body
describes the implementation from the maintainer's point of view. The
two views are kept distinct. **Symmetry.** Every procedure has the
same five-section convention (summary, How it works, Tricky details,
Arguments, Results). A reader who has read one block knows where to
find each piece of information in any other block.

*What follows for correctness.* The convention has survived a decade
of changes without modification to the parser. The mechanism's
stability is a property of its minimality — there is no surface to
break. The audit that produced this whitepaper's case study found
that the `# <help>` blocks were substantially accurate across roughly
a thousand procedures, with nineteen documentation fixes applied. The
accuracy is not a property of the convention itself — it is a
property of the maintainers' discipline. But the convention makes the
discipline tractable: a block that is wrong is wrong in a place the
maintainer can find and fix without leaving the procedure body. The
`#help` command is the discovery mechanism that makes the codebase
navigable without IDE support. A developer at an Eagle shell can
answer questions about any procedure by asking the interpreter; the
interpreter knows because the documentation is part of the procedure.

The beauty property that pays off most here is minimality. The
convention adds nothing new to the language; it gets a documentation
system from the primitives the language already has. The lack of new
machinery is what makes the convention survivable across changes that
would break a more elaborate system.

#### 8.5.7 The pattern across the examples

Six examples, six instances of the §8.2 properties holding in
conjunction, six procedures or systems whose audit defect rate is
consistent with the §8.4 mechanisms.

The pattern across the examples is that the beauty properties are not
decoration. They produce concrete correctness benefits: bugs that
cannot enter (minimality), bugs that are caught at review (clarity),
bugs that are documented out of existence (symmetric naming), bugs
that the composition of the parts cannot introduce (cohesion). The
examples are not selected because they are beautiful; they are
selected because their beauty is *visible* and their correctness
record is consistent with the visibility.

A reader who finishes §8.5 should also notice an absence. Not one of
the six examples is "clever" in the sense of using a non-obvious
technique. None of them performs a virtuoso compression of intent
into syntax. None of them relies on an obscure feature of the
language. The examples are beautiful because they are *simple*, not
because they are surprising. That is what the §8.4 mechanisms predict:
the beauty properties that correlate with correctness are the ones
that make code *easier* to understand, not harder. Cleverness pulls
in the opposite direction.

This is the deepest version of the §8 thesis. Beauty in code is the
visible signature of an author who chose simple over clever every
time the choice came up. The correlation with correctness follows
because simple code is verifiable and clever code is not.

### 8.6 Counterexamples and what they teach

The thesis is probabilistic, not deterministic. Counterexamples exist,
and they instruct.

**Beautiful code with bugs.** The `[isNetFx40]` procedure discussed
earlier in this whitepaper is structurally elegant — a clean comparison
against a sentinel version, with a defensive fallback when the runtime
version is unknown. The procedure is short, named clearly, and
predictable. It also contained a wrong sentinel value for years, causing
it to misclassify .NET Framework 4.0 through 4.5.2 runtimes. The beauty
of the procedure did not prevent the bug because the beauty was on the
wrong axis — the structure was clean but the constant was wrong, and
constants are not what makes code beautiful or ugly.

What this teaches: beauty is a signal in some dimensions but not all.
Structural beauty does not catch value-level errors. The thesis must be
read as a correlation, not a guarantee, and the correlation is weakest
on properties that beauty does not see.

**Ugly code that works.** Long-lived production systems contain ugly
procedures that have run reliably for years. The mechanism is usually
that the procedure was written, tested, deployed, never modified, and
faced a narrow input distribution. Beauty matters less when code does
not change.

What this teaches: the beauty-correctness correlation operates over the
codebase's lifetime, not at any single moment. A procedure that is
frozen accumulates fewer bugs than one that is touched, regardless of
its initial beauty. The discipline of writing beautiful code pays off
disproportionately for code that changes.

**Beauty in the wrong dimension.** Over-abstraction, premature DRY, and
gold-plating all produce code that looks beautiful but is actually
worse. A procedure with three optional callbacks and a configurable
strategy object may be cleverer than the equivalent inline code; it is
also harder to read, harder to debug, and harder to verify. The beauty
is shallow — it is the beauty of pattern application, not the beauty
of fit-to-purpose.

What this teaches: the beauty properties of §8.2 are necessary
together, not individually. Clean abstraction without minimality is
over-engineering. Symmetry without cohesion is ritual. The signal comes
from the conjunction.

**Eagle's own articulation: reliability over elegance.** The Eagle
architecture documentation explicitly states a design principle —
"when a choice exists between a pattern that looks clean and one that
works correctly under all conditions (threading, disposal, platform
differences, AppDomain boundaries), correctness wins." This is the
counterexample teaching internalized as a design rule. The §8 thesis
is that beauty *correlates* with correctness, not that beauty *is*
correctness; Eagle's own design principle says the same thing from the
opposite direction. When the two would conflict, the architecture picks
correctness; the code that results may not look maximally elegant, but
it is right, and "right" is what the beauty discipline was a heuristic
for in the first place. The architecture's stated rule and the
whitepaper's stated thesis are the same observation, calibrated for
different cases: most of the time they agree, and the rare cases where
they would disagree are decided in correctness's favor on both
sides.

### 8.7 Beauty as a design discipline

The thesis can be inverted into a discipline: write code that you find
beautiful, and you will produce code that is more likely to be correct.

The discipline is not aesthetic posturing. It is the application of a
heuristic with empirical support. The mechanisms in §8.4 explain why
the heuristic works; the examples in §8.5 illustrate it; the
counterexamples in §8.6 calibrate it.

The discipline scales because it can be taught. A developer asking
"what would make this beautiful?" is asking a tractable question:
which of the §8.2 properties is missing? Cohesion? Add it. Symmetry?
Restore it. Minimality? Delete the vestigial code. Clear abstraction?
Rename until the name fits. Predictable control flow? Refactor until
the nesting drops. Consistent naming? Audit the file for surprises.

The discipline costs. It takes time at the design moment. It rejects
working code that has not yet been made beautiful. It produces fewer
features per quarter than the alternative discipline of "ship it when
it works."

The discipline pays off later. Beautiful code attracts fewer bugs,
receives more meaningful review, attracts more careful contributors,
and resists the entropy that ugly code invites. Over the lifetime of
a long-lived system, the discipline produces measurably fewer
production incidents.

The thesis of this whitepaper — that the dual-language model is the
right architecture for long-lived, security-sensitive systems — is in
turn supported by the beauty discipline. The conventions described in
§5 and defended in §6 produce code that experienced peers tend to call
beautiful. The procedures audited during the case-study work were
found to be correct at a rate substantially higher than the rates
typical of large codebases. Both facts have the same explanation: the
model produces a structural environment in which beautiful code is
the natural local minimum.

### 8.8 The relationship to the dual-language model

The dual-language model supports beauty structurally.

The primitive layer is written in a language with strong typing and
mature tooling. Beautiful primitives are easier to write because the
language helps — types catch many errors, tooling supports
refactoring, the abstraction-versus-implementation distinction is
enforceable.

The policy layer is written in a small-kernel scripting language.
Beautiful policies are easier to write because the language imposes
few constraints — there are no class hierarchies to design, no type
parameters to thread, no module systems to satisfy. The policy code
is exactly what the policy says.

The boundary between the two is explicit. Beautiful boundary code is
easier to write because the boundary is visible — every cross-layer
call is marked, so the developer can see what they are doing.

A single-language system can produce beautiful code, but it has to
work harder for it. The single language must serve two roles, and the
roles' aesthetic requirements pull in different directions. The
primitive role wants type rigor; the policy role wants terse
flexibility. The single language reaches a compromise; the compromise
is by definition less aesthetic than the role-specific optima.

This is why the dual-language model and the beauty discipline are
complements. The model gives the discipline structural support; the
discipline gives the model the correctness payoff that justifies the
operational cost. Together they describe a way of writing software
that experienced peers tend to find beautiful and that experienced
operators tend to find reliable.

These are the same property, viewed from different angles.

---

## §9 Conclusion: the boundary is the feature

**Section thesis.** The dual-language model is a *design philosophy*, not a
language preference. It can be applied in Python (C extensions plus Python
policy), Rust (with embedded scripting), C# (with Eagle or another
CLR-hosted scripting language), or any environment where the primitive layer
and the policy layer can be separated and the boundary can be made explicit.
What it requires is the discipline to keep the boundary visible and
load-bearing. The Eagle case study is the example that grounds the
abstraction; the argument generalizes.

### 9.1 The model is portable across languages

The dual-language model is not Eagle. It is not Tcl. It is not .NET. These
are instantiations; the model is the underlying design philosophy.

The same model can be applied in Python with C extensions and a clean
composition layer (most of the modern scientific-computing ecosystem). In
Rust with an embedded scripting language for policy (a growing pattern in
security tools). In C# with Eagle or any other CLR-hosted scripting
language. In Java with Clojure or Groovy for policy code. In any
environment where the primitive layer and the policy layer can be
separated and the boundary can be made explicit.

The Eagle case study in §4 is the example that the rest of this
whitepaper grounds. The argument generalizes. The conventions described
in §5 fall out in any dual-language deployment; the divergences from
"best practice" in §6 apply wherever the model is taken seriously; the
costs in §7 are paid in any deployment; the beauty discipline of §8 is
the same regardless of language.

The choice of *which* two languages is contingent. The choice of *whether*
to have two is architectural.

### 9.2 The boundary test

A simple test distinguishes systems that apply the model from systems that
do not.

Pick the system. Ask: can you point to the boundary?

If yes — if you can identify the syntactic events that mark cross-layer
calls, if you can grep for them, if the developers know which file
contains primitives and which contains policy — then the model is
applied. The boundary may be at `[object invoke]`, at `extern "C"`, at
`import ctypes`, at FFI wrappers, at a network protocol. The form does
not matter. The visibility matters.

If no — if the cross-layer calls are hidden behind ergonomic wrappers,
if the developers cannot tell which calls cost what, if the boundary is
implicit in the import system — then the model is not applied. The
system may still work. The system may even be productive. But it is
paying the costs of a hidden boundary: poorer auditability, opaque
performance, ambiguous trust, untestable seams.

The test is not perfect, but it is useful. Systems that fail it can
choose to make the boundary visible (with refactoring, documentation, or
convention). Systems that pass it can choose to maintain the visibility
deliberately (with conventions like Eagle's). The test names a property;
the property can be intervened upon.

### 9.3 When to apply and when not to

The model is not universally appropriate.

Small projects do not need it. A team of two building a tool that will
exist for a year can write everything in one language, accept the
implicit boundary, and ship faster than they would with the dual-language
overhead. The model's payoff arrives over time; a short-lifetime project
does not collect the payoff.

Large, long-lived, security-sensitive systems benefit from it
persistently. The systems that suit the model are the ones that the model
was named for: software that will outlive its original developer's
familiarity with it, that has to be audited periodically, that has trust
requirements expressed at the boundary, that has policy code changing
faster than primitive code, that has policy code that needs to be
deployed without rebuilding primitives.

The threshold is approximately: "the system will outlive its original
author's familiarity with it." If the answer is yes, the model is worth
the cost. If the answer is no, simpler is better.

This is not a binary. A system that starts small and grows can adopt the
model later; the migration costs in §7.6 are real but bounded. A system
that is large but uniformly maintained by its original team can stay
with a simpler architecture and adopt the model when the team changes.
The decision is contextual; the model is an option, not a requirement.

### 9.4 The mainstream is re-discovering the model under other names

The dual-language model recurs across the industry, usually without
acknowledgment.

**Infrastructure-as-code** (Pulumi, Terraform, CloudFormation) is a
dual-language deployment. The primitives are cloud APIs; the policy is
the configuration code. Pulumi's choice to use general-purpose languages
(TypeScript, Python, Go) for configuration is exactly the dual-language
model expressed across the cloud boundary.

**eBPF** is a dual-language deployment in the operating system. The
primitives are kernel functions; the policy is the eBPF program loaded
at runtime. The trust chain is implemented through the eBPF verifier
rather than through cryptographic signatures, but the structure is the
same.

**Embedded scripting in databases** — PostgreSQL functions in PL/pgSQL or
PL/Python, Snowflake stored procedures in JavaScript or Python, MongoDB
aggregation pipelines — are dual-language deployments where the database
is the primitive layer and the user-supplied script is the policy.

**WebAssembly** as a sandbox boundary is the most recent instance. The
primitives are host functions (browser APIs, server-side runtimes,
edge-compute platforms); the policy is the WebAssembly module loaded at
runtime. The boundary is the WASM ABI; the trust chain is the signing
and capability model of the host.

None of these is called "a dual-language system." None of them
acknowledges Ousterhout. All of them are instances of the model. The
recurrence is the strongest evidence that Ousterhout was naming a real
architectural pattern rather than describing a Tcl-specific accident.

### 9.5 Closing observation

Ousterhout was not predicting the future. He was naming a structural
feature of long-lived software systems.

Naming things makes them harder to forget.

This whitepaper is an attempt to name the model again, in the late
2020s, before the next round of "scripting languages won" commentary
makes it harder to find. The case study in §4 grounds the abstraction
in a working system. The conventions in §5 show what taking the model
seriously looks like. The divergences in §6 defend the conventions
against mainstream alternatives. The costs in §7 are honest. The
aesthetic argument in §8 offers a complementary case: even if the
architectural argument is rejected, the conventions produce code that
experienced peers find beautiful, and beauty correlates with
correctness.

The whitepaper's contribution is not that the dual-language model is
novel — it is twenty-eight years old, and the underlying pattern is
older than that. The contribution is that the model is still right,
still applicable, still mostly applied without acknowledgment, and
still worth naming explicitly. A reader who finishes this whitepaper
should not be persuaded to use Eagle. A reader who finishes this
whitepaper should be able to ask, of any system they encounter: where
is the boundary?

A companion paper, *If You Want a Project to Be Good, You Have to Love
Working on It* (also in the Eagle docs repository, as
`paper_love_and_software.md`), makes a complementary argument from the
opposite direction: that the characteristics of software described in
§§4–6 of this whitepaper — relentless attention to edge cases,
willingness to refactor working code because the abstraction is not
quite right, documentation of every deviation from convention, design
decisions that optimize for the next twenty years rather than the next
sprint — emerge only when the author is intrinsically motivated to do
the work. The two papers describe the same phenomenon from different
angles. The dual-language model is the architectural shape that
sustained intrinsic motivation produces over time. The intrinsic
motivation is what keeps the architectural shape from decaying. Either
paper read alone makes a case; both papers read together make the
fuller observation that good architecture and good motivation reinforce
each other across decades.

If the boundary is visible, the system is applying the model. If the
boundary is hidden, the system is paying for its hiding. The choice
between the two is the architectural decision this whitepaper exists
to surface.

The boundary is the feature.

---

## Appendices

### Appendix A — References

This appendix lists the works cited directly in the whitepaper, plus the
foundational works whose claims the whitepaper engages with. References are
grouped by relevance to the argument rather than chronologically. Where a
work has been reprinted or made available online by its publisher, the most
accessible form is given.

**The foundational dichotomy.**

- John K. Ousterhout, "Scripting: Higher-Level Programming for the 21st
  Century," *IEEE Computer*, vol. 31, no. 3, March 1998, pp. 23–30. The
  paper this whitepaper engages with throughout. Available in scanned form
  through IEEE Xplore and in HTML mirrors hosted by several universities.
- John K. Ousterhout, "Tcl: An Embeddable Command Language," in
  *Proceedings of the 1990 Winter USENIX Conference*, pp. 133–146. The
  earlier paper introducing Tcl, which establishes the design principles
  the 1998 essay generalizes.
- John K. Ousterhout, *Tcl and the Tk Toolkit*, Addison-Wesley, 1994. The
  original book-length treatment of Tcl, including the rationale for the
  command-language structure and brace-quoted bodies.

**Critiques and responses.**

- Bertrand Meyer, several essays in *Object-Oriented Software Engineering*
  arguing for strongly typed languages as a general-purpose solution. The
  strongest sustained pushback against the dichotomy during the period in
  which it was actively debated.
- Discussions in `comp.lang.tcl` and similar forums through the late
  1990s and 2000s, particularly around the question of whether Tcl's
  small-kernel character was an asset or a defect.

**Beauty and correctness.**

- Donald E. Knuth, "Literate Programming," *The Computer Journal*, vol.
  27, no. 2, May 1984, pp. 97–111. The original argument that the
  expressiveness of the program text affects the correctness of the
  program.
- Donald E. Knuth, *Literate Programming*, CSLI Publications, 1992. The
  collected essays.
- Edsger W. Dijkstra, "EWD 1308: What led to 'Notes on Structured
  Programming,'" 2001. Available through the EWD archive at the
  University of Texas. The source for "elegance is not a dispensable
  luxury but a quality that decides between success and failure."
- C. A. R. Hoare, "The Emperor's Old Clothes," 1981 Turing Award lecture,
  *Communications of the ACM*, vol. 24, no. 2, February 1981, pp. 75–83.
  The source for the observation that one builds either a system so
  simple it has no obvious deficiencies or so complicated it has no
  obvious deficiencies, and the argument that the first approach is
  preferable.
- Andy Oram and Greg Wilson, eds., *Beautiful Code: Leading Programmers
  Explain How They Think*, O'Reilly Media, 2007. The collected essays in
  which thirty-three expert programmers defend variants of the
  beauty-correctness correlation.

**The mainstream's drift.**

- Python Enhancement Proposals cited in §2.1, particularly PEP 484 (Type
  Hints, 2014), PEP 492 (Coroutines via async/await, 2015), PEP 544
  (Protocols: Structural subtyping, 2017), PEP 557 (Data Classes, 2017),
  and PEP 634 (Structural Pattern Matching, 2020). Available at
  `python.org/dev/peps`.
- TC39 ECMAScript specifications for the JavaScript-to-TypeScript
  trajectory. Available through the TC39 GitHub organization.

**Dual-language deployments.**

- Roberto Ierusalimschy, *Programming in Lua*, Lua.org, multiple editions.
  The standard reference for Lua, with explicit treatment of the
  embedded-scripting use case.
- Roberto Ierusalimschy, Luiz Henrique de Figueiredo, and Waldemar Celes,
  "The Evolution of Lua," in *HOPL III: Proceedings of the third ACM
  SIGPLAN conference on History of programming languages*, 2007.
- Brendan Gregg, *BPF Performance Tools: Linux System and Application
  Observability*, Addison-Wesley, 2019. The current standard reference
  for eBPF, including the trust model and the verifier as the boundary.
- The WebAssembly Core Specification, W3C Recommendation. The
  specification of the WASM boundary, the host/guest distinction, and the
  capability model that hosts can impose.

**Supply-chain security.**

- Selected reports on supply-chain attacks from CISA, ENISA, and academic
  venues, particularly from 2020 onward. The historical context in which
  signed-script trust chains earn their operational cost.
- Microsoft documentation on Authenticode and strong-name signing, for
  the .NET-ecosystem trust primitives that Harpy builds on.

### Appendix B — Glossary

Terms defined here are used in the whitepaper without further explanation.
A reader who is fluent in both Eagle/Tcl and .NET will recognize most of
them; the appendix exists for readers who are fluent in one ecosystem but
not the other.

**Authenticode.** Microsoft's code-signing technology for Windows
executables. Uses X.509 certificates to bind a vendor identity to a binary
artifact. Distinct from Harpy in that Authenticode signs binaries while
Harpy signs source.

**Brace-quoted body.** A procedure body delimited by an opening and closing
brace such that all bytes between the braces are taken verbatim — no
substitution, no escape processing, no normalization. The brace-quoted body
is the unit that Harpy signs, that `[info body]` returns, and that the
`# <help>` parser reads.

**CLI.** The Common Language Infrastructure (ECMA-335 / ISO/IEC 23271).
The standardized runtime that Eagle's primitive layer sits on, and the
type system that Eagle scripts cross into via `[object create]` and
`[object invoke]`. .NET is the most common implementation; Mono is another.

**Constraint.** In Eagle's test framework, a named runtime property that
tests can require. Constraints are added with `[addConstraint]`, queried
with `[haveConstraint]`, and produced by `[checkFor*]` probes. The
constraint system gates conditional test execution against the actual
running interpreter rather than against compile-time configuration.

**Cross-layer call.** A call from script code into primitive code or
vice versa. In Eagle, cross-layer calls are syntactically marked by the
`[object]` command family. In hidden-boundary systems, cross-layer calls
look the same as in-layer calls.

**Detached signature.** A cryptographic signature stored separately from
the signed artifact. In Harpy, a signed `foo.eagle` file has a sibling
`foo.eagle.harpy` containing the signature. Editing the signed file
invalidates the signature but does not corrupt the file itself.

**Dual-language model.** The design philosophy this whitepaper is about:
the explicit separation of primitive code (in a systems language) and
policy code (in a scripting language), with the boundary between them
made syntactically visible.

**Eagle.** The Tcl-semantics scripting language hosted on the .NET CLI
that serves as this whitepaper's worked case study.

**Fail-closed.** A failure mode in which an unavailable check refuses
the operation. Used in security-critical contexts where the cost of a
missed check is higher than the cost of denied access.

**Fail-open.** A failure mode in which an unavailable check allows the
operation. Used in non-critical contexts where availability matters more
than the security property.

**Fail-safe.** Sometimes used synonymously with fail-open; sometimes
distinguished from it by emphasizing that the failure mode is
deliberately chosen to be safe rather than restrictive. The whitepaper
uses fail-safe and fail-open interchangeably, with fail-closed as the
antonym.

**FFI.** Foreign Function Interface. The mechanism by which a high-level
language calls into a lower-level language's compiled code. The
hidden-boundary version of what `[object]` makes explicit in Eagle.

**Harpy.** Eagle's signed-source trust chain. Signs `.eagle` script files
with detached `.harpy` signatures. Verified by the Harpy plugin at script
load time.

**Hook procedure.** An extension point implemented as a named procedure
whose existence is checked at the call site. Eagle's convention is
`<type>_hook` for hooks of a given type. See §5.4.

**Interpreter.** In Eagle, the runtime state that owns a set of commands,
variables, namespaces, and policy. `Interpreter.GetActive()` returns the
current interpreter from C# code. A script can create child interpreters
via `[interp create]`.

**Key ring.** A collection of trusted public keys that Harpy verifies
against. A deployment configures which key rings are active; the
configuration determines which scripts are accepted.

**LSP.** Language Server Protocol. The standardized interface between
editors and language servers. The Eagle LSP is a community implementation
that provides completion, hover documentation, and basic navigation.

**Marshalling.** The conversion of values across a language boundary —
in Eagle's case, between Tcl's everything-is-a-string substrate and
.NET's typed object model. Marshalling has a cost that is proportional
to the number of boundary crossings.

**Override variable.** A script-level configuration mechanism. The
`::no(...)` flags are the most common form. A script that checks
`[info exists ::no(someFeature)]` is consulting an override variable.
See §5.1.

**Plugin.** In Eagle, a .NET assembly loaded into the interpreter that
adds commands, primitives, or services. Harpy is a plugin. Zeus is a
plugin. The plugin system is the primitive layer's extension mechanism.

**Policy code.** Code that says what to do, when, with which primitives.
Per Ousterhout's dichotomy and §1.2.

**Primitive.** Code whose correctness has to hold under every
circumstance the program could put it in. Per Ousterhout's dichotomy
and §1.2.

**Runtime option.** Interpreter-level configuration queried by
`[hasRuntimeOption ...]`. Distinct from override variables (script
level) and environment variables (process level). See §5.1.

**Sandboxing.** Restricting a child interpreter's command set, file
system access, and network capability. In Eagle, achieved with
`[interp create -safe]` or by setting security flags on an existing
child interpreter.

**Save/restore pair.** A procedure pair that snapshots and restores
some piece of global state, allowing a temporary mutation to be
reverted. The script-layer equivalent of RAII. See §5.5.

**Scripting language.** In Ousterhout's sense: a language optimized for
composition and policy expression, with runtime malleability, late
binding, and a small kernel. The narrowed sense the whitepaper uses
throughout.

**Sentinel value.** A specific constant used as a marker — for example,
the `4.0.30319.0` version used by `[isNetFx40]` as the lower bound for
the .NET Framework 4.x CLR family.

**Strong name.** In .NET, a cryptographic identifier for an assembly,
combining the assembly's name, version, culture, and public key.
Stronger than file-path identification; weaker than Authenticode for
trust purposes.

**Systems language.** In Ousterhout's sense: a language optimized for
primitive construction, with strong typing, ahead-of-time compilation,
and rich tooling. The contrast term to scripting language.

**Tcl.** Tool Command Language. The scripting language whose semantics
Eagle inherits, originally developed by John Ousterhout at Berkeley and
later at Sun Microsystems.

**Trust chain.** The end-to-end sequence of cryptographic verifications
that establishes a script's authenticity. In Eagle's case: authoring,
signing, distribution, verification, execution. The Harpy chain.

**`# <help>` block.** An XML-shaped comment block embedded in a proc
body that documents the procedure's contract. Parsed at runtime by the
Eagle `HelpOps` component; queried by the interactive `#help <proc>`
command. See Appendix C.

### Appendix C — Eagle proc anatomy reference

An Eagle procedure that follows the conventions defended in this
whitepaper has a specific anatomy. This appendix documents the format by
example and lists the rules that the example illustrates.

**Worked example.** A procedure from the `list.eagle` library:

```tcl
proc lshuffle { list } {
  # <help>
  # This procedure returns a new list whose elements are a uniformly
  # random permutation of the input list.  It is the script-layer
  # equivalent of the in-place shuffle algorithms used in many
  # languages, but applied to a private copy so that the caller's
  # list is unchanged.
  #
  # How it works: it copies the input list, then walks the copy from
  # the last element toward the first, performing a Fisher-Yates
  # shuffle.  At each step it picks a random index in the unshuffled
  # prefix, swaps the chosen element into the current position, and
  # decrements the loop variable to shrink the unshuffled prefix.
  # The randomness source is the rand() expression function.
  #
  # Tricky details: the swap is performed across two clauses of the
  # for loop's body, which is non-obvious on first reading.  The
  # element at the chosen index is saved, the element at the end of
  # the unshuffled prefix is moved into the chosen position, and
  # then the saved element is placed at the end of the prefix.  The
  # decrement of length happens inside the lindex expression.
  #
  # Arguments:
  #   list -- The list to shuffle.  The original list is not
  #           modified.
  #
  # Results:
  #   A new list containing the same elements as the input, in
  #   randomized order.
  # </help>

  set result $list
  set length [llength $result]

  for {} {$length > 0} {} {
    set index [expr {int(rand() * $length)}]
    set element [lindex $result [incr length -1]]
    lset result $length [lindex $result $index]
    lset result $index $element
  }

  return $result
}
```

**Anatomy.**

*Proc declaration.* The `proc` keyword, the proc name, the parameter
list in braces, and the body in braces. The body is brace-quoted — its
bytes are verbatim. See §4.3 on why the brace-quoting is a contract.

*Help block.* The `# <help>` and `# </help>` markers bracket the
documentation. The block must appear as the first element of the proc
body for the `HelpOps` parser to find it. Indentation must match the
body's indentation.

*Sections within the help block.* The whitepaper uses a five-section
convention that has proven robust across the audit work:

1. **Summary paragraph.** What the procedure does and why it exists. One
   to three sentences. Sets the context.
2. **How it works.** The implementation walkthrough. Describes the
   algorithm, the key API calls, and any noteworthy control flow. Not a
   blow-by-blow paraphrase of the code; the reader has the code. A
   paragraph or two, sized to the procedure's complexity.
3. **Tricky details (optional).** Anything that surprises careful
   readers. Hidden invariants, subtle semantics, security implications,
   workarounds for specific bugs. Skipped for procedures that are
   straightforward.
4. **Arguments.** One line per argument, with a brief description. For
   complex arguments, the description may extend to a short paragraph.
5. **Results.** What the procedure returns and what side effects it
   has. "Returns the empty string" is appropriate for procedures whose
   main purpose is side effects.

*Body.* The procedure's actual implementation. Eagle scripts
conventionally use two-space indentation; the help block matches.

**Rules that the example illustrates.**

- **No literal braces in help text.** A literal open or close brace in
  the help block would unbalance the brace-quoted body and break
  parsing. Describe braces in prose ("open brace") or in escaped form.
  The Fisher-Yates description in `[lshuffle]` describes a swap "across
  two clauses" rather than reproducing literal braces.
- **Code spans in prose.** Mentions of language commands use
  bracket-quoted code spans: `[set]`, `[info exists]`, `[catch]`. This
  is the same convention used in the surrounding docs repo.
- **The `# NOTE:` / `# HACK:` / `# TODO:` / `# BUGFIX:` taxonomy.** Used
  in the procedure body for rationale that lives next to the code.
  Distinct from `# <help>` blocks, which document the contract for
  callers. See §5.7.
- **Override checks at the top.** Procedures that respect override
  variables typically check them as the first executable statement. See
  §5.1 for the convention.
- **Defensive guards.** `[info exists]` before reading a global;
  `[catch]` around fallible operations; `try`/`finally` around resource
  acquisition. See §5.2.
- **Sensitive data hygiene.** Procedures that handle key material end
  with `unset -nocomplain -maybezerostring -purge` and a
  `[debug collect]`. See §5.3.

**The brace-quoting contract.** The body's bytes are signed, parsed,
and introspected verbatim. Any tool that modifies an Eagle script file
must:

- Preserve the line endings of the original (CRLF in the Eagle
  ecosystem; see §6.5).
- Preserve the exact byte sequence inside brace-quoted bodies (no
  whitespace normalization, no quote-style changes, no comment
  reformatting).
- Update detached signatures after modification, or accept that the
  signature has been invalidated and re-sign before deployment.

Tools written outside the Eagle ecosystem are the most common source of
signature invalidation. Python helpers using `Path.write_text()` and
similar functions silently normalize line endings on macOS and Linux;
they must be hardened to read in binary, restore the detected EOL, and
write in binary.

### Appendix D — The C# layer conventions

The Eagle primitive layer is written in C# under a set of conventions
that are unusual for the .NET ecosystem. This appendix documents them
as reference material for developers extending the primitive layer.

**Namespace pattern.** Eagle uses a namespace prefix convention to mark
the public/internal boundary that C# does not natively express at the
namespace level. The pattern:

- `Eagle._Components.Public.X` — types intended for use by scripts and
  by external integrators. Stable API surface.
- `Eagle._Components.Private.X` — types that implement the runtime but
  are not stable API. May change without notice.
- `Eagle._Components.Internal.X` — types that exist for build-time or
  testing concerns. Not part of the runtime in production builds.

A `using Eagle._Components.Private.X` declaration is honest at the
import site: it documents that the file is reaching into internal
implementation. A reviewer can flag such imports for scrutiny. The
convention provides namespace-level visibility marking that C# itself
does not. See §6.9.

**Conditional compilation taxonomy.** Eagle uses build-time flags as a
first-class architectural mechanism. The flags include:

- `NATIVE` — gates code that calls native (non-CLR) libraries. A build
  without `NATIVE` cannot interoperate with native code at all.
- `HISTORY` — gates the script-level command history feature. A build
  without `HISTORY` has no `[history]` command and a smaller footprint.
- `DEBUGGER` — gates the script-level debugger. A build without
  `DEBUGGER` does not support breakpoints, single-stepping, or watch
  expressions.
- `DEBUGGER_BREAKPOINTS` — gates breakpoint support specifically, for
  builds that want the debugger framework but not the breakpoint
  mechanism.
- `SECURITY` — gates security-policy enforcement. A build without
  `SECURITY` cannot enforce safe-interpreter restrictions, so it is not
  appropriate for environments that run untrusted scripts.
- `EMIT` — gates the runtime code-generation features. A build without
  `EMIT` cannot use `[object emit]` and similar primitives.
- `THREADING` — gates the cross-thread interpreter primitives. A build
  without `THREADING` cannot create script-level threads.

Each flag is independent. Each flag has a meaningful "off" state in
which the corresponding feature is genuinely absent from the binary,
not merely disabled at runtime. The build matrix is the architecture;
see §6.4.

**Accessor pattern.** Internal helpers are exposed to script-side
introspection through a uniform pattern. The C# method is declared
with appropriate visibility for the assembly; script-side access
reaches it through `[object invoke]` with the `+NonPublic` flag if
needed:

```tcl
object invoke -flags +NonPublic \
    Eagle._Components.Private.ScriptOps HasFlags ...
```

The `+NonPublic` flag is additive — it adds non-public binding to the
default public binding. The class containing the method must be
reachable through some `using` declaration or fully-qualified type
name; the flag does not bypass type accessibility, only member
accessibility.

**Strong-name integration.** Every Eagle assembly is strong-named. The
strong-name signature is verified by the CLR at load time; tampering
with the assembly between build and load is detected. Strong names
are the .NET equivalent of Authenticode for assembly-level identity,
weaker than Authenticode for trust but cheaper to verify.

**Authenticode integration.** Production builds of Eagle assemblies are
Authenticode-signed in addition to being strong-named. The Authenticode
signature binds a vendor identity (typically the build's signing
authority) to the binary. Deployments can configure the CLR to require
Authenticode verification for assemblies loaded from outside the
canonical bin directory.

**File organization.** Within an Eagle source tree, files are organized
by component. The `Library/Components/Private/X.cs` pattern is
canonical. Subdirectories under `Library/Components/` correspond to the
namespace hierarchy.

**Test conventions.** All tests use the Eagle `[test1]` and `[test2]`
commands, either directly or indirectly via the `[test]` wrapper or via
the higher-level `[runTest]`, et al; see §3.4.

**Common idioms.**

- `Interpreter.GetActive()` resolves the current-thread interpreter.
  See §6.8 for the rationale.
- `MutableAnyPair<T1, T2>` and similar generic helpers wrap small
  tuples of CLR values for return across the script boundary.
- `Result` is the canonical return-value carrier used by the primitive
  layer; many methods take a `ref Result` parameter that the caller
  can inspect after the call. The `Result` class carries thirty-plus
  implicit conversion operators (from/to `string`, `int`, `long`,
  `double`, `decimal`, `DateTime`, `TimeSpan`, `Guid`, `Uri`, `byte[]`,
  `Version`, `Exception`, `StringList`, `BigInteger`, and more) so any
  .NET return value flows into the result pipeline without explicit
  conversion at the call site.
- `ReturnCode` enumerates the script-level return codes (Ok, Error,
  Break, Continue, Return, WhatIf) that primitive methods communicate
  to the script layer.

**Patterns worth knowing.**

- **Intentionally mutable static fields.** Many private static fields
  in the primitive layer are marked with a `purposely not read-only`
  comment. These are ambient configuration knobs — `HelpOps.
  DefaultShowTopics`, `ChannelOps.DefaultBufferSize`,
  `ScriptOps.SubCommandNoCase`, `StringOps.DefaultMatchMode` — that a
  test harness, host application, or interactive session can adjust
  without recompilation or method-signature changes. The pattern is
  the C# layer's expression of the §6.2 "mutation as a feature"
  argument.
- **Runtime immutability enforcement.** Rather than relying on C#'s
  compile-time `readonly` semantics, Eagle enforces immutability via a
  boolean flag (`immutable`) checked in every setter, with a
  `MakeImmutable()` method that flips the flag. Objects like
  `ParseState`, `ExpressionState`, `Token`, `BundleData`, and `Script`
  start mutable (populated during construction) and become immutable
  when cached. Compile-time `readonly` cannot express "mutable during
  construction, immutable after caching"; the runtime flag can.
- **Six-phase interpreter disposal.** `Interpreter.Dispose` executes
  six ordered phases: vwait/events/threads/child interpreters; bundle
  manager and plugins; database/objects/channels; events/scopes/
  aliases/procedures; plugin/command cleanup; final cleanup and
  threading resources. The phasing exists because plugins may hold
  references to interpreter resources, and disposing in the wrong
  order causes use-after-dispose exceptions in plugin cleanup code.
- **Trait-based host interface composition.** The `IHost` interface
  aggregates ten-plus smaller interfaces (`IColorHost`, `IBoxHost`,
  `IPositionHost`, `ISizeHost`, `IStreamHost`, `IDebugHost`,
  `IReadHost`, `IWriteHost`, and others) rather than using deep
  inheritance. The `HostFlags` enum (sixty-plus flags) provides
  runtime capability queries via `DoesSupport(HostFlags.Color)`. The
  pattern lets each host implement exactly the capabilities it
  supports — a console host needs color and positioning; a file host
  needs streams; a null host needs nothing.
- **Polymorphic variable storage backends.** The `IVariable` interface
  supports transparent delegation to external storage. Backends
  include `DatabaseVariable` (rows in SQL databases), `RegistryVariable`
  (Windows registry keys), `NetworkVariable` (HTTP-based remote
  storage), `ElementDictionary` (standard in-memory), `System.Array`
  (.NET arrays), plus thread, environment, and test backends. Script
  code like `[set myVar "hello"]` works identically regardless of
  where the variable lives; the variable trace system fires callbacks
  on read/write/unset to enable transparent persistence.
- **`ObjectId` GUID on every type.** Every class, interface, struct,
  enum, and delegate in the codebase carries an `[ObjectId("guid")]`
  attribute with a unique GUID. This enables type identification
  across `AppDomain` boundaries (where `typeof()` yields different
  objects in different domains), plugin versioning, and serialization
  identity. It also lets tooling track type additions, removals, and
  renames across releases.
- **`goto` state machine pattern.** Roughly 240 `goto` occurrences
  exist outside `[switch]` statements, primarily in
  `PrivateShellMainCore`, `ScriptOps`, and `InteractiveOps`. These
  methods are finite-state machines; the labeled-block representation
  makes the state topology visible in ways that nested loops with
  state variables would not.

These idioms are not strictly required for new primitives, but
following them keeps new code consistent with the existing surface.
The full catalog of intentional patterns is in `architecture_patterns.
md` in the Eagle docs repository.

### Appendix E — Bibliography and further reading

This appendix lists works that informed the whitepaper without being
directly cited, plus recommended further reading for readers who want
to dig deeper into the model, the case study, or the aesthetic
argument.

**Foundational scripting language history.**

- John K. Ousterhout, *Tcl and the Tk Toolkit*, 1st edition,
  Addison-Wesley, 1994. The Tcl reference manual for the era in which
  Ousterhout's dichotomy was being formulated.
- Brent B. Welch, Ken Jones, and Jeffrey Hobbs, *Practical Programming
  in Tcl and Tk*, 4th edition, Prentice Hall, 2003. The standard
  practitioner's reference, including detailed treatment of the
  brace-quoting and substitution rules that Eagle inherits.
- Roberto Ierusalimschy, *Programming in Lua*, Lua.org, 4th edition,
  2016. A clean treatment of the embedded-scripting use case from the
  perspective of a successful dual-language deployment.

**Language design.**

- Niklaus Wirth, "On the Design of Programming Languages," in
  *Information Processing 74*, North-Holland, 1974. The "make it
  simple" argument from one of its most consistent advocates.
- Edsger W. Dijkstra, *A Discipline of Programming*, Prentice-Hall,
  1976. The argument that programming is a mathematical discipline
  whose artifacts should be provable, not just runnable.
- Daniel P. Friedman and Matthias Felleisen, *The Little Schemer*, 4th
  edition, MIT Press, 1995. A book-length defense of expressiveness in
  small kernels.

**The dual-language model in other domains.**

- Brendan Gregg, *BPF Performance Tools: Linux System and Application
  Observability*, Addison-Wesley, 2019. The current standard reference
  for eBPF, including the dual-language structure (C-compiled BPF
  programs running over kernel primitives, accessed by user-space
  tools in Python or shell).
- Lin Clark, Till Schneidereit, and Luke Wagner's writings on
  WebAssembly as a sandbox boundary, mostly on Mozilla Hacks and the
  Bytecode Alliance blog. The most accessible treatment of the WASM
  trust model.
- Pulumi documentation on the rationale for using general-purpose
  languages for cloud configuration. A concrete example of the
  dual-language model in infrastructure-as-code.

**Supply-chain security.**

- Bruce Schneier, *Applied Cryptography*, 2nd edition, Wiley, 1996.
  The reference text for the cryptographic primitives that underlie
  the Harpy chain.
- Ross Anderson, *Security Engineering*, 3rd edition, Wiley, 2020.
  The textbook on security engineering, including extensive treatment
  of code-signing trust models.
- The CISA "Defending Against Software Supply Chain Attacks" series,
  2021–present. The most current operational guidance for the threat
  model that signed-source distributions defend against.

**Aesthetic theory in software.**

- Donald E. Knuth, *Selected Papers on Computer Science*, CSLI, 1996.
  The collected essays in which Knuth most explicitly defends the
  beauty-correctness correlation.
- Andy Oram and Greg Wilson, eds., *Beautiful Code*, O'Reilly, 2007.
  See Appendix A. Read the Brian Kernighan and Yukihiro Matsumoto
  chapters in particular; they apply variants of the §8 argument to
  specific languages.
- Richard P. Gabriel, *Patterns of Software*, Oxford University Press,
  1996. The "habitability" argument, which is the same beauty argument
  from an architectural-design angle.

**Tcl- and Eagle-specific.**

- The Eagle docs repository (`docs/`) — the canonical source for Eagle
  command behavior. Key files: `index.md` (overview), `core_language.md`
  (the full command catalog), `core_script_library.md` (script library
  procedures), `architecture_patterns.md` (Eagle's deliberate
  unorthodox patterns, with rationale), `safe.md` (the safe-interpreter
  security model in detail), `object.md` (deep-dive on the `[object]`
  command), `interp.md` (interpreter management and security),
  `info.md` (introspection), `why_eagle.md` (rationale and
  comparisons), `quick_start_guide.md` (practical orientation),
  `build_system.md` (the build matrix and `EagleBuildType` presets).
- The `EAGLE_COMMAND_REFERENCE.md` file in the Eagle source tree. The
  manifest of every documented command, used by the documentation
  tooling (`scan_commands.eagle`, `restyle.eagle`) to keep the docs in
  sync with the source.
- The companion paper *If You Want a Project to Be Good, You Have to
  Love Working on It* (`paper_love_and_software.md` in the same docs
  repository). Argues that the engineering characteristics this
  whitepaper documents emerge only under sustained intrinsic
  motivation. The architectural argument and the motivational argument
  describe the same phenomenon from different sides.

**Optional reading for context on the larger argument.**

- Frederick P. Brooks, Jr., *The Mythical Man-Month*, Anniversary
  edition, Addison-Wesley, 1995. For the "essential complexity"
  framing that the §6 divergences engage with.
- Butler W. Lampson, "Hints for Computer System Design," in
  *Operating Systems Review*, vol. 17, no. 5, October 1983, pp.
  33–48. For "get it right" and the general argument that simplicity
  is a design property to optimize for.
- Richard P. Gabriel, "The Rise of 'Worse is Better,'" in *AI Expert*,
  1991. The classic essay on why the simpler-but-less-correct
  solution often wins. The whitepaper's argument is in some sense an
  inversion: not "worse is better" but "smaller is right," which is a
  weaker claim that survives where the Gabriel argument does not.

