# Eagle Tips and Tricks

> **For AI agents**: This document highlights Eagle-specific features, advanced idioms, and best practices not found in standard Tcl. For comprehensive command syntax, see [core_language.md](core_language.md). For worked examples, see [core_examples.md](core_examples.md). For script library procedures, see [core_script_library.md](core_script_library.md). For getting started, see [quick_start_guide.md](quick_start_guide.md).

This guide covers Eagle's unique capabilities and highest-value patterns. Each section provides a brief explanation, code examples, and cross-references to the full documentation.

## Table of Contents

- [String Handling](#string-handling)
  - [appendArgs: The Right Way to Concatenate Strings](#appendargs-the-right-way-to-concatenate-strings)
- [.NET Interop Patterns](#net-interop-patterns)
  - [The object Command: Full .NET Access](#the-object-command-full-net-access)
  - [Object Lifecycle: try/finally + dispose](#object-lifecycle-tryfinally--dispose)
  - [Compiling C# from Eagle](#compiling-c-from-eagle)
- [Procedures and Functions](#procedures-and-functions)
  - [Procedure Annotations](#procedure-annotations)
  - [Named Arguments with nproc and napply](#named-arguments-with-nproc-and-napply)
  - [Persistent State with scope](#persistent-state-with-scope)
- [Control Flow Enhancements](#control-flow-enhancements)
  - [do: Do-While and Do-Until Loops](#do-do-while-and-do-until-loops)
  - [try/finally: Guaranteed Cleanup](#tryfinally-guaranteed-cleanup)
- [List Operations](#list-operations)
  - [lget: Deep Nested List Access](#lget-deep-nested-list-access)
  - [lmap: Functional List Transformation](#lmap-functional-list-transformation)
  - [lremove: Remove Elements by Index](#lremove-remove-elements-by-index)
- [Expression Enhancements](#expression-enhancements)
  - [Logical Operators: ^^, ->, <->](#logical-operators----)
  - [Bit Rotation: <<<, >>>](#bit-rotation--)
  - [Variable Assignment in Expressions: :=](#variable-assignment-in-expressions-)
  - [List Membership: in, ni](#list-membership-in-ni)
  - [Mathematical Functions: log2, logx, random, randstr](#mathematical-functions-log2-logx-random-randstr)
- [Data and Encoding](#data-and-encoding)
  - [base64: Built-in Base64 Encoding](#base64-built-in-base64-encoding)
  - [hash: Cryptographic Hashing](#hash-cryptographic-hashing)
  - [guid: GUID Generation](#guid-guid-generation)
- [Networking and Data](#networking-and-data)
  - [uri: URI Parsing and Construction](#uri-uri-parsing-and-construction)
  - [sql: ADO.NET Database Access](#sql-adonet-database-access)
  - [xml: XML Serialization](#xml-xml-serialization)
- [Regular Expression Enhancements](#regular-expression-enhancements)
  - [-compiled: Precompiled Regexes](#-compiled-precompiled-regexes)
  - [-command and -eval: Programmatic Replacement](#-command-and--eval-programmatic-replacement)
  - [-options: Direct .NET RegexOptions](#-options-direct-net-regexoptions)
- [Security and Sandboxing](#security-and-sandboxing)
  - [Safe Interpreters](#safe-interpreters)
- [Testing](#testing)
  - [Built-in Test Framework: test1 and test2](#built-in-test-framework-test1-and-test2)
- [Debugging](#debugging)
  - [Variable Watchpoints](#variable-watchpoints)
  - [Single-Stepping](#single-stepping)
  - [Breakpoints and Inspection](#breakpoints-and-inspection)
- [Script Library Utilities](#script-library-utilities)
  - [Platform Detection: isEagle, isWindows, isMono, isDotNetCore](#platform-detection-iseagle-iswindows-ismono-isdotnetcore)
  - [Dictionary Access: getDictionaryValue](#dictionary-access-getdictionaryvalue)
  - [List Helpers: filter](#list-helpers-filter)
  - [File Discovery: findFilesRecursive](#file-discovery-findfilesrecursive)

---

## String Handling

### appendArgs: The Right Way to Concatenate Strings

The `appendArgs` library procedure concatenates all its arguments into a single string verbatim. Unlike `concat`, which joins arguments with spaces and treats them as list elements, `appendArgs` performs simple string concatenation without introducing whitespace or altering the structure of values.

```tcl
# concat can introduce unwanted spaces and treats values as list elements
concat "Hello," " World!"
;# Returns: Hello, World!  (note: handled as list elements)

# appendArgs concatenates exactly what you pass
appendArgs "Hello," " World!"
;# Returns: Hello, World!
```

The difference matters most when building strings that contain special characters or when you need precise control over whitespace:

```tcl
# Building a path-like string
set base "/api"
set version "v1"
set endpoint "users"
appendArgs $base / $version / $endpoint
;# Returns: /api/v1/users

# Building error messages
proc positiveInt {n} {
    if {![string is integer -strict $n] || $n <= 0} then {
        error [appendArgs "expected positive integer, got \"" $n \"]
    }
    return $n
}
```

Use `appendArgs` whenever you need to join string fragments. It is the idiomatic Eagle way to concatenate.

- **See also**: [core_script_library.md](core_script_library.md) — `appendArgs` in Auxiliary Utilities

---

## .NET Interop Patterns

### The object Command: Full .NET Access

The `object` command is Eagle's gateway to the .NET ecosystem. It lets you load assemblies, create objects, call methods, access properties, iterate collections, and manage object lifecycles.

#### Core Workflow

```tcl
# 1. Load an assembly (if not already loaded)
object load System.Data

# 2. Import namespaces for shorter type names
object import System.Text System.IO

# 3. Create an instance
set sb [object create StringBuilder "Hello"]

# 4. Call methods and properties
object invoke $sb Append ", World!"
set result [object invoke $sb ToString]
;# Returns: Hello, World!

# 5. Clean up
object dispose $sb
```

#### Aliases for Natural Syntax

The `-alias` option creates a Tcl command for the object, allowing direct member access:

```tcl
object load -import System.Windows.Forms
set form [object create -alias Form]

# Direct property access via alias
$form Text "My Window"
$form TopMost true
$form Show
```

#### Iterating .NET Collections

```tcl
set list [object create System.Collections.ArrayList]
object invoke $list Add "one"
object invoke $list Add "two"
object invoke $list Add "three"

# foreach over IEnumerable
object foreach item $list {
    puts $item
}

# lmap to collect transformed results
set upper [object lmap item $list {
    string toupper $item
}]
;# Returns: {ONE TWO THREE}
```

#### Static Methods and Properties

Use the type name instead of an object handle:

```tcl
# Static method
set sqrt [object invoke System.Math Sqrt 144.0]
;# Returns: 12

# Static property
set now [object invoke System.DateTime Now]
set newline [object invoke System.Environment NewLine]
```

#### Searching for Types

```tcl
# List loaded assemblies
object assemblies *System*

# Search for a type
object search System.Text.StringBuilder

# List types matching a pattern
object types *DataTable*
```

- **See also**: [core_language.md](core_language.md#cmd-object) — `object` command reference; [core_examples.md](core_examples.md#ex-object) — object examples

---

### Object Lifecycle: try/finally + dispose

.NET objects that implement `IDisposable` must be cleaned up. The canonical pattern uses `try`/`finally` to guarantee `object dispose` runs even if an error occurs:

```tcl
# Single resource
set stream [object create System.IO.MemoryStream]
try {
    object invoke $stream WriteByte 65
    object invoke $stream WriteByte 66
} finally {
    object dispose $stream
}
```

For multiple resources:

```tcl
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
```

Using `catch` inside `finally` prevents a disposal error from masking the original error.

- **See also**: [core_language.md](core_language.md#cmd-try) — `try` command; [core_language.md](core_language.md#cmd-object) — `object dispose`

---

### Compiling C# from Eagle

Eagle can compile C# code at runtime using the script library procedures from `csharp.eagle`. This enables dynamic code generation, testing of C# snippets, and hybrid Eagle/C# workflows.

#### Using CSharpCodeProvider (.NET Framework)

```tcl
# Check if compilation is available
if {[doesCompileCSharpWork]} then {
    # Compile C# source code in memory
    set source {
        public class Calculator {
            public static int Add(int a, int b) { return a + b; }
        }
    }
    set assembly [compileViaCSharpCodeProvider $source true false false \
        results errors]

    # Call the compiled method
    set result [object invoke Calculator Add 3 4]
    ;# Returns: 7
}
```

#### Using .NET Core SDK

```tcl
# For .NET Core / .NET 5+ environments
set assembly [compileViaDotNetCoreCSharp $source true false false \
    results errors]
```

- **See also**: [core_script_library.md](core_script_library.md) — C# Compilation (csharp.eagle)

---

## Procedures and Functions

### Procedure Annotations

Eagle provides a procedure annotation system that controls how procedures are created, called, and managed. Annotations are embedded as specially formatted comments in the procedure body.

#### <<fast>>: Disable Variable Traces

Disables variable traces and watchpoints within the procedure, eliminating trace-checking overhead on every variable read/write. Use this for performance-critical hot paths:

```tcl
proc computeIntensive {data} {; # <<fast>>
    set sum 0
    foreach item $data {
        set sum [expr {$sum + $item}]
    }
    return $sum
}
```

#### <<atomic>>: Acquire Interpreter Lock

Holds the interpreter's internal lock for the entire procedure execution, preventing concurrent access from other threads:

```tcl
proc updateSharedState {key value} {; # <<atomic>>
    variable sharedData
    set sharedData($key) $value
    return [array size sharedData]
}
```

Keep atomic procedures short to avoid blocking other threads.

#### <<inline>>: Execute in Caller's Frame

Skips creating a new call frame. The procedure body executes in the caller's variable scope, functioning like a macro:

```tcl
proc setLocal {varName value} {; # <<inline>>
    set $varName $value
}

proc example {} {
    setLocal myVar 42
    puts $myVar   ;# 42 — set by the inline procedure
}
```

#### <<private>>: Namespace-Enforced Access Control

Restricts the procedure so it can only be called from within its own namespace:

```tcl
namespace eval ::MyLib {
    proc publicApi {x} {
        return [helper $x]
    }

    proc helper {x} {; # <<private>>
        return [expr {$x * 2}]
    }
}

::MyLib::publicApi 5     ;# OK — returns 10
::MyLib::helper 5        ;# ERROR — private procedure
```

Unlike Tcl's convention of `_`-prefixed "private" names, Eagle's `<<private>>` annotation provides enforced encapsulation.

#### <<matchTypes>>: Argument Type Constraints

Enables type restriction enforcement on local variables within the procedure's call frame:

```tcl
proc typedExample {x y} {; # <<matchTypes>>
    return [expr {$x + $y}]
}
```

#### <<nonCaching>>: Disable Body Caching

Forces the interpreter to re-parse the body on each invocation rather than reusing cached parse trees:

```tcl
proc dynamicBody {code} {; # <<nonCaching>>
    eval $code
}
```

#### Combining Annotations

Multiple annotations can appear on the same line:

```tcl
proc secureHelper {x} {; # <<private>> <<fast>>
    # Both private and fast
    return [expr {$x * $x}]
}
```

**Compatibility note**: `<<inline>>` cannot be combined with `<<fast>>` or `<<matchTypes>>`. Annotations are ignored in safe interpreters.

- **See also**: [core_language.md](core_language.md#cmd-proc) — Procedure Body Annotations

---

### Named Arguments with nproc and napply

Eagle extends Tcl's procedure system with named (keyword) arguments via `nproc` and `napply`.

#### nproc: Procedures with Named Arguments

```tcl
nproc connect {host port timeout} {
    return [appendArgs "Connecting to " $host : $port " (timeout=" $timeout )]
}

# Call with named arguments in any order
connect -host localhost -port 8080 -timeout 60
;# Returns: Connecting to localhost:8080 (timeout=60)

connect -timeout 30 -port 443 -host example.com
;# Returns: Connecting to example.com:443 (timeout=30)
```

#### napply: Lambdas with Named Arguments

```tcl
napply {{x y} {expr {$x + $y}}} -x 3 -y 4
;# Returns: 7
```

Named arguments are valuable for procedures with many parameters where positional ordering is hard to remember.

- **See also**: [core_language.md](core_language.md#cmd-nproc) — `nproc`; [core_language.md](core_language.md#cmd-napply) — `napply`

---

### Persistent State with scope

The `scope` command creates persistent variable environments that survive across procedure calls. This enables stateful procedures without using global variables.

#### Counter Example

```tcl
proc counter {name} {
    scope create -open -clone -args $name
    if {![info exists count]} then {set count 0}
    incr count
    return $count
    # scope close implied on return
}

counter myCounter  ;# Returns: 1
counter myCounter  ;# Returns: 2
counter myCounter  ;# Returns: 3
scope destroy myCounter
```

How it works:
- `scope create` creates a named scope (or reuses it if it already exists).
- `-open` pushes the scope onto the call stack so its variables are accessible.
- `-clone` copies the current frame's variables into the scope on first creation.
- `-args` copies the procedure's arguments into the scope.
- The scope is implicitly closed when the procedure returns.

#### scope eval for Scoped Execution

```tcl
scope create myScope
scope eval myScope {
    set x 10
    set y 20
    expr {$x + $y}
}
;# Returns: 30

# Access variables without opening the scope
scope set myScope x
;# Returns: 10

scope destroy myScope
```

#### The -procedure Option for Auto-Naming

```tcl
proc accumulate {value} {
    scope create -open -procedure -args
    if {![info exists total]} then {set total 0}
    incr total $value
    return $total
}

accumulate 10   ;# Returns: 10
accumulate 20   ;# Returns: 30
accumulate 5    ;# Returns: 35
```

The `-procedure` option auto-generates the scope name from the enclosing procedure, so each procedure gets its own persistent state.

- **See also**: [core_language.md](core_language.md#cmd-scope) — `scope` command; [core_examples.md](core_examples.md#ex-scope) — scope examples

---

## Control Flow Enhancements

### do: Do-While and Do-Until Loops

Eagle adds the `do` loop, which executes the body at least once before testing the condition. This is not available in standard Tcl.

#### do ... while

```tcl
set i 0
set result [list]
do {
    lappend result $i
    incr i
} while {$i < 5}
;# result is {0 1 2 3 4}
```

#### do ... until

The `until` form loops while the condition is **false** (i.e., it stops when the condition becomes true):

```tcl
set j 0
do {
    incr j
} until {$j >= 5}
;# j is 5
```

`break` and `continue` work as expected inside `do` loops.

- **See also**: [core_language.md](core_language.md#cmd-do) — `do` command; [core_examples.md](core_examples.md#ex-do) — do examples

---

### try/finally: Guaranteed Cleanup

Eagle's `try`/`finally` guarantees the finally block runs even if the try block executes `return`, `break`, `continue`, or raises an error:

```tcl
proc readFirstLine {filename} {
    set fh [open $filename r]
    try {
        return [gets $fh]
    } finally {
        close $fh
    }
}
```

The finally block executes after the `return` but before the value is returned to the caller, ensuring `close` always runs. This is the standard pattern for resource cleanup in Eagle.

```tcl
# Error handling with guaranteed cleanup
set tempFile [file tempname]
set fh [open $tempFile w]
try {
    puts $fh "test data"
    error "simulated failure"
} finally {
    close $fh
    file delete -force $tempFile
}
# fh is closed and tempFile deleted even though error occurred
```

- **See also**: [core_language.md](core_language.md#cmd-try) — `try` command; [core_examples.md](core_examples.md#ex-try) — try examples

---

## List Operations

### lget: Deep Nested List Access

`lget` combines variable lookup with list indexing in a single operation. Multiple indices navigate nested lists:

```tcl
set data {{a b} {c d} {e f}}
lget data 1 0
;# Returns: c

set matrix {a b c {d e f {g h i}}}
lget matrix 0          ;# Returns: a
lget matrix end         ;# Returns: {d e f {g h i}}
lget matrix end end     ;# Returns: {g h i}
```

This is more concise than `lindex [set data] 1 0` and operates directly on the variable.

- **See also**: [core_language.md](core_language.md#cmd-lget) — `lget` command

---

### lmap: Functional List Transformation

`lmap` works like `foreach` but collects the result of each iteration into a new list. Use `continue` to skip (filter out) elements:

```tcl
# Transform: double each element
set doubled [lmap x {1 2 3 4 5} {expr {$x * 2}}]
;# Returns: {2 4 6 8 10}

# Filter: keep only positive numbers
set positive [lmap x {-3 -1 0 2 4 -5 7} {
    if {$x > 0} then {set x} else {continue}
}]
;# Returns: {2 4 7}

# Transform key-value pairs
set pairs {a 1 b 2 c 3}
set formatted [lmap {k v} $pairs {
    format "%s=%s" $k $v
}]
;# Returns: {a=1 b=2 c=3}
```

- **See also**: [core_language.md](core_language.md#cmd-lmap) — `lmap` command; [core_examples.md](core_examples.md#ex-lmap) — lmap examples

---

### lremove: Remove Elements by Index

`lremove` returns a new list with elements at the specified indices removed:

```tcl
lremove {a b c d e} 1 3
;# Returns: {a c e}

lremove {x y z w} 0 end
;# Returns: {y z}
```

- **See also**: [core_language.md](core_language.md#cmd-lremove) — `lremove` command

---

## Expression Enhancements

Eagle extends Tcl's expression system with additional operators and functions.

### Logical Operators: ^^, ->, <->

| Operator | Name | Description |
|----------|------|-------------|
| `^^` | Logical XOR | True when exactly one operand is true |
| `->` | Logical implication | False only when the first is true and the second is false |
| `<->` | Logical equivalence | True when both operands have the same truth value |

```tcl
expr {1 ^^ 0}     ;# Returns: 1 (XOR: one true, one false)
expr {1 ^^ 1}     ;# Returns: 0 (XOR: both true)
expr {1 -> 0}     ;# Returns: 0 (implication: true -> false is false)
expr {0 -> 1}     ;# Returns: 1 (implication: false -> anything is true)
expr {1 <-> 1}    ;# Returns: 1 (equivalence: both true)
expr {1 <-> 0}    ;# Returns: 0 (equivalence: different)
```

---

### Bit Rotation: <<<, >>>

Bit rotation shifts bits and wraps them around instead of discarding them:

```tcl
expr {1 <<< 31}    ;# Left rotate
expr {1 >>> 1}     ;# Right rotate
```

---

### Variable Assignment in Expressions: :=

The `:=` operator assigns a value to a variable within an expression. The variable name must be quoted:

```tcl
expr {"result" := 42}
;# Returns: 42, and sets variable 'result' to 42

# Useful for computing and storing in one step
expr {"sum" := 10 + 20 + 30}
;# Returns: 60, and sets variable 'sum' to 60
```

---

### List Membership: in, ni

Test whether a string is a member of a list, without numeric type conversion:

```tcl
expr {"b" in {a b c}}     ;# Returns: 1
expr {"d" in {a b c}}     ;# Returns: 0
expr {"d" ni {a b c}}     ;# Returns: 1 (ni = not in)
```

---

### Mathematical Functions: log2, logx, random, randstr

Eagle adds several mathematical functions not found in standard Tcl:

```tcl
# Logarithms
expr {log2(256)}            ;# Returns: 8.0
expr {logx(81, 3)}          ;# Returns: 4.0 (log base 3 of 81)

# Cryptographic random integer
expr {random()}             ;# Returns: a secure random 64-bit integer

# Random string
expr {randstr(16)}          ;# Returns: a random 16-character string

# Rounding
expr {round2(3.14159, 2)}   ;# Returns: 3.14 (round to 2 decimal places)
expr {truncate(3.99)}       ;# Returns: 3.0 (truncate toward zero)

# Sign and indicators
expr {sign(-42)}            ;# Returns: -1
expr {isfinite(1.0)}        ;# Returns: true
expr {isnan(0.0/0.0)}       ;# Returns: true

# Constants
expr {epsilon()}            ;# Machine epsilon
```

- **See also**: [core_language.md](core_language.md#expression-operators) — Expression Operators; [core_language.md](core_language.md#mathematical-functions) — Mathematical Functions

---

## Data and Encoding

### base64: Built-in Base64 Encoding

Eagle includes a native `base64` command for encoding and decoding:

```tcl
base64 encode "Hello, World!"
;# Returns: SGVsbG8sIFdvcmxkIQ==

base64 decode "SGVsbG8sIFdvcmxkIQ=="
;# Returns: Hello, World!

# Round-trip
set original "Eagle scripting!"
set encoded [base64 encode $original]
set decoded [base64 decode $encoded]
expr {$original eq $decoded}
;# Returns: 1

# Specify encoding
base64 encode -encoding utf-8 "Hello"
```

- **See also**: [core_language.md](core_language.md#cmd-base64) — `base64` command

---

### hash: Cryptographic Hashing

The `hash` command provides access to .NET's cryptographic hash algorithms:

```tcl
# SHA-256
hash normal sha256 "Hello"
;# Returns: 185f8db32271fe25f561a6fc938b2e264306ec304eda518007d1764826381969

# MD5
hash normal md5 "Hello"
;# Returns: 8b1a9953c4611296a827abf8c47804d7

# HMAC (keyed-hash message authentication code)
hash mac sha256 "message" "secret-key"

# List available algorithms
hash list
;# Returns pairs of {type name}, e.g., {normal MD5} {normal SHA1} ...
hash list normal
;# Only non-keyed algorithms
```

- **See also**: [core_language.md](core_language.md#cmd-hash) — `hash` command

---

### guid: GUID Generation

Generate and validate GUIDs/UUIDs:

```tcl
set id [guid new]
;# e.g., "550e8400-e29b-41d4-a716-446655440000"

guid isvalid $id              ;# Returns: 1
guid isvalid "not-a-guid"    ;# Returns: 0

guid isnull [guid null]       ;# Returns: 1 (all-zeros GUID)
guid isnull [guid new]        ;# Returns: 0

set a [guid new]
set b [guid new]
guid compare $a $a            ;# Returns: 0
guid compare $a $b            ;# Returns: -1 or 1
```

- **See also**: [core_language.md](core_language.md#cmd-guid) — `guid` command

---

## Networking and Data

### uri: URI Parsing and Construction

The `uri` command provides URI handling and HTTP client functionality:

```tcl
# Parse a URI into components
set parts [uri parse https://example.com:8080/path?q=test]
;# Returns dictionary with scheme, host, port, path, query

# Validate
uri isvalid https://example.com    ;# Returns: 1

# URL encoding/decoding
set encoded [uri escape Data "hello world"]
;# Returns: hello%20world
set decoded [uri unescape "hello%20world"]
;# Returns: hello world

# HTTP GET (returns content as string)
set html [uri get https://example.com/]

# HTTP POST with form data
set response [uri post -data {var1 val1 var2 val2} -- \
    https://example.com/api]

# Download file to disk
uri download https://example.com/file.zip /tmp/file.zip

# Ping a host
uri ping example.com 5000
;# Returns: {status roundtripTime ms}
```

- **See also**: [core_language.md](core_language.md#cmd-uri) — `uri` command; [core_examples.md](core_examples.md#ex-uri) — uri examples

---

### sql: ADO.NET Database Access

The `sql` command provides database access through ADO.NET:

#### Connection and Queries

```tcl
# Open a connection
set conn [sql open "Data Source=mydb.sqlite;Version=3;"]

# Scalar query
set count [sql execute -execute scalar $conn "SELECT COUNT(*) FROM users"]

# Reader query with results as nested lists
set results [sql execute -execute reader -format nestedlist $conn \
    "SELECT name, age FROM users"]
foreach row $results {
    lassign $row name age
    puts [appendArgs "Name: " $name ", Age: " $age]
}

# Parameterized query (safe from SQL injection)
set results [sql execute -execute reader $conn \
    "SELECT * FROM users WHERE age > @minAge" \
    {minAge Int32 21}]

# Close the connection
sql close $conn
```

#### Transactions

```tcl
set trans [sql transaction begin $conn]
try {
    sql execute $conn "INSERT INTO users (name) VALUES (@n)" {n String Alice}
    sql execute $conn "INSERT INTO users (name) VALUES (@n)" {n String Bob}
    sql transaction commit $trans
} finally {
    catch {sql transaction rollback $trans}
}
```

Always use parameterized queries with `{name type value}` argument lists to prevent SQL injection.

- **See also**: [core_language.md](core_language.md#cmd-sql) — `sql` command; [core_examples.md](core_examples.md#ex-sql) — sql examples

---

### xml: XML Serialization

The `xml` command handles XML serialization, deserialization, and validation:

```tcl
# Serialize a .NET object to XML
set xmlStr [xml serialize MyNamespace.Person $personObj]

# Deserialize XML back to an object
set person [xml deserialize MyNamespace.Person $xmlStr]

# Iterate over XML elements
set xmlData {<items><item>A</item><item>B</item><item>C</item></items>}
xml foreach node $xmlData {
    puts [appendArgs "Element: " $node]
}

# Validate against XSD schema
xml validate $schemaXml $documentXml
;# Returns: 1 if valid
```

- **See also**: [core_language.md](core_language.md#cmd-xml) — `xml` command; [core_examples.md](core_examples.md#ex-xml) — xml examples

---

## Regular Expression Enhancements

Eagle extends Tcl's `regexp` and `regsub` commands with several .NET-powered options.

### -compiled: Precompiled Regexes

The `-compiled` flag compiles the regex into .NET IL code for faster repeated matching:

```tcl
regexp -compiled -nocase {pattern} $text
```

Use this when matching the same pattern against many strings in a loop.

### -command and -eval: Programmatic Replacement

`regsub` supports `-command` and `-eval` modes for dynamic replacement logic:

```tcl
# -eval: evaluate the replacement as a script
regsub -all -eval {\d+} "item1 item2 item3" {
    expr {[string range $match 0 end] * 10}
}
```

### -options: Direct .NET RegexOptions

Pass .NET `RegexOptions` enum values directly for fine-grained control:

```tcl
regexp -options {IgnoreCase, Multiline} {^hello} $text
```

Additional Eagle-specific switches:

| Switch | Description |
|--------|-------------|
| `-compiled` | Compile regex to IL for performance |
| `-debug` | Show match attempts and results |
| `-ecma` | ECMAScript-compliant behavior |
| `-explicit` | Only named groups capture |
| `-reverse` | Right-to-left matching |
| `-noempty` | Skip empty matches |
| `-noculture` | Culture-invariant matching |
| `-limit n` | Limit number of matches |
| `-skip n` | Skip first n capture groups |

- **See also**: [core_language.md](core_language.md#cmd-regexp) — `regexp` command; [core_examples.md](core_examples.md#ex-regexp) — regexp examples

---

## Security and Sandboxing

### Safe Interpreters

Eagle supports safe (sandboxed) interpreters that restrict access to dangerous operations like file I/O, process execution, and .NET reflection.

#### Creating a Safe Interpreter

```tcl
set safe [interp create -safe mySafe]
interp issafe mySafe    ;# Returns: 1
```

#### Aliasing Controlled Access

Grant specific capabilities to the safe interpreter by creating aliases:

```tcl
# Allow the child to log messages through the parent
interp alias $safe safeLog {} puts

# The child can call safeLog but not puts directly
interp eval $safe {safeLog "Message from sandbox"}
;# Prints: Message from sandbox
```

#### Resource Limits

Prevent resource exhaustion in sandboxed code:

```tcl
interp recursionlimit $safe 100       ;# Max call stack depth
interp iterationlimit $safe 10000     ;# Max loop iterations
interp timeout $safe 5000             ;# 5-second execution timeout
```

#### Policy Subsystem

Eagle includes a policy subsystem for fine-grained security control:

```tcl
interp policy $safe {
    # Policy script evaluated for sensitive operations
}
```

Hidden commands can be selectively exposed:

```tcl
interp hidden $safe              ;# List hidden commands
interp invokehidden $safe source "trusted_script.tcl"
```

- **See also**: [core_language.md](core_language.md#cmd-interp) — `interp` command; [core_examples.md](core_examples.md#ex-interp) — interp examples

---

## Testing

### Built-in Test Framework: test1 and test2

Eagle includes built-in test commands for writing and running tests.

#### test1: Basic Tests

```tcl
test1 "string-length-1.1" "Test string length" {} {
    string length "hello"
} {5}

test1 "math-1.1" "Test basic arithmetic" {} {
    expr {2 + 2}
} {4}
```

Arguments: name, description, constraints, body, expected result.

#### test2: Advanced Tests with Setup/Cleanup

```tcl
test2 "file-read-1.1" "Test file reading" \
    -setup {
        set tmpFile [file tempname]
        set fh [open $tmpFile w]
        puts $fh "test data"
        close $fh
    } \
    -body {
        set fh [open $tmpFile r]
        set data [read -nonewline $fh]
        close $fh
        return $data
    } \
    -cleanup {
        file delete -force $tmpFile
    } \
    -result "test data" \
    -match exact
```

#### Testing Expected Errors

```tcl
test2 "error-1.1" "Test error handling" \
    -body {
        error "expected error"
    } \
    -returnCodes error \
    -result "expected error"
```

#### Constraint-Based Test Skipping

Constraints control when tests run. If a constraint is not satisfied, the test is skipped:

```tcl
# Platform-specific test
test2 "platform-1.1" "Unix-only test" \
    -constraints {unix} \
    -body {
        file exists /dev/null
    } \
    -result {1}

# Pattern matching
test2 "version-1.1" "Test version format" \
    -body {
        version
    } \
    -match glob \
    -result {*.*.*.*}
```

Common constraints: `unix`, `win`, `mac`, `knownBug`, `interactive`, `network`, `longRunning`.

- **See also**: [core_language.md](core_language.md#cmd-test1) — `test1`; [core_language.md](core_language.md#cmd-test2) — `test2`

---

## Debugging

Eagle includes a built-in debugger with variable watchpoints, single-stepping, and breakpoints.

### Variable Watchpoints

Monitor variable reads, writes, and unsets:

```tcl
debug watch myVar BreakOnSet     ;# Break when myVar is written
debug watch myVar BreakOnGet     ;# Break when myVar is read
debug watch myVar                ;# Query current watch flags
debug watch                      ;# List all watched variables
```

### Single-Stepping

Step through script execution one command at a time:

```tcl
debug enable true            ;# Enable the debugger
debug interactive true       ;# Required for stepping
debug step true              ;# Enable single-stepping
```

Control step count:

```tcl
debug steps 100              ;# Execute 100 steps then pause
debug steps                  ;# Query current step counter
```

### Breakpoints and Inspection

#### Demand Breakpoints

Enter the interactive debugger at any point in your script:

```tcl
debug break                            ;# Enter debugger here
debug break -nocomplain -noerror       ;# Silently skip if no debugger
```

#### Command Breakpoints

Break when specific commands are invoked:

```tcl
debug execute puts true          ;# Break on puts
debug function rand true         ;# Break on rand() in expressions
debug operator + true            ;# Break on + operator
```

#### Inspection

```tcl
debug variable -elements myArray   ;# Inspect array variable details
debug levels                       ;# Show nesting depth limits
debug stack                        ;# Stack space information
debug memory                       ;# Memory statistics
```

#### Running Without Debugger Interception

```tcl
debug run {
    # This code runs at full speed without debugger interception
    set result [expensive_computation]
}
```

- **See also**: [core_language.md](core_language.md#cmd-debug) — `debug` command; [core_examples.md](core_examples.md#ex-debug) — debug examples

---

## Script Library Utilities

The Eagle script library (`Eagle1.0`) provides commonly used utility procedures. These are available after `package require Eagle.Library`.

### Platform Detection: isEagle, isWindows, isMono, isDotNetCore

```tcl
if {[isEagle]} then {
    puts "Running in Eagle"
}

if {[isWindows]} then {
    set pathSep ";"
} else {
    set pathSep ":"
}

if {[isDotNetCore]} then {
    puts "Running on .NET Core"
} elseif {[isMono]} then {
    puts "Running on Mono"
}
```

These procedures return non-zero if the condition is true, zero otherwise.

- **See also**: [core_script_library.md](core_script_library.md) — Platform Detection (platform.eagle)

---

### Dictionary Access: getDictionaryValue

Eagle does not have the Tcl `dict` command. Instead, use key-value lists (flat lists of alternating name-value pairs) and the `getDictionaryValue` library procedure:

```tcl
set data {name Alice age 30 city Boston}
getDictionaryValue $data name
;# Returns: Alice

getDictionaryValue $data country "unknown"
;# Returns: unknown (default when key not found)
```

- **See also**: [core_script_library.md](core_script_library.md) — `getDictionaryValue` in Auxiliary Utilities

---

### List Helpers: filter

The `filter` procedure returns list elements for which a script evaluates to true:

```tcl
set numbers {1 2 3 4 5 6}
set evens [filter $numbers {expr {$item % 2 == 0}}]
;# Returns: {2 4 6}
```

- **See also**: [core_script_library.md](core_script_library.md) — List Utilities (list.eagle)

---

### File Discovery: findFilesRecursive

Recursively find files matching a glob pattern:

```tcl
set scripts [findFilesRecursive *.eagle]
```

- **See also**: [core_script_library.md](core_script_library.md) — File Finder (file3.eagle)
