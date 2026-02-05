# Eagle Script Library

This document provides comprehensive documentation for all script procedures in the Eagle scripting language libraries, organized by package and functional category.

## Table of Contents

- [Overview](#overview)
- [Eagle1.0 Library](#eagle10-library)
  - [Initialization (init.eagle)](#initialization-initeagle)
  - [Auxiliary Utilities (auxiliary.eagle)](#auxiliary-utilities-auxiliaryeagle)
  - [Tcl Compatibility (compat.eagle)](#tcl-compatibility-compateagle)
  - [Database Utilities (database.eagle)](#database-utilities-daborteagle)
  - [List Utilities (list.eagle)](#list-utilities-listeagle)
  - [Platform Detection (platform.eagle)](#platform-detection-platformeagle)
  - [File I/O - Basic (file1.eagle)](#file-io---basic-file1eagle)
  - [File I/O - Types (file2.eagle)](#file-io---types-file2eagle)
  - [File I/O - Unicode (file2u.eagle)](#file-io---unicode-file2ueagle)
  - [File Finder (file3.eagle)](#file-finder-file3eagle)
  - [Execution Utilities (exec.eagle)](#execution-utilities-execeagle)
  - [Information Utilities (info.eagle)](#information-utilities-infoeagle)
  - [Object Utilities (object.eagle)](#object-utilities-objecteagle)
  - [Process Management (process.eagle)](#process-management-processeagle)
  - [Runtime Options (runopt.eagle)](#runtime-options-runopteagle)
  - [Test Logging (testlog.eagle)](#test-logging-testlogeagle)
  - [ZIP Extraction (unzip.eagle)](#zip-extraction-unzipeagle)
  - [Software Updates (update.eagle)](#software-updates-updateeagle)
  - [Unknown Object Handler (unkobj.eagle)](#unknown-object-handler-unkobjeagle)
  - [C# Compilation (csharp.eagle)](#c-compilation-csharpeagle)
  - [Safe Interpreter (safe.eagle)](#safe-interpreter-safeeagle)
  - [Interactive Shell (shell.eagle)](#interactive-shell-shelleagle)
  - [Tcl Shim (shim.eagle)](#tcl-shim-shimeagle)
  - [Package Toolset (pkgt.eagle)](#package-toolset-pkgteagle)
  - [Test Framework (test.eagle)](#test-framework-testeagle)
- [Test1.0 Library](#test10-library)
  - [Test Constraints (constraints.eagle)](#test-constraints-constraintseagle)
- [System Aliases](#system-aliases)

---

## Overview

The Eagle script library is organized into two main packages:

1. **Eagle1.0** - Core library containing utility procedures for file I/O, platform detection, .NET interop, process management, and more. These procedures work in both Eagle and native Tcl where applicable.

2. **Test1.0** - Test framework library containing constraint checking procedures for the Eagle test suite.

### Namespace Convention

All procedures are defined in the `::Eagle` namespace to avoid polluting the global namespace. Most procedures are exported and imported into the global namespace for convenient access.

### Tcl/Eagle Compatibility

Many procedures are designed to work in both Eagle and native Tcl. Procedures use `isEagle` to detect the runtime environment and adapt their behavior accordingly.

---

## Eagle1.0 Library

### Initialization (init.eagle)

The initialization file bootstraps the Eagle script library and defines core procedures.

#### isEagle

```tcl
isEagle
```

Detects whether the script is running in Eagle or vanilla Tcl.

- **Returns**: Non-zero if running in Eagle, zero if running in Tcl.
- **Note**: This is a bootstrap procedure that must work in both interpreters. It checks for the presence of `::tcl_platform(engine)` set to "eagle".

- **Example**:
```tcl
if {[isEagle]} {
    puts "Running in Eagle"
} else {
    puts "Running in Tcl"
}
```

---

#### loadGarudaForUseByEagle

```tcl
loadGarudaForUseByEagle {machine ""} {configuration ""} {suffix ""} {methodFlags true} {noNormalize true} {quiet false}
```

Loads the native Tcl library, enables command bridging, and loads the Eagle Native Package for Tcl (Garuda).

- **Arguments**:
  - `machine` - Target machine architecture (optional, auto-detected)
  - `configuration` - Build configuration (optional, auto-detected)
  - `suffix` - Test suffix (optional)
  - `methodFlags` - Garuda method flags (default: true for METHOD_PROTOCOL_V1R2)
  - `noNormalize` - Avoid Tcl junction bug (default: true)
  - `quiet` - Suppress logging (default: false)
- **Returns**: Empty string on success.
- **Note**: This procedure can fail if native Tcl or Garuda is not available.

---

#### loadScripts

```tcl
loadScripts directory fileNamesOnly
```

Sources other script files that belong to the package.

- **Arguments**:
  - `directory` - Directory containing scripts (uses `$tcl_library` if empty)
  - `fileNamesOnly` - List of script file names to load
- **Returns**: Empty string on success.
- **Note**: In Eagle, uses `-withinfo` and `-library` options to preserve procedure location information.

---

#### maybeLoadScripts

```tcl
maybeLoadScripts directory fileNamesOnly
```

Like `loadScripts`, but skips files that have been explicitly forbidden via `::no($fileNameOnly)`.

- **Arguments**:
  - `directory` - Directory containing scripts
  - `fileNamesOnly` - List of script file names to load
- **Returns**: Empty string on success.

---

#### sourceWithInfo (Eagle only)

```tcl
sourceWithInfo args
```

Sources a script file while preserving location information for procedures defined within it.

- **Arguments**: Same as the `source` command
- **Returns**: Result of the sourced script.
- **Note**: Eagle-only. Manages argument caching and location tracking.

---

#### unknown

```tcl
unknown name args
```

The unknown command handler executed when a command is not found.

- **Arguments**:
  - `name` - The unknown command name
  - `args` - Arguments passed to the command
- **Returns**: Error with "invalid command name" message.
- **Note**: If the `eagleUnknownObjectInvoke` runtime option is set, attempts to use the command name as a CLR type name first.

---

#### tclPkgUnknown

```tcl
tclPkgUnknown name args
```

Package unknown handler that forces a rescan of package indexes.

- **Arguments**:
  - `name` - The requested package name
  - `args` - Additional arguments
- **Returns**: Empty string.
- **Note**: Called by the package management subsystem when a package cannot be found.

---

#### makeProcedureFast (Eagle only, experimental)

```tcl
makeProcedureFast name fast
```

Marks a procedure for "fast" execution by disabling variable access overhead.

- **Arguments**:
  - `name` - Procedure name
  - `fast` - Boolean to enable/disable fast mode
- **Returns**: Empty string.

---

#### makeVariableFast (Eagle only, experimental)

```tcl
makeVariableFast name fast
```

Marks a variable for "fast" access by disabling access overhead.

- **Arguments**:
  - `name` - Variable name
  - `fast` - Boolean to enable/disable fast mode
- **Returns**: Empty string.

---

### Auxiliary Utilities (auxiliary.eagle)

Package: `Eagle.Auxiliary`

#### getEnvironmentVariable

```tcl
getEnvironmentVariable name
```

Returns the value of an environment variable, or empty string if it doesn't exist.

- **Arguments**:
  - `name` - Environment variable name
- **Returns**: The environment variable value or empty string.

- **Example**:
```tcl
set home [getEnvironmentVariable HOME]
set path [getEnvironmentVariable PATH]
```

---

#### appendArgs

```tcl
appendArgs args
```

Appends all arguments into one string verbatim, avoiding undesired string interpolation.

- **Arguments**: Any number of arguments
- **Returns**: Concatenated string.

- **Example**:
```tcl
set result [appendArgs "Hello, " $name "!"]
# Equivalent to: set result "Hello, ${name}!"
```

---

#### getDictionaryValue

```tcl
getDictionaryValue dictionary name {default ""} {wrap ""}
```

Finds and returns a named value from a dictionary (list of name-value pairs).

- **Arguments**:
  - `dictionary` - List in format `{name1 value1 name2 value2 ...}`
  - `name` - Name to search for
  - `default` - Default value if not found
  - `wrap` - String to wrap around the value
- **Returns**: The found value (optionally wrapped) or the default.

- **Example**:
```tcl
set dict {color red size large}
set color [getDictionaryValue $dict color "unknown"]  ;# Returns: red
set shape [getDictionaryValue $dict shape "circle"]   ;# Returns: circle
```

---

#### exportAndImportPackageCommands

```tcl
exportAndImportPackageCommands namespace exports forget force
```

Exports commands from a namespace and imports them into the global namespace.

- **Arguments**:
  - `namespace` - Source namespace
  - `exports` - List of command names to export
  - `forget` - If true, forget previous imports first
  - `force` - If true, overwrite existing commands
- **Returns**: Empty string.

---

### Tcl Compatibility (compat.eagle)

Package: `Eagle.Tcl.Compatibility`

#### getHostSize

```tcl
getHostSize
```

Returns the host console size in columns and rows.

- **Returns**: List `{columns rows}`, defaults to `{80 25}` if unavailable.

---

#### parray

```tcl
parray a ?pattern?
```

Prints the contents of an array to stdout, emulating the native Tcl `parray` procedure.

- **Arguments**:
  - `a` - Array name
  - `pattern` - Optional glob pattern to filter names
- **Returns**: Empty string (output goes to stdout).

- **Example**:
```tcl
array set data {name "John" age 30 city "NYC"}
parray data
# Output:
# data(age)  = 30
# data(city) = NYC
# data(name) = John
```

---

#### pdict

```tcl
pdict d
```

Prints the contents of a dictionary to stdout.

- **Arguments**:
  - `d` - Dictionary (list of name-value pairs)
- **Returns**: Empty string (output goes to stdout).

---

#### test

```tcl
test name description args
```

Emulates the native Tcl `test` command from the tcltest package. Automatically detects old-style vs new-style tests.

- **Arguments**:
  - `name` - Test name
  - `description` - Test description
  - `args` - Test arguments (constraints, body, result, etc.)
- **Returns**: Test result.
- **Note**: Delegates to `test1` (old-style) or `test2` (new-style) based on argument format.

---

#### tclLog

```tcl
tclLog string
```

Emulates the native Tcl `tclLog` command by writing to stderr.

- **Arguments**:
  - `string` - Message to log
- **Returns**: Empty string.

---

### Database Utilities (database.eagle)

Package: `Eagle.Database`

#### haveColumnValue

```tcl
haveColumnValue row column
```

Checks if a database column exists within a row.

- **Arguments**:
  - `row` - Database row (list of `{columnName value}` pairs)
  - `column` - Column name to find
- **Returns**: Non-zero if the column exists.

---

#### haveRowColumnValue

```tcl
haveRowColumnValue varName id column
```

Checks if a column exists within a specific row in an array of rows.

- **Arguments**:
  - `varName` - Name of array variable containing rows
  - `id` - Row identifier (array index)
  - `column` - Column name to find
- **Returns**: Non-zero if the column exists in the specified row.

---

#### getColumnValue

```tcl
getColumnValue row column {default ""} {wrap ""}
```

Gets the value of a database column from a row.

- **Arguments**:
  - `row` - Database row (list of `{columnName value}` pairs)
  - `column` - Column name
  - `default` - Default value if column not found
  - `wrap` - String to wrap around the value
- **Returns**: Column value or default.

- **Example**:
```tcl
set row {{name "John"} {age 30}}
set name [getColumnValue $row name "Unknown"]  ;# Returns: John
set city [getColumnValue $row city "N/A"]      ;# Returns: N/A
```

---

#### getRowColumnValue

```tcl
getRowColumnValue varName id column {default ""} {wrap ""}
```

Gets a column value from a specific row in an array of rows.

- **Arguments**:
  - `varName` - Name of array variable containing rows
  - `id` - Row identifier (array index)
  - `column` - Column name
  - `default` - Default value if not found
  - `wrap` - String to wrap around the value
- **Returns**: Column value or default.

---

### List Utilities (list.eagle)

Package: `Eagle.List`

#### lappendArgs

```tcl
lappendArgs args
```

Appends all arguments as list elements and returns the resulting list.

- **Arguments**: Any number of arguments
- **Returns**: A list containing all arguments.

- **Example**:
```tcl
set items [lappendArgs "a" "b" "c"]  ;# Returns: {a b c}
```

---

#### lshuffle

```tcl
lshuffle list
```

Pseudo-randomly shuffles a list using the Fisher-Yates algorithm.

- **Arguments**:
  - `list` - List to shuffle
- **Returns**: Shuffled list.

- **Example**:
```tcl
set cards {1 2 3 4 5}
set shuffled [lshuffle $cards]  ;# e.g., {3 1 5 2 4}
```

---

#### ldifference

```tcl
ldifference list1 list2
```

Returns elements present in one list but not the other (symmetric difference).

- **Arguments**:
  - `list1` - First list
  - `list2` - Second list
- **Returns**: List of elements unique to either list.

- **Example**:
```tcl
set a {1 2 3 4}
set b {3 4 5 6}
set diff [ldifference $a $b]  ;# Returns: {1 2 5 6}
```

---

#### filter

```tcl
filter list script
```

Returns elements from the list for which the script returns non-zero.

- **Arguments**:
  - `list` - List to filter
  - `script` - Script that receives each element and returns a boolean
- **Returns**: Filtered list.

- **Example**:
```tcl
set numbers {1 2 3 4 5 6}
set evens [filter $numbers {expr {$item % 2 == 0}}]  ;# Returns: {2 4 6}
```

---

#### map

```tcl
map list script
```

Applies a transformation script to each list element.

- **Arguments**:
  - `list` - List to transform
  - `script` - Script that receives each element and returns transformed value
- **Returns**: Transformed list.

- **Example**:
```tcl
set numbers {1 2 3 4}
set doubled [map $numbers {expr {$item * 2}}]  ;# Returns: {2 4 6 8}
```

---

#### reduce

```tcl
reduce list script
```

Reduces a list to a single value by applying a script cumulatively.

- **Arguments**:
  - `list` - List to reduce
  - `script` - Script receiving `result` and `item`, returns accumulated value
- **Returns**: Final accumulated value.

- **Example**:
```tcl
set numbers {1 2 3 4 5}
set sum [reduce $numbers {expr {$result + $item}}]  ;# Returns: 15
```

---

### Platform Detection (platform.eagle)

Package: `Eagle.Platform`

#### isEagle

```tcl
isEagle
```

Detects if running in Eagle (vs Tcl).

- **Returns**: Non-zero if Eagle, zero if Tcl.

---

#### isMono

```tcl
isMono
```

Detects if running in Eagle on the Mono runtime.

- **Returns**: Non-zero if running on Mono.

---

#### isDotNetCore

```tcl
isDotNetCore
```

Detects if running in Eagle on .NET Core (or .NET 5+).

- **Returns**: Non-zero if running on .NET Core.

---

#### isAdministrator

```tcl
isAdministrator
```

Checks if the current user has administrator privileges.

- **Returns**: Non-zero if administrator.
- **Note**: Currently only works in Eagle.

---

#### isWindows

```tcl
isWindows
```

Detects if running on Windows.

- **Returns**: Non-zero if Windows.

---

#### isMacOS

```tcl
isMacOS
```

Detects if running on macOS (Darwin).

- **Returns**: Non-zero if macOS.

---

#### isInteractive

```tcl
isInteractive
```

Checks if there is an interactive user who can respond to prompts.

- **Returns**: Non-zero if interactive.

---

#### foundInPath

```tcl
foundInPath dirs dir
```

Checks if a directory is in a list of directories (case-insensitive on Windows).

- **Arguments**:
  - `dirs` - List of directories
  - `dir` - Directory to find
- **Returns**: Boolean.

---

#### addToPath

```tcl
addToPath dir
```

Adds a directory to the system PATH (or LD_LIBRARY_PATH on Unix).

- **Arguments**:
  - `dir` - Directory to add
- **Returns**: Non-zero if the path was modified.

---

#### removeFromPath

```tcl
removeFromPath dir
```

Removes a directory from the system PATH.

- **Arguments**:
  - `dir` - Directory to remove
- **Returns**: Non-zero if the path was modified.

---

#### isSameFileName

```tcl
isSameFileName fileName1 fileName2
```

Compares two file names for equality using the most robust method available.

- **Arguments**:
  - `fileName1` - First file name
  - `fileName2` - Second file name
- **Returns**: Non-zero if the files are the same.
- **Note**: Uses `file same` in Eagle, string comparison in Tcl (case-insensitive on Windows).

---

### File I/O - Basic (file1.eagle)

Package: `Eagle.File`

#### makeBinaryChannel

```tcl
makeBinaryChannel channel
```

Reconfigures a channel for full binary mode.

- **Arguments**:
  - `channel` - Channel identifier
- **Returns**: Empty string.

---

#### readFile

```tcl
readFile fileName
```

Reads all data from a binary file.

- **Arguments**:
  - `fileName` - Path to file
- **Returns**: File contents as binary data.

- **Example**:
```tcl
set data [readFile "image.png"]
```

---

#### writeFile

```tcl
writeFile fileName data
```

Writes data to a binary file (overwrites existing content).

- **Arguments**:
  - `fileName` - Path to file
  - `data` - Data to write
- **Returns**: Empty string.

---

#### appendFile

```tcl
appendFile fileName data
```

Appends data to a binary file.

- **Arguments**:
  - `fileName` - Path to file
  - `data` - Data to append
- **Returns**: Empty string.

---

### File I/O - Types (file2.eagle)

Package: `Eagle.File.Types`

#### makeAsciiChannel

```tcl
makeAsciiChannel channel
```

Reconfigures a channel for ASCII mode with auto line-ending translation.

- **Arguments**:
  - `channel` - Channel identifier
- **Returns**: Empty string.

---

#### readAsciiFile

```tcl
readAsciiFile fileName
```

Reads all data from an ASCII text file.

- **Arguments**:
  - `fileName` - Path to file
- **Returns**: File contents as ASCII text.

---

#### writeAsciiFile

```tcl
writeAsciiFile fileName data
```

Writes data to an ASCII text file.

- **Arguments**:
  - `fileName` - Path to file
  - `data` - Text to write
- **Returns**: Empty string.

---

#### makeLogChannel

```tcl
makeLogChannel channel
```

Reconfigures a channel for use by the logging subsystem.

- **Arguments**:
  - `channel` - Channel identifier
- **Returns**: Empty string.
- **Note**: Uses "protocol" translation in Eagle, "auto" in Tcl.

---

#### appendLogFile

```tcl
appendLogFile fileName data
```

Appends data to a log file.

- **Arguments**:
  - `fileName` - Path to log file
  - `data` - Data to append
- **Returns**: Empty string.

---

#### appendSharedLogFile

```tcl
appendSharedLogFile fileName data
```

Appends data to a shared log file (allows concurrent access).

- **Arguments**:
  - `fileName` - Path to log file
  - `data` - Data to append
- **Returns**: Empty string.

---

#### readSharedFile

```tcl
readSharedFile fileName
```

Reads from a file with shared access (allows concurrent readers/writers).

- **Arguments**:
  - `fileName` - Path to file
- **Returns**: File contents.

---

#### appendSharedFile

```tcl
appendSharedFile fileName data
```

Appends to a file with shared access.

- **Arguments**:
  - `fileName` - Path to file
  - `data` - Data to append
- **Returns**: Empty string.

---

### File I/O - Unicode (file2u.eagle)

Package: `Eagle.File.Unicode`

#### makeUnicodeChannel

```tcl
makeUnicodeChannel channel
```

Reconfigures a channel for Unicode mode with auto line-ending translation.

- **Arguments**:
  - `channel` - Channel identifier
- **Returns**: Empty string.

---

#### readUnicodeFile

```tcl
readUnicodeFile fileName
```

Reads all data from a Unicode file.

- **Arguments**:
  - `fileName` - Path to file
- **Returns**: File contents.

---

#### writeUnicodeFile

```tcl
writeUnicodeFile fileName data
```

Writes data to a Unicode file.

- **Arguments**:
  - `fileName` - Path to file
  - `data` - Data to write
- **Returns**: Empty string.

---

#### makeUnicodeBinaryChannel

```tcl
makeUnicodeBinaryChannel channel
```

Reconfigures a channel for Unicode mode with binary (no) line-ending translation.

- **Arguments**:
  - `channel` - Channel identifier
- **Returns**: Empty string.

---

#### readUnicodeBinaryFile

```tcl
readUnicodeBinaryFile fileName
```

Reads from a Unicode binary file (no line-ending translation).

- **Arguments**:
  - `fileName` - Path to file
- **Returns**: File contents.

---

#### writeUnicodeBinaryFile

```tcl
writeUnicodeBinaryFile fileName data
```

Writes to a Unicode binary file.

- **Arguments**:
  - `fileName` - Path to file
  - `data` - Data to write
- **Returns**: Empty string.

---

#### makeUtf8Channel

```tcl
makeUtf8Channel channel
```

Reconfigures a channel for UTF-8 mode.

- **Arguments**:
  - `channel` - Channel identifier
- **Returns**: Empty string.

---

#### readUtf8File

```tcl
readUtf8File fileName
```

Reads from a UTF-8 file.

- **Arguments**:
  - `fileName` - Path to file
- **Returns**: File contents.

---

#### writeUtf8File

```tcl
writeUtf8File fileName data
```

Writes to a UTF-8 file.

- **Arguments**:
  - `fileName` - Path to file
  - `data` - Data to write
- **Returns**: Empty string.

---

### File Finder (file3.eagle)

Package: `Eagle.File.Finder`

#### tclLogForCommand

```tcl
tclLogForCommand {command ""}
```

Emits a Tcl log message based on the calling procedure.

- **Arguments**:
  - `command` - Optional command to include in log
- **Returns**: Empty string.

---

#### populateTypesForComSpecDir

```tcl
populateTypesForComSpecDir dirVarName fileVarName
```

Populates arrays with type options for the Windows `dir` command.

- **Arguments**:
  - `dirVarName` - Variable name for directory types
  - `fileVarName` - Variable name for file types
- **Returns**: Empty string.

---

#### populateTypesForGlob

```tcl
populateTypesForGlob dirVarName fileVarName
```

Populates arrays with `-types` option values for `glob`.

- **Arguments**:
  - `dirVarName` - Variable name for directory types
  - `fileVarName` - Variable name for file types
- **Returns**: Empty string.

---

#### filterForGlob

```tcl
filterForGlob paths
```

Filters glob results to remove unwanted entries like "." and "..".

- **Arguments**:
  - `paths` - List of paths
- **Returns**: Filtered list.

---

#### canUseComSpecDir

```tcl
canUseComSpecDir pattern
```

Checks if file searches can use the Windows command shell `dir` command.

- **Arguments**:
  - `pattern` - Search pattern
- **Returns**: Boolean.

---

#### findDirectories

```tcl
findDirectories pattern
```

Finds directories matching a pattern (non-recursive).

- **Arguments**:
  - `pattern` - Glob pattern
- **Returns**: List of matching directories.

- **Example**:
```tcl
set dirs [findDirectories "/home/user/*"]
```

---

#### findDirectoriesRecursive

```tcl
findDirectoriesRecursive pattern
```

Finds directories matching a pattern (recursive).

- **Arguments**:
  - `pattern` - Glob pattern
- **Returns**: List of matching directories.

---

#### findFiles

```tcl
findFiles pattern
```

Finds files matching a pattern (non-recursive).

- **Arguments**:
  - `pattern` - Glob pattern
- **Returns**: List of matching files.

- **Example**:
```tcl
set scripts [findFiles "*.eagle"]
```

---

#### findFilesRecursive

```tcl
findFilesRecursive pattern
```

Finds files matching a pattern (recursive).

- **Arguments**:
  - `pattern` - Glob pattern
- **Returns**: List of matching files.

---

#### copyFilesRecursive

```tcl
copyFilesRecursive sourceDirectory targetDirectory {patterns ""} {options ""}
```

Copies files recursively using Robocopy (Windows only).

- **Arguments**:
  - `sourceDirectory` - Source directory
  - `targetDirectory` - Target directory
  - `patterns` - File patterns to copy (default: all)
  - `options` - List of options: `-nocopyopts`, `-nosubdirs`, `-retries:N`, `-junctions`, `-purge`, `-logging`
- **Returns**: Robocopy output.

---

### Execution Utilities (exec.eagle)

Package: `Eagle.Execute`

#### getShellExecutableName

```tcl
getShellExecutableName
```

Returns the fully qualified file name for the shell executable.

- **Returns**: Path to the shell executable (native or managed).

---

#### getRuntimeCommandLine

```tcl
getRuntimeCommandLine fileName
```

Returns command line arguments needed to run an executable on the current runtime.

- **Arguments**:
  - `fileName` - Executable file name
- **Returns**: List of command line arguments.
- **Note**: Handles differences between .NET Framework, Mono, and .NET Core.

---

#### execShell

```tcl
execShell options args
```

Executes a native Tcl or Eagle sub-shell with the specified arguments.

- **Arguments**:
  - `options` - Options for the `exec` command
  - `args` - Arguments for the shell
- **Returns**: Captured output from the shell.

- **Example**:
```tcl
set result [execShell {} -c {puts "Hello from sub-shell"}]
```

---

#### maybeGetExitCode

```tcl
maybeGetExitCode value {default ""}
```

Extracts the exit code from `$::errorCode` after an `exec` command.

- **Arguments**:
  - `value` - The `$::errorCode` value
  - `default` - Default value if no exit code found
- **Returns**: Exit code as integer or default.

- **Example**:
```tcl
if {[catch {exec somecommand} result]} {
    set exitCode [maybeGetExitCode $::errorCode -1]
}
```

---

### Information Utilities (info.eagle)

Package: `Eagle.Information`

#### getCompileInfo

```tcl
getCompileInfo
```

Returns compile-time information for the Eagle core library.

- **Returns**: List with TimeStamp, ImageRuntimeVersion, ModuleVersionId, and CompileOptions.

---

#### getPlatformInfo

```tcl
getPlatformInfo name {default ""}
```

Returns specific Eagle platform information.

- **Arguments**:
  - `name` - Platform info key (e.g., "machine", "runtime")
  - `default` - Default value if not found
- **Returns**: Platform information value.

---

#### getPluginName

```tcl
getPluginName pattern
```

Returns the name of the first loaded plugin matching a pattern.

- **Arguments**:
  - `pattern` - Regular expression pattern
- **Returns**: Plugin name or empty string.

---

#### getPluginPath

```tcl
getPluginPath pattern
```

Returns the file path of the first loaded plugin matching a pattern.

- **Arguments**:
  - `pattern` - Regular expression pattern
- **Returns**: Plugin file path or empty string.

---

#### getPackageInstallPath

```tcl
getPackageInstallPath {packageName ""} {temporaryPrefix ""}
```

Returns the directory where packages should be installed.

- **Arguments**:
  - `packageName` - Optional package name (creates subdirectory)
  - `temporaryPrefix` - Prefix for temporary directory if Tcl library unavailable
- **Returns**: Installation directory path.

---

#### getBasePath (Eagle only)

```tcl
getBasePath
```

Returns the Eagle core library base path.

- **Returns**: Base directory path (e.g., "C:\Eagle" when loaded from "C:\Eagle\bin\Eagle.dll").

---

#### getPluginFlags

```tcl
getPluginFlags pattern
```

Returns the flags for the first loaded plugin matching a pattern.

- **Arguments**:
  - `pattern` - Regular expression pattern
- **Returns**: List of plugin flags.

---

#### haveGaruda

```tcl
haveGaruda {varName ""}
```

Checks if the Eagle Native Package for Tcl (Garuda) is loaded.

- **Arguments**:
  - `varName` - Optional variable to store the Garuda package ID
- **Returns**: Non-zero if Garuda is available.

---

#### isTclThread

```tcl
isTclThread name
```

Checks if a name represents a thread managed by the native Tcl integration subsystem.

- **Arguments**:
  - `name` - Thread name
- **Returns**: Non-zero if it's a Tcl thread.

---

### Object Utilities (object.eagle)

Package: `Eagle.Object`

These procedures work with .NET objects in Eagle.

#### combineFlags

```tcl
combineFlags flags1 flags2 {flags3 ""} {noCase false}
```

Combines two flag strings and optionally excludes specified flags.

- **Arguments**:
  - `flags1` - First flag string
  - `flags2` - Second flag string
  - `flags3` - Flags to exclude
  - `noCase` - Case-insensitive comparison
- **Returns**: Combined flags as comma-separated string.

---

#### getReturnType

```tcl
getReturnType object member
```

Returns the type name of the return type for a CLR member.

- **Arguments**:
  - `object` - Object or type name
  - `member` - Member name
- **Returns**: Assembly-qualified type name.

---

#### getDefaultValue

```tcl
getDefaultValue typeName
```

Returns the default value for a CLR type.

- **Arguments**:
  - `typeName` - CLR type name
- **Returns**: `0` for value types, `"null"` for reference types.

---

#### getStringFromObjectHandle

```tcl
getStringFromObjectHandle value {default ""}
```

Converts an opaque object handle to a string.

- **Arguments**:
  - `value` - Object handle
  - `default` - Default value if conversion fails
- **Returns**: String representation or default.

---

#### isObjectHandle

```tcl
isObjectHandle value
```

Checks if a value can be used as an opaque object handle.

- **Arguments**:
  - `value` - Value to check
- **Returns**: Boolean.

---

#### isNonNullObjectHandle

```tcl
isNonNullObjectHandle value
```

Checks if a value is a valid, non-null object handle.

- **Arguments**:
  - `value` - Value to check
- **Returns**: Boolean.

---

#### isBasicType

```tcl
isBasicType value {subset basic}
```

Checks if a CLR object is a basic type (losslessly convertible to string).

- **Arguments**:
  - `value` - Object handle
  - `subset` - Type subset: `basic`, `integral`, `integral8`, `fixedPoint`, `floatingPoint`, `string`, `dateTime`, `dbNull`
- **Returns**: Boolean.

---

#### isManagedType

```tcl
isManagedType name
```

Checks if a name represents a valid CLR type.

- **Arguments**:
  - `name` - Type name
- **Returns**: Boolean.

---

#### canGetManagedType

```tcl
canGetManagedType name allowExtra {typeVarName ""} {extraVarName ""}
```

Checks if a name is usable as a CLR type name, optionally with member access.

- **Arguments**:
  - `name` - Name to check
  - `allowExtra` - Allow extra parts after type name
  - `typeVarName` - Variable to store the type name
  - `extraVarName` - Variable to store extra parts
- **Returns**: Boolean.

---

#### evalAsync (Eagle only)

```tcl
evalAsync doneScript args
```

Evaluates a script asynchronously with optional completion notification.

- **Arguments**:
  - `doneScript` - Script to run when evaluation completes (empty for no notification)
  - `args` - Script to evaluate (concatenated if multiple)
- **Returns**: Empty string (result goes to callback).
- **Note**: Requires THREADING compile option. If using a callback, also requires EMIT compile option.

- **Example**:
```tcl
evalAsync {puts "Done: $context"} {
    after 1000
    return "result"
}
```

---

### Process Management (process.eagle)

Package: `Eagle.Process`

#### getOwnerForProcess

```tcl
getOwnerForProcess process {noIntegrity false} {refresh false}
```

Determines the owner of a process.

- **Arguments**:
  - `process` - Process object
  - `noIntegrity` - Skip integrity level check
  - `refresh` - Refresh cached information
- **Returns**: `DOMAIN\USER` format string or error information.

---

#### getProcesses

```tcl
getProcesses name
```

Returns a list of process IDs matching a name.

- **Arguments**:
  - `name` - Process name (empty for all processes)
- **Returns**: List of process IDs.

---

#### waitForProcesses

```tcl
waitForProcesses ids timeout {collect true} {kill true}
```

Waits for processes to exit within a timeout.

- **Arguments**:
  - `ids` - List of process IDs
  - `timeout` - Timeout in milliseconds
  - `collect` - Run garbage collection
  - `kill` - Kill processes if they don't exit
- **Returns**: Empty string.

---

### Runtime Options (runopt.eagle)

Package: `Eagle.RuntimeOptions`

#### hasRuntimeOption

```tcl
hasRuntimeOption name {default false}
```

Checks if a runtime option is currently set.

- **Arguments**:
  - `name` - Option name
  - `default` - Default return value
- **Returns**: Non-zero if option is set.

- **Example**:
```tcl
if {[hasRuntimeOption verbose]} {
    puts "Verbose mode enabled"
}
```

---

#### listRuntimeOptions

```tcl
listRuntimeOptions {default ""}
```

Returns a list of runtime options that are currently set.

- **Arguments**:
  - `default` - Default return value
- **Returns**: List of option names.

---

#### addRuntimeOption

```tcl
addRuntimeOption name
```

Adds a runtime option.

- **Arguments**:
  - `name` - Option name
- **Returns**: Non-zero if added successfully.

---

#### removeRuntimeOption

```tcl
removeRuntimeOption name
```

Removes a runtime option.

- **Arguments**:
  - `name` - Option name
- **Returns**: Non-zero if removed successfully.

---

#### toggleRuntimeOption

```tcl
toggleRuntimeOption name {value ""}
```

Toggles a runtime option or sets it to a specific value.

- **Arguments**:
  - `name` - Option name
  - `value` - Specific value to set (empty to toggle)
- **Returns**: Empty string.

---

### Test Logging (testlog.eagle)

Package: `Eagle.TestLog`

#### vwaitLocked

```tcl
vwaitLocked varName isArray script
```

Locks a variable while evaluating a script (thread-safe).

- **Arguments**:
  - `varName` - Variable name
  - `isArray` - True if variable is an array
  - `script` - Script to evaluate
- **Returns**: Script result.

---

#### tqputs

```tcl
tqputs channel string
```

Emits a message to a channel and adds it to the test log queue.

- **Arguments**:
  - `channel` - Output channel
  - `string` - Message to emit
- **Returns**: Empty string.

---

#### tqlog

```tcl
tqlog string
```

Adds a message to the test log queue for later writing.

- **Arguments**:
  - `string` - Message to log
- **Returns**: Empty string.

---

### ZIP Extraction (unzip.eagle)

Package: `Eagle.Unzip`

#### setupUnzipVars

```tcl
setupUnzipVars force {cleanup false}
```

Sets up default configuration parameters for the unzip package.

- **Arguments**:
  - `force` - Force setup even if already done
  - `cleanup` - Clean up existing configuration
- **Returns**: Empty string.

---

#### unzipMustBeInstalled

```tcl
unzipMustBeInstalled
```

Verifies that the unzip command line tool is installed.

- **Returns**: Empty string.
- **Raises**: Error if unzip is not available.

---

#### extractZipArchive

```tcl
extractZipArchive archiveFileName {extractRootDirectory ""} {rootOnly false}
```

Extracts a ZIP archive using the unzip command.

- **Arguments**:
  - `archiveFileName` - Path to ZIP file
  - `extractRootDirectory` - Extraction destination (default: temp directory)
  - `rootOnly` - Extract only root-level files
- **Returns**: Extraction directory path.
- **Note**: Downloads unzip tool automatically on Windows if needed.

---

### Software Updates (update.eagle)

Package: `Eagle.Update`

#### makeUpdateId

```tcl
makeUpdateId args
```

Creates an identifier for use with update tracking.

- **Arguments**: Variable arguments forming the identifier
- **Returns**: Update identifier string.

---

#### getUpdateFileName

```tcl
getUpdateFileName {directory ""}
```

Returns the path to the updates.tsv file.

- **Arguments**:
  - `directory` - Directory containing the file
- **Returns**: Full path to updates.tsv.

---

#### isUpdateInstalled

```tcl
isUpdateInstalled updateId {directory ""} {script ""}
```

Checks if a specific update is installed.

- **Arguments**:
  - `updateId` - Update identifier
  - `directory` - Directory containing updates.tsv
  - `script` - Optional script to evaluate for each found update
- **Returns**: Non-zero if installed.

---

#### markUpdateInstalled

```tcl
markUpdateInstalled updateId installed {directory ""} {notes ""}
```

Marks an update as installed or removes the installation mark.

- **Arguments**:
  - `updateId` - Update identifier
  - `installed` - True to mark installed, false to unmark
  - `directory` - Directory containing updates.tsv
  - `notes` - Optional notes
- **Returns**: Empty string.

---

#### checkForUpdate

```tcl
checkForUpdate {type ""} {uri ""} {publicKeyToken ""} {name ""} {culture ""} {patchLevel ""} {timeStamp ""} {wantScripts false} {quiet false} {prompt false} {automatic false}
```

Main procedure to check for software updates.

- **Arguments**:
  - `type` - Update type
  - `uri` - Update server URI
  - `publicKeyToken` - Product public key token
  - `name` - Product name
  - `culture` - Product culture
  - `patchLevel` - Current patch level
  - `timeStamp` - Current timestamp
  - `wantScripts` - Download update scripts
  - `quiet` - Suppress output
  - `prompt` - Prompt before downloading
  - `automatic` - Automatic mode
- **Returns**: Update information or empty string.

---

#### checkForEngine

```tcl
checkForEngine {wantScripts false} {quiet false} {prompt false} {automatic false}
```

Checks for new Eagle engine versions.

- **Arguments**:
  - `wantScripts` - Also check for update scripts
  - `quiet` - Suppress output
  - `prompt` - Prompt before downloading
  - `automatic` - Automatic mode
- **Returns**: Update information.

---

#### runUpdateAndExit

```tcl
runUpdateAndExit {automatic false} {whatIf false}
```

Runs the updater tool and exits the process.

- **Arguments**:
  - `automatic` - Automatic mode
  - `whatIf` - Preview mode (don't actually update)
- **Returns**: Does not return (exits process).

---

### Unknown Object Handler (unkobj.eagle)

Package: `Eagle.UnknownObject`

#### unknownObjectInvoke

```tcl
unknownObjectInvoke level name args
```

Handler for the `unknown` command that treats command names as CLR type names.

- **Arguments**:
  - `level` - Call stack level
  - `name` - Unknown command name (treated as type name)
  - `args` - Arguments for the invocation
- **Returns**: Result of the object invocation.
- **Note**: Enables syntax like `System.Console WriteLine "Hello"`.

---

### C# Compilation (csharp.eagle)

Package: `Eagle.CSharp`

#### csharpLog

```tcl
csharpLog string {object ""}
```

Logs C# compilation lifecycle stages.

- **Arguments**:
  - `string` - Log message
  - `object` - Optional object to include properties from
- **Returns**: Empty string.

---

#### getDotNetCoreSdkPath

```tcl
getDotNetCoreSdkPath
```

Returns the path to the .NET Core SDK.

- **Returns**: SDK path or empty string on error.

---

#### getDotNetStandardReferencePath

```tcl
getDotNetStandardReferencePath {packageVersion ""} {standardVersion ""} {useSdkVersion false}
```

Returns the path to .NET Standard reference assemblies.

- **Arguments**:
  - `packageVersion` - NuGet package version
  - `standardVersion` - .NET Standard version
  - `useSdkVersion` - Use SDK version for lookup
- **Returns**: Reference path or empty string.

---

#### getCSharpTestProgram

```tcl
getCSharpTestProgram {name ""}
```

Returns a C# test program for compiler verification.

- **Arguments**:
  - `name` - Test class name
- **Returns**: List with class name and program text.

---

#### doesCompileCSharpWork

```tcl
doesCompileCSharpWork {name ""} {errorsVarName ""} {memory true} args
```

Tests if the C# compiler is working.

- **Arguments**:
  - `name` - Test class name
  - `errorsVarName` - Variable to store errors
  - `memory` - Compile to memory (vs. file)
  - `args` - Additional compiler arguments
- **Returns**: Non-zero if compilation succeeds.

---

#### compileViaCSharpCodeProvider

```tcl
compileViaCSharpCodeProvider string memory symbols strict resultsVarName errorsVarName args
```

Compiles C# code using CSharpCodeProvider (desktop .NET Framework).

- **Arguments**:
  - `string` - C# source code
  - `memory` - Compile to memory
  - `symbols` - Generate debug symbols
  - `strict` - Treat warnings as errors
  - `resultsVarName` - Variable for results
  - `errorsVarName` - Variable for errors
  - `args` - Additional options
- **Returns**: Assembly object on success.

---

#### compileViaDotNetCoreCSharp

```tcl
compileViaDotNetCoreCSharp string memory symbols strict resultsVarName errorsVarName args
```

Compiles C# code using the .NET Core SDK command-line compiler.

- **Arguments**: Same as `compileViaCSharpCodeProvider`
- **Returns**: Assembly object on success.

---

### Safe Interpreter (safe.eagle)

Package: `Eagle.Safe`

The safe interpreter package defines minimal procedures for use in restricted environments.

#### isEagle (bootstrap)

```tcl
isEagle
```

Detects if running in Eagle.

- **Returns**: Non-zero if Eagle.

---

#### appendArgs (safe version)

```tcl
appendArgs args
```

Safe version of appendArgs for use in restricted interpreters.

---

#### unknown (safe version)

```tcl
unknown name args
```

Unknown command handler for safe interpreters - simply raises an error.

---

#### tclPkgUnknown (safe version)

```tcl
tclPkgUnknown name args
```

Package unknown handler for safe interpreters - does nothing.

---

### Interactive Shell (shell.eagle)

Package: `Eagle.Shell`

#### help

```tcl
help args
```

Displays help via the interactive "#help" command.

- **Arguments**: Optional help topic
- **Returns**: Empty string.

---

#### quit

```tcl
quit args
```

Exits the interactive shell.

- **Arguments**: Optional exit code
- **Returns**: Does not return (exits).

---

#### #support

```tcl
#support
```

Shows commercial support requirements and attempts to redirect to the support website.

- **Returns**: Empty string.

---

### Tcl Shim (shim.eagle)

Package: `Eagle.Shim`

These procedures provide compatibility shims for native Tcl.

#### getLengthModifier

```tcl
getLengthModifier value {width ""}
```

Returns a format modifier to force 64-bit integer treatment in native Tcl.

- **Arguments**:
  - `value` - The value to format
  - `width` - Optional width specification
- **Returns**: Format modifier string.

---

#### debug

```tcl
debug args
```

Intercepts Eagle `debug` calls from Tcl scripts.

- **Arguments**: Debug command arguments
- **Returns**: Empty string.
- **Note**: Prints a diagnostic message indicating the command is not available.

---

### Package Toolset (pkgt.eagle)

Package: `Eagle.PackageToolset`

#### setupPackageToolsetVars

```tcl
setupPackageToolsetVars force {cleanup false}
```

Sets up default configuration for the package toolset.

- **Arguments**:
  - `force` - Force setup
  - `cleanup` - Clean up existing configuration
- **Returns**: Empty string.

---

#### downloadAndExtractPackageClientToolset

```tcl
downloadAndExtractPackageClientToolset {channel stdout} {quiet false}
```

Downloads and extracts the Package Client Toolset.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Auto-path directory.

---

#### getBogusPackageName

```tcl
getBogusPackageName
```

Builds a package name that never exists to force package index refresh.

- **Returns**: Bogus package name string.

---

#### forceScanOfPackages

```tcl
forceScanOfPackages
```

Forces a rescan of all available package indexes.

- **Returns**: Empty string.

---

#### loadPackageClientToolset

```tcl
loadPackageClientToolset {directory auto} {apiKeys ""} {hookUnknown true} {enableSecurity true} {isolateSecurity false} {strictSecurity false} {fetchKeyRing false} {debug false}
```

Loads the package client toolset via `package require`.

- **Arguments**:
  - `directory` - Toolset directory ("auto" for auto-detect)
  - `apiKeys` - API keys for package repository
  - `hookUnknown` - Hook the unknown package handler
  - `enableSecurity` - Enable security features
  - `isolateSecurity` - Isolate security
  - `strictSecurity` - Strict security mode
  - `fetchKeyRing` - Fetch key ring
  - `debug` - Debug mode
- **Returns**: Empty string.

---

#### downloadAndExtractNativeTclKitDll

```tcl
downloadAndExtractNativeTclKitDll {channel stdout} {quiet false}
```

Downloads and extracts the native TclKit DLL for the current platform.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

#### downloadAndExtractNativeTclTkDlls

```tcl
downloadAndExtractNativeTclTkDlls {channel stdout} {quiet false}
```

Downloads and extracts native Tcl/Tk DLLs for the current platform.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

#### downloadAndExtractSecurityToolset

```tcl
downloadAndExtractSecurityToolset {channel stdout} {quiet false}
```

Downloads and extracts the Security Toolset (Harpy and Badge plugins).

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

#### requestLicenseCertificate

```tcl
requestLicenseCertificate {channel stdout} {quiet false}
```

Requests an Eagle license certificate from the license server.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

#### evaluateInRemoteSandbox

```tcl
evaluateInRemoteSandbox script {apiKey ""} {params ""} {channel stdout} {quiet false}
```

Submits a script to the remote sandbox for evaluation.

- **Arguments**:
  - `script` - Script to evaluate
  - `apiKey` - API key for authentication
  - `params` - Additional parameters
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Result dictionary.

---

#### listExampleScripts

```tcl
listExampleScripts {apiKey ""} {channel stdout} {quiet false}
```

Lists available named example scripts.

- **Arguments**:
  - `apiKey` - API key
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: List of script names.

---

#### downloadExampleScript

```tcl
downloadExampleScript script {apiKey ""} {channel stdout} {quiet false}
```

Downloads and saves a named example script.

- **Arguments**:
  - `script` - Script name
  - `apiKey` - API key
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

#### getExternalIpAddress

```tcl
getExternalIpAddress {apiKey ""} {channel stdout} {quiet false}
```

Queries and returns the current external IP address.

- **Arguments**:
  - `apiKey` - API key
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: IP address string.

---

### Test Framework (test.eagle)

Package: `Eagle.Test`

The test.eagle file is the core test framework library, containing approximately 250+ procedures for test execution, constraint management, logging, statistics tracking, and remote result reporting. This is the most comprehensive file in the Eagle script library.

#### Core Procedure Definition Utilities

##### s_proc

```tcl
s_proc name {args ""} {command ""}
```

Creates a "stub" procedure with minimal body, typically used as a placeholder.

- **Arguments**:
  - `name` - Procedure name
  - `args` - Argument list (default: "args")
  - `command` - Base command ("proc" or "nproc", default: "proc")
- **Returns**: Result of procedure definition.

---

##### f_proc

```tcl
f_proc name args body {command ""}
```

Creates a "flexible" procedure, automatically selecting `nproc` when available in Eagle.

- **Arguments**:
  - `name` - Procedure name
  - `args` - Argument list
  - `body` - Procedure body
  - `command` - Base command (default: auto-detect)
- **Returns**: Result of procedure definition.

---

##### private

```tcl
private command name arguments body
```

Declares a procedure as "private", preventing calls from outside its namespace.

- **Arguments**:
  - `command` - "proc" or "nproc"
  - `name` - Procedure name
  - `arguments` - Argument list
  - `body` - Procedure body
- **Returns**: Result of procedure definition.

---

##### annotateProcedure

```tcl
annotateProcedure annotation enable command name {arguments ""} {body ""}
```

Adds or removes metadata annotations from a procedure body.

- **Arguments**:
  - `annotation` - Annotation name (e.g., "inline", "nonCaching")
  - `enable` - Boolean to add or remove
  - `command` - "proc" or "nproc"
  - `name` - Procedure name
  - `arguments` - Argument list
  - `body` - Procedure body
- **Returns**: Result of procedure definition.

---

#### User Input

##### promptForAndGetTextInput

```tcl
promptForAndGetTextInput {prompt ""} {title ""} {default ""} {noDots true} {canceledVarName ""}
```

Prompts the user for text input, using a GUI dialog when available.

- **Arguments**:
  - `prompt` - Prompt text
  - `title` - Dialog title
  - `default` - Default value
  - `noDots` - Forbid dots-only input
  - `canceledVarName` - Variable to receive cancellation status
- **Returns**: User-provided text.
- **Note**: Uses Microsoft.VisualBasic.Interaction.InputBox when available, falls back to stdin.

---

#### Test Script Management

##### addTestScripts

```tcl
addTestScripts scriptVarName args
```

Adds test scripts to an indexed array for batch execution.

- **Arguments**:
  - `scriptVarName` - Name of script array variable
  - `args` - Script strings to add
- **Returns**: Count of scripts added.

---

##### evaluateTestScripts

```tcl
evaluateTestScripts interp scriptVarName codeVarName resultVarName
```

Evaluates all scripts in the script array, capturing codes and results.

- **Arguments**:
  - `interp` - Interpreter name (empty for current)
  - `scriptVarName` - Script array variable
  - `codeVarName` - Variable for return codes
  - `resultVarName` - Variable for results
- **Returns**: Count of scripts evaluated.

---

##### combineTestScriptResults

```tcl
combineTestScriptResults scriptVarName codeVarName resultVarName {debug false}
```

Combines test script results into a structured list.

- **Arguments**:
  - `scriptVarName` - Script array variable
  - `codeVarName` - Return codes array
  - `resultVarName` - Results array
  - `debug` - Include scripts in output
- **Returns**: List of result dictionaries.

---

#### .NET Runtime Detection

##### haveModernNetFx

```tcl
haveModernNetFx
```

Returns non-zero if running on .NET Framework 4.x on Windows 10 or higher.

- **Returns**: Boolean.
- **Note**: Returns false on Mono, .NET Core, or non-Windows systems.

---

##### getDotNetCoreRuntimeVersions

```tcl
getDotNetCoreRuntimeVersions {versionOnly false}
```

Gets available .NET Core runtime versions via the `dotnet` CLI.

- **Arguments**:
  - `versionOnly` - Return only version strings (default: false for [version, path] pairs)
- **Returns**: Sorted list of versions or version/path pairs.

---

##### detectDotNetCoreRuntimeVersion

```tcl
detectDotNetCoreRuntimeVersion {majorOnly false}
```

Detects the current .NET Core runtime version.

- **Arguments**:
  - `majorOnly` - Return only major version number
- **Returns**: Version string.

---

##### getDotNetCoreTargetFrameworkMoniker

```tcl
getDotNetCoreTargetFrameworkMoniker {version ""} {includeVersion false}
```

Gets the Target Framework Moniker (TFM) for .NET Core.

- **Arguments**:
  - `version` - Major version (default: auto-detect)
  - `includeVersion` - Include version in TFM
- **Returns**: TFM string (e.g., "net", "netcoreapp").

---

#### Tcl Version Detection

##### getTclMinimumVersion

```tcl
getTclMinimumVersion
```

Returns the minimum supported Tcl version (default: 8.6).

- **Returns**: Version string.
- **Note**: Can be overridden via `TclMinimumVersion` environment variable.

---

##### getTclMaximumVersion

```tcl
getTclMaximumVersion
```

Returns the maximum supported Tcl version (default: 8.9).

- **Returns**: Version string.
- **Note**: Can be overridden via `TclMaximumVersion` environment variable.

---

#### Procedure Utilities

##### getProcedureArguments

```tcl
getProcedureArguments name
```

Returns the full argument specification for a procedure, including defaults.

- **Arguments**:
  - `name` - Procedure name
- **Returns**: Argument list with defaults.

---

##### cloneProcedure

```tcl
cloneProcedure oldName newName {command ""}
```

Creates a copy of a procedure with a new name.

- **Arguments**:
  - `oldName` - Source procedure
  - `newName` - Target procedure name
  - `command` - "proc" or "nproc"
- **Returns**: Result of procedure definition.

---

##### makeProcedureCommand

```tcl
makeProcedureCommand oldName {newName ""} {command ""}
```

Constructs a procedure definition command from an existing procedure.

- **Arguments**:
  - `oldName` - Source procedure
  - `newName` - New name (optional)
  - `command` - Base command
- **Returns**: List suitable for [eval] to define the procedure.

---

#### Cache Management

##### haveCaches

```tcl
haveCaches type
```

Checks if caches of the specified type are available.

- **Arguments**:
  - `type` - Cache type: "instance", "toString", or "stringBuilder"
- **Returns**: Boolean.

---

##### resetCaches

```tcl
resetCaches {enable true}
```

Resets interpreter caches to initial state.

- **Arguments**:
  - `enable` - Lock/unlock caches after reset
- **Returns**: Empty string.

---

##### reportCaches

```tcl
reportCaches
```

Reports cache statistics to the test channel.

- **Returns**: Empty string.

---

#### Flag Management

The test.eagle file provides numerous procedures for enabling/disabling interpreter flags:

##### enableFlags

```tcl
enableFlags memberName {newFlags ""} {enable ""} {memberType Field} {typeName Interpreter} {objectName Interpreter.GetActive}
```

Generic flag modification for interpreter fields/properties.

- **Arguments**:
  - `memberName` - Name of flag field/property
  - `newFlags` - Flags to set
  - `enable` - true to add, false to remove
  - `memberType` - "Field" or "Property"
  - `typeName` - Type containing the member
  - `objectName` - Object expression
- **Returns**: Current flag value after modification.

---

The following specialized flag procedures use `enableFlags` internally:

| Procedure | Target |
|-----------|--------|
| `enableDataFlags` | DataFlags property |
| `enableHostFlags` | hostFlags field |
| `enableInterpreterFlags` | interpreterFlags field |
| `enableInterpreterStateFlags` | interpreterStateFlags field |
| `enablePluginFlags` | pluginFlags field |
| `enableSharedProcedureFlags` | SharedProcedureFlags property |
| `enableContextProcedureFlags` | ContextProcedureFlags property |
| `enableSharedPackageFlags` | SharedPackageFlags property |
| `enableContextPackageFlags` | ContextPackageFlags property |
| `enableSharedPackageIndexFlags` | SharedPackageIndexFlags property |
| `enableContextPackageIndexFlags` | ContextPackageIndexFlags property |
| `enableSharedEngineFlags` | SharedEngineFlags property |
| `enableContextEngineFlags` | ContextEngineFlags property |
| `enableDefaultInterpreterFlags` | DefaultInterpreterFlags property |
| `enableExpressionFlags` | ExpressionFlags property |
| `enableInterpreterTestFlags` | interpreterTestFlags field |
| `enableInteractiveLoopFlags` | interactiveLoopFlags field |
| `enableReadyFlags` | readyFlags field |
| `enableEventWaitFlags` | eventWaitFlags field |
| `enableQueueEventFlags` | queueEventFlags field |
| `enableWaitEventFlags` | waitEventFlags field |
| `enableNewGlobalVariableFlags` | newGlobalVariableFlags field |
| `enableNewLocalVariableFlags` | newLocalVariableFlags field |
| `enableTclExitUnloadFlags` | tclExitUnloadFlags field |

---

#### Debug Hooks

##### debugBreakHook

```tcl
debugBreakHook args
```

Debug hook that breaks into interactive loop when matched.

- **Arguments**: Dictionary from `[debug hook]`
- **Returns**: `-code Ok` with message.
- **Usage**: `debug hook -type Before basic-1.* ::debugBreakHook`

---

##### skipTestHook

```tcl
skipTestHook args
```

Debug hook that skips the matched test entirely.

- **Returns**: `-code Break` with message.

---

##### noFailTestHook

```tcl
noFailTestHook args
```

Debug hook that prevents matched tests from failing.

- **Returns**: `-code Continue` with message.

---

##### whatIfTestHook

```tcl
whatIfTestHook args
```

Debug hook that enables "what-if" mode for matched tests.

- **Returns**: `-code WhatIf` with message.

---

##### errorTestHook

```tcl
errorTestHook args
```

Debug hook that forces matched tests to error.

- **Returns**: `-code Error` with message.

---

##### failTestHook

```tcl
failTestHook args
```

Debug hook that forces matched tests to fail.

- **Returns**: `-code Exception` with message.

---

#### Error Handling

##### breakOnError

```tcl
breakOnError script
```

Evaluates a script with automatic debug break on errors.

- **Arguments**:
  - `script` - Script to evaluate
- **Returns**: Result on success.
- **Note**: On error, displays error info and enters interactive debug loop. User can fix issues and retry by returning true from the loop.

---

##### getFirstLineOfError

```tcl
getFirstLineOfError error
```

Extracts the first line from an error message.

- **Arguments**:
  - `error` - Error string
- **Returns**: First line of error.

---

#### Test Constraint Management

##### haveConstraint

```tcl
haveConstraint name
```

Checks if a test constraint is currently set.

- **Arguments**:
  - `name` - Constraint name
- **Returns**: Boolean.

---

##### addConstraint

```tcl
addConstraint name {value 1}
```

Adds a test constraint.

- **Arguments**:
  - `name` - Constraint name
  - `value` - Constraint value (default: 1)
- **Returns**: Empty string.

---

##### removeConstraint

```tcl
removeConstraint name
```

Removes a test constraint.

- **Arguments**:
  - `name` - Constraint name
- **Returns**: Empty string.

---

##### haveOrAddConstraint

```tcl
haveOrAddConstraint name {value ""}
```

Checks or sets a constraint depending on argument count.

- **Arguments**:
  - `name` - Constraint name
  - `value` - Value to set (optional)
- **Returns**: Boolean (query) or empty string (set).

---

##### getConstraints

```tcl
getConstraints
```

Returns list of all currently set constraints.

- **Returns**: List of constraint names.

---

##### fixConstraints

```tcl
fixConstraints constraints
```

Normalizes constraint syntax for Tcl compatibility.

- **Arguments**:
  - `constraints` - Constraint expression
- **Returns**: Fixed constraint expression.
- **Note**: Handles "!" negation syntax differences between Eagle and Tcl.

---

##### fixMemoryConstraints

```tcl
fixMemoryConstraints constraints
```

Adjusts constraints for memory-sensitive tests.

- **Arguments**:
  - `constraints` - Base constraints
- **Returns**: Constraints with `fail.false` added when appropriate.

---

##### fixTimingConstraints

```tcl
fixTimingConstraints constraints
```

Adjusts constraints for timing-sensitive tests.

- **Arguments**:
  - `constraints` - Base constraints
- **Returns**: Constraints with `fail.false` added when appropriate.

---

#### Test Output

##### tputs

```tcl
tputs channel string
```

Primary test output procedure - writes to channel and log file.

- **Arguments**:
  - `channel` - Output channel
  - `string` - Text to output
- **Returns**: Empty string.
- **Note**: Suppresses repeated consecutive output.

---

##### trawputs

```tcl
trawputs channel string
```

Raw output without repeat suppression.

- **Arguments**:
  - `channel` - Output channel
  - `string` - Text to output
- **Returns**: Empty string.

---

##### toneputs

```tcl
toneputs channel string
```

Output to channel and log without repeat check.

- **Arguments**:
  - `channel` - Output channel
  - `string` - Text to output
- **Returns**: Empty string.

---

##### tlog

```tcl
tlog string
```

Writes string to test log file only.

- **Arguments**:
  - `string` - Text to log
- **Returns**: Empty string.

---

##### dputs

```tcl
dputs string
```

Debug output via `debug output`.

- **Arguments**:
  - `string` - Debug text
- **Returns**: Empty string.

---

##### dlog

```tcl
dlog string
```

Debug log via `debug log`.

- **Arguments**:
  - `string` - Log text
- **Returns**: Empty string.

---

##### dtrace

```tcl
dtrace string
```

Debug trace output.

- **Arguments**:
  - `string` - Trace text
- **Returns**: Empty string.

---

#### Test Log Management

##### getTestLog

```tcl
getTestLog
```

Returns the current test log file path.

- **Returns**: File path or empty string.

---

##### getTestLogPath

```tcl
getTestLogPath
```

Returns the test log directory path.

- **Returns**: Directory path.

---

##### getDefaultTestLog

```tcl
getDefaultTestLog
```

Returns the default test log file name.

- **Returns**: File name.

---

##### getTestLogStartSentry

```tcl
getTestLogStartSentry
```

Returns the start marker for the test log.

- **Returns**: Sentry string including test run ID.

---

##### doesTestLogHaveStartSentry

```tcl
doesTestLogHaveStartSentry
```

Checks if the test log contains a start marker.

- **Returns**: Boolean.

---

#### Performance Measurement

##### calculateBogoCops

```tcl
calculateBogoCops {milliseconds 2000} {legacy false}
```

Calculates "bogus commands per second" for performance scaling.

- **Arguments**:
  - `milliseconds` - Measurement duration
  - `legacy` - Use legacy calculation method
- **Returns**: Commands per second.
- **Note**: Used to scale test timeouts based on machine performance.

---

##### calculateRelativePerformance

```tcl
calculateRelativePerformance type value
```

Adjusts performance values based on machine speed ratio.

- **Arguments**:
  - `type` - "elapsed" or "iterations"
  - `value` - Base value
- **Returns**: Adjusted value.

---

#### Test Run Information

##### getTestRunId

```tcl
getTestRunId
```

Returns the current test run identifier.

- **Returns**: Run ID string.

---

##### getNewTestRunId

```tcl
getNewTestRunId
```

Generates a new unique test run identifier.

- **Returns**: New run ID.

---

##### getTestRunTag

```tcl
getTestRunTag
```

Builds a descriptive tag for web request tracking.

- **Returns**: Tag string with user, host, batch ID, run ID, pid, tid.

---

##### setupTestRunTag

```tcl
setupTestRunTag {channel stdout} {quiet false}
```

Sets up the WebClient tag for remote logging.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Boolean indicating if tag was set.

---

#### Test Suite Information

##### getTestSuite

```tcl
getTestSuite
```

Returns the test suite name.

- **Returns**: Suite name string.

---

##### getTestSuiteFileName

```tcl
getTestSuiteFileName
```

Returns the test suite script file name.

- **Returns**: File name.

---

##### getTestMachine

```tcl
getTestMachine
```

Returns the target machine architecture for tests.

- **Returns**: Machine string (e.g., "x86", "x64", "arm64").

---

##### getTestPlatform

```tcl
getTestPlatform {architecture false}
```

Returns the test platform.

- **Arguments**:
  - `architecture` - Include architecture details
- **Returns**: Platform string.

---

##### getTestConfiguration

```tcl
getTestConfiguration
```

Returns the build configuration (Debug/Release).

- **Returns**: Configuration string.

---

#### State Management

##### cleanState

```tcl
cleanState {namespaceName ""} {excludePatterns ""} {noEagle false} {noTest false} {noOther false} {checkOnly false}
```

Cleans interpreter state by removing non-system variables.

- **Arguments**:
  - `namespaceName` - Namespace to clean
  - `excludePatterns` - Patterns to exclude
  - `noEagle` - Skip Eagle variables
  - `noTest` - Skip test variables
  - `noOther` - Skip other known variables
  - `checkOnly` - Report only, don't clean
- **Returns**: List of cleaned/found variables.

---

##### dumpState

```tcl
dumpState {namespaceName ""}
```

Dumps all variable state for debugging.

- **Arguments**:
  - `namespaceName` - Namespace to dump
- **Returns**: Dictionary of variable names and values.

---

#### Temporary File Management

##### evaluateViaTemporaryFile

```tcl
evaluateViaTemporaryFile varName name script {verbose 0}
```

Evaluates a script by writing it to a temporary file first.

- **Arguments**:
  - `varName` - Tracking variable name
  - `name` - Unique script name
  - `script` - Script content
  - `verbose` - Verbosity level
- **Returns**: Script result.
- **Note**: Useful for debugging script evaluation issues.

---

##### cleanupEvaluateViaTemporaryFiles

```tcl
cleanupEvaluateViaTemporaryFiles varName {verbose 0}
```

Cleans up temporary script files.

- **Arguments**:
  - `varName` - Tracking variable name
  - `verbose` - Verbosity level
- **Returns**: List of deleted files.

---

#### Process Management

##### getProcessGroup

```tcl
getProcessGroup pid {varName ""} {quiet false}
```

Gets the process group ID for a process (Unix only).

- **Arguments**:
  - `pid` - Process ID
  - `varName` - Variable to receive PGID
  - `quiet` - Suppress output
- **Returns**: Boolean success.

---

##### killProcessGroup

```tcl
killProcessGroup pgid {quiet false}
```

Kills a process group (Unix only).

- **Arguments**:
  - `pgid` - Process group ID
  - `quiet` - Suppress output
- **Returns**: Boolean success.

---

##### maybeKillProcessGroup

```tcl
maybeKillProcessGroup pid {self false} {quiet false}
```

Conditionally kills a process group if safe to do so.

- **Arguments**:
  - `pid` - Target process ID
  - `self` - Allow killing own process group
  - `quiet` - Suppress output
- **Returns**: Boolean indicating if killed.

---

##### enableFailSafeExitAfter

```tcl
enableFailSafeExitAfter {group false} {milliseconds 600000}
```

Sets up a fail-safe process termination after timeout.

- **Arguments**:
  - `group` - Kill entire process group
  - `milliseconds` - Timeout (default: 10 minutes)
- **Returns**: Result value.
- **Note**: Prevents runaway tests from hanging indefinitely.

---

#### Test Execution

##### testDebugBreak

```tcl
testDebugBreak {force 0} args
```

Breaks into the script debugger for test debugging.

- **Arguments**:
  - `force` - Force debugger activation level
  - `args` - Additional arguments
- **Returns**: Debug break result.

---

##### runTest

```tcl
runTest script
```

Executes a test script with proper tracking and statistics.

- **Arguments**:
  - `script` - Test script
- **Returns**: Test result.

---

##### tsource

```tcl
tsource fileName {prologue true} {epilogue true}
```

Sources a test file with optional prologue/epilogue.

- **Arguments**:
  - `fileName` - Test file path
  - `prologue` - Run test prologue
  - `epilogue` - Run test epilogue
- **Returns**: Result of sourcing.

---

##### runTestPrologue

```tcl
runTestPrologue {overridePath ""} {quiet false}
```

Executes the test prologue script.

- **Arguments**:
  - `overridePath` - Custom prologue path
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

##### runTestEpilogue

```tcl
runTestEpilogue {overridePath ""} {quiet false}
```

Executes the test epilogue script.

- **Arguments**:
  - `overridePath` - Custom epilogue path
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

##### runAllTests

```tcl
runAllTests channel path fileNames skipFileNames startFileNames stopFileNames
```

Executes all test files in sequence.

- **Arguments**:
  - `channel` - Output channel
  - `path` - Test directory path
  - `fileNames` - List of test files
  - `skipFileNames` - Files to skip
  - `startFileNames` - Files to start after
  - `stopFileNames` - Files to stop at
- **Returns**: Empty string.

---

#### Test Statistics

##### recordTestStatistics

```tcl
recordTestStatistics varName index
```

Records current test statistics to a tracking variable.

- **Arguments**:
  - `varName` - Statistics variable name
  - `index` - Array index
- **Returns**: Empty string.

---

##### reportTestStatistics

```tcl
reportTestStatistics channel name stop statsVarName namesVarName {quiet false}
```

Reports test resource leak statistics.

- **Arguments**:
  - `channel` - Output channel
  - `name` - Test name
  - `stop` - Statistics index
  - `statsVarName` - Statistics variable
  - `namesVarName` - Names variable
  - `quiet` - Suppress output
- **Returns**: Boolean indicating leaks found.

---

##### reportTestResultCounts

```tcl
reportTestResultCounts channel
```

Reports final test result counts (passed, failed, skipped).

- **Arguments**:
  - `channel` - Output channel
- **Returns**: Empty string.

---

#### Remote Logging

##### logRemoteMessage

```tcl
logRemoteMessage message {uri ""} {apiKey ""} {password ""} {channel stdout} {quiet false}
```

Sends a message to a remote logging service.

- **Arguments**:
  - `message` - Message content
  - `uri` - Target URI
  - `apiKey` - API authentication key
  - `password` - Optional password
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Boolean success.

---

##### logRemoteTestResults

```tcl
logRemoteTestResults success {channel stdout} {verbose false} {quiet false}
```

Logs test results to a remote service.

- **Arguments**:
  - `success` - Overall success status
  - `channel` - Output channel
  - `verbose` - Include detailed results
  - `quiet` - Suppress output
- **Returns**: Remote logging result.

---

#### Formatting Utilities

##### formatTimeStamp

```tcl
formatTimeStamp seconds {gmt false}
```

Formats a timestamp for display.

- **Arguments**:
  - `seconds` - Unix timestamp
  - `gmt` - Use GMT timezone
- **Returns**: Formatted timestamp string.

---

##### formatElapsedTime

```tcl
formatElapsedTime seconds
```

Formats elapsed time as hours:minutes:seconds.

- **Arguments**:
  - `seconds` - Elapsed seconds
- **Returns**: Formatted time string.

---

##### formatList

```tcl
formatList list {default ""} {columns 1}
```

Formats a list for display.

- **Arguments**:
  - `list` - List to format
  - `default` - Default if empty
  - `columns` - Number of columns
- **Returns**: Formatted string.

---

##### formatListAsDict

```tcl
formatListAsDict list {default ""}
```

Formats a list as a dictionary.

- **Arguments**:
  - `list` - List to format
  - `default` - Default if empty
- **Returns**: Formatted dictionary string.

---

##### formatDecimal

```tcl
formatDecimal value {places 4} {zeros false}
```

Formats a decimal number.

- **Arguments**:
  - `value` - Numeric value
  - `places` - Decimal places
  - `zeros` - Include trailing zeros
- **Returns**: Formatted number string.

---

#### Array and Value Utilities

##### testArrayGet

```tcl
testArrayGet varName {integer false}
```

Gets array contents in sorted order.

- **Arguments**:
  - `varName` - Array variable name
  - `integer` - Sort keys as integers
- **Returns**: Sorted key-value list.

---

##### testValueGet

```tcl
testValueGet varName {integer false}
```

Gets variable value, handling both arrays and scalars.

- **Arguments**:
  - `varName` - Variable name
  - `integer` - Sort array keys as integers
- **Returns**: Value or array contents.

---

##### getValueOrDefault

```tcl
getValueOrDefault varName {default <none>}
```

Gets variable value or returns default if undefined/empty.

- **Arguments**:
  - `varName` - Variable name
  - `default` - Default value
- **Returns**: Value or default.

---

#### Command-Line Argument Processing

##### addToArgv

```tcl
addToArgv option subValue
```

Adds a value to a command-line option in argv.

- **Arguments**:
  - `option` - Option name (e.g., "-constraints")
  - `subValue` - Value to add
- **Returns**: Modified argv.

---

##### removeFromArgv

```tcl
removeFromArgv option subValue
```

Removes a value from a command-line option in argv.

- **Arguments**:
  - `option` - Option name
  - `subValue` - Value to remove
- **Returns**: Modified argv.

---

##### addConstraintToArgv

```tcl
addConstraintToArgv subValue
```

Convenience wrapper to add a constraint to argv.

- **Arguments**:
  - `subValue` - Constraint value
- **Returns**: Modified argv.

---

##### removeConstraintFromArgv

```tcl
removeConstraintFromArgv subValue
```

Convenience wrapper to remove a constraint from argv.

- **Arguments**:
  - `subValue` - Constraint value
- **Returns**: Modified argv.

---

#### Debugging Utilities

##### whereAmI

```tcl
whereAmI
```

Returns a .NET stack trace of the current execution point.

- **Returns**: Stack trace string.

---

##### dumpWhereAmI

```tcl
dumpWhereAmI
```

Writes execution location to a file for debugging.

- **Returns**: Empty string.

---

##### breakpoint

```tcl
breakpoint args
```

Enters the script debugger at the current point.

- **Arguments**: Ignored
- **Returns**: Debug result.

---

##### debugBreakWithNewConsole

```tcl
debugBreakWithNewConsole args
```

Opens a new console window and enters debugger.

- **Arguments**: Ignored
- **Returns**: Debug result.

---

#### Tracing

##### enableTracing

```tcl
enableTracing {stateTypes "=CoreEnableMask +ForceListeners"} {message true}
```

Enables maximum tracing for debugging.

- **Arguments**:
  - `stateTypes` - Trace state types
  - `message` - Output trace message
- **Returns**: Trace result.

---

##### disableTracing

```tcl
disableTracing {stateTypes "=CoreDisableMask +ForceListeners"} {message true}
```

Disables tracing.

- **Arguments**:
  - `stateTypes` - Trace state types
  - `message` - Output trace message
- **Returns**: Trace result.

---

#### File and Path Utilities

##### getFiles

```tcl
getFiles directory include {exclude ""} {forceReadable false}
```

Gets files matching include pattern, excluding specified patterns.

- **Arguments**:
  - `directory` - Search directory
  - `include` - Include glob pattern
  - `exclude` - Exclude glob pattern
  - `forceReadable` - Only include readable files
- **Returns**: List of file paths.

---

##### getTestFiles

```tcl
getTestFiles directories matchFilePatterns skipFilePatterns {quiet false}
```

Gets test files from multiple directories.

- **Arguments**:
  - `directories` - Search directories
  - `matchFilePatterns` - Match patterns
  - `skipFilePatterns` - Skip patterns
  - `quiet` - Suppress output
- **Returns**: List of test file paths.

---

##### findParentDirectory

```tcl
findParentDirectory path name
```

Finds a parent directory with the specified name.

- **Arguments**:
  - `path` - Starting path
  - `name` - Directory name to find
- **Returns**: Parent directory path or empty string.

---

##### pathToRegexp

```tcl
pathToRegexp path {list false}
```

Converts a file path to a regular expression pattern.

- **Arguments**:
  - `path` - File path
  - `list` - Return as list
- **Returns**: Regexp pattern.

---

#### Known Variables

##### getKnownTclVariables

```tcl
getKnownTclVariables
```

Returns list of documented Tcl global variables.

- **Returns**: Sorted list of variable names.

---

##### getKnownEagleVariables

```tcl
getKnownEagleVariables
```

Returns list of documented Eagle global variables.

- **Returns**: Sorted list of variable names.

---

##### getKnownTestVariables

```tcl
getKnownTestVariables
```

Returns list of test-related global variables.

- **Returns**: Sorted list of variable names.

---

##### getKnownOtherVariables

```tcl
getKnownOtherVariables
```

Returns list of other known global variables.

- **Returns**: Sorted list of variable names.

---

#### Event Handling

##### testDoEvents

```tcl
testDoEvents milliseconds
```

Processes events for the specified duration.

- **Arguments**:
  - `milliseconds` - Duration to process events
- **Returns**: List of [count, total_time].

---

##### cleanupAfterEvents

```tcl
cleanupAfterEvents {quiet false}
```

Cancels all pending after events.

- **Arguments**:
  - `quiet` - Suppress output
- **Returns**: Count of canceled events or -1 on failure.

---

#### Tcl Shell Utilities

##### getTclShellFileName

```tcl
getTclShellFileName automatic kits machine
```

Locates the Tcl shell executable.

- **Arguments**:
  - `automatic` - Auto-detect
  - `kits` - Include tclkit variants
  - `machine` - Target architecture
- **Returns**: Tcl shell path.

---

##### evalWithTclShell

```tcl
evalWithTclShell args
```

Evaluates a script in an external Tcl shell.

- **Arguments**:
  - `args` - Script and arguments
- **Returns**: Evaluation result.

---

#### Precision Management

##### saveAndResetPrecision

```tcl
saveAndResetPrecision {precision 0}
```

Saves current tcl_precision and resets to specified value.

- **Arguments**:
  - `precision` - New precision value
- **Returns**: Empty string.

---

##### restorePrecision

```tcl
restorePrecision
```

Restores previously saved tcl_precision.

- **Returns**: Empty string.

---

#### Shell Integration (Eagle only)

These procedures provide integration with the operating system shell for executing external commands.

##### eagle_haveShell

```tcl
eagle_haveShell {varName ""}
```

Checks if an operating system shell is available.

- **Arguments**:
  - `varName` - Variable to receive shell path
- **Returns**: Boolean indicating shell availability.
- **Note**: Checks `ComSpec` on Windows, `SHELL` on Unix.

---

##### eagle_enableShellUnknown

```tcl
eagle_enableShellUnknown {enable ""} {quiet false}
```

Enables or disables the shell-based unknown command handler.

- **Arguments**:
  - `enable` - Boolean to enable/disable (empty to query)
  - `quiet` - Suppress output
- **Returns**: Boolean indicating current state.
- **Note**: When enabled, unknown commands are passed to the OS shell.

---

##### eagle_isShellScriptLevel

```tcl
eagle_isShellScriptLevel {extraLevels 0} {quiet false}
```

Checks if currently at the shell script execution level.

- **Arguments**:
  - `extraLevels` - Additional levels to account for
  - `quiet` - Suppress output
- **Returns**: Boolean.

---

##### eagle_appendExecArgs

```tcl
eagle_appendExecArgs viaShell varName args
```

Appends arguments to an exec command with proper escaping.

- **Arguments**:
  - `viaShell` - Whether executing via shell
  - `varName` - Command list variable
  - `args` - Arguments to append
- **Returns**: Empty string.

---

##### eagle_shellBuildCommand

```tcl
eagle_shellBuildCommand shell name args
```

Builds a shell command for execution.

- **Arguments**:
  - `shell` - Shell executable path
  - `name` - Command name
  - `args` - Command arguments
- **Returns**: Command list for exec.
- **Note**: Handles differences between cmd.exe, PowerShell, and Unix shells.

---

##### eagle_shellUnknown

```tcl
eagle_shellUnknown name args
```

Unknown command handler that passes commands to the OS shell.

- **Arguments**:
  - `name` - Unknown command name
  - `args` - Command arguments
- **Returns**: Shell command output.
- **Note**: Activated via `eagle_enableShellUnknown`.

---

##### eagle_getUnsafePromptCommands

```tcl
eagle_getUnsafePromptCommands
```

Returns list of commands unsafe for interactive prompts.

- **Returns**: List of command names.

---

##### eagle_haveProbeForCommand

```tcl
eagle_haveProbeForCommand
```

Checks if command probing is available.

- **Returns**: Boolean.

---

##### eagle_probeForCommand

```tcl
eagle_probeForCommand name
```

Probes for availability of an external command.

- **Arguments**:
  - `name` - Command name to probe
- **Returns**: Boolean indicating availability.

---

##### eagle_probeForCommands

```tcl
eagle_probeForCommands names
```

Probes for multiple external commands.

- **Arguments**:
  - `names` - List of command names
- **Returns**: List of available commands.

---

##### eagle_probeForPromptCommands

```tcl
eagle_probeForPromptCommands {names ""}
```

Probes for commands safe to use in interactive prompts.

- **Arguments**:
  - `names` - Command names (optional)
- **Returns**: List of safe available commands.

---

##### eagle_getShellPromptScript

```tcl
eagle_getShellPromptScript
```

Returns the shell prompt script.

- **Returns**: Prompt script string.

---

##### eagle_setupPromptScript

```tcl
eagle_setupPromptScript {enable ""}
```

Sets up or tears down the shell prompt script.

- **Arguments**:
  - `enable` - Boolean to enable/disable
- **Returns**: Empty string.

---

##### eagle_buildDataId

```tcl
eagle_buildDataId value {length 16} {hashAlgorithmName SHA512}
```

Builds a unique identifier from data using a hash function.

- **Arguments**:
  - `value` - Data to hash
  - `length` - Output length
  - `hashAlgorithmName` - Hash algorithm (default: SHA512)
- **Returns**: Hex string identifier.

---

#### URI and JSON Utilities (Eagle only)

##### isUriLikelyToBeRedirected

```tcl
isUriLikelyToBeRedirected uri
```

Checks if a URI is likely to be a redirect service URL.

- **Arguments**:
  - `uri` - URI to check
- **Returns**: Boolean.
- **Note**: Checks against the auxiliary base URI.

---

##### maybeResolveUri

```tcl
maybeResolveUri uri {varName ""} {channel stdout} {quiet false}
```

Resolves a URI through redirect services if needed.

- **Arguments**:
  - `uri` - URI to resolve
  - `varName` - Variable to receive resolution status
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Resolved URI.

---

##### maybeFullyResolveUri

```tcl
maybeFullyResolveUri uri redirectLimit {channel stdout} {quiet false}
```

Fully resolves a URI through multiple redirects.

- **Arguments**:
  - `uri` - URI to resolve
  - `redirectLimit` - Maximum redirects (-1 for unlimited)
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Final resolved URI.

---

##### escapeForJsonString

```tcl
escapeForJsonString value
```

Escapes a string for safe inclusion in JSON.

- **Arguments**:
  - `value` - String to escape
- **Returns**: JSON-safe escaped string.

---

##### isValidJson

```tcl
isValidJson value
```

Validates that a string is valid JSON.

- **Arguments**:
  - `value` - String to validate
- **Returns**: Boolean.
- **Note**: Uses Newtonsoft.Json for parsing.

---

##### getOrSetViaJsonPaths

```tcl
getOrSetViaJsonPaths json jpaths {value ""} {root false}
```

Gets or sets a value in JSON using a path list.

- **Arguments**:
  - `json` - JSON string
  - `jpaths` - List of path elements (keys/indices)
  - `value` - Value to set (optional)
  - `root` - Return entire JSON from root
- **Returns**: JSON value or modified JSON.

---

##### verifyConfigurationDirectory

```tcl
verifyConfigurationDirectory directory {pattern ""}
```

Verifies a configuration directory exists and is readable.

- **Arguments**:
  - `directory` - Directory path
  - `pattern` - File pattern to check
- **Returns**: Boolean.

---

#### OpenAI Integration (Eagle only)

These procedures provide integration with the OpenAI API for AI-assisted operations.

##### openAI_getPrompt

```tcl
openAI_getPrompt command {channel stdout} {quiet false}
```

Builds a prompt for OpenAI from an unknown command.

- **Arguments**:
  - `command` - The unknown command
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Formatted prompt string.

---

##### openAI_getJsonPaths

```tcl
openAI_getJsonPaths json {channel stdout} {quiet false}
```

Returns the JSON path to extract content from OpenAI response.

- **Arguments**:
  - `json` - JSON response
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Path list (default: `choices 0 message content`).

---

##### openAI_enableUnknown

```tcl
openAI_enableUnknown {enable ""} {options true} {whatIf true} {channel stdout} {quiet false}
```

Enables or disables OpenAI-based unknown command handling.

- **Arguments**:
  - `enable` - Boolean to enable/disable (empty to query)
  - `options` - Manage runtime options
  - `whatIf` - Use what-if mode
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Boolean indicating state change.

---

##### openAI_getKeyRingDirectory

```tcl
openAI_getKeyRingDirectory {channel stdout} {quiet false}
```

Locates the keyring directory for OpenAI credentials.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Directory path.
- **Note**: Searches `OPENAI_KEYRING_DIRECTORY`, binary directory, and Kapok paths.

---

##### openAI_writeScript

```tcl
openAI_writeScript script
```

Writes a script to a temporary file.

- **Arguments**:
  - `script` - Script content
- **Returns**: Temporary file path.

---

##### openAI_haveSecurity

```tcl
openAI_haveSecurity {channel stdout} {quiet false}
```

Checks if security (script signing) is available.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Boolean.

---

##### openAI_enableSecurity

```tcl
openAI_enableSecurity {varName ""} {channel stdout} {quiet false}
```

Enables security for OpenAI script execution.

- **Arguments**:
  - `varName` - Variable to receive security status
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Boolean indicating security state.

---

##### openAI_cleanupSandbox

```tcl
openAI_cleanupSandbox {channel stdout} {quiet false}
```

Cleans up the OpenAI sandbox interpreter.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

##### openAI_maybeEvaluateInSandbox

```tcl
openAI_maybeEvaluateInSandbox fileName security {channel stdout} {quiet false}
```

Evaluates a script in the sandbox interpreter if security allows.

- **Arguments**:
  - `fileName` - Script file path
  - `security` - Security enabled flag
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Evaluation result.

---

##### openAI_unknown

```tcl
openAI_unknown whatIf channel quiet name args
```

Unknown command handler that queries OpenAI for corrections.

- **Arguments**:
  - `whatIf` - Use what-if mode
  - `channel` - Output channel
  - `quiet` - Suppress output
  - `name` - Unknown command name
  - `args` - Command arguments
- **Returns**: OpenAI suggestion or error.

---

##### openAI_scriptWebClient

```tcl
openAI_scriptWebClient args
```

Callback procedure for ScriptWebClient customization.

- **Arguments**:
  - `args` - Callback arguments
- **Returns**: Empty string.
- **Note**: Configures HTTP headers for OpenAI API requests.

---

##### openAI_setupScriptWebClient

```tcl
openAI_setupScriptWebClient enable varName {channel stdout} {quiet false}
```

Sets up or tears down the ScriptWebClient for OpenAI.

- **Arguments**:
  - `enable` - Boolean to enable/disable
  - `varName` - Variable for saved flags
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Empty string.

---

##### openAI_getTypes

```tcl
openAI_getTypes {channel stdout} {quiet false}
```

Returns supported OpenAI model types.

- **Arguments**:
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: List of types (default: `"" chat`).

---

##### openAI_getDefaultModel

```tcl
openAI_getDefaultModel type {channel stdout} {quiet false}
```

Returns the default model for a type.

- **Arguments**:
  - `type` - Model type
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Model name (default: `gpt-3.5-turbo`).

---

##### openAI_getStandardModel

```tcl
openAI_getStandardModel type {channel stdout} {quiet false}
```

Returns the standard (premium) model for a type.

- **Arguments**:
  - `type` - Model type
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: Model name (default: `chatgpt-4o-latest`).

---

##### openAI_getJson

```tcl
openAI_getJson prompt model options {channel stdout} {quiet false}
```

Builds the JSON payload for an OpenAI API request.

- **Arguments**:
  - `prompt` - User prompt
  - `model` - Model name
  - `options` - Additional options dictionary
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: JSON string.
- **Note**: Supports `deterministic` option for reproducible results.

---

##### openAI_getAnyApiKey

```tcl
openAI_getAnyApiKey proxy {varName ""}
```

Retrieves an API key from available sources.

- **Arguments**:
  - `proxy` - Use proxy service
  - `varName` - Variable to receive proxy flag
- **Returns**: API key string.
- **Note**: Checks `OPENAI_API_KEY`, `OPENAI_API_KEY_FILE`, and Harpy plugin.

---

##### openAI_chatCompletion

```tcl
openAI_chatCompletion prompt {apiKey ""} {model ""} {type ""} {options ""} {proxy false} {whatIf true} {fake false} {channel stdout} {quiet false}
```

Sends a chat completion request to the OpenAI API.

- **Arguments**:
  - `prompt` - User prompt text
  - `apiKey` - API key (optional, auto-detected)
  - `model` - Model name (optional, auto-detected)
  - `type` - Model type
  - `options` - Additional options dictionary
  - `proxy` - Use proxy service
  - `whatIf` - Use what-if mode for testing
  - `fake` - Return fake response
  - `channel` - Output channel
  - `quiet` - Suppress output
- **Returns**: AI response JSON.
- **Note**: Handles URI resolution, authentication, and ScriptWebClient setup.

---

## Test1.0 Library

### Test Constraints (constraints.eagle)

Package: `Eagle.Test`

The constraints.eagle file contains over 200 procedures for test constraint checking. These procedures are used by the test suite to determine which tests should run based on the current environment.

#### Version and Build Information

| Procedure | Description |
|-----------|-------------|
| `getKnownBuildTypes` | Returns list of known .NET build types |
| `getKnownCompileOptions` | Returns list of known compile options |
| `getKnownWindowsVersions` | Returns list of Windows OS versions |
| `getKnownPublicKeyTokenPattern` | Returns regex for known public key tokens |
| `getKnownDotNetVersions` | Returns list of known .NET Framework versions |
| `getKnownMonoVersions` | Returns list of known Mono versions |
| `getKnownDotNetCoreVersions` | Returns list of known .NET Core versions |
| `getKnownTclVersions` | Returns list of known Tcl versions |
| `filterKnownVersions versions {minimumVersion ""}` | Filters versions >= minimum |

#### Version Constraint Adders

| Procedure | Description |
|-----------|-------------|
| `addKnownDotNetConstraints generic` | Adds .NET Framework version constraints |
| `addKnownMonoConstraints generic` | Adds Mono version constraints |
| `addKnownDotNetCoreConstraints generic` | Adds .NET Core version constraints |

#### Version Utilities

| Procedure | Description |
|-----------|-------------|
| `getDotNetCoreDirectoryNameOnly path` | Extracts .NET Core directory name from path |
| `getRuntimeVersion verify` | Gets runtime version with optional verification |
| `getDottedVersion version` | Converts version to dotted format |
| `getDotlessVersion version` | Removes dots from version |
| `getMajorMinorVersion version` | Extracts major.minor components |

#### Test Settings

| Procedure | Description |
|-----------|-------------|
| `loadTestSettings channel {suffix ""} {quiet false}` | Loads test configuration from file |

#### List Utilities

| Procedure | Description |
|-----------|-------------|
| `lpermute list` | Generates all permutations of a list |
| `lcombine list wantLength` | Generates combinations of specified length |
| `alwaysFullInterpReady` | Checks if interpreter is always ready |

#### Executable Availability Checks

| Procedure | Description |
|-----------|-------------|
| `canExecComSpec` | Checks if OS shell can be executed |
| `canExecWhoAmI` | Checks if "whoami" command works |
| `canExecTclShell` | Checks if native Tcl shell works |
| `canExecFossil` | Checks if Fossil VCS works |
| `canExecFsUtil` | Checks if Windows fsutil works |
| `canExecVsWhere` | Checks if vswhere tool works |
| `canExecUlimit` | Checks if ulimit works |
| `canExecCc` | Checks if C compiler works |
| `canExecWmic` | Checks if wmic command works |

#### Pre-Test Checks (checkFor* procedures)

These procedures add test constraints based on environmental checks:

| Procedure | Description |
|-----------|-------------|
| `checkForTestSuiteFiles channel` | Verifies required test files exist |
| `checkForPlatform channel` | Identifies current platform |
| `checkForWindowsVersion channel` | Identifies Windows version |
| `checkForScriptLibrary channel` | Verifies script library location |
| `checkForEnvironmentVariable channel name {notEmpty true} {constraint ""}` | Checks environment variable |
| `checkForVariable channel name {notEmpty true} {constraint ""}` | Checks global variable |
| `checkForPackage channel pattern` | Checks if package can be loaded |
| `checkForFossil channel` | Checks Fossil availability |
| `checkForVisualStudioViaVsWhere channel` | Detects Visual Studio |
| `checkForEagle channel` | Verifies running in Eagle |

#### Feature Checks

| Procedure | Description |
|-----------|-------------|
| `checkForSymbols channel name {constraint ""}` | Checks for debug symbols |
| `checkForLogFile channel` | Verifies log file accessibility |
| `checkForGaruda channel` | Checks for Garuda |
| `checkForShell channel` | Verifies shell availability |
| `checkForDebug channel` | Checks debug mode |
| `checkForTk channel` | Checks Tk availability |
| `checkForVersion channel` | Gets interpreter version |
| `checkForCommand channel name` | Checks command availability |
| `checkForSubCommand channel names` | Checks sub-command exists |
| `checkForNamespaces channel quiet` | Checks namespace support |
| `checkForTestExec channel quiet` | Checks exec availability |

#### TIP Support Checks

| Procedure | Description |
|-----------|-------------|
| `checkForTip127 channel` | TIP 127 support |
| `checkForTip182 channel` | TIP 182 support |
| `checkForTip194 channel` | TIP 194 support |
| `checkForTip207 channel` | TIP 207 support |
| `checkForTip237 channel` | TIP 237 support |
| `checkForTip241 channel` | TIP 241 support |
| `checkForTip285 channel` | TIP 285 support |
| `checkForTip405 channel` | TIP 405 support |
| `checkForTip421 channel` | TIP 421 support |
| `checkForTip426 channel` | TIP 426 support |
| `checkForTip429 channel` | TIP 429 support |
| `checkForTip440 channel` | TIP 440 support |
| `checkForTip461 channel` | TIP 461 support |
| `checkForTip463 channel` | TIP 463 support |
| `checkForTip471 channel` | TIP 471 support |
| `checkForTip508 channel` | TIP 508 support |
| `checkForTip521 channel` | TIP 521 support |

#### Performance/Resource Checks

| Procedure | Description |
|-----------|-------------|
| `checkForTiming channel threshold {constraint ""}` | Checks timing test threshold |
| `checkForPerformance channel` | Checks performance testing enabled |
| `checkForBigLists channel` | Checks big list testing enabled |
| `checkForProcessorIntensive channel` | Checks processor-intensive tests |
| `checkForFileSystemIntensive channel` | Checks filesystem-intensive tests |
| `checkForTimeIntensive channel` | Checks time-intensive tests |
| `checkForFullTest channel` | Checks full test mode |
| `checkForMemoryIntensive channel {memoryThreshold 3000000000}` | Checks memory for tests |
| `checkForStackIntensive channel` | Checks stack-intensive tests |
| `checkForStackSize channel` | Checks available stack size |

#### Interactive/Network Checks

| Procedure | Description |
|-----------|-------------|
| `checkForInteractive channel` | Checks interactive user |
| `checkForInteractiveFocus channel` | Checks window focus |
| `checkForInteractiveCommand channel name` | Checks interactive command |
| `checkForUserInteraction channel` | Checks user interaction allowed |
| `checkForOfflineMode channel` | Checks offline mode |
| `checkForNetwork channel host timeout {successOnly false}` | Checks network connectivity |
| `checkForInternet channel uri timeout` | Checks internet connectivity |
| `checkForTlsOk channel hosts timeout` | Checks TLS/SSL |
| `canPing {varName ""}` | Checks ping capability |

#### Build/Compile Checks

| Procedure | Description |
|-----------|-------------|
| `checkForCompileOption channel name` | Checks compile option |
| `checkForBuildType channel name` | Checks build type |
| `checkForKnownBuildTypes channel` | Checks all build types |
| `checkForKnownCompileOptions channel` | Checks all compile options |

#### Runtime Option Management

| Procedure | Description |
|-----------|-------------|
| `saveRuntimeOptions varName` | Saves current options |
| `clearRuntimeOptions {ignoreError false} {names ""}` | Clears options |
| `restoreRuntimeOptions varName {full true} {ignoreError false}` | Restores options |

#### .NET/Mono Specific Checks

| Procedure | Description |
|-----------|-------------|
| `checkForSystemDataSQLite channel` | Checks System.Data.SQLite |
| `checkForSecurity channel` | Checks security settings |
| `checkForStrongName channel` | Checks strong name signing |
| `checkForCertificate channel` | Checks certificate availability |
| `checkForCompileCSharp channel` | Checks C# compilation |
| `checkForAdministrator channel` | Checks admin privileges |
| `checkForHost channel` | Checks host environment |
| `checkForPrimaryThread channel` | Checks primary thread |
| `checkForDefaultAppDomain channel` | Checks AppDomain |
| `checkForRuntime channel` | Checks runtime type |
| `checkForFrameworkVersion channel` | Checks .NET Framework version |
| `checkForRuntimeVersion channel` | Checks runtime version |
| `checkForProcessBits channel` | Checks 32-bit vs 64-bit |
| `checkForMachine channel bits machine` | Checks architecture |
| `checkForDynamicLoading channel` | Checks dynamic loading |
| `checkForWindowsForms channel` | Checks Windows Forms |
| `checkForWindowsPresentationFoundation channel` | Checks WPF |
| `checkForDatabase channel type string` | Checks database availability |
| `checkForAssembly channel name` | Checks .NET assembly |
| `checkForObjectMember channel object member {constraint ""}` | Checks object member |

#### Framework Installation Checks

| Procedure | Description |
|-----------|-------------|
| `checkForNetFx40 channel` | .NET Framework 4.0 |
| `checkForNetFx45 channel` | .NET Framework 4.5 |
| `getFrameworkSetup45Value` | .NET 4.5 installation status |
| `getFrameworkSetup451Value` | .NET 4.5.1 installation status |
| `getFrameworkSetup452Value` | .NET 4.5.2 installation status |
| `getFrameworkSetup46Value` | .NET 4.6 installation status |
| `getFrameworkSetup461Value` | .NET 4.6.1 installation status |
| `getFrameworkSetup462Value` | .NET 4.6.2 installation status |
| `getFrameworkSetup47Value` | .NET 4.7 installation status |
| `getFrameworkSetup471Value` | .NET 4.7.1 installation status |
| `getFrameworkSetup472Value` | .NET 4.7.2 installation status |
| `getFrameworkSetup48Value` | .NET 4.8 installation status |
| `getFrameworkSetup481Value` | .NET 4.8.1 installation status |

#### OS Detection

| Procedure | Description |
|-----------|-------------|
| `getOsBuild` | Gets Windows build number |
| `isOsWindows11` | Checks for Windows 11 |
| `isOsReleaseId releaseId` | Checks Windows release ID |
| `isOsProductType type` | Checks Windows product type |

#### Tcl/Third-Party Tool Checks

| Procedure | Description |
|-----------|-------------|
| `checkForTclInstalls channel` | Checks Tcl installations |
| `checkForTclReady channel` | Checks Tcl readiness |
| `checkForTclSelect channel` | Checks Tcl select() |
| `checkForTclShell channel` | Checks tclsh |
| `checkForTkPackage channel` | Checks Tk package |
| `checkForPowerShell channel` | Checks PowerShell |
| `checkForWix channel` | Checks WiX toolset |

#### Debugging Checks

| Procedure | Description |
|-----------|-------------|
| `checkForNativeDebugger channel` | Checks native debugger |
| `checkForManagedDebugger channel` | Checks managed debugger attached |
| `checkForScriptDebugger channel` | Checks script debugger |
| `checkForScriptDebuggerInterpreter channel` | Checks debugger interpreter |

---

## System Aliases

When the Eagle script library is loaded, the following system aliases are created for convenience:

| Alias | Expands To | Description |
|-------|-----------|-------------|
| `igap` | `object invoke -flags +NonPublic Interpreter.GetActive` | Get active interpreter (non-public) |
| `iga` | `object invoke Interpreter.GetActive` | Get active interpreter |
| `mrogsf` | `interp maybereadorgetscriptfile` | Maybe read or get script file |
| `rogsf` | `interp readorgetscriptfile` | Read or get script file |
| `oc` | `object create -alias` | Create object with alias |
| `ocp` | `object create -alias -flags +NonPublic` | Create object (non-public) |
| `oi` | `object invoke` | Invoke object method |
| `oip` | `object invoke -flags +NonPublic` | Invoke object method (non-public) |
| `oic` | `object invoke -create` | Invoke with create |
| `oicp` | `object invoke -create -flags +NonPublic` | Invoke with create (non-public) |
| `nq` | `sql execute -execute NonQuery -format list` | Execute SQL (non-query) |
| `scalar` | `sql execute -execute Scalar -format list` | Execute SQL (scalar) |
| `reader` | `sql execute -execute Reader -format list` | Execute SQL (reader) |

---

## Summary Statistics

### Eagle1.0 Library
- **Total files**: 28
- **Files with procedures**: 24
- **Stub files**: 4 (embed.eagle, vendor.eagle, pkgIndex.eagle, test.eagle)
- **Estimated procedures**: 150+

### Test1.0 Library
- **Total files**: 5
- **Files with procedures**: 1 (constraints.eagle)
- **Procedures**: 207+

### Combined Total
- **All files**: 33
- **All procedures**: 350+

---

## Advanced Usage Patterns and Examples

This section documents common usage patterns, idioms, and best practices discovered through analysis of the Eagle test suite.

### Test Framework Usage Patterns

#### Basic Test Structure

```tcl
# Standard test file header
package require Eagle
package require Eagle.Library
package require Eagle.Test

runTestPrologue

###############################################################################

# Define test-specific setup/cleanup
proc testSetup {} {
    # Create test resources
}

proc testCleanup {} {
    # Clean up test resources
}

###############################################################################

# Standard test with setup and cleanup
test example-1.1 {description of test} -setup {
    testSetup
} -body {
    # Test implementation
    set result [someOperation]
    return $result
} -cleanup {
    testCleanup
} -result {expected result}

###############################################################################

runTestEpilogue
unset -nocomplain test_channel
```

#### Constraint-Based Test Skipping

```tcl
# Skip test based on platform
test platform-1.1 {Windows-only test} -constraints {
    eagle windows
} -body {
    # Windows-specific code
}

# Skip test based on runtime
test runtime-1.1 {Mono-specific test} -constraints {
    eagle mono
} -body {
    # Mono-specific code
}

# Skip test based on available features
test feature-1.1 {requires compilation} -constraints {
    eagle compileCSharp
} -body {
    # Test C# compilation
}

# Multiple constraints (all must be satisfied)
test multi-1.1 {complex requirements} -constraints {
    eagle windows administrator compileCSharp
} -body {
    # Requires all three conditions
}
```

#### Expected Error Testing

```tcl
# Test that expects an error
test error-1.1 {division by zero} -body {
    expr {1 / 0}
} -returnCodes error -result {divide by zero}

# Test with error pattern matching
test error-1.2 {file not found} -body {
    open /nonexistent/file r
} -returnCodes error -match glob -result {*no such file*}

# Test with regexp error matching
test error-1.3 {invalid argument} -body {
    someCommand -invalidoption
} -returnCodes error -match regexp -result {bad option.*invalidoption}
```

#### Output Verification

```tcl
# Capture and verify output
test output-1.1 {verify puts output} -body {
    set output [capture {
        puts "Hello, World!"
    }]
    return $output
} -result {Hello, World!}

# Verify output pattern
test output-1.2 {verify log format} -body {
    set output [capture {
        tputs $test_channel "Test message"
    }]
    string match "*Test message*" $output
} -result {1}
```

### Object Lifecycle Patterns

#### Proper Resource Management

```tcl
# Pattern 1: Try/finally for guaranteed cleanup
proc processFile {filename} {
    set fh [open $filename r]
    try {
        set content [read $fh]
        # Process content...
        return $content
    } finally {
        close $fh
    }
}

# Pattern 2: Object disposal with cleanup
proc useClrObject {} {
    set obj [object create -alias System.IO.MemoryStream]
    try {
        $obj Write [encoding convertto utf-8 "Hello"] 0 5
        $obj Position 0
        # Use the object...
    } finally {
        object dispose $obj
    }
}

# Pattern 3: Multiple resources
proc processWithMultipleResources {} {
    set resources [list]
    try {
        lappend resources [object create -alias System.IO.FileStream \
            $inputFile Read]
        lappend resources [object create -alias System.IO.FileStream \
            $outputFile Write]
        # Use resources...
    } finally {
        foreach resource $resources {
            catch {object dispose $resource}
        }
    }
}
```

#### Reference Counting and Cleanup

```tcl
# Check reference count before disposal
proc safeDispose {objVar} {
    upvar 1 $objVar obj
    if {[isNonNullObjectHandle $obj]} {
        set refCount [object refcount $obj]
        if {$refCount <= 1} {
            object dispose $obj
        }
        unset obj
    }
}

# Cleanup pattern for test procedures
proc cleanupTestObjects {} {
    # Remove all test objects matching pattern
    foreach obj [info objects test_*] {
        catch {object dispose $obj}
    }
    object cleanup -pattern test_*
}
```

### Platform-Specific Code Patterns

#### Conditional Execution by Platform

```tcl
# Execute platform-specific code
proc getPlatformTempDir {} {
    if {[isWindows]} {
        return $env(TEMP)
    } elseif {[isMacOS]} {
        return "/tmp"
    } else {
        # Linux/Unix
        if {[info exists env(TMPDIR)]} {
            return $env(TMPDIR)
        }
        return "/tmp"
    }
}

# Platform-specific path handling
proc normalizePath {path} {
    if {[isWindows]} {
        return [string map {/ \\} $path]
    } else {
        return [string map {\\ /} $path]
    }
}

# Runtime-specific code
proc getGarbageCollector {} {
    if {[isMono]} {
        return "Mono GC"
    } elseif {[isDotNetCore]} {
        return "CoreCLR GC"
    } else {
        return ".NET Framework GC"
    }
}
```

#### Feature Detection Pattern

```tcl
# Check for feature before using it
proc maybeUseFeature {} {
    if {[llength [info commands tcl]] > 0 && [tcl ready]} {
        # Tcl integration available
        return [tcl eval [tcl primary] {expr {2 + 2}}]
    } else {
        # Fallback to Eagle-only implementation
        return [expr {2 + 2}]
    }
}

# Check for .NET assembly before using it
proc maybeUseAssembly {assemblyName} {
    if {[catch {
        object invoke System.Reflection.Assembly LoadWithPartialName \
            $assemblyName
    } assembly]} {
        return false
    }
    return [expr {$assembly ne ""}]
}
```

### Data Processing Patterns

#### List Processing with Functional Style

```tcl
# Filter list elements
proc lfilter {list condition} {
    set result [list]
    foreach item $list {
        if {[uplevel 1 [list expr $condition]]} {
            lappend result $item
        }
    }
    return $result
}

# Example usage
set numbers {1 2 3 4 5 6 7 8 9 10}
set evens [lfilter $numbers {$item % 2 == 0}]
# evens = {2 4 6 8 10}

# Map with transformation
set doubled [lmap x $numbers {expr {$x * 2}}]
# doubled = {2 4 6 8 10 12 14 16 18 20}

# Reduce/fold pattern
proc lreduce {list initial script} {
    set accumulator $initial
    foreach item $list {
        set accumulator [uplevel 1 [list apply $script $accumulator $item]]
    }
    return $accumulator
}

# Sum all elements
set sum [lreduce $numbers 0 {{acc x} {expr {$acc + $x}}}]
```

#### Key-Value List Operations

**Note**: Eagle does NOT have the `dict` command. Use key-value lists (pairs) instead, along with `getDictionaryValue` from auxiliary.eagle.

```tcl
# Build key-value list from pairs
proc kvlist_from_pairs {args} {
    set result [list]
    foreach {key value} $args {
        lappend result $key $value
    }
    return $result
}

# Merge multiple key-value lists (later values win)
proc kvlist_merge {args} {
    array set result {}
    foreach kvlist $args {
        foreach {key value} $kvlist {
            set result($key) $value
        }
    }
    return [array get result]
}

# Get value from key-value list with default
# Use getDictionaryValue from auxiliary.eagle
proc kvlist_get {kvlist key {default ""}} {
    foreach {k v} $kvlist {
        if {$k eq $key} {
            return $v
        }
    }
    return $default
}

# Iterate over key-value list pairs
proc kvlist_foreach {kvlist varNames body} {
    upvar 1 [lindex $varNames 0] key [lindex $varNames 1] value
    foreach {key value} $kvlist {
        uplevel 1 $body
    }
}
```

### String Processing Patterns

#### Parsing and Extraction

```tcl
# Extract all matches from string
proc extractAll {pattern string} {
    set matches [list]
    set start 0
    while {[regexp -start $start -indices -- $pattern $string match]} {
        lassign $match matchStart matchEnd
        lappend matches [string range $string $matchStart $matchEnd]
        set start [expr {$matchEnd + 1}]
    }
    return $matches
}

# Parse key=value pairs into key-value list
proc parseKeyValuePairs {string {separator "="}} {
    set result [list]
    foreach line [split $string \n] {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} continue
        if {[set pos [string first $separator $line]] > 0} {
            set key [string trim [string range $line 0 $pos-1]]
            set value [string trim [string range $line $pos+1 end]]
            lappend result $key $value
        }
    }
    return $result
}

# Template substitution using key-value list
proc substituteTemplate {template vars} {
    foreach {name value} $vars {
        set template [string map [list \${$name} $value] $template]
    }
    return $template
}
```

#### Safe String Handling

```tcl
# Escape for shell usage
proc shellEscape {string} {
    if {[isWindows]} {
        # Windows escaping
        return [format {"%s"} [string map {\" \\\"} $string]]
    } else {
        # Unix shell escaping
        return [format {'%s'} [string map {' '\''} $string]]
    }
}

# Truncate with ellipsis
proc truncate {string maxLength {suffix "..."}} {
    if {[string length $string] <= $maxLength} {
        return $string
    }
    set cutLength [expr {$maxLength - [string length $suffix]}]
    return "[string range $string 0 $cutLength-1]$suffix"
}
```

### Error Handling Patterns

#### Graceful Error Recovery

```tcl
# Retry with exponential backoff
proc retryWithBackoff {script {maxAttempts 3} {baseDelay 100}} {
    set attempt 0
    while {$attempt < $maxAttempts} {
        incr attempt
        if {![catch {uplevel 1 $script} result options]} {
            return $result
        }
        if {$attempt < $maxAttempts} {
            set delay [expr {$baseDelay * (1 << ($attempt - 1))}]
            after $delay
        }
    }
    # Re-raise last error
    return -options $options $result
}

# Multiple fallback strategies
proc withFallbacks {scripts} {
    set lastError ""
    foreach script $scripts {
        if {![catch {uplevel 1 $script} result]} {
            return $result
        }
        set lastError $result
    }
    error "All strategies failed. Last error: $lastError"
}
```

#### Structured Error Information

```tcl
# Create structured error
proc raiseStructuredError {code message {details ""}} {
    set errorCode [list MYAPP $code]
    if {$details ne ""} {
        lappend errorCode $details
    }
    return -code error -errorcode $errorCode $message
}

# Handle structured error
proc handleStructuredError {script} {
    if {[catch $script result options]} {
        # Use getDictionaryValue from auxiliary.eagle
        set errorCode [getDictionaryValue $options -errorcode]
        if {[lindex $errorCode 0] eq "MYAPP"} {
            set code [lindex $errorCode 1]
            switch $code {
                "NOT_FOUND" { return [handleNotFound $result] }
                "PERMISSION" { return [handlePermission $result] }
                default { return [handleGeneric $result] }
            }
        }
        # Re-raise non-application errors
        return -options $options $result
    }
    return $result
}
```

### Debugging and Logging Patterns

#### Conditional Debug Output

```tcl
# Debug output with level control
proc debugLog {level message} {
    global debugLevel
    if {![info exists debugLevel]} {
        set debugLevel 0
    }
    if {$level <= $debugLevel} {
        set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
        puts stderr "\[$timestamp\] DEBUG($level): $message"
    }
}

# Trace procedure execution
proc traceProc {procName} {
    trace add execution $procName enter [list traceEnter $procName]
    trace add execution $procName leave [list traceLeave $procName]
}

proc traceEnter {procName args} {
    puts "ENTER: $procName [lindex $args 0]"
}

proc traceLeave {procName args} {
    puts "LEAVE: $procName -> [lindex $args 1]"
}
```

#### Performance Measurement

```tcl
# Measure execution time
proc measureTime {script {iterations 1}} {
    set start [clock microseconds]
    for {set i 0} {$i < $iterations} {incr i} {
        uplevel 1 $script
    }
    set elapsed [expr {[clock microseconds] - $start}]
    return [list \
        total [expr {$elapsed / 1000.0}]ms \
        per_iteration [expr {$elapsed / 1000.0 / $iterations}]ms]
}

# Memory usage tracking (Eagle-specific)
proc trackMemory {script} {
    if {[isEagle]} {
        set before [debug memory]
        set result [uplevel 1 $script]
        set after [debug memory]
        return [list result $result \
            memory_delta [expr {$after - $before}]]
    } else {
        return [list result [uplevel 1 $script] memory_delta unknown]
    }
}
```

### Timer and Polling Patterns

**Note**: Eagle does NOT support `fileevent` for asynchronous I/O. Use timer-based polling or synchronous operations instead. Eagle does support `after` for scheduling callbacks.

#### Timer-Based Operations

```tcl
# Timer-based polling with timeout
proc pollUntil {condition timeout interval} {
    set deadline [expr {[clock milliseconds] + $timeout}]
    while {[clock milliseconds] < $deadline} {
        if {[uplevel 1 $condition]} {
            return true
        }
        after $interval
    }
    return false
}

# Schedule callback after delay
proc scheduleOperation {delayMs script} {
    after $delayMs [list uplevel #0 $script]
}

# Periodic execution using after
proc repeatEvery {intervalMs script} {
    uplevel #0 $script
    after $intervalMs [list repeatEvery $intervalMs $script]
}
```

#### Synchronous File Operations

```tcl
# Read file synchronously
proc readFileSync {filename} {
    set fh [open $filename r]
    try {
        set content [read $fh]
        return $content
    } finally {
        close $fh
    }
}

# Process file line by line (memory efficient)
proc processFileLines {filename callback} {
    set fh [open $filename r]
    try {
        while {[gets $fh line] >= 0} {
            # Eagle has no {*} operator - use eval for argument expansion
            uplevel 1 [concat $callback [list $line]]
        }
    } finally {
        close $fh
    }
}
```

### Configuration and Settings Patterns

#### Configuration File Handling

```tcl
# Load configuration from file (uses array internally)
proc loadConfig {filename {defaults {}}} {
    array set config {}
    # Load defaults first
    foreach {key value} $defaults {
        set config($key) $value
    }
    if {[file exists $filename]} {
        set fh [open $filename r]
        try {
            set content [read $fh]
            foreach line [split $content \n] {
                set line [string trim $line]
                # Skip comments and empty lines
                if {$line eq "" || [string match "#*" $line]} continue
                if {[regexp {^(\w+)\s*=\s*(.*)$} $line -> key value]} {
                    set config($key) [string trim $value]
                }
            }
        } finally {
            close $fh
        }
    }
    return [array get config]
}

# Save configuration to file (config is key-value list)
proc saveConfig {filename config} {
    set fh [open $filename w]
    try {
        puts $fh "# Configuration file"
        puts $fh "# Generated: [clock format [clock seconds]]"
        puts $fh ""
        foreach {key value} $config {
            puts $fh "$key = $value"
        }
    } finally {
        close $fh
    }
}
```

#### Environment Variable Handling

```tcl
# Get environment variable with default
proc getEnv {name {default ""}} {
    global env
    if {[info exists env($name)]} {
        return $env($name)
    }
    return $default
}

# Set environment variable if not already set
proc setEnvDefault {name value} {
    global env
    if {![info exists env($name)]} {
        set env($name) $value
        return true
    }
    return false
}

# Expand environment variables in string
proc expandEnvVars {string} {
    global env
    set result $string
    foreach {match var} [regexp -all -inline {\$(\w+)} $string] {
        if {[info exists env($var)]} {
            set result [string map [list $match $env($var)] $result]
        }
    }
    return $result
}
```

---

## Notes

1. All procedures in the `::Eagle` namespace are designed to be used in both Eagle and native Tcl unless otherwise noted.

2. Procedures marked "(Eagle only)" use Eagle-specific features and will not work in native Tcl.

3. The test constraint procedures are primarily used internally by the Eagle test suite but can be used for custom constraint checking.

4. Many procedures support optional parameters with sensible defaults to simplify common use cases.

5. Error handling varies by procedure - some return error indicators, others raise script errors. Check individual documentation for details.

6. The advanced patterns section provides reusable idioms that can be adapted for your specific use cases.

7. When working with .NET objects, always ensure proper cleanup to avoid resource leaks.
