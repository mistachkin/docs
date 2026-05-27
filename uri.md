# Eagle `[uri]` Command: Deep-Dive Analysis of URI Operations, HTTP Client, and Async Transfers

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `[uri]` command internals, including the 18 sub-commands, the four per-interpreter web callbacks (`PreWebClientCallback`, `NewWebClientCallback`, `WebTransferCallback`, `WebErrorCallback`), custom `WebClient`-derived classes, async download/upload with `CommandCallback` script evaluation, retry infrastructure, and offline mode. For basic command syntax, see [`core_language.md`](core_language.md#cmd-uri). For usage examples, see [`core_examples.md`](core_examples.md#ex-uri). For tips on URI parsing and HTTP operations, see [`tips_and_tricks.md`](tips_and_tricks.md).

## 1. Executive Summary

Eagle's `[uri]` command provides **comprehensive URI handling and HTTP
client functionality** — constructing, parsing, validating, and comparing
URIs; performing synchronous and asynchronous HTTP downloads and uploads;
pinging hosts; querying network time; and managing offline mode and
security protocol settings. It is built on .NET's `System.Net.WebClient`
infrastructure with extensive customization hooks.

The command has three areas of complexity that go well beyond simple HTTP
requests:

1. **Four per-interpreter web callbacks** — Each interpreter has
   configurable callback properties (`PreWebClientCallback`,
   `NewWebClientCallback`, `WebTransferCallback`, `WebErrorCallback`)
   that allow complete interception and customization of the web client
   creation, transfer initiation, and error handling pipeline. These
   callbacks can substitute custom `WebClient` instances, bypass the
   default transfer mechanism, control retry behavior, and supply
   alternative results on failure.

2. **Async download/upload with `CommandCallback`** — The `-callback`
   option enables asynchronous transfers where an Eagle script is
   evaluated when the operation completes. The `CommandCallback` class
   bridges .NET's event-based async pattern to Eagle script evaluation,
   passing the URI, method, response data, cancellation status, and any
   exception details to the callback script.

3. **Custom `WebClient`-derived classes** — Eagle provides
   `TagAndTimeoutWebClient` (injects custom `X-Eagle-Tag` and
   `X-Eagle-Version` headers, applies per-request timeouts) and
   `ScriptWebClient` (test infrastructure allowing Eagle scripts to
   intercept `GetWebRequest` and `GetWebResponse` at a low level). The
   `-webclientdata` option passes custom configuration to these classes.

The command carries `CommandFlags.Unsafe | CommandFlags.NonStandard` and
is **not** part of standard Tcl. The network sub-commands (`download`,
`upload`, `get`, `post`, `ping`, `[time]`, `offline`, `security`,
`softwareupdates`) require the `NETWORK` compilation flag.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Uri.cs` | ~1,475 | Main command implementation (18 sub-commands) |
| `Eagle/Library/Components/Private/WebOps.cs` | 4,680 | Web operations: client creation, download/upload, retries, callbacks, async handlers |
| `Eagle/Library/Components/Public/WebClientData.cs` | ~200 | Transfer state container passed through callbacks |
| `Eagle/Library/Components/Private/CommandCallback.cs` | ~3,470 | Async callback bridge: .NET events → Eagle script evaluation |
| `Eagle/Library/Components/Public/Delegates.cs` | ~50 | Callback delegate declarations |
| `Eagle/Library/Interfaces/Public/WebTransferCallback.cs` | ~20 | `IWebTransferCallback` interface |
| `Eagle/Library/Interfaces/Public/WebErrorCallback.cs` | ~20 | `IWebErrorCallback` interface |
| `Eagle/Library/Interfaces/Public/NewWebClientCallback.cs` | ~20 | `INewWebClientCallback` interface |
| `Eagle/Library/Components/Public/Interpreter.cs` | 124,855 | Callback property declarations (thread-safe) |
| `Eagle/Library/Tests/Default.cs` | ~1,500 | `ScriptWebClient` (test infrastructure) |

## 2. Why the URI Command Exists

### No Tcl equivalent

Standard Tcl has no `[uri]` command. Tcl applications typically use the
`http` package (`package require http`) for HTTP operations, which
provides a different API based on tokens, callbacks, and the event loop.
Eagle's `[uri]` command takes a more direct approach, wrapping .NET's
`WebClient` class to provide synchronous and asynchronous HTTP operations
as command options.

### .NET WebClient integration

The command delegates to `System.Net.WebClient` for all HTTP operations.
This gives access to the full .NET HTTP stack including:

- Automatic proxy detection and authentication
- TLS/SSL with configurable security protocols
- Cookie management
- Custom headers and user agent strings
- Form-encoded POST data (`NameValueCollection`)
- Raw binary uploads and downloads
- File-based transfers
- Event-based asynchronous operations

### URI utility operations

Beyond HTTP transfers, the command wraps .NET's `System.Uri` and
`System.UriBuilder` classes for URI construction, parsing, validation,
comparison, and encoding/decoding — operations that Tcl handles through
separate packages or `[string map]` workarounds.

## 3. Sub-Command Overview

The command has 18 sub-commands organized into four categories:

### URI construction and parsing

| Sub-command | Syntax | Description |
|-------------|--------|-------------|
| `create` | `uri create scheme host ?options?` | Build a URI from components using `UriBuilder` |
| `[parse]` | `uri parse uri` | Decompose a URI into `-scheme`, `-host`, `-port`, `-username`, `-password`, `-path`, `-query`, `-fragment` |
| `[join]` | `uri join name ?name ...?` | Combine path segments into a URI path |
| `[host]` | `uri host uri` | Validate a hostname via `Uri.CheckHostName()` |
| `scheme` | `uri scheme name` | Validate a scheme name via `Uri.CheckSchemeName()` |

### Validation and comparison

| Sub-command | Syntax | Description |
|-------------|--------|-------------|
| `isvalid` | `uri isvalid uri ?kind?` | Test if a URI string is well-formed (`Absolute`, `Relative`, `RelativeOrAbsolute`) |
| `compare` | `uri compare ?options? uri1 uri2` | Compare two URIs by components, format, and comparison type |

### Encoding

| Sub-command | Syntax | Description |
|-------------|--------|-------------|
| `escape` | `uri escape type string` | URL-encode a string (`None`, `Uri`, `Data`) |
| `unescape` | `uri unescape string` | URL-decode a string via `Uri.UnescapeDataString()` |

### Network operations (require `NETWORK` flag)

| Sub-command | Syntax | Description |
|-------------|--------|-------------|
| `download` | `uri download ?options? uri ?fileName?` | Download data (default: file mode) |
| `get` | `uri get ?options? uri ?fileName?` | Download data (default: inline mode) |
| `upload` | `uri upload ?options? uri ?argument?` | Upload data (default: file mode) |
| `post` | `uri post ?options? uri ?argument?` | Upload data (default: inline mode) |
| `ping` | `uri ping hostOrUri timeout` | Ping a host via HTTP request or socket |
| `[time]` | `[uri time]` | Query remote time server |
| `offline` | `uri offline ?enabled?` | Get/set offline mode (reference-counted) |
| `security` | `[uri security]` | Report security protocol and network status |
| `softwareupdates` | `uri softwareupdates ?trusted? ?exclusive?` | Get/set trusted update status |

## 4. The Download/Upload Sub-Commands in Detail

### Inline mode vs file mode

The four HTTP sub-commands (`download`, `get`, `upload`, `post`) share
the same implementation but differ in their **default mode**:

| Sub-command | Default mode | To switch |
|-------------|-------------|-----------|
| `download` | File mode (save to disk) | Use `-inline` for string result |
| `get` | Inline mode (return string) | Use `-noinline` for file mode |
| `upload` | File mode (read from disk) | Use `-inline` for inline data |
| `post` | Inline mode (send inline data) | Use `-noinline` for file mode |

### Download flow

1. **Option parsing** — Parse all options from the argument list.
2. **Safety check** — If the interpreter is safe, validate the URI via
   `PolicyOps.IsTrustedUri()`. Untrusted URIs are blocked.
3. **Timeout resolution** — Resolve timeout from `-timeouttype`,
   `-timeout`, or interpreter/config defaults via `WebOps.GetTimeout()`.
4. **Security protocol setup** — (TEST builds only) Configure TLS/SSL
   via `WebOps.SetSecurityProtocol()`.
5. **Transfer**:
   - **Sync inline**: `WebOps.DownloadData()` → byte array → string
     conversion via `StringOps.GetString()` with encoding.
   - **Sync file**: `WebOps.DownloadFile()` → writes to disk.
   - **Async inline**: `WebOps.DownloadDataAsync()` → callback on
     completion.
   - **Async file**: `WebOps.DownloadFileAsync()` → callback on
     completion.

### Upload flow

1. **Option parsing** — Same as download, plus `-method`, `-data`,
   `-raw`.
2. **Safety/timeout/protocol** — Same as download.
3. **Data preparation**:
   - With `-raw`: Convert the `-data` list to a byte array.
   - Without `-raw`: Convert the `-data` list to a `NameValueCollection`
     (form-encoded key-value pairs).
4. **Transfer**:
   - **Sync inline with `-raw`**: `WebOps.UploadData()` → returns response.
   - **Sync inline without `-raw`**: `WebOps.UploadValues()` → returns
     response.
   - **Sync file**: `WebOps.UploadFile()` → returns response.
   - **Async** variants: corresponding `*Async()` methods with callback.

### The `-method` option

By default, uploads use HTTP POST. The `-method` option overrides this:

```tcl
uri upload -inline -raw -method PUT \
    -data {72 101 108 108 111} -- https://example.com/resource/1

uri upload -inline -raw -method PATCH \
    -data {48 49 50} -- https://example.com/resource/1
```

## 5. Complete Download/Upload Options Reference

### Download options (`[uri download]`, `[uri get]`)

| Option | Type | Description |
|--------|------|-------------|
| `-inline` | flag | Return data as string instead of saving to file |
| `-noinline` | flag | Save to file instead of returning as string |
| `-timeout` | int | Timeout in milliseconds |
| `-timeouttype` | TimeoutType | Use interpreter's named timeout (`None`, `network`, etc.) |
| `-retries` | int | Maximum retry attempts on failure |
| `-callback` | StringList | Eagle script to evaluate on async completion |
| `-callbackflags` | CallbackFlags | Flags controlling callback behavior (default: `Default`) |
| `-trusted` | flag | Use trusted execution context (incompatible with `-callback`) |
| `-encoding` | Encoding | Response encoding (e.g., `utf-8`) |
| `-encodingtype` | EncodingType | Encoding resolution strategy (default: `RemoteUri`) |
| `-webclientdata` | IObject | Custom WebClient configuration object |
| `-yesprotocol` | flag | (TEST only) Enable security protocol setup |
| `-noprotocol` | flag | (TEST only) Skip security protocol setup |
| `-obsolete` | flag | (TEST only) Allow obsolete protocol versions |

### Upload options (`[uri upload]`, `[uri post]`)

All download options above, plus:

| Option | Type | Description |
|--------|------|-------------|
| `-method` | string | HTTP method (default: `POST`; can be `PUT`, `PATCH`, etc.) |
| `-data` | StringList | Request body — key-value pairs (form-encoded) or raw bytes |
| `-raw` | flag | Send `-data` as raw bytes instead of form-encoded pairs |

## 6. The Four Per-Interpreter Web Callbacks

Each Eagle interpreter has four callback properties for customizing web
operations. All are thread-safe (guarded by `syncRoot`) and nullable.
They are called in a specific order during the web operation lifecycle:

```tcl
PreWebClientCallback          (1. modify creation parameters)
       ↓
NewWebClientCallback          (2. create custom WebClient)
       ↓
WebTransferCallback           (3. intercept before transfer)
       ↓
  [actual transfer]
       ↓
WebErrorCallback              (4. handle errors, control retries)
```

### Callback 1: `PreWebClientCallback`

**When called**: Before `WebClient` creation in `WebOps.CreateClient()`.

**Signature**:
```csharp
ReturnCode PreWebClientCallback(
    Interpreter interpreter,
    ref string argument,        // modifiable: tag or context string
    ref IClientData clientData, // modifiable: custom state
    ref int? timeout,           // modifiable: request timeout
    ref Result error            // error output
);
```

**Purpose**: Pre-process WebClient creation parameters. Can modify the
argument (tag), client data, and timeout before the WebClient is created.

**Return codes**:
- `Ok` — Proceed with WebClient creation using (possibly modified) parameters.
- Any other — Abort; return error.

### Callback 2: `NewWebClientCallback`

**When called**: After `PreWebClientCallback` succeeds, before default
client creation.

**Signature**:
```csharp
WebClient NewWebClientCallback(
    Interpreter interpreter,
    string argument,
    IClientData clientData,
    ref Result error
);
```

**Purpose**: Supply a custom `WebClient` instance instead of the default
`TagAndTimeoutWebClient`. This is the primary hook for using custom
`WebClient`-derived classes with specialized headers, authentication,
proxy settings, or request/response interception.

**Return values**:
- Non-null `WebClient` — Use this client for the operation.
- `null` — Fall through to default client creation.

### Callback 3: `WebTransferCallback`

**When called**: Before each download/upload operation (both sync and
async), after the `WebClient` has been created.

**Signature**:
```csharp
ReturnCode WebTransferCallback(
    Interpreter interpreter,
    WebFlags webFlags,           // operation type (DownloadData, UploadFile, etc.)
    IClientData clientData,      // WebClientData with URI, method, data, etc.
    ref Result error
);
```

**Purpose**: Intercept the transfer before it happens. The callback
receives a `WebClientData` object containing the URI, method, file name,
raw data, and other transfer parameters. The callback can:
- Handle the transfer itself (set `webClientData.Bytes` or
  `webClientData.Stream` with the result data, set
  `webClientData.ViaClient = false` to skip the default transfer).
- Let the default transfer proceed (`ViaClient` remains `true`).

**Return codes**:
- `Ok` — Transfer callback handled; check `ViaClient` to decide
  whether to proceed with the default WebClient transfer.
- `Error` — Abort the operation.

**WebFlags values** tell the callback what operation is in progress:

| WebFlags | Operation |
|----------|-----------|
| `DownloadData` | Synchronous byte download |
| `DownloadDataAsynchronous` | Async byte download |
| `DownloadFile` | Synchronous file download |
| `DownloadFileAsynchronous` | Async file download |
| `UploadData` | Synchronous raw byte upload |
| `UploadDataAsynchronous` | Async raw byte upload |
| `UploadValues` | Synchronous form-encoded upload |
| `UploadValuesAsynchronous` | Async form-encoded upload |
| `UploadFile` | Synchronous file upload |
| `UploadFileAsynchronous` | Async file upload |
| `OpenScriptStream` | Script loading via HTTP |

### Callback 4: `WebErrorCallback`

**When called**: When a download/upload operation fails, inside the retry
loop.

**Signature**:
```csharp
ReturnCode WebErrorCallback(
    Interpreter interpreter,
    IClientData clientData,
    Uri uri,
    WebFlags webFlags,
    int retries,              // current retry attempt number
    int? timeout,
    int? maximumRetries,
    ref object result,        // can supply alternative result
    ref ResultList errors     // accumulated errors from all attempts
);
```

**Purpose**: Control error handling and retry behavior. This callback
integrates deeply with the retry loop and can:

**Return codes** (each has distinct semantics):

| Return code | Effect |
|-------------|--------|
| `Ok` | Callback handled the error; use `result` as the operation's output (e.g., substitute cached data) |
| `Error` | Stop immediately; report accumulated `errors` |
| `Return` | Fake success with empty result (e.g., `new byte[0]`) |
| `Break` | Increment retry count and continue to next retry attempt |
| `Continue` | Callback did nothing; use default retry handling |

## 7. The Retry Infrastructure

All synchronous download and upload operations in `WebOps` use a retry
loop:

```tcl
while (true) {
    attempt operation once
    if success → return Ok

    add error to accumulated list

    if WebErrorCallback exists:
        switch (callback result):
            Ok       → use callback's result, return Ok
            Error    → return Error with accumulated errors
            Return   → return Ok with empty result
            Break    → increment retries, continue loop
            Continue → fall through to default retry logic

    if retries > maximumRetries → break

    SleepForRetry(retries)    // sleep duration scales with retry count
    retries++
}
return Error with all accumulated errors
```

### Retry configuration

- **`-retries N`** — Set maximum retries for this operation.
- **`WebOps.GetMaximumRetries()`** / **`SetMaximumRetries()`** — Global
  default retry limit (thread-safe via `Interlocked`).
- **`SleepForRetry()`** — Pauses between retries. Sleep duration is
  configurable or defaults to a value based on the retry count.
- **Error accumulation** — All errors across retry attempts are collected
  in a `ResultList`. The final error includes the retry count via
  `PrepareErrors()`.

## 8. Async Operations and `CommandCallback`

### How async transfers work

When the `-callback` option is used, transfers run asynchronously:

1. **Setup**: A `CommandCallback` is created from the callback script
   arguments and `CallbackFlags`. A `WebClient` is created and the
   appropriate `*Completed` event handler is attached.

2. **Initiation**: The async method is called (e.g.,
   `webClient.DownloadDataAsync(uri, callback)`) with the
   `CommandCallback` as the `UserState` object.

3. **Completion**: When the .NET async operation completes, the event
   handler fires:
   - Extracts the `ICallback` from `e.UserState`.
   - Extracts the `WebClient` and URI from `callback.ClientData`.
   - Disposes the `WebClient`.
   - Builds callback arguments via `GetAsyncCompletedArguments()`.
   - Invokes the callback script via `callback.FireEventHandler()` or
     `callback.Invoke()`.

### Arguments passed to the callback script

The async completion handler passes these named arguments to the Eagle
callback script:

| Argument | Description |
|----------|-------------|
| `[uri]` | The URI that was accessed |
| `method` | The HTTP method used (for uploads) |
| `rawData` | Hexadecimal representation of uploaded byte data |
| `data` | The `NameValueCollection` as a list (for form uploads) |
| `fileName` | The local file path (for file transfers) |
| `canceled` | Boolean indicating if the operation was cancelled |
| `exception` | .NET exception type name if an error occurred |
| `[error]` | Full exception details if an error occurred |

### `CallbackFlags` enum

The `-callbackflags` option controls how the callback is executed:

| Flag | Effect |
|------|--------|
| `Arguments` | Automatically add sender and EventArgs as opaque object handles |
| `UseOwner` | Use the interpreter's owner (`IScriptThread`) for evaluation |
| `Asynchronous` | Queue the callback asynchronously to the owner |
| `AsynchronousIfBusy` | Queue async only if the owner is busy, otherwise sync |
| `ResetCancel` | Reset script cancellation flags before evaluating |
| `MustResetCancel` | Forcefully reset cancellation (including global/pending) |
| `FireAndForget` | Auto-cleanup the callback after invocation |
| `Complain` | Report failures to debug output |
| `ThrowOnError` | Throw `ScriptException` on evaluation error |
| `CatchInterrupt` | Catch `ThreadInterruptedException` during evaluation |
| `ReturnValue` | Handle return values from the callback script |
| `DefaultValue` | Force return of a default value (0, null) |

### Example: async download with callback

```tcl
proc onDownloadComplete {args} {
    # args contains: uri, canceled, exception, error, and
    # possibly response data or opaque object handles
    array set info $args
    if {$info(canceled) eq "True"} {
        puts "Download was cancelled"
    } elseif {$info(exception) ne ""} {
        puts "Error: $info(error)"
    } else {
        puts "Download of $info(uri) complete"
    }
}

uri download -inline \
    -callback {onDownloadComplete} \
    -callbackflags {FireAndForget, ResetCancel} \
    -- https://example.com/data.json
```

### Constraint: `-trusted` and `-callback` are incompatible

The `-trusted` flag establishes a lock-based trusted execution context
for the duration of the synchronous transfer. This is incompatible with
async operations because the trusted lock cannot be held across the async
boundary. Attempting to use both produces an error: `"-trusted cannot be
used with -callback option"`.

## 9. Custom WebClient Classes

### `TagAndTimeoutWebClient`

This is Eagle's default `WebClient` subclass, used when no custom client
is supplied via callbacks. It overrides `GetWebRequest()` to inject:

- **`X-Eagle-Tag` header** — A custom tag string for request
  identification, configurable via environment variables or the `tag`
  parameter.
- **`X-Eagle-Version` header** — The Eagle runtime version string.
- **User-Agent modification** — Appends the tag to the existing
  `User-Agent` header.
- **Per-request timeout** — Sets `WebRequest.Timeout` if a timeout value
  is provided.

```tcl
Headers injected by TagAndTimeoutWebClient:
  X-Eagle-Tag: <tag value>
  X-Eagle-Version: <runtime version>
  User-Agent: <default user-agent> <tag value>
```

### `ScriptWebClient` (test infrastructure)

Available in TEST builds, `ScriptWebClient` allows Eagle scripts to
intercept web requests and responses at the `WebRequest`/`WebResponse`
level. It overrides:

- **`GetWebRequest(Uri address)`** — Evaluates a script before creating
  the request. The script receives the method name (`"GetWebRequest"`),
  the address, and can modify request properties.
- **`GetWebResponse(WebRequest, IAsyncResult)`** — Evaluates a script
  before processing the response.

Properties:
- `Text` — The Eagle script to evaluate at interception points.
- `Argument` — Method name passed during creation.
- `ThrowOnError` — Whether to throw on script evaluation errors.
- `Interpreter` — The interpreter context for script evaluation.

### The `-webclientdata` option

The `-webclientdata` option passes an opaque object to the WebClient
creation pipeline. With `ScriptWebClient`, this is typically a script
string that configures request properties:

```tcl
# Configure custom HTTP headers and timeout via ScriptWebClient
set script [object create String {
    if {[getStringFromObjectHandle methodName] eq "GetWebRequest"} then {
        webRequest KeepAlive false
        webRequest Timeout 30000
        webRequest UserAgent "MyApp/1.0"
    }
}]
set response [uri upload -timeouttype network -inline \
    -webclientdata $script -data {key value} -- $uri]
```

## 10. The WebClient Creation Pipeline

The `WebOps.CreateClient()` method orchestrates client creation through
the callback chain:

```tcl
CreateClient(interpreter, argument, clientData, tag, timeout)
│
├─ If interpreter has PreWebClientCallback:
│   └─ Call preCallback(interpreter, ref argument, ref clientData, ref timeout)
│       ├─ ReturnCode.Ok → continue with (possibly modified) params
│       └─ other → return null (creation failed)
│
├─ Check offline mode → if offline, return null with error
│
├─ If interpreter has NewWebClientCallback:
│   └─ Call newCallback(interpreter, argument, clientData, ref error)
│       ├─ returns WebClient → use it
│       └─ returns null → fall through
│
├─ (TEST only) If interpreter.UseScriptWebClient():
│   └─ Create ScriptWebClient with interpreter and script text
│
└─ Default: Create TagAndTimeoutWebClient(tag, timeout)
```

## 11. Offline Mode

Offline mode prevents all `WebClient` creation, effectively blocking all
network operations. It uses **reference counting** (via
`Interlocked.Increment` / `Interlocked.Decrement`) so that nested
`uri offline true` / `uri offline false` calls are properly balanced:

```tcl
uri offline          ;# Query: returns current state
uri offline true     ;# Enter offline mode (increment counter)
uri offline true     ;# Nested: increment counter again
uri offline false    ;# Decrement counter (still offline)
uri offline false    ;# Decrement to zero (back online)
```

When offline, `CreateClient()` returns `null` with the error
`"cannot create web client while offline"`.

## 12. The `[uri compare]` Sub-Command

The `compare` sub-command provides fine-grained URI comparison using
.NET's `Uri.Compare()` method:

```tcl
uri compare ?options? uri1 uri2
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-kind` | UriKind | `Absolute` | How to parse the URIs |
| `-components` | UriComponents | `AbsoluteUri` | Which URI parts to compare |
| `-format` | UriFormat | `UriEscaped` | How to format components for comparison |
| `-comparison` | StringComparison | (system default) | String comparison type |
| `-nocase` | flag | — | Case-insensitive comparison |

The `UriComponents` enum allows comparing specific parts: `Scheme`,
`Host`, `Port`, `Path`, `Query`, `Fragment`, or combinations.

## 13. The `[uri create]` Sub-Command

Builds a URI from components using .NET's `UriBuilder`:

```tcl
uri create scheme host ?options?
```

| Option | Type | Description |
|--------|------|-------------|
| `-username` | string | URI username component |
| `-password` | string | URI password component |
| `-port` | int | Port number |
| `-path` | string | URI path |
| `-query` | string | Query string |
| `-fragment` | string | Fragment identifier |

```tcl
uri create https api.example.com \
    -port 8443 \
    -path /v2/users \
    -query "role=admin" \
    -fragment top
# Result: https://api.example.com:8443/v2/users?role=admin#top
```

## 14. The `[uri ping]` Sub-Command

Pings a host using two strategies:

1. **URI mode** — If the argument parses as a valid URI, performs an HTTP
   download (`WebOps.DownloadData()`) and measures the round-trip time.
   Returns `IPStatus.Success` on success or `IPStatus.TimedOut` on
   timeout.

2. **Socket mode** — If URI parsing fails (e.g., bare hostname),
   falls back to `SocketOps.Ping()` for a lower-level network ping.

Return value is a `StringList` with:
- `IPStatus` enum value
- Round-trip time in milliseconds
- Units label (`"milliseconds"`)

## 15. The `[uri time]` Sub-Command

Queries a remote time server and compares with local time:

1. Records local time via `TimeOps.GetUtcNow()`.
2. Calls `ScriptOps.QueryRemoteTime()` to fetch the remote time.
3. Parses the response (expects `"OK"` status followed by a numeric
   value in milliseconds or seconds).
4. Converts via `TimeOps.UnixMillisecondsOrSecondsToDateTime()`.

Return value is a `StringList` with:
- `localNow` — ISO 8601 formatted local time
- `remoteNow` — ISO 8601 formatted remote time
- `remoteRawValue` — Original server response
- `remoteValue` — Converted numeric value
- `remoteUnits` — Units string
- `remoteDifference` — `TimeSpan` difference between remote and local

## 16. The `[uri security]` Sub-Command

Reports the current security and network status:

```tcl
uri security
```

Returns a `StringList` containing:
- `offline` — Current offline mode state
- `timeout` — Network timeout value
- `probedError` (TEST only) — Error from `WebOps.ProbeSecurityProtocol()`
- `getError` (TEST only) — Error from `WebOps.GetSecurityProtocol()`
- Additional status from `UpdateOps.GetStatus()`

## 17. The `WebClientData` State Container

`WebClientData` is the central data structure passed through the
callback chain. It carries all transfer parameters and can be both read
and modified by callbacks:

| Property | Type | Description |
|----------|------|-------------|
| `Arguments` | StringList | Callback script arguments |
| `CallbackFlags` | CallbackFlags | Callback execution control flags |
| `Uri` | Uri | Target URI |
| `Method` | string | HTTP method (GET, POST, PUT, etc.) |
| `FileName` | string | Local file path for file transfers |
| `RawData` | byte[] | Raw byte data for upload |
| `Data` | NameValueCollection | Form-encoded key-value pairs |
| `Timeout` | int? | Operation timeout in milliseconds |
| `Trusted` | bool? | Trusted execution context |
| `Stream` | Stream | For stream-based operations |
| `Bytes` | byte[] | Result bytes (set by transfer callback) |
| `ViaClient` | bool | If `true`, use WebClient; if `false`, callback handled it |

The `ViaClient` property is the key mechanism for the
`WebTransferCallback` to bypass the default transfer: set it to `false`
and populate `Bytes` or `Stream` with the result data.

## 18. Practical Patterns

### Pattern 1: Simple HTTP GET

```tcl
# Inline download (returns content as string)
set html [uri get https://example.com/]

# Equivalent:
set html [uri download -inline -- https://example.com/]
```

### Pattern 2: POST form data

```tcl
# Form-encoded POST (key-value pairs)
set response [uri post \
    -data {username admin password secret} \
    -- https://example.com/login]
```

### Pattern 3: Upload raw bytes with custom method

```tcl
# PUT raw JSON data
set response [uri upload -inline -raw -method PUT \
    -data {123 34 110 97 109 101 34 58 34 118 97 108 117 101 34 125} \
    -- https://api.example.com/resource/1]
```

### Pattern 4: Download with retries and timeout

```tcl
# Retry up to 3 times with 30-second timeout
uri download -retries 3 -timeout 30000 \
    -- https://example.com/large-file.zip /tmp/large-file.zip
```

### Pattern 5: Async download with completion callback

```tcl
proc handleDownload {args} {
    array set info $args
    if {$info(exception) ne ""} {
        puts stderr "Download failed: $info(error)"
    } else {
        puts "Downloaded $info(uri) successfully"
    }
}

uri download -inline \
    -callback {handleDownload} \
    -callbackflags {FireAndForget} \
    -- https://example.com/data.json
```

### Pattern 6: Custom WebClient via NewWebClientCallback

```csharp
// C# code to set up a custom WebClient factory
interpreter.NewWebClientCallback = delegate(
    Interpreter interp, string argument,
    IClientData clientData, ref Result error)
{
    var client = new WebClient();
    client.Headers.Add("Authorization", "Bearer " + token);
    client.Headers.Add("Accept", "application/json");
    client.Proxy = new WebProxy("http://proxy:8080");
    return client;
};
```

```tcl
# Eagle script using the custom client
set data [uri get https://api.example.com/protected/resource]
```

### Pattern 7: WebTransferCallback for caching/interception

```csharp
// C# code to intercept downloads with a cache
interpreter.WebTransferCallback = delegate(
    Interpreter interp, WebFlags webFlags,
    IClientData clientData, ref Result error)
{
    var data = clientData as WebClientData;
    if (data != null && cache.ContainsKey(data.Uri))
    {
        data.Bytes = cache[data.Uri];
        data.ViaClient = false;  // skip actual HTTP request
        return ReturnCode.Ok;
    }
    return ReturnCode.Ok;  // ViaClient remains true, proceed normally
};
```

### Pattern 8: WebErrorCallback for custom retry logic

```csharp
// C# code for custom error handling with exponential backoff
interpreter.WebErrorCallback = delegate(
    Interpreter interp, IClientData clientData, Uri uri,
    WebFlags webFlags, int retries, int? timeout,
    int? maximumRetries, ref object result,
    ref ResultList errors)
{
    if (retries < 5)
    {
        Thread.Sleep(Math.Pow(2, retries) * 1000);
        return ReturnCode.Break;  // retry with incremented count
    }
    return ReturnCode.Error;  // give up
};
```

### Pattern 9: URI construction and parsing round-trip

```tcl
# Build a URI
set uri [uri create https api.example.com \
    -port 8443 -path /v2/users -query "role=admin"]

# Parse it back
set parts [uri parse $uri]
# Returns: -scheme https -host api.example.com -port 8443
#          -path /v2/users -query ?role=admin ...
```

### Pattern 10: Offline mode for testing

```tcl
# Disable all network operations
uri offline true

# These will now fail with "cannot create web client while offline"
catch {uri get https://example.com/} err
puts $err

# Re-enable network
uri offline false
```

## 19. Comparison: Eagle `[uri]` vs Tcl HTTP Package

| Feature | Tcl (`http` package) | Eagle `[uri]` |
|---------|---------------------|---------------|
| Package requirement | `package require http` | Built-in (no package needed) |
| HTTP method | Token-based (`::http::geturl`) | Direct sub-commands (`get`, `post`, `download`, `upload`) |
| Async model | Event loop + callback | .NET event-based async + `CommandCallback` |
| Custom headers | `-headers` option | `NewWebClientCallback` or `-webclientdata` |
| Proxy support | `::http::config -proxyhost` | .NET system proxy or `NewWebClientCallback` |
| TLS/SSL | Requires `tls` package | Built into .NET runtime |
| Retry mechanism | Manual implementation | Built-in with `WebErrorCallback` integration |
| URI parsing | Separate `[uri]` package | Built into `[uri parse]` / `[uri create]` |
| URL encoding | `::http::formatQuery` | `[uri escape]` / `[uri unescape]` |
| File downloads | Manual stream handling | `uri download fileName` (one command) |
| File uploads | Manual with `::http::geturl -querychannel` | `uri upload fileName` (one command) |
| Form POST | `::http::formatQuery` + `-query` | `-data {key value ...}` (auto form-encoded) |
| Raw byte upload | Manual | `-raw -data {byte byte ...}` |
| Offline mode | Not available | `[uri offline]` (reference-counted) |
| Network ping | Not available | `uri ping host timeout` |
| Time sync | Not available | `[uri time]` |
| Transfer interception | Not available | `WebTransferCallback` |
| Error callback | Not available | `WebErrorCallback` with retry control |
| Custom client factory | Not available | `NewWebClientCallback` / `PreWebClientCallback` |

## 20. Security Considerations

- **`CommandFlags.Unsafe`** — The command is unavailable in safe
  interpreters unless specific URIs are whitelisted via
  `PolicyOps.IsTrustedUri()`.

- **URI trust validation** — In safe interpreters, every URI is checked
  against the trust policy before any network operation. Untrusted URIs
  are blocked.

- **`-trusted` execution context** — The `-trusted` flag establishes a
  lock-based context for operations that require elevated trust (e.g.,
  accessing update servers). This context cannot span async boundaries.

- **TLS/SSL protocols** — (TEST builds) Security protocols can be
  configured via `-yesprotocol`/`-noprotocol`/`-obsolete` flags and
  `WebOps.SetSecurityProtocol()`.

- **Credential exposure** — The `[uri create]` sub-command supports
  `-username` and `-password` options. URIs with embedded credentials
  should be handled carefully to avoid logging or leaking them.

- **Custom WebClient risks** — `NewWebClientCallback` allows arbitrary
  `WebClient` subclasses. A poorly implemented custom client could
  bypass security checks, leak data, or introduce vulnerabilities.

- **Offline mode as security control** — `uri offline true` can be used
  as a security measure to prevent all network access from scripts.

## 21. Relationship to Other Commands

| Related command | Relationship |
|----------------|-------------|
| `[socket]` | Low-level TCP socket operations; `[uri]` is higher-level HTTP |
| `[exec]` | Can invoke `curl`, `wget` externally; `[uri]` uses .NET HTTP natively |
| `[object]` | Can create and invoke .NET `HttpClient`, `WebRequest` directly; `[uri]` provides a simpler command interface |
| `[sql]` | Database access; script bundle loading may use HTTP internally |
| `[interp]` | Safe interpreter policies control which URIs are trusted |
| `[load]` | Plugin loading can trigger web operations (update checking) |

## 22. References

- **Source code**: `Eagle/Library/Commands/Uri.cs` — `[uri]` command (18 sub-commands)
- **Source code**: `Eagle/Library/Components/Private/WebOps.cs` — web operations, callbacks, retry logic
- **Source code**: `Eagle/Library/Components/Public/WebClientData.cs` — transfer state container
- **Source code**: `Eagle/Library/Components/Private/CommandCallback.cs` — async callback bridge
- **Source code**: `Eagle/Library/Components/Public/Delegates.cs` — callback delegate declarations
- **Source code**: `Eagle/Library/Interfaces/Public/WebTransferCallback.cs` — transfer callback interface
- **Source code**: `Eagle/Library/Interfaces/Public/WebErrorCallback.cs` — error callback interface
- **Source code**: `Eagle/Library/Interfaces/Public/NewWebClientCallback.cs` — client factory interface
- **Command reference**: [`core_language.md`](core_language.md#cmd-uri) — `[uri]` syntax and options
- **Examples**: [`core_examples.md`](core_examples.md#ex-uri) — `[uri]` examples
- **Tips**: [`tips_and_tricks.md`](tips_and_tricks.md) — URI Parsing and Construction section
- **Script library**: [`core_script_library.md`](core_script_library.md) — download helpers, URI resolution procedures
- **.NET reference**: [System.Net.WebClient](https://docs.microsoft.com/en-us/dotnet/api/system.net.webclient)
- **.NET reference**: [System.Uri](https://docs.microsoft.com/en-us/dotnet/api/system.uri)
- **.NET reference**: [System.UriBuilder](https://docs.microsoft.com/en-us/dotnet/api/system.uribuilder)
