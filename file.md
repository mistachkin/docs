# Eagle `[file]` Command — Deep-Dive Analysis

## 1. Executive Summary

The Eagle `[file]` command provides **53 sub-commands** for file system
operations with deep .NET/CLR integration. While Tcl's `[file]` offers roughly
25 sub-commands focused on portable path manipulation and basic I/O, Eagle
extends this to include Windows security descriptors (SDDL), ACL access
checks, PE file magic number parsing, .NET assembly verification, object IDs,
file ownership queries, interpreter cleanup management, advanced globbing with
`MatchMode`, and temporary paths.

Key differentiators from Tcl:

| Area | Tcl | Eagle |
|------|-----|-------|
| Sub-commands | ~25 | 53 |
| Security | Basic permissions | ACL, SDDL, ownership, trusted/verified |
| Path validation | Minimal | `validname` with platform-specific rules |
| Temporary files | `file tempfile` (8.6) | `tempname`/`temppath` with env precedence |
| PE inspection | None | `magic` extracts PE headers, CLR info |
| Glob matching | `[glob]` command | `[file glob]` with `MatchMode` enum |
| Cleanup | Manual | `[file cleanup]` with interpreter lifecycle |
| Timestamp setting | `[file mtime]` only | `atime`, `ctime`, `mtime` all settable |
| Platform details | Abstracted | `drive`, `system`, `objectid`, `information` |

---

## 2. Why the Eagle `[file]` Command Differs from Tcl

Eagle's `[file]` command sits atop .NET's `System.IO` and
`System.Security.AccessControl` namespaces, giving it direct access to:

- **FileAttributes enum** — 14 attribute flags (Archive, Compressed,
  Encrypted, Hidden, ReadOnly, ReparsePoint, SparseFile, System, Temporary,
  etc.)
- **FileVersionInfo** — PE version metadata for executables and DLLs
- **FileSecurity / DirectorySecurity** — Windows ACL and SDDL manipulation
- **WindowsIdentity** — ownership and group membership queries
- **DriveInfo** — volume and filesystem type information
- **Native P/Invoke** — `stat`/`lstat` on Unix/macOS, `BY_HANDLE_FILE_INFORMATION`
  and file object IDs on Windows

This integration means Eagle can perform operations that would require external
packages or `[exec]` calls in Tcl, while maintaining the familiar `[file]`
sub-command interface.

### Source files

| File | Role |
|------|------|
| `Commands/File.cs` (~2,827 lines) | Command implementation: sub-command dispatch, option parsing, policy enforcement |
| `Components/Private/FileOps.cs` (~3,904 lines) | File operations: copy, delete, touch, glob, access control, PE parsing |
| `Components/Private/PathOps.cs` (~10,518 lines) | Path manipulation: normalization, temp files, unique paths, platform P/Invoke |
| `Components/Private/RuntimeOps.cs` | Cryptographic randomness for unique path generation |
| `Components/Public/Delegates.cs` | `GetDateTimeCallback`, `SetDateTimeCallback` delegate types |

---

## 3. Sub-Command Reference

Eagle's 53 `[file]` sub-commands are organized below by functional category.
Sub-commands marked **(Eagle)** have no Tcl equivalent. Sub-commands marked
**(Enhanced)** extend Tcl's version with additional options or behavior.

### 3.1 Path Manipulation

These sub-commands decompose, combine, and transform file paths without
touching the filesystem.

#### `file dirname name`

Returns the directory portion of `name`, stripping the last path component.

```tcl
file dirname /usr/local/bin/eagle   ;# /usr/local/bin
file dirname relative/path.txt      ;# relative
file dirname justfile.txt            ;# .
```

#### `file tail name`

Returns the final component of `name` (the filename).

```tcl
file tail /usr/local/bin/eagle   ;# eagle
file tail /path/to/file.txt     ;# file.txt
```

#### `file rootname name`

Returns `name` without its extension (strips the last `.suffix`).

```tcl
file rootname /path/to/file.txt     ;# /path/to/file
file rootname archive.tar.gz        ;# archive.tar
```

#### `file rootpath name` **(Eagle)**

Returns the root portion of `name` (drive letter on Windows, `/` on Unix).

```tcl
file rootpath C:\Users\test\file.txt   ;# C:\
file rootpath /usr/local/bin           ;# /
```

#### `file extension name`

Returns the extension of `name` including the leading dot.

```tcl
file extension file.txt      ;# .txt
file extension archive.tar   ;# .tar
```

#### `file join name ?name ...?`

Joins path components using the platform separator, handling absolute
components correctly.

```tcl
file join /usr local bin          ;# /usr/local/bin
file join /base /absolute/path    ;# /absolute/path (absolute resets)
```

#### `file split name`

Splits `name` into its individual components as a list.

```tcl
file split /usr/local/bin   ;# {/ usr local bin}
file split relative/path    ;# {relative path}
```

#### `file normalize ?options? name` **(Enhanced)**

Resolves `name` to an absolute, normalized path. Eagle adds the `-legacy`
option.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-legacy` | `true` | Use legacy path resolution for Tcl compatibility |

```tcl
file normalize ./relative/../actual   ;# /current/actual (resolved)
file normalize -legacy false ~/file   ;# Uses .NET Path.GetFullPath
```

#### `file nativename name`

Converts `name` to the platform's native path format (backslashes on Windows,
forward slashes on Unix).

```tcl
file nativename /path/to/file   ;# \path\to\file (Windows)
file nativename C:/Users/test   ;# C:\Users\test (Windows)
```

#### `file pathtype name`

Returns the path type: `absolute`, `relative`, or `volumerelative`.

```tcl
file pathtype /usr/local      ;# absolute
file pathtype relative/path   ;# relative
file pathtype \Windows        ;# volumerelative (Windows)
```

#### `file separator ?name?`

Returns the platform path separator character. With `name`, returns the
separator appropriate for that path.

```tcl
file separator   ;# / (Unix) or \ (Windows)
```

#### `file drive name` **(Eagle, Windows)**

Returns detailed drive information for the volume containing `name` as a list
with 7 fields: `name`, `volumeLabel`, `driveType`, `driveFormat`,
`totalFreeSpace`, `availableFreeSpace`, `totalSize`. UNC paths are rejected.

```tcl
file drive C:\Users\test
;# name C:\ volumeLabel OS driveType Fixed driveFormat NTFS totalFreeSpace 107374182400 availableFreeSpace 107374182400 totalSize 256060514304
```

#### `file tildeexpand name` **(Eagle)**

Expands tilde (`~`) prefixes in `name` to the user's home directory.

```tcl
file tildeexpand ~/documents   ;# /home/user/documents
file tildeexpand ~             ;# /home/user
```

### 3.2 File Tests and Queries

These sub-commands test file properties without modifying the filesystem.

#### `file exists name`

Returns `1` if `name` exists (file or directory), `0` otherwise.

```tcl
file exists /etc/passwd   ;# 1 (on Unix)
file exists nosuchfile    ;# 0
```

#### `file isfile name`

Returns `1` if `name` is a regular file, `0` otherwise.

#### `file isdirectory name`

Returns `1` if `name` is a directory, `0` otherwise.

#### `file readable name`

Returns `1` if `name` is readable by the current process.

Eagle's implementation uses `FileOps.VerifyReadable()`, which on Windows
performs ACL access checks via `FileSystemAccessRule` evaluation rather than
simple file-open attempts.

#### `file writable name`

Returns `1` if `name` is writable by the current process.

Eagle's implementation uses `FileOps.VerifyWritable()`, which on Windows
checks ACL write permissions and on all platforms can fall back to creating
and immediately deleting a temporary file in the target location.

#### `file executable name`

Returns `1` if `name` is executable by the current process.

Eagle's implementation uses `FileOps.VerifyExecutable()`, which on Windows
checks `FileSystemRights.ExecuteFile` and `Traverse` permissions via ACL
evaluation.

#### `file type name`

Returns the type of `name`: `[file]`, `directory`, `link`, or raises an error
if the path does not exist.

#### `file size name`

Returns the size of `name` in bytes. For directories, returns the directory
entry size.

#### `file same name1 name2` **(Eagle)**

Returns `1` if both paths refer to the same filesystem object (resolves
symlinks, normalizes paths).

```tcl
file same /tmp/../tmp/file /tmp/file   ;# 1
```

#### `file owned name ?verbose?` **(Eagle, Windows/.NET)**

Tests whether the current user owns the file. With `verbose`, returns a
list containing `owned` (boolean), `owner` (SID or name), and `account`
details.

```tcl
file owned myfile.txt                ;# 1 or 0
file owned myfile.txt true           ;# {owned 1 owner DOMAIN\user ...}
```

Uses `WindowsIdentity` and `FileSecurity.GetOwner()` under the hood.

#### `file rights name` **(Eagle, Windows)**

Returns the effective access rights for the current user as a list of
`FileSystemRights` flags: `GenericRead`, `GenericWrite`, `GenericExecute`,
`GenericAll`.

```tcl
file rights myfile.txt   ;# GenericRead GenericWrite
```

Implementation uses `FileOps.AccessCheck()` which evaluates all
`FileSystemAccessRule` entries (both Allow and Deny) for the current user
and their group memberships via `AuthorizationRuleCollection`.

#### `file validname path ?pathType?` **(Eagle)**

Validates whether `path` is a syntactically valid filename or path.
Returns a boolean, or with certain flags, returns the reason for invalidity.

**PathType flags:**

| Flag | Description |
|------|-------------|
| `ForceWindows` | Validate using Windows rules regardless of platform |
| `ForceUnix` | Validate using Unix rules regardless of platform |
| `Component` | Validate as a single filename component (no separators) |
| `AllowExtended` | Allow Windows extended paths (`\\?\`) |
| `DisallowExtended` | Reject Windows extended paths |
| `AllowDrive` | Allow drive letters |
| `DisallowDrive` | Reject drive letters |
| `Verify` | Use component-based verification |

```tcl
file validname "good_file.txt"                    ;# 1
file validname "bad:file.txt" ForceWindows        ;# 0 (colon invalid)
file validname "relative/path" Component          ;# 0 (has separator)
file validname "\\?\C:\long\path" AllowExtended   ;# 1
```

#### `file under ?options? parentDir targetPath` **(Eagle)**

Tests whether `targetPath` is located under `parentDir`. Supports pattern
matching for flexible containment checks.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-mode` | `None` | Pattern matching mode (`MatchMode` enum) |
| `-searchoption` | `AllDirectories` | Search option (`SearchOption` enum) |
| `-pathtype` | — | `PathType` enum for validation |
| `-contains` | — | Check containment vs equality |
| `-failonerror` | — | Fail on access errors |

```tcl
file under /usr /usr/local/bin          ;# 1
file under -mode Glob /usr /usr/*/bin   ;# 1
```

### 3.3 File Information and Metadata

#### `file atime name ?time?` **(Enhanced)**

Gets or sets the last access time as Unix epoch seconds (UTC). Setting
access time is an Eagle extension over Tcl.

```tcl
set t [file atime myfile.txt]       ;# Get access time
file atime myfile.txt 1700000000    ;# Set access time
```

Uses `GetDateTimeCallback` / `SetDateTimeCallback` delegates that map to
`File.GetLastAccessTimeUtc` / `File.SetLastAccessTimeUtc`.

#### `file ctime name ?time?` **(Eagle)**

Gets or sets the creation time as Unix epoch seconds (UTC). Tcl does not
expose creation time at all — the `ctime` in Tcl's `[file stat]` is the
inode change time on Unix, not the creation time.

```tcl
set t [file ctime myfile.txt]       ;# Get creation time
file ctime myfile.txt 1700000000    ;# Set creation time
```

Maps to `File.GetCreationTimeUtc` / `File.SetCreationTimeUtc`.

#### `file mtime name ?time?`

Gets or sets the last modification time as Unix epoch seconds (UTC).

#### `file stat name varName`

Stores file status information in the array variable `varName`. Fields
include: `atime`, `ctime`, `dev`, `gid`, `ino`, `mode`, `mtime`, `nlink`,
`size`, `type`, `uid`.

On Windows and Unix, Eagle uses native P/Invoke (`BY_HANDLE_FILE_INFORMATION`
on Windows, `stat` syscall on Unix/macOS) for accurate results.

#### `file lstat name varName`

Like `[file stat]` but does not follow symbolic links. Uses native `lstat`
on Unix/macOS and native file information APIs on Windows.

#### `file attributes name ?option? ?value? ?option value ...?`

Gets or sets file attributes. Without options, returns all attributes as a
list of option-value pairs.

**Attribute options:**

| Option | .NET FileAttributes |
|--------|---------------------|
| `-archive` | Archive |
| `-compressed` | Compressed (read-only) |
| `-directory` | Directory (read-only) |
| `-encrypted` | Encrypted |
| `-hidden` | Hidden |
| `-notcontentindexed` | NotContentIndexed |
| `-offline` | Offline |
| `-readonly` | ReadOnly |
| `-reparsepoint` | ReparsePoint (read-only) |
| `-sparsefile` | SparseFile (read-only) |
| `-system` | System |
| `-temporary` | Temporary |

```tcl
file attributes myfile.txt                     ;# All attributes
file attributes myfile.txt -readonly           ;# Get readonly flag
file attributes myfile.txt -hidden true        ;# Set hidden flag
file attributes myfile.txt -readonly 1 -hidden 1  ;# Set multiple
```

#### `file information ?options? name` **(Eagle, Windows)**

Returns detailed file information as a dictionary, including reparse point
data. Uses native Windows APIs.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-directory` | auto-detect | Hint that path is a directory |
| `-reparse` | `false` | Include reparse point information |

```tcl
file information myfile.txt
;# Returns dict with device, links, index, size, etc.

file information -reparse true junction_point
;# Includes reparse tag and target info
```

#### `file version ?options? name` **(Eagle)**

Returns version information for PE files (executables and DLLs). Uses
.NET's `FileVersionInfo` class.

**Options:**

| Option | Description |
|--------|-------------|
| `-full` | Return complete `FileVersionInfo` via `ToString()` (multi-line) |
| `-fixed` | Return the fixed (semantic) file version |

```tcl
file version myapp.exe             ;# "1.2.3.4"
file version -full myapp.exe       ;# Multi-line FileVersionInfo.ToString() output
file version -fixed mydll.dll      ;# "1.2.3.4" (fixed version)
```

#### `file magic fileName` **(Eagle)**

Extracts the PE magic number and CLR header information from a file. Used
to identify PE file type (32-bit, 64-bit, .NET assembly).

```tcl
file magic myapp.exe   ;# PE magic number and CLR header info
```

### 3.4 Security and Trust

These sub-commands leverage .NET and Windows security infrastructure for
access control and code verification.

#### `file sddl ?options? name ?sddl?` **(Eagle, Windows)**

Gets or sets the Security Descriptor Definition Language (SDDL) string for
a file or directory. SDDL strings encode the complete access control list
(owner, group, DACL, SACL).

**Options:**

| Option | Description |
|--------|-------------|
| `-flags` | `SddlFlags` enum controlling behavior |

**SddlFlags values:**

| Flag | Description |
|------|-------------|
| `IncludeExplicit` | Include explicitly set ACE entries |
| `IncludeInherited` | Include inherited ACE entries |
| `Remove` | Remove specified rights (when setting) |
| `SkipBadRights` | Skip unresolvable rights entries |
| `ToList` | Return as structured list instead of SDDL string |

```tcl
# Get SDDL string
set sddl [file sddl myfile.txt]

# Get as structured list
file sddl -flags ToList myfile.txt

# Set SDDL
file sddl myfile.txt "O:BAG:BAD:(A;;FA;;;SY)(A;;FA;;;BA)"

# Remove specific rights
file sddl -flags Remove myfile.txt "D:(D;;WD;;;WD)"
```

Uses .NET `FileSecurity` / `DirectorySecurity` classes with
`AuthorizationRuleCollection` for ACL evaluation.

#### `file trusted path` **(Eagle)**

Returns `1` if the file at `path` is trusted (has a valid Authenticode
signature or meets the interpreter's trust policy).

```tcl
file trusted signed_assembly.dll   ;# 1
file trusted unsigned.dll          ;# 0
```

#### `file verified path` **(Eagle)**

Returns `1` if the .NET assembly at `path` has strong name verification
enabled and passes verification.

```tcl
file verified MyAssembly.dll   ;# 1 (strong-named and verified)
```

### 3.5 File Operations

These sub-commands modify the filesystem.

#### `file copy ?options? source ?source ...? target`

Copies one or more files to `target`. If multiple sources are given,
`target` must be a directory.

**Options:**

| Option | Description |
|--------|-------------|
| `-force` | Overwrite existing files |

```tcl
file copy original.txt backup.txt
file copy -force src.txt dst.txt          ;# Overwrite
file copy file1.txt file2.txt /dest/dir   ;# Multiple to directory
```

Implementation uses `FileOps.FileCopy()` with move=false.

#### `file rename ?options? source ?source ...? target`

Renames or moves files. Supports multiple sources to a directory target.

**Options:**

| Option | Description |
|--------|-------------|
| `-force` | Overwrite existing files |

```tcl
file rename old.txt new.txt
file rename -force source.txt existing.txt
```

Implementation uses `FileOps.FileCopy()` with move=true.

#### `file delete ?options? file ?file ...?`

Deletes one or more files or directories.

**Options:**

| Option | Description |
|--------|-------------|
| `-recursive` | Delete directory trees (required for non-empty directories) |
| `-force` | Force deletion (clears read-only attributes before deleting) |
| `-nocomplain` | Suppress errors for non-existent files |

```tcl
file delete tempfile.txt
file delete -force -recursive /tmp/builddir
file delete -nocomplain maybe_exists.txt
```

The `-force` option is notable: `FileOps.FileDelete()` clears the
`ReadOnly` attribute before attempting deletion, which is necessary on
Windows where read-only files cannot be deleted without this step.

#### `file mkdir dir ?dir ...?`

Creates one or more directories. Parent directories are created as needed
(equivalent to `mkdir -p`).

```tcl
file mkdir /tmp/new/nested/dir   ;# Creates all intermediate dirs
```

#### `file rmdir dir ?dir ...?` **(Eagle)**

Removes one or more **empty** directories. Not available in standard Tcl
(Tcl uses `[file delete]` for directories).

```tcl
file rmdir /tmp/emptydir
```

#### `file touch path` **(Eagle)**

Creates an empty file if `path` does not exist, or updates its timestamps
if it does. Equivalent to the Unix `touch` command.

```tcl
file touch newfile.txt       ;# Create empty file
file touch existing.txt      ;# Update timestamps
```

Implementation: `FileOps.Touch()` opens/creates the file and immediately
closes it.

### 3.6 Directory Listing and Globbing

#### `file channels ?pattern?`

Lists open I/O channel identifiers in the current interpreter. With
`pattern`, filters by glob match.

```tcl
file channels          ;# {stdin stdout stderr channel0 ...}
file channels file*    ;# Channels matching "file*"
```

#### `file list ?directory? ?pattern?` **(Eagle)**

Lists directory contents, optionally filtered by a glob pattern. Simpler
alternative to `[file glob]` for basic directory listing.

```tcl
file list                    ;# Current directory contents
file list /usr/local/bin     ;# List specific directory
file list /tmp *.txt         ;# Filter by pattern
```

#### `file glob ?options? ?pattern?` **(Eagle)**

Advanced file globbing with extensive options beyond Tcl's standalone
`[glob]` command.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-nocomplain` | — | Return empty list on no matches (vs error) |
| `-noresolve` | — | Don't resolve relative paths to absolute |
| `-novalidate` | — | Skip directory existence validation |
| `-match` | `Glob` | Match mode: `Exact`, `Glob`, `Regexp`, `SubString` |
| `-nocase` | — | Case-insensitive matching |
| `-directory` | current | Search directory |
| `-searchpattern` | — | .NET `SearchPattern` for pre-filtering |

The `-match` option accepts any value from Eagle's `MatchMode` enumeration,
allowing regex or substring matching in addition to standard glob patterns.

```tcl
# Standard glob
file glob -directory /tmp *.txt

# Regex matching
file glob -match Regexp -directory /src {.*\.cs$}

# Case-insensitive substring
file glob -match SubString -nocase -directory /docs readme
```

**Glob pattern features:**

- Standard wildcards: `*`, `?`, `[chars]`
- Brace expansion: `{a,b,c}` patterns
- Dotfile handling: leading dots are not matched by `*` by default
- Special entries `.` and `..` conditionally included
- File attribute filtering (Hidden, System, etc.)

#### `[file volumes]`

Returns a list of mounted filesystem volumes.

```tcl
file volumes   ;# {C:/ D:/ E:/} (Windows) or {/} (Unix)
```

### 3.7 Temporary File Management

#### `[file tempname]` **(Eagle)**

Returns a unique temporary filename. Eagle uses .NET's
`Path.GetRandomFileName()` for name generation and supports
interpreter-specific temp path callbacks.

```tcl
set tmp [file tempname]   ;# /tmp/esc_xxxxxxxx.xxxx (random)
```

**Generation algorithm:**

1. Get temp directory via `PathOps.GetTempPath()` (see environment
   variable precedence below)
2. Generate a random filename using `Path.GetRandomFileName()`
3. Prepend the prefix `"esc_"` (Eagle Script Command)
4. Combine with the temp directory path

#### `[file temppath]` **(Eagle)**

Returns the system temporary directory path. Eagle checks multiple
environment variables in a defined precedence order.

```tcl
set tmp [file temppath]   ;# /tmp (Unix) or C:\Users\...\Temp (Windows)
```

**Environment variable precedence:**

| Priority | Variable | Description |
|----------|----------|-------------|
| 1 | `EAGLE_TEST_TEMP` | Test-specific temp directory |
| 2 | `EAGLE_TEMP` | Eagle-specific temp directory |
| 3 | `XDG_RUNTIME_DIR` | XDG runtime directory (Unix) |
| 4 | `TEMP` | System temp (standard) |
| 5 | `TMP` | System temp (fallback) |
| 6 | `Path.GetTempPath()` | .NET system default |

Each candidate directory is verified for write access before being
selected. If a directory fails verification, the next candidate is tried.

**Sub-path support:** Eagle can optionally use a subdirectory within the
temp directory (defaulting to the package filename) to isolate temporary
files per application.

**Callback hooks:** Both `GetTempFileName` and `GetTempPath` support
callback hooks (`GetStringValueCallback`) that allow test frameworks or
embedders to override the default behavior.

### 3.8 Interpreter Cleanup Management

#### `file cleanup ?options? ?path?` **(Eagle)**

Registers a path for automatic cleanup when the interpreter shuts down, or
manages the cleanup list. This is Eagle's mechanism for ensuring temporary
files and directories are removed during interpreter disposal.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-type` | `Cleanup` | Path type category |
| `-pattern` | — | Glob pattern for listing/filtering |
| `-nocase` | — | Case-insensitive pattern matching |
| `-recursive` | — | Recursive directory cleanup |
| `-force` | — | Force cleanup (clear read-only) |
| `-nocomplain` | — | Suppress errors during cleanup |
| `-now` | — | Execute cleanup immediately |

```tcl
# Register a temp file for cleanup
file cleanup /tmp/mytemp.txt

# Register with recursive directory deletion
file cleanup -recursive -force /tmp/mybuilddir

# Execute cleanup immediately
file cleanup -now

# List registered cleanup paths matching pattern
file cleanup -pattern *.tmp
```

When the interpreter is disposed, all registered cleanup paths are
processed: files are deleted and directories are removed (recursively if
registered with `-recursive`).

### 3.9 System Information

#### `file system name` **(Eagle)**

Returns filesystem type information for the volume containing `name`.
The result is a list prefixed with `native` (since Eagle has no VFS
support), followed by the drive format string.

```tcl
file system C:\   ;# {native NTFS} (Windows)
```

#### `file objectid ?options? name` **(Eagle, Windows)**

Returns the Windows file object ID (MFT file reference number). Can
optionally create an object ID if one does not exist.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-directory` | auto-detect | Hint that path is a directory |
| `-create` | `false` | Create object ID if missing |

```tcl
file objectid myfile.txt                ;# Existing object ID
file objectid -create true newfile.txt  ;# Create if missing
```

---

## 4. Callback Infrastructure

The `[file]` command uses two callback delegate types for timestamp
operations, defined in `Delegates.cs`:

```tcl
GetDateTimeCallback(string path) -> DateTime
SetDateTimeCallback(string path, DateTime dateTime) -> void
```

### Callback dictionary

At construction time (`File.cs` lines 72-99), the command builds two
static dictionaries mapping operation names to .NET methods:

| Key | Get callback | Set callback |
|-----|-------------|-------------|
| `file.atime` | `File.GetLastAccessTimeUtc` | `File.SetLastAccessTimeUtc` |
| `file.ctime` | `File.GetCreationTimeUtc` | `File.SetCreationTimeUtc` |
| `file.mtime` | `File.GetLastWriteTimeUtc` | `File.SetLastWriteTimeUtc` |
| `directory.atime` | `Directory.GetLastAccessTimeUtc` | `Directory.SetLastAccessTimeUtc` |
| `directory.ctime` | `Directory.GetCreationTimeUtc` | `Directory.SetCreationTimeUtc` |
| `directory.mtime` | `Directory.GetLastWriteTimeUtc` | `Directory.SetLastWriteTimeUtc` |

The lookup key is constructed as `FormatOps.QualifiedName(fileType, subCommand)`
-- for example, if the path is a directory and the sub-command is `mtime`,
the key becomes `"directory.mtime"`, selecting `Directory.GetLastWriteTimeUtc`.

### Temporary path callbacks

`PathOps` provides two hook points for overriding temp file behavior:

- `GetStringValueCallback getTempFileNameCallback` -- override
  `[file tempname]` generation
- `GetStringValueCallback getTempPathCallback` -- override
  `[file temppath]` resolution

These allow test frameworks or embedders to redirect temporary files to
controlled locations.

---

## 5. Access Control Infrastructure

Eagle implements a three-tier access verification system in `FileOps.cs`:

### Tier 1 -- Simple verification methods

`VerifyExecutable()`, `VerifyReadable()`, `VerifyWritable()` are the
entry points called by `[file executable]`, `[file readable]`, `[file writable]`.

On Windows (non-Mono), these delegate to Tier 2. On other platforms, they
fall back to Tier 3.

### Tier 2 -- Generic path access

`VerifyPathAccess()` dispatches to file or directory verification based
on the path type, using `FileAccess.Read`, `FileAccess.Write`, or
`FileAccess.ReadWrite`.

### Tier 3 -- Detailed ACL evaluation

`AccessCheck()` performs full Windows ACL evaluation:

1. Retrieves the `AuthorizationRuleCollection` from `FileSecurity` or
   `DirectorySecurity`
2. Gets the current `WindowsIdentity` and all group SIDs
3. Iterates all `FileSystemAccessRule` entries
4. Applies Allow/Deny logic per user and group membership
5. Validates that all desired rights are granted

### Write access fallback

When ACL evaluation is not available (Mono, .NET Standard, non-Windows),
`FileOps` uses a pragmatic fallback: it creates a unique temporary
file/directory in the target location, verifies the operation succeeded,
and immediately cleans up.

---

## 6. Glob Implementation

Eagle's `[file glob]` is implemented in `FileOps.GlobFiles()` and supports
features beyond Tcl's standalone `[glob]` command.

### Pattern features

- **Standard wildcards**: `*`, `?`, `[charclass]`
- **Brace expansion**: `{a,b,c}` via `SplitGlobSubPatterns()`
- **MatchMode selection**: `Exact`, `Glob`, `Regexp`, `SubString`
  (configurable via `-match`)
- **Dotfile handling**: leading-dot files are not matched by `*` by
  default (Tcl-compatible behavior)
- **Attribute filtering**: file type and attribute bits are checked
  against the types dictionary

### Attribute filtering

The glob implementation checks `FileAttributes` against a filter
dictionary that maps attribute names to inclusion/exclusion flags. The
following attributes are recognized:

`ReadOnly`, `Hidden`, `System`, `Directory`, `Archive`, `Device`,
`Normal`, `Temporary`, `SparseFile`, `ReparsePoint`, `Compressed`,
`Offline`, `NotContentIndexed`, `Encrypted`

Synthetic attributes are also supported for Tcl compatibility.

### Search pattern optimization

The `-searchpattern` option passes a .NET `SearchPattern` directly to
`Directory.GetFiles()` / `Directory.GetDirectories()`, allowing the
operating system to perform initial filtering before Eagle applies the
full pattern match.

---

## 7. Platform-Specific Behavior

### Windows

| Feature | Implementation |
|---------|---------------|
| ACL/SDDL | `FileSecurity`, `DirectorySecurity`, `AuthorizationRuleCollection` |
| Ownership | `WindowsIdentity.GetCurrent()`, `GetOwner(typeof(SecurityIdentifier))` |
| Object IDs | Native FSCTL via P/Invoke |
| File info | `BY_HANDLE_FILE_INFORMATION` structure via P/Invoke |
| Drive info | `DriveInfo` class |
| Path format | Backslash separators, drive letters, UNC paths, extended paths (`\\?\`) |

### Unix / macOS

| Feature | Implementation |
|---------|---------------|
| stat/lstat | P/Invoke to `stat`/`lstat` syscalls |
| Linux | `__xstat` / `__lxstat` variants |
| macOS | `stat` / `lstat` with `timespec` structures |
| File mode | Full mode word parsing (permissions, file type bits) |
| Path format | Forward slash separators, tilde expansion |
| XDG support | `XDG_RUNTIME_DIR` in temp path resolution |

### Mono

| Consideration | Handling |
|---------------|----------|
| ACL not available | Falls back to temp-file write test |
| StreamReader internals | Field name variations handled in `FileOps` |
| I/O exceptions | Mono 4.x/5.x exception handling workarounds |

### Conditional compilation guards

The source uses these preprocessor symbols for platform-specific code:

| Symbol | Scope |
|--------|-------|
| `NATIVE` | Enable native P/Invoke code |
| `WINDOWS` | Windows-specific features |
| `UNIX` | Unix/macOS features |
| `MONO` | Mono runtime workarounds |
| `NET_STANDARD_20` | .NET Standard 2.0 compatibility |

---

## 8. Safe Interpreter Restrictions

The `[file]` command is marked with `CommandFlags.Unsafe | CommandFlags.Critical`
and enforces sub-command filtering in safe interpreters via the
`AllowedSubCommands` property, which delegates to
`PolicyOps.AllowedFileSubCommandNames`.

### Restricted sub-commands

In a safe interpreter, only a subset of `[file]` sub-commands are available.
Operations that modify the filesystem, access security information, or
reveal system details are blocked:

- **Blocked categories**: all sub-commands not explicitly listed below
- **Allowed sub-commands**: `channels`, `dirname`, `[join]`, `[split]`,
  `validname`

The exact set of allowed sub-commands is determined by
`PolicyOps.AllowedFileSubCommandNames` and can be customized via the
interpreter's policy system.

### Path validation

Even for allowed sub-commands, safe interpreters apply additional path
validation to prevent directory traversal attacks:

- `PathOps.ResolveFullPath()` resolves paths to absolute form
- Path existence checks via `PathOps.PathExists()` before operations
- Exception results are sanitized to avoid information leakage

---

## 9. File Operations Internals

### Copy and move

`FileOps.FileCopy()` handles both copy and rename operations through a
`move` parameter:

1. If multiple source files are given, the target must be an existing
   directory
2. For single-file operations, the target can be a file or directory
3. With `-force`, existing files are overwritten
4. Without `-force`, existing targets raise an error
5. Move operations use `File.Move()` (atomic on same volume) or
   copy-then-delete (cross-volume)

### Delete

`FileOps.FileDelete()` processes each path:

1. Determine if path is a file or directory
2. For files:
   - If `-force`: clear `ReadOnly` attribute, then delete
   - Otherwise: delete directly (fails if read-only)
3. For directories:
   - If `-recursive`: recursively clear read-only attributes on all
     contained files, then `Directory.Delete(path, true)`
   - Otherwise: attempt `Directory.Delete(path, false)` (fails if
     non-empty)
4. If `-nocomplain`: catch and suppress exceptions

### Timestamp operations

`FileOps.GetFileTime()` and `FileOps.SetFileTime()` use the callback
delegates:

1. Determine if path is a file or directory
2. Construct the callback key (e.g., `"file.mtime"` or `"directory.mtime"`)
3. Look up the appropriate callback in the static dictionary
4. Invoke the callback, converting between Unix epoch seconds and .NET
   `DateTime` (UTC)

---

## 10. Practical Patterns

### Pattern 1 -- Safe temporary file workflow

```tcl
# Get a unique temp file
set tmp [file tempname]

# Write content
set f [open $tmp w]
puts $f "temporary data"
close $f

# Register for automatic cleanup
file cleanup $tmp

# ... use the file ...
# Cleanup happens automatically when interpreter disposes
```

### Pattern 2 -- Recursive directory deletion with force

```tcl
# Remove an entire build directory, even with read-only files
file delete -force -recursive /tmp/build_output
```

### Pattern 3 -- Cross-platform path construction

```tcl
# Join paths portably
set config [file join [file temppath] myapp config.ini]
set normalized [file normalize $config]
set native [file nativename $normalized]
```

### Pattern 4 -- File attribute inspection and modification

```tcl
# Check all attributes
set attrs [file attributes myfile.txt]

# Make a file hidden and read-only
file attributes myfile.txt -hidden true -readonly true

# Clear read-only before modification
file attributes myfile.txt -readonly false
```

### Pattern 5 -- Windows security descriptor management

```tcl
# Get SDDL string
set sddl [file sddl important_file.dat]

# Get as structured list for programmatic access
set acl [file sddl -flags ToList important_file.dat]

# Check specific access rights
set rights [file rights important_file.dat]
if {[lsearch $rights GenericWrite] >= 0} {
    puts "File is writable"
}
```

### Pattern 6 -- File type detection and validation

```tcl
# Validate a path before use
if {![file validname $userInput Component]} {
    error "invalid filename"
}

# Check PE file type
set magic [file magic $dllPath]

# Verify assembly trust
if {[file trusted $assembly] && [file verified $assembly]} {
    load $assembly
}
```

### Pattern 7 -- Advanced globbing with regex

```tcl
# Find all C# source files matching a pattern
set files [file glob -match Regexp -directory /src {.*Controller\.cs$}]

# Case-insensitive search for readme files
set readmes [file glob -match SubString -nocase -directory /project readme]

# Standard glob with no-complain
set logs [file glob -nocomplain -directory /var/log *.log]
```

### Pattern 8 -- Ownership and access verification

```tcl
# Check ownership (verbose)
set info [file owned sensitive.dat true]
puts "Owner: [lindex $info 3]"

# Verify access before operation
if {[file readable $path] && [file writable $path]} {
    # Safe to read and modify
}
```

### Pattern 9 -- Timestamp manipulation

```tcl
# Preserve timestamps during copy
set atime [file atime original.txt]
set mtime [file mtime original.txt]
file copy original.txt backup.txt
file atime backup.txt $atime
file mtime backup.txt $mtime
```

### Pattern 10 -- Directory containment check

```tcl
# Verify a path is within an allowed directory
if {![file under /safe/base $userPath]} {
    error "path outside allowed directory"
}

# Recursive containment with pattern
if {[file under -mode Glob -searchoption AllDirectories /project $path]} {
    # Path is somewhere under /project
}
```

---

## 11. Comparison with Tcl

| Feature | Tcl `[file]` | Eagle `[file]` |
|---------|-----------|-------------|
| Path manipulation | dirname, tail, rootname, extension, join, split, normalize, nativename, separator, pathtype | Same + `rootpath`, `drive`, `tildeexpand`, `validname` |
| File tests | exists, isdirectory, isfile, readable, writable, executable, type | Same + `same`, `owned`, `rights`, `under` |
| Timestamps | mtime (get/set), atime (get only) | atime/ctime/mtime all get/set |
| Attributes | `[file attributes]` (platform-specific) | `[file attributes]` with 12 .NET `FileAttributes` options |
| Security | Basic permissions | ACL evaluation, SDDL get/set, ownership, trusted/verified |
| Stat/lstat | `[file stat]`, `[file lstat]` | Same (native P/Invoke on all platforms) |
| File operations | copy, rename, delete, mkdir | Same + `rmdir`, `touch` |
| Globbing | Separate `[glob]` command | `[file glob]` with `MatchMode` (Exact, Glob, Regexp, SubString) |
| Directory listing | `glob -directory` | `[file list]` (simpler) + `[file glob]` (advanced) |
| Temporary files | `file tempfile` (8.6+) | `tempname`, `temppath` with env precedence |
| PE inspection | None | `magic`, `[version]` |
| System info | None | `system`, `objectid`, `information`, `drive`, `volumes` |
| Cleanup | Manual | `[file cleanup]` with interpreter lifecycle |
| Channels | `[file channels]` | Same |

---

## 12. Security Considerations

### Path traversal

- All path arguments are validated before use
- Safe interpreters apply `PathOps.ResolveFullPath()` to prevent
  directory traversal via `..` components
- `[file validname]` should be used to validate user-supplied filenames

### Race conditions (TOCTOU)

- `[file exists]` followed by `[file delete]` is subject to time-of-check-
  time-of-use races, as in any filesystem API
- For critical operations, use error handling (`[catch]`) rather than
  pre-checking existence

### Information leakage

- `[file information]`, `[file sddl]`, `[file objectid]`, and `[file magic]`
  can reveal system details
- These are blocked in safe interpreters
- Exception messages are sanitized in safe mode

### Temporary file security

- `[file tempname]` uses .NET's `Path.GetRandomFileName()` for generating
  unique filenames
- Generated names are verified non-existent before returning
- The `EAGLE_TEST_TEMP` and `EAGLE_TEMP` environment variables allow
  controlled redirection of temp files

### Trust verification

- `[file trusted]` checks Authenticode signatures
- `[file verified]` checks .NET strong name verification
- Both should be used before loading untrusted assemblies via `[load]`

---

## 13. References

- **Source**: `eagle/Eagle/Library/Commands/File.cs` -- command implementation
- **File operations**: `eagle/Eagle/Library/Components/Private/FileOps.cs`
- **Path operations**: `eagle/Eagle/Library/Components/Private/PathOps.cs`
- **Delegates**: `eagle/Eagle/Library/Components/Public/Delegates.cs` --
  `GetDateTimeCallback`, `SetDateTimeCallback`
- **Core language reference**: `core_language.md` -- String Processing -->
  `[file]` command
- **Examples**: `core_examples.md` -- file
- **Tcl reference**: [Tcl `[file]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/file.htm)
