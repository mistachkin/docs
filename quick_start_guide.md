# Eagle Quick Start Guide

> **For AI agents**: This is an introductory guide for new Eagle users. For comprehensive command syntax, see [core_language.md](core_language.md). For worked examples, see [core_examples.md](core_examples.md). For script library procedures, see [core_script_library.md](core_script_library.md). For Eagle-specific tips and idioms, see [tips_and_tricks.md](tips_and_tricks.md).

## Table of Contents

- [What is Eagle](#what-is-eagle)
- [How to Obtain Eagle](#how-to-obtain-eagle)
  - [NuGet Package](#nuget-package)
  - [Docker Image](#docker-image)
  - [Release Binaries](#release-binaries)
  - [Building from Source](#building-from-source)
- [Running the Eagle Shell](#running-the-eagle-shell)
  - [Interactive Mode (REPL)](#interactive-mode-repl)
  - [Running a Script File](#running-a-script-file)
  - [Evaluating from the Command Line](#evaluating-from-the-command-line)
- [Eagle Language Basics](#eagle-language-basics)
  - [Hello World](#hello-world)
  - [Variables](#variables)
  - [Substitution](#substitution)
  - [Grouping](#grouping)
  - [Arrays](#arrays)
  - [Control Flow](#control-flow)
  - [Procedures](#procedures)
  - [Lists](#lists)
  - [Strings](#strings)
  - [Expressions](#expressions)
- [Accessing .NET from Eagle](#accessing-net-from-eagle)
  - [Loading Assemblies and Importing Namespaces](#loading-assemblies-and-importing-namespaces)
  - [Creating Objects](#creating-objects)
  - [Calling Methods and Properties](#calling-methods-and-properties)
  - [Object Lifecycle and Cleanup](#object-lifecycle-and-cleanup)
  - [A Complete Example: Windows Forms](#a-complete-example-windows-forms)
- [Where to Go Next](#where-to-go-next)

---

## What is Eagle

Eagle (Extensible Adaptable Generalized Logic Engine) is an implementation of the Tcl scripting language for the Common Language Runtime (CLR), written entirely in C#. It provides a Tcl-compatible language with full .NET interoperability, allowing scripts to create .NET objects, call methods, access properties, and interact with the entire .NET ecosystem.

Eagle supports .NET Framework 2.0 through 4.8.1, .NET Standard 2.0 and 2.1, and the Mono runtime, on all their supported platforms.

---

## How to Obtain Eagle

### NuGet Package

The simplest way to add Eagle to a .NET project is via NuGet:

```
dotnet add package Eagle
```

Or from the Package Manager Console in Visual Studio:

```
Install-Package Eagle
```

Package page: https://www.nuget.org/packages/Eagle

### Docker Image

Eagle is available as a Docker image for containerized environments:

```bash
docker pull mistachkin/eagle
```

Run the Eagle shell interactively:

```bash
docker run -it mistachkin/eagle
```

Image page: https://hub.docker.com/r/mistachkin/eagle

### Release Binaries

Pre-built release binaries can be downloaded from:

- Download page: https://eagle.to/download_full.html
- Example release URL: https://download.eagle.to/releases/1.0.8734.30319/EagleBinaryNetFx40_1.0.8734.30319.exe

### Building from Source

Eagle includes solution files for Visual Studio 2005 through 2022, as well as .NET Standard. There are three primary ways to build:

#### Windows Command Line

From the repository root, run the build script:

```
Library\Tools\build.bat
```

This uses the included build tooling to compile Eagle for the default target platform.

#### Cross-Platform Command Line (.NET Standard)

Use the `dotnet` CLI to build the .NET Standard solution:

```
dotnet build EagleNetStandard2X.sln /property:EagleBuildType=NetStandard21 /property:EaglePatchLevel=false
```

This works on Windows, macOS, and Linux wherever the .NET SDK is installed.

#### Visual Studio

1. Open the appropriate solution file for your Visual Studio version (e.g., `Eagle.sln`, `EagleNetStandard2X.sln`).
2. Select the desired build configuration (Debug or Release).
3. Use **Build > Build Solution** (Ctrl+Shift+B) or **Build > Rebuild All**.

The repository contains multiple `.sln` files targeting different framework versions and Visual Studio editions.

---

## Running the Eagle Shell

### Interactive Mode (REPL)

Launch the Eagle shell executable without arguments to enter interactive mode:

```
EagleShell.exe
```

You will see a prompt where you can type commands and see results immediately:

```
% puts "Hello from Eagle!"
Hello from Eagle!
% expr {2 + 2}
4
```

Type `exit` or press Ctrl+C to leave the interactive shell. For a full list of interactive commands, see the Interactive Commands section in [core_language.md](core_language.md).

### Running a Script File

Use `-file` to specify a script file to evaluate:

```
EagleShell.exe -file myscript.eagle
```

### Evaluating from the Command Line

Use the `-evaluate` option to evaluate a script directly:

```
EagleShell.exe -evaluate "puts {Hello from the command line!}"
```

For a complete list of shell options, see the Eagle Shell Command Line Options section in [core_language.md](core_language.md).

---

## Eagle Language Basics

Eagle uses Tcl syntax: everything is a command followed by arguments, separated by whitespace. The language follows a simple rule — **everything is a string** — but provides rich operations on lists, expressions, and .NET objects.

### Hello World

```tcl
puts "hello world"
# Prints: hello world
```

`puts` writes a string to standard output followed by a newline.

### Variables

Use `set` to assign a variable, and `$` to read its value:

```tcl
set x 1
puts $x
# Prints: 1

incr x
puts $x
# Prints: 2

lappend x 2
puts $x
# Prints: 2 2
```

- `set varName value` assigns a value; `set varName` reads it.
- `incr` increments an integer variable.
- `lappend` appends an element to a list stored in a variable.

### Substitution

Eagle performs three kinds of substitution inside double-quoted strings and command bodies:

```tcl
set x 1
puts "variable: $x, command: [set x], backslash: \""
# Prints: variable: 1, command: 1, backslash: "
```

- `$x` — variable substitution
- `[set x]` — command substitution (evaluates the command and inserts the result)
- `\"` — backslash substitution (inserts a literal double-quote)

### Grouping

There are three grouping mechanisms:

```tcl
set x 1

puts "grouping with quotes, x = $x"
# Prints: grouping with quotes, x = 1

puts {grouping with braces, x = $x}
# Prints: grouping with braces, x = $x

proc grouping { args } { return [info level [info level]] }
puts [grouping with brackets, x = $x]
# Prints: grouping with brackets, x = 1
```

- **Double quotes** (`"..."`) — group words into one argument; substitutions are performed.
- **Braces** (`{...}`) — group words into one argument; no substitutions are performed.
- **Brackets** (`[...]`) — command substitution; the enclosed command is evaluated and its result is inserted.

### Arrays

Arrays are collections of variables indexed by string keys:

```tcl
set y(1) 1
puts $y(1)
;# Prints: 1

set y(two) 2
puts $y(two)
;# Prints: 2

array names y
;# Returns: 1 two (order may vary)
```

Use `array names`, `array get`, `array set`, and `array size` to work with arrays. See [core_language.md](core_language.md#cmd-array) for full details.

### Control Flow

#### if / elseif / else

```tcl
set x 15
if {$x > 10} then {
  set result large
} elseif {$x > 5} then {
  set result medium
} else {
  set result small
}
;# result is large
```

#### for (C-style loop)

```tcl
for {set i 0} {$i < 5} {incr i} {
  puts $i
}
# Prints: 0 1 2 3 4 (one per line)
```

#### foreach (iterate over a list)

```tcl
foreach fruit {apple banana cherry} {
  puts $fruit
}
# Prints: apple banana cherry (one per line)
```

#### while

```tcl
set i 0
while {$i < 3} {
  puts $i
  incr i
}
# Prints: 0 1 2 (one per line)
```

**Important**: Always brace your conditions (`{$x > 10}`, not `"$x > 10"`) to avoid premature substitution.

### Procedures

Use `proc` to define reusable procedures:

```tcl
proc greet {name} {
  return [appendArgs "Hello, " $name !]
}
greet World
;# Returns: Hello, World!
```

Procedures can have default argument values and variable arguments:

```tcl
proc connect {host {port 80} {timeout 30}} {
  return [appendArgs "Connecting to " $host : $port " (timeout=" $timeout )]
}
connect localhost            ;# port=80, timeout=30
connect localhost 8080       ;# timeout=30
connect localhost 443 60     ;# All specified
```

Use `args` as the last parameter to accept a variable number of arguments:

```tcl
proc sum {args} {
  set total 0
  foreach n $args { incr total $n }
  return $total
}
sum 1 2 3 4 5
;# Returns: 15
```

### Lists

Lists are ordered sequences of values. Eagle provides a rich set of list commands:

```tcl
# Create a list
set colors [list red green blue]

# Get the length
llength $colors
;# Returns: 3

# Access by index
lindex $colors 1
;# Returns: green

# Append to a list variable
lappend colors yellow
;# colors is now: red green blue yellow

# Iterate
foreach c $colors {
  puts $c
}

# Search
lsearch $colors blue
;# Returns: 2

# Sort
lsort $colors
;# Returns: blue green red yellow
```

See [core_language.md](core_language.md#lists) for the full list of commands including `linsert`, `lrange`, `lreplace`, `lsort`, `lmap`, and more.

### Strings

The `string` command provides a wide range of string operations:

```tcl
# Length
string length Eagle
;# Returns: 5

# Substring
string range "Hello, World!" 0 4
;# Returns: Hello

# Case conversion
string toupper eagle
;# Returns: EAGLE

# Pattern matching
string match *.txt report.txt
;# Returns: 1

# String mapping (search and replace)
string map {hello goodbye world universe} "hello world"
;# Returns: goodbye universe

# Type checking
string is integer 42
;# Returns: 1
```

### Expressions

The `expr` command evaluates mathematical and logical expressions. Always brace the expression for best performance and correctness:

```tcl
# Arithmetic
expr {2 + 3}           ;# Returns: 5
expr {10 / 3}          ;# Returns: 3 (integer division)
expr {10.0 / 3}        ;# Returns: 3.3333333333333335
expr {2 ** 10}         ;# Returns: 1024
expr {entier(2) ** 70} ;# Returns: 1180591620717411303424

# Comparisons
expr {5 > 3}              ;# Returns: 1
expr {"hello" eq "hello"} ;# Returns: 1

# Functions
expr {sqrt(144)} ;# Returns: 12.0
expr {abs(-5)}   ;# Returns: 5

# Ternary conditional
set x 5
expr {$x > 0 ? "positive" : "non-positive"}
;# Returns: positive
```

Eagle extends Tcl's expression operators with logical XOR (`^^`), implication (`->`), equivalence (`<->`), bit rotation (`<<<`, `>>>`), and variable assignment (`:=`). See [tips_and_tricks.md](tips_and_tricks.md#expression-enhancements) for details.

---

## Accessing .NET from Eagle

Eagle's most powerful feature is its seamless .NET interoperability through the `object` command. This lets you create .NET objects, call methods, access properties, and use the entire .NET class library from Eagle scripts.

### Loading Assemblies and Importing Namespaces

Before using types from an assembly, load it and optionally import its namespaces:

```tcl
# Load an assembly by name
object load System.Data

# Import namespaces so you can use short type names
object import System.Text System.IO

# Now you can write StringBuilder instead of System.Text.StringBuilder
set sb [object create StringBuilder]
```

### Creating Objects

Use `object create` to instantiate .NET types:

```tcl
# Create a StringBuilder
set sb [object create System.Text.StringBuilder Initial]

# Create with alias (generates a command you can call directly)
set form [object create -alias System.Windows.Forms.Form]

# Create with constructor overload selection
set dt [object create -type {int int int} System.DateTime 2024 1 15]
```

The `-alias` option creates a Tcl command named after the object handle, allowing a more natural calling syntax.

### Calling Methods and Properties

Use `object invoke` to call methods and access properties:

```tcl
set sb [object create System.Text.StringBuilder]

# Call methods
object invoke $sb Append Hello
object invoke $sb Append ", World!"

# Read a property
set length [object invoke $sb Length]
;# Returns: 13

# Call ToString
set result [object invoke $sb ToString]
;# Returns: Hello, World!

# Call static methods (use the type name instead of an object handle)
set now [object invoke System.DateTime Now]
set sqrt [object invoke System.Math Sqrt 144.0]
;# Returns: 12
```

When using `-alias`, you can call members directly on the alias command:

```tcl
set form [object create -alias System.Windows.Forms.Form]
$form Text "My Window Title"
$form Show
```

### Object Lifecycle and Cleanup

Always clean up .NET objects when you are done with them, especially objects that implement `IDisposable`. Use `try`/`finally` to guarantee cleanup:

```tcl
try {
  set stream [object create System.IO.MemoryStream]

  object invoke $stream WriteByte 65
  object invoke $stream WriteByte 66
} finally {
  if {[info exists stream]} then {
    object dispose $stream
  }
}
```

For multiple resources:

```tcl
try {
  set reader [object create System.IO.StreamReader $filename]

  set content [object invoke $reader ReadToEnd]
} finally {
  if {[info exists reader]} then {
    object dispose $reader
  }
}
```

### A Complete Example: Windows Forms

This example creates a Windows Forms window with a clickable button (requires .NET Framework with System.Windows.Forms):

```tcl
proc handleClickEvent { sender e } {
  puts stdout "I have been clicked!"
}

proc centerButton {} {
  set size [$::form -alias ClientSize]

  $::button AutoSize true
  $::button Left [expr {([$size Width] - [$::button Width]) / 2}]
  $::button Top [expr {([$size Height] - [$::button Height]) / 2}]
}

object load -import System.Windows.Forms
set form [object create -alias Form]

$form Text [appendArgs [info engine] " Test 'ex_winForms.eagle' Form Title"]
$form TopMost true
$form Show

set button [object create -alias System.Windows.Forms.Button]
set size [$form -alias ClientSize]

$button Left [expr {([$size Width] - [$button Width]) / 2}]
$button Top [expr {([$size Height] - [$button Height]) / 2}]

$button Text "Click Here"
$button add_Click handleClickEvent

object invoke $form.Controls Add $button

interp sleeptime {} 200
after 100 [list centerButton]

vwait forever
```

This demonstrates:
- Loading and importing .NET assemblies (`object load -import`)
- Creating aliased objects (`object create -alias`)
- Setting properties (`$form Text "..."`)
- Reading properties (`[$size Width]`)
- Adding event handlers (`$button add_Click handleClickEvent`)
- Accessing nested members (`$form.Controls`)

---

## Where to Go Next

### Eagle Documentation

- [Eagle Core Language](core_language.md) — Complete command reference with syntax, options, and behavior for all 121 built-in commands.
- [Eagle Core Examples](core_examples.md) — 500+ worked examples for every command and sub-command.
- [Eagle Script Library](core_script_library.md) — 580+ library procedures for platform detection, file helpers, object utilities, test framework, and more.
- [Eagle Tips and Tricks](tips_and_tricks.md) — Eagle-specific features, advanced idioms, and best practices not found in standard Tcl.
- [Eagle Native Package for Tcl (Garuda)](garuda.md) — Using Eagle from within a native Tcl environment.
- [Why Eagle?](why_eagle.md) — Feature overview, language comparisons, and use-case guidance.
- [Eagle Integration Sub-Projects](integrations.md) — MSBuild, WiX, PowerShell, and MonoDevelop integration.
- [Eagle Updater (Hippogriff)](updater.md) — Keeping Eagle up to date.

### External Tcl Resources

Since Eagle is Tcl-compatible, general Tcl resources are helpful for learning the language fundamentals:

- [Tcl 8.6 Manual Pages (Command Reference)](https://www.tcl-lang.org/man/tcl8.6/TclCmd/contents.htm)
- [Tcl Tutorial Index (Tcler's Wiki)](https://wiki.tcl-lang.org/page/Tcl+Tutorial+Index)

**Note**: Eagle is Tcl-compatible, not Tcl-identical. Some Tcl features are intentionally different or missing in Eagle (e.g., no `dict` command, no `fileevent`, no `scan`). When in doubt, verify against the Eagle documentation.
