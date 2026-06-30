# Zeus Plugin Command Catalog

> **For AI agents**: This document catalogs all script commands provided by the Zeus plugin (Eagle Enterprise Edition). The Zeus plugin provides CLR method hooking, registered/obfuscated procedure management, RFC 2898 cryptographic key derivation, and script encryption for the Eagle script engine. Use the [Command Summary](#command-summary) for a quick overview. The single `zeus` ensemble command has an anchor `#cmd-zeus` for direct linking. The [Composition Architecture](#composition-architecture) section explains how hooking, procedure registration, and obfuscation interact. The [Script Library](#script-library) section documents the `Zeus.Cryptography` package. Options marked **(Unsafe)** require an unsafe execution context.

## Table of Contents

- [Overview](#overview)
- [Command Summary](#command-summary)
- [Commands](#commands)
  - [`zeus`](#cmd-zeus) — Hooking, procedures, key derivation, and diagnostics (14 sub-commands)
    - [`about`](#cmd-zeus-about)
    - [`callback`](#cmd-zeus-callback)
    - [`certificate`](#cmd-zeus-certificate)
    - [`clone`](#cmd-zeus-clone)
    - [`create`](#cmd-zeus-create)
    - [`derive`](#cmd-zeus-derive)
    - [`hook`](#cmd-zeus-hook)
    - [`isolated`](#cmd-zeus-isolated)
    - [`options`](#cmd-zeus-options)
    - [`pi`](#cmd-zeus-pi)
    - [`proc`](#cmd-zeus-proc)
    - [`register`](#cmd-zeus-register)
    - [`selftest`](#cmd-zeus-selftest)
    - [`unregister`](#cmd-zeus-unregister)
- [Composition Architecture](#composition-architecture)
  - [Registered Procedures](#arch-registered)
  - [Obfuscated Procedures](#arch-obfuscated)
  - [Method Hooking](#arch-hooking)
  - [The Full Composition Chain](#arch-full-chain)
- [RFC 2898 Provider System](#rfc2898-provider-system)
- [Script Library](#script-library)
- [Plugin Variant](#plugin-variant)
- [Conditional Compilation](#conditional-compilation)

---

## Overview

The **Zeus** plugin is the Eagle Enterprise Edition managed environment, cryptographic operations, and runtime instrumentation subsystem. It provides:

- **CLR method hooking** — Native code patching that redirects CLR method calls to managed callbacks, supporting x86, x64, ARM, and ARM64 architectures across Windows, macOS, and Linux
- **Registered procedures** — Tamper-evident script procedures whose names are SHA-512 hashes of their body, arguments, and flags, making any modification detectable at execution time
- **Obfuscated procedures** — An extension of registered procedures that encrypts procedure bodies at rest using RFC 2898 (PBKDF2) key derivation and Rijndael-256 encryption, decrypting just-in-time for execution
- **RFC 2898 key derivation** — A pluggable provider system for PBKDF2 cryptographic parameters (password, salt, iteration count, hash algorithm) with built-in, remote, script-based, and test providers
- **Script encryption** — A script library (`Zeus.Cryptography`) providing procedures for encrypting and decrypting Eagle scripts with Rijndael symmetric encryption
- **Pi digit computation** — A Bailey-Borwein-Plouffe (BBP) algorithm implementation for computing arbitrary hexadecimal digits of pi (requires `NET_40`)
- **License certificate integration** — Optional license verification during plugin initialization (when compiled with `LICENSING`)

### Architecture

The Zeus plugin provides a single ensemble command (`zeus`) with 14 sub-commands. The command class inherits from `Eagle._Commands.Default` and is marked with `CommandFlags.Unsafe` and the `managedEnvironment` object group.

The plugin has one class variant:

- **`Zeus.Enterprise`** — The primary plugin, loaded as a standard Eagle package. Implements `IRfc2898DataManager` to hold RFC 2898 data and provider references.

The plugin also provides a script library package:

- **`Zeus.Cryptography`** — A pure-script package (sourced from `zeus.eagle`) providing high-level encryption, decryption, and encrypted script sourcing procedures.

### Key Concepts

**Registered procedures:** A registered procedure's name is the SHA-512 hash of its body concatenated (tab-separated) with its saved arguments and procedure flags. Before every execution, the `Registered` class recomputes this hash and verifies it against the procedure name. If the hash does not match, execution is refused. The `Name` property setter throws `NotSupportedException`, preventing name changes. The `ReadOnly` procedure flag prevents removal by ordinary code; only `zeus unregister` can clear it.

**Obfuscated procedures:** The `Obfuscated` class extends `Registered`. At construction time, the procedure body is encrypted using the plugin's RFC 2898 parameters and stored in encrypted form. During execution, the body is decrypted into a temporary variable, the inner procedure's body is replaced with the plaintext, `base.Execute()` runs (which includes the hash verification from `Registered`), and a `finally` block restores the encrypted body. The procedure's `Arguments`, `NamedArguments`, `OverwriteArguments`, and `Body` fields are cleared at construction time to prevent inspection.

**NewProcedureCallback:** When `zeus proc` installs a provider, it also installs a `NewProcedureCallback` on the interpreter. This callback intercepts all procedure creation and wraps each new procedure in an `Obfuscated` instance, transparently adding encryption.

**Method hooking:** The `HookOps` engine patches CLR methods at the native code level. It supports three strategies: `FullTrampoline` (legacy, direct code replacement), `AbsoluteAddress` (jump stub with 64-bit address), and `RelativeAddress` (jump stub with 32-bit relative offset). Hooks are tracked via `HookClientData` objects; disposing the object reverses the hook.

---

## Command Summary

| Command | Type | Sub-commands | Command Flags | Description |
|---------|------|-------------|---------------|-------------|
| [`zeus`](#cmd-zeus) | Ensemble | 14 | Unsafe | Hooking, procedures, key derivation, and diagnostics |

---

## Commands

---

<a id="cmd-zeus"></a>
### `zeus` — Hooking, Procedures, Key Derivation, and Diagnostics

```
zeus option ?arg ...?
```

The single Zeus command is an ensemble with 14 sub-commands for CLR method hooking, registered/obfuscated procedure management, RFC 2898 key derivation, script encryption support, and plugin diagnostics. All sub-commands are dispatched via `Utility.TryExecuteSubCommandFromEnsemble`.

**Command flags:** `CommandFlags.Unsafe`

**Object group:** `managedEnvironment`

#### Sub-commands

---

<a id="cmd-zeus-about"></a>
##### `zeus about`

```
zeus about
```

Returns plugin "about" information, including version, copyright, and license certificate details. Delegates to the plugin's `About` method, which calls `Utility.FormatPluginAbout` and, when compiled with `LICENSING`, appends certificate information.

**Returns:** Plugin about string.

**Errors:** Returns error if the plugin reference is invalid.

---

<a id="cmd-zeus-callback"></a>
##### `zeus callback`

```
zeus callback ?options? arg ?arg ...?
```

Creates a managed callback from a registered procedure. The callback can be used as a hook target for `zeus hook`. The first non-option argument must be a registration (a `{token name}` pair from `zeus register`). Additional arguments are prepended to the callback's argument list.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-name` | String | (derived) | Name for the callback object handle. Defaults to the procedure name plus any extra arguments. |
| `-marshalflags` | MarshalFlags enum | `MethodHookMask` | Controls how method parameters are marshaled. |
| `-callbackflags` | CallbackFlags enum | `Default` | Flags controlling callback behavior. |
| `-objectflags` | ObjectFlags enum | `Callback` | Flags for the opaque object handle. |
| `-byrefargumentflags` | ByRefArgumentFlags enum | `None` | Controls by-reference argument handling. |

**Arguments:**

| Argument | Type | Description |
|----------|------|-------------|
| *arg* | String | The first argument must be a registration string (`{token name}`). Additional arguments are passed to the callback. |

**Returns:** An opaque object handle name for the created callback.

**Errors:** Returns error if the registration cannot be parsed, the procedure is not found or not registered, or the callback cannot be created.

**Notes:** The registration is validated via `CommonOps.IsRegisteredProcedure` before the callback is created, which includes hash verification of the procedure body.

**Example:**
```tcl
set reg [zeus register {x} { return $x }]
set cb [zeus callback $reg]
```

---

<a id="cmd-zeus-certificate"></a>
##### `zeus certificate`

```
zeus certificate
```

Returns the file name of the plugin's configured license certificate file.

**Returns:** The certificate file path string, or an error if the file name is null (no certificate configured) or the plugin reference is invalid.

**Notes:** Only available when compiled with `LICENSING`.

---

<a id="cmd-zeus-clone"></a>
##### `zeus clone`

```
zeus clone provider
```

Validates that a named object is a usable `IRfc2898DataProvider` and returns its object name if `Rfc2898Data.IsEnabled()` is true.

| Argument | Type | Description |
|----------|------|-------------|
| *provider* | String | The opaque object handle name of an RFC 2898 data provider. |

**Returns:** The provider object name if the provider is valid and enabled, or null (empty string) if not enabled.

**Errors:** Returns error if the object is not a valid provider or the plugin reference is invalid.

---

<a id="cmd-zeus-create"></a>
##### `zeus create`

```
zeus create ?options? assemblyName typeName
```

Creates an RFC 2898 data provider instance. The provider supplies cryptographic parameters (password, salt, iteration count, hash algorithm) for procedure obfuscation and script encryption.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-allownull` | Flag | false | If present, a null return from the provider factory is not treated as an error. |
| `-plugin` | Plugin | (this plugin) | The plugin to associate with the provider. |
| `-clientdata` | Object | (current) | Client data passed to the provider constructor. |
| *(fixup options)* | Various | | Standard return value fixup options (`-alias`, `-aliasraw`, `-objectflags`, `-objectname`, etc.). |

| Argument | Type | Description |
|----------|------|-------------|
| *assemblyName* | String | Assembly containing the provider type. Use empty string for built-in types. |
| *typeName* | String | Provider type name. The recognized built-in names are the simple type names `Rfc2898Data`, `Core`, `Test`, `Remote`, and `Script`; their fully-qualified forms (`Zeus.Providers.Core`, etc.) are also accepted. Any other name is resolved as an arbitrary type. |

**Returns:** An opaque object handle name for the created provider.

**Errors:** Returns error if the provider cannot be created, the type is not found, or the plugin reference is invalid.

**Built-in provider types:**

| Type Name | Description |
|-----------|-------------|
| `Rfc2898Data` | Creates an `Rfc2898Data` instance (direct data, no provider logic). |
| `Core` | Core provider with explicit password/salt/iterations. |
| `Test` | Test provider with hardcoded weak credentials (NOT for production). |
| `Remote` | Fetches parameters from a remote URL (XML or script format). |
| `Script` | Evaluates an Eagle script to compute parameters dynamically. |

**Example:**
```tcl
zeus create "" Test
# => opaque object handle for Test provider

zeus create "" Core
# => opaque object handle for Core provider
```

---

<a id="cmd-zeus-derive"></a>
##### `zeus derive`

```
zeus derive ?options? salt password ?password ...?
```

Derives cryptographic key material using RFC 2898 (PBKDF2). Multiple password arguments are concatenated. Returns the derived bytes as a Base64-encoded string.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-encoding` | Encoding | UTF-8 | Text encoding for password and salt conversion to bytes. |
| `-count` | Integer | 32 | Number of bytes to derive (256 bits by default). |
| `-iterations` | Integer | 100001 | PBKDF2 iteration count. |
| `-hashalgorithm` | String | (default) | Hash algorithm name for PBKDF2 (e.g., `SHA512`). Requires .NET 4.7.2+. |

| Argument | Type | Description |
|----------|------|-------------|
| *salt* | String | The salt value for key derivation. |
| *password* | String | One or more password strings, concatenated for derivation. |

**Returns:** Base64-encoded derived key bytes with line breaks.

**Errors:** Returns error if the derivation fails.

**Example:**
```tcl
zeus derive -iterations 10000 "mySalt" "myPassword"
# => (Base64-encoded 32 bytes)

zeus derive -count 16 -hashalgorithm SHA512 "salt" "part1" "part2"
# => (Base64-encoded 16 bytes)
```

---

<a id="cmd-zeus-hook"></a>
##### `zeus hook`

```
zeus hook ?options?
```

Hooks a CLR method by patching its native code entry point to redirect calls to a managed callback. The hook is tracked via an opaque object handle; disposing the handle reverses the hook.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-methodtype` | Type | (none) | The CLR type containing the method to hook. **Required.** |
| `-methodname` | String | (none) | The name of the method to hook. **Required.** |
| `-bindingflags` | BindingFlags enum | (default) | Reflection binding flags for method lookup. |
| `-parametermarshalflags` | MarshalFlags enum list | `None` | Per-parameter marshal flag list. |
| `-marshalflags` | MarshalFlags enum | `MethodHookMask` | Marshal flags for the hook delegate. |
| `-callback` | Callback | (none) | The callback to redirect calls to. **Required.** Created via `zeus callback`. |
| `-allowlegacy` | Boolean | (auto) | Allow legacy full-trampoline patching. |
| `-allowfallback` | Boolean | (auto) | Allow fallback address resolution. |

**Returns:** An opaque object handle name for the hook. Disposing this handle reverses the hook.

**Errors:** Returns error if the method cannot be found, the callback is missing, the hook cannot be applied, or the plugin is running in isolated (cross-AppDomain) mode.

**Notes:**
- Requires `EMIT && NATIVE` compile flags.
- Cannot be used when the plugin is running in cross-AppDomain isolation.
- Not supported on Mono.
- If the hook sub-command fails after the native patch is applied, a `finally` block disposes the hook to guarantee the original method is restored.
- Three patching strategies are used depending on the runtime:
  - **FullTrampoline** — Direct code replacement (legacy, .NET Framework / .NET Core < 5).
  - **AbsoluteAddress** — Jump stub with 64-bit address (.NET 5+ on AMD64/ARM64).
  - **RelativeAddress** — Jump stub with 32-bit relative offset (.NET 5+ on AMD64).

**Example:**
```tcl
set reg [zeus register {x} { return "hooked: $x" }]
set cb [zeus callback $reg]
set hook [zeus hook \
    -methodtype SomeType \
    -methodname SomeMethod \
    -callback $cb]

# ... SomeMethod now calls the registered procedure ...

# Reverse the hook:
object dispose $hook
```

---

<a id="cmd-zeus-isolated"></a>
##### `zeus isolated`

```
zeus isolated
```

Returns whether the plugin is running in cross-AppDomain (isolated) mode.

**Returns:** A boolean (`True` or `False`).

**Errors:** Returns error if the plugin reference is invalid.

---

<a id="cmd-zeus-options"></a>
##### `zeus options`

```
zeus options
```

Returns the compile-time options (preprocessor defines) that were active when the Zeus plugin assembly was built.

**Returns:** A Tcl list of compile option strings.

**Example:**
```tcl
zeus options
# => APPDOMAINS EMIT LICENSING NATIVE NET_40 PLUGIN_COMMANDS ...
```

---

<a id="cmd-zeus-pi"></a>
##### `zeus pi`

```
zeus pi digit ?count?
```

Computes hexadecimal digits of pi starting at the specified position, using the Bailey-Borwein-Plouffe (BBP) algorithm. This algorithm can compute individual hexadecimal digits of pi without computing all preceding digits.

| Argument | Type | Description |
|----------|------|-------------|
| *digit* | Wide integer | The one-based starting digit position (must be >= 1; a value below 1 raises an error). |
| *count* | Integer (optional) | Number of digits to compute. Defaults to 1. |

**Returns:** A hexadecimal string of the requested pi digits.

**Errors:** Returns error if the arguments are invalid.

**Notes:** Requires `NET_40` compile flag (uses `System.Numerics.BigInteger`). The computation includes interpreter readiness checks, allowing script cancellation during long computations.

**Example:**
```tcl
zeus pi 1 10
# => 243F6A8885  (first 10 hex digits of pi)

zeus pi 100
# => (single hex digit at position 100)
```

---

<a id="cmd-zeus-proc"></a>
##### `zeus proc`

```
zeus proc ?provider?
```

Queries or sets the RFC 2898 data provider for procedure obfuscation. When a provider is set, a `NewProcedureCallback` is installed on the interpreter that intercepts all procedure creation and wraps new procedures in `Obfuscated` instances. When the provider is set to null, the callback is removed.

| Argument | Type | Description |
|----------|------|-------------|
| *provider* | String (optional) | An opaque object handle name for an `IRfc2898Data` or `IRfc2898DataProvider` object. Pass `null` to clear the provider and remove the callback. |

**Returns:** A diagnostic status string describing the current RFC 2898 configuration (whether data or provider is set, types detected).

**Errors:** Returns error if the object is not a valid data or provider type, the callback cannot be installed, or the plugin reference is invalid.

**Notes:** When a provider is active, all procedures created via `proc` or `zeus register` will have their bodies encrypted. The `NewProcedureCallback` intercepts `Utility.NewProcedure` and wraps each procedure in an `Obfuscated` instance. For cross-AppDomain scenarios, a `NewProcedureCallbackBridge` wrapper is used.

**Example:**
```tcl
set provider [zeus create "" Test]
zeus proc $provider
# => (status showing provider is active)

# All subsequent procedures will be obfuscated:
zeus register { return "secret" }

zeus proc null
# => (status showing no provider)
```

---

<a id="cmd-zeus-register"></a>
##### `zeus register`

```
zeus register ?options? ?arguments? body
```

Creates a registered procedure. The procedure name is the SHA-512 hash of its body, arguments, and flags. The procedure is marked `ReadOnly` to prevent modification or removal by ordinary code.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-group` | String | (none) | Object group for the procedure. |
| `-description` | String | (none) | Description text for the procedure. |
| `-flags` | ProcedureFlags enum | `None` | Additional procedure flags. Key values: `NamedArguments`, `PositionalArguments`. |

| Argument | Type | Description |
|----------|------|-------------|
| *arguments* | String (optional) | Formal argument list. If omitted, the procedure takes no formal arguments. |
| *body* | String | The procedure body script. |

**Returns:** A registration string in the form `{token name}` where *token* is the procedure token (wide integer) and *name* is the fully-qualified procedure name (a 128-character hexadecimal hash).

**Errors:** Returns error if the procedure body is empty, the hash cannot be computed, or the procedure cannot be added to the interpreter.

**Notes:**
- If a `NewProcedureCallback` is installed (via `zeus proc`), the procedure will automatically be wrapped in an `Obfuscated` instance with encrypted body.
- Without a callback, the procedure is wrapped in a `Registered` instance with hash verification only.
- The procedure name is a 128-character lowercase hexadecimal string (SHA-512 hash).
- The `ReadOnly` flag prevents removal except via `zeus unregister`.
- The `Registered` flag enables pre-execution hash verification.
- Procedure flag masking enforces mutual exclusion between `NamedArguments` and `PositionalArguments`; if neither is set, `DefaultArguments` is added.

**Example:**
```tcl
set reg [zeus register {x y} { expr {$x + $y} }]
# => {12345 ::ab01cd23...ef}  (token and 128-char hex name)

# Call the registered procedure:
[lindex $reg end] 3 4
# => 7

# With named arguments:
set reg [zeus register -flags +NamedArguments {-name "world"} {
    return "hello $name"
}]
```

---

<a id="cmd-zeus-selftest"></a>
##### `zeus selftest`

```
zeus selftest
```

Runs the hook subsystem self-test. The test creates a test method, hooks it, verifies the hook redirects calls, unhooks it, and verifies the original behavior is restored. The expected result sequence is `{A Z M M A Z}`.

**Returns:** An empty string on success.

**Errors:** Returns error if the self-test fails, or if compiled without `EMIT && NATIVE`, or if running on Mono.

**Example:**
```tcl
zeus selftest
# => (empty string on success)
```

---

<a id="cmd-zeus-unregister"></a>
##### `zeus unregister`

```
zeus unregister registration
```

Removes a registered procedure by its registration token. The procedure's integrity is verified via hash comparison before removal. The `ReadOnly` flag is cleared to permit the removal.

| Argument | Type | Description |
|----------|------|-------------|
| *registration* | String | A registration string (`{token name}`) from `zeus register`. |

**Returns:** An empty string on success.

**Errors:** Returns error if the registration cannot be parsed, the procedure is not found, or the procedure fails hash verification.

**Example:**
```tcl
set reg [zeus register { return "hello" }]
zeus unregister $reg
# => (empty string)
```

---

## Composition Architecture

The Zeus plugin's core subsystems — registered procedures, obfuscated procedures, and method hooking — compose together to provide a complete runtime instrumentation and code protection system. This section explains each layer and how they interact.

---

<a id="arch-registered"></a>
### Registered Procedures

The `Registered` class (in `Zeus.Procedures.Registered`) extends `Eagle._Procedures.Default` and wraps an inner `IProcedure`:

```
Registered
├── Inner IProcedure procedure (the actual script procedure)
├── savedArguments (original argument string)
├── savedProcedureFlags (original flags)
└── Name property (setter throws NotSupportedException)
```

**Hash construction:** The hash input is built by `GetHashBuilderForRegisteredProcedure`:

```
procedureFlags + "\t" + arguments + "\t" + body
```

This string is hashed with SHA-512 and converted to a 128-character lowercase hexadecimal string, which becomes the procedure name.

**Execution flow:**

1. `Execute()` is called
2. If `ProcedureFlags.Registered` is set, call `HashAndVerifyAgainstName()`
3. Compute SHA-512 of `(flags + tab + arguments + tab + body)`
4. Compare hex hash against the tail portion of the procedure name
5. If match: delegate to inner `procedure.Execute()`
6. If mismatch: return error "registered procedure could not be verified"

---

<a id="arch-obfuscated"></a>
### Obfuscated Procedures

The `Obfuscated` class (in `Zeus.Procedures.Obfuscated`) extends `Registered`:

```
Obfuscated : Registered
├── plugin (IPlugin reference for RFC 2898 parameter access)
├── Encrypted procedure body (stored in inner procedure)
└── ClearData() nulls Arguments, NamedArguments, OverwriteArguments, Body
```

**Construction flow:**

1. Constructor receives `IProcedureData` (with plaintext body) and `IPlugin`
2. `ClearData()` — nulls all inspection-visible fields
3. `MarkAsObfuscated()` — adds `ProcedureFlags.Obfuscated`
4. `SetupProcedureOrThrow()`:
   a. Reads plaintext body from `procedureData.Body`
   b. `Transform(true, ref body)` — encrypts body using RFC 2898 parameters from plugin
   c. Writes encrypted body back to `procedureData.Body`
   d. Sets `ProcedureFlags.Obfuscated` on procedure data
   e. Creates a core procedure from the modified (encrypted) data
   f. Stores as the inner procedure via `MaybeSetProcedure()`

**Execution flow:**

1. `Execute()` is called
2. Verify inner procedure exists and has `ProcedureFlags.Obfuscated`
3. Save the encrypted body: `savedBody = procedure.Body`
4. **try:**
   a. `Transform(false, ref body)` — decrypt body
   b. `procedure.Body = body` — replace with plaintext (temporarily)
   c. `base.Execute()` — calls `Registered.Execute()`, which verifies hash then runs
5. **finally:**
   a. `procedure.Body = savedBody` — restore encrypted body

**Transform method:** Gets password, salt, iteration count, and hash algorithm from `Rfc2898Ops.GetData(plugin, ...)`, then calls `CryptographyOps.Transform()` which uses:
- Algorithm: Rijndael (AES-256)
- Key size: 256 bits
- Block size: 128 bits
- Mode: CBC (Cipher Block Chaining)
- Padding: PKCS7
- Key derivation: RFC 2898 / PBKDF2 with configurable iteration count (default: 100,001)

---

<a id="arch-hooking"></a>
### Method Hooking

The `HookOps` engine (in `Zeus.Components.Private.HookOps`) patches CLR methods at the native code level:

**Data structures:**

| Structure | Purpose |
|-----------|---------|
| `HookData` | Immutable record of a hook: old/new method, handles, native pointers, patch kind, saved/applied bytes, active flag |
| `HookClientData` | Disposable wrapper; disposing calls `Stop()` to reverse the hook |

**Patching strategies:**

| Strategy | Runtime | Mechanism |
|----------|---------|-----------|
| `FullTrampoline` | .NET Framework, .NET Core < 5 | Overwrites method entry point with `MOV reg, addr + JMP reg` |
| `AbsoluteAddress` | .NET 5+ (AMD64, ARM64) | Modifies address word in jump stub |
| `RelativeAddress` | .NET 5+ (AMD64) | Modifies relative offset in jump stub |

**Architecture-specific trampolines:**

```
x86:    PUSH imm32; RET                       (6 bytes)
x64:    MOV R11, imm64; JMP R11              (13 bytes)
ARM32:  LDR.W PC, [PC, #0]; <addr>           (8 bytes)
ARM64:  LDR X16, [PC, #8]; BR X16; <addr>   (16 bytes)
```

**Platform-specific memory handling:**

| Platform | Write Mechanism | Cache Flush |
|----------|----------------|-------------|
| Windows | `VirtualProtect` + `WriteProcessMemory` + `FlushInstructionCache` |
| macOS | `write_code_patch()` (libBolt) or `mprotect` + `sys_icache_invalidate` |
| Linux | `mprotect` (parses `/proc/self/maps`) + `__clear_cache` (ARM/ARM64) |

**ARM64 resolution:** The `ARM64` helper class decodes instruction sequences (`B`, `BR`, `LDR`, `ADRP`, `ADD`) to follow chains of jump stubs up to a configurable limit, resolving the actual target method address.

---

<a id="arch-full-chain"></a>
### The Full Composition Chain

The three subsystems compose into a complete code protection and instrumentation pipeline:

```
                  ┌─────────────────────────────┐
                  │    zeus create / provider    │
                  │  (RFC 2898 parameters)       │
                  └──────────┬──────────────────┘
                             │
                             ▼
                  ┌─────────────────────────────┐
                  │       zeus proc $provider    │
                  │  (installs NewProcCallback)  │
                  └──────────┬──────────────────┘
                             │
                             ▼
                  ┌─────────────────────────────┐
                  │     zeus register body       │
                  │  ┌───────────────────────┐  │
                  │  │ NewProcedureCallback   │  │
                  │  │ intercepts creation    │  │
                  │  │ → Obfuscated wrapper   │  │
                  │  │   → encrypts body      │  │
                  │  │   → hash-based name    │  │
                  │  └───────────────────────┘  │
                  │  Returns: {token name}      │
                  └──────────┬──────────────────┘
                             │
                             ▼
                  ┌─────────────────────────────┐
                  │   zeus callback $reg         │
                  │  (managed callback from proc)│
                  └──────────┬──────────────────┘
                             │
                             ▼
                  ┌─────────────────────────────┐
                  │   zeus hook -callback $cb    │
                  │  (patches CLR method)        │
                  └──────────┬──────────────────┘
                             │
                             ▼
                  ┌─────────────────────────────┐
                  │   CLR method call            │
                  │  → native redirect           │
                  │  → callback                  │
                  │  → registered procedure      │
                  │  → decrypt body              │
                  │  → verify hash               │
                  │  → execute script            │
                  │  → re-encrypt body           │
                  └─────────────────────────────┘
```

**Execution of a hooked method call (full chain):**

1. Caller invokes the hooked CLR method
2. Native code redirect (trampoline or jump stub) sends to the callback's managed delegate
3. The callback invokes the registered procedure
4. `Obfuscated.Execute()`:
   a. Saves encrypted body
   b. Decrypts body using RFC 2898 parameters
   c. Sets plaintext body on inner procedure
5. `Registered.Execute()`:
   a. Computes SHA-512 hash of `(flags + tab + arguments + tab + body)`
   b. Verifies hash matches procedure name
   c. Executes the script body
6. `Obfuscated.Execute()` finally block:
   a. Restores encrypted body

**Cleanup chain (in reverse order):**

```tcl
object dispose $hook     ;# Reverses native code patch
object dispose $callback ;# Removes managed callback
zeus unregister $reg     ;# Removes registered/obfuscated procedure
zeus proc null           ;# Removes NewProcedureCallback, clears provider
object dispose $provider ;# Disposes provider object
```

---

## RFC 2898 Provider System

The Zeus plugin uses a pluggable provider system for cryptographic parameters. Providers implement the `IRfc2898DataProvider` interface and supply password, salt, iteration count, hash algorithm name, and signature values.

### Provider Hierarchy

```
Default (abstract)
├── Core (concrete, implements IRfc2898Data)
│   ├── Remote (sealed, fetches from URL)
│   ├── Script (sealed, evaluates Eagle script)
│   └── Test (sealed, hardcoded weak values)
└── (external providers via reflection)
```

### Built-in Providers

| Provider | Class | Description |
|----------|-------|-------------|
| `Providers.Core` | `Zeus.Providers.Core` | Base provider with explicit parameter storage. |
| `Providers.Test` | `Zeus.Providers.Test` | Test-only provider. Default password: `"password"`, salt: `"test1234"`, iterations: 1000. **Not for production.** |
| `Providers.Remote` | `Zeus.Providers.Remote` | Fetches parameters from a remote URL. Supports XML and script-based formats. Client data must contain a `Uri` and optional trust flag. |
| `Providers.Script` | `Zeus.Providers.Script` | Evaluates an Eagle script to dynamically compute parameters. TEST builds only. |

### Rfc2898Data

The `Rfc2898Data` class is a thread-safe data container with:

- Properties: `Password`, `Salt`, `IterationCount`, `HashAlgorithmName`, `Signature`
- Each property has a corresponding `*Set` boolean flag
- Static `IsEnabled()` / `IsPersistent()` methods using interlocked atomic operations
- Getters/setters check `IsEnabled()` before accessing values

---

## Script Library

The `Zeus.Cryptography` package (version 1.0) is provided by the `zeus.eagle` script library file. It provides high-level procedures for script encryption and decryption.

### Package Loading

```tcl
package require Zeus.Cryptography
```

### Key Procedures

| Procedure | Description |
|-----------|-------------|
| `encryptScript script encodingName password salt iterationCount hashAlgorithmName` | Encrypts a script using Rijndael-256/CBC/PKCS7. Returns wrapped encrypted text with magic prefix. |
| `decryptScript script encodingName password salt iterationCount hashAlgorithmName` | Decrypts an encrypted script. Normalizes line endings to Unix style. |
| `isEncryptedScript script ?strict?` | Tests whether a string is an encrypted script. Strict mode validates Base64 and wrapper format. |
| `sourceEncrypted ?options? fileName ?password? ?salt? ?iterationCount? ?hashAlgorithmName? ?signature?` | Sources (evaluates) an encrypted script file. Handles password management and provider integration. |
| `hasEncryptedScriptMagic script ?varName?` | Checks if a script starts with the encrypted script magic sentinel. |
| `hasEncryptedScriptFileMagic fileName` | Checks if a file appears to contain an encrypted script. |
| `rawEncryptString ...` | Low-level string encryption using configurable algorithm. |
| `rawDecryptString ...` | Low-level string decryption using configurable algorithm. |
| `rawCreateAlgorithm ...` | Creates and configures a symmetric encryption algorithm instance. |
| `zeus_createProvider` | Creates an RFC 2898 provider using global `zeus` array configuration. |
| `zeus_createRemoteClientData relativeUri ?trusted?` | Creates client data for the Remote provider. |
| `setupStateForZeus requiredOnly` | Initializes global `zeus` array with default configuration values. |

### sourceEncrypted Options

| Option | Description |
|--------|-------------|
| `-encoding` | Text encoding name. |
| `-withinfo` | Include diagnostic information. |
| `-time` | Report timing information. |
| `-password` | Override password. |
| `-library` | Treat as library script. |
| `-bundle` | Use bundled (embedded) script. |
| `-erroronempty` | Error if decrypted script is empty. |
| `-stoponerror` | Stop on first error during evaluation. |

### Global Configuration

The library uses a global `zeus` array for configuration:

| Key | Description |
|-----|-------------|
| `zeus(magic)` | Encrypted script magic sentinel prefix. |
| `zeus(prologue)` | Prologue prepended to encrypted scripts. |
| `zeus(epilogue)` | Epilogue appended to encrypted scripts. |
| `zeus(mode)` | Cipher mode (default: `CBC`). |
| `zeus(padding)` | Padding mode (default: `PKCS7`). |
| `zeus(encryptionAlgorithmName)` | Encryption algorithm (default: `RijndaelManaged`). |
| `zeus(password)` | Default password. |
| `zeus(salt)` | Default salt. |
| `zeus(iterationCount)` | Default PBKDF2 iteration count. |
| `zeus(hashAlgorithmName)` | Default hash algorithm for PBKDF2. |
| `zeus(providerPluginName)` | Plugin name for provider creation. |
| `zeus(providerAssemblyName)` | Assembly name for provider creation. |
| `zeus(providerTypeName)` | Type name for provider creation. |
| `zeus(providerClientData)` | Client data for provider creation. |

### Encryption Tools

The Zeus plugin includes command-line tools in the `Tools/` directory:

| Tool | Description |
|------|-------------|
| `encrypt.eagle` | Encrypts a script file. Usage: `eagle encrypt.eagle <in> <out> <password> <salt> <iterations> [hashAlgorithm] [encoding] [debug]` |
| `encrypt-self.eagle` | Encrypts plugin resource scripts for self-decryption. |

---

## Plugin Variant

The Zeus assembly contains one plugin class:

| Package Name | Class | Description |
|---|---|---|
| `Zeus.Enterprise` | `Zeus.Enterprise` | Primary plugin. Manages RFC 2898 data/provider, custom `pi()` function, self-decrypting resource strings, and license verification. |

The `Enterprise` class inherits from `Eagle._Plugins.Default` and implements `IRfc2898DataManager`:

- **`Initialize()`** — Verifies license certificate (if `LICENSING`), saves original `pi()` function, creates custom `pi()` function (if `NET_40`), then calls `base.Initialize()`.
- **`Terminate()`** — Removes custom `pi()` function, restores original, clears certificate data, then calls `base.Terminate()`.
- **`GetString()`** — Resolves resource names through embedded resources (verbatim then package-relative lookup). If `SelfDecrypt` is enabled, Base64-encoded resource values are decrypted using hardcoded self-decryption parameters before returning.
- **`Rfc2898Data`** / **`Rfc2898DataProvider`** — Properties implementing `IRfc2898DataManager` to store the active data or provider.

**Plugin flags:** `Primary | User | Commercial | NoFunctions | NoPolicies | NoTraces`

---

## Conditional Compilation

Some features require specific compile-time flags:

| Flag | Features Gated |
|------|---------------|
| `EMIT` | Required (with `NATIVE`) for `zeus hook` and `zeus selftest`. Enables runtime code generation. |
| `NATIVE` | Required (with `EMIT`) for `zeus hook` and `zeus selftest`. Enables native code patching. |
| `NET_40` | `zeus pi` (BBP algorithm using `BigInteger`), custom `pi()` function replacement. |
| `LICENSING` | License certificate verification during `Initialize`, `zeus certificate`, `About` with certificate details. |
| `OBFUSCATION` | Assembly obfuscation support (`[Obfuscation]` attribute on classes). |
| `PLUGIN_COMMANDS` | The `zeus` command itself. |
| `NET_472` | Configurable hash algorithm for RFC 2898 (`HashAlgorithmName` parameter). |
| `NET_STANDARD_20` | Cross-AppDomain provider creation via `Assembly.Load` + `Activator.CreateInstance`. |
| `TEST` | `Providers.Script` provider (evaluates Eagle scripts for parameters). |
| `ARGUMENT_CACHE` / `PARSE_CACHE` | Non-caching procedure flag support. |

### Self-Decryption Parameters

The plugin uses hardcoded parameters for decrypting its own embedded resources:

| Parameter | Value |
|-----------|-------|
| Password | `55BBFEE56823F5CAC63D06614A9AFAEE7E7E8996` |
| Salt | `79455596BBDBCDE17686E2C2A20A888CD8329BC9` |
| Iteration count | 100,000 |
| Hash algorithm | (default) |
