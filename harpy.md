# Harpy Plugin Command Catalog

> **For AI agents**: This document catalogs all script commands provided by the Harpy plugin (Eagle Enterprise Edition). Use the [Command Summary](#command-summary) for a quick overview. Each command has an anchor `#cmd-NAME` for direct linking. Enum types accepted as arguments are documented in the [Enum Reference](#enum-reference) appendix. Options marked **(Unsafe)** require an unsafe execution context. The [Configuration Subsystem Architecture](#configuration-subsystem-architecture) section explains the design, structure, and robustness guarantees of the configuration subsystem. The [Configuration Subsystem Commands](#configuration-subsystem-commands) section documents 107 transient commands available only during plugin configuration script evaluation. The [Installation Subsystem](#installation-subsystem) section documents the multi-phase package installation mechanism.

## Table of Contents

- [Overview](#overview)
- [Command Summary](#command-summary)
- [Commands](#commands)
  - [`certificate`](#cmd-certificate) — Certificate and license management (52 sub-commands)
  - [`cryptography`](#cmd-cryptography) — Symmetric/asymmetric encryption, signing, and verification (16 sub-commands)
  - [`flags`](#cmd-flags) — Attribute flag string manipulation (8 sub-commands)
  - [`harpy`](#cmd-harpy) — Plugin state, configuration, and diagnostics (27 sub-commands)
  - [`keval`](#cmd-keval) — Evaluate script in secure context
  - [`keypair`](#cmd-keypair) — Cryptographic key pair management (15 sub-commands)
  - [`keyring`](#cmd-keyring) — Trusted key ring management (20 sub-commands)
  - [`ksource`](#cmd-ksource) — Source script file in sandboxed context
  - [`secret`](#cmd-secret) — Remote secret management (7 sub-commands)
  - [`security`](#cmd-security) — Enable or disable security policy
  - [`storage`](#cmd-storage) — Persistent storage operations (10 sub-commands)
  - [`support`](#cmd-support) — Diagnostics and support information (4 sub-commands)
- [Configuration Subsystem Architecture](#configuration-subsystem-architecture)
  - [Entry Points and Call Chain](#arch-entry-points)
  - [Configuration File Discovery](#arch-file-discovery)
  - [EvaluateClientData — The Central State Carrier](#arch-evaluate-client-data)
  - [Context Variables and the Two-Phase Model](#arch-context-variables)
  - [Transient Command Lifecycle](#arch-transient-commands)
  - [Per-File Evaluation Flow](#arch-per-file-flow)
  - [Error Handling and Robustness Guarantees](#arch-error-handling)
  - [Security Model](#arch-security-model)
  - [Dynamic Script Queuing](#arch-dynamic-queuing)
  - [Cross-AppDomain Support](#arch-cross-appdomain)
  - [Thread Safety](#arch-thread-safety)
  - [Plugin Lifecycle Integration](#arch-plugin-lifecycle)
- [Configuration Subsystem Commands](#configuration-subsystem-commands)
  - [Overview](#config-overview)
  - [Quick Reference](#config-quick-reference)
  - [Flow Control](#config-flow-control)
  - [Script Evaluation](#config-script-evaluation)
  - [Context Variable Management](#config-context-variables)
  - [Interpreter Variable Management](#config-interpreter-variables)
  - [Property and Mode Management](#config-property-management)
  - [Feature and Policy Management](#config-feature-policy)
  - [Key and Certificate Management](#config-key-cert)
  - [Requirement Checks](#config-requirements)
  - [Introspection and Status](#config-introspection)
  - [Time and Version Validation](#config-time-version)
  - [Iteration](#config-iteration)
  - [Output and Diagnostics](#config-output)
  - [Ensemble Sub-Commands](#config-ensembles)
  - [Network and Licensing](#config-network)
  - [Sandbox Testing](#config-sandbox)
- [Installation Subsystem](#installation-subsystem)
  - [Installation Class Overview](#licensingcomponentsprivatecommandshelpersinstallation-class)
  - [Installation Phases](#installation-phases-passes)
  - [Manifest Script Interface](#manifest-script-interface)
  - [InstallFlags Enumeration](#installflags-enumeration)
  - [InstallPass Enumeration](#installpass-enumeration)
  - [Result Structure](#result-structure)
  - [Test Coverage](#test-coverage)
  - [State Diagram](#state-diagram)
  - [Thread Safety](#thread-safety)
- [Enum Reference](#enum-reference)

---

## Overview

The **Harpy** plugin is the Eagle Enterprise Edition security and licensing subsystem. Like all Eagle Enterprise Edition plugins, it requires a valid license certificate by default, but is now also open source. It provides:

- **Script signing and verification** — RSA and DSA digital signatures for scripts, files, and strings
- **Certificate management** — XML-based license certificates with expiration, revocation, and feature flags
- **Execution policy enforcement** — Configurable policies controlling which scripts may execute
- **Cryptographic operations** — Symmetric encryption (AES, RC4), asymmetric signing, HMAC, hashing
- **Key pair and key ring management** — Public/private key handling with trust chains
- **Sandboxed script evaluation** — `keval` and `ksource` for policy-controlled execution
- **Persistent storage** — Registry-based and interpreter-based secure storage
- **Remote secret management** — API-based secret generation, retrieval, and deletion

### Architecture

All Harpy commands inherit from a base `Default` class that implements `ILicenseCommand`. Before any command executes, `CanExecute()` verifies that the current license certificate has the required feature flags. Commands are grouped into two categories:

- **Ensemble commands** (with sub-commands): `certificate`, `cryptography`, `flags`, `harpy`, `keypair`, `keyring`, `secret`, `storage`, `support`
- **Direct commands** (no sub-commands): `keval`, `ksource`, `security`

Each ensemble command has an `AllowedSubCommands` set — when a security policy is active, only sub-commands in this set are permitted.

### Conditional Compilation

Some features require specific compile-time flags. When a feature is unavailable, the sub-command returns `"not available"` or `"not implemented"`. Key flags:

| Flag | Features Gated |
|------|---------------|
| `CERTIFICATE_POLICY` | Per-PolicyType get/set/unset operations, policy enforcement |
| `XML && SERIALIZATION` | Certificate import/export/extract, `harpy verify` |
| `NETWORK` | Download lists, network time, software updates, remote checks |
| `SHELL` | Shell callbacks, `certificate evaluate` |
| `PLUGIN_COMMANDS` | `-usestream`, `-assembly`, plugin-loading options in `ksource`/`certificate source` |
| `NATIVE` | DPAPI protect/unprotect, CryptoAPI RC4 |
| `ENTERPRISE_LOCKDOWN` | `NoRename`/`NoRemove` on `harpy`, `keval`, `ksource`, `keyring`, `security`; blocks `certificate unsetpolicy` |
| `DEMO_KEY_PAIRS` or `DEMO_EDITION` | `harpy demomode`, demo-related reset |
| `LIMITED_EDITION` | Blocks `harpy features` |

### PolicyType Values

Many sub-commands accept a `-policytype` option or iterate over all policy types. The seven standard policy types are:

| PolicyType | Description |
|------------|-------------|
| `Script` | Inline script evaluation |
| `File` | File-based script evaluation |
| `Stream` | Stream-based script evaluation |
| `License` | License certificate operations |
| `KeyPair` | Key pair operations |
| `Trace` | Diagnostic tracing |
| `Other` | All other operations |

### Managed RSA Engine (BigRSA / BigBigInteger)

RSA operations — `keypair generate`, the RSA paths of `cryptography sign` /
`verify` / `encryptandsign`, and `certificate sign` / `verify` — use the
platform RSA implementation by default. Harpy can transparently substitute an
optional, fully managed provider, **BigRSA** (`BigRSACryptoServiceProvider`,
namespace `BigCrypto`), selected by the `CreateRsaProvider` factory. It is
controlled entirely by environment/configuration variables (the *presence* of
the variable matters; its value is ignored):

| Variable | Effect |
|----------|--------|
| `UseBigCrypto` | When present, RSA providers are created as the managed BigRSA implementation instead of the platform `RSACryptoServiceProvider` / `RSA`. When absent, the platform RSA is used and behavior is unchanged. |
| `UseBigBigInteger` | When present, routes BigRSA's private-key modular exponentiation through the in-house **BigBigInteger** engine instead of `System.Numerics.BigInteger`. Seeded once per provider instance at construction; can also be toggled per instance in managed code. |

**Why it matters in practice:**

- **Key sizes beyond the platform limits.** The platform providers cap RSA at
  16384 bits and reject sizes below 1024. With `UseBigCrypto`, `keypair
  generate -keysize` accepts Harpy's full range — **512 to 262144 bits**.
  Supporting keys both smaller and larger than the platform allows is the
  entire reason BigRSA exists. (Very large keys are slow to generate in managed
  arithmetic, but the key size is operator-chosen, not attacker-chosen.)
- **Portability.** The `BigBigInteger` engine is a self-contained, signed,
  `System.Numerics.BigInteger`-compatible big integer authored to the C# 2.0 /
  .NET 2.0 floor (constant-time CIOS Montgomery `ModPow` for small/medium
  moduli; Barrett + NTT modexp for very large keys). Because of it, BigRSA —
  and therefore big-key RSA — works on every framework Harpy targets, **down
  to .NET Framework 2.0 RTM**, not just 4.6+.
- **Hardening.** BigRSA's private-key path adds message (base) blinding and CRT
  exponent blinding, a fault-injection self-check (the result is recomputed and
  compared before being returned), and constant-time padding removal and
  signature comparison. Supported padding: PKCS#1 v1.5 and OAEP (encryption);
  PKCS#1 v1.5 and PSS (signatures).

> **Default behavior is unchanged unless `UseBigCrypto` is set** — modern
> targets continue to use the platform RSA and remain byte-for-byte identical
> to before. A built-in `SelfTest()` exercises the engine plus full
> encrypt/decrypt and sign/verify round-trips on a fresh 4096-bit key.

---

## Common patterns

*Test-verified quick start (from `Plugins/Commercial/Enterprise/Harpy/Tests/basic.eagle` and `Tools/`). Command results are string tokens — `SignedOk`, `VerifiedOk`, `ExportedOk` — compare them literally. Harpy's key rings, policy, and `security` state are **per-AppDomain / per-plugin-instance**, not process-global; load `-isolated` for an independent security domain.*

Load:

```eagle
package require Licensing.Enterprise   ;# [certificate] [keypair] [keyring] [harpy]
package require Security.Core          ;# [security] + safe-interp enforcement (optional)
```

Sign a script file and verify its detached `.harpy` signature (production signer: `Tools/sign.eagle`):

```eagle
set pub  [keypair open -alias -public $publicKeyFile]
set priv [keypair open -alias -public -private $privateKeyFile]
set cert [certificate import -alias -validate $certFile]
certificate signfile -setid -settimestamp -setkey $cert $priv $scriptFile  ;# -> SignedOk
certificate verifyfile $cert $pub $scriptFile                              ;# -> VerifiedOk
```

Check a license certificate's features:

```eagle
certificate flags -flagtype Feature     -hasflags    QX $cert   ;# grants features Q and X?
certificate flags -flagtype Restriction -nothasflags E  $cert   ;# restriction E absent?
```

Run a signed, untrusted script under enforcement (restore `security` state afterward):

```eagle
security true
set child [interp create -safe]
debug secureeval -file true -trusted true -- $child $signedFile   ;# runs only if the .harpy sig verifies
```

## Command Summary

| Command | Type | Sub-commands | Command Flags | Description |
|---------|------|-------------|---------------|-------------|
| [`certificate`](#cmd-certificate) | Ensemble | 52 | Unsafe | Certificate and license management |
| [`cryptography`](#cmd-cryptography) | Ensemble | 16 | Unsafe | Encryption, signing, and verification |
| [`flags`](#cmd-flags) | Ensemble | 8 | Unsafe | Attribute flag string manipulation |
| [`harpy`](#cmd-harpy) | Ensemble | 27 | Unsafe | Plugin state, configuration, and diagnostics |
| [`keval`](#cmd-keval) | Direct | — | Safe | Evaluate script in secure context |
| [`keypair`](#cmd-keypair) | Ensemble | 15 | Unsafe | Cryptographic key pair management |
| [`keyring`](#cmd-keyring) | Ensemble | 20 | Unsafe | Trusted key ring management |
| [`ksource`](#cmd-ksource) | Direct | — | Safe | Source script file in sandboxed context |
| [`secret`](#cmd-secret) | Ensemble | 7 | Unsafe | Remote secret management via API |
| [`security`](#cmd-security) | Direct | — | Unsafe | Enable or disable security policy |
| [`storage`](#cmd-storage) | Ensemble | 10 | Unsafe | Persistent storage operations |
| [`support`](#cmd-support) | Ensemble | 4 | Unsafe | Diagnostics and support information |

---

## Commands

---

<a id="cmd-certificate"></a>
### `certificate` — Certificate and License Management

```
certificate option ?arg ...?
```

The largest Harpy command with 52 sub-commands for managing license certificates, script signing/verification, execution policies, and related operations.

**Policy-allowed sub-commands**: `evaluate`, `expired`, `flags`, `formattimestamp`, `hash`, `hashstring`, `isolated`, `manager`, `options`, `revoked`, `subject`, `verify`, `verifystring`

#### Common behavior

- **Key-pair resolution and RSA engine.** The signing/verifying sub-commands
  (`sign`, `signfile`, `signhash`, `signstring`, `verify`, `verifyfile`,
  `verifyhash`, `verifystream`, `verifystring`, `loadandverify`) take a
  *keyPair* (and usually a *certificate*) and resolve it through the key-ring
  subsystem via `-keyringname`, `-matchkeyringname`, and `-policytype`, as in
  [`cryptography`](#cmd-cryptography). The RSA primitive comes from the key
  pair; when the `UseBigCrypto` variable is set, RSA signing and verification
  route through the managed BigRSA engine (see *Managed RSA Engine (BigRSA /
  BigBigInteger)* in the Overview).
- **Hash selection.** `-hashalgorithm` selects the digest (`SHA1`, `SHA256`,
  `SHA384`, `SHA512`); `-hashflags` (a `CertificateHashFlags` value) tunes what
  is included in the hash.
- **Per-policy-type sub-commands.** `defaultpolicy` and `simplepolicy` are
  read-only and return a name/value list keyed by the seven policy-type labels
  (`-script`, `-file`, `-stream`, `-license`, `-keypair`, `-trace`, `-other`).
  `keyname`, `keyringname`, `networkflags`, `pathflags`, `policy`,
  `renewcallback`, and `scriptflags` use the same labels but additionally accept
  `-local` and `-unset` (with a per-type flag) to set or clear a single type's
  value — this is where the read-only [`harpy`](#cmd-harpy) queries of the same
  names are actually changed.
- **Returned objects.** Sub-commands that produce a certificate or data
  (`import`, `loadandverify`, `decrypt`, `extract`, the `hash*` family) return
  opaque object handles and accept Eagle's standard object-return options.
- **Conditional features.** Certificate XML operations (`import`, `export`,
  `extract`, and `verify` of certificate files) require `XML && SERIALIZATION`;
  the network-driven forms (`revoked`, `downloadlist`, `networktime`,
  `softwareupdates`, `time`) require `NETWORK` (and often `WEB`).

#### Sub-commands

##### `certificate about`

```
certificate about
```

Returns plugin "about" information (version, copyright, etc.).

---

##### `certificate certificate`

```
certificate certificate
```

Returns the file name of the plugin's configured certificate file. Returns an empty string if none is configured.

---

##### `certificate cleanup`

```
certificate cleanup ?token?
```

Cleans up sandbox interpreters. Without *token*, cleans up all sandboxes; with *token* (unsigned wide integer), cleans up only the sandbox associated with that token.

**Example:**
```tcl
certificate cleanup $sandboxToken
```

---

##### `certificate current`

```
certificate current
```

Returns the file name of the currently active (loaded) license certificate. Returns an empty string if no certificate is active.

**Example:**
```tcl
set fileName [certificate current]
if {[file exists $fileName]} {
    puts "License file: $fileName"
}
```

---

##### `certificate decrypt`

```
certificate decrypt ?options? fileName
```

Decrypts an encrypted certificate file or resource.

| Option | Type | Description |
|--------|------|-------------|
| `-encoding` | Encoding | Text encoding for the decrypted content |
| `-noremote` | Flag | Disable remote resource lookup |
| `-resource` | Flag | Treat *fileName* as an embedded resource name |
| `-anyresourcekey` | Flag | Allow any public key for resource lookup |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Requires:** `XML`

---

##### `certificate defaultpolicy`

```
certificate defaultpolicy
```

Returns a list of default `ExecutionPolicy` values, one for each of the seven PolicyTypes (Script, File, Stream, License, KeyPair, Trace, Other).

**Requires:** `CERTIFICATE_POLICY`

---

##### `certificate discard`

```
certificate discard fileName text
```

Removes the XML signature envelope from *text* (the contents of *fileName*), returning the unsigned script text.

**Requires:** `XML && SERIALIZATION`

**Example:**
```tcl
set unsignedText [certificate discard $file [readFile $file]]
```

---

##### `certificate downloadlist`

```
certificate downloadlist ?options? uri
```

Downloads a list resource from *uri*, optionally verifying its signature.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context for key lookup |
| `-matchkeyringname` | Flag | Match key ring name during lookup |
| `-keypairs` | String | Key pair pattern for verification |
| `-keyringname` | String | Specific key ring name |
| `-hashalgorithm` | String | Hash algorithm name (e.g., `SHA256`) |
| `-encoding` | Encoding | Text encoding |
| `-signed` | Flag | Verify the downloaded list's signature |
| `-first` | Flag | Return only the first matching entry |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Requires:** `NETWORK`

---

##### `certificate evaluate`

```
certificate evaluate ?options? script
```

Evaluates *script* (or a file if `-file` is specified) within the certificate policy security context. Functionally identical to [`keval`](#cmd-keval) but accessed as a `certificate` sub-command.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-defaults` | Flag | false | Load default ShellFlags from current state |
| `-danger` | Flag | false | Allow dangerous flag combinations |
| `-file` | Flag | false | Treat *script* argument as a file path |
| `-encoding` | Encoding | null | File encoding (only with `-file`) |
| `-flags` | ShellFlags | (from state) | Shell evaluation flags |
| `-timeout` | Integer | (from config) | Network timeout in milliseconds |

**Requires:** `SHELL && CERTIFICATE_POLICY`

**Example:**
```tcl
certificate evaluate {puts "hello from secure context"}
certificate evaluate -file /path/to/script.eagle
certificate evaluate -flags +FallbackOnUnsafe $script
certificate evaluate -danger -flags +NoPoliciesOnFallback $script
```

---

##### `certificate expired`

```
certificate expired ?options? certificate ?keyPair?
```

Checks whether *certificate* has expired, optionally using *keyPair* for verification.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name during lookup |
| `-keypairs` | String | Key pair pattern |
| `-keyringname` | String | Specific key ring name |
| `-installed` | DateTime | Override installation date |
| `-forcenetwork` | Flag | Force network time check |
| `-strictnetwork` | Flag | Fail if network time is unavailable |
| `-viahttp` | Boolean | Use HTTPS for time check |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Returns:** Boolean — `True` if expired, `False` otherwise.

---

##### `certificate export`

```
certificate export ?options? certificate fileName
```

Exports *certificate* to an XML file at *fileName*.

| Option | Type | Description |
|--------|------|-------------|
| `-validate` | Flag | Validate the certificate during export |
| `-novalidate` | Flag | Skip validation |
| `-usestream` | Flag | Treat *fileName* as a stream object handle |
| `-encoding` | Encoding | Text encoding for the XML output |

**Requires:** `XML && SERIALIZATION`

**Returns:** `ExportedOk` on success.

**Example:**
```tcl
certificate export -validate $certificate $outputFile
```

---

##### `certificate extract`

```
certificate extract ?options? fileName
```

Extracts a certificate object from an XML file, optionally storing the raw XML text.

| Option | Type | Description |
|--------|------|-------------|
| `-noremote` | Flag | Disable remote resource lookup |
| `-anyresourcekey` | Flag | Allow any public key for resources |
| `-validate` | Flag | Validate the certificate |
| `-novalidate` | Flag | Skip validation |
| `-textvar` | String | Variable name to store the raw XML text |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Requires:** `XML && SERIALIZATION`

**Returns:** Certificate object handle.

**Example:**
```tcl
set cert [certificate extract -validate -textvar xmlText $file]
puts $xmlText  ;# Raw XML
```

---

##### `certificate flags`

```
certificate flags ?options? certificate
```

Gets or checks feature/restriction flags on a *certificate*.

| Option | Type | Description |
|--------|------|-------------|
| `-flagtype` | FlagType | `Feature`, `Restriction`, `KeyUsage`, or `All` |
| `-key` | WideInteger | Key index for keyed flags |
| `-hasflags` | Flag | Check that certificate HAS specified flags |
| `-nothasflags` | Flag | Check that certificate does NOT have specified flags |
| `-hasall` | Flag | Require ALL specified flags present |
| `-nothasall` | Flag | Require NOT ALL specified flags present |
| `-strict` | Flag | Unknown flag characters cause errors |

**Returns:** Without `-hasflags`/`-nothasflags`: the flags value. With check flags: `FlagOk` on success, error on failure.

**Example:**
```tcl
# Get all feature flags
certificate flags -flagtype Feature $cert

# Check for specific features
certificate flags -flagtype Feature -hasflags QX $cert         ;# Has Q and/or X
certificate flags -flagtype Feature -hasflags QX -hasall $cert ;# Has both Q and X

# Check restrictions
certificate flags -flagtype Restriction -nothasflags E $cert   ;# Does NOT have E

# Strict mode rejects unknown characters
certificate flags -strict -hasflags %Q $cert  ;# Error if % is not a valid flag
```

---

##### `certificate formattimestamp`

```
certificate formattimestamp dateTime ?never?
```

Formats a *dateTime* value as a human-readable timestamp string. If *never* is provided, it is used when the timestamp represents "never expires."

**Example:**
```tcl
certificate formattimestamp [clock seconds]
certificate formattimestamp $timestamp true
```

---

##### `certificate hash`

```
certificate hash ?options? certificate
```

Computes a hash of the *certificate* content.

| Option | Type | Description |
|--------|------|-------------|
| `-hashflags` | CertificateHashFlags | Which properties to include in the hash |
| `-hexadecimal` | Flag | Return hex string instead of byte list |
| `-hashalgorithm` | String | Algorithm name (e.g., `SHA256`, `SHA512`) |
| `-encoding` | Encoding | Text encoding |

**Returns:** Hash bytes (as byte list) or hex string (with `-hexadecimal`).

---

##### `certificate hashfile`

```
certificate hashfile ?options? certificate fileName
```

Computes a hash of file *fileName* using settings from *certificate*.

| Option | Type | Description |
|--------|------|-------------|
| `-hashflags` | CertificateHashFlags | Properties to include |
| `-hexadecimal` | Flag | Return hex string |
| `-hashalgorithm` | String | Algorithm name |
| `-encoding` | Encoding | Text encoding |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

---

##### `certificate hashstring`

```
certificate hashstring ?options? certificate string
```

Computes a hash of *string* using settings from *certificate*.

| Option | Type | Description |
|--------|------|-------------|
| `-hashflags` | CertificateHashFlags | Properties to include |
| `-hexadecimal` | Flag | Return hex string |
| `-hashalgorithm` | String | Algorithm name |
| `-encoding` | Encoding | Text encoding |

**Example:**
```tcl
certificate hashstring -hexadecimal $cert "Hello, World!"
```

---

##### `certificate import`

```
certificate import ?options? fileName
```

Imports a certificate from an XML file (or stream/resource).

| Option | Type | Description |
|--------|------|-------------|
| `-encoding` | Encoding | Text encoding |
| `-noremote` | Flag | Disable remote resource lookup |
| `-trace` | Flag | Emit trace diagnostics during import |
| `-validate` | Flag | Validate the certificate |
| `-novalidate` | Flag | Skip validation |
| `-usestream` | Flag | Treat *fileName* as a stream object handle |
| `-anyresourcekey` | Flag | Allow any public key for resources |
| `-thisassembly` | Flag | Look up resource in the Harpy assembly |
| `-encrypted` | Flag | Decrypt before importing |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Requires:** `XML && SERIALIZATION`

**Returns:** Certificate object handle.

**Example:**
```tcl
set cert [certificate import -validate $certFile]
```

---

##### `certificate isolated`

```
certificate isolated
```

Returns whether the plugin is running in a cross-AppDomain isolated context. Returns a boolean.

---

##### `certificate keyname`

```
certificate keyname ?options?
```

Gets, sets, or unsets the key name for one or more policy types.

**Two-pass option parsing**: `-local` is extracted first.

| Option | Type | Description |
|--------|------|-------------|
| `-local` | Boolean | Use local (per-interpreter) key name |
| `-unset` | Boolean | If true, unset the specified key names |
| `-script` | String | Key name for Script policy type |
| `-file` | String | Key name for File policy type |
| `-stream` | String | Key name for Stream policy type |
| `-license` | String | Key name for License policy type |
| `-keypair` | String | Key name for KeyPair policy type |
| `-trace` | String | Key name for Trace policy type |
| `-other` | String | Key name for Other policy type |

Without policy-type options, returns a list of current key names for all policy types (get mode).

**Example:**
```tcl
# Set key names for file and script contexts
certificate keyname -file myKeyName -script myKeyName

# Get all current key names
certificate keyname
```

---

##### `certificate keyringname`

```
certificate keyringname ?options?
```

Gets, sets, or unsets the key ring name for one or more policy types. Same option pattern as `certificate keyname` but for key ring names.

| Option | Type | Description |
|--------|------|-------------|
| `-local` | Boolean | Use local (per-interpreter) key ring name |
| `-unset` | Boolean | If true, unset the specified key ring names |
| `-script` | String | Key ring name for Script policy type |
| `-file` | String | Key ring name for File policy type |
| `-stream` | String | Key ring name for Stream policy type |
| `-license` | String | Key ring name for License policy type |
| `-keypair` | String | Key ring name for KeyPair policy type |
| `-trace` | String | Key ring name for Trace policy type |
| `-other` | String | Key ring name for Other policy type |

---

##### `certificate loadandverify`

```
certificate loadandverify ?options? ?keyPair?
```

Loads and verifies a license certificate, optionally using a specific *keyPair*. This is the most complex sub-command, combining import, validation, and policy enforcement.

**Two-pass option parsing**: `-defaults` is extracted first.

| Option | Type | Description |
|--------|------|-------------|
| `-defaults` | Flag | Load default values for all options |
| `-policytype` | PolicyType | Policy context |
| `-policy` | ExecutionPolicy | Execution policy flags (prefix with `+`/`-` to add/remove) |
| `-matchkeyringname` | Flag | Match key ring name during lookup |
| `-hashalgorithm` | String | Hash algorithm name |
| `-encoding` | Encoding | Text encoding |
| `-plugin` | Plugin | Plugin handle for certificate lookup |
| `-filename` | String | Certificate file path |
| `-keyname` | String | Key name for lookup |
| `-keyringname` | String | Key ring name for lookup |
| `-features` | String | Required feature flags |
| `-restrictions` | String | Required restriction flags |
| `-force` | Boolean | Force loading (bypass cache) |
| `-embedded` | Boolean | Allow embedded certificates |
| `-validate` | Boolean | Validate the certificate |
| `-useplugin` | Boolean | Use plugin key for verification |
| `-useassembly` | Boolean | Use assembly key for verification |
| `-scriptclientdata` | Dictionary | Additional client data for script operations |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Returns:** Certificate object handle.

**Example:**
```tcl
# Load with specific policy
certificate loadandverify -filename $file -policytype License \
    -policy -EnforceKeyGroup -force true $publicKeyToken

# Load without plugin or assembly keys
certificate loadandverify -filename $file -useplugin 0 -useassembly 0 \
    -policytype License -policy TrustSignedOnly -force true
```

---

##### `certificate manager`

```
certificate manager
```

Returns the type of certificate manager in use: `"custom"` if a custom manager is registered, `"default"` if the default manager is active, or `"none"` if no manager exists.

---

##### `certificate metadata`

```
certificate metadata
certificate metadata certificate propertyName
certificate metadata certificate propertyName propertyValue
```

Gets or sets metadata properties on a *certificate*.

- **No arguments**: Returns a list of all available property names.
- **Two arguments**: Returns the value of *propertyName* from *certificate*.
- **Three arguments**: Sets *propertyName* to *propertyValue* on *certificate*.

**Available properties**: `Agreement`, `Authority`, `Duration`, `EntityName`, `EntityType`, `EntityValue`, `ExtraData`, `Features`, `HashAlgorithm`, `Id`, `Key`, `Notes`, `Number`, `Origin`, `Product`, `Protocol`, `ProtocolVersion`, `Quantity`, `Restrictions`, `SerialNumber`, `ServerInfo`, `Signature`, `Support`, `TimeStamp`, `Type`, `Vendor`, `Version`

**Example:**
```tcl
# List all property names
certificate metadata

# Get a property
set vendor [certificate metadata $cert Vendor]
set features [certificate metadata $cert Features]

# Set a property
certificate metadata $cert HashAlgorithm SHA512
```

---

##### `certificate networkflags`

```
certificate networkflags ?options?
```

Gets, sets, unsets, or resets `NetworkFlags` for one or more policy types. Same two-pass pattern as `keyname`/`keyringname`.

| Option | Type | Description |
|--------|------|-------------|
| `-local` | Boolean | Use local (per-interpreter) flags |
| `-unset` | Boolean | If true, unset specified flags |
| `-script` | NetworkFlags | Flags for Script policy type |
| `-file` | NetworkFlags | Flags for File policy type |
| `-stream` | NetworkFlags | Flags for Stream policy type |
| `-license` | NetworkFlags | Flags for License policy type |
| `-keypair` | NetworkFlags | Flags for KeyPair policy type |
| `-trace` | NetworkFlags | Flags for Trace policy type |
| `-other` | NetworkFlags | Flags for Other policy type |

Without policy-type options, returns a list of current NetworkFlags for all policy types.

---

##### `certificate networktime`

```
certificate networktime ?enable?
```

Gets or sets whether NTP network time checking is enabled. Without *enable*, returns the current setting. With *enable* (boolean), enables or disables network time.

**Requires:** `NETWORK`

---

##### `certificate options`

```
certificate options
```

Returns plugin option information.

---

##### `certificate pathflags`

```
certificate pathflags ?options?
```

Gets, sets, unsets, or resets `PathFlags` for one or more policy types. Same option pattern as `networkflags`.

| Option | Type | Description |
|--------|------|-------------|
| `-local` | Boolean | Use local (per-interpreter) flags |
| `-unset` | Boolean | If true, unset specified flags |
| `-script` | PathFlags | Flags for Script policy type |
| `-file` | PathFlags | Flags for File policy type |
| `-stream` | PathFlags | Flags for Stream policy type |
| `-license` | PathFlags | Flags for License policy type |
| `-keypair` | PathFlags | Flags for KeyPair policy type |
| `-trace` | PathFlags | Flags for Trace policy type |
| `-other` | PathFlags | Flags for Other policy type |

---

##### `certificate policy`

```
certificate policy ?options?
```

Gets, sets, unsets, enables, or disables the `ExecutionPolicy` for one or more policy types.

**Two-pass option parsing**: `-enabled` and `-local` are extracted first.

| Option | Type | Description |
|--------|------|-------------|
| `-enabled` | Boolean | Enable (true) or disable (false) policy checking |
| `-local` | Boolean | Use local (per-interpreter) policy |
| `-unset` | Boolean | If true, unset specified policies |
| `-script` | ExecutionPolicy | Policy for Script type |
| `-file` | ExecutionPolicy | Policy for File type |
| `-stream` | ExecutionPolicy | Policy for Stream type |
| `-license` | ExecutionPolicy | Policy for License type |
| `-keypair` | ExecutionPolicy | Policy for KeyPair type |
| `-trace` | ExecutionPolicy | Policy for Trace type |
| `-other` | ExecutionPolicy | Policy for Other type |

Without policy-type options, returns a list of current policies for all policy types.

**Example:**
```tcl
# Enable policy checking
certificate policy -enabled true

# Set specific policies
certificate policy -file TrustSignedOnly -script TrustSignedOnly

# Use local policy mode
certificate policy -local true -file TrustSignedOnly

# Add/remove flags with +/- prefix
certificate policy -local true -file +TrustSignedOnly
certificate policy -local true -file -TrustSignedOnly
```

---

##### `certificate policytrace`

```
certificate policytrace ?flags?
```

Gets or sets the `PolicyTraceFlags` for diagnostic tracing. Without *flags*, returns the current flags. With *flags*, sets the trace configuration.

**Example:**
```tcl
certificate policytrace Default    ;# Reset to default
certificate policytrace Verbose    ;# Enable verbose tracing
```

---

##### `certificate renewcallback`

```
certificate renewcallback ?options?
```

Gets, sets, or unsets certificate renewal callbacks for one or more policy types.

| Option | Type | Description |
|--------|------|-------------|
| `-unset` | Boolean | If true, unset specified callbacks |
| `-script` | Boolean | Set/unset for Script policy type |
| `-file` | Boolean | Set/unset for File policy type |
| `-stream` | Boolean | Set/unset for Stream policy type |
| `-license` | Boolean | Set/unset for License policy type |
| `-keypair` | Boolean | Set/unset for KeyPair policy type |
| `-trace` | Boolean | Set/unset for Trace policy type |
| `-other` | Boolean | Set/unset for Other policy type |

**Requires:** `NETWORK && CERTIFICATE_POLICY && CERTIFICATE_RENEWAL` for set/unset operations.

Without policy-type options, returns a list of booleans indicating whether each policy type has a renewal callback.

---

##### `certificate reset`

```
certificate reset ?flags?
```

Resets various global caches and configuration. Without *flags*, uses `ResetFlags.DefaultMask`. With *flags*, resets only the specified components.

**Reset components** (selected by `ResetFlags`): PolicyTrace, FailSafeMode, GlobalState, TestMode, SdkMode, DemoMode, ServerUri, NetworkTime, PluginData, Configuration, Sandbox, GlobalFileCache, GlobalLicenseCache, GlobalKeyRingState, GlobalDurationData, and more.

**Example:**
```tcl
# Reset file and license caches
certificate reset {GlobalFileCache GlobalLicenseCache}

# Reset global configuration
certificate reset GlobalConfiguration

# Reset multiple items
certificate reset "KeyPairsMask GlobalFileCache GlobalLicenseCache"
```

---

##### `certificate revoked`

```
certificate revoked ?options? certificate
```

Checks whether *certificate* has been revoked.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keypairs` | String | Key pair pattern |
| `-keyringname` | String | Key ring name |
| `-hashalgorithm` | String | Hash algorithm |
| `-forcenetwork` | Flag | Force remote revocation check |
| `-strictnetwork` | Flag | Fail if remote check fails |
| `-nocache` | Flag | Disable revocation cache |
| `-failsafe` | Flag | Abort process on failure |
| `-whatif` | Flag | Dry run (don't trip fail-safe) |
| `-encoding` | Encoding | Text encoding |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Returns:** Boolean — `True` if revoked, `False` otherwise.

**Example:**
```tcl
certificate revoked $cert
certificate revoked -forcenetwork -nocache -failsafe -whatif $cert
```

---

##### `certificate scriptflags`

```
certificate scriptflags ?options?
```

Gets, sets, unsets, or resets `ScriptFlags` for one or more policy types. Same option pattern as `networkflags`/`pathflags`.

| Option | Type | Description |
|--------|------|-------------|
| `-local` | Boolean | Use local (per-interpreter) flags |
| `-unset` | Boolean | If true, unset specified flags |
| `-script` | ScriptFlags | Flags for Script policy type |
| `-file` | ScriptFlags | Flags for File policy type |
| `-stream` | ScriptFlags | Flags for Stream policy type |
| `-license` | ScriptFlags | Flags for License policy type |
| `-keypair` | ScriptFlags | Flags for KeyPair policy type |
| `-trace` | ScriptFlags | Flags for Trace policy type |
| `-other` | ScriptFlags | Flags for Other policy type |

---

##### `certificate shell`

```
certificate shell ?flags?
```

Gets or sets the shell callback state. Without *flags*, returns the current `ShellFlags`. With *flags*, applies the specified shell configuration.

**Requires:** `SHELL && CERTIFICATE_POLICY`

**Example:**
```tcl
certificate shell                      ;# Get current state
certificate shell InstallCallbacks     ;# Install shell callbacks
certificate shell UninstallCallbacks   ;# Uninstall shell callbacks
```

---

##### `certificate sign`

```
certificate sign ?options? certificate keyPair
```

Signs *certificate* using *keyPair* (private key required).

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-hashflags` | CertificateHashFlags | Properties to include in signature hash |
| `-hashalgorithm` | String | Hash algorithm (e.g., `SHA256`, `SHA512`) |
| `-encoding` | Encoding | Text encoding |
| `-setid` | GUID | Set certificate ID to this value |
| `-maybesetid` | GUID (nullable) | Set ID only if not already set |
| `-settimestamp` | DateTime | Set timestamp to this value |
| `-maybesettimestamp` | DateTime (nullable) | Set timestamp only if not already set |
| `-setkey` | Flag | Set the public key token from the signing key |

**Returns:** `SignedOk` on success.

**Example:**
```tcl
certificate sign -setid -settimestamp -setkey $cert $privateKey
```

---

##### `certificate signfile`

```
certificate signfile ?options? certificate keyPair fileName
```

Signs file *fileName* using *certificate* and *keyPair*. Same options as `certificate sign` plus `-timeout`.

**Returns:** `SignedOk` on success.

**Example:**
```tcl
certificate signfile -setid -settimestamp -setkey $cert $privateKey $file
```

---

##### `certificate signhash`

```
certificate signhash ?options? keyPair data
```

Creates a raw hash signature of *data* using *keyPair*.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-hashalgorithm` | String | Hash algorithm |

**Returns:** Signature byte array (opaque object).

---

##### `certificate signstring`

```
certificate signstring ?options? certificate keyPair string
```

Signs *string* using *certificate* and *keyPair*. Same options as `certificate sign` plus `-timeout`.

**Returns:** `SignedOk` on success.

---

##### `certificate simplepolicy`

```
certificate simplepolicy
```

Returns the *simple* (built-in default) `ExecutionPolicy` for each policy type, as a name/value list keyed by `-script`, `-file`, `-stream`, `-license`, `-keypair`, `-trace`, `-other`. Read-only.

**Requires:** `CERTIFICATE_POLICY`

---

##### `certificate softwareupdates`

```
certificate softwareupdates ?trusted?
```

Checks for software updates. Without *trusted*, performs a standard check. With *trusted* (boolean), controls whether to trust software update certificates.

**Requires:** `NETWORK`

---

##### `certificate source`

```
certificate source ?options? keyPair fileName
```

Sources (evaluates) a script file *fileName* with certificate verification using *keyPair*. Has an extensive set of options similar to [`ksource`](#cmd-ksource).

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-policy` | ExecutionPolicy | Execution policy |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keypairs` | String | Key pair pattern |
| `-keyname` | String | Key name |
| `-keyringname` | String | Key ring name |
| `-usestream` | Flag | Treat *fileName* as a stream handle |
| `-assembly` | String | Assembly name |
| `-hashalgorithm` | String | Hash algorithm |
| `-encoding` | Encoding | Text encoding |
| `-keyusage` | String | Key usage restrictions |
| `-trustflags` | TrustFlags | Trust behavior flags |
| `-untrusted` | Flag | Force untrusted evaluation |
| `-useshared` | Flag | Use shared interpreter resources |
| `-useplugin` | Flag | Load plugin in sandbox |
| `-usecontext` | Flag | Preserve evaluation context |
| `-withuniqueid` | Flag | Assign unique ID to sandbox |
| `-withcommands` | Flag | Share commands from parent |
| `-removecommands` | Flag | Remove commands after evaluation |
| `-swapcommands` | Flag | Swap command sets |
| `-withframe` | Flag | Create a new scope frame |
| `-noremote` | Flag | Disable remote resource lookup |
| `-noglobal` | Flag | Don't evaluate at global level |
| `-local` | Flag | Use local policy |
| `-noapply` | Flag | Don't apply result to parent |
| `-sandboxtoken` | UnsignedWideInteger | Explicit sandbox token |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Example:**
```tcl
certificate source -keyusage "" $publicKey $scriptFile
```

---

##### `certificate subject`

```
certificate subject assembly certificate ?policy?
```

Returns the subject string for *certificate* verified against *assembly*. The optional *policy* argument specifies an `ExecutionPolicy` to use.

---

##### `certificate time`

```
certificate time ?options? ?keyPair?
```

Gets the current time from a network time source, optionally using *keyPair* for signed NTP.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keypairs` | String | Key pair pattern |
| `-keyringname` | String | Key ring name |
| `-hostnameoraddress` | String | Specific NTP server |
| `-retries` | Integer | Number of retry attempts |
| `-refresh` | Flag | Force refresh (bypass cache) |
| `-signed` | Flag | Use signed NTP response |
| `-viahttp` | Boolean | Use HTTPS instead of NTP |
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Requires:** `NETWORK`

**Returns:** DateTime value.

---

##### `certificate trace`

```
certificate trace ?options? message
```

Emits a diagnostic trace *message*.

| Option | Type | Description |
|--------|------|-------------|
| `-priority` | TracePriority | Trace priority level |
| `-category` | String | Trace category name |

---

##### `certificate unsetpolicy`

```
certificate unsetpolicy
```

Unsets all execution policies for all policy types and disables policy enforcement. **This is a destructive operation.**

**Requires:** `CERTIFICATE_POLICY` and NOT `ENTERPRISE_LOCKDOWN`

---

##### `certificate verify`

```
certificate verify ?options? certificate keyPair
```

Verifies the signature on *certificate* using *keyPair*.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-hashflags` | CertificateHashFlags | Properties to include |
| `-hashalgorithm` | String | Hash algorithm |
| `-encoding` | Encoding | Text encoding |
| `-matchpublickeytoken` | Boolean | Require public key token match |
| `-checkrevocation` | Boolean | Check revocation status |

**Returns:** `VerifiedOk` on success, or a boolean verification result.

**Example:**
```tcl
certificate verify $cert $publicKey
certificate verify -policytype Script $cert $publicKeyToken
```

---

##### `certificate verifyfile`

```
certificate verifyfile ?options? certificate keyPair fileName
```

Verifies the signature on file *fileName*. Same options as `certificate verify` plus `-timeout`.

**Returns:** `VerifiedOk` or boolean verification result.

---

##### `certificate verifyhash`

```
certificate verifyhash ?options? keyPair data signature
```

Verifies a raw hash *signature* of *data* using *keyPair*.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-hashalgorithm` | String | Hash algorithm |

**Returns:** Boolean verification result.

---

##### `certificate verifystream`

```
certificate verifystream ?options? certificate keyPair stream
```

Verifies the signature on a *stream* object.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-hashflags` | CertificateHashFlags | Properties to include |
| `-hashalgorithm` | String | Hash algorithm |
| `-encoding` | Encoding | Text encoding |
| `-matchpublickeytoken` | Boolean | Require public key token match |
| `-checkrevocation` | Boolean | Check revocation status |

---

##### `certificate verifystring`

```
certificate verifystring ?options? certificate keyPair string
```

Verifies the signature on *string*. Same options as `certificate verify` plus `-timeout`.

**Returns:** `VerifiedOk` or boolean verification result.

---

##### `certificate warning`

```
certificate warning ?options? ?fileName?
```

Returns warning information for a certificate file.

| Option | Type | Description |
|--------|------|-------------|
| `-type` | String | Warning check type (e.g., `License`) |
| `-filename` | String | Certificate file path (alternative to positional) |
| `-hashalgorithm` | String | Hash algorithm |

**Requires:** `XML && SERIALIZATION`

**Returns:** Warning status string (e.g., `WarningOk`).

**Example:**
```tcl
certificate warning -type License $exportFile
```

---

<a id="cmd-cryptography"></a>
### `cryptography` — Encryption, Signing, and Verification

```
cryptography option ?arg ...?
```

Provides symmetric and asymmetric cryptographic operations including encryption, decryption, signing, and verification.

**Policy-allowed sub-commands**: `encrypt`, `isolated`, `options`, `verify`

#### Common options and behavior

These conventions apply across the sub-commands below:

- **`(Unsafe)` options.** Options tagged **(Unsafe)** carry the
  `OptionFlags.Unsafe` flag: they are honored only in an *unsafe* (trusted)
  interpreter and are rejected when the command runs in a *safe* interpreter.
  The unsafe set is per sub-command and intentionally asymmetric — `encrypt` /
  `decrypt` and `verify` mark their options unsafe, while `sign` / `signfile` /
  `encrypt3` / `rc4` do not.
- **Key-pair resolution and RSA engine.** Sub-commands that take a *keyPair*
  argument (`sign`, `verify`, `signfile`, `verifyfile`, `encryptandsign*`,
  `verifyanddecrypt*`) resolve it to a concrete key pair through the key-ring
  subsystem: `-keyringname` selects which trusted key ring to search,
  `-matchkeyringname` requires the resolved key's key-ring name to match, and
  `-policytype` selects the policy context (defaulted from the command). The
  RSA/DSA primitive is taken from the key pair; **when the `UseBigCrypto`
  variable is set, the RSA path uses the managed BigRSA engine** instead of the
  platform provider (see *Managed RSA Engine (BigRSA / BigBigInteger)* in the
  Overview).
- **Returned objects.** Data-producing sub-commands (ciphertext, a
  data-plus-signature triplet, etc.) return an *opaque object handle*, not a
  raw string. They also accept Eagle's standard object-return ("fixup")
  options — e.g. `-create`, `-alias`, `-tostring`, `-objectname` — that control
  how the handle is created and surfaced; omit them for the default handle.
- **Hash algorithms.** `-hashalgorithm` (and the per-purpose `*hashalgorithm`
  variants) accept the standard names `SHA1`, `SHA256`, `SHA384`, `SHA512`,
  used for signature digests and, in the password-based `*3` forms, for PBKDF2
  key derivation.
- **Symmetric defaults.** `-ciphermode` defaults to `CBC` and `-paddingmode` to
  `PKCS7` (`Constants.DefaultCipherMode` / `Constants.DefaultPaddingMode`).

#### Sub-commands

##### `cryptography about`

```
cryptography about
```

Returns plugin "about" information.

---

##### `cryptography decrypt` / `cryptography encrypt`

```
cryptography encrypt ?options? data rfc2898
cryptography decrypt ?options? data rfc2898
```

Encrypts or decrypts *data* using an RFC2898 data provider object (*rfc2898*).

| Option | Type | Description |
|--------|------|-------------|
| `-filename` | String **(Unsafe)** | File path context |
| `-encodingname` | String **(Unsafe)** | Encoding name (e.g., `OneByte`) |
| `-symmetricalgorithm` | String **(Unsafe)** | Algorithm name (e.g., `AES`) |
| `-ciphermode` | CipherMode **(Unsafe)** | Block cipher mode (default: CBC) |
| `-paddingmode` | PaddingMode **(Unsafe)** | Padding mode (default: PKCS7) |

**Returns:** Encrypted/decrypted data as an opaque object.

**Example:**
```tcl
set encrypted [cryptography encrypt $data $provider]
set decrypted [cryptography decrypt $encrypted $provider]
```

---

##### `cryptography decrypt3` / `cryptography encrypt3`

```
cryptography encrypt3 ?options? data password salt
cryptography decrypt3 ?options? data password salt
```

Password-based encryption/decryption using *password* and *salt* (RFC2898-derived key).

| Option | Type | Description |
|--------|------|-------------|
| `-symmetricalgorithm` | String | Algorithm name |
| `-ciphermode` | CipherMode | Block cipher mode (default: CBC) |
| `-paddingmode` | PaddingMode | Padding mode (default: PKCS7) |
| `-iterations` | Integer | PBKDF2 iteration count |
| `-hashalgorithm` | String | Hash algorithm for key derivation |

**Returns:** Encrypted/decrypted data as an opaque object.

**Example:**
```tcl
set encrypted [cryptography encrypt3 $data "myPassword" $salt]
set decrypted [cryptography decrypt3 $encrypted "myPassword" $salt]
cryptography encrypt3 -hashalgorithm SHA1 $data "password" $salt
```

---

##### `cryptography encryptandsign`

```
cryptography encryptandsign ?options? data provider keyPair
```

Encrypts *data* with *provider* and signs it with *keyPair* in a single operation.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-filename` | String | File path context |
| `-encodingname` | String | Encoding name |
| `-symmetricalgorithm` | String | Algorithm name |
| `-ciphermode` | CipherMode | Block cipher mode |
| `-paddingmode` | PaddingMode | Padding mode |
| `-hashalgorithm` | String | Hash algorithm for signing |

**Returns:** Triplet with encrypted data and signature (opaque object).

---

##### `cryptography encryptandsign3`

```
cryptography encryptandsign3 ?options? data password salt keyPair
```

Password-based encrypt-and-sign with separate hash algorithms for encryption and signing.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-symmetricalgorithm` | String | Algorithm name |
| `-ciphermode` | CipherMode | Block cipher mode |
| `-paddingmode` | PaddingMode | Padding mode |
| `-encrypthashalgorithm` | String | Hash algorithm for key derivation |
| `-signhashalgorithm` | String | Hash algorithm for signing |
| `-iterations` | Integer | PBKDF2 iteration count |

**Returns:** Triplet with encrypted data and signature (opaque object).

**Example:**
```tcl
set result [cryptography encryptandsign3 $data "password" $salt $privateKey]
```

---

##### `cryptography isolated`

```
cryptography isolated
```

Returns whether the plugin is running in a cross-AppDomain isolated context.

---

##### `cryptography options`

```
cryptography options
```

Returns plugin option information.

---

##### `cryptography rc4`

```
cryptography rc4 ?options? key data
```

RC4 stream cipher encryption/decryption.

| Option | Type | Description |
|--------|------|-------------|
| `-cryptoapi` | Boolean | Use Windows CryptoAPI (requires `NATIVE`) |
| `-encrypt` | Boolean | True for encrypt, false for decrypt (requires `NATIVE`) |
| `-obfuscate` | Boolean | Apply obfuscation layer (requires `NATIVE`) |
| `-encoding` | Encoding | Text encoding |
| `-hashalgorithm` | String | Hash algorithm for key derivation |

**Example:**
```tcl
# Managed RC4 with obfuscation
set enc [cryptography rc4 -cryptoapi false -encrypt true -obfuscate true $key $data]
set dec [cryptography rc4 -cryptoapi false -encrypt false -obfuscate true $key $enc]

# With encoding
cryptography rc4 -encoding OneByte -cryptoapi false -encrypt true -obfuscate true $key $text
```

---

##### `cryptography sign`

```
cryptography sign ?options? data keyPair
```

Signs *data* with *keyPair*.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-hashalgorithm` | String | Hash algorithm |

**Returns:** Triplet with data and signature (opaque object).

**Example:**
```tcl
set signed [cryptography sign $data $privateKey]
```

---

##### `cryptography signfile`

```
cryptography signfile ?options? fileName keyPair
```

Signs file *fileName* with *keyPair*. Creates a `.b64sig` sidecar file containing the base64-encoded signature.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-nowarning` | Flag | Suppress warnings |

**Example:**
```tcl
cryptography signfile $fileName $privateKey
# Creates $fileName.b64sig
```

---

##### `cryptography verify`

```
cryptography verify ?options? data keyPair signature
```

Verifies *signature* on *data* using *keyPair*.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType **(Unsafe)** | Policy context |
| `-matchkeyringname` | Flag **(Unsafe)** | Match key ring name |
| `-keyringname` | String **(Unsafe)** | Key ring name |
| `-hashalgorithm` | String **(Unsafe)** | Hash algorithm |

**Returns:** Triplet (opaque object); verification status is embedded in the result.

---

##### `cryptography verifyanddecrypt`

```
cryptography verifyanddecrypt ?options? data keyPair signature rfc2898
```

Verifies *signature* and decrypts *data* using *keyPair* and *rfc2898* provider.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-filename` | String | File path context |
| `-encodingname` | String | Encoding name |
| `-symmetricalgorithm` | String | Algorithm name |
| `-ciphermode` | CipherMode | Block cipher mode |
| `-paddingmode` | PaddingMode | Padding mode |
| `-hashalgorithm` | String | Hash algorithm |

**Returns:** The decrypted data as an opaque object; the operation fails if the signature does not verify.

---

##### `cryptography verifyanddecrypt3`

```
cryptography verifyanddecrypt3 ?options? data keyPair signature password salt
```

Password-based verify-and-decrypt with separate hash algorithms for verification and decryption.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-symmetricalgorithm` | String | Algorithm name |
| `-ciphermode` | CipherMode | Block cipher mode |
| `-paddingmode` | PaddingMode | Padding mode |
| `-verifyhashalgorithm` | String | Hash algorithm for verification |
| `-decrypthashalgorithm` | String | Hash algorithm for decryption |
| `-iterations` | Integer | PBKDF2 iteration count |

**Returns:** The decrypted data as an opaque object; the operation fails if the signature does not verify.

---

##### `cryptography verifyfile`

```
cryptography verifyfile ?options? fileName keyPair
```

Verifies the signature on file *fileName* (reads from `.b64sig` sidecar).

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-timeout` | Integer | Timeout in milliseconds |

**Returns:** The verification result (indicates whether the `.b64sig` signature for the file is valid). `-timeout` bounds any network access performed during verification.

**Example:**
```tcl
cryptography verifyfile $fileName $publicKey
```

---

<a id="cmd-flags"></a>
### `flags` — Attribute Flag String Manipulation

```
flags option ?arg ...?
```

Provides operations for checking, changing, and verifying attribute flag strings. Flag strings are compact representations of feature sets, restrictions, and other properties.

**Policy-allowed sub-commands**: `change`, `check`, `have`, `isolated`, `options`, `verify`

#### Sub-commands

##### `flags about`

```
flags about
```

Returns plugin "about" information.

---

##### `flags change`

```
flags change ?options? flags changeFlags
```

Applies *changeFlags* modifications to *flags*, returning the resulting flag string.

| Option | Type | Description |
|--------|------|-------------|
| `-complex` | Flag | Enable complex (key:value) flag parsing |
| `-space` | Flag | Space-separated output |
| `-sort` | Flag | Sort output flags |
| `-legacy` | Flag | Legacy mode compatibility |
| `-compact` | Flag | Compact output format |
| `-key` | WideInteger | Key index for keyed flags |

**Returns:** Modified flag string.

**Example:**
```tcl
flags change -complex -space -sort -legacy -compact -key 1 $flags $changeFlags
```

---

##### `flags check`

```
flags check ?options? flags
```

Checks *flags* against allow/deny rules.

| Option | Type | Description |
|--------|------|-------------|
| `-ruletype` | FlagRuleType | Matching rule type (default: `AllowDeny, MatchAnyKey, MatchAnyRule`) |
| `-allow` | List | List of allowed flag patterns |
| `-deny` | List | List of denied flag patterns |
| `-complex` | Flag | Complex flag parsing |
| `-space` | Flag | Space-separated |
| `-sort` | Flag | Sort output |
| `-all` | Flag | Match all flags |
| `-strict` | Flag | Strict matching |

**Returns:** Boolean result.

**Example:**
```tcl
flags check -allow [list a] abc
flags check -ruletype +MatchAllKey -deny [list b] -allow [list a z] abc
```

---

##### `flags have`

```
flags have ?options? flags haveFlags
```

Tests whether *flags* contains *haveFlags*.

| Option | Type | Description |
|--------|------|-------------|
| `-complex` | Flag | Complex flag parsing |
| `-space` | Flag | Space-separated |
| `-sort` | Flag | Sort output |
| `-all` | Flag | Require ALL specified flags |
| `-strict` | Flag | Strict matching |
| `-key` | WideInteger | Key index for keyed flags |

**Returns:** Boolean result.

**Example:**
```tcl
flags have -complex -space -sort -all -strict -key 1 $flags $haveFlags
```

---

##### `flags isolated`

```
flags isolated
```

Returns whether the plugin is running in an isolated context.

---

##### `flags options`

```
flags options
```

Returns plugin option information.

---

##### `flags show`

```
flags show ?options? flags
```

Normalizes *flags* and returns it in displayable form (each flag rendered as a hexadecimal value by default, or decimal with `-decimal`).

| Option | Type | Description |
|--------|------|-------------|
| `-complex` | Flag | Complex (key:value) flag parsing |
| `-decimal` | Flag | Render flag values as decimal instead of hexadecimal |
| `-space` | Flag | Space-separated output |
| `-sort` | Flag | Sort output flags |

**Returns:** The formatted flag string.

**Example:**
```tcl
flags show $flags
flags show -decimal -sort $flags
```

---

##### `flags verify`

```
flags verify ?options? flags
```

Verifies that *flags* is a syntactically valid flag string.

| Option | Type | Description |
|--------|------|-------------|
| `-complex` | Flag | Complex flag parsing |
| `-fromobject` | Flag | Treat *flags* as an opaque object handle |
| `-space` | Flag | Space-separated |

**Returns:** Success on valid syntax, error otherwise.

**Example:**
```tcl
flags verify -- "ABC"
flags verify -complex -- "key1:value1 key2:value2"
```

---

<a id="cmd-harpy"></a>
### `harpy` — Plugin State, Configuration, and Diagnostics

```
harpy option ?arg ...?
```

Provides access to the Harpy plugin's internal state, configuration management, and diagnostic information.

**Policy-allowed sub-commands**: `failsafemode`, `isolated`, `keyname`, `keyringname`, `options`, `policy`, `renewcallback`, `scriptflags`, `sdkmode`, `security`, `testmode`

#### Common behavior

- **Policy-type query sub-commands.** `keyname`, `keyringname`, `networkflags`,
  `pathflags`, `policy`, `renewcallback`, `scriptflags`, and `security` are
  **read-only**. Each returns a name/value list keyed by the seven policy-type
  labels — `-script`, `-file`, `-stream`, `-license`, `-keypair`, `-trace`,
  `-other` — paired with that type's current value (or boolean). To *change* a
  policy type's key name, key ring, execution policy, etc., use the
  corresponding per-type [`certificate`](#cmd-certificate) sub-commands. Most of
  these require the `CERTIFICATE_POLICY` compile-time flag.
- **State vs. configuration.** Many sub-commands report plugin state
  (`changecount`, `changed`, `sandboxes`, `source`, `timeout`, and the `demomode`
  / `failsafemode` / `sdkmode` / `testmode` queries); `configurations` and
  `reconfigure` read and (re)apply the configuration files.

#### Sub-commands

##### `harpy about`

```
harpy about
```

Returns plugin "about" information.

---

##### `harpy changecount`

```
harpy changecount
```

Returns the global change count, an integer tracking how many configuration changes have occurred.

---

##### `harpy changed`

```
harpy changed ?ignore? ?local? ?default?
```

Checks or triggers the plugin "changed" state.

| Argument | Type | Description |
|----------|------|-------------|
| *ignore* | Boolean | Whether to ignore changes |
| *local* | Boolean | Use local check |
| *default* | Boolean | Default value |

**Example:**
```tcl
harpy changed true         ;# Mark as changed
harpy changed true false   ;# Changed with reset
harpy changed true true    ;# Changed with force
```

---

##### `harpy configurations`

```
harpy configurations ?flags?
```

Gets or applies configuration settings. Without *flags*, returns the current configurations. With *flags* (`ConfigurationFileFlags`), applies the specified configuration.

**Example:**
```tcl
harpy configurations                                          ;# Get current
harpy configurations {+Global WithOkResults WithErrorResults} ;# Apply global config
harpy configurations {+Global Reset WithOkResults WithErrorResults}  ;# With reset
```

---

##### `harpy demomode`

```
harpy demomode
```

Returns whether demo mode is enabled. Returns a boolean.

**Requires:** `DEMO_KEY_PAIRS` or `DEMO_EDITION`; returns `false` when not compiled in.

---

##### `harpy failsafemode`

```
harpy failsafemode
```

Returns whether fail-safe mode is enabled. Returns a boolean.

---

##### `harpy failsafetrip`

```
harpy failsafetrip ?count?
```

Queries the fail-safe trip status. Without *count*, returns whether fail-safe has been tripped (boolean). With *count* = `true`, returns the trip count (integer).

**Example:**
```tcl
harpy failsafetrip       ;# Was it tripped? (boolean)
harpy failsafetrip true  ;# How many times? (integer)
```

---

##### `harpy features`

```
harpy features
```

Returns the current license feature flags string.

**Requires:** NOT `LIMITED_EDITION`; returns empty string when limited.

---

##### `harpy isolated`

```
harpy isolated
```

Returns whether the plugin is running in a cross-AppDomain isolated context.

---

##### `harpy keyname`

```
harpy keyname
```

Returns a list of current key names for all seven policy types (read-only). For per-type management, use [`certificate keyname`](#certificate-keyname).

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy keyringname`

```
harpy keyringname
```

Returns a list of current key ring names for all seven policy types (read-only).

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy machine`

```
harpy machine ?flags?
```

Returns machine identification information. Without *flags*, uses default identification. With *flags* (`PathFlags`), controls which identification elements are included.

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy networkflags`

```
harpy networkflags
```

Returns a list of current `NetworkFlags` for all seven policy types (read-only).

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy options`

```
harpy options
```

Returns plugin option information.

---

##### `harpy pathflags`

```
harpy pathflags
```

Returns a list of current `PathFlags` for all seven policy types (read-only).

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy policy`

```
harpy policy
```

Returns a list of current `ExecutionPolicy` values for all seven policy types (read-only). For per-type management, use [`certificate policy`](#certificate-policy).

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy reconfigure`

```
harpy reconfigure
```

Triggers a full reconfiguration by reloading all configuration files.

**Requires:** `LICENSING`

---

##### `harpy renewcallback`

```
harpy renewcallback
```

Returns a list of booleans indicating whether each policy type has a renewal callback (read-only).

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy sandboxes`

```
harpy sandboxes
```

Returns the current sandbox tokens as a string.

---

##### `harpy scriptflags`

```
harpy scriptflags
```

Returns a list of current `ScriptFlags` for all seven policy types (read-only).

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy security`

```
harpy security ?exact?
```

Returns a list of booleans indicating whether a security policy is active for each policy type. The optional *exact* (boolean) argument controls matching precision.

**Requires:** `CERTIFICATE_POLICY`

---

##### `harpy sdkmode`

```
harpy sdkmode
```

Returns whether SDK mode is enabled. Returns a boolean.

---

##### `harpy source`

```
harpy source
```

Returns a two-element list: `[sourceId, sourceTimeStamp]` identifying the build source.

---

##### `harpy testmode`

```
harpy testmode
```

Returns whether test mode is enabled. Returns a boolean.

---

##### `harpy timeout`

```
harpy timeout
```

Returns the current default network timeout value.

---

##### `harpy uri`

```
harpy uri ?type?
```

Gets URI information. Without *type*, returns a list of all `UriType` names. With *type*, returns the URI for that specific type.

**Example:**
```tcl
harpy uri                  ;# List all URI type names
harpy uri SupportBase      ;# Get the support base URI
```

---

##### `harpy verify`

```
harpy verify ?options? fileName
```

Verifies a certificate XML file by importing it, extracting key pairs, and verifying the file signature.

| Option | Type | Description |
|--------|------|-------------|
| `-timeout` | Integer **(Unsafe)** | Network timeout in milliseconds |

**Requires:** `XML && SERIALIZATION`

**Returns:** Boolean verification result.

---

<a id="cmd-keval"></a>
### `keval` — Evaluate Script in Secure Context

```
keval ?options? script
```

Evaluates *script* (or a file if `-file` is specified) within the certificate policy security context. This command is marked `Safe` — it can be used even in restricted interpreters.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-defaults` | Flag | false | Load default ShellFlags from current state |
| `-danger` | Flag | false | Allow dangerous flag combinations (removes DangerForbidMask restriction) |
| `-file` | Flag | false | Treat *script* as a file path |
| `-encoding` | Encoding | null | File encoding (only with `-file`) |
| `-flags` | ShellFlags | (from state or null) | Shell evaluation flags |
| `-timeout` | Integer | (from config) | Network timeout in milliseconds |

**Two-pass option parsing**: The `-defaults` flag is extracted first; if set, default ShellFlags are loaded before the remaining options are parsed.

**ShellFlags** control fallback behavior when policy checks don't produce a clear allow/deny result:

| Flag | Description |
|------|-------------|
| `FallbackOnUnsafe` | Allow untrusted eval when interpreter is not "safe" |
| `FallbackOnNoPolicy` | Allow untrusted eval when no policy is set |
| `FallbackOnNeutral` | Allow untrusted eval when policy is neutral |
| `FallbackOnDenied` | Allow untrusted eval when policy denies |
| `FallbackOnFailure` | Allow untrusted eval when policy errors |
| `NoPoliciesOnFallback` | Skip policy checks on fallback |

Use `+` prefix to add flags, `-` prefix to remove flags from the current set.

**Returns:** The result of evaluating *script* (or the `-file` contents) in the secure context.

**Example:**
```tcl
keval {puts "hello from secure context"}
keval -file /path/to/script.eagle
keval -flags +FallbackOnUnsafe $script
keval -danger -flags +NoPoliciesOnFallback $script
```

---

<a id="cmd-keypair"></a>
### `keypair` — Cryptographic Key Pair Management

```
keypair option ?arg ...?
```

Manages RSA and DSA cryptographic key pairs — opening, generating, saving, and inspecting key pair files.

**Policy-allowed sub-commands**: `assembly`, `expired`, `isolated`, `options`, `revoked`, `root`, `script`

#### Common options and behavior

- **Key-pair resolution.** Sub-commands that take a *keyPair* argument
  (`dump`, `expired`, `revoked`, `metadata`, `open`, `save`) accept it as a key
  pair object handle, a public key token, or a key-ring entry; `-keyringname`,
  `-matchkeyringname`, and `-policytype` drive the key-ring lookup exactly as in
  the [`cryptography`](#cmd-cryptography) command.
- **Key-file options.** For the file/assembly forms (`open`, `save`,
  `assembly`, `token`): `-keypairtype` selects `RSA` or `DSA`; `-keyfileformat`
  selects the on-disk format (SNK, PVK, raw CryptoAPI blob, or a strong-name
  variant); `-pvk` with `-password` handle PVK files; `-public` / `-private`
  choose which half to read or write; and `-usestream` treats *fileName* as a
  stream object handle rather than a filesystem path.
- **RSA engine.** Key pairs produced or opened here feed the signing and
  verification paths. When the `UseBigCrypto` variable is set, RSA operations
  route through the managed BigRSA engine — which is also what allows
  `generate -keysize` to exceed the platform limits (see *Managed RSA Engine
  (BigRSA / BigBigInteger)* in the Overview).
- **Returned objects.** `open`, `assembly`, and the other object-producing
  sub-commands return an *opaque key pair object handle* and accept Eagle's
  standard object-return ("fixup") options (`-create`, `-alias`, `-tostring`,
  `-objectname`).
- **`(Unsafe)` options** are honored only in an unsafe (trusted) interpreter,
  as described for [`cryptography`](#cmd-cryptography); here they guard
  private-key extraction (`assembly -private`, `-password`) and the
  network-driven `revoked` options.

#### Sub-commands

##### `keypair about`

```
keypair about
```

Returns plugin "about" information.

---

##### `keypair assembly`

```
keypair assembly ?options? assembly
```

Gets a key pair from a loaded .NET assembly.

| Option | Type | Description |
|--------|------|-------------|
| `-keyname` | String | Resource key name |
| `-pvk` | Flag | Treat as PVK format |
| `-password` | String **(Unsafe)** | Decryption password |
| `-keytype` | AssemblyKeyType | Key type (default: `Signature`) |
| `-public` | Flag | Extract public key |
| `-private` | Flag **(Unsafe)** | Extract private key |

**Returns:** Key pair object handle.

**Example:**
```tcl
# Get default assembly key (public only)
set asmKey [keypair assembly -public null]

# Get named key from assembly resources
set key [keypair assembly -public -keyname myKeyName null]
```

---

##### `keypair dump`

```
keypair dump ?options? keyPair
```

Dumps key pair metadata in human-readable form.

| Option | Type | Description |
|--------|------|-------------|
| `-chainonly` | Boolean | Show only chain information |
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |

**Returns:** A human-readable dump of the key pair's fields (and, unless `-chainonly` is set, its trust chain).

---

##### `keypair expired`

```
keypair expired ?options? keyPair
```

Checks whether *keyPair* has expired.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType **(Unsafe)** | Policy context |
| `-matchkeyringname` | Flag **(Unsafe)** | Match key ring name |
| `-keyringname` | String | Key ring name |

**Returns:** Non-zero if *keyPair* has expired; otherwise zero.

---

##### `keypair generate`

```
keypair generate ?options? fileName
```

Generates a new key pair and saves it to *fileName*.

| Option | Type | Description |
|--------|------|-------------|
| `-keynumber` | KeyNumber | Key number (default: `AT_DEFAULT`) |
| `-keysize` | Integer | Key size in bits (e.g., 1024, 2048) |
| `-keypairtype` | KeyPairType | `RSA` or `DSA` (default: `Legacy`/RSA) |

**Example:**
```tcl
keypair generate -keysize 2048 $fileName           ;# 2048-bit RSA
keypair generate -keypairtype DSA $fileName         ;# Default DSA
```

> **Key-size limits.** For RSA, the platform provider accepts `-keysize` only
> within its supported range (1024–16384 bits). When the `UseBigCrypto`
> variable is set, the managed BigRSA engine is used instead and `-keysize` may
> range from **512 to 262144 bits** — see *Managed RSA Engine (BigRSA /
> BigBigInteger)* in the Overview.

---

##### `keypair isolated`

```
keypair isolated
```

Returns whether the plugin is running in an isolated context.

---

##### `keypair metadata`

```
keypair metadata ?options?
keypair metadata ?options? keyPair propertyName
keypair metadata ?options? keyPair propertyName propertyValue
```

Gets or sets metadata properties on a key pair.

| Option | Type | Description |
|--------|------|-------------|
| `-keypairtype` | KeyPairType | Filter by key pair type |
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |

- **No positional args**: Returns a list of available property names for the key type.
- **Two positional args**: Returns the value of *propertyName*.
- **Three positional args**: Sets *propertyName* to *propertyValue*.

**RSA properties**: `Algorithm`, `BitLength`, `ByteCount`, `D`, `DP`, `DQ`, `Exponent`, `FileName`, `HashAlgorithmId`, `HavePrivateKey`, `HavePublicKey`, `IQ`, `KeyDomains`, `KeyExpiration`, `KeyFileFormat`, `KeyGroups`, `KeyPairType`, `KeyUsage`, `Magic`, `Modulus`, `P`, `Parent`, `PublicKeyToken`, `Q`, `Reserved`, `Salt`, `SignatureAlgorithmId`, `Type`, `Version`

**DSA properties**: `Algorithm`, `BitLength`, `ByteCount`, `Counter`, `FileName`, `G`, `HashAlgorithmId`, `HavePrivateKey`, `HavePublicKey`, `KeyDomains`, `KeyExpiration`, `KeyFileFormat`, `KeyGroups`, `KeyPairType`, `KeyUsage`, `Magic`, `P`, `Parent`, `PublicKeyToken`, `Q`, `Reserved`, `Salt`, `Seed`, `SignatureAlgorithmId`, `Type`, `Version`, `X`, `Y`

**Example:**
```tcl
keypair metadata                                ;# List RSA properties
keypair metadata -keypairtype DSA               ;# List DSA properties
keypair metadata $key PublicKeyToken             ;# Get token
keypair metadata $key BitLength                  ;# Get bit length (e.g., 1024)
keypair metadata $key HavePrivateKey             ;# True or False
```

---

##### `keypair open`

```
keypair open ?options? fileName
```

Opens a key pair from a file (SNK, PVK, or raw CryptoAPI blob).

| Option | Type | Description |
|--------|------|-------------|
| `-keypairtype` | KeyPairType | `RSA` or `DSA` |
| `-keyfileformat` | KeyFileFormat | File format hint |
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-pvk` | Flag | Read PVK format file |
| `-password` | String | Password for encrypted PVK |
| `-public` | Flag | Extract public key |
| `-private` | Flag | Extract private key |
| `-usestream` | Flag | Treat *fileName* as stream object handle |

**Returns:** Key pair object handle.

**Example:**
```tcl
# RSA key pair (public + private)
keypair open -public -private $snkFile

# Public key only
keypair open -public $publicKeyFile

# PVK format with password
keypair open -public -private -pvk -password 12345678 $pvkFile

# DSA key pair
keypair open -public -private -keypairtype DSA $dsaKeyFile
```

---

##### `keypair options`

```
keypair options
```

Returns plugin option information.

---

##### `keypair resources`

```
keypair resources ?pattern?
```

Lists assembly manifest resource names. If *pattern* is given, returns only matching names (glob-style).

**Example:**
```tcl
keypair resources *.snk   ;# List all SNK resources
```

---

##### `keypair revoked`

```
keypair revoked ?options? keyPair
```

Checks whether *keyPair* has been revoked.

| Option | Type | Description |
|--------|------|-------------|
| `-policytype` | PolicyType **(Unsafe)** | Policy context |
| `-matchkeyringname` | Flag **(Unsafe)** | Match key ring name |
| `-when` | DateTime **(Unsafe)** | Check as of this date |
| `-keypairs` | String **(Unsafe)** | Key pair pattern |
| `-keyringname` | String | Key ring name |
| `-hashalgorithm` | String **(Unsafe)** | Hash algorithm |
| `-forcenetwork` | Flag **(Unsafe)** | Force network check |
| `-strictnetwork` | Flag **(Unsafe)** | Fail if network unavailable |
| `-nocache` | Flag **(Unsafe)** | Disable cache |
| `-failsafe` | Flag **(Unsafe)** | Abort on failure |
| `-whatif` | Flag **(Unsafe)** | Dry run |
| `-encoding` | Encoding **(Unsafe)** | Text encoding |
| `-timeout` | Integer **(Unsafe)** | Network timeout |

**Returns:** Non-zero if *keyPair* is revoked; otherwise zero. The result is subject to the network and cache options (e.g. `-forcenetwork`, `-nocache`, `-failsafe`); `-whatif` reports without enforcing.

**Requires:** `CERTIFICATE_POLICY`

**Example:**
```tcl
keypair revoked $publicKeyToken
keypair revoked -forcenetwork -nocache -failsafe -whatif $publicKeyToken
```

---

##### `keypair root`

```
keypair root
```

Returns the root public key token(s).

**Requires:** `CERTIFICATE_POLICY`

---

##### `keypair save`

```
keypair save ?options? fileName keyPair
```

Saves *keyPair* to file *fileName*.

| Option | Type | Description |
|--------|------|-------------|
| `-keypairtype` | KeyPairType | `RSA` or `DSA` |
| `-keyfileformat` | KeyFileFormat | Output file format |
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-pvk` | Flag | Save in PVK format |
| `-password` | String | Encryption password for PVK |
| `-public` | Flag | Save public key only |
| `-private` | Flag | Save private key |
| `-usestream` | Flag | Treat *fileName* as stream handle |

**Example:**
```tcl
keypair save -private $file $key              ;# Save private RSA
keypair save -public $file $key               ;# Save public RSA only
keypair save -private -pvk -password 12345678 $file $key  ;# PVK with password
keypair save -private -keypairtype DSA $file $key         ;# DSA private
keypair save -public -keypairtype DSA -keyfileformat DsaStrongName $file $key
```

---

##### `keypair script`

```
keypair script
```

Returns the script signing public key token.

**Requires:** `CERTIFICATE_POLICY`

---

##### `keypair token`

```
keypair token ?options? ?fileName?
```

Returns the public key token. Without *fileName*, returns the assembly public key token from the plugin. With *fileName*, opens the key file and returns its token.

| Option | Type | Description |
|--------|------|-------------|
| `-keypairtype` | KeyPairType | `RSA` or `DSA` |
| `-keyfileformat` | KeyFileFormat | File format hint |
| `-strict` | Flag **(Unsafe)** | Error on failure (vs. empty string) |

**Example:**
```tcl
keypair token                                ;# Assembly token
keypair token $keyFile                       ;# File token
keypair token -keypairtype DSA $dsaFile      ;# DSA file token
```

---

<a id="cmd-keyring"></a>
### `keyring` — Trusted Key Ring Management

```
keyring option ?arg ...?
```

Manages the trusted key ring — a collection of public keys used for verifying scripts, certificates, and other signed data.

**Policy-allowed sub-commands**: `assembly`, `embedded`, `isolated`, `options`, `script`

#### Common behavior

- **What a key ring holds.** A key ring is a collection of trusted **public**
  keys, partitioned by [`PolicyType`](#policytype-values) (e.g. `Script`,
  `License`, `KeyPair`). Verifying scripts, certificates, and other signed data
  consults the ring for the relevant policy type.
- **The optional `policyType` argument.** Many sub-commands accept a trailing
  `?policyType?`: when supplied, the operation is scoped to that policy context;
  when omitted, it uses this command instance's current default (settable via
  `keyring policytype`). Listing sub-commands with no type act on the default
  ring.
- **Snapshots.** `save` captures the current ring state as a named snapshot
  (returning its name), `restore name` re-applies one, and `clear` empties the
  ring (optionally for a single policy type) — letting a host stage and roll
  back trust state.
- **Population.** `bootstrap` and `merge` add public-only key pairs (from the
  bootstrap directory or a supplied path); `assembly` and `embedded` enumerate
  the tokens available from loaded assemblies and embedded resources.

#### Sub-commands

##### `keyring about`

```
keyring about
```

Returns plugin "about" information.

---

##### `keyring assembly`

```
keyring assembly
```

Lists assembly public key tokens.

**Returns:** A list of assembly public key tokens.

---

##### `keyring bootstrap`

```
keyring bootstrap ?policyType?
```

Bootstraps key pairs (public only) into the key ring. The optional *policyType* controls which policy context to initialize.

**Returns:** Integer count of loaded keys.

---

##### `keyring clear`

```
keyring clear ?policyType?
```

Clears all key pairs from the key ring. Optional *policyType* clears only that type.

**Example:**
```tcl
keyring clear              ;# Clear all
keyring clear License      ;# Clear only License type
```

---

##### `keyring directory`

```
keyring directory
```

Returns the bootstrap directory path.

---

##### `keyring embedded`

```
keyring embedded
```

Lists embedded public key tokens.

**Returns:** A list of embedded public key tokens.

---

##### `keyring fetch`

```
keyring fetch ?name?
```

Fetches key ring data from the configured URI. Optional *name* filters the request.

**Requires:** `XML && NETWORK && WEB`

---

##### `keyring isolated`

```
keyring isolated
```

Returns whether the plugin is running in an isolated context.

---

##### `keyring license`

```
keyring license
```

Lists key pairs for the `License` policy type.

**Returns:** A list of key pair entries registered for the `License` policy type.

---

##### `keyring loaded`

```
keyring loaded hashValue
```

Returns the loaded file name for a given *hashValue*.

---

##### `keyring merge`

```
keyring merge ?path? ?policyType?
```

Loads and merges key pairs from *path* (directory or file) into the key ring. Optional *policyType* restricts the target.

**Returns:** Integer count of loaded keys, or empty string.

**Example:**
```tcl
keyring merge $keyRingFile
```

---

##### `keyring metadata`

```
keyring metadata pattern ?policyType?
```

Gets key pair metadata for entries matching *pattern* (glob-style).

**Example:**
```tcl
keyring metadata ""                ;# Default key ring
keyring metadata *                 ;# All entries
keyring metadata TestPrivate1.snk  ;# Specific file
keyring metadata Z*                ;# Pattern match
```

---

##### `keyring options`

```
keyring options
```

Returns plugin option information.

---

##### `keyring policytype`

```
keyring policytype ?policyType?
```

Gets or sets the default PolicyType for this `keyring` command instance. Without *policyType*, returns the current default. With *policyType*, sets it.

**Example:**
```tcl
keyring policytype           ;# Get current
keyring policytype License   ;# Set to License
keyring policytype Script    ;# Set to Script
```

---

##### `keyring remove`

```
keyring remove name
```

Removes the trusted key ring entry identified by *name*.

---

##### `keyring restore`

```
keyring restore name ?policyType?
```

Restores the key ring from a previously saved snapshot named *name*.

---

##### `keyring save`

```
keyring save ?policyType?
```

Saves the current key ring state as a named snapshot.

**Returns:** Name of the saved snapshot.

---

##### `keyring script`

```
keyring script
```

Lists key pairs for the `Script` policy type.

**Returns:** A list of key pair entries registered for the `Script` policy type.

---

##### `keyring share`

```
keyring share interp ?policyType?
```

Copies the trusted key ring to child interpreter *interp*.

**Example:**
```tcl
keyring share $childInterp
```

---

##### `keyring usage`

```
keyring usage pattern ?policyType?
```

Gets key usage information for key pairs matching *pattern*.

**Example:**
```tcl
keyring usage $publicKeyToken
```

---

<a id="cmd-ksource"></a>
### `ksource` — Source Script File in Sandboxed Context

```
ksource ?options? fileName
```

Sources (evaluates) a script file *fileName* in a sandboxed interpreter with certificate policy enforcement. This command is marked `Safe` — it can be used even in restricted interpreters.

| Option | Type | Description |
|--------|------|-------------|
| `-usestream` | Flag | Treat *fileName* as a stream object handle |
| `-assembly` | String | Assembly name for resource lookup |
| `-policytype` | PolicyType | Policy context |
| `-policy` | ExecutionPolicy | Execution policy |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyname` | String | Key name for lookup |
| `-keyringname` | String | Key ring name |
| `-hashalgorithm` | String | Hash algorithm |
| `-encoding` | Encoding | Text encoding |
| `-keypairs` | String | Key pair pattern for verification |
| `-keyusage` | String | Key usage constraints (empty string = no constraints) |
| `-trustflags` | TrustFlags | Trust behavior flags |
| `-timeout` | Integer | Network timeout in milliseconds |
| `-untrusted` | Flag | Force untrusted evaluation context |
| `-useshared` | Flag | Use shared interpreter resources |
| `-useplugin` | Flag | Load plugin in sandboxed interpreter |
| `-usecontext` | Flag | Preserve evaluation context |
| `-withuniqueid` | Flag | Assign unique ID to sandbox |
| `-withcommands` | Flag | Share commands from parent interpreter |
| `-removecommands` | Flag | Remove commands after evaluation |
| `-swapcommands` | Flag | Swap command sets |
| `-withframe` | Flag | Create a new scope frame |
| `-noremote` | Flag | Disable remote resource lookup |
| `-useanykey` | Flag | Use any available key |
| `-noglobal` | Flag | Don't evaluate at global level |
| `-local` | Flag | Use local policy (not inherited from parent) |
| `-noapply` | Flag | Don't apply result to parent interpreter |
| `-sandboxtoken` | UnsignedWideInteger | Explicit sandbox token for state management |

All options are marked **(Unsafe)** when `PLUGIN_COMMANDS` is defined.

**Returns:** The result of evaluating the script.

**Example:**
```tcl
# Basic sourcing
ksource $scriptFile

# With specific key pair
ksource -keypairs $publicKeyToken $scriptFile

# Full context sharing
ksource -withcommands -useshared -useplugin -usecontext -- $scriptFile

# Local policy with sandbox token
ksource -sandboxtoken $token -withcommands -useshared -useplugin -usecontext -local -- $scriptFile

# Untrusted evaluation
ksource -withcommands -useplugin -untrusted -- $scriptFile

# Key usage override
ksource -keypairs $token -keyusage "" $scriptFile
```

---

<a id="cmd-secret"></a>
### `secret` — Remote Secret Management

```
secret option ?arg ...?
```

Manages secrets via a remote API service. Supports generating, retrieving, and deleting secrets with optional encryption and signing.

**Policy-allowed sub-commands**: `isolated`, `options`

#### Common behavior

- **Remote API.** `generate`, `request`, and `delete` call a remote secret
  service: `-uri` sets the base URI, `-apikey` supplies the authentication key
  (a byte array), `-encoding` selects request/response encoding, and `-timeout`
  bounds the network call. These forms require `XML && NETWORK && WEB`.
- **Signing and key resolution.** Supplying `-keypair` (a private key) to
  `generate` signs the request; `-certificate`, `-policytype`,
  `-matchkeyringname`, and `-keyringname` drive certificate / key-ring
  resolution as elsewhere. RSA signing routes through the managed BigRSA engine
  when the `UseBigCrypto` variable is set (see *Managed RSA Engine (BigRSA /
  BigBigInteger)* in the Overview).
- **Key derivation.** `-iterations`, `-salt`, and `-hashalgorithms` parameterize
  the PBKDF2-based derivation; `-hashalgorithms` is a *list* of up to three
  names (client, server, signature).

#### Sub-commands

##### `secret about`

```
secret about
```

Returns plugin "about" information.

---

##### `secret cache`

```
secret cache fileName ?overwrite?
```

Imports a certificate from *fileName* and caches it. The optional *overwrite* argument controls cache replacement.

**Requires:** `XML && SERIALIZATION`

**Returns:** Certificate GUID on success.

---

##### `secret delete`

```
secret delete ?options? id
```

Deletes a secret identified by *id* from the remote service.

| Option | Type | Description |
|--------|------|-------------|
| `-uri` | URI | Secret server base URI |
| `-apikey` | ByteArray | API authentication key |
| `-encoding` | Encoding | Text encoding |
| `-timeout` | Integer | Network timeout |

**Requires:** `XML && NETWORK && WEB`

**Example:**
```tcl
secret delete -apikey $key -- $secretId
```

---

##### `secret generate`

```
secret generate ?options?
```

Generates a new secret on the remote server.

| Option | Type | Description |
|--------|------|-------------|
| `-iterations` | Integer | PBKDF2 iteration count |
| `-hashalgorithms` | List | Hash algorithms (up to 3: client, server, signature) |
| `-salt` | String | Salt value |
| `-id` | GUID | Secret ID |
| `-certificate` | GUID | Certificate GUID |
| `-uri` | URI | Secret server base URI |
| `-apikey` | ByteArray | API authentication key |
| `-encoding` | Encoding | Text encoding |
| `-encrypted` | Boolean | Whether the secret should be encrypted |
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keypair` | String | Private key for request signing |
| `-keyringname` | String | Key ring name |
| `-timeout` | Integer | Network timeout |

**Requires:** `XML && NETWORK && WEB`

**Returns:** GUID derived from the server ID salt.

**Example:**
```tcl
secret generate -iterations 99999 -hashalgorithms [list SHA512] -encrypted true -apikey $key
secret generate -iterations 99999 -hashalgorithms [list SHA512] -encrypted true \
    -apikey $key -keypair $privateKey   ;# With signing
```

---

##### `secret isolated`

```
secret isolated
```

Returns whether the plugin is running in an isolated context.

---

##### `secret options`

```
secret options
```

Returns plugin option information.

---

##### `secret request`

```
secret request ?options? id
```

Retrieves a previously generated secret by *id*.

| Option | Type | Description |
|--------|------|-------------|
| `-hashalgorithms` | List | Hash algorithms |
| `-certificate` | GUID | Certificate GUID |
| `-uri` | URI | Secret server base URI |
| `-apikey` | ByteArray | API authentication key |
| `-encoding` | Encoding | Text encoding |
| `-policytype` | PolicyType | Policy context |
| `-matchkeyringname` | Flag | Match key ring name |
| `-keyringname` | String | Key ring name |
| `-timeout` | Integer | Network timeout |

**Requires:** `XML && NETWORK && WEB`

**Returns:** Dictionary with `password`, `salt`, `iterationCount`, `hashAlgorithmName`.

**Example:**
```tcl
set result [secret request -hashalgorithms [list SHA512] -apikey $key -- $secretId]
```

---

<a id="cmd-security"></a>
### `security` — Enable or Disable Security Policy

```
security ?force? enabled
```

Enables or disables the Harpy security policy. This is a direct command (not an ensemble).

| Argument | Type | Description |
|----------|------|-------------|
| *force* | Literal `"force"` | Optional — ignore errors during enable/disable |
| *enabled* | Boolean (nullable) | `true` to enable, `false` to disable, `""` to reset |

**Example:**
```tcl
security true        ;# Enable security
security false       ;# Disable security
security ""          ;# Reset to default state
security force true  ;# Enable, ignoring errors
```

---

<a id="cmd-storage"></a>
### `storage` — Persistent Storage Operations

```
storage option ?arg ...?
```

Provides persistent storage using the Windows registry or interpreter-based storage, with optional DPAPI data protection.

**Policy-allowed sub-commands**: `isolated`, `options`

#### Common behavior

- **Storage backends.** `-type` selects the backend — `Registry` (Windows
  registry) or `Interpreter` (in-interpreter storage). When `-type` is omitted,
  the global default set by `storage type` is used.
- **Scope and protection.** `-permachine` selects per-machine rather than
  per-user storage, and `-security` selects the security-protected store; stored
  values are returned base64-encoded.
- **DPAPI.** `protect` / `unprotect` wrap the Windows Data Protection API
  (`-permachine` chooses machine vs. user scope) and require the `NATIVE`
  compile-time flag; they are independent of the registry / interpreter stores.

#### Sub-commands

##### `storage about`

```
storage about
```

Returns plugin "about" information.

---

##### `storage delete`

```
storage delete ?options? name
```

Deletes a storage value by *name*.

| Option | Type | Description |
|--------|------|-------------|
| `-type` | StorageType | `Registry` or `Interpreter` |
| `-permachine` | Boolean | Per-machine (vs. per-user) storage |
| `-security` | Boolean | Security-protected storage |

---

##### `storage isolated`

```
storage isolated
```

Returns whether the plugin is running in an isolated context.

---

##### `storage list`

```
storage list ?options?
```

Lists all storage value names.

| Option | Type | Description |
|--------|------|-------------|
| `-type` | StorageType | `Registry` or `Interpreter` |
| `-permachine` | Boolean | Per-machine storage |
| `-security` | Boolean | Security-protected storage |

---

##### `storage options`

```
storage options
```

Returns plugin option information.

---

##### `storage protect`

```
storage protect ?options? data entropy
```

Protects (encrypts) *data* using DPAPI with *entropy* as additional entropy.

| Option | Type | Description |
|--------|------|-------------|
| `-permachine` | Boolean | Use machine scope (vs. user scope) |

**Requires:** `NATIVE`

**Returns:** Base64-encoded protected data.

---

##### `storage read`

```
storage read ?options? name
```

Reads a storage value by *name*.

| Option | Type | Description |
|--------|------|-------------|
| `-type` | StorageType | `Registry` or `Interpreter` |
| `-permachine` | Boolean | Per-machine storage |
| `-security` | Boolean | Security-protected storage |

**Returns:** Base64-encoded bytes.

---

##### `storage type`

```
storage type ?type?
```

Gets or sets the global storage type. Without *type*, returns the current type. With *type* (empty string to unset), sets it.

**Example:**
```tcl
storage type Interpreter   ;# Set to Interpreter storage
storage type ""            ;# Reset to default
```

---

##### `storage unprotect`

```
storage unprotect ?options? data entropy
```

Unprotects (decrypts) DPAPI-protected *data* using *entropy*.

| Option | Type | Description |
|--------|------|-------------|
| `-permachine` | Boolean | Use machine scope |

**Requires:** `NATIVE`

**Returns:** Base64-encoded unprotected data.

---

##### `storage write`

```
storage write ?options? name value
```

Writes *value* to storage under *name*.

| Option | Type | Description |
|--------|------|-------------|
| `-type` | StorageType | `Registry` or `Interpreter` |
| `-permachine` | Boolean | Per-machine storage |
| `-security` | Boolean | Security-protected storage |

**Example:**
```tcl
storage type Interpreter
storage write myKey $data
set retrieved [storage read myKey]
storage delete myKey
```

---

<a id="cmd-support"></a>
### `support` — Diagnostics and Support Information

```
support ?option? ?arg ...?
```

Provides diagnostic information and support tooling. When called with no sub-command (just `support`), returns the support URI directly.

**Policy-allowed sub-commands**: `isolated`, `options`

#### Sub-commands

##### `support about`

```
support about
```

Returns plugin "about" information.

---

##### `support diagnostic`

```
support diagnostic ?list?
```

Queries or modifies diagnostic settings. Without *list*, returns a summary of all "Get" diagnostics. With *list* (a Tcl list of `SupportDiagnostic` enum values), processes each entry.

**Available diagnostics:**

| Diagnostic | Description |
|------------|-------------|
| `GetExtraDiagnostics` | Returns whether extra diagnostics are compiled in |
| `GetForceTrace` | Returns whether force trace is compiled in |
| `GetUri` | Returns the support URI |
| `GetNormalizeErrors` | Returns error normalization state |
| `EnableNormalizeErrors` | Enables error normalization |
| `DisableNormalizeErrors` | Disables error normalization |
| `GetIncludePublicKeyToken` | Returns public key token inclusion state |
| `EnableIncludePublicKeyToken` | Enables public key token in traces |
| `DisableIncludePublicKeyToken` | Disables public key token in traces |
| `GetTracing` | Returns trace subsystem state |
| `EnableTracing` | Enables trace subsystem |
| `DisableTracing` | Disables trace subsystem |
| `GetLogFileNames` | Returns trace log file names |

Note: `EnableExtraDiagnostics`, `DisableExtraDiagnostics`, `EnableForceTrace`, `DisableForceTrace`, `EnableUri`, `DisableUri`, `EnableLogFileNames`, `DisableLogFileNames` are compile-time only and return `"unsupported"`.

---

##### `support isolated`

```
support isolated
```

Returns whether the plugin is running in an isolated context.

---

##### `support options`

```
support options
```

Returns plugin option information.

---

## Configuration Subsystem Architecture

<a id="configuration-subsystem-architecture"></a>

This section explains the design, structure, and robustness guarantees of the
Harpy configuration subsystem. Understanding this architecture provides the
context needed to work with the [107 transient commands](#configuration-subsystem-commands)
that follow.

---

<a id="arch-entry-points"></a>
### Entry Points and Call Chain

Configuration loading is initiated through a three-method call chain:

```
MaybeLoadFor()          (public, top-level entry point)
  │
  ├── Pre-checks NoConfiguration environment variable
  ├── Resolves plugin type, directory, key pairs, key usage
  ├── Reads environment flags (environmentOnly, failOnError, etc.)
  │
  └── MaybeLoadAll()    (private, orchestration layer)
        │
        ├── Checks NoConfiguration again (fast exit)
        ├── Optionally creates isolated interpreter
        ├── Supports async loading via thread pool (Engine.QueueWorkItem)
        │
        └── LoadAll()   (private, core loop)
              │
              ├── MaybeGatherAndReadAll() — file discovery
              ├── Creates EvaluateClientData (using block)
              ├── foreach loop over configuration files
              ├── DequeueScripts / goto retry — dynamic chaining
              └── Tracks ok/error file names via IConfiguration
```

**ConfigurationPhase** controls when loading occurs:

| Phase | Value | Trigger |
|---|---|---|
| `Initialize` | `0x4` | `IState.Initialize` — plugin startup |
| `Verify` | `0x8` | License verification subsystem |
| `Demand` | `0x10` | On-demand via script command |
| `Terminate` | `0x20` | `IState.Terminate` — plugin shutdown |
| `Manager` | `0x100` | License manager context |
| `Isolated` | `0x200` | Isolated (sandbox) context |

The phase is passed through to configuration scripts as a context variable,
allowing them to vary behavior depending on when they are evaluated.

---

<a id="arch-file-discovery"></a>
### Configuration File Discovery

The `MaybeGatherAndReadAll()` method discovers configuration files in six phases:

| Phase | Description |
|---|---|
| **#0** | Detect debugger presence (native, managed, or forced via environment variable). Sets a flag that causes additional debug-variant files to be discovered. |
| **#1** | Gather inline script blocks and their signatures from the process environment (`GatherAllFromEnvironment`). |
| **#2** | Query explicit configuration file paths from environment variables (`AddEnvironmentFileNames`, `AddEnvironmentFilePatterns`). |
| **#3** | Build the implicit file list by scanning the configuration directory (`GatherAllFromDirectory`). Skipped if the override-only environment variable is set. |
| **#4** | Resolve the optional epilogue file and/or stream, appended after each main configuration file. |
| **#5** | Read data from all gathered files/streams, deduplicate (`GetUniqueElements`), and produce `FileAndOrStreamDataList`. |

**File naming convention:**

Configuration files follow a structured naming pattern with optional segments:

```
<simple>.<pluginType>.v1.<machineId>.<variant>.<extension>
```

Where:
- `<simple>` — base name (e.g., from `GetSimpleNames()`)
- `<pluginType>` — optional, fully-qualified plugin type name
- `v1` — version tag (always present)
- `<machineId>` — optional, GUID identifying the machine
- `<variant>` — optional, variant name from assembly configuration
- `<extension>` — file extension (e.g., `.eagle`)

The format constants range from `ConfigurationFileNameFormat1` (simplest: `{0}.v1{1}`)
through `ConfigurationFileNameFormat14` (most specific, including all optional segments).
The system iterates from most-specific to least-specific:

1. `<simple>.<pluginType>.v1.<machineId>.<variant>.<ext>` — machine + variant + type
2. `<simple>.v1.<machineId>.<variant>.<ext>` — machine + variant
3. `<simple>.<pluginType>.v1.<machineId>.<ext>` — machine + type
4. `<simple>.v1.<machineId>.<ext>` — machine only
5. `<simple>.<pluginType>.v1.<variant>.<ext>` — variant + type
6. `<simple>.v1.<variant>.<ext>` — variant only
7. `<simple>.<pluginType>.v1.<ext>` — type only
8. `<simple>.v1.<ext>` — generic (least specific)

Each configuration file has a companion `.b64sig` signature file containing the
base64-encoded cryptographic signature. Files are only evaluated if signature
verification succeeds.

---

<a id="arch-evaluate-client-data"></a>
### EvaluateClientData — The Central State Carrier

`EvaluateClientData` is the central object that carries all state through the
configuration evaluation pipeline. It is created once per `LoadAll()` invocation
and is passed to every method in the chain.

**Inheritance chain:**

```
ClientData                      (Eagle core)
  └── ScriptClientData          (script text, encoding)
        └── ScriptContextClientData  (IHavePlugin, IHaveFileName, IHaveExecutionPolicy)
              └── ScriptLogClientData     (ILogClientData — optional trace logging)
                    └── EvaluateClientData     (IIdentifier — full configuration state)
```

**Thread safety:** All mutable state access is protected by a private `syncRoot`
object. Every property getter and mutating method acquires `lock (syncRoot)` before
accessing fields. Reference counting uses `Interlocked.Increment` / `Interlocked.Decrement`.

**Key state fields:**

| Category | Fields | Purpose |
|---|---|---|
| Version control | `minimumVersion`, `maximumVersion` | Required version range (immutable once set) |
| Key management | `keyPairs`, `keyPair`, `keyName`, `keyRingName`, `hashValue`, `signature` | Cryptographic signing state |
| Trust/flags | `trustFlags`, `untrusted`, `configurationPhase` | Trust level and current phase |
| Error control | `failOnError`, `fatalError` | Error escalation behavior |
| Script queuing | `scriptQueue` (`ScriptList`) | Dynamic script chaining |
| Command tracking | `commandTokens` (`LongList`), `withCommands`, `removeCommands`, `swapCommands` | Transient command lifecycle |
| Scoping | `scopeFrame`, `useContext`, `noGlobalOnly`, `extractAndApply` | Variable scoping and commit behavior |
| Sandbox | `sandboxes` (`Dictionary<long, SandboxData>`), `sandboxToken` | Sandbox interpreter tracking |

**Key methods:**

- **`AddReference()` / `RemoveReference()`** — Atomic reference counting via
  `Interlocked.Increment` / `Interlocked.Decrement`. A return value of `1` from
  `AddReference()` indicates the top-level (first) entry, gating command registration
  and variable setup. `ResetReferences()` forcibly sets the count to zero.

- **`QueueScript(text, signature, name)`** — Appends a script to the internal
  `scriptQueue` for deferred evaluation after the main loop completes.

- **`DequeueScripts()`** — Converts queued scripts into a `FileAndOrStreamDataList`,
  clears the queue, and returns the list (or `null` if empty).

- **`CheckRequiredVersion()`** — Called by every transient command; verifies the
  plugin assembly version falls within the required range. Returns error if out of range.

- **`SetRequiredVersion()`** — Sets the minimum/maximum version range. Once set,
  the range can only be narrowed, never widened (immutable ceiling).

- **`DoNotModifyInterpreter()`** — Disables all flags that would modify the
  interpreter (`withCommands`, `removeCommands`, `swapCommands`, `useContext`).
  Used when the configuration should be read-only.

- **`ForNewScript(clientData, data)`** — Resets per-file state (fileName, stream,
  signature, hashValue) for the next iteration of the main loop.

The entire `EvaluateClientData` instance is wrapped in a `using` block within
`LoadAll()`, ensuring disposal even on exceptions.

---

<a id="arch-context-variables"></a>
### Context Variables and the Two-Phase Model

The `ScriptContext` static class manages configuration variables that are set
before each script runs and optionally committed to the interpreter afterward.

**Variable lifecycle:**

```
RefreshVariables()              Set read-only + writable variables
       │                        into interpreter for script access
       ▼
  [Script runs]                 Script may modify writable variables
       │
       ▼
SignalChanged() ◄── dirty flag  Script calls commands that flag
       │                        which variables were modified
       ▼
HasChanged() ─── check ───►    Only changed variables are extracted
       │
       ▼
ExtractAndApplyVariables()      Commit changed values to global
       │                        plugin state (only on success)
       ▼
UnsetVariables()                Remove all context variables from
                                interpreter (always, in finally)
```

**Dirty-flag tracking:** The `SignalChanged(clientData, key)` method marks a
variable as modified. `HasChanged(clientData, key)` checks the dirty flag.
During `ExtractAndApplyVariables`, only variables where `HasChanged` returns
`true` (or where `ignoreChanged` is set) are committed.

**Two-phase commit:** Script evaluation is local (Phase 1). If and only if the
script succeeds (`ReturnCode.Ok`), `ExtractAndApplyVariables` commits changes
to global state (Phase 2). If the script fails, `extractAndApply` is set to
`false` and no changes propagate.

**Save/Restore:** `SaveVariables()` captures the current variable state into a
named snapshot (using `FormatSaveStateVariableName`). `RestoreVariables()`
reloads from that snapshot and optionally removes it. This enables commands like
[`saveState`](#config-introspection) and [`restoreState`](#config-introspection).

---

<a id="arch-transient-commands"></a>
### Transient Command Lifecycle

The 107 transient commands exist only during configuration script evaluation.
Their registration and removal follow a precise lifecycle:

```
AddReference() == 1?  ◄── top-level entry gate
       │ yes
       ▼
RemoveAllCommands()   ◄── optional, if removeCommands flag set
       │
       ▼
SwapCommands()        ◄── optional, saves and replaces command table
       │
       ▼
AddAllCommands()      ◄── registers 107 commands, returns tokens[]
       │
       ▼
  [Script runs]       ◄── commands available during evaluation
       │
       ▼
RemoveTokens()        ◄── removes commands by token (in finally)
       │
       ▼
SwapCommands()        ◄── restores original command table (in finally)
```

**Registration gating:** Commands are only added when `WithCommands` is `true`
AND `AddReference()` returns `1` (indicating the top-level, non-nested entry).
This prevents duplicate registration during recursive configuration loading.

**Two registration paths:**

- **`ExecuteCallback` delegates** — Used in same-AppDomain scenarios. All 107
  commands are implemented as static methods in the `Callbacks` class, registered
  via `AddAllCommandsViaBuiltIns()`.

- **`ICommand` objects** — Used for cross-AppDomain scenarios. Registered via
  `AddAllCommandsViaReflection()` (test/debug mode).

**Token tracking:** Each registered command returns a `long` token. These tokens
are stored in `clientData.CommandTokens` via `AddCommandTokens()` and used for
precise removal via `RemoveTokens()`. This ensures exactly the commands that were
added are removed.

**Guaranteed cleanup:** Command removal occurs in a `finally` block, ensuring
commands are removed even if the script throws an exception.

---

<a id="arch-per-file-flow"></a>
### Per-File Evaluation Flow

Within the `LoadAll` loop, each configuration file (or stream) follows this
sequence. The main logic resides in `EvaluateFile()` / `EvaluateStream()`:

1. **`ForNewScript(clientData, data)`** — Reset per-file state (fileName, stream,
   signature, hashValue) on the `EvaluateClientData` instance.

2. **`ResetRequiredVersion(clientData, true)`** — Clear the required version range
   so each file starts with a clean version constraint.

3. **`VerifyFile()`** — Cryptographically verify the file against its `.b64sig`
   companion. Determines the script type (signed/unsigned), the matching key pair,
   and whether command swapping should be enabled.

4. **`RefreshVariables()`** — Set all context variables into the interpreter.
   Includes plugin state, file metadata, phase, key pair info, and more.

5. **`SwapCommands()`** — If enabled, save the current interpreter command table
   and replace it with an empty one (isolation).

6. **`AddAllCommands()`** — Register the 107 transient commands. Track returned
   tokens for later removal.

7. **`EvaluateTrustedScript()` / `EvaluateScript()`** — Execute the configuration
   script. Trusted execution temporarily grants access to unsafe commands (even
   in a safe interpreter) and bypasses normal security policy checks. Untrusted
   execution uses the standard evaluation path.

8. **`ExtractAndApplyVariables()`** — If the script succeeded and `extractAndApply`
   is `true`, commit changed context variables to global plugin state.

9. **`RemoveTokens()`** — Remove all transient commands by their tracked tokens.

10. **Restore swapped commands** — If commands were swapped, restore the original
    command table.

11. **`UnsetVariables()`** — Remove all context variables from the interpreter.

**Loop control mapping:** Configuration scripts can use flow control commands
that map to Eagle return codes:

| Command | Return Code | Effect |
|---|---|---|
| [`breakOutNow`](#config-flow-control) | `ReturnCode.Break` | Stop processing remaining files |
| [`continueWithNow`](#config-flow-control) | `ReturnCode.Continue` | Skip to next file |
| [`returnBackNow`](#config-flow-control) | `ReturnCode.Return` | Exit current file (mapped to `Ok`) |

---

<a id="arch-error-handling"></a>
### Error Handling and Robustness Guarantees

The configuration subsystem uses multiple layers of `try`/`finally` blocks to
guarantee cleanup regardless of how script evaluation terminates:

```
EvaluateFile() / EvaluateStream()
│
├── try ─────────────────────────────── savedKeyPair restoration
│   │
│   ├── try ──────────────────────────── RemoveReference() (ref counting)
│   │   │
│   │   ├── try ─────────────────────── ExtractAndApply + UnsetVariables
│   │   │   │
│   │   │   ├── try ─────────────────── RemoveTokens + RestoreSwapped
│   │   │   │   │
│   │   │   │   └── [Script runs]
│   │   │   │
│   │   │   └── finally: remove command tokens, restore swapped commands
│   │   │
│   │   └── finally: ExtractAndApply (if success), UnsetVariables (always)
│   │
│   └── finally: RemoveReference()
│
└── finally: restore savedKeyPair
```

**Error escalation levels:**

| Level | Mechanism | Behavior |
|---|---|---|
| Normal error | `ReturnCode.Error` | Logged; continues to next file (default) |
| `FailOnError` | `clientData.FailOnError` flag | Returns `ReturnCode.Error` from `LoadAll`, halting all processing |
| `FatalError` | `clientData.FatalError` flag | Immediately returns from `LoadAll`; set by the [`fatalError`](#config-flow-control) command |
| Stop on error | `stopOnError` parameter | Breaks out of the loop but returns normally |

**Script-level error handling:** Configuration scripts can use built-in error
control commands:

- [`evaluateWithCleanup`](#config-script-evaluation) — Evaluate a script with
  guaranteed cleanup, even on error.
- [`evaluateWithoutError`](#config-script-evaluation) — Evaluate a script,
  suppressing any error result.

**Robustness invariants — the following are ALWAYS guaranteed:**

- **Commands are ALWAYS removed** — `RemoveTokens()` runs in a `finally` block;
  transient commands never leak into the permanent command table.
- **Variables are ALWAYS unset** — `UnsetVariables()` runs in a `finally` block;
  context variables never persist after configuration evaluation.
- **Swapped command tables are ALWAYS restored** — The second `SwapCommands()`
  call runs in a `finally` block.
- **Key pairs are ALWAYS restored** — `savedKeyPair` is restored in the outermost
  `finally` block.
- **Reference count is ALWAYS decremented** — `RemoveReference()` runs in a
  `finally` block, ensuring the nesting count remains correct.
- **Streams are ALWAYS closed** — `CloseStreamsAndReset()` runs in the `LoadAll`
  outer `finally` block.

---

<a id="arch-security-model"></a>
### Security Model

The configuration subsystem enforces a strict security model:

**Cryptographic signing:** Every configuration file must have a valid cryptographic
signature. The `VerifyFile()` method checks the file content against its `.b64sig`
companion file using the key pairs loaded at startup. Files that fail verification
are rejected before any script evaluation occurs.

**Hardcoded keys:** When no `IConfiguration` interface is available, key pairs are
loaded exclusively from the Harpy assembly itself (`CertificateAssemblyOps.GetObject()`).
This prevents unauthorized keys from being used to sign configuration scripts.

**Trusted vs. untrusted execution:** By default, configuration scripts run in
trusted mode via `interpreter.EvaluateTrustedScript()`, which sets specific
`TrustFlags` that temporarily grant access to unsafe commands (even in a safe
interpreter) and bypass normal security policy checks. The `untrusted` flag
(controlled via `EvaluateClientData`) can force standard evaluation instead.

**Command flags:** All 107 transient commands use `CommandFlags.Unsafe | CommandFlags.NoAdd`:
- `Unsafe` — commands are hidden in safe interpreters; however, trusted evaluation (e.g., `EvaluateTrustedScript`) temporarily grants access to unsafe commands, even in a safe interpreter.
- `NoAdd` — commands cannot be added to the permanent interpreter command table.

**ENTERPRISE_LOCKDOWN:** When compiled with this flag, additional restrictions
are enforced on key ring operations and other security-sensitive functionality.

**Version gating:** `SetRequiredVersion()` establishes a version range that is
checked by `CheckRequiredVersion()` at the start of every transient command.
Once set, the range can only be narrowed (never widened), preventing a later
script from relaxing version constraints established by an earlier one.

**Command table swapping:** When `swapCommands` is enabled, the interpreter's
entire command table is saved and replaced before the configuration script runs.
This isolates the script from commands that should not be accessible during
configuration. The original table is always restored afterward.

**Interpreter creation control:** `VerifyFile()` can set a
`disableInterpreterCreation` flag based on script metadata. When set, the
`Utility.DisableInterpreterCreation()` method prevents the configuration script
from creating new interpreter instances.

---

<a id="arch-dynamic-queuing"></a>
### Dynamic Script Queuing

Configuration scripts can dynamically enqueue additional scripts for evaluation
after the main file loop completes:

```
LoadAll() main loop
       │
  foreach file in configurations
       │  ◄── scripts may call [queueScript]
       ▼
  DequeueScripts()
       │
       ├── null? ──► return Ok (done)
       │
       └── non-null?
             │
             ├── CloseStreamsAndReset(configurations)
             ├── configurations = queue
             └── goto retry  ──► restart the foreach loop
```

The [`queueScript`](#config-script-evaluation) command calls
`clientData.QueueScript(text, signature, name)`, which appends a
`ScriptTriplet` to the internal `scriptQueue`. After all files in the current
batch have been evaluated, `DequeueScripts()` converts the queue into a new
`FileAndOrStreamDataList`. If non-null, the main loop restarts with the new
list via `goto retry`.

This mechanism enables configuration scripts to dynamically chain additional
configuration logic without requiring those scripts to be discovered during
the initial file gathering phases.

---

<a id="arch-cross-appdomain"></a>
### Cross-AppDomain Support

The configuration subsystem detects and adapts to cross-AppDomain scenarios:

- **Detection:** `Utility.IsCrossAppDomain(interpreter, plugin)` determines
  whether the plugin is running in a different AppDomain from the interpreter.

- **Command registration:** In cross-AppDomain mode, commands must be registered
  as `ICommand` objects (which are `MarshalByRefObject`) rather than
  `ExecuteCallback` delegates (which cannot cross AppDomain boundaries).

- **Isolated interpreters:** When the `IsolatedConfiguration` environment variable
  is set, `MaybeLoadAll()` creates a new interpreter specifically for configuration
  evaluation. This interpreter is disposed after use.

- **`PluginIsolated` context variable:** Exposed to configuration scripts so they
  can detect and adapt to cross-AppDomain execution.

- **Sandbox support:** `sandboxToken` tracks sandbox interpreters. When non-null,
  existing sandbox interpreters may be reused rather than creating new ones.

---

<a id="arch-thread-safety"></a>
### Thread Safety

The configuration subsystem uses several mechanisms to ensure thread safety:

- **`EvaluateClientData.syncRoot`** — A private `readonly object` that guards all
  mutable field access. Every property getter and mutating method acquires
  `lock (syncRoot)` before reading or writing state.

- **`Interlocked` operations** — Reference counting (`AddReference`,
  `RemoveReference`, `ResetReferences`) uses `Interlocked.Increment`,
  `Interlocked.Decrement`, and `Interlocked.Exchange` for lock-free atomicity.

- **Async loading** — `MaybeLoadAll()` supports asynchronous configuration loading
  via `Engine.QueueWorkItem()`. When the `AsynchronousConfiguration` environment
  variable is set, the entire `LoadAll()` call is dispatched to the thread pool.

- **Single-threaded script execution** — Within a single configuration evaluation,
  script execution is always single-threaded per interpreter. The threading check
  `Utility.HaveEagleThreading(interpreter) || interpreter.IsPrimaryThread()` is
  enforced at the start of `EvaluateFile()` and `EvaluateStream()`.

---

<a id="arch-plugin-lifecycle"></a>
### Plugin Lifecycle Integration

The configuration subsystem is tightly integrated with the Harpy plugin lifecycle
(`Plugins.Default` class):

**Initialize sequence** (`IState.Initialize`):

1. `SetupForCoreLibraryState()` — Initialize core library bindings.
2. `MaybeCleanupAll("Initialize")` — Clean up stale global state.
3. `AssemblyOps.AddReference()` — Track plugin reference in interpreter.
4. `KeyFile.InitializeKeyPairTypes()` — Register key pair type handlers.
5. `InitializeMappings()` / `InitializeDurations()` / `InitializeRanges()` —
   Set up policy mappings, time durations, and version ranges.
6. `SetupWellKnownConfigurationData()` — Populate well-known configuration entries.
7. `LoadConfigurations(ConfigurationPhase.Initialize)` — Execute the full
   configuration loading pipeline via `MaybeLoadFor()`.

**Terminate sequence** (`IState.Terminate`):

1. `ClearConfigurationFileNames()` — Remove tracked file name data.
2. `CleanupInterpreters()` — Dispose sandbox interpreters.
3. `AssemblyOps.RemoveReference()` — Decrement plugin reference count.
4. `RemoveAllTrusted()` — If reference count reaches zero, remove trusted keys.
5. `CleanupOne()` / `MaybeCleanupAll("Terminate")` — Clean up global state.

**Reconfigure flow:** The `Demand` phase (`ConfigurationPhase.Demand`) enables
on-demand re-evaluation of configuration scripts at runtime. This is triggered
by script commands rather than the plugin lifecycle, using the same `MaybeLoadFor()`
entry point with a different phase value.

**Phase exposure:** The `ConfigurationPhase` enum value is passed into
`EvaluateClientData` and exposed to configuration scripts as a context variable,
enabling phase-specific behavior within configuration scripts.

---

## Configuration Subsystem Commands

<a id="config-overview"></a>
### Overview

The Harpy plugin configuration subsystem provides **107 transient (temporary) commands** that are available **only during configuration script evaluation**. These commands are automatically added when the plugin evaluates its configuration scripts and are removed immediately afterward.

**Key characteristics:**
- All are gated by `#if ISOLATED_INTERPRETERS || ISOLATED_PLUGINS` at compile time
- All use `CommandFlags.Unsafe | CommandFlags.NoAdd` — they are hidden in safe interpreters (accessible only via trusted evaluation) and never added to the permanent command table
- All are implemented as static methods in the internal `Callbacks` class matching the `ExecuteCallback` delegate
- All validate the interpreter and arguments, and most check `EvaluateClientData.CheckRequiredVersion`
- Script-level names use **lowerCamelCase** (e.g., `applyContextVariables`, `forEachPolicyType`)
- They operate on the `EvaluateClientData` context object, interpreter context variables, and global state

**When these commands are available:**
These commands exist only during the execution of Harpy configuration scripts (e.g., the plugin's startup/configuration phase). They cannot be called from normal user scripts. They are the building blocks used by configuration scripts to set up security policies, key rings, certificates, licensing, and other plugin state.

---

<a id="config-quick-reference"></a>
### Quick Reference

| Command | Category | Syntax | Compilation Gate |
|---------|----------|--------|-----------------|
| `addCertificates` | Key/Cert | `path ?snippetFlags? ?lookupFlags?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `addPublicKey` | Key/Cert | `metadata data ?varName?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `addRingPublicKey` | Key/Cert | `metadata data ?varName? ?policyType?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `applyContextVariables` | Context Vars | `?contextName?` | — |
| `breakOutNow` | Flow Control | `?result?` | — |
| `changeDuration` | Property | `policyType ?duration?` | — |
| `changeFeatures` | Feature/Policy | `?features?` | `CERTIFICATE_PLUGIN && !LIMITED_EDITION` |
| `changeLicensePolicy` | Feature/Policy | `?policy?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `changeLicenseProperty` | Property | `id ?name? ?value?` | `CERTIFICATE_PLUGIN && PLUGIN_COMMANDS` |
| `changeNetworkFlags` | Feature/Policy | `policyType ?flags?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `changePathFlags` | Feature/Policy | `policyType ?flags?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `changePolicyProperty` | Feature/Policy | `policyType propertyName ?propertyValue?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `changeTimeServers` | Property | `?servers?` | — |
| `changeVersionRange` | Property | `policyType ?versionRange?` | — |
| `cleanupForSandbox` | Sandbox | `id` | `TEST` |
| `configurePackages` | Feature/Policy | `?flags?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `configureRuleSet` | Feature/Policy | `type ruleSets` | — |
| `continueWithNow` | Flow Control | `?result?` | — |
| `demoMode` | Property | `?enable?` | `DEMO_KEY_PAIRS \|\| DEMO_EDITION` |
| `disableInterpreterCreation` | Feature/Policy | `persistent` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `downloadAndInstall` | Network | `uri ?flags? ?targetDirectory? ?plugin?` | `XML && NETWORK && WEB` |
| `enableExtractAndApply` | Property | `enable` | — |
| `enableInterpreterCreation` | Feature/Policy | `persistent` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `enableLocalPolicy` | Feature/Policy | `enable` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `enableSecurity` | Feature/Policy | `?flags?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `evaluateFile` | Evaluation | `fileName ?flags? ?password?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `evaluateInSandbox` | Sandbox | `fileName ?varName?` | `TEST` |
| `evaluateStream` | Evaluation | `fileName ?assembly? ?flags?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `evaluateWithCleanup` | Evaluation | `body1 finally body2` | — |
| `evaluateWithoutError` | Evaluation | `body1 ?else? ?body2?` | — |
| `evaluateWithScope` | Evaluation | `script` | — |
| `extractZipFile` | Network | `fileName directory` | `XML && NETWORK && WEB` |
| `failOnError` | Flow Control | `enable` | — |
| `failSafeMode` | Property | `?enable?` | — |
| `fatalError` | Flow Control | `?message? ?errorLine?` | — |
| `forEachFile` | Iteration | `pattern ?directory? ?script? ?varName?` | — |
| `forEachPolicyType` | Iteration | `varName script` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `haveComponent` | Introspection | `name` | — |
| `haveConfiguration` | Introspection | `name` | — |
| `haveEnvironment` | Introspection | `name` | — |
| `haveFeatures` | Introspection | `features ?all?` | `CERTIFICATE_PLUGIN && !LIMITED_EDITION` |
| `haveIdentifier` | Introspection | `name ?kind?` | — |
| `havePublicKey` | Key/Cert | `keyPair` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `haveRingPublicKey` | Key/Cert | `keyPair ?policyType?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `haveVariable` | Introspection | `name` | — |
| `interactiveLoop` | Flow Control | *(no args)* | `SHELL` |
| `isDebuggerPresentOrAttached` | Introspection | *(no args)* | — |
| `isRestrictedInterpreter` | Introspection | `?flags?` | — |
| `issueTicket` | Requirement | `scope policyType key ?id?` | — |
| `joinSubPaths` | Utility | `name ?name ...?` | — |
| `joinUriParts` | Network | `baseUri relativeUri ?varName?` | `WEB` |
| `keyUsage` | Ensemble | `subCommand ?entityType? ?...?` | — |
| `listComponents` | Introspection | *(no args)* | — |
| `listContextVariables` | Introspection | *(no args)* | — |
| `makeUriRequest` | Network | `uri ?data? ?method? ?raw? ?fileName?` | `XML && NETWORK && WEB` |
| `matchPlatform` | Introspection | `patterns` | — |
| `maybeEvaluate` | Evaluation | `expr1 body1 ?else? ?body2?` | — |
| `maybeIterateUsingExpression` | Iteration | `?list? body` | — |
| `maybeRecordResult` | Evaluation | `flags tag arg ?arg ...?` | — |
| `notAfter` | Time/Version | `dateTime ?flags?` | — |
| `notBefore` | Time/Version | `dateTime ?flags?` | — |
| `offlineMode` | Property | `?enable?` | `NETWORK` |
| `peekOnFlags` | Introspection | `fileName flagType ?hasFlags?` | — |
| `queryStatus` | Introspection | `name` | — |
| `queueScript` | Evaluation | `script signature ?name?` | — |
| `readScript` | Evaluation | `verify name` | — |
| `redeemTicket` | Requirement | `scope policyType ticket key` | — |
| `refreshContextVariables` | Context Vars | `?readOnly?` | — |
| `removeLicense` | Network | `id` | `XML && NETWORK && WEB` |
| `removePublicKey` | Key/Cert | `varName` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `removeRingPublicKey` | Key/Cert | `varName ?policyType?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `requestLicense` | Network | `id ?baseUri? ?assemblyName?` | `XML && NETWORK && WEB` |
| `requireAdministrator` | Requirement | *(no args)* | — |
| `requireComponent` | Requirement | `name` | — |
| `requireData` | Requirement | `name` | — |
| `requireEnvironment` | Requirement | `name` | — |
| `requireFeatures` | Requirement | `?features?` | `CERTIFICATE_PLUGIN && !LIMITED_EDITION` |
| `requireIdentifier` | Requirement | `name ?kind?` | — |
| `requireLicense` | Requirement | `?fileName? ?policyType?` | — |
| `requireMachine` | Requirement | `list ?flags?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `requireNetwork` | Requirement | `policyType ?enable?` | — |
| `requireProcess` | Requirement | `list ?flags?` | — |
| `requirePublicKey` | Requirement | `publicKeyToken ?policyType?` | `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY` |
| `requireShell` | Requirement | `?flags?` | `SHELL && CERTIFICATE_PLUGIN && CERTIFICATE_POLICY && PLUGIN_COMMANDS` |
| `requireTracing` | Requirement | `?enable?` | — |
| `requireTrusted` | Requirement | `?fileName?` | — |
| `requireVariable` | Requirement | `name` | — |
| `requireVerified` | Requirement | `?fileName?` | — |
| `requireVersion` | Requirement | `?minimumVersion? ?maximumVersion?` | — |
| `restoreContextVariables` | Context Vars | `contextName` | — |
| `returnBackNow` | Flow Control | `?result?` | — |
| `saveContextVariables` | Context Vars | `contextName` | — |
| `setConfiguration` | Interp Vars | `name ?value?` | — |
| `setData` | Interp Vars | `name ?value?` | — |
| `setEnvironment` | Interp Vars | `name ?value?` | — |
| `setPassword` | Key/Cert | `id password` | `XML && CERTIFICATE_PLUGIN && PLUGIN_COMMANDS` |
| `setVariable` | Interp Vars | `name ?value?` | — |
| `skipLicense` | Feature/Policy | `?enable? ?types?` | — |
| `snippet` | Ensemble | `subCommand ?args?` | — |
| `storageType` | Ensemble | `?type?` | — |
| `swapCommands` | Utility | `?flags?` | — |
| `testMode` | Property | `?enable?` | — |
| `unsetVariable` | Interp Vars | `name` | — |
| `waitForSandbox` | Sandbox | `id ?timeout?` | `TEST` |
| `writeStatus` | Output | `?flags? ?tag?` | — |
| `writeWithoutFail` | Output | `arg ?arg ...?` | — |

**Total: 107 transient configuration commands** (including `TraceProxy` which is an internal helper command not directly callable by configuration scripts).

---

<a id="config-flow-control"></a>
### Flow Control

- **breakOutNow** — Break out of configuration evaluation
  - `breakOutNow ?result?`
  - Causes an immediate break out of the current configuration script evaluation loop. Returns `ReturnCode.Break` to signal the caller to stop processing.
  - **Returns**: The optional *result* argument (or empty).

- **continueWithNow** — Continue to next iteration
  - `continueWithNow ?result?`
  - Causes the current configuration loop iteration to skip remaining processing and continue with the next iteration. Returns `ReturnCode.Continue`.
  - **Returns**: The optional *result* argument (or empty).

- **returnBackNow** — Return from configuration evaluation
  - `returnBackNow ?result?`
  - Causes a return from the current configuration script. Returns `ReturnCode.Return`.
  - **Returns**: The optional *result* argument (or empty).

- **failOnError** — Enable/disable fail-on-error behavior
  - `failOnError enable`
  - Parses *enable* as a nullable boolean. Sets `evaluateClientData.FailOnError` to the new value.
  - **Returns**: The **previous** value of the fail-on-error flag (before modification).

- **fatalError** — Trigger or query fatal error state
  - `fatalError ?message? ?errorLine?`
  - Without arguments: returns whether the state was already in fatal error (inverted boolean).
  - With *message*: triggers a fatal error with that message and returns `ReturnCode.Error`.
  - Optional *errorLine* sets the error line number.
  - **Returns**: Boolean `!wasFatalError` (no args) or error message (with args).

- **interactiveLoop** — Enter interactive shell loop
  - `interactiveLoop`
  - Enters an interactive shell evaluation loop. Requires `#if SHELL`.
  - **Returns**: The result of the interactive loop.

---

<a id="config-script-evaluation"></a>
### Script Evaluation

- **evaluateFile** — Evaluate a script file
  - `evaluateFile fileName ?flags? ?password?`
  - Evaluates a script file with optional `EvaluateCommandFlags` and base64-encoded password. Supports multiple modes via flags:
    - `ViaBundle` — evaluate as a bundle file (requires `DATA`)
    - `ViaShell` — evaluate via the shell (requires `SHELL`)
    - `WithVerify` — verify signature before evaluation
    - `WithTrust` — evaluate as a trusted file
    - Default — plain file evaluation
  - If `NoComplain` flag is set, wraps result as `{returnCode result}` instead of propagating errors.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Script result or `{returnCode result}` list.

- **evaluateStream** — Evaluate script from embedded resource
  - `evaluateStream fileName ?assembly? ?flags?`
  - Evaluates a script from an embedded resource stream in the specified assembly (defaults to current assembly). Supports `WithVerify`, `WithTrust`, and default modes.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Script result or `{returnCode result}` list.

- **evaluateWithCleanup** — Try/finally for configuration scripts
  - `evaluateWithCleanup body1 finally body2`
  - Evaluates *body1*, then always evaluates *body2* in a `finally` block. The third argument must be the literal string `"finally"`.
  - **Returns**: The try body's result if the finally body succeeds; the finally body's result otherwise.

- **evaluateWithoutError** — Evaluate with error suppression
  - `evaluateWithoutError body1 ?else? ?body2?`
  - Evaluates *body1* and suppresses any error. If *body1* fails and an `else` clause is provided, evaluates *body2*. Always returns `ReturnCode.Ok`.
  - **Returns**: List containing try code/result (and optionally else code/result).

- **evaluateWithScope** — Evaluate within a scoped call frame
  - `evaluateWithScope script`
  - Evaluates *script* within a persistent scoped call frame that survives across calls.
  - **Returns**: The script's result and return code.

- **maybeEvaluate** — Conditional evaluation (if/else)
  - `maybeEvaluate expr1 body1 ?else? ?body2?`
  - Evaluates boolean expression *expr1*. If true, evaluates *body1*; if false and `else body2` is given, evaluates *body2*.
  - **Returns**: Result of the chosen body script.

- **maybeRecordResult** — Record and execute command/script
  - `maybeRecordResult flags tag arg ?arg ...?`
  - Executes a command or script based on `RecordResultType` flags:
    - `ForCommand` — execute as a command invocation
    - `ForScript` — evaluate as a script
    - `ForAutomatic` — auto-detect mode
  - **Returns**: The execution result.

- **queueScript** — Queue script for later execution
  - `queueScript script signature ?name?`
  - Queues a script (with its byte-array signature) for deferred execution. Auto-generates a name if not provided.
  - **Returns**: The queued script identifier.

- **readScript** — Read and optionally verify a script file
  - `readScript verify name`
  - If *verify* is true, reads and verifies the script's signature file. If false, reads without verification.
  - **Returns**: List of `{hexHash scriptText}`.

---

<a id="config-context-variables"></a>
### Context Variable Management

- **applyContextVariables** — Apply context variables to interpreter
  - `applyContextVariables ?contextName?`
  - If *contextName* is given, applies variables for that specific named context. Otherwise, extracts and applies all context variables.
  - **Returns**: Count of variables applied.

- **refreshContextVariables** — Refresh context variables in current frame
  - `refreshContextVariables ?readOnly?`
  - Refreshes context variables with full evaluation context data. Optional *readOnly* boolean (default: true).
  - **Returns**: Sorted list of refreshed variable names.

- **listContextVariables** — List available context variable names
  - `listContextVariables`
  - **Returns**: List of context variable names.

- **saveContextVariables** — Save context variables
  - `saveContextVariables contextName`
  - Saves the current context variables under the given *contextName*.
  - **Returns**: Result of the save operation.

- **restoreContextVariables** — Restore saved context variables
  - `restoreContextVariables contextName`
  - Restores previously saved context variables from *contextName*.
  - **Returns**: Result of the restore operation.

---

<a id="config-interpreter-variables"></a>
### Interpreter Variable Management

- **setVariable** — Set a context variable
  - `setVariable name ?value?`
  - Sets the named context variable to *value*. If no value given, gets the current value.
  - **Returns**: The variable value.

- **unsetVariable** — Unset a context variable
  - `unsetVariable name`
  - Removes the named context variable.
  - **Returns**: The variable name on success.

- **setConfiguration** — Set a configuration value
  - `setConfiguration name ?value?`
  - Gets or sets a named configuration value on the evaluate client data.
  - **Returns**: The configuration value.

- **setData** — Set AppDomain data
  - `setData name ?value?`
  - Gets or sets a named data value on the current AppDomain. The *name* is a format string with process ID and AppDomain ID as parameters.
  - **Returns**: The data value.

- **setEnvironment** — Set an environment variable
  - `setEnvironment name ?value?`
  - Gets or sets a system environment variable. If *value* is empty/null, the variable is removed.
  - **Returns**: The environment variable value.

---

<a id="config-property-management"></a>
### Property and Mode Management

- **offlineMode** — Get/set offline mode
  - `offlineMode ?enable?`
  - Gets or sets the offline mode flag (nullable boolean). Signals context change when set.
  - **Requires**: `NETWORK`
  - **Returns**: Current or new offline mode value.

- **demoMode** — Get/set demo mode
  - `demoMode ?enable?`
  - Gets or sets the demo mode flag (nullable boolean).
  - **Requires**: `DEMO_KEY_PAIRS || DEMO_EDITION`
  - **Returns**: Current or new demo mode value.

- **testMode** — Get/set test mode
  - `testMode ?enable?`
  - Gets or sets the test mode flag (nullable boolean).
  - **Returns**: Current or new test mode value.

- **failSafeMode** — Get/set fail-safe mode
  - `failSafeMode ?enable?`
  - Gets or sets the fail-safe mode flag (nullable boolean).
  - **Returns**: Current or new fail-safe mode value.

- **enableExtractAndApply** — Enable/disable extract-and-apply
  - `enableExtractAndApply enable`
  - Parses *enable* as nullable boolean. Sets `evaluateClientData.ExtractAndApply`.
  - **Returns**: Current value of extract-and-apply flag.

- **changeDuration** — Get/set policy duration
  - `changeDuration policyType ?duration?`
  - Gets or sets a `TimeSpan` duration for a specific policy type. Empty value unsets the variable.
  - **Returns**: Current or new duration value.

- **changeTimeServers** — Get/set time servers
  - `changeTimeServers ?servers?`
  - Gets or sets the list of time servers (as a Tcl list).
  - **Returns**: Current or new time servers value.

- **changeVersionRange** — Get/set version range
  - `changeVersionRange policyType ?versionRange?`
  - Gets or sets a version range for a specific policy type.
  - **Returns**: Formatted version range.

- **changeLicenseProperty** — Get/set license properties
  - `changeLicenseProperty id ?name? ?value?`
  - With *id* only: lists all property names for the license.
  - With *id name*: gets a specific property value.
  - With *id name value*: sets a property value.
  - **Requires**: `CERTIFICATE_PLUGIN && PLUGIN_COMMANDS`
  - **Returns**: Property name list or property value.

---

<a id="config-feature-policy"></a>
### Feature and Policy Management

- **changeFeatures** — Get/modify plugin features
  - `changeFeatures ?features?`
  - Reads current features; if *features* is provided, applies add/remove change semantics.
  - **Requires**: `CERTIFICATE_PLUGIN && !LIMITED_EDITION`
  - **Returns**: Current or modified features value.

- **changeLicensePolicy** — Get/set license execution policy
  - `changeLicensePolicy ?policy?`
  - Gets or sets the `ExecutionPolicy` flags. Empty value unsets the policy.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Current or new execution policy.

- **changeNetworkFlags** — Get/set network flags per policy type
  - `changeNetworkFlags policyType ?flags?`
  - Gets or sets `NetworkFlags` for a specific policy type.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Current or new network flags.

- **changePathFlags** — Get/set path flags per policy type
  - `changePathFlags policyType ?flags?`
  - Gets or sets `PathFlags` for a specific policy type.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Current or new path flags.

- **changePolicyProperty** — Get/set named policy property
  - `changePolicyProperty policyType propertyName ?propertyValue?`
  - Generic getter/setter for policy configuration properties. Supported property names:
    - `KeyName` (String), `KeyRingName` (String)
    - `CurrentPolicy` (ExecutionPolicy), `ScriptFlags` (ScriptFlags)
    - `PathFlags` (PathFlags), `NetworkFlags` (NetworkFlags)
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Current or new property value.

- **configurePackages** — Configure packages for the plugin
  - `configurePackages ?flags?`
  - Configures packages using `PackageIfNeededFlags`. If `UseBuiltInMappings` is set, uses built-in assembly-to-plugin mappings (requires `TEST`); otherwise copies mappings from `CertificatePluginState`.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Result of package configuration.

- **configureRuleSet** — Configure policy rule sets
  - `configureRuleSet type ruleSets`
  - Parses `RuleSetType` and a `RuleSetDictionary`, filters by public key token, and merges matching rule sets into a single rule set.
  - **Returns**: String representation of the resulting rule set.

- **enableSecurity** — Enable security policies
  - `enableSecurity ?flags?`
  - Enables security policies and optionally bootstraps key rings. Accepts `EnableSecurityFlags`.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Formatted result summarizing what happened.

- **enableLocalPolicy** — Enable/disable local policy
  - `enableLocalPolicy enable`
  - Sets `evaluateClientData.AllowLocalPolicy` to the parsed boolean.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Current value of allow-local-policy flag.

- **disableInterpreterCreation** — Disable interpreter creation
  - `disableInterpreterCreation persistent`
  - Disables creation of new interpreters. The *persistent* boolean controls whether the setting survives resets.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: The enabled state (false when successfully disabled).

- **enableInterpreterCreation** — Enable interpreter creation
  - `enableInterpreterCreation persistent`
  - Enables creation of new interpreters. Inverse of `disableInterpreterCreation`.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: The enabled state (true when successfully enabled).

- **skipLicense** — Skip license checking
  - `skipLicense ?enable? ?types?`
  - Gets or sets whether license checking should be skipped, optionally for specific policy types.
  - **Returns**: Current or new skip-license value.

- **swapCommands** — Swap command implementations
  - `swapCommands ?flags?`
  - Swaps command implementations based on optional flags.
  - **Returns**: Result of the swap operation.

---

<a id="config-key-cert"></a>
### Key and Certificate Management

- **addCertificates** — Add certificate-based snippets
  - `addCertificates path ?snippetFlags? ?lookupFlags?`
  - If *path* is non-empty, loads certificate snippets from that path. If *path* is empty, lists existing snippets.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: List of snippet names.

- **addPublicKey** — Add public key to context
  - `addPublicKey metadata data ?varName?`
  - Adds a public key to the context's key pair collection. Optionally stores the result in *varName*.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: List of `{policyType keyName publicKeyToken}`.

- **addRingPublicKey** — Add public key to key ring
  - `addRingPublicKey metadata data ?varName? ?policyType?`
  - Adds a public key to a key ring for a specific policy type (default: `License`).
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: List of `{policyType keyName publicKeyToken}`.

- **havePublicKey** — Check if public key exists
  - `havePublicKey keyPair`
  - Checks whether a specific public key exists in the context's key pair collection.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Boolean.

- **haveRingPublicKey** — Check if public key exists in ring
  - `haveRingPublicKey keyPair ?policyType?`
  - Checks whether a public key exists in the key ring for a given policy type (default: `License`).
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Boolean.

- **removePublicKey** — Remove public key from context
  - `removePublicKey varName`
  - Removes a public key identified by the value of *varName* from the context's key pair collection.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: List of `{policyType keyName publicKeyToken}` or null.

- **removeRingPublicKey** — Remove public key from ring
  - `removeRingPublicKey varName ?policyType?`
  - Removes a public key from the key ring for a specific policy type (default: `License`).
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: List of `{policyType keyName publicKeyToken}` or null.

- **requirePublicKey** — Require a specific public key
  - `requirePublicKey publicKeyToken ?policyType?`
  - Requires that a specific public key token is available for the given policy type (default: `Script`).
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Ok on success; error if key not found.

- **requireMachine** — Require specific machine identifier
  - `requireMachine list ?flags?`
  - Verifies the current machine's GUID is in the provided *list*. `Guid.Empty` in the list matches any machine.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: The matched GUID.

- **setPassword** — Set a password/passphrase
  - `setPassword id password`
  - Sets a password associated with a GUID identifier using the GUID's bytes as salt.
  - **Requires**: `XML && CERTIFICATE_PLUGIN && PLUGIN_COMMANDS`
  - **Returns**: Ok on success.

---

<a id="config-requirements"></a>
### Requirement Checks

- **requireAdministrator** — Require administrator privileges
  - `requireAdministrator`
  - Checks whether the current user has administrator/root privileges.
  - **Returns**: Ok if administrator; error otherwise.

- **requireComponent** — Require a named component
  - `requireComponent name`
  - Checks whether a named component (command or define constant) exists.
  - **Returns**: Ok if found; error with "required component ... is unavailable".

- **requireData** — Require AppDomain data
  - `requireData name`
  - Retrieves required data from the current AppDomain. The *name* is a format string with process ID and AppDomain ID.
  - **Returns**: The data string value; error if unavailable.

- **requireEnvironment** — Require an environment variable
  - `requireEnvironment name`
  - Checks whether a named environment variable exists.
  - **Returns**: Ok if found; error if missing.

- **requireFeatures** — Require specific features
  - `requireFeatures ?features?`
  - Checks that all requested features are available. Without *features*, returns current features.
  - **Requires**: `CERTIFICATE_PLUGIN && !LIMITED_EDITION`
  - **Returns**: Features list if present; error if unavailable.

- **requireIdentifier** — Require a named identifier
  - `requireIdentifier name ?kind?`
  - Checks whether a named identifier (command, procedure, or `IExecute` entity) exists. Optional *kind* specifies `IdentifierKind`.
  - **Returns**: Ok if found; error if missing.

- **requireLicense** — Require a valid license
  - `requireLicense ?fileName? ?policyType?`
  - Checks and requires a valid license, optionally from a specific file and for a specific policy type.
  - **Returns**: Ok if license is valid; error otherwise.

- **requireNetwork** — Require/configure network access
  - `requireNetwork policyType ?enable?`
  - Gets or sets network access enablement for a policy type.
  - **Returns**: Current or new network enablement.

- **requireProcess** — Require specific process
  - `requireProcess list ?flags?`
  - Verifies the current process against a list of allowed process identifiers.
  - **Returns**: The matched identifier.

- **requireShell** — Require/configure shell
  - `requireShell ?flags?`
  - Gets or sets shell flags. If *flags* is empty, unsets the shell configuration.
  - **Requires**: `SHELL && CERTIFICATE_PLUGIN && CERTIFICATE_POLICY && PLUGIN_COMMANDS`
  - **Returns**: Current or new shell flags.

- **requireTracing** — Require/configure tracing
  - `requireTracing ?enable?`
  - Gets or sets tracing enablement.
  - **Returns**: Current or new tracing value.

- **requireTrusted** — Require trusted script
  - `requireTrusted ?fileName?`
  - Verifies that the current (or specified) script is trusted.
  - **Returns**: Ok if trusted; error otherwise.

- **requireVariable** — Require a context variable
  - `requireVariable name`
  - Checks that a named context variable exists.
  - **Returns**: Ok if present; error if missing.

- **requireVerified** — Require verified script
  - `requireVerified ?fileName?`
  - Verifies that the current (or specified) script has been verified.
  - **Returns**: Ok if verified; error otherwise.

- **requireVersion** — Require specific version range
  - `requireVersion ?minimumVersion? ?maximumVersion?`
  - Sets the minimum and/or maximum version requirements. Updates `evaluateClientData.RequiredVersion`.
  - **Returns**: Ok on success.

- **issueTicket** — Issue a security ticket
  - `issueTicket scope policyType key ?id?`
  - Issues a security ticket and stores it in an environment variable. The *key* is obfuscated with the process ID.
  - **Returns**: The created ticket string.

- **redeemTicket** — Redeem a security ticket
  - `redeemTicket scope policyType ticket key`
  - Validates and consumes a previously issued ticket from the environment.
  - **Returns**: The validated ticket string.

---

<a id="config-introspection"></a>
### Introspection and Status

- **haveComponent** — Check if component exists
  - `haveComponent name`
  - Checks if a command or define constant with the given name exists.
  - **Returns**: Boolean.

- **haveConfiguration** — Check if configuration exists
  - `haveConfiguration name`
  - Checks whether a named configuration exists in the evaluate context.
  - **Returns**: Boolean.

- **haveEnvironment** — Check if environment variable exists
  - `haveEnvironment name`
  - **Returns**: Boolean.

- **haveFeatures** — Check if features are present
  - `haveFeatures features ?all?`
  - Checks whether specified features are available. Optional *all* boolean controls whether ALL must match (default: any).
  - **Requires**: `CERTIFICATE_PLUGIN && !LIMITED_EDITION`
  - **Returns**: Boolean.

- **haveIdentifier** — Check if identifier exists
  - `haveIdentifier name ?kind?`
  - Checks whether a named identifier exists. Optional *kind* specifies `IdentifierKind` (default: `AnyIExecute`).
  - **Returns**: Boolean.

- **haveVariable** — Check if context variable exists
  - `haveVariable name`
  - Checks whether a named context variable exists.
  - **Returns**: Boolean.

- **isDebuggerPresentOrAttached** — Check for debugger
  - `isDebuggerPresentOrAttached`
  - Checks whether a debugger is present (native) or attached (managed).
  - **Returns**: Boolean.

- **isRestrictedInterpreter** — Check interpreter restrictions
  - `isRestrictedInterpreter ?flags?`
  - Checks restriction aspects based on `RestrictionFlags`: `Any`, `Safe`, `HideUnsafe`, `Sdk`, `Security`.
  - **Returns**: Boolean (OR of checked aspects).

- **listComponents** — List all configuration commands
  - `listComponents`
  - Lists all available transient commands and define constants.
  - **Returns**: List of component names.

- **listContextVariables** — List context variable names
  - `listContextVariables`
  - **Returns**: List of variable names.

- **matchPlatform** — Match platform name
  - `matchPlatform patterns`
  - Matches the current platform against *patterns* (a list of `{matchMode pattern}`). Supports Exact, Glob, and RegExp modes.
  - **Returns**: Boolean.

- **peekOnFlags** — Inspect certificate flags
  - `peekOnFlags fileName flagType ?hasFlags?`
  - Reads a certificate from *fileName* and inspects its flags. If *hasFlags* is given, checks for those flags; otherwise returns the flags.
  - **Returns**: Boolean (with *hasFlags*) or flags string (without).

- **queryStatus** — Query detailed status information
  - `queryStatus name`
  - Queries a wide range of status values by `QueryStatusFlags` name. Supports 50+ status queries including:
    - `ConfigurationPhase`, `PublicKeyToken`, `ChangeCount`
    - `ScriptType`, `ScriptSubType`, `ScriptDirectory`, `ScriptFileName`
    - `PluginType`, `ContextName`, `VariantName`, `Isolated`
    - `Machine`, `KeyPair`, `KeyPairs`, `ForceNetworkLicense`
    - `StorageType`, `SdkMode`, `DemoMode`, `TestMode`, `FailSafeMode`, `OfflineMode`
    - `Levels`, `TrustedLevels`, `IsAdministrator`, `IsInteractive`
    - `Runtime`, `OperatingSystem`, `Version`, `TimeStamp`
    - `Duration`, `VersionRange`, `Timeout`, and many more.
  - **Returns**: String representation of the queried status value.

---

<a id="config-time-version"></a>
### Time and Version Validation

- **notAfter** — Validate expiration time
  - `notAfter dateTime ?flags?`
  - Validates that the current UTC time is before *dateTime*. If expired, applies a multi-stage grace/fallback system controlled by `NotCommandFlags`:
    - `DebuggerOnly` — only enforce with debugger attached
    - `WarnOnly` — treat as warning
    - `Grace1`/`Grace2`/`Grace3` — successive grace periods
    - `Web` — open "out of time" URI
    - `Remote` — verify via NTP/HTTPS time servers (requires `NETWORK`)
    - `FailFast` — fail immediately
    - `FailSafe` — always succeed
  - **Returns**: Ok if valid; error with "not valid after ..." if expired.

- **notBefore** — Validate start time
  - `notBefore dateTime ?flags?`
  - Validates that the current UTC time is after *dateTime*. Same grace/fallback system as `notAfter`.
  - **Returns**: Ok if valid; error with "not valid before ..." if too early.

---

<a id="config-iteration"></a>
### Iteration

- **forEachFile** — Iterate over files
  - `forEachFile pattern ?directory? ?script? ?varName?`
  - Iterates over files matching *pattern* in *directory* (defaults to configuration file directory). Sets *varName* to each file path and evaluates *script*.
  - **Returns**: Result of the iteration.

- **forEachPolicyType** — Iterate over policy types
  - `forEachPolicyType varName script`
  - Iterates over all `PolicyType` values, setting *varName* to each and evaluating *script*.
  - **Requires**: `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`
  - **Returns**: Ok on success; accumulated errors on failure.

- **maybeIterateUsingExpression** — Expression-based loop
  - `maybeIterateUsingExpression ?list? body`
  - Implements a for-loop construct. The optional *list* contains sub-expressions:
    - 0 elements: infinite loop
    - 1 element: `test` only
    - 2 elements: `test next`
    - 3 elements: `start test next`
    - 4 elements: `start test next final`
  - Handles `Break` and `Continue`. Enforces iteration limit.
  - **Returns**: Result of the last script evaluation.

---

<a id="config-output"></a>
### Output and Diagnostics

- **writeStatus** — Write detailed status report
  - `writeStatus ?flags? ?tag?`
  - Produces a formatted status report based on `StatusFlags`. Sections include:
    - `TimeServers` — configured time servers
    - `ShellFlags` — shell configuration
    - `ExtraFeatures` — extra feature flags
    - `Policy` — per-policy-type key names, execution flags, path/network flags, key ring contents
    - `DumpState` — all context variables
  - **Returns**: Formatted status string.

- **writeWithoutFail** — Write concatenated output
  - `writeWithoutFail arg ?arg ...?`
  - Concatenates all arguments into a single output string with separators and writes it.
  - **Returns**: The concatenated output string.

---

<a id="config-ensembles"></a>
### Ensemble Sub-Commands

#### `keyUsage` — Key usage management

An ensemble command with 8 sub-commands for managing certificate key usage restrictions on entity types.

- `keyUsage change entityType ?flags? ?all? ?root?`
  - Resolves current key usage, applies flag change, and merges.
  - **Returns**: Merged key usage string.

- `keyUsage clear ?entityType?`
  - With *entityType*: removes its key usage entry. Without: clears all key usages.
  - **Returns**: Count or empty.

- `keyUsage default entityType`
  - Returns the default key usage triplet for the entity type.

- `keyUsage forbid entityType`
  - Forbids key usage for the entity type.

- `keyUsage get entityType`
  - Retrieves the current key usage triplet.

- `keyUsage list`
  - Lists all configured key usages.

- `keyUsage modify entityType ?flags? ?all? ?root?`
  - Similar to `change` but verifies flags before merging.

- `keyUsage resolve entityType`
  - Resolves the effective key usage triplet.

#### `snippet` — Snippet management

An ensemble command with 4 sub-commands for managing code snippets.

- `snippet add text ?snippetFlags? ?lookupFlags? ?name?`
  - Adds a snippet with the given *text*. Auto-generates *name* if not provided.
  - **Returns**: The snippet name.

- `snippet clear ?snippetFlags? ?lookupFlags?`
  - Clears all snippets matching the given flags.
  - **Returns**: Count of cleared snippets.

- `snippet dump name ?snippetFlags? ?lookupFlags?`
  - Retrieves and dumps a snippet's full details.
  - **Returns**: Key-value pair list of snippet properties.

- `snippet evaluate name ?snippetFlags? ?lookupFlags?`
  - Evaluates a named snippet.
  - **Returns**: The evaluation result.

#### `storageType` — Storage type management

- `storageType ?type?`
  - Gets or sets the storage type. If *type* is provided, parses it as a `StorageType` enum and sets the context variable; otherwise returns the current storage type.
  - **Returns**: Current or new storage type.

---

<a id="config-network"></a>
### Network and Licensing

- **downloadAndInstall** — Download and install a package
  - `downloadAndInstall uri ?flags? ?targetDirectory? ?plugin?`
  - Downloads a package from *uri*, extracts it, and installs it. Refuses if offline mode is active.
  - **Requires**: `XML && NETWORK && WEB`
  - **Returns**: Empty on success; error on failure.

- **extractZipFile** — Extract a ZIP file
  - `extractZipFile fileName directory`
  - Extracts a ZIP file to the specified directory.
  - **Requires**: `XML && NETWORK && WEB`
  - **Returns**: Ok on success.

- **makeUriRequest** — Make HTTP request
  - `makeUriRequest uri ?data? ?method? ?raw? ?fileName?`
  - Makes an HTTP request. If *fileName* is provided, downloads content and verifies its signature.
  - **Requires**: `XML && NETWORK && WEB`
  - **Returns**: Response text, or list of `{hexHash filePath signatureText}` with *fileName*.

- **removeLicense** — Remove a license certificate
  - `removeLicense id`
  - Removes a license identified by GUID.
  - **Requires**: `XML && NETWORK && WEB`
  - **Returns**: Empty on success.

- **requestLicense** — Request a license from server
  - `requestLicense id ?baseUri? ?assemblyName?`
  - Requests a license from a remote server for the given GUID.
  - **Requires**: `XML && NETWORK && WEB`
  - **Returns**: Filename of the downloaded license.

- **joinUriParts** — Join URI components
  - `joinUriParts baseUri relativeUri ?varName?`
  - Joins a base URI with a relative URI, optionally incorporating query parameters from *varName*.
  - **Requires**: `WEB`
  - **Returns**: The combined URI string.

- **joinSubPaths** — Join file path components
  - `joinSubPaths name ?name ...?`
  - Combines one or more path segments, optionally prepending a base path from the configuration context.
  - **Returns**: The combined path string.

---

<a id="config-sandbox"></a>
### Sandbox Testing

These commands are only available when compiled with `#if TEST`.

- **evaluateInSandbox** — Start async sandbox evaluation
  - `evaluateInSandbox fileName ?varName?`
  - Starts asynchronous script evaluation in a child interpreter sandbox. Queues the work item on the thread pool.
  - **Returns**: The sandbox ID (long integer).

- **waitForSandbox** — Wait for sandbox completion
  - `waitForSandbox id ?timeout?`
  - Waits for a sandbox evaluation to complete. Default timeout is defined by `Constants.EvaluateInSandboxTimeout`.
  - **Returns**: Boolean indicating whether the wait succeeded (completed within timeout).

- **cleanupForSandbox** — Clean up sandbox resources
  - `cleanupForSandbox id`
  - Cleans up resources for a completed sandbox. Verifies the sandbox is complete, removes it, and unsets related variables.
  - **Returns**: Empty on success; error if sandbox is still active.

---

## Installation Subsystem

This section documents the `Installation` helper class used by the `downloadAndInstall` command and related package installation functionality.

### Licensing.Components.Private.Commands.Helpers+Installation Class

#### Overview

The `Installation` class is a private sealed helper class within the `Helpers` class in the Harpy plugin's `Commands.cs` file. It implements `IDisposable` and manages a transactional, multi-phase installation process for securely installing signed packages from a source directory to a target directory.

**Location**: `Eagle/Plugins/Commercial/Enterprise/Harpy/Components/Private/Commands.cs` (line 5765)

**Compilation Requirements**: `#if XML && NETWORK && WEB`

**Object ID**: `10d306c5-2d7b-4b14-9871-f6b11c4a93e0`

#### Purpose

The `Installation` class provides a robust, transactional file installation mechanism with:
- Digital signature verification for all installed files
- Atomic backup and rollback capabilities
- Manifest script hooks for custom pre/post-install logic
- Support for "what-if" mode (dry-run)

#### Constructor

```csharp
public Installation(
    Interpreter interpreter,     // Eagle interpreter instance
    IClientData clientData,      // Context client data (must be EvaluateClientData)
    string sourceDirectory,      // Directory containing files to install
    string targetDirectory,      // Destination directory for installation
    int? timeout,               // Optional timeout for signature verification
    InstallFlags installFlags   // Installation behavior flags
)
```

### Installation Phases (Passes)

The installation proceeds through 7 sequential passes (Pass0-Pass6). Each pass performs specific operations and maintains state for subsequent passes.

#### Pass 0: PRE-INSTALL

**Method**: `PerformPass0(ReturnCode returnCode, ref Result error)`

**Purpose**: Initialization and manifest pre-evaluation

**Operations**:
1. Casts `clientData` to `EvaluateClientData` and stores as `evaluateClientData`
2. Verifies source and target directories exist
3. Evaluates manifest scripts (`manifest.eagle` files) with `installPass = Pass0`
4. Populates `sourceFileNames` with all files from source directory (recursive)
5. Sorts source file names

**State Produced**:
- `evaluateClientData` — Context for script evaluation
- `manifestFileNames` — List of found manifest script files
- `sourceFileNames` — Sorted list of all source files

---

#### Pass 1: VERIFY

**Method**: `PerformPass1(ReturnCode returnCode, ref Result error)`

**Purpose**: Validate signatures and check for conflicts

**Operations**:
1. Evaluates manifest scripts with `installPass = Pass1`
2. For each source file:
   - Computes relative file name (relative to source directory)
   - Checks if target file already exists (populates `existingFileNames` if `AllowOverwrite` is set)
   - Skips signature verification for `.b64sig` signature files themselves (but validates their base files exist)
   - Verifies file signatures via:
     - `MaybeCheckTrustedFiles` — If `AllowTrustedFiles` flag is set
     - `MaybeVerifySignature` — Authenticode/X.509 signature verification (if `CERTIFICATE_PLUGIN && CERTIFICATE_POLICY`)
     - `MaybeVerifyBase64Signature` — Base64-encoded signature files (`.b64sig`)
   - **Fails if no valid signature is found for any file**

**State Produced**:
- `relativeFileNames` — List of relative paths for all files to install
- `existingFileNames` — List of existing target files that will be overwritten

**Error Conditions**:
- Signature file references non-existent base file
- No valid signature found for a file
- Target file exists and `AllowOverwrite` not set

---

#### Pass 2: BACKUP

**Method**: `PerformPass2(ReturnCode returnCode, ref Result error)`

**Purpose**: Create backups of existing files before overwriting

**Operations**:
1. Evaluates manifest scripts with `installPass = Pass2`
2. If `SkipBackup` flag is set, skips backup phase
3. Requires `evaluateClientData.Id` to be a valid GUID (used in backup file naming)
4. For each file in `existingFileNames`:
   - Creates a backup file named `backup-{GUID}-{originalFileName}`
   - Moves original file to backup location (atomic rename)

**State Produced**:
- `backupFileNames` — List of backup file paths created

**Backup File Naming Convention**:
```
backup-{ContextGUID}-{OriginalFileName}
```

---

#### Pass 3: COMMIT

**Method**: `PerformPass3(ReturnCode returnCode, ref Result error)`

**Purpose**: Copy source files to target directory

**Operations**:
1. Evaluates manifest scripts with `installPass = Pass3`
2. For each source file:
   - Creates target directory structure if needed
   - Copies source file to target location
   - If copy fails and files have already been copied, sets `rollback = true`

**State Produced**:
- `targetFileNames` — List of newly created target file paths
- `rollback` — Set to `true` if commit fails after partial completion

**Error Recovery**:
- If any file copy fails after at least one successful copy, the `rollback` flag is set, triggering rollback in Pass 4

---

#### Pass 4: ROLLBACK

**Method**: `PerformPass4(ReturnCode returnCode, ref Result error)`

**Purpose**: Undo installation if commit failed

**Operations** (only if `rollback == true`):
1. Evaluates manifest scripts with `installPass = Pass4`
2. Gets list of target directories from `targetFileNames`
3. Sorts directories in reverse order (to delete nested directories first)
4. Deletes all files in `targetFileNames`
5. Deletes empty target directories
6. Restores backup files to their original names by moving `backup-{GUID}-{name}` back to `{name}`
7. Clears `targetFileNames` and `backupFileNames` lists

**State Produced**:
- `rollbackFileNames` — List of restored original file paths

**Error Handling**:
- If `StopRollbackOnError` flag is set, rollback halts on first error
- Otherwise, errors are logged but rollback continues

---

#### Pass 5: CLEANUP

**Method**: `PerformPass5(ReturnCode returnCode, ref Result error)`

**Purpose**: Clean up backup files after successful installation

**Operations** (only if `rollback == false`):
1. Evaluates manifest scripts with `installPass = Pass5`
2. If `KeepBackupFiles` flag is set, skips cleanup
3. Deletes all backup files in `backupFileNames`
4. Clears `backupFileNames` list

**Note**: Errors during cleanup are logged but don't fail the installation

---

#### Pass 6: POST-INSTALL

**Method**: `PerformPass6(ReturnCode returnCode, ref Result error)`

**Purpose**: Final manifest script evaluation

**Operations**:
1. Evaluates manifest scripts with `installPass = Pass6`

**Use Case**: Custom post-installation logic in manifest scripts (e.g., configuration updates, cache invalidation)

---

### Manifest Script Interface

Manifest scripts (`manifest.eagle`) are Eagle scripts evaluated during each installation pass. They receive the following variables:

| Variable | Type | Description |
|----------|------|-------------|
| `installPass` | String | Current pass name (`Pass0`-`Pass6`) |
| `sourceDirectory` | String | Source directory path |
| `targetDirectory` | String | Target directory path |
| `relativeFileNames` | List/String | Files to be installed (null in Pass0) |
| `rollback` | Boolean | Whether rollback is active (can be set by script to force rollback) |
| `returnCode` | ReturnCode | Current return code (includes `WhatIf` prefix in what-if mode) |
| `error` | Result | Current error message (if any) |

**Rollback Control**: A manifest script can set the `rollback` variable to `true` to force a rollback during Pass 4.

---

### InstallFlags Enumeration

| Flag | Value | Description |
|------|-------|-------------|
| `None` | 0x0 | No special handling |
| `WhatIf` | 0x2 | Dry-run mode — no file system changes |
| `ForceUniqueId` | 0x100 | Require unique identifier for backup naming |
| `NoEvaluateManifests` | 0x200 | Skip manifest script evaluation |
| `AllowTrustedFiles` | 0x400 | Accept interpreter-trusted files without signature |
| `AllowOverwrite` | 0x800 | Allow overwriting existing files |
| `SkipBackup` | 0x1000 | Don't backup existing files |
| `StopRollbackOnError` | 0x2000 | Halt rollback on first error |
| `KeepBackupFiles` | 0x4000 | Don't delete backups after success |
| `VerboseResult` | 0x8000 | Include extra diagnostic info in results |
| `Default` | (combined) | `ForceUniqueId \| AllowTrustedFiles \| AllowOverwrite \| KeepBackupFiles` |

---

### InstallPass Enumeration

| Pass | Value | Description |
|------|-------|-------------|
| `None` | 0x0 | No special handling |
| `Invalid` | 0x1 | Invalid, do not use |
| `Reserved` | 0x2 | Reserved, do not use |
| `Pass0` | 0x100 | Pre-evaluate manifest files, gather source file names |
| `Pass1` | 0x200 | Verify overwrite, signatures, gather backup file names |
| `Pass2` | 0x400 | Perform backup of existing files |
| `Pass3` | 0x800 | Commit all source files to target directory |
| `Pass4` | 0x1000 | Rollback all source files within target directory |
| `Pass5` | 0x2000 | Maybe cleanup (delete) the backup files |
| `Pass6` | 0x4000 | Post-evaluate manifest files |

---

### Result Structure

The `BuildResult` method returns a dictionary-style list:

| Key | Condition | Description |
|-----|-----------|-------------|
| `returnCode` | Always | Final return code |
| `errors` | If errors exist | Error messages |
| `elapsed` | Always | Total elapsed time |
| `rollback` | Always | Whether rollback occurred |
| `targetDirectory` | If set | Target directory path |
| `manifestFileNames` | VerboseResult | Found manifest files |
| `sourceFileNames` | VerboseResult | Source files processed |
| `relativeFileNames` | If set | Relative file paths |
| `existingFileNames` | If set | Files that were overwritten |
| `backupFileNames` | If set | Backup file paths |
| `targetFileNames` | VerboseResult | Created target files |
| `rollbackFileNames` | If set | Restored files after rollback |

---

### Test Coverage

Tests are in `Eagle/Plugins/Commercial/Enterprise/Harpy/Tests/basic.eagle`:

- **harpy-61.1**: Tests successful installation with overwrite of existing files
- **harpy-61.2**: Tests rollback by setting `Rollback` environment variable

Example test invocation:
```tcl
ksource -withuniqueid -withcommands -useshared \
    -useplugin -usecontext -- $installPackageFile
```

Where `installPackageFile` contains:
```tcl
failOnError true
requireVersion 0.0.0.0
downloadAndInstall https://urn.to/r/harpy_test_package
```

---

### State Diagram

```
Pass0 (PRE-INSTALL)
    │
    ├── Evaluate manifest scripts
    ├── Populate source file list
    │
    ▼
Pass1 (VERIFY)
    │
    ├── Evaluate manifest scripts
    ├── Verify signatures for all files
    ├── Check for overwrite conflicts
    │
    ▼
Pass2 (BACKUP)
    │
    ├── Evaluate manifest scripts
    ├── Backup existing files (if not SkipBackup)
    │
    ▼
Pass3 (COMMIT)
    │
    ├── Evaluate manifest scripts
    ├── Copy files to target ──▶ On failure: set rollback=true
    │
    ▼
Pass4 (ROLLBACK)  ◀── Only executes if rollback=true
    │
    ├── Evaluate manifest scripts
    ├── Delete committed files
    ├── Restore backups
    │
    ▼
Pass5 (CLEANUP)   ◀── Only executes if rollback=false
    │
    ├── Evaluate manifest scripts
    ├── Delete backup files (if not KeepBackupFiles)
    │
    ▼
Pass6 (POST-INSTALL)
    │
    └── Evaluate manifest scripts
```

---

### Thread Safety

All public methods and most private methods are synchronized using `lock (syncRoot)` to ensure thread-safe transactional behavior.

---

## Enum Reference

This appendix documents the key enum types accepted as arguments by Harpy commands. Enum values can typically be specified by name, by numeric value, or by combining flags with commas. Many accept `+`/`-` prefixes for additive/subtractive flag modification.

### PolicyType

Controls which policy context an operation applies to.

| Value | Hex | Description |
|-------|-----|-------------|
| `None` | 0x0 | No policy type |
| `Script` | 0x1000 | Inline script evaluation |
| `File` | 0x2000 | File-based evaluation |
| `Stream` | 0x4000 | Stream-based evaluation |
| `License` | 0x8000 | License operations |
| `KeyPair` | 0x10000 | Key pair operations |
| `Trace` | 0x20000 | Diagnostic tracing |
| `Other` | 0x40000 | All other operations |

---

### ExecutionPolicy

Controls script execution behavior. Flags can be combined.

| Value | Hex | Description |
|-------|-----|-------------|
| `None` | 0x0 | Skip policy check (allow all) |
| `AllowNone` | 0x8 | No files allowed |
| `AllowSignedOnly` | 0x10 | Only signed files allowed |
| `AllowAny` | 0x20 | All files allowed |
| `TrustSignedOnly` | 0x100000 | Signed files get full permissions |
| `CheckExpiry` | 0x800 | Enforce certificate expiration |
| `CheckPublicKeyToken` | 0x8000 | Ensure public key tokens match |
| `AllowAssemblyPublicKey` | 0x10000 | Assembly keys may be used |
| `AllowEmbeddedPublicKey` | 0x20000 | Embedded resource keys may be used |
| `AllowRingPublicKey` | 0x40000 | Key ring keys may be used |
| `AllowAnyPublicKey` | 0x80000 | Any public key may be used |
| `EnforceKeyGroup` | 0x100000000 | Key only used with associated assemblies |
| `EnforceKeyUsage` | 0x200000000 | Key only used per declared usage |
| `CheckRevocation` | 0x40000000000 | Enforce revocation checking |
| `EnableTracing` | 0x200000000000 | Enable diagnostic tracing |
| `DisableCreation` | 0x8000000000000000 | Forbid further interpreter creation |

See the source code for the complete set of 60+ flags.

---

### ShellFlags

Controls `keval` and `certificate evaluate` behavior.

| Value | Hex | Description |
|-------|-----|-------------|
| `None` | 0x0 | No special flags |
| `InstallCallbacks` | 0x100 | Install shell callbacks |
| `UninstallCallbacks` | 0x200 | Uninstall shell callbacks |
| `ResetCallbacks` | 0x400 | Reset shell callbacks |
| `NoPoliciesOnFallback` | 0x1000 | Skip policies on fallback |
| `FallbackOnUnsafe` | 0x10000 | Fallback when not "safe" |
| `FallbackOnNoPolicy` | 0x20000 | Fallback when no policy |
| `FallbackOnNeutral` | 0x40000 | Fallback when policy neutral |
| `FallbackOnDenied` | 0x80000 | Fallback when policy denies |
| `FallbackOnFailure` | 0x100000 | Fallback when policy errors |

**Composites**: `FallbackMask` = all Fallback flags; `Default` = `FallbackOnNoPolicy, FallbackOnNeutral`

---

### TrustFlags

Controls trust behavior during script evaluation.

| Value | Hex | Description |
|-------|-----|-------------|
| `None` | 0x0 | Default handling |
| `Shared` | 0x2 | Allow other threads (dangerous) |
| `WithEvents` | 0x4 | Allow async events (dangerous) |
| `MarkTrusted` | 0x8 | Temporarily mark as trusted |
| `AllowUnsafe` | 0x10 | Permit unsafe command access |
| `PushScriptLocation` | 0x100 | Push/pop script file location |
| `WithScopeFrame` | 0x200 | Create a new scope frame |

**Composites**: `MaybeMarkTrusted` = `MarkTrusted, AllowUnsafe`; `SecurityPackage` = `MaybeMarkTrusted, ViaCoreLibrary, UseSecurityLevels`

---

### CertificateHashFlags

Controls which certificate properties are included when computing a hash.

| Value | Hex | Description |
|-------|-----|-------------|
| `Protocol` | 0x2 | Protocol property |
| `Vendor` | 0x8 | Vendor property |
| `Id` | 0x100 | Certificate ID |
| `TimeStamp` | 0x200 | Timestamp |
| `Duration` | 0x400 | Duration |
| `Key` | 0x800 | Public key |
| `Keys` | 0x1000 | All keys |
| `HashAlgorithm` | 0x8000 | Hash algorithm |
| `EntityType` | 0x20000 | Entity type |
| `EntityName` | 0x40000 | Entity name |
| `Product` | 0x400000 | Product name |
| `Features` | 0x1000000 | Feature flags |
| `Restrictions` | 0x2000000 | Restriction flags |

**Composites**: `Basic` = `Id, TimeStamp, Duration, Key, Keys`; `Full` = all meaningful properties; `Certificate` = `Full`; `String` / `File` / `Stream` = `Basic`

---

### FlagType

Selects which property to use for flag operations.

| Value | Hex | Description |
|-------|-----|-------------|
| `Feature` | 0x2 | Features property |
| `Restriction` | 0x4 | Restrictions property |
| `KeyUsage` | 0x8 | KeyUsage property |
| `Default` | 0x10 | Default (Features) |

---

### StorageType

Selects persistent storage backend.

| Value | Hex | Description |
|-------|-----|-------------|
| `Registry` | 0x2 | Windows registry |
| `Interpreter` | 0x4 | Interpreter-based storage |

---

### KeyPairType

Specifies cryptographic key pair algorithm.

| Value | Hex | Description |
|-------|-----|-------------|
| `RSA` | 0x100 | RSA algorithm |
| `DSA` | 0x200 | DSA algorithm |
| `Legacy` | `RSA, ForLegacy` | RSA legacy format (default for `keypair generate`) |

---

### KeyFileFormat

Specifies key file format.

| Value | Hex | Description |
|-------|-----|-------------|
| `StrongName` | 0x10 | SNK file format |
| `CryptoAPI` | 0x20 | Raw CryptoAPI blob |
| `PrivateKey` | 0x40 | PVK file format |
| `RsaStrongName` | `StrongName, ForRsa` | RSA SNK |
| `DsaStrongName` | `StrongName, ForDsa` | DSA SNK |
| `RsaPrivateKey` | `PrivateKey, ForRsa` | RSA PVK |
| `DsaPrivateKey` | `PrivateKey, ForDsa` | DSA PVK |

---

### NetworkFlags

Controls network behavior for remote operations.

| Value | Hex | Description |
|-------|-----|-------------|
| `Force` | 0x2000 | Force remote check |
| `Strict` | 0x4000 | Fail if remote check fails |
| `NoCache` | 0x100000 | Disable caches |
| `ViaHttp` | 0x200000 | Use HTTPS |
| `FailSafe` | 0x400000 | Abort process on failure |
| `WhatIf` | 0x800000 | Dry run |
| `Asynchronous` | 0x1000000 | Separate thread |

---

### PathFlags

Controls file path resolution behavior.

| Value | Hex | Description |
|-------|-----|-------------|
| `NoShared` | 0x2 | Skip shared path override |
| `Root` | 0x4 | Use root "lib" path |
| `NoBinary` | 0x8 | Disable binary path fallback |
| `Verbatim` | 0x20 | Skip path modification |
| `PerUser` | 0x8000 | Include per-user info |
| `PerProcess` | 0x10000 | Include process info |
| `NoRegistry` | 0x40000 | Avoid Windows registry |

---

### ResetFlags

Controls which components are reset by `certificate reset`.

| Value | Hex | Description |
|-------|-----|-------------|
| `GlobalKeyRingState` | 0x200 | Key ring state |
| `GlobalFileCache` | 0x1000 | File cache |
| `GlobalLicenseCache` | 0x4000 | License cache |
| `GlobalPolicyData` | 0x20000 | Policy data |
| `GlobalConfiguration` | 0x100000 | Configuration |
| `GlobalDurationData` | 0x100000000 | Duration data |

**Composites**: `KeyPairsMask`, `LicenseMask`, `PolicyMask`, `ConfigurationMask`, `AllMask`, `DefaultMask`

---

### PolicyTraceFlags

Controls diagnostic tracing configuration.

| Value | Hex | Description |
|-------|-----|-------------|
| `Enable` | 0x2 | Enable tracing |
| `AutoFile` | 0x4 | Auto-generate log file |
| `Append` | 0x8 | Append to log |
| `Shared` | 0x10 | Shared log file |
| `Full` | 0x20 | Full verbatim output |
| `Reset` | 0x40 | Reset tracing first |
| `Interpreter` | 0x400 | Per-interpreter tracing |
| `Global` | 0x800 | Global tracing |

**Composites**: `Default` = `Priorities, Limits`; `Standard` = most flags; `Verbose` = all non-dangerous flags

---

### ConfigurationFileFlags

Controls configuration file operations.

| Value | Hex | Description |
|-------|-----|-------------|
| `Global` | 0x100 | Global configuration |
| `PluginOnly` | 0x200 | Plugin-only configuration |
| `WithOkResults` | 0x400 | Include success results |
| `WithErrorResults` | 0x800 | Include error results |
| `Reset` | 0x1000 | Reset before applying |

---

### SupportDiagnostic

Controls diagnostic queries and settings for the `support diagnostic` sub-command.

| Value | Hex | Description |
|-------|-----|-------------|
| `GetExtraDiagnostics` | 0x100 | Query extra diagnostics |
| `GetForceTrace` | 0x1000 | Query force trace |
| `GetUri` | 0x10000 | Query support URI |
| `GetNormalizeErrors` | 0x100000 | Query error normalization |
| `EnableNormalizeErrors` | 0x200000 | Enable error normalization |
| `DisableNormalizeErrors` | 0x400000 | Disable error normalization |
| `GetIncludePublicKeyToken` | 0x1000000 | Query token inclusion |
| `EnableIncludePublicKeyToken` | 0x2000000 | Enable token inclusion |
| `DisableIncludePublicKeyToken` | 0x4000000 | Disable token inclusion |
| `GetTracing` | 0x10000000 | Query trace state |
| `EnableTracing` | 0x20000000 | Enable tracing |
| `DisableTracing` | 0x40000000 | Disable tracing |
| `GetLogFileNames` | 0x100000000 | Query log file names |

---

### AssemblyKeyType

Specifies which assembly key to retrieve.

| Value | Hex | Description |
|-------|-----|-------------|
| `Signature` | 0x1000 | Assembly RSA signing key |
| `Assembly` | 0x2000 | Embedded assembly key |
| `License` | 0x4000 | Embedded licensing key |
| `Time` | 0x8000 | Embedded time server key |
| `Auxiliary` | 0x10000 | Embedded auxiliary key |

---

### FlagRuleType

Controls flag rule matching in `flags check`.

| Value | Hex | Description |
|-------|-----|-------------|
| `Allow` | 0x2 | Rule must match |
| `Deny` | 0x4 | Rule must not match |
| `AllowDeny` | 0x2000 | Process allow rules first |
| `DenyAllow` | 0x4000 | Process deny rules first |
| `MatchAllKey` | 0x100000 | All keys must match |
| `MatchAnyKey` | 0x200000 | Any key may match |
| `MatchAllRule` | 0x1000000 | All rules must match |
| `MatchAnyRule` | 0x2000000 | Any rule may match |

**Default**: `AllowDeny, MatchAnyKey, MatchAnyRule`

---

### UriType

Identifies URI endpoints used by the Harpy plugin.

| Value | Description |
|-------|-------------|
| `PingBase` / `PingRelative` | Connectivity check |
| `NtpBase` / `NtpRelative` | NTP time server |
| `HttpTimeBase` / `HttpTimeRelative` | HTTPS time server |
| `SecretBase` / `SecretRelative` | Secret management server |
| `AuthorityBase` / `AuthorityRelative` | Certificate authority |
| `RenewalBase` / `RenewalRelative` | Certificate renewal |
| `RevocationBase` / `RevocationRelative` | Revocation checking |
| `SupportBase` / `SupportRelative` | Support server |
| `ScriptBase` / `ScriptRelative` | Script server |
| `StorageBase` / `StorageRelative` | Storage server |
| `RequestBase` / `RequestRelative` | Request server |
| `ProvisionBase` / `ProvisionRelative` | Provisioning server |
| `TestBase` / `TestRelative` | Test server |
| `LicenseBase` / `LicenseRelative` | License server |
| `LibraryBase` / `LibraryRelative` | Library server |

**Flags**: `UseCertificate`, `UseLibrary`, `UseVariable`
