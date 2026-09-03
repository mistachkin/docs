# Eagle and Other Scripting Ecosystems

Eagle occupies an unusual place among scripting systems.  It combines a
Tcl-compatible command language, direct access to the Common Language Runtime
(CLR), a managed embedding API, safe interpreters, policy hooks, signed-script
workflows, native Tcl bridges, and a script-native test and build ecosystem.
No single comparison captures all of that.

This document compares Eagle with six practical alternatives:

- native Tcl;
- PowerShell;
- Python (specifically CPython);
- Lua;
- JavaScript on Node.js; and
- C# scripting with Roslyn.

The comparison is organized first by **task**, because choosing a scripting
system is normally a workload decision, and then by **ecosystem**, so that the
tradeoffs for each alternative are easy to find.  It is not a universal
ranking.  Each ecosystem has workloads where it is the better choice.

> **Version and evidence note:** This comparison was reviewed on
> September 3, 2026.  It uses current official documentation while avoiding
> dependence on short-lived patch-version details.  For production Node.js,
> “Node.js” means an Active LTS or Maintenance LTS release.  “Python” means
> CPython unless another implementation is named.  Eagle examples are marked
> as `tcl` because Tcl highlighting most closely matches Eagle syntax.

## Contents

- [Executive Decision Guide](#executive-decision-guide)
- [Scope and Comparison Method](#scope-and-comparison-method)
- [Capabilities at a Glance](#capabilities-at-a-glance)
- [Task 1: Embed a Scripting Engine](#task-1-embed-a-scripting-engine)
- [Task 2: Automate .NET Objects and Host APIs](#task-2-automate-net-objects-and-host-apis)
- [Task 3: Handle Events and Asynchronous I/O](#task-3-handle-events-and-asynchronous-io)
- [Task 4: Run Untrusted Code](#task-4-run-untrusted-code)
- [Task 5: Distribute Trusted Scripts and Packages](#task-5-distribute-trusted-scripts-and-packages)
- [Task 6: Automate Builds, Installers, and Operations](#task-6-automate-builds-installers-and-operations)
- [Task 7: Reuse Libraries and Packages](#task-7-reuse-libraries-and-packages)
- [Task 8: Test and Diagnose the System](#task-8-test-and-diagnose-the-system)
- [Task 9: Migrate or Interoperate](#task-9-migrate-or-interoperate)
- [Task 10: Balance Footprint, Throughput, and Deployment](#task-10-balance-footprint-throughput-and-deployment)
- [Ecosystem Profiles](#ecosystem-profiles)
  - [Eagle Profile](#eagle-profile)
  - [Native Tcl Profile](#native-tcl-profile)
  - [PowerShell Profile](#powershell-profile)
  - [Python Profile](#python-profile)
  - [Lua Profile](#lua-profile)
  - [Node.js Profile](#nodejs-profile)
  - [Roslyn C# Scripting Profile](#roslyn-c-scripting-profile)
- [Recommended Deployment Patterns](#recommended-deployment-patterns)
- [Security and Mission-Critical Checklist](#security-and-mission-critical-checklist)
- [Conclusions](#conclusions)
- [Official References](#official-references)

## Executive Decision Guide

Choose Eagle first when several of these are true:

- the application is written for .NET and needs an embedded, dynamic
  orchestration layer;
- scripts should manipulate CLR types and live host objects without a
  generated binding layer;
- CLR callbacks, delegates, and events must call back into script;
- the host needs interpreter-level policy, safe interpreters, resource
  controls, or signed scripts;
- existing Tcl skills or scripts should remain useful;
- native Tcl and CLR components must coexist during a migration; or
- the same scripting model should span an application, test harness, build,
  installer, PowerShell integration, and operational tooling.

Start with another ecosystem when the dominant requirement is:

| Dominant requirement | Usually start with | Why |
|----------------------|--------------------|-----|
| Existing Tcl C application or Tcl extension inventory | Native Tcl | It is the reference Tcl implementation and has the broadest direct compatibility with Tcl packages. |
| Interactive system administration and Microsoft service automation | PowerShell | Its object pipeline, cmdlet conventions, remoting, and administration modules are purpose-built for this work. |
| Data science, machine learning, scientific computing, or the widest general Python package selection | Python | CPython and PyPI dominate these domains. |
| The smallest conventional C embedding surface | Lua | Lua was designed as a compact C library with a small language and API. |
| Web servers, JavaScript applications, or npm-centered development | Node.js | Its event-driven runtime and JavaScript package ecosystem are the natural fit. |
| Full C# syntax, static typing, compiler analysis, or generated code that should behave like C# | Roslyn scripting | It exposes the C# compiler platform and preserves C# language semantics. |

Eagle is strongest where these categories overlap.  For example, a .NET
product that needs Tcl-like policy scripts, host-defined capabilities, CLR
callbacks, signed distribution, and native Tcl migration has a much stronger
case for Eagle than a standalone data-analysis script does.

## Scope and Comparison Method

### Baselines

The comparison uses the ordinary, documented baseline of each ecosystem:

| Ecosystem | Baseline used here |
|-----------|--------------------|
| Eagle | The Eagle core plus its documented first-party ecosystem, including enterprise components where they are explicitly identified. |
| Native Tcl | The Tcl core, standard library, Safe Tcl, and the public C API. |
| PowerShell | PowerShell and the `System.Management.Automation` hosting API. |
| Python | CPython, its standard library, and the normal Python packaging ecosystem.  Python.NET and IronPython are separate integration choices, not assumed CPython features. |
| Lua | The Lua language, standard libraries, and C API.  LuaRocks is identified as ecosystem tooling rather than part of the language core. |
| Node.js | Node.js, its standard modules, Node-API, and npm. |
| Roslyn | `Microsoft.CodeAnalysis.CSharp.Scripting` and the surrounding .NET/NuGet ecosystem. |

Third-party libraries can change almost every row in a comparison table.
Where an important capability normally comes from a bridge, framework,
container, or package rather than the baseline runtime, this document says so.

### Terms

- **Built in** means the documented language or runtime directly supplies the
  capability.
- **First-party integration** means the capability is maintained as part of
  the same project ecosystem, even when shipped separately.
- **Host-defined** means an embedding application must design and enforce the
  relevant API or policy.
- **External isolation** means the actual boundary is an operating-system
  process, account, container, virtual machine, or similarly independent
  mechanism.

“Can evaluate code in another namespace” does not mean “can safely evaluate
hostile code.”  That distinction is central to
[Task 4](#task-4-run-untrusted-code).

### What this document does not claim

This is not a benchmark, a package-count contest, or proof that a feature is
globally unique.  Performance depends on the host, runtime, build options,
script shape, I/O pattern, and warm-up strategy.  Security depends on the
complete deployment, not merely the evaluator API.  Benchmark and threat-model
the exact production workload.

For Eagle's internally distinctive mechanisms, see
[What Is Innovative About Eagle?](innovation.md).  For the shorter adoption
case, see [Why Eagle?](why_eagle.md).

## Capabilities at a Glance

The cells below describe the normal architectural fit, not every result that
can be achieved with custom engineering.

| Ecosystem | Natural embedding host | CLR access | In-process untrusted-code model | Event and async model | Broadest library advantage |
|-----------|------------------------|------------|---------------------------------|-----------------------|---------------------------|
| Eagle | .NET | Built in and bidirectional | Safe interpreters, policy, limits, and capability aliases; external isolation still recommended for hostile workloads | Tcl-style event loop, channel events, callbacks, and CLR delegates | CLR libraries plus Eagle packages and optional native Tcl bridges |
| Native Tcl | C/C++ | Requires an extension or a bridge | Safe interpreters, aliases, and command/time limits | Mature notifier, channels, `fileevent`, and callbacks | Tcl packages and native extensions |
| PowerShell | .NET/runspaces | Built in and object-oriented | Constrained endpoints and language modes require correct system policy; execution policy alone is not a boundary | Pipeline jobs, events, runspaces, and .NET async APIs | Administration modules and Microsoft service integrations |
| Python | C/C++ | External bridge or a different Python implementation | No supported general-purpose in-process sandbox for `eval` or `exec` | `asyncio`, threads, processes, and extensive frameworks | PyPI, especially data, science, automation, and web software |
| Lua | C/C++ | Host binding required | Host-selected libraries/environments and custom limits; no turnkey core safe interpreter | Coroutines; an I/O event loop normally comes from the host or a library | Compact embeddable modules and application/game integrations |
| Node.js | C++ or a separate process | Addon, bridge, or process boundary required | `node:vm` is explicitly not a security mechanism | EventEmitter, promises, streams, workers, and libuv | npm and the web/JavaScript ecosystem |
| Roslyn C# scripting | .NET | Native C# access | Script code has process permissions; an assembly load context is not a sandbox | Tasks, async/await, events, and the full .NET library | NuGet and statically typed .NET APIs |

### A useful shorthand

| If the script is primarily... | Strongest default candidates |
|-------------------------------|------------------------------|
| A policy and orchestration layer inside a .NET product | Eagle or Roslyn |
| An administrator's interactive object pipeline | PowerShell |
| A portable Tcl program | Native Tcl or Eagle, after compatibility testing |
| A data or scientific program | Python |
| A compact extension language inside a native program | Lua or Tcl |
| An asynchronous JavaScript service | Node.js |
| Dynamically submitted but otherwise ordinary C# | Roslyn |
| Hostile tenant code | None by itself; combine the selected language controls with external isolation |

## Task 1: Embed a Scripting Engine

The first design question is not “Which syntax is shortest?”  It is “Which
runtime boundary does the host want to own?”

### Eagle in a .NET host

Eagle's public API uses `Interpreter`, `ReturnCode`, and `Result`
throughout.  Ordinary evaluation failures are returned as structured status
rather than requiring the host to treat every script error as a CLR exception.

```csharp
using System;
using Eagle._Components.Public;

Result result = null;

using (Interpreter interpreter = Interpreter.Create(ref result))
{
    if (interpreter == null)
        throw new InvalidOperationException(result.ToString());

    ReturnCode code = interpreter.EvaluateScript(
        "expr {6 * 7}", ref result);

    if (code != ReturnCode.Ok)
        throw new InvalidOperationException(result.ToString());

    Console.WriteLine(result); // 42
}
```

The long-lived interpreter can then receive variables, custom commands,
functions, plugins, policies, and live CLR objects.  See
[Embedding Eagle in a C# Application](embedding.md).

### Native Tcl in a C host

Native Tcl has a mature C API and is a natural fit for an existing C or C++
application:

```c
#include <stdio.h>
#include <tcl.h>

int main(int argc, char **argv)
{
    Tcl_FindExecutable(argv[0]);

    Tcl_Interp *interp = Tcl_CreateInterp();
    int code = Tcl_Eval(interp, "expr {6 * 7}");

    fprintf(code == TCL_OK ? stdout : stderr, "%s\n",
        Tcl_GetStringResult(interp));

    Tcl_DeleteInterp(interp);
    Tcl_Finalize();

    return code == TCL_OK ? 0 : 1;
}
```

Production code must initialize Tcl as appropriate and preserve error details,
but the lifecycle is intentionally direct.

### CPython in a C host

CPython is also embeddable, although exchanging rich application values
requires the lower-level Python/C object and reference-counting APIs:

```c
#include <Python.h>

int main(void)
{
    Py_Initialize();
    int code = PyRun_SimpleString("print(6 * 7)");

    if (Py_FinalizeEx() < 0)
        return 120;

    return code == 0 ? 0 : 1;
}
```

The current CPython documentation recommends its configuration APIs for
nontrivial hosts.  The abbreviated example shows only the boundary shape.

### Lua in a C host

Lua's small, stack-oriented C API is one of its defining strengths:

```c
#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>

int main(void)
{
    lua_State *state = luaL_newstate();

    if (state == NULL)
        return 1;

    int code = luaL_dostring(state, "return 6 * 7");

    if (code == LUA_OK)
        printf("%lld\n", (long long)lua_tointeger(state, -1));
    else
        fprintf(stderr, "%s\n", lua_tostring(state, -1));

    lua_close(state);

    return code == LUA_OK ? 0 : 1;
}
```

The host decides which standard libraries to open and which C functions to
register.  That explicitness is valuable for small native applications.

### PowerShell in a .NET host

PowerShell is hosted through a runspace and
`System.Management.Automation.PowerShell`:

```csharp
using System;
using System.Management.Automation;

using (PowerShell shell = PowerShell.Create())
{
    shell.AddScript("6 * 7");

    foreach (PSObject value in shell.Invoke())
        Console.WriteLine(value);
}
```

A default runspace exposes core PowerShell commands.  A host that wants a
smaller command surface constructs an `InitialSessionState` and a custom
runspace.  This is powerful for administrative pipelines, but it is a larger
semantic surface than a minimal application-specific interpreter.

### Roslyn C# scripting in a .NET host

Roslyn evaluates C# and can strongly type the result:

```csharp
using Microsoft.CodeAnalysis.CSharp.Scripting;

int answer = await CSharpScript.EvaluateAsync<int>("6 * 7");
Console.WriteLine(answer);
```

Roslyn also supports typed global objects, imports, assembly references,
reusable compiled scripts, delegates, stateful submissions, and compiler
analysis.  It is the obvious choice when “the script language should be C#” is
the controlling requirement.

### Node.js as an embedded runtime

Node.js has an [official C++ embedder API](https://nodejs.org/api/embedding.html).
It requires management of V8,
per-process Node state, an isolate, a context, and a libuv event loop.  Its
documentation also warns that embedder API breaking changes may occur on each
semantic-version major release.  This can be the right boundary for a C++
product that specifically needs a Node environment, but it is not a
CLR-native analogue of Eagle's managed hosting API.

### Task 1 conclusion

- In a .NET application, Eagle offers the smallest coherent path from
  interpreter creation to dynamic Tcl-style orchestration and host extension.
- Roslyn offers the highest C# fidelity and compiler intelligence.
- PowerShell offers the richest ready-made administrative command surface.
- In a native C/C++ application, Lua and Tcl normally offer the most direct
  conventional embedding boundaries.
- Choose CPython or Node.js embedding when their library/runtime ecosystem is
  important enough to justify the corresponding native integration surface.

## Task 2: Automate .NET Objects and Host APIs

Calling one static .NET method looks simple in all three CLR-centered
ecosystems:

### Eagle

```tcl
set path [object invoke System.IO.Path Combine $root report.json]
set text [object invoke System.IO.File ReadAllText $path]
```

### PowerShell

```powershell
$path = [System.IO.Path]::Combine($root, 'report.json')
$text = [System.IO.File]::ReadAllText($path)
```

### Roslyn C# scripting

```csharp
string path = System.IO.Path.Combine(root, "report.json");
string text = System.IO.File.ReadAllText(path);
```

The difference appears at the application boundary.

### Eagle's boundary

Eagle's `[object]` subsystem provides:

- opaque handles for live CLR objects;
- constructor, method, property, field, and event access;
- overload selection and argument conversion;
- optional, `params`, and by-reference argument handling;
- aliases that make an object or method look like a script command;
- configurable object ownership, reference counting, and disposal;
- generated delegates for script callbacks; and
- policy and trust checks at the boundary.

A managed object can call back into script through an ordinary event:

```tcl
proc clicked {} {
    puts "button clicked"
}

# The host supplied a live button object as $button.
object invoke $button add_Click {clicked}
```

See the [`[object]` architecture](object.md) for the marshalling and lifetime
model.

### Where PowerShell is stronger

PowerShell wraps command output in an object pipeline, has discoverable cmdlet
metadata, and has a very large inventory of administration modules.  It is
usually better when the human-facing command pipeline and remote
administration model are primary.

### Where Roslyn is stronger

Roslyn preserves C# overload resolution, generics, LINQ, static typing,
compiler diagnostics, and access to the syntax and semantic models.  It is
usually better when scripts are expected to resemble application source and
the host accepts compilation cost and full-code authority.

### Where the other baselines differ

CPython, Lua, Node.js, and native Tcl all have excellent foreign-function or
extension stories in their natural host environments.  Direct CLR object
automation is not part of their baseline runtimes.  It requires a bridge,
generated/manual bindings, an addon, a separate language implementation, or a
process protocol.  Those may be good solutions, but their compatibility and
security properties belong to the selected bridge.

### Task 2 conclusion

For a dynamic, host-governed .NET extension language, Eagle's bidirectional
boundary is its clearest advantage.  For an administrative object shell,
choose PowerShell.  For dynamically compiled C# with full language fidelity,
choose Roslyn.

## Task 3: Handle Events and Asynchronous I/O

Asynchronous design includes at least four separate concerns:

1. detecting readiness or completion;
2. scheduling the continuation;
3. preserving interpreter or request ownership;
4. making timeout, cancellation, error, and cleanup paths single-shot.

Syntax alone does not guarantee any of them.

### Eagle and native Tcl channel events

Eagle and native Tcl share the notifier-oriented `[fileevent]` model.  The
following client clears one-shot handlers before acting, checks asynchronous
connect status, sets an explicit deadline, and centralizes cleanup:

```tcl
proc finish {channel outcome} {
    if {$::done} {
        return
    }

    set ::done true
    set ::outcome $outcome

    after cancel $::timer
    catch {fileevent $channel readable {}}
    catch {fileevent $channel writable {}}
    catch {close $channel}
}

proc connected {channel} {
    fileevent $channel writable {}

    set error [fconfigure $channel -error]
    if {$error ne ""} {
        finish $channel [list error $error]
        return
    }

    if {[catch {
        fconfigure $channel -blocking false -translation crlf
        puts $channel "GET / HTTP/1.1"
        puts $channel "Host: example.com"
        puts $channel "Connection: close"
        puts $channel ""
        flush $channel

        fileevent $channel readable [list receive $channel]
    } error]} {
        finish $channel [list error $error]
    }
}

proc receive {channel} {
    if {[catch {read $channel} chunk]} {
        finish $channel [list error $chunk]
        return
    }

    append ::response $chunk

    if {[eof $channel]} {
        finish $channel ok
    }
}

set ::done false
set ::response ""
set channel [socket -async example.com 80]
set ::timer [after 10000 [list finish $channel timeout]]

fileevent $channel writable [list connected $channel]
vwait ::done
```

This illustrates the model; production clients should also define protocol
limits, validate responses, and test close/error races.  Eagle additionally
supports selecting event-manager priority when registering a file event.  See
the [core `[fileevent]` examples](core_examples.md#ex-fileevent).
Tcl 9 also documents `[chan event]` as the modern spelling for the same
readable/writable event facility.

The model is compact and works well for event-driven channel programs.
However, it is callback-based, not structured concurrency.  The application
must retain a clear ownership and completion protocol.

### Python `asyncio`

Python's standard [`asyncio` library](https://docs.python.org/3/library/asyncio.html)
supplies coroutines, tasks, streams, synchronization primitives, and
event-loop APIs:

```python
import asyncio

async def fetch(host):
    reader, writer = await asyncio.wait_for(
        asyncio.open_connection(host, 80),
        timeout=10,
    )

    writer.write(
        f"GET / HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n"
        .encode("ascii")
    )
    await writer.drain()

    data = await reader.read()
    writer.close()
    await writer.wait_closed()
    return data

response = asyncio.run(fetch("example.com"))
```

This style makes sequential asynchronous logic easy to read.  Python also has
many higher-level networking frameworks.  Integrating the event loop into a
foreign GUI or application host still needs deliberate lifecycle design.

### Node.js

Node.js is asynchronous and event-driven at its center:

```javascript
import net from 'node:net';

const socket = net.createConnection({ host: 'example.com', port: 80 });
const chunks = [];

socket.setTimeout(10_000);

socket.once('connect', () => {
  socket.write(
    'GET / HTTP/1.1\r\n' +
    'Host: example.com\r\n' +
    'Connection: close\r\n\r\n'
  );
});

socket.on('data', chunk => chunks.push(chunk));
socket.once('timeout', () => socket.destroy(new Error('timeout')));
socket.once('error', error => console.error(error));
socket.once('close', () => console.log(Buffer.concat(chunks).length));
```

Node's streams, promises, workers, and enormous network ecosystem make it a
strong default for JavaScript services.  EventEmitter listeners themselves
are invoked synchronously when an event is emitted; asynchronous work started
by a listener follows the relevant promise or callback rules.

### Roslyn and ordinary C#

Roslyn scripts can use the same task and cancellation APIs as compiled C#:

```csharp
using System;
using System.Net.Sockets;
using System.Threading;

using var client = new TcpClient();
using var cancellation = new CancellationTokenSource(
    TimeSpan.FromSeconds(10));

await client.ConnectAsync(
    "example.com", 80, cancellation.Token);
```

This is the strongest option when the desired abstraction is exactly modern
.NET async/await and the script is trusted to use the full framework.

### PowerShell and Lua

PowerShell can subscribe to CLR events with `Register-ObjectEvent`, use jobs
and runspaces, and call .NET asynchronous APIs.  It is effective for
occasional administrative events:

```powershell
$timer = [System.Timers.Timer]::new(250)
$job = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
    Write-Output 'timer fired'
}

$timer.Start()
```

For high-volume protocol code, a dedicated .NET library or another
event-centered runtime is normally easier to reason about.

Lua provides first-class coroutines, but the core does not prescribe a network
event loop.  The host or a library supplies readiness, timers, and scheduling,
which is either useful flexibility or extra integration work depending on the
application.

### Task 3 conclusion

- Choose Node.js for a JavaScript-first event-driven service.
- Choose Python when `asyncio` and Python's network ecosystem fit the
  application.
- Choose Roslyn when ordinary .NET async/await is the desired script model.
- Choose Eagle or native Tcl when a compact notifier/channel model and
  script-level callbacks fit the host.  In a .NET host, Eagle adds direct CLR
  event and delegate integration.
- Regardless of language, test timeout, cancellation, close, partial-read,
  partial-write, callback reentry, and exactly-once completion paths.

## Task 4: Run Untrusted Code

This is the comparison where imprecise language is most dangerous.

### Eagle

Eagle safe interpreters start with unsafe commands and options unavailable.
The parent may grant a narrowly checked operation through an alias:

```tcl
proc checkedAdd {left right} {
    if {![string is integer -strict $left] ||
        ![string is integer -strict $right]} {
        error "integer operands required"
    }

    return [expr {$left + $right}]
}

set child [interp create -safe]
interp alias $child add {} checkedAdd
interp recursionlimit $child 50
interp timeout $child 5000
interp watchdog $child true

set result [interp eval $child {add 20 22}]
interp delete $child
```

Eagle layers command hiding, unsafe-option rejection, subcommand allow-lists,
policy callbacks, capability aliases, recursion/time controls, and broader
resource accounting.  Enterprise components can add locked policy rules and
signed-script workflows.  See [Eagle Safe Interpreters](safe.md).

These controls reduce authority inside the interpreter.  They do not make the
CLR process mathematically immune to denial of service, runtime
vulnerabilities, unsafe host commands, or mistakes in a granted capability.
For mutually hostile tenants or high-impact workloads, also use external
isolation and operating-system resource limits.

### Native Tcl

Safe Tcl is a mature capability-oriented design.  Unsafe commands are hidden,
aliases mediate selected operations, and the parent can set command and time
limits:

```tcl
set child [interp create -safe]
interp alias $child add {} checkedAdd

interp limit $child command -value 1000
interp limit $child time -milliseconds 500

set result [interp eval $child {add 20 22}]
interp delete $child
```

The [official Safe Tcl manual](https://www.tcl-lang.org/man/tcl9.0/TclCmd/safe.html)
explicitly says that it does not attempt to
completely prevent annoyance and denial-of-service attacks.  Its virtualized
package access and aliases are valuable, but a high-assurance deployment still
needs careful extension review and external controls.

### PowerShell

PowerShell has `FullLanguage`, `RestrictedLanguage`,
`ConstrainedLanguage`, and `NoLanguage` modes.  Constrained Language is a
real security component when enforced with supported system application
control; the official documentation warns that merely setting the language
mode for experimentation is not sufficient.  Just Enough Administration
(JEA) endpoints can expose a defined set of commands.

PowerShell execution policy is not a sandbox.  Microsoft
[describes it](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
as a safety feature rather than a security system, and it can be bypassed by
a user who already has authority to enter commands.

### Python

[CPython's documentation](https://docs.python.org/3/library/functions.html#exec)
warns that `eval` and `exec` execute arbitrary code and that untrusted
input creates vulnerabilities.  Replacing or restricting
`__builtins__` is also explicitly not a security mechanism.  Use a separate
process, account, container, virtual machine, or a deliberately restricted
language instead of inventing an in-process Python sandbox.

### Lua

A Lua host can open only selected libraries, supply a controlled environment,
register capability functions, set allocator limits, and use hooks to meter
execution.  This makes Lua a good foundation for a host-designed restricted
language.  It is not a turnkey safe-interpreter contract: the host must audit
every exposed C function and library.  The Lua manual specifically warns that
the debug library can compromise otherwise secure code.

### Node.js

The [Node.js documentation](https://nodejs.org/api/vm.html) is unambiguous:
`node:vm` is not a security
mechanism and must not be used to run untrusted code.  Context separation is
useful for names and globals, not as a hostile-code boundary.  Use external
isolation or a purpose-built sandbox service with its own threat model.
The current
[Node.js Permission Model](https://nodejs.org/api/permissions.html) can reduce
the resources available to trusted code, but its own documentation describes
it as a seat belt and says that malicious code can bypass it.

### Roslyn

Roslyn scripts compile and execute C# with the permissions of the host
process.  Restricting references or imports may improve the application API,
but it is not a security boundary against hostile C#.  Likewise,
`AssemblyLoadContext` provides loading/version isolation, not security; the
[.NET documentation](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.loader.assemblyloadcontext)
states that loaded code has the process's permissions.

### Task 4 conclusion

| Requirement | Appropriate starting point |
|-------------|----------------------------|
| In-process, capability-oriented Tcl-family sandbox | Eagle or native Tcl |
| Locked-down administrative endpoint | PowerShell with JEA and supported system application control |
| Host-designed restricted language in a small native runtime | Lua, with a complete host audit |
| Hostile Python, JavaScript, or C# | External isolation; their ordinary evaluation APIs are not sandboxes |
| High-assurance hostile Eagle or Tcl workload | Safe interpreter **and** external isolation, resource quotas, narrow capabilities, and independent review |

## Task 5: Distribute Trusted Scripts and Packages

Confinement and authenticity answer different questions:

- a sandbox asks, “What may this code do?”
- a signature asks, “Which key approved these bytes, and are they unchanged?”
- package resolution asks, “Which artifact will actually be loaded?”

A secure deployment often needs all three.

| Ecosystem | Normal trust mechanism | Important boundary |
|-----------|------------------------|--------------------|
| Eagle | Script signatures, key rings, policy checks, trusted evaluation, package/plugin verification, signed SQLite bundles, and enterprise rule sets | The strongest workflows span evaluation and distribution, but key custody and package resolution still require operational controls. |
| Native Tcl | Host/package policy, safe interpreters, extension review, and deployment-layer signing | Tcl's package mechanism does not by itself establish the signer of every sourced script. |
| PowerShell | Authenticode-signed scripts and modules, execution policies, application control, and repository policy | Execution policy alone is not a security boundary; signer trust and endpoint capability must be configured separately. |
| Python | Package indexes, hashes/lock data, attestations, environment isolation, and deployment policy | `exec` does not authenticate code.  Package trust belongs to the selected packaging and deployment workflow. |
| Lua | Host-controlled resources plus project-specific package/signature tooling | Signing is not a core language service. |
| Node.js | Registry policy, lockfiles/integrity data, provenance/signing tooling, and deployment controls | Module integrity is not the same as safely executing a hostile package. |
| Roslyn/.NET | NuGet signing and repository policy, assembly/deployment controls, and host authorization | The scripting API itself evaluates submitted C#; it does not establish publisher trust or confinement. |

Eagle's distinctive advantage is architectural continuity: the interpreter,
package loader, policy system, enterprise signing tools, bundles, installer,
and updater can participate in one trust story.  That is especially useful
for products that distribute policy or extension scripts to managed
installations.

Its disadvantage is ecosystem scale.  Most public packages in PyPI, npm, and
NuGet were not authored for Eagle's signed-script workflow.  Calling a large
external library expands the supply-chain review to that library and its
dependencies.

For Eagle details, see [Harpy](harpy.md), [package loading](package.md),
[plugin loading](load.md), and the [updater](updater.md).

## Task 6: Automate Builds, Installers, and Operations

### Eagle

Eagle's first-party integrations reuse the same interpreter model in:

- MSBuild tasks;
- WiX custom actions;
- PowerShell cmdlets;
- managed and native shells;
- application hosts and services;
- package/update tooling; and
- the Eagle test harness.

This is valuable when one product wants the same Tcl-compatible procedures,
policy concepts, and CLR bridge across development, installation, runtime, and
support.  See [Eagle Integration Sub-Projects](integrations.md).

### Native Tcl

Tcl remains a strong portable glue language and is especially natural in
systems that already embed Tcl or depend on Tcl/Tk.  Its C API and mature
channel/event model are advantages.  Direct participation in managed build
objects or installer APIs requires a bridge or external process.

### PowerShell

PowerShell is normally the best first choice for:

- interactive Windows administration;
- Microsoft service and cloud administration;
- object-pipeline composition;
- remoting and constrained administrative endpoints; and
- tasks already exposed as cmdlets.

Eagle can be hosted inside PowerShell, but that does not make Eagle a
replacement for PowerShell's module inventory.

### Python

Python is a strong general automation language with excellent libraries for
file formats, web APIs, cloud systems, testing, and data processing.  It is
often the best standalone automation choice when CLR embedding and Tcl
compatibility are not requirements.

### Lua

Lua is better suited to extending the application being automated than to
being a universal administration shell.  It works well when the product
already owns the native host and wants a compact, application-specific
command surface.

### Node.js

Node.js is a natural fit for front-end build chains, JavaScript/TypeScript
tooling, web services, and JSON-heavy automation.  It is less natural as an
in-process policy engine inside a conventional .NET desktop or server product.

### Roslyn

Roslyn is useful when build rules or extensions benefit from C# types,
generics, analyzers, and compiler services.  Compared with Eagle, those scripts
are more verbose for string/list-oriented orchestration and are not naturally
confined as safe child interpreters.

### Task 6 conclusion

Use the ecosystem that already owns the automation objects.  Eagle's special
case is a .NET product that wants a small, composable scripting language to
remain consistent across multiple lifecycle stages.

## Task 7: Reuse Libraries and Packages

Every ecosystem can load reusable code; the practical difference is what code
already exists and how it crosses the host boundary.

### Typical package operations

Eagle and Tcl use the familiar package protocol:

```tcl
package require json
```

Python normally installs distributions with pip:

```bash
python -m pip install package-name
```

Lua projects commonly use LuaRocks:

```bash
luarocks install package-name
```

Node.js projects use npm or a compatible client:

```bash
npm install package-name
```

PowerShell installs modules from a configured repository:

```powershell
Install-Module -Name ModuleName -Repository PSGallery
```

.NET projects normally consume NuGet packages:

```bash
dotnet add package PackageName
```

### Ecosystem reach

| Ecosystem | Practical package advantage | Practical limitation |
|-----------|-----------------------------|----------------------|
| Eagle | Direct access to installed CLR assemblies, Eagle packages/plugins, first-party modules, and optional native Tcl through `[tcl]` or Garuda | The public Eagle-specific package catalog is much smaller than PyPI, npm, or NuGet. |
| Native Tcl | Long-lived Tcl package conventions and native extensions | Smaller modern public catalog than the largest general-purpose ecosystems; binary extensions are platform-sensitive. |
| PowerShell | Rich administration modules and PowerShell Gallery distribution | General application libraries are often consumed through .NET rather than idiomatic PowerShell modules. |
| Python | Exceptional breadth, especially in science, data, AI, web, and automation | Binary wheels, interpreter versions, native dependencies, and environment resolution can complicate embedding/deployment. |
| Lua | Small modules and many embedded/game integrations; LuaRocks fills common needs | Library coverage is thinner for broad enterprise application tasks. |
| Node.js | Very broad JavaScript/web catalog and mature lockfile workflows | Dependency trees and install-time scripts increase supply-chain review scope. |
| Roslyn/.NET | NuGet and the entire compatible .NET API surface | Dynamically resolving arbitrary packages inside a scripting host requires a deliberate loading and trust policy. |

Eagle's answer to a missing script package is often “call the CLR library
directly.”  That is a real advantage in a .NET product, but it does not replace
domain ecosystems such as Python's scientific stack or Node's web modules.

## Task 8: Test and Diagnose the System

Eagle's own test system is written in Eagle and can also compare behavior with
native Tcl.  Tests are commonly wrapped by `runTest` so the harness can
track constraints, isolation, cleanup, resource deltas, and diagnostics:

```tcl
runTest {test arithmetic-1.1 {integer expression} -setup {
    set left 6
} -body {
    expr {$left * 7}
} -cleanup {
    unset -nocomplain left
} -result 42}
```

The first-party suite adds:

- runtime constraints for platform, runtime, network, timing, and optional
  features;
- leak/resource accounting and cleanup checks;
- stress, timing, isolated-process, and native Tcl comparison modes;
- white-box test seams in the engine;
- out-of-process progress monitoring through WatchCat; and
- shared test utilities written in the same language under test.

This is an integration advantage, not a claim that no other ecosystem has an
excellent test framework.

### Other ecosystems

- Native Tcl includes `tcltest` and has a mature self-test tradition.
- Python includes `unittest` and has a large ecosystem led by tools such as
  pytest.
- Node.js includes a stable test runner and has several established external
  frameworks.
- PowerShell commonly uses Pester and can test modules, scripts, and
  infrastructure-facing behavior.
- Lua has multiple small external test frameworks suited to embedded projects.
- C# has MSTest, xUnit.net, NUnit, BenchmarkDotNet, and the compiler-analysis
  facilities exposed by Roslyn.

Eagle's strongest testing argument is continuity: interpreter internals,
scripts, native Tcl compatibility, packages, builds, installers, and
operational behavior can be tested through one harness and one constraint
vocabulary.  Its weakness is that fewer outside teams and tools understand
that harness than understand mainstream Python, JavaScript, or .NET test
formats.

For examples of the wider feedback loop, see
[What Is Innovative About Eagle?](innovation.md#7-testing-the-system-in-its-own-language)
and [Core Examples](core_examples.md).

## Task 9: Migrate or Interoperate

### From native Tcl

Eagle is intentionally Tcl-compatible, not identical to Tcl.  It is based on
the Tcl command/list/substitution model and a Tcl 8.4 foundation, with selected
later Tcl behavior and Eagle extensions.  Compatibility must be tested,
especially around:

- exact command and option availability;
- numeric, encoding, culture, and regular-expression edge cases;
- event-loop and channel timing;
- platform-specific path and process behavior;
- binary extensions and Tk;
- namespace/package subtleties; and
- code that depends on implementation-specific error text.

Eagle offers two unusual migration paths:

- `[tcl]` loads and controls native Tcl from Eagle; and
- [Garuda](garuda.md) loads Eagle into a native Tcl process.

That makes incremental migration possible.  A native package can remain in
Tcl while new .NET-facing orchestration is written in Eagle, or an existing Tcl
application can introduce selected Eagle/CLR capabilities.

### From a .NET application

If the application already exposes services as CLR objects, Eagle, PowerShell,
and Roslyn avoid a native foreign-function boundary:

- Eagle is best for a compact dynamic command language and controlled
  capability surface.
- PowerShell is best when the host should expose cmdlets and pipelines.
- Roslyn is best when extensions should simply be C#.

Moving to CPython, Lua, Node.js, or native Tcl may still be justified by their
ecosystems, but the host must own an additional bridge, native runtime, or
process protocol.

### From another scripting language

Syntax migration is rarely the main cost.  Inventory these semantic
dependencies first:

1. package and native-extension dependencies;
2. concurrency/event-loop assumptions;
3. object identity and lifetime across the host boundary;
4. exception/error propagation;
5. module/package resolution;
6. trust and code-signing workflow;
7. deployment footprint and target runtimes; and
8. observability and test infrastructure.

Eagle is not a compatibility layer for Python, Lua, JavaScript, PowerShell, or
C#.  Migration is attractive only when Eagle's host boundary and lifecycle
benefits outweigh a rewrite of the language-specific layer.

## Task 10: Balance Footprint, Throughput, and Deployment

No responsible general comparison can name a universal performance winner.
The architectural expectations are:

| Ecosystem | Startup and footprint tendency | Throughput tendency | Deployment consideration |
|-----------|--------------------------------|----------------------|--------------------------|
| Eagle | Requires a compatible CLR and benefits from reusing long-lived interpreters | Good for orchestration; repeated reflection/marshalling and script parsing should be measured | Broad .NET Framework, modern .NET, .NET Standard, and Mono build matrix; feature sets vary by target |
| Native Tcl | Compact native runtime with mature initialization behavior | Efficient command/event workloads; C extensions handle hot paths | Native binaries and extensions must match target platforms |
| PowerShell | A shell/runspace and module inventory can be comparatively heavy | Excellent for coarse administrative operations; pipeline object volume can matter | Cross-platform PowerShell exists, but many administration modules remain platform/service-specific |
| Python | Runtime startup is moderate; scientific stacks may be large | Excellent native libraries; Python-level CPU loops may need vectorization, extensions, processes, or newer concurrency modes | Virtual environments, wheels, and native dependencies need management |
| Lua | Commonly the smallest and simplest baseline here | Fast lightweight VM for embedded logic; application-specific C functions handle hot paths | The host normally owns library selection and deployment |
| Node.js | V8/libuv process has a larger baseline than Lua/Tcl | Strong event-driven I/O and optimized JavaScript after warm-up | Use supported LTS releases; native addons must match supported interfaces/platforms |
| Roslyn | Compiler services and first evaluation have meaningful cost | Reusable compiled scripts can run as ordinary generated .NET code | Runtime code generation, references, and generated assemblies affect trimming/AOT and restricted platforms |

### Benchmark the boundary, not only the loop

For an embedded language, measure:

- cold and warm interpreter creation;
- parsing/compilation and repeated execution;
- host-to-script and script-to-host call frequency;
- argument conversion and object-handle lifetime;
- callback/event dispatch latency;
- memory after repeated create/evaluate/dispose cycles;
- cancellation and timeout latency;
- package/module loading;
- deployment size; and
- behavior on every supported runtime and operating system.

Eagle is designed around a dual-language model: keep hot, typed primitives in
.NET and use script for composition and policy.  A benchmark that moves every
scalar operation through reflection measures an avoidable boundary pattern,
not the intended architecture.

## Ecosystem Profiles

### Eagle Profile

#### Best fit

- Embedded scripting in .NET products.
- Tcl-compatible orchestration that directly manipulates CLR objects.
- Bidirectional host callbacks and event integration.
- Safe child interpreters with host-defined capabilities.
- Products that want first-party signing, policy, package, build, installer,
  testing, and update integration.
- Gradual native Tcl/CLR coexistence.

#### Advantages

- The CLR boundary is a core language subsystem, not an optional bridge.
- Safe interpreters and signed-code workflows address authority and
  authenticity as separate layers.
- Native Tcl works in both directions through `[tcl]` and Garuda.
- The test, documentation, and integration projects share the same language
  and conventions.
- A single codebase deliberately supports a wide range of .NET generations
  and feature configurations.

#### Costs

- The Eagle-specific user and package ecosystem is small relative to Python,
  JavaScript, PowerShell, and mainstream .NET.
- Tcl syntax and substitution rules are unfamiliar to many modern developers.
- Compatibility with Tcl is substantial but not automatic or complete.
- The broad runtime/build matrix creates complexity for contributors and
  embedders.
- Reflection, marshalling, dynamic callbacks, event ownership, and safe-host
  capability design still require engineering discipline.

#### Choose Eagle over the alternatives when

The application values the *combination* of Tcl composition, CLR reach,
host-governed execution, and lifecycle integration more than it values the
largest external package catalog or a mainstream syntax.

### Native Tcl Profile

#### Where native Tcl is stronger

- It is the reference runtime for Tcl semantics.
- It has a compact, mature C API and native event system.
- Existing Tcl/Tk applications and compiled Tcl extensions run in their
  intended environment.
- Safe Tcl is mature and well documented.
- The Tcl community and literature directly target it.

#### Where Eagle is stronger

- CLR types, objects, delegates, and assemblies are first-class integration
  targets.
- A managed application does not need to host an additional native runtime.
- Eagle adds project-specific policies, richer resource accounting,
  signed-script and enterprise trust workflows, CLR-oriented packages, and
  managed host abstractions.
- Bidirectional integration permits native Tcl to remain in the architecture
  where it is useful.

#### Decision

Choose native Tcl for maximum Tcl fidelity, Tcl/Tk, and existing native
extensions.  Choose Eagle when .NET is the center of gravity and incremental
Tcl compatibility is more valuable than exact implementation identity.

### PowerShell Profile

#### Where PowerShell is stronger

- Interactive administration, remoting, providers, and object pipelines.
- Microsoft product and cloud-service modules.
- Discoverable cmdlet conventions and a broad operations community.
- JEA and system-enforced constrained endpoints for administration.

#### Where Eagle is stronger

- A smaller application-defined scripting surface.
- Tcl list/command composition and lightweight procedures.
- Safe child interpreters, cross-interpreter aliases, and interpreter-level
  policy as product architecture.
- Direct integration with native Tcl and Tcl-compatible assets.
- Signed script/package/bundle workflows designed around Eagle evaluation.

#### Decision

Choose PowerShell when the operator and administrative object pipeline are the
center of the design.  Choose Eagle when the application is the center and
should expose a narrow, durable script language under its own lifecycle and
policy.

### Python Profile

#### Where Python is stronger

- General adoption, training resources, editors, and community.
- PyPI package breadth.
- Data science, machine learning, scientific computing, web frameworks, and
  general automation.
- `asyncio` and a large selection of concurrent/network libraries.
- Readability for developers already trained in Python.

#### Where Eagle is stronger

- Direct CLR automation without assuming an external bridge or a separate
  Python implementation.
- A Tcl-style embedded command language rather than a general application
  language hosted through the CPython C API.
- Built-in safe interpreters and capability aliases.
- First-party policy and signed-script integration.
- Native Tcl coexistence and compatibility.

Python.NET materially changes the CLR comparison: it lets CPython import and
use CLR namespaces, types, generics, delegates, and events.  IronPython is a
separate Python implementation tightly integrated with .NET.  Both are
legitimate alternatives when Python syntax or packages are required, but
their Python-version, native-extension, runtime-loading, marshalling, and
deployment constraints must be evaluated independently; they are not
features of baseline CPython.

#### Decision

Choose Python when its packages or developer ecosystem dominate the
requirement.  Choose Eagle when a .NET host, controlled interpreter surface,
and Tcl/CLR integration dominate.  Do not select CPython `eval` or `exec`
as an in-process hostile-code sandbox.

### Lua Profile

#### Where Lua is stronger

- Very small native embedding surface and runtime.
- Simple host registration through the C API.
- Tables, functions, metatables, and coroutines form a compact extension
  language.
- Long-standing adoption in games, devices, and native applications.
- The host can construct a deliberately minimal environment.

#### Where Eagle is stronger

- The natural host is .NET rather than C.
- CLR reflection, overload resolution, object lifetime, delegates, and events
  are integrated.
- Safe interpreters and policy machinery are predefined architectural
  concepts rather than a host convention assembled from environments and
  hooks.
- Package, signing, testing, documentation, and native Tcl bridges form a
  larger first-party product lifecycle.

#### Decision

Choose Lua when small native embedding is the decisive requirement.  Choose
Eagle when the host is managed, CLR object reach matters, and the product
wants a more extensive interpreter governance model.

### Node.js Profile

#### Where Node.js is stronger

- JavaScript/TypeScript developer availability.
- npm package breadth and web tooling.
- A runtime centered on event-driven I/O, streams, promises, and services.
- Natural code sharing with browser or JavaScript front ends.
- Mature tooling for network applications.

#### Where Eagle is stronger

- Managed embedding in a .NET application without managing V8/libuv C++
  lifecycle.
- Direct CLR object handles, overload selection, delegates, and policy hooks.
- Tcl-compatible native migration paths.
- Safe interpreters and integrated signed-code workflows.
- A compact command language for application-specific orchestration.

#### Decision

Choose Node.js when the application and team are JavaScript-first or the web
ecosystem is decisive.  Choose Eagle for a .NET-centered embedded extension
language.  Never treat a `node:vm` context as a hostile-code security
boundary.

### Roslyn C# Scripting Profile

#### Where Roslyn is stronger

- Full C# syntax and type system.
- Generics, LINQ, async/await, compiler diagnostics, and static analysis.
- Typed globals and reusable compiled scripts.
- Access to syntax trees, semantic models, analyzers, and generated code.
- Minimal conceptual distance between application code and script code.

#### Where Eagle is stronger

- Concise command/list/string composition for orchestration.
- Runtime definition and replacement of commands without a compilation model.
- Safe interpreters, capability aliases, and script-oriented policy.
- Tcl compatibility and native Tcl bridges.
- Explicit object handles and lifecycle policy at a dynamic boundary.
- First-party signing/package/bundle workflows tied to the interpreter.

#### Decision

Choose Roslyn when submitted code should be C# and is trusted with process
authority.  Choose Eagle when scripts should be smaller, more dynamic,
Tcl-compatible, and governed through interpreter capabilities.

## Recommended Deployment Patterns

| Product shape | Recommended starting pattern |
|---------------|------------------------------|
| .NET application with trusted user automation | Long-lived Eagle interpreter; expose a documented object/command surface; add timeouts and cancellation |
| .NET application with semi-trusted extensions | Eagle safe child per trust domain; capability aliases; policy; resource limits; signed packages; isolate externally where impact demands it |
| Existing native Tcl product adding .NET | Keep Tcl components; introduce Eagle through Garuda or host Tcl from Eagle with `[tcl]`; maintain differential tests |
| Administrative console | PowerShell runspace or JEA endpoint; host Eagle only for Eagle-specific policy/scripts |
| Scientific/data product | Python service or process for the scientific layer; use an explicit protocol if a .NET/Eagle host coordinates it |
| Small C/C++ application extension language | Lua or native Tcl; choose based on syntax, package, event, and safety requirements |
| JavaScript network service | Supported Node.js LTS; use process/container isolation for untrusted extensions |
| Trusted typed business rules | Roslyn with precompiled reusable scripts, explicit references, cancellation, and a deployment trust policy |
| Hostile multi-tenant evaluation | Separate process/account/container or VM, quotas, restricted network/filesystem, authenticated artifacts, and a language-level restriction layer where available |

Hybrid systems are legitimate.  Eagle's value is often not replacing every
other language; it is serving as the inspectable orchestration and policy
layer around typed .NET components and selected external runtimes.

## Security and Mission-Critical Checklist

Before using any scripting ecosystem in a mission-critical system:

1. **Classify script trust.**  Distinguish product-authored, administrator-
   authored, tenant-authored, and anonymous code.
2. **Minimize authority.**  Expose narrow operations, not general reflection,
   filesystem, process, network, or package-loading access.
3. **Authenticate code.**  Verify signatures, provenance, repository policy,
   and dependency lock data before evaluation.
4. **Bound resources.**  Set time, command/iteration, recursion, memory,
   output, input, file, process, and network quotas at the strongest available
   layer.
5. **Use external isolation.**  In-process language restrictions are one
   layer, not a substitute for an OS boundary when tenants are hostile or
   consequences are severe.
6. **Make completion single-shot.**  Async operations need one owner and one
   terminal transition across success, timeout, cancellation, error, close,
   and disposal.
7. **Test adverse schedules.**  Include immediate completion, delayed
   completion, partial I/O, peer reset, DNS failure, unreachable addresses,
   callback reentry, disposal during callback, and event-loop shutdown.
8. **Pin and audit dependencies.**  A safe interpreter cannot make an unsafe
   native extension or privileged host command safe.
9. **Preserve diagnostics without leaking secrets.**  Correlate interpreter,
   script, request, and event identities while redacting paths, credentials,
   keys, and tenant data.
10. **Exercise recovery.**  Verify that the host can cancel, dispose, restart,
    and restore service after a failed or wedged script.
11. **Test every supported target.**  Runtime, operating system, architecture,
    culture, encoding, and feature-flag differences matter.
12. **Review the boundary independently.**  Treat custom commands, aliases,
    callbacks, marshalling rules, package resolvers, and signing-key custody as
    security-sensitive code.

For Eagle specifically, start with [Safe Interpreters](safe.md),
[Embedding Eagle](embedding.md), [the object boundary](object.md),
[package loading](package.md), and [plugin loading](load.md).

## Conclusions

Eagle should not be presented as a replacement for every scripting language.
Its compelling case is narrower and stronger:

> Eagle is a Tcl-compatible systems-scripting environment designed to live
> inside .NET applications while keeping object interoperation, callbacks,
> policy, safe evaluation, signed distribution, native Tcl migration, testing,
> and lifecycle tooling within one coherent architecture.

Native Tcl remains the standard for Tcl fidelity and native extensions.
PowerShell leads administrative object automation.  Python leads many data and
general package domains.  Lua is exceptionally compact for native embedding.
Node.js is a natural event-driven JavaScript service platform.  Roslyn is the
right answer when dynamic code should retain full C# semantics.

Choose Eagle when its combination is the requirement.  Choose another
ecosystem when that ecosystem's center of gravity is the requirement.  For
high-stakes systems, combine the choice with explicit trust, isolation,
resource, test, and operational designs rather than relying on language
branding.

## Official References

### Eagle

- [What Is Innovative About Eagle?](innovation.md)
- [Why Eagle?](why_eagle.md)
- [Embedding Eagle in a C# Application](embedding.md)
- [Eagle Safe Interpreters](safe.md)
- [Eagle `[object]` Command Analysis](object.md)
- [Eagle `[tcl]` Command Analysis](tcl.md)
- [Eagle Native Package for Tcl (Garuda)](garuda.md)
- [Eagle Package Loading](package.md)
- [Eagle Integration Sub-Projects](integrations.md)

### Native Tcl

- [Tcl `interp` manual](https://www.tcl-lang.org/man/tcl9.0.2/TclCmd/interp.html)
- [Safe Tcl manual](https://www.tcl-lang.org/man/tcl9.0/TclCmd/safe.html)
- [Tcl 8.6 C API index](https://www.tcl-lang.org/man/tcl8.6/TclLib/contents.htm)
- [Tcl `fileevent` manual](https://www.tcl-lang.org/man/tcl9.0/TclCmd/fileevent.html)

### PowerShell

- [PowerShell host quickstart](https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/windows-powershell-host-quickstart)
- [PowerShell language modes](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_language_modes)
- [PowerShell execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- [`Register-ObjectEvent`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/register-objectevent)
- [PowerShell Gallery getting started](https://learn.microsoft.com/en-us/powershell/gallery/getting-started)

### Python

- [Embedding CPython](https://docs.python.org/3/extending/embedding.html)
- [Python `eval` and `exec`](https://docs.python.org/3/library/functions.html#exec)
- [Python `asyncio`](https://docs.python.org/3/library/asyncio.html)
- [Python Packaging User Guide](https://packaging.python.org/en/latest/)
- [Python.NET documentation](https://pythonnet.github.io/pythonnet/python.html)
- [IronPython](https://ironpython.net/)

### Lua

- [Lua reference manual](https://www.lua.org/manual/5.5/manual.html)
- [Lua versions](https://www.lua.org/versions.html)
- [Lua downloads and ecosystem links](https://www.lua.org/download.html)

### Node.js

- [Node.js release policy](https://nodejs.org/en/about/previous-releases)
- [Node.js events](https://nodejs.org/api/events.html)
- [Node.js `node:vm`](https://nodejs.org/api/vm.html)
- [Node.js Permission Model](https://nodejs.org/api/permissions.html)
- [Node.js C++ embedder API](https://nodejs.org/api/embedding.html)
- [Node-API](https://nodejs.org/api/n-api.html)
- [npm documentation](https://docs.npmjs.com/)

### Roslyn and .NET

- [Roslyn scripting API samples](https://github.com/dotnet/roslyn/blob/main/docs/wiki/Scripting-API-Samples.md)
- [`Microsoft.CodeAnalysis.CSharp.Scripting` on NuGet](https://www.nuget.org/packages/Microsoft.CodeAnalysis.CSharp.Scripting)
- [`AssemblyLoadContext`](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.loader.assemblyloadcontext)
- [.NET dependency loading](https://learn.microsoft.com/en-us/dotnet/core/dependency-loading/overview)
