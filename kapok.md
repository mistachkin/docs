# Kapok Plugin Command Catalog

> **For AI agents**: This document catalogs all script commands provided by the Kapok plugin (Eagle Enterprise Edition). The Kapok plugin is a web server component providing sandboxed script evaluation, access control with API key token management, request throttling, configuration settings, and license certificate integration. Use the [Command Summary](#command-summary) for a quick overview. The single `kapok` ensemble command has an anchor `#cmd-kapok` for direct linking. The [Token Management](#token-management) section explains the access control model. The [Throttle Subsystem](#throttle-subsystem) section documents both fixed-window and sliding-window rate limiting. The [Setting Resolution Order](#setting-resolution-order) section describes the multi-source setting lookup chain. The [Script Library](#script-library) section documents the `Eagle.CIDR`, `Eagle.Signing`, and `Eagle.OpenAI` packages. Options marked **(Unsafe)** require an unsafe execution context.

## Table of Contents

- [Overview](#overview)
- [Command Summary](#command-summary)
- [Commands](#commands)
  - [`kapok`](#cmd-kapok) — Access control, sandboxed evaluation, settings, and diagnostics (11 sub-commands)
    - [`about`](#cmd-kapok-about)
    - [`access`](#cmd-kapok-access)
    - [`certificate`](#cmd-kapok-certificate)
    - [`cleanup`](#cmd-kapok-cleanup)
    - [`done`](#cmd-kapok-done)
    - [`evaluate`](#cmd-kapok-evaluate)
    - [`isolated`](#cmd-kapok-isolated)
    - [`log`](#cmd-kapok-log)
    - [`options`](#cmd-kapok-options)
    - [`setting`](#cmd-kapok-setting)
    - [`source`](#cmd-kapok-source)
- [Server Architecture](#server-architecture)
  - [Request Processing Pipeline](#server-pipeline)
  - [Interpreter Caching](#server-interpreter-caching)
- [Token Management](#token-management)
- [Throttle Subsystem](#throttle-subsystem)
- [Setting Resolution Order](#setting-resolution-order)
- [Script Library](#script-library)
- [Plugin Variant](#plugin-variant)
- [Conditional Compilation](#conditional-compilation)

---

## Overview

The **Kapok** plugin is the Eagle Enterprise Edition web server and sandboxed script evaluation subsystem. Like all Eagle Enterprise Edition plugins, it requires a valid license certificate by default, but is now also open source. It provides:

- **Sandboxed script evaluation** — Creates and manages "safe" (sandboxed) interpreters for evaluating client-submitted scripts with restricted command sets, optional ruleset-based filtering, and host-based access control via CIDR matching
- **API key token management** — A multi-dictionary access control system supporting allow/deny lists, administrator promotion, fake (simulated) access, and per-key ruleset restrictions
- **Request throttling** — Both fixed-window and sliding-window rate limiting on a per-client and per-server basis, with configurable lifetime counts, interval counts, and time windows
- **Configuration settings** — A multi-source setting resolution chain (script variables, .NET app settings, environment variables) with indexed search, token expansion, and type-aware validation
- **Configuration action tracking** — One-time-per-AppDomain initialization actions (library paths, log files, listeners, SQLite directories) with completion status tracking
- **Diagnostic logging** — Native `OutputDebugString` and managed trace listener output with configurable priority levels
- **License certificate integration** — Optional license verification during plugin initialization (when compiled with `LICENSING`), with Harpy SDK security configuration for sandboxed interpreters
- **Web server request pipeline** — A multi-phase request handler coordinating interpreter creation, license verification, script evaluation, and response generation

### Architecture

The Kapok plugin provides a single ensemble command (`kapok`) with 11 sub-commands. The command class inherits from `Eagle._Commands.Default` and is marked with `CommandFlags.Unsafe` and the `managedEnvironment` object group.

The plugin architecture is organized into several component layers:

- **`Kapok.Commands.Kapok`** — The ensemble command class dispatching all 11 sub-commands
- **`Kapok.Enterprise`** — The plugin class handling initialization, license verification, and lifecycle
- **`SandboxOps`** — Interpreter creation, caching, and cleanup; contains the `TokenManagement` inner class for access control
- **`ThrottleOps`** — Fixed-window and sliding-window rate limiting with per-client and per-server tracking
- **`WebSettingsOps`** — Multi-source setting resolution with indexed search and type validation
- **`Server`** — The multi-phase request processing pipeline coordinating all components
- **`InterpreterOps`** — Thread-local interpreter caching by phase with staleness detection
- **`StorageOps`** — Persistent variable storage via SQLite with access control

---

## Common patterns

*Test-verified quick start (from `Plugins/Commercial/Enterprise/Kapok/Tests/basic.eagle` and `Configurations/`). The operator API is `kapok access` (key management) + `kapok evaluate` (sandboxed eval); `Configurations/openAI_configuration.eagle` is the real config.*

Load:

```eagle
package require Kapok.Enterprise   ;# [kapok]
package require Eagle.OpenAI       ;# + Eagle.CIDR, Eagle.Signing, Licensing.Enterprise
```

Provision an API key (order matters; wrap each in `catch`): `unban` -> `grant`/`revoke` -> `promote`/`demote` -> `real`/`fake` -> `restrict`/`unrestrict`:

```eagle
catch {kapok access unban   $apiKey};  catch {kapok access grant   $apiKey}
catch {kapok access promote $apiKey};  catch {kapok access real    $apiKey}
catch {kapok access restrict $apiKey {{id 1 type Include kind Command \
    mode {Include Exact} regExOptions None patterns clock}}}
```

Throttle + access-gated sandbox evaluation (the core flow):

```eagle
kapok access throttle $apiKey $address           ;# per-host quota; throws when exceeded
set ruleSet [getDictionaryValue [kapok access $apiKey] ruleSet]
set cmd [list kapok evaluate -unsafe true -apikeyid $apiKey]
if {[string length $ruleSet] > 0} then {lappend cmd -ruleset $ruleSet}
eval [linsert $cmd end -- $script]
```

CIDR allow/deny lists (`Configurations/cidr_{allow,deny}.eagle`):

```eagle
package require Eagle.CIDR
maybeLoadCidrs $dir cidr_deny.eagle  openAI_deny_cidrs  false false
maybeLoadCidrs $dir cidr_allow.eagle openAI_allow_cidrs false false
```

Client submitting a prompt (receives a signed, sandbox-verified script):

```eagle
uri upload -trusted -inline -retries 0 \
    -data [list nop false fake true apiKey $apiKey prompt $prompt] -- \
    $scriptBaseUri$scriptRelativeUri
```

## Command Summary

| Command | Type | Sub-commands | Command Flags | Description |
|---------|------|-------------|---------------|-------------|
| [`kapok`](#cmd-kapok) | Ensemble | 11 | Unsafe | Access control, sandboxed evaluation, settings, and diagnostics |

---

## Commands

---

<a id="cmd-kapok"></a>
### `kapok` — Access Control, Sandboxed Evaluation, Settings, and Diagnostics

```
kapok option ?arg ...?
```

The single Kapok command is an ensemble with 11 sub-commands for managing API key access control, evaluating scripts in sandboxed interpreters, querying and manipulating server configuration, and performing diagnostics. All sub-commands are dispatched via `Utility.TryExecuteSubCommandFromEnsemble`.

**Command flags:** `CommandFlags.Unsafe`

**Object group:** `managedEnvironment`

#### Sub-commands

---

<a id="cmd-kapok-about"></a>
##### `kapok about`

```
kapok about
```

Returns plugin "about" information, including version, copyright, and license certificate details. Delegates to the plugin's `About` method, which includes `Utility.FormatPluginAbout` output and, when compiled with `LICENSING`, certificate information.

**Returns:** Plugin about string.

**Errors:** Returns error if the plugin reference is invalid.

---

<a id="cmd-kapok-access"></a>
##### `kapok access`

```
kapok access ?type? apiKeyId ?value?
```

Queries or modifies access control state for an API key identifier. This is the most complex sub-command, supporting five distinct operational modes based on the *type* argument.

| Argument | Type | Description |
|----------|------|-------------|
| *type* | AccessChangeType (optional) | The access control operation to perform. If omitted, defaults to `None` (query mode). |
| *apiKeyId* | GUID | The API key identifier to query or modify. Must be a valid, non-empty GUID. |
| *value* | String (optional) | Context-dependent: a client host/IP address for `Throttle` mode, or a ruleset specification for `Restrict` mode. |

**Operational modes:**

1. **Query mode** (`type` omitted or `None`) — Returns the full access state for the API key as a Tcl key-value list:

   ```tcl
   kapok access {12345678-1234-1234-1234-123456789abc}
   # => result true token 42 noAnonymous true isAllowed true isDenied false
   #    isAdministrator false isFake false ruleSet {}
   ```

   The returned fields are:
   - `result` — Whether a token was found for this API key
   - `token` — The interpreter token value (0 if none)
   - `noAnonymous` — Whether anonymous token fallback is suppressed
   - `isAllowed` — Whether the key is in the allow list
   - `isDenied` — Whether the key is in the deny (ban) list
   - `isAdministrator` — Whether the key has administrator privileges
   - `isFake` — Whether the key is in simulated-only mode
   - `ruleSet` — The configured ruleset, if any

2. **Hits query mode** (`Hits` or `Hits|Sliding`) — Returns the current throttle tracking data. With `Sliding`, returns a list of sliding-window entries formatted as `{key timestamp count}` elements. Without `Sliding`, returns a dictionary of fixed-window entries formatted as `{iso8601-datetime intervalCount lifetimeCount}`.

   ```tcl
   kapok access Hits {12345678-1234-1234-1234-123456789abc}
   # => (fixed-window throttle data)

   kapok access Hits,Sliding {12345678-1234-1234-1234-123456789abc}
   # => (sliding-window throttle data)
   ```

3. **Throttle validation mode** (`Throttle` or `Throttle|Sliding`) — Checks whether a request from the specified API key (and optionally a client host address in *value*) would be rate-limited. Returns successfully if the request is allowed; returns an error with throttle violation details if the request would be denied.

   ```tcl
   kapok access Throttle {12345678-...} 192.168.1.100
   # => (ok if not throttled; error with details if throttled)
   ```

4. **Reset mode** (`Reset` or `Reset|Sliding`) — Resets the throttle tracking data. Returns the number of entries that were cleared.

   ```tcl
   kapok access Reset {12345678-...}
   # => 5  (five fixed-window entries cleared)
   ```

5. **Modification mode** (any other `AccessChangeType` value) — Applies an access control change to the API key, then automatically re-queries and returns the updated state (via internal `goto retry` back to query mode). Supported change types:

   | Type | Effect | Default state |
   |------|--------|---------------|
   | `Grant` | Add to allow list | Not allowed |
   | `Revoke` | Remove from allow list | Revoked |
   | `Ban` | Add to deny list (blocks all access) | Not banned |
   | `Unban` | Remove from deny list | Unbanned |
   | `Promote` | Grant administrator access | Not administrator |
   | `Demote` | Revoke administrator access | Demoted |
   | `Fake` | Enable simulated-only access | Real access |
   | `Real` | Disable simulated-only access | Real access |
   | `Restrict` | Apply a ruleset (requires *value*) | Unrestricted |
   | `Unrestrict` | Remove ruleset restriction | Unrestricted |

   ```tcl
   kapok access Grant {12345678-...}
   # => result true token 0 noAnonymous true isAllowed true isDenied false ...

   kapok access Restrict {12345678-...} "allow {set puts info}"
   # => result true ... ruleSet {allow {set puts info}}
   ```

**Errors:** Returns error if *type* is not a valid `AccessChangeType`, if *apiKeyId* is null or not a valid GUID, if the modification fails (e.g., "access already granted"), or if *value* is required but missing or invalid.

**Notes:** The `Guid.Empty` value is explicitly forbidden as an API key identifier. After a successful modification, the sub-command automatically returns the updated query state.

---

<a id="cmd-kapok-certificate"></a>
##### `kapok certificate`

```
kapok certificate
```

Returns the file name of the plugin's configured license certificate file.

**Returns:** The certificate file path string.

**Errors:** Returns error if the certificate file name is null (no certificate configured) or the plugin reference is invalid.

**Notes:** Only available when compiled with `LICENSING`.

---

<a id="cmd-kapok-cleanup"></a>
##### `kapok cleanup`

```
kapok cleanup ?apiKeyId?
```

Disposes cached sandboxed interpreters. When an *apiKeyId* is specified, disposes only the interpreter associated with that API key and resets its token. When no argument is provided, disposes all cached interpreters across all tokens.

| Argument | Type | Description |
|----------|------|-------------|
| *apiKeyId* | GUID (optional) | The API key identifier whose cached interpreter should be cleaned up. If omitted, all cached interpreters are cleaned up. |

**Returns:** Empty string on success.

**Errors:** Returns error if *apiKeyId* is not a valid GUID, if the interpreter cannot be found or disposed, or if the token cannot be reset.

**Example:**
```tcl
kapok cleanup {12345678-1234-1234-1234-123456789abc}
# => (empty, interpreter for this API key disposed)

kapok cleanup
# => (empty, all cached interpreters disposed)
```

---

<a id="cmd-kapok-done"></a>
##### `kapok done`

```
kapok done action ?value?
```

Queries or sets the completion status of a one-time-per-AppDomain configuration action. These actions track whether certain initialization steps (such as configuring library paths, log files, or SQLite directories) have already been performed, preventing redundant execution.

| Argument | Type | Description |
|----------|------|-------------|
| *action* | ConfigurationAction | The configuration action to query or set. Supports flag-style combinations. |
| *value* | Boolean (optional) | If provided, marks or unmarks the action as done. |

**ConfigurationAction values:**

| Value | Description |
|-------|-------------|
| `MaybeConfigureSettings` | Configure server settings |
| `MaybeSetupLogFile` | Set up the log file |
| `MaybeSetupListeners` | Set up trace listeners |
| `DisablePackageRootPath` | Disable the package root path |
| `ConfigureLibrary` | Configure the script library path |
| `ConfigureAutoPath` | Configure the auto-path |
| `ConfigureSQLiteBaseDirectory` | Configure the SQLite base directory |

**Returns:** When querying (no *value*), returns a boolean indicating whether the action has been completed. When setting (*value* provided), returns a boolean indicating whether the mark operation succeeded.

**Errors:** Returns error if *action* is not a valid `ConfigurationAction` value, or if *value* is not a valid boolean.

**Example:**
```tcl
kapok done ConfigureLibrary
# => True  (library configuration has been performed)

kapok done MaybeSetupLogFile false
# => True  (successfully unmarked)
```

---

<a id="cmd-kapok-evaluate"></a>
##### `kapok evaluate`

```
kapok evaluate ?options? script
```

Evaluates a script in a sandboxed interpreter. By default, the interpreter is created in "safe" mode with a restricted command set. The interpreter is associated with an API key token (per-thread) and is reused across subsequent evaluations for the same token.

| Argument | Type | Description |
|----------|------|-------------|
| *script* | String | The Eagle script to evaluate in the sandbox. |

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `-apikeyid` | GUID | The API key identifier for this evaluation. Controls which sandbox interpreter is used and which access control rules apply. |
| `-args` | List | Command-line arguments to pass to the sandboxed interpreter. |
| `-ruleset` | RuleSet | An inline ruleset object to apply when creating the sandbox interpreter. Restricts which commands are available. |
| `-rulesetfilename` | String | Path to a ruleset file to load. If not fully qualified, resolved relative to the configured ruleset directory. |
| `-rulesettype` | RuleSetType | The type of ruleset file being loaded. Defaults to `KapokDefault`. |
| `-unsafe` | Boolean | If true and the API key belongs to an administrator, creates an "unsafe" interpreter with the full command set. Non-administrators are always sandboxed regardless of this option. |
| `-nobuiltins` | Boolean | If true, creates an interpreter with no built-in commands, functions, policies, or traces. |
| `-host` | String | The client's IP address or hostname. Used for host-based access control with CIDR matching. |
| `-allowhosts` | List | CIDR patterns of hosts that are explicitly allowed. If specified and the `-host` does not match any pattern, the request is denied. |
| `-denyhosts` | List | CIDR patterns of hosts that are explicitly denied. If the `-host` matches any pattern, the request is denied. |

**Returns:** The result of evaluating the script in the sandbox.

**Errors:** Returns error if:
- The API key is banned (in the deny list)
- The `-host` is not in the `-allowhosts` list (when specified)
- The `-host` matches a `-denyhosts` pattern
- The interpreter token cannot be created or found
- The ruleset file cannot be loaded
- The script evaluation fails

**Sandbox creation details:**

- Safe interpreters use `CreateFlags.SafeAndHideUnsafe` by default
- Unsafe interpreters require `-unsafe true` and an administrator API key
- The `-nobuiltins` option adds `CreateFlags.NoCommands | NoFunctions | NoCoreTraces | NoCorePolicies`
- When a ruleset is provided, `CreateFlags.UseNamespaces` is removed
- Interpreter settings are cached per-thread (unless the API key has its own token)
- The default ruleset file is `tcl84.ruleSet`

**Example:**
```tcl
kapok evaluate {expr {2 + 2}}
# => 4

kapok evaluate -apikeyid {12345678-...} -args {a b c} {
    return [llength $argv]
}
# => 3

kapok evaluate -host 10.0.0.5 -allowhosts {10.0.0.0/8} {puts hello}
# => (ok, host is in allowed range)
```

---

<a id="cmd-kapok-isolated"></a>
##### `kapok isolated`

```
kapok isolated
```

Returns whether the plugin is running in cross-AppDomain (isolated) mode.

**Returns:** A boolean (`True` or `False`).

**Errors:** Returns error if the plugin reference is invalid.

---

<a id="cmd-kapok-log"></a>
##### `kapok log`

```
kapok log message ?priority?
```

Writes a diagnostic message to both the native debug output (via `OutputDebugString`, when compiled with `NATIVE`) and the managed trace listeners (via `Utility.DebugTrace`).

| Argument | Type | Description |
|----------|------|-------------|
| *message* | String | The message to log. |
| *priority* | TracePriority (optional) | The trace priority level. Defaults to `AlwaysDemand` if omitted. Supports flag-style combinations. |

**Returns:** Empty string on success.

**Errors:** Returns error if *priority* is not a valid `TracePriority` value.

**Example:**
```tcl
kapok log "Server starting up"
# => (empty, message sent to debug output and trace listeners)

kapok log "Detailed info" MediumLow
# => (empty, message sent with MediumLow priority)
```

---

<a id="cmd-kapok-options"></a>
##### `kapok options`

```
kapok options
```

Returns the compile-time options (preprocessor defines) that were active when the Kapok plugin assembly was built.

**Returns:** A Tcl list of compile option strings.

**Errors:** Returns error if the plugin reference is invalid.

**Example:**
```tcl
kapok options
# => APPDOMAINS KAPOK KAPOK_PRIVATE LICENSING NATIVE NETWORK ...
```

---

<a id="cmd-kapok-setting"></a>
##### `kapok setting`

```
kapok setting name ?flags?
```

Retrieves a configuration setting value by name using the multi-source setting resolution chain. The setting is searched across script variables, .NET application settings, and environment variables, with optional indexed search and token expansion.

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The setting name to look up. |
| *flags* | SettingDataType (optional) | Flags controlling the search behavior and value validation. Defaults to `DefaultAndExpand` (`MustVerify | ForDefault | ExpandTokens`). Supports flag-style combinations. |

**SettingDataType value flags** (data type indicators):

| Flag | Description |
|------|-------------|
| `Boolean` | Value should be a boolean |
| `Integer` | Value should be a 32-bit integer |
| `WideInteger` | Value should be a 64-bit integer |
| `Enumeration` | Value should be an enumeration value |
| `String` | Value should be a plain string |
| `List` | Value should be an Eagle formatted list |
| `Script` | Value should be a script to evaluate |
| `TypeName` | Value should be a .NET type name |
| `EncodingName` | Value should be an encoding name |
| `FileName` | Value should be a file path |
| `DirectoryName` | Value should be a directory path |

**SettingDataType behavior flags:**

| Flag | Description |
|------|-------------|
| `AllowEmpty` | Allow null or empty string values |
| `NoExists` | Allow file/directory paths that do not exist |
| `ExpandTokens` | Replace runtime tokens in the value |
| `NoSearch` | Do not search indexed variants (skip `name1` through `name9`) |
| `MustVerify` | Return null if no candidate value can be verified |
| `CreatePath` | Create the file or directory if it does not exist |
| `NoVariableValue` | Skip script variable lookup |
| `NoAppSetting` | Skip .NET application setting lookup |
| `NoEnvironment` | Skip environment variable lookup |
| `TraceOk` | Emit a diagnostic trace on success |
| `TraceError` | Emit a diagnostic trace on failure |

**Common composite flags:**

| Flag | Composition |
|------|-------------|
| `Default` | `MustVerify | ForDefault` |
| `DefaultAndExpand` | `Default | ExpandTokens` |
| `StringListMask` | `Default | String | List | AllowEmpty` |
| `PathMask` | `FileName | DirectoryName` |

**Returns:** The resolved setting value, or null/empty if not found.

**Errors:** Returns error if *flags* is not a valid `SettingDataType` value.

**Example:**
```tcl
kapok setting ServerCertificate
# => /path/to/certificate.cer

kapok setting MyCustomSetting String,AllowEmpty,NoSearch
# => (value from first matching source)
```

---

<a id="cmd-kapok-source"></a>
##### `kapok source`

```
kapok source
```

Returns the source control identifier and timestamp of the Kapok plugin assembly.

**Returns:** A two-element Tcl list: `{sourceId sourceTimestamp}`.

**Errors:** Returns error if the assembly reference is invalid.

**Example:**
```tcl
kapok source
# => {abc123def456 2024-01-15T12:00:00.000}
```

---

## Server Architecture

The Kapok web server processes requests through a multi-phase pipeline and manages a pool of cached interpreters for script evaluation.

<a id="server-pipeline"></a>
### Request Processing Pipeline

The `Server.Handler` method orchestrates request processing through the following phases, tracked by the `ServerPhase` enumeration:

```
Parameters ──> StartResponse ──> Configure ──> Certificates ──> PreValidate
     │                                                              │
     │              PreValidateResponse <─── (early return) ────────┘
     │                                                              │
     ▼                                                              ▼
Freshness ──> PackagePaths ──> ScriptLibrary ──> AutoPath ──> SQLite
     │
     ▼
DumpEnvironment ──> Validate ──> Interpreter ──> SdkSecurity ──> Licensed
                        │                                           │
                        │        ValidateResponse <── (early) ──────┘
                        │                                           │
                        ▼                                           ▼
                   SetArguments ──> EvaluateSetup ──> Handle (non-scripted)
                                         │
                                         ▼
                                    CheckFile ──> BuildResponse
                                         │
                        ┌────────────────┴────────────────┐
                        ▼                                  ▼
                 ValidateBlocks                      EvaluateFile
                        │                                  │
                   ReadBlocks                              │
                        │                                  │
                  ProcessBlocks                            │
                        │                                  │
                        └──────────┬───────────────────────┘
                                   ▼
                              EndResponse
```

**Key phases:**

| Phase | Description |
|-------|-------------|
| `Configure` | Loads page settings via `ConfigureScriptRequest` |
| `Certificates` | Discovers and configures license certificates (when licensing enabled) |
| `PreValidate` | Pre-validation; may return early with a response |
| `Freshness` | Checks whether a new interpreter needs to be created |
| `PackagePaths` / `ScriptLibrary` / `AutoPath` | One-time library path configuration (tracked via `ConfigurationAction`) |
| `SQLite` | One-time SQLite base directory configuration |
| `Validate` | Full request validation; extracts arguments |
| `Interpreter` | Gets or creates a cached interpreter for the current thread |
| `SdkSecurity` / `Licensed` | Harpy/Badge plugin loading and license verification (for new interpreters) |
| `EvaluateSetup` | Evaluates the setup script, if configured |
| `Handle` | For non-scripted pages: delegates to `HandleScriptRequest` |
| `EvaluateFile` | Evaluates the configured script file |
| `ProcessBlocks` | Alternative: processes script blocks within an HTML template |
| `EndResponse` | Flushes output and completes the response |

The `fatalError` flag is initially `true` and is set to `false` only when the method completes through the `finally` block, ensuring the caller can detect incomplete processing.

<a id="server-interpreter-caching"></a>
### Interpreter Caching

The `InterpreterOps` class manages a thread-local cache of interpreters by `InterpreterPhase`:

| Phase | Purpose |
|-------|---------|
| `Validate` | Used during request validation |
| `Configuration` | Used during server configuration |
| `Server` | Used during script evaluation (the primary phase) |

**Cache behavior:**

- Interpreters are cached per-thread using `ThreadStatic` fields
- Staleness detection compares the interpreter's creation time against a configurable `CacheSeconds` threshold
- When an interpreter is detected as stale or disposed, it is automatically refreshed
- The `MaybeCleanupStale` method runs after each request to dispose of stale interpreters across all threads

---

## Token Management

The `SandboxOps.TokenManagement` class implements the access control model used by `kapok access` and `kapok evaluate`. It maintains five static dictionaries, all synchronized via a shared `syncRoot` lock:

| Dictionary | Key | Value | Purpose |
|------------|-----|-------|---------|
| `allowTokens` | GUID | `ulong?` | API keys explicitly granted access; value is the interpreter token |
| `denyTokens` | GUID | `ulong?` | API keys explicitly banned |
| `administratorTokens` | GUID | `ulong?` | API keys with administrator privileges |
| `fakeTokens` | GUID | `ulong?` | API keys in simulated-only mode |
| `ruleSets` | GUID | `IRuleSet` | Per-key command restriction rulesets |

Additionally, a `ThreadStatic` field `anonymousToken` provides a per-thread global token for requests without an explicit API key.

**Token lifecycle:**

1. `Have()` — Checks for an existing token: first in `allowTokens` by API key, then falls back to the thread's `anonymousToken`
2. `Create()` — Generates a random token: stores it in `allowTokens` (if the key is present with a null token) or in `anonymousToken`
3. `Reset()` — Removes the token from `allowTokens` or clears `anonymousToken`
4. `Cleanup()` — Iterates all tokens and invokes a dispose callback for each

**Access check order** (in `GetOrCreateInterpreter`):

1. Check `denyTokens` — banned keys are rejected immediately
2. Check `-host` against `-allowhosts` via CIDR matching (if provided)
3. Check `-host` against `-denyhosts` via CIDR matching (if provided)
4. Get or create a token via `TokenManagement`
5. Create an interpreter: safe by default, unsafe only if `-unsafe true` AND key is in `administratorTokens`
6. Apply `-nobuiltins` flags if requested
7. Apply the ruleset from `ruleSets` dictionary, `-ruleset` option, or `-rulesetfilename` option

---

## Throttle Subsystem

The `ThrottleOps` class provides rate limiting to prevent abuse of the script evaluation server. Two algorithms are supported:

### Fixed-Window Throttling

Tracks requests per client using a dictionary keyed by `"{clientIP}-{requestType}"`. Each entry stores:
- `X` — The DateTime of the first tracked request in the current window
- `Y` — The request count within the current window
- `Z` — The lifetime request count

**Default limits:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| Maximum client count | 1 | Maximum concurrent clients |
| Maximum lifetime count | 32 | Maximum total requests before process restart |
| Maximum interval count | 7 | Maximum requests per time window |
| Maximum interval seconds | 604,800 (7 days) | Time window duration |

When the elapsed time exceeds the maximum seconds, the interval count is divided by the number of elapsed intervals, effectively decaying old request counts.

### Sliding-Window Throttling

Available when compiled with `KAPOK_PRIVATE` or `EAGLE_BETA_56`. Uses a `ThrottleDictionary` that tracks individual request timestamps, providing more accurate rate limiting than fixed windows.

### API Key Status

The throttle subsystem recognizes these API key status levels:

| Status | Description |
|--------|-------------|
| `Error` | No keys configured; cannot determine status |
| `Unknown` | Key not found; access denied |
| `Banned` | Key found but administratively banned |
| `Anonymous` | No key specified; anonymous access |
| `Restricted` | Key found; limited access |
| `Standard` | Key found; normal user access |
| `Administrator` | Key found; administrator access (exempt from throttle enforcement) |

**Throttle check flow** (in `IsBadRequest`):

1. Check if the API key is denied/unknown — always rejected
2. Determine if the caller is an administrator — administrators are tracked but exempt from limits
3. Check for non-human requests (missing `raw`/`superRaw` query parameters and non-standard API key)
4. Validate the request key format
5. Check per-client throttle limits
6. Check per-server throttle limits (using `maximumCount * maximumClientCount`)
7. If either check fails and the caller is not an administrator, reject the request

---

## Setting Resolution Order

When `kapok setting` (or the internal `WebSettingsOps.GetGlobal`) is called, the setting value is resolved through a multi-source chain:

1. **Assembly configuration prefix** — If the assembly has a configuration name, try `{configuration}.{settingName}` first, then fall back to `{settingName}` alone.

2. **Indexed search** — For each configuration prefix, try the base name, then `{name}1` through `{name}9` (unless `NoSearch` is set). The search range can be overridden via `{name}_SettingMinimumIndex` and `{name}_SettingMaximumIndex` script variables.

3. **Source priority** (for each indexed name):
   - **Script variable** — Via `WebScriptOps.GetVariableValue` (skipped if `NoVariableValue`)
   - **.NET application setting** — Via `Utility.GetAppSetting` (skipped if `NoAppSetting`)
   - **Environment variable** — Via `EnvironmentOps.GetVariableValue` (skipped if `NoEnvironment`)

4. **Token expansion** — If `ExpandTokens` is set and the value is non-empty, runtime tokens are replaced via `WebTokenOps.Expand`.

5. **Verification** — The value is validated against the data type (e.g., file existence for `FileName`, boolean parsing for `Boolean`). If `MustVerify` is set and no value passes verification, null is returned.

The first value that passes verification is returned. If no value is found across all indexed names and configuration prefixes, null is returned (or the last unverified value, if `MustVerify` is not set).

---

## Script Library

The Kapok plugin ships with four packages registered in `pkgIndex.eagle`:

### Kapok.Enterprise v1.0

The plugin itself, loaded from `Kapok.dll`. Registers the `kapok` command.

### Eagle.CIDR v1.0

Provides IP address CIDR (Classless Inter-Domain Routing) matching for host-based access control.

**Procedures:**

| Procedure | Description |
|-----------|-------------|
| `maybeLoadCidrs` | Loads CIDR definitions from a file if not already loaded |
| `getCidrFileName` | Returns the path to the CIDR definitions file |
| `loadCidrFileFast` | Reads and parses a CIDR file efficiently |
| `matchViaCidr` | Tests whether an IP address matches any CIDR pattern in a list |

### Eagle.Signing v1.0

Provides script signing capabilities using the Harpy sign tool.

**Procedures:**

| Procedure | Description |
|-----------|-------------|
| `eagle_sign_script` | Signs an Eagle script file using the Harpy cryptographic signing tool |

### Eagle.OpenAI v1.0

Provides an OpenAI API proxy for server-side AI integration.

**Procedures:**

| Procedure | Description |
|-----------|-------------|
| `openAI_server_maybe_load_configuration` | Loads OpenAI proxy configuration settings |
| `openAI_check_address` | Validates a client address for OpenAI proxy access |
| `openAI_check_access` | Checks API key access for OpenAI proxy requests |
| `openAI_get_fake_response_data` | Returns simulated response data for testing |
| `openAI_sign_script` | Signs a script returned in an OpenAI response |
| `openAI_server_chatCompletion` | Proxies a chat completion request to the OpenAI API |

---

## Plugin Variant

The Kapok assembly contains a single plugin class:

| Package Name | Class | Plugin Flags | Description |
|---|---|---|---|
| `Kapok.Enterprise` | `Kapok.Enterprise` | Primary, User, Commercial, NoFunctions, NoPolicies, NoTraces | Standard entry point. Registers the `kapok` command. |

The `Enterprise` class handles:

- **Initialize** — Sets up well-known configuration data, verifies the license certificate (when `LICENSING` is defined), sets the `Licensed` flag, then calls `base.Initialize()`
- **Terminate** — Clears certificate data, removes the `Licensed` flag, then calls `base.Terminate()`
- **GetCertificateFileName** — Returns the certificate file path; supports named certificate types via `Utility.GetPluginRelativeFileName`
- **GetCertificate** — Returns the certificate object (not supported in cross-AppDomain mode)
- **About** — Returns formatted plugin information with optional certificate details
- **Options** — Returns the compile-time option list from `DefineConstants.OptionList`

---

## Conditional Compilation

The Kapok plugin supports a large number of compile-time flags. The most significant feature-gating flags are:

| Flag | Features Gated |
|------|---------------|
| `KAPOK` | Core Kapok functionality; enables Eagle-specific attributes and types |
| `KAPOK_PRIVATE` | The private sandbox/throttle components: the whole `SandboxOps` class (sandboxed evaluation and `TokenManagement` access control) and the sliding-window throttle support in `ThrottleOps` (also enabled by `EAGLE_BETA_56`). Note: `InterpreterOps`, `WebSettingsOps`, and `Server` are **not** gated by this flag. |
| `LICENSING` | License certificate verification during `Initialize`, the `certificate` sub-command, `About` with certificate details, `Terminate` cleanup |
| `NATIVE` | Native `OutputDebugString` in the `log` sub-command |
| `NETWORK` | Network-related functionality |
| `SECURITY` | Security subsystem integration |
| `TEST` | Ruleset file loading from disk (`RuleSet.CreateFromFile`); without this flag, ruleset file loading returns "not implemented" |
| `APPDOMAINS` | AppDomain support for plugin isolation |
| `ISOLATED_INTERPRETERS` | Isolated interpreter support |
| `ISOLATED_PLUGINS` | Cross-AppDomain plugin isolation |
| `OBFUSCATION` | Assembly obfuscation support (renaming protection) |
| `DEBUG` | Debug-mode features: disposed interpreter retry logic, error information copying, environment dumping defaults |
| `THROW_ON_DISPOSED` | Throws `ObjectDisposedException` when accessing disposed server objects |
| `OPEN_SSL` | OpenSSL integration |
| `XML` | XML processing support |
| `CONSOLE` | Console output support |
| `DEMO_EDITION` | Demo edition restrictions |
| `LIMITED_EDITION` | Limited edition restrictions |
| `ENTERPRISE_LOCKDOWN` | Additional restrictions on security operations |
