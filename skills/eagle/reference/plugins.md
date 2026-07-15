# Eagle Plugin Ecosystem

Eagle's extensibility mechanism is the **plugin**: a managed .NET assembly
containing one or more classes that implement `IPlugin`. Plugins add commands,
functions, policies, traces, resolvers, hosts, and notification subscribers to
an interpreter — either compiled into the core and loaded at startup, or loaded
on demand with [`load`](commands/objects-dotnet.md). This is *not* Tcl's
`[load]` (which loads native C libraries with a `Tcl_PkgInitProc`); see the
authoritative deep-dive [`../../../load.md`](../../../load.md) for the full loading
pipeline, AppDomain isolation, and the security-verification chain.

The runnable examples below were **executed** against Eagle 1.0
(`info engine version` ⇒ `1.0`, assembly `Version=1.0.9675.37713`) on a Debug
`netcoreapp3.0` build; see [`verification.md`](verification.md). `;# =>` marks a
verified result. The commercial and proprietary plugins require a license
certificate by default (and are now also open source); without one they are not
loadable here, so they are documented from source — their plugin classes, flags,
and directories — rather than from runtime output.

> Eagle reports `info patchlevel` ⇒ `8.4.21` (its Tcl-compatibility level); the
> *engine* version is separate: `info engine` ⇒ `Eagle`, `info engine version`
> ⇒ `1.0`. Don't confuse the two.

---

## Built-in / system plugins (compiled into the core)

Source: `eagle/Eagle/Library/Plugins/`. These are created by the interpreter's
`SetupPlugins()` during construction (flag `PluginFlags.Static`), not via
`[load]`. The class hierarchy:

```
Default (public base for ALL plugins)
 ├── Core   (primary system plugin)
 ├── Test   (plugin-subsystem test plugin)
 └── Notify (notification base)
      ├── Object (object-handle reference tracking)
      └── Trace  (abstract; runtime-tunable field base)
           └── Monitor (engine-execution monitor)
```

| Plugin | File | One-line purpose |
|--------|------|------------------|
| **Default** | `Default.cs` | Base `IPlugin` implementation: standard command/policy/function/trace management. Almost every plugin (built-in and external) derives from it; it is *not* itself registered as a loaded plugin. |
| **Core** | `Core.cs` | The primary system plugin: adds the built-in (core) command set and function library, and serves the core assembly's embedded resources, framework info, and localized strings. Always present unless `CreateFlags.NoCorePlugin`. |
| **Object** | `Object.cs` | System plugin that tracks reference counts of opaque .NET object handles held in interpreter variables; on call-frame pop/delete it adjusts those counts so objects are cleaned up. Subscribes to `NotifyType.CallFrame` (`Popped`/`Deleted`). |
| **Notify** | `Notify.cs` | Base class for plugins that receive engine notifications; registers the plugin's notify types/flags on `Initialize()` and removes them on `Terminate()`. Not registered directly. |
| **Trace** | `Trace.cs` | Abstract base for plugins exposing named instance fields that can be read/written at run-time via the request mechanism. Not registered directly. |
| **Monitor** | `Monitor.cs` | Diagnostic plugin that monitors engine execution: on each `NotifyType.Engine`/`Executed` notification it formats the arguments and result and writes them to the tracing subsystem. **Not loaded by default** (guarded by `NOTIFY && NOTIFY_ARGUMENTS` and off via its defaults / `CreateFlags.NoMonitorPlugin`). |
| **Test** | `Test.cs` | Exercises the plugin subsystem itself: a "nop" command plus switchable `Execute`/`GetStream`/`GetString` implementations. Present only when built with `TEST_PLUGIN \|\| DEBUG`. |

**Verified — what is actually loaded in a default session.** `[info loaded]`
returns one entry per registered plugin, each a `{fileName {typeName,
assembly, version, culture, publicKeyToken}}` pair:

```tcl
foreach p [info loaded] {puts [lindex [split [lindex $p 1] ,] 0]}
;# => Eagle._Plugins.Core
;#    Eagle._Plugins.Object
;#    Eagle._Plugins.Test
puts [llength [info loaded]]                      ;# => 3
```

So this Debug build loads **Core, Object, and Test**. `Test` appears because
this is a debug build; a release build without `TEST_PLUGIN` would omit it.
`Monitor` is *not* loaded by default, and `Notify`/`Trace`/`Default` are base
classes that are never registered on their own. The full entry carries the
assembly identity:

```tcl
puts [lindex [info loaded] 0]
;# => .../Eagle.dll {Eagle._Plugins.Core, Eagle, Version=1.0.9675.37713,
;#    Culture=neutral, PublicKeyToken=645d697a1b3acac5}
```

(All three plugins live in the single core `Eagle.dll`.)

---

## Enterprise / commercial plugins

Source: `eagle/Eagle/Plugins/Commercial/Enterprise/`. Each is a separate
assembly carrying at least `PluginFlags.Primary | User | Commercial`, and each
**verifies a license certificate during `Initialize()`** (via
`GetCertificateFileName()` / `GetCertificate()` and `LicenseOps`-style
verification). Without a valid license certificate — the `certificate.exml` /
`keyRing.License.*` material that ships beside the sources — `Initialize()`
fails and the partially-loaded plugin is rolled back. These plugins require a
license certificate by default but are now also open source, and are therefore
**documented from source**, not from runtime output.

**Command references** (canonical, in the docs root — how to actually *use* each
plugin's commands): Harpy → [`../../../harpy.md`](../../../harpy.md) · Badge →
[`../../../badge.md`](../../../badge.md) · Kapok → [`../../../kapok.md`](../../../kapok.md) ·
Zeus → [`../../../zeus.md`](../../../zeus.md) · Demo → [`../../../demo.md`](../../../demo.md) ·
HotKey → [`../../../hotKey.md`](../../../hotKey.md). (Aquila and Featherlight have
no dedicated command doc yet.)

| Plugin | Directory | One-line purpose |
|--------|-----------|------------------|
| **Harpy** | `Enterprise/Harpy/` | Licensing **and** script signing/security: verifies license certificates, loads configuration, and exposes the licensing/certificate services the rest of the suite (and Eagle's script-signing) depends on. A single assembly with tiered plugin classes — `Licensing.Plugins.Default`, `Licensing.Core`, `Licensing.Standard`, `Licensing.Enterprise` — with `PluginFlags.Primary` selecting the tier loaded by default. |
| **Badge** | `Enterprise/Badge/` | Certificate management and embedded-resource string handling; registers the `badge` command (most behavior inherited from its `Default` plugin). |
| **HotKey** | `Enterprise/HotKey/` | Global hot-key manager: starts/stops a dedicated hot-key manager thread, registers template packages, and adds the `hotkey` command. Flags include `NativeCode` (P/Invoke to the Win32 hot-key API) and `UserInterface`; requires an interpreter with Eagle threading. |
| **Zeus** | `Enterprise/Zeus/` | Cryptographic utilities: registers the `zeus` command, performs RFC 2898 (PBKDF2) string encryption/decryption, transparently decrypts its own resource strings, swaps in an enhanced `pi` math function, and backs a procedure-obfuscation feature. |
| **Demo** | `Enterprise/Demo/` | Host-replacement demonstration: installs a demo host that replays a script as simulated interactive input (`PluginFlags.Host`), restoring the original host on `Terminate()`. |
| **Featherlight** | `Enterprise/Featherlight/` | WPF-backed windowed interpreter-host environment: on init it launches a dedicated interactive UI thread running the windowed shell and registers a new-host callback; on term it shuts the shell down (`Host \| UserInterface`). |
| **Aquila** | `Enterprise/Aquila/` | Example/skeleton Enterprise plugin — a template for writing new plugins; verifies its license certificate when licensing is enabled. |
| **Kapok** | `Enterprise/Kapok/` | Data/configuration management: registers the `kapok` command and verifies its license certificate when licensing is enabled. |

**Verified — Kapok is deployed but still needs a license.** Of the enterprise
plugins, only `Kapok.dll` (plus `Kapok.pdb`/`Kapok.xml`) is copied into the
build output beside `Eagle.dll`, so it is the one `[load]` can even *reach*.
Attempting it shows the licensing gate firing — the assembly loads and the
plugin instantiates, but `Initialize()` fails inside Harpy's certificate
verification:

```tcl
set rc [catch {load .../Kapok.dll} m]; puts "rc=$rc"
;# => rc=1
;# m begins: caught exception while initializing plugin: ...
;#   ...CertificateSharedOps.VerifyHashRsa(...) ...
;#   Licensing.Plugins.Default.Initialize(...)
```

(On this macOS/.NET Core build the RSA verification surfaces as an
`AppleCrypto` error; on a properly licensed Windows install it would verify the
certificate instead. Either way, the takeaway is the same: the commercial
license check runs at `Initialize()` and gates the load.)

---

## Proprietary plugins

Source: `eagle/Eagle/Plugins/Proprietary/Vadium/`. These proprietary plugins
(now largely obsolete) also require a license certificate by default, but are
now open source as well.

| Plugin | Directory | One-line purpose |
|--------|-----------|------------------|
| **Vadium / AlphaCipher** | `Proprietary/Vadium/AlphaCipher/` | One-time-pad cryptography: provides the `otp3` and `otp4` cipher commands and the `random` command, together with their safe-interpreter policies (plugin class `AlphaCipher` in `Plugins/Cryptography.cs`). |
| **Vadium / KeyPair** | `Proprietary/Vadium/KeyPair/` | The "Peyote" key-pair generator: a WPF-based key-generation UI; loading it into the primary interpreter starts a dedicated thread hosting the WPF app and windows, and unloading shuts that thread down (plugin class in `Plugins/Generator.cs`). |

---

## Loading and unloading plugins

`[load]` and `[unload]` manage on-demand (`PluginFlags.Demand`) plugins. Full
syntax, every option, and the verification internals are in
[`../../../load.md`](../../../load.md); command-level coverage of `[load]`/`[unload]`
and `[object]` is in [`commands/objects-dotnet.md`](commands/objects-dotnet.md).
The essentials:

```tcl
load ?options? fileName ?typeName? ?interp?      ;# discover & register a plugin
unload ?options? fileName ?typeName? ?interp?    ;# terminate & remove it
```

- **Discovery** — with no `typeName`, the loader reflects over the assembly,
  finds the `IPlugin` type marked `PluginFlags.Primary` (skipping the `Default`
  base and wrappers), and instantiates it. Multi-tier assemblies (e.g. Harpy)
  use `Primary` to pick the default class.
- **Security verification** — `-verifiedonly` requires a valid **strong-name**
  signature; `-trustedonly` requires a valid **Authenticode** signature;
  `-publickeytoken <hex>` pins the signer's public key token. Verification is
  fail-closed (any error ⇒ "not verified") and runs *before* any plugin code
  executes. (`-maybeverifiedonly`/`-maybetrustedonly` are the only such
  options allowed in safe interpreters; they exist for the core's internal
  loader.)
- **Isolation** — `-isolated` loads the plugin into a separate AppDomain
  (requires the `ISOLATED_PLUGINS` build) for fault/type isolation and true
  unloadability.
- **Selective registration** — `-nocommands` / `-nofunctions` / `-nopolicies`
  / `-notraces` / `-noprovide` suppress categories; `-ruleset` filters which
  commands/policies are included, excluded, hidden, or shown.

**`[load]`/`[unload]` are unsafe commands** — they carry `CommandFlags.Unsafe`
and cannot be called from a safe interpreter:

```tcl
interp create -safe kid
puts [catch {interp eval kid {load /tmp/x.dll}} m]:$m
;# => 1:permission denied: safe interpreter cannot use command "load"
```

A bad path is rejected before anything loads, and unloading something that was
never loaded is an error:

```tcl
puts [catch {load /tmp/does-not-exist.dll} m]:$m
;# => 1:invalid assembly file name
puts [catch {unload /tmp/notloaded.dll} m]:$m
;# => 1:file "/tmp/notloaded.dll" has never been loaded
```

`[info loaded ?interp? ?pattern?]` is the introspection entry point (shown
above). For the broader `PluginFlags` taxonomy — classification
(`System`/`User`/`Commercial`/`Proprietary`/`Static`/`Demand`), feature
(`Command`/`Function`/`Policy`/`Host`/`UserInterface`/`NativeCode`/…),
suppression (`No*`), and security (`VerifiedOnly`/`TrustedOnly`/`Isolated`/…) —
see [`../../../load.md`](../../../load.md) §4.2.
