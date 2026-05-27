# Eagle `[load]` / `[unload]` Commands: Deep-Dive Analysis of Plugin Loading

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[load]` and `[unload]` command internals, including the plugin loading infrastructure, security verification chain, AppDomain isolation, built-in plugins, and enterprise plugins. For basic command syntax and options, see [`core_language.md`](core_language.md#cmd-load) and [`core_language.md`](core_language.md#cmd-unload). For usage examples, see [`core_examples.md`](core_examples.md#ex-load). For the interpreter security model, see [`interp.md`](interp.md). For the native library FFI system, see [`library.md`](library.md).

## 1. Executive Summary

Eagle's `[load]` and `[unload]` commands manage **.NET assembly-based
plugins** — compiled extensions that add commands, functions, policies,
traces, and other capabilities to the interpreter at runtime. This is
fundamentally different from native Tcl's `[load]`, which loads C shared
libraries containing `Tcl_PkgInitProc` initialization functions. Eagle
plugins are managed .NET assemblies containing classes that implement the
`IPlugin` interface.

The plugin system is Eagle's primary extensibility mechanism. It supports:

- **On-demand loading** of new commands, functions, policies, and traces
  from compiled .NET assemblies
- **AppDomain isolation** for loading plugins into separate security and
  fault boundaries (requires `ISOLATED_PLUGINS` compilation flag)
- **Multi-layer security verification** — strong name validation,
  Authenticode signature checking, public key token verification, and
  policy-based access control
- **Plugin preview** — inspecting plugin metadata in a temporary AppDomain
  before committing to a full load
- **Update checking** — querying for newer plugin versions before loading
- **Resource-based loading** — loading plugins from embedded resources
  rather than files on disk
- **Rule-set filtering** — controlling which commands and policies from a
  plugin are included, excluded, hidden, or shown
- **Enterprise plugin ecosystem** — eight commercial plugins providing
  licensing, certificates, cryptography, UI hosting, and more

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Load.cs` | 485 | `[load]` command implementation |
| `Eagle/Library/Commands/Unload.cs` | 269 | `[unload]` command implementation |
| `Eagle/Library/Components/Public/Interpreter.cs` | 124,855 | LoadPlugin, CreatePlugin, AddPlugin, UnloadPlugin methods |
| `Eagle/Library/Components/Private/RuntimeOps.cs` | 10,304 | Resource-based LoadPlugin, entity population, security checks |
| `Eagle/Library/Components/Private/AppDomainOps.cs` | 3,034 | AppDomain creation, isolation, teardown |
| `Eagle/Library/Components/Private/AssemblyOps.cs` | 1,483 | Assembly analysis, certificate extraction |
| `Eagle/Library/Components/Private/StrongNameOps.cs` | 328 | Strong name verification (CLR) |
| `Eagle/Library/Components/Private/StrongNameDotNet.cs` | 400 | Strong name verification (.NET Core) |
| `Eagle/Library/Components/Private/StrongNameMono.cs` | 194 | Strong name verification (Mono) |
| `Eagle/Library/Components/Private/SecurityOps.cs` | 213 | Trusted/verified plugin status validation |
| `Eagle/Library/Plugins/Default.cs` | ~600 | Base class for all plugins |
| `Eagle/Library/Plugins/Core.cs` | ~500 | Core system plugin |
| `Eagle/Library/Wrappers/Plugin.cs` | ~600 | Cross-AppDomain remoting proxy |
| `Eagle/Library/Interfaces/Public/IPlugin.cs` | 63 | Plugin runtime interface |
| `Eagle/Library/Interfaces/Public/IPluginData.cs` | 111 | Plugin metadata interface |
| `Eagle/Library/Interfaces/Public/IPluginManager.cs` | 185 | Plugin lifecycle interface |

## 2. Why the Load/Unload Commands Exist

### The problem

Scripting languages need extensibility. New commands, custom data types,
specialized I/O handlers, and security policies cannot all be built into the
core interpreter — they need to be loaded on demand from compiled code.

Native Tcl solves this with `[load]`, which loads C shared libraries
containing a `Tcl_PkgInitProc` function that calls `Tcl_CreateCommand` to
register new commands. This works but is limited to native C code and a
flat initialization protocol.

Eagle operates in the .NET/CLR environment and needs a plugin system that:

1. **Loads managed .NET assemblies**, not native C libraries (that role
   is filled by `[library]`)
2. **Discovers plugin types automatically** — finds classes implementing
   `IPlugin` without requiring a known entry-point function name
3. **Supports rich metadata** — plugins carry version information, URIs,
   certificates, and capability flags
4. **Enforces security** — verifying strong names, Authenticode
   signatures, and public key tokens before executing untrusted code
5. **Provides isolation** — loading plugins into separate AppDomains so
   that faults and security compromises are contained
6. **Supports lifecycle management** — initialization, termination,
   resource cleanup, and AppDomain unloading

### Design philosophy

The plugin system follows a **discover → verify → load → populate →
register** pipeline:

```tcl
File/Resource → Assembly → Security Check → Type Discovery → Plugin Instance
    → Entity Population → Interpreter Registration
```

Each stage can reject the plugin. Security verification is front-loaded:
strong name and trust checks happen before any plugin code executes. Entity
population (discovering commands, functions, policies) happens via
reflection on the assembly types, and registration with the interpreter
happens only after all checks pass.

Error handling follows a **rollback-on-failure** model: if any stage fails
after the plugin has been partially loaded, the cleanup path removes the
plugin from the interpreter and unloads any isolated AppDomain.

## 3. Tcl vs. Eagle: A Fundamental Difference

This distinction is critical and often causes confusion:

| Aspect | Tcl `[load]` | Eagle `[load]` |
|--------|-------------|----------------|
| **What it loads** | Native C shared libraries (`.so`, `.dll`) | .NET managed assemblies (`.dll`) |
| **Entry point** | Named `Tcl_PkgInitProc` function | `IPlugin` interface implementation |
| **Discovery** | Explicit function name required | Automatic type discovery via reflection |
| **Security** | None (loads and executes native code) | Multi-layer: strong name, Authenticode, policy |
| **Isolation** | None (same process, same address space) | Optional AppDomain isolation |
| **Metadata** | None | Version, URI, update URI, certificates, flags |
| **Type system** | C function pointers | Full .NET type system, interfaces, attributes |

Eagle's `[library]` command is conceptually closer to Tcl's `[load]` —
both deal with native code — while Eagle's `[load]` has no direct Tcl
equivalent. The closest Tcl concept is `[package require]` combined with
`[load]`, but Eagle's system is architecturally richer.

## 4. Plugin Loading Architecture

### 4.1 The Plugin Interface Hierarchy

Every Eagle plugin implements a chain of interfaces:

```tcl
IPluginData (metadata)
    ├── Name, Description, Group, Tags
    ├── Flags (PluginFlags enumeration)
    ├── Version, Uri, UpdateUri
    ├── AppDomain, Assembly, AssemblyName
    ├── FileName, TypeName, DateTime
    ├── Commands (CommandDataList)
    ├── Policies (PolicyDataList)
    └── Token (registration token)

IPlugin : IPluginData (runtime behavior)
    ├── Initialize(interpreter, clientData, ref result)
    ├── Terminate(interpreter, clientData, ref result)
    ├── PostInitialize(interpreter, clientData, ref result)
    ├── Execute(interpreter, clientData, arguments, ref result)
    ├── GetFramework(interpreter, ref result)
    ├── GetStream(interpreter, name, cultureInfo, ref result)
    ├── GetString(interpreter, name, cultureInfo, ref result)
    ├── GetCertificateFileName(ref result)
    ├── GetCertificate(ref result)
    ├── GetKeyPair(ref result)
    ├── GetKeyRing(ref result)
    ├── GetUri(interpreter, ref result)
    ├── Banner(ref result)
    ├── About(ref result)
    ├── Options(ref result)
    └── Status(ref result)

IPluginManager (interpreter-side lifecycle)
    ├── FindPlugin(name/token, ...)
    ├── LoadPlugin(3 overloads: bytes, AssemblyName, fileName)
    ├── UnloadPlugin(3 overloads: name, plugin, token)
    ├── AddPlugin(plugin, clientData, ref token, ...)
    ├── RemovePlugin(token, clientData, ...)
    ├── AddCommands(plugin, clientData, ...)
    ├── RemoveCommands(plugin, clientData, ...)
    ├── AddPolicies(plugin, clientData, ...)
    └── RemovePolicies(plugin, clientData, ...)
```

### 4.2 The PluginFlags Enumeration

`PluginFlags` is a large flags enumeration that controls every aspect of
plugin classification, behavior, and loading. Key categories:

**Classification flags:**

| Flag | Meaning |
|------|---------|
| `System` | Built-in system plugin (Core, Object, Monitor, Test) |
| `User` | User-supplied plugin |
| `Commercial` | Commercial/licensed plugin |
| `Proprietary` | Proprietary plugin |
| `Primary` | Primary plugin type in multi-type assemblies |
| `Static` | Loaded during interpreter initialization, not on-demand |
| `Demand` | Loaded on-demand via `[load]` command |

**Feature flags:**

| Flag | Meaning |
|------|---------|
| `Command` | Plugin provides commands |
| `Function` | Plugin provides functions |
| `Trace` | Plugin provides variable traces |
| `Notify` | Plugin subscribes to interpreter notifications |
| `Policy` | Plugin provides security policies |
| `Resolver` | Plugin provides command/variable resolvers |
| `Host` | Plugin provides/replaces the interpreter host |
| `Debugger` | Plugin provides debugger functionality |
| `UserInterface` | Plugin provides a user interface |

**Suppression flags:**

| Flag | Meaning |
|------|---------|
| `NoCommands` | Do not populate commands from this plugin |
| `NoFunctions` | Do not populate functions |
| `NoPolicies` | Do not populate policies |
| `NoTraces` | Do not populate traces |
| `NoProvide` | Do not register as a package |
| `NoResources` | Do not process embedded resources |
| `NoGetString` | Do not call GetString on this plugin |
| `MergeCommands` | Merge new commands with existing ones |

**Security and loading flags:**

| Flag | Meaning |
|------|---------|
| `Isolated` | Load in a separate AppDomain |
| `NoPreview` | Skip metadata preview in temporary AppDomain |
| `UpdateCheck` | Check for updates before loading |
| `VerifiedOnly` | Require strong name verification |
| `TrustedOnly` | Require Authenticode signature trust |
| `SkipVerified` | Bypass strong name check |
| `SkipTrusted` | Bypass trust check |
| `VerifyCoreAssembly` | Also verify the core Eagle assembly |
| `LoadOnAnyThread` | Allow loading on non-primary thread |
| `SkipTerminate` | Skip Terminate() during unload |
| `Licensed` | Plugin has been license-verified |

**Code type flags:**

| Flag | Meaning |
|------|---------|
| `UnsafeCode` | Plugin contains unsafe managed code |
| `NativeCode` | Plugin contains native (P/Invoke) code |
| `SafeCommands` | All commands are safe for safe interpreters |

### 4.3 Two Loading Paths

The `[load]` command supports two distinct loading paths controlled by
the `-viaresource` option:

**File-based loading** (default):

```tcl
[load] → Interpreter.LoadPlugin(fileName, ...) → Assembly.LoadFrom(fileName)
```

This is the standard path for loading plugin DLLs from the file system.
It supports file-specific security features like Authenticode signature
verification and hash-based integrity checking.

**Resource-based loading** (`-viaresource`):

```tcl
[load] -viaresource → RuntimeOps.LoadPlugin(resourceName, ...)
    → fileSystemHost.GetData(resourceName)
    → Security verification (via temporary file)
    → AppDomain.Load(bytes, ...)
```

This path loads plugins from embedded resources within the Eagle assembly
itself. The resource name is used to retrieve assembly bytes (and
optional PDB symbol bytes) from the file system host. This is used for
plugins that ship embedded within the Eagle core binary, such as certain
enterprise plugins.

Even though the assembly is loaded from in-memory bytes rather than a
file on disk, Authenticode and strong name signature verification still
applies. The bytes are written to a temporary file so that the same
file-based verification APIs can be used (see §5.5).

### 4.4 Command Flags

The `[load]` and `[unload]` commands themselves carry security-relevant
`CommandFlags`:

| Command | CommandFlags | Meaning |
|---------|-------------|---------|
| `[load]` | `Unsafe \| Critical \| Standard \| SecuritySdk \| LicenseSdk` | Cannot be called from safe interpreters; part of the security and licensing SDK surface |
| `[unload]` | `Unsafe \| Critical \| Standard` | Cannot be called from safe interpreters |

Both commands belong to the `managedEnvironment` object group.

## 5. The Loading Pipeline in Detail

### 5.1 Step 1: Option Parsing and Flag Assembly

The `[load]` command parses its options and assembles a `PluginFlags`
value that controls every subsequent step:

```csharp
// All user-loaded plugins are marked as on-demand
PluginFlags pluginFlags = PluginFlags.Demand;

// Inherit interpreter-level plugin flags
pluginFlags |= childInterpreter.PluginFlags;

// Apply option-driven flags
if (options.IsPresent("-isolated"))    pluginFlags |= PluginFlags.Isolated;
if (options.IsPresent("-noisolated"))  pluginFlags &= ~PluginFlags.Isolated;
if (options.IsPresent("-verifiedonly"))  pluginFlags |= PluginFlags.VerifiedOnly;
if (options.IsPresent("-trustedonly"))   pluginFlags |= PluginFlags.TrustedOnly;
// ... and so on for each option
```

The `-maybeverifiedonly` and `-maybetrustedonly` options are notable:
they are **allowed in safe interpreters** (no `OptionFlags.Unsafe`)
because the core binary plugin loader uses them for loading internal
enterprise plugins like HotKey. In release builds, they behave
identically to `-verifiedonly` and `-trustedonly`; in debug builds, they
are silently ignored to facilitate development.

### 5.2 Step 2: Public Key Token Verification

If `-publickeytoken` is specified, the assembly's public key token is
checked before any loading occurs:

```tcl
load -publickeytoken "a9f3c4d2e1b0..." MyPlugin.dll
```

This provides an early rejection path — the assembly file can be
inspected without loading it into any AppDomain.

### 5.3 Step 3: Policy Check

Before assembly loading begins, the plugin policy system is consulted:

```csharp
CheckPluginPolicies(PolicyFlags.EngineBeforePlugin, ...)
```

This invokes any registered plugin-loading policies. If any policy
returns a negative decision, loading is rejected before the assembly
touches memory.

### 5.4 Step 4: Thread Validation

The system checks `CanPluginBeLoaded(flags)` to ensure plugin loading
is happening on the correct thread. By default, plugins must be loaded
on the primary thread; the `-anythread` option sets
`PluginFlags.LoadOnAnyThread` to bypass this restriction.

### 5.5 Step 5: Security Verification

Two optional security checks run in sequence:

**Strong name verification** (when `PluginFlags.VerifiedOnly` is set):

```tcl
RuntimeOps.IsStrongNameVerified(interpreter, assemblyBytes/fileName)
```

This verifies the assembly's strong name signature using platform-specific
mechanisms:

| Platform | Implementation | Method |
|----------|---------------|--------|
| .NET Framework | P/Invoke to `mscoree.dll` | `StrongNameOps.IsStrongNameVerifiedClr()` |
| .NET Core | Managed implementation | `StrongNameDotNet.IsStrongNameVerifiedDotNet()` |
| Mono | Managed implementation | `StrongNameMono.IsStrongNameVerifiedMono()` |

For byte-loaded assemblies, the bytes are written to a temporary file,
the file is kept open during verification (preventing TOCTOU tampering),
and the bytes are read back and compared against the originals as an
integrity check.

**Authenticode trust verification** (when `PluginFlags.TrustedOnly` is set):

```tcl
RuntimeOps.IsFileTrusted(interpreter, null, assemblyBytes/fileName)
```

This verifies the assembly's Authenticode (code signing) signature:

| Platform | Implementation | Method |
|----------|---------------|--------|
| .NET Framework | WinVerifyTrust API | `WinTrustOps.IsFileTrusted()` |
| .NET Core | Managed implementation with trusted hashes | `WinTrustDotNet.IsFileTrusted()` |
| Mono | Managed implementation | `WinTrustMono.IsFileTrusted()` |

On .NET Core, where the Windows WinVerifyTrust API may not be available,
the system falls back to a trusted hash list — pre-computed hashes of
known-good assemblies.

### 5.6 Step 6: Plugin Preview (Optional)

When `ISOLATED_PLUGINS` is compiled in and `PluginFlags.NoPreview` is
**not** set, the system performs a lightweight preview:

```tcl
RuntimeOps.PreviewPluginFlagsAndUpdateUri()
```

This creates a **temporary AppDomain**, loads the assembly in
reflection-only mode, inspects the plugin's `PluginFlags` attribute and
update URI, then tears down the temporary AppDomain. This allows:

1. **Discovering the plugin's isolation preference** — if the plugin's
   assembly-level `PluginFlags` attribute includes `Isolated`, the system
   automatically loads it into an isolated AppDomain even if
   `-isolated` was not specified
2. **Triggering update checks** — if `PluginFlags.UpdateCheck` is set
   (either from the `-update` option or from the assembly attribute),
   `ShellOps.CheckForUpdate()` is called to query for a newer version

The preview phase runs no plugin code — it only reads attributes.

### 5.7 Step 7: AppDomain Setup

The system calls `AppDomainOps.GetOrCreate()` to obtain the target
AppDomain:

- **Non-isolated plugins**: Use the interpreter's default AppDomain
- **Isolated plugins**: Create a new AppDomain with:
  - `DisallowCodeDownload = true` (prevents runtime code injection)
  - `ApplicationBase` set to the core library directory or plugin
    directory
  - `PrivateBinPath` including both the core assembly and plugin
    directories
  - Optional CAS evidence passed through

### 5.8 Step 8: Assembly Loading

The actual assembly loading is performed by `PluginLoadHelper`, a helper
class that runs inside the target AppDomain via
`AppDomainOps.DoCallBack()`:

**File-based loading methods:**

| Method | When Used | API |
|--------|----------|-----|
| `NoCasLoad1()` | Default (no CAS) | `Assembly.LoadFrom(fileName)` |
| `CasLoad2()` | CAS policy enabled | `Assembly.LoadFrom(fileName, evidence)` |
| `CasLoad4()` | CAS + hash check | `Assembly.LoadFrom(fileName, evidence, hashValue, hashAlgorithm)` |

**Bytes-based loading methods:**

| Method | When Used | API |
|--------|----------|-----|
| `NoCasLoad2()` | Resource loading (no CAS) | `AppDomain.Load(assemblyBytes, symbolBytes)` |
| `CasLoad3()` | Resource loading + CAS | `AppDomain.Load(assemblyBytes, symbolBytes, evidence)` |

After loading, `PluginLoadHelper.Setup()` extracts metadata from the
assembly:

- `AssemblyName` (via `assembly.GetName()`)
- `DateTime` (from PE header or assembly attributes)
- `Uri` and `UpdateUri` (from assembly-level attributes)
- `PluginFlags` (from assembly-level attributes)
- All types (via `assembly.GetTypes()`)

### 5.9 Step 9: Plugin Type Discovery

If no `typeName` was specified (the common case), the system discovers
the plugin type automatically:

```csharp
RuntimeOps.FindPrimaryPlugin(assembly, ...)
```

This process:

1. Calls `assembly.GetTypes()` to get all types in the assembly
2. Filters for types implementing `IPlugin`
   (`RuntimeOps.GetMatchingClassTypes()`)
3. Excludes the `_Plugins.Default` base class
4. Excludes wrapper types (`IWrapper` implementations)
5. Searches for a type with the `PluginFlags.Primary` attribute
6. Returns the first primary plugin type found

For multi-plugin assemblies (like Harpy, which contains Core, Standard,
and Enterprise tiers), the `PluginFlags.Primary` attribute on one class
determines which plugin is loaded by default.

### 5.10 Step 10: Plugin Instantiation

**For non-isolated plugins:**

```csharp
assembly.GetType(typeName, true, false);
Assembly.CreateInstance(typeFullName, false, bindingFlags, null, args, null, null);
```

The plugin constructor receives a single `PluginData` argument containing
the assembly name, URI, update URI, flags, and other metadata.

**For isolated plugins:**

```csharp
AppDomain.CreateInstanceFromAndUnwrap(...)
// or
AppDomain.CreateInstanceAndUnwrap(...)
```

The plugin is instantiated in the isolated AppDomain and a transparent
proxy (MarshalByRefObject) is returned to the calling AppDomain. A
`PluginPropertyHelper` is used to extract properties from the remote
object across the AppDomain boundary.

### 5.11 Step 11: Entity Population

After instantiation, `RuntimeOps.PopulatePluginEntities()` discovers
the commands, functions, and policies provided by the plugin:

**Command population** (`PopulatePluginCommands()`):

1. Finds all types implementing `ICommand` in the plugin assembly
2. Skips types with `CommandFlags.NoPopulate`
3. Applies rule-set filtering:
   - `IncludeRuleSetMask` — type must match to be included
   - `ExcludeRuleSetMask` — type is excluded if it matches
   - `HideRuleSetMask` — converts Safe commands to Unsafe (hidden)
   - `ShowRuleSetMask` — converts Unsafe commands to Safe (exposed)
4. Creates `CommandData` objects and adds them to `plugin.Commands`

**Policy population** (`PopulatePluginPolicies()`):

1. Finds all methods with `MethodFlags.PolicyMask` attributes
2. Filters out methods with `MethodFlags.NoAdd`
3. Applies rule-set filtering
4. Creates `PolicyData` objects and adds them to `plugin.Policies`

**Type population** (`PopulatePluginTypes()`):

Discovers all types in the plugin assembly for later use.

### 5.12 Step 12: Interpreter Registration

After successful loading and entity population, the `[load]` command
calls:

```csharp
childInterpreter.AddPlugin(plugin, localClientData, ref token, ref result);
```

This:

1. Registers the plugin in the interpreter's plugin dictionary
2. Calls the plugin's `Initialize()` method
3. Adds the plugin's commands via `AddCommands()`
4. Adds the plugin's policies via `AddPolicies()`
5. Returns a security token for later reference

### 5.13 Error Handling and Rollback

If any step fails after partial loading, the cleanup sequence runs:

```csharp
finally
{
    if (code != ReturnCode.Ok)
    {
        if (token != 0)
        {
            // Terminate and remove the plugin (does not unload AppDomain)
            childInterpreter.RemovePlugin(token, localClientData, ref removeResult);
        }

        if (plugin != null)
        {
            // Unload the plugin — for isolated plugins, this unloads
            // the AppDomain; for non-isolated, this is essentially a no-op
            childInterpreter.UnloadPlugin(
                plugin, localClientData,
                pluginFlags | PluginFlags.SkipTerminate, ref unloadResult);
        }
    }
}
```

Note the `PluginFlags.SkipTerminate` flag — since plugin initialization
may not have completed, the cleanup skips the `Terminate()` call to
avoid calling lifecycle methods on a partially-initialized plugin.

## 6. AppDomain Isolation

### 6.1 Why Isolation Matters

AppDomain isolation provides three critical guarantees:

1. **Fault isolation** — if a plugin crashes, the isolated AppDomain can
   be unloaded without affecting the host interpreter
2. **Type isolation** — plugins can use different versions of the same
   assembly without type conflicts
3. **Unloadability** — isolated AppDomains can be fully unloaded,
   reclaiming all memory (a capability not available for assemblies
   loaded into the default AppDomain)

### 6.2 AppDomain Configuration

When `PluginFlags.Isolated` is set, `AppDomainOps.GetOrCreate()` creates
a new AppDomain with this configuration:

```csharp
AppDomainSetup setup = new AppDomainSetup();
setup.DisallowCodeDownload = true;      // Prevent dynamic code downloads
setup.ApplicationBase = coreDirectory;   // Base directory for assembly resolution
setup.PrivateBinPath = pluginDirectory;  // Additional search path
```

Key properties:

- **DisallowCodeDownload = true** — prevents the AppDomain from
  downloading code from remote locations at runtime, closing a potential
  code injection vector
- **ApplicationBase** — set to the parent directory of the core Eagle
  library, enabling the plugin to resolve Eagle's own assemblies
- **PrivateBinPath** — set to the plugin's directory, enabling the
  plugin to resolve its own dependencies

### 6.3 Cross-Domain Communication

Plugins loaded into isolated AppDomains communicate with the interpreter
through .NET remoting transparent proxies. The `Plugin` wrapper class
(`Eagle/Library/Wrappers/Plugin.cs`) acts as the proxy:

```tcl
[Host AppDomain]                    [Isolated AppDomain]

Interpreter ──→ Plugin (wrapper)    Actual IPlugin implementation
                    │                       ↑
                    └── transparent proxy ──┘
                    (MarshalByRefObject)
```

All `IPlugin` method calls on the wrapper are forwarded across the
AppDomain boundary via .NET remoting. The system detects transparent
proxies using `RemotingServices.IsTransparentProxy()`.

### 6.4 AppDomain Unloading

When a plugin is unloaded, its isolated AppDomain is torn down:

1. `AppDomainOps.MarkPendingUnload(appDomain)` marks the domain
2. `AppDomain.Unload()` is called
3. If unloading fails (e.g., threads still running in the domain):
   - Retries up to 3 times (configurable via `UnloadRetryLimit`)
   - Forces garbage collection between retries
   - Catches `CannotUnloadAppDomainException`
4. Handles edge cases:
   - `RemotingException` (Mono compatibility)
   - `AppDomainUnloadedException` (already unloaded)

## 7. The Unloading Pipeline

The `[unload]` command reverses the loading process:

### 7.1 Plugin Lookup

The command iterates all loaded plugins and matches by file name and
optional type name:

```csharp
foreach (string name in childInterpreter.CopyPluginKeys())
{
    IPluginData pluginData = childInterpreter.GetPluginData(name);

    if (pluginData != null)
    {
        // Match by file path (case-insensitive path comparison)
        if (PathOps.IsSameFile(interpreter, pluginData.FileName, fileName))
        {
            // If typeName given, match by type name or plugin name
            if (String.IsNullOrEmpty(typeName) ||
                StringOps.Match(interpreter, mode, pluginData.TypeName, typeName, noCase) ||
                StringOps.Match(interpreter, mode, pluginData.Name, typeName, noCase))
            {
                code = childInterpreter.UnloadPlugin(name, localClientData, pluginFlags, ref result);
                break;  // Only unload first match
            }
        }
    }
}
```

Key behaviors:

- **Single-plugin unloading** — only the first matching plugin is
  unloaded (the loop breaks after the first match)
- **Path comparison** — uses `PathOps.IsSameFile()` for
  platform-appropriate path comparison
- **Flexible matching** — matches against both `TypeName` and `Name`
  properties, using configurable `MatchMode`
- **Demand flag** — the `PluginFlags.Demand` flag is always set for
  unload operations (only on-demand plugins can be unloaded via `[unload]`)

### 7.2 Unload Options

| Option | Effect |
|--------|--------|
| `-keeplibrary` | Keep the assembly loaded but remove the plugin package |
| `-nocomplain` | Suppress error if plugin not found |
| `-nocase` | Case-insensitive type name matching |
| `-match <MatchMode>` | Pattern matching mode (default: `DefaultUnloadMatchMode`) |
| `-clientdata <object>` | Custom client data for the unload operation |
| `-data <object>` | Additional data to wrap with client data |

### 7.3 The UnloadPlugin Method

The interpreter's `UnloadPlugin` method performs:

1. Calls the plugin's `Terminate()` method (unless `SkipTerminate` is set)
2. Removes the plugin's commands via `RemoveCommands()`
3. Removes the plugin's policies via `RemovePolicies()`
4. Removes the plugin from the interpreter's plugin dictionary
5. For isolated plugins, unloads the AppDomain

## 8. Built-in Plugins

Eagle ships with several built-in plugins that are loaded during
interpreter initialization rather than via the `[load]` command. These
use `PluginFlags.Static` (not `Demand`) and are created by the
`SetupPlugins()` method during interpreter construction.

### 8.1 Core Plugin

| Property | Value |
|----------|-------|
| **Class** | `Eagle._Plugins.Core` (sealed) |
| **Base** | `Default` |
| **Flags** | `Primary \| System \| Host \| Debugger \| Command \| Function \| Trace \| Policy \| Resolver \| Static \| MergeCommands \| NoPolicies \| NoTraces` |
| **Always loaded?** | Yes (unless `CreateFlags.NoCorePlugin`) |
| **Purpose** | Primary system plugin; adds the core command set to the interpreter |

The Core plugin is the foundation of every Eagle interpreter. It provides
the full set of built-in commands (set, if, while, proc, etc.), the
core function library, and framework resource streaming. It is always
loaded first during interpreter initialization and cannot normally be
skipped.

Restorable via `Interpreter.RestoreCorePlugin()`.

### 8.2 Object Plugin

| Property | Value |
|----------|-------|
| **Class** | `Eagle._Plugins.Object` (sealed) |
| **Base** | `Notify` |
| **Flags** | `System \| Notify \| Static \| NoCommands \| NoFunctions \| NoPolicies \| NoTraces` |
| **Always loaded?** | Conditional (`NOTIFY \|\| NOTIFY_OBJECT` compilation flag) |
| **Purpose** | Object reference cleanup; monitors call frame destruction |

The Object plugin subscribes to `NotifyType.CallFrame` notifications
(specifically `Popped` and `Deleted` events). When a call frame is
destroyed, it adjusts reference counts for .NET objects held in
variables within that frame, preventing object leaks.

Disabled with `CreateFlags.NoObjectPlugin`.

### 8.3 Monitor Plugin

| Property | Value |
|----------|-------|
| **Class** | `Eagle._Plugins.Monitor` (sealed) |
| **Base** | `Trace` → `Notify` → `Default` |
| **Flags** | `System \| Notify \| Static \| NoCommands \| NoFunctions \| NoPolicies \| NoTraces` |
| **Always loaded?** | Conditional (`NOTIFY && NOTIFY_ARGUMENTS` compilation flags) |
| **Purpose** | Engine execution tracing; logs command execution with configurable formatting |

The Monitor plugin subscribes to `NotifyType.Engine` / `NotifyFlags.Executed`
notifications. When enabled, it logs every command execution with
configurable formatting, normalization, and ellipsis options. Useful for
debugging and profiling.

Disabled with `CreateFlags.NoMonitorPlugin`. Restorable via
`Interpreter.RestoreMonitorPlugin()`.

### 8.4 Test Plugin

| Property | Value |
|----------|-------|
| **Class** | `Eagle._Plugins.Test` (sealed) |
| **Base** | `Default` |
| **Flags** | `System \| Command \| Static \| MergeCommands \| Test` |
| **Always loaded?** | Conditional (`TEST_PLUGIN \|\| DEBUG` compilation flag) |
| **Purpose** | Test infrastructure; provides test nop command and plugin request execution testing |

The Test plugin provides a test "nop" command and supports custom
`Execute`, `GetStream`, and `GetString` request handling for testing
the plugin infrastructure itself.

Disabled with `CreateFlags.NoTestPlugin`.

### 8.5 Plugin Class Hierarchy

```tcl
_Plugins.Default (base class for all plugins)
    ├── _Plugins.Core (core system plugin)
    ├── _Plugins.Test (test plugin)
    └── _Plugins.Notify (notification infrastructure)
            ├── _Plugins.Object (object reference tracking)
            └── _Plugins.Trace (abstract, execution tracing)
                    └── _Plugins.Monitor (execution monitor)
```

## 9. Enterprise Plugins

Eagle includes eight enterprise plugins in the
`Eagle/Plugins/Commercial/Enterprise/` directory. These are commercial,
licensed plugins that demonstrate the full capabilities of the plugin
loading system.

### 9.1 Harpy — Licensing and Certificate Management

| Property | Value |
|----------|-------|
| **Directory** | `Enterprise/Harpy/` |
| **Plugin classes** | `Licensing.Plugins.Default`, `Licensing.Core`, `Licensing.Standard`, `Licensing.Enterprise` |
| **Key flags** | `Primary \| User \| Commercial \| Command \| MergeCommands \| NoFunctions \| NoTraces \| NoGetString` |
| **Purpose** | Licensing infrastructure with tiered access (Core, Standard, Enterprise) |

Harpy is the licensing and certificate management plugin. It provides:

- Certificate verification and management
- License agreement handling
- Resource string lookup (embedded and package-relative)
- Override string management via dictionary
- Tiered licensing with feature gating

The multi-class design (`Core`, `Standard`, `Enterprise`) demonstrates
how a single assembly can contain multiple plugin tiers, with
`PluginFlags.Primary` marking which class is loaded by default. Each
tier supports increasingly restrictive license requirements.

### 9.2 Badge — Certificate and String Management

| Property | Value |
|----------|-------|
| **Directory** | `Enterprise/Badge/` |
| **Plugin classes** | `Badge.Plugins.Default`, `Badge.Enterprise`, `Security.Certificates` |
| **Key flags** | `Primary \| User \| Commercial \| Command \| MergeCommands \| NoFunctions \| NoPolicies \| NoTraces` |
| **Purpose** | Certificate management and embedded resource string handling |

Badge provides certificate management and string operations:

- `enable` / `clearstrings` / `getstring` / `liststrings`
- `removestring` / `setstring` / `nullstring` / `resetstring` / `renullstring`

The `Security.Certificates` sub-plugin may include
`PluginFlags.IsolatedOnly` and `PluginFlags.UpdateCheck`, demonstrating
how plugins can enforce their own isolation and update requirements via
assembly-level attributes.

### 9.3 HotKey — Global Hotkey Manager

| Property | Value |
|----------|-------|
| **Directory** | `Enterprise/HotKey/` |
| **Plugin class** | `HotKey.Enterprise` (sealed) |
| **Key flags** | `Primary \| User \| Commercial \| Command \| NativeCode \| MergeCommands \| UserInterface \| NoFunctions \| NoTraces` |
| **Implements** | `IStarted` |
| **Purpose** | Global hotkey management with a dedicated manager UI thread |

HotKey demonstrates several advanced plugin features:

- **NativeCode flag** — indicates the plugin uses P/Invoke for global
  hotkey registration (Windows API)
- **UserInterface flag** — indicates the plugin creates UI elements
- **IStarted interface** — the plugin manages its own thread lifecycle
- **Safe interpreter loading** — the core binary plugin loader uses
  `-maybeverifiedonly` and `-maybetrustedonly` to load HotKey even from
  safe interpreters, which is why those options lack the `Unsafe`
  option flag

The plugin starts a dedicated hotkey manager form thread, handles
template packages, and evaluates startup scripts.

### 9.4 Zeus — Cryptographic Utilities

| Property | Value |
|----------|-------|
| **Directory** | `Enterprise/Zeus/` |
| **Plugin class** | `Zeus.Enterprise` (sealed) |
| **Key flags** | `Primary \| User \| Commercial \| NoFunctions \| NoPolicies \| NoTraces` |
| **Implements** | `IRfc2898DataManager` |
| **Purpose** | RFC 2898 PBKDF2 encryption/decryption and custom mathematical functions |

Zeus provides:

- RFC 2898 PBKDF2 key derivation management
- String encryption/decryption capabilities
- Self-decryption mechanism with base64 detection
- Custom `pi()` mathematical function (.NET 4.0+)
- Configurable hash algorithm, password, salt, and iteration count
  (default: 100,000 iterations)

### 9.5 Demo — Host Replacement

| Property | Value |
|----------|-------|
| **Directory** | `Enterprise/Demo/` |
| **Plugin class** | `Demo.Enterprise` (sealed) |
| **Key flags** | `Primary \| User \| Commercial \| Host \| NoFunctions \| NoPolicies \| NoTraces` |
| **Implements** | `IDemoPlugin`, `IDisposable` |
| **Purpose** | Demonstrates host replacement — swaps the interpreter's host at plugin load time |

The Demo plugin illustrates the `PluginFlags.Host` pattern:

- At `Initialize()`, it saves the current interpreter host and replaces
  it with a demo host
- At `Terminate()`, it restores the original host
- Supports `Console` and `Wrapper` host types
- Thread-safe with lock-based synchronization
- Proper `IDisposable` cleanup

### 9.6 Featherlight — Interactive Shell Environment

| Property | Value |
|----------|-------|
| **Directory** | `Enterprise/Featherlight/` |
| **Plugin class** | `Featherlight.Environment` (sealed) |
| **Key flags** | `Primary \| User \| Commercial \| Host \| UserInterface \| NoCommands \| NoFunctions \| NoPolicies \| NoTraces` |
| **Implements** | `IDisposable` |
| **Purpose** | Interactive shell/UI environment with dedicated UI thread management |

Featherlight demonstrates advanced plugin lifecycle:

- Creates and manages an interactive UI thread
- Validates threading support during initialization
- Graceful shutdown via `Featherlight.Shell.Window.Shutdown()`
- `IDisposable` pattern with proper cleanup on termination

### 9.7 Kapok — Data/Configuration Management

| Property | Value |
|----------|-------|
| **Directory** | `Enterprise/Kapok/` |
| **Plugin class** | `Kapok.Enterprise` (sealed) |
| **Key flags** | `Primary \| User \| Commercial \| NoFunctions \| NoPolicies \| NoTraces` |
| **Purpose** | Data and configuration management with licensing infrastructure |

Kapok provides certificate-based licensing and extensible data management
via `Kapok.Components` and `Kapok.Components.Shared`.

### 9.8 Common Enterprise Plugin Patterns

All enterprise plugins follow these conventions:

**Licensing integration:**
Every enterprise plugin verifies its license certificate during
`Initialize()`:

```csharp
// Retrieve certificate file
GetCertificateFileName(ref result);

// Get the certificate object
GetCertificate(ref result);

// Verify the certificate
LicenseOps.VerifyCertificate(...);
```

**PluginFlags conventions:**
- All use at least `Primary | User | Commercial`
- Most suppress unused features: `NoFunctions | NoTraces`
- Host-providing plugins add `Host` (Demo, Featherlight)
- UI-creating plugins add `UserInterface` (HotKey, Featherlight)
- Plugins with native interop add `NativeCode` (HotKey)

**Initialize/Terminate lifecycle:**
- `Initialize()` — set up resources, verify certificates, start threads
- `Terminate()` — clean up resources, stop threads, clear certificates

**GetString interface:**
Many plugins implement `GetString()` to return resource strings from
embedded assembly resources, with optional package-relative path
translation and encrypted string transformation.

## 10. Complete `[load]` Options Reference

```tcl
load ?options? fileName ?packageName? ?interp?
```

| Option | Flags | Description |
|--------|-------|-------------|
| `-ruleset <ruleSet>` | Unsafe | Specify an `IRuleSet` to filter which commands/policies are included, excluded, hidden, or shown |
| `-needclientdata` | Unsafe | Ensure a `ClientData` object exists (create one if needed) |
| `-anythread` | Unsafe | Allow loading on any thread (not just the primary thread) |
| `-nocommands` | Unsafe | Do not add any commands from the plugin |
| `-nofunctions` | Unsafe | Do not add any functions from the plugin |
| `-nopolicies` | Unsafe | Do not add any policies from the plugin |
| `-notraces` | Unsafe | Do not add any traces from the plugin |
| `-noprovide` | Unsafe | Do not register the plugin as a package |
| `-noresources` | Unsafe | Do not process embedded resources from the plugin |
| `-verifiedonly` | Unsafe | Require strong name signature verification |
| `-maybeverifiedonly` | *(none)* | Like `-verifiedonly` but allowed in safe interpreters (release builds only) |
| `-trustedonly` | Unsafe | Require Authenticode signature trust verification |
| `-maybetrustedonly` | *(none)* | Like `-trustedonly` but allowed in safe interpreters (release builds only) |
| `-publickeytoken <hex>` | Unsafe, MustHaveValue | Require matching public key token |
| `-isolated` | Unsafe | Load plugin in a separate AppDomain (requires `ISOLATED_PLUGINS`) |
| `-noisolated` | Unsafe | Explicitly prevent AppDomain isolation |
| `-preview` | Unsafe | Enable plugin metadata preview (requires `ISOLATED_PLUGINS`) |
| `-nopreview` | Unsafe | Disable plugin metadata preview |
| `-update` | Unsafe | Check for plugin updates before loading (requires `ISOLATED_PLUGINS` and `SHELL`) |
| `-noupdate` | Unsafe | Disable plugin update checking |
| `-clientdata <object>` | MustHaveObjectValue | Custom client data to pass to the plugin |
| `-data <object>` | MustHaveObjectValue | Additional data to wrap with client data |
| `-viaresource` | *(none)* | Load from an embedded resource instead of a file |
| `--` | | End of options |

**Positional arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `fileName` | Yes | Path to the plugin assembly (or resource name with `-viaresource`) |
| `packageName` | No | Type name of the plugin class (auto-discovered if omitted) |
| `[interp]` | No | Target interpreter path (defaults to current) |

## 11. Complete `[unload]` Options Reference

```tcl
unload ?options? fileName ?packageName? ?interp?
```

| Option | Description |
|--------|-------------|
| `-keeplibrary` | Keep the assembly loaded but remove the plugin package |
| `-nocomplain` | Suppress error if the plugin was never loaded |
| `-nocase` | Case-insensitive type/plugin name matching |
| `-match <MatchMode>` | Pattern matching mode for type/name comparison (default: `DefaultUnloadMatchMode`) |
| `-clientdata <object>` | Custom client data for the unload operation |
| `-data <object>` | Additional data to wrap with client data |
| `--` | End of options |

**Positional arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `fileName` | Yes | Path to the plugin assembly to unload |
| `packageName` | No | Type name or plugin name to match (if assembly contains multiple plugins) |
| `[interp]` | No | Target interpreter path (defaults to current) |

## 12. Practical Patterns

### Pattern 1: Basic Plugin Loading

```tcl
# Load a plugin from a DLL file (type auto-discovered)
load /path/to/MyPlugin.dll

# Load a specific plugin type from a multi-plugin assembly
load /path/to/MultiPlugin.dll MyNamespace.SpecificPlugin

# Load into a child interpreter
load /path/to/MyPlugin.dll {} {child}
```

### Pattern 2: Security-Verified Loading

```tcl
# Require strong name verification
load -verifiedonly /path/to/SignedPlugin.dll

# Require Authenticode trust
load -trustedonly /path/to/TrustedPlugin.dll

# Require both strong name and Authenticode
load -verifiedonly -trustedonly /path/to/SecurePlugin.dll

# Require specific public key token
load -publickeytoken "a9f3c4d2e1b0c7f8" /path/to/KnownPlugin.dll
```

### Pattern 3: Isolated Plugin Loading

```tcl
# Load into a separate AppDomain for fault isolation
load -isolated /path/to/UntrustedPlugin.dll

# Load with preview (inspect metadata before committing)
load -isolated -preview /path/to/Plugin.dll

# Load with update check
load -isolated -update /path/to/Plugin.dll
```

### Pattern 4: Selective Entity Loading

```tcl
# Load only commands (no functions, policies, or traces)
load -nofunctions -nopolicies -notraces /path/to/Plugin.dll

# Load only policies (security-only plugin)
load -nocommands -nofunctions -notraces /path/to/SecurityPlugin.dll

# Load with a rule set to filter commands
load -ruleset $myRuleSet /path/to/Plugin.dll

# Load but don't register as a package
load -noprovide /path/to/Plugin.dll
```

### Pattern 5: Resource-Based Loading

```tcl
# Load from embedded resource (used internally for enterprise plugins)
load -viaresource "MyPlugin.dll.compressed"
```

### Pattern 6: Plugin Unloading

```tcl
# Unload a plugin by file path
unload /path/to/MyPlugin.dll

# Unload a specific plugin type from a multi-plugin assembly
unload /path/to/MultiPlugin.dll MyNamespace.SpecificPlugin

# Unload without errors if not loaded
unload -nocomplain /path/to/MaybeLoadedPlugin.dll

# Unload with case-insensitive matching
unload -nocase /path/to/Plugin.dll myplugin

# Unload with glob-pattern matching
unload -match Glob /path/to/Plugin.dll *Enterprise*
```

### Pattern 7: Plugin Lifecycle Management

```tcl
# Load a plugin, use it, then clean up
load /path/to/DataPlugin.dll

# ... use the plugin's commands ...
dataPlugin connect "server=localhost;database=test"
dataPlugin query "SELECT * FROM users"

# Unload when done
unload /path/to/DataPlugin.dll
```

### Pattern 8: Loading Plugins with Custom Data

```tcl
# Create a configuration object
set config [object create -alias MyConfig]
$config SetProperty ConnectionString "server=prod;database=app"

# Pass configuration to the plugin during loading
load -clientdata $config /path/to/DatabasePlugin.dll

# Or wrap additional data
load -data $config /path/to/DatabasePlugin.dll
```

## 13. Comparisons to Other Languages

### C# Assembly Loading

Eagle's plugin loading system is architecturally similar to .NET's
`Assembly.LoadFrom()` but adds:

- Automatic type discovery (vs. requiring explicit type names)
- Policy-based access control before loading
- Strong name and Authenticode verification integrated into the loading
  pipeline (vs. requiring separate CAS configuration)
- Scriptable control over which entities are registered
- Automatic rollback on failure

### Java Plugin Systems (OSGi)

Eagle's AppDomain isolation is conceptually similar to OSGi's bundle
classloader isolation:

| Aspect | Eagle | OSGi |
|--------|-------|------|
| Isolation unit | AppDomain | ClassLoader |
| Communication | .NET remoting proxies | Service registry |
| Unloadability | Full AppDomain unload | Bundle stop/uninstall |
| Security | Strong name + Authenticode | Java security manager |
| Discovery | Reflection on `IPlugin` | Manifest headers |

### Python Plugin Systems

Python's plugin loading (via `importlib`) has no built-in security
verification, no isolation, and no automatic type discovery. Eagle's
system is significantly more structured:

| Aspect | Eagle | Python |
|--------|-------|--------|
| Loading | `[load]` with security verification | `importlib.import_module()` |
| Isolation | AppDomain | None (same process) |
| Security | Strong name, Authenticode, policies | None built-in |
| Discovery | `IPlugin` interface, `PluginFlags.Primary` | Convention-based |
| Unloading | `[unload]` with cleanup | Not reliably supported |

### Tcl TEA Extensions

Native Tcl's extension loading via `[load]` is simpler but less capable:

| Aspect | Eagle | Tcl |
|--------|-------|-----|
| Code type | Managed .NET assemblies | Native C shared libraries |
| Entry point | `IPlugin` interface (auto-discovered) | `Tcl_PkgInitProc` function (named convention) |
| Security | Multi-layer verification | None |
| Isolation | Optional AppDomain isolation | None |
| Metadata | Version, URI, certificates, flags | None |
| Unloading | Full lifecycle teardown | `[unload]` with unload proc |

## 14. Security Considerations

### 14.1 Threat Model

The plugin loading system addresses several threat categories:

**Tampered assemblies** — An attacker modifies a plugin DLL to include
malicious code. Mitigated by strong name verification
(`-verifiedonly`), which detects any modification to a signed assembly.

**Unsigned assemblies** — An attacker provides a plugin that lacks
proper code signing. Mitigated by Authenticode verification
(`-trustedonly`), which requires a valid certificate chain.

**Wrong publisher** — A validly signed plugin comes from an unexpected
publisher. Mitigated by public key token verification
(`-publickeytoken`), which ensures the assembly was signed with a
specific key.

**Privilege escalation** — A plugin attempts to provide commands or
policies that exceed its intended capabilities. Mitigated by rule-set
filtering (`-ruleset`), which controls which entities are registered,
and by the `No*` suppression flags.

**Denial of service** — A plugin crashes or hangs the interpreter.
Mitigated by AppDomain isolation (`-isolated`), which contains faults
to the plugin's domain, and by thread validation, which ensures
loading occurs on the correct thread.

**TOCTOU attacks** — An attacker swaps a plugin file between
verification and loading. Mitigated by the verification process: for
byte-loaded assemblies, the bytes are written to a temp file that is
kept open during verification, then read back and compared to the
originals.

### 14.2 Security Invariants

1. **Safe interpreters cannot call `[load]` or `[unload]`** — both
   commands have `CommandFlags.Unsafe`
2. **`-maybeverifiedonly` and `-maybetrustedonly` are the only
   safe-interpreter-accessible verification options** — they exist
   solely for the internal binary plugin loader
3. **`PluginFlags.Demand` is always set** for user-loaded plugins,
   distinguishing them from built-in `Static` plugins
4. **Verification is fail-closed** — if strong name or trust
   verification encounters any error, the result is "not verified"
   (secure by default)
5. **Cleanup always runs** — the `finally` block in `[load]` ensures
   that failed loads are fully rolled back, including AppDomain
   unloading
6. **No code execution before verification** — strong name and trust
   checks run before any plugin code is loaded or executed

### 14.3 Best Practices

For maximum security when loading third-party plugins:

```tcl
# Use all available verification
load -verifiedonly -trustedonly -publickeytoken "..." -isolated \
    /path/to/ThirdPartyPlugin.dll

# Use rule sets to restrict what the plugin can provide
load -ruleset $restrictiveRuleSet -nopolicies \
    /path/to/ThirdPartyPlugin.dll
```

For development and testing:

```tcl
# Relaxed loading for local development
load /path/to/DevPlugin.dll

# Debug builds: -maybeverifiedonly and -maybetrustedonly are no-ops
load -maybeverifiedonly /path/to/DevPlugin.dll
```

## 15. Relationship to Other Commands

| Command | Relationship |
|---------|-------------|
| `[library]` | Loads *native* (unmanaged) shared libraries for P/Invoke-style FFI. Complementary to `[load]`, which loads *managed* .NET plugins. See [`library.md`](library.md). |
| `[interp]` | Manages interpreter lifecycle and security. Plugins can be loaded into child interpreters via the `[interp]` argument. Safe interpreters cannot call `[load]`/`[unload]`. See [`interp.md`](interp.md). |
| `[object]` | Provides .NET object manipulation. Plugin-provided commands often use `[object]` internally. Plugins can provide custom object resolvers. |
| `[package]` | Package management. Unless `-noprovide` is used, loaded plugins are registered as packages. |
| `[info]` | `[info loaded]` lists currently loaded plugins. |
| `[exec]` | External process execution. Unrelated to plugin loading but shares the `managedEnvironment` object group. |

## 16. References

- **Source code**: `Eagle/Library/Commands/Load.cs` — `[load]` command implementation
- **Source code**: `Eagle/Library/Commands/Unload.cs` — `[unload]` command implementation
- **Source code**: `Eagle/Library/Components/Public/Interpreter.cs` — LoadPlugin, CreatePlugin, AddPlugin, UnloadPlugin
- **Source code**: `Eagle/Library/Components/Private/RuntimeOps.cs` — resource-based loading, entity population, security verification
- **Source code**: `Eagle/Library/Components/Private/AppDomainOps.cs` — AppDomain isolation
- **Source code**: `Eagle/Library/Plugins/` — built-in plugins (Core, Default, Object, Monitor, Test, Notify, Trace)
- **Source code**: `Eagle/Plugins/Commercial/Enterprise/` — enterprise plugins (Harpy, Badge, HotKey, Zeus, Demo, Featherlight, Aquila, Kapok)
- **Related documentation**: [`library.md`](library.md) — native library FFI
- **Related documentation**: [`interp.md`](interp.md) — interpreter security model
- **Related documentation**: [`core_language.md`](core_language.md#cmd-load) — basic load command reference
- **Related documentation**: [`core_language.md`](core_language.md#cmd-unload) — basic unload command reference
- **Related documentation**: [`core_examples.md`](core_examples.md#ex-load) — load/unload examples
