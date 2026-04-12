# Eagle `[sql]` Command: Deep-Dive Analysis of Database Operations and Script Bundles

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `sql` command internals, including ADO.NET integration, the `-variable` options for automatic resource cleanup via DbTraceCallback, the script bundle database system, and the query execution pipeline. For basic command syntax, see [`core_language.md`](core_language.md#cmd-sql). For usage examples, see [`core_examples.md`](core_examples.md#ex-sql). For database utility procedures, see [`core_script_library.md`](core_script_library.md).

## 1. Executive Summary

Eagle's `[sql]` command provides **complete ADO.NET database access**
from script code — connecting to databases, executing queries with
parameterized inputs, iterating over result sets, managing transactions,
and profiling query performance. It works with any .NET data provider
(SQLite, SQL Server, Oracle, ODBC, OLE DB) through the standard
`IDbConnection` / `IDbCommand` / `IDbTransaction` interfaces.

The command has two capabilities that go well beyond basic database
access:

1. **Automatic resource cleanup via `-variable` and DbTraceCallback** —
   When connections or transactions are stored in variables using the
   `-variable` option, Eagle attaches a variable trace callback that
   automatically closes connections and commits/rolls back transactions
   when the variable goes out of scope. This prevents resource leaks
   even in the presence of exceptions or early returns.

2. **Script bundle databases** — Eagle can mount SQLite databases
   containing digitally signed Eagle scripts as virtual file systems.
   Each script in the bundle is individually signed with an RSA key pair,
   and the bundle database follows a specific schema with security
   metadata, evaluation ordering, isolation levels, and rule-set
   filtering. This enables secure distribution of script packages as
   single encrypted, signed database files.

The command is **not** part of standard Tcl — it has no Tcl equivalent.
It carries `CommandFlags.Unsafe | CommandFlags.NonStandard` and is
unavailable in safe interpreters.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Sql.cs` | 1,802 | Main command implementation (9 sub-commands) |
| `Eagle/Library/Components/Private/DataOps.cs` | 4,214 | Database operations: connection creation, query execution, result formatting, bundle scripts |
| `Eagle/Library/Components/Private/ObjectOps.cs` | large | SQL execute option definitions and processing |
| `Eagle/Library/Components/Public/Interpreter.cs` | 124,855 | Connection/transaction storage, DbTraceCallback, SetDbVariableValue |
| `Eagle/Library/Components/Public/DatabaseVariable.cs` | ~1,700 | Database-backed variable infrastructure |
| `Eagle/Library/Components/Private/BundleData.cs` | 264 | Script bundle data representation |
| `Eagle/Library/Components/Private/BundleManager.cs` | 394 | Bundle mounting, unmounting, and data retrieval |
| `Eagle/Library/Components/Private/Vars.cs` | ~500 | Result set variable name constants |

## 2. Why the SQL Command Exists

### The problem

Scripting languages frequently need to interact with databases. In the
Tcl world, database access requires loading extension packages (e.g.,
`tdbc`, `sqlite3`, `mysqltcl`) that provide Tcl commands for database
operations. These extensions are platform-specific native libraries
that must be compiled, distributed, and loaded separately.

Eagle operates in the .NET/CLR environment where ADO.NET provides a
rich, provider-independent database abstraction. The `[sql]` command
exposes this abstraction directly to script code, eliminating the need
for external database extensions.

### Design philosophy

The command follows ADO.NET's layered architecture:

```
Script Layer:           [sql] command → sub-commands
                              ↓
Provider Abstraction:   IDbConnection → IDbCommand → IDataReader
                              ↓
Concrete Providers:     SQLiteConnection, SqlConnection, OdbcConnection, ...
```

Each database operation maps directly to ADO.NET concepts:

| Script operation | ADO.NET equivalent |
|-----------------|-------------------|
| `sql open` | `new XxxConnection(connStr); connection.Open()` |
| `sql execute` | `connection.CreateCommand(); command.ExecuteReader()` |
| `sql foreach` | `while (reader.Read()) { ... }` |
| `sql transaction begin` | `connection.BeginTransaction(isolation)` |
| `sql transaction commit` | `transaction.Commit()` |
| `sql close` | `connection.Close()` |

### No Tcl equivalent

Native Tcl has no built-in database command. Eagle's `[sql]` is entirely
Eagle-specific (`CommandFlags.NonStandard`). The closest Tcl comparison
would be `package require tdbc` plus `tdbc::connection create`, but
Eagle's approach is more deeply integrated with the runtime.

## 3. Sub-Command Reference

The `[sql]` command supports **9 sub-commands**:

| Sub-command | Purpose |
|-------------|---------|
| `open` | Create and open a database connection |
| `close` | Close and release a database connection |
| `isopen` | Check if a connection exists and is open |
| `connection` | Query connection metadata |
| `execute` | Execute SQL and return results |
| `foreach` | Execute SQL and iterate over each row |
| `transaction` | Manage transactions (begin/commit/rollback) |
| `hasbegun` | Check if a transaction is active |
| `types` | List available database provider types |

### 3.1 `sql open` — Create a Database Connection

```
sql open ?options? connectionString
```

Opens a new database connection using the specified connection string
and returns a connection handle (name) for use with other sub-commands.

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `-type <DbConnectionType>` | enum | Primary database type (SQLite, Sql, Odbc, OleDb, Oracle, SqlCe) |
| `-type1 <DbConnectionType>` | enum | Override primary type |
| `-type2 <DbConnectionType>` | enum | Fallback type (tried if type1 fails) |
| `-variable <varName>` | string | Store connection name in variable with DbTraceCallback for auto-cleanup |
| `-assemblyfilename <path>` | string | Path to the provider assembly to load |
| `-typename <name>` | string | Short type name of the connection class |
| `-typefullname <name>` | string | Full (namespace-qualified) type name |
| `-valueflags <ValueFlags>` | enum | Type resolution flags |
| `-trustedonly` | flag | Only accept assemblies with trusted signatures |
| `-maybetrustedonly` | flag | Like `-trustedonly` but allowed in safe interpreters |
| `-publickeytoken1 <hex>` | string | Public key token for primary type assembly |
| `-publickeytoken2 <hex>` | string | Public key token for fallback type assembly |
| `-nocase` | flag | Case-insensitive type name matching |
| `-stricttype` | flag | Prevent automatic type name resolution |
| `-verbose` | flag | Return full type resolution error information |

**SQLite auto-fallback:**
When `-type SQLite` is specified without an explicit `-type2`, the
command automatically tries `SQLiteEnterprise` first, then falls back
to standard `SQLite`. This transparent upgrade behavior ensures that
the enterprise edition (with encryption support, etc.) is used when
available.

**Provider verification:**
The interpreter can enforce `DataFlags.TrustedOnly` and
`DataFlags.VerifiedOnly` globally, requiring all database provider
assemblies to pass trust and public key token checks. The default
public key tokens for SQLite Enterprise and standard SQLite are used
when `-publickeytoken1` and `-publickeytoken2` are not explicitly
specified but verification is required.

### 3.2 `sql close` — Close a Connection

```
sql close connection
```

Closes the database connection and removes it from the interpreter's
connection registry. Fires `NotifyType.Connection` /
`NotifyFlags.Removed` notification.

### 3.3 `sql isopen` — Check Connection Status

```
sql isopen connection
```

Returns `1` if the named connection exists in the interpreter's
registry, `0` otherwise.

### 3.4 `sql connection` — Query Connection Metadata

```
sql connection connection
```

Returns a list of key-value pairs describing the connection:

```tcl
type SQLiteConnection state Open database main timeout 15 string "Data Source=test.db"
```

Fields: `type` (provider class name), `state` (ConnectionState),
`database` (current database), `timeout` (connection timeout),
`string` (connection string).

### 3.5 `sql execute` — Execute SQL

```
sql execute ?options? connection string ?{paramName ?paramType? ?paramValue? ?paramSize? ?paramValueFlags?} ...?
```

Executes a SQL statement and returns results. The execution type and
result format are controlled by options.

**Execution pipeline:**

1. Parse options and validate connection
2. Attach `-changed` callback (if specified)
3. Create `IDbCommand` from connection
4. Set command text, timeout, type, and transaction
5. Bind parameters via `DataOps.GetParameters()`
6. Call `command.Prepare()`
7. Execute via `DataOps.ExecuteCommandAndGetResults()`
8. Store timing data (if `-time` is enabled)
9. Dispose command

### 3.6 `sql foreach` — Iterate Over Results

```
sql foreach ?options? connection string ?{params} ...? body
```

Like `execute`, but evaluates `body` for each result row. The current
row data is available in the row variable (default:
`sql(ResultSet.Row)`). Supports `break`, `continue`, and `return` from
the body script.

The key difference from `execute`: the default rows variable name is
`Vars.ResultSet.Row` (singular) instead of `Vars.ResultSet.Rows`
(plural), reflecting the one-row-at-a-time processing model.

### 3.7 `sql transaction` — Transaction Management

```
sql transaction ?options? action connection/transaction
```

**Actions:**

| Action | Syntax | Description |
|--------|--------|-------------|
| `begin` | `sql transaction ?options? begin connection` | Start a new transaction; returns transaction handle |
| `commit` | `sql transaction ?options? commit transaction` | Commit the transaction |
| `rollback` | `sql transaction ?options? rollback transaction` | Roll back the transaction |

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `-isolation <IsolationLevel>` | enum | Isolation level: `Unspecified` (default), `ReadUncommitted`, `ReadCommitted`, `RepeatableRead`, `Serializable` |
| `-variable <varName>` | string | Store transaction name in variable with DbTraceCallback for auto-cleanup |

### 3.8 `sql hasbegun` — Check Transaction Status

```
sql hasbegun transaction ?connection?
```

- With one argument: returns `1` if the transaction exists, `0`
  otherwise
- With two arguments: returns `1` only if the transaction exists AND
  belongs to the specified connection (checks
  `Object.ReferenceEquals(transaction.Connection, connection)`)

### 3.9 `sql types` — List Available Providers

```
sql types ?pattern?
```

Returns a list of available database connection type names, optionally
filtered by a glob pattern. The list combines:

1. Primary (built-in) connection types: `Odbc`, `OleDb`, `Sql`
2. Trusted "other" connection types (e.g., `SQLiteEnterprise`)
3. Public/verified connection types (e.g., `SQLite`, `Oracle`, `SqlCe`)

## 4. The `-variable` Option and DbTraceCallback

This is one of Eagle's most distinctive database features: **automatic
resource cleanup tied to variable lifetime**.

### 4.1 The Problem

Traditional database code requires explicit cleanup:

```tcl
set conn [sql open -type SQLite "Data Source=test.db"]
# If an error occurs here, the connection leaks
sql execute $conn "CREATE TABLE t1(x)"
sql close $conn
```

If an error occurs between `open` and `close`, the connection leaks.
While `try`/`finally` can help, it's error-prone and verbose.

### 4.2 The Solution: `-variable` with DbTraceCallback

```tcl
sql open -variable conn -type SQLite "Data Source=test.db"
# $conn now holds the connection name
# When $conn is unset (scope exit, explicit unset, etc.),
# the connection is automatically closed
sql execute $conn "CREATE TABLE t1(x)"
# No explicit close needed — cleanup happens automatically
```

### 4.3 How It Works

When `-variable` is used with `sql open` or `sql transaction begin`,
the command calls `interpreter.SetDbVariableValue()` instead of simply
returning the handle:

```csharp
// In sql open (Sql.cs, line 1348):
code = interpreter.SetDbVariableValue(varName, connectionName, ref result);

// In sql transaction begin (Sql.cs, line 1502):
code = interpreter.SetDbVariableValue(varName, transactionName, ref result);
```

`SetDbVariableValue` sets the variable's value AND attaches the
`dbTraceList` — a `TraceList` containing the `DbTraceCallback` — as a
variable trace:

```csharp
// Interpreter.cs, line 30491:
internal ReturnCode SetDbVariableValue(
    string name, string value, ref Result error)
{
    lock (syncRoot)
    {
        return SetVariableValue(
            VariableFlags.None, name, value, dbTraceList, ref error);
    }
}
```

The `dbTraceList` is initialized during interpreter construction:

```csharp
// Interpreter.cs, line 81420:
dbTraceList = new TraceList(
    clientData, TraceFlags.None, plugin,
    new TraceCallback[] { DbTraceCallback });
```

### 4.4 The DbTraceCallback Implementation

The `DbTraceCallback` is a static method that fires when a
traced variable is unset:

```csharp
[MethodFlags(MethodFlags.VariableTrace | MethodFlags.System | MethodFlags.NoAdd)]
private static ReturnCode DbTraceCallback(
    BreakpointType breakpointType,
    Interpreter interpreter,
    ITraceInfo traceInfo,
    ref Result result)
```

**Trigger condition:** `BreakpointType.BeforeVariableUnset` only.

**Cleanup flow:**

1. **Gather old values** — Extract the variable's current value(s),
   which contain connection/transaction names
2. **Collect transactions** — Call
   `GetDbTransactionsForTrace(names, ref transactions)` to find
   matching active transactions
3. **Commit or roll back** — For each transaction, attempt
   commit or rollback based on the variable's `VariableFlags.Success`
   flag:
   ```csharp
   bool commit = FlagOps.HasFlags(
       traceInfo.Flags, VariableFlags.Success, true);
   CommitOrRollback(transaction, ref commit, ref errors);
   ```
4. **Fail-safe retry** — If the initial operation fails,
   `CommitOrRollback` retries with the opposite operation (commit
   failure triggers rollback attempt)
5. **Remove transaction** — On success, calls
   `interpreter.RemoveDbTransaction(name)` to unregister it
6. **Collect connections** — Call
   `GetDbConnectionsForTrace(names, ref connections)` to find
   matching connections
7. **Close connections** — For each connection, calls
   `connection.Close()` and `interpreter.RemoveDbConnection(name)`
8. **Report errors** — Errors are reported via `DebugOps.Complain()`
   but the callback always returns `ReturnCode.Ok` (cleanup errors
   do not block variable unset)

### 4.5 The CommitOrRollback Method

This method implements the fail-safe transaction finalization:

```csharp
private static bool CommitOrRollback(
    IDbTransaction transaction, ref bool commit, ref ResultList errors)
{
    try
    {
        if (commit)
            transaction.Commit();
        else
            transaction.Rollback();
        return true;
    }
    catch (Exception e)
    {
        if (commit)
            commit = false;   // Force rollback on commit failure
        if (errors == null)
            errors = new ResultList();
        errors.Add(e);
        return false;
    }
}
```

If commit fails, the `commit` flag is set to `false`, and the caller
retries — this time performing a rollback. This ensures transactions
are always finalized, even if the database connection is in a bad state.

### 4.6 Variable Ordering with `-variable`

When `-variable` is used, the ordering of operations differs from the
non-variable path:

**With `-variable` (sql open):**
1. Generate connection name
2. Set variable (attaches DbTraceCallback) ← trace is live before Open
3. `connection.Open()`

**Without `-variable` (sql open):**
1. `connection.Open()` ← connection opens first
2. Generate connection name

This ordering ensures the trace is in place before the connection
opens, so if `Open()` throws, the cleanup still fires when the
variable goes out of scope (though there may be nothing to clean up).

**With `-variable` (sql transaction begin):**
1. Generate transaction name
2. Set variable (attaches DbTraceCallback) ← trace is live before Begin
3. `connection.BeginTransaction(isolationLevel)`

**Without `-variable` (sql transaction begin):**
1. `connection.BeginTransaction(isolationLevel)` ← transaction starts first
2. Generate transaction name

### 4.7 Lifecycle Diagram

```
sql open -variable conn "connStr"
    │
    ├── SetDbVariableValue("conn", connectionName)
    │       ├── Sets $conn = connectionName
    │       └── Attaches DbTraceCallback as BeforeVariableUnset trace
    │
    ├── connection.Open()
    └── AddDbConnection(connectionName, connection)

    ... script uses $conn ...

$conn goes out of scope (proc returns, unset, etc.)
    │
    ├── DbTraceCallback fires (BeforeVariableUnset)
    │       ├── GetDbTransactionsForTrace()  →  (none found)
    │       └── GetDbConnectionsForTrace()   →  finds connection
    │               ├── connection.Close()
    │               └── RemoveDbConnection(name)
    └── Variable is unset
```

## 5. Query Execution Options

The `execute` and `foreach` sub-commands share a large set of options
defined by `ObjectOps.GetSqlExecuteOptions()`.

### 5.1 Execution Type (`-execute`)

Controls how the SQL statement is executed:

| Value | ADO.NET method | Returns |
|-------|---------------|---------|
| `NonQuery` | `command.ExecuteNonQuery()` | Number of rows affected |
| `Scalar` | `command.ExecuteScalar()` | Single value from first row, first column |
| `Reader` | `command.ExecuteReader()` | Full result set |
| `ReaderAndCount` | `command.ExecuteReader()` + count | Result set plus row count |

### 5.2 Result Format (`-format`)

Controls the structure of returned results:

| Value | Description |
|-------|-------------|
| `None` | No result formatting |
| `List` | Flat list of values |
| `NestedList` | List of lists (one per row) |
| `Array` | Tcl array variable (column names as keys) |
| `Dictionary` | Tcl dictionary |
| `RawArray` | Raw array format |
| `RawDictionary` | Raw dictionary format |

### 5.3 Value Handling Options

| Option | Type | Description |
|--------|------|-------------|
| `-allownull` | bool | Allow null values in results |
| `-nullvalue <string>` | string | String representation for null values |
| `-dbnullvalue <string>` | string | String representation for `DBNull.Value` |
| `-errorvalue <string>` | string | String representation for error values |
| `-datetimebehavior <enum>` | DateTimeBehavior | How to handle DateTime values (Ticks, Format, etc.) |
| `-datetimeformat <string>` | string | Format string for DateTime conversion |
| `-datetimekind <enum>` | DateTimeKind | DateTimeKind for parsed DateTime values (Local, Utc, Unspecified) |
| `-datetimestyles <enum>` | DateTimeStyles | Styles for DateTime parsing |
| `-blobbehavior <enum>` | BlobBehavior | How to handle BLOB/binary data |
| `-numberformat <string>` | string | Format string for numeric values |
| `-valueformat <string>` | string | General value format string |
| `-valueflags <enum>` | ValueFlags | Value conversion behavior flags |
| `-verbatim` | flag | Skip value conversion; use raw values |
| `-culture <CultureInfo>` | CultureInfo | Culture for parsing and formatting |

**Null value fallback chain:** If `-dbnullvalue` is not set, it defaults
to `-nullvalue`. If `-errorvalue` is not set, it also defaults to
`-nullvalue`. This ensures consistent null representation across all
value types.

### 5.4 Result Variable Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-rowsvar <varName>` | string | `sql(ResultSet.Rows)` | Variable for result rows (execute) |
| `-rowvar <varName>` | string | `sql(ResultSet.Row)` | Variable for current row (foreach) |
| `-timevar <varName>` | string | `sql(ResultSet.Time)` | Variable for timing data |
| `-pairs` | flag | false | Return results as name-value pairs |
| `-names` | flag | false | Include column names in results |
| `-nested` | flag | false | Allow nested result sets |
| `-nofixup` | flag | false | Skip result object fixup/conversion |
| `-limit <int>` | int | unlimited | Maximum number of rows to return |
| `-nocreate` | flag | false | Don't create opaque object handles |

### 5.5 Command Options

| Option | Type | Description |
|--------|------|-------------|
| `-transaction <name>` | string | Transaction to use with this query |
| `-timeout <seconds>` | int | Command execution timeout |
| `-commandtype <enum>` | CommandType | `Text` (default), `StoredProcedure`, `TableDirect` |
| `-behavior <enum>` | CommandBehavior | Command behavior flags |
| `-time` | flag | Enable performance profiling |

### 5.6 Object Return Value Options

| Option | Type | Description |
|--------|------|-------------|
| `-objectname <name>` | string | Name for created opaque object handle |
| `-returntype <type>` | Type | Expected return type |
| `-objecttype <type>` | Type | Expected object type |
| `-create` | flag | Create opaque object handle for result |
| `-nodispose` | flag | Don't dispose returned objects |
| `-alias` | flag | Create command alias for result object |
| `-aliasraw` | flag | Create raw (unprocessed) alias |
| `-aliasall` | flag | Alias all result objects |
| `-aliasreference` | flag | Alias by reference (unsafe) |
| `-tostring` | flag | Convert result objects to string |
| `-objectflags <enum>` | ObjectFlags | Flags controlling object behavior |
| `-noforcedelete` | flag | Don't force object deletion |

### 5.7 Event Callback Option

| Option | Type | Description |
|--------|------|-------------|
| `-changed <callback>` | ICallback | Hook for the database connection's "Changed" event |

The `-changed` option uses reflection to find the connection type's
`Changed` event (e.g., `SQLiteConnection.Changed`) and attaches the
callback delegate as an event handler. This enables monitoring of
connection state changes, command execution events, and other
provider-specific notifications.

## 6. Parameter Binding

SQL parameters prevent injection attacks and enable type-safe value
passing.

### 6.1 Parameter Format

Parameters are specified as lists after the SQL text:

```tcl
sql execute $conn "SELECT * FROM users WHERE id = @id AND name = @name" \
    {id Int32 42} {name String "Alice"}
```

Each parameter is a list with the format:

```
{paramName ?paramType? ?paramValue? ?paramSize? ?paramValueFlags?}
```

| Field | Required | Description |
|-------|----------|-------------|
| `paramName` | Yes | Parameter name (e.g., `@id`, `@name`) |
| `paramType` | No | `DbType` enum value (Int32, String, DateTime, Binary, etc.) |
| `paramValue` | No | The parameter value |
| `paramSize` | No | Size hint for string/binary parameters |
| `paramValueFlags` | No | `ValueFlags` for conversion control |

### 6.2 Type-Safe Conversion

Parameters are processed by `DataOps.GetParameters()`, which:

1. Parses the parameter list from the argument array
2. Creates `IDbDataParameter` objects on the command
3. Converts values using the specified culture, DateTime settings,
   and value format
4. Supports object references (opaque handles) as parameter values

### 6.3 Security: Parameterized Queries

**Always use parameterized queries** to prevent SQL injection:

```tcl
# DANGEROUS: Direct string interpolation
sql execute $conn "SELECT * FROM users WHERE name = '$userInput'"

# SAFE: Parameterized query
sql execute $conn "SELECT * FROM users WHERE name = @name" \
    {name String $userInput}
```

## 7. Performance Profiling

### 7.1 The `-time` Option

When `-time` is specified, the command measures two phases:

1. **Prepare phase** — time spent in `command.Prepare()`
2. **Execute phase** — time spent in result retrieval

Timing data is stored in the time variable (default:
`sql(ResultSet.Time)`) as an array:

```tcl
sql execute -time $conn "SELECT * FROM large_table"
puts "Prepare: $sql(ResultSet.Time)(prepare)"
puts "Execute: $sql(ResultSet.Time)(execute)"
```

### 7.2 Profiler Implementation

The profiler uses `IProfilerState` / `ProfilerState.Create()`:

- On Windows with `NATIVE` compilation: uses high-resolution
  native performance counters (hence `CommandFlags.NativeCode`)
- Otherwise: uses managed timing mechanisms

The profiler is created before `Prepare()`, started, stopped after
prepare, timing stored, restarted before execute, and stopped after
execute. Both measurements are stored in the time variable.

## 8. Script Bundle Databases

Script bundles are SQLite databases that contain digitally signed Eagle
scripts. They serve as secure, portable containers for distributing
script packages.

### 8.1 The Scripts Table Schema

The bundle database schema is defined in `scratch/eagle/sql/scripts.sql`:

```sql
CREATE TABLE IF NOT EXISTS Scripts(
    Id BLOB(16) NOT NULL,              -- Unique script identifier (GUID)
    Language TEXT NOT NULL,             -- Always "Eagle"
    Sequence INTEGER NOT NULL,         -- Evaluation order (non-zero)
    IsolationLevel TEXT NULL,          -- None, Interpreter, AppDomain,
                                       -- AppDomainOrInterpreter, Process,
                                       -- Session, or Machine
    SecurityLevel TEXT NULL,           -- None, Safe, or Sdk
    SecurityFlags TEXT NULL,           -- ScriptSecurityFlags
    RuleSet TEXT NULL,                 -- Command/policy filtering rules
    BlockType TEXT NULL,               -- Reserved (must be None)
    FullName TEXT NOT NULL,            -- POSIX path, e.g. /some/script.eagle
    "Group" TEXT NOT NULL,             -- Logical group name
    Description TEXT NOT NULL,         -- Human-readable description
    TimeStamp DATETIME NOT NULL,       -- Creation/modification timestamp
    PublicKeyToken BLOB(8) NOT NULL,   -- SNK public key token
    Text TEXT NOT NULL,                -- Script source code
    Vendor TEXT NOT NULL,              -- e.g. "Mistachkin Systems"
    HashAlgorithm TEXT NOT NULL,       -- e.g. "SHA512"
    Signature BLOB NOT NULL,           -- RSA signature (typically 2048 bytes
                                       -- for 16384-bit keys)
    UNIQUE (Id),
    UNIQUE (FullName),
    UNIQUE (Language, Sequence)
);
```

### 8.2 Key Schema Columns

**Sequence** — Controls evaluation order and package association:

- **Positive values**: Scripts evaluated in this order by
  `EvaluateBundleFile`. The sequence is relative to other scripts in
  the same bundle.
- **Negative values**: Package index files and associated package
  scripts. These are NOT directly evaluated by `EvaluateBundleFile`;
  instead, they are accessed via `[package scan]` or
  `[interp readorgetscriptfile]`. Package index files require
  `[package scan -normal -host -bundle --]`.

**IsolationLevel** — Controls the isolation boundary for evaluating the
bundled script:

| Value | Meaning |
|-------|---------|
| `None` | No isolation; evaluated in the current interpreter |
| `Interpreter` | Evaluated in a new child interpreter |
| `AppDomain` | Evaluated in a new AppDomain |
| `AppDomainOrInterpreter` | AppDomain if available, otherwise interpreter |
| `Process` | Evaluated in a new process |
| `Session` | Session-level isolation |
| `Machine` | Machine-level isolation |

**SecurityLevel** — Security context for evaluation:

| Value | Meaning |
|-------|---------|
| `None` | Standard execution |
| `Safe` | Evaluated in a safe interpreter |
| `Sdk` | SDK-level security context |

**RuleSet** — Optional list of rules for command/policy filtering in
interpreters created to evaluate the bundle. Each rule is a dictionary:

```tcl
rule {
    type Include
    kind Command
    mode {Include Exact}
    patterns after
}
```

Rule fields:
- `type` — `Include` or `Exclude`
- `kind` — `Command` or `Policy`
- `mode` — Match modes: `Exact`, `Glob`, `RegExp`, `SubString`, etc.
- `patterns` — List of identifier name patterns

**Signature** — RSA digital signature of ALL data in the row. Signatures
are typically 2048 bytes (corresponding to 16384-bit RSA keys) and use
SHA512 hashing. Before any script is evaluated, its signature is
verified against the interpreter's trusted script key rings.

### 8.3 BundleData — Script Entry Representation

The `BundleData` class (`Eagle._Components.Private.BundleData`)
represents a single script entry from a bundle database:

```
IBundleData
    ├── Language (string)
    ├── Sequence (long)
    ├── Vendor (string)
    ├── Path (string) — the database file path
    ├── FullName (string) — the script's POSIX path within the bundle
    ├── HashAlgorithmName (string) — e.g., "SHA512"
    ├── FileBytes (byte[]) — the raw script bytes
    ├── IsolationLevel (IsolationLevel)
    ├── SecurityLevel (SecurityLevel)
    ├── SecurityFlags (ScriptSecurityFlags)
    └── RuleSet (IRuleSet) — command/policy filtering rules
```

Security flags include `ReadOnly`, `Immutable`, `NoVendor`,
`NoHashAlgorithm`, `NoEntityType`, `NoEntityName`, `NoEntityValue`,
`NoBlockType`, and `TreatAsFile`. The typical value is `BundleMask`.

The `MakeImmutable()` method sets the `Immutable` flag permanently —
once called, it cannot be undone. This is used for security when
passing script objects to the policy engine.

### 8.4 BundleManager — Virtual File System

The `BundleManager` class manages mounted script bundle databases as
virtual file systems:

**Mounting and unmounting:**

```
BundleManager.Mount(interpreter, fileName, password, errorOnMounted)
BundleManager.Unmount(interpreter, fileName, errorOnNotMounted)
BundleManager.ListMounts(interpreter, pattern, noCase)
```

- Databases are mounted **read-only** — the schema comments explicitly
  state that databases should not be opened in read-write mode
- Databases may be **encrypted** using the SQLite Encryption Extension
- Passwords are stored as `byte[]` in the mount dictionary
- File names use platform-appropriate path comparison
  (`PathOps.Comparer`)

**Data retrieval:**

```
BundleManager.GetData(interpreter, cultureInfo, encoding, path, ref data)
```

The path format for bundle scripts is `{databaseFile}:{scriptPath}`:

```
/path/to/scripts.db:/some/script.eagle
```

The retrieval process:
1. Validates the path against security regex patterns
   (`DataOps.VerifyBundlePath`)
2. Splits into database file name and script full name
3. Looks up the database password in the mount dictionary
4. Calls `DataOps.GatherBundleScripts()` to query the database
5. Calls `DataOps.VerifyOneBundleScript()` to validate that exactly
   one matching script was found and returns its bytes

**Evaluation tracking:**

```
BundleManager.BeginEvaluation(interpreter, fileName, out savedFileName)
BundleManager.EndEvaluation(interpreter, ref savedFileName)
```

These methods track which bundle is currently being evaluated, using
save/restore semantics to support nested bundle evaluation.

### 8.5 Package Index Files in Bundles

Scripts with **negative sequence numbers** are treated as package
components:

- They are NOT evaluated by the main bundle evaluation loop
- They can be accessed via `[package scan -normal -host -bundle --]`
- Package index paths follow the pattern:
  `databaseFile:/path/to/pkg/dir/pkgIndex.eagle`
- The full name is matched via regular expression patterns, e.g.:
  `^\/path\/to\/pkg\/dir\/pkgIndex(?:_[0-9a-f]{16})?$`
- Associated package script files can be evaluated using their
  database-qualified paths, e.g., `eagle.db:/script.eagle`

### 8.6 Bundle Security Model

Script bundles implement defense-in-depth security:

1. **Database integrity** — Verified via `PRAGMA integrity_check`
   before processing
2. **Per-script signatures** — Each script row is individually signed
   with RSA, covering ALL columns including metadata
3. **Key ring verification** — Signatures are verified against the
   interpreter's trusted script key rings
4. **Hash algorithm enforcement** — Configurable but typically SHA512
5. **Public key token matching** — SNK public key tokens must match
   trusted publishers
6. **Vendor identification** — Each script identifies its vendor
7. **Encryption** — Databases can be encrypted using the SQLite
   Encryption Extension, requiring a password to mount
8. **Immutability** — Script data can be made immutable once loaded,
   preventing modification
9. **Isolation levels** — Scripts can require specific isolation
   boundaries for execution
10. **Rule-set filtering** — Scripts can restrict which commands and
    policies are available during execution

## 9. The Connection Type System

### 9.1 DbConnectionType Enumeration

Eagle supports these built-in connection types:

| Type | .NET Provider | Assembly |
|------|-------------|----------|
| `Odbc` | `System.Data.Odbc.OdbcConnection` | System.Data |
| `OleDb` | `System.Data.OleDb.OleDbConnection` | System.Data |
| `Sql` | `System.Data.SqlClient.SqlConnection` | System.Data |
| `Oracle` | `System.Data.OracleClient.OracleConnection` | System.Data.OracleClient |
| `SqlCe` | `System.Data.SqlServerCe.SqlCeConnection` | System.Data.SqlServerCe |
| `SQLite` | `System.Data.SQLite.SQLiteConnection` | System.Data.SQLite |
| `SQLiteEnterprise` | `System.Data.SQLite.SQLiteConnection` | System.Data.SQLite (Enterprise) |

### 9.2 Connection Resolution

The connection creation process (`DataOps.CreateDbConnection()`)
follows a fallback chain:

1. Try `type1` (primary type)
2. If that fails, try `type2` (fallback type)
3. If custom type names are specified (`-typename`/`-typefullname`),
   resolve via reflection
4. If `-assemblyfilename` is specified, load the assembly first
5. Apply public key token verification if required
6. Apply trust verification if `ValueFlags.TrustedOnly` is set

### 9.3 SQLite Enterprise Auto-Upgrade

When the user specifies `-type SQLite`:

```csharp
if ((dbConnectionType1 == DbConnectionType.SQLite) &&
    (dbConnectionType2 == DbConnectionType.None))
{
    dbConnectionType1 = DbConnectionType.SQLiteEnterprise;
    dbConnectionType2 = DbConnectionType.SQLite;
}
```

This transparent upgrade ensures the enterprise edition (with
encryption support, enhanced features, etc.) is used when available,
with automatic fallback to the standard edition.

## 10. DatabaseVariable — Database-Backed Variables

Eagle provides a separate but related feature: **database-backed
array variables**. A `DatabaseVariable` transparently maps Eagle array
variable operations to SQL DML statements:

| Variable operation | SQL operation |
|-------------------|---------------|
| Get element | `SELECT` by name |
| Set element | `INSERT` or `UPDATE` |
| Unset element | `DELETE` by name |
| List elements | `SELECT` all names |

This is implemented via its own `TraceCallback` (separate from
`DbTraceCallback`) that intercepts variable get/set/unset operations
and translates them to SQL queries. The implementation supports
database-specific syntax for Oracle (ROWID), SQL Server ($IDENTITY),
and SQLite (rowid, CAST).

## 11. Notification System Integration

The `[sql]` command fires interpreter notifications at key lifecycle
points:

| Operation | NotifyType | NotifyFlags |
|-----------|-----------|-------------|
| Connection opened | `Connection` | `Added` |
| Connection closed | `Connection` | `Removed` |
| Transaction begun | `Transaction` | `Added` |
| Transaction committed | `Transaction` | `Removed` |
| Transaction rolled back | `Transaction` | `Removed` |

These notifications are gated by the `NOTIFY` compilation flag and
enable plugins and other subsystems to monitor database lifecycle
events.

## 12. Practical Patterns

### Pattern 1: Basic Query Execution

```tcl
# Open a SQLite connection
set conn [sql open -type SQLite "Data Source=mydb.db"]

# Execute a non-query (returns rows affected)
sql execute -execute NonQuery $conn "CREATE TABLE users(id INTEGER, name TEXT)"
sql execute -execute NonQuery $conn "INSERT INTO users VALUES(1, 'Alice')"

# Execute a scalar query (returns single value)
set count [sql execute -execute Scalar $conn "SELECT COUNT(*) FROM users"]

# Execute a reader query (returns result set)
sql execute -execute Reader -format NestedList $conn "SELECT * FROM users"

# Close
sql close $conn
```

### Pattern 2: Auto-Cleanup with `-variable`

```tcl
proc queryDatabase {dbFile query} {
    # Connection is automatically closed when $conn goes out of scope
    sql open -variable conn -type SQLite \
        "Data Source=$dbFile;Read Only=True"

    return [sql execute -execute Reader -format NestedList \
        $conn $query]
    # No explicit close needed — DbTraceCallback handles it
}
```

### Pattern 3: Transaction with Auto-Cleanup

```tcl
proc transferFunds {dbFile fromId toId amount} {
    sql open -variable conn -type SQLite "Data Source=$dbFile"

    # Transaction auto-commits on clean exit, auto-rolls-back on error
    sql transaction -variable trans begin $conn

    sql execute -transaction $trans $conn \
        "UPDATE accounts SET balance = balance - @amt WHERE id = @id" \
        {amt Int32 $amount} {id Int32 $fromId}

    sql execute -transaction $trans $conn \
        "UPDATE accounts SET balance = balance + @amt WHERE id = @id" \
        {amt Int32 $amount} {id Int32 $toId}

    sql transaction commit $trans
    # If an error occurs before commit, DbTraceCallback rolls back
}
```

### Pattern 4: Iterating Over Results

```tcl
set conn [sql open -type SQLite "Data Source=app.db"]

sql foreach $conn "SELECT id, name, email FROM users" {
    puts "User $sql(ResultSet.Row)(id): \
        $sql(ResultSet.Row)(name) <$sql(ResultSet.Row)(email)>"
}

sql close $conn
```

### Pattern 5: Parameterized Queries (SQL Injection Prevention)

```tcl
# ALWAYS use parameters for user input
sql execute -execute Reader $conn \
    "SELECT * FROM products WHERE category = @cat AND price < @max" \
    {cat String "Electronics"} {max Double 99.99}

# With explicit parameter size
sql execute -execute NonQuery $conn \
    "INSERT INTO logs(message) VALUES(@msg)" \
    {msg String "Event occurred" 1000}
```

### Pattern 6: Performance Profiling

```tcl
sql execute -time -execute Reader $conn "SELECT * FROM large_table"
puts "Prepare time: $sql(ResultSet.Time)(prepare)"
puts "Execute time: $sql(ResultSet.Time)(execute)"
```

### Pattern 7: Multiple Database Providers

```tcl
# SQL Server
set sqlConn [sql open -type Sql \
    "Server=localhost;Database=mydb;Integrated Security=True"]

# ODBC
set odbcConn [sql open -type Odbc \
    "Driver={SQL Server};Server=localhost;Database=mydb"]

# Custom provider with explicit assembly
set customConn [sql open -assemblyfilename "/path/to/provider.dll" \
    -typefullname "Custom.Data.Connection" \
    "CustomConnectionString"]
```

### Pattern 8: Checking Transaction Status

```tcl
set conn [sql open -type SQLite "Data Source=test.db"]
set trans [sql transaction begin $conn]

# Is the transaction active?
puts [sql hasbegun $trans]         ;# 1

# Does it belong to this connection?
puts [sql hasbegun $trans $conn]   ;# 1

sql transaction commit $trans
puts [sql hasbegun $trans]         ;# 0
sql close $conn
```

## 13. Comparisons to Other Languages

### Python (sqlite3 / DB-API)

| Aspect | Eagle `[sql]` | Python DB-API |
|--------|-------------|--------------|
| Provider abstraction | ADO.NET interfaces | DB-API 2.0 (PEP 249) |
| Connection | `sql open -type SQLite connStr` | `sqlite3.connect("db.sqlite3")` |
| Parameters | `{name Type value}` lists | `?` or `:name` placeholders |
| Auto-cleanup | DbTraceCallback on variable unset | `with` statement (context manager) |
| Result iteration | `sql foreach` | `cursor.fetchall()` / `for row in cursor` |
| Transaction | `sql transaction begin/commit` | `connection.commit()` |
| Script bundles | SQLite-based signed script databases | No equivalent |

### Tcl (tdbc / sqlite3)

| Aspect | Eagle `[sql]` | Tcl `tdbc` |
|--------|-------------|-----------|
| Installation | Built-in | `package require tdbc` + driver |
| Connection | `sql open -type SQLite connStr` | `tdbc::sqlite3::connection create db "file.db"` |
| Query | `sql execute $conn "SELECT ..."` | `$db allrows "SELECT ..."` |
| Parameters | `{name Type value}` | `:name` with variable binding |
| Transactions | `sql transaction begin/commit/rollback` | `$db begintransaction` / `$db commit` |
| Auto-cleanup | DbTraceCallback | Object command deletion |
| Script bundles | Signed SQLite databases | No equivalent |
| Provider types | 7+ built-in types | One package per driver |

### C# (ADO.NET direct)

Eagle's `[sql]` maps almost 1:1 to ADO.NET, but adds:

- Automatic type discovery for connection providers
- Integrated result formatting (lists, dictionaries, arrays)
- DbTraceCallback for scope-based resource management
- Script-level parameter binding without compile-time types
- Built-in performance profiling
- Script bundle database system

## 14. Security Considerations

### 14.1 SQL Injection Prevention

**Always use parameterized queries** for user-supplied input:

```tcl
# VULNERABLE:
sql execute $conn "SELECT * FROM t WHERE x = '$userInput'"

# SAFE:
sql execute $conn "SELECT * FROM t WHERE x = @val" {val String $userInput}
```

### 14.2 Command Access Control

`[sql]` is marked `Unsafe` — it is hidden and inaccessible in safe
interpreters. This prevents untrusted code from:

- Opening arbitrary database connections
- Reading or modifying database contents
- Exhausting database resources
- Accessing the file system via database file paths

### 14.3 Provider Assembly Trust

The `-trustedonly` option and `DataFlags.TrustedOnly` /
`DataFlags.VerifiedOnly` interpreter flags ensure that only signed
and trusted provider assemblies can be loaded. Public key token
verification (`-publickeytoken1`, `-publickeytoken2`) prevents loading
of unauthorized provider implementations.

### 14.4 Script Bundle Security

Script bundles implement a multi-layer security model (see Section 8.6)
that ensures scripts are authentic, unmodified, and authorized for
execution.

## 15. Relationship to Other Commands

| Command | Relationship |
|---------|-------------|
| `[object]` | The `[sql]` command uses `[object]`-style opaque handles for connection and transaction management. Result objects can be aliased via `-alias`, `-create`, etc. |
| `[load]` | Database provider assemblies may need to be loaded via `[load]` or `-assemblyfilename` before use. See [`load.md`](load.md). |
| `[source]` | Script bundle databases can be evaluated via `[source -bundle]`. |
| `[package]` | Package index files in bundles are accessed via `[package scan -normal -host -bundle --]`. |
| `[interp]` | Bundle scripts with `IsolationLevel` of `Interpreter` or `Safe` SecurityLevel create child interpreters for evaluation. See [`interp.md`](interp.md). |
| `[library]` | Native FFI. Complementary: `[sql]` accesses managed databases; `[library]` calls native C functions. See [`library.md`](library.md). |

## 16. Production Patterns from the SQLite .NET Test Suite

The canonical example of production-grade Eagle database scripting is the
**System.Data.SQLite test suite** (`sqlite/dotnet/Tests/` — 113 `.eagle`
test files, backed by the `sqlite/dotnet/lib/System.Data.SQLite/common.eagle`
library at ~7,000 lines). These patterns have been refined over many years
of real-world use.

### 16.1 Connection Lifecycle: `setupDb` / `cleanupDb`

Production code never calls `sql open` directly. Instead, a wrapper
procedure builds the connection string from multiple sources, opens the
connection, configures PRAGMAs, and runs setup SQL:

```tcl
proc setupDb {fileName {mode ""} {dateTimeFormat ""} {dateTimeKind ""}
             {flags ""} {extra ""} {qualify true} {delete true}
             {uri false} {temporary true} {varName db} {quiet false}} {
    upvar 1 $varName db

    # Build connection string from multiple sources
    set connection "Data Source=${fileName};ToFullPath=${qualify}"
    if {$mode ne ""} { append connection ";Journal Mode=${mode}" }
    if {$dateTimeFormat ne ""} { append connection ";DateTimeFormat=${dateTimeFormat}" }
    append connection [getTestProperties $flags $extra]

    # Open connection
    set db [sql open -type SQLite $connection]

    # Configure temporary directory
    sql execute $db "PRAGMA temp_store_directory = \"${tempDir}\";"

    # Run per-connection setup SQL (configurable)
    set setupSql [getExecuteOnSetup]
    if {$setupSql ne ""} { sql execute $db $setupSql }
}
```

Cleanup is equally thorough:

```tcl
proc cleanupDb {fileName {varName db} {collect true} {qualify true}
               {delete true} {pool true} {quiet false}} {
    upvar 1 $varName db

    # Clear connection pools
    catch {object invoke System.Data.SQLite.SQLiteConnection ClearAllPools}

    # Force garbage collection to release file handles
    if {$collect} { collectGarbage $::test_channel }

    # Close connection
    sql close $db

    # Delete associated files (WAL, SHM, main database)
    if {$delete} {
        catch {file delete "${fileName}-wal"}
        catch {file delete "${fileName}-shm"}
        catch {file delete $fileName}
    }

    unset db
}
```

### 16.2 Connection String Building

Connection strings are assembled from multiple sources with priority
merging:

```tcl
# Local flags + global overrides + shared flags
set flags [combineFlags $localFlags ""]
if {[info exists ::connection_flags]} {
    set flags [combineFlags $flags $::connection_flags]
}

# Extra connection properties
set extra [combineExtra $::connection_extra $localExtra]
```

This allows per-user configuration files (`settings.before.username.eagle`)
to override defaults without modifying test code.

### 16.3 Parameter Binding: Real Syntax

Parameters use `?` placeholders with typed list bindings:

```tcl
# Check if a table exists (parameterized)
set sql {SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?;}
set exists [expr {[sql execute -execute scalar $db $sql \
    [list param1 String $tableName]] > 0}]

# Insert with typed parameters
sql execute $db {INSERT INTO t1 (x, y) VALUES(?, ?);} \
    [list param1 Int64 42] [list param2 String "value"]
```

Each parameter is a list: `{paramName DbType Value}`. The `paramName` is
a logical name (the actual binding is positional for `?` placeholders, or
named for `@param` syntax).

### 16.4 Result Access Patterns

**Scalar results (single value):**
```tcl
set count [sql execute -execute scalar $db "SELECT COUNT(*) FROM t1;"]
```

**Reader with implicit `$rows` array:**
```tcl
sql execute -execute reader $db "SELECT x, y, z FROM t1;"
# $rows(count) = number of rows
# $rows(names) = column name list
# $rows(0)     = first row as value list
# $rows(1)     = second row
```

**DataReader for streaming large result sets:**
```tcl
set reader [sql execute -execute reader -format datareader \
    -alias $db "SELECT * FROM large_table;"]

while {[$reader Read]} {
    set id    [$reader GetValue [$reader GetOrdinal "id"]]
    set name  [$reader GetValue [$reader GetOrdinal "name"]]
    # Process one row at a time -- constant memory usage
}

unset reader
```

**DataTable for materialized results with named column access:**
```tcl
set table [sql execute -execute reader -format datatable \
    $db "SELECT id, name, age FROM users;"]

# Built-in conversion methods (replaces getRowsFromDataTable)
set rows [$table ToList]          ;# {{1 Alice 30} {2 Bob 25}}
set dicts [$table ToDictionary]   ;# {{id 1 name Alice age 30} ...}
set cols [$table GetColumnNames]  ;# {id name age}

# Named column access on individual rows
object foreach -alias row [$table Rows] {
    puts "[$row Item name]: [$row Item age]"
}

# In-memory filtering (no new query needed)
set filtered [$table Select "age >= 30"]

unset table
```

The `DataTable` format returns a custom `DataOps.DataTable` object (derived
from `System.Data.DataTable`) that captures the value formatting parameters
(`DateTimeBehavior`, `BlobBehavior`, etc.) so that `ToList` and `ToDictionary`
apply the same conversion pipeline (`MarshalOps.FixupDataValue`) as other
`[sql execute]` formats. This replaces the manual `getRowsFromDataTable`
pattern from the SQLite test suite library.

### 16.5 Transaction Management

```tcl
set transaction [sql transaction begin $db]

if {[catch {
    sql execute $db "INSERT INTO t1 VALUES(1, 'a');"
    sql execute $db "INSERT INTO t1 VALUES(2, 'b');"
    sql transaction commit $transaction
} error]} {
    catch {sql transaction rollback $transaction}
    error $error
}
```

**Nested transactions:**
```tcl
set outer [sql transaction begin $db]
set inner [sql transaction begin $db]   ;# savepoint

catch {sql execute $db "INSERT ..."}
sql transaction rollback $inner         ;# rollback to savepoint
sql transaction commit $outer           ;# commit the rest
```

### 16.6 Advanced .NET Interop with Database Objects

The test suite demonstrates deep .NET interop for advanced database
features:

**Event handlers (authorization callbacks):**
```tcl
proc onAuthorize {sender e} {
    if {[$e ActionCode] eq "CreateTable"} {
        $e ReturnCode Deny
    }
}

set connection [getDbConnection]
object invoke $connection add_Authorize onAuthorize

# ... use connection ...

# Cleanup ritual: remove handler, remove callback, delete proc
catch {object invoke $connection remove_Authorize onAuthorize}
catch {object removecallback onAuthorize}
rename onAuthorize ""
```

**Type callbacks (custom marshaling):**
```tcl
set callback {-callbackflags +Default readValueCallback}
set typeCallbacks [object invoke -marshalflags +DynamicCallback \
    System.Data.SQLite.SQLiteTypeCallbacks Create \
    null $callback null null]

$connection SetTypeCallbacks "TYPENAME" $typeCallbacks
```

**Connection pooling:**
```tcl
# Enable pooling in connection string
setupDb $fileName "" "" "" "" "Pooling=True;"

# Explicit pool management
catch {
    object invoke -flags +NonPublic \
        System.Data.SQLite.SQLiteConnectionPool ClearAllPools
}
```

### 16.7 Diagnostic and Resource Tracking

```tcl
# Handle leak detection
proc getSQLiteHandleCounts {channel} {
    set counts [list]
    foreach name {connectionCount statementCount backupCount blobCount} {
        lappend counts $name [object invoke -flags +NonPublic \
            System.Data.SQLite.UnsafeNativeMethods \
            sqlite3_changes_interop ...]
    }
    return $counts
}

# Full shutdown with leak detection
proc shutdownSQLite {channel} {
    # Roll back leaked transactions
    foreach transaction [info transactions] {
        catch {sql transaction rollback $transaction}
    }
    # Close leaked connections
    foreach connection [info connections] {
        catch {sql close $connection}
    }
}
```

### 16.8 Test Structure Pattern

Every test follows a consistent lifecycle:

```tcl
runTest {test data-1.1 "basic CRUD operations" \
    -setup {
        setupDb [set fileName data-1.1.db]
    } \
    -body {
        sql execute $db "CREATE TABLE t1(x INTEGER, y TEXT);"
        sql execute $db "INSERT INTO t1 VALUES(1, 'hello');"
        set result [sql execute -execute scalar $db \
            "SELECT y FROM t1 WHERE x = ?;" \
            [list param1 Int64 1]]
    } \
    -cleanup {
        cleanupDb $fileName
        unset -nocomplain result
    } \
    -constraints {eagle command.sql compile.DATA SQLite \
        System.Data.SQLite} \
    -result {hello}
}
```

## 17. References

- **Source code**: `Eagle/Library/Commands/Sql.cs` — `[sql]` command implementation (9 sub-commands)
- **Source code**: `Eagle/Library/Components/Private/DataOps.cs` — database operations, connection creation, result formatting, bundle scripts
- **Source code**: `Eagle/Library/Components/Private/ObjectOps.cs` — SQL execute option definitions
- **Source code**: `Eagle/Library/Components/Public/Interpreter.cs` — DbTraceCallback, SetDbVariableValue, connection/transaction storage
- **Source code**: `Eagle/Library/Components/Public/DatabaseVariable.cs` — database-backed variable system
- **Source code**: `Eagle/Library/Components/Private/BundleData.cs` — script bundle data representation
- **Source code**: `Eagle/Library/Components/Private/BundleManager.cs` — bundle mounting and data retrieval
- **Schema**: `scratch/eagle/sql/scripts.sql` — script bundle database schema
- **Related documentation**: [`core_language.md`](core_language.md#cmd-sql) — basic sql command reference
- **Related documentation**: [`core_examples.md`](core_examples.md#ex-sql) — sql examples
- **Related documentation**: [`tips_and_tricks.md`](tips_and_tricks.md) — SQL best practices
- **Related documentation**: [`core_script_library.md`](core_script_library.md) — database utility procedures (haveColumnValue, getColumnValue, etc.)
- **Related documentation**: [`load.md`](load.md) — plugin loading (for database provider assemblies)
- **Related documentation**: [`interp.md`](interp.md) — interpreter security model (for bundle isolation)
- **Production reference**: `sqlite/dotnet/Tests/*.eagle` — 113 production test files demonstrating real-world database access patterns
- **Production reference**: `sqlite/dotnet/lib/System.Data.SQLite/common.eagle` — ~7,000-line test support library with `setupDb`, `cleanupDb`, connection string building, DataTable conversion, and resource management
