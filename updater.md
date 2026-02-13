# Eagle Updater (Hippogriff) -- Architecture and Design Analysis

This document provides a detailed analysis of the Eagle Updater, code-named
**Hippogriff**. It covers the project structure, architecture, update workflow,
security model, configuration system, UI design, and platform support. This
document is intended for developers and AI agents working with the Hippogriff
codebase.

Copyright (c) 2007-2012 by Joe Mistachkin. All rights reserved.

Source directory: `Eagle/Update/`

---

## Table of Contents

1.  [Overview](#1-overview)
2.  [Project Structure](#2-project-structure)
    - 2.1 [Source File Inventory](#21-source-file-inventory)
    - 2.2 [Shared Source Files](#22-shared-source-files)
    - 2.3 [Build Configuration](#23-build-configuration)
    - 2.4 [Visual Studio Project Variants](#24-visual-studio-project-variants)
3.  [Architecture](#3-architecture)
    - 3.1 [Component Overview](#31-component-overview)
    - 3.2 [Class Hierarchy](#32-class-hierarchy)
    - 3.3 [Namespace Organization](#33-namespace-organization)
    - 3.4 [Comparers and Equality](#34-comparers-and-equality)
4.  [Update Workflow](#4-update-workflow)
    - 4.1 [Startup and Initialization](#41-startup-and-initialization)
    - 4.2 [Release Manifest Download](#42-release-manifest-download)
    - 4.3 [Release Manifest Parsing](#43-release-manifest-parsing)
    - 4.4 [Release Selection and Validation](#44-release-selection-and-validation)
    - 4.5 [File Download](#45-file-download)
    - 4.6 [Extraction and Verification](#46-extraction-and-verification)
    - 4.7 [Three-Phase File Installation](#47-three-phase-file-installation)
    - 4.8 [Self-Update Mechanism](#48-self-update-mechanism)
    - 4.9 [Post-Update Actions](#49-post-update-actions)
    - 4.10 [Shutdown and Cleanup](#410-shutdown-and-cleanup)
5.  [Security Model](#5-security-model)
    - 5.1 [Multi-Layer Verification](#51-multi-layer-verification)
    - 5.2 [Authenticode Signature Verification](#52-authenticode-signature-verification)
    - 5.3 [Strong Name Signature Verification](#53-strong-name-signature-verification)
    - 5.4 [Hash Verification](#54-hash-verification)
    - 5.5 [TLS Certificate Pinning](#55-tls-certificate-pinning)
    - 5.6 [Application Manifest](#56-application-manifest)
    - 5.7 [Self-Integrity Check](#57-self-integrity-check)
6.  [Configuration System](#6-configuration-system)
    - 6.1 [Configuration Loading Order](#61-configuration-loading-order)
    - 6.2 [Command-Line Options](#62-command-line-options)
    - 6.3 [Arguments File](#63-arguments-file)
    - 6.4 [Default Values](#64-default-values)
    - 6.5 [Release Type Detection](#65-release-type-detection)
7.  [Release Manifest Format](#7-release-manifest-format)
    - 7.1 [Protocol Types](#71-protocol-types)
    - 7.2 [Field Layout](#72-field-layout)
    - 7.3 [Release Matching](#73-release-matching)
8.  [User Interface](#8-user-interface)
    - 8.1 [Form Layout](#81-form-layout)
    - 8.2 [Keyboard Shortcuts](#82-keyboard-shortcuts)
    - 8.3 [Silent and Invisible Modes](#83-silent-and-invisible-modes)
    - 8.4 [Progress Reporting](#84-progress-reporting)
    - 8.5 [Thread-Safe Status Updates](#85-thread-safe-status-updates)
9.  [Platform Support](#9-platform-support)
    - 9.1 [.NET Framework Versions](#91-net-framework-versions)
    - 9.2 [Windows Version Support](#92-windows-version-support)
    - 9.3 [Mono Compatibility](#93-mono-compatibility)
    - 9.4 [Conditional Compilation](#94-conditional-compilation)
10. [File Operations](#10-file-operations)
    - 10.1 [In-Use File Handling](#101-in-use-file-handling)
    - 10.2 [Backup and Restore](#102-backup-and-restore)
    - 10.3 [Hash-Verified Copy](#103-hash-verified-copy)
    - 10.4 [File List Synchronization](#104-file-list-synchronization)
11. [Diagnostics and Logging](#11-diagnostics-and-logging)
    - 11.1 [Trace System](#111-trace-system)
    - 11.2 [Console Allocation](#112-console-allocation)
12. [Embedded Eagle Shell](#12-embedded-eagle-shell)

---

## 1. Overview

Hippogriff is a standalone Windows Forms application that automatically
downloads and installs newer versions of the Eagle runtime. It is shipped
alongside Eagle as `Hippogriff.exe` and operates independently of the Eagle
interpreter -- it has no compile-time dependency on the Eagle core library
assembly (`Eagle.dll`).

Key characteristics:

- **Self-contained**: No dependency on `Eagle.dll` at compile time. Shares only
  lightweight attribute and utility source files with the Eagle library via
  MSBuild linked items.
- **Self-updating**: Can update itself (the updater binary) in addition to the
  Eagle runtime.
- **Multi-layer security**: Authenticode signatures, strong name verification,
  triple hash verification (MD5 + SHA1 + SHA512), and TLS certificate pinning.
- **Three-phase installation**: Backup existing files, copy new files with hash
  verification, delete backups only on success.
- **Silent operation**: Can run headless for automated deployment scenarios.
- **Administrator required**: The application manifest requests
  `requireAdministrator` elevation.
- **Mutex-based instance detection**: Prevents running while Eagle is active
  via a named mutex (`Global\Eagle_Setup`).

Assembly metadata:

- **Title**: Eagle Updater (Hippogriff)
- **Root namespace**: `Hippogriff`
- **Assembly name**: `Hippogriff`
- **Output**: `Hippogriff.exe` (Windows Forms executable)
- **GUID**: `ded5194a-e56b-4caa-9a81-dca91373f96e`
- **Default update server**: `https://update.eagle.to/`

---

## 2. Project Structure

### 2.1 Source File Inventory

The project lives in `Eagle/Update/` and contains 47 files:

| Directory | Files | Purpose |
|-----------|-------|---------|
| `Comparers/` | 4 | Custom equality/comparison logic |
| `Components/Private/` | 24 | Core application logic |
| `Forms/` | 3 | Windows Forms UI (code + designer + resources) |
| `Interfaces/Private/` | 1 | Internal interface definitions |
| `Properties/` | 2 | Assembly metadata |
| `Resources/` | 3 | Embedded resources (manifest, designer, resx) |
| *(root)* | 10 | `.csproj` project files for Visual Studio versions |

**Comparers** (4 files):

| File | Class | Implements | Purpose |
|------|-------|-----------|---------|
| `ByteArray.cs` | `ByteArray` | `IEqualityComparer<byte[]>` | Byte array comparison using element-wise `GenericOps<byte>.Equals` and FNV-1 hashing |
| `Configuration.cs` | `_Configuration` | `IEqualityComparer<Configuration>` | Release-to-configuration matching on lookup fields (ProtocolId, PublicKeyToken, Name, Culture, BuildType) |
| `CultureInfo.cs` | `_CultureInfo` | `IEqualityComparer<CultureInfo>` | Culture comparison with null handling |
| `FileName.cs` | `FileName` | `IAnyComparer<string>` | Platform-aware file name comparison (case-insensitive on Windows, case-sensitive elsewhere) |

**Components/Private** (24 files):

| File | Class | Purpose |
|------|-------|---------|
| `AnyPair.cs` | `AnyPair<T1,T2>` | Immutable generic key-value pair container |
| `Characters.cs` | `Characters` | Character and escape sequence constants |
| `Configuration.cs` | `Configuration` | Central configuration management (sealed, ~40 properties, factory methods, validation) |
| `ConsoleEx.cs` | `ConsoleEx` | P/Invoke wrappers for `kernel32.dll` console allocation (NATIVE+WINDOWS only) |
| `Defaults.cs` | `Defaults` | All default configuration values (static constants) |
| `DefineConstants.cs` | `DefineConstants` | Runtime list of active compilation symbols |
| `Delegates.cs` | `Delegates` | Delegate type definitions (`TraceCallback`, `DelegateWithNoArgs`) |
| `Enumerations.cs` | `Enumerations` | `StrongNameExFlags` and `SignatureFlags` flag enums |
| `FileOps.cs` | `FileOps` | File operations: hash, backup, copy, sync, delete, in-use handling |
| `FormOps.cs` | `FormOps` | Thread-safe `ISynchronizeInvoke.BeginInvoke` helpers |
| `FormatOps.cs` | `FormatOps` | String/object formatting for display and logging |
| `GenericOps.cs` | `GenericOps<T>` | Generic collection utilities (`Contains`, `Equals` for `IComparable<T>`) |
| `HashOps.cs` | `HashOps` | FNV-1 hash algorithm implementation (32-bit, standard and alternate) |
| `ParseOps.cs` | `ParseOps` | Parsing utilities: hex strings, command lines, versions, enums, URIs, cultures |
| `Program.cs` | `Program` | Application entry point (`Main`), `Fail` handler, `ApplicationExit` cleanup |
| `Release.cs` | `Release` | Release manifest entry (parsing, validation, comparison, URI construction, file verification) |
| `SecurityOps.cs` | `SecurityOps` | Authenticode verification, strong name checking, certificate subject matching, TLS pinning |
| `ShellOps.cs` | `ShellOps` | Eagle interactive shell launcher via reflection (late binding) |
| `StrongNameEx.cs` | `StrongNameEx` | P/Invoke wrapper for `mscoree.dll` `StrongNameSignatureVerificationEx` (NATIVE+WINDOWS only) |
| `TextProgressBar.cs` | `TextProgressBar` | Custom progress bar control with centered text overlay |
| `TraceOps.cs` | `TraceOps` | Diagnostics: trace output with caller identification, message boxes, timestamps |
| `UpdateWebClient.cs` | `UpdateWebClient` | Custom `WebClient` subclass with configurable `User-Agent` header |
| `VersionOps.cs` | `VersionOps` | Platform/runtime detection (Windows, Mono, version comparison) |
| `WinTrustEx.cs` | `WinTrustEx` | P/Invoke wrapper for `wintrust.dll` `WinVerifyTrust` Authenticode verification (NATIVE+WINDOWS only) |

**Forms** (3 files):

| File | Purpose |
|------|---------|
| `UpdateForm.cs` | Main UI logic: download orchestration, event handlers, keyboard shortcuts |
| `UpdateForm.Designer.cs` | Auto-generated UI layout with Mono-aware sizing |
| `UpdateForm.resx` | Form resource file |

**Interfaces** (1 file):

| File | Interface | Purpose |
|------|-----------|---------|
| `AnyComparer.cs` | `IAnyComparer<T>` | Combines `IComparer<T>` and `IEqualityComparer<T>` |

### 2.2 Shared Source Files

Hippogriff includes several source files from the Eagle core library via
MSBuild linked items (`<Link>` elements). These are shared at the source level,
not via assembly reference:

| Linked File | Purpose |
|-------------|---------|
| `AssemblyDateTimeAttribute.cs` | Build timestamp attribute |
| `AssemblyLicenseAttribute.cs` | License text attribute |
| `AssemblyReleaseAttribute.cs` | Release tag attribute |
| `AssemblySourceIdAttribute.cs` | Source control ID attribute |
| `AssemblySourceTimeStampAttribute.cs` | Source timestamp attribute |
| `AssemblyStrongNameTagAttribute.cs` | Strong name tag attribute |
| `AssemblyTagAttribute.cs` | General tag attribute |
| `AssemblyTextAttribute.cs` | Text attribute |
| `AssemblyUriAttribute.cs` | URI attribute |
| `AttributeOps.cs` | Assembly attribute reflection utilities |
| `Enumerations.cs` (Shared) | Shared `BuildType` and `ReleaseType` enums |
| `PublicKey.cs` | Public key constants |
| `SourceLicense.cs` | Source license text |
| `StringOps.cs` | String comparison utilities |
| `BinaryLicense.cs` | Binary license text (official builds only) |

This source-sharing approach ensures Hippogriff has zero runtime dependency on
`Eagle.dll` while reusing common attribute definitions and utility code.

### 2.3 Build Configuration

The project file (`Hippogriff.csproj`) references:

- **Framework assemblies**: `System`, `System.Drawing`, `System.Windows.Forms`
- **No external NuGet packages or third-party dependencies**
- **Build targets imported**: `Eagle.Presets.targets`, `Eagle.Builds.targets`,
  `Eagle.Settings.targets`, `Eagle.targets`
- **Build pipeline**: Includes detection of OS, architecture, .NET versions,
  strong name signing, Authenticode signing, and PDB path stripping.

Conditional compilation items:

- `ConsoleEx.cs`, `StrongNameEx.cs`, `WinTrustEx.cs` are included only when
  `EagleNative` and `EagleWindows` are not `false`.
- `BinaryLicense.cs` is included only for official binary builds.

### 2.4 Visual Studio Project Variants

Ten `.csproj` files provide compatibility across Visual Studio versions:

| File | Target |
|------|--------|
| `Hippogriff.csproj` | Default (Visual Studio 2005 format) |
| `Hippogriff2005.csproj` | Visual Studio 2005 |
| `Hippogriff2008.csproj` | Visual Studio 2008 |
| `Hippogriff2010.csproj` | Visual Studio 2010 |
| `Hippogriff2012.csproj` | Visual Studio 2012 |
| `Hippogriff2013.csproj` | Visual Studio 2013 |
| `Hippogriff2015.csproj` | Visual Studio 2015 |
| `Hippogriff2017.csproj` | Visual Studio 2017 |
| `Hippogriff2019.csproj` | Visual Studio 2019 |
| `Hippogriff2022.csproj` | Visual Studio 2022 |

The default project targets .NET Framework 2.0 (`v2.0`) when
`EagleOnlyNetFx20` is not `false`, ensuring maximum backward compatibility.

---

## 3. Architecture

### 3.1 Component Overview

Hippogriff follows a layered architecture with clear separation of concerns:

```
+-----------------------------------------------------------+
|                    Program (Entry Point)                  |
+-----------------------------------------------------------+
|                    UpdateForm (UI + Orchestration)        |
+-----------------------------------------------------------+
|  Configuration  |  Release  |  UpdateWebClient  |  FileOps|
+-----------------------------------------------------------+
|  SecurityOps  |  StrongNameEx  |  WinTrustEx  |  HashOps  |
+-----------------------------------------------------------+
|  TraceOps  |  FormatOps  |  ParseOps  |  VersionOps       |
+-----------------------------------------------------------+
|  Platform Abstractions (ConsoleEx, ShellOps, FormOps)     |
+-----------------------------------------------------------+
```

- **Entry layer**: `Program` handles startup, configuration loading, mutex
  checking, and error exit.
- **UI layer**: `UpdateForm` orchestrates the entire update workflow through
  asynchronous web client events.
- **Domain layer**: `Configuration` and `Release` model the update domain.
  `UpdateWebClient` handles network I/O. `FileOps` handles file system
  operations.
- **Security layer**: `SecurityOps`, `StrongNameEx`, and `WinTrustEx` provide
  multi-layer cryptographic verification.
- **Infrastructure layer**: Formatting, parsing, tracing, version detection,
  and generic utilities.

### 3.2 Class Hierarchy

All classes are `internal` (assembly-private). The key relationships:

| Class | Base | Pattern |
|-------|------|---------|
| `Program` | (none, static) | Entry point |
| `UpdateForm` | `System.Windows.Forms.Form` | Main UI |
| `Configuration` | (none, sealed) | Immutable-ish configuration |
| `Release` | (none, sealed) | Immutable release descriptor |
| `UpdateWebClient` | `System.Net.WebClient` | Custom HTTP client |
| `TextProgressBar` | `System.Windows.Forms.ProgressBar` | Custom control |
| `StrongNameEx` | (none, static) | P/Invoke wrapper |
| `WinTrustEx` | (none, static) | P/Invoke wrapper |
| `ConsoleEx` | (none, static) | P/Invoke wrapper |

Most utility classes (`FileOps`, `SecurityOps`, `HashOps`, `FormatOps`,
`ParseOps`, `TraceOps`, `VersionOps`, `FormOps`, `GenericOps<T>`,
`ShellOps`) are `internal static`.

### 3.3 Namespace Organization

| Namespace | Contents |
|-----------|----------|
| `Eagle._Components.Private` | All core logic classes |
| `Eagle._Components.Shared` | Shared types from Eagle library (enums, string ops) |
| `Eagle._Comparers` | Custom comparer implementations |
| `Eagle._Controls.Private` | `TextProgressBar` custom control |
| `Eagle._Forms` | `UpdateForm` UI |
| `Eagle._Interfaces.Private` | `IAnyComparer<T>` interface |
| `Eagle._Components.Private.Delegates` | Delegate type definitions |

### 3.4 Comparers and Equality

The `_Configuration` comparer is central to release matching. It compares
`Configuration` objects on lookup fields only:

1. **Id**: Negative means "any" (wildcard match).
2. **ProtocolId**: String comparison (system comparison type).
3. **PublicKeyToken**: Byte array comparison via `ByteArray` comparer.
4. **Name**: String comparison (system comparison type).
5. **Culture**: Culture equality via `_CultureInfo` comparer.
6. **BuildType**: Enum equality.

The `GetHashCode` implementation uses FNV-1 hashing (via `HashOps`) on
ProtocolId bytes, PublicKeyToken, Name bytes, and Culture, XOR-combined.

The `FileName` comparer uses `FileOps.GetComparisonType()` to determine
platform-appropriate comparison: `OrdinalIgnoreCase` on Windows, `Ordinal`
elsewhere.

---

## 4. Update Workflow

### 4.1 Startup and Initialization

The `Program.Main` method executes the following sequence:

1. **Configuration creation**: `Configuration.TryCreate(assembly)` builds a
   base configuration from the executing assembly's metadata (version, public
   key token, URIs from `[AssemblyUri]` attributes).

2. **Configuration from file**: `Configuration.FromFile()` loads settings from
   a companion file (`Hippogriff.exe.args`) if present.

3. **Configuration from arguments**: `Configuration.FromArgs(args)` parses
   command-line arguments, overriding file and default values.

4. **Configuration processing**: `Configuration.Process()` validates all
   settings and performs final adjustments (refresh core file paths, detect
   release type).

5. **Self-integrity check**: Verifies `configuration.IsSigned` -- that the
   updater's own Authenticode and strong name signatures are valid.

6. **Mutex check**: Attempts to open the named mutex (`Global\Eagle_Setup`).
   If it already exists, Eagle is running and the update is aborted. If
   `WaitHandleCannotBeOpenedException` is thrown, no mutex exists and the
   update can proceed.

7. **UI creation**: Registers the `ApplicationExit` handler, enables visual
   styles, creates `UpdateForm`, and enters the Windows Forms message loop
   via `Application.Run`.

### 4.2 Release Manifest Download

When the user clicks the Update button (or after the 5-second silent timer
fires):

1. An `UpdateWebClient` is created with a custom user-agent string formatted
   as `Hippogriff/1.0`.

2. The manifest URI is constructed: `configuration.BaseUri` +
   `configuration.GetPathAndQuery()`. The path includes the current version
   as a cache-busting query parameter (e.g., `latest.txt?v=1.0` or
   `stable.txt?v=1.0`).

3. `client.DownloadDataAsync(uri)` initiates an asynchronous download of the
   release manifest.

4. Progress is reported via `DownloadProgressChanged` events, updating the
   progress bar and speed display.

### 4.3 Release Manifest Parsing

When the manifest download completes (`DownloadDataCompleted`):

1. The response bytes are decoded as UTF-8 text.

2. `Release.ParseData()` splits the text by line separators and processes
   each line:
   - Lines starting with `#` or `;` are treated as comments and skipped.
   - Empty lines are skipped.
   - Each valid line is parsed as a tab-separated record with 11 fields.
   - Each parsed `Release` receives an auto-incremented ID.
   - For each release, a `Configuration` is created via
     `Configuration.CreateFrom(release)` and stored as the dictionary key.
   - Releases are stored in a dictionary keyed by `Configuration` using the
     `_Configuration` equality comparer.

3. Protocol type counts are tracked and displayed (builds, scripts, self
   updates, plugins).

### 4.4 Release Selection and Validation

After parsing:

1. **Find self-update**: `Release.FindSelf()` searches for a release with
   `ProtocolId == "3"` (Self) that matches the updater's own public key
   token, name, and culture. If a newer self-update exists, it takes
   priority.

2. **Find target update**: `Release.Find()` searches for a release matching
   the configured protocol ID, public key token, name, culture, and build
   type.

3. **Validation checks**:
   - `release.IsValid` -- all required fields are present and well-formed.
   - `release.IsGreater` -- the release patch level is higher than the
     currently installed version. (The `Force` flag bypasses this check.)

4. **User confirmation**: If `-confirm` is enabled (the default), a dialog
   asks the user whether to proceed.

5. **Release notes**: If the release includes notes, they are displayed in a
   dialog and the user can choose to continue or cancel.

### 4.5 File Download

The release archive URI is constructed from `release.BaseUri` and
`release.UriFormat`. A temporary directory is created under the system temp
path, and `client.DownloadFileAsync()` downloads the archive. Progress
reporting continues via `DownloadProgressChanged`.

### 4.6 Extraction and Verification

After the file download completes (`DownloadFileCompleted`):

1. **Release file signature**: If `SignatureFlags.Release` is set, the
   downloaded archive's Authenticode signature is verified against the
   expected `SubjectName`.

2. **Extraction**: The archive is extracted using a configurable command
   format. The default format is designed for self-extracting archives
   (e.g., 7-Zip SFX): the command is the archive itself, with arguments
   `-d<targetDir> -s2` for silent extraction.

3. **Core file location**: `FileOps.GetFirstName()` recursively searches the
   extraction directory for the core file (default: `Eagle.dll`).

4. **Core file verification**:
   - Authenticode signature check (if `SignatureFlags.Core` is set).
   - `release.VerifyFile()` performs comprehensive verification:
     - Strong name signature verification via `StrongNameEx` (Windows only).
     - Public key token comparison against the release manifest.
     - MD5 hash verification.
     - SHA1 hash verification.
     - SHA512 hash verification.
   - All three hashes must match. Any failure aborts the update.

5. **Directory offset calculation**: The relative path from the extraction
   root to the core file determines the directory structure offset (e.g.,
   `Eagle\bin`). This offset is matched against the existing installation
   directory to calculate the correct target.

### 4.7 Three-Phase File Installation

File installation uses a three-phase approach for reliability:

**Phase 1 -- Backup**:
- Every existing target file is copied to a `.old` backup.
- The currently running assembly (`Hippogriff.exe`) receives special handling:
  it is first moved to `.in-use`, then copied to `.old`.

**Phase 2 -- Copy**:
- Each extracted file is copied to its target location.
- Before copying, the source file hash is computed.
- After copying, the target file hash is computed.
- The two hashes are compared; any mismatch aborts the update.
- Signature verification (strong name and/or Authenticode) is optionally
  performed on each copied file.

**Phase 3 -- Cleanup**:
- Only after all copies succeed, the `.old` backup files are deleted.
- The extraction temporary directory is deleted.
- The download temporary directory is deleted.

This design ensures that if any step fails, the original files remain intact
via the `.old` backups.

### 4.8 Self-Update Mechanism

When `release.IsSelf` is true (the release is for the updater itself):

1. The downloaded release file is copied directly to the assembly location,
   replacing the current `Hippogriff.exe`.

2. `Configuration.StartAsSelf()` launches a new process of the updated
   updater with appropriate arguments.

3. The current instance closes via `SafeClose()`.

The `.in-use` mechanism handles the fact that Windows locks running
executables: the current binary is moved to `Hippogriff.exe.in-use` before
the new version is written.

### 4.9 Post-Update Actions

If the `-reCheck` flag is set:

1. The user is prompted to re-run the updater to check for additional
   updates (chained update scenario).

2. If confirmed, a new Hippogriff process is launched via
   `Configuration.StartAsSelf(update: false)` and the current instance
   closes.

In silent mode, the form closes automatically after the update completes.

### 4.10 Shutdown and Cleanup

The `ApplicationExit` handler:

1. Checks for an `.in-use` file (left from a previous self-update).

2. If found, creates a temporary batch file that:
   - Waits 3+ seconds using `ping -n 4 localhost`.
   - Deletes the `.in-use` file.

3. Launches the batch file as a child process and exits. The batch file
   completes after the updater process has terminated, successfully deleting
   the locked file.

---

## 5. Security Model

### 5.1 Multi-Layer Verification

Hippogriff implements defense-in-depth with multiple independent verification
layers:

| Layer | What It Verifies | API Used | When Applied |
|-------|-----------------|----------|-------------|
| Self-integrity | Updater's own signatures | SecurityOps | Startup |
| TLS pinning | Update server certificate | SecurityOps callback | All HTTPS requests |
| Release file Authenticode | Downloaded archive signature | WinTrustEx | After archive download |
| Core file Authenticode | Extracted core assembly signature | WinTrustEx | After extraction |
| Strong name | .NET assembly strong name | StrongNameEx | After extraction |
| Public key token | Assembly identity | Reflection | After extraction |
| MD5 hash | File integrity | System.Security.Cryptography | After extraction |
| SHA1 hash | File integrity | System.Security.Cryptography | After extraction |
| SHA512 hash | File integrity | System.Security.Cryptography | After extraction |
| Copy verification | Post-copy integrity | Hash comparison | After each file copy |

### 5.2 Authenticode Signature Verification

`WinTrustEx` provides a P/Invoke wrapper around the Windows
`WinVerifyTrust` API (`wintrust.dll`):

- Uses `WINTRUST_ACTION_GENERIC_VERIFY_V2` for standard code signing
  verification.
- Configurable UI mode: can show trust dialogs or run silently.
- Configurable revocation checking: `WTD_REVOKE_WHOLECHAIN` for full chain
  verification or `WTD_REVOKE_NONE` to skip.
- Uses `WTD_SAFER_FLAG` for safe code verification context.
- Properly allocates and frees unmanaged memory for the `WINTRUST_FILE_INFO`
  and `WINTRUST_DATA` structures.

`SecurityOps.IsAuthenticodeSigned` provides a higher-level API that:
- Creates an `X509Certificate2` from the signed file.
- Matches the certificate subject against the expected `SubjectName`.
- Optionally calls `certificate2.Verify()` for full chain validation.

In DEBUG builds, Authenticode verification is skipped (returns true) to
facilitate development.

### 5.3 Strong Name Signature Verification

`StrongNameEx` provides a P/Invoke wrapper around
`StrongNameSignatureVerificationEx` from `mscoree.dll`:

- Verifies that a .NET assembly has a valid strong name signature.
- The `force` parameter controls whether the runtime cache is bypassed.
- Returns both a success boolean and a "was verified" boolean (the latter
  indicates whether actual verification was performed vs. cached).

`SecurityOps.IsStrongNameSigned` provides a reflection-based verification
path that:
- Extracts the assembly's public key from `AssemblyName`.
- Enumerates the assembly's `Evidence` looking for `StrongName` evidence.
- Compares the evidence public key with the assembly's public key.
- Extracts and returns the public key token.

In DEBUG builds, strong name verification is skipped.

### 5.4 Hash Verification

`Release.VerifyFile` computes three independent hashes of each file and
compares them against values from the release manifest:

1. **MD5** (128-bit) -- legacy compatibility.
2. **SHA1** (160-bit) -- standard verification.
3. **SHA512** (512-bit) -- strong verification.

All three must match for verification to succeed. `FileOps.Hash` uses
`System.Security.Cryptography.HashAlgorithm.Create()` with a configurable
algorithm name.

`HashOps` implements the FNV-1 hash algorithm (32-bit) for internal use in
comparers and dictionary key generation, not for security verification.

### 5.5 TLS Certificate Pinning

`SecurityOps.RemoteCertificateValidationCallback` implements a custom
`ServicePointManager` callback for HTTPS connections:

- If the standard SSL policy reports no errors, the connection is accepted.
- If there are policy errors, the callback compares the server certificate's
  public key against four pinned public keys (`SoftwareUpdate1` through
  `SoftwareUpdate4`).
- The connection is accepted only if the server certificate's public key
  matches one of the pinned keys.

This provides protection against compromised certificate authorities.

### 5.6 Application Manifest

The embedded `manifest.xml` requests:

- **Execution level**: `requireAdministrator` -- the updater must run elevated
  because it writes to the Eagle installation directory (typically under
  `Program Files`).
- **Supported OS**: Windows Vista through Windows 10 are declared for
  compatibility.

### 5.7 Self-Integrity Check

At startup, `configuration.IsSigned` verifies that the updater's own binary
passes both Authenticode and strong name verification. If either check fails,
the updater refuses to run, preventing execution of a tampered binary.

---

## 6. Configuration System

### 6.1 Configuration Loading Order

Configuration is assembled from multiple sources, with later sources
overriding earlier ones:

1. **Defaults** (`Defaults` class) -- compile-time default values.
2. **Assembly metadata** (`TryCreate`) -- reads `[AssemblyUri]`,
   `[AssemblyVersion]`, and other attributes from the executing assembly.
3. **Arguments file** (`FromFile`) -- reads from `Hippogriff.exe.args` on
   disk.
4. **Command-line arguments** (`FromArgs`) -- highest priority overrides.
5. **Processing** (`Process`) -- validates, resolves paths, and detects
   release type.

### 6.2 Command-Line Options

All options use the `-optionName value` syntax (with `-` or `/` prefix):

**Identity and Server:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-id` | int | -1 | Configuration ID (-1 means "any") |
| `-protocolId` | string | `"1"` | Release protocol type |
| `-publicKeyToken` | hex string | `29c6297630be05eb` | Expected public key token |
| `-name` | string | `"Eagle"` | Assembly name to match |
| `-culture` | CultureInfo | null (invariant) | Culture to match |
| `-patchLevel` | Version | (from assembly) | Current installed version |
| `-baseUri` | URI | `https://update.eagle.to/` | Update server base URI |
| `-tagPathAndQuery` | string | `latest.txt?v={0}` or `stable.txt?v={0}` | Manifest file path |
| `-uriFormat` | string | (from release) | Download URI format |
| `-mutexName` | string | `Global\Eagle_Setup` | Named mutex for instance detection |

**Paths and Files:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-coreDirectory` | path | (detected) | Eagle installation directory |
| `-coreFileName` | path | `Eagle.dll` | Core assembly file name |
| `-logFileName` | path | (temp directory) | Log file path |
| `-commandFormat` | string | `{0}` | Extraction command format |
| `-argumentFormat` | string | `"-d{0}" -s2` | Extraction argument format |
| `-hashAlgorithmName` | string | `"sha1"` | Hash algorithm for file verification |

**Build Configuration:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-buildType` | BuildType | Default | Build type to match |
| `-releaseType` | ReleaseType | Default | Release type (Binary, Runtime, Core) |
| `-strongNameExFlags` | flags | All | Strong name verification flags |
| `-signatureFlags` | flags | All | Authenticode verification flags |
| `-subjectName` | string | `"Mistachkin Systems"` (official) | Expected certificate subject |

**Behavior Flags:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-silent` | bool | false | Automatic update without user interaction |
| `-invisible` | bool | false | Hide the update form completely |
| `-confirm` | bool | true | Ask user to confirm before updating |
| `-force` | bool | false | Proceed even if version is not newer |
| `-whatIf` | bool | false | Simulation mode (no actual changes) |
| `-verbose` | bool | false | Detailed logging |
| `-reCheck` | bool | false | Re-launch after successful update |
| `-shell` | bool | false | Enable embedded Eagle shell |
| `-shellArgs` | string | null | Arguments for the Eagle shell |
| `-tracing` | bool | false | Enable diagnostic tracing |
| `-logging` | bool | true | Enable log file output |
| `-delay` | int (ms) | 0 | Delay before starting update |
| `-noAuthenticodeSigned` | bool | false | Skip Authenticode verification |
| `-noStrongNameSigned` | bool | false | Skip strong name verification |
| `-coreIsAssembly` | bool | true | Whether core file is a .NET assembly |
| `-strict` | bool | (varies) | Strict error handling |
| `-exceptions` | bool | false | Allow non-Ok return codes |
| `-policies` | bool | false | Enable command execution policies |

### 6.3 Arguments File

Configuration can be loaded from `Hippogriff.exe.args` (a companion file
next to the executable):

- One argument per line.
- Lines starting with `#` or `;` are comments.
- Leading and trailing whitespace is trimmed.
- Empty lines are ignored.
- Arguments follow the same `-optionName value` syntax as command-line
  arguments.

### 6.4 Default Values

Key defaults from the `Defaults` class:

| Constant | Value | Purpose |
|----------|-------|---------|
| `ExecutableName` | `"Hippogriff"` | Assembly and executable name |
| `BaseUri` | `https://update.eagle.to/` | Update server |
| `TagPathAndQuery` | `latest.txt?v={0}` (or `stable.txt?v={0}`) | Manifest path |
| `DefaultCreateFlags` | `SafeEmbeddedUse` | Interpreter flags (if shell enabled) |
| `SelfUriFormat` | `releases/{0}/Hippogriff.exe` | Self-update download path |
| `BuildUriFormat` | `releases/{0}/Eagle{1}{2}{0}.exe` | Eagle download path |
| `HashAlgorithmName` | `"sha1"` | Default hash algorithm |
| `MutexName` | `Global\Eagle_Setup` | Instance detection mutex |
| `PublicKeyToken` | `29c6297630be05eb` | Expected Eagle public key token |
| `UserAgentFormat` | `{0}/{1}` | HTTP User-Agent format |
| `CoreFileName` | `Eagle.dll` | Core library file name |
| `ShellFileName` | `EagleShell.exe` | Shell executable name |
| `TasksFileName` | `EagleTasks.dll` | MSBuild tasks assembly name |
| `CmdletsFileName` | `EagleCmdlets.dll` | PowerShell cmdlets assembly name |

### 6.5 Release Type Detection

The `Configuration` class automatically detects the release type by checking
which files exist in the core directory:

| Release Type | Required Files |
|-------------|----------------|
| **Binary** | `Eagle.dll`, `EagleShell.exe`, `Hippogriff.exe`, `EagleTasks.dll`, `EagleCmdlets.dll` |
| **Runtime** | `Eagle.dll`, `EagleShell.exe`, `Hippogriff.exe` |
| **Core** | `Eagle.dll` only |

The most complete matching type is selected. This determines which files the
updater expects to find in the downloaded release.

---

## 7. Release Manifest Format

### 7.1 Protocol Types

Each release manifest entry has a protocol identifier:

| Protocol ID | Name | Description |
|-------------|------|-------------|
| `"1"` | Build | Standard Eagle build release |
| `"2"` | Script | Eagle script package release |
| `"3"` | Self | Hippogriff self-update release |
| `"4"` | Plugin | Eagle plugin release |

### 7.2 Field Layout

The manifest is a plain-text file with one release per line. Each line
contains 11 tab-separated fields:

| Index | Field | Type | Example |
|-------|-------|------|---------|
| 0 | ProtocolId | string | `1` |
| 1 | PublicKeyToken | hex string | `29c6297630be05eb` |
| 2 | Name | string | `Eagle_Default` (for builds, includes build type) |
| 3 | Culture | string | `neutral` |
| 4 | PatchLevel | version | `1.0.8406.33142` |
| 5 | TimeStamp | datetime | `2023-01-15T12:00:00.0000000` |
| 6 | BaseUri | URI | `https://download.eagle.to/` |
| 7 | Md5Hash | hex string | (32 hex chars) |
| 8 | Sha1Hash | hex string | (40 hex chars) |
| 9 | Sha512Hash | hex string | (128 hex chars) |
| 10 | Notes | string | (optional, entity-escaped) |

Comment lines start with `#` or `;`. Empty lines are ignored.

For Build protocol entries, the Name field is parsed by
`ParseOps.NameAndBuildType()` to extract both the assembly name and build
type (e.g., `Eagle_Default` yields name `Eagle` and build type `Default`).

For Self protocol entries, the `UriFormat` is automatically set to
`releases/{0}/Hippogriff.exe`.

### 7.3 Release Matching

The `Release.Find()` method searches the parsed releases dictionary using
the `_Configuration` equality comparer, which matches on:

1. ProtocolId (exact match)
2. PublicKeyToken (byte-wise comparison)
3. Name (string comparison)
4. Culture (CultureInfo equality)
5. BuildType (enum equality)

The `Release.FindSelf()` method creates a temporary configuration with
`ProtocolId = "3"` (Self) and uses the same matching logic.

After matching, additional validation ensures `IsValid` (all required fields
present) and `IsGreater` (newer version).

---

## 8. User Interface

### 8.1 Form Layout

The `UpdateForm` is a fixed-size, non-resizable dialog:

- **Windows size**: 634 x 233 pixels
- **Mono size**: 634 x 269 pixels (adjusted for different DPI scaling)
- **Border style**: FixedSingle (no resize grip)
- **Title bar**: No minimize/maximize/close buttons (`ControlBox = false`)
- **Start position**: Center screen
- **Colors**: Dark blue background (RGB 72, 93, 124), light blue controls
  (RGB 118, 134, 157), white text
- **Font**: Segoe UI, 9pt (13pt for buttons)

Control layout:

| Control | Type | Position | Purpose |
|---------|------|----------|---------|
| `lblBanner` | Label | Top-left (12, 12) | Eagle logo image (180 x 60) |
| `lblUpdate` | Label | Top-right (200, 12) | Main status message (422 x 42) |
| `lblPercent` | Label | Below status (200, 62) | Download speed and percentage (422 x 22) |
| `prbUpdate` | TextProgressBar | Middle (12, 92) | Progress bar with text overlay (610 x 30, max 1000) |
| `lblUri` | Label | Below progress (12, 130) | Current download URI (610 x 42) |
| `btnUpdate` | Button | Bottom-left (12, 180) | Starts update (207 x 41) |
| `btnCancel` | Button | Bottom-right (415, 180) | Cancels or closes (207 x 41) |

### 8.2 Keyboard Shortcuts

The form enables `KeyPreview` to intercept keyboard input:

| Shortcut | Action |
|----------|--------|
| F1 | Display help message |
| Ctrl-A | Show license text (source or binary) |
| Ctrl-E | Launch Eagle Shell externally |
| Ctrl-L | Open log file in Notepad |
| Ctrl-R | Reset core directory to default |
| Ctrl-T | Browse for a new core directory |
| Ctrl-F2 | Start embedded Eagle interactive shell in a new thread |

### 8.3 Silent and Invisible Modes

When `-silent` is enabled:

1. The Update button is disabled (the user cannot manually trigger updates).
2. A one-shot timer fires after 5 seconds and automatically clicks the
   Update button.
3. After the update completes (or fails), the form closes automatically.

When `-invisible` is also enabled, the form is hidden entirely. The update
runs completely headless.

### 8.4 Progress Reporting

The `TextProgressBar` is a custom `ProgressBar` subclass that renders
centered text over the progress bar fill. It overrides `WndProc` to handle
`WM_PAINT` messages, drawing the progress text using the parent font in
bold.

Progress is reported as:
- Percentage fill (0% to 100%).
- Bytes transferred: `"{received:N0} of {total:N0} bytes, {speed:N2}
  bytes/second"`.
- Download speed is calculated from elapsed time since download start.

A "progress bar hack" works around a Windows Vista+ animation bug by
temporarily toggling the progress bar's maximum value to force an immediate
repaint.

### 8.5 Thread-Safe Status Updates

Because WebClient events fire on worker threads, the `UpdateForm` uses a
queue-based approach for status updates:

1. Worker threads call `QueueStatus(message)`, which enqueues the message
   into a `Queue<string>` protected by a lock.

2. A `statusTimer` (200ms interval) fires on the UI thread and dequeues
   messages, updating `lblUpdate` via `UpdateStatus(message)`.

3. `FormOps.BeginInvoke` handles cross-thread control access using
   `ISynchronizeInvoke.BeginInvoke` for safe UI updates.

---

## 9. Platform Support

### 9.1 .NET Framework Versions

The default project targets .NET Framework 2.0 for maximum compatibility.
Conditional compilation defines are added for higher framework versions when
detected:

`NET_20_ONLY`, `NET_40`, `NET_45`, `NET_451`, `NET_452`, `NET_46`,
`NET_461`, `NET_462`, `NET_47`, `NET_471`, `NET_472`, `NET_48`, `NET_481`

On .NET 4.0+, `SecurityCritical` attributes replace the older
`SecurityPermission` attributes for P/Invoke methods.

### 9.2 Windows Version Support

The application manifest declares support for:
- Windows Vista
- Windows 7
- Windows 8
- Windows 8.1
- Windows 10

`VersionOps.IsWindowsVistaOrHigher()` detects Windows Vista+ for features
like the progress bar animation workaround.

### 9.3 Mono Compatibility

`VersionOps.IsMono()` detects the Mono runtime by attempting to resolve
`Mono.Runtime` via reflection. When running on Mono:

- Strong name verification via `StrongNameSignatureVerificationEx` is
  unavailable (returns "not implemented").
- Console attachment via `kernel32.dll` is unavailable.
- WinTrust verification is unavailable.
- `UpdateForm.Designer.cs` adjusts form height to 269px (vs. 233px on
  Windows) and disables auto-scaling.
- `SecurityOps.IsAdministrator()` may not work correctly.

### 9.4 Conditional Compilation

Key compilation symbols and their effects:

| Symbol | Effect |
|--------|--------|
| `DEBUG` | Skips all signature/strong-name verification (returns true) |
| `NATIVE` | Enables P/Invoke wrappers (ConsoleEx, StrongNameEx, WinTrustEx) |
| `WINDOWS` | Enables Windows-specific functionality |
| `MONO` | Enables Mono workarounds |
| `CONSOLE` | Enables console output and debugger prompts |
| `SHELL` | Enables embedded Eagle shell via reflection |
| `OFFICIAL` | Sets default SubjectName to "Mistachkin Systems" |
| `STABLE` | Uses `stable.txt` instead of `latest.txt` for manifest path |
| `PATCHLEVEL` | Uses explicit PatchLevel.cs instead of `AssemblyVersion("1.0.*")` |
| `DEAD_CODE` | Includes unused but preserved code |
| `OFFICIAL_BINARY` | Includes binary license text |

---

## 10. File Operations

### 10.1 In-Use File Handling

Windows locks running executables, preventing in-place replacement. The
updater handles this with a two-step mechanism:

1. **During update**: The running `Hippogriff.exe` is moved to
   `Hippogriff.exe.in-use` (a rename/move succeeds even for locked files on
   NTFS). The new version is then written to the original path.

2. **On exit**: The `ApplicationExit` handler creates a temporary batch
   script:
   ```
   ping -n 4 localhost > NUL 2>&1
   DEL /F /Q "...\Hippogriff.exe.in-use"
   ```
   The batch file is launched as a child process. After the updater exits
   (releasing the file lock), the batch file's 3-second ping delay ensures
   the process has fully terminated before attempting deletion.

### 10.2 Backup and Restore

`FileOps.Backup()` creates `.old` copies of existing files before overwriting:

- Regular files: `File.Copy(source, source + ".old")`.
- Running assembly: `File.Move(source, source + ".in-use")`, then
  `File.Copy(source + ".in-use", source + ".old")`.

Read-only attributes are cleared before backup operations and restored
afterward if needed.

### 10.3 Hash-Verified Copy

`FileOps.CopyOrMoveWithHash()` ensures data integrity during file operations:

1. Compute hash of source file.
2. Perform the copy (or move).
3. Compute hash of target file.
4. Compare hashes. If they differ, the copy is considered failed.

The target directory is created if it does not exist.

### 10.4 File List Synchronization

`FileOps.SynchronizeNameLists()` handles the case where the new release
contains different files than the existing installation:

- Files in the source but not the target are added to the target list.
- Files in the target but not the source are removed from the target list.
- Comparison uses the `FileName` comparer for platform-appropriate case
  sensitivity.
- Files with the `.in-use` suffix are excluded from target file lists.

---

## 11. Diagnostics and Logging

### 11.1 Trace System

`TraceOps` provides comprehensive diagnostic logging:

- **Caller identification**: Walks the call stack to find the first non-trace
  method, formatting it as `Type::Method`.
- **Thread-safe output**: Uses `System.Diagnostics.Trace` with a lock around
  writes.
- **Unique IDs**: Each trace entry receives a monotonically increasing ID via
  `Interlocked.Increment`.
- **Timestamps**: ISO 8601 format (`yyyy.MM.ddTHH:mm:ss.fffffff`).
- **Message boxes**: `ShowMessage()` displays user-facing dialogs with
  configurable buttons and icons. Falls back to trace callback if
  configured.
- **Pluggable callback**: The `TraceCallback` delegate allows configuration
  of custom trace output handling.

### 11.2 Console Allocation

`ConsoleEx` enables console output for the GUI application on Windows:

1. `TryOpen()` first checks if a console is already attached
   (`GetConsoleWindow`).
2. If not, tries to attach to the parent process's console
   (`AttachConsole(ATTACH_PARENT_PROCESS)`).
3. If attachment fails, allocates a new console (`AllocConsole`).
4. `TryClose()` frees the console when no longer needed.

This allows the updater to display diagnostic output in a console window
even though it is a Windows Forms application.

---

## 12. Embedded Eagle Shell

When built with the `SHELL` compilation symbol and invoked with the `-shell`
flag, the updater can launch an embedded Eagle interactive shell:

`ShellOps.ShellMain()` uses reflection to late-bind to the Eagle interpreter:

1. Loads the `Eagle` assembly by name
   (`Eagle, Version=1.0, Culture=neutral`).
2. Resolves the `Eagle._Components.Public.Interpreter` type.
3. Invokes the static `ShellMain` method with the configured shell arguments.
4. Returns the shell's exit code.

This approach avoids a compile-time dependency on `Eagle.dll`. The shell is
launched in a new thread (accessible via Ctrl-F2 in the UI) and is intended
for debugging and diagnostic purposes.

`ShellOps.CheckBreak()` supports debugger attachment: if the `Break`
environment variable is set, the method clears it and calls
`Debugger.Break()`, allowing a developer to attach a debugger before the
shell loads.
