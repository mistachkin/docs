# Eagle `[array]` Command — Deep-Dive Analysis

## 1. Executive Summary

The Eagle `[array]` command provides **17 sub-commands** for associative
array manipulation, backed by a polymorphic storage system that supports
eight distinct backend types. While Tcl's `[array]` offers roughly 10
sub-commands for basic hash table operations, Eagle extends this with
deep copy support, default values (TIP #508), random element selection,
`[array for]`/`[array foreach]`/`[array lmap]` iteration, per-element flags,
and virtual arrays backed by environment variables, .NET `System.Array`
objects, database connections, network state, Windows registry, and
thread-local storage.

Key differentiators from Tcl:

| Area | Tcl | Eagle |
|------|-----|-------|
| Sub-commands | ~10 | 17 |
| Storage backend | Single hash table | 8 polymorphic backends |
| Default values | None | `[array default]` (TIP #508) |
| Copy | Manual via `[array get]`/`[set]` | `[array copy]` with `-deep` option |
| Random access | None | `[array random]` with 5 options |
| Iteration | `[array for]` (8.7+) | `[array for]`, `[array foreach]`, `[array lmap]` |
| Values query | None | `[array values]` with match modes |
| Per-element flags | None | Read-only elements via `ElementDictionary` |
| Thread safety | None | Per-variable locking and event signaling |
| Match modes | `-glob`, `-regexp`, `-exact` | Same + `-substring` |
| .NET arrays | None | `System.Array` transparent access |

---

## 2. Why the Eagle `[array]` Command Differs from Tcl

Eagle arrays sit atop .NET's collection infrastructure and serve as a
bridge between script-level associative arrays and multiple .NET data
sources:

- **ElementDictionary** — extends `Dictionary<string, object>` with
  per-element flags, default values, pattern-filtered enumeration, and
  random element selection
- **Virtual arrays** — the `env`, tests, thread, database, network, and
  registry variables present their backing .NET data structures through
  the standard array interface, allowing scripts to manipulate them
  with `[array get]`, `[array names]`, etc.
- **Variable trace integration** — `[array set]` and `[array copy]` fire
  `BeforeVariableSet` traces, enabling watch callbacks
- **Thread safety** — every sub-command acquires
  `lock (interpreter.InternalSyncRoot)` for transactional access, and
  the `Variable` class supports per-variable thread locking with
  re-entrance detection

### Source files

| File | Role |
|------|------|
| `Commands/Array.cs` (~2,695 lines) | Command implementation: 17 sub-commands |
| `Containers/Public/ElementDictionary.cs` (~686 lines) | Array storage: `Dictionary<string, object>` with per-element flags, defaults |
| `Components/Public/Variable.cs` (~1,568 lines) | Variable container: scalar value + `ArrayValue` (ElementDictionary) |
| `Components/Private/ArrayOps.cs` (~1,371 lines) | Utilities: deep copy, conversion |
| `Components/Private/ArraySearch.cs` (~352 lines) | Stateful iteration across all backend types |
| `Containers/Private/ArraySearchDictionary.cs` | Active search tracking: maps search IDs to `ArraySearch` objects |
| `Components/Private/TraceOps.cs` | Variable trace infrastructure |

---

## 3. Sub-Command Reference

Eagle's 17 `[array]` sub-commands are organized below by functional
category. Sub-commands marked **(Eagle)** have no Tcl equivalent.

### 3.1 Basic Array Operations

#### `array exists arrayName`

Returns `1` if `arrayName` is an array variable, `0` otherwise.
Follows variable links via `EntityOps.FollowLinks()`.

```tcl
array set data {a 1 b 2}
array exists data    ;# 1
array exists nosuch  ;# 0
```

#### `array size arrayName`

Returns the number of elements in the array. Returns `0` for
non-existent or empty arrays (no error).

**Backend-specific behavior:**

| Backend | Method |
|---------|--------|
| Standard | `ElementDictionary.Count` |
| Environment | Counts environment variables |
| System.Array | `array.Length` |
| Thread/Database/Network/Registry | `.GetCount()` |
| Tests | Counts test information entries |

```tcl
array set data {a 1 b 2 c 3}
array size data   ;# 3
array size empty  ;# 0 (no error even if doesn't exist)
```

#### `array set arrayName list`

Sets multiple array elements from a flat key-value list. Creates the
array if it does not exist.

**Validation:**
- `[list]` must have an even number of elements
- Enforces interpreter array element limit
- Cannot operate on special variables

**Trace behavior:** Fires `BeforeVariableSet` traces via
`interpreter.FireArraySetTraces()` before modifying elements.

**Implementation:**
1. Parse list into key-value pairs
2. Create `ElementDictionary` with calculated capacity
3. If array already exists: merge new pairs into existing dictionary
4. If new: set entire array value
5. Mark variable as `Array`, clear `Undefined`, signal dirty

```tcl
array set data {name Alice age 30 city Boston}
array set data {age 31}   ;# Updates existing element
```

#### `array get arrayName ?pattern?`

Returns a flat list of alternating keys and values. With `pattern`,
only keys matching the glob pattern are included.

**Backend dispatch:** Detects the array type and delegates to the
appropriate backend (see §5 for the complete backend list).

```tcl
array set data {name Alice age 30 city Boston}
array get data         ;# {name Alice age 30 city Boston}
array get data a*      ;# {age 30}
```

#### `array unset arrayName ?pattern?`

Without `pattern`: unsets the entire array. With `pattern`: unsets
only elements whose keys match the glob pattern.

**Per-element unset:**
1. Get all element names (dispatched to appropriate backend)
2. Match against pattern using `StringOps.Match()`
3. Call `interpreter.UnsetVariable2()` for each match

**Constraint:** Cannot match-unset `System.Array` elements (returns
error: "operation not supported for System.Array").

```tcl
array set data {a 1 b 2 c 3}
array unset data b*    ;# Removes 'b' only
array unset data       ;# Removes entire array
```

### 3.2 Array Element Queries

#### `array names arrayName ?mode? ?pattern?`

Returns a list of array element names, optionally filtered.

**Match modes:**

| Mode | Description |
|------|-------------|
| `-exact` | Exact string comparison |
| `-substring` | Substring matching |
| `-glob` | Glob pattern matching (default) |
| `-regexp` | Regular expression matching |

Match mode parsing uses `EnumOps.TryParse()` on the `MatchMode` enum,
case-insensitive.

```tcl
array set data {apple 1 apricot 2 banana 3 blueberry 4}
array names data                ;# {apple apricot banana blueberry}
array names data -glob a*       ;# {apple apricot}
array names data -regexp {^b}   ;# {banana blueberry}
array names data -exact apple   ;# {apple}
```

#### `array values arrayName ?mode? ?pattern?` **(Eagle)**

Returns a list of array element values, optionally filtered by the
same match modes as `[array names]`. Not available in standard Tcl.

```tcl
array set data {a 10 b 20 c 30}
array values data              ;# {10 20 30}
array values data -glob 2*     ;# {20}
```

### 3.3 Array Copying

#### `array copy ?options? source destination` **(Eagle)**

Copies the contents of array `[source]` to a new array `destination`.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-deep` | shallow | Deep copy: creates new `ElementDictionary` with independently copied elements |
| `-nosignal` | signal | Suppress dirty flag signaling |

**Validation:**
- Source must exist and be an array
- Source must not be a "forbidden" variable for copying
- Destination must NOT already exist (returns error if it does)
- System arrays cannot be copied to user variables

**Deep copy behavior:**
- For standard arrays: creates new `ElementDictionary`, copies all
  key-value pairs, handles opaque object handle reference counting
- For `System.Array` variables: calls `ArrayOps.DeepCopy()`

**Trace behavior:** Fires `BeforeVariableSet` traces on the
destination variable.

```tcl
array set src {a 1 b 2 c 3}
array copy src dst              ;# Shallow copy
array copy -deep src dst2       ;# Deep copy
```

### 3.4 Default Values (TIP #508)

#### `[array default]` **(Eagle)**

Manages default values for array elements. When a default is set,
accessing a non-existent element returns the default value instead
of raising an error.

**Sub-sub-commands:**

| Sub-command | Description |
|-------------|-------------|
| `array default exists arrayName` | Returns `1` if a default value is set |
| `array default get arrayName` | Returns the default value (error if none) |
| `array default set arrayName value` | Sets the default value |
| `array default unset arrayName` | Clears the default value |

The default value is stored in `ElementDictionary.DefaultValue`.

```tcl
array set counts {}
array default set counts 0

# Now non-existent elements return 0 instead of error
incr counts(apples)     ;# Works: default 0, incremented to 1
incr counts(apples)     ;# Now 2
incr counts(bananas)    ;# Works: default 0, incremented to 1

array default get counts    ;# 0
array default exists counts ;# 1
array default unset counts
```

This is particularly useful for counter patterns, accumulation, and
any scenario where a known initial value eliminates the need for
`[info exists]` checks before first use.

---

## 4. Iteration Sub-Commands

Eagle provides three iteration sub-commands plus the traditional
manual search interface.

### 4.1 High-Level Iteration

#### `array for {keyVar valueVar} arrayName body`

Iterates over array elements, setting `keyVar` and `valueVar` for
each element, then executing `body`.

Delegates to `ScriptOps.ArrayNamesAndValuesLoopCommand()`.

```tcl
array set data {a 1 b 2 c 3}
array for {key value} data {
    puts "$key => $value"
}
```

#### `array foreach varList arrayName body` **(Eagle)**

Iterates over array element names (keys only), setting each variable
in `varList` per iteration.

Delegates to `ScriptOps.ArrayNamesLoopCommand()`.

```tcl
array set rgb {red 255 green 128 blue 0}
array foreach key rgb {
    puts "$key = $rgb($key)"
}
```

#### `array lmap varList arrayName body` **(Eagle)**

Like `[array foreach]` but collects the result of each `body` evaluation
into a list. The mapping equivalent for arrays.

```tcl
array set prices {apple 1.50 banana 0.75 cherry 2.00}
set formatted [array lmap fruit prices {
    format "%s: $%s" $fruit $prices($fruit)
}]
;# {"apple: $1.50" "banana: $0.75" "cherry: $2.00"}
```

### 4.2 Manual Search Interface

For fine-grained iteration control, Eagle provides the traditional
Tcl search interface backed by the `ArraySearch` class.

#### `array startsearch arrayName`

Initiates a search over array elements and returns a unique search
identifier.

**Search ID format:** `"arraySearch"` + `interpreter.NextId()`,
formatted via `FormatOps.Id()`.

The `ArraySearch` object creates an enumerator appropriate for the
array's backend type (see §5).

```tcl
set sid [array startsearch data]
```

#### `array anymore arrayName searchId`

Returns `1` if there are more elements in the search, `0` otherwise.

Implementation creates a fresh enumerator and advances to the current
position to peek ahead — this is an O(N) operation per call, so
prefer `[array for]`/`[array foreach]` for performance-sensitive iteration.

#### `array nextelement arrayName searchId`

Returns the next element key in the search. Returns empty string when
no more elements remain.

#### `array donesearch arrayName searchId`

Terminates the search and removes it from the `ArraySearchDictionary`.
Always call this when done to free resources.

```tcl
set sid [array startsearch data]
while {[array anymore data $sid]} {
    set key [array nextelement data $sid]
    puts "$key => $data($key)"
}
array donesearch data $sid
```

---

## 5. Polymorphic Storage Backends

Eagle arrays are polymorphic: the `[array]` command detects the variable
type and dispatches to the appropriate backend. This is the mechanism
that allows `array names env` to return environment variable names
and `[array get]` on a database variable to return query results.

### Backend detection order

For each sub-command that reads array contents, the implementation
checks the variable type in this order:

1. **Environment variable** (`env`)
2. **Tests variable** (test harness state)
3. **System.Array** (.NET managed arrays)
4. **Thread variable** (thread-local storage)
5. **Database variable** (conditional: `#if DATA`)
6. **Network variable** (conditional: `#if NETWORK && WEB`)
7. **Registry variable** (conditional: `#if !NET_STANDARD_20 && WINDOWS`)
8. **Standard array** (default: `ElementDictionary`)

### Backend details

| Backend | Detection method | Backing store | Notes |
|---------|-----------------|---------------|-------|
| Environment | `interpreter.IsEnvironmentVariable()` | `Environment.GetEnvironmentVariables()` | Read from process environment on each access |
| Tests | `interpreter.IsTestsVariable()` | `interpreter.GetAllTestInformation()` | Test harness integration |
| System.Array | `interpreter.IsSystemArrayVariable()` | .NET `System.Array` object | Uses `MarshalOps` for element access; cannot match-unset |
| Thread | `interpreter.IsThreadVariable()` | `ObjectDictionary` | Thread-local; `.GetList()`, `.GetCount()` |
| Database | `interpreter.IsDatabaseVariable()` | `ObjectDictionary` | Requires `DATA` compilation flag |
| Network | `interpreter.IsNetworkVariable()` | `ObjectDictionary` | Requires `NETWORK && WEB` flags |
| Registry | `interpreter.IsRegistryVariable()` | `ObjectDictionary` | Windows only; reads registry keys |
| Standard | Default | `ElementDictionary` | `Dictionary<string, object>` with extensions |

### ArraySearch backend awareness

The `ArraySearch` class (`GetEnumerator()`) is also backend-aware.
When creating an enumerator for iteration, it dispatches to the
appropriate backend:
- Environment: `Environment.GetEnvironmentVariables().Keys`
- System.Array: `MarshalOps.GetArrayElementKeys()`
- Thread/Database/Network/Registry: `.GetList().Keys`
- Standard: `arrayValue.Keys.GetEnumerator()`

---

## 6. Random Element Selection

#### `array random ?options? arrayName ?pattern?` **(Eagle)**

Returns a random element from the array. Uses
`interpreter.RandomNumberGenerator` and
`interpreter.InternalProvideEntropy` for cryptographic-quality
randomness.

**Options:**

| Option | Description |
|--------|-------------|
| `-strict` | Return error if array empty (default: return empty string) |
| `-pair` | Return `{name value}` list instead of just name |
| `-valueonly` | Return only the value |
| `-matchname` | Match pattern against element names |
| `-matchvalue` | Match pattern against element values |

If `pattern` is provided without `-matchname` or `-matchvalue`, it
defaults to matching against names.

**Backend support:** Works with all eight backend types. For
non-standard backends, elements are collected into a temporary
`ElementDictionary` for random selection.

```tcl
array set data {a 1 b 2 c 3 d 4 e 5}

array random data              ;# Random key: e.g., "c"
array random -pair data        ;# Random pair: e.g., {b 2}
array random -valueonly data   ;# Random value: e.g., "4"
array random data "a*"         ;# Random from keys matching "a*"
array random -matchvalue data "3"  ;# Random from elements with value "3"
array random -strict data      ;# Error if empty
```

---

## 7. ElementDictionary Internals

`ElementDictionary` is the primary storage for standard Eagle arrays,
extending `Dictionary<string, object>`.

### Per-element flags

Each element can have individual `VariableFlags`:

| Method | Description |
|--------|-------------|
| `GetFlags(key)` | Get flags for a specific element |
| `HasFlags(key, flags)` | Test if element has specific flags |
| `ChangeFlags(key, flags, set)` | Set or clear flags on an element |

This enables per-element read-only protection — individual array
elements can be locked while others remain modifiable.

The flags are stored in a separate `VariableFlagsDictionary`
(`elementFlags` field) and an `EventWaitHandle` (`variableEvent`)
signals when element flags change.

### Default value

The `DefaultValue` property (TIP #508) stores a value returned when
accessing non-existent keys. When set, `ContainsKey()` returns `true`
for any key, and the default value is used for reads of missing
elements.

### Pattern-filtered enumeration

`ElementDictionary` provides built-in filtered enumeration methods:

| Method | Returns |
|--------|---------|
| `KeysToString(mode, pattern, noCase, regexOptions)` | Filtered key list |
| `KeysAndValuesToString(pattern, noCase)` | Filtered key-value flat list |
| `ValuesToString(mode, pattern, noCase, regexOptions)` | Filtered value list |
| `GetRandom(entropy, rng, ref result)` | Random element selection |

---

## 8. Variable Infrastructure

### Variable class

The `Variable` class (`Components/Public/Variable.cs`) stores both
scalar and array values:

| Field | Type | Description |
|-------|------|-------------|
| `value` | `[object]` | Scalar value |
| `arrayValue` | `ElementDictionary` | Array elements |
| `flags` | `VariableFlags` | State and behavior flags |
| `traces` | `TraceList` | Read/write/unset callbacks |
| `link` | `IVariable` | Alias target (for `[upvar]`/`[global]`) |
| `linkIndex` | `[string]` | Array element alias index |
| `threadId` | `long?` | Thread lock owner |
| `levels` | `long` | Re-entrance count |
| `@event` | `EventWaitHandle` | Change signaling |

### VariableFlags

The `VariableFlags` enum provides extensive control over variable
behavior. Key flags for arrays:

**Instance flags (stored per-variable):**

| Flag | Description |
|------|-------------|
| `Array` | Variable is an array |
| `ReadOnly` | Cannot be modified |
| `WriteOnly` | Cannot be read |
| `Virtual` | Cannot use array commands on it |
| `System` | Pre-defined system variable |
| `Undefined` | Declared but not set |
| `Dirty` | Has been modified |
| `NoTrace` | Disable trace callbacks |
| `NoWatchpoint` | Disable watchpoint triggers |
| `BreakOnGet/Set/Unset` | Debugger breakpoints |
| `Substitute` | Substitute before returning value |
| `Evaluate` | Evaluate before returning value |

**Operation flags (per-call):**

| Flag | Description |
|------|-------------|
| `NoCreate` | Don't create if missing |
| `GlobalOnly` | Only global scope |
| `NoArray` | Restrict to scalar |
| `NoElement` | Restrict to whole-array |
| `NoComplain` | Silent unset |
| `AppendValue` | Append instead of replace |
| `ResetValue` | Zero on unset |
| `ZeroString` | Forcibly zero sensitive strings (Windows) |

**Composite masks:**

| Mask | Purpose |
|------|---------|
| `ArrayCommandMask` | Validation mask for array command operations |
| `ArrayErrorMask` | Flags indicating array-related errors |
| `VirtualOrSystemMask` | `Virtual \| System` combined check |

### Thread safety

Every `[array]` sub-command acquires
`lock (interpreter.InternalSyncRoot)` before operating. The `Variable`
class additionally supports per-variable locking:

- `Lock()` / `Unlock()` — acquire/release with thread ID tracking
- `IsLockedByThisThread()` / `IsLockedByOtherThread()` — ownership
  checks
- `IsUsable()` — validates cross-thread accessibility
- `levels` field — `Interlocked.Increment/Decrement` for re-entrance
  counting

---

## 9. Trace Integration

Array operations interact with Eagle's variable trace infrastructure:

### Trace firing

| Sub-command | Traces fired |
|-------------|-------------|
| `[array set]` | `BeforeVariableSet` via `FireArraySetTraces()` |
| `[array copy]` | `BeforeVariableSet` via `FireTraces()` |
| `[array get]` | None (known limitation — FIXME in source) |
| `[array names]` | None (known limitation) |
| `[array unset]` | Fires through `UnsetVariable2()` per element |

### TraceList

Each `Variable` maintains a `TraceList` (list of `ITrace` callbacks)
for read, write, and unset events. Traces are:

- Added via `variable.AddTraces()`
- Checked via `variable.HasTraces()`
- Cleared via `variable.ClearTraces()`

### Variable event signaling

The `Variable.@event` (`EventWaitHandle`) is signaled when the
variable changes. This supports `[vwait]`-style waiting on array
modifications. The `EntityOps.SignalDirty()` method marks the variable
as dirty and signals the event handle.

---

## 10. Practical Patterns

### Pattern 1 — Counter accumulation with default values

```tcl
array set wordCount {}
array default set wordCount 0

foreach word {the quick brown fox the quick} {
    incr wordCount($word)
}
# wordCount(the) = 2, wordCount(quick) = 2, wordCount(brown) = 1, ...
```

### Pattern 2 — Deep copy for independent modification

```tcl
array set original {a 1 b 2 c 3}
array copy -deep original working
set working(a) 999
# original(a) is still 1
```

### Pattern 3 — Random sampling

```tcl
array set colors {red #FF0000 green #00FF00 blue #0000FF}

# Get a random color name
set name [array random colors]

# Get a random name-value pair
set pair [array random -pair colors]

# Get just a random value
set hex [array random -valueonly colors]
```

### Pattern 4 — Filtered element enumeration

```tcl
array set config {
    db.host localhost  db.port 5432
    app.name MyApp     app.debug true
}

# Get only database config keys
set dbKeys [array names config -glob db.*]

# Get only config values matching a regex
set vals [array values config -regexp {^\d+$}]
```

### Pattern 5 — Environment variable access

```tcl
# List all environment variables
set envNames [array names env]

# Get specific env vars by pattern
array get env PATH*

# Check env var count
array size env
```

### Pattern 6 — Array iteration with lmap

```tcl
array set students {alice 95 bob 82 charlie 91}

# Create formatted list
set report [array lmap name students {
    format "%s: %d%%" $name $students($name)
}]
```

### Pattern 7 — Manual search for complex filtering

```tcl
array set data {a 10 b 20 c 30 d 40 e 50}
set results [list]
set sid [array startsearch data]
while {[array anymore data $sid]} {
    set key [array nextelement data $sid]
    if {$data($key) > 25} {
        lappend results $key $data($key)
    }
}
array donesearch data $sid
;# results = {c 30 d 40 e 50}
```

### Pattern 8 — Array-to-array transfer with filtering

```tcl
array set source {a 1 b 2 c 3 d 4}
array set filtered {}
foreach {key value} [array get source] {
    if {$value > 2} {
        set filtered($key) $value
    }
}
;# filtered contains only c=3, d=4
```

---

## 11. Comparison with Tcl

| Feature | Tcl `[array]` | Eagle `[array]` |
|---------|-----------|-------------|
| exists / size | Standard | Same (polymorphic backends) |
| get / set | Standard | Same (8 backend types) |
| names | `-exact`, `-glob`, `-regexp` | Same + `-substring` |
| values | Not available | `[array values]` with match modes |
| unset | Standard | Same (cannot match-unset System.Array) |
| copy | Not available | `[array copy]` with `-deep` |
| default | Tcl 8.7 (TIP #508) | `array default exists/get/set/unset` |
| random | Not available | `[array random]` with 5 options |
| for | Tcl 8.7 | `[array for]` (name-value iteration) |
| foreach | `[foreach]` + `[array names]` | `[array foreach]` (direct key iteration) |
| lmap | `[lmap]` + `[array names]` | `[array lmap]` (direct mapped iteration) |
| startsearch / anymore / nextelement / donesearch | Standard | Same (backend-aware) |
| statistics | `array statistics` | Not implemented |
| Backing store | Hash table | `ElementDictionary` + 7 virtual backends |
| Per-element flags | None | Read-only elements |
| Thread safety | None | Per-variable locking, event signaling |
| Trace integration | Full (read, write, unset) | Partial (set, copy fire; get, names do not) |
| .NET arrays | None | Transparent `System.Array` access |

---

## 12. Security Considerations

### Safe interpreter access

The `[array]` command is marked `CommandFlags.Safe` — it runs in safe
interpreters. However, access to array variables is controlled by:

- Variable resolver: safe interpreters may not have access to all
  variables
- Forbidden variable checks: `interpreter.IsForbiddenVariableForArrayCopy()`
  blocks copying of protected variables
- Special variable checks: `interpreter.IsSpecialVariable()` blocks
  `[array set]` on special variables
- Option error messages are sanitized in safe interpreters

### Thread safety

All 17 sub-commands acquire `lock (interpreter.InternalSyncRoot)` as
their first operation. This provides transactional consistency but
means array operations are serialized per-interpreter.

### Sensitive data

The `VariableFlags.ZeroString` flag (Windows only) causes variable
values to be forcibly zeroed in memory when unset, preventing
sensitive data from lingering in the managed heap.

### Element limits

`[array set]` enforces an interpreter-configured array element limit to
prevent denial-of-service through unbounded array growth.

---

## 13. References

- **Source**: `eagle/Eagle/Library/Commands/Array.cs` — command implementation
- **ElementDictionary**: `eagle/Eagle/Library/Containers/Public/ElementDictionary.cs`
- **Variable class**: `eagle/Eagle/Library/Components/Public/Variable.cs`
- **ArrayOps**: `eagle/Eagle/Library/Components/Private/ArrayOps.cs`
- **ArraySearch**: `eagle/Eagle/Library/Components/Private/ArraySearch.cs`
- **Core language reference**: `core_language.md` § Variables / Data →
  `[array]` command
- **Examples**: `core_examples.md` § array
- **Tcl reference**: [Tcl `[array]` manual page](https://www.tcl-lang.org/man/tcl8.6/TclCmd/array.htm)
