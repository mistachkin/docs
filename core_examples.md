# Eagle Scripting Language — Examples

> **For AI agents**: This document provides runnable examples for every command and sub-command in Eagle. Use anchors `#ex-NAME` (e.g., `#ex-string`, `#ex-object`) for quick navigation. Cross-reference the [Eagle Scripting Language](core_language.md) reference for full syntax and option documentation.

This companion file to [`core_language.md`](core_language.md) provides at least one example for every user-facing command and sub-command, plus additional examples demonstrating useful options. All examples are self-contained and use idiomatic Eagle style.

## Conventions

- All code blocks use ` ```tcl ` fencing.
- Return values are shown as: `;# Returns: value`
- Side effects: `# varName is now "value"`
- Output to stdout: `# Prints: text`
- Eagle extensions are marked: `# Eagle extension`
- Compile-time requirements: `# Requires: FLAG`
- Platform-specific examples are clearly labeled.

---

## Table of Contents

- [Control Flow](#control-flow-examples)
  - [if](#ex-if), [switch](#ex-switch), [break](#ex-break), [catch](#ex-catch), [continue](#ex-continue), [downlevel](#ex-downlevel), [error](#ex-error), [return](#ex-return), [throw](#ex-throw), [try](#ex-try), [uplevel](#ex-uplevel)
  - [do](#ex-do), [for](#ex-for), [foreach](#ex-foreach), [lmap](#ex-lmap), [while](#ex-while)
- [Variables](#variable-examples)
  - [append](#ex-append), [global](#ex-global), [incr](#ex-incr), [scope](#ex-scope), [set](#ex-set), [unset](#ex-unset), [upvar](#ex-upvar), [variable](#ex-variable)
- [Lists](#list-examples)
  - [lappend](#ex-lappend), [lassign](#ex-lassign), [lget](#ex-lget), [lindex](#ex-lindex), [linsert](#ex-linsert), [list](#ex-list), [llength](#ex-llength), [lrange](#ex-lrange), [lremove](#ex-lremove), [lrepeat](#ex-lrepeat), [lreplace](#ex-lreplace), [lreverse](#ex-lreverse), [lsearch](#ex-lsearch), [lset](#ex-lset), [lsort](#ex-lsort)
- [Strings](#string-examples)
  - [base64](#ex-base64), [concat](#ex-concat), [encoding](#ex-encoding), [format](#ex-format), [guid](#ex-guid), [hash](#ex-hash), [join](#ex-join), [parse](#ex-parse), [regexp](#ex-regexp), [regsub](#ex-regsub), [split](#ex-split), [string](#ex-string)
- [Arrays](#array-examples)
  - [array](#ex-array)
- [Dictionaries](#dictionary-examples)
  - [dict](#ex-dict)
- [I/O and Channels](#io-examples)
  - [close](#ex-close), [eof](#ex-eof), [fblocked](#ex-fblocked), [fconfigure](#ex-fconfigure), [fcopy](#ex-fcopy), [flush](#ex-flush), [gets](#ex-gets), [open](#ex-open), [puts](#ex-puts), [read](#ex-read), [seek](#ex-seek), [tell](#ex-tell), [truncate](#ex-truncate)
- [File System](#file-system-examples)
  - [cd](#ex-cd), [file](#ex-file), [glob](#ex-glob), [pwd](#ex-pwd)
- [Procedures](#procedure-examples)
  - [proc](#ex-proc), [nproc](#ex-nproc), [apply](#ex-apply), [napply](#ex-napply)
- [Namespaces](#namespace-examples)
  - [namespace](#ex-namespace)
- [Objects (.NET Interop)](#object-examples)
  - [object](#ex-object)
- [Debugging](#debugging-examples)
  - [debug](#ex-debug)
- [Interpreter Management](#interpreter-examples)
  - [interp](#ex-interp)
- [Packages](#package-examples)
  - [package](#ex-package)
- [Testing](#testing-examples)
  - [test1](#ex-test1), [test2](#ex-test2)
- [Database (SQL)](#database-examples)
  - [sql](#ex-sql)
- [Network and URI](#network-examples)
  - [socket](#ex-socket), [uri](#ex-uri)
- [XML](#xml-examples)
  - [xml](#ex-xml)
- [Tcl Integration](#tcl-examples)
  - [tcl](#ex-tcl)
- [Expression Evaluation](#expression-examples)
  - [expr](#ex-expr), [fpclassify](#ex-fpclassify)
- [Mathematical Functions](#math-function-examples)
- [Expression Operators](#operator-examples)
- [Time and Clock](#time-examples)
  - [clock](#ex-clock), [time](#ex-time)
- [Event Management](#event-examples)
  - [after](#ex-after), [callback](#ex-callback), [update](#ex-update), [vwait](#ex-vwait)
- [Introspection](#introspection-examples)
  - [info](#ex-info), [version](#ex-version)
- [Engine Operations](#engine-examples)
  - [eval](#ex-eval), [invoke](#ex-invoke), [source](#ex-source), [subst](#ex-subst)
- [Native Environment](#native-environment-examples)
  - [exec](#ex-exec), [exit](#ex-exit), [kill](#ex-kill), [library](#ex-library), [pid](#ex-pid)
- [Managed Environment](#managed-environment-examples)
  - [host](#ex-host), [load](#ex-load), [unload](#ex-unload)
- [Core and Miscellaneous](#core-misc-examples)
  - [bgerror](#ex-bgerror), [nop](#ex-nop), [rename](#ex-rename)

---

## Control Flow Examples

<a id="ex-if"></a>
### if

```tcl
# Basic conditional
set x 15
if {$x > 10} then {
  set result large
} elseif {$x > 5} then {
  set result medium
} else {
  set result small
}
;# Returns: large
```

```tcl
# Using 'then' keyword for readability
set mode read
if {$mode eq "read"} then {
  set access r
} else {
  set access w
}
;# Returns: r
```

```tcl
# Compact one-line form
set sign [if {$x >= 0} then {expr {1}} else {expr {-1}}]
;# Returns: 1
```

```tcl
# Chained elseif
set code 404
if {$code == 200} then {
  set msg OK
} elseif {$code == 301} then {
  set msg "Moved Permanently"
} elseif {$code == 404} then {
  set msg "Not Found"
} elseif {$code == 500} then {
  set msg "Internal Server Error"
} else {
  set msg Unknown
}
;# Returns: Not Found
```

---

<a id="ex-switch"></a>
### switch

```tcl
# Exact matching (default)
set fruit banana
switch $fruit {
  apple  { set color red }
  banana { set color yellow }
  grape  { set color purple }
  default { set color unknown }
}
;# Returns: yellow
```

```tcl
# Glob matching
set filename report.pdf
switch -glob $filename {
  *.txt  { set type text }
  *.pdf  { set type document }
  *.jpg -
  *.png  { set type image }
  default { set type other }
}
;# Returns: document
```

```tcl
# Fall-through with '-' body
set day Saturday
switch $day {
  Monday -
  Tuesday -
  Wednesday -
  Thursday -
  Friday    { set kind weekday }
  Saturday -
  Sunday    { set kind weekend }
}
;# Returns: weekend
```

```tcl
# Case-insensitive regexp matching
set input YES
switch -nocase -regexp $input {
  {^y(es)?$} { set answer true }
  {^no?$}    { set answer false }
  default    { set answer invalid }
}
;# Returns: true
```

---

<a id="ex-break"></a>
### break

```tcl
# Exit loop early
set result ""
foreach item {a b c STOP d e} {
  if {$item eq "STOP"} then break
  append result $item
}
;# result is "abc"
```

```tcl
# Note: break accepts an optional value, but loop commands like
# while and foreach reset the result after handling break, so the
# break value is not propagated as the loop's return value.
set i 0
while {$i < 100} {
  if {[expr {$i * $i}] > 50} then {
    break
  }
  incr i
}
;# $i is the first i where i*i > 50
```

---

<a id="ex-catch"></a>
### catch

```tcl
# Basic error catching
if {[catch {expr {1 / 0}} result]} then {
  set msg [appendArgs "Error: " $result]
} else {
  set msg [appendArgs "Result: " $result]
}
;# Returns: Error: divide by zero
```

```tcl
# Capture return code and options
set code [catch {error oops "" {MYAPP ERROR}} result opts]
;# code is 1 (TCL_ERROR)
;# result is "oops"
;# opts contains -code, -errorinfo, -errorcode
```

```tcl
# Safe file open pattern
set filename nonexistent.txt
if {[catch {open $filename r} fh]} then {
  set data "default value"
} else {
  set data [read $fh]
  close $fh
}
```

```tcl
# Distinguishing return codes
proc mayReturn {} { return -code return done }
set code [catch {mayReturn} result]
;# code is 2 (TCL_RETURN), result is "done"
```

---

<a id="ex-continue"></a>
### continue

```tcl
# Skip odd numbers
set evens [list]
for {set i 0} {$i < 10} {incr i} {
  if {$i % 2 != 0} then continue
  lappend evens $i
}
;# evens is {0 2 4 6 8}
```

```tcl
# Skip blank lines
set lines "one\n\ntwo\n\nthree"
set nonEmpty [list]
foreach line [split $lines "\n"] {
  if {$line eq ""} then continue
  lappend nonEmpty $line
}
;# nonEmpty is {one two three}
```

---

<a id="ex-downlevel"></a>
### downlevel

```tcl
# Eagle extension — execute in the pre-uplevel call frame
proc deepdown {} {
  lappend a 1              ;# in deepdown's frame
  uplevel 1 {
    lappend a 2            ;# in caller's frame
    downlevel {
      lappend a 3          ;# back in deepdown's frame
    }
  }
  return $a
}
set a [list]
list [deepdown] $a
;# Returns: {1 3} {0 2}
;# {1 3} = deepdown's local 'a', {0 2} = global 'a'
```

---

<a id="ex-error"></a>
### error

```tcl
# Simple error
catch {
  error "something went wrong"
} msg
;# msg is: something went wrong
```

```tcl
# Error with machine-readable code
catch {
  error "file not found" "" {POSIX ENOENT {no such file}}
} msg opts
;# msg is "file not found"
```

```tcl
# Validation pattern
proc positiveInt {n} {
  if {![string is integer -strict $n] || $n <= 0} then {
    error [appendArgs \
        "expected positive integer, got \"" $n \"] \
        "" {MYAPP BADARG}
  }
  return $n
}
catch {positiveInt -5} msg
;# msg is: expected positive integer, got "-5"
```

---

<a id="ex-return"></a>
### return

```tcl
# Simple return
proc greet {name} {
  return [appendArgs "Hello, " $name !]
}
greet Eagle
;# Returns: Hello, Eagle!
```

```tcl
# Return with error code
proc divide {a b} {
  if {$b == 0} then {
    return -code error \
        -errorcode {ARITH DIVZERO} \
        "division by zero"
  }
  return [expr {$a / $b}]
}
catch {divide 10 0} msg
;# msg is "division by zero"
```

```tcl
# Return from nested uplevel (returning through 2 levels)
proc outerReturn {} {
  uplevel 1 {return -level 2 "from deep inside"}
}
proc wrapper {} {
  outerReturn
  return "never reached"
}
```

---

<a id="ex-throw"></a>
### throw

```tcl
# Eagle extension — throw an exception
catch {
  throw "connection refused"
} msg
;# msg is "connection refused"
```

---

<a id="ex-try"></a>
### try

```tcl
# Try/finally for resource cleanup
proc readFirstLine {filename} {
  try {
    set fh [open $filename r]
    return [gets $fh]
  } finally {
    if {[info exists fh]} then {
      close $fh
    }
  }
}
```

```tcl
# Error handling with try/finally
set tempFile [file tempname]
try {
  set fh [open $tempFile w]
  puts $fh "test data"
  error "simulated failure"
} finally {
  if {[info exists fh]} then {
    close $fh
  }
  file delete -force $tempFile
}
# fh is closed and tempFile deleted even though error occurred
```

---

<a id="ex-uplevel"></a>
### uplevel

```tcl
# Execute in caller's scope
proc setInCaller {varName value} {
  uplevel 1 [list set $varName $value]
}
setInCaller myVar Hello
;# myVar is "Hello" in the calling scope
```

```tcl
# Execute at global level
proc setGlobal {varName value} {
  uplevel #0 [list set $varName $value]
}
setGlobal ::config production
```

```tcl
# Assert utility using uplevel for expression context
proc assert {expr {msg ""}} {
  if {![uplevel 1 [list expr $expr]]} then {
    if {$msg eq ""} then {
      set msg [appendArgs "Assertion failed: " $expr]
    }
    error $msg
  }
}
set x 5
assert {$x > 0}  ;# Passes
```

---

<a id="ex-do"></a>
### do

```tcl
# Eagle extension — do-while loop
set i 0
set result [list]
do {
  lappend result $i
  incr i
} while {$i < 5}
;# result is {0 1 2 3 4}
```

```tcl
# do-until loop (loops while condition is FALSE)
set j 0
do {
  incr j
} until {$j >= 5}
;# j is 5
```

```tcl
# Prompt and validate input pattern
proc getPositive {} {
  set value 0
  do {
    incr value
  } until {$value > 0}
  return $value
}
```

---

<a id="ex-for"></a>
### for

```tcl
# Classic counting loop
set sum 0
for {set i 1} {$i <= 10} {incr i} {
  incr sum $i
}
;# sum is 55
```

```tcl
# Decrementing loop
set countdown [list]
for {set i 5} {$i > 0} {incr i -1} {
  lappend countdown $i
}
;# countdown is {5 4 3 2 1}
```

```tcl
# Loop with step of 2
set odds [list]
for {set i 1} {$i < 10} {incr i 2} {
  lappend odds $i
}
;# odds is {1 3 5 7 9}
```

```tcl
# Eagle extension — optional 'end' script
for {set i 0} {$i < 3} {incr i} {
  # loop body
} {
  # This 'end' script runs when the loop terminates normally
}
```

---

<a id="ex-foreach"></a>
### foreach

```tcl
# Simple iteration
set total 0
foreach num {10 20 30 40} {
  incr total $num
}
;# total is 100
```

```tcl
# Multiple variables per iteration (key-value pairs)
set dict {name Alice age 30 city Boston}
foreach {key value} $dict {
  # Prints: name => Alice, age => 30, city => Boston
}
```

```tcl
# Parallel iteration over two lists
set names {Alice Bob Carol}
set ages  {30 25 35}
foreach name $names age $ages {
  # Prints: Alice is 30, Bob is 25, Carol is 35
}
```

```tcl
# Three variables from one list
set coords {1 2 3  4 5 6  7 8 9}
foreach {x y z} $coords {
  # Process (x,y,z) triples
}
```

---

<a id="ex-lmap"></a>
### lmap

```tcl
# Eagle extension — transform each element
set doubled [lmap x {1 2 3 4 5} {expr {$x * 2}}]
;# Returns: {2 4 6 8 10}
```

```tcl
# Filter with lmap using continue
set positive [lmap x {-3 -1 0 2 4 -5 7} {
  if {$x > 0} then {set x} else {continue}
}]
;# Returns: {2 4 7}
```

```tcl
# Transform key-value pairs
set pairs {a 1 b 2 c 3}
set formatted [lmap {k v} $pairs {
  format "%s=%s" $k $v
}]
;# Returns: {a=1 b=2 c=3}
```

---

<a id="ex-while"></a>
### while

```tcl
# Simple while loop
set i 1
set product 1
while {$i <= 5} {
  set product [expr {$product * $i}]
  incr i
}
;# product is 120 (5!)
```

```tcl
# Sentinel-controlled loop
set items {a b c END d e}
set i 0
set collected [list]
while {[lindex $items $i] ne "END"} {
  lappend collected [lindex $items $i]
  incr i
}
;# collected is {a b c}
```

---

## Variable Examples

<a id="ex-append"></a>
### append

```tcl
# Build a string incrementally
set msg Hello
append msg ", " World !
;# msg is "Hello, World!"
```

```tcl
# Append to nonexistent variable (creates it)
unset -nocomplain html
append html "<html>"
append html "<body>Hello</body>"
append html "</html>"
;# html is "<html><body>Hello</body></html>"
```

---

<a id="ex-global"></a>
### global

```tcl
# Access global variable from procedure
set ::counter 0
proc incrementCounter {} {
  global counter
  incr counter
}
incrementCounter
incrementCounter
;# ::counter is 2
```

```tcl
# Multiple global declarations
proc configure {key value} {
  global config errorCount
  set config($key) $value
  incr errorCount 0  ;# Ensure it exists
}
```

---

<a id="ex-incr"></a>
### incr

```tcl
# Increment by 1 (default)
set x 10
incr x
;# x is 11
```

```tcl
# Increment by arbitrary amount
set x 10
incr x 5    ;# x is 15
incr x -3   ;# x is 12
```

```tcl
# Counter pattern (creates variable if needed with incr alone in Tcl,
# but in Eagle the variable must exist or be initialized first)
set count 0
incr count
incr count
;# count is 2
```

---

<a id="ex-scope"></a>
### scope

> For a deep-dive on scope internals, the call frame stack model, cloning modes, locking, and namespace integration, see [`scope.md`](scope.md).

```tcl
# Eagle extension — persistent counter across calls
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

```tcl
# scope eval — evaluate script in scope context
scope create myScope
scope eval myScope {
  set x 10
  set y 20
  expr {$x + $y}
}
;# Returns: 30
scope set myScope x   ;# Returns: 10
scope destroy myScope
```

```tcl
# scope set/unset — manipulate variables without opening
scope create temp
scope set temp color blue
scope set temp size 42
scope set temp color      ;# Returns: blue
scope vars temp           ;# Returns: {color size}
scope unset temp color
scope vars temp           ;# Returns: size
scope destroy temp
```

```tcl
# scope exists/list
scope create alpha
scope create beta
scope exists alpha    ;# Returns: True
scope exists gamma    ;# Returns: False
scope list            ;# Returns: {alpha beta}
scope destroy alpha
scope destroy beta
```

```tcl
# scope global — redirect global frame to a scope
scope create sandbox
scope global sandbox        ;# All 'global' ops now use sandbox
scope global                ;# Returns: sandbox
scope global -unset         ;# Restore normal global frame
scope destroy sandbox
```

```tcl
# scope with -procedure option for auto-named per-procedure scopes
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

### Scope Persistence Pattern

```tcl
# Create a scope and demonstrate variable persistence across eval calls
scope create myCounter

# First eval: initialize the counter
scope eval myCounter {
    set count 0
    set label "visits"
}

# Second eval: increment and read -- variables persist from previous eval
scope eval myCounter {
    incr count
    puts "Counter: $count $label"  ;# prints: Counter: 1 visits
}

# Third eval: increment again
scope eval myCounter {
    incr count
    puts "Counter: $count $label"  ;# prints: Counter: 2 visits
}

# Variables persist in the scope even when not "open"
scope vars myCounter  ;# returns: count label

# Clean up
scope destroy myCounter
```

### Scope Locking for Thread Safety

```tcl
# Thread-safe shared counter using scope eval -lock
scope create sharedState

scope eval sharedState {set total 0}

# In different threads or event handlers, use -lock:
scope eval -lock true sharedState {
    incr total
    # Lock is held during this entire block
    # Other scope eval -lock calls will wait
}
```

### Scope Global Sandboxing

```tcl
# Redirect the global namespace to a scope
scope create sandbox
scope global sandbox

# Now global variable access goes to the sandbox
set ::safeVar "sandboxed value"   ;# stored in sandbox, not real global
global myGlobal                    ;# creates in sandbox scope

# Restore normal global behavior
scope global -unset
```

---

<a id="ex-set"></a>
### set

```tcl
# Set and read a variable
set name Alice
set greeting [appendArgs "Hello, " $name]
;# greeting is "Hello, Alice"
```

```tcl
# Read-only form (no newValue)
set x 42
puts [set x]   ;# Prints: 42
```

```tcl
# Array element access
set data(key1) value1
set data(key2) value2
set v [set data(key1)]
;# v is "value1"
```

---

<a id="ex-unset"></a>
### unset

```tcl
# Remove a variable
set temp temporary
unset temp
;# Reading $temp now would produce an error
```

```tcl
# Remove without error if nonexistent
unset -nocomplain x y z
```

```tcl
# Remove array element
set arr(a) 1
set arr(b) 2
unset arr(a)
;# arr(b) still exists, arr(a) is gone
```

```tcl
# Remove entire array
array set data {x 1 y 2}
unset data
;# data no longer exists
```

---

<a id="ex-upvar"></a>
### upvar

```tcl
# Pass-by-reference pattern
proc swap {aName bName} {
  upvar 1 $aName a $bName b
  set temp $a
  set a $b
  set b $temp
}
set x 1
set y 2
swap x y
;# x is 2, y is 1
```

```tcl
# Modify caller's list
proc addElement {listName element} {
  upvar 1 $listName myList
  lappend myList $element
}
set fruits {apple banana}
addElement fruits cherry
;# fruits is {apple banana cherry}
```

```tcl
# Link to global variable
proc readGlobal {varName} {
  upvar #0 $varName val
  return $val
}
set ::greeting Hello
readGlobal greeting
;# Returns: Hello
```

---

<a id="ex-variable"></a>
### variable

```tcl
# Declare namespace variables
namespace eval myns {
  variable counter 0
  variable name default

  proc increment {} {
    variable counter
    incr counter
  }

  proc getName {} {
    variable name
    return $name
  }
}
myns::increment
myns::increment
;# myns::counter is 2
```

---

## List Examples

<a id="ex-lappend"></a>
### lappend

```tcl
# Append elements to list
set fruits {apple banana}
lappend fruits cherry "dragon fruit"
;# fruits is {apple banana cherry {dragon fruit}}
```

```tcl
# Build list from scratch
set items [list]
lappend items first second third
;# items is {first second third}
```

---

<a id="ex-lassign"></a>
### lassign

```tcl
# Assign list elements to variables
lassign {Alice 30 Boston} name age city
;# name is "Alice", age is "30", city is "Boston"
```

```tcl
# Excess elements returned
set rest [lassign {a b c d e} x y z]
;# x="a", y="b", z="c", rest={d e}
```

```tcl
# Fewer elements than variables
lassign {1 2} a b c
;# a="1", b="2", c=""
```

---

<a id="ex-lget"></a>
### lget

```tcl
# Eagle extension — get element from list variable
set data {{a b} {c d} {e f}}
lget data 1 0     ;# Returns: c
```

```tcl
# Nested access
set matrix {a b c {d e f {g h i}}}
lget matrix 0          ;# Returns: a
lget matrix end         ;# Returns: {d e f {g h i}}
lget matrix end end     ;# Returns: {g h i}
```

---

<a id="ex-lindex"></a>
### lindex

```tcl
# Get element by index
set colors {red green blue yellow}
lindex $colors 0       ;# Returns: red
lindex $colors end     ;# Returns: yellow
lindex $colors end-1   ;# Returns: blue
```

```tcl
# Nested list access
set nested {{1 2} {3 4} {5 6}}
lindex $nested 1 0     ;# Returns: 3
```

```tcl
# Out of range returns empty
lindex {a b c} 10      ;# Returns: (empty string)
```

---

<a id="ex-linsert"></a>
### linsert

```tcl
# Insert at beginning
linsert {b c d} 0 a
;# Returns: {a b c d}
```

```tcl
# Insert in middle
linsert {a b c} 1 X Y
;# Returns: {a X Y b c}
```

```tcl
# Append (index past end)
linsert {a b c} 999 d e
;# Returns: {a b c d e}
```

---

<a id="ex-list"></a>
### list

```tcl
# Create properly-quoted list
list a b c                    ;# Returns: {a b c}
list "hello world" foo        ;# Returns: {{hello world} foo}
list a {b c} d                ;# Returns: {a {b c} d}
```

```tcl
# Safe command construction
set message "Hello, World!"
set cmd [list puts $message]
eval $cmd                     ;# Prints: Hello, World!
```

---

<a id="ex-llength"></a>
### llength

```tcl
llength {a b c d}     ;# Returns: 4
llength {}            ;# Returns: 0
llength {{a b} c}     ;# Returns: 2
```

---

<a id="ex-lrange"></a>
### lrange

```tcl
lrange {a b c d e} 1 3     ;# Returns: {b c d}
lrange {a b c d e} 2 end   ;# Returns: {c d e}
lrange {a b c} 0 end-1     ;# Returns: {a b}
```

```tcl
# Extract head and tail of a list
set data {10 20 30 40 50}
set head [lindex $data 0]
set tail [lrange $data 1 end]
;# head is 10, tail is {20 30 40 50}
```

---

<a id="ex-lremove"></a>
### lremove

```tcl
# Eagle extension — remove by index
lremove {a b c d e} 1      ;# Returns: {a c d e}
```

```tcl
# Nested removal: index 1 selects {d e f}, then index 0 removes "d"
lremove {{a b c} {d e f}} 1 0   ;# Returns: {{a b c} {e f}}
```

---

<a id="ex-lrepeat"></a>
### lrepeat

```tcl
lrepeat 3 a           ;# Returns: {a a a}
lrepeat 2 x y z       ;# Returns: {x y z x y z}
lrepeat 0 a b         ;# Returns: {}
```

```tcl
# Create zero-filled list
lrepeat 5 0            ;# Returns: {0 0 0 0 0}
```

---

<a id="ex-lreplace"></a>
### lreplace

```tcl
# Replace elements
lreplace {a b c d e} 1 2 X Y Z   ;# Returns: {a X Y Z d e}
```

```tcl
# Delete elements (no replacement values)
lreplace {a b c d e} 1 2          ;# Returns: {a d e}
```

```tcl
# Insert without removing (first > last)
lreplace {a b c} 1 0 X            ;# Returns: {a X b c}
```

---

<a id="ex-lreverse"></a>
### lreverse

```tcl
lreverse {a b c d}    ;# Returns: {d c b a}
lreverse {1 2 3}      ;# Returns: {3 2 1}
lreverse {}           ;# Returns: {}
```

---

<a id="ex-lsearch"></a>
### lsearch

```tcl
# Exact search
lsearch {a b c d} c                     ;# Returns: 2
lsearch {a b c d} x                     ;# Returns: -1
```

```tcl
# Glob search
lsearch -glob {apple banana cherry} b*  ;# Returns: 1
```

```tcl
# Regexp search
lsearch -regexp {cat dog bird} {^d}     ;# Returns: 1
```

```tcl
# Find all matches inline
lsearch -all -inline {1 2 3 2 1} 2      ;# Returns: {2 2}
```

```tcl
# Case-insensitive search
lsearch -nocase {Apple banana Cherry} cherry  ;# Returns: 2
```

```tcl
# Inverted search — all non-matching
lsearch -all -inline -not {a b a c a} a      ;# Returns: {b c}
```

```tcl
# Search sorted list (binary search)
lsearch -sorted -integer {1 3 5 7 9 11} 7    ;# Returns: 3
```

```tcl
# Search sublists by index
lsearch -index 1 -integer {{a 3} {b 1} {c 2}} 2  ;# Returns: 2
```

---

<a id="ex-lset"></a>
### lset

```tcl
# Replace element in place
set mylist {a b c d}
lset mylist 1 X
;# mylist is {a X c d}
```

```tcl
# Nested list modification
set nested {{1 2} {3 4}}
lset nested 0 1 9
;# nested is {{1 9} {3 4}}
```

---

<a id="ex-lsort"></a>
### lsort

```tcl
# Default ASCII sort
lsort {banana Apple cherry}           ;# Returns: {Apple banana cherry}
```

```tcl
# Case-insensitive
lsort -nocase {banana Apple cherry}   ;# Returns: {Apple banana cherry}
```

```tcl
# Integer sort
lsort -integer {10 2 5 1}            ;# Returns: {1 2 5 10}
```

```tcl
# Unique values
lsort -unique {a b a c b}            ;# Returns: {a b c}
```

```tcl
# Descending order
lsort -decreasing -integer {1 3 2}   ;# Returns: {3 2 1}
```

```tcl
# Sort list of pairs by second element
lsort -index 1 {{a 2} {b 1} {c 3}}  ;# Returns: {{b 1} {a 2} {c 3}}
```

```tcl
# Dictionary sort (numbers embedded in strings sort naturally)
lsort -dictionary {file10 file2 file1 file20}
;# Returns: {file1 file2 file10 file20}
```

```tcl
# Custom comparison command
proc byLength {a b} {
  set la [string length $a]
  set lb [string length $b]
  if {$la < $lb} then {return -1}
  if {$la > $lb} then {return 1}
  return 0
}
lsort -command byLength {cat elephant be a}
;# Returns: {a be cat elephant}
```

---

## String Examples

<a id="ex-base64"></a>
### base64

```tcl
# Eagle extension — encode to Base64
base64 encode "Hello, World!"   ;# Returns: SGVsbG8sIFdvcmxkIQ==
```

```tcl
# Decode Base64
base64 decode SGVsbG8=          ;# Returns: Hello
```

```tcl
# Round-trip
set original "Eagle scripting!"
set encoded [base64 encode $original]
set decoded [base64 decode $encoded]
expr {$original eq $decoded}    ;# Returns: 1
```

```tcl
# With explicit encoding
base64 encode -encoding utf-8 "Héllo"
```

---

<a id="ex-concat"></a>
### concat

```tcl
# Merge lists
concat {a b} {c d}        ;# Returns: {a b c d}
```

```tcl
# Trims whitespace
concat "  a  " "  b  "    ;# Returns: {a b}
```

```tcl
# Merge multiple lists
concat {1 2} {3} {4 5 6}  ;# Returns: {1 2 3 4 5 6}
```

---

<a id="ex-encoding"></a>
### encoding

```tcl
# Convert to UTF-8
encoding convertto utf-8 Hello
```

```tcl
# List available encodings
encoding names
;# Returns list of encoding names
```

```tcl
# Get current system encoding
encoding system
;# Returns: e.g., utf-8
```

```tcl
# Eagle extension — get string from byte array object
encoding getstring $byteArrayObj utf-8
```

---

<a id="ex-format"></a>
### format

```tcl
# String and integer
format "Name: %s, Age: %d" Alice 30
;# Returns: Name: Alice, Age: 30
```

```tcl
# Hexadecimal with padding
format "%08x" 255                     ;# Returns: 000000ff
format "%#010x" 255                   ;# Returns: 0x000000ff
```

```tcl
# Floating-point precision
format "%.2f" 3.14159                 ;# Returns: 3.14
format "%10.4f" 3.14159              ;# Returns:     3.1416
```

```tcl
# Left-justified, right-justified
format "%-10s|" Hi                    ;# Returns: Hi        |
format "%10s|" Hi                     ;# Returns:         Hi|
```

```tcl
# Character from code point
format "%c" 65                        ;# Returns: A
```

```tcl
# Multiple format specifiers
format "%s scored %d%% on the %s exam" Bob 95 math
;# Returns: Bob scored 95% on the math exam
```

---

<a id="ex-guid"></a>
### guid

```tcl
# Eagle extension — generate new GUID
set id [guid new]
;# e.g., "550e8400-e29b-41d4-a716-446655440000"
```

```tcl
# Validate GUID format
guid isvalid $id              ;# Returns: 1
guid isvalid not-a-guid      ;# Returns: 0
```

```tcl
# Null GUID
guid isnull [guid null]       ;# Returns: 1
guid isnull [guid new]        ;# Returns: 0
```

```tcl
# Compare GUIDs
set a [guid new]
set b [guid new]
guid compare $a $a            ;# Returns: 0
guid compare $a $b            ;# Returns: -1 or 1
```

---

<a id="ex-hash"></a>
### hash

```tcl
# Eagle extension — SHA-256 hash
hash normal sha256 Hello
;# Returns: 185f8db32271fe25f561a6fc938b2e264306ec304eda518007d1764826381969
```

```tcl
# MD5 hash
hash normal md5 Hello
;# Returns: 8b1a9953c4611296a827abf8c47804d7
```

```tcl
# HMAC (keyed hash)
hash mac sha256 message secret-key
```

```tcl
# List available algorithms
hash list          ;# Returns all algorithm pairs
hash list normal   ;# Only non-keyed algorithms
```

```tcl
# Hash a file's contents
# hash normal -filename sha256 myfile.txt     # Requires: UNSAFE
```

---

<a id="ex-join"></a>
### join

```tcl
# Default separator (space)
join {a b c}             ;# Returns: a b c
```

```tcl
# Custom separator
join {a b c} ", "        ;# Returns: a, b, c
```

```tcl
# No separator
join {a b c} ""          ;# Returns: abc
```

```tcl
# Newline-separated output
join {line1 line2 line3} "\n"
;# Returns multi-line string
```

```tcl
# Build CSV row
join {Alice 30 Boston} ","  ;# Returns: Alice,30,Boston
```

---

<a id="ex-parse"></a>
### parse

```tcl
# Eagle extension — parse a command
parse command {puts "hello world"}
;# Returns token structure describing the command
```

```tcl
# Parse an expression
parse expression {2 + 3 * 4}
;# Returns token structure with operator precedence
```

```tcl
# Parse a complete script
parse script {
  set x 1
  puts $x
}
;# Returns list of parsed command structures
```

---

<a id="ex-regexp"></a>
> **See also**: [`regexp.md`](regexp.md) — Deep-dive analysis covering the .NET regex engine, default `Singleline` behavior, Eagle-specific options (`-global`, `-skip`, `-limit`, `-compiled`, `-extra`), pattern mutation prefixes, and practical patterns.

### regexp

```tcl
# Simple match test
regexp {^[A-Z]} Hello                  ;# Returns: 1
regexp {^[A-Z]} hello                  ;# Returns: 0
```

```tcl
# Capture sub-matches
regexp {(\d+)-(\d+)} "Phone: 123-456" all area number
;# all="123-456", area="123", number="456"
```

```tcl
# Count all matches
regexp -all {\d+} a1b2c3              ;# Returns: 3
```

```tcl
# Return all matches inline
regexp -inline -all {\d+} a1b22c333
;# Returns: {1 22 333}
```

```tcl
# Case-insensitive matching
regexp -nocase {hello} "HELLO WORLD"   ;# Returns: 1
```

```tcl
# Index-based results
regexp -indices {(\w+)@(\w+)} "user@host" all user domain
;# all={0 8}, user={0 3}, domain={5 8}
```

```tcl
# Eagle extension — compiled regex for performance
regexp -compiled -nocase {pattern} "Some Pattern"
```

---

<a id="ex-regsub"></a>
> **See also**: [`regexp.md`](regexp.md) — Deep-dive on `[regsub]` internals: the three replacement modes (normal, `-eval`, `-command`), `TranslateSubSpec` translation, `-extra` substitutions for named groups, and `-strict`/`-nostrict` behavior.

### regsub

```tcl
# Simple substitution
regsub {world} "Hello world" Eagle
;# Returns: Hello Eagle
```

```tcl
# Replace all occurrences
regsub -all {[aeiou]} Hello *
;# Returns: H*ll*
```

```tcl
# Back-reference substitution
regsub {(\w+) (\w+)} "John Doe" {\2, \1}
;# Returns: Doe, John
```

```tcl
# Store in variable, return count
regsub -all {\d} a1b2c3 X result
;# result is "aXbXcX", returns 3
```

```tcl
# Eagle extension — command-based replacement (TIP #463)
regsub -all -command {\d+} a1b22c333 {string length}
;# Returns: a1b2c3  (each number replaced by its character length)
```

```tcl
# Literal replacement (no special chars)
regsub -literal {.} a.b {$1}
;# Returns: a$1b
```

---

<a id="ex-split"></a>
### split

```tcl
# Default (whitespace) split
split "a b c"              ;# Returns: {a b c}
```

```tcl
# Split on comma
split "a,b,c" ","          ;# Returns: {a b c}
```

```tcl
# Split into individual characters
split abc ""               ;# Returns: {a b c}
```

```tcl
# Multiple separator characters
split "a.b,c" ".,"        ;# Returns: {a b c}
```

```tcl
# Empty elements preserved
split "a::b" ":"           ;# Returns: {a {} b}
```

```tcl
# Split path
split /usr/local/bin /
;# Returns: {{} usr local bin}
```

---

> **See also:** [`string.md`](string.md) — deep-dive analysis of the `string` command with additional examples covering 29 sub-commands, 64-class type checking, culture-aware operations, extended `string map`, and `string format` .NET integration.

<a id="ex-string"></a>
### string

#### String Measurement and Access

```tcl
string length Hello                ;# Returns: 5
string length ""                   ;# Returns: 0 (quotes needed: empty string)
```

```tcl
string index Hello 0              ;# Returns: H
string index Hello end            ;# Returns: o
string index Hello 10             ;# Returns: (empty string)
```

```tcl
string range "Hello, World" 0 4   ;# Returns: Hello
string range Hello 1 end          ;# Returns: ello
```

```tcl
# Eagle extension — Unicode code point
string ordinal A 0                ;# Returns: 65
string character 65               ;# Returns: A
```

```tcl
string bytelength Hello           ;# Returns: 10 (UTF-16, 2 bytes per char)
string bytelength Hello ascii     ;# Returns: 5 (ASCII, 1 byte each)
```

#### String Comparison

```tcl
string compare abc abd                ;# Returns: -1
string compare abc abc                ;# Returns: 0
string compare abd abc                ;# Returns: 1
```

```tcl
string equal Hello Hello              ;# Returns: 1
string equal Hello hello              ;# Returns: 0
string equal -nocase Hello HELLO      ;# Returns: 1
```

```tcl
# Compare only first N characters
string equal -length 3 Hello Help      ;# Returns: 1
```

#### String Searching

```tcl
string first l Hello                  ;# Returns: 2
string last l Hello                   ;# Returns: 3
string first xyz Hello                ;# Returns: -1
```

```tcl
# Start search at offset
string first l Hello 3                ;# Returns: 3
```

```tcl
# Glob matching
string match *.txt file.txt           ;# Returns: 1
string match {[A-Z]*} Hello           ;# Returns: 1
string match -nocase hello HELLO      ;# Returns: 1
```

```tcl
string wordstart "Hello World" 7      ;# Returns: 6
string wordend "Hello World" 7        ;# Returns: 11
```

#### String Modification

```tcl
string cat Hello ", " World            ;# Returns: Hello, World
string repeat ab 3                     ;# Returns: ababab
string replace Hello 1 3 XYZ           ;# Returns: HXYZo
string reverse Hello                   ;# Returns: olleH
```

```tcl
# String mapping
string map {a A e E} hello             ;# Returns: hEllo
string map {foo bar baz qux} "foo is baz"
;# Returns: bar is qux
```

```tcl
# Format via string command
string format %05d 42                 ;# Returns: 00042
```

#### Case Conversion and Trimming

```tcl
string tolower HELLO                   ;# Returns: hello
string toupper hello                   ;# Returns: HELLO
string totitle "hello world"           ;# Returns: Hello world
```

```tcl
# Partial range conversion
string toupper hello 0 0              ;# Returns: Hello
```

```tcl
string trim "  hello  "               ;# Returns: hello
string trimleft xxhello x             ;# Returns: hello
string trimright helloxx x            ;# Returns: hello
string trim "###text###" "#"          ;# Returns: text
```

#### Prefix/Suffix Testing (Eagle extensions)

```tcl
string starts Hello "Hello, World"        ;# Returns: 1
string starts Bye "Hello, World"          ;# Returns: 0
string ends .txt readme.txt              ;# Returns: 1
string ends -nocase .TXT file.txt        ;# Returns: 1
```

#### String Classification

```tcl
# Standard Tcl character classes
string is alpha Hello                 ;# Returns: 1
string is alpha Hello123              ;# Returns: 0
string is alnum Hello123              ;# Returns: 1
string is digit 123                   ;# Returns: 1
string is space "  \t\n"             ;# Returns: 1
string is upper HELLO                ;# Returns: 1
string is lower hello                ;# Returns: 1
string is ascii Hello                ;# Returns: 1
string is print Hello                ;# Returns: 1
string is graph Hello                ;# Returns: 1
string is punct ".,;!"              ;# Returns: 1 (quotes needed: semicolon)
string is control "\x01\x02"        ;# Returns: 1
string is wordchar hello_123        ;# Returns: 1
string is xdigit 1a2F               ;# Returns: 1
```

```tcl
# Numeric type testing
string is integer 123                  ;# Returns: 1
string is integer 12.3                ;# Returns: 0
string is wideinteger 9999999999      ;# Returns: 1 (64-bit)
string is entier 12345678901234567890 ;# Returns: 1 (arbitrary precision)
string is double 3.14                 ;# Returns: 1
string is boolean yes                 ;# Returns: 1
```

```tcl
# Eagle extension — additional numeric classes
string is decimal 3.14                ;# Returns: 1
string is byte 255                    ;# Returns: 1
string is byte 256                    ;# Returns: 0
string is single 3.14                ;# Returns: 1 (single-precision float)
string is hexadecimal FF00           ;# Returns: 1
string is real 3.14159               ;# Returns: 1
string is number 42                  ;# Returns: 1
```

```tcl
# Strict mode (empty string fails)
string is alpha ""                     ;# Returns: 1
string is alpha -strict ""            ;# Returns: 0
```

```tcl
# Fail index
string is integer -failindex idx 12x4
;# Returns: 0, idx is 2
```

```tcl
# List and dict validation
string is list {a b c}               ;# Returns: 1
string is list "a {b"                 ;# Returns: 0
string is element hello              ;# Returns: 1
string is dict {a 1 b 2}            ;# Returns: 1 (Eagle extension)
```

```tcl
# Eagle extension — file and path validation
string is file /tmp/data.txt         ;# Returns: 1 if file exists
string is directory /tmp             ;# Returns: 1 if directory exists
string is path /some/path            ;# Returns: 1 if valid path syntax
```

```tcl
# Eagle extension — format validation classes
string is guid 550e8400-e29b-41d4-a716-446655440000    ;# Returns: 1
string is uri https://example.com                       ;# Returns: 1
string is version 1.2.3                                 ;# Returns: 1
string is versionrange 1.0-2.0                          ;# Returns: 1
string is inetaddr 192.168.1.1                          ;# Returns: 1
string is cidr 192.168.1.0/24                           ;# Returns: 1
string is datetime 2024-01-15                           ;# Returns: 1
string is timespan 01:30:00                             ;# Returns: 1
string is xml <root/>                                   ;# Returns: 1
string is base64 SGVsbG8=                               ;# Returns: 1
```

```tcl
# Eagle extension — interpreter/object validation
string is command puts                ;# Returns: 1 if command exists
string is object $handle              ;# Returns: 1 if valid object handle
string is type System.String          ;# Returns: 1 if valid .NET type
string is encoding utf-8              ;# Returns: 1 if valid encoding
string is identifier myCmd            ;# Returns: 1 if valid identifier
string is interpreter $interp         ;# Returns: 1 if valid interpreter
```

```tcl
# Eagle extension — boolean specifics
string is true yes                    ;# Returns: 1
string is false no                    ;# Returns: 1
string is none ""                     ;# Returns: 1 (Eagle extension)
```

```tcl
# Eagle extension — ASCII-restricted classes
string is asciialnum Hello123         ;# Returns: 1 (ASCII only)
string is asciialpha Hello            ;# Returns: 1 (ASCII letters only)
string is asciidigit 123              ;# Returns: 1 (ASCII digits only)
```

```tcl
# Get all available classification classes
string classes
;# Returns list of all class names
```

---

## Array Examples

> **See also:** [`array.md`](array.md) — deep-dive analysis of the `array` command with additional examples covering 17 sub-commands, 8 storage backends, deep copy, default values, random access, and iteration patterns.

<a id="ex-array"></a>
### array

#### Basic Operations

```tcl
# Create array from list
array set data {name Alice age 30 city Boston}
array exists data           ;# Returns: 1
array size data             ;# Returns: 3
```

```tcl
# Get keys and values
array names data            ;# Returns: {name age city} (order may vary)
array get data              ;# Returns flat key-value list
array get data "a*"         ;# Returns: {age 30}
```

```tcl
# Eagle extension — get values
array values data           ;# Returns: {Alice 30 Boston} (order may vary)
```

```tcl
# Unset specific elements
array unset data "a*"       ;# Removes 'age'
array size data             ;# Returns: 2
```

```tcl
# Unset entire array
array unset data
array exists data           ;# Returns: 0
```

#### Default Values (Eagle extension)

```tcl
array set counts {}
array default set counts 0
incr counts(apples)         ;# Works because default is 0
incr counts(apples)
incr counts(bananas)
;# counts(apples) is 2, counts(bananas) is 1
```

```tcl
array default exists counts ;# Returns: 1
array default get counts    ;# Returns: 0
array default unset counts
```

#### Iteration

```tcl
# array for
array set data {a 1 b 2 c 3}
array for {key value} data {
  # Iterates over each key-value pair
}
```

```tcl
# Eagle extension — array foreach (iterates over keys)
array set rgb {red 255 green 128 blue 0}
array foreach key rgb {
  puts [appendArgs $key " = " $rgb($key)]
}
```

```tcl
# Eagle extension — array lmap (collect results, iterates over keys)
array set prices {apple 1.50 banana 0.75 cherry 2.00}
set formatted [array lmap fruit prices {
  format "%s: $%s" $fruit $prices($fruit)
}]
```

#### Manual Search

```tcl
array set data {x 10 y 20 z 30}
set sid [array startsearch data]
while {[array anymore data $sid]} {
  set key [array nextelement data $sid]
  # Process $key => $data($key)
}
array donesearch data $sid
```

#### Copying (Eagle extension)

```tcl
array set src {a 1 b 2 c 3}
array copy src dst
;# dst is now a copy of src
```

#### Random Element (Eagle extension)

```tcl
array set data {a 1 b 2 c 3 d 4}
# array random data              ;# Returns random key name
# array random -pair data        ;# Returns random key-value pair
# array random data "a*"         ;# Random from matching keys only
```

---

<a id="dictionary-examples"></a>

## Dictionary Examples

<a id="ex-dict"></a>
### dict

#### Creating and Querying

```tcl
# Create an empty dictionary
dict create                   ;# Returns: (empty string)

# Create with key-value pairs
dict create a b c d e f       ;# Returns: {a b c d e f}
```

```tcl
# Get entire dictionary
dict get {a b c d}            ;# Returns: {a b c d}

# Get single key
dict get {a b c d} a          ;# Returns: b

# Get nested key
dict get {a {x y} c d} a x   ;# Returns: y
```

```tcl
# Check key existence
dict exists {a b c d} a      ;# Returns: 1
dict exists {a b c d} z      ;# Returns: 0

# Nested existence
dict exists {a {x y} c d} a x  ;# Returns: 1
dict exists {a {x y} c d} a z  ;# Returns: 0
```

```tcl
# Size, keys, values
dict size {a b c d e f}      ;# Returns: 3
dict keys {a b c d e f}      ;# Returns: {a c e}
dict keys {abc 1 def 2 abx 3} ab*  ;# Returns: {abc abx}
dict values {a b c d e f}    ;# Returns: {b d f}
dict values {a 1 b 2 c 10} 1*     ;# Returns: {1 10}
```

```tcl
# Info about dictionary structure
dict info {a b c d}          ;# Returns internal info string
```

#### In-Place Modification

```tcl
# Set keys (creates variable if needed)
set d [dict create]
dict set d name eagle         ;# d = {name eagle}
dict set d a b c              ;# Nested: a -> b -> c
dict get $d a b               ;# Returns: c
```

```tcl
# Overwrite existing key
set d [dict create a b]
dict set d a new
dict get $d a                 ;# Returns: new
```

```tcl
# Unset keys
set d [dict create a b c d]
dict unset d a
dict keys $d                  ;# Returns: {c}

# Unset missing key — no error
set d [dict create a b c d]
dict unset d z
dict size $d                  ;# Returns: 2
```

```tcl
# Append strings to key value
set d [dict create a hello]
dict append d a " world"
dict get $d a                 ;# Returns: hello world

# Append to new key
dict append d b greeting
dict get $d b                 ;# Returns: greeting
```

```tcl
# Increment key value
set d [dict create x 5]
dict incr d x 3
dict get $d x                 ;# Returns: 8

# Increment new key (starts from 0)
dict incr d y
dict get $d y                 ;# Returns: 1

# Negative increment
set d [dict create x 10]
dict incr d x -7
dict get $d x                 ;# Returns: 3
```

```tcl
# List-append to key value
set d [dict create]
dict lappend d x hello
dict lappend d x world
dict get $d x                 ;# Returns: {hello world}
```

#### Functional Operations (Value-Based)

```tcl
# Remove keys (returns new dictionary)
dict remove {a b c d e f} c          ;# Returns: {a b e f}
dict remove {a b c d e f} a e        ;# Returns: {c d}
dict remove {a b c d} z              ;# Returns: {a b c d} (no error)
```

```tcl
# Replace/add key-value pairs
dict replace {a b} c d               ;# Returns: {a b c d}
dict replace {a b c d} a x           ;# Returns: {a x c d}
```

```tcl
# Merge dictionaries (later wins)
dict merge                            ;# Returns: (empty)
dict merge {a b c d}                  ;# Returns: {a b c d}
dict merge {a 1 b 2} {b 3 c 4}       ;# Returns: {a 1 b 3 c 4}
```

```tcl
# Filter by key pattern
dict filter {abc 1 def 2 abx 3} key ab*    ;# Returns: {abc 1 abx 3}

# Filter by value pattern
dict filter {a 10 b 2 c 13} value 1*       ;# Returns: {a 10 c 13}

# Filter by script
dict filter {a 10 b 2 c 13 d 1} script {k v} {
  expr {$v > 5}
}
;# Returns: {a 10 c 13}
```

```tcl
# Map: transform values
dict map {k v} {a 1 b 2 c 3} {
  expr {$v * 2}
}
;# Returns: {a 2 b 4 c 6}
```

#### Iteration and Scoping

```tcl
# foreach: iterate over key-value pairs
set keys {}
set vals {}
dict foreach {k v} {a 1 b 2 c 3} {
  lappend keys $k
  lappend vals $v
}
;# keys = {a b c}, vals = {1 2 3}
```

```tcl
# foreach with break
set keys {}
dict foreach {k v} {a 1 b 2 c 3} {
  lappend keys $k
  if {$k eq "b"} break
}
;# keys = {a b}
```

```tcl
# foreach with continue
set vals {}
dict foreach {k v} {a 1 b 2 c 3} {
  if {$k eq "b"} continue
  lappend vals $v
}
;# vals = {1 3}
```

```tcl
# update: map keys to local variables, modify, write back
set d [dict create a 1 b 2]
dict update d a x b y {
  set x [expr {$x + 10}]
}
dict get $d a    ;# Returns: 11
```

```tcl
# with: unpack all keys into local variables
set d [dict create a 1 b 2]
dict with d {
  set a [expr {$a + 10}]
  set b [expr {$b + 20}]
}
list [dict get $d a] [dict get $d b]  ;# Returns: {11 22}
```

---

<a id="io-examples"></a>

## I/O and Channel Examples

<a id="ex-close"></a>
### close

```tcl
set fh [open example.txt w]
puts $fh Hello
close $fh
```

---

<a id="ex-eof"></a>
### eof

```tcl
set fh [open data.txt r]
while {![eof $fh]} {
  set line [gets $fh]
  # Process line
}
close $fh
```

---

<a id="ex-fblocked"></a>
### fblocked

```tcl
# Check if non-blocking channel would block
# fconfigure $sock -blocking 0
# if {[fblocked $sock]} { ... }
```

---

<a id="ex-fconfigure"></a>
### fconfigure

```tcl
# Set channel encoding and translation
set fh [open data.txt r]
fconfigure $fh -encoding utf-8 -translation lf
```

```tcl
# Non-blocking socket I/O
fconfigure $sock -blocking 0
```

```tcl
# Mixed input/output translation
fconfigure $fh -translation {auto lf}  ;# Accept any input, output LF
```

```tcl
# Query current encoding
set fh [open data.txt r]
set enc [fconfigure $fh -encoding]
close $fh
```

---

<a id="ex-fcopy"></a>
### fcopy

```tcl
# Copy entire file
set src [open source.txt r]
set dst [open dest.txt w]
fcopy $src $dst
close $src
close $dst
```

```tcl
# Copy limited bytes
fcopy $input $output -size 1024
```

---

<a id="ex-flush"></a>
### flush

```tcl
# Force buffered data to be written
set fh [open log.txt a]
puts $fh "Log entry"
flush $fh
close $fh
```

```tcl
# Flush stdout for unbuffered prompt
puts -nonewline "Enter value: "
flush stdout
```

---

<a id="ex-gets"></a>
### gets

```tcl
# Read line, return content
set fh [open data.txt r]
set firstLine [gets $fh]
close $fh
```

```tcl
# Read line into variable, return char count
set fh [open data.txt r]
while {[gets $fh line] >= 0} {
  # Process $line
}
close $fh
```

```tcl
# Eagle extension — keep end-of-line characters
gets -keepeol true $fh line
```

---

<a id="ex-open"></a>
### open

```tcl
# Read mode (default)
set fh [open data.txt r]
set contents [read $fh]
close $fh
```

```tcl
# Write mode (create or truncate)
set fh [open output.txt w]
puts $fh "Hello, World!"
close $fh
```

```tcl
# Append mode
set fh [open log.txt a]
puts $fh "New log entry"
close $fh
```

```tcl
# Eagle extension — exclusive access with auto-flush
set fh [open log.txt a -share None -autoflush]
```

---

<a id="ex-puts"></a>
### puts

```tcl
# Print to stdout
puts "Hello, World!"
;# Prints: Hello, World!
```

```tcl
# Without trailing newline
puts -nonewline "Enter name: "
```

```tcl
# Write to file channel
set fh [open output.txt w]
puts $fh "Line 1"
puts $fh "Line 2"
close $fh
```

```tcl
# Write to stderr
puts stderr "Warning: something unexpected"
```

---

<a id="ex-read"></a>
### read

```tcl
# Read entire file
set fh [open data.txt r]
set contents [read $fh]
close $fh
```

```tcl
# Read specific number of characters
set fh [open data.txt r]
set chunk [read $fh 1024]
close $fh
```

```tcl
# Read without trailing newline
set fh [open data.txt r]
set data [read -nonewline $fh]
close $fh
```

---

<a id="ex-seek"></a>
### seek

```tcl
set fh [open data.txt r]
seek $fh 0 start      ;# Go to beginning
seek $fh 0 end        ;# Go to end
seek $fh -10 current  ;# Back 10 characters
close $fh
```

---

<a id="ex-tell"></a>
### tell

```tcl
set fh [open data.txt r]
read $fh 100
set pos [tell $fh]     ;# Returns offset after reading 100 chars
close $fh
```

---

<a id="ex-truncate"></a>
### truncate

```tcl
# Eagle extension — truncate file at current position
# set fh [open data.txt r+]
# seek $fh 100 start
# truncate $fh            ;# File is now 100 bytes
# close $fh
```

---

## File System Examples

<a id="ex-cd"></a>
### cd

```tcl
# Change to specific directory
# cd /tmp

# Change to home directory
# cd
```

---

> **See also:** [`file.md`](file.md) — deep-dive analysis of the `file` command with additional examples covering 54 sub-commands, security descriptors, access control, advanced globbing, and temporary file management.

<a id="ex-file"></a>
### file

#### Path Manipulation

```tcl
file dirname /usr/local/bin/eagle         ;# Returns: /usr/local/bin
file tail /usr/local/bin/eagle           ;# Returns: eagle
file rootname document.txt               ;# Returns: document
file extension document.txt              ;# Returns: .txt
```

```tcl
file join /usr local bin                 ;# Returns: /usr/local/bin
file split /usr/local/bin                ;# Returns: {/ usr local bin}
```

```tcl
# Normalize path (resolve . and ..)
file normalize /usr/local/../lib
;# Returns: /usr/lib
```

```tcl
file separator                           ;# Returns: / or \\
file pathtype /usr                       ;# Returns: absolute
file pathtype relative/path              ;# Returns: relative
```

#### File Tests

```tcl
file exists /tmp                         ;# Returns: 1
file isdirectory /tmp                    ;# Returns: 1
file isfile /tmp                         ;# Returns: 0
```

```tcl
# Permission tests
file readable data.txt                   ;# Returns: 1 or 0
file writable data.txt                   ;# Returns: 1 or 0
file executable /usr/bin/eagle           ;# Returns: 1 or 0
```

```tcl
# Eagle extension — ownership check
file owned data.txt                      ;# Returns: 1 if owned
```

```tcl
file type /tmp                           ;# Returns: directory
file pathtype /usr                       ;# Returns: absolute
file pathtype relative/path              ;# Returns: relative
```

```tcl
# Eagle extension — compare paths
file same /tmp/a /tmp/../tmp/a           ;# Returns: 1
```

#### File Information

```tcl
# Get file size
file size data.txt                       ;# Returns: size in bytes
```

```tcl
# Get file status
file stat data.txt info
set fileSize $info(size)
set fileType $info(type)
```

```tcl
# Symbolic link status
file lstat link.txt info                 ;# Info about the link itself
```

```tcl
# Get file times
set mtime [file mtime data.txt]
set atime [file atime data.txt]
clock format $mtime -format "%Y-%m-%d"
```

```tcl
# Eagle extension — creation time
set ctime [file ctime data.txt]
```

```tcl
# File attributes (platform-specific)
file attributes data.txt                 ;# Returns all attributes
```

```tcl
# Eagle extension — detailed file information
file information data.txt
file information -directory true /tmp
```

```tcl
# Eagle extension — file version (executables/DLLs)
file version program.exe
```

```tcl
# Eagle extension — file magic number/type
file magic data.bin
```

```tcl
# Eagle extension — security descriptor (Windows)
file sddl data.txt                       ;# Get SDDL string
file rights data.txt                     ;# Get access rights
```

```tcl
# Eagle extension — code signing verification
file trusted program.exe                 ;# Check trust status
file verified program.exe                ;# Check signature verification
```

#### File Operations

```tcl
# Create directory (including parents)
# file mkdir /tmp/mydir/subdir
```

```tcl
# Eagle extension — remove empty directories
# file rmdir /tmp/mydir
```

```tcl
# Copy file
# file copy data.txt /tmp/mydir/
# file copy -force old.txt new.txt
```

```tcl
# Rename/move
# file rename old.txt new.txt
# file rename -force src.txt dst.txt
```

```tcl
# Delete
# file delete myfile.txt
# file delete -force /tmp/mydir        ;# Recursive delete
```

```tcl
# Eagle extension — create empty file or update timestamps
# file touch newfile.txt
```

#### Directory Listing and Temporary Files

```tcl
# List directory contents (Eagle extension)
file list /tmp *.log
```

```tcl
# Eagle extension — temporary file/path
set tmpFile [file tempname]
set tmpDir [file temppath]
```

```tcl
# List open channels
file channels                            ;# Returns: stdin stdout stderr ...
```

```tcl
# List volumes (Windows)
file volumes                          ;# Returns: {C:/ D:/}
```

---

<a id="ex-glob"></a>
### glob

```tcl
# Find all .txt files
glob *.txt
```

```tcl
# Search in specific directory
glob -directory /tmp *.log
```

```tcl
# Only regular files
glob -types f -nocomplain /var/log/*
```

```tcl
# Return only tails (no directory prefix)
glob -tails -directory /usr/local/bin *
```

```tcl
# No error if no matches
glob -nocomplain /nonexistent/*.xyz
;# Returns: {} (empty list, no error)
```

---

<a id="ex-pwd"></a>
### pwd

```tcl
set cwd [pwd]
;# Returns current working directory path
```

---

## Procedure Examples

<a id="ex-proc"></a>
### proc

```tcl
# Simple procedure
proc greet {name} {
  return [appendArgs "Hello, " $name !]
}
greet World
;# Returns: Hello, World!
```

```tcl
# Default argument values
proc connect {host {port 80} {timeout 30}} {
  return [appendArgs \
      "Connecting to " $host : $port \
      " (timeout=" $timeout )]
}
connect localhost            ;# port=80, timeout=30
connect localhost 8080       ;# timeout=30
connect localhost 443 60     ;# All specified
```

```tcl
# Variable arguments
proc sum {args} {
  set total 0
  foreach n $args { incr total $n }
  return $total
}
sum 1 2 3 4 5
;# Returns: 15
```

```tcl
# Mixed required, default, and variable arguments
proc log {level message args} {
  set extra [join $args " "]
  return [appendArgs \
      "\[" $level "\] " $message " " $extra]
}
log INFO "Server started" port=8080 host=localhost
;# Returns: [INFO] Server started port=8080 host=localhost
```

```tcl
# Recursive procedure
proc factorial {n} {
  if {$n <= 1} then { return 1 }
  return [expr {$n * [factorial [expr {$n - 1}]]}]
}
factorial 5
;# Returns: 120
```

---

<a id="ex-nproc"></a>
### nproc

```tcl
# Eagle extension — named (keyword) arguments
nproc connect {host port timeout} {
  return [appendArgs \
      "Connecting to " $host : $port \
      " (timeout=" $timeout )]
}
connect -host localhost -port 8080 -timeout 60
;# Returns: Connecting to localhost:8080 (timeout=60)
```

---

<a id="ex-apply"></a>
### apply

```tcl
# Anonymous function (lambda)
apply {{x y} {expr {$x + $y}}} 3 4
;# Returns: 7
```

```tcl
# Store lambda in variable
set double {{x} {expr {$x * 2}}}
apply $double 5
;# Returns: 10
```

```tcl
# Lambda with no arguments
apply {{} {clock seconds}}
;# Returns: current timestamp
```

```tcl
# Use as callback
set transform {{s} {string toupper $s}}
set result [apply $transform hello]
;# Returns: HELLO
```

---

<a id="ex-napply"></a>
### napply

```tcl
# Eagle extension — lambda with named arguments
napply {{x y} {expr {$x + $y}}} -x 3 -y 4
;# Returns: 7
```

---

## Namespace Examples

> **See also:** [`namespace.md`](namespace.md) — deep-dive analysis of the `namespace` command with additional examples covering the dual-implementation architecture, import/export mechanism, per-namespace unknown handlers, and scope integration.

<a id="ex-namespace"></a>
### namespace

#### Creating and Managing

```tcl
# Create namespace with procedures and variables
namespace eval mylib {
  variable version 1.0

  proc greet {name} {
    return [appendArgs "Hello from mylib, " $name !]
  }

  proc getVersion {} {
    variable version
    return $version
  }
}
mylib::greet World           ;# Returns: Hello from mylib, World!
mylib::getVersion            ;# Returns: 1.0
```

```tcl
# Check existence
namespace exists mylib       ;# Returns: 1
namespace exists nosuch      ;# Returns: 0
```

```tcl
# Delete namespace
# namespace delete mylib
```

```tcl
# Eagle extension — enable/disable namespace support
namespace enable            ;# Query current state
namespace enable true       ;# Enable namespace support
```

#### Information

```tcl
namespace eval myns {
  namespace current         ;# Returns: ::myns
  namespace parent          ;# Returns: ::
}
```

```tcl
# List child namespaces
namespace eval parent {
  namespace eval child1 {}
  namespace eval child2 {}
}
namespace children ::parent
;# Returns: {::parent::child1 ::parent::child2}
```

```tcl
# Eagle extension — recursive descendants
namespace descendants ::parent
```

```tcl
# Eagle extension — namespace info and rename
namespace info ::myns      ;# Detailed namespace info
namespace rename ::myns ::mylib  ;# Rename namespace
```

```tcl
# Eagle extension — namespace mappings
namespace mappings         ;# Returns mapping information
```

#### Path and Name Manipulation

```tcl
namespace qualifiers "::foo::bar::baz"    ;# Returns: ::foo::bar
namespace tail "::foo::bar::baz"          ;# Returns: baz
```

```tcl
# Resolve command to fully-qualified name
namespace which -command puts             ;# Returns: ::puts
namespace which -variable env             ;# Returns: ::env
```

#### Exporting and Importing

```tcl
namespace eval mathlib {
  namespace export add subtract
  proc add {a b} { expr {$a + $b} }
  proc subtract {a b} { expr {$a - $b} }
  proc internal {} { return "not exported" }
}

# Import exported commands
namespace import mathlib::*
add 3 4              ;# Returns: 7 (no qualifier needed)
subtract 10 3        ;# Returns: 7
```

```tcl
# Remove imported commands
namespace forget mathlib::*
```

#### Script Execution in Namespace Context

```tcl
namespace eval myns {
  variable data secret
  proc showData {} {
    variable data
    return $data
  }
}
set callback [namespace code {showData}]
eval $callback
;# Returns: secret (executes in ::myns context)
```

```tcl
# Inscope
namespace inscope ::myns showData
;# Returns: secret
```

```tcl
# Unknown command handler for a namespace
namespace unknown myUnknownHandler
namespace unknown                   ;# Query current handler
```

```tcl
# Resolve original command through import chain
namespace origin add               ;# Returns: ::mathlib::add
```

---

<a id="object-examples"></a>

## Objects (.NET Interop) Examples

> **See also:** [`object.md`](object.md) — Deep-dive analysis of all 44 sub-commands, the opaque handle system, FixupReturnValue pipeline, method overload resolution, and practical .NET interop patterns.

<a id="ex-object"></a>
### object

#### Creating Objects

```tcl
# Create a StringBuilder
set sb [object create System.Text.StringBuilder Initial]
```

```tcl
# Create with alias (auto-generates alias command)
object create -alias -objectname myList System.Collections.ArrayList
```

```tcl
# Create with constructor overload (specify parameter types)
set dt [object create -parametertypes {int int int} System.DateTime 2024 1 15]
```

#### Invoking Members

```tcl
# Instance methods
set sb [object create System.Text.StringBuilder]
object invoke $sb Append Hello
object invoke $sb Append ", World!"
set result [object invoke $sb ToString]
;# result is "Hello, World!"
```

```tcl
# Static method
set now [object invoke System.DateTime Now]
```

```tcl
# Property access
set sb [object create System.Text.StringBuilder Test]
set length [object invoke $sb Length]
;# length is 4
```

```tcl
# Static property
set newline [object invoke System.Environment NewLine]
```

```tcl
# Math operations via .NET
set result [object invoke System.Math Sqrt 144.0]
;# result is 12
```

```tcl
# Invoke multiple members in sequence
set sb [object create System.Text.StringBuilder]
object invokeall $sb {Append Hello} {Append " World"} {ToString}
```

```tcl
# Raw invocation (no automatic type conversion)
object invokeraw $sb Append test
```

### Chained .NET Method Calls

```tcl
# Create a StringBuilder and chain operations
set sb [object create System.Text.StringBuilder]

# Chain append calls using the returned object
object invoke $sb Append "Hello"
object invoke $sb Append ", "
object invoke $sb Append "World!"
puts [object invoke $sb ToString]  ;# Hello, World!

# Property access on nested objects
set list [object create System.Collections.Generic.List\`1\[System.String\]]
object invoke $list Add "first"
object invoke $list Add "second"
puts [object invoke $list Count]        ;# 2
puts [object invoke $list Item 0]       ;# first
```

#### Object Information

```tcl
set sb [object create System.Text.StringBuilder]
object exists $sb              ;# Returns: 1
object isnull $sb              ;# Returns: 0
object isdisposed $sb       ;# Returns: 0 (not yet disposed)
```

```tcl
# List members
set members [object members $sb]
```

```tcl
# Type checking
set list [object create System.Collections.ArrayList]
object isoftype $list System.Collections.IList
;# Returns: 1
```

```tcl
# Object flags and reference counting
object flags $sb              ;# Query object flags
object referencecount $sb     ;# Returns reference count
```

#### Object Lifecycle

```tcl
# Proper disposal pattern
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

```tcl
# Cleanup unreferenced objects
object cleanup
```

```tcl
# Manual reference management
object addreference $obj      ;# Prevent automatic cleanup
object removereference $obj   ;# Allow cleanup again
```

#### Collections and Iteration

```tcl
# Build and iterate a collection
set list [object create System.Collections.ArrayList]
object invoke $list Add one
object invoke $list Add two
object invoke $list Add three

object foreach item $list {
  # Prints: one, two, three
}
```

```tcl
# Collect results with lmap
set doubled [object lmap item $list {
  string toupper $item
}]
;# Returns: {ONE TWO THREE}
```

#### Assemblies and Types

```tcl
# List loaded assemblies
object assemblies *System*
```

```tcl
# Load an assembly by name or path
object load System.Data
object load MyAssembly.dll
```

```tcl
# List registered type mappings
object types *StringBuilder*
```

```tcl
# Search for a specific type
object search System.Text.StringBuilder
```

```tcl
# List .NET namespaces and interfaces
object namespaces *System*
object interfaces *IDisposable*
```

#### Namespace Import and Type Declarations

```tcl
# Import .NET namespaces for shorter type names
object import System.Text System.IO
set sb [object create StringBuilder]    ;# No System.Text. prefix needed
object unimport
```

```tcl
# Register type name mapping
object type SB System.Text.StringBuilder
set sb [object create SB]
object untype
```

#### Aliases

```tcl
# Create named alias for object
set sb [object create System.Text.StringBuilder Hello]
object alias -aliasname mySB $sb
# Can now use mySB as a command
```

```tcl
# Remove alias
object unalias mySB
```

```tcl
# List alias namespaces and all object handles
object aliasnamespaces
object list                  ;# List all object handles
object list *String*         ;# List matching handles
```

#### Type Conversion and Variable Access

```tcl
# Register custom type converters
object type fromTypeName toTypeName
object untype                ;# Remove custom converters
```

```tcl
# Get object reference from a variable
object fromvar myObjectVar
```

---

## Debugging Examples

  > **See also:** [`debug.md`](debug.md) for a deep-dive analysis of the debugger architecture, emergency recovery, secure evaluation, variable watchpoints, and practical debugging patterns.

<a id="ex-debug"></a>
### debug

#### Debugger Control

```tcl
# Requires: DEBUGGER
debug enable true            ;# Enable the debugger
debug enable false           ;# Disable the debugger
debug enable                 ;# Toggle (NOT a query)
```

```tcl
debug interactive true       ;# Enable interactive mode
debug interactive            ;# Query interactive state
```

```tcl
# Requires: DEBUGGER
debug status                 ;# Returns human-readable debugger status string
debug ready                  ;# Returns: True if debugger is ready
debug ready true             ;# Also check for isolated debugger interpreter
```

```tcl
# Managed debugger break (for debugging the interpreter itself)
debug self                   ;# Break if managed debugger is attached
debug self true true         ;# Force break even on release builds
```

#### Breakpoints and Execution Control

```tcl
# Requires: DEBUGGER
debug break                            ;# Demand breakpoint
debug break -nocomplain -noerror       ;# Silent if no debugger
```

```tcl
# Requires: DEBUGGER, DEBUGGER_BREAKPOINTS
debug breakpoints                      ;# List all breakpoints
debug breakpoints my*                  ;# List matching breakpoints
```

```tcl
# Single-stepping
# Requires: DEBUGGER
debug step true                        ;# Enable single-stepping
debug step                             ;# Toggle stepping mode
debug steps 100                        ;# Execute 100 steps then pause
debug steps                            ;# Query current step counter
```

```tcl
# Suspend and resume debugger
# Requires: DEBUGGER
debug suspend                          ;# Suspend debugger (save context)
debug resume                           ;# Resume debugger (restore context)
```

```tcl
# Halt script evaluation immediately
debug halt "stopped by user"           ;# Halt with custom result
```

#### Call Stack and Variables

```tcl
# Nesting depth limits
debug levels                 ;# Returns nesting depth limits
```

```tcl
# Stack space information
debug stack                  ;# Returns: threadId N used N allocated N ...
debug stack true             ;# Force refresh of native stack pointers
```

```tcl
# Variable introspection
debug variable myVar                 ;# Basic variable info
debug variable -elements myArray     ;# Include array elements
debug variable -links myVar          ;# Follow variable links
```

```tcl
# Variable watchpoints
debug watch myVar BreakOnSet         ;# Break when myVar is written
debug watch myVar BreakOnGet         ;# Break when myVar is read
debug watch myVar                    ;# Query watch flags
debug watch                          ;# List all watched variables
```

```tcl
# Variable locking (thread-exclusive access)
debug lockvar true myVar             ;# Lock variable
debug lockvar false myVar            ;# Unlock variable
debug lockvar null myVar             ;# Query lock state
```

```tcl
# Interactive loop semaphore
# Requires: SHELL
debug lockloop true                  ;# Acquire interactive loop lock
debug lockloop false                 ;# Release interactive loop lock
```

#### Script Evaluation in Debug Context

```tcl
# Evaluate in the debugger interpreter (not main)
# Requires: DEBUGGER
debug eval {info vars}               ;# Run in debugger interp
```

```tcl
# Run code without debugger interception ("full speed")
# Requires: DEBUGGER
debug run {
  set result [expensive_computation]
}
```

```tcl
# Invoke command in debugger interpreter at a specific level
# Requires: DEBUGGER
debug invoke #0 info vars            ;# At global level of debugger interp
```

```tcl
# Substitution in debugger interpreter
# Requires: DEBUGGER
debug subst {Value is $myVar}
debug subst -novariables {Literal $dollar}
```

```tcl
# Secure evaluation in a child interpreter
debug secureeval -timeout 5000 child {expr {2 + 2}}
debug secureeval -trusted true -stoponerror true child {source safe.tcl}
```

#### Interactive Debugger

```tcl
# Requires: SHELL
debug shell                          ;# Start interactive debug shell
debug shell -asynchronous true       ;# Start on background thread
```

```tcl
# Requires: DEBUGGER
debug icommand {info vars}           ;# Set one-time command for debugger loop
debug icommand                       ;# Query current one-time command
```

```tcl
# Requires: DEBUGGER
debug iqueue {set x 1}              ;# Enqueue command
debug iqueue -dump                   ;# Show queued commands
debug iqueue -clear                  ;# Clear the queue
```

```tcl
# Requires: DEBUGGER
debug iresult "custom result"        ;# Set one-time result
debug iresult                        ;# Query current one-time result
```

#### Event Handlers (Break-On Triggers)

```tcl
# Requires: DEBUGGER
# All toggle without arguments; explicitly set with boolean:
debug onerror true                    ;# Break on errors
debug onerror                         ;# Toggle break-on-error
debug oncancel true                   ;# Break on script cancellation
debug onexecute true                  ;# Break on command execution
debug onexit true                     ;# Break on interpreter exit
debug onreturn true                   ;# Break on procedure return
debug ontest true                     ;# Break during test execution
```

```tcl
# Requires: DEBUGGER, DEBUGGER_BREAKPOINTS
debug ontoken true                    ;# Break on token processing
```

#### Debug Hooks

```tcl
debug hook -type Before mytest-* {puts [appendArgs "About to run: " $name]}
debug hook                            ;# List all hooks
debug hook mytest-*                   ;# List hooks matching pattern
debug hook -unset true mytest-*       ;# Remove hook
```

#### Logging and Output

```tcl
debug log -category MyApp "Processing started"
debug log -level 2 "Detailed message"
```

```tcl
# Native debug output (e.g., OutputDebugString on Windows)
# Requires: NATIVE
debug output "Native debug message"
debug output "Notice priority" Notice    ;# Uses DebugPriority enum
```

```tcl
# Multi-channel debug write
debug write "Message to all channels"
debug write "Output only" NoViaTrace
```

```tcl
# Trace configuration and messaging
debug trace -priority Notice [appendArgs "Item " $i " processed"]
# Requires: TEST
debug trace -log true -logfilename /tmp/eagle.log
debug trace                              ;# Query current trace status
```

```tcl
# Virtual output buffering
debug vout stdout true                   ;# Enable virtual output on stdout
# ... output operations ...
set captured [debug vout stdout]         ;# Get accumulated output
```

#### Memory and GC

```tcl
debug memory                             ;# Detailed memory statistics
# Requires: NATIVE
debug sysmemory                          ;# Native/system memory info
debug gcmemory                           ;# GC total memory
debug gcmemory true                      ;# GC memory (force collect)
debug collect                            ;# Force garbage collection
debug cleanup                            ;# Clean up caches and call frames
debug purge                              ;# Purge all call frame information
```

#### Script Bundles

```tcl
# Requires: DATA
debug bundle scripts.db                  ;# Parse and list bundle contents
debug bundle scripts.db c2VjcmV0         ;# With Base64 password
debug bundle scripts.db "" util*         ;# Filter by pattern
```

```tcl
# Requires: DATA
debug mount scripts.bundle c2VjcmV0     ;# Mount with Base64 password
debug mounts                             ;# List mounted bundles
debug mounts script*                     ;# List matching mounts
debug unmount scripts.bundle             ;# Unmount
```

#### Command and Function Breakpoints

```tcl
# Requires: DEBUGGER
debug execute puts true                  ;# Break on puts
debug execute puts                       ;# Query breakpoint state
debug function rand true                 ;# Break on rand() in expressions
debug operator + true                    ;# Break on + operator
```

```tcl
# Procedure flags
debug procedureflags myProc              ;# Query flags
debug procedureflags myProc Breakpoint   ;# Set flags
```

```tcl
# Test breakpoints
# Requires: DEBUGGER
debug test mytest-1.0 true               ;# Break on specific test
debug test mytest-1.0                    ;# Query breakpoint state
debug test                               ;# List all test breakpoints
```

```tcl
# Token-level breakpoints (source location)
# Requires: DEBUGGER, DEBUGGER_BREAKPOINTS
debug token script.tcl 10 20 true        ;# Break on lines 10-20
debug token script.tcl 10 20             ;# Query breakpoint match
```

```tcl
# Restore deleted variables
debug undelete my*                       ;# Restore matching variables
```

#### History and Caching

```tcl
# Requires: HISTORY
debug history                            ;# Query history tracking state
debug history true                       ;# Enable history tracking
```

```tcl
# Cache configuration
debug cacheconfiguration                 ;# Query current cache state
debug refreshautopath                    ;# Refresh auto-path list
debug refreshautopath true               ;# Refresh with verbose output
```

#### Runtime Options

```tcl
debug runtimeoption add noGc             ;# Add option
debug runtimeoption has noGc             ;# Check -> True
debug runtimeoption get                  ;# List all
debug runtimeoption remove noGc          ;# Remove
debug runtimeoption clear                ;# Clear all
debug runtimeoption set {opt1 opt2}      ;# Replace all
```

```tcl
# Runtime override
debug runtimeoverride Default            ;# Set manual runtime override
```

#### Path and Configuration

```tcl
debug paths                              ;# All interpreter paths
debug paths GetAll                       ;# Get all paths
debug paths ExistingOnly                 ;# Only existing paths
```

```tcl
debug testpath                           ;# Query current test path
debug testpath /path/to/tests            ;# Set test path
```

```tcl
# Breakpoint types
# Requires: DEBUGGER
debug types                              ;# Query active breakpoint types
debug types "Demand|Execute"             ;# Set active types
```

#### Read-Only Locking

```tcl
debug readonly {} Command true puts         ;# Lock puts command
debug readonly {} Command false puts        ;# Unlock puts command
debug readonly {} Variable null *           ;# Query all variable locks
debug readonly {} Procedure true myProc     ;# Lock a procedure
```

#### Exception and Result Inspection

```tcl
catch {error "something went wrong"}
debug result                             ;# Full result with stack traces
debug exception                          ;# Get exception as object handle
debug complaint                          ;# Get internal diagnostic messages
```

#### Plugin Debugging

```tcl
debug pluginexecute MyPlugin {arg1 arg2} ;# Execute plugin method
debug pluginflags                        ;# Query plugin flags
debug pluginflags SomeFlag               ;# Set plugin flags
```

#### Other Operations

```tcl
debug null                               ;# Force null result
debug set myVar $objectHandle            ;# Set variable to object value
debug set -convert true myVar $obj       ;# Convert object to string
debug keyring                            ;# Fetch and merge security keyring
debug restore                            ;# Restore core plugin to defaults
debug restore true true                  ;# Strict and verbose restore
```

```tcl
# Emergency debugging mode
debug emergency                          ;# Enter emergency mode
debug emergency -nocomplain Default      ;# With options
```

```tcl
# Debugger callback management
# Requires: DEBUGGER
debug callback arg1 arg2                 ;# Set callback arguments
debug callback                           ;# Query callback arguments
debug callback {}                        ;# Clear callback
```

---

<a id="interpreter-examples"></a>

## Interpreter Management Examples

<a id="ex-interp"></a>
### interp

> **Deep-dive**: For comprehensive analysis of the interp command's internals, including the safe interpreter security model, command hiding, policy-based access control, resource limits, and cross-interpreter communication, see [`interp.md`](interp.md).

#### Creating and Deleting

```tcl
# Create a child interpreter
set child [interp create myChild]
interp exists myChild          ;# Returns: 1
interp children                ;# Returns: myChild
interp parent myChild          ;# Returns parent interpreter path (e.g., "")
```

```tcl
# Create safe (sandboxed) interpreter
set safe [interp create -safe mySafe]
interp issafe mySafe           ;# Returns: 1
```

```tcl
# Delete interpreter
# interp delete myChild
```

#### Evaluating Code

```tcl
set child [interp create]
interp eval $child {
  proc greet {name} { return [appendArgs "Hello, " $name !] }
}
set result [interp eval $child {greet World}]
;# result is "Hello, World!"
interp delete $child
```

```tcl
# Expression evaluation in child
set child [interp create]
set result [interp expr $child {2 + 2}]
;# result is 4
interp delete $child
```

```tcl
# Source a file in child interpreter
# interp source $child config.eagle
```

```tcl
# String substitution in child
set child [interp create]
interp set $child name World
set result [interp subst $child {Hello, $name!}]
;# result is "Hello, World!"
interp delete $child
```

```tcl
# Queue a script for later evaluation
interp queue $child {puts "deferred execution"}
```

#### Variable Access

```tcl
set child [interp create]
interp set $child myVar value
set v [interp set $child myVar]
;# v is "value"
interp unset $child myVar      ;# Remove the variable
interp delete $child
```

#### Aliases (Cross-Interpreter Commands)

```tcl
set child [interp create -safe]
# Allow child to call 'safeLog' which maps to 'puts' in parent
interp alias $child safeLog {} puts
interp eval $child {safeLog "Message from child"}
;# Prints: Message from child
```

```tcl
# Query alias target
interp alias $child safeLog  ;# Returns: target info
interp aliases $child        ;# List all aliases
interp target $child safeLog ;# Returns target interpreter
interp delete $child
```

```tcl
# Create alias with prepended arguments
interp alias {} dir {} glob -nocomplain
# dir *.txt  =>  glob -nocomplain *.txt
```

#### Hidden Commands

```tcl
set safe [interp create -safe]
interp hidden $safe            ;# List hidden commands
interp exposed $safe           ;# List exposed commands
```

```tcl
# Invoke hidden commands directly (trusted operations)
interp invokehidden $safe source trusted.tcl
```

```tcl
# Hide and expose commands
interp hide $safe puts          ;# Hide puts in safe interp
interp expose $safe puts        ;# Re-expose puts
interp delete $safe
```

#### Security Configuration

```tcl
set child [interp create]
interp issafe $child           ;# Returns: 0 (not safe)
interp makesafe $child       ;# Convert to safe mode
interp issafe $child         ;# Returns: 1
```

```tcl
# Standard mode
interp makestandard $child
interp isstandard $child     ;# Returns: 1
```

```tcl
# Trust and policy management
interp marktrusted $child
interp policy $child -type SomeType \
    {puts [appendArgs "Policy check for: " $args]}
interp nopolicy $child policyName
```

```tcl
# Isolation and immutability
interp isolated $child       ;# Returns: 0 or 1
interp immutable $child true ;# Make immutable
interp readonly $child true  ;# Make read-only
interp enabled $child false  ;# Disable interpreter
interp issdk $child          ;# Check SDK mode
interp delete $child
```

#### Resource Limits

```tcl
set child [interp create -safe]
interp recursionlimit $child 100      ;# Limit stack depth
interp iterationlimit $child 10000    ;# Limit loop iterations
```

```tcl
# Additional resource limits
interp proclimit $child 500         ;# Max procedures
interp varlimit $child 1000         ;# Max variables
interp namespacelimit $child 50     ;# Max namespaces
interp scopelimit $child 100        ;# Max scopes
interp resultlimit $child 1048576   ;# Max result size
interp callbacklimit $child 100     ;# Max callbacks
interp eventlimit $child 1000       ;# Max events
interp execlimit $child 100000      ;# Max operation limit
interp readylimit $child 100        ;# Max ready operations
interp childlimit $child 10         ;# Max child interpreters
interp delete $child
```

#### Timeout and Execution Control

```tcl
set child [interp create -safe]
interp timeout $child 5000            ;# 5 second execution timeout
interp finallytimeout $child 2000   ;# 2 second finally block timeout
interp sleeptime $child 100         ;# 100ms between timeout checks
```

```tcl
# Cancel execution
interp cancel $child "Time limit exceeded"
interp cancel -unwind $child        ;# Cancel and unwind stack
interp resetcancel $child           ;# Reset cancel flag
```

```tcl
# Watchdog timer for automatic cancellation
interp watchdog $child true         ;# Enable watchdog
interp delete $child
```

#### Command Management

```tcl
# Add commands to child interpreter
interp addcommands $child string*
```

```tcl
# Rename commands in child
interp rename $child oldCmd newCmd
```

```tcl
# Create stub commands
interp stub $child myStub
```

```tcl
# Add sub-commands to an ensemble in child
interp subcommand $child string mysubcmd {myImplementation}
```

#### Object Sharing

```tcl
# Share .NET objects between interpreters
set obj [object create System.Text.StringBuilder]
interp shareobject $child $obj      ;# Share object with child
```

```tcl
# Share interpreter as an object
interp shareinterp $child interpObj
```

#### Background Error Handling

```tcl
# Set background error handler for child
interp bgerror $child myBgErrorHandler
interp bgerror $child               ;# Query current handler
```

---

## Package Examples

<a id="ex-package"></a>
> **See also**: [`package.md`](package.md) — Deep-dive analysis covering multi-source index discovery, tagged indexes, auto-path integration, package aliases, security verification, the require fallback chain, and all 23 sub-commands.

### package

#### Loading Packages

```tcl
# Require a package (loads if not present)
package require http 2.0

# Require exact version
package require -exact json 1.0
```

```tcl
# Check if already loaded (no loading)
package present http 2.0
```

#### Providing Packages

```tcl
# In your package script:
package provide mypackage 1.0
proc mypackage::init {} { ... }
```

#### Package Index

```tcl
# Register a package script
package ifneeded mypackage 1.0 \
    [list source [file join $dir mypackage.tcl]]
```

```tcl
# Scan directories for packages
package scan /usr/local/lib/eagle
```

### Package Scanning with Flags

```tcl
# Scan specific directories for packages
package scan /path/to/my/packages

# Scan with verbose output and forced refresh
package scan -verbose -refresh

# Scan using the interpreter's current flags
package scan -interpreter -verbose

# Preview what would be scanned without actually doing it
package scan -whatif /path/to/packages
```

```tcl
# Get/set unknown package handler
package unknown               ;# Query current handler
package unknown myHandler     ;# Set custom handler
```

```tcl
# List package index files
package indexes              ;# All known indexes
package indexes *.eagle      ;# Matching pattern
```

#### Querying Information

```tcl
package names                ;# List all known packages
package names http*          ;# Matching pattern
package versions http        ;# List versions of http
package loaded               ;# List loaded packages
package vloaded              ;# Loaded with version info
package pending              ;# Packages currently being loaded
package info http            ;# Detailed info about a package
```

#### Version Comparison

```tcl
package vcompare 1.0 2.0      ;# Returns: -1
package vcompare 2.1 2.1      ;# Returns: 0
package vcompare 3.0 2.0      ;# Returns: 1
package vsatisfies 2.5 2.0    ;# Returns: 1
package vsatisfies 1.5 2.0    ;# Returns: 0
package vsort 2.0 1.0       ;# Sort two versions
```

#### Package State

```tcl
package forget mypackage      ;# Remove from known list
package withdraw mypackage 1.0  ;# Withdraw a specific version
package absent mypackage      ;# Mark as explicitly absent
package reset                 ;# Reset package management state
```

#### Package Aliases

```tcl
# Create alias for a package
package alias myAlias mypackage 1.0
package aliases              ;# List all package aliases
```

```tcl
# Relative filename in package context
package relativefilename lib/helper.eagle
```

---

## Testing Examples

<a id="ex-test1"></a>
### test1

```tcl
# Eagle extension — basic test command
test1 string-length-1.1 "Test string length" {} {
  string length hello
} {5}
```

```tcl
test1 math-1.1 "Test basic arithmetic" {} {
  expr {2 + 2}
} {4}
```

```tcl
test1 list-1.1 "Test list creation" {} {
  list a b c
} {a b c}
```

---

<a id="ex-test2"></a>
### test2

```tcl
# Eagle extension — advanced test with setup/cleanup
test2 file-read-1.1 "Test file reading" \
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

```tcl
# Test expected error
test2 error-1.1 "Test error handling" \
    -body {
      error "expected error"
    } \
    -returnCodes error \
    -result "expected error"
```

```tcl
# Test with constraints
test2 platform-1.1 "Unix-only test" \
    -constraints {unix} \
    -body {
      file exists /dev/null
    } \
    -result {1}
```

```tcl
# Test with glob match
test2 version-1.1 "Test version format" \
    -body {
      version
    } \
    -match glob \
    -result {*.*.*.*}
```

---

<a id="database-examples"></a>

## Database (SQL) Examples

<a id="ex-sql"></a>
### sql

> **See also**: [`sql.md`](sql.md) for a deep-dive analysis of the database command, including `-variable` auto-cleanup, script bundles, parameterized queries, result formatting, and practical patterns.

#### Connection Management

```tcl
# Open SQLite connection
# set conn [sql open -type SQLite "Data Source=mydb.sqlite;"]
# sql isopen $conn       ;# Returns: 1
# sql connection $conn   ;# Returns connection info
# sql close $conn
```

```tcl
# List available database types
# sql types              ;# Returns available SQL/database types
# sql types "*SQLite*"   ;# Filter by pattern
```

#### Executing Queries

```tcl
# Scalar query
# set count [sql execute -execute scalar $conn \
#     "SELECT COUNT(*) FROM users"]
```

```tcl
# Reader query with nested list format
# set results [sql execute -execute reader -format nestedlist $conn \
#     "SELECT name, age FROM users"]
# foreach row $results {
#     lassign $row name age
# }
```

```tcl
# Parameterized query (SQL injection safe)
# set results [sql execute -execute reader $conn \
#     "SELECT * FROM users WHERE age > @minAge" \
#     {minAge Int32 21}]
```

```tcl
# Iteration with sql foreach
# sql foreach $conn "SELECT name, age FROM users" {
#     puts "Name: $name, Age: $age"
# }
```

#### Transactions

```tcl
# set trans [sql transaction begin $conn]
# sql hasbegun $trans           ;# Returns: 1
# try {
#     sql execute $conn "INSERT INTO users (name) VALUES (@n)" \
#         {n String Alice}
#     sql execute $conn "INSERT INTO users (name) VALUES (@n)" \
#         {n String Bob}
#     sql transaction commit $trans
# } finally {
#     catch {sql transaction rollback $trans}
# }
```

### SQL Connection with Automatic Cleanup

```tcl
# Open a SQLite database with -variable for automatic cleanup
sql open -type SQLite -variable db "Data Source=mydb.db"

# Create and populate a table
sql execute $db "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)"
sql execute $db {INSERT INTO users (name) VALUES (?);} \
    [list param1 String "Alice"]

# Scalar query: get a single value
set count [sql execute -execute scalar $db \
    "SELECT COUNT(*) FROM users;"]

# Reader query: results populate $rows array
sql execute -execute reader $db "SELECT * FROM users;"
# $rows(count) = number of rows
# $rows(names) = {id name}
# $rows(0)     = first row values

# Parameterized lookup
set name [sql execute -execute scalar $db \
    {SELECT name FROM users WHERE id = ?;} \
    [list param1 Int64 1]]

# When $db variable is unset or goes out of scope, connection
# is automatically closed and disposed
unset db
```

### SQL Transaction with Error Handling

```tcl
set db [sql open -type SQLite "Data Source=mydb.db"]

set transaction [sql transaction begin $db]

if {[catch {
    sql execute $db {INSERT INTO users (name) VALUES (?);} \
        [list param1 String "Bob"]
    sql execute $db {INSERT INTO users (name) VALUES (?);} \
        [list param1 String "Carol"]
    sql transaction commit $transaction
} error]} {
    catch {sql transaction rollback $transaction}
    error $error
}

sql close $db
```

### SQL DataReader for Large Result Sets

```tcl
# Stream results one row at a time (constant memory)
set reader [sql execute -execute reader -format datareader \
    -alias $db "SELECT id, name FROM users ORDER BY id;"]

while {[$reader Read]} {
    set id   [$reader GetValue [$reader GetOrdinal "id"]]
    set name [$reader GetValue [$reader GetOrdinal "name"]]
    puts "User $id: $name"
}

unset reader
```

### SQL DataTable for Reusable Named-Column Access

```tcl
# Materialize results as a DataTable object
set table [sql execute -execute reader -format datatable \
    $db "SELECT id, name, age FROM users;"]

# Get column names
puts [$table GetColumnNames]  ;# {id name age}

# Convert to list of row-value lists
puts [$table ToList]          ;# {1 Alice 30} {2 Bob 25}

# Convert to list of key-value dictionaries
puts [$table ToDictionary]    ;# {id 1 name Alice age 30} {id 2 ...}

# Named column access on individual rows
object foreach -alias row [$table Rows] {
    puts "[$row Item name] is [$row Item age] years old"
}

# In-memory filtering (no new query needed)
set seniors [$table Select "age >= 65"]

# Row count
puts [$table Rows.Count]

# Clean up
unset table
```

---

<a id="network-examples"></a>

## Network and URI Examples

<a id="ex-socket"></a>
### socket

```tcl
# Client socket
# set sock [socket localhost 8080]
# puts $sock "Hello, server!"
# flush $sock
# gets $sock response
# close $sock
```

```tcl
# Server socket
# proc handleClient {chan addr port} {
#     gets $chan line
#     puts $chan "Echo: $line"
#     close $chan
# }
# set server [socket -server handleClient 8080]
# vwait forever
```

```tcl
# Async connection
# set sock [socket -async localhost 8080]
```

---

<a id="ex-uri"></a>
> **See also**: [`uri.md`](uri.md) — Deep-dive analysis covering HTTP download/upload, async callbacks, custom WebClient classes, the four per-interpreter web callbacks, retry infrastructure, and all 18 sub-commands.

### uri

#### URI Construction and Parsing

```tcl
# Eagle extension — create URI from components
uri create https example.com -port 8080 -path /api/data
```

```tcl
# Parse URI into components
set parts [uri parse https://example.com:8080/path?q=test]
;# Returns dictionary with scheme, host, port, path, query
```

```tcl
# Validate individual components
uri host example.com                ;# Validates hostname
uri scheme https                    ;# Validates scheme name
```

```tcl
# Join URI path components
uri join /api v1 users                      ;# Returns: /api/v1/users
```

#### Validation and Comparison

```tcl
# Validate URI
uri isvalid https://example.com             ;# Returns: 1
uri isvalid "not a uri"                     ;# Returns: 0
uri isvalid relative/path relative          ;# Check as relative URI
```

```tcl
# Compare two URIs
uri compare https://a.com https://b.com     ;# Returns: -1, 0, or 1
```

#### Encoding

```tcl
# URL-encode a string
set encoded [uri escape Data "hello world"] ;# Uses UriEscapeType enum
;# Returns: hello%20world

# URL-decode
set decoded [uri unescape hello%20world]
;# Returns: hello world
```

#### HTTP Operations

> **Note**: `uri get` is an alias for `uri download -inline` and
> `uri post` is an alias for `uri upload -inline`. All four sub-commands
> share the same implementation; the difference is that `get`/`post`
> default to inline mode (return data) while `download`/`upload` default
> to file mode (read/write disk). All require the `NETWORK` compile flag.

##### uri download / uri get — Downloading Data

```tcl
# Requires: NETWORK
# Download file to disk (default file mode)
uri download https://example.com/file.zip /tmp/file.zip
;# Returns: "" (empty string on success)
```

```tcl
# Requires: NETWORK
# Download with explicit timeout (milliseconds)
uri download -timeout 30000 -- https://example.com/large.zip /tmp/large.zip
```

```tcl
# Requires: NETWORK
# Download with timeout type (uses interpreter's network timeout)
uri download -timeouttype network -- \
    https://example.com/file.zip /tmp/file.zip
```

```tcl
# Requires: NETWORK
# Download with retry on failure
uri download -retries 3 -timeout 10000 -- \
    https://example.com/file.zip /tmp/file.zip
```

```tcl
# Requires: NETWORK
# Download inline — return content as string instead of saving to file
set html [uri download -inline -- https://example.com/]
;# html contains the page content
```

```tcl
# Requires: NETWORK
# uri get is shorthand for uri download -inline
set html [uri get https://example.com/]
;# Equivalent to: uri download -inline -- https://example.com/
```

```tcl
# Requires: NETWORK
# Inline download with network timeout
set data [uri download -timeouttype network -inline -- $uri]
```

```tcl
# Requires: NETWORK
# Specify response encoding
set text [uri download -inline -encoding utf-8 \
    -- https://example.com/data.txt]
```

```tcl
# Requires: NETWORK
# Asynchronous download with callback
uri download -inline -callback {myDownloadHandler} -- https://example.com/data
;# myDownloadHandler is called when download completes
;# Note: -trusted cannot be used with -callback
```

##### uri upload / uri post — Uploading Data

```tcl
# Requires: NETWORK
# Upload a file to server (default file mode)
uri upload https://example.com/upload /tmp/data.txt
;# Returns: server response as string
```

```tcl
# Requires: NETWORK
# Upload file with explicit HTTP method
uri upload -method PUT -- https://example.com/files/doc.txt /tmp/doc.txt
```

```tcl
# Requires: NETWORK
# Upload file with timeout and retries
uri upload -timeout 60000 -retries 3 -- \
    https://example.com/upload /tmp/large-file.zip
```

```tcl
# Requires: NETWORK
# POST form data inline (name-value pairs, URL-encoded automatically)
set response [uri upload -inline -data {username admin password secret} -- \
    https://example.com/login]
;# Data sent as: username=admin&password=secret (form-encoded)
;# Returns: server response as string
```

```tcl
# Requires: NETWORK
# uri post is shorthand for uri upload -inline
set response [uri post -data {var1 val1 var2 val2} -- \
    https://example.com/api]
;# Equivalent to: uri upload -inline -data {var1 val1 var2 val2} -- ...
```

```tcl
# Requires: NETWORK
# POST form data with network timeout type
set response [uri upload -timeouttype network -inline \
    -data {key1 value1 key2 value2} -- $uri]
```

```tcl
# Requires: NETWORK
# POST raw bytes (not form-encoded) with -raw flag
set response [uri upload -inline -raw \
    -data {72 101 108 108 111} -- https://example.com/raw]
;# Sends raw byte values (not form-encoded name-value pairs)
```

```tcl
# Requires: NETWORK
# POST raw data with custom HTTP method
set response [uri upload -inline -raw -method PATCH \
    -data {48 49 50} -- https://example.com/resource/1]
```

```tcl
# Requires: NETWORK
# Asynchronous upload with callback
uri upload -inline -callback {myUploadHandler} \
    -data {field1 data1} -- https://example.com/submit
;# myUploadHandler is called when upload completes
;# Note: -trusted cannot be used with -callback
```

```tcl
# Requires: NETWORK
# Upload with custom WebClient configuration
set script [object create String {
  if {[getStringFromObjectHandle methodName] eq "GetWebRequest"} then {
    webRequest KeepAlive false
    webRequest Timeout 30000
    webRequest UserAgent MyApp/1.0
  }
}]
set response [uri upload -timeouttype network -inline \
    -webclientdata $script -data {key value} -- $uri]
```

##### Inline Mode Override

```tcl
# Requires: NETWORK
# Force file mode on get (override default inline behavior)
uri get -noinline https://example.com/data.json /tmp/data.json
;# Saves to file instead of returning inline

# Force inline mode on download (override default file behavior)
set data [uri download -inline -- https://example.com/data.json]
;# Returns content instead of saving to file
```

#### Network Utilities

```tcl
# Ping host
uri ping example.com 5000  ;# 5 second timeout
```

```tcl
# Get network time
uri time                           ;# Returns current time from network source
```

```tcl
# Check/set offline mode
uri offline                        ;# Query current mode
uri offline true                   ;# Disable network operations
```

```tcl
# Security and update information
uri security                       ;# Returns TLS/security settings info
uri softwareupdates                ;# Returns update trust status
# uri softwareupdates true         ;# Enable built-in update keys
# uri softwareupdates false        ;# Disable built-in update keys
```

---

## XML Examples

<a id="ex-xml"></a>
### xml

#### Serialization

```tcl
# Serialize .NET object to XML
set xmlStr [xml serialize MyNamespace.Person $personObj]
```

```tcl
# Deserialize XML to .NET object
set person [xml deserialize MyNamespace.Person $xmlStr]
```

#### Iteration

```tcl
# Iterate over XML elements
set xmlData <items><item>A</item><item>B</item></items>
xml foreach node $xmlData {
  puts [appendArgs "Element: " $node]
}
```

#### Validation

```tcl
# Validate XML against XSD schema
set schema {<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="root" type="xs:string"/>
</xs:schema>}
set doc {<root>Hello</root>}
xml validate $schema $doc   ;# Returns: 1 if valid
```

---

<a id="tcl-examples"></a>

## Tcl Integration Examples

<a id="ex-tcl"></a>
### tcl

> For a deep-dive on native Tcl integration internals, command bridging, function pointer marshalling, and library discovery, see [`tcl.md`](tcl.md). For the reverse direction (Tcl loading Eagle), see [`garuda.md`](garuda.md).

#### Loading and Unloading

```tcl
# Load native Tcl library
tcl load
tcl load /usr/lib/libtcl8.6.so    ;# With specific path
```

```tcl
# Unload Tcl library
tcl unload
```

#### Availability and Discovery

```tcl
# Check without loading
tcl available                         ;# Returns: 1 if Tcl is available
tcl find                              ;# Find Tcl installations
tcl find /usr/local/lib 8.6*          ;# Search specific path and pattern
tcl select                            ;# Select a Tcl installation
```

```tcl
# Tcl build and module information
tcl build                              ;# Returns Tcl build info
tcl module                             ;# Returns loaded module info
tcl module true                        ;# Returns full module info
```

#### Creating and Managing Interpreters

```tcl
# Create and use Tcl interpreter
tcl load
set interp [tcl create]
tcl exists $interp                    ;# Returns: 1
tcl ready $interp                     ;# Returns: 1 if ready
```

```tcl
# Evaluate code in Tcl
tcl eval $interp {
  proc greet {name} { return "Hello from Tcl, ${name}!" }
}
set greeting [tcl eval $interp {greet Eagle}]
;# greeting is "Hello from Tcl, Eagle!"
```

```tcl
# Expression and substitution in Tcl
tcl expr $interp {2 + 2}              ;# Returns: 4
tcl subst $interp {Value: $myVar}
```

```tcl
# Source a file in Tcl
tcl source $interp tclscript.tcl
```

```tcl
# Get last result
tcl result $interp
```

```tcl
# List interpreters
tcl interps                            ;# List all Tcl interpreters
tcl primary                            ;# Returns primary interpreter handle
tcl active $interp                     ;# Get/set active interpreter
```

```tcl
# Reference counting
tcl preserve $interp                   ;# Increment ref count
tcl release $interp                    ;# Decrement ref count
```

```tcl
# Delete interpreter
tcl delete $interp
```

#### Variable Access

```tcl
# Get/set variables in Tcl interpreter
tcl set $interp myVar Hello
set val [tcl set $interp myVar]
tcl unset $interp myVar
```

#### Command Bridging

```tcl
# Create bridge: Eagle -> Tcl
tcl command create eagleCmd $interp tclCmd
tcl command exists $interp tclCmd    ;# Returns: 1
tcl command list                     ;# List all bridges
tcl command list my*                 ;# List matching bridges
tcl command delete $interp tclCmd    ;# Remove bridge
```

#### Execution Control

```tcl
# Cancel Tcl execution
tcl cancel $interp "Canceling execution"
tcl canceled $interp                  ;# Returns: 1 if canceled
tcl resetcancel $interp               ;# Reset cancel state
```

```tcl
# Queue script for later execution
tcl queue $interp {puts "Deferred Tcl script"}
```

#### Type and Thread Info

```tcl
# Check completeness of Tcl command
tcl complete "set x {incomplete"       ;# Returns: 0
tcl complete "set x 1"                 ;# Returns: 1
```

```tcl
# Type conversion and listing
tcl convert $interp 42 int
tcl types $interp                      ;# List available Tcl types
```

```tcl
# Thread and version info
tcl threads                            ;# List Tcl threads
tcl versionrange                       ;# Supported Tcl version range
tcl errorline $interp                  ;# Get error line number
tcl exceptions                         ;# Get/set exception handling
```

---

<a id="expression-examples"></a>

## Expression Evaluation Examples

<a id="ex-expr"></a>
### expr

```tcl
# Basic arithmetic
expr {2 + 3}            ;# Returns: 5
expr {10 / 3}           ;# Returns: 3 (integer division)
expr {10.0 / 3}         ;# Returns: 3.3333333333333335
expr {10 % 3}           ;# Returns: 1
expr {2 ** 10}          ;# Returns: 1024
```

```tcl
# Comparison operators
expr {5 > 3}            ;# Returns: 1
expr {5 == 5}           ;# Returns: 1
expr {5 != 3}           ;# Returns: 1
```

```tcl
# String comparison in expressions
expr {"hello" eq "hello"}    ;# Returns: 1
expr {"abc" lt "def"}        ;# Returns: 1
```

```tcl
# Logical operators
expr {1 && 0}           ;# Returns: 0
expr {1 || 0}           ;# Returns: 1
expr {!0}               ;# Returns: 1
```

```tcl
# Eagle extension — logical XOR and implication
expr {1 ^^ 0}           ;# Returns: 1 (XOR)
expr {1 ^^ 1}           ;# Returns: 0
expr {1 -> 0}           ;# Returns: 0 (implication)
expr {0 -> 1}           ;# Returns: 1
```

```tcl
# Bitwise operators
expr {0xFF & 0x0F}      ;# Returns: 15
expr {0x0F | 0xF0}      ;# Returns: 255
expr {0xFF ^ 0x0F}      ;# Returns: 240
expr {~0}               ;# Returns: -1
```

```tcl
# Shift operators
expr {1 << 4}           ;# Returns: 16
expr {256 >> 4}         ;# Returns: 16
```

```tcl
# Eagle extension — rotate operators
expr {1 <<< 31}         ;# Left rotate
expr {1 >>> 1}          ;# Right rotate
```

```tcl
# Ternary conditional
set x 5
expr {$x > 0 ? "positive" : "non-positive"}
;# Returns: positive
```

```tcl
# List membership
expr {"b" in {a b c}}   ;# Returns: 1
expr {"d" ni {a b c}}   ;# Returns: 1
```

```tcl
# Eagle extension — variable assignment in expression
expr {"result" := 42}
;# Returns: 42, sets variable 'result' to 42
```

```tcl
# Function calls
expr {sqrt(144)}        ;# Returns: 12.0
expr {abs(-5)}          ;# Returns: 5
expr {max(3, 7, 1)}     ;# Returns: 7
expr {min(3, 7, 1)}     ;# Returns: 1
```

```tcl
# Nested expressions
expr {int(sqrt(pow(3, 2) + pow(4, 2)))}
;# Returns: 5 (hypotenuse of 3-4-5 triangle)
```

---

<a id="ex-fpclassify"></a>
### fpclassify

```tcl
fpclassify 1.0               ;# Returns: normal
fpclassify 0.0               ;# Returns: zero
fpclassify [expr {1.0/0}]    ;# Returns: infinite
fpclassify NaN                ;# Returns: nan
```

---

## Mathematical Function Examples

<a id="math-function-examples"></a>

### Trigonometric Functions

```tcl
expr {sin(0)}                 ;# Returns: 0.0
expr {cos(0)}                 ;# Returns: 1.0
expr {tan(0)}                 ;# Returns: 0.0
expr {asin(1.0)}              ;# Returns: 1.5707963... (pi/2)
expr {acos(0.0)}              ;# Returns: 1.5707963... (pi/2)
expr {atan(1.0)}              ;# Returns: 0.7853981... (pi/4)
expr {atan2(1.0, 1.0)}        ;# Returns: 0.7853981... (pi/4)
```

```tcl
# Hyperbolic functions
expr {sinh(0)}                ;# Returns: 0.0
expr {cosh(0)}                ;# Returns: 1.0
expr {tanh(0)}                ;# Returns: 0.0
```

### Logarithmic and Exponential Functions

```tcl
expr {exp(1)}                 ;# Returns: 2.71828... (e)
expr {log(exp(1))}            ;# Returns: 1.0
expr {log10(1000)}            ;# Returns: 3.0
expr {pow(2, 10)}             ;# Returns: 1024.0
expr {sqrt(144)}              ;# Returns: 12.0
```

```tcl
# Eagle extensions
expr {log2(1024)}             ;# Returns: 10.0
expr {logx(81, 3)}            ;# Returns: 4.0
```

### Rounding Functions

```tcl
expr {ceil(3.2)}              ;# Returns: 4.0
expr {floor(3.8)}             ;# Returns: 3.0
expr {round(3.5)}             ;# Returns: 4
```

```tcl
# Eagle extensions
expr {round2(3.14159, 2)}     ;# Returns: 3.14
expr {truncate(3.9)}          ;# Returns: 3.0
```

### Component Functions

```tcl
expr {abs(-42)}               ;# Returns: 42
expr {fmod(10.5, 3.0)}        ;# Returns: 1.5
expr {hypot(3.0, 4.0)}        ;# Returns: 5.0
```

```tcl
# Eagle extension
expr {sign(-42)}              ;# Returns: -1
expr {sign(0)}                ;# Returns: 0
expr {sign(42)}               ;# Returns: 1
```

### Aggregate Functions

```tcl
expr {max(1, 5, 3)}           ;# Returns: 5
expr {min(1, 5, 3)}           ;# Returns: 1
```

### Indicator Functions (Eagle extensions)

```tcl
expr {isnan(0.0/0.0)}         ;# Returns: 1
expr {isinf(1.0/0.0)}         ;# Returns: 1
expr {isfinite(3.14)}         ;# Returns: 1
expr {isnormal(3.14)}         ;# Returns: 1
```

### Random Number Functions

```tcl
expr {rand()}                 ;# Returns: random float in [0, 1)
expr {int(rand() * 100)}      ;# Random integer 0-99
```

```tcl
# Eagle extensions
expr {random()}               ;# Cryptographic random 64-bit integer
```

### Conversion Functions

```tcl
expr {int(3.9)}               ;# Returns: 3
expr {double(42)}             ;# Returns: 42.0
expr {wide(42)}               ;# Returns: 42 (64-bit)
expr {bool(1)}                ;# Returns: true
```

### Constants

```tcl
expr {pi()}                   ;# Returns: 3.14159265358979...
expr {e()}                    ;# Returns: 2.71828182845904...
```

```tcl
# Eagle extension
expr {epsilon()}              ;# Returns: smallest eps where 1.0 + eps != 1.0
```

### Type Introspection (Eagle extension)

```tcl
expr {typeof(42)}             ;# Returns type name of the value
```

---

## Expression Operator Examples

<a id="operator-examples"></a>

### Arithmetic

```tcl
expr {5 + 3}     ;# Returns: 8
expr {5 - 3}     ;# Returns: 2
expr {5 * 3}     ;# Returns: 15
expr {15 / 4}    ;# Returns: 3 (integer division)
expr {15 % 4}    ;# Returns: 3
expr {2 ** 8}    ;# Returns: 256
```

### Comparison

```tcl
expr {3 == 3}    ;# Returns: 1
expr {3 != 4}    ;# Returns: 1
expr {3 < 5}     ;# Returns: 1
expr {5 > 3}     ;# Returns: 1
expr {3 <= 3}    ;# Returns: 1
expr {3 >= 5}    ;# Returns: 0
```

### String Comparison

```tcl
expr {"abc" eq "abc"}  ;# Returns: 1
expr {"abc" ne "def"}  ;# Returns: 1
expr {"abc" lt "def"}  ;# Returns: 1
expr {"def" gt "abc"}  ;# Returns: 1
expr {"abc" le "abc"}  ;# Returns: 1
expr {"abc" ge "def"}  ;# Returns: 0
```

### Logical

```tcl
expr {!0}            ;# Returns: 1
expr {1 && 1}        ;# Returns: 1
expr {0 || 1}        ;# Returns: 1
```

```tcl
# Eagle extensions
expr {1 ^^ 0}       ;# Returns: 1 (XOR)
expr {1 -> 1}        ;# Returns: 1 (implication: if P then Q)
expr {1 <-> 1}       ;# Returns: 1 (equivalence: P iff Q)
```

### Bitwise

```tcl
expr {~0xFF}         ;# Returns: -256
expr {0xF0 & 0xFF}   ;# Returns: 240
expr {0x0F | 0xF0}   ;# Returns: 255
expr {0xFF ^ 0x0F}   ;# Returns: 240
```

### Shift and Rotate

```tcl
expr {1 << 8}        ;# Returns: 256
expr {256 >> 4}      ;# Returns: 16
```

```tcl
# Eagle extensions — rotate
expr {1 <<< 31}      ;# Left rotate
expr {1 >>> 1}       ;# Right rotate
```

### List Membership

```tcl
expr {"x" in {a b c x y z}}   ;# Returns: 1
expr {"q" ni {a b c}}         ;# Returns: 1
```

### Conditional (Ternary)

```tcl
set age 20
expr {$age >= 18 ? "adult" : "minor"}
;# Returns: adult
```

---

<a id="time-examples"></a>

## Time and Clock Examples

<a id="ex-clock"></a>
> **See also**: [`clock.md`](clock.md) — Deep-dive analysis covering format string translation, custom epochs, high-resolution timing, ISO 8601 modes, build numbering, duration calculation, and all 15 sub-commands.

### clock

#### Getting Current Time

```tcl
set secs [clock seconds]            ;# Seconds since epoch
set ms [clock milliseconds]         ;# Milliseconds since epoch
set us [clock microseconds]         ;# Microseconds since epoch
```

```tcl
# High-resolution timer
set ticks [clock clicks]
set ticksMs [clock clicks -milliseconds]
```

```tcl
# Eagle extension — high-resolution ticks
set ticks [clock now]              ;# Returns DateTime.Ticks (long integer)
set utcTicks [clock now -gmt true] ;# UTC DateTime.Ticks
```

#### Formatting Time

```tcl
set now [clock seconds]
clock format $now -format "%Y-%m-%d %H:%M:%S"
;# Returns: e.g., 2024-01-15 14:30:00
```

```tcl
clock format $now -format "%A, %B %d, %Y"
;# Returns: e.g., Monday, January 15, 2024
```

```tcl
# UTC time
clock format $now -gmt true -format "%H:%M UTC"
```

```tcl
# Just the date
clock format $now -format "%Y-%m-%d"
```

```tcl
# 12-hour format with AM/PM
clock format $now -format "%I:%M %p"
```

#### Parsing Time

```tcl
# Parse ISO-style date
clock scan 2024-01-15
```

```tcl
# Parse relative expressions
clock scan tomorrow
clock scan "+1 week" -base [clock seconds]
```

#### Validation and Date Queries (Eagle extensions)

```tcl
# Validate date strings
clock isvalid 2024-01-15    ;# Returns: 1
clock isvalid not-a-date    ;# Returns: 0
```

```tcl
# Days in a month
clock monthdays 2             ;# Returns: 28 or 29 (February)
clock monthdays 12            ;# Returns: 31
```

```tcl
# Day-related information
clock days 2024-01-15
```

```tcl
# Duration between two dates
clock duration 2024-01-01 2024-12-31
```

```tcl
# Windows FILETIME conversion
clock filetime $fileTimeValue
```

#### Performance Timing (Eagle extension)

```tcl
# High-resolution profiling
set start [clock start]
# ... code to measure ...
set elapsed [clock stop $start]
```

---

<a id="ex-time"></a>
### time

```tcl
# Benchmark a single operation
time {expr {sqrt(2.0)}} 10000
;# Returns: "X.X microseconds per iteration"
```

```tcl
# Benchmark list sort
set data [lrepeat 100 a b c d e]
time {lsort $data} 1000
```

```tcl
# Compare two implementations
set list {5 3 1 4 2}
puts [appendArgs "lsort: " [time {lsort -integer $list} 10000]]
```

---

<a id="event-examples"></a>

## Event Management Examples

<a id="ex-after"></a>
### after

```tcl
# Synchronous sleep (1 second)
after 1000
```

```tcl
# Schedule callback
set id [after 5000 {puts "Timer fired!"}]
```

```tcl
# Schedule idle callback
after idle {puts "Idle processing"}
```

```tcl
# Cancel scheduled event
set id [after 5000 {puts Hello}]
after cancel $id
```

```tcl
# List pending events
set pending [after info]
```

```tcl
# Eagle extension — cancel all events
after clear
```

```tcl
# Eagle extension — event queue management
after active            ;# Returns: 1 or 0 (events pending?)
after counts            ;# Returns event statistics
after dump              ;# Dump event queue for debugging
after enable            ;# Query event processing state
after enable true       ;# Enable event processing
after flags             ;# Get event processing flags
after flags SomeFlag    ;# Set event processing flags
```

---

<a id="ex-callback"></a>
### callback

```tcl
# Eagle extension — callback queue
callback enqueue set x 1
callback enqueue puts "deferred message"
callback count           ;# Returns: 2
callback list            ;# Returns: {set puts}
```

```tcl
# Execute all queued callbacks
callback execute         ;# Runs both, empties queue
callback count           ;# Returns: 0
```

```tcl
# Clear without executing
callback enqueue set y 2
callback clear
callback count           ;# Returns: 0
```

---

<a id="ex-update"></a>
### update

```tcl
# Process pending events
after 0 {set done 1}
update
# $done is now 1 (the after-0 event fired)
```

```tcl
# Process only idle tasks
update idletasks
```

---

<a id="ex-vwait"></a>
### vwait

```tcl
# Wait for variable change
after 1000 {set result completed}
vwait result
;# result is completed (waited ~1 second)
```

```tcl
# Eagle extension — wait with timeout
vwait -timeout 5000 result
```

### Vwait with Timeout and Event Flags

```tcl
# Wait for a variable change with a 5-second timeout
after 3000 {set done "completed"}

# This will return after 3 seconds when $done is set
vwait -timeout 5000 done
puts $done  ;# completed

# Wait with timeout that expires (no one sets the variable)
vwait -timeout 1000 -nocomplain neverSet
# Returns after 1 second without error due to -nocomplain
```

### Vwait with Locked Script

```tcl
# Atomically read and reset a shared variable
vwait -locked {
    set snapshot $sharedData
    set sharedData ""
} sharedData
```

---

## Introspection Examples

> **See also:** [`info.md`](info.md) — deep-dive analysis of the `info` command with additional examples covering 85 sub-commands, safe interpreter filtering, obfuscated procedure protection, .NET reflection, and engine metadata introspection.

<a id="ex-info"></a>
### info

#### Procedure Introspection

```tcl
proc greet {name {greeting Hello}} {
  return [appendArgs $greeting ", " $name !]
}
info args greet              ;# Returns: {name greeting}
info args greet true         ;# Returns: {name {}} {greeting Hello}
info body greet              ;# Returns the procedure body
info default greet greeting defVar
;# defVar is "Hello", returns 1
```

```tcl
info procs *greet*           ;# Returns: greet
```

```tcl
# Procedures in the current namespace
namespace eval ::myns {
  proc helper {} { return 1 }
}
info nprocs                  ;# Procs with NamedArguments flag
```

```tcl
# Source location of a procedure
info source greet            ;# Returns: fileName (where proc was defined)
info source greet true       ;# Returns full path info
```

#### Variable Introspection

```tcl
set x 42
info exists x                ;# Returns: 1
info exists nosuch           ;# Returns: 0
info globals *path*          ;# Globals matching pattern
```

```tcl
proc example {} {
  set local1 a
  set local2 b
  return [info locals]
}
example
;# Returns: {local1 local2}
```

```tcl
# All visible variables (locals + globals)
proc showVars {} {
  set myLocal 1
  info vars               ;# Returns: locals and visible globals
}
```

```tcl
# System variables
info sysvars                ;# Returns: system-defined variables
```

```tcl
# Variable links (upvar tracking)
proc outer {} {
  set data hello
  inner data
}
proc inner {varName} {
  upvar 1 $varName local
  info linkedname local   ;# Returns: data
}
```

```tcl
# Variable link information
info varlinks               ;# Returns info about all variable links
```

#### Command Introspection

```tcl
info commands string*        ;# Returns: string
info commands *puts*         ;# Returns: puts
info cmdtype puts            ;# Returns: native
info cmdtype greet           ;# Returns: proc (if greet is a proc)
info complete {set x 1}     ;# Returns: 1
info complete "set x {"     ;# Returns: 0 (quotes needed: unclosed brace)
```

```tcl
# Command execution count
info cmdcount               ;# Returns: total commands executed
```

```tcl
# List sub-commands of an ensemble
info subcommands string      ;# Returns: compare concat equal first ...
info subcommands array       ;# Returns: copy default exists for ...
```

```tcl
# Syntax help for a command
info syntax string           ;# Returns syntax description
info syntax lsort            ;# Returns syntax description
```

```tcl
# List undefined variables (declared but not yet set)
info undefined               ;# Returns: list of undefined variables
```

#### Call Stack

```tcl
proc inner {} {
  puts [appendArgs "Level: " [info level]]
  puts [appendArgs "Caller: " [info level 1]]
  return [info level]
}
proc outer {} { inner }
# At global level:
info level                   ;# Returns: 0
```

```tcl
# Unique level identifier
proc showLevelId {} {
  info levelid             ;# Returns unique ID for this stack level
}
```

```tcl
# Execution frame information (TIP #280 — not fully implemented)
# info frame                 ;# Not available in current builds
```

#### Script and Interpreter

```tcl
info script                  ;# Returns current script file path
info argv                    ;# Returns command-line arguments
info cmdline                 ;# Returns full command line string
info interactive             ;# Returns: 1 (interactive) or 0
info library                 ;# Returns Eagle library directory path
info context                 ;# Returns current execution context info
# Requires: NATIVE, WINDOWS
info lastinput               ;# Returns tick count of last input
```

#### Environment and System

```tcl
info os                      ;# Returns OS info (e.g., "Windows NT 10.0")
info hostname                ;# Returns hostname
info user                    ;# Returns username
info pid                     ;# Returns process ID
info processors              ;# Returns CPU count (e.g., 8)
```

```tcl
# Administrative privilege check
# Requires: NATIVE
info administrator           ;# Returns: 1 if admin/root, 0 otherwise
```

```tcl
# Parent process and previous PID
info ppid                    ;# Returns parent process ID
info previouspid             ;# Returns previous PID (fork detection)
```

```tcl
# Thread IDs
info tid                     ;# Returns system thread ID
info tid true                ;# Returns native OS thread ID
info ptid                    ;# Returns primary thread ID
```

```tcl
# Application paths
info base                    ;# Returns application base directory
info binary                  ;# Returns Eagle binary path
info nameofexecutable        ;# Returns full executable path
```

```tcl
# Platform extensions
info programextension        ;# Returns: ".exe" on Windows, "" on Unix
info sharedlibextension      ;# Returns: ".dll", ".so", or ".dylib"
```

```tcl
# Other system info
info shelllibrary            ;# Returns shell library path
info newline                 ;# Returns platform newline ("\r\n" or "\n")
info whitespace              ;# Returns whitespace chars recognized by parser
```

```tcl
# Path queries by type
info path temp               ;# Returns temp directory
info path home               ;# Returns home directory
```

#### .NET/CLR

```tcl
info patchlevel              ;# Returns Eagle version (e.g., "1.0.0.0")
info tclversion              ;# Returns Tcl compatibility version
```

```tcl
# CLR and framework info
info clr                     ;# Alias for info framework
info framework               ;# Returns .NET Framework version
info frameworkextra           ;# Returns additional framework details
info runtime                 ;# Returns runtime info (Mono, .NET Core, etc.)
info runtimeversion           ;# Returns runtime version string
info runtimeversion true      ;# With refresh from runtime
```

```tcl
# Application domain
info appdomain               ;# Returns current AppDomain name
```

```tcl
# Assembly information
info assembly                ;# Returns loaded assembly info
info assembly true           ;# Returns entry assembly info
```

#### Engine and Version

```tcl
info engine                  ;# Returns Eagle engine information
info engine Version          ;# Returns specific attribute
info setup                   ;# Returns setup/configuration info
info setup true              ;# Returns verbose setup info
```

#### Objects, Types, and Functions

```tcl
info objects *               ;# List all opaque object handles
info delegates *             ;# List delegate objects
info ensembles               ;# List ensemble commands
```

```tcl
# Expression functions and operators
info functions               ;# Returns: abs acos asin atan ...
info operators               ;# Returns: + - * / == != ...
info operands +              ;# Returns operand count for + operator
```

```tcl
info bindertypes             ;# List available binder types
info callbacks               ;# List registered callbacks
info policies                ;# List security policies
```

#### Channels and Connections

```tcl
info channels                ;# Returns: stdin stdout stderr ...
info connections             ;# List database connections
info transactions            ;# List active database transactions
```

#### Interpreter Management

```tcl
info interps                 ;# List interpreters
info interps * true          ;# List all interpreters
info loaded                  ;# List loaded plugins
info modules                 ;# List loaded modules
info externals               ;# Returns externals directory path
```

```tcl
# Plugin information
info plugin MyPlugin         ;# Info about specific plugin
info pluginflags MyPlugin    ;# Plugin flags
```

#### Culture

```tcl
info culture                 ;# Current culture info
# info culture en-US        ;# Set interpreter culture
info cultures *en*           ;# Cultures matching pattern
```

#### Identifier and Decision

```tcl
info identifier myCmd        ;# Identifier info
info decision                ;# Type decision info
```

#### Windows-Specific

```tcl
# Windows only
info windows                 ;# List windows
info hwnd $handle            ;# Window handle info
info windowtext $handle      ;# Window title text
```

#### Activity Tracking

```tcl
info active                  ;# List active interpreters
```

---

<a id="ex-version"></a>
### version

```tcl
# Eagle extension
puts [version]               ;# e.g., "1.0.0.0"
```

```tcl
# Version with additional flags
version Default            ;# Base version only
```

---

<a id="engine-examples"></a>

## Engine Operation Examples

<a id="ex-eval"></a>
### eval

```tcl
# Dynamic command execution
set cmd puts
set msg Hello
eval $cmd [list $msg]
;# Prints: Hello
```

```tcl
# Build command safely with [list]
set args {a b c}
eval lindex [list $args] 1
;# Returns: b
```

```tcl
# Evaluate multi-command script
eval {
  set x 10
  set y 20
  expr {$x + $y}
}
;# Returns: 30
```

---

<a id="ex-invoke"></a>
### invoke

```tcl
# Eagle extension — invoke at global level
invoke #0 set globalVar value
```

```tcl
# Invoke at parent frame
proc foo {} {
  invoke 1 info level
}
```

---

<a id="ex-source"></a>
### source

```tcl
# Source a script file
source config.eagle
```

```tcl
# Source with explicit encoding
source -encoding utf-8 unicode_script.eagle
```

```tcl
# Source with timing information
source -time true benchmark.eagle
```

```tcl
# Source a script bundle database
# Requires: DATA
source myScripts.db
```

```tcl
# Source an encrypted bundle
# Requires: DATA
source -bundle true -password $key secure.db
```

```tcl
# Source with bundle flags
# Requires: DATA
source -bundleflags {StopOnError|RequireKeyRing} production.db
```

---

<a id="ex-subst"></a>
### subst

```tcl
set name World
subst {Hello, $name!}
;# Returns: Hello, World!
```

```tcl
# Command substitution
subst {Value: [expr {2 + 2}]}
;# Returns: Value: 4
```

```tcl
# Disable variable substitution
subst -novariables {$name}
;# Returns: $name
```

```tcl
# Disable command substitution
subst -nocommands {Value: [expr {2+2}]}
;# Returns: Value: [expr {2+2}]
```

```tcl
# Backslash processing only
subst -novariables -nocommands {Tab:\tNewline:\n}
;# Returns: Tab:(tab)Newline:(newline)
```

---

## Native Environment Examples

<a id="ex-exec"></a>
### exec

> For a detailed analysis of argument processing, quoting/escaping, and differences from native Tcl, see [`exec.md`](exec.md).

```tcl
# Simple command execution
# set output [exec ls -la]
```

```tcl
# Capture exit code
# exec -exitcode code myprogram
# puts "Exit code: $code"
```

```tcl
# Background execution
# exec -background myprogram
```

```tcl
# With timeout
# exec -timeout 5000 slowprogram
```

```tcl
# Specify working directory
# exec -directory /tmp ls -la
```

```tcl
# Capture stdout and stderr separately
# exec -stdout out -stderr err myprogram
# puts "Output: $out"
# puts "Errors: $err"
```

```tcl
# Ignore stderr
# set output [exec -ignorestderr myprogram]
```

```tcl
# Provide stdin
# set input "line1\nline2"
# exec -stdin input grep pattern
```

```tcl
# Shell execution (open URL in browser)
# exec -shell https://example.com
```

```tcl
# Hidden window (Windows)
# exec -windowstyle Hidden cmd /c "echo test"
```

```tcl
# Error handling
# if {[catch {exec -exitcode code program} result]} {
#     puts "Error: $result"
# }
```

---

<a id="ex-exit"></a>
### exit

```tcl
# exit              ;# Exit with code 0
# exit 1            ;# Exit with error code
# exit -force 2     ;# Force immediate exit
```

---

<a id="ex-kill"></a>
### kill

```tcl
# Eagle extension — kill process by PID
# kill 1234                     ;# Graceful termination
# kill -force 1234              ;# Force kill
```

```tcl
# Kill by name pattern
# kill notepad                  ;# Close first notepad
# kill -all notepad             ;# Close all notepad processes
# kill -all -force notepad*     ;# Force kill all matching
```

```tcl
# Dry run
# kill -whatIf -all chrome*     ;# Show what would be killed
```

---

<a id="ex-library"></a>
### library

> **Deep-dive**: For comprehensive analysis of the library command's internals, dynamic delegate creation, module lifecycle, and marshalling infrastructure, see [`library.md`](library.md).

```tcl
# Eagle extension — P/Invoke native library calls
# Requires: NATIVE, LIBRARY

# Complete Windows example:
# set kernel32 [library load kernel32.dll]
#
# set getConsoleWindow [library declare \
#     -functionname GetConsoleWindow \
#     -returntype IntPtr \
#     -module $kernel32]
#
# set hwnd [library call $getConsoleWindow]
# puts "Console window: $hwnd"
#
# library info module $kernel32
# library info delegate $getConsoleWindow
#
# library undeclare $getConsoleWindow
# library unload $kernel32
```

```tcl
# Check architecture compatibility
# Requires: NATIVE, TCL
# library matcharchitecture mylib.dll    ;# Returns: True or False
```

```tcl
# Declare with parameters
# set delegate [library declare \
#     -functionname GetStdHandle \
#     -returntype IntPtr \
#     -parametertypes {int32} \
#     -module $module]
# set handle [library call $delegate -11]
```

---

<a id="ex-pid"></a>
### pid

```tcl
puts [appendArgs "My PID: " [pid]]
```

---

## Managed Environment Examples

  > **See also:** [`host.md`](host.md) for a deep-dive analysis of the host lifecycle safety interlocks, Windows-native screen buffer management, color theming, box drawing, and practical patterns.

<a id="ex-host"></a>
### host

#### Screen Control

```tcl
host clear                           ;# Clear console screen
host title "My Application"          ;# Set window title
set title [host title]               ;# Get current title
set pos [host position]              ;# Get cursor position {col row}
host position -x 10 -y 5            ;# Set cursor position
host size                            ;# Get console window size
host size -width 120 -height 40     ;# Set console size
```

#### Colors and Styles

```tcl
host color -foreground Green -background Black
host color                           ;# Get current colors
host namedcolor -name Red            ;# Get named color value
```

```tcl
# Box and output styles
host boxstyle                        ;# Get current box style
host boxstyle 1                      ;# Set box drawing style (integer index)
host outputstyle                     ;# Get output style
host outputstyle Normal              ;# Set output style
```

#### Input

```tcl
host readchar                        ;# Read single character
host readkey                         ;# Read key press (with echo)
host readkey true                    ;# Read key without echo (intercept)
set name [host readline]             ;# Read line of input
host readline true                   ;# Allow null/empty input
host pause                           ;# Press any key...
```

#### Output

```tcl
host write Processing... false        ;# No newline
host write " Done!\n"
host writebox "Important Message"    ;# Write text in decorative box
host beep                            ;# Sound alert
host beep -frequency 800 -duration 200  ;# Custom beep
```

#### Screen Buffers

```tcl
# Requires: NATIVE, WINDOWS
set screen [host screen create]      ;# Create new screen
host screen exists $screen           ;# Check if screen exists
host screen list                     ;# List all screens
host screen push $screen             ;# Activate it
host screen active                   ;# Get active screen
host screen peek                     ;# Peek at top of stack
host write "On secondary screen"
host screen pop                      ;# Return to previous
host screen delete $screen
```

#### Channel Management

```tcl
host inchan                          ;# Get input channel
host outchan                         ;# Get output channel
host errchan                         ;# Get error channel
host redirected Output               ;# Check if stdout redirected
host mode Output                     ;# Get channel mode (ChannelType)
host echo false                      ;# Disable input echo (for passwords)
```

#### Host Lifecycle

```tcl
host open                            ;# Open host for interaction
host isopen                          ;# Returns: 1 if open
host close                           ;# Close host
```

```tcl
host cancel                          ;# Cancel current operation
host exit                            ;# Exit host
host reset                           ;# Reset to default state
```

```tcl
host flags                           ;# Returns capability flags
host query                           ;# Query host information
host result 0 OK                     ;# Set host result
host sleep 1000                      ;# Sleep for 1 second
```

```tcl
# Font settings
# Requires: CONSOLE, NATIVE, WINDOWS
host font                            ;# Get current font info
host font -facename Consolas -fontsize 12 ;# Set console font
```

---

<a id="ex-load"></a>
### load

> **See also**: [`load.md`](load.md) for a deep-dive analysis of the plugin loading infrastructure, security verification chain, AppDomain isolation, built-in and enterprise plugins, and practical loading patterns.

```tcl
# Load a compiled extension
load myextension.dll MyPackage
```

---

<a id="ex-unload"></a>
### unload

> **See also**: [`load.md`](load.md) for a deep-dive analysis of the unloading pipeline, plugin matching, and all unload options.

```tcl
# Unload a previously loaded extension
unload myextension.dll MyPackage
unload -nocomplain myextension.dll
```

---

<a id="core-misc-examples"></a>

## Core and Miscellaneous Examples

<a id="ex-bgerror"></a>
### bgerror

```tcl
# Define custom background error handler
proc bgerror {message} {
  puts stderr [appendArgs "Background error: " $message]
  puts stderr [appendArgs "Stack trace: " $::errorInfo]
}
```

```tcl
# Example: error in after callback
proc bgerror {message} {
  # Log to file instead of crashing
}
after 0 {error "background failure"}
update
;# bgerror is called with "background failure"
```

---

<a id="ex-nop"></a>
### nop

```tcl
# Eagle extension — no operation
nop
;# Returns: {} (empty string)
```

```tcl
# Measure interpreter overhead
time {nop} 100000
;# Returns: microseconds per iteration for a no-op
```

---

<a id="ex-rename"></a>
### rename

```tcl
# Rename a procedure
proc myproc {} { return hello }
rename myproc my_new_proc
my_new_proc
;# Returns: hello
```

```tcl
# Delete a command
proc temp {} { return temporary }
rename temp {}
;# temp no longer exists
```

```tcl
# Wrap an existing command
rename puts _original_puts
proc puts {args} {
  set timestamp [clock format [clock seconds] \
      -format "%H:%M:%S"]
  eval _original_puts \
      [list [appendArgs \[ $timestamp \]]] $args
}
# Now all puts calls include a timestamp prefix
```

```tcl
# Prevent accidental deletion
# rename -nodelete myproc newname
```

---

## Practical Patterns

### Using Script Library Procedures

The following examples reference procedures from the Eagle script library
([`core_script_library.md`](core_script_library.md)).

#### File I/O with Library Helpers

```tcl
# Using readFile / writeFile from file1.eagle
# writeFile output.txt "Hello, World!"
# set contents [readFile output.txt]
```

#### Platform Detection

```tcl
# Using platform detection from platform.eagle
# if {[isWindows]} {
#     set pathSep ";"
# } else {
#     set pathSep :
# }

# if {[isDotNetCore]} {
#     puts "Running on .NET Core"
# }
```

#### List Utilities

```tcl
# Using filter from list.eagle
# set evens [filter {x} {expr {$x % 2 == 0}} {1 2 3 4 5 6}]
# ;# Returns: {2 4 6}
```

```tcl
# Using map from list.eagle
# set doubled [map {x} {expr {$x * 2}} {1 2 3 4 5}]
# ;# Returns: {2 4 6 8 10}
```

```tcl
# Using reduce from list.eagle
# set sum [reduce {acc x} {expr {$acc + $x}} 0 {1 2 3 4 5}]
# ;# Returns: 15
```

#### Dictionary Access

```tcl
# Using getDictionaryValue from auxiliary.eagle
# set data {name Alice age 30 city Boston}
# set name [getDictionaryValue $data name]
# ;# Returns: Alice
```

### Error Handling Patterns

```tcl
# Comprehensive error handling
proc safeOperation {args} {
  set code [catch {
    # risky operation
    set result [eval $args]
  } msg opts]

  switch $code {
    0 { return $result }
    1 {
      puts stderr [appendArgs "Error: " $msg]
      return ""
    }
    default {
      return -options $opts $msg
    }
  }
}
```

### Functional Programming Patterns

```tcl
# Higher-order function: apply a transform to each element
proc mapList {lambda data} {
  set result [list]
  foreach item $data {
    lappend result [apply $lambda $item]
  }
  return $result
}
set squares [mapList {{x} {expr {$x * $x}}} {1 2 3 4 5}]
;# Returns: {1 4 9 16 25}
```

```tcl
# Pipeline pattern using proc chaining
proc pipeline {data args} {
  set current $data
  foreach cmd $args {
    set current [eval $cmd [list $current]]
  }
  return $current
}
```

### .NET Interop Patterns

```tcl
# StringBuilder pattern (efficient string building)
set sb [object create System.Text.StringBuilder]
for {set i 0} {$i < 100} {incr i} {
  object invoke $sb AppendLine \
      [format "Line %d" $i]
}
set output [object invoke $sb ToString]
object dispose $sb
```

```tcl
# Using .NET collections
set dict [object create \
    "System.Collections.Generic.Dictionary\`2\[System.String,System.Int32\]"]
object invoke $dict Add one 1
object invoke $dict Add two 2
set count [object invoke $dict Count]
;# count is 2
object dispose $dict
```

```tcl
# File operations via .NET
set contents [object invoke System.IO.File ReadAllText config.txt]
object invoke System.IO.File WriteAllText output.txt "Hello from Eagle"
```

```tcl
# Environment access via .NET
set home [object invoke System.Environment GetFolderPath Personal]
set hostname [object invoke System.Net.Dns GetHostName]
```

### Scope-Based State Management

```tcl
# Accumulator using scope
proc createAccumulator {name} {
  scope create $name
  scope set $name total 0
}

proc accumulate {name value} {
  scope create -open -args $name
  incr total $value
  return $total
}

createAccumulator myAcc
accumulate myAcc 10    ;# Returns: 10
accumulate myAcc 20    ;# Returns: 30
accumulate myAcc 5     ;# Returns: 35
scope destroy myAcc
```

### Testing Patterns

```tcl
# Parameterized test pattern
foreach {n expected} {0 1  1 1  5 120  10 3628800} {
  test1 [appendArgs factorial- $n] \
      [appendArgs factorial( $n ") == " $expected] \
      {} {
    proc fact {n} {
      if {$n <= 1} then {return 1}
      expr {$n * [fact [expr {$n - 1}]]}
    }
    fact $n
  } $expected
}
```

```tcl
# Test with temporary files
test2 tempfile-1.1 "Write and read temp file" \
    -setup {
      set tmpDir [file temppath]
      set tmpFile [file join $tmpDir \
          [appendArgs eagle_test_ [pid] .txt]]
    } \
    -body {
      set fh [open $tmpFile w]
      puts $fh "eagle test data"
      close $fh
      set fh [open $tmpFile r]
      set data [read -nonewline $fh]
      close $fh
      return $data
    } \
    -cleanup {
      file delete -force $tmpFile
    } \
    -result "eagle test data"
```
