# Embedding Eagle in a C# Application

Eagle is a Tcl-compatible scripting engine written in managed code. Because it
*is* a .NET library, "embedding" it means nothing more than referencing one
assembly (`Eagle.dll`), creating an `Interpreter`, and evaluating script text.
This guide covers the idiomatic way to do that: the core evaluate loop, how to
exchange data with scripts, how to extend the interpreter with your own C#
commands and functions, how to call .NET back from scripts, how to sandbox
untrusted code, and how to deploy the result.

Everything here is grounded in the two sample projects that ship with Eagle and
are the authoritative templates for embedders:

- **`Eagle/Example/`** — the minimal host: create an interpreter, add a custom
  command and a policy, evaluate a script, clean up (`Example.cs`, `Class0.cs`).
- **`Eagle/Sample/`** — a fuller tour organized by extension point:
  `Sample/Commands/`, `Sample/Functions/`, `Sample/Plugins/`, `Sample/Policies/`,
  `Sample/Hosts/`, and `Sample/Forms/` (embedding in a WinForms app).

Keep those open alongside this document; when in doubt, they are the ground
truth.

## Table of Contents

- [1. Overview and mental model](#1-overview-and-mental-model)
- [2. Installation and assembly references](#2-installation-and-assembly-references)
- [3. The core types: Interpreter, ReturnCode, Result](#3-the-core-types-interpreter-returncode-result)
- [4. Hello, world — the minimal embed](#4-hello-world--the-minimal-embed)
- [5. Creating and disposing interpreters](#5-creating-and-disposing-interpreters)
- [6. Evaluating scripts, files, and expressions](#6-evaluating-scripts-files-and-expressions)
- [7. Exchanging data with scripts](#7-exchanging-data-with-scripts)
- [8. Extending the interpreter with C# commands](#8-extending-the-interpreter-with-c-commands)
- [9. Custom expr functions and plugins](#9-custom-expr-functions-and-plugins)
- [10. Calling .NET from scripts and injecting C# objects](#10-calling-net-from-scripts-and-injecting-c-objects)
- [11. Customizing input/output: the host](#11-customizing-inputoutput-the-host)
- [12. Sandboxing untrusted scripts](#12-sandboxing-untrusted-scripts)
- [13. Cancellation, timeouts, and resource limits](#13-cancellation-timeouts-and-resource-limits)
- [14. Threading model](#14-threading-model)
- [15. AppDomain isolation](#15-appdomain-isolation)
- [16. Deployment and target frameworks](#16-deployment-and-target-frameworks)
- [17. Idiomatic checklist](#17-idiomatic-checklist)
- [18. Further reading](#18-further-reading)

---

## 1. Overview and mental model

An embedded Eagle host revolves around one object, the **`Interpreter`**, and one
error-handling convention, the **`ReturnCode` / `Result` pair**.

- You **create** an `Interpreter` (it is `IDisposable`; wrap it in `using`).
- You **evaluate** script text against it. Every evaluation returns a
  `ReturnCode` (an `enum`; `ReturnCode.Ok` means success) and writes its outcome
  into a `Result` that you pass by reference — the script's return value on
  success, or an error message on failure.
- You **extend** the interpreter by adding commands, functions, policies, and
  objects before (or between) evaluations.
- You **dispose** it when done.

This return-code-plus-result model — rather than exceptions — is the pervasive
Eagle idiom. Public methods return a `ReturnCode` and take a `ref Result`; you
check the code and read the result. (Exceptions still exist for truly
exceptional conditions, but the engine is designed so that ordinary script
failures are values, not throws.)

Eagle is **Tcl-compatible, not Tcl-identical** — it targets the Tcl 8.4 language
baseline plus selected later features, on the CLR. For language-level questions
see the [Quick Start Guide](quick_start_guide.md) and the core language docs.

---

## 2. Installation and assembly references

The simplest way to add Eagle to a project is NuGet:

```sh
dotnet add package Eagle
```

`Eagle` is an umbrella meta-package that selects the correct build for your
target framework:

| Your target | Package chain | `Eagle.dll` from |
|---|---|---|
| .NET Framework 2.0 | `Eagle` → `Eagle.CLRv2` → `Eagle.CLRv2.Core` | `lib\net20` |
| .NET Framework 4.x | `Eagle` → `Eagle.CLRv4` → `Eagle.CLRv4.Core` | `lib\net40` |
| .NET Standard 2.0 / 2.1 (Core, .NET 5–10) | `Eagle` → `Eagle.DotNet` → `Eagle.DotNet.Standard.2.0` / `2.1` | `lib\netstandard2.0` / `2.1` |

You reference a **single managed assembly, `Eagle.dll`.** (The CLRv2/CLRv4
packages also bundle the optional native `Spilornis.dll` used for native-Tcl
integration; you do not need it for pure managed embedding.)

The public API lives in a small set of namespaces:

```csharp
using Eagle._Attributes;         // [ObjectId], [CommandFlags], [ObjectGroup], ...
using Eagle._Components.Public;   // Interpreter, Engine, Result, Utility, and the enums
using Eagle._Containers.Public;   // ArgumentList, StringList, ...
using Eagle._Interfaces.Public;   // IExecute, ICommand, IHost, IClientData, ...
```

Custom-command base classes live in `Eagle._Commands`, the default host in
`Eagle._Hosts`, so those two typically get aliased or fully qualified:

```csharp
using _Commands = Eagle._Commands; // base class Default for custom commands
```

---

## 3. The core types: Interpreter, ReturnCode, Result

**`Interpreter`** (`Eagle._Components.Public`) is the script engine instance. It
is `sealed`, implements `IDisposable`, and is thread-safe — it supports
concurrent script evaluation, locking only shared state (see
[§14](#14-threading-model)). Every public member first checks for disposal, so
using one after its `using` block throws `ObjectDisposedException`.

**`ReturnCode`** is a Tcl-compatible `enum`:

| Value | Meaning |
|---|---|
| `ReturnCode.Ok` (0) | success — `result` holds the value |
| `ReturnCode.Error` (1) | failure — `result` holds the error message |
| `ReturnCode.Return` (2) | script called `return` |
| `ReturnCode.Break` (3) | script called `break` |
| `ReturnCode.Continue` (4) | script called `continue` |

For normal embedding you check `code == ReturnCode.Ok`; the loop/return codes
matter mainly when you implement custom control-structure commands.

**`Result`** is a mutable value carrier — not just a string. It converts
implicitly to and from `string` (so you can assign `result = "message";` and
pass a `Result` straight into `Console.WriteLine`), and it also carries
`ErrorLine`, `ErrorCode`, and the return code. The idiom is to declare the
carrier as `null` and let the callee populate it:

```csharp
Result result = null;
```

Handy helpers on **`Utility`** (`Eagle._Components.Public`):
`Utility.FormatResult(code, result, errorLine)` to render an outcome,
`Utility.ReturnCodeToExitCode(code)` / `SuccessExitCode()` / `FailureExitCode()`
for process exit codes, and `Utility.IsSuccess(code, true)` as an alternative to
`code == ReturnCode.Ok`.

---

## 4. Hello, world — the minimal embed

```csharp
using System;
using Eagle._Components.Public;

internal static class Program
{
    private static int Main(string[] args)
    {
        Result result = null;

        // Create an interpreter with default options. Returns null on
        // failure, in which case "result" holds the reason.
        using (Interpreter interpreter = Interpreter.Create(args, ref result))
        {
            if (interpreter == null)
            {
                Console.WriteLine(Utility.FormatResult(ReturnCode.Error, result));
                return (int)Utility.FailureExitCode();
            }

            int errorLine = 0;

            ReturnCode code = interpreter.EvaluateScript(
                "expr {2 + 2}", ref result, ref errorLine);

            if (code == ReturnCode.Ok)
                Console.WriteLine("result = {0}", result);          // -> result = 4
            else
                Console.WriteLine("error (line {0}): {1}", errorLine, result);

            return (int)Utility.ReturnCodeToExitCode(code);
        } // Interpreter.Dispose() runs here
    }
}
```

The absolute one-liner, when you just need to run a snippet and throw the
interpreter away, is `Engine.EvaluateOneScript` — it creates a single-use
interpreter, evaluates, and disposes internally:

```csharp
string result = null;
int code = Engine.EvaluateOneScript("string toupper hello", ref result);
// code is a ReturnCode cast to int; result is "HELLO"
```

Prefer an explicit long-lived `Interpreter` for anything beyond a throwaway
snippet — creation has real cost, and most extension points (commands,
variables, objects) require an interpreter you keep around.

---

## 5. Creating and disposing interpreters

`Interpreter.Create(...)` is a family of `static` overloads. All of them take a
trailing `ref Result result` and **return `null` on failure** (never throwing
for ordinary configuration errors). The ones you will actually use:

```csharp
// Simplest — default options, no startup args.
public static Interpreter Create(ref Result result);

// With command-line arguments (populates the argv/argc script variables).
public static Interpreter Create(IEnumerable<string> args, ref Result result);

// With explicit interpreter and host creation flags (this is the one you use
// to make a "safe" interpreter — see §12).
public static Interpreter Create(
    IEnumerable<string> args,
    CreateFlags createFlags,
    HostCreateFlags hostCreateFlags,
    ref Result result);
```

`CreateFlags` controls how the interpreter is built (which command sets are
included, safety, etc.); `HostCreateFlags` controls the host. `CreateFlags.Default`
and `HostCreateFlags.Default` are the sensible baselines. A common tweak is to
suppress the engine throwing on error so you stay purely in the return-code
model:

```csharp
using (Interpreter interpreter = Interpreter.Create(
        args,
        CreateFlags.Default & ~CreateFlags.ThrowOnError,
        HostCreateFlags.Default,
        ref result))
{
    ...
}
```

For advanced construction (custom `IHost`, rule sets, profiles, owner objects,
a specific `AppDomain`, pre-registered policies/traces), there are settings-based
overloads that take an `IInterpreterSettings`; populate that object once and pass
it in. Reach for those only when the flag-based overloads are not enough.

**Disposal.** Always use a `using` block (or call `Dispose()` deterministically).
An interpreter owns resources — child interpreters, loaded plugins/AppDomains,
host channels — that are released on dispose.

---

## 6. Evaluating scripts, files, and expressions

All evaluation methods return `ReturnCode` and take a trailing `ref Result`. The
`errorLine` overloads additionally report the 1-based line within the script
where an error occurred.

```csharp
// Script text.
public ReturnCode EvaluateScript(string text, ref Result result);
public ReturnCode EvaluateScript(string text, ref Result result, ref int errorLine);

// A file on disk.
public ReturnCode EvaluateFile(string fileName, ref Result result);
public ReturnCode EvaluateFile(string fileName, ref Result result, ref int errorLine);

// A single [expr] expression (returns the computed value).
public ReturnCode EvaluateExpression(string text, ref Result result);
```

A reusable helper that captures the idiomatic error handling once:

```csharp
static bool TryRun(Interpreter interpreter, string script, out string output)
{
    Result result = null;
    int errorLine = 0;

    ReturnCode code = interpreter.EvaluateScript(script, ref result, ref errorLine);

    output = (result != null) ? result.ToString() : null;

    if (code == ReturnCode.Ok)
        return true;

    // "result" now holds the error message; errorLine the failing line.
    // result.ErrorInfo carries the script stack trace if you want it.
    return false;
}
```

Notes:

- The instance methods (`interpreter.EvaluateScript(...)`) are the ones to use
  for normal embedding. There are equivalent `static` entry points on `Engine`
  (`Engine.EvaluateScript(interpreter, text, ref result, ref errorLine)`), which
  the shipped `Example` uses; they are the lower-level re-entrant forms and
  behave identically.
- To run an interactive REPL inside your own process (read-eval-print against the
  host console), use `Interpreter.InteractiveLoop(interpreter, args, ref result)`.
- On a **safe** interpreter, use `EvaluateTrustedScript` / `EvaluateTrustedFile`
  to run a specific trusted snippet with full command visibility without
  permanently un-sandboxing the interpreter (see [§12](#12-sandboxing-untrusted-scripts)).

---

## 7. Exchanging data with scripts

The most direct channel is interpreter variables. Note that `GetVariableValue`
uses **two** `Result` parameters — one for the retrieved value, one for an error
message:

```csharp
public ReturnCode SetVariableValue(string name, string value, ref Result error);
public ReturnCode GetVariableValue(string name, ref Result value, ref Result error);
public ReturnCode UnsetVariable(string name, ref Result error);
```

```csharp
Result error = null;

// Push a value in, run script that uses it, read a value back out.
interpreter.SetVariableValue("userName", "ada", ref error);

Result result = null;
interpreter.EvaluateScript("set greeting \"hello, $userName\"", ref result);

Result value = null;
if (interpreter.GetVariableValue("greeting", ref value, ref error) == ReturnCode.Ok)
    Console.WriteLine(value);   // hello, ada
```

**Linked variables** bind a C# field or property directly to a script variable,
so reads and writes on either side stay in sync. This is how the shipped
`Example` exposes the process command line to scripts:

```csharp
// Bind the static field Program.mainArgs to a script variable of the same name.
interpreter.SetVariableLink(
    VariableFlags.None, "mainArgs",
    typeof(Program).GetField("mainArgs"), null, ref result);
```

Thereafter the script can read `$mainArgs` (as a list) and see live values. Use
`UnsetVariable` to unlink/remove when finished. `VariableFlags.None` is the usual
default; the flags let you request global scope, array semantics, and so on.

For passing *objects* (not strings) into a script, see
[§10](#10-calling-net-from-scripts-and-injecting-c-objects).

---

## 8. Extending the interpreter with C# commands

A custom command is a C# class that implements the command contract and is
registered on the interpreter. In practice you do **not** implement the full
`ICommand` interface by hand — you derive from the base class
`Eagle._Commands.Default`, which implements the whole aggregate, and override the
one method that matters, `IExecute.Execute`:

```csharp
ReturnCode Execute(
    Interpreter interpreter,  // the interpreter context
    IClientData clientData,   // the client data supplied at registration (if any)
    ArgumentList arguments,   // arguments[0] is the command name as invoked
    ref Result result);       // set the command's result (or error) here
```

The canonical template (adapted from `Eagle/Example/Class0.cs`) — note the
standard validity checks and the exact "wrong # args" idiom:

```csharp
using System;
using Eagle._Attributes;
using Eagle._Components.Public;
using Eagle._Containers.Public;
using Eagle._Interfaces.Public;
using _Commands = Eagle._Commands;

namespace MyApp
{
    // Out-of-tree commands should be public and carry a FRESH, unique GUID.
    [ObjectId("00000000-0000-0000-0000-000000000000")] // <-- change this!
    [CommandFlags(CommandFlags.Unsafe)]                // omit Unsafe -> usable in safe interps
    [ObjectGroup("myapp")]
    public sealed class GreetCommand : _Commands.Default
    {
        public GreetCommand(ICommandData commandData)
            : base(commandData)
        {
            // Recommended: fold in the flags declared via attributes.
            this.Flags |= Utility.GetCommandFlags(GetType().BaseType) |
                Utility.GetCommandFlags(this);
        }

        public override ReturnCode Execute(
            Interpreter interpreter, IClientData clientData,
            ArgumentList arguments, ref Result result)
        {
            if (interpreter == null) { result = "invalid interpreter"; return ReturnCode.Error; }
            if (arguments == null)   { result = "invalid argument list"; return ReturnCode.Error; }

            // "greet name" -> exactly two arguments (command name + one arg).
            if (arguments.Count != 2)
            {
                result = Utility.WrongNumberOfArguments(this, 1, arguments, "name");
                return ReturnCode.Error;
            }

            try
            {
                result = "hello, " + arguments[1];   // Argument -> string implicitly
                return ReturnCode.Ok;
            }
            catch (Exception e)
            {
                result = e;                          // set the result to the exception
                return ReturnCode.Error;
            }
        }
    }
}
```

Register it, then it is callable from any script as `greet`:

```csharp
long token = 0;
Result result = null;

ICommandData data = new CommandData(
    "greet",                       // command name (required)
    null,                          // group
    null,                          // description
    ClientData.Empty,              // client data handed to Execute
    typeof(GreetCommand).FullName, // type name
    CommandFlags.None,             // flags
    null,                          // owning plugin (none)
    0);                            // token

ICommand command = new GreetCommand(data);

if (interpreter.AddCommand(command, null, ref token, ref result) != ReturnCode.Ok)
    Console.WriteLine("add failed: {0}", result);

// ... interpreter.EvaluateScript("greet world", ...) -> "hello, world" ...

// When finished (optional; disposal also cleans up):
interpreter.RemoveCommand(token, null, ref result);
```

Argument conventions:

- `arguments[0]` is the command name as invoked; real parameters start at
  `arguments[1]`. Index with `arguments[i]`, count with `arguments.Count`.
- An `Argument` converts implicitly to `string`, so treat elements as strings;
  parse numbers/booleans with the `Value`/`Utility` helpers or `[expr]`.
- On success set `result` to the command's value (use `String.Empty` if there is
  no meaningful value) and return `ReturnCode.Ok`. On failure set `result` to a
  non-empty error message (or the caught exception) and return `ReturnCode.Error`.
- Commands are discouraged from letting exceptions escape `Execute`; catch and
  convert to a `Result` as shown.

The `[CommandFlags(CommandFlags.Unsafe)]` attribute marks the command as
unavailable in safe interpreters. Mark a command `CommandFlags.Safe` (or simply
omit `Unsafe`) if untrusted scripts should be allowed to call it. See
`Eagle/Sample/Commands/` for richer examples, including ensemble (sub-command)
commands.

---

## 9. Custom expr functions and plugins

**Custom `[expr]` functions** implement `IFunction` (which uses
`IExecuteArgument`, a single-value form) — derive from the function base class in
`Eagle._Functions` and register with `AddFunction`:

```csharp
long token = 0;
Result result = null;

interpreter.AddFunction(
    typeof(MyFunction),   // null -> resolved by naming convention
    "myfunc",             // name usable as myfunc(...) inside [expr]
    1,                    // expected argument count
    null,                 // argument types (null -> any)
    FunctionFlags.None,
    null,                 // owning plugin
    null,                 // client data
    true,                 // strict
    ref token, ref result);
```

See `Eagle/Sample/Functions/Class8.cs` for a complete example.

**Plugins** implement `IPlugin` and bundle a set of commands, functions,
policies, and resources behind a single loadable unit — this is the mechanism
behind `[package]`-style extensions and the Enterprise plugins. A plugin's
`Initialize` method calls `AddCommand`/`AddFunction` for everything it provides.
Register one directly with:

```csharp
interpreter.AddPlugin(myPlugin, null, ref token, ref result);
```

Most embedders add a handful of commands directly (as in §8) and only reach for
a plugin when they want a reusable, separately-versioned, or isolatable bundle
(see [§15](#15-appdomain-isolation)). See `Eagle/Sample/Plugins/` and the
[`[load]` reference](load.md) for the plugin lifecycle.

---

## 10. Calling .NET from scripts and injecting C# objects

There are two complementary directions.

### Reflection from script — the `[object]` command

Scripts can create and drive arbitrary .NET objects via the `[object]` command
ensemble. Objects are represented by **opaque handle strings** (e.g.
`System#Text#StringBuilder#1`):

```tcl
set sb [object create System.Text.StringBuilder]
object invoke $sb Append "Hello"
object invoke $sb Append ", world"
set text [object invoke $sb ToString]     ;# "Hello, world"

set root [object invoke System.Math Sqrt 144.0]   ;# static method -> 12
set now  [object invoke System.DateTime Now]      ;# static property
```

`[object]` is powerful (43 sub-commands: `create`, `invoke`, `load`, `members`,
`dispose`, and more) and is therefore **unsafe by default** — it is not
available in safe interpreters. The full reference is [object.md](object.md).

### Injecting a live C# object

To hand an existing C# object to scripts, add it to the interpreter's object
table and expose the handle. The simplest surface is `ScriptThread.AddObject`,
which generates the handle name and returns it:

```csharp
MyService svc = new MyService();

Result result = null;
scriptThread.AddObject(svc, ref result);   // result now holds the handle name
// bind it to a well-known variable so scripts can find it:
scriptThread.SetVariableValue("svc", result.ToString());
```

At the raw interpreter level the equivalent is `Interpreter.AddObject(...)`
(create an opaque handle for a CLR value), after which you typically
`SetVariableValue` the handle string into a script variable. The script then
uses `object invoke $svc SomeMethod ...`.

### The controlled alternative: wrap the object in a command

For most "let scripts call my application" scenarios, exposing raw reflection is
more power than you want. The cleaner, safe-interp-friendly idiom is to write a
small custom command (§8) that closes over your C# object and exposes exactly the
operations you intend — for example a `GreetCommand` that holds a reference to
your service via its `clientData`. This gives you a curated, safe surface instead
of unrestricted reflection.

---

## 11. Customizing input/output: the host

Eagle routes all console-style I/O — what `puts` writes, what `gets` reads, the
prompt, titles, colors — through a **host** object implementing `IHost`. The
default host talks to the system console; replace it to redirect output into a
GUI, a log, a socket, or nothing at all.

`IHost` composes fifteen finer interfaces (`IWriteHost` backs `puts`,
`IReadHost`/`IInteractiveHost` back `gets`, plus display, file-system, thread,
process, stream, and debug facets). You rarely implement it from scratch: derive
from the built-in base host and override only the members you care about.

```csharp
using _Hosts = Eagle._Hosts;

public sealed class CaptureHost : _Hosts.Default
{
    private readonly System.Text.StringBuilder buffer;

    public CaptureHost(IHostData hostData, System.Text.StringBuilder buffer)
        : base(hostData)
    {
        this.buffer = buffer;
    }

    // Override the write path to capture output instead of printing it.
    // (See Eagle/Sample/Hosts/Class10.cs for the full set of members.)
}
```

Attach it either at creation (the `Create` overloads that take an `IHost`) or by
assigning the settable property afterward:

```csharp
interpreter.Host = new CaptureHost(hostData, buffer);
```

For a headless service, provide a host that discards or redirects output so no
code path touches `System.Console`. The host subsystem is specified in detail in
[host.md](host.md) and [interpreter_host.md](interpreter_host.md); see
`Eagle/Sample/Hosts/` and `Eagle/Sample/Forms/` (a WinForms host) for working
implementations.

---

## 12. Sandboxing untrusted scripts

To run scripts you do not trust, create a **safe interpreter**. A safe
interpreter has every command lacking the `CommandFlags.Safe` attribute hidden
away, so untrusted code cannot touch the filesystem, network, processes, the
host, .NET reflection (`[object]`), child-interpreter management, or timing
facilities.

```csharp
Result result = null;

using (Interpreter interpreter = Interpreter.Create(
        null,
        CreateFlags.Default | CreateFlags.Safe,   // build a safe interpreter
        HostCreateFlags.Default,
        ref result))
{
    if (interpreter == null) { /* handle */ }

    // Bound runaway scripts (see §13).
    interpreter.RecursionLimit = 100;
    interpreter.SetOrUnsetTimeout(TimeoutType.Script, 5000, ref result); // 5s

    ReturnCode code = interpreter.EvaluateScript(untrustedScript, ref result);
    // filesystem/network/process/object/... are all unavailable to the script
}
```

What "safe" removes, the layered defenses (command hiding, policies, resource
limits), and the full list of security guarantees are documented in
[safe.md](safe.md). Key points for an embedder:

- **Grant capability deliberately.** Expose a specific operation to safe scripts
  by writing a custom command marked `CommandFlags.Safe` (§8), or by installing a
  **policy** callback that approves/denies specific hidden-command invocations
  (see `Eagle/Example/Example.cs`'s policy and `Eagle/Sample/Policies/`).
- **Elevate temporarily, not permanently.** To run one trusted snippet inside an
  otherwise-safe interpreter, use `EvaluateTrustedScript`, or bracket the
  operation with `LockAndMarkTrusted(...)` / `MarkSafeAndUnlock(...)` so the
  interpreter is only trusted for the duration and under the lock.
- **Runtime transitions:** `IsSafe()`, `MakeSafe(makeFlags, safe, ref error)`
  (actually hides/restores commands), `MarkSafe`/`MarkTrusted` (flip the flag).
- **Isolate further** by loading untrusted plugins into their own AppDomain (see
  [§15](#15-appdomain-isolation)).

Sandboxing is also available from *within* scripts via the `[interp]` command
(child safe interpreters, aliases, resource limits); that model is covered in
[interp.md](interp.md).

---

## 13. Cancellation, timeouts, and resource limits

A long-running or runaway script must be stoppable. Eagle observes cancellation,
timeouts, and limits at its periodic *readiness check*, which fires as scripts
execute.

**Cancel from another thread.** `Engine.CancelEvaluate` is explicitly
thread-safe and is the way a host aborts a script running on a worker thread:

```csharp
// From a control thread, while a worker is inside interpreter.EvaluateScript(...):
Result error = null;
Engine.CancelEvaluate(
    interpreter, "aborted by host",
    CancelFlags.Unwind | CancelFlags.Global,   // unwind the whole call stack
    ref error);

// Before reusing the interpreter, clear the cancel state:
Engine.ResetCancel(interpreter, CancelFlags.Global, ref error);
```

**Timeouts.** Set a millisecond budget for script execution:

```csharp
interpreter.SetOrUnsetTimeout(TimeoutType.Script, 5000, ref result); // 5s, or null to clear
```

**Limits** (properties on `Interpreter`):

- `RecursionLimit` — maximum recursion depth (default 1000, Tcl-compatible).
- `ReadyLimit` — maximum nested readiness checks (default unlimited).
- `ReadyTimeout` — milliseconds allotted to readiness checks.

```csharp
interpreter.RecursionLimit = 100;
```

Together these let a host cap how deep, how long, and how much a script may
consume, and abort it deterministically from the outside.

---

## 14. Threading model

An `Interpreter` is **thread-safe, and it supports genuine concurrent script
evaluation** — it is not a global lock that serializes everything. In the
shipped builds (which define the `THREADING` compile symbol) each thread that
enters an interpreter gets its **own per-thread execution state**: its own call
stack and call frames, nesting-level counters, and cancellation/error state.
Eagle keeps this in per-thread *engine* and *variable* contexts (`EngineContext`,
`VariableContext`), held in thread-local storage and handed out on demand by the
interpreter's per-thread context manager. The practical result: **multiple
threads can evaluate scripts on the same interpreter at the same time, and script
evaluation and call-frame management are fully concurrent.**

What locks — and therefore *may* be serialized — is access to genuinely
**shared, lockable resources**: global variables, the command/procedure and
object tables, and other shared interpreter state are guarded by the
interpreter's synchronization root. So contention appears only where threads
actually touch the same shared state (e.g. two threads writing the same global
variable), not around evaluation itself. Consequences:

- **You may drive one interpreter from many threads concurrently.** They run
  their own scripts in parallel and only queue behind one another when they
  contend for the same shared resource.
- **Per-thread interpreters remain a good choice for *isolation*** — separate
  global namespaces, no shared-state contention, independent lifetimes — but they
  are not *required* to obtain concurrency. Choose per-thread interpreters for
  isolation, a shared interpreter when threads should see shared state.
- **To abort a script from a different thread**, use the thread-safe
  `Engine.CancelEvaluate` (§13): `CancelFlags.Global` stops every in-flight
  evaluation, `CancelFlags.Local` only the calling thread's. Prefer this over
  reaching into interpreter state directly.
- The interpreter exposes `TryLock` / `ExitLock` so you can hold its lock across
  a compound sequence that must be atomic with respect to other threads — for
  example, a read-modify-write of shared (global) state.

If you implement a custom host, observe the host thread-safety rules in
[interpreter_host.md](interpreter_host.md) (Appendix C): never call back into the
interpreter while holding a host lock, and prefer `TryLock` with a timeout over
an unconditional `Monitor.Enter`.

---

## 15. AppDomain isolation

`Interpreter` derives from `ScriptMarshalByRefObject` (itself a
`MarshalByRefObject`), as do the callback bridges and client-data types. That is
what makes interpreters and their callbacks usable **across AppDomain
boundaries**.

The practical embedder feature built on this is **isolated plugins**: loading a
plugin with `[load -isolated ...]` runs it in its own AppDomain, giving it a
separate security and fault boundary. You interact with an isolated plugin
through a transparent cross-AppDomain proxy, and unloading the AppDomain tears
the plugin down cleanly. This is the mechanism behind per-tenant isolation for
the Enterprise plugins. (Isolation requires the `ISOLATED_PLUGINS` build symbol;
the standard packaged builds include it.) See the [`[load]` reference](load.md)
for flags and lifecycle.

For an embedder, the takeaway: if you must host genuinely untrusted or
crash-prone extension code, combine a **safe interpreter** (§12) with an
**isolated AppDomain** so a failure or escape is contained and disposable.

---

## 16. Deployment and target frameworks

- **Reference:** a single managed assembly, `Eagle.dll`.
- **Package:** `dotnet add package Eagle` (the umbrella meta-package resolves the
  right build for your TFM, per the table in [§2](#2-installation-and-assembly-references)).
- **Supported target frameworks** (from the actual project files):
  - .NET Framework: **2.0** through **4.8.1** (2.0, 3.5, 4.0, 4.5.x, 4.6.x,
    4.7.x, 4.8, 4.8.1).
  - .NET Standard **2.0** and **2.1** — which is how you consume Eagle from
    .NET Core and .NET 5–10.
- **Transitive dependency:** the netstandard builds pull
  `System.Security.Cryptography.Pkcs` (2.0 →`[5.0.1,6.0.0)`, 2.1 →`[7.0.3,8.0.0)`).
- **Native bits are optional.** The CLRv2/CLRv4 packages bundle `Spilornis.dll`
  for native-Tcl integration; pure managed embedding does not need it.

Because Eagle targets down to .NET Framework 2.0, the assembly is broadly
loadable; pick the package/TFM that matches your host application and reference
`Eagle.dll`.

---

## 17. Idiomatic checklist

Do:

- Wrap every `Interpreter` in a `using` block; treat it as owning resources.
- Declare `Result result = null;` and pass `ref result`; check
  `code == ReturnCode.Ok` and read `result` (and `errorLine`) on failure.
- Keep a long-lived interpreter for repeated evaluation; register your commands,
  functions, and objects once, up front.
- Prefer curated **custom commands** over exposing raw `[object]` reflection when
  scripts should call into your application.
- Use a **safe interpreter** plus explicit capability grants (safe-flagged
  commands and/or policies) for untrusted input; add timeouts and limits.
- Evaluate concurrently on one interpreter when you want shared state (evaluation
  is concurrent-capable), or give workers their own interpreter for isolation;
  cancel from another thread via `Engine.CancelEvaluate`.
- Assign a fresh, unique `[ObjectId]` GUID to every custom command/function/host
  class, and make out-of-tree extension classes `public`.

Avoid:

- Reusing an interpreter after its `using` block (throws `ObjectDisposedException`).
- Letting exceptions escape a custom command's `Execute` — catch and convert to a
  `Result`.
- Assuming a shared interpreter must be single-threaded — it need not be; only
  shared-state access (e.g. the same global variable) serializes, not evaluation.
- Exposing `[object]` (or other unsafe commands) to untrusted scripts.
- Assuming Tcl-identical behavior — Eagle is Tcl-*compatible*; verify edge cases.

---

## 18. Further reading

- [Quick Start Guide](quick_start_guide.md) — obtaining Eagle, the shell, and
  language basics.
- [`[object]` command](object.md) — calling .NET from scripts, in depth.
- [`[interp]` command](interp.md) — child interpreters and script-level sandboxing.
- [Safe interpreters](safe.md) — the full safety model and guarantees.
- [`[host]` command](host.md) and [Interpreter Host subsystem](interpreter_host.md)
  — customizing I/O and the host interface hierarchy.
- [`[load]` command](load.md) — plugins, packages, and AppDomain isolation.
- [Integration sub-projects](integrations.md) — real embeddings (MSBuild, WiX,
  PowerShell) as worked examples.
- Sample source: `Eagle/Example/` (minimal host) and `Eagle/Sample/` (commands,
  functions, plugins, policies, hosts, and a WinForms embedding).
