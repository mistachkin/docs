# Badge Plugin Command Catalog

> **For AI agents**: This document catalogs all script commands provided by the Badge plugin (Eagle Enterprise Edition). The Badge plugin provides signed script certificate resources and a string override mechanism for the Eagle script engine. Use the [Command Summary](#command-summary) for a quick overview. The single `badge` ensemble command has an anchor `#cmd-badge` for direct linking. Options marked **(Unsafe)** require an unsafe execution context.

## Table of Contents

- [Overview](#overview)
- [Command Summary](#command-summary)
- [Commands](#commands)
  - [`badge`](#cmd-badge) — Plugin state, string management, and diagnostics (15 sub-commands)
    - [`about`](#cmd-badge-about)
    - [`certificate`](#cmd-badge-certificate)
    - [`clearstrings`](#cmd-badge-clearstrings)
    - [`enable`](#cmd-badge-enable)
    - [`getstring`](#cmd-badge-getstring)
    - [`isolated`](#cmd-badge-isolated)
    - [`liststrings`](#cmd-badge-liststrings)
    - [`names`](#cmd-badge-names)
    - [`nullstring`](#cmd-badge-nullstring)
    - [`options`](#cmd-badge-options)
    - [`removestring`](#cmd-badge-removestring)
    - [`renullstring`](#cmd-badge-renullstring)
    - [`resetstring`](#cmd-badge-resetstring)
    - [`setstring`](#cmd-badge-setstring)
    - [`test`](#cmd-badge-test)
- [Plugin Variants](#plugin-variants)
- [String Resolution Order](#string-resolution-order)
- [Conditional Compilation](#conditional-compilation)

---

## Overview

The **Badge** plugin is the Eagle Enterprise Edition script certificate and resource string management subsystem. Like all Eagle Enterprise Edition plugins, it requires a valid license certificate by default, but is now also open source. It provides:

- **Signed script certificates** — Embedded resource strings (script files and their cryptographic signatures) that the Eagle script engine uses to verify script authenticity
- **String override mechanism** — A runtime dictionary that can augment or override embedded resource strings, enabling dynamic certificate and script management
- **Enable/disable control** — The plugin's `GetString` interface can be toggled on or off at runtime, controlling whether the script engine can resolve resource names through this plugin
- **License certificate integration** — Optional license verification during plugin initialization (when compiled with `LICENSING`)

### Architecture

The Badge plugin provides a single ensemble command (`badge`) with 15 sub-commands. The command class inherits from `Eagle._Commands.Default` and is marked with `CommandFlags.Unsafe` and the `certificateManagement` object group.

The plugin has three class variants that share the same `Default` base class:

- **`Badge.Enterprise`** — The primary plugin, loaded as a standard Eagle package
- **`Security.Certificates`** — An alternate entry point with `IsolatedOnly` support and `UpdateCheck` capability (when compiled with `SHELL`)
- **`Plugins.Default`** — The shared base class containing all `GetString`, `Execute`, and lifecycle logic

Many sub-commands delegate to the plugin's `Execute` method (the `IExecuteRequest` interface), which handles cross-AppDomain communication. The command constructs a `string[]` request array and dispatches it to the plugin, which processes it and returns a response object.

### Key Concepts

**String dictionary:** The plugin maintains an internal `StringDictionary` called `strings`. Entries in this dictionary override embedded resource strings of the same name. When the `GetString` method is called (by the script engine or by the `test` sub-command), the dictionary is checked first; only if the name is not found there does the plugin fall back to embedded resources.

**Enabled state:** The `enabled` boolean controls whether the plugin's `GetString` method returns results. When disabled, all lookups return `null` with the error "plugin strings not enabled". The plugin is enabled by default unless the `BadgePluginDisabled` environment variable is set.

---

## Common patterns

*Test-verified quick start (from `Plugins/Commercial/Enterprise/Badge/Tests/basic.eagle` and `Tools/verify.eagle`). Badge exposes embedded signed-script resources plus a runtime string-override map; `badge enable false` makes all Badge resources resolve as "no such file".*

Load:

```eagle
package require Badge.Enterprise        ;# [badge]
package require Security.Certificates    ;# verified reads / signature policy (optional)
```

Enumerate resources and toggle interception:

```eagle
lsort [badge names]
set saved [badge enable]; badge enable true; ...; badge enable $saved
```

Shim / replace an embedded resource at runtime:

```eagle
badge setstring   $name ""      ;# add (errors "key already present" on dup)
badge resetstring $name $value  ;# idempotent set-or-replace
badge getstring   $name
badge removestring $name        ;# errors "key not present" if absent
```

Mask a resource as missing:

```eagle
badge nullstring someResource   ;# `badge test someResource` -> "string not found"
badge clearstrings              ;# restore
```

Read a resource with signature enforcement:

```eagle
certificate policy -enabled true
interp readorgetscriptfile -scriptflags [combineFlags $pluginFlags "+NoXml NoPolicy"] -- "" $name
```

`Tools/verify.eagle` is a ready-to-run CLI that batch-verifies signatures across an Eagle tree.

## Command Summary

| Command | Type | Sub-commands | Command Flags | Description |
|---------|------|-------------|---------------|-------------|
| [`badge`](#cmd-badge) | Ensemble | 15 | Unsafe | Plugin state, string management, and diagnostics |

---

## Commands

---

<a id="cmd-badge"></a>
### `badge` — Plugin State, String Management, and Diagnostics

```
badge option ?arg ...?
```

The single Badge command is an ensemble with 15 sub-commands for managing the plugin's string dictionary, querying plugin state, and performing diagnostics. All sub-commands are dispatched via `Utility.TryExecuteSubCommandFromEnsemble`.

**Command flags:** `CommandFlags.Unsafe`

**Object group:** `certificateManagement`

#### Sub-commands

---

<a id="cmd-badge-about"></a>
##### `badge about`

```
badge about
```

Returns plugin "about" information, including version, copyright, and license certificate details. Delegates to the plugin's `About` method.

Both loadable variants format the plugin about text via `Utility.FormatPluginAbout` and then append license certificate details through the shared base `About` method; they differ only in a formatting flag passed to `FormatPluginAbout` (the `Security.Certificates` variant requests the certificate-oriented form).

**Returns:** Plugin about string.

**Errors:** Returns error if the plugin reference is invalid.

---

<a id="cmd-badge-certificate"></a>
##### `badge certificate`

```
badge certificate
```

Returns the file name of the plugin's configured license certificate file.

**Returns:** The certificate file path string, or an error if the file name is null (no certificate configured) or the plugin reference is invalid.

**Notes:** Only available when compiled with `LICENSING`.

---

<a id="cmd-badge-clearstrings"></a>
##### `badge clearstrings`

```
badge clearstrings
```

Removes all entries from the plugin's string override dictionary.

**Returns:** An integer — the number of entries that were in the dictionary before clearing.

**Errors:** Returns error if the plugin reference is invalid or the internal dictionary is null.

**Example:**
```tcl
badge clearstrings
# => 3  (three entries were removed)
```

---

<a id="cmd-badge-enable"></a>
##### `badge enable`

```
badge enable ?enabled?
```

Queries or sets the plugin's enabled state. When disabled, the plugin's `GetString` method returns null for all lookups, effectively making all script certificate resources unavailable to the script engine.

| Argument | Type | Description |
|----------|------|-------------|
| *enabled* | Boolean (optional) | If provided, sets the enabled state. Accepts any boolean format (true/false, yes/no, 1/0, on/off). |

**Returns:** The current enabled state as a boolean (`True` or `False`), reflecting the state after any change.

**Errors:** Returns error if *enabled* is not a valid boolean value, or if the plugin reference is invalid.

**Example:**
```tcl
badge enable          ;# query: => True
badge enable false    ;# disable: => False
badge enable true     ;# re-enable: => True
```

---

<a id="cmd-badge-getstring"></a>
##### `badge getstring`

```
badge getstring name
```

Retrieves a string from the plugin's override dictionary by name.

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The key to look up in the string override dictionary. |

**Returns:** The string value associated with *name*.

**Errors:** Returns error if *name* is not present in the dictionary, if the retrieved value is null ("string is null"), or if the plugin reference is invalid.

**Notes:** This only searches the override dictionary, not the embedded resources. Use `badge test` to search the full resolution chain (override dictionary, then embedded resources).

**Example:**
```tcl
badge setstring myKey "hello"
badge getstring myKey
# => hello
```

---

<a id="cmd-badge-isolated"></a>
##### `badge isolated`

```
badge isolated
```

Returns whether the plugin is running in cross-AppDomain (isolated) mode.

**Returns:** A boolean (`True` or `False`).

**Errors:** Returns error if the plugin reference is invalid.

---

<a id="cmd-badge-liststrings"></a>
##### `badge liststrings`

```
badge liststrings
```

Returns the names (keys) of all entries in the plugin's string override dictionary.

**Returns:** A Tcl list of string names. Returns an empty list `{}` if the dictionary has no entries.

**Errors:** Returns error if the plugin reference is invalid or the internal dictionary is null.

**Example:**
```tcl
badge setstring key1 "value1"
badge setstring key2 "value2"
badge liststrings
# => key1 key2
```

---

<a id="cmd-badge-names"></a>
##### `badge names`

```
badge names
```

Returns the names of all embedded resource strings available in the plugin assembly. These are the resource names that can be resolved via the `GetString` interface (subject to override by the string dictionary).

**Returns:** A Tcl list of resource name strings.

**Errors:** Returns error if the resource names cannot be retrieved.

---

<a id="cmd-badge-nullstring"></a>
##### `badge nullstring`

```
badge nullstring name
```

Adds an entry to the string override dictionary with the given *name* and a `null` value. This effectively "blocks" the named resource — when the script engine calls `GetString` for this name, the override dictionary will match but return null, preventing fallback to embedded resources.

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The key to add to the string override dictionary. |

**Returns:** A boolean — `True` when the entry was newly added (add-only semantics; an already-present key is an error rather than a `False` return).

**Errors:** Returns error if *name* already exists in the dictionary ("key already present"), or if the plugin reference is invalid.

**Notes:** Like `setstring`, this sub-command uses add-only semantics — it will not overwrite an existing entry. Use `renullstring` to overwrite an existing entry with null.

**Example:**
```tcl
badge nullstring badgeEmpty
# => True  (entry added with null value)

badge nullstring badgeEmpty
# => error: key already present
```

---

<a id="cmd-badge-options"></a>
##### `badge options`

```
badge options
```

Returns the compile-time options (preprocessor defines) that were active when the Badge plugin assembly was built.

**Returns:** A Tcl list of compile option strings (e.g., `PLUGIN_COMMANDS`, `LICENSING`, `CERTIFICATE_PLUGIN`, etc.).

**Example:**
```tcl
badge options
# => APPDOMAINS CERTIFICATE_PLUGIN CERTIFICATE_POLICY LICENSING PLUGIN_COMMANDS ...
```

---

<a id="cmd-badge-removestring"></a>
##### `badge removestring`

```
badge removestring name
```

Removes an entry from the string override dictionary by name.

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The key to remove from the string override dictionary. |

**Returns:** An empty string on success.

**Errors:** Returns error if *name* is not present in the dictionary ("key not present"), or if the plugin reference is invalid.

**Example:**
```tcl
badge setstring myKey "hello"
badge removestring myKey
# => (empty string)

badge removestring myKey
# => error: key not present
```

---

<a id="cmd-badge-renullstring"></a>
##### `badge renullstring`

```
badge renullstring name
```

Sets an entry in the string override dictionary with the given *name* and a `null` value, creating or overwriting the entry. This is the "replace" variant of `nullstring`.

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The key to set in the string override dictionary. |

**Returns:** A boolean — `True` if the entry was newly added, `False` if an existing entry was overwritten.

**Notes:** Unlike `nullstring`, this sub-command uses replace semantics — it will overwrite an existing entry. The resulting dictionary entry has a null value, which blocks resource resolution for that name.

**Example:**
```tcl
badge setstring myKey "hello"
badge renullstring myKey
# => False  (existing entry overwritten with null)
```

---

<a id="cmd-badge-resetstring"></a>
##### `badge resetstring`

```
badge resetstring name value
```

Sets an entry in the string override dictionary, creating or overwriting the entry. This is the "replace" variant of `setstring`.

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The key to set in the string override dictionary. |
| *value* | String | The value to associate with *name*. |

**Returns:** A boolean — `True` if the entry was newly added, `False` if an existing entry was overwritten.

**Notes:** Unlike `setstring`, this sub-command uses replace semantics — it will overwrite an existing entry with the new value.

**Example:**
```tcl
badge setstring myKey "original"
badge resetstring myKey "updated"
# => False  (existing entry overwritten)

badge getstring myKey
# => updated
```

---

<a id="cmd-badge-setstring"></a>
##### `badge setstring`

```
badge setstring name value
```

Adds an entry to the string override dictionary with the given *name* and *value*, using add-only semantics.

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The key to add to the string override dictionary. |
| *value* | String | The value to associate with *name*. |

**Returns:** A boolean — `True` if the entry was newly added.

**Errors:** Returns error if *name* already exists in the dictionary ("key already present"), or if the plugin reference is invalid.

**Notes:** This sub-command will not overwrite an existing entry. Use `resetstring` to create-or-overwrite.

**Example:**
```tcl
badge setstring myKey "hello"
# => True

badge setstring myKey "world"
# => error: key already present
```

---

<a id="cmd-badge-test"></a>
##### `badge test`

```
badge test name
```

Looks up a string by name using the full `GetString` resolution chain: first the string override dictionary, then embedded resources (with both verbatim and package-relative name lookups).

| Argument | Type | Description |
|----------|------|-------------|
| *name* | String | The resource name to look up. |

**Returns:** The resolved string value.

**Errors:** Returns error if the string cannot be found through any resolution path ("string not found"), or if the plugin's `GetString` returns null with an error, or if the plugin reference is invalid.

**Notes:** This sub-command tests the complete resolution path that the script engine uses. It is useful for verifying that a particular resource name resolves correctly, whether from the override dictionary or from embedded resources.

**Example:**
```tcl
badge test pkgIndex.eagle.harpy
# => (contents of the embedded script certificate)

badge setstring custom "my override"
badge test custom
# => my override
```

---

## Plugin Variants

The Badge assembly contains three plugin classes: two loadable variants (below) plus their shared `Badge.Plugins.Default` base class.

| Package Name | Class | Primary | Isolated Support | Description |
|---|---|---|---|---|
| `Badge.Enterprise` | `Badge.Enterprise` | Yes | No | Standard entry point. Registers the `badge` command. |
| `Security.Certificates` | `Security.Certificates` | Yes (when `PLUGIN_COMMANDS` is not defined) | Yes (`IsolatedOnly`) | Alternate entry point for security certificate delivery. When `SHELL` is defined, also supports `UpdateCheck`. |

Both classes inherit from `Badge.Plugins.Default`, which contains all shared logic:

- `GetString` method — resolves resource names through the override dictionary and embedded resources
- `Execute` method — handles `IExecuteRequest` dispatching for cross-AppDomain sub-command execution
- `Initialize`/`Terminate` — license certificate verification lifecycle
- `Banner` — displays plugin status on interpreter startup (only for `Security.Certificates`)
- `Status` — returns plugin enabled/disabled state
- `Options` — returns compile-time option list

---

## String Resolution Order

When the `GetString` method is called (either by the script engine or by `badge test`), name resolution follows this order:

1. **Enabled check** — If the plugin is disabled, return null with "plugin strings not enabled".

2. **Override dictionary lookup** — Search the `strings` dictionary for an exact match on the requested name. If found, return the value (which may be null for `nullstring`/`renullstring` entries).

3. **Verbatim resource lookup** — Call `Utility.GetAnyString` with the exact name against the plugin's `ResourceManager` (embedded assembly resources).

4. **Package-relative resource lookup** — Convert the name to a package-relative file path via `Utility.GetPackageRelativeFileName`, translate to Unix path separators, and search the `ResourceManager` again with the translated name.

5. **Failure** — If none of the above succeed, return null with accumulated errors.

---

## Conditional Compilation

Some features require specific compile-time flags:

These are the conditional compilation symbols actually referenced by the Badge plugin's C# source:

| Flag | Features Gated |
|------|---------------|
| `PLUGIN_COMMANDS` | The `badge` command itself, the `Execute` request-dispatch method, the `enabled` flag, the `strings` override dictionary, the `GetSimpleName`/`IsSecurityCertificates` helpers, and the `Banner` and `Status` methods. Also selects the command-plugin flags on `Security.Certificates`. |
| `LICENSING` | License certificate verification during `Initialize`, the certificate fields and `GetCertificate`/`GetCertificateFileName`/`SetFlagAndData` members, the `certificate` sub-command, `About` with certificate details, and `Terminate` cleanup. |
| `ISOLATED_PLUGINS` | The `IsolatedOnly` (and, with `SHELL`, `UpdateCheck`) plugin flags on `Security.Certificates`, and isolation-aware certificate access. |
| `SHELL` | The `UpdateCheck` plugin flag on `Security.Certificates` (when also non-`PLUGIN_COMMANDS` and isolated). |
| `OBFUSCATION` | Applies the `[Obfuscation]` renaming attribute to the command and plugin classes. |
| `CONSOLE` | Selects the console color type used by `Banner` output. |
| `MONO_BUILD` | Suppresses an unused-field warning for the certificate file name under Mono. |
| `DEBUG` / `FORCE_TRACE` | Enables diagnostic trace output in `GetString`. |

### Environment Variables

| Variable | Effect |
|----------|--------|
| `BadgePluginDisabled` | When set (to any value), the plugin's `GetString` method is disabled at construction time. The `enabled` flag defaults to `false`. |
