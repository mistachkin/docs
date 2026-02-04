# Eagle Scripting Language

This document provides a comprehensive catalog the Eagle scripting language, organized by functional category based on their ObjectGroup attributes.

## Table of Contents

- [Command Count Summary](#command-count-summary)
- [Alphabetical Command Index](#alphabetical-command-index)
- [Commands by Category](#commands-by-category)
  - [Control Flow](#control-flow)
  - [Variables](#variables)
  - [Lists](#lists)
  - [Strings](#strings)
  - [Arrays](#arrays)
  - [I/O and Channels](#io-and-channels)
  - [File System](#file-system)
  - [Procedures](#procedures)
  - [Namespaces](#namespaces)
  - [Objects (.NET Interop)](#objects-net-interop)
  - [Debugging](#debugging)
  - [Interpreter Management](#interpreter-management)
  - [Packages](#packages)
  - [Testing](#testing)
  - [Database (SQL)](#database-sql)
  - [Network and URI](#network-and-uri)
  - [XML](#xml)
  - [Tcl Integration](#tcl-integration)
  - [Expression Evaluation](#expression-evaluation)
  - [Mathematical Functions](#mathematical-functions)
  - [Expression Operators](#expression-operators)
  - [Time and Clock](#time-and-clock)
  - [Event Management](#event-management)
  - [Introspection](#introspection)
  - [Delegates and Aliases](#delegates-and-aliases)
  - [Ensemble Commands](#ensemble-commands)
  - [Engine Operations](#engine-operations)
  - [Native Environment](#native-environment)
  - [Managed Environment](#managed-environment)
  - [Core and Miscellaneous](#core-and-miscellaneous)
- [Common Option Patterns](#common-option-patterns)
- [Test Functions](#test-functions)
- [Advanced Topics and Patterns](#advanced-topics-and-patterns)
  - [Built-in Virtual Scripts](#built-in-virtual-scripts)
  - [Managed Assembly Plugin Loader Subsystem](#managed-assembly-plugin-loader-subsystem)

---

## Command Count Summary

Total Commands: **122**

Commands are organized into the following ObjectGroup categories:
- Control Flow (conditional, control, loop): 12 commands
- Variables: 10 commands
- Lists: 18 commands
- Strings: 11 commands
- Channels (I/O): 12 commands
- File System: 5 commands
- Procedures: 4 commands
- Script Environment: 5 commands
- Managed Environment: 6 commands
- Native Environment: 5 commands
- Debugging: 1 command (with 70+ sub-commands)
- Expression: 3 commands
- Time: 2 commands
- Event: 4 commands
- Introspection: 2 commands
- Network: 2 commands
- Test: 2 commands
- Other categories: ~20 commands

---

## Alphabetical Command Index

Quick reference to all Eagle commands with links to their detailed documentation.

| Command | Description | Section |
|---------|-------------|---------|
| [`after`](#cmd-after) | Execute script after delay | [Event Management](#event-management) |
| [`alias`](#cmd-alias) | Create command alias | [Delegates and Aliases](#delegates-and-aliases) |
| [`append`](#cmd-append) | Append values to variable | [Variables](#variables) |
| [`apply`](#cmd-apply) | Apply lambda expression | [Procedures](#procedures) |
| [`array`](#cmd-array) | Array operations | [Arrays](#arrays) |
| [`automatic`](#cmd-automatic) | Automatic command delegation | [Core and Miscellaneous](#core-and-miscellaneous) |
| [`bgerror`](#cmd-bgerror) | Background error handler | [Core and Miscellaneous](#core-and-miscellaneous) |
| [`break`](#cmd-break) | Break out of loop | [Control Flow](#control-flow) |
| [`callback`](#cmd-callback) | Callback management | [Event Management](#event-management) |
| [`catch`](#cmd-catch) | Catch exceptions and errors | [Control Flow](#control-flow) |
| [`cd`](#cmd-cd) | Change directory | [File System](#file-system) |
| [`clock`](#cmd-clock) | Clock and time operations | [Time and Clock](#time-and-clock) |
| [`close`](#cmd-close) | Close channel | [I/O and Channels](#io-and-channels) |
| [`concat`](#cmd-concat) | Concatenate arguments | [Strings](#strings) |
| [`continue`](#cmd-continue) | Continue to next loop iteration | [Control Flow](#control-flow) |
| [`core`](#cmd-core) | Core operations | [Core and Miscellaneous](#core-and-miscellaneous) |
| [`debug`](#cmd-debug) | Debugging operations | [Debugging](#debugging) |
| [`default`](#cmd-default) | Default operations | [Core and Miscellaneous](#core-and-miscellaneous) |
| [`delegate`](#cmd-delegate) | Delegate operations | [Delegates and Aliases](#delegates-and-aliases) |
| [`do`](#cmd-do) | Do-while loop | [Control Flow](#control-flow) |
| [`downlevel`](#cmd-downlevel) | Execute script at lower call stack level | [Control Flow](#control-flow) |
| [`encoding`](#cmd-encoding) | Character encoding operations | [Strings](#strings) |
| [`eof`](#cmd-eof) | Check for end-of-file | [I/O and Channels](#io-and-channels) |
| [`error`](#cmd-error) | Generate an error | [Control Flow](#control-flow) |
| [`eval`](#cmd-eval) | Evaluate script | [Engine Operations](#engine-operations) |
| [`exec`](#cmd-exec) | Execute external program | [Native Environment](#native-environment) |
| [`exit`](#cmd-exit) | Exit interpreter | [Native Environment](#native-environment) |
| [`expr`](#cmd-expr) | Evaluate expression | [Expression Evaluation](#expression-evaluation) |
| [`fblocked`](#cmd-fblocked) | Check if channel is blocked | [I/O and Channels](#io-and-channels) |
| [`fconfigure`](#cmd-fconfigure) | Configure channel options | [I/O and Channels](#io-and-channels) |
| [`fcopy`](#cmd-fcopy) | Copy data between channels | [I/O and Channels](#io-and-channels) |
| [`file`](#cmd-file) | File operations | [File System](#file-system) |
| [`flush`](#cmd-flush) | Flush channel buffer | [I/O and Channels](#io-and-channels) |
| [`for`](#cmd-for) | C-style for loop | [Control Flow](#control-flow) |
| [`foreach`](#cmd-foreach) | Iterate over lists | [Control Flow](#control-flow) |
| [`format`](#cmd-format) | Format string (like sprintf) | [Strings](#strings) |
| [`fpclassify`](#cmd-fpclassify) | Classify floating point number | [Expression Evaluation](#expression-evaluation) |
| [`getf`](#cmd-getf) | Get variable with flags | [Variables](#variables) |
| [`gets`](#cmd-gets) | Read line from channel | [I/O and Channels](#io-and-channels) |
| [`glob`](#cmd-glob) | Glob for files | [File System](#file-system) |
| [`global`](#cmd-global) | Declare global variables | [Variables](#variables) |
| [`guid`](#cmd-guid) | GUID/UUID operations | [Strings](#strings) |
| [`hash`](#cmd-hash) | Hashing operations | [Strings](#strings) |
| [`host`](#cmd-host) | Host operations | [Managed Environment](#managed-environment) |
| [`if`](#cmd-if) | Conditional execution | [Control Flow](#control-flow) |
| [`incr`](#cmd-incr) | Increment variable value | [Variables](#variables) |
| [`info`](#cmd-info) | Introspection operations | [Introspection](#introspection) |
| [`interp`](#cmd-interp) | Interpreter management | [Interpreter Management](#interpreter-management) |
| [`invoke`](#cmd-invoke) | Invoke command | [Engine Operations](#engine-operations) |
| [`join`](#cmd-join) | Join list elements with separator | [Strings](#strings) |
| [`kill`](#cmd-kill) | Kill process | [Native Environment](#native-environment) |
| [`lappend`](#cmd-lappend) | Append elements to list variable | [Lists](#lists) |
| [`lassign`](#cmd-lassign) | Assign list elements to variables | [Lists](#lists) |
| [`lget`](#cmd-lget) | Get element from list variable | [Lists](#lists) |
| [`library`](#cmd-library) | Native library operations | [Native Environment](#native-environment) |
| [`lindex`](#cmd-lindex) | Get list element by index | [Lists](#lists) |
| [`linsert`](#cmd-linsert) | Insert elements into list | [Lists](#lists) |
| [`list`](#cmd-list) | Create a list | [Lists](#lists) |
| [`llength`](#cmd-llength) | Get list length | [Lists](#lists) |
| [`lmap`](#cmd-lmap) | List mapping (transform list) | [Lists](#lists) |
| [`load`](#cmd-load) | Load binary plugin/extension | [Managed Environment](#managed-environment) |
| [`lrange`](#cmd-lrange) | Get range of list elements | [Lists](#lists) |
| [`lremove`](#cmd-lremove) | Remove list elements by index | [Lists](#lists) |
| [`lrepeat`](#cmd-lrepeat) | Create list by repeating values | [Lists](#lists) |
| [`lreplace`](#cmd-lreplace) | Replace list elements | [Lists](#lists) |
| [`lreverse`](#cmd-lreverse) | Reverse a list | [Lists](#lists) |
| [`lsearch`](#cmd-lsearch) | Search for element in list | [Lists](#lists) |
| [`lset`](#cmd-lset) | Set list element | [Lists](#lists) |
| [`lsort`](#cmd-lsort) | Sort a list | [Lists](#lists) |
| [`namespace`](#cmd-namespace) | Namespace operations | [Namespaces](#namespaces) |
| [`napply`](#cmd-napply) | Apply lambda with named arguments | [Procedures](#procedures) |
| [`nop`](#cmd-nop) | No operation | [Core and Miscellaneous](#core-and-miscellaneous) |
| [`nproc`](#cmd-nproc) | Create procedure with named arguments | [Procedures](#procedures) |
| [`object`](#cmd-object) | .NET object operations | [Objects (.NET Interop)](#objects-net-interop) |
| [`open`](#cmd-open) | Open file or channel | [I/O and Channels](#io-and-channels) |
| [`package`](#cmd-package) | Package management | [Packages](#packages) |
| [`parse`](#cmd-parse) | Parse scripts and expressions | [Strings](#strings) |
| [`pid`](#cmd-pid) | Get process ID | [Native Environment](#native-environment) |
| [`proc`](#cmd-proc) | Create procedure | [Procedures](#procedures) |
| [`puts`](#cmd-puts) | Write to channel | [I/O and Channels](#io-and-channels) |
| [`pwd`](#cmd-pwd) | Print working directory | [File System](#file-system) |
| [`read`](#cmd-read) | Read from channel | [I/O and Channels](#io-and-channels) |
| [`regexp`](#cmd-regexp) | Regular expression matching | [Strings](#strings) |
| [`regsub`](#cmd-regsub) | Regular expression substitution | [Strings](#strings) |
| [`rename`](#cmd-rename) | Rename command | [Core and Miscellaneous](#core-and-miscellaneous) |
| [`return`](#cmd-return) | Return from procedure or script | [Control Flow](#control-flow) |
| [`scope`](#cmd-scope) | Variable scope operations | [Variables](#variables) |
| [`seek`](#cmd-seek) | Set channel position | [I/O and Channels](#io-and-channels) |
| [`set`](#cmd-set) | Set variable value | [Variables](#variables) |
| [`setf`](#cmd-setf) | Set variable with flags | [Variables](#variables) |
| [`socket`](#cmd-socket) | Socket operations | [Network and URI](#network-and-uri) |
| [`source`](#cmd-source) | Source script file | [Engine Operations](#engine-operations) |
| [`split`](#cmd-split) | Split string into list | [Strings](#strings) |
| [`sql`](#cmd-sql) | Database operations | [Database (SQL)](#database-sql) |
| [`string`](#cmd-string) | String operations | [Strings](#strings) |
| [`subdelegate`](#cmd-subdelegate) | Sub-delegate operations | [Core and Miscellaneous](#core-and-miscellaneous) |
| [`subst`](#cmd-subst) | Perform substitutions | [Engine Operations](#engine-operations) |
| [`switch`](#cmd-switch) | Pattern matching and branching | [Control Flow](#control-flow) |
| [`tcl`](#cmd-tcl) | Tcl integration | [Tcl Integration](#tcl-integration) |
| [`tell`](#cmd-tell) | Get channel position | [I/O and Channels](#io-and-channels) |
| [`throw`](#cmd-throw) | Throw an exception | [Control Flow](#control-flow) |
| [`time`](#cmd-time) | Time script execution | [Time and Clock](#time-and-clock) |
| [`truncate`](#cmd-truncate) | Truncate channel | [I/O and Channels](#io-and-channels) |
| [`try`](#cmd-try) | Try/finally exception handling | [Control Flow](#control-flow) |
| [`unload`](#cmd-unload) | Unload binary plugin/extension | [Managed Environment](#managed-environment) |
| [`unset`](#cmd-unset) | Unset variables | [Variables](#variables) |
| [`unsetf`](#cmd-unsetf) | Unset variable with flags | [Variables](#variables) |
| [`update`](#cmd-update) | Process events | [Event Management](#event-management) |
| [`uplevel`](#cmd-uplevel) | Execute script at higher call stack level | [Control Flow](#control-flow) |
| [`upvar`](#cmd-upvar) | Link variable to upper scope | [Variables](#variables) |
| [`uri`](#cmd-uri) | URI operations | [Network and URI](#network-and-uri) |
| [`variable`](#cmd-variable) | Declare namespace variables | [Variables](#variables) |
| [`version`](#cmd-version) | Get Eagle version | [Introspection](#introspection) |
| [`vwait`](#cmd-vwait) | Wait for variable change | [Event Management](#event-management) |
| [`while`](#cmd-while) | While loop | [Control Flow](#control-flow) |
| [`xml`](#cmd-xml) | XML operations | [XML](#xml) |

---

## Commands by Category

### Control Flow

#### Conditional Commands (ObjectGroup: "conditional")

<a id="cmd-if"></a>
- **if** - Conditional execution
  - `if expr1 ?then? body1 elseif expr2 ?then? body2 elseif ... ?else? ?bodyN?`
  - Evaluates *expr1* as a boolean expression. If true, executes *body1* and returns its result. Otherwise, evaluates subsequent `elseif` expressions in order until one is true. If no expression is true and an `else` clause exists, executes its body. The `then` and `else` keywords are optional but improve readability.
  - **Returns**: The result of the executed body, or an empty string if no body was executed.
  - **Example**:
    ```tcl
    if {$x > 10} {
        puts "large"
    } elseif {$x > 5} {
        puts "medium"
    } else {
        puts "small"
    }
    ```

<a id="cmd-switch"></a>
- **switch** - Pattern matching and branching
  - `switch ?switches? string {pattern body ... ?default body?}`
  - `switch ?switches? string pattern body ... ?default body?`
  - Compares *string* against each *pattern* in order. When a match is found, executes the corresponding *body* and returns its result. The special pattern `default` matches anything and is typically used as the last pattern.
  - **Switches**:
    - `-exact` - Use exact string matching (default)
    - `-glob` - Use glob-style pattern matching (*, ?, [chars])
    - `-regexp` - Use regular expression matching
    - `-nocase` - Perform case-insensitive matching
    - `--` - Marks end of switches
  - **Fall-through**: If a body is `-`, execution falls through to the next body.
  - **Returns**: The result of the executed body, or an empty string if no pattern matched.
  - **Example**:
    ```tcl
    switch -glob $action {
        "get*" { return [getData] }
        "set*" { setData $value }
        default { error "unknown action" }
    }
    ```

#### Control Commands (ObjectGroup: "control")

<a id="cmd-break"></a>
- **break** - Break out of loop
  - `break ?string?`
  - Terminates the innermost enclosing loop (`for`, `foreach`, `while`, `do`). Control continues with the statement following the loop. If *string* is provided, it becomes the result of the loop command.
  - **Returns**: The optional *string* value, or an empty string.

<a id="cmd-catch"></a>
- **catch** - Catch exceptions and errors
  - `catch script ?resultVarName? ?optionsVarName?`
  - Executes *script* and catches any errors or exceptions that occur. This prevents errors from propagating up the call stack.
  - **Parameters**:
    - *script* - The script to execute
    - *resultVarName* - Optional variable to store the script's result (or error message if an error occurred)
    - *optionsVarName* - Optional variable to store a dictionary of return options (including `-code`, `-errorinfo`, `-errorcode`, `-level`)
  - **Returns**: An integer return code:
    - `0` (TCL_OK) - Script completed successfully
    - `1` (TCL_ERROR) - Script raised an error
    - `2` (TCL_RETURN) - Script executed a `return`
    - `3` (TCL_BREAK) - Script executed a `break`
    - `4` (TCL_CONTINUE) - Script executed a `continue`
  - **Example**:
    ```tcl
    if {[catch {open $filename r} fh]} {
        puts "Could not open file: $fh"
    } else {
        # Use $fh...
        close $fh
    }
    ```

<a id="cmd-continue"></a>
- **continue** - Continue to next loop iteration
  - `continue ?string?`
  - Skips the remainder of the current loop iteration and continues with the next iteration of the innermost enclosing loop. In a `for` loop, the *next* script is still executed.
  - **Returns**: The optional *string* value (rarely used).

<a id="cmd-downlevel"></a>
- **downlevel** - Execute script in the pre-uplevel call frame (Eagle extension)
  - `downlevel arg ?arg ...?`
  - Executes the concatenated arguments as a script in the context of the call frame that was active *prior to* the most recent `uplevel`. This is an Eagle extension that solves a problem that is otherwise quite difficult in Tcl: when you're inside an upleveled script and need to temporarily execute code back in the original (lower) context.
  - **Use case**: When a procedure uses `uplevel` to execute a script in the caller's context, code within that script may need to access variables or execute commands in the *original* procedure's context. `downlevel` provides this capability.
  - **Returns**: The result of the executed script.
  - **Example**:
    ```tcl
    proc deepdown {} {
        lappend a 1              ;# in deepdown's frame (level 1)
        uplevel 1 {
            lappend a 2          ;# in caller's frame (level 0)
            downlevel {
                lappend a 3      ;# back in deepdown's frame (level 1)
                uplevel #0 {
                    lappend a 4  ;# in global frame (level 0)
                    downlevel {
                        lappend a 5  ;# back in deepdown's frame (level 1)
                    }
                }
            }
        }
        return $a
    }
    set a [list]
    list [deepdown] $a
    # Returns: {{1 3 5} {0 2 4}}
    # {1 3 5} = deepdown's local 'a' (level 1 appends)
    # {0 2 4} = global 'a' (level 0 appends)
    ```

<a id="cmd-error"></a>
- **error** - Generate an error
  - `error ?message? ?errorInfo? ?errorCode? ?returnCode?`
  - Raises an error with the specified *message*. The error propagates up the call stack until caught by `catch` or `try`.
  - **Parameters**:
    - *message* - The error message text
    - *errorInfo* - Initial stack trace information (appended to as error propagates)
    - *errorCode* - Machine-readable error code (a list, e.g., `{POSIX ENOENT}`)
    - *returnCode* - Custom return code (Eagle extension, default is 1/TCL_ERROR)
  - **Returns**: Does not return normally; raises an error.
  - **Example**:
    ```tcl
    if {$value < 0} {
        error "value must be non-negative" "" {MYAPP INVALID_VALUE}
    }
    ```

<a id="cmd-return"></a>
- **return** - Return from procedure or script
  - `return ?options? ?string?`
  - Returns from the current procedure or sourced script with the specified value.
  - **Options**:
    - `-code code` - Return code: `ok` (0), `error` (1), `return` (2), `break` (3), `continue` (4), or an integer
    - `-errorcode code` - Set the error code (used with `-code error`)
    - `-errorinfo info` - Set the error info/stack trace
    - `-level n` - Number of levels to return through (default 1)
  - **Returns**: The *string* value, or an empty string if not specified.
  - **Example**:
    ```tcl
    proc divide {a b} {
        if {$b == 0} {
            return -code error -errorcode {ARITH DIVZERO} "division by zero"
        }
        return [expr {$a / $b}]
    }
    ```

<a id="cmd-throw"></a>
- **throw** - Throw an exception
  - `throw message ?returnCode? ?innerException?`
  - Throws an exception with the specified message. This is an Eagle extension that provides .NET-style exception handling.
  - **Parameters**:
    - *message* - The exception message
    - *returnCode* - Return code (default is error)
    - *innerException* - An inner exception object for exception chaining
  - **Returns**: Does not return normally; throws an exception.

<a id="cmd-try"></a>
- **try** - Try/finally exception handling
  - `try script ?finally script?`
  - Executes the try *script*. If a `finally` clause is provided, its script is always executed, whether or not an error occurred in the try script. The finally script runs even if the try script executes `return`, `break`, or `continue`.
  - **Returns**: The result of the try script (errors are re-raised after finally executes).
  - **Example**:
    ```tcl
    set fh [open $filename r]
    try {
        processFile $fh
    } finally {
        close $fh
    }
    ```

<a id="cmd-uplevel"></a>
- **uplevel** - Execute script at higher call stack level
  - `uplevel ?level? arg ?arg ...?`
  - Executes the concatenated arguments as a script in the context of an enclosing call frame. This allows procedures to modify variables in the caller's scope.
  - **Level specification**:
    - A positive integer *n* means *n* levels up from the current level (default is 1)
    - `#n` specifies an absolute stack level (0 is the global level)
  - **Returns**: The result of the executed script.
  - **Example**:
    ```tcl
    proc setInCaller {varName value} {
        uplevel 1 [list set $varName $value]
    }
    ```

#### Loop Commands (ObjectGroup: "loop")

<a id="cmd-do"></a>
- **do** - Do-while loop
  - `do script clause test`
  - Executes *script* at least once, then repeatedly while *test* evaluates to true. The *clause* must be the literal word `while` or `until`.
  - **Clauses**:
    - `while` - Continue looping while *test* is true
    - `until` - Continue looping until *test* is true (i.e., while *test* is false)
  - **Returns**: An empty string (or the value from `break`).
  - **Example**:
    ```tcl
    set i 0
    do {
        puts $i
        incr i
    } while {$i < 5}
    ```

<a id="cmd-for"></a>
- **for** - C-style for loop
  - `for start test next script ?end?`
  - Executes *start* once, then repeatedly executes *script* followed by *next* while *test* evaluates to true. The optional *end* script (Eagle extension) is executed when the loop terminates normally.
  - **Parameters**:
    - *start* - Initialization script (executed once before the loop)
    - *test* - Boolean expression evaluated before each iteration
    - *next* - Script executed after each iteration (even after `continue`)
    - *script* - The loop body
    - *end* - Optional cleanup script (Eagle extension)
  - **Returns**: An empty string (or the value from `break`).
  - **Example**:
    ```tcl
    for {set i 0} {$i < 10} {incr i} {
        puts "i = $i"
    }
    ```

<a id="cmd-foreach"></a>
- **foreach** - Iterate over lists
  - `foreach varList list ?varList list ...? script`
  - Iterates over one or more lists, assigning elements to variables and executing *script* for each iteration.
  - **Parameters**:
    - *varList* - One or more variable names to receive list elements
    - *list* - The list to iterate over
    - Multiple varList/list pairs can be specified for parallel iteration
  - **Behavior**: When *varList* contains multiple variables, that many elements are consumed from *list* per iteration. If lists have different lengths, shorter lists pad with empty strings.
  - **Returns**: An empty string (or the value from `break`).
  - **Example**:
    ```tcl
    foreach {key value} $dict {
        puts "$key => $value"
    }

    foreach x $list1 y $list2 {
        puts "$x, $y"
    }
    ```

<a id="cmd-lmap"></a>
- **lmap** - List mapping (transform list with script)
  - `lmap varList list ?varList list ...? script`
  - Like `foreach`, but collects the results of each *script* evaluation into a new list.
  - **Behavior**: Each non-empty result from *script* is appended to the result list. Use `continue` to skip adding a result for the current iteration.
  - **Returns**: A list containing the results of each script evaluation.
  - **Example**:
    ```tcl
    # Double each element
    set doubled [lmap x {1 2 3 4} {expr {$x * 2}}]
    # Result: {2 4 6 8}

    # Filter: keep only positive numbers
    set positive [lmap x {-1 2 -3 4} {
        if {$x > 0} {set x} else {continue}
    }]
    # Result: {2 4}
    ```

<a id="cmd-while"></a>
- **while** - While loop
  - `while test script`
  - Repeatedly executes *script* while *test* evaluates to true. The *test* is evaluated before each iteration, so if it is initially false, *script* is never executed.
  - **Returns**: An empty string (or the value from `break`).
  - **Example**:
    ```tcl
    set i 0
    while {$i < 10} {
        puts $i
        incr i
    }
    ```

---

### Variables

All variable commands belong to ObjectGroup: "variable"

<a id="cmd-append"></a>
- **append** - Append values to variable
  - `append varName ?value ...?`
  - Appends all *value* arguments to the current value of variable *varName*. If the variable does not exist, it is created with an initial empty value before appending. This is more efficient than `set varName "$varName$value"` because it avoids creating intermediate string copies.
  - **Returns**: The new value of the variable.
  - **Example**:
    ```tcl
    set msg "Hello"
    append msg ", " "World" "!"
    # msg is now "Hello, World!"
    ```

<a id="cmd-array"></a>
- **array** - Array operations (see Arrays section for sub-commands)

<a id="cmd-getf"></a>
- **getf** - Get variable with flags (obsolete, diagnostic)
  - `getf varName`
  - Retrieves a variable's value along with internal flag information. This is an obsolete diagnostic command primarily used for interpreter debugging.
  - **Returns**: The variable value with associated flags.

<a id="cmd-global"></a>
- **global** - Declare global variables
  - `global varName ?varName ...?`
  - Declares that the specified variables refer to global variables (in the `::` namespace) rather than local variables. This command is typically used inside procedures to access or modify global state.
  - **Behavior**: Creates a link between a local name and the global variable. If the global variable doesn't exist, it is not created until a value is assigned.
  - **Returns**: An empty string.
  - **Example**:
    ```tcl
    set ::counter 0
    proc incrementCounter {} {
        global counter
        incr counter
    }
    ```

<a id="cmd-incr"></a>
- **incr** - Increment variable value
  - `incr varName ?increment?`
  - Increments the integer value stored in *varName* by *increment* (default is 1). The variable must contain a valid integer value, or an error is raised.
  - **Parameters**:
    - *varName* - Name of the variable to increment
    - *increment* - Amount to add (can be negative); default is 1
  - **Returns**: The new value of the variable.
  - **Example**:
    ```tcl
    set x 10
    incr x      ;# x is now 11
    incr x 5    ;# x is now 16
    incr x -3   ;# x is now 13
    ```

<a id="cmd-scope"></a>
- **scope** - Variable scope operations (Eagle extension)
  - `scope subcommand ?options? ?args?`
  - Provides fine-grained control over variable scopes (call frames), enabling creation of isolated variable environments that persist across procedure calls. Scopes allow variables to be preserved and shared across multiple invocations of procedures, making them useful for implementing stateful operations, coroutine-like patterns, and persistent local state.
  - **Core Concepts**:
    - A **scope** is a named call frame with its own variable dictionary
    - Scopes can be **created** (defining the frame), **opened** (pushing onto call stack), and **closed** (popping from call stack)
    - Opening a scope makes its variables accessible as local variables
    - Multiple opens of the same scope stack and affect `[info level]`
    - Scopes are automatically closed when procedures return (implied close)
    - Scopes can be **cloned** from existing variable frames to capture current state
  - **Sub-commands**:

    **scope attach** - Attach scope to namespace (requires namespaces)
    - `scope attach name namespace`
    - Associates an existing scope with a namespace. Requires namespaces to be enabled.
    - **Returns**: List of attached items.

    **scope close** - Close an open scope
    - `scope close ?options? ?name?`
    - Pops the current (or named) scope from the call stack. If no name is specified, closes the innermost open scope.
    - **Options**:
      - `-all` - Close all open scopes at once, returning to the base level
    - **Returns**: The name of the closed scope.
    - **Note**: Scope close is implied when a procedure returns; explicit close is rarely needed.

    **scope create** - Create a new scope
    - `scope create ?options? ?name?`
    - Creates a new named scope. If no name is provided, an automatic name is generated.
    - **Options**:
      - `-args` - Copy procedure arguments from enclosing procedure frame into the scope
      - `-clone` - Clone variables from the current variable frame into the new scope
      - `-byref` - Clone variables by reference instead of by value (unsafe option)
      - `-global` - Clone variables from the global frame instead of current frame
      - `-open` - Immediately open (push) the scope after creation
      - `-procedure` - Auto-generate scope name based on enclosing procedure frame (cannot specify name with this option)
      - `-shared` - Use a shared scope name (for cross-thread scenarios)
      - `-strict` - Return error if scope with same name already exists
      - `-fast` - Enable fast local variable access mode for the scope
    - **Returns**: The name of the created scope.
    - **Example**:
      ```tcl
      # Create a named scope with cloned variables, opened immediately
      proc counter {name} {
          scope create -open -clone -args $name
          if {![info exists count]} {set count 0}
          incr count
          return $count
          # scope close implied on return
      }
      counter myCounter  ;# Returns 1
      counter myCounter  ;# Returns 2
      counter myCounter  ;# Returns 3
      scope destroy myCounter
      ```

    **scope current** - Get current open scope name
    - `scope current`
    - Returns the name of the currently open scope, or an empty string if no scope is open.
    - **Returns**: Current scope name or empty string.

    **scope destroy** - Destroy a scope
    - `scope destroy name`
    - Destroys the named scope, releasing all its variables and resources. If the scope is currently open, it is closed first. Any opaque object handles in the scope are released.
    - **Returns**: List containing cleanup information.

    **scope detach** - Detach scope from namespace (requires namespaces)
    - `scope detach name namespace`
    - Disassociates a scope from a namespace.
    - **Returns**: List of detached items.

    **scope eval** - Evaluate script in scope context
    - `scope eval ?options? name arg ?arg ...?`
    - Evaluates the script arguments in the context of the named scope. The scope is pushed, script is evaluated, and scope is popped (along with any scopes opened during evaluation).
    - **Options**:
      - `-lock` - Acquire lock on scope during evaluation
      - `-timeout milliseconds` - Timeout for lock acquisition (unsafe option)
      - `-eventwaitflags flags` - Event wait flags for lock (unsafe option)
    - **Returns**: Result of evaluated script.
    - **Example**:
      ```tcl
      scope create myScope
      scope eval myScope {
          set x 10
          set y 20
          expr {$x + $y}
      }  ;# Returns 30
      scope set myScope x  ;# Returns 10
      scope destroy myScope
      ```

    **scope exists** - Check if scope exists
    - `scope exists name`
    - Tests whether a scope with the given name exists.
    - **Returns**: Boolean true if scope exists, false otherwise.

    **scope export** - Export scope variables to namespace (requires namespaces)
    - `scope export name namespace`
    - Exports variables from a scope into a namespace.
    - **Returns**: List of exported items.

    **scope global** - Get or set global scope
    - `scope global ?options? ?name?`
    - Gets or sets the interpreter's global scope. When a global scope is set, variable operations that would normally go to the true global frame go to the designated scope instead.
    - **Options**:
      - `-unset` - Unset the global scope (cannot specify name with this option)
      - `-force` - Force setting even if already set
    - **Returns**: Current global scope name (may be empty).
    - **Example**:
      ```tcl
      scope create foo
      scope global foo    ;# Set foo as global scope
      scope global        ;# Returns "foo"
      scope global -unset ;# Clear global scope setting
      ```

    **scope import** - Import namespace variables to scope (requires namespaces)
    - `scope import name namespace`
    - Imports variables from a namespace into a scope.
    - **Returns**: List of imported items.

    **scope list** - List all scopes
    - `scope list ?pattern?`
    - Returns a list of all defined scope names, optionally filtered by a glob pattern.
    - **Returns**: List of scope names.

    **scope lock** - Lock a scope
    - `scope lock ?options? name`
    - Acquires a lock on the named scope, preventing other operations from modifying it.
    - **Options**:
      - `-nocomplain` - Don't error if scope doesn't exist
    - **Returns**: Empty string on success.

    **scope open** - Open an existing scope
    - `scope open ?options? ?name?`
    - Pushes an existing scope onto the call stack, making its variables accessible. The scope must have been previously created.
    - **Options**:
      - `-procedure` - Use auto-generated name from procedure frame
      - `-shared` - Use shared scope naming
      - `-args` - Copy procedure arguments into the scope
    - **Returns**: Empty string on success.
    - **Note**: Each open increases `[info level]` by 1; multiple opens of the same scope stack.

    **scope set** - Get or set variable in scope
    - `scope set name varName ?value?`
    - Gets or sets a variable within the named scope without opening it.
    - **Returns**: The variable value.
    - **Example**:
      ```tcl
      scope create myScope
      scope set myScope x 100
      scope set myScope x  ;# Returns 100
      ```

    **scope unlock** - Unlock a scope
    - `scope unlock ?options? name`
    - Releases a lock previously acquired on a scope.
    - **Options**:
      - `-nocomplain` - Don't error if scope doesn't exist
    - **Returns**: Empty string on success.

    **scope unset** - Unset variable in scope
    - `scope unset name varName`
    - Removes a variable from the named scope.
    - **Returns**: Empty string on success.

    **scope update** - Update scope with current variables
    - `scope update ?options? ?name?`
    - Updates the named scope (or current open scope) by cloning variables from the current or global frame. This refreshes the scope's variables to match the current state.
    - **Options**:
      - `-global` - Update from global frame instead of current frame
    - **Returns**: Empty string on success.
    - **Example**:
      ```tcl
      proc updateDemo {arg} {
          set local 123
          scope create -clone demo
          set local 456
          scope update demo
          scope set demo local  ;# Returns 456
      }
      ```

    **scope vars** - List variables in scope
    - `scope vars name ?pattern?`
    - Returns a list of defined variable names in the specified scope, optionally filtered by a glob pattern.
    - **Returns**: List of variable names.

  - **Procedure Scope Pattern** (using `-procedure`):
    The `-procedure` option provides a convenient way to create per-procedure scopes that persist across calls:
    ```tcl
    proc statefulProc {varName} {
        # Creates/opens scope named after this procedure
        set ::scope [scope create -open -procedure -args]
        upvar 0 $varName myVar
        if {[info exists myVar]} {
            incr myVar
        } else {
            set myVar 0
        }
        return $myVar
        # scope close implied
    }
    statefulProc x  ;# Returns 0
    statefulProc y  ;# Returns 0 (different variable)
    statefulProc x  ;# Returns 1
    statefulProc y  ;# Returns 1
    scope destroy $::scope
    ```

  - **Scope with upvar Pattern**:
    Scopes can be combined with `upvar` to implement persistent references:
    ```tcl
    proc accumulator {scopeName varName} {
        set c 9
        scope create -open -clone -args $scopeName
        if {![info exists sum]} then {
            upvar 2 $varName sum  ;# Link to caller's variable
            set sum 0
        }
        incr sum $c
        return $sum
        # scope close implied
    }
    set total 0
    accumulator myScope total  ;# total = 9
    accumulator myScope total  ;# total = 18
    accumulator myScope total  ;# total = 27
    scope destroy myScope
    ```

  - **Impact on `[info level]`**:
    Opening a scope increases the call stack level reported by `[info level]`:
    ```tcl
    info level                ;# 0
    scope create -open foo
    info level                ;# 1
    scope open foo            ;# Opening same scope again
    info level                ;# 2
    scope close               ;# Close innermost
    info level                ;# 1
    scope close               ;# Close again
    info level                ;# 0
    scope destroy foo
    ```

  - **Error Handling**:
    Scopes are properly unwound when errors occur. An error inside a procedure with an open scope will still properly close the scope:
    ```tcl
    proc mayFail {scopeName} {
        scope create -open -clone $scopeName
        error "something went wrong"
        # scope close still implied, scope remains intact
    }
    catch {mayFail testScope}
    scope exists testScope  ;# Returns True
    scope destroy testScope
    ```

<a id="cmd-set"></a>
- **set** - Set variable value
  - `set varName ?newValue?`
  - If *newValue* is provided, sets the variable *varName* to that value. If *newValue* is omitted, returns the current value of the variable (raises an error if the variable doesn't exist).
  - **Array elements**: Use `set arrayName(index) value` to set array elements.
  - **Returns**: The value of the variable.
  - **Example**:
    ```tcl
    set name "Alice"
    set greeting "Hello, $name"
    puts [set greeting]  ;# Prints: Hello, Alice

    set data(key1) "value1"
    set data(key2) "value2"
    ```

<a id="cmd-setf"></a>
- **setf** - Set variable with flags (obsolete, diagnostic)
  - `setf varFlags varName ?newValue?`
  - Sets a variable with specific internal flags. This is an obsolete diagnostic command used for interpreter debugging.
  - **Returns**: The value of the variable.

<a id="cmd-unset"></a>
- **unset** - Unset variables
  - `unset ?options? ?varName varName ...?`
  - Removes the specified variables from the current scope. After unsetting, the variable no longer exists (reading it will raise an error).
  - **Options**:
    - `-nocomplain` - Don't raise an error if a variable doesn't exist
    - `--` - Marks end of options
  - **Array handling**: `unset arrayName` removes the entire array; `unset arrayName(index)` removes only that element.
  - **Returns**: An empty string.
  - **Example**:
    ```tcl
    set x 10
    unset x
    unset -nocomplain x y z  ;# No error even if y, z don't exist
    ```

<a id="cmd-unsetf"></a>
- **unsetf** - Unset variable with flags
  - `unsetf varFlags ?varName varName ...?`
  - Unsets variables with specific internal flags. This is a diagnostic command for advanced interpreter manipulation.
  - **Returns**: An empty string.

<a id="cmd-upvar"></a>
- **upvar** - Link variable to upper scope
  - `upvar ?level? otherVar localVar ?otherVar localVar ...?`
  - Creates a link between *localVar* in the current scope and *otherVar* in an enclosing scope. Any access to *localVar* actually accesses *otherVar*. This enables procedures to modify variables passed "by reference."
  - **Level specification**:
    - A positive integer *n* means *n* levels up (default is 1, i.e., the caller's scope)
    - `#n` specifies an absolute stack level (0 is global)
  - **Returns**: An empty string.
  - **Example**:
    ```tcl
    proc swap {aName bName} {
        upvar 1 $aName a $bName b
        set temp $a
        set a $b
        set b $temp
    }

    set x 1
    set y 2
    swap x y
    # Now x=2, y=1
    ```

<a id="cmd-variable"></a>
- **variable** - Declare namespace variables
  - `variable ?name value...? name ?value?`
  - Declares variables within the current namespace. If called inside a procedure within a namespace, creates a link to the namespace variable (similar to `global` but for namespace variables).
  - **Parameters**:
    - *name* - Variable name to declare
    - *value* - Optional initial value
  - **Returns**: An empty string.
  - **Example**:
    ```tcl
    namespace eval myns {
        variable counter 0
        variable name "default"

        proc increment {} {
            variable counter
            incr counter
        }
    }
    ```

---

### Lists

All list commands belong to ObjectGroup: "list"

Lists in Eagle are ordered collections of string values. Lists use a specific syntax where elements are separated by whitespace, and elements containing whitespace or special characters must be enclosed in braces `{}` or quoted with backslashes.

#### Index Notation

Many list commands accept index arguments. Valid index formats include:
- Non-negative integers (0-based): `0`, `1`, `2`, ...
- `end` - The last element
- `end-n` - The nth element from the end (e.g., `end-1` is second-to-last)
- `n+m` or `n-m` - Arithmetic on indices

<a id="cmd-lappend"></a>
- **lappend** - Append elements to list variable
  - `lappend varName ?value ...?`
  - Appends each *value* as a new element to the list stored in *varName*. If the variable doesn't exist, it is created as an empty list before appending. This is the preferred way to build lists incrementally as it's more efficient than `set varName [concat $varName [list $value]]`.
  - **Returns**: The new value of the list variable.
  - **Example**:
    ```tcl
    set fruits {apple banana}
    lappend fruits cherry "dragon fruit"
    # fruits is now: {apple banana cherry {dragon fruit}}
    ```

<a id="cmd-lassign"></a>
- **lassign** - Assign list elements to variables
  - `lassign list varName ?varName ...?`
  - Assigns successive elements of *list* to the specified variables. If there are more variables than list elements, the excess variables are set to empty strings. If there are more elements than variables, the excess elements are returned.
  - **Returns**: A list of any unassigned elements (empty if all elements were assigned).
  - **Example**:
    ```tcl
    lassign {a b c d e} x y z
    # x="a", y="b", z="c"
    # Returns: {d e}

    lassign {1 2} a b c
    # a="1", b="2", c=""
    ```

<a id="cmd-lget"></a>
- **lget** - Get element from list variable (Eagle extension)
  - `lget varName ?index ...?`
  - Retrieves an element from a list stored in a variable. This combines variable lookup with list indexing in a single operation, which can be more efficient than `lindex [set varName] index`.
  - **Nested indexing**: Multiple indices navigate nested lists.
  - **Returns**: The selected list element.
  - **Example**:
    ```tcl
    set data {{a b} {c d} {e f}}
    lget data 1 0    ;# Returns: "c"
    ```

<a id="cmd-lindex"></a>
- **lindex** - Get list element by index
  - `lindex list ?index ...?`
  - Returns the element at the specified *index* in *list*. If multiple indices are provided, each successive index navigates into nested lists.
  - **Out of range**: Returns an empty string if the index is out of range (no error).
  - **Returns**: The selected element, or empty string if index is out of range.
  - **Example**:
    ```tcl
    set mylist {a b c d e}
    lindex $mylist 0       ;# Returns: "a"
    lindex $mylist end     ;# Returns: "e"
    lindex $mylist end-1   ;# Returns: "d"

    set nested {{1 2} {3 4} {5 6}}
    lindex $nested 1 0     ;# Returns: "3"
    ```

<a id="cmd-linsert"></a>
- **linsert** - Insert elements into list
  - `linsert list index value ?value ...?`
  - Returns a new list with the *value* arguments inserted into *list* before the element at *index*. The original list is not modified.
  - **Index behavior**:
    - Index 0 inserts at the beginning
    - Index `end` inserts before the last element
    - Index greater than list length appends at the end
  - **Returns**: A new list with elements inserted.
  - **Example**:
    ```tcl
    linsert {a b c} 1 X Y
    # Returns: {a X Y b c}

    linsert {a b c} end X
    # Returns: {a b X c}
    ```

<a id="cmd-list"></a>
- **list** - Create a list
  - `list ?arg arg ...?`
  - Creates a properly formatted list from the given arguments. Each argument becomes one element of the list, with proper quoting applied automatically. This is the safe way to construct lists—never use string concatenation.
  - **Returns**: A list containing all arguments as elements.
  - **Example**:
    ```tcl
    list a b c                    ;# Returns: {a b c}
    list "hello world" foo        ;# Returns: {{hello world} foo}
    list a {b c} d                ;# Returns: {a {b c} d}

    # Safe command construction:
    set cmd [list puts $message]  ;# Properly quotes $message
    ```

<a id="cmd-llength"></a>
- **llength** - Get list length
  - `llength list`
  - Returns the number of elements in *list*.
  - **Returns**: An integer count of elements.
  - **Example**:
    ```tcl
    llength {a b c d}     ;# Returns: 4
    llength {}            ;# Returns: 0
    llength {{a b} c}     ;# Returns: 2 (nested list counts as one element)
    ```

- **lmap** - List mapping (see Loop section)
  - Creates a new list by applying a script to each element of the input list(s).

<a id="cmd-lrange"></a>
- **lrange** - Get range of list elements
  - `lrange list first last`
  - Returns a list containing the elements of *list* from index *first* through index *last*, inclusive.
  - **Boundary handling**: Indices are automatically constrained to valid range (no error for out-of-range indices).
  - **Returns**: A list containing the selected elements.
  - **Example**:
    ```tcl
    lrange {a b c d e} 1 3     ;# Returns: {b c d}
    lrange {a b c d e} 2 end   ;# Returns: {c d e}
    lrange {a b c} 0 end-1     ;# Returns: {a b}
    ```

<a id="cmd-lremove"></a>
- **lremove** - Remove list elements by index (Eagle extension)
  - `lremove list index ?index...?`
  - Returns a new list with the elements at the specified indices removed. Multiple indices can be specified; they are processed in a way that accounts for shifting positions.
  - **Returns**: A new list with elements removed.
  - **Example**:
    ```tcl
    lremove {a b c d e} 1 3    ;# Returns: {a c e}
    ```

<a id="cmd-lrepeat"></a>
- **lrepeat** - Create list by repeating values
  - `lrepeat count value ?value ...?`
  - Creates a list by repeating the sequence of *value* arguments *count* times.
  - **Returns**: A list with the values repeated.
  - **Example**:
    ```tcl
    lrepeat 3 a           ;# Returns: {a a a}
    lrepeat 2 x y z       ;# Returns: {x y z x y z}
    lrepeat 0 a b         ;# Returns: {}
    ```

<a id="cmd-lreplace"></a>
- **lreplace** - Replace list elements
  - `lreplace list first last ?value ...?`
  - Returns a new list with elements from *first* to *last* (inclusive) replaced by the *value* arguments. If no values are provided, the elements are simply deleted.
  - **Insertion**: If *first* > *last*, the values are inserted before *first* without removing any elements.
  - **Returns**: A new list with elements replaced.
  - **Example**:
    ```tcl
    lreplace {a b c d e} 1 2 X Y Z   ;# Returns: {a X Y Z d e}
    lreplace {a b c d e} 1 2         ;# Returns: {a d e} (deletion)
    lreplace {a b c} 1 0 X           ;# Returns: {a X b c} (insertion)
    ```

<a id="cmd-lreverse"></a>
- **lreverse** - Reverse a list
  - `lreverse list`
  - Returns a list with the elements in reverse order.
  - **Returns**: The reversed list.
  - **Example**:
    ```tcl
    lreverse {a b c d}    ;# Returns: {d c b a}
    ```

<a id="cmd-lsearch"></a>
- **lsearch** - Search for element in list
  - `lsearch ?options? list pattern`
  - Searches *list* for an element matching *pattern* and returns the index of the first match, or -1 if no match is found.
  - **Match Options** (mutually exclusive):
    - `-exact` - Exact string match (default)
    - `-glob` - Glob-style pattern matching
    - `-regexp` - Regular expression matching
    - `-sorted` - List is sorted; use binary search (faster for large lists)
  - **Modifier Options**:
    - `-all` - Return indices of all matching elements (as a list)
    - `-inline` - Return the matching element(s) instead of indices
    - `-not` - Invert the match sense
    - `-nocase` - Case-insensitive matching
    - `-start index` - Begin search at specified index
  - **Data Type Options** (for `-sorted`):
    - `-integer` - Compare as integers
    - `-real` - Compare as floating-point numbers
    - `-ascii` - Compare as strings (default)
    - `-dictionary` - Dictionary-style comparison
    - `-increasing` / `-decreasing` - Sort order (default: increasing)
  - **Sublist Options**:
    - `-index indexList` - Search within a specific element of sublists
    - `-subindices` - Return full index path for nested matches
  - **Returns**: Index of first match, -1 if not found (or list of indices/elements with `-all`/`-inline`).
  - **Example**:
    ```tcl
    lsearch {a b c d} c                    ;# Returns: 2
    lsearch -glob {apple banana cherry} b* ;# Returns: 1
    lsearch -all -inline {1 2 3 2 1} 2     ;# Returns: {2 2}
    lsearch -regexp {cat dog bird} {^d}    ;# Returns: 1
    ```

<a id="cmd-lset"></a>
- **lset** - Set list element
  - `lset varName index ?index...? value`
  - Modifies the list stored in *varName* by replacing the element at the specified index with *value*. Multiple indices navigate into nested lists. The variable is modified in place.
  - **Returns**: The new value of the list.
  - **Example**:
    ```tcl
    set mylist {a b c d}
    lset mylist 1 X           ;# mylist is now: {a X c d}

    set nested {{1 2} {3 4}}
    lset nested 0 1 9         ;# nested is now: {{1 9} {3 4}}
    ```

<a id="cmd-lsort"></a>
- **lsort** - Sort a list
  - `lsort ?options? list`
  - Returns a sorted copy of *list*. The original list is not modified.
  - **Sort Type Options** (mutually exclusive):
    - `-ascii` - String comparison using ASCII values (default)
    - `-dictionary` - Dictionary-style: case-insensitive with numbers sorted numerically
    - `-integer` - Compare as integers
    - `-real` - Compare as floating-point numbers
    - `-command cmdPrefix` - Use custom comparison command
  - **Order Options**:
    - `-increasing` - Ascending order (default)
    - `-decreasing` - Descending order
  - **Modifier Options**:
    - `-nocase` - Case-insensitive comparison
    - `-unique` - Remove duplicate elements
    - `-indices` - Return indices of elements in sorted order (not the elements)
    - `-index indexList` - Sort by a specific element within sublists
    - `-stride n` - Treat list as groups of *n* elements
  - **Returns**: The sorted list.
  - **Example**:
    ```tcl
    lsort {banana Apple cherry}           ;# Returns: {Apple banana cherry}
    lsort -nocase {banana Apple cherry}   ;# Returns: {Apple banana cherry}
    lsort -integer {10 2 5 1}             ;# Returns: {1 2 5 10}
    lsort -unique {a b a c b}             ;# Returns: {a b c}
    lsort -decreasing {1 3 2}             ;# Returns: {3 2 1}

    # Sort list of pairs by second element:
    lsort -index 1 {{a 2} {b 1} {c 3}}    ;# Returns: {{b 1} {a 2} {c 3}}
    ```

---

### Strings

String commands belong to ObjectGroup: "string"

- **append** - Append to string variable (see Variables)

- **base64** - Base64 encoding/decoding
  - `base64 decode ?options? string` - Decode a Base64-encoded string back to its original binary/text form
  - `base64 encode ?options? string` - Encode a string or binary data to Base64 format
  - **Options**:
    - `-encoding name` - Character encoding to use (default: utf-8)
    - `-strict` - Strict mode; error on invalid input
  - **Returns**: The encoded or decoded string.
  - **Example**:
    ```tcl
    base64 encode "Hello, World!"   ;# Returns: SGVsbG8sIFdvcmxkIQ==
    base64 decode "SGVsbG8="        ;# Returns: Hello
    ```

<a id="cmd-concat"></a>
- **concat** - Concatenate arguments
  - `concat ?arg arg ...?`
  - Concatenates the arguments with spaces, treating each as a list and merging them into a single list. Leading/trailing whitespace is trimmed from each argument.
  - **Note**: For simple string concatenation, use `append` or double-quotes. `concat` is primarily for merging lists.
  - **Returns**: A list formed by concatenating all arguments.
  - **Example**:
    ```tcl
    concat {a b} {c d}      ;# Returns: {a b c d}
    concat "  a  " "  b  "  ;# Returns: {a b}
    ```

<a id="cmd-encoding"></a>
- **encoding** - Character encoding operations
  - `encoding convertfrom ?encoding? data` - Convert from external encoding to Unicode
  - `encoding convertto ?encoding? data` - Convert from Unicode to external encoding
  - `encoding getstring object ?encoding?` - Get string from byte array object (Eagle extension)
  - `encoding names ?system? ?pattern?` - List available encodings
  - `encoding system ?encoding?` - Get or set the system encoding
  - **Common encodings**: `utf-8`, `ascii`, `unicode`, `iso8859-1`
  - **Returns**: Converted data or encoding information.
  - **Example**:
    ```tcl
    encoding convertto utf-8 "Hello"
    encoding names               ;# List all encodings
    encoding system              ;# Get current system encoding
    ```

<a id="cmd-format"></a>
- **format** - Format string (like sprintf)
  - `format formatString ?arg ...?`
  - Generates a formatted string using C-style printf format specifiers. Each `%` conversion specifier in *formatString* consumes one argument.
  - **Format specifiers**:
    - `%s` - String
    - `%d`, `%i` - Signed decimal integer
    - `%u` - Unsigned decimal integer
    - `%o` - Octal integer
    - `%x`, `%X` - Hexadecimal integer (lowercase/uppercase)
    - `%f` - Floating-point (fixed notation)
    - `%e`, `%E` - Floating-point (exponential notation)
    - `%g`, `%G` - Floating-point (shorter of %f or %e)
    - `%c` - Character (from integer code)
    - `%%` - Literal percent sign
  - **Field width and precision**: `%[flags][width][.precision]specifier`
    - Flags: `-` (left-justify), `+` (show sign), `0` (zero-pad), space (space for positive)
    - Width: Minimum field width
    - Precision: Digits after decimal (floats) or max chars (strings)
  - **Returns**: The formatted string.
  - **Example**:
    ```tcl
    format "Name: %s, Age: %d" "Alice" 30    ;# Returns: "Name: Alice, Age: 30"
    format "%08x" 255                         ;# Returns: "000000ff"
    format "%.2f" 3.14159                     ;# Returns: "3.14"
    format "%-10s|" "Hi"                      ;# Returns: "Hi        |"
    ```

<a id="cmd-guid"></a>
- **guid** - GUID/UUID operations (Eagle extension)
  - `guid compare guid1 guid2` - Compare two GUIDs (-1, 0, or 1)
  - `guid isnull guid` - Check if GUID is the null/empty GUID
  - `guid isvalid guid` - Check if string is a valid GUID format
  - `guid new` - Generate a new random GUID
  - `guid null` - Return the null GUID (all zeros)
  - **Returns**: GUID string or boolean result.
  - **Example**:
    ```tcl
    set id [guid new]           ;# e.g., "550e8400-e29b-41d4-a716-446655440000"
    guid isvalid $id            ;# Returns: 1 (true)
    guid isnull [guid null]     ;# Returns: 1 (true)
    ```

<a id="cmd-hash"></a>
- **hash** - Hashing operations (Eagle extension)
  - `hash normal ?options? algorithm string` - Compute a hash of the string
  - `hash keyed ?options? algorithm string ?key?` - Compute a keyed hash
  - `hash mac ?options? algorithm string ?key?` - Compute HMAC (keyed-hash message authentication code)
  - `hash list ?type?` - List available hash algorithms
  - **Algorithms**: `md5`, `sha1`, `sha256`, `sha384`, `sha512`, and others
  - **Options**:
    - `-encoding name` - Text encoding (default: utf-8)
    - `-binary` - Return raw bytes instead of hex string
  - **Returns**: Hexadecimal hash string (or byte array with `-binary`).
  - **Example**:
    ```tcl
    hash normal sha256 "Hello"
    # Returns: 185f8db32271fe25f561a6fc938b2e264306ec304eda518007d1764826381969

    hash mac sha256 "message" "secretkey"
    hash list  ;# List available algorithms
    ```

<a id="cmd-join"></a>
- **join** - Join list elements with separator
  - `join list ?joinString?`
  - Concatenates the elements of *list* into a single string, with each element separated by *joinString* (default is a single space).
  - **Returns**: A string with all elements joined.
  - **Example**:
    ```tcl
    join {a b c}           ;# Returns: "a b c"
    join {a b c} ", "      ;# Returns: "a, b, c"
    join {a b c} ""        ;# Returns: "abc"
    join {1 2 3} "\n"      ;# Returns: "1\n2\n3" (multi-line)
    ```

<a id="cmd-parse"></a>
- **parse** - Parse scripts and expressions (Eagle extension)
  - `parse command ?options? text` - Parse text as a single command
  - `parse expression ?options? text` - Parse text as an expression
  - `parse options ?options? optionList argumentList` - Parse command-line style options
  - `parse script ?options? text` - Parse text as a script (multiple commands)
  - **Use cases**: Syntax analysis, building tools, validating scripts
  - **Returns**: Parsed structure information (varies by sub-command).

<a id="cmd-regexp"></a>
- **regexp** - Regular expression matching
  - `regexp ?switches? exp string ?matchVar? ?subMatchVar subMatchVar ...?`
  - Tests whether the regular expression *exp* matches part or all of *string*. Optionally stores matches in variables.
  - **Standard Switches** (Tcl-compatible):
    - `-nocase` - Case-insensitive matching
    - `-indices` / `-indexes` - Store indices (start, end) instead of matched text
    - `-line` - Newline-sensitive matching (combines `-lineanchor` and `-linestop`)
    - `-lineanchor` - `^` and `$` match line boundaries (enables Multiline mode)
    - `-linestop` - `.` doesn't match newlines (disables Singleline mode)
    - `-all` - Find all matches (return count instead of 0/1)
    - `-inline` - Return matches as a list instead of storing in variables
    - `-start index` - Start matching at specified index (supports `end-n` notation)
    - `-expanded` - Allow whitespace and comments in pattern (IgnorePatternWhitespace)
    - `--` - End of switches
  - **Eagle Extension Switches**:
    - `-options value` - Direct .NET `RegexOptions` enum value for fine-grained control
    - `-debug` - Enable debug output showing match attempts and results
    - `-ecma` - Use ECMAScript-compliant regex behavior
    - `-compiled` - Compile the regex for better performance on repeated use
    - `-explicit` - Use explicit capture mode (only named groups capture)
    - `-reverse` - Match right-to-left (RightToLeft mode)
    - `-global` - Global mode: don't reset variable index between matches
    - `-skip n` - Skip the first *n* capture groups when storing results
    - `-limit n` - Limit the number of matches returned
    - `-length n` - Limit the input string length to consider
    - `-noempty` - Skip empty matches when storing results
    - `-noculture` - Use culture-invariant matching
  - **Returns**: 1 if match found, 0 otherwise (or count with `-all`, or list with `-inline`).
  - **Example**:
    ```tcl
    regexp {^[A-Z]} "Hello"                    ;# Returns: 1
    regexp {(\d+)-(\d+)} "123-456" all a b     ;# all="123-456", a="123", b="456"
    regexp -all {\d+} "a1b2c3"                 ;# Returns: 3
    regexp -inline -all {\d+} "a1b2c3"         ;# Returns: {1 2 3}
    regexp -debug -all {\w+} "hello world"     ;# Shows debug output during matching
    regexp -compiled -nocase {pattern} $text   ;# Compiled, case-insensitive match
    ```

<a id="cmd-regsub"></a>
- **regsub** - Regular expression substitution
  - `regsub ?switches? exp string subSpec ?varName?`
  - Replaces matches of regular expression *exp* in *string* with *subSpec*. If *varName* is provided, stores the result there and returns the number of replacements; otherwise returns the modified string.
  - **Substitution specifiers in subSpec**:
    - `&` or `\0` - The entire matched string
    - `\1` through `\9` - Captured subexpressions
    - `\\` - Literal backslash
  - **Standard Switches** (Tcl-compatible):
    - `-all` - Replace all matches (not just the first)
    - `-nocase` - Case-insensitive matching
    - `-start index` - Start at specified index (supports `end-n` notation)
    - `-line` - Newline-sensitive matching (combines `-lineanchor` and `-linestop`)
    - `-lineanchor` - `^` and `$` match line boundaries
    - `-linestop` - `.` doesn't match newlines
    - `-expanded` - Allow whitespace and comments in pattern
    - `--` - End of switches
  - **Eagle Extension Switches**:
    - `-options value` - Direct .NET `RegexOptions` enum value for fine-grained control
    - `-count n` - Maximum number of replacements to make (default: 1 without `-all`)
    - `-ecma` - Use ECMAScript-compliant regex behavior
    - `-compiled` - Compile the regex for better performance on repeated use
    - `-explicit` - Use explicit capture mode (only named groups capture)
    - `-reverse` - Match right-to-left (RightToLeft mode)
    - `-quote` - Quote the replacement string (escape special characters)
    - `-nostrict` - Disable strict substitution syntax checking
    - `-extra` - Enable extra substitution syntax for Tcl compatibility
    - `-literal` - Treat *subSpec* as a literal string (no substitution processing)
    - `-verbatim` - Verbatim replacement mode
    - `-noculture` - Use culture-invariant matching
    - `-eval script` - Evaluate *script* for each match to compute the replacement; the match is available via special variables
    - `-command` - Command mode (TIP #463): treat *subSpec* as a command prefix; the matched text is appended as an argument and the result becomes the replacement. Cannot be used with `-eval`.
  - **Returns**: Modified string (or count if *varName* provided).
  - **Example**:
    ```tcl
    regsub {world} "Hello world" "Eagle"       ;# Returns: "Hello Eagle"
    regsub -all {[aeiou]} "Hello" "*"          ;# Returns: "H*ll*"
    regsub {(\w+) (\w+)} "John Doe" {\2, \1}   ;# Returns: "Doe, John"

    regsub -all {\d} "a1b2c3" "X" result
    # result = "aXbXcX", returns: 3

    # Using -command (TIP #463): transform each match via a command
    regsub -all -command {\d+} "a1b22c333" {string length}
    # Returns: "a1b2c3" (each number replaced by its length)

    # Using -literal: no substitution processing
    regsub -literal {.} "a.b" {$1}             ;# Returns: "a$1b"
    ```

<a id="cmd-split"></a>
- **split** - Split string into list
  - `split string ?splitChars? ?options?`
  - Splits *string* into a list of elements. By default, splits on any whitespace and removes empty elements.
  - **Parameters**:
    - *splitChars* - Characters to split on (each character is a separator); default is whitespace
    - If *splitChars* is empty string, splits into individual characters
  - **Returns**: A list of substrings.
  - **Example**:
    ```tcl
    split "a b c"            ;# Returns: {a b c}
    split "a,b,c" ","        ;# Returns: {a b c}
    split "a::b" ":"         ;# Returns: {a {} b} (empty element)
    split "abc" ""           ;# Returns: {a b c} (individual chars)
    split "a.b,c" ".,"       ;# Returns: {a b c} (multiple separators)
    ```

<a id="cmd-string"></a>
- **string** - String operations (extensive sub-commands)

  The `string` command provides comprehensive string manipulation capabilities through numerous sub-commands.

  #### String Measurement and Access

  - `string bytelength string ?encoding?` - Returns the number of bytes needed to represent *string* in the specified encoding (default: utf-8). Different from character length for multi-byte encodings.
  - `string length string` - Returns the number of characters in *string*.
  - `string index string charIndex` - Returns the character at *charIndex* (0-based). Returns empty string if index is out of range.
  - `string range string first last` - Returns a substring from index *first* to *last* (inclusive). Indices can use `end`, `end-n` notation.
  - `string ordinal string charIndex` - Returns the Unicode code point (integer) of the character at *charIndex* (Eagle extension).
  - `string character integer` - Returns the character corresponding to the Unicode code point *integer* (Eagle extension).

  **Example**:
  ```tcl
  string length "Hello"           ;# Returns: 5
  string index "Hello" 1          ;# Returns: "e"
  string range "Hello" 1 3        ;# Returns: "ell"
  string ordinal "A" 0            ;# Returns: 65
  string character 65             ;# Returns: "A"
  ```

  #### String Comparison

  - `string compare ?options? string1 string2` - Compares two strings lexicographically. Returns -1, 0, or 1 if *string1* is less than, equal to, or greater than *string2*.
  - `string equal ?options? string1 string2` - Returns 1 if strings are equal, 0 otherwise.
  - **Common options**: `-nocase` (case-insensitive), `-length n` (compare only first n characters)

  **Example**:
  ```tcl
  string compare "abc" "abd"          ;# Returns: -1
  string equal -nocase "Hello" "HELLO" ;# Returns: 1
  ```

  #### String Searching

  - `string first ?options? needleString haystackString ?startIndex?` - Returns the index of the first occurrence of *needleString* in *haystackString*, or -1 if not found. Search starts at *startIndex* (default 0).
  - `string last ?options? needleString haystackString ?startIndex?` - Returns the index of the last occurrence, searching backward from *startIndex* (default end).
  - `string match ?options? pattern string` - Returns 1 if *string* matches the glob *pattern*, 0 otherwise.
    - Glob patterns: `*` (any chars), `?` (one char), `[chars]` (character class), `\x` (escape)
  - `string wordstart string index` - Returns the index of the first character of the word containing the character at *index*.
  - `string wordend string index` - Returns the index of the character just after the last character of the word at *index*.

  **Example**:
  ```tcl
  string first "l" "Hello"            ;# Returns: 2
  string last "l" "Hello"             ;# Returns: 3
  string match "*.txt" "file.txt"     ;# Returns: 1
  string match {[A-Z]*} "Hello"       ;# Returns: 1
  ```

  #### String Modification

  - `string cat ?arg ...?` - Concatenates all arguments into a single string (no separators).
  - `string repeat string count` - Returns *string* repeated *count* times.
  - `string replace string first last ?newString?` - Returns *string* with characters from *first* to *last* replaced by *newString* (or deleted if *newString* is omitted).
  - `string reverse string` - Returns *string* with characters in reverse order.
  - `string map ?options? charMap string` - Performs character/string mapping. *charMap* is a list of `{old new old new ...}` pairs; all occurrences of each *old* substring are replaced with *new*.
  - `string format format ?arg ...?` - Same as the `format` command.

  **Example**:
  ```tcl
  string cat "Hello" ", " "World"     ;# Returns: "Hello, World"
  string repeat "ab" 3                ;# Returns: "ababab"
  string replace "Hello" 1 3 "XYZ"    ;# Returns: "HXYZo"
  string reverse "Hello"              ;# Returns: "olleH"
  string map {a A e E} "hello"        ;# Returns: "hEllo"
  ```

  #### Case Conversion and Trimming

  - `string tolower ?options? string ?first? ?last?` - Converts characters to lowercase. If *first* and *last* are given, only converts that range.
  - `string toupper ?options? string ?first? ?last?` - Converts characters to uppercase.
  - `string totitle ?options? string ?first? ?last?` - Converts first character to uppercase, rest to lowercase.
  - `string trim string ?chars?` - Removes leading and trailing characters in *chars* (default: whitespace).
  - `string trimleft string ?chars?` - Removes leading characters only.
  - `string trimright string ?chars?` - Removes trailing characters only.

  **Example**:
  ```tcl
  string tolower "HELLO"              ;# Returns: "hello"
  string toupper "hello"              ;# Returns: "HELLO"
  string totitle "hello world"        ;# Returns: "Hello world"
  string trim "  hello  "             ;# Returns: "hello"
  string trim "xxhelloxx" "x"         ;# Returns: "hello"
  ```

  #### Prefix/Suffix Testing (Eagle extensions)

  - `string starts ?options? prefix string` - Returns 1 if *string* starts with *prefix*, 0 otherwise.
  - `string ends ?options? suffix string` - Returns 1 if *string* ends with *suffix*, 0 otherwise.
  - **Options**: `-nocase` for case-insensitive comparison.

  **Example**:
  ```tcl
  string starts "Hello" "Hello, World"    ;# Returns: 1
  string ends -nocase ".TXT" "file.txt"   ;# Returns: 1
  ```

  #### Utility

  - `string classes` - Returns a list of all available string classification classes (for `string is`).

  #### String Classification (`string is`)

  The `string is` sub-command tests whether a string belongs to a particular class. All forms take the syntax:
  `string is class ?-strict? ?-failindex varName? string`

  - `-strict` - Empty string returns false (default: empty string passes most tests)
  - `-failindex varName` - Stores the index of the first character that fails the test

  **Character Classes (Tcl-compatible)**:
  - `string is alnum` - Alphanumeric characters (letters and digits)
  - `string is alpha` - Alphabetic characters only
  - `string is ascii` - ASCII characters (0-127)
  - `string is control` - Control characters
  - `string is digit` - Digit characters (0-9)
  - `string is graph` - Graphical (printable, non-space) characters
  - `string is lower` - Lowercase characters
  - `string is print` - Printable characters (including space)
  - `string is punct` - Punctuation characters
  - `string is space` - Whitespace characters
  - `string is upper` - Uppercase characters
  - `string is wordchar` - Word characters (alphanumeric + underscore)
  - `string is xdigit` - Hexadecimal digit characters (0-9, a-f, A-F)

  **Numeric Classes**:
  - `string is boolean` - Valid boolean value (true, false, yes, no, on, off, 1, 0)
  - `string is integer` - Valid 32-bit integer
  - `string is wideinteger` - Valid 64-bit integer
  - `string is entier` - Valid arbitrary-precision integer
  - `string is double` - Valid double-precision floating-point number
  - `string is decimal` - Valid decimal number (Eagle extension)

  **Eagle-specific Classes**:
  - `string is asciialnum` - ASCII alphanumeric only
  - `string is asciialpha` - ASCII alphabetic only
  - `string is asciidigit` - ASCII digits only
  - `string is base64` - Valid Base64-encoded string
  - `string is byte` - Valid byte value (0-255)
  - `string is cidr` - Valid CIDR notation (e.g., "192.168.1.0/24")
  - `string is command` - Valid command name in interpreter
  - `string is datetime` - Valid DateTime value
  - `string is dict` - Valid dictionary (even number of elements)
  - `string is directory` - Valid/existing directory path
  - `string is element` - Valid list element
  - `string is encoding` - Valid encoding name
  - `string is file` - Valid/existing file path
  - `string is guid` - Valid GUID/UUID format
  - `string is hexadecimal` - Valid hexadecimal number
  - `string is identifier` - Valid Eagle identifier
  - `string is inetaddr` - Valid internet address (IPv4 or IPv6)
  - `string is interpreter` - Valid interpreter name/handle
  - `string is list` - Valid Tcl list syntax
  - `string is none` - None/null value
  - `string is number` / `string is numeric` - Any numeric value
  - `string is object` - Valid object reference
  - `string is path` - Valid file system path
  - `string is real` - Valid real number
  - `string is single` - Valid single-precision float
  - `string is timespan` - Valid TimeSpan value
  - `string is true` / `string is false` - Specific boolean values
  - `string is type` - Valid .NET type name
  - `string is uri` - Valid URI
  - `string is version` - Valid version number (e.g., "1.2.3")
  - `string is versionrange` - Valid version range expression
  - `string is xml` - Valid XML content

  **Example**:
  ```tcl
  string is integer "123"          ;# Returns: 1
  string is integer "12.3"         ;# Returns: 0
  string is double "3.14"          ;# Returns: 1
  string is list {a b c}           ;# Returns: 1
  string is list "a {b"            ;# Returns: 0 (unbalanced brace)
  string is boolean "yes"          ;# Returns: 1
  string is -strict alpha ""       ;# Returns: 0 (empty string with -strict)
  ```

---

### Arrays

Array operations belong to ObjectGroup: "variable"

Arrays in Eagle are associative arrays (hash tables) that map string keys to string values. Array elements are accessed using the syntax `$arrayName(key)` or `set arrayName(key) value`.

- **array** - Array operations

  #### Basic Array Operations

  - `array exists arrayName` - Returns 1 if *arrayName* is an array variable, 0 otherwise.
  - `array size arrayName` - Returns the number of elements in the array.
  - `array get arrayName ?pattern?` - Returns a flat list of `{key value key value ...}` pairs. If *pattern* is specified, only keys matching the glob pattern are included.
  - `array set arrayName list` - Sets multiple array elements from a flat list `{key value key value ...}`. Creates the array if it doesn't exist.
  - `array unset arrayName ?pattern?` - Removes array elements. Without *pattern*, removes all elements (making it a non-array). With *pattern*, removes only matching keys.
  - `array names arrayName ?mode? ?pattern?` - Returns a list of array keys. *mode* can be `-exact`, `-glob` (default), or `-regexp`.
  - `array values arrayName ?mode? ?pattern?` - Returns a list of array values (Eagle extension). *mode* controls pattern matching on keys.

  **Example**:
  ```tcl
  array set data {name Alice age 30 city Boston}
  array exists data           ;# Returns: 1
  array size data             ;# Returns: 3
  array names data            ;# Returns: {name age city} (order may vary)
  array get data "a*"         ;# Returns: {age 30}
  array unset data "a*"       ;# Removes 'age' key
  ```

  #### Array Copying

  - `array copy ?options? source destination` - Copies array *source* to *destination* (Eagle extension).
    - **Options**: `-force` (overwrite existing), `-deep` (deep copy)

  #### Default Value Operations (Eagle extension)

  Eagle arrays can have a default value returned when accessing non-existent keys:

  - `array default exists arrayName` - Returns 1 if array has a default value set.
  - `array default get arrayName` - Returns the default value.
  - `array default set arrayName value` - Sets the default value for missing keys.
  - `array default unset arrayName` - Removes the default value.

  **Example**:
  ```tcl
  array set counts {}
  array default set counts 0
  incr counts(apples)    ;# Works even though 'apples' didn't exist
  ```

  #### Array Iteration

  - `array for {keyVar valueVar} arrayName script` - Iterates over array, setting *keyVar* and *valueVar* for each element, then executing *script*.
  - `array foreach varList arrayName ?varList arrayName ...? script` - More flexible iteration, similar to `foreach` but for arrays (Eagle extension).
  - `array lmap varList arrayName ?varList arrayName ...? script` - Like `array foreach` but collects results into a list (Eagle extension).

  **Example**:
  ```tcl
  array set data {a 1 b 2 c 3}
  array for {key value} data {
      puts "$key => $value"
  }
  ```

  #### Array Search (Manual Iteration)

  For manual iteration when you need more control:

  - `array startsearch arrayName` - Starts a search and returns a search token.
  - `array anymore arrayName searchId` - Returns 1 if more elements remain in the search.
  - `array nextelement arrayName searchId` - Returns the next key in the search.
  - `array donesearch arrayName searchId` - Ends the search and frees resources.

  **Example**:
  ```tcl
  set searchId [array startsearch data]
  while {[array anymore data $searchId]} {
      set key [array nextelement data $searchId]
      puts "Key: $key, Value: $data($key)"
  }
  array donesearch data $searchId
  ```

  #### Random Access (Eagle extension)

  - `array random ?options? arrayName ?pattern?` - Returns a random key-value pair from the array. If *pattern* is given, only matching keys are considered.

---

### I/O and Channels

Channel commands belong to ObjectGroup: "channel"

Channels are Eagle's abstraction for I/O streams. Standard channels include `stdin`, `stdout`, and `stderr`. Additional channels are created by `open`, `socket`, and other commands.

<a id="cmd-close"></a>
- **close** - Close channel
  - `close channelId`
  - Closes the specified channel and releases associated resources. For files, buffers are flushed and the file handle is released. For sockets, the connection is terminated.
  - **Returns**: An empty string.

<a id="cmd-eof"></a>
- **eof** - Check for end-of-file
  - `eof channelId`
  - Returns 1 if an end-of-file condition has occurred on *channelId*, 0 otherwise. This is typically checked after a read operation returns less data than expected.
  - **Returns**: Boolean (0 or 1).

<a id="cmd-fblocked"></a>
- **fblocked** - Check if channel is blocked
  - `fblocked channelId`
  - Returns 1 if the last input operation on *channelId* would have blocked (in non-blocking mode). Used for asynchronous I/O.
  - **Returns**: Boolean (0 or 1).

<a id="cmd-fconfigure"></a>
- **fconfigure** - Configure channel options
  - `fconfigure channelId ?optionName? ?value? ?optionName value ...?`
  - Gets or sets configuration options for a channel. Without arguments after *channelId*, returns all options. With just *optionName*, returns that option's value.
  - **Options**:
    - `-blocking boolean` - Blocking (true) or non-blocking (false) mode. Non-blocking mode allows `gets` and `read` with `-noblock` to return immediately with available data.
    - `-encoding name` - Character encoding (e.g., `utf-8`, `ascii`, `unicode`). Use `binary` or set to null for raw binary I/O.
    - `-translation mode` - Line ending translation mode. Can be a single value for both input and output, or a two-element list `{inputMode outputMode}`:
      - `auto` - Accept any line ending on input; use platform-native on output
      - `binary` - No translation (raw bytes)
      - `cr` - Carriage return only
      - `crlf` - Carriage return + line feed (Windows)
      - `lf` - Line feed only (Unix)
    - `-buffer boolean` - Enable (true) or disable (false) buffering (Eagle extension).
  - **Returns**: Option value(s) or empty string when setting.
  - **Example**:
    ```tcl
    fconfigure $fh -encoding utf-8 -translation lf
    fconfigure $sock -blocking 0           ;# Non-blocking socket I/O
    fconfigure $fh -translation {auto lf}  ;# Accept any input, output LF
    puts [fconfigure $fh -encoding]        ;# Query encoding
    ```

<a id="cmd-fcopy"></a>
- **fcopy** - Copy data between channels
  - `fcopy input output ?-size size? ?-command callback?`
  - Copies data from *input* channel to *output* channel efficiently.
  - **Options**:
    - `-size n` - Copy at most *n* bytes (default: copy until EOF)
    - `-command callback` - Asynchronous mode; *callback* is invoked when copy completes
  - **Returns**: Number of bytes copied (synchronous) or empty string (asynchronous).

<a id="cmd-flush"></a>
- **flush** - Flush channel buffer
  - `flush channelId`
  - Forces any buffered output data to be written to *channelId*. Normally, data is buffered and written in larger chunks for efficiency. `flush` ensures all pending data is actually sent.
  - **Returns**: An empty string.

<a id="cmd-gets"></a>
- **gets** - Read line from channel
  - `gets ?options? channelId ?varName?`
  - Reads a single line from *channelId* (up to but not including the newline by default).
  - **Without varName**: Returns the line read, or an empty string at EOF.
  - **With varName**: Stores the line in *varName* and returns the number of characters read (-1 at EOF).
  - **Standard Options**:
    - `--` - End of options
  - **Eagle Extension Options**:
    - `-noblock` - Non-blocking read: returns immediately with whatever data is currently available in the channel's internal buffer, rather than waiting for a complete line or EOF. **Important**: If no data is available in the buffer, the command will raise an error; wrap in `catch` to handle this case. This is useful for responsive I/O on sockets, pipes, or other streaming channels.
    - `-keepeol boolean` - When true, keep end-of-line characters in the result instead of stripping them.
    - `-count n` - Read exactly *n* bytes/characters instead of reading until end-of-line.
    - `-encoding value` - Override the channel's encoding for this read operation (unsafe).
    - `-usecount` - Read a count-prefixed value: first reads a size prefix, then reads that many bytes (unsafe).
  - **Returns**: Line content (or character count with *varName*).
  - **Example**:
    ```tcl
    while {[gets $fh line] >= 0} {
        puts "Read: $line"
    }

    # Non-blocking read pattern for sockets (use catch to handle no-data case)
    fconfigure $sock -translation crlf
    while {![eof $sock]} {
        if {[catch {gets -noblock $sock} line] == 0} then {
            append result $line
        } else {
            # No data available yet, continue polling
            after 10
        }
    }

    # Keep the end-of-line characters
    gets -keepeol true $fh line
    ```

<a id="cmd-open"></a>
- **open** - Open file or channel
  - `open fileName ?access? ?permissions? ?type? ?options?`
  - Opens a file or other resource and returns a channel identifier.
  - **Access modes**:
    - `r` - Read only (default); file must exist
    - `r+` - Read and write; file must exist
    - `w` - Write only; create or truncate
    - `w+` - Read and write; create or truncate
    - `a` - Write only; append; create if needed
    - `a+` - Read and write; append; create if needed
  - **Access flags** (alternative POSIX-style): `RDONLY`, `WRONLY`, `RDWR`, `APPEND`, `CREAT`, `EXCL`, `TRUNC`, `SeekToEof`
  - **Permissions**: Unix-style permission bits (default: 0666, modified by umask). Parsed but not used for file creation in Eagle.
  - **Type**: Channel type; currently only `file` (default) is supported.
  - **Eagle Extension Options**:
    - `-channelid value` - Specify a custom channel identifier instead of auto-generated
    - `-buffersize n` - Set the buffer size in bytes
    - `-share mode` - File sharing mode: `None`, `Read` (default), `Write`, `ReadWrite`, `Delete`
    - `-options flags` - .NET `FileOptions` flags: `None`, `WriteThrough`, `Asynchronous`, `RandomAccess`, `DeleteOnClose`, `SequentialScan`, `Encrypted`
    - `-streamflags flags` - `HostStreamFlags` for stream behavior control
    - `-nullencoding` - Allow null encoding (raw binary mode)
    - `-autoflush` - Automatically flush after each write operation
    - `-rawendofstream` - Use raw end-of-stream detection
    - `-stdin` - Open standard input stream (console only, ignores *fileName*)
    - `-stdout` - Open standard output stream (console only, ignores *fileName*)
    - `-stderr` - Open standard error stream (console only, ignores *fileName*)
  - **Returns**: A channel identifier (e.g., `file3`).
  - **Example**:
    ```tcl
    set fh [open "data.txt" r]
    set data [read $fh]
    close $fh

    set fh [open "output.txt" w]
    puts $fh "Hello, World!"
    close $fh

    # Open with exclusive access and auto-flush
    set fh [open "log.txt" a -share None -autoflush]

    # Open with custom channel ID
    set fh [open "data.bin" r -channelid mydata -nullencoding]
    ```

<a id="cmd-puts"></a>
- **puts** - Write to channel
  - `puts ?options? ?channelId? string`
  - Writes *string* to *channelId* (default: `stdout`), followed by a newline unless `-nonewline` is specified.
  - **Standard Options**:
    - `-nonewline` - Don't append a newline after the string
  - **Eagle Extension Options**:
    - `-encoding value` - Override the channel's encoding for this write operation (unsafe).
    - `-usecount` - Prepend a count prefix to the output, allowing the receiver to know exactly how many bytes to expect (unsafe). Useful for binary protocols.
    - `-useobject` - Write from an opaque object handle (byte array) instead of a string (unsafe). Useful for binary data.
  - **Returns**: An empty string.
  - **Example**:
    ```tcl
    puts "Hello"                    ;# To stdout with newline
    puts -nonewline "Enter name: "  ;# No newline (prompt)
    puts $fh "Line to file"         ;# To file channel

    # Write with specific encoding
    puts -encoding utf-8 $fh "Unicode: \u00e9"

    # Write binary data from object handle
    puts -useobject $fh $byteArrayHandle
    ```

<a id="cmd-read"></a>
- **read** - Read from channel
  - `read ?options? channelId ?numChars?`
  - Reads data from *channelId*.
  - **Without numChars**: Reads all remaining data until EOF.
  - **With numChars**: Reads at most *numChars* characters.
  - **Standard Options**:
    - `-nonewline` - Strip trailing newline from result
    - `--` - End of options
  - **Eagle Extension Options**:
    - `-noblock` - Non-blocking read: returns immediately with whatever data is currently available in the channel's internal buffer, rather than waiting for *numChars* characters or EOF. **Important**: If no data is available in the buffer, the command will raise an error; wrap in `catch` to handle this case. Essential for responsive I/O on sockets, pipes, or other streaming channels.
    - `-encoding value` - Override the channel's encoding for this read operation (unsafe).
    - `-useobject` - Return result as an opaque object handle (byte array) instead of a string (unsafe). Useful for binary data that shouldn't be encoded/decoded.
  - **Returns**: The data read as a string (or object handle with `-useobject`).
  - **Example**:
    ```tcl
    set fh [open "data.txt" r]
    set contents [read $fh]         ;# Read entire file
    close $fh

    set chunk [read $fh 1024]       ;# Read up to 1024 chars

    # Non-blocking read pattern for sockets (use catch to handle no-data case)
    fconfigure $sock -translation binary
    while {![eof $sock]} {
        if {[catch {read -noblock $sock} chunk] == 0} then {
            append data $chunk
        } else {
            # No data available yet, continue polling
            after 10
        }
    }

    # Read without trailing newline
    set data [read -nonewline $fh]
    ```

<a id="cmd-seek"></a>
- **seek** - Set channel position
  - `seek channelId offset ?origin?`
  - Moves the read/write position in *channelId*. Only works on seekable channels (files, not pipes or sockets).
  - **Origin**:
    - `start` - Offset from beginning of file (default)
    - `current` - Offset from current position
    - `end` - Offset from end of file
  - **Returns**: An empty string.
  - **Example**:
    ```tcl
    seek $fh 0 start      ;# Go to beginning
    seek $fh 0 end        ;# Go to end
    seek $fh -10 current  ;# Back 10 characters
    ```

<a id="cmd-tell"></a>
- **tell** - Get channel position
  - `tell channelId`
  - Returns the current read/write position in *channelId* as a byte offset from the beginning.
  - **Returns**: Integer offset, or -1 if position cannot be determined.

<a id="cmd-truncate"></a>
- **truncate** - Truncate channel (Eagle extension)
  - `truncate channelId ?length?`
  - Truncates the file associated with *channelId* to *length* bytes. If *length* is omitted, truncates at the current position.
  - **Returns**: An empty string.

---

### File System

File system commands belong to ObjectGroup: "fileSystem"

<a id="cmd-cd"></a>
- **cd** - Change directory
  - `cd ?dirName?`
  - Changes the current working directory to *dirName*. If *dirName* is omitted, changes to the user's home directory.
  - **Returns**: An empty string.

<a id="cmd-file"></a>
- **file** - File operations (extensive sub-commands)

  The `file` command provides comprehensive file system operations. Sub-commands are organized by category below.

  #### Path Manipulation

  - `file dirname name` - Returns the directory portion of *name* (everything up to the last path separator).
  - `file tail name` - Returns the final component of *name* (the file name without directory).
  - `file rootname name` - Returns *name* without its extension.
  - `file extension name` - Returns the extension of *name* (including the dot), or empty string.
  - `file join name ?name ...?` - Joins path components using the platform's path separator. Handles absolute paths intelligently.
  - `file split name` - Splits *name* into a list of path components.
  - `file normalize ?options? name` - Returns a normalized absolute path (resolves `.`, `..`, symlinks).
  - `file nativename name` - Converts *name* to the native format for the platform (e.g., backslashes on Windows).
  - `file separator ?name?` - Returns the path separator character for the platform (or for *name*'s path type).

  **Example**:
  ```tcl
  file dirname "/usr/local/bin/eagle"     ;# Returns: /usr/local/bin
  file tail "/usr/local/bin/eagle"        ;# Returns: eagle
  file rootname "document.txt"            ;# Returns: document
  file extension "document.txt"           ;# Returns: .txt
  file join "/usr" "local" "bin"          ;# Returns: /usr/local/bin
  file split "/usr/local/bin"             ;# Returns: {/ usr local bin}
  ```

  #### File Tests

  - `file exists name` - Returns 1 if *name* exists, 0 otherwise.
  - `file isdirectory name` - Returns 1 if *name* is a directory.
  - `file isfile name` - Returns 1 if *name* is a regular file.
  - `file readable name` - Returns 1 if *name* is readable by the current user.
  - `file writable name` - Returns 1 if *name* is writable by the current user.
  - `file executable name` - Returns 1 if *name* is executable.
  - `file owned name ?verbose?` - Returns 1 if *name* is owned by the current user (Eagle extension).
  - `file type name` - Returns the type: `file`, `directory`, `link`, `characterSpecial`, `blockSpecial`, `fifo`, or `socket`.
  - `file pathtype name` - Returns: `absolute`, `relative`, or `volumerelative`.
  - `file same name1 name2` - Returns 1 if both paths refer to the same file (Eagle extension).

  #### File Information

  - `file size name` - Returns the size of *name* in bytes.
  - `file atime name ?time?` - Gets or sets the access time (seconds since epoch).
  - `file mtime name ?time?` - Gets or sets the modification time.
  - `file ctime name ?time?` - Gets or sets the creation time (Eagle extension; platform-dependent).
  - `file stat name varName` - Stores file status in array *varName* with keys: `atime`, `ctime`, `dev`, `gid`, `ino`, `mode`, `mtime`, `nlink`, `size`, `type`, `uid`.
  - `file lstat name varName` - Like `stat`, but for symbolic links returns info about the link itself.
  - `file attributes name ?option? ?value ...?` - Gets or sets file attributes (platform-specific).

  **Example**:
  ```tcl
  file size "data.txt"                    ;# Returns file size in bytes
  file mtime "data.txt"                   ;# Returns modification timestamp
  file stat "data.txt" info
  puts "Size: $info(size), Type: $info(type)"
  ```

  #### File Operations

  - `file copy ?options? source ?source ...? target` - Copies files/directories. Options: `-force` (overwrite), `--` (end of options).
  - `file rename ?options? source ?source ...? target` - Renames/moves files. Options: `-force` (overwrite).
  - `file delete ?options? file ?file ...?` - Deletes files/directories. Options: `-force` (no error if missing), `--`.
  - `file mkdir dir ?dir ...?` - Creates directories (including parents as needed).
  - `file rmdir dir ?dir ...?` - Removes empty directories (Eagle extension).
  - `file touch path` - Creates empty file or updates timestamps (Eagle extension).

  **Example**:
  ```tcl
  file mkdir /tmp/mydir/subdir
  file copy data.txt /tmp/mydir/
  file rename -force old.txt new.txt
  file delete -force /tmp/mydir
  ```

  #### Directory Listing

  - `file channels ?pattern?` - Lists open channel identifiers matching *pattern*.
  - `file list ?directory? ?pattern?` - Lists directory contents matching *pattern* (Eagle extension).
  - `file volumes` - Returns a list of mounted volumes (e.g., `{C:/ D:/}` on Windows).

  #### Temporary Files

  - `file tempname` - Returns a unique temporary file name (Eagle extension).
  - `file temppath` - Returns the path to the system temporary directory (Eagle extension).

  #### Advanced Operations (Eagle extensions)

  - `file information ?-directory boolean? ?--? name` - Returns detailed file information as a dictionary.
  - `file version ?options? name` - Returns version information for executables/DLLs.
  - `file magic fileName` - Returns the file's magic number/type signature.
  - `file sddl ?options? name ?sddl?` - Gets or sets Windows security descriptor (SDDL format).
  - `file rights name` - Returns file access rights.
  - `file trusted path` / `file verified path` - Checks code signing/trust status.

<a id="cmd-glob"></a>
- **glob** - Glob for files
  - `glob ?options? pattern ?pattern ...?`
  - Returns a list of file names matching the glob pattern(s).
  - **Pattern syntax**: `*` (any chars), `?` (one char), `[chars]` (character set), `{a,b,c}` (alternatives)
  - **Options**:
    - `-directory dir` - Search relative to *dir*
    - `-path pathPrefix` - Prepend *pathPrefix* to patterns
    - `-types typeList` - Filter by type (`f`=file, `d`=directory, `r`=readable, `w`=writable, `x`=executable)
    - `-nocomplain` - Return empty list instead of error if no matches
    - `-tails` - Return only the file names, not full paths
    - `--` - End of options
  - **Returns**: List of matching file paths.
  - **Example**:
    ```tcl
    glob *.txt                            ;# All .txt files in current dir
    glob -directory /tmp *.log            ;# All .log files in /tmp
    glob -types f -nocomplain /var/log/*  ;# Only regular files
    glob {*.c *.h}                        ;# .c and .h files
    ```

<a id="cmd-pwd"></a>
- **pwd** - Print working directory
  - `pwd`
  - Returns the absolute path of the current working directory.
  - **Returns**: Directory path string.

---

### Procedures

Procedure commands belong to ObjectGroup: "procedure"

Procedures are Eagle's primary mechanism for code reuse and abstraction.

<a id="cmd-proc"></a>
- **proc** - Create procedure
  - `proc name args body`
  - Creates a new procedure named *name*. When called, the procedure executes *body* with arguments bound to variables as specified by *args*.
  - **Arguments specification** (*args*):
    - Simple list of names: `{a b c}` - Three required arguments
    - Default values: `{a {b default} c}` - *b* has a default value
    - Variable arguments: `{a b args}` - *args* collects remaining arguments as a list
    - No arguments: `{}` - Procedure takes no arguments
  - **Returns**: An empty string (the procedure is defined as a side effect).
  - **Example**:
    ```tcl
    proc greet {name} {
        return "Hello, $name!"
    }
    greet "World"  ;# Returns: "Hello, World!"

    proc sum {args} {
        set total 0
        foreach n $args { incr total $n }
        return $total
    }
    sum 1 2 3 4    ;# Returns: 10

    proc connect {host {port 80} {timeout 30}} {
        # port defaults to 80, timeout to 30
    }
    ```

<a id="cmd-nproc"></a>
- **nproc** - Create procedure with named arguments (Eagle extension)
  - `nproc name args body`
  - Creates a procedure that accepts named arguments (keyword arguments). Arguments are passed as `-name value` pairs.
  - **Arguments specification**: List of argument names. All arguments can be passed by name using `-argname value` syntax.
  - **Example**:
    ```tcl
    nproc connect {host port timeout} {
        puts "Connecting to $host:$port with timeout $timeout"
    }
    connect -host localhost -port 8080 -timeout 60
    ```

<a id="cmd-apply"></a>
- **apply** - Apply lambda expression
  - `apply lambdaExpr ?arg1 arg2 ...?`
  - Applies an anonymous procedure (lambda) to the given arguments. A lambda expression is a two or three element list: `{args body}` or `{args body namespace}`.
  - **Lambda structure**:
    - Element 1: Argument list (same format as `proc`)
    - Element 2: Procedure body
    - Element 3: Optional namespace context
  - **Returns**: The result of executing the lambda body.
  - **Example**:
    ```tcl
    apply {{x y} {expr {$x + $y}}} 3 4    ;# Returns: 7

    set double {{x} {expr {$x * 2}}}
    apply $double 5                        ;# Returns: 10

    # Lambda with namespace context
    apply {{} {variable counter; incr counter}} {} ::myns
    ```

<a id="cmd-napply"></a>
- **napply** - Apply lambda with named arguments (Eagle extension)
  - `napply lambdaExpr ?arg1 arg2 ...?`
  - Like `apply`, but accepts named arguments using `-name value` syntax.
  - **Example**:
    ```tcl
    napply {{x y} {expr {$x + $y}}} -x 3 -y 4    ;# Returns: 7
    ```

---

### Namespaces

Namespace commands belong to ObjectGroup: "scriptEnvironment"

Namespaces provide hierarchical organization of commands and variables, preventing name collisions and enabling modular code organization. The global namespace is `::`, and all other namespaces are nested within it.

<a id="cmd-namespace"></a>
- **namespace** - Namespace operations

  #### Creating and Managing Namespaces

  - `namespace eval name arg ?arg ...?` - Evaluates the concatenated arguments as a script in namespace *name*. Creates the namespace if it doesn't exist. This is the primary way to define namespace contents.
  - `namespace delete ?name name ...?` - Deletes the specified namespaces and all their contents (commands, variables, child namespaces).
  - `namespace exists name` - Returns 1 if namespace *name* exists, 0 otherwise.
  - `namespace enable ?enabled? ?force?` - Enables or disables namespace support (Eagle extension).

  **Example**:
  ```tcl
  namespace eval mylib {
      variable version 1.0
      proc greet {name} {
          return "Hello from mylib, $name!"
      }
  }
  mylib::greet "World"    ;# Returns: "Hello from mylib, World!"
  ```

  #### Namespace Information

  - `namespace current` - Returns the fully-qualified name of the current namespace.
  - `namespace parent ?name?` - Returns the parent namespace of *name* (or current namespace if omitted).
  - `namespace children ?name? ?pattern?` - Returns a list of child namespaces matching *pattern*.
  - `namespace descendants ?name? ?pattern?` - Returns all descendant namespaces (recursive) (Eagle extension).
  - `namespace info name` - Returns information about namespace *name* (Eagle extension).

  #### Path and Name Manipulation

  - `namespace qualifiers string` - Returns the namespace qualifiers (everything before the last `::`).
  - `namespace tail string` - Returns the simple name (after the last `::`).
  - `namespace origin name` - Returns the fully-qualified name of the original command if *name* is an imported alias.
  - `namespace which ?-command? ?-variable? name` - Returns the fully-qualified name of *name* if it exists as a command or variable.

  **Example**:
  ```tcl
  namespace qualifiers "::foo::bar::baz"  ;# Returns: ::foo::bar
  namespace tail "::foo::bar::baz"        ;# Returns: baz
  ```

  #### Exporting and Importing Commands

  - `namespace export ?-clear? ?pattern pattern ...?` - Specifies which commands in the current namespace can be imported by other namespaces. `-clear` removes all previous export patterns.
  - `namespace import ?-force? ?pattern pattern ...?` - Imports commands from other namespaces into the current namespace. `-force` overwrites existing commands.
  - `namespace forget ?pattern pattern ...?` - Removes previously imported commands.

  **Example**:
  ```tcl
  namespace eval mylib {
      namespace export greet farewell  ;# Allow these to be imported
      proc greet {name} { return "Hello, $name!" }
      proc farewell {name} { return "Goodbye, $name!" }
      proc internal {} { return "Not exported" }
  }

  namespace import mylib::*          ;# Import exported commands
  greet "World"                      ;# Can now call without qualifier
  ```

  #### Script Execution

  - `namespace code script` - Returns a script that, when evaluated, will execute *script* in the current namespace context. Useful for callbacks.
  - `namespace inscope name arg ?arg...?` - Evaluates script in namespace *name* with additional arguments appended. Similar to `namespace eval` but handles arguments differently.

  **Example**:
  ```tcl
  namespace eval myns {
      variable data "secret"
      proc showData {} { variable data; return $data }
  }
  set callback [namespace code {showData}]
  eval $callback    ;# Executes in myns context
  ```

  #### Other Operations

  - `namespace unknown ?script?` - Gets or sets the handler for unknown commands in the current namespace.
  - `namespace rename oldName newName` - Renames namespace *oldName* to *newName* (Eagle extension).
  - `namespace mappings` - Returns namespace mapping information (Eagle extension).

---

### Objects (.NET Interop)

Object commands belong to ObjectGroup: "managedEnvironment"

<a id="cmd-object"></a>
- **object** - .NET object operations (comprehensive .NET interop)

  The `object` command provides Eagle's powerful .NET interoperability, allowing scripts to create, manipulate, and invoke methods on .NET objects.

  #### Creating Objects

  - `object create ?options? typeName ?arg ...?` - Creates a new instance of the specified .NET type. Arguments are passed to the constructor.
    - **Options**: `-alias` (create named alias), `-objectname name` (specify alias name), `-type typeList` (specify parameter types for overload resolution)
    - **Returns**: An opaque object handle (e.g., `object#1`)

  **Example**:
  ```tcl
  # Create a StringBuilder
  set sb [object create System.Text.StringBuilder "Initial"]

  # Create with alias
  object create -alias System.Collections.ArrayList myList

  # Create with constructor overload selection
  set dt [object create -type {int int int} System.DateTime 2024 1 15]
  ```

  #### Invoking Members

  - `object invoke ?options? object member ?arg ...?` - Invokes a method, property, or field on *object*. This is the primary way to interact with .NET objects.
    - **Methods**: `object invoke $obj MethodName arg1 arg2`
    - **Properties (get)**: `object invoke $obj PropertyName`
    - **Properties (set)**: `object invoke $obj PropertyName value`
    - **Static members**: Use the type name instead of an object handle
    - **Options**: `-type typeList` (parameter types), `-alias` (alias the result)
  - `object invokeall ?options? object memberAndArgs ...?` - Invokes multiple members in sequence.
  - `object invokeraw ?options? object member ?arg ...?` - Invokes without automatic type conversion.

  **Example**:
  ```tcl
  set sb [object create System.Text.StringBuilder]
  object invoke $sb Append "Hello"
  object invoke $sb Append ", World!"
  set result [object invoke $sb ToString]    ;# Returns: "Hello, World!"

  # Static method
  set now [object invoke System.DateTime Now]

  # Property access
  set length [object invoke $sb Length]

  # Indexer access
  object invoke $list Item 0               ;# Get item at index 0
  object invoke $list Item 0 "newValue"    ;# Set item at index 0
  ```

  #### Object Information

  - `object exists object` - Returns 1 if *object* is a valid object handle.
  - `object isnull ?options? object` - Returns 1 if *object* is null.
  - `object isdisposed ?options? object` - Returns 1 if *object* has been disposed.
  - `object isoftype ?options? object type` - Returns 1 if *object* is an instance of *type*.
  - `object members ?options? object` - Lists all members (methods, properties, fields) of *object*.
  - `object flags object ?flags?` - Gets or sets object flags.
  - `object referencecount object` - Returns the reference count for *object*.

  **Example**:
  ```tcl
  if {[object exists $obj]} {
      set members [object members $obj]
  }
  ```

  #### Object Lifecycle

  - `object dispose ?options? object ?object ...?` - Calls Dispose() on IDisposable objects and releases the handle.
  - `object cleanup ?options?` - Cleans up unreferenced objects and runs garbage collection.
  - `object addreference object` - Adds a reference to prevent automatic cleanup.
  - `object removereference object` - Removes a reference added by `addreference`.

  **Example**:
  ```tcl
  set fh [object create System.IO.FileStream "test.txt" Create]
  try {
      # Use the file...
  } finally {
      object dispose $fh
  }
  ```

  #### Collections and Iteration

  - `object foreach varName object body` - Iterates over an IEnumerable collection, setting *varName* to each element.
  - `object lmap varName object body` - Like `foreach` but collects results into a list.

  **Example**:
  ```tcl
  set list [object create System.Collections.ArrayList]
  object invoke $list Add "one"
  object invoke $list Add "two"
  object invoke $list Add "three"

  object foreach item $list {
      puts "Item: $item"
  }
  ```

  #### Assemblies and Types

  - `object load ?options? assembly` - Loads a .NET assembly by name or path.
  - `object assemblies ?pattern?` - Lists loaded assemblies matching *pattern*.
  - `object types ?pattern?` - Lists available types matching *pattern*.
  - `object search ?options? typeName` - Searches for a type by name.
  - `object namespaces ?pattern?` - Lists .NET namespaces.
  - `object interfaces ?pattern?` - Lists available interfaces.

  **Example**:
  ```tcl
  object load System.Data
  object types *DataTable*
  ```

  #### Namespace and Type Shortcuts

  - `object import ?options? ?name name ...?` - Imports .NET namespaces, allowing unqualified type names.
  - `object unimport ?options?` - Removes imported namespaces.
  - `object declare ?options? ?name name ...?` - Declares type aliases for shorter names.
  - `object undeclare ?options?` - Removes type declarations.

  **Example**:
  ```tcl
  object import System.Text System.IO
  set sb [object create StringBuilder]   ;# No need for System.Text. prefix
  ```

  #### Aliases

  - `object alias ?options? object` - Creates a named alias for an object handle.
  - `object unalias object` - Removes an object alias.
  - `object aliasnamespaces ?pattern?` - Lists alias namespaces.
  - `object list ?pattern?` - Lists all object handles matching *pattern*.

  #### Type Conversion

  - `object type ?options? ?fromName toName...? fromName toName` - Registers custom type converters.
  - `object untype ?options?` - Removes type converters.
  - `object fromvar ?options? varName` - Gets an object reference from a variable containing an object handle.

---

### Debugging

Debug command belongs to ObjectGroup: "debug"

The `debug` command provides comprehensive debugging capabilities for Eagle scripts and the interpreter itself. It includes breakpoint management, execution control, memory analysis, and script bundling.

<a id="cmd-debug"></a>
- **debug** - Debugging operations

  #### Debugger Control

  - `debug enable ?enabled?` - Enables or disables the debugger. Without argument, returns current state.
  - `debug interactive ?enabled?` - Enables or disables interactive debugging mode. When enabled, the debugger will prompt for commands at breakpoints.
  - `debug setup ?create? ?isolated? ?createFlags? ?initializeFlags? ?scriptFlags? ?interpreterFlags?` - Initializes or configures the debugger. With *create*, creates a debug interpreter.
  - `debug status` - Returns the current status of the debugger (enabled, breakpoints, watches, etc.).
  - `debug ready ?isolated?` - Returns 1 if the debugger is ready for use.
  - `debug self ?debug? ?force?` - Enables debugging of the debugger itself (for advanced troubleshooting).

  #### Breakpoints and Execution Control

  - `debug break ?options?` - Triggers a breakpoint, pausing execution and entering the interactive debugger.
    - **Options**: `-condition expr` (break only if expression is true)
  - `debug breakpoints ?pattern?` - Lists all breakpoints matching *pattern*.
  - `debug step ?enabled?` - Enables or disables single-stepping mode. When enabled, execution pauses after each command.
  - `debug steps ?integer?` - Sets the number of steps to execute before pausing.
  - `debug suspend` - Suspends script execution at the current point.
  - `debug resume` - Resumes suspended script execution.
  - `debug halt ?result?` - Halts execution immediately, optionally with *result* as the return value.

  **Example**:
  ```tcl
  debug enable true        ;# Enable the debugger
  debug step true          ;# Enable single-stepping
  debug break              ;# Break into debugger here
  debug resume             ;# Continue execution
  ```

  #### Call Stack and Variables

  - `debug levels` - Returns information about all call stack levels.
  - `debug stack ?force?` - Returns a formatted stack trace. With *force*, includes internal frames.
  - `debug variable ?options? varName` - Returns detailed information about variable *varName*.
  - `debug watch ?varName? ?types?` - Sets a watchpoint on *varName*. *types* specifies what to watch (read, write, unset).
  - `debug lockvar enabled name` - Locks or unlocks a variable for debugging.
  - `debug lockloop enabled` - Enables or disables loop debugging.

  **Example**:
  ```tcl
  debug watch myVar write  ;# Break when myVar is written
  debug levels             ;# Show call stack
  debug variable myVar     ;# Show variable details
  ```

  #### Script Evaluation in Debug Context

  - `debug eval arg ?arg ...?` - Evaluates a script in the debug context, with access to debug state.
  - `debug run arg ?arg ...?` - Runs a script under debugger control.
  - `debug invoke ?level? cmd ?arg ...?` - Invokes a command at the specified stack level.
  - `debug subst ?-nobackslashes? ?-nocommands? ?-novariables? string` - Performs substitution with debug context.
  - `debug secureeval ?options? path arg ?arg ...?` - Evaluates a script securely in a child interpreter.

  #### Interactive Debugger

  - `debug shell ?options? ?arg ...?` - Starts an interactive debug shell.
  - `debug icommand ?command?` - Gets or sets the interactive command handler.
  - `debug iqueue ?options? ?command?` - Manages the interactive command queue.
  - `debug iresult ?result?` - Gets or sets the interactive result.

  #### Event Handlers

  These sub-commands enable or disable automatic breakpoints on specific events:

  - `debug oncancel ?enabled?` - Break when script is canceled.
  - `debug onerror ?enabled?` - Break when an error occurs.
  - `debug onexecute ?enabled?` - Break on command execution.
  - `debug onexit ?enabled?` - Break when interpreter exits.
  - `debug onreturn ?enabled?` - Break on procedure return.
  - `debug ontest ?enabled?` - Break during test execution.
  - `debug ontoken ?enabled?` - Break on token processing.

  **Example**:
  ```tcl
  debug onerror true   ;# Break into debugger on any error
  debug onreturn true  ;# Break when procedures return
  ```

  #### Debug Hooks

  - `debug hook ?options? ?pattern? ?script?` - Manages debug hooks that execute at specific points.
    - Without arguments, lists all hooks.
    - With *script*, sets a hook for events matching *pattern*.

  #### Logging and Output

  - `debug log ?options? message` - Logs a debug message with optional options for filtering and formatting.
  - `debug output message ?priority?` - Outputs a debug message with specified priority.
  - `debug write message ?priority?` - Writes a debug message to the debug output.
  - `debug trace ?options? ?message?` - Traces execution with optional message.
  - `debug vout ?channelId? ?enabled?` - Configures verbose debug output channel.

  **Example**:
  ```tcl
  debug log "Entering critical section"
  debug trace -commands "Processing item $i"
  ```

  #### Memory and Garbage Collection

  - `debug memory` - Returns detailed information about managed memory usage.
  - `debug sysmemory` - Returns system memory information.
  - `debug gcmemory ?collect?` - Returns garbage collection memory statistics. With *collect*, forces a GC.
  - `debug collect ?flags?` - Forces garbage collection with specified flags.
  - `debug cleanup ?flags?` - Cleans up debug resources with specified flags.
  - `debug purge` - Purges all debug information and resources.

  **Example**:
  ```tcl
  puts "Memory: [debug memory]"
  debug collect                ;# Force garbage collection
  puts "After GC: [debug gcmemory]"
  ```

  #### Script Bundling and Mounting

  - `debug bundle fileName ?password? ?pattern?` - Creates a script bundle (encrypted archive) containing scripts matching *pattern*.
  - `debug mount fileName ?password?` - Mounts a script bundle, making its scripts available.
  - `debug unmount fileName` - Unmounts a previously mounted bundle.
  - `debug mounts ?pattern?` - Lists mounted bundles matching *pattern*.

  **Example**:
  ```tcl
  debug bundle "scripts.bundle" "secret" "*.tcl"  ;# Create bundle
  debug mount "scripts.bundle" "secret"            ;# Mount it
  source "bundled_script.tcl"                       ;# Use bundled script
  debug unmount "scripts.bundle"                    ;# Unmount
  ```

  #### Command and Function Control

  - `debug execute name ?enabled?` - Enables or disables execution of command *name*.
  - `debug function name ?enabled?` - Enables or disables expression function *name*.
  - `debug operator name ?enabled?` - Enables or disables expression operator *name*.
  - `debug procedureflags procName ?flags?` - Gets or sets procedure flags for debugging.
  - `debug undelete ?pattern?` - Restores deleted commands matching *pattern*.

  #### History and Caching

  - `debug history ?enabled?` - Enables or disables command history tracking.
  - `debug cacheconfiguration ?settings? ?level?` - Configures debug caching behavior.
  - `debug refreshautopath ?verbose?` - Refreshes the auto-path configuration.

  #### Runtime Options

  - `debug runtimeoption add name` - Adds a runtime option.
  - `debug runtimeoption clear` - Clears all runtime options.
  - `debug runtimeoption get` - Gets current runtime options.
  - `debug runtimeoption has name` - Checks if runtime option exists.
  - `debug runtimeoption remove name` - Removes a runtime option.
  - `debug runtimeoption set list` - Sets runtime options from a list.
  - `debug runtimeoverride name` - Overrides a runtime option.

  #### Path and Configuration

  - `debug paths ?flags?` - Returns various interpreter paths.
  - `debug testpath ?path?` - Gets or sets the test path.
  - `debug types ?types?` - Gets or sets the debug types enabled.
  - `debug readonly kind enabled ?pattern?` - Sets readonly mode for specific resources.

  #### Plugin Debugging

  - `debug pluginexecute name request` - Executes a plugin command for debugging.
  - `debug pluginflags ?flags?` - Gets or sets plugin debugging flags.

  #### Other Operations

  - `debug callback ?{}|arg ...?` - Manages debug callbacks.
  - `debug complaint` - Reports a complaint (internal diagnostic).
  - `debug emergency ?options? ?level?` - Enters emergency mode for critical debugging.
  - `debug keyring` - Accesses the security keyring.
  - `debug null` - No-operation (for testing).
  - `debug result` - Returns the last debug result.
  - `debug restore ?strict? ?verbose?` - Restores debug state.
  - `debug set ?options? varName object` - Sets a debug variable.
  - `debug test ?name? ?enabled?` - Enables or disables specific tests.
  - `debug token fileName startLine endLine ?enabled?` - Enables token-level debugging for specific source locations.

---

### Interpreter Management

Interpreter commands belong to ObjectGroup: "scriptEnvironment"

The `interp` command manages child interpreters, providing sandboxing, isolation, and communication between interpreters. Child interpreters can be "safe" (restricted) or full-featured.

<a id="cmd-interp"></a>
- **interp** - Interpreter management

  #### Creating and Deleting Interpreters

  - `interp create ?-safe? ?--? ?path?` - Creates a new child interpreter.
    - `-safe` - Creates a safe interpreter with restricted capabilities (no file I/O, no exec, etc.)
    - *path* - Name for the interpreter (defaults to a generated name)
    - **Returns**: The interpreter path/name.
  - `interp delete ?path ...?` - Deletes one or more child interpreters and releases their resources.
  - `interp exists ?path?` - Returns 1 if interpreter *path* exists, 0 otherwise.
  - `interp children ?path?` - Returns a list of child interpreters. With *path*, returns children of that interpreter.
  - `interp parent ?path?` - Returns the parent interpreter path, or empty string for the root interpreter.

  **Example**:
  ```tcl
  set child [interp create -safe myChild]
  interp exists myChild       ;# Returns: 1
  interp children             ;# Returns: myChild
  interp delete myChild
  ```

  #### Evaluating Code in Interpreters

  - `interp eval path arg ?arg ...?` - Evaluates the concatenated arguments as a script in interpreter *path*.
    - **Returns**: The result of the evaluation.
  - `interp expr path arg ?arg ...?` - Evaluates an expression in interpreter *path*.
  - `interp source ?options? path fileName` - Sources a script file in interpreter *path*.
  - `interp subst ?options? path string` - Performs variable, command, and backslash substitution in interpreter *path*.
  - `interp queue path ?options? arg ?arg ...?` - Queues a script for later evaluation in interpreter *path*.

  **Example**:
  ```tcl
  set child [interp create]
  interp eval $child {
      proc greet {name} { return "Hello, $name!" }
  }
  set result [interp eval $child {greet "World"}]
  puts $result    ;# Prints: Hello, World!
  ```

  #### Variable Access Across Interpreters

  - `interp set interp varName ?newValue?` - Gets or sets a variable in interpreter *interp*.
  - `interp unset interp varName` - Unsets a variable in interpreter *interp*.

  **Example**:
  ```tcl
  interp set $child myVar "value"
  puts [interp set $child myVar]    ;# Prints: value
  ```

  #### Command Aliases

  - `interp alias childPath childCmd ?parentPath parentCmd? ?arg ...?` - Creates an alias in *childPath* that invokes *parentCmd* in *parentPath*.
    - Without *parentCmd*, returns the current alias target.
    - With empty *parentCmd* (`{}`), removes the alias.
    - Additional *arg* values are prepended to the command when invoked.
  - `interp aliases ?path? ?pattern? ?all?` - Lists aliases in interpreter *path* matching *pattern*.
  - `interp target path alias` - Returns the target interpreter for *alias* in interpreter *path*.

  **Example**:
  ```tcl
  # Allow child to use 'safeLog' which calls 'puts' in parent
  interp alias $child safeLog {} puts
  interp eval $child {safeLog "Message from child"}
  ```

  #### Hidden Commands

  Safe interpreters hide dangerous commands. These sub-commands manage hidden commands:

  - `interp hide path cmdName ?hiddenCmdName?` - Hides command *cmdName* in interpreter *path*.
  - `interp expose path hiddenCmdName ?cmdName?` - Exposes hidden command *hiddenCmdName* in interpreter *path*.
  - `interp hidden path` - Lists hidden commands in interpreter *path*.
  - `interp exposed path` - Lists exposed commands in interpreter *path*.
  - `interp invokehidden path ?options? cmd ?arg ..?` - Invokes a hidden command directly.

  **Example**:
  ```tcl
  set safe [interp create -safe]
  interp hidden $safe           ;# Lists hidden commands
  interp invokehidden $safe source "trusted_script.tcl"
  ```

  #### Security Configuration

  - `interp issafe ?path?` - Returns 1 if interpreter *path* is safe, 0 otherwise.
  - `interp makesafe ?path? ?safe? ?flags?` - Converts interpreter to safe mode.
  - `interp makestandard ?path? ?standard? ?flags?` - Converts interpreter to standard mode.
  - `interp isstandard ?path?` - Returns 1 if interpreter is standard.
  - `interp marktrusted path` - Marks interpreter as trusted (allows certain operations).
  - `interp policy ?options? path script` - Sets a security policy script that is called for sensitive operations.
  - `interp nopolicy path name` - Disables a specific policy.
  - `interp isolated ?path?` - Returns 1 if interpreter is isolated.
  - `interp issdk ?path? ?sdkType?` - Returns 1 if interpreter is SDK mode.
  - `interp immutable ?path? ?immutable?` - Gets or sets immutable mode.
  - `interp readonly ?path? ?readonly?` - Gets or sets readonly mode.
  - `interp enabled ?path? ?enabled?` - Enables or disables interpreter.

  #### Resource Limits

  These sub-commands set limits to prevent resource exhaustion:

  - `interp recursionlimit path ?limit?` - Maximum call stack depth.
  - `interp iterationlimit path ?limit?` - Maximum loop iterations.
  - `interp proclimit path ?limit?` - Maximum procedures.
  - `interp varlimit path ?limit?` - Maximum variables.
  - `interp namespacelimit path ?limit?` - Maximum namespaces.
  - `interp scopelimit path ?limit?` - Maximum scopes.
  - `interp resultlimit path ?limit?` - Maximum result size.
  - `interp callbacklimit path ?limit?` - Maximum callbacks.
  - `interp eventlimit path ?limit?` - Maximum events.
  - `interp execlimit path ?limit?` - Maximum command executions.
  - `interp readylimit path ?limit?` - Maximum ready operations.
  - `interp childlimit path ?limit?` - Maximum child interpreters.

  **Example**:
  ```tcl
  set child [interp create -safe]
  interp recursionlimit $child 100     ;# Limit stack depth
  interp iterationlimit $child 10000   ;# Limit loop iterations
  ```

  #### Timeout and Execution Control

  - `interp timeout ?path? ?newValue?` - Gets or sets the execution timeout (milliseconds).
  - `interp finallytimeout ?path? ?newValue?` - Gets or sets the finally block timeout.
  - `interp sleeptime ?path? ?newValue?` - Gets or sets the sleep time between checks.
  - `interp cancel ?-unwind? ?--? ?path? ?result?` - Cancels script execution in interpreter.
    - `-unwind` - Unwind the call stack
    - *result* - Return value for the canceled script
  - `interp resetcancel path ?options?` - Resets the cancel flag.
  - `interp watchdog ?path? ?enabled? ?flags? ?type?` - Configures the watchdog timer.

  **Example**:
  ```tcl
  interp timeout $child 5000  ;# 5 second timeout
  interp eval $child {
      # Long-running script...
  }
  ```

  #### Command Management

  - `interp addcommands ?options? path pattern` - Adds commands matching *pattern* to interpreter.
  - `interp rename ?options? path oldName newName` - Renames a command in interpreter *path*.
  - `interp stub ?options? path name` - Creates a stub command.
  - `interp subcommand ?options? path cmdName subCmdName ?command?` - Adds a sub-command to an ensemble.

  #### Object Sharing

  - `interp shareobject interp objectName` - Shares an opaque object with interpreter *interp*.
  - `interp shareinterp interp objectName` - Shares the interpreter itself as an object.

  #### Script File Operations

  - `interp readorgetscriptfile ?options? path fileName` - Reads or retrieves a script file for interpreter *path*.
  - `interp maybereadorgetscriptfile ?options? path fileName` - Similar to above, but may skip if not needed.

  #### Background Error Handling

  - `interp bgerror path ?cmdPrefix?` - Gets or sets the background error handler for interpreter *path*. The handler is called when an error occurs in event handlers or callbacks.

  #### Service Operations

  - `interp service path ?options?` - Performs service-related operations on interpreter *path*.

---

### Packages

Package commands belong to ObjectGroup: "scriptEnvironment"

The `package` command manages Eagle packages - reusable collections of procedures and commands. It handles versioning, dependencies, and lazy loading of packages.

<a id="cmd-package"></a>
- **package** - Package management

  #### Loading and Requiring Packages

  - `package require ?options? package ?version?` - Loads a package if not already present.
    - If *version* is specified, ensures the loaded version satisfies the requirement.
    - Searches `auto_path` directories for the package.
    - **Options**: `-exact` (require exact version match)
    - **Returns**: The version of the loaded package.
  - `package present ?options? package ?version?` - Checks if a package is already loaded.
    - Returns the version if present, otherwise raises an error.
    - Does not attempt to load the package.

  **Example**:
  ```tcl
  package require http 2.0     ;# Load http package, version 2.0 or later
  package require -exact json 1.0  ;# Load exactly version 1.0
  ```

  #### Providing Packages

  - `package provide package ?version?` - Declares that the current script provides *package* at *version*.
    - Without *version*, returns the version if already provided.
    - Typically placed at the beginning of package scripts.

  **Example**:
  ```tcl
  # In mypackage.tcl
  package provide mypackage 1.0
  proc mypackage::init {} { ... }
  ```

  #### Package Index and Discovery

  - `package ifneeded package version ?script? ?flags?` - Registers a script to load *package* at *version*.
    - Without *script*, returns the current script.
    - The script is executed when `package require` is called.
    - This is typically set in `pkgIndex.tcl` files.
  - `package scan ?options? ?dir dir ...?` - Scans directories for packages and builds index information.
    - If no directories specified, scans `auto_path`.
  - `package unknown ?command?` - Gets or sets the handler called when a package is not found.
    - The default handler searches `auto_path` for `pkgIndex.tcl` files.
  - `package indexes ?pattern?` - Lists package index files matching *pattern*.

  **Example**:
  ```tcl
  # In pkgIndex.tcl
  package ifneeded mypackage 1.0 [list source [file join $dir mypackage.tcl]]
  ```

  #### Querying Package Information

  - `package names ?pattern?` - Returns a list of all known package names matching *pattern*.
  - `package versions package` - Returns a list of all known versions of *package*.
  - `package loaded ?pattern?` - Returns a list of loaded packages matching *pattern*.
  - `package vloaded ?pattern?` - Returns loaded packages with version information.
  - `package pending ?name?` - Returns packages that are being loaded (for dependency tracking).
  - `package info name` - Returns detailed information about package *name*.

  **Example**:
  ```tcl
  puts [package names]          ;# List all known packages
  puts [package versions http]  ;# List versions of http package
  puts [package loaded]         ;# List loaded packages
  ```

  #### Version Comparison

  - `package vcompare version1 version2` - Compares two version strings.
    - **Returns**: -1 if *version1* < *version2*, 0 if equal, 1 if *version1* > *version2*.
  - `package vsatisfies version1 version2` - Checks if *version1* satisfies requirement *version2*.
    - **Returns**: 1 if satisfied, 0 otherwise.
  - `package vsort version1 version2` - Sorts two versions.

  **Example**:
  ```tcl
  package vcompare 1.0 2.0        ;# Returns: -1
  package vcompare 2.1 2.1        ;# Returns: 0
  package vsatisfies 2.5 2.0      ;# Returns: 1 (2.5 satisfies >=2.0)
  package vsatisfies 1.5 2.0      ;# Returns: 0
  ```

  #### Package State Management

  - `package forget ?package package ...?` - Removes packages from the known list. Does not unload already-loaded packages.
  - `package withdraw package ?version?` - Withdraws a package version, making it unavailable.
  - `package absent ?options? package ?version?` - Marks a package as explicitly absent.
  - `package reset` - Resets package management state.

  #### Package Aliases

  - `package alias ?options? name ?package? ?version?` - Creates an alias *name* for *package*.
    - Allows using a different name to refer to a package.
  - `package aliases ?pattern?` - Lists package aliases matching *pattern*.

  #### Utility

  - `package relativefilename fileName ?type?` - Returns the filename relative to the package directory.

---

### Testing

Test commands belong to ObjectGroup: "test"

Eagle provides built-in test commands for unit testing. These commands integrate with the test framework infrastructure and support constraints, setup/cleanup, and result comparison.

- **test1** - Basic test command (Eagle-specific)
  - `test1 name description constraints body result`
  - Defines and executes a simple test case.
  - **Parameters**:
    - *name* - Unique identifier for the test (e.g., "myproc-1.1")
    - *description* - Human-readable description of what is being tested
    - *constraints* - List of constraints that must be satisfied for the test to run (e.g., `{unix}`, `{knownBug}`)
    - *body* - Script to execute as the test
    - *result* - Expected result to compare against the body's result
  - **Returns**: Test pass/fail status.

  **Example**:
  ```tcl
  test1 "string-length-1.1" "Test string length" {} {
      string length "hello"
  } {5}

  test1 "math-1.1" "Test basic arithmetic" {} {
      expr {2 + 2}
  } {4}
  ```

- **test2** - Advanced test command (Eagle-specific)
  - `test2 name description ?options?`
  - Defines and executes an advanced test case with full options.
  - **Options**:
    - `-constraints list` - Constraints that must be satisfied
    - `-setup script` - Script to run before the test body
    - `-body script` - The test script to execute
    - `-cleanup script` - Script to run after the test (always runs, even on error)
    - `-result value` - Expected result value
    - `-output pattern` - Expected stdout output pattern
    - `-errorOutput pattern` - Expected stderr output pattern
    - `-returnCodes codes` - Expected return codes (ok, error, return, break, continue)
    - `-match mode` - Matching mode: exact, glob, regexp
  - **Returns**: Test pass/fail status with detailed diagnostics on failure.

  **Example**:
  ```tcl
  test2 "file-read-1.1" "Test file reading" \
      -constraints {tempdir} \
      -setup {
          set f [open test.txt w]
          puts $f "test data"
          close $f
      } \
      -body {
          set f [open test.txt r]
          set data [read $f]
          close $f
          return $data
      } \
      -cleanup {
          file delete test.txt
      } \
      -result "test data\n" \
      -match exact

  test2 "error-1.1" "Test error handling" \
      -body {
          error "expected error"
      } \
      -returnCodes error \
      -result "expected error"
  ```

  #### Common Test Constraints

  Constraints control when tests run:
  - `unix`, `win`, `mac` - Platform-specific tests
  - `knownBug` - Known issues (skipped by default)
  - `interactive` - Requires user interaction
  - `tempdir` - Requires temp directory access
  - `network` - Requires network access
  - `longRunning` - Skipped in quick test runs

---

### Database (SQL)

SQL commands belong to ObjectGroup: "managedEnvironment"

The `sql` command provides database connectivity using ADO.NET, supporting any database with a .NET provider (SQL Server, SQLite, MySQL, PostgreSQL, etc.).

<a id="cmd-sql"></a>
- **sql** - Database operations

  #### Connection Management

  - `sql open ?options? connectionString` - Opens a database connection using the ADO.NET connection string.
    - **Options**: `-type providerType` (specify the connection type, e.g., `System.Data.SqlClient.SqlConnection`)
    - **Returns**: A connection handle.
  - `sql close connection` - Closes the database connection and releases resources.
  - `sql isopen connection` - Returns 1 if the connection is open, 0 otherwise.
  - `sql connection connection` - Returns information about the connection.

  **Example**:
  ```tcl
  set conn [sql open "Data Source=mydb.sqlite;Version=3;"]
  if {[sql isopen $conn]} {
      # Use connection...
  }
  sql close $conn
  ```

  #### Executing Queries

  - `sql execute ?options? connection query ?{paramName ?paramType? paramValue ?paramSize?} ...?` - Executes a SQL query with optional parameters.
    - **For SELECT**: Returns results as a list of dictionaries (one per row)
    - **For INSERT/UPDATE/DELETE**: Returns the number of affected rows
    - **Parameters**: Specified as lists `{name type value}` for parameterized queries (prevents SQL injection)
    - **Options**: `-time` (measure execution time)

  - `sql foreach ?options? connection query ?params...? body` - Executes a query and iterates over results, executing *body* for each row with column values accessible as variables.

  **Example**:
  ```tcl
  # Simple scalar query
  set count [sql execute -execute scalar $conn "SELECT COUNT(*) FROM users"]

  # Reader query with nested list format
  set results [sql execute -execute reader -format nestedlist $conn \
      "SELECT name, age FROM users"]
  foreach row $results {
      lassign $row name age
      puts "Name: $name, Age: $age"
  }

  # Parameterized query (safe from SQL injection)
  set results [sql execute -execute reader $conn \
      "SELECT * FROM users WHERE age > @minAge" \
      {minAge Int32 21}]

  # Iteration style with sql foreach
  sql foreach $conn "SELECT name, age FROM users" {
      puts "Name: $name, Age: $age"
  }
  ```

  #### Transaction Management

  - `sql transaction begin connection` - Begins a new transaction. Returns a transaction handle.
  - `sql transaction commit transaction` - Commits the transaction.
  - `sql transaction rollback transaction` - Rolls back the transaction.
  - `sql hasbegun transaction ?connection?` - Returns 1 if a transaction is active.

  **Example**:
  ```tcl
  set trans [sql transaction begin $conn]
  try {
      sql execute $conn "INSERT INTO users (name) VALUES (@name)" {name String "Alice"}
      sql execute $conn "INSERT INTO users (name) VALUES (@name)" {name String "Bob"}
      sql transaction commit $trans
  } on error {msg} {
      sql transaction rollback $trans
      error "Transaction failed: $msg"
  }
  ```

  #### Metadata

  - `sql types ?pattern?` - Lists available SQL/database types matching *pattern*.

---

### Network and URI

Network commands belong to ObjectGroup: "network"

<a id="cmd-socket"></a>
- **socket** - Socket operations

  Creates TCP socket connections for network communication.

  - `socket ?options? host port` - Creates a client socket connected to *host*:*port*.
    - **Options**:
      - `-myaddr addr` - Local address to bind to
      - `-myport port` - Local port to bind to
      - `-async` - Connect asynchronously (non-blocking)
    - **Returns**: A channel identifier for the socket.

  - `socket -server command ?-myaddr addr? port` - Creates a server socket listening on *port*.
    - When a client connects, *command* is called with: `command channel clientAddr clientPort`
    - **Returns**: A channel identifier for the listening socket.

  **Example**:
  ```tcl
  # Client
  set sock [socket localhost 8080]
  puts $sock "Hello, server!"
  flush $sock
  gets $sock response
  close $sock

  # Server
  proc handleClient {chan addr port} {
      gets $chan line
      puts $chan "Echo: $line"
      close $chan
  }
  set server [socket -server handleClient 8080]
  vwait forever
  ```

<a id="cmd-uri"></a>
- **uri** - URI operations (Eagle extension)

  Comprehensive URI handling and HTTP client functionality.

  #### URI Construction and Parsing

  - `uri create scheme host ?options?` - Creates a URI from components.
  - `uri parse uri` - Parses *uri* into a dictionary with keys: scheme, host, port, path, query, fragment.
  - `uri join name ?name ...?` - Joins URI path components.
  - `uri host uri` - Returns the host portion of *uri*.
  - `uri scheme name` - Returns the scheme of *uri*.

  #### URI Validation and Comparison

  - `uri isvalid uri ?kind?` - Returns 1 if *uri* is valid. *kind* can specify URI type (absolute, relative).
  - `uri compare ?options? uri1 uri2` - Compares two URIs (-1, 0, or 1).

  #### Encoding

  - `uri escape type string` - URL-encodes *string*. *type* specifies what to escape (path, query, etc.).
  - `uri unescape string` - URL-decodes *string*.

  #### HTTP Operations

  - `uri get ?options? uri ?argument?` - Performs an HTTP GET request.
    - **Options**: `-headers dict` (custom headers), `-timeout ms` (timeout)
    - **Returns**: Response body (or saves to file with appropriate options).

  - `uri post ?options? uri ?argument?` - Performs an HTTP POST request.
    - *argument* is the POST body
    - **Options**: `-contenttype type` (Content-Type header), `-headers dict`

  - `uri download ?options? uri ?argument?` - Downloads content from *uri* to a file.
  - `uri upload ?options? uri ?argument?` - Uploads content to *uri*.

  **Example**:
  ```tcl
  # Simple GET
  set html [uri get "https://example.com/"]

  # POST with data
  set response [uri post -contenttype "application/json" \
      "https://api.example.com/data" \
      {{"name":"value"}}]

  # Download file
  uri download "https://example.com/file.zip" "/tmp/file.zip"
  ```

  #### Network Utilities

  - `uri ping hostOrUri timeout` - Pings *host* with *timeout* milliseconds. Returns 1 if reachable.
  - `uri time` - Gets current time from a network time source.
  - `uri offline ?enabled?` - Gets or sets offline mode (disables network operations).
  - `uri security` - Returns information about security settings (TLS versions, etc.).
  - `uri softwareupdates ?trusted? ?exclusive?` - Checks for software updates.

---

### XML

XML commands belong to ObjectGroup: "managedEnvironment"

The `xml` command provides XML processing capabilities using the .NET XML infrastructure.

<a id="cmd-xml"></a>
- **xml** - XML operations

  #### Serialization

  - `xml serialize ?options? type object` - Converts a .NET object to its XML representation using XmlSerializer.
    - *type* - The .NET type name for serialization
    - *object* - The object handle to serialize
    - **Options**: `-encoding name` (character encoding)
    - **Returns**: XML string representation.

  - `xml deserialize ?options? type xml` - Creates a .NET object from XML data.
    - *type* - The .NET type to deserialize into
    - *xml* - The XML string to parse
    - **Returns**: Object handle for the deserialized object.

  **Example**:
  ```tcl
  # Serialize an object to XML
  set xmlStr [xml serialize MyNamespace.Person $personObj]

  # Deserialize XML back to an object
  set newPerson [xml deserialize MyNamespace.Person $xmlStr]
  ```

  #### Iteration

  - `xml foreach ?options? varName xml body` - Iterates over XML elements, setting *varName* to each element node and executing *body*.
    - **Options**: `-xpath expression` (filter elements with XPath)
    - Useful for processing XML documents element by element.

  **Example**:
  ```tcl
  set xmlData {<items><item>A</item><item>B</item><item>C</item></items>}
  xml foreach node $xmlData {
      puts "Element: $node"
  }
  ```

  #### Validation

  - `xml validate schemaXml documentXml` - Validates *documentXml* against the XML Schema (XSD) in *schemaXml*.
    - **Returns**: 1 if valid, raises error if invalid.

  **Example**:
  ```tcl
  set schema {<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">...</xs:schema>}
  set doc {<root>...</root>}
  if {[xml validate $schema $doc]} {
      puts "Document is valid"
  }
  ```

---

### Tcl Integration

Tcl commands belong to ObjectGroup: "nativeEnvironment"

Eagle can interoperate with native Tcl interpreters, allowing scripts to leverage both Eagle's .NET integration and Tcl's extensive library ecosystem. This requires Tcl to be installed and the Eagle Tcl integration to be enabled at build time.

<a id="cmd-tcl"></a>
- **tcl** - Tcl integration

  #### Library and Interpreter Management

  - `tcl load ?options? ?path?` - Loads the native Tcl library (DLL/shared library). Must be called before using other Tcl commands.
    - *path* - Optional path to the Tcl library
    - **Options**: `-version range` (specify acceptable Tcl version range)
  - `tcl unload` - Unloads the Tcl library.
  - `tcl available ?options? ?path? ?pattern?` - Checks if Tcl is available without loading it.
  - `tcl ready ?interp?` - Returns 1 if Tcl is loaded and ready for use.
  - `tcl build` - Returns Tcl build information.
  - `tcl module ?full?` - Returns information about the loaded Tcl module.

  **Example**:
  ```tcl
  tcl load                    ;# Load default Tcl library
  if {[tcl ready]} {
      puts "Tcl version: [tcl build]"
  }
  ```

  #### Creating and Managing Tcl Interpreters

  - `tcl create ?options?` - Creates a new Tcl interpreter. Returns an interpreter handle.
  - `tcl delete interp` - Deletes a Tcl interpreter.
  - `tcl exists interp` - Returns 1 if *interp* is a valid Tcl interpreter.
  - `tcl interps ?pattern?` - Lists all Tcl interpreters matching *pattern*.
  - `tcl primary` - Returns the primary Tcl interpreter handle.
  - `tcl active interp` - Gets or sets the active Tcl interpreter.
  - `tcl preserve interp` - Increments the interpreter's reference count.
  - `tcl release interp` - Decrements the interpreter's reference count.

  **Example**:
  ```tcl
  tcl load
  set tclInterp [tcl create]
  # Use the interpreter...
  tcl delete $tclInterp
  ```

  #### Evaluating Tcl Code

  - `tcl eval ?options? interp arg ?arg ...?` - Evaluates a script in the Tcl interpreter.
    - Concatenates all *arg* values and evaluates as a Tcl script
    - **Returns**: The result of the Tcl evaluation.
  - `tcl expr ?options? interp arg ?arg ...?` - Evaluates an expression in Tcl.
  - `tcl subst ?options? interp string` - Performs Tcl substitution on *string*.
  - `tcl source ?options? interp fileName` - Sources a Tcl file in the interpreter.
  - `tcl result interp` - Returns the last result from the interpreter.

  **Example**:
  ```tcl
  tcl load
  set interp [tcl create]

  # Evaluate Tcl code
  tcl eval $interp {
      proc greet {name} {
          return "Hello from Tcl, $name!"
      }
  }
  set greeting [tcl eval $interp {greet "Eagle"}]
  puts $greeting    ;# "Hello from Tcl, Eagle!"

  tcl delete $interp
  ```

  #### Variable Access

  - `tcl set interp varName ?newValue?` - Gets or sets a variable in the Tcl interpreter.
  - `tcl unset interp varName` - Unsets a variable in the Tcl interpreter.

  **Example**:
  ```tcl
  tcl set $interp myVar "Hello"
  set value [tcl set $interp myVar]    ;# Get the value
  tcl unset $interp myVar
  ```

  #### Command Bridging

  - `tcl command create ?options? srcCmd interp targetCmd` - Creates a bridge allowing Eagle commands to be called from Tcl (or vice versa).
  - `tcl command delete interp targetCmd` - Removes a bridged command.
  - `tcl command exists interp targetCmd` - Checks if a bridged command exists.
  - `tcl command list ?pattern?` - Lists bridged commands.

  #### Script Control

  - `tcl cancel ?options? path ?result?` - Cancels script execution in a Tcl interpreter.
  - `tcl canceled interp` - Checks if the interpreter has been canceled.
  - `tcl resetcancel ?options? interp` - Resets the canceled state.
  - `tcl complete command` - Returns 1 if *command* is a complete Tcl command (balanced braces, etc.).

  #### Other Operations

  - `tcl convert interp string type` - Converts a value to the specified Tcl type.
  - `tcl types interp` - Lists available Tcl types.
  - `tcl threads ?pattern?` - Lists Tcl threads.
  - `tcl queue ?options? interp arg ?arg ...?` - Queues a script for later execution.
  - `tcl find ?options? ?path? ?pattern?` - Finds Tcl installations.
  - `tcl select ?options? ?path?` - Selects a Tcl installation.
  - `tcl errorline interp ?line?` - Gets or sets the error line number.
  - `tcl exceptions ?exceptions?` - Gets or sets exception handling behavior.
  - `tcl versionrange ?options?` - Gets the supported Tcl version range.
  - `tcl update ?options?` - Update Tcl
  - `tcl versionrange ?options?` - Get version range

---

### Expression Evaluation

Expression commands belong to ObjectGroup: "expression"

<a id="cmd-expr"></a>
- **expr** - Evaluate expression
  - `expr arg ?arg ...?`

<a id="cmd-fpclassify"></a>
- **fpclassify** - Classify floating point number
  - `fpclassify value`

- **incr** - Increment variable (see Variables)

---

### Mathematical Functions

Mathematical functions are used within expressions (via `expr`) to perform calculations. Functions are called using the syntax `func(arg1, arg2, ...)` within an expression.

#### Trigonometric Functions (ObjectGroup: "trigonometric")

- **acos(x)** - Arc cosine (inverse cosine)
  - Returns the arc cosine of x in radians

- **asin(x)** - Arc sine (inverse sine)
  - Returns the arc sine of x in radians

- **atan(x)** - Arc tangent (inverse tangent)
  - Returns the arc tangent of x in radians

- **atan2(y, x)** - Two-argument arc tangent
  - Returns the arc tangent of y/x, using the signs to determine the quadrant

- **cos(x)** - Cosine
  - Returns the cosine of x (x in radians)

- **cosh(x)** - Hyperbolic cosine
  - Returns the hyperbolic cosine of x

- **sin(x)** - Sine
  - Returns the sine of x (x in radians)

- **sinh(x)** - Hyperbolic sine
  - Returns the hyperbolic sine of x

- **tan(x)** - Tangent
  - Returns the tangent of x (x in radians)

- **tanh(x)** - Hyperbolic tangent
  - Returns the hyperbolic tangent of x

#### Logarithmic and Exponential Functions (ObjectGroup: "logarithmic", "exponential")

- **exp(x)** - Exponential
  - Returns e raised to the power x

- **log(x)** - Natural logarithm
  - Returns the natural logarithm (base e) of x

- **log10(x)** - Base-10 logarithm
  - Returns the base-10 logarithm of x

- **log2(x)** - Base-2 logarithm (Eagle extension)
  - Returns the base-2 logarithm of x

- **logx(x, base)** - Arbitrary base logarithm (Eagle extension)
  - Returns the logarithm of x with the specified base

- **pow(x, y)** - Power
  - Returns x raised to the power y

- **sqrt(x)** - Square root
  - Returns the square root of x

#### Rounding Functions (ObjectGroup: "rounding")

- **ceil(x)** - Ceiling
  - Returns the smallest integer greater than or equal to x

- **floor(x)** - Floor
  - Returns the largest integer less than or equal to x

- **round(x)** - Round to nearest integer
  - Returns x rounded to the nearest integer

- **round2(x, digits)** - Round to specified decimal places (Eagle extension)
  - Returns x rounded to the specified number of decimal digits

- **round3(x, digits, mode)** - Round with mode (Eagle extension)
  - Returns x rounded to specified digits using the specified rounding mode

- **truncate(x)** - Truncate toward zero (Eagle extension)
  - Returns x with the fractional part removed

#### Component Functions (ObjectGroup: "component")

- **abs(x)** - Absolute value
  - Returns the absolute value of x

- **fmod(x, y)** - Floating-point modulus
  - Returns the floating-point remainder of x/y

- **hypot(x, y)** - Hypotenuse
  - Returns sqrt(x² + y²) without intermediate overflow

- **sign(x)** - Sign (Eagle extension)
  - Returns -1, 0, or 1 depending on the sign of x

#### Aggregate Functions (ObjectGroup: "aggregate")

- **max(x, y, ...)** - Maximum
  - Returns the maximum value among all arguments

- **min(x, y, ...)** - Minimum
  - Returns the minimum value among all arguments

#### Indicator Functions (ObjectGroup: "indicator")

- **isfinite(x)** - Check if finite (Eagle extension)
  - Returns true if x is a finite number

- **isinf(x)** - Check if infinite (Eagle extension)
  - Returns true if x is positive or negative infinity

- **isnan(x)** - Check if NaN
  - Returns true if x is Not-a-Number

- **isnormal(x)** - Check if normal (Eagle extension)
  - Returns true if x is a normal floating-point number

- **issubnormal(x)** - Check if subnormal (Eagle extension)
  - Returns true if x is a subnormal (denormalized) number

- **isunordered(x, y)** - Check if unordered (Eagle extension)
  - Returns true if either x or y is NaN

#### Random Number Functions (ObjectGroup: "random")

- **rand()** - Random float
  - Returns a random floating-point number in [0, 1)

- **random()** - Cryptographic random integer (Eagle extension)
  - Returns a cryptographically secure random 64-bit integer

- **randstr(length, ?charset?)** - Random string (Eagle extension)
  - Returns a random string of the specified length

- **srand(seed)** - Seed random generator
  - Seeds the random number generator with the specified value

#### Conversion Functions (ObjectGroup: "conversion")

- **bool(x)** - Convert to boolean
  - Converts x to a boolean value

- **double(x)** - Convert to double
  - Converts x to a double-precision floating-point number

- **int(x)** - Convert to integer
  - Converts x to an integer (truncates toward zero)

- **entier(x)** - Convert to arbitrary-precision integer
  - Converts x to an arbitrary-precision integer

- **wide(x)** - Convert to wide (64-bit) integer
  - Converts x to a 64-bit integer

- **decimal(x)** - Convert to decimal (Eagle extension)
  - Converts x to a decimal number

#### Type and Constant Functions

- **e()** - Euler's number (ObjectGroup: "constant")
  - Returns the mathematical constant e (≈ 2.71828...)

- **pi()** - Pi (ObjectGroup: "constant")
  - Returns the mathematical constant π (≈ 3.14159...)

- **epsilon()** - Machine epsilon (Eagle extension, ObjectGroup: "constant")
  - Returns the smallest positive number such that 1.0 + epsilon ≠ 1.0

- **typeof(x)** - Get type name (Eagle extension, ObjectGroup: "introspection")
  - Returns the type name of the value x

- **datetime(x)** - DateTime operations (Eagle extension)
  - Converts or operates on DateTime values

- **timespan(x)** - TimeSpan operations (Eagle extension)
  - Converts or operates on TimeSpan values

#### Utility Functions

- **flags(x)** - Flags operations (Eagle extension)
  - Performs operations on flag/enum values

- **list(...)** - List operations (Eagle extension)
  - Creates or operates on list values

---

### Expression Operators

Operators are used within expressions to perform calculations, comparisons, and logical operations. Eagle supports both infix notation (`a + b`) and prefix function-call notation (`+(a, b)`).

#### Arithmetic Operators (ObjectGroup: "arithmetic")

| Operator | Name | Description |
|----------|------|-------------|
| `+` | Plus | Unary positive or binary addition |
| `-` | Minus | Unary negation or binary subtraction |
| `*` | Multiply | Multiplication |
| `/` | Divide | Division |
| `%` | Modulus | Integer modulus (remainder) |
| `**` | Exponent | Exponentiation (x raised to power y) |

#### Comparison Operators (ObjectGroup: "comparison")

| Operator | Name | Description |
|----------|------|-------------|
| `==` | Equal | Numeric equality comparison |
| `!=` | NotEqual | Numeric inequality comparison |
| `<` | LessThan | Less than comparison |
| `>` | GreaterThan | Greater than comparison |
| `<=` | LessThanOrEqualTo | Less than or equal comparison |
| `>=` | GreaterThanOrEqualTo | Greater than or equal comparison |

#### String Comparison Operators (ObjectGroup: "equality")

| Operator | Name | Description |
|----------|------|-------------|
| `eq` | StringEqual | String equality comparison |
| `ne` | StringNotEqual | String inequality comparison |
| `lt` | StringLessThan | String less than (lexicographic) |
| `gt` | StringGreaterThan | String greater than (lexicographic) |
| `le` | StringLessThanOrEqualTo | String less than or equal |
| `ge` | StringGreaterThanOrEqualTo | String greater than or equal |

#### Logical Operators (ObjectGroup: "logical")

| Operator | Name | Description |
|----------|------|-------------|
| `!` | LogicalNot | Logical NOT (unary) |
| `&&` | LogicalAnd | Logical AND (short-circuit evaluation) |
| `\|\|` | LogicalOr | Logical OR (short-circuit evaluation) |
| `^^` | LogicalXor | Logical XOR (Eagle extension) |
| `->` | LogicalImp | Logical implication (Eagle extension) |
| `<->` | LogicalEqv | Logical equivalence (Eagle extension) |

#### Bitwise Operators (ObjectGroup: "bitwise")

| Operator | Name | Description |
|----------|------|-------------|
| `~` | BitwiseNot | Bitwise NOT (one's complement, unary) |
| `&` | BitwiseAnd | Bitwise AND |
| `\|` | BitwiseOr | Bitwise OR |
| `^` | BitwiseXor | Bitwise XOR |
| `~&` | BitwiseEqv | Bitwise equivalence (Eagle extension) |
| `~\|` | BitwiseImp | Bitwise implication (Eagle extension) |

#### Shift and Rotate Operators (ObjectGroup: "shift")

| Operator | Name | Description |
|----------|------|-------------|
| `<<` | LeftShift | Left bit shift |
| `>>` | RightShift | Right bit shift (arithmetic) |
| `<<<` | LeftRotate | Left bit rotate (Eagle extension) |
| `>>>` | RightRotate | Right bit rotate (Eagle extension) |

#### List Membership Operators (ObjectGroup: "membership")

| Operator | Name | Description |
|----------|------|-------------|
| `in` | ListIn | Check if string element is in list (no numeric conversion) |
| `ni` | ListNotIn | Check if string element is not in list (no numeric conversion) |

#### Conditional Operator (ObjectGroup: "conditional")

| Operator | Name | Description |
|----------|------|-------------|
| `? :` | Question | Ternary conditional: `condition ? trueValue : falseValue` |

#### Variable Assignment Operator (ObjectGroup: "assignment")

| Operator | Name | Description |
|----------|------|-------------|
| `:=` | VariableAssignment | Variable assignment within expression (Eagle extension) |

**Note**: The variable name must be quoted when using the variable assignment operator. For example: `expr {"x" := 5}` assigns the value 5 to variable x.

#### Operator Precedence (highest to lowest)

1. Function calls, parentheses
2. `!`, `~`, unary `+`, unary `-` (right-to-left)
3. `**` (right-to-left)
4. `*`, `/`, `%`
5. `+`, `-`
6. `<<`, `>>`, `<<<`, `>>>`
7. `<`, `>`, `<=`, `>=`
8. `==`, `!=`
9. `eq`, `ne`, `lt`, `gt`, `le`, `ge`
10. `in`, `ni`
11. `&`
12. `^`
13. `|`
14. `~&`, `~|`
15. `&&`
16. `||`
17. `^^`
18. `->`, `<->`
19. `? :`
20. `:=`

---

### Time and Clock

Time commands belong to ObjectGroup: "time"

<a id="cmd-clock"></a>
- **clock** - Clock and time operations

  The `clock` command provides comprehensive date/time functionality including formatting, parsing, and high-resolution timing.

  #### Getting Current Time

  - `clock seconds ?epoch?` - Returns the current time as seconds since the epoch (Jan 1, 1970 UTC). This is the most common way to get the current time.
  - `clock milliseconds ?epoch?` - Returns current time in milliseconds since the epoch.
  - `clock microseconds ?epoch?` - Returns current time in microseconds since the epoch.
  - `clock clicks ?options?` - Returns a high-resolution timer value for measuring elapsed time.
    - **Options**: `-milliseconds` (use milliseconds resolution)
  - `clock now ?-gmt boolean?` - Returns current time as a DateTime object (Eagle extension).

  **Example**:
  ```tcl
  set timestamp [clock seconds]
  set ms [clock milliseconds]
  ```

  #### Formatting Time

  - `clock format clockValue ?options?` - Converts a timestamp to a human-readable string.
    - *clockValue* - Seconds since epoch (from `clock seconds`)
    - **Options**:
      - `-format string` - Format string with % specifiers (see below)
      - `-gmt boolean` - Use GMT/UTC instead of local time
      - `-locale name` - Use specified locale
    - **Format specifiers**: `%Y` (year), `%m` (month), `%d` (day), `%H` (hour), `%M` (minute), `%S` (second), `%A` (weekday name), `%B` (month name), `%Z` (timezone), and many more.

  **Example**:
  ```tcl
  set now [clock seconds]
  clock format $now -format "%Y-%m-%d %H:%M:%S"   ;# 2024-01-15 14:30:00
  clock format $now -format "%A, %B %d, %Y"       ;# Monday, January 15, 2024
  clock format $now -gmt true -format "%H:%M UTC" ;# 19:30 UTC
  ```

  #### Parsing Time

  - `clock scan dateString ?options?` - Parses a date/time string and returns seconds since epoch.
    - **Options**:
      - `-format string` - Expected format of the input string
      - `-base clockValue` - Base time for relative expressions
      - `-gmt boolean` - Input is in GMT/UTC
    - Supports natural language expressions like "tomorrow", "next week", "+3 days".

  **Example**:
  ```tcl
  clock scan "2024-01-15"
  clock scan "Jan 15, 2024 2:30pm" -format "%b %d, %Y %I:%M%p"
  clock scan "tomorrow"
  clock scan "+1 week" -base [clock seconds]
  ```

  #### Validation and Utilities

  - `clock isvalid dateString` - Returns 1 if *dateString* can be parsed as a valid date (Eagle extension).
  - `clock monthdays ?month?` - Returns the number of days in *month* (Eagle extension).
  - `clock days ?options? ?dateString?` - Returns day-related information (Eagle extension).
  - `clock duration ?options? startDateString endDateString` - Calculates the duration between two dates (Eagle extension).

  #### Performance Timing (Eagle extensions)

  - `clock start` - Starts a high-resolution timer. Returns a start token.
  - `clock stop startCount` - Stops the timer started by `clock start` and returns elapsed time.

  **Example**:
  ```tcl
  set start [clock start]
  # ... code to measure ...
  set elapsed [clock stop $start]
  puts "Elapsed: $elapsed"
  ```

  #### File Time Conversion

  - `clock filetime fileTimeValue ?options?` - Converts Windows FILETIME values to/from clock values (Eagle extension).

<a id="cmd-time"></a>
- **time** - Time script execution
  - `time script ?count? ?options?`
  - Executes *script* multiple times and returns timing information. This is the standard way to benchmark code.
  - *count* - Number of iterations (default: 1)
  - **Returns**: A string like "X microseconds per iteration" (average time).

  **Example**:
  ```tcl
  time {expr {sqrt(2.0)}} 10000
  # Returns something like: "2.5 microseconds per iteration"

  time {lsort $bigList} 100
  ```

---

### Event Management

Event commands belong to ObjectGroup: "event"

Eagle's event loop allows asynchronous operations, timed callbacks, and idle processing.

<a id="cmd-after"></a>
- **after** - Execute script after delay

  #### Scheduling Delayed Execution

  - `after milliseconds` - Pauses execution for *milliseconds* (synchronous sleep). Use sparingly as it blocks the interpreter.
  - `after milliseconds arg ?arg ...?` - Schedules *script* (concatenated args) to execute after *milliseconds*. Returns an event ID.
  - `after idle arg ?arg ...?` - Schedules *script* to execute when the interpreter becomes idle.

  **Example**:
  ```tcl
  # Sleep for 1 second
  after 1000

  # Schedule callback in 5 seconds
  set id [after 5000 {puts "Timer fired!"}]

  # Execute when idle
  after idle {cleanup}
  ```

  #### Managing Scheduled Events

  - `after cancel arg ?arg ...?` - Cancels a scheduled event. *arg* can be the event ID or the script.
  - `after info ?id?` - Without *id*, returns list of all pending event IDs. With *id*, returns information about that event.
  - `after clear` - Cancels all scheduled events (Eagle extension).

  **Example**:
  ```tcl
  set id [after 5000 {puts "Hello"}]
  after cancel $id                    ;# Cancel by ID
  after cancel {puts "Hello"}         ;# Cancel by script

  set pending [after info]            ;# List all pending events
  ```

  #### Status and Configuration (Eagle extensions)

  - `after active` - Returns 1 if any after events are pending.
  - `after counts` - Returns statistics about scheduled events.
  - `after dump` - Dumps the event queue for debugging.
  - `after enable ?enabled?` - Enables or disables after event processing.
  - `after flags ?flags?` - Gets or sets event processing flags.

<a id="cmd-callback"></a>
- **callback** - Callback management (Eagle extension)

  Provides a callback queue system for managing asynchronous operations.

  - `callback enqueue name ?arg ...?` - Adds a callback to the queue.
  - `callback dequeue ?options?` - Removes and returns a callback from the queue.
  - `callback execute` - Executes pending callbacks.
  - `callback list ?pattern?` - Lists callbacks matching *pattern*.
  - `callback count` - Returns the number of queued callbacks.
  - `callback clear` - Clears all queued callbacks.

<a id="cmd-update"></a>
- **update** - Process events
  - `update ?mask?`
  - Processes pending events (after callbacks, idle handlers, etc.) and returns. Without this, scheduled events won't fire until the script completes or enters `vwait`.
  - *mask* - Optional event types to process: `idletasks` (only idle events)

  **Example**:
  ```tcl
  after 0 {set done 1}
  update                ;# Process the event
  puts $done            ;# Prints: 1
  ```

<a id="cmd-vwait"></a>
- **vwait** - Wait for variable change
  - `vwait ?options? varName`
  - Enters the event loop and waits until variable *varName* is modified (set or unset). This is the standard way to wait for asynchronous operations.
  - **Options**: `-timeout ms` (maximum time to wait)

  **Example**:
  ```tcl
  # Start async operation that will set 'result' when done
  after 1000 {set result "completed"}

  # Wait for result
  vwait result
  puts $result    ;# Prints: completed
  ```

---

### Introspection

Introspection commands belong to ObjectGroup: "introspection"

The `info` command is the primary means for querying the state of the interpreter, examining procedures, variables, commands, and system information. It has over 80 sub-commands organized by category.

<a id="cmd-info"></a>
- **info** - Introspection operations

  #### Procedure Introspection

  - `info args procName ?defaults?` - Returns the list of argument names for *procName*. If *defaults* is true, returns pairs of {name defaultValue} for arguments with defaults.
  - `info body procName ?showLines? ?useLocation?` - Returns the body of procedure *procName*. With *showLines*, includes line numbers. With *useLocation*, uses source file location.
  - `info default procName arg varName` - Returns 1 if argument *arg* of *procName* has a default value (stored in *varName*), 0 otherwise.
  - `info procs ?pattern?` - Returns a list of all procedures matching *pattern* (glob-style).
  - `info nprocs ?pattern?` - Returns a list of procedures in the current namespace matching *pattern*.
  - `info source ?procName? ?full?` - Returns source location information for *procName*. If *full*, includes full path.

  **Example**:
  ```tcl
  proc greet {name {greeting "Hello"}} {
      return "$greeting, $name!"
  }
  info args greet           ;# Returns: name greeting
  info args greet true      ;# Returns: {name {}} {greeting Hello}
  info body greet           ;# Returns the procedure body
  info default greet greeting defVar  ;# Sets defVar to "Hello", returns 1
  ```

  #### Variable Introspection

  - `info exists varName` - Returns 1 if variable *varName* exists in the current scope, 0 otherwise.
  - `info globals ?pattern?` - Returns a list of all global variables matching *pattern*.
  - `info locals ?pattern?` - Returns a list of all local variables in the current procedure matching *pattern*.
  - `info vars ?options? ?pattern?` - Returns a list of all visible variables matching *pattern*. Options control filtering.
  - `info sysvars ?pattern?` - Returns a list of system variables matching *pattern*.
  - `info linkedname varName` - Returns the name of the variable that *varName* is linked to (via `upvar`), or an error if not linked.
  - `info varlinks ?pattern?` - Returns information about variable links matching *pattern*.

  **Example**:
  ```tcl
  proc example {arg1} {
      set local1 "value"
      upvar 1 external ext
      info exists local1     ;# Returns: 1
      info exists nosuch     ;# Returns: 0
      info locals            ;# Returns: arg1 local1 ext
      info linkedname ext    ;# Returns: external
  }
  ```

  #### Command Introspection

  - `info commands ?options? ?pattern?` - Returns a list of all commands matching *pattern*. Options:
    - `-globmode` - Use glob matching (default)
    - `-regexpmode` - Use regular expression matching
    - `-hidden` - Include hidden commands
    - `-exposed` - Include only exposed commands
  - `info cmdtype commandName` - Returns the type of command (procedure, command, alias, ensemble, etc.).
  - `info cmdcount ?path? ?type?` - Returns the count of commands executed. With *path*, counts for that interpreter. With *type*, counts specific command types.
  - `info complete script` - Returns 1 if *script* is a complete Tcl command (balanced braces, quotes, etc.), 0 otherwise. Useful for interactive input.
  - `info subcommands ?options? name ?pattern?` - Returns a list of sub-commands for ensemble *name* matching *pattern*.
  - `info syntax ?name?` - Returns the syntax help string for command *name*.
  - `info undefined ?pattern?` - Returns a list of undefined commands matching *pattern*.

  **Example**:
  ```tcl
  info commands string*   ;# Returns: string
  info cmdtype puts       ;# Returns: Command
  info cmdtype myproc     ;# Returns: Procedure
  info complete "set x"   ;# Returns: 1
  info complete "set x {"  ;# Returns: 0 (unclosed brace)
  info subcommands string  ;# Returns: compare concat equal first ...
  ```

  #### Call Stack Introspection

  - `info level ?number? ?fullName?` - Without arguments, returns the current stack level number. With *number*, returns a list describing that level: command name and arguments. `#0` is the global level, positive numbers are relative to current.
  - `info levelid ?number? ?fullName?` - Returns the unique identifier for the specified stack level.
  - `info frame ?refresh?` - Returns information about the current execution frame including script file, line number, and type.

  **Example**:
  ```tcl
  proc inner {} {
      puts "Level: [info level]"        ;# Prints: Level: 2
      puts "Caller: [info level 1]"     ;# Prints: outer
      puts "Global: [info level 0]"     ;# Prints: inner
  }
  proc outer {} { inner }
  outer
  ```

  #### Script and Interpreter Information

  - `info script ?fileName?` - Returns the name of the script file currently being evaluated. With *fileName*, sets it temporarily.
  - `info cmdline` - Returns the full command line used to start the interpreter.
  - `info argv` - Returns a list of command-line arguments passed to the script.
  - `info interactive` - Returns 1 if the interpreter is running interactively, 0 otherwise.
  - `info library ?refresh?` - Returns the path to the Eagle library directory.
  - `info context` - Returns information about the current execution context.
  - `info lastinput` - Returns the last input read from the console.

  #### Environment and System Information

  - `info os ?refresh?` - Returns operating system information (platform, version).
  - `info hostname ?refresh?` - Returns the hostname of the machine.
  - `info user` - Returns the current user name.
  - `info administrator` - Returns 1 if running with administrator/root privileges, 0 otherwise.
  - `info pid` - Returns the process ID of the interpreter.
  - `info ppid` - Returns the parent process ID.
  - `info previouspid ?reset? ?newId?` - Returns the previous process ID (for fork detection). With *reset*, resets the tracking.
  - `info processors` - Returns the number of processors/cores available.
  - `info tid ?native?` - Returns the current thread ID. With *native*, returns the native OS thread ID.
  - `info ptid ?native?` - Returns the primary thread ID.
  - `info base` - Returns the base directory for the application.
  - `info binary` - Returns the path to the Eagle binary/executable.
  - `info nameofexecutable` - Returns the full path to the current executable.
  - `info programextension` - Returns the program file extension for the current platform (`.exe` on Windows).
  - `info sharedlibextension` - Returns the shared library extension (`.dll`, `.so`, `.dylib`).
  - `info shelllibrary ?refresh?` - Returns the path to the shell library.
  - `info newline` - Returns the newline character(s) for the current platform.
  - `info whitespace` - Returns the whitespace characters recognized by the parser.
  - `info path type` - Returns the path for the specified type (temp, home, etc.).

  **Example**:
  ```tcl
  puts "OS: [info os]"                    ;# e.g., "Windows NT 10.0"
  puts "Host: [info hostname]"             ;# e.g., "mycomputer"
  puts "User: [info user]"                 ;# e.g., "jsmith"
  puts "Admin: [info administrator]"       ;# 0 or 1
  puts "CPUs: [info processors]"           ;# e.g., 8
  puts "PID: [info pid]"                   ;# e.g., 12345
  ```

  #### .NET/CLR Information

  - `info clr ?refresh?` - Returns information about the Common Language Runtime.
  - `info framework ?refresh?` - Returns the .NET Framework version and information.
  - `info frameworkextra ?refresh?` - Returns additional .NET Framework information.
  - `info runtime ?refresh?` - Returns runtime information (Mono, .NET Core, etc.).
  - `info runtimeversion ?refresh? ?build? ?extra?` - Returns the runtime version. With *build*, includes build number. With *extra*, includes additional details.
  - `info appdomain` - Returns the current application domain name.
  - `info assembly ?entry?` - Returns information about loaded assemblies. With *entry*, returns the entry assembly info.

  **Example**:
  ```tcl
  puts "CLR: [info clr]"
  puts "Framework: [info framework]"
  puts "Runtime: [info runtime]"
  puts "AppDomain: [info appdomain]"
  ```

  #### Engine and Version Information

  - `info engine ?attribute? ?refresh? ?all?` - Returns Eagle engine information. With *attribute*, returns specific attribute. With *all*, includes all attributes.
  - `info patchlevel ?refresh?` - Returns the Eagle patch level (e.g., "1.0.0.0").
  - `info tclversion ?refresh?` - Returns the Tcl compatibility version.
  - `info setup ?verbose?` - Returns setup/configuration information. With *verbose*, includes detailed information.

  #### Object and Type Introspection

  - `info objects ?pattern?` - Returns a list of opaque object handles matching *pattern*.
  - `info delegates ?pattern?` - Returns a list of delegate objects matching *pattern*.
  - `info bindertypes ?pattern?` - Returns a list of binder types matching *pattern*.
  - `info ensembles ?pattern?` - Returns a list of ensemble commands matching *pattern*.
  - `info functions ?options? ?pattern?` - Returns a list of expression functions matching *pattern*.
  - `info operators ?options? ?pattern?` - Returns a list of expression operators matching *pattern*.
  - `info operands name` - Returns the operand count for operator *name*.
  - `info callbacks ?pattern?` - Returns a list of registered callbacks matching *pattern*.
  - `info policies ?pattern?` - Returns a list of security policies matching *pattern*.

  #### Channel and Connection Information

  - `info channels ?pattern?` - Returns a list of open channels matching *pattern* (stdin, stdout, stderr, file handles, sockets).
  - `info connections ?pattern?` - Returns a list of database connections matching *pattern*.
  - `info transactions ?pattern?` - Returns a list of active transactions matching *pattern*.

  #### Interpreter Management

  - `info interps ?pattern? ?all?` - Returns a list of child interpreters matching *pattern*. With *all*, includes all interpreters.
  - `info loaded ?options? ?interp? ?pattern?` - Returns a list of loaded packages. With *interp*, queries that interpreter.
  - `info modules ?pattern?` - Returns a list of loaded modules matching *pattern*.
  - `info plugin name` - Returns information about the specified plugin.
  - `info pluginflags name` - Returns the flags for the specified plugin.
  - `info externals` - Returns information about external references.

  #### Culture and Localization

  - `info culture ?name?` - Returns information about the current culture. With *name*, returns info for that specific culture.
  - `info cultures ?pattern?` - Returns a list of available cultures matching *pattern*.

  #### Identifier and Decision Information

  - `info identifier name ?kind? ?full?` - Returns information about the specified identifier.
  - `info decision ?types?` - Returns information about type decisions.

  #### Windows-Specific (Windows Only)

  - `info hwnd handle` - Returns information about the specified window handle.
  - `info windows ?pattern?` or `info windows ?full? ?pattern?` - Returns a list of windows matching *pattern*.
  - `info windowtext handle` - Returns the text/title of the specified window.

  #### Activity Tracking

  - `info active ?pattern?` - Returns a list of active operations matching *pattern*.

<a id="cmd-version"></a>
- **version** - Get Eagle version
  - `version ?flags?`
  - Returns the Eagle version string. With *flags*, can control the format:
    - Default returns version like "1.0.0.0"
    - Various flags control inclusion of build info, configuration, etc.

  **Example**:
  ```tcl
  puts [version]    ;# e.g., "1.0.0.0"
  ```

---

### Delegates and Aliases

Aliases and delegates provide mechanisms to create command shortcuts and manage callable objects.

<a id="cmd-alias"></a>
- **alias** - Create command alias (ObjectGroup: "alias")
  - `alias name` - Returns the definition of alias *name*.
  - `alias name {}` - Deletes alias *name*.
  - `alias name targetCmd ?arg ...?` - Creates an alias *name* that invokes *targetCmd* with optional prepended arguments.

  Aliases allow creating shortcuts or wrappers for commands. When the alias is invoked, any additional arguments are appended to the predefined arguments.

  **Example**:
  ```tcl
  # Create a shortcut
  alias ll list                ;# 'll' is now an alias for 'list'

  # Create an alias with prepended arguments
  alias dir glob -nocomplain   ;# 'dir *.txt' becomes 'glob -nocomplain *.txt'

  # Create a procedure-like alias
  alias greet puts "Hello,"    ;# 'greet World' prints "Hello, World"

  # Delete an alias
  alias greet {}
  ```

<a id="cmd-delegate"></a>
- **delegate** - Delegate operations (ObjectGroup: "delegate")
  - `delegate create ?options? typeName` - Creates a delegate of the specified .NET type.
  - `delegate delete delegateName` - Deletes a delegate.
  - `delegate invoke delegateName ?arg ...?` - Invokes a delegate with arguments.
  - `delegate list ?pattern?` - Lists delegates matching *pattern*.

  Delegates are used to create callable wrappers for .NET methods, enabling callback mechanisms and event handling.

  **Example**:
  ```tcl
  # Create a delegate for a .NET method
  set del [delegate create -alias System.Comparison\`1\[System.Int32\]]
  ```

---

### Ensemble Commands

Ensemble commands belong to ObjectGroup: "ensemble"

Ensemble commands group related sub-commands under a single command name. In Eagle, commands like `string`, `array`, `file`, `info`, `debug`, and `object` are implemented as ensemble commands internally.

**Note**: Unlike Tcl 8.5+, Eagle does not provide user-facing `ensemble` or `namespace ensemble` commands for creating custom ensembles at the script level. Ensemble functionality is handled internally by the interpreter for built-in commands.

---

### Engine Operations

Engine commands belong to ObjectGroup: "engine"

These commands control script evaluation and substitution at the core level.

<a id="cmd-eval"></a>
- **eval** - Evaluate script
  - `eval arg ?arg ...?`
  - Concatenates all arguments with spaces and evaluates the result as a script.
  - **Returns**: The result of the last command in the script.

  **Example**:
  ```tcl
  set cmd "puts"
  set msg "Hello"
  eval $cmd [list $msg]    ;# Prints: Hello

  # Build and execute command dynamically - use [list] to preserve structure
  set args {a b c}
  eval lindex [list $args] 1        ;# Returns: b

  # Dynamic command invocation with arguments
  set cmd {string length}
  set value "hello"
  eval $cmd [list $value]           ;# Returns: 5
  ```

  **Note**: Eagle does NOT support the Tcl 8.5+ argument expansion operator `{*}`. Use `[eval]` with `[list]` for dynamic command construction to properly handle quoting.

<a id="cmd-invoke"></a>
- **invoke** - Invoke command
  - `invoke ?level? cmd ?arg ...?`
  - Invokes *cmd* with the given arguments at the specified stack *level*.
  - Without *level*, invokes at the current level.
  - This is an Eagle extension for controlled command invocation.

  **Example**:
  ```tcl
  invoke #0 set globalVar "value"  ;# Set variable at global level
  invoke 1 puts "Message"          ;# Invoke at caller's level
  ```

<a id="cmd-source"></a>
- **source** - Source script file
  - `source ?options? fileName`
  - Reads and evaluates the contents of *fileName* as a script.
  - **Options**:
    - `-encoding name` - Character encoding of the file
  - **Returns**: The result of the last command in the file.

  **Example**:
  ```tcl
  source "config.tcl"
  source -encoding utf-8 "unicode_script.tcl"
  ```

<a id="cmd-subst"></a>
- **subst** - Perform substitutions
  - `subst ?-nobackslashes? ?-nocommands? ?-novariables? string`
  - Performs variable, command, and backslash substitutions on *string* without evaluating it as a script.
  - **Options** (disable specific substitutions):
    - `-nobackslashes` - Don't process backslash sequences
    - `-nocommands` - Don't evaluate `[...]` command substitutions
    - `-novariables` - Don't substitute `$variable` references
  - **Returns**: The substituted string.

  **Example**:
  ```tcl
  set name "World"
  subst {Hello, $name!}          ;# Returns: Hello, World!
  subst {Value: [expr {2+2}]}    ;# Returns: Value: 4
  subst -novariables {$name}     ;# Returns: $name
  subst {Tab:\tNewline:\n}       ;# Returns: Tab:	Newline:(newline)
  ```

---

### Native Environment

Native environment commands belong to ObjectGroup: "nativeEnvironment"

These commands interact with the operating system and native code.

<a id="cmd-exec"></a>
- **exec** - Execute external program
  - `exec ?options? arg ?arg ...? ?&?`
  - Executes an external program with the given arguments. Unlike Tcl's exec, Eagle's exec provides extensive options for process control, I/O handling, and .NET integration.

  **Basic Syntax**:
  ```tcl
  exec ?options? program ?arg ...? ?&?
  ```

  The trailing `&` runs the process in the background (non-blocking).

  **Options Reference**:

  | Option | Description |
  |--------|-------------|
  | **Output Control** | |
  | `-keepnewline` | Don't remove trailing newline from output |
  | `-nocarriagereturns` | Remove carriage returns from output (Windows) |
  | `-trimall` | Trim whitespace from stdout and stderr |
  | `-unicode` | Use Unicode encoding for captured output |
  | `-ignorestderr` | Don't treat stderr output as an error |
  | **Capture Control** | |
  | `-nocapture` | Don't capture stdin or stdout (disables both) |
  | `-nocaptureinput` | Don't capture/redirect stdin |
  | `-nocaptureoutput` | Don't capture stdout/stderr |
  | `-overridecapture` | Use custom handlers instead of wrapping built-in ones |
  | `-noexitcode` | Don't capture exit code |
  | **Variable Storage** | |
  | `-processid varName` | Store process ID in variable |
  | `-exitcode varName` | Store exit code in variable |
  | `-stdin varName` | Read stdin content from variable |
  | `-stdout varName` | Store stdout in variable (instead of returning) |
  | `-stderr varName` | Store stderr in variable |
  | `-stdinobject varName` | Get stdin stream object handle for direct writing |
  | `-setall` | Set all output variables even on error |
  | **Execution Control** | |
  | `-background` | Run process in background (same as trailing `&`) |
  | `-shell` | Use ShellExecute (opens documents, URLs, etc.) |
  | `-timeout milliseconds` | Maximum time to wait for process exit |
  | `-killonerror` | Kill process if interpreter error occurs |
  | `-success exitCode` | Expected success exit code (default: 0) |
  | `-directory path` | Working directory for child process |
  | `-windowstyle style` | Window style: Normal, Hidden, Minimized, Maximized |
  | **Authentication** | |
  | `-domainname name` | Domain for process credentials |
  | `-username name` | Username for process credentials |
  | `-password secureString` | Password for process credentials |
  | **Callbacks** | |
  | `-startcallback script` | Script to call when process starts |
  | `-stdoutcallback script` | Script to call for each stdout line |
  | `-stderrcallback script` | Script to call for each stderr line |
  | **Logging** | |
  | `-stdoutlogpath path` | Log stdout to file |
  | `-stderrlogpath path` | Log stderr to file |
  | `-logtag string` | Tag to include in log entries |
  | **Argument Processing** | |
  | `-commandline` | Build proper command line with quoting |
  | `-dequote` | Remove quotes from arguments before building command line |
  | `-quoteall` | Quote all arguments in command line |
  | `-forprocessor` | Use command processor escaping rules |
  | `-escaperanges ranges` | Index ranges of arguments to escape |
  | `-escapesubstring command` | Custom command for substring escaping |
  | `-preprocessarguments command` | Custom command to preprocess arguments |
  | **Debugging** | |
  | `-debug` | Enable debug output |
  | `-trace` | Trace the final command line |
  | `-nonormalize` | Don't normalize paths in debug output |
  | `-noellipsis` | Don't truncate long values in debug output |
  | **Event Processing** | |
  | `-noevents` | Don't process events while waiting |
  | `-nosleep` | Don't sleep while waiting for process |
  | `-userinterface` | Process window messages while waiting |
  | `-eventflags flags` | Event flags for waiting |
  | **Miscellaneous** | |
  | `-nointerpreter` | Don't associate interpreter with process |
  | `-nopreviousprocessid` | Don't set interpreter's PreviousProcessId |
  | `-objectflags flags` | Object flags for stdin stream handle |
  | `-tags list` | Tags for external use |
  | `--` | End of options |

  **Returns**: The standard output of the command (unless `-stdout` is used).

  **Exit Code Handling**:
  - By default, a non-zero exit code causes an error
  - Use `-exitcode varName` to capture the exit code
  - Use `-success exitCode` to specify expected success code
  - Use `-ignorestderr` to prevent stderr from causing errors

  **Basic Examples**:
  ```tcl
  # Simple command execution
  set output [exec ls -la]

  # Run in background
  exec myprogram &

  # With explicit background option
  exec -background myprogram

  # Capture exit code
  exec -exitcode code myprogram
  puts "Exit code: $code"

  # Specify working directory
  exec -directory /tmp ls -la

  # With timeout (5 seconds)
  exec -timeout 5000 slowprogram
  ```

  **I/O Redirection Examples**:
  ```tcl
  # Provide stdin from variable
  set input "line1\nline2\nline3"
  exec -stdin input grep pattern

  # Capture stdout and stderr separately
  exec -stdout out -stderr err myprogram
  puts "Output: $out"
  puts "Errors: $err"

  # Get process ID
  exec -processid pid -background longrunning
  puts "Started process: $pid"
  ```

  **Shell Execution Examples**:
  ```tcl
  # Open URL in default browser
  exec -shell https://example.com

  # Open document with associated application
  exec -shell document.pdf

  # Open folder in file explorer
  exec -shell -directory /path/to/folder .
  ```

  **Callback Examples**:
  ```tcl
  # Process stdout line-by-line
  exec -stdoutcallback {
      puts "LINE: $args"
  } longrunning

  # Log output to file
  exec -stdoutlogpath /tmp/output.log -stderrlogpath /tmp/error.log myprogram
  ```

  **Windows-Specific Examples**:
  ```tcl
  # Run hidden (no window)
  exec -windowstyle Hidden cmd /c "echo test"

  # Run minimized
  exec -windowstyle Minimized notepad

  # With credentials
  exec -username admin -password $securePass -domainname MYDOMAIN program.exe
  ```

  **Command Line Building**:
  ```tcl
  # Build proper command line with quoting (handles spaces in arguments)
  exec -commandline program "arg with spaces" "another arg"

  # Quote all arguments
  exec -commandline -quoteall program arg1 arg2 arg3

  # For command processor (cmd.exe / sh)
  exec -commandline -forprocessor cmd /c "echo test"
  ```

  **Error Handling**:
  ```tcl
  # Ignore non-zero exit code
  if {[catch {exec -exitcode code program} result]} {
      puts "Error: $result"
  } else {
      puts "Output: $result (exit code: $code)"
  }

  # Ignore stderr
  set output [exec -ignorestderr program]

  # Always get output even on error
  exec -setall -stdout out -stderr err -exitcode code program
  ```

  **Notes**:
  - Eagle's exec does NOT support Tcl-style pipeline syntax (`cmd1 | cmd2`)
  - Eagle's exec does NOT support Tcl-style I/O redirection (`< file`, `> file`, `2>&1`)
  - For pipelines, use separate exec calls or the shell: `exec cmd /c "cmd1 | cmd2"`
  - For I/O redirection, use the `-stdin`, `-stdout`, `-stderr` options
  - Use `-shell` to open documents/URLs with associated applications
  - The `-timeout` option kills the process if it doesn't exit in time

<a id="cmd-exit"></a>
- **exit** - Exit interpreter
  - `exit ?options? ?returnCode?`
  - Terminates the interpreter with the specified return code (default 0).
  - **Options**:
    - `-force` - Force immediate exit without cleanup
  - **Returns**: Does not return.

  **Example**:
  ```tcl
  exit              ;# Exit with code 0
  exit 1            ;# Exit with error code 1
  exit -force 2     ;# Force immediate exit
  ```

<a id="cmd-kill"></a>
- **kill** - Kill process (Eagle extension)
  - `kill ?options? process`
  - Terminates the specified process or processes matching a pattern.
  - **Options**:
    - `-all` - Kill all processes matching the pattern (only valid with process name patterns, not PIDs)
    - `-force` - Force immediate termination using `Process.Kill()`. Without this option, attempts graceful termination via `Process.CloseMainWindow()`.
    - `-whatIf` - Show what would be killed without actually terminating processes
    - `-verbose` - Output detailed information about the kill operation
  - *process* can be:
    - A numeric PID (process identifier)
    - A process name pattern using glob matching (e.g., `notepad*`)
  - **Returns**: List of killed/closed processes on success.
  - **Note**: This command is marked as unsafe and requires appropriate permissions.

  **Example**:
  ```tcl
  kill 1234                    ;# Kill process with PID 1234 (graceful)
  kill -force 1234             ;# Force kill process with PID 1234
  kill notepad                 ;# Close first notepad process (graceful)
  kill -all notepad            ;# Close all notepad processes
  kill -all -force notepad*    ;# Force kill all processes matching notepad*
  kill -whatIf -all chrome*    ;# Show what would be killed (dry run)
  ```

<a id="cmd-library"></a>
- **library** - Native library operations (Eagle extension)
  - `library subcommand ?options? ?args?`
  - Provides P/Invoke-style access to native (unmanaged) libraries, enabling Eagle scripts to load native DLLs, declare native function signatures, and call native functions directly. This is an unsafe command that requires native code execution capability.
  - **Note**: This command requires the `compile.EMIT`, `compile.NATIVE`, and `compile.LIBRARY` compile-time features and native platform support.
  - **Core Concepts**:
    - **Modules**: Native libraries (DLLs, .so, .dylib files) loaded into the process
    - **Delegates**: Function signature declarations that describe native function prototypes
    - **Resolution**: Binding a delegate to an actual function address in a module
    - **Reference counting**: Modules track references from delegates; unloading a module only succeeds when no delegates reference it
  - **Sub-commands**:

    **library call** - Call a native function
    - `library call ?options? delegate ?arg ...?`
    - Invokes the native function associated with a previously declared and resolved delegate.
    - **Options**: Supports extensive marshaling options for type conversion and return value handling:
      - `-create` - Create an opaque object handle for the return value
      - `-alias` - Create an alias command for the returned object
      - `-dispose` - Dispose of the return value after use
      - `-tostring` - Convert return value to string
      - `-nobyref` - Disable by-reference argument handling
      - `-invoke` - Force invocation (default behavior)
      - `-debug` - Enable debug output for method resolution
      - `-trace` - Enable tracing of method calls
      - Additional marshaling options for controlling type conversion
    - **Returns**: The function's return value, converted according to options.
    - **Example**:
      ```tcl
      # Call GetConsoleWindow (no arguments, returns IntPtr)
      set hwnd [library call $getConsoleWindow]

      # Call with arguments and create object handle for result
      set result [library call -create $createInterp]
      ```

    **library certificate** - Check library digital signature
    - `library certificate ?options? fileName`
    - Retrieves and optionally verifies the digital certificate/signature of a native library file.
    - **Options**:
      - `-chain` - Verify the full certificate chain
      - `-cache` - Use cached certificate information
      - `-verificationflags flags` - X509 verification flags
      - `-revocationmode mode` - Certificate revocation check mode
      - `-revocationflag flag` - Certificate revocation flag
    - **Returns**: Certificate information as a formatted string.

    **library checkload** - Check if library can be loaded
    - `library checkload ?options? fileName`
    - Checks if a native library can be loaded without actually loading it. If already loaded, returns the existing module handle.
    - **Options**: Same as `library load`
    - **Returns**: Module handle name if already loaded, or loads and returns handle.
    - **Use case**: Useful for conditionally loading libraries or avoiding duplicate loads.

    **library declare** - Declare a native function signature
    - `library declare ?options?`
    - Declares a native function signature by creating a delegate type dynamically. The delegate can then be resolved to an actual function address and called.
    - **Options**:
      - `-module moduleName` - Associate with a specific loaded module
      - `-functionname name` - Name of the native function to bind to
      - `-address intptr` - Explicit function address (dangerous)
      - `-returntype type` - Return type (e.g., `IntPtr`, `int32`, `void`, `Boolean`)
      - `-parametertypes typeList` - List of parameter types (e.g., `{IntPtr String int32}`)
      - `-callingconvention conv` - Calling convention: `Winapi` (default), `Cdecl`, `StdCall`, `ThisCall`, `FastCall`
      - `-charset charset` - Character set for string marshaling: `Ansi`, `Unicode`, `Auto`
      - `-setlasterror bool` - Capture Win32 last error after call
      - `-bestfitmapping bool` - Enable best-fit character mapping
      - `-throwonunmappablechar bool` - Throw on unmappable characters
      - `-assemblyname name` - Custom assembly name for dynamic type
      - `-modulename name` - Custom module name for dynamic type
      - `-typename name` - Custom type name for the delegate
      - `-delegatename name` - Custom delegate handle name
      - `-alias` - Create a command alias for the delegate
    - **Returns**: Delegate handle name (e.g., `IDelegate#1`).
    - **Example**:
      ```tcl
      # Declare GetConsoleWindow from kernel32.dll
      set module [library load kernel32.dll]
      set delegate [library declare \
          -functionname GetConsoleWindow \
          -returntype IntPtr \
          -module $module]

      # Declare a function with parameters
      set delegate2 [library declare \
          -functionname GetStdHandle \
          -returntype IntPtr \
          -parametertypes {int32} \
          -module $module]

      # Declare Tcl_Eval from Tcl library
      set tclEval [library declare \
          -module $tclModule \
          -functionname Tcl_Eval \
          -callingconvention cdecl \
          -charset ansi \
          -returntype ReturnCode \
          -parametertypes {IntPtr String}]
      ```

    **library handle** - Get module handle by file name
    - `library handle fileName`
    - Returns the native module handle for an already-loaded library without loading it.
    - **Returns**: Integer handle value (IntPtr as Int32 or Int64 depending on platform).
    - **Note**: Returns 0 if the library is not loaded.

    **library info** - Get information about modules or delegates
    - `library info delegate delegateName` - Returns detailed information about a delegate
    - `library info module moduleName` - Returns detailed information about a module
    - **Delegate info includes**: kind, id, name, description, callingConvention, returnType, parameterTypes, typeId, typeName, moduleFlags, moduleName, moduleFileName, moduleReferenceCount, functionName, address
    - **Module info includes**: kind, id, name, description, flags, fileName, module (handle), referenceCount
    - **Returns**: Dictionary-formatted list of key-value pairs.
    - **Example**:
      ```tcl
      library info module $module
      # Returns: {kind NativeModule id ... name IModule#1 fileName kernel32.dll ...}

      library info delegate $delegate
      # Returns: {kind NativeDelegate ... functionName GetConsoleWindow address 123456}
      ```

    **library load** - Load a native library
    - `library load ?options? fileName`
    - Loads a native library (DLL, .so, .dylib) into the process and creates a module handle.
    - **Options**:
      - `-modulename name` - Custom module handle name
      - `-locked` - Prevent the module from being unloaded (sets `NoUnload` flag)
      - `-flags flags` - Module flags (enum value)
      - `-trustedonly` - Only load if library is signed/trusted
      - `-maybetrustedonly` - Like `-trustedonly` but only in release builds
    - **Returns**: Module handle name (e.g., `IModule#1`).
    - **Note**: Module names can be used with `[info modules]` to list loaded modules.
    - **Example**:
      ```tcl
      # Load a system DLL
      set kernel32 [library load kernel32.dll]

      # Load with explicit path
      set myLib [library load "/path/to/mylib.so"]

      # Load and lock (prevent unload)
      set lockedLib [library load -locked "important.dll"]
      ```

    **library matcharchitecture** - Check architecture compatibility
    - `library matcharchitecture fileName`
    - Checks if a library file's architecture matches the current process architecture (x86/x64/ARM).
    - **Returns**: Boolean `true` if compatible, `false` otherwise.

    **library resolve** - Resolve delegate to function address
    - `library resolve ?options? delegate`
    - Binds a declared delegate to an actual function address in a module. This step is required before calling the function if not done during `library declare`.
    - **Options**:
      - `-module moduleName` - Module containing the function
      - `-functionname name` - Function name to resolve (can change the binding)
    - **Returns**: Empty string on success.
    - **Use case**: Re-resolve a delegate to a different function or module.
    - **Example**:
      ```tcl
      # Create delegate without module, then resolve later
      set delegate [library declare -functionname MyFunc -returntype int32]
      library resolve -module $myModule $delegate

      # Re-resolve to different function
      library resolve -module $otherModule -functionname OtherFunc $delegate
      ```

    **library test** - Test library loading capability
    - `library test ?fileName?`
    - Tests the native library loading subsystem, optionally with a specific file.
    - **Returns**: Empty string on success.

    **library undeclare** - Remove a function declaration
    - `library undeclare delegate`
    - Removes a previously declared delegate and releases any associated resources. Also removes any alias created with `-alias` option.
    - **Returns**: Empty string on success.

    **library unload** - Unload a native library
    - `library unload module`
    - Unloads a previously loaded native library module.
    - **Note**: Unloading fails if any delegates still reference the module. Use `library undeclare` first.
    - **Returns**: Empty string on success.

    **library unresolve** - Unresolve a delegate
    - `library unresolve ?options? delegate`
    - Removes the function address binding from a delegate without removing the delegate itself. The delegate can be re-resolved later.
    - **Returns**: Empty string on success.
    - **Use case**: Release a module reference while keeping the delegate declaration.

    **library verifyarchitecture** - Verify architecture compatibility
    - `library verifyarchitecture fileName`
    - Like `matcharchitecture` but returns an error if incompatible instead of a boolean.
    - **Returns**: Empty string if compatible, error otherwise.

  - **Complete P/Invoke Example** (Windows):
    ```tcl
    # Load kernel32.dll
    set kernel32 [library load kernel32.dll]

    # Declare GetConsoleWindow
    set getConsoleWindow [library declare \
        -functionname GetConsoleWindow \
        -returntype IntPtr \
        -module $kernel32]

    # Declare GetStdHandle
    set getStdHandle [library declare \
        -functionname GetStdHandle \
        -returntype IntPtr \
        -parametertypes {int32} \
        -module $kernel32]

    # Call the functions
    set hwnd [library call $getConsoleWindow]
    set STD_OUTPUT_HANDLE -11
    set handle [library call $getStdHandle $STD_OUTPUT_HANDLE]

    puts "Console window handle: $hwnd"
    puts "Standard output handle: $handle"

    # Check module info
    puts [library info module $kernel32]

    # Cleanup
    library undeclare $getStdHandle
    library undeclare $getConsoleWindow
    library unload $kernel32
    ```

  - **Calling Tcl from Eagle** (cross-library interop):
    ```tcl
    # Load the Tcl library
    set tclDll [library load tcl86.dll]

    # Declare Tcl functions
    set createInterp [library declare \
        -module $tclDll \
        -functionname Tcl_CreateInterp \
        -callingconvention cdecl \
        -returntype IntPtr]

    set tclEval [library declare \
        -module $tclDll \
        -functionname Tcl_Eval \
        -callingconvention cdecl \
        -charset ansi \
        -returntype int32 \
        -parametertypes {IntPtr String}]

    set deleteInterp [library declare \
        -module $tclDll \
        -functionname Tcl_DeleteInterp \
        -callingconvention cdecl \
        -parametertypes {IntPtr}]

    set tclFinalize [library declare \
        -module $tclDll \
        -functionname Tcl_Finalize \
        -callingconvention cdecl]

    # Create and use a Tcl interpreter
    set interp [library call -create $createInterp]
    set code [library call $tclEval $interp {expr {2 + 2}}]

    # Cleanup
    library call $deleteInterp $interp
    library call $tclFinalize

    # Undeclare and unload
    library undeclare $tclFinalize
    library undeclare $deleteInterp
    library undeclare $tclEval
    library undeclare $createInterp
    library unload $tclDll
    ```

  - **Reference Counting Behavior**:
    - Loading a module sets its reference count to 1
    - Each delegate that references a module increments its reference count
    - Undeclaring a delegate decrements the module's reference count
    - Unloading a module only succeeds when reference count reaches 0
    - Use `library info module` to check reference counts

  - **Related Commands**:
    - `[info modules]` - List all loaded native modules
    - `[info delegates]` - List all declared delegates

<a id="cmd-pid"></a>
- **pid** - Get process ID
  - `pid ?channelId?`
  - Without arguments, returns the process ID of the current interpreter.
  - With *channelId*, returns the process ID of the process connected to that channel (e.g., from `exec ... &` or `open |...`).

  **Example**:
  ```tcl
  puts "My PID: [pid]"
  set pipe [open |"long_running_process" r]
  puts "Process PID: [pid $pipe]"
  ```

- **tcl** - Tcl integration (see Tcl Integration section)

---

### Managed Environment

Managed environment commands belong to ObjectGroup: "managedEnvironment"

These commands interact with the .NET runtime and the interactive host environment.

<a id="cmd-host"></a>
- **host** - Host operations (interactive console host)

  The `host` command provides control over the interactive console/terminal interface.

  #### Screen Control

  - `host clear` - Clears the console screen.
  - `host position ?options?` - Gets or sets the cursor position.
    - Without options, returns `{column row}`.
    - With `-x col -y row`, sets the cursor position.
  - `host size ?options?` - Gets or sets the console window size.
  - `host title ?title?` - Gets or sets the console window title.

  #### Colors and Styling

  - `host color ?options?` - Gets or sets console colors.
    - `-foreground color` - Set foreground color
    - `-background color` - Set background color
    - Without options, returns current colors.
  - `host namedcolor ?options?` - Gets a named color value.
  - `host boxstyle ?style?` - Gets or sets the box drawing style.
  - `host outputstyle ?style?` - Gets or sets the output style.

  **Example**:
  ```tcl
  host color -foreground Green -background Black
  host title "My Application"
  host clear
  ```

  #### Input Operations

  - `host readchar` - Reads a single character from input.
  - `host readkey ?intercept?` - Reads a key press. With *intercept*, doesn't echo the key.
  - `host readline ?nullOk?` - Reads a line of input.
  - `host pause` - Pauses and waits for user input (like "Press any key...").

  **Example**:
  ```tcl
  host write "Enter your name: "
  set name [host readline]
  host write "Press any key to continue..."
  host readkey true
  ```

  #### Output Operations

  - `host write value ?newLine?` - Writes *value* to the host. With *newLine*, adds a newline.
  - `host writebox ?options? string` - Writes *string* inside a decorative box.
  - `host beep ?options?` - Produces a beep sound.

  **Example**:
  ```tcl
  host write "Processing..." false
  # ... do work ...
  host write " Done!\n"
  host beep
  ```

  #### Channel Management

  - `host inchan ?channel?` - Gets or sets the input channel.
  - `host outchan ?channel?` - Gets or sets the output channel.
  - `host errchan ?channel?` - Gets or sets the error channel.
  - `host redirected channel` - Checks if *channel* is redirected.
  - `host mode channel ?mode?` - Gets or sets the channel mode.
  - `host echo ?enabled?` - Enables or disables input echo.

  #### Screen Buffers (Multiple Screens)

  - `host screen create` - Creates a new screen buffer.
  - `host screen delete name ?active?` - Deletes a screen buffer.
  - `host screen exists name ?primary?` - Checks if a screen buffer exists.
  - `host screen list ?pattern? ?primary?` - Lists screen buffers.
  - `host screen active` - Gets the active screen buffer.
  - `host screen push name` - Pushes a screen buffer onto the stack.
  - `host screen pop` - Pops a screen buffer from the stack.
  - `host screen peek` - Peeks at the top of the screen stack.

  #### Host Control

  - `host open` - Opens the host for interaction.
  - `host close` - Closes the host.
  - `host isopen` - Returns 1 if the host is open, 0 otherwise.
  - `host cancel ?force?` - Cancels the current host operation.
  - `host exit ?force?` - Exits the host.
  - `host reset ?options?` - Resets the host to default state.
  - `host flags` - Returns host capability flags.
  - `host query` - Queries host information.
  - `host result code result ?errorLine?` - Sets the host result.
  - `host sleep milliseconds` - Sleeps for the specified duration.
  - `host font ?options?` - Gets or sets the console font.

<a id="cmd-load"></a>
- **load** - Load binary package/extension
  - `load ?options? fileName ?packageName? ?interp?`
  - Loads a compiled extension (DLL) into the interpreter.
  - *fileName* - Path to the extension library
  - *packageName* - Name of the package to initialize (optional)
  - *interp* - Target interpreter (optional, defaults to current)
  - **Options**:
    - `-global` - Load symbols globally
    - `-lazy` - Lazy loading

  **Example**:
  ```tcl
  load "myextension.dll" MyPackage
  ```

- **object** - .NET object operations (see Objects section)

- **sql** - SQL operations (see Database section)

<a id="cmd-unload"></a>
- **unload** - Unload binary package/extension
  - `unload ?options? fileName ?packageName? ?interp?`
  - Unloads a previously loaded extension.
  - **Options**:
    - `-keeplibrary` - Keep library loaded but remove package
    - `-nocomplain` - Don't error if package not loaded

  **Example**:
  ```tcl
  unload "myextension.dll" MyPackage
  ```

- **xml** - XML operations (see XML section)

---

### Core and Miscellaneous

These commands provide fundamental interpreter operations and utility functions.

<a id="cmd-automatic"></a>
- **automatic** - Automatic command delegation (ObjectGroup: "delegate")
  - Manages automatic delegation of commands to other implementations.
  - Used internally for command dispatch optimization.

<a id="cmd-bgerror"></a>
- **bgerror** - Background error handler (ObjectGroup: "scriptEnvironment")
  - `bgerror message`
  - Called automatically when an error occurs in a background event handler (e.g., after callbacks).
  - You can define your own `bgerror` procedure to customize error handling.

  **Example**:
  ```tcl
  proc bgerror {message} {
      puts stderr "Background error: $message"
      puts stderr "Stack trace: $::errorInfo"
      # Log to file, show dialog, etc.
  }
  ```

<a id="cmd-core"></a>
- **core** - Core operations (ObjectGroup: "core")
  - Provides access to core interpreter functionality.
  - Used for advanced interpreter manipulation and debugging.

<a id="cmd-default"></a>
- **default** - Default operations (ObjectGroup: "default")
  - Provides default behavior for various operations.
  - Used internally by the interpreter.

<a id="cmd-nop"></a>
- **nop** - No operation (ObjectGroup: "nop")
  - `nop`
  - Does nothing and returns an empty string.
  - Useful as a placeholder or for timing/profiling.

  **Example**:
  ```tcl
  nop                    ;# Returns: {}
  time {nop} 1000000     ;# Measure interpreter overhead
  ```

<a id="cmd-rename"></a>
- **rename** - Rename command (ObjectGroup: "scriptEnvironment")
  - `rename ?options? oldName newName`
  - Renames command *oldName* to *newName*.
  - If *newName* is empty, deletes the command.
  - **Options**:
    - `-force` - Overwrite existing command

  **Example**:
  ```tcl
  # Rename a command
  rename myproc my_new_proc

  # Save original and wrap
  rename puts _puts
  proc puts {args} {
      eval _puts [list "[clock format [clock seconds]]:"] $args
  }

  # Delete a command
  rename myproc {}
  ```

<a id="cmd-subdelegate"></a>
- **subdelegate** - Sub-delegate operations (ObjectGroup: "delegate")
  - Manages sub-delegation of commands within ensemble structures.
  - Used for advanced command routing.

---

## Common Option Patterns

Eagle commands use consistent option patterns across many commands. Here are the most common options found in ObjectOps.cs option factory methods:

### Object Creation and Disposal Options

**-create / -nocreate**
- Controls whether objects should be automatically created
- Used in: object create, library call, debug exception
- Default: -nocreate (objects not created automatically)

**-dispose / -nodispose**
- Controls whether objects should be disposed when removed
- Used in: object dispose, object create, object cleanup, library call
- Default: -dispose (objects are disposed by default)

**-synchronous**
- Controls synchronous garbage collection
- Used in: object dispose, object cleanup
- Default: asynchronous (no immediate GC)

### Object Invocation Options

**-alias / -aliasraw / -aliasall / -aliasreference**
- Controls object aliasing behavior
- -alias: Create alias to object
- -aliasraw: Create raw alias (minimal processing)
- -aliasall: Create comprehensive alias
- -aliasreference: Create reference alias
- Used in: object alias, object create, object invoke, library call

**-objectname**
- Specifies the name for a created object
- Used in: object create, library call, debug exception

**-type / -objecttypes / -parametertypes / -methodtypes**
- Type specification for .NET interop
- Used in: object create, object alias, library call

### Marshaling and Binding Options

**-marshalflags**
- Controls value marshaling behavior
- Used in: object create, object invoke, library call
- Default: MarshalFlags.Default

**-argumentflags**
- Controls by-reference argument handling
- Used in: object create, library call
- Default: ByRefArgumentFlags.None

**-bindingflags / -flags**
- Controls .NET reflection binding flags
- Used in: object invoke, object members, library call
- Default: DefaultBindingFlags

**-objectflags**
- Controls object handling flags
- Used in: object create, object invoke, exec, library call
- Default: ObjectFlags.Default

**-byrefobjectflags**
- Controls by-reference object flags
- Used in: library call
- Default: ObjectFlags.None

**-reorderflags**
- Controls parameter reordering
- Used in: object create
- Default: ReorderFlags.Default

### Common Utility Options

**-verbose**
- Enables verbose output
- Used in: object alias, library call, many commands
- Provides detailed operation information

**-debug**
- Enables debug output
- Used in: object create, library call, exec
- Provides debugging information

**-trace**
- Enables trace output
- Used in: object create, library call, exec
- Provides execution tracing

**-nocomplain**
- Suppresses error complaints
- Used in: object dispose, object cleanup, interp operations

**-force**
- Forces operation even if normally not allowed
- Used in: namespace enable, host exit, kill

**-nocase**
- Case-insensitive comparison
- Used in: object alias, library call, string operations

**-strict / -stricttype / -strictmember / -strictargs**
- Enables strict type/member checking
- Used in: object operations, library call

### Execution and Timing Options

**-time**
- Times the operation execution
- Used in: sql execute, tcl eval

**-timeout**
- Sets operation timeout
- Used in: exec, interp timeout

**-limit / -index**
- Sets limits on operations
- Used in: library call, object create

### Pattern Matching Options

**-pattern**
- Specifies pattern for matching
- Used in: many info sub-commands, object cleanup

**-mode**
- Specifies matching mode
- Used in: array names, array values

### Other Common Options

**-noinvoke**
- Prevents automatic invocation
- Used in: object create, library call

**-noargs**
- Prevents automatic argument processing
- Used in: object create, library call

**-default**
- Uses default values
- Used in: library call, info operations

**-tostring**
- Converts result to string
- Used in: object operations, library call

**-arrayasvalue / -arrayaslink**
- Controls array marshaling
- Used in: library call

---

## Test Functions

The Eagle test suite (in Eagle/Library/Tests/Default.cs) provides a dedicated test class with managed methods that support comprehensive testing of the Eagle engine. A subset of these methods are exposed as script commands via AddExecuteCallback, AddCommand, and AddSubCommands method calls:

### Core Test Script Commands (via TestAddCommands)

- **seti** - Set variable immutability
  - `seti varName ?immutable?`

- **writable** - Check if a variable is writable
  - `writable varName`

- **exists** - Check if a variable exists
  - `exists varName`

- **vadd** - Add a variable
  - `vadd varName ?value?`

- **vusable** - Check if a variable is usable
  - `vusable varName`

- **vislocked** - Check if a variable is locked
  - `vislocked varName`

- **vlock** - Lock a variable
  - `vlock varName`

- **vunlock** - Unlock a variable
  - `vunlock varName`

### Expression Test Commands

- **testExpr** - Test expression evaluation with flags
  - `testExpr flags arg ?arg ...?`

- **calc** - Calculator/expression evaluation
  - `calc arg ?arg ...?`

### Callback Test Commands (via TestAddBuiltInExecuteCallbacks)

- **appendArgs** - Append arguments to a result
  - `appendArgs ?arg ...?`

- **lappendArgs** - List append arguments to a result
  - `lappendArgs ?arg ...?`

### Definition Commands (via TestAddDefinitionCommands)

- **define** - Define a macro or definition
  - `define name ?value?`

- **include** - Include a file
  - `include fileName`

### Rule Set Commands (via TestAddRuleSetCommands)

- **rule** - Add a rule to the rule set
  - `rule ?options? pattern body`

- **findRules** - Find rules matching a pattern
  - `findRules ?pattern?`

- **noRules** - Clear all rules
  - `noRules`

- **discardRules** - Discard specified rules
  - `discardRules ?pattern?`

- **newRules** - Create a new rule set
  - `newRules`

- **mergeRules** - Merge rules from another rule set
  - `mergeRules ruleSet`

- **includeRuleSet** - Include rules from a rule set file
  - `includeRuleSet fileName`

- **saveRules** - Save rules to a file
  - `saveRules fileName`

- **createWithRules** - Create an object with rules applied
  - `createWithRules ?options?`

- **introspect** - Introspect the current rule set state
  - `introspect ?options?`

### Delegate Test Commands (dynamically created)

- **integerDelegate** - Test delegate returning integer
- **objectDelegate** - Test delegate returning object
- **enumerableDelegate** - Test delegate returning enumerable

**Note**: The Default.cs class contains many additional managed methods used internally for test infrastructure, callbacks, and utilities. The commands listed above are registered via AddExecuteCallback, AddCommand, or AddSubCommands calls and represent the script commands directly callable from Eagle test scripts.

---

## Advanced Topics and Patterns

This section documents advanced language features, edge cases, and patterns discovered through comprehensive analysis of the Eagle test suite.

### Parser Behavior and Edge Cases

#### Escape Sequences

Eagle supports standard Tcl backslash escape sequences (see the [Tcl manual](https://www.tcl-lang.org/man/tcl8.6/TclCmd/Tcl.htm)) plus additional Eagle-specific extensions.

**Standard Tcl/Eagle Escape Sequences**:

| Escape | Description | Example |
|--------|-------------|---------|
| `\a` | Bell (BEL, 0x07) | `puts "alert\a"` |
| `\b` | Backspace (0x08) | `puts "back\bspace"` |
| `\f` | Form feed (0x0C) | `puts "page\fbreak"` |
| `\n` | Newline (0x0A) | `puts "line1\nline2"` |
| `\r` | Carriage return (0x0D) | `puts "return\rhere"` |
| `\t` | Tab (0x09) | `puts "col1\tcol2"` |
| `\v` | Vertical tab (0x0B) | `puts "vert\vtab"` |
| `\\` | Literal backslash | `puts "path\\file"` |
| `\ooo` | Octal byte (1-3 digits) | `puts "\101"` → "A" |
| `\xhh` | Hex byte (1-2 digits) | `puts "\x41"` → "A" |
| `\uhhhh` | Unicode BMP (4 hex digits) | `puts "\u0041"` → "A" |
| `\Uhhhhhhhh` | Unicode (8 hex digits, Tcl 8.6+) | `puts "\U0001F600"` → emoji |

**Eagle-Specific Escape Extensions**:

| Escape | Description | Example |
|--------|-------------|---------|
| `\B<bits>` | Binary number | `puts "\B01000001"` → "A" |
| `\o<digits>` | Octal number (explicit) | `puts "\o101"` → "A" |
| `\d<digits>` | Decimal number | `puts "\d65"` → "A" |
| `\X<digits>` | Hex number (uppercase prefix) | `puts "\X41"` → "A" |

**Notes**:
- The `\uhhhh` escape requires exactly 4 hex digits for BMP characters
- The `\Uhhhhhhhh` escape requires exactly 8 hex digits and supports the full Unicode range including supplementary planes
- Eagle's `\B`, `\o`, `\d`, and `\X` extensions provide explicit radix specification for character codes
- Hex escapes (`\x`) support 1-2 digits: `\x1` and `\x01` are equivalent
- Octal escapes (`\ooo`) support 1-3 digits

#### Brace and Quote Handling

```tcl
# Braces prevent all substitution
set x {$var [cmd] \n}  ;# Literal string "$var [cmd] \n"

# Double quotes allow variable and command substitution
set x "$var [cmd] \n"  ;# Substituted value with newline

# Backslash-newline is a continuation (replaced with single space)
set x "this is \
       a continued line"

# Nested braces must be balanced
set x {outer {inner} outer}  ;# Valid
# set x {unbalanced {}        ;# Error

# Backslash before closing brace prevents matching
set x {this has a \} brace}  ;# Valid, contains "}"
```

#### Word Boundaries and Tokenization

```tcl
# Commands are separated by newlines or semicolons
set a 1; set b 2
set c 3
set d 4

# Command arguments are separated by whitespace
cmd arg1 arg2 arg3

# Braces group into single argument
cmd {multi word argument}

# Quotes also group into single argument
cmd "multi word argument"

# Backslash continues words
cmd word1\
    word2  ;# Single argument "word1word2" with intervening space

# Variable substitution in command name position
set cmd puts
$cmd "hello"  ;# Calls puts
```

#### Comment Syntax

```tcl
# Line comment (must be at start of command)
set x 1  ;# Inline comment after semicolon

# Not a comment: # in middle of command
set x "# not a comment"
set y {# also not a comment}

# Comment continues to end of line
# No block comments - each line needs #
```

### Expression Evaluation Details

#### Numeric Types and Precision

Eagle expressions support multiple numeric types:

```tcl
# Integer literals
expr {42}          ;# Decimal integer
expr {0x2A}        ;# Hexadecimal (42)
expr {052}         ;# Octal (42)
expr {0b101010}    ;# Binary (42) - Eagle extension

# Floating-point literals
expr {3.14159}     ;# Standard decimal
expr {2.5e10}      ;# Scientific notation
expr {.5}          ;# Leading decimal point OK
expr {5.}          ;# Trailing decimal point OK

# Wide integers (64-bit)
expr {9223372036854775807}  ;# Max Int64

# Decimal (fixed-point) for financial calculations
expr {decimal(123.45)}  ;# Eagle extension
```

#### Operator Precedence (Highest to Lowest)

1. Function calls, `()` grouping
2. Unary: `- + ~ !`
3. Power: `**` (right-associative)
4. Multiplicative: `* / %`
5. Additive: `+ -`
6. Shift: `<< >>`
7. Comparison: `< > <= >=`
8. Equality: `== != eq ne`
9. List Membership: `in ni`
10. Bitwise AND: `&`
11. Bitwise XOR: `^`
12. Bitwise OR: `|`
13. Logical AND: `&&`
14. Logical OR: `||`
15. Ternary: `? :`

#### String Comparison in Expressions

```tcl
# String equality (preferred over == for strings)
expr {"hello" eq "hello"}    ;# 1
expr {"Hello" eq "hello"}    ;# 0

# String inequality
expr {"abc" ne "def"}        ;# 1

# Numeric comparison (type coercion)
expr {"42" == 42}            ;# 1 (string converted to number)

# Use eq/ne for pure string comparison
expr {" 42" eq "42"}         ;# 0 (different strings)
expr {" 42" == 42}           ;# 1 (both convert to 42)
```

#### List Membership in Expressions

The `in` and `ni` operators test whether a string element is contained in a list. These operators perform **string comparison only** (no numeric conversion) and are the list-based counterparts to `eq` and `ne`.

```tcl
# Basic list membership
expr {"apple" in {apple banana cherry}}     ;# 1 (found)
expr {"grape" in {apple banana cherry}}     ;# 0 (not found)

# List non-membership
expr {"apple" ni {apple banana cherry}}     ;# 0 (it IS in the list)
expr {"grape" ni {apple banana cherry}}     ;# 1 (not in the list)

# String comparison - no numeric conversion
expr {"1" in {1 2 3}}        ;# 1 (string "1" matches element "1")
expr {"01" in {1 2 3}}       ;# 0 (string "01" does not match "1")
expr {"0x1" in {1 2 3}}      ;# 0 (no numeric conversion)

# Case sensitivity (default is case-sensitive)
expr {"Apple" in {apple banana cherry}}     ;# 0 (case mismatch)
expr {"apple" in {apple banana cherry}}     ;# 1 (exact match)

# Common idiom: check before adding to avoid duplicates
if {$item ni $result} {
    lappend result $item
}

# Combining with other operators
expr {$x in $valid_values && $y > 0}
expr {$cmd ni $dangerous_commands || $is_admin}
```

**Key differences from numeric operators:**
- `in`/`ni` perform **pure string matching** (like `eq`/`ne`)
- No type coercion occurs - `"1"` and `1` are compared as strings
- The second operand must be a valid Tcl list
- Comparison type can be configured (case-sensitive by default)

#### Boolean Handling

```tcl
# Boolean literals
expr {true}        ;# 1
expr {false}       ;# 0
expr {yes}         ;# 1
expr {no}          ;# 0
expr {on}          ;# 1
expr {off}         ;# 0

# Boolean operations
expr {!0}          ;# 1 (logical NOT)
expr {1 && 0}      ;# 0 (logical AND)
expr {1 || 0}      ;# 1 (logical OR)

# Short-circuit evaluation
expr {0 && [expensive_proc]}   ;# [expensive_proc] not called
expr {1 || [expensive_proc]}   ;# [expensive_proc] not called
```

### List Operations Advanced Patterns

#### List Manipulation Idioms

```tcl
# Remove duplicates while preserving order
proc lremove_dups {list} {
    set result [list]
    foreach item $list {
        if {$item ni $result} {
            lappend result $item
        }
    }
    return $result
}

# Flatten nested lists
proc lflatten {list} {
    set result [list]
    foreach item $list {
        if {[llength $item] > 1} {
            # Use eval with lappend for list expansion (Eagle has no {*} operator)
            eval lappend result [lflatten $item]
        } else {
            lappend result $item
        }
    }
    return $result
}

# Dictionary-style key-value pair iteration
foreach {key value} $list {
    puts "$key => $value"
}

# Parallel list iteration
foreach a $list1 b $list2 c $list3 {
    puts "$a $b $c"
}
```

#### lsearch Advanced Usage

```tcl
# Return all matching indices
lsearch -all {a b a c a} a    ;# Returns: {0 2 4}

# Return matching values (not indices)
lsearch -all -inline {apple banana apricot} ap*  ;# Returns: {apple apricot}

# Case-insensitive glob matching
lsearch -nocase -glob {Apple Banana} a*  ;# Returns: 0

# Regular expression matching
lsearch -regexp {one two three} {^t.*}  ;# Returns: 1

# Exact match starting from specific index
lsearch -exact -start 2 {a b c a d} a    ;# Returns: 3

# Search in sorted list (binary search)
lsearch -sorted -integer {1 5 10 15 20} 10  ;# Returns: 2

# Return not-found indication
lsearch -exact {a b c} x  ;# Returns: -1
```

#### lsort Advanced Usage

```tcl
# Sort with custom comparison command
proc compareLength {a b} {
    return [expr {[string length $a] - [string length $b]}]
}
lsort -command compareLength {one three two}  ;# Returns: {one two three}

# Sort by dictionary value (key extraction)
set data {{name Alice age 30} {name Bob age 25}}
lsort -index 3 -integer $data  ;# Sort by age

# Sort with multiple keys
lsort -index {0 1} $nested_list

# Unique values after sort
lsort -unique {c a b a c}  ;# Returns: {a b c}

# Descending order
lsort -decreasing {3 1 2}  ;# Returns: {3 2 1}

# Dictionary order (natural sort)
lsort -dictionary {a1 a10 a2}  ;# Returns: {a1 a2 a10}
```

### Array Operations Advanced Patterns

#### Array Iteration Patterns

```tcl
# Iterate over array with names/get
foreach name [array names myArray] {
    puts "$name = $myArray($name)"
}

# Iterate with pattern matching
foreach name [array names myArray "prefix_*"] {
    puts "$name = $myArray($name)"
}

# Convert array to list and back
array set myArray [array get otherArray]

# Filter array elements
array set filtered {}
foreach {name value} [array get myArray] {
    if {[string match "keep_*" $name]} {
        set filtered($name) $value
    }
}
```

#### Array Search and Statistics

```tcl
# Check if key exists
array exists myArray
info exists myArray(key)

# Get array size
array size myArray

# Search for values
array names myArray -glob "*pattern*"
array names myArray -regexp {^prefix}

# Array statistics (hash bucket distribution)
array statistics myArray
```

### Namespace Advanced Patterns

#### Variable Resolution Order

```tcl
# Variables are resolved in this order:
# 1. Local scope (procedure local variables)
# 2. Namespace variables (if 'variable' command was used)
# 3. Global namespace (if 'global' command was used)

namespace eval ns {
    variable nsVar "namespace"

    proc test {} {
        variable nsVar          ;# Access namespace variable
        global globalVar        ;# Access global variable
        set localVar "local"    ;# Create local variable
    }
}
```

### .NET Integration Patterns

#### Object Lifecycle Management

```tcl
# Create with automatic disposal tracking
set obj [object create -alias System.Text.StringBuilder]

# Use object
$obj Append "Hello"
$obj Append " World"
puts [$obj ToString]

# Explicit disposal (recommended for IDisposable)
object dispose $obj

# Or let Eagle manage disposal
unset obj  ;# Will dispose if no other references
```

#### Type Conversion and Marshaling

```tcl
# Explicit type specification for method calls
object invoke -parametertypes {System.String System.Int32} \
    $obj MethodName "arg1" 42

# Marshal arrays
set clrArray [object invoke -create System.Array CreateInstance \
    System.String 10]

# Access array elements
$clrArray SetValue "value" 0
puts [$clrArray GetValue 0]

# Convert between Tcl lists and .NET arrays
set list [object invoke Utility ToList $clrArray]
```

#### Event Handling

```tcl
# Subscribe to .NET events
object invoke -eventsubscribe $obj EventName "myHandler"

proc myHandler {sender args} {
    puts "Event fired: $args"
}

# Unsubscribe
object invoke -eventunsubscribe $obj EventName "myHandler"
```

#### Static Method and Property Access

```tcl
# Call static method
set now [object invoke -create System.DateTime Now]

# Access static property
set pi [object invoke System.Math PI]

# Call static method with type specification
set result [object invoke System.Math Max 10 20]
```

### Control Flow Edge Cases

#### Return Codes and Exception Handling

```tcl
# Standard return codes
# 0 (TCL_OK)       - Normal completion
# 1 (TCL_ERROR)    - Error occurred
# 2 (TCL_RETURN)   - return command executed
# 3 (TCL_BREAK)    - break command executed
# 4 (TCL_CONTINUE) - continue command executed

# Catch with options (key-value list)
if {[catch {risky_operation} result options]} {
    # options contains: -code, -errorcode, -errorinfo, -level
    puts "Error: $result"
    # Use getDictionaryValue (from auxiliary.eagle) to extract values
    puts "Stack: [getDictionaryValue $options -errorinfo]"
}

# Re-raise with preserved stack trace
catch {
    some_operation
} result options
if {[getDictionaryValue $options -code] == 1} {
    return -options $options $result
}
```

#### try/finally Patterns

Eagle's `try` command supports `try {} finally {}` syntax (not the Tcl 8.6-style `try {} on {} {} catch {} {}` syntax). Use `catch` separately for error handling.

```tcl
# try/finally ensures cleanup runs regardless of errors
try {
    set fh [open $filename r]
    processFile $fh
} finally {
    # Always executed, even if error occurs
    if {[info exists fh]} {
        close $fh
    }
}

# Combine with catch for full error handling
if {[catch {
    try {
        set fh [open $filename r]
        processFile $fh
    } finally {
        if {[info exists fh]} {
            close $fh
        }
    }
} error]} {
    puts "Error processing file: $error"
}
```

### Procedure Definition Patterns

#### Variable Arguments

```tcl
# Using args for variable arguments
proc myproc {required1 required2 args} {
    puts "Required: $required1 $required2"
    puts "Optional: $args"
}

# Default values
proc myproc {arg1 {arg2 "default"} {arg3 10}} {
    puts "$arg1 $arg2 $arg3"
}
myproc "a"          ;# a default 10
myproc "a" "b"      ;# a b 10
myproc "a" "b" 20   ;# a b 20
```

#### Anonymous Procedures (apply)

```tcl
# Define and call anonymous procedure
apply {{x y} {expr {$x + $y}}} 3 4  ;# Returns: 7

# With namespace context
apply {{x} {variable nsvar; expr {$x + $nsvar}}} 5 ::mynamespace

# Store lambda for later use
set lambda {{x} {expr {$x * 2}}}
apply $lambda 21  ;# Returns: 42

# Use with lmap for functional programming
lmap x {1 2 3 4} {apply {{n} {expr {$n * $n}}} $x}  ;# {1 4 9 16}
```

### Tcl Integration (Native Tcl Interop)

#### Cross-Interpreter Communication

```tcl
# Check if Tcl integration is available
if {[llength [info commands tcl]] > 0 && [tcl ready]} {
    # Evaluate script in Tcl interpreter
    tcl eval [tcl primary] {
        # This runs in native Tcl
        package require Tk
        button .b -text "Hello" -command exit
        pack .b
    }
}

# Pass variables between interpreters
set result [tcl eval [tcl primary] {
    set x 42
    return $x
}]
```

#### Garuda Bridge (Eagle Package for Tcl)

```tcl
# Check for Garuda availability
if {[haveGaruda]} {
    # Use Garuda commands in Tcl
    tcl eval [tcl primary] {
        package require Garuda
        eagle eval {puts "Hello from Eagle!"}
    }
}
```

### Script Cancellation (TIP #285)

Eagle supports cooperative script cancellation:

```tcl
# In one thread/context, request cancellation
interp cancel $interpName

# Scripts should check periodically
proc long_operation {} {
    for {set i 0} {$i < 1000000} {incr i} {
        # Check for cancellation every N iterations
        if {$i % 1000 == 0} {
            update  ;# Allows cancellation to take effect
        }
        # Do work...
    }
}

# Cancellation raises an error that can be caught
if {[catch {long_operation} result]} {
    if {[string match "*cancel*" $result]} {
        puts "Operation was cancelled"
    }
}
```

### String Pattern Matching Details

#### Glob Patterns

```tcl
# Glob metacharacters
# *     - Matches any sequence of characters
# ?     - Matches any single character
# [abc] - Matches any character in the set
# [a-z] - Matches any character in the range
# \x    - Matches the literal character x

string match "*.txt" "file.txt"      ;# 1
string match "file?.txt" "file1.txt" ;# 1
string match "file[123].txt" "file2.txt"  ;# 1
string match {*\**} "has*star"       ;# 1 (literal *)
```

#### Regular Expression Syntax

```tcl
# Basic regex
regexp {[0-9]+} "abc123def" match    ;# match = "123"

# Capturing groups
regexp {(\w+)@(\w+)\.(\w+)} "user@host.com" \
    full user host domain
# full = "user@host.com", user = "user", host = "host", domain = "com"

# Non-capturing groups
regexp {(?:prefix_)?name} "name" match  ;# match = "name"

# Case-insensitive
regexp -nocase {hello} "HELLO"  ;# 1

# Extended syntax (whitespace and comments)
regexp -expanded {
    ^\d{3}    # Area code
    -         # Separator
    \d{4}$    # Local number
} "555-1234"  ;# 1

# All matches
regexp -all -inline {[0-9]+} "a1b2c3"  ;# {1 2 3}
```

### Channel I/O Patterns

#### File Operations with Encoding

```tcl
# Open with specific encoding
set fh [open $filename r]
fconfigure $fh -encoding utf-8 -translation auto

# Read entire file
set content [read $fh]
close $fh

# Read line by line (memory efficient)
set fh [open $filename r]
while {[gets $fh line] >= 0} {
    process $line
}
close $fh

# Binary mode
set fh [open $filename rb]
fconfigure $fh -translation binary
set data [read $fh]
close $fh
```

#### Socket Communication

**Note**: Eagle supports the `socket` command for network communication but does NOT support `fileevent` for asynchronous I/O. Socket operations in Eagle are typically synchronous.

```tcl
# Client socket (synchronous)
set sock [socket localhost 8080]
fconfigure $sock -buffering line -translation auto
puts $sock "Hello"
flush $sock
gets $sock response
close $sock

# Server socket with -server callback
# The callback handles each connection synchronously
set server [socket -server acceptConnection 8080]

proc acceptConnection {channel clientAddr clientPort} {
    fconfigure $channel -buffering line -translation auto
    # Handle synchronously - read request and respond
    gets $channel request
    puts $channel "Echo: $request"
    close $channel
}
```

### Debug Command Sub-Commands Reference

The `debug` command provides extensive debugging capabilities:

| Sub-command | Description |
|-------------|-------------|
| `debug break` | Set/manage breakpoints |
| `debug cache` | Cache management |
| `debug cleanup` | Resource cleanup |
| `debug collect` | Garbage collection |
| `debug complaint` | Complaint handling |
| `debug emit` | Dynamic code emission |
| `debug enabled` | Check debug status |
| `debug execute` | Execute with debugging |
| `debug exception` | Exception management |
| `debug hash` | Hash operations |
| `debug invoke` | Debug invocation |
| `debug iqueue` | Input queue management |
| `debug memory` | Memory operations |
| `debug oncancel` | Cancellation handlers |
| `debug onexecute` | Execution handlers |
| `debug onreturn` | Return handlers |
| `debug pending` | Pending operations |
| `debug plugindata` | Plugin data access |
| `debug pqueue` | Priority queue ops |
| `debug purge` | Purge operations |
| `debug queue` | Queue operations |
| `debug refresh` | Refresh state |
| `debug rqueue` | Result queue ops |
| `debug securitycontext` | Security context |
| `debug self` | Self-referential ops |
| `debug stack` | Call stack access |
| `debug step` | Step debugging |
| `debug suspend` | Suspend execution |
| `debug sysinvoke` | System invocation |
| `debug test` | Debug testing |
| `debug trace` | Trace operations |
| `debug types` | Type information |
| `debug variable` | Variable debugging |
| `debug watch` | Watch expressions |

---

## Flags Enumeration Semantics

Eagle provides a powerful and flexible system for working with .NET `[Flags]` enumeration types from scripts. This is integrated with the "Universal Option Parser" used throughout Eagle's command infrastructure.

### Flag Operators

When specifying a flags enumeration value, you can prefix the flag name with an operator to control how it is combined with the current value:

| Operator | Name | Description | Operation |
|----------|------|-------------|-----------|
| `+` | Add | Adds the specified flag bits | `current \| value` (bitwise OR) |
| `-` | Remove | Removes the specified flag bits | `current & ~value` (bitwise AND NOT) |
| `=` | Set | Sets the value directly, replacing entirely | `value` |
| `:` | Set-Add | Sets the value, then switches to add mode | Sets value, subsequent use `+` |
| `&` | Keep | Keeps only the specified flag bits | `current & value` (bitwise AND) |

### Default Behavior

- The default operator when no prefix is specified is `:` (Set-Add)
- This means the first value encountered sets the base value
- Subsequent values without operators are added to that base

### Basic Examples

```tcl
# Add NonPublic to the default binding flags
object invoke -flags +NonPublic System.String Empty

# Multiple flags can be combined (space or comma separated)
object invoke -flags {+NonPublic +Static} MyType MyMethod

# Start with all flags, then remove specific ones
object members -membertypes {+All -Method} System.Console

# Explicitly set flags (replacing defaults)
object create -objectflags =NoDispose System.Text.StringBuilder
```

### Detailed Usage Patterns

#### Adding Flags (+)

The `+` operator performs a bitwise OR, adding the specified flags to the current value:

```tcl
# Add NonPublic access to default BindingFlags
object invoke -flags +NonPublic $obj PrivateMethod

# Add multiple flags
object invoke -flags {+NonPublic +Static} MyClass MyStaticPrivateField
```

#### Removing Flags (-)

The `-` operator performs a bitwise AND NOT, removing the specified flags:

```tcl
# Get all member types except methods
object members -membertypes {+All -Method} System.Console

# Get all member types except methods and properties
object members -membertypes {+All -Method -Property} System.Type
```

#### Setting Flags (= and :)

The `=` operator directly sets the value, completely replacing any defaults:

```tcl
# Explicitly set only Public and Static (no default flags)
object members -bindingflags {=Public =Static} System.Math
```

The `:` operator (Set-Add) sets the first value and switches to add mode for subsequent values. This is the default behavior when no operator is specified:

```tcl
# These are equivalent:
object invoke -flags {NonPublic Static} $obj Method
object invoke -flags {:NonPublic +Static} $obj Method
```

#### Keeping Flags (&)

The `&` operator performs a bitwise AND, keeping only flags that are in both the current and specified value:

```tcl
# Keep only flags that match both current and specified
object invoke -flags {&Instance} $obj Method
```

### Integration with the Universal Option Parser

Eagle's "Universal Option Parser" (implemented in `Interpreter.GetOptions*` methods) automatically handles flags enumeration options. When an option's value type is a `[Flags]` enumeration, the parser:

1. Detects the `[Flags]` attribute on the enum type
2. Retrieves the current/default value of the option
3. Parses the new value using `EnumOps.TryParseFlags`
4. Applies the flag operators to combine old and new values
5. Stores the resulting enum value in the option

This means any command option typed as a flags enumeration supports this syntax automatically.

### Common Flags Enumeration Options

Several Eagle commands accept flags enumeration options:

| Command | Option | Type | Description |
|---------|--------|------|-------------|
| `object invoke` | `-flags` | BindingFlags | .NET reflection binding flags |
| `object invoke` | `-objectflags` | ObjectFlags | Eagle object handling flags |
| `object invoke` | `-marshalflags` | MarshalFlags | Parameter marshaling flags |
| `object invoke` | `-argumentflags` | ArgumentFlags | Argument processing flags |
| `object create` | `-objectflags` | ObjectFlags | Object creation flags |
| `object members` | `-membertypes` | MemberTypes | Member type filter |
| `object members` | `-bindingflags` | BindingFlags | Reflection binding flags |
| `interp policy` | `-flags` | PolicyFlags | Interpreter policy flags |

### BindingFlags Reference

The most commonly used flags enumeration is `System.Reflection.BindingFlags`:

| Flag | Description |
|------|-------------|
| `Default` | No binding flags (zero) |
| `IgnoreCase` | Case-insensitive member lookup |
| `DeclaredOnly` | Only members declared in the type (not inherited) |
| `Instance` | Include instance members |
| `Static` | Include static members |
| `Public` | Include public members |
| `NonPublic` | Include non-public (private/protected/internal) members |
| `FlattenHierarchy` | Include static members from base types |
| `InvokeMethod` | Invoke a method |
| `CreateInstance` | Create an instance (constructor) |
| `GetField` | Get field value |
| `SetField` | Set field value |
| `GetProperty` | Get property value |
| `SetProperty` | Set property value |

**Default for `object invoke`**: Typically includes `Public`, `Instance`, and `InvokeMethod`.

### ObjectFlags Reference

Eagle-specific flags for object handle management:

| Flag | Description |
|------|-------------|
| `None` | No special handling |
| `NoDispose` | Don't dispose object when handle is released |
| `NoReturnReference` | Don't add reference for return values |
| `TemporaryReturnReference` | Add temporary reference for return values |
| `Alias` | Create an aliased object handle |
| `Verbose` | Verbose output during object operations |

### Combining Library Procedures

The `combineFlags` procedure in `object.eagle` provides a script-level way to combine flags:

```tcl
# Combine two flag strings, excluding specific flags
set result [combineFlags $flags1 $flags2 $excludeFlags]

# Example: Combine flags, exclude "Static"
set combined [combineFlags "Public Instance" "NonPublic" "Static"]
```

### Error Handling

Invalid flag names or operators produce descriptive error messages:

```tcl
# Invalid flag name
object invoke -flags +InvalidFlag $obj Method
# Error: bad BindingFlags value "InvalidFlag", must be Default, IgnoreCase, ...

# Invalid operator
object invoke -flags %Public $obj Method
# Error: bad BindingFlags flags operator '%', must be '/', '+', '-', '=', ':', or '&'
```

### Tips for Using Flags

1. **Use `+` for adding access**: When you need to access non-public members, use `+NonPublic` rather than rebuilding all flags

2. **Use `{+All -X}` pattern**: To get "everything except X", start with `+All` then remove what you don't want

3. **Braces for multiple flags**: Enclose multiple flags in braces or quotes: `-flags {+NonPublic +Static}`

4. **Check command defaults**: Some commands have sensible defaults; you may only need to add one or two flags

5. **Comma separation works too**: `+NonPublic,+Static` is equivalent to `{+NonPublic +Static}`

---

## Core Marshaller and Command Callbacks

Eagle provides powerful .NET integration through its core marshaller, which handles type conversion between script values and .NET types. One of its most sophisticated features is the **command callback mechanism**, which enables transparent creation and execution of .NET delegates using Eagle scripts.

### Overview: Script-Backed Delegates

The command callback mechanism allows Eagle scripts (procedures, lambda expressions, or arbitrary script code) to be used wherever .NET code expects a delegate. When .NET code invokes the delegate, Eagle automatically:

1. Marshals the delegate's arguments from .NET types to script-accessible values
2. Evaluates the callback script with those arguments
3. Marshals the return value from the script result back to the expected .NET type

This enables powerful scenarios like:
- Event handlers written in Eagle script
- Custom comparers and predicates for LINQ operations
- Asynchronous callbacks for .NET async patterns
- Thread entry points for multi-threaded applications

### How Command Callbacks Work

#### Creating a Callback from Script

When a script value is passed to a .NET method expecting a delegate type, Eagle's marshaller (via `ConversionOps.ToCommandCallback`) performs these steps:

1. **Parse the script text** to separate any callback options from the actual script body
2. **Create a CommandCallback object** that wraps the script and stores configuration
3. **Generate a .NET delegate** that, when invoked, calls back into the CommandCallback
4. **Return the delegate** for use by .NET code

The generated delegate acts as a "trampoline" - when .NET code invokes it, execution flows through `StaticFireDynamicInvokeCallback` into `FireWithParameters`, which marshals arguments and evaluates the script.

#### Callback Execution Flow

```
.NET Code → Delegate.Invoke()
         → StaticFireDynamicInvokeCallback (trampoline)
         → FireDynamicInvokeCallback
         → FireWithParameters
            1. Process CallbackFlags to determine behavior
            2. Check interpreter availability
            3. Marshal .NET arguments to script values (via FixupReturnValue)
            4. Create opaque object handles for complex objects
            5. Set up ByRef argument handling if needed
            6. Evaluate the callback script
            7. Handle ByRef argument values from script back to .NET
            8. Marshal script result to .NET return type (via FixupArgument)
         → Return value to .NET
```

### Callback Script Syntax

A callback script can include optional configuration flags before the script body:

```tcl
{?options? script ?args?}
```

**Basic examples:**

```tcl
# Simple callback - just a script
object invoke $button add_Click {puts "Button clicked!"}

# Callback with procedure
object invoke $button add_Click {myClickHandler}

# Callback with arguments appended at invocation
object invoke $list Sort {compareItems}
```

### Callback Options Reference

Callback options can be embedded at the beginning of the callback script to customize behavior:

| Option | Type | Description |
|--------|------|-------------|
| `-identifier` | String | Unique ID for the callback (useful when multiple callbacks may be pending) |
| `-returntype` | Type | Expected .NET return type for the callback |
| `-parametertypes` | TypeList | Expected parameter types for the delegate signature |
| `-parametermarshalflags` | MarshalFlags[] | Per-parameter marshalling behavior |
| `-argumentflags` | ByRefArgumentFlags | How ByRef arguments are handled |
| `-marshalflags` | MarshalFlags | Overall marshalling behavior |
| `-objectflags` | ObjectFlags | Object handle creation/management |
| `-callbackflags` | CallbackFlags | Callback execution behavior |

**Example with options:**

```tcl
# Callback with explicit return type
object invoke $list Sort {-returntype System.Int32 -- {compareItems $a $b}}

# Callback with custom flags
object invoke $timer add_Elapsed {-callbackflags {+Complain +ResetCancel} -- {handleTimer}}
```

### CallbackFlags Reference

The `CallbackFlags` enumeration controls how callbacks are executed:

| Flag | Value | Description |
|------|-------|-------------|
| `None` | 0x0 | No special handling |
| `Arguments` | 0x4 | Automatically add delegate arguments as script arguments |
| `Create` | 0x8 | Create opaque object handles for arguments |
| `Dispose` | 0x10 | Dispose objects if creation/addition fails |
| `Alias` | 0x20 | Create a command alias for newly created objects |
| `AliasRaw` | 0x40 | Alias refers to `[object invokeall]` |
| `AliasAll` | 0x80 | Alias refers to `[object invokeall]` |
| `AliasReference` | 0x100 | Alias holds an object reference |
| `ToString` | 0x200 | Convert object to string and discard |
| `ByRefStrict` | 0x400 | Enforce strict type checking on ByRef arguments |
| `Complain` | 0x800 | Log/report failures when firing callbacks |
| `CatchInterrupt` | 0x1000 | Catch ThreadInterruptedException without re-throwing |
| `ReturnValue` | 0x2000 | Automatically handle return value conversion |
| `DefaultValue` | 0x4000 | Return default value (0, null) on error |
| `AddReference` | 0x8000 | Add reference to callback return value |
| `RemoveReference` | 0x10000 | Remove reference from callback return value |
| `DisposeThread` | 0x20000 | Dispose thread after thread-related delegates |
| `ThrowOnError` | 0x40000 | Throw exception if script returns error |
| `UseOwner` | 0x100000 | Route callback through interpreter owner |
| `Asynchronous` | 0x200000 | Queue callback asynchronously |
| `AsynchronousIfBusy` | 0x400000 | Queue async only if owner is busy |
| `ResetCancel` | 0x800000 | Reset script cancellation before evaluating |
| `MustResetCancel` | 0x1000000 | Force reset of cancellation flags |
| `FireAndForget` | 0x2000000 | Clean up callback automatically after invocation |
| `UseParameterNames` | 0x4000000 | Use delegate parameter names in script |

**Default flags:** `Arguments | Create | Dispose | Alias | Complain | ReturnValue | AddReference`

### MarshalFlags for Callbacks

The `MarshalFlags` enumeration controls type marshalling behavior:

| Flag | Description |
|------|-------------|
| `NoDelegateCallback` | Don't convert script to delegate (use existing delegate) |
| `NoGenericCallback` | Prevent use of GenericCallback type |
| `DynamicCallback` | Enable dynamic delegate generation via MSIL |
| `CallbackParameterNames` | Populate parameter names for use in callback script |
| `NoCallbackOptions` | Skip parsing callback options |
| `IgnoreCallbackOptions` | Parse but ignore callback options |
| `ThrowOnBindFailure` | Throw exception on delegate binding failure |
| `SimpleCallback` | Use simple (non-command) callback binding |

### Supported Delegate Types

Eagle's command callback subsystem has built-in support for specific delegate types. Other delegate types are handled via dynamic delegate generation.

**Built-in Delegate Types** (directly supported):

| Delegate Type | Description |
|---------------|-------------|
| `System.Delegate` | Base delegate type (mapped to GenericCallback) |
| `System.AsyncCallback` | Asynchronous operation callbacks |
| `System.EventHandler` | Standard event handlers |
| `System.Threading.ThreadStart` | Thread entry points (no parameters) |
| `System.Threading.ParameterizedThreadStart` | Thread entry points (with parameter) |
| `System.Threading.WaitCallback` | Thread pool work item callbacks |
| `GenericCallback` | Eagle's generic no-parameter callback |

**Custom Delegate Types** (via dynamic generation or signature matching):

| Delegate Type | Notes |
|---------------|-------|
| `System.EventHandler<T>` | Supported if signature matches built-in EventHandler |
| `System.Action` | Treated as custom; matches GenericCallback if no parameters |
| `System.Action<T...>` | Treated as custom; requires dynamic generation |
| `System.Func<T...>` | Treated as custom; requires dynamic generation |
| `System.Predicate<T>` | Treated as custom; requires dynamic generation |
| `System.Comparison<T>` | Treated as custom; requires dynamic generation |
| Other delegate types | Via dynamic delegate generation (MSIL emission) |

**Note**: Delegate types like `Action<T>`, `Func<T>`, `Predicate<T>`, and `Comparison<T>` are usable but are not directly supported by the callback subsystem. They are handled as custom delegate types unless their signature happens to exactly match one of the built-in types (e.g., `Action` with no parameters matches `GenericCallback`).

### Dynamic Delegate Generation

For delegate types not in the built-in list, Eagle can dynamically generate delegates using MSIL emission (when `EMIT` is enabled). This process:

1. Creates a `DynamicMethod` matching the target delegate signature
2. Emits IL code to load the callback and arguments
3. Calls `StaticFireDynamicInvokeCallback` as a trampoline
4. Handles return value boxing/unboxing as needed

This enables Eagle scripts to implement virtually any .NET delegate type.

### Practical Examples

#### Event Handler

```tcl
# Create a button and add a click handler
set button [object create System.Windows.Forms.Button]
$button set_Text "Click Me"

# Script-based event handler
object invoke $button add_Click {
    puts "Button was clicked!"
    puts "Sender: $args(0)"
}
```

#### Custom Comparer

```tcl
# Sort a list using a script-based comparison
proc compareByLength {a b} {
    set lenA [string length $a]
    set lenB [string length $b]
    return [expr {$lenA - $lenB}]
}

# Use as Comparison<string> delegate
set sorted [object invoke -marshalflags +DynamicCallback \
    $list Sort {compareByLength}]
```

#### Thread Entry Point

```tcl
# Create a thread with script-based entry point
set thread [object create System.Threading.Thread {
    -callbackflags {+CatchInterrupt +DisposeThread} -- {
        puts "Thread started"
        # Do work...
        puts "Thread finished"
    }
}]

object invoke $thread Start
```

#### Async Callback

```tcl
# Async file read with callback
proc readComplete {asyncResult} {
    set stream [object invoke $asyncResult get_AsyncState]
    set bytesRead [object invoke $stream EndRead $asyncResult]
    puts "Read $bytesRead bytes"
}

object invoke $fileStream BeginRead $buffer 0 $length \
    {-callbackflags +FireAndForget -- readComplete} $fileStream
```

#### Predicate for Filtering

```tcl
# Filter a list using a script predicate
proc isEven {n} {
    return [expr {($n % 2) == 0}]
}

set evenNumbers [object invoke $list FindAll {isEven}]
```

### ByRef Parameter Handling

When a delegate has `ref` or `out` parameters, Eagle handles them specially:

1. **Input ByRef**: The script receives the current value; modifications are written back
2. **Output ByRef**: The script must set the value; it's written back after evaluation
3. **ByRefStrict mode**: Enforces type checking on ByRef value assignments

```tcl
# Handling a TryParse-style delegate with out parameter
proc tryParseNumber {text resultVar} {
    upvar $resultVar result
    if {[string is integer -strict $text]} {
        set result [expr {int($text)}]
        return true
    }
    return false
}
```

### Callback Lifetime Management

**Important considerations:**

1. **Reference counting**: Callbacks maintain references to prevent premature garbage collection
2. **FireAndForget**: Use this flag for one-shot callbacks that should auto-cleanup
3. **Identifier**: Use `-identifier` for distinguishing multiple pending callbacks
4. **Dispose**: Callbacks are cleaned up when the interpreter is disposed or explicitly removed

### Error Handling in Callbacks

When a callback script returns an error:

- **Default behavior**: Error is logged (with `Complain` flag), default value returned
- **ThrowOnError**: Exception is thrown back to .NET caller
- **DefaultValue**: Returns type's default value (0, null, false) instead of script result

```tcl
# Callback that handles errors gracefully
object invoke $button add_Click {
    -callbackflags {+Complain +DefaultValue} -- {
        # If this errors, logged but doesn't crash
        riskyOperation
    }
}

# Callback that propagates errors
object invoke $validator Validate {
    -callbackflags +ThrowOnError -- {
        if {![isValid $data]} {
            error "Validation failed"
        }
        return true
    }
}
```

### Performance Considerations

1. **Callback caching**: Eagle caches CommandCallback objects by script content to avoid recreating them
2. **Delegate reuse**: Generated delegates are reused when the same callback is requested multiple times
3. **Dynamic vs static**: Built-in delegate types are faster than dynamically generated ones
4. **Marshalling overhead**: Complex argument types incur marshalling costs; simple types are faster

### Integration with the ScriptBinder

The `ScriptBinder` class provides custom type binding for Eagle:

- Maintains a dictionary of type converters (`changeTypes`)
- Handles conversions not supported by the default .NET binder
- Integrates with `MarshalOps.FixupArgument` for inbound conversions
- Integrates with `MarshalOps.FixupReturnValue` for outbound conversions

This enables seamless type conversion between Eagle's string-based values and .NET's strongly-typed system.

---

## Built-in Virtual Scripts

Eagle provides several built-in virtual scripts that are embedded as resources within the core library assembly. These scripts are cryptographically signed and are used for security-critical operations such as enabling/disabling security policies, managing interpreter state during safe interpreter creation, and managing key rings for script signing verification.

### Overview

These virtual scripts:
- Are stored in `Eagle/Library/Resources/library.resx` as embedded resources
- Have accompanying `.harpy` certificate resources containing their digital signatures
- Can only be loaded from within the compiled core library assembly itself
- Are signed with trusted keys (either the core library script signing key or the Eagle Enterprise Trust Root key)
- Cannot be modified without re-signing (signature verification would fail)

### Security Scripts

#### enableSecurity

**Purpose**: Enables the security policies and certificates provided by the Harpy and Badge plugins.

**Script Content**:
```tcl
package require Security.Core; security force true; keyring bootstrap; package require Security.Certificates
```

**Behavior**:
1. Loads the `Security.Core` package
2. Forces security mode to be enabled (`security force true`)
3. Bootstraps the key ring with trusted signing keys
4. Loads the `Security.Certificates` package for certificate management

**Usage Context**: Called internally during interpreter initialization when security is requested. This is typically the first security-related script evaluated in a new interpreter.

**Signature**: Signed with the core library script signing key.

---

#### disableSecurity

**Purpose**: Disables the security policies and clears the key ring.

**Script Content**:
```tcl
package require Security.Core; keyring clear; security force false
```

**Behavior**:
1. Loads the `Security.Core` package
2. Clears all keys from the key ring (`keyring clear`)
3. Forces security mode to be disabled (`security force false`)

**Usage Context**: Used when security needs to be disabled in an interpreter that previously had security enabled.

**Signature**: Signed with the core library script signing key.

---

### Interpreter Cleanup Scripts

These scripts are signed with the **Eagle Enterprise Trust Root** key (embedded in the Harpy assembly) rather than the normal core library script signing key. This is necessary because they are used during the trusted key ring loading process, when the normal signing key is not yet available.

#### removeCommands

**Purpose**: Removes all commands and procedures from the interpreter except those explicitly listed in a "keep" list.

**Script Content**:
```tcl
apply [list [list keep] {
    foreach namespace [namespace children ::] {
        catch {namespace delete $namespace}
    }
    set keepIf [expr {"if" in $keep}]
    set keepRename [expr {"rename" in $keep}]
    lappend keep if rename
    set keep [lsort -dictionary -unique $keep]
    foreach command [info commands] {
        if {$command ni $keep} then {
            rename $command ""
        }
    }
    if {!$keepIf} then {
        if {!$keepRename} then {
            rename if ""
            rename rename ""
        } else {
            rename if ""
        }
    } elseif {!$keepRename} then {
        rename rename ""
    }
}] [list set]
```

**Behavior**:
1. Deletes all child namespaces
2. Takes a list of commands to keep (passed as the `keep` argument)
3. Temporarily adds `if` and `rename` to the keep list (needed for the cleanup logic)
4. Removes all commands not in the keep list by renaming them to empty string
5. Finally removes `if` and `rename` themselves unless they were in the original keep list

**Usage Context**: Used during safe interpreter creation to strip down the interpreter to a minimal set of commands. Called via `ScriptOps.RemoveCommands()`.

**Example Call** (internal):
```csharp
ScriptOps.RemoveCommands(interpreter, keepList, ref error);
```

**Signature**: Signed with the Eagle Enterprise Trust Root key.

---

#### removeVariables

**Purpose**: Removes all global variables from the interpreter.

**Script Content**:
```tcl
apply [list [list] {
    foreach namespace [namespace children ::] {
        catch {namespace delete $namespace}
    }
    foreach varName [info globals] {
        catch {uplevel #0 [list unset -nocomplain $varName]}
    }
    unset -nocomplain ::errorCode ::errorInfo
}]
```

**Behavior**:
1. Deletes all child namespaces
2. Iterates through all global variables (`info globals`)
3. Unsets each variable at the global level (`uplevel #0`)
4. Explicitly clears `::errorCode` and `::errorInfo` as a final cleanup

**Usage Context**: Used during safe interpreter creation to ensure no pre-existing variables leak into the safe interpreter. Called via `ScriptOps.RemoveVariables()`.

**Signature**: Signed with the Eagle Enterprise Trust Root key.

---

### Key Ring Management Scripts

These scripts manage the trusted key ring used for script signature verification.

#### fetchKeyRing

**Purpose**: Fetches an official key ring from a configured remote URI.

**Script Content**:
```tcl
package require Security.Core; keyring fetch
```

**Behavior**:
1. Loads the `Security.Core` package
2. Executes `keyring fetch` to download the key ring from the configured remote location

**Usage Context**: Called when initializing security with trusted remote key ring support. The fetched key ring is written to a temporary file and then merged.

**Signature**: Signed with the Eagle Enterprise Trust Root key.

---

#### mergeKeyRing

**Purpose**: Merges a specified key ring file into the script key ring.

**Script Content**:
```tcl
package require Security.Core; security true; keyring merge {0}
```

Note: `{0}` is a format placeholder that gets replaced with the actual key ring file path.

**Behavior**:
1. Loads the `Security.Core` package
2. Enables security (`security true`)
3. Merges the specified key ring file into the current key ring

**Usage Context**: Called after `fetchKeyRing` to merge the downloaded key ring into the interpreter's trusted key store.

**Signature**: Signed with the Eagle Enterprise Trust Root key.

---

### Security Considerations

1. **Immutability**: These scripts cannot be modified without access to the signing keys. Any modification will cause signature verification to fail.

2. **Trust Chain**: The scripts signed with the Eagle Enterprise Trust Root key form the foundation of the trust chain, allowing the normal script signing infrastructure to be bootstrapped.

3. **Embedded Resources**: The scripts are compiled into the assembly, preventing file-system-based tampering.

4. **Minimal Privileges**: The cleanup scripts (`removeCommands`, `removeVariables`) are designed to work with minimal privileges, using only basic commands like `foreach`, `catch`, `rename`, `unset`, and `info`.

5. **Safe Interpreter Creation**: The `removeCommands` and `removeVariables` scripts are critical for creating properly isolated safe interpreters, ensuring no commands or variables leak from the parent interpreter.

---

This enables seamless type conversion between Eagle's string-based values and .NET's strongly-typed system.

---

## Managed Assembly Plugin Loader Subsystem

The Eagle plugin loader subsystem provides a comprehensive framework for loading, managing, and unloading managed (.NET) assembly plugins at runtime. This subsystem extends Eagle's functionality by allowing dynamic loading of compiled extensions that can add commands, functions, policies, traces, and other entities to the interpreter.

### Overview

The plugin loader subsystem consists of several key components:

1. **Script Commands**: The `[load]` and `[unload]` script commands provide the primary interface for plugin management
2. **Script Library Package**: The `Eagle.Loader` package provides helper procedures for building `[package ifneeded]` scripts
3. **C# Runtime Infrastructure**: The `Interpreter.LoadPlugin()` and related methods in `RuntimeOps.cs` handle the actual assembly loading
4. **Security Integration**: Strong name verification, Authenticode trust checking, and policy enforcement
5. **AppDomain Isolation**: Optional loading of plugins into isolated application domains

### The `[load]` Command

**Syntax**: `load ?options? fileName ?packageName? ?interp?`

Loads a managed assembly plugin into the interpreter. The plugin assembly must contain one or more classes that implement the `IPlugin` interface.

**Arguments**:
- *fileName*: Path to the plugin assembly file (`.dll`)
- *packageName*: Optional type name of the specific plugin class to load. If omitted, the primary plugin in the assembly is loaded.
- *interp*: Optional target interpreter path. Defaults to the current interpreter.

**Command Flags**: `Unsafe | Critical | Standard | SecuritySdk | LicenseSdk`

**ObjectGroup**: `managedEnvironment`

#### Load Options Reference

| Option | Flags | Description |
|--------|-------|-------------|
| `-ruleset value` | Unsafe | Specifies a rule set for policy evaluation |
| `-needclientdata` | Unsafe | Ensures client data is created if not provided |
| `-anythread` | Unsafe | Allows loading on any thread (not just the primary thread) |
| `-nocommands` | Unsafe | Skips adding commands from the plugin |
| `-nofunctions` | Unsafe | Skips adding expression functions from the plugin |
| `-nopolicies` | Unsafe | Skips adding policies from the plugin |
| `-notraces` | Unsafe | Skips adding variable traces from the plugin |
| `-noprovide` | Unsafe | Skips automatic `[package provide]` for the plugin |
| `-noresources` | Unsafe | Skips querying plugin resources |
| `-verifiedonly` | Unsafe | Requires strong name signature verification |
| `-maybeverifiedonly` | Safe | Enables verification in non-debug builds |
| `-trustedonly` | Unsafe | Requires Authenticode signature and trust |
| `-maybetrustedonly` | Safe | Enables trust checking in non-debug builds |
| `-publickeytoken value` | Unsafe | Requires matching public key token |
| `-isolated` | Unsafe | Loads plugin into an isolated AppDomain |
| `-noisolated` | Unsafe | Prevents isolated loading |
| `-preview` | Unsafe | Enables plugin metadata preview |
| `-nopreview` | Unsafe | Disables plugin metadata preview |
| `-update` | Unsafe | Enables update checking before loading |
| `-noupdate` | Unsafe | Disables update checking |
| `-clientdata value` | N/A | Provides custom client data object |
| `-data value` | N/A | Provides additional data object |
| `-viaresource` | Safe | Loads plugin from embedded resource instead of file |
| `--` | N/A | Marks end of options |

#### Load Examples

**Basic plugin loading**:
```tcl
# Load a plugin from file
load /path/to/MyPlugin.dll

# Load specific plugin class from assembly
load /path/to/Plugin.dll Sample.Class3

# Load into a child interpreter
set child [interp create]
load /path/to/Plugin.dll MyPlugin $child
```

**Security-verified loading**:
```tcl
# Require strong name verification
load -verifiedonly -- /path/to/SignedPlugin.dll

# Require both strong name and Authenticode trust
load -verifiedonly -trustedonly -- /path/to/TrustedPlugin.dll

# Verify specific public key token
load -publickeytoken 0x29c6297630be05eb -- /path/to/Plugin.dll
```

**Isolated plugin loading**:
```tcl
# Load into isolated AppDomain
load -isolated -- /path/to/UntrustedPlugin.dll

# Load without commands (just initialize)
load -nocommands -nofunctions -- /path/to/Plugin.dll
```

### The `[unload]` Command

**Syntax**: `unload ?options? fileName ?packageName? ?interp?`

Unloads a previously loaded plugin from the interpreter. If the plugin was loaded into an isolated AppDomain, that AppDomain is unloaded.

**Arguments**:
- *fileName*: Path to the plugin assembly file
- *packageName*: Optional type name or plugin name pattern to match
- *interp*: Optional target interpreter path

**Command Flags**: `Unsafe | Critical | Standard`

**ObjectGroup**: `managedEnvironment`

#### Unload Options Reference

| Option | Description |
|--------|-------------|
| `-clientdata value` | Provides custom client data object |
| `-data value` | Provides additional data object |
| `-nocase` | Performs case-insensitive name matching |
| `-keeplibrary` | Keeps the library loaded but removes the package |
| `-nocomplain` | Suppresses errors if package is not loaded |
| `-match mode` | Specifies match mode: `exact`, `glob`, or `regexp` (default: `glob`) |
| `--` | Marks end of options |

#### Unload Examples

```tcl
# Basic unload
unload /path/to/MyPlugin.dll

# Unload specific plugin class
unload /path/to/Plugin.dll Sample.Class3

# Unload with glob pattern matching
unload -match glob /path/to/Plugin.dll "Sample.Class*"

# Case-insensitive unload
unload -nocase /path/to/Plugin.dll mypackage

# Silent unload (no error if not loaded)
unload -nocomplain /path/to/Plugin.dll
```

### The Eagle.Loader Script Package

The `Eagle.Loader` package (source: `Eagle/Library/Resources/loader.eagle`) provides helper procedures for constructing `[package ifneeded]` scripts that can dynamically load binary plugins.

#### Package Namespace

All procedures are defined in the `::Eagle` namespace.

#### Key Procedures

**`::Eagle::isEagleForLoader`**: Detects if running in Eagle vs. Tcl
```tcl
# Returns non-zero only when running in Eagle
if {[::Eagle::isEagleForLoader]} {
    # Eagle-specific code
}
```

**`::Eagle::isMonoForLoader`**: Detects if running on Mono runtime
```tcl
if {[::Eagle::isMonoForLoader]} {
    # Mono-specific handling
}
```

**`::Eagle::isDotNetCoreForLoader`**: Detects if running on .NET Core/.NET 5+
```tcl
if {[::Eagle::isDotNetCoreForLoader]} {
    # .NET Core-specific handling
}
```

**`::Eagle::isWindowsForLoader`**: Detects if running on Windows
```tcl
if {[::Eagle::isWindowsForLoader]} {
    # Windows-specific paths
}
```

**`::Eagle::getPatchLevelForLoader`**: Returns the Eagle core library patch level
```tcl
set version [::Eagle::getPatchLevelForLoader]
```

**`::Eagle::getBuildTypeForLoader`**: Returns the build type (e.g., "Bare", "MonoOnUnix")
```tcl
set buildType [::Eagle::getBuildTypeForLoader]
```

**`::Eagle::createLoadCommand`**: Constructs a `[load]` command with appropriate options
```tcl
# Create load command for plugin
set loadCmd [::Eagle::createLoadCommand MyPlugin $publicKeyToken]
# Result: "::load -publickeytoken 0x... -maybeverifiedonly -maybetrustedonly -- $fileName MyPlugin"
```

**`::Eagle::maybeCreatePackageIfNeededCommand`**: Creates a complete `[package ifneeded]` script
```tcl
# Create package ifneeded command
set cmd [::Eagle::maybeCreatePackageIfNeededCommand \
    MyPackage $dir {Plugin.dll} tag "1.0"]

# Execute it to register the package
eval $cmd
```

#### Loader Package Usage Pattern

The idiomatic usage of the Eagle.Loader package is from `pkgIndex.eagle` files (not `pkgIndex.tcl`), as it relies on Eagle-specific extensions. The `$dir` variable is automatically set by the package indexing system to the directory containing the index file.

```tcl
# In a pkgIndex.eagle file:
if {![package vsatisfies [package provide Tcl] 8.4]} {return}
if {![package vsatisfies [package provide Eagle] 1.0]} {return}

###############################################################################

eval [maybeCreatePackageIfNeededCommand \
    Sample.Class3 $dir [list Plugin.dll] tag 1.0]

eval [maybeCreatePackageIfNeededCommand \
    Sample.Class4 $dir [list Plugin.dll] tag 1.0]
```

**Key Points**:
- The version checks ensure the script only runs in compatible environments
- Multiple plugins from the same assembly can be registered with separate calls
- The `$dir` variable is provided by the package system and points to the directory containing the `pkgIndex.eagle` file
- The `eval` command executes the generated `[package ifneeded]` script to register the package

#### Tagged Package Index Files

When a package index file is named with a tag suffix (e.g., `pkgIndex_29c6297630be05eb.eagle`), the package index subsystem automatically provides the `tag` variable set to that 16-character hexadecimal string. This tag represents the public key token of the target assembly.

**File Naming Convention**:
```
pkgIndex_<16-char-hex-public-key-token>.eagle
```

**Example**:
```
pkgIndex_29c6297630be05eb.eagle
```

In this case, when the package index file is processed, the `tag` variable is automatically set to `29c6297630be05eb`.

**Security Chain**:
1. The tagged filename encodes the expected public key token
2. The package index subsystem extracts the tag and provides it as a variable
3. The `maybeCreatePackageIfNeededCommand` procedure uses the tag to build a `[load]` command with the `-publickeytoken` option
4. When the plugin is loaded, the `-publickeytoken 0x29c6297630be05eb` option ensures the loaded assembly's public key token matches the expected value
5. If the tokens don't match, the load fails, preventing unauthorized assemblies from being loaded

This mechanism provides cryptographic binding between the package index and the plugin assembly, ensuring that only assemblies signed with the correct key can be loaded through that package index

#### Build Type Handling

The loader automatically adjusts behavior based on the build type:

- **Bare**: No P/Invoke support; skips strong name and Authenticode verification
- **MonoOnUnix**: Limited verification unless running on Mono
- **Standard**: Full verification support

```tcl
set buildType [::Eagle::getBuildTypeForLoader]

if {$buildType ni [list Bare]} {
    # Can use strong name verification
    lappend loadCmd -maybeverifiedonly
}
```

### PluginFlags Enumeration

The `PluginFlags` enumeration controls plugin loading and behavior. Flags can be set via command options or programmatically.

#### Plugin Type Flags

| Flag | Value | Description |
|------|-------|-------------|
| `Primary` | 0x4 | Primary plugin in the assembly |
| `System` | 0x8 | System plugin (part of Eagle runtime) |
| `Host` | 0x10 | Plugin contains a custom host |
| `Debugger` | 0x20 | Plugin contains a script debugger |
| `User` | 0x40 | Third-party user plugin |
| `Commercial` | 0x80 | Commercial/proprietary plugin |
| `Proprietary` | 0x100 | Contains proprietary code |

#### Content Flags

| Flag | Value | Description |
|------|-------|-------------|
| `Command` | 0x200 | Contains custom commands |
| `Function` | 0x400 | Contains expression functions |
| `Trace` | 0x800 | Contains variable traces |
| `Notify` | 0x1000 | Listens for notifications |
| `Policy` | 0x2000 | Contains policies (requires Primary) |
| `Resolver` | 0x4000 | Contains command/variable resolvers |

#### Loading Context Flags

| Flag | Value | Description |
|------|-------|-------------|
| `Static` | 0x8000 | Statically provided by application |
| `Demand` | 0x10000 | Loaded on-demand by `[load]` command |
| `UnsafeCode` | 0x20000 | Contains unsafe code |
| `NativeCode` | 0x40000 | Contains native code |
| `SafeCommands` | 0x80000 | Only contains safe commands |

#### Behavior Control Flags

| Flag | Value | Description |
|------|-------|-------------|
| `MergeCommands` | 0x100000 | Ignore existing commands when adding |
| `OverwriteCommands` | 0x200000 | Overwrite existing commands |
| `MergeProcedures` | 0x400000 | Ignore existing procedures |
| `OverwriteProcedures` | 0x800000 | Overwrite existing procedures |
| `MergePolicies` | 0x1000000 | Ignore existing policies |
| `OverwritePolicies` | 0x2000000 | Overwrite existing policies |
| `NoInitialize` | 0x10000000 | Skip initialization logic |
| `NoTerminate` | 0x20000000 | Skip termination logic |
| `NoCommands` | 0x40000000 | Don't add commands |
| `NoFunctions` | 0x80000000 | Don't add functions |
| `NoPolicies` | 0x100000000 | Don't add policies |
| `NoTraces` | 0x200000000 | Don't add traces |
| `NoProvide` | 0x400000000 | Don't provide package |
| `NoResources` | 0x800000000 | Don't query resources |

#### Security Flags

| Flag | Value | Description |
|------|-------|-------------|
| `StrongName` | 0x20000000000 | Assembly has strong name signature |
| `Verified` | 0x40000000000 | Strong name has been verified |
| `VerifiedOnly` | 0x80000000000 | Require strong name verification |
| `SkipVerified` | 0x100000000000 | Skip verification |
| `Authenticode` | 0x200000000000 | Assembly has Authenticode signature |
| `Trusted` | 0x400000000000 | Authenticode is trusted |
| `TrustedOnly` | 0x800000000000 | Require Authenticode trust |
| `SkipTrusted` | 0x1000000000000 | Skip trust checking |

#### Isolation Flags

| Flag | Value | Description |
|------|-------|-------------|
| `Isolated` | 0x4000000000000 | Load into isolated AppDomain |
| `NoIsolated` | 0x8000000000000 | Prevent isolated loading |
| `IsolatedOnly` | 0x10000000000000 | Must load into isolated AppDomain |
| `NoIsolatedOnly` | 0x20000000000000 | Prevent IsolatedOnly from being honored |
| `NoUseEntryAssembly` | 0x40000000000000 | Don't reset entry assembly |
| `OptionalEntryAssembly` | 0x80000000000000 | Ignore entry assembly errors |
| `VerifyCoreAssembly` | 0x100000000000000 | Verify core assembly in AppDomain |
| `UpdateCheck` | 0x200000000000000 | Check for plugin updates |
| `NoUpdateCheck` | 0x400000000000000 | Prevent update checking |
| `NoPreview` | 0x800000000000000 | Disable metadata preview |

#### Threading Flags

| Flag | Value | Description |
|------|-------|-------------|
| `LoadOnAnyThread` | 0x4000000000000000 | Allow loading on any thread |

### Plugin Lifecycle

#### Loading Phase

1. **Policy Check**: The engine checks plugin policies before loading
2. **Thread Verification**: Verifies loading is happening on the correct thread (unless `-anythread`)
3. **Security Verification**:
   - Strong name verification (if `-verifiedonly` or `-maybeverifiedonly`)
   - Authenticode trust checking (if `-trustedonly` or `-maybetrustedonly`)
   - Public key token matching (if `-publickeytoken`)
4. **Preview Phase** (if not `-nopreview`): Creates temporary AppDomain to preview plugin metadata
5. **AppDomain Creation**: Creates or obtains AppDomain (isolated or default)
6. **Assembly Loading**: Loads the assembly bytes or file into the target AppDomain
7. **Type Resolution**: Locates the plugin type within the assembly
8. **Plugin Instantiation**: Creates the plugin instance
9. **Initialization**: Calls `IState.Initialize()` on the plugin
10. **Entity Registration**: Adds commands, functions, policies, traces as appropriate
11. **Package Provision**: Automatically provides the package (unless `-noprovide`)
12. **Notification**: Sends `NotifyType.Plugin` notification with `NotifyFlags.Load`

#### Unloading Phase

1. **Plugin Lookup**: Finds the plugin by name, token, or file path
2. **Pre-Unload Notification**: Sends `NotifyFlags.PreUnload` notification
3. **Termination**: Calls `IState.Terminate()` on the plugin
4. **Entity Removal**: Removes commands, functions, policies, traces
5. **Post-Unload Notification**: Sends `NotifyFlags.Unload` notification
6. **AppDomain Unload**: If isolated, unloads the associated AppDomain

### Isolated Plugin Loading

Isolated plugins are loaded into separate AppDomains, providing:

- **Memory Isolation**: Plugin can be fully unloaded, freeing memory
- **Security Boundary**: Plugin runs with restricted permissions
- **Version Isolation**: Different assembly versions can coexist
- **Crash Isolation**: Plugin failures don't crash the host

#### Enabling Isolation

```tcl
# Via command option
load -isolated /path/to/Plugin.dll

# Via interpreter plugin flags
package require Eagle.Test
enablePluginFlags Isolated true
load /path/to/Plugin.dll
```

#### Isolation Considerations

1. **Cross-AppDomain Marshaling**: Data crossing AppDomain boundaries must be serializable or MarshalByRefObject
2. **Performance**: Isolated calls have marshaling overhead
3. **Debugging**: Isolated plugins are harder to debug
4. **Static State**: Each AppDomain has its own static state

### Security Integration

#### Policy-Based Security

Plugins can be allowed or denied by interpreter policies:

```tcl
# Example: Policy callback to deny specific plugins
proc MyPluginPolicy {args} {
    array set info $args
    if {[string match "*Untrusted*" $info(typeName)]} {
        return -code error "Plugin denied by policy"
    }
    return approved
}
```

#### Strong Name Verification

Strong name verification ensures the assembly hasn't been tampered with:

```tcl
# Require verification
load -verifiedonly /path/to/Plugin.dll

# In loader scripts, automatically enabled for non-Bare builds
lappend loadCmd -maybeverifiedonly
```

#### Authenticode Trust

Authenticode verification checks the assembly is signed and the certificate is trusted:

```tcl
# Require trust
load -trustedonly /path/to/Plugin.dll

# For official Eagle plugins
load -maybeverifiedonly -maybetrustedonly /path/to/OfficialPlugin.dll
```

### Resource-Based Loading

Plugins can be loaded from embedded resources instead of files:

```tcl
# Load plugin from embedded resource
load -viaresource MyPlugin.dll

# RuntimeOps.LoadPlugin retrieves bytes from host's GetData method
```

This is used internally for loading plugins embedded in the host application.

### Testing Plugin Loading

The test file `Eagle/Library/Tests/load.eagle` provides comprehensive test coverage:

```tcl
# Test isolated plugin loading
runTest {test load-1.1.1 {load/unload isolated plugin assembly} -setup {
    package require Eagle.Test
    set savedPluginFlags [enablePluginFlags]
    enablePluginFlags Isolated true
} -body {
    set file [file join $core_lib_path Plugin1.0 Plugin.dll]
    list [llength [info loaded]] \
         [load $file Sample.Class3 {}] \
         [llength [info loaded]] \
         [unload -match glob $file "Sample.Class3, *" {}] \
         [llength [info loaded]]
} -cleanup {
    enablePluginFlags $savedPluginFlags
}}
```

### Introspection

**`[info loaded]`**: Lists loaded plugins
```tcl
# List all loaded plugins
info loaded

# Filter by interpreter
info loaded "" $childInterp

# Filter by pattern
info loaded "" "" "*Sample*"
```

**`[info load]`**: Returns low-level load information

### Error Handling

Plugin loading can fail for various reasons:

- **File Not Found**: Assembly file doesn't exist
- **Policy Denied**: Interpreter policy rejected the plugin
- **Wrong Thread**: Loading attempted on non-primary thread without `-anythread`
- **Verification Failed**: Strong name or Authenticode verification failed
- **Type Not Found**: Specified plugin type doesn't exist in assembly
- **Initialization Failed**: Plugin's `Initialize()` method returned error
- **Already Loaded**: Plugin is already loaded (unless merge/overwrite flags set)

```tcl
# Handle loading errors
if {[catch {load /path/to/Plugin.dll} err]} {
    puts "Plugin load failed: $err"
}
```

---

## Notes

1. **Command Flags**: All commands are decorated with CommandFlags attributes indicating:
   - Safe/Unsafe: Whether command can run in safe interpreter
   - Standard/NonStandard: Whether command is part of standard Tcl/Eagle
   - Critical: Whether command performs critical operations
   - Diagnostic: Whether command is for diagnostic purposes
   - Obsolete: Whether command is deprecated
   - Initialize: Whether command is needed during initialization
   - SecuritySdk/LicenseSdk: SDK-related flags

2. **ObjectGroup Categories**: Commands are organized by ObjectGroup for logical categorization and documentation purposes.

3. **Sub-Commands**: Many commands (debug, object, interp, file, string, etc.) are ensemble commands with extensive sub-commands, providing rich functionality in a hierarchical structure.

4. **Option Consistency**: Eagle maintains consistent option naming across commands, making it easier to learn and use related commands.

5. **Test Infrastructure**: The test commands (test1, test2) and test functions provide comprehensive testing capabilities, essential for ensuring Eagle interpreter reliability.

6. **Tcl Compatibility**: Many commands maintain compatibility with Tcl while extending functionality for .NET integration.

---

## Advanced: Interpreter Customization Hooks

Eagle provides extensive mechanisms for customizing interpreter behavior at runtime. This section documents the advanced customization APIs available for modifying commands, sub-commands, and name resolution.

### Sub-Command Manipulation

Eagle ensemble commands (like `string`, `file`, `info`, etc.) use an `EnsembleDictionary` to map sub-command names to their implementations. These dictionaries can be accessed and modified at runtime.

#### Command Properties

Each ensemble command object exposes three key properties for sub-command management:

| Property | Description |
|----------|-------------|
| `SubCommands` | Dictionary of available sub-commands (name → ISubCommand or null) |
| `AllowedSubCommands` | Whitelist of sub-commands (if set, only these are allowed) |
| `DisallowedSubCommands` | Blacklist of sub-commands (these are explicitly denied) |

#### Accessing Sub-Commands via Object System

```tcl
# Get interpreter reference
set interpreter [object invoke Interpreter.GetActive]

# Get a command object (e.g., "string")
set command null; set error null
set code [$interpreter GetIdentifier Command string null Default command error]

# Access the sub-commands dictionary
object flags $command +NoDispose  ;# Command is not owned by us
set subCommands [$command -alias SubCommands]

# List all sub-command names
$subCommands Keys

# Remove a sub-command
$subCommands Remove length

# Add a sub-command back (with null = use core implementation)
$subCommands Add length null
```

#### The `interp subcommand` Command

The `interp subcommand` command provides a simpler interface for sub-command manipulation:

```
interp subcommand ?options? path cmdName subCmdName ?command?
```

**Arguments:**
- `path` - Interpreter path ("" for current interpreter)
- `cmdName` - Name of the ensemble command (e.g., "string")
- `subCmdName` - Name of the sub-command (e.g., "length")
- `command` - (Optional) Script command to execute for this sub-command

**Options (`-flags`):**

| Flag | Description |
|------|-------------|
| `ForceQuery` | Query sub-command even if arguments suggest modification |
| `ForceNew` | Sub-command must be added new, not modified |
| `ForceReset` | Re-add sub-command during reset if it doesn't exist |
| `ForceDelete` | Remove sub-command instead of reset (with empty command) |
| `NoComplain` | Don't error if sub-command exists/doesn't exist |
| `StrictNoArguments` | Error if arguments present (script won't process them) |
| `UseExecuteArguments` | Append execution arguments to script command |
| `SkipNameArguments` | Omit command/sub-command names from passed arguments |

**Examples:**

```tcl
# Query a sub-command
interp subcommand {} string length

# Remove a sub-command
interp subcommand -flags ForceDelete {} string length {}

# Add a custom sub-command that calls a procedure
interp subcommand {} string myLength {string_myLength}

# Add with argument passing
interp subcommand -flags UseExecuteArguments {} string upper {myUpperProc}
```

### Creating Custom Sub-Commands

For more control, you can create custom `ISubCommand` implementations. The test infrastructure provides an example class `Eagle._Tests.Default+SubCommand`:

```tcl
# Create a script command list
set list [object create -alias StringList]
$list Add return
$list Add "custom result"

# Create a custom sub-command
set subCommand [object create -alias Eagle._Tests.Default+SubCommand \
    mySubCmd           ;# name
    $command           ;# parent command
    null               ;# callback
    null               ;# clientData
    None               ;# commandFlags
    $list              ;# scriptCommand
    null               ;# execute (IExecute)
    1                  ;# nameIndex
    false              ;# useIExecute
    false              ;# strictNoArguments
    false              ;# useExecuteArguments
    false]             ;# skipNameArguments

# Add to the sub-commands dictionary
$subCommands Add mySubCmd $subCommand
```

#### SubCommand Constructor Parameters

| Parameter | Description |
|-----------|-------------|
| `name` | Sub-command name |
| `command` | Parent ICommand reference |
| `callback` | ExecuteCallback delegate (optional) |
| `clientData` | Custom client data (optional) |
| `commandFlags` | CommandFlags for the sub-command |
| `scriptCommand` | StringList of script to evaluate |
| `execute` | IExecute to dispatch to (if useIExecute is true) |
| `nameIndex` | Index of sub-command name in arguments |
| `useIExecute` | Use IExecute instead of scriptCommand |
| `strictNoArguments` | Error if extra arguments provided |
| `useExecuteArguments` | Pass execution arguments to script |
| `skipNameArguments` | Skip command/sub-command name args |

#### Wrapping Existing Sub-Commands

You can wrap an existing sub-command to intercept or modify its behavior:

```tcl
# Get the existing sub-command
set oldSubCommand [$subCommands Item length]
object flags $oldSubCommand +NoDispose

# Create a wrapper that calls the original
set wrapperScript [object create -alias StringList]
$wrapperScript Add puts
$wrapperScript Add "Calling string length..."

set newSubCommand [object create -alias Eagle._Tests.Default+SubCommand \
    length $command null null None $wrapperScript $oldSubCommand true false false false]

# Replace in dictionary
$subCommands Item length $newSubCommand
```

### Custom Name Resolution (IResolve Interface)

Eagle allows installing custom resolvers that intercept name lookup for variables, commands, namespaces, and call frames. This is useful for:

- Creating virtual variables that map to external data sources
- Redirecting command execution to different interpreters
- Implementing custom namespace resolution logic
- Cross-interpreter variable/command sharing

#### IResolve Interface Methods

| Method | Description |
|--------|-------------|
| `GetVariableFrame` | Resolve the call frame for variable lookup |
| `GetCurrentNamespace` | Resolve the current namespace |
| `GetIExecute` | Resolve command name to IExecute instance |
| `GetVariable` | Resolve variable name to IVariable instance |

#### Creating and Installing a Resolver

```tcl
# Create resolver with a decision script
set script {
    if {[isNonNullObjectHandle varName]} then {
        if {[getStringFromObjectHandle varName] eq "special"} then {
            return true  ;# Use our custom resolution
        }
    }
    return false  ;# Use default resolution
}

# Create resolver instance
# Arguments: sourceInterp, targetInterp, script, frame, namespace, execute, variable, flags
set resolve [object create -alias Eagle._Tests.Default+Resolve \
    $interp1 $interp2 $script $frame null null null Default]

# Install the resolver
set result null
$targetInterpreter AddResolver $resolve null Default result
```

#### Resolver Use Cases

**Cross-Interpreter Variable Access:**
```tcl
# In interp1
set sharedVar "Hello from interp1"

# Create resolver that redirects "sharedVar" lookups to interp1
set frame [getScopeFrame $interp1 global]
set resolve [object create -alias Eagle._Tests.Default+Resolve \
    $interp1 $interp2 $script $frame null null null Default]

# Install in interp2 - now $sharedVar in interp2 reads from interp1
```

**Command Redirection:**
```tcl
# Redirect unknown commands to another interpreter
set execute [getIExecute $interp1 myProc]
set resolve [object create -alias Eagle._Tests.Default+Resolve \
    $interp1 $interp2 $script null null $execute null Default]
```

#### TestResolveFlags

Resolvers can be configured with flags that modify their behavior:

| Flag | Description |
|------|-------------|
| `Default` | No special handling |
| `HandleGlobalOnly` | Handle global-only variable lookups |
| `HandleAbsolute` | Handle absolute namespace names |
| `HandleQualified` | Handle qualified names |
| `EnableLogging` | Enable debug trace logging |
| `AlwaysUseNamespaceFrame` | Always use namespace's frame |
| `NextUseNamespaceFrame` | Use namespace frame on next call |

### Command Object Manipulation

Beyond sub-commands, you can modify command objects directly:

```tcl
# Get command object
set command [getCommand "" myCommand false]

# Modify description
$command Description "New description string"

# Check/modify command flags
set flags [$command CommandFlags]

# Access the underlying .NET object
set obj [$command -create -alias Object]
```

### Best Practices

1. **Use `object flags +NoDispose`** when accessing interpreter-owned objects to prevent premature disposal.

2. **Isolated interpreters** provide a safer environment for customization experiments:
   ```tcl
   set interp [interp create -isolated]
   # Customizations in $interp won't affect the parent
   ```

3. **Test customizations thoroughly** - modifying core commands can break scripts in subtle ways.

4. **Consider using `AllowedSubCommands`** instead of removing sub-commands for security restrictions:
   ```tcl
   set allowed [object create -alias EnsembleDictionary]
   $allowed Add length null
   $allowed Add index null
   $command AllowedSubCommands $allowed
   # Now only "length" and "index" sub-commands are available
   ```

5. **Restore modified commands** using `debug restore` if needed:
   ```tcl
   debug restore  ;# Restores all core commands to original state
   ```

### See Also

- `Eagle/Library/Tests/redefine.eagle` - Comprehensive test suite for customization features
- `Eagle/Library/Tests/Default.cs` - Test support classes including SubCommand and Resolve
- `Eagle/Library/Commands/Interp.cs` - Implementation of `interp subcommand`

---

## Advanced: Automatic Command Mapping Subsystem

Eagle provides a powerful mechanism for automatically exposing .NET type methods as script commands through the **Automatic Command Mapping** subsystem. This feature dynamically maps .NET methods to script sub-commands, providing direct access to .NET functionality without writing custom command classes.

### Overview

The automatic command system creates ensemble commands where each sub-command corresponds to a method on a .NET type. Method overloads are automatically resolved based on parameter count, and delegates are dynamically created for efficient invocation.

**Key components:**

| Component | Description |
|-----------|-------------|
| `Automatic` command class | The ensemble command that dispatches to mapped methods |
| `DelegateMapper` | Maps .NET types/methods to delegates organized by name and parameter count |
| `TypedInstance` | Wraps a type and optional object instance for method invocation |
| `AddAutomaticCommands` | Interpreter method to register automatic commands |

### Creating Automatic Commands

Automatic commands are created using the `Interpreter.AddAutomaticCommands` method:

```tcl
# Get interpreter reference
set interpreter null; set error null
set code [object invoke -alias Value GetInterpreter "" "" Default interpreter error]

# Create a TypedInstance for the target type
set typeName "System.Int64"
set instance [object invoke -create $typeName Parse 12345]

set typedInstance [object create -alias TypedInstance \
    $typeName None $instance myInt64 null null]

# Create a list of TypedInstances
set typedInstances [object create -alias \
    [appendArgs System.Collections.Generic.List`1 \
    \[Eagle._Components.Public.TypedInstance\]]]

$typedInstances Add $typedInstance

# Add automatic commands
set bindingFlags {Public NonPublic Instance Static}
set delegateFlags null
set count 0
set tokens null
set result null

set code [$interpreter AddAutomaticCommands \
    null null $typedInstances null $bindingFlags \
    null $delegateFlags false count tokens result]

# Now "myInt64" is a command with sub-commands for Int64 methods:
# myInt64 ToString
# myInt64 GetHashCode
# myInt64 GetType
# myInt64 CompareTo <value>
# etc.
```

### TypedInstance

A `TypedInstance` encapsulates the information needed for automatic command creation:

```tcl
set typedInstance [object create -alias TypedInstance \
    $typeName       ;# Type - the .NET type containing methods
    $objectFlags    ;# ObjectFlags - flags controlling object handling
    $instance       ;# Object - instance for instance methods (or null for static-only)
    $objectName     ;# ObjectName - short command name
    $fullObjectName ;# FullObjectName - optional full name (fallback)
    $extraParts]    ;# ExtraParts - additional name parts (optional)
```

**Constructor parameters:**

| Parameter | Description |
|-----------|-------------|
| `type` | The .NET `Type` whose methods will be mapped |
| `objectFlags` | `ObjectFlags` controlling object handling behavior |
| `object` | Object instance for instance method invocation (null = static only) |
| `objectName` | Short name used as the command name |
| `fullObjectName` | Optional fallback name if `objectName` is null |
| `extraParts` | Additional name components (rarely used) |

### Command Syntax

Once created, automatic commands follow this syntax:

```
commandName ?options? methodName ?arg ...?
```

**Example:**
```tcl
# Call ToString with no arguments
myInt64 ToString

# Call instance method with arguments
myObject SomeMethod arg1 arg2

# Use options for advanced control
myObject -flags +NonPublic GetPrivateData
```

### Command Options

Automatic commands support extensive options (shared with `[library call]` and `[object invoke]`):

#### Method Selection Options

| Option | Description |
|--------|-------------|
| `-flags <bindingFlags>` | .NET BindingFlags for method lookup (e.g., `+NonPublic`) |
| `-bindingflags <flags>` | Alias for `-flags` |
| `-autolimit <n>` | Limit number of method overloads considered |
| `-autoindex <n>` | Select specific overload by index (0-based) |
| `-limit <n>` | Limit overloads (used during method resolution) |
| `-index <n>` | Select specific overload (used during invocation) |

#### Object Handling Options

| Option | Description |
|--------|-------------|
| `-create` | Create an opaque object handle for the return value |
| `-alias` | Create an aliased object handle (command alias) |
| `-aliasraw` | Create raw alias without extra processing |
| `-aliasall` | Alias all returned objects |
| `-aliasreference` | Create reference alias |
| `-nodispose` | Prevent automatic disposal of returned object |
| `-objectname <name>` | Specify name for created object handle |
| `-objectflags <flags>` | Flags for object handle creation |
| `-byrefobjectflags <flags>` | Flags for by-reference parameters |

#### Type Conversion Options

| Option | Description |
|--------|-------------|
| `-type <typeName>` | Specify expected return type |
| `-marshalflags <flags>` | Flags controlling value marshaling |
| `-argumentflags <flags>` | Flags for by-reference argument handling |
| `-datetimekind <kind>` | DateTimeKind for date conversions |
| `-datetimestyles <styles>` | DateTimeStyles for date parsing |
| `-datetimeformat <format>` | Custom date/time format string |

#### Invocation Control Options

| Option | Description |
|--------|-------------|
| `-noinvoke` | Don't invoke, just resolve the method |
| `-noargs` | Don't pass arguments to the method |
| `-nocase` | Case-insensitive method name matching |
| `-strictmember` | Require exact method match |
| `-strictargs` | Strict argument type matching |
| `-nobyref` | Disable by-reference parameter handling |
| `-default` | Use default parameter values |
| `-verbose` | Enable verbose error messages |
| `-debug` | Enable debug output |
| `-trace` | Enable trace output |
| `-tostring` | Convert result to string |

#### Maintenance Options

| Option | Description |
|--------|-------------|
| `-autocreate <bool>` | Create target object on-demand if not already created |
| `-autoflush <bool>` | Clear cached delegates (true = delegates only, false = all) |
| `-autostatus <bool>` | Report count of mapped types/delegates |

### Method Resolution

The automatic command system resolves methods based on:

1. **Method name** - Matched case-insensitively by default
2. **Parameter count** - Number of arguments determines which overloads are eligible
3. **BindingFlags** - Controls visibility (Public, NonPublic, Instance, Static)
4. **Safe/Unsafe attributes** - Methods marked with `[CommandFlags(CommandFlags.Unsafe)]` are blocked in safe interpreters

**Overload selection process:**
1. Find all methods with matching name and parameter count
2. Filter by binding flags and safety requirements
3. If multiple matches remain, use `-autoindex` or let the marshaller choose
4. Create/cache delegate for the selected method
5. Invoke the delegate with converted arguments

### Safety and Security

Methods can be annotated with `[CommandFlags]` attributes to control accessibility:

```csharp
public class MyType
{
    [CommandFlags(CommandFlags.None)]
    public void NeutralMethod() { }  // Accessible from any interpreter

    [CommandFlags(CommandFlags.Safe)]
    public void SafeMethod() { }     // Accessible from safe interpreters

    [CommandFlags(CommandFlags.Unsafe)]
    public void UnsafeMethod() { }   // Blocked in safe interpreters
}
```

When running in a safe interpreter:
- Methods with `CommandFlags.Safe` are allowed
- Methods with `CommandFlags.Unsafe` are blocked with "permission denied"
- Methods with `CommandFlags.None` follow the interpreter's default policy

### DelegateFlags

The `DelegateFlags` enumeration controls automatic command behavior:

| Flag | Description |
|------|-------------|
| `None` | No special handling (default) |
| `Public` | Include public members |
| `NonPublic` | Include non-public members |
| `Instance` | Include instance members |
| `Static` | Include static members |
| `AllowDuplicate` | Don't error on duplicate delegate names |
| `OverwriteExisting` | Replace existing delegates |
| `FailOnNone` | Fail if no methods found |
| `NoComplain` | Continue on errors |
| `Verbose` | Enable verbose error reporting |
| `UseCallOptions` | Allow `[library call]` options |
| `UseReturnOptions` | Allow `[object invoke]` return options |
| `LookupObjects` | Translate object handles in arguments |
| `MakeIntoObject` | Convert unsupported return types to object handles |
| `WrapReturnType` | Force wrapping of return values |

### AddAutomaticCommands Method

```csharp
public ReturnCode AddAutomaticCommands(
    IPlugin plugin,                            // Optional parent plugin
    IClientData clientData,                    // Optional client data
    IEnumerable<TypedInstance> typedInstances, // Types/instances to map
    IDelegateMapper mapper,                    // Optional shared mapper
    BindingFlags? bindingFlags,                // Method binding flags
    MarshalFlags? marshalFlags,                // Marshaling flags
    DelegateFlags? delegateFlags,              // Delegate creation flags
    bool? safe,                                // Override safe mode
    ref long count,                            // Output: items added
    ref LongList tokens,                       // Output: command tokens
    ref Result result                          // Output: error message
)
```

### DelegateMapper

The `DelegateMapper` class maintains the mapping between .NET methods and script delegates:

**Structure:** `Type → MethodName → ParameterCount → List<(MethodBase, Delegate, DelegateFlags)>`

**Key methods:**
- `Load(type, bindingFlags, ...)` - Load all methods from a type
- `Lookup(type, methodName, paramCount, ...)` - Find matching delegates
- `Clear(delegatesOnly, ...)` - Clear cached delegates
- `Count(delegatesOnly, ...)` - Count mappings
- `ToList(...)` - Get available sub-commands for help/completion
- `CreateEnsemble(type, argCount)` - Create EnsembleDictionary for sub-command dispatch

### Complete Example

```tcl
# Create an automatic command for a custom test class
# Assumes Eagle._Tests.Default+Automatic class is available

set interpreter [object invoke Interpreter.GetActive]

# Create instance of the test class
set instance [object invoke -alias Eagle._Tests.Default+Automatic Create]

# Create TypedInstance
set typedInstance [object create -alias TypedInstance \
    Eagle._Tests.Default+Automatic None $instance automatic null null]

# Build list
set typedInstances [object create -alias \
    {System.Collections.Generic.List`1[Eagle._Components.Public.TypedInstance]}]
$typedInstances Add $typedInstance

# Register automatic command
set count 0; set tokens null; set result null
$interpreter AddAutomaticCommands null null $typedInstances null \
    {Public NonPublic Instance Static} null null false count tokens result

# Now use the automatic command
automatic NeutralStaticMethod          ;# Call with 0 args
automatic NeutralStaticMethod 1234     ;# Call with 1 int arg
automatic NeutralStaticMethod "test"   ;# Call with 1 string arg (different overload)
automatic NeutralStaticMethod 10 20    ;# Call with 2 args

# Check status
automatic -autostatus true             ;# Returns delegate count

# Clear cached delegates
automatic -autoflush true              ;# Clear delegate cache only
automatic -autoflush false             ;# Clear all mappings

# Access non-public members
automatic -flags +NonPublic get_SomePrivateProperty
```

### Error Handling

When method resolution or invocation fails, the automatic command provides detailed error messages:

```tcl
# Method not found
% myObject NonExistentMethod
bad option "NonExistentMethod": must be ToString, GetHashCode, ...

# Wrong number of arguments
% myObject MethodWith2Args arg1
wrong # args: should be "myObject ?options? method ?arg ...?"

# Permission denied (in safe interpreter)
% myObject UnsafeMethod
permission denied: safe interpreter cannot use method overload System.Type.UnsafeMethod(..)

# Overload ambiguity
% myObject OverloadedMethod arg
# (Uses -autoindex to select specific overload)
```

### Implementation Files

| File | Description |
|------|-------------|
| `Eagle/Library/Commands/Automatic.cs` | The `Automatic` command class implementation |
| `Eagle/Library/Components/Private/DelegateMapper.cs` | Method-to-delegate mapping logic |
| `Eagle/Library/Components/Private/DelegateOps.cs` | Delegate type creation utilities |
| `Eagle/Library/Components/Private/ObjectOps.cs` | `GetCallOptions()` and marshaling support |
| `Eagle/Library/Components/Private/ScriptOps.cs` | `NewAutomaticCommand()` factory method |
| `Eagle/Library/Components/Public/TypedInstance.cs` | Type/instance wrapper class |
| `Eagle/Library/Components/Public/Interpreter.cs` | `AddAutomaticCommands()` method |

### See Also

- `Eagle/Library/Tests/interp-exited.eagle` - Test "interp-1.70001" demonstrates automatic commands
- `Eagle/Library/Tests/Default.cs` - `Automatic` test class with various method signatures
- `[library call]` command - Similar invocation options
- `[object invoke]` command - Related object invocation functionality
