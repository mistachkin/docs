# Eagle `[library]` Command: Deep-Dive Analysis of Native Library FFI

> **For AI agents**: This document provides a deep-dive analysis of Eagle's `library` command internals. For basic command syntax and options, see [`core_language.md`](core_language.md#cmd-library). For usage examples, see [`core_examples.md`](core_examples.md#ex-library).

## 1. Executive Summary

Eagle's `[library]` command provides **P/Invoke-style foreign function
interface (FFI)** from Eagle scripts to native (unmanaged) code. It
dynamically loads native shared libraries (DLLs on Windows, `.so` on Linux,
`.dylib` on macOS), declares function signatures as dynamically-generated
delegate types, resolves function addresses, and calls native functions with
full argument marshalling — all from script code.

This is a concept **unique to Eagle**. Native Tcl's `[load]` command loads
Tcl extensions — shared libraries that follow a specific initialization
protocol (`Tcl_PkgInitProc`) and register Tcl commands. It cannot call
arbitrary C functions by name and signature. Eagle's `[library]` command
provides true FFI: you specify any function's name, return type, parameter
types, and calling convention, then call it directly.

The command is architecturally similar to **Python's `ctypes`**, **Ruby's
`fiddle`/`ffi`**, **Lua's `luajit` FFI**, or **.NET's `DllImport`
(P/Invoke)** — but it operates entirely at the script level, generating the
required .NET delegate types at runtime using `System.Reflection.Emit`.

**Key source files:**

| File | Lines | Role |
|------|-------|------|
| `Eagle/Library/Commands/Library.cs` | 1,360 | Main command implementation (14+2 sub-commands) |
| `Eagle/Library/Components/Private/DelegateOps.cs` | ~1,200 | Dynamic delegate type creation via Reflection.Emit |
| `Eagle/Library/Components/Private/NativeDelegate.cs` | ~400 | Delegate wrapper: resolve, unresolve, invoke |
| `Eagle/Library/Components/Private/NativeModule.cs` | ~300 | Module wrapper: load, unload, reference counting |
| `Eagle/Library/Components/Private/NativeOps.cs` | ~4,600 | Platform-specific LoadLibrary/FreeLibrary/GetProcAddress |
| `Eagle/Library/Components/Private/MarshalOps.cs` | ~11,000 | Argument/return value marshalling (shared with `[object]`) |
| `Eagle/Library/Components/Private/FileOps.cs` | ~300 | PE file architecture verification |
| `Eagle/Library/Components/Private/CertificateOps.cs` | ~400 | X.509 certificate chain validation |

## 2. Why the Library Command Exists

### The problem

Scripting languages frequently need to call native platform APIs: Windows
system calls, C libraries, hardware interfaces, database drivers, or
cryptographic routines written in C/C++. Most languages provide some FFI
mechanism for this purpose.

Eagle already has deep .NET/CLR integration via the `[object]` command,
which can invoke any managed method. But calling *unmanaged* (native) code
from managed code normally requires either:

1. **Compile-time P/Invoke** — declaring `[DllImport]` attributes in C# code,
   which requires a compilation step and cannot be done dynamically.
2. **Manual marshalling** — using `Marshal.GetDelegateForFunctionPointer` with
   hand-crafted delegate types, which is verbose and error-prone.

The `[library]` command eliminates both obstacles by:

- **Generating delegate types at runtime** using `System.Reflection.Emit`
  (no compile step needed)
- **Wrapping the entire workflow** in a simple script-level API
  (load → declare → call → cleanup)
- **Reusing Eagle's existing marshalling infrastructure** (`MarshalOps`)
  for argument type conversion

### Design philosophy

The command follows a **lifecycle-oriented design** with explicit resource
management:

```
load module → declare delegate → resolve function → call → undeclare → unload
```

Each step is a separate sub-command, giving the script author full control
over resource lifetime. Reference counting ensures modules cannot be
unloaded while delegates still reference them.

## 3. Architecture Overview

### The integration stack

```
┌──────────────────────────────────────────────────────────┐
│                     Eagle Script                         │
│   library load → library declare → library call → ...    │
├──────────────────────────────────────────────────────────┤
│                   Library.cs (command)                   │
│   Parses sub-commands and options; dispatches to infra   │
├──────────────────────────────────────────────────────────┤
│              DelegateOps / NativeDelegate                │
│   CreateNativeDelegateType (Reflection.Emit)             │
│   Resolve / Unresolve / Invoke                           │
├──────────────────────────────────────────────────────────┤
│              NativeModule / NativeOps                    │
│   LoadLibrary / FreeLibrary / GetProcAddress             │
│   Reference counting and lifecycle management            │
├──────────────────────────────────────────────────────────┤
│                    MarshalOps                            │
│   FindMethodsAndFixupArguments                           │
│   FixupByRefArguments / FixupReturnValue                 │
├──────────────────────────────────────────────────────────┤
│               .NET Runtime / P/Invoke                    │
│   System.Runtime.InteropServices                         │
│   System.Reflection.Emit                                 │
├──────────────────────────────────────────────────────────┤
│               Native Platform APIs                       │
│   Windows: LoadLibrary / GetProcAddress / FreeLibrary    │
│   Unix: dlopen / dlsym / dlclose                         │
└──────────────────────────────────────────────────────────┘
```

### Component responsibilities

| Component | Responsibility |
|-----------|---------------|
| `Library.cs` | Command parsing, option handling, sub-command dispatch |
| `DelegateOps` | Dynamic delegate type creation via `AssemblyBuilder` / `TypeBuilder` |
| `NativeDelegate` | Wraps a dynamically-created delegate; handles resolve, unresolve, invoke |
| `NativeModule` | Wraps a loaded native library; handles load, unload, reference counting |
| `NativeOps` | Platform-abstracted `LoadLibrary` / `FreeLibrary` / `GetProcAddress` |
| `MarshalOps` | Type coercion, by-ref argument handling, return value conversion |
| `FileOps` | PE header parsing for architecture verification |
| `CertificateOps` | X.509 digital signature verification |

## 4. The P/Invoke Workflow

### 4.1. Loading a module (`library load`)

The first step is loading a native shared library into the process address
space.

```tcl
set kernel32 [library load kernel32.dll]
```

**What happens internally:**

1. `Library.cs` parses options: `-modulename`, `-locked`, `-flags`,
   `-trustedonly`, `-maybetrustedonly`.
2. Calls `DelegateOps.LoadNativeModule`, which:
   a. Creates a `NativeModule` instance.
   b. If `-trustedonly` is set, validates the file's Authenticode signature
      via `RuntimeOps.IsFileTrusted`.
   c. Calls `NativeOps.LoadLibrary(fileName)` — platform dispatch:
      - **Windows**: `kernel32!LoadLibraryW`
      - **Unix**: `dlopen(fileName, RTLD_NOW)`
   d. Increments the module's reference count.
3. Registers the module with the interpreter via `interpreter.AddModule`.
4. Returns the module handle name (e.g., `IModule#1`).

**Options:**

| Option | Effect |
|--------|--------|
| `-modulename name` | Custom handle name instead of auto-generated |
| `-locked` | Sets `ModuleFlags.NoUnload`; prevents `library unload` |
| `-flags flags` | Explicit `ModuleFlags` enum value |
| `-trustedonly` | Require valid Authenticode signature |
| `-maybetrustedonly` | Like `-trustedonly` but only in release builds |

**`library checkload`** shares the same code path but first checks if the
module is already loaded via `interpreter.GetModuleByFileName`. If found,
it returns the existing handle without re-loading.

### 4.2. Declaring a delegate (`library declare`)

A delegate declaration describes a native function's signature: return type,
parameter types, calling convention, and string marshalling characteristics.

```tcl
set getStdHandle [library declare \
    -functionname GetStdHandle \
    -returntype IntPtr \
    -parametertypes {int32} \
    -module $kernel32]
```

**What happens internally:**

1. `Library.cs` parses options (15 total; see table below).
2. Calls `DelegateOps.CreateNativeDelegateType`, which uses
   **`System.Reflection.Emit`** to build a delegate type at runtime:

   a. Creates an `AssemblyBuilder` (dynamic assembly in memory).
   b. Creates a `ModuleBuilder` within the assembly.
   c. Creates a `TypeBuilder` that extends `System.MulticastDelegate`.
   d. Defines the constructor: `.ctor(object, IntPtr)`.
   e. Defines the `Invoke` method with the specified return type and
      parameter types.
   f. Defines `BeginInvoke` and `EndInvoke` for async support.
   g. Applies `UnmanagedFunctionPointerAttribute` with the specified
      calling convention, charset, and error handling settings.
   h. Calls `TypeBuilder.CreateType()` to finalize the dynamic type.

3. Creates a `NativeDelegate` wrapper object with the generated type.
4. If `-module` and `-functionname` are both provided, **auto-resolves**
   the function immediately (combines declare + resolve in one step).
5. Registers the delegate with the interpreter via
   `interpreter.AddDelegate`.
6. If `-alias` is specified, creates a command alias for convenient calling.
7. Returns the delegate handle name (e.g., `IDelegate#1`).

**Declaration options:**

| Option | Default | Purpose |
|--------|---------|---------|
| `-module moduleName` | none | Module containing the target function |
| `-functionname name` | none | Native export name to resolve |
| `-address intptr` | none | Explicit function pointer (bypasses resolution) |
| `-returntype type` | `void` | Return type (CLR type name) |
| `-parametertypes typeList` | `{}` | Parameter type list |
| `-callingconvention conv` | `Winapi` | `Winapi`, `Cdecl`, `StdCall`, `ThisCall`, `FastCall` |
| `-charset charset` | `(CharSet)0` | String marshalling: `Ansi`, `Unicode`, `Auto` (.NET default) |
| `-setlasterror bool` | `false` | Capture Win32 last error after call |
| `-bestfitmapping bool` | `true` | Best-fit character mapping |
| `-throwonunmappablechar bool` | `false` | Throw on unmappable characters |
| `-assemblyname name` | auto | Custom dynamic assembly name |
| `-modulename name` | auto | Custom dynamic module name |
| `-typename name` | auto | Custom delegate type name |
| `-delegatename name` | auto | Custom delegate handle name |
| `-alias` | off | Create a command alias for the delegate |

### 4.3. Resolving a function (`library resolve`)

If the delegate was not auto-resolved during declaration (i.e., `-module`
was not provided), it must be explicitly resolved before calling.

```tcl
library resolve -module $kernel32 $getStdHandle
```

**What happens internally:**

1. Looks up the `NativeDelegate` by handle name.
2. Calls `NativeDelegate.Resolve(module, functionName)`, which:
   a. Calls `NativeOps.GetProcAddress(moduleHandle, functionName)` to get
      the native function's memory address.
   b. Calls `Marshal.GetDelegateForFunctionPointer(address, delegateType)`
      to create a callable .NET delegate pointing to that address.
   c. Stores the resulting delegate for later invocation.
   d. Increments the module's reference count (the delegate now holds a
      reference to the module).

Resolution can also be changed after the fact: calling `library resolve`
again with a different module or function name re-binds the delegate.

### 4.4. Calling a native function (`library call`)

Once declared and resolved, a native function can be called:

```tcl
set handle [library call $getStdHandle -11]
```

**What happens internally:**

1. `Library.cs` looks up the `NativeDelegate` by handle name.
2. Parses marshalling options (`-create`, `-alias`, `-dispose`, `-tostring`,
   `-nobyref`, `-debug`, `-trace`, and additional type conversion options).
3. Calls `MarshalOps.FindMethodsAndFixupArguments` to:
   a. Match the provided script arguments against the delegate's `Invoke`
      method parameters.
   b. Coerce argument types (e.g., string `"-11"` → `Int32 -11`).
   c. Handle by-reference parameters (allocating output buffers).
4. Calls `NativeDelegate.Invoke(args)`, which invokes the underlying
   .NET delegate — which in turn calls the native function via the
   function pointer.
5. Calls `MarshalOps.FixupByRefArguments` to update any Tcl variables
   that were passed by reference.
6. Calls `MarshalOps.FixupReturnValue` to convert the native return
   value back to a Tcl result string (or opaque object handle if
   `-create` was specified).

**Call options:**

| Option | Effect |
|--------|--------|
| `-create` | Wrap the return value as an opaque object handle |
| `-alias` | Create a command alias for the returned object |
| `-dispose` | Dispose of the return value after use |
| `-tostring` | Convert the return value via `.ToString()` |
| `-nobyref` | Disable by-reference argument handling |
| `-invoke` | Force invocation (default behavior) |
| `-debug` | Enable debug output for argument resolution |
| `-trace` | Enable tracing of method calls |

### 4.5. Cleanup (`library undeclare` / `library unload`)

Resources must be explicitly released in reverse order: undeclare delegates
first, then unload modules.

```tcl
library undeclare $getStdHandle
library unload $kernel32
```

**Undeclare:**
1. Calls `NativeDelegate.Unresolve()` — releases the function pointer binding
   and decrements the module's reference count.
2. Removes the delegate from the interpreter via
   `interpreter.InternalRemoveDelegate`.
3. Removes any command alias created with `-alias`.

**Unload:**
1. Checks whether any delegates still reference the module (reference count > 0).
   If so, returns an error — the module cannot be unloaded while delegates
   reference it.
2. Calls `NativeOps.FreeLibrary(moduleHandle)` — platform dispatch:
   - **Windows**: `kernel32!FreeLibrary`
   - **Unix**: `dlclose`
3. Removes the module from the interpreter via
   `interpreter.InternalRemoveModule`.

**`library unresolve`** is a partial cleanup: it releases the function pointer
binding without removing the delegate declaration. The delegate can be
re-resolved later to a different function or module.

## 5. Dynamic Delegate Type Creation

The heart of the `[library]` command is its ability to create .NET delegate
types at runtime without any compilation step. This section describes how
it works.

### The problem

.NET's `DllImport` P/Invoke mechanism requires delegate types to be defined
at compile time with attributes:

```csharp
[UnmanagedFunctionPointer(CallingConvention.StdCall)]
delegate IntPtr GetConsoleWindow();
```

This is impossible when function signatures are specified dynamically in
script code.

### The solution: Reflection.Emit

`DelegateOps.CreateNativeDelegateType` builds delegate types at runtime
using the `System.Reflection.Emit` API:

```
AssemblyBuilder (in-memory dynamic assembly)
  └─ ModuleBuilder (dynamic module)
       └─ TypeBuilder (extends MulticastDelegate)
            ├─ .ctor(object, IntPtr)
            ├─ Invoke(param1, param2, ...) → returnType
            ├─ BeginInvoke(...) → IAsyncResult
            └─ EndInvoke(...) → returnType
```

The generated type has `UnmanagedFunctionPointerAttribute` applied with
the caller-specified:
- **CallingConvention** (`Winapi`, `Cdecl`, `StdCall`, `ThisCall`, `FastCall`)
- **CharSet** (`Ansi`, `Unicode`, `Auto`)
- **BestFitMapping** (bool)
- **SetLastError** (bool)
- **ThrowOnUnmappableChar** (bool)

Once `TypeBuilder.CreateType()` is called, the resulting `Type` is a fully
valid .NET delegate type that `Marshal.GetDelegateForFunctionPointer` can
use to create a callable delegate instance pointing to any matching native
function.

### Compile-time requirements

The dynamic type creation requires the `System.Reflection.Emit` API, which
is not available in all .NET environments. The `[library]` command requires
the following compile-time features:

| Feature | Purpose |
|---------|---------|
| `EMIT` | Enables `System.Reflection.Emit` support |
| `NATIVE` | Enables native code interop support |
| `LIBRARY` | Enables the library command specifically |

If any feature is missing, the `[library]` command is not available.

## 6. Module Lifecycle and Reference Counting

### Module states

A native module progresses through a simple lifecycle:

```
          load                      unload
  ─────────────►  LOADED  ─────────────────►  UNLOADED
                    │                            ▲
                    │ declare with -module        │ undeclare (last ref)
                    ▼                             │
                 REFERENCED ──────────────────────┘
                 (refcount > 0)
```

### Reference counting rules

| Operation | Effect on reference count |
|-----------|--------------------------|
| `library load` | Sets reference count to 1 |
| `library declare -module $m` (auto-resolve) | Increments reference count |
| `library resolve -module $m $d` | Increments reference count |
| `library undeclare $d` | Decrements reference count |
| `library unresolve $d` | Decrements reference count |
| `library unload $m` | Succeeds only if reference count is 0 |

The reference counting mechanism prevents a common class of FFI bugs: calling
a native function after its library has been unloaded (which would crash the
process). By tracking references, Eagle ensures a module cannot be unloaded
while any delegate still holds a function pointer into it.

### Querying module state

```tcl
# List all loaded modules
info modules

# Get detailed module information
library info module $kernel32
# Returns: {kind NativeModule id ... name IModule#1 fileName kernel32.dll
#           module 0x7FFE12340000 referenceCount 2}
```

## 7. The Marshalling Layer

### Shared infrastructure with `[object]`

The `[library]` command reuses the same `MarshalOps` infrastructure that
powers the `[object invoke]` command for managed method calls. This means
native function calls benefit from the full type coercion and conversion
machinery that Eagle provides for .NET interop.

### Argument marshalling flow

```
Script arguments (strings)
         │
         ▼
MarshalOps.FindMethodsAndFixupArguments
  ├─ Match arguments to Invoke method parameters
  ├─ Coerce types: String → Int32, String → IntPtr, etc.
  ├─ Handle by-ref parameters (allocate output storage)
  └─ Return coerced Object[] array
         │
         ▼
delegate.Invoke(args)  ──►  Native function call
         │
         ▼
MarshalOps.FixupByRefArguments
  ├─ Read by-ref output values
  └─ Set corresponding Tcl variables
         │
         ▼
MarshalOps.FixupReturnValue
  ├─ Convert native return value to Tcl string
  ├─ Or create opaque object handle (-create)
  └─ Or call .ToString() (-tostring)
```

### Supported type conversions

Because the marshalling layer uses the standard .NET type system, the
following type names are available in `-returntype` and `-parametertypes`:

| Script name | .NET type | Notes |
|-------------|-----------|-------|
| `void` | `System.Void` | No return value |
| `Boolean` | `System.Boolean` | `true`/`false` |
| `int32` | `System.Int32` | 32-bit signed integer |
| `uint32` | `System.UInt32` | 32-bit unsigned integer |
| `int64` | `System.Int64` | 64-bit signed integer |
| `uint64` | `System.UInt64` | 64-bit unsigned integer |
| `IntPtr` | `System.IntPtr` | Platform-sized pointer |
| `UIntPtr` | `System.UIntPtr` | Platform-sized unsigned pointer |
| `String` | `System.String` | Managed string (marshalled per `-charset`) |
| `Byte[]` | `System.Byte[]` | Byte array |
| Any CLR type | Full type name | Fully-qualified .NET type names work |

### By-reference parameters

Native functions that return values through pointer parameters (a common C
pattern) are supported via by-reference argument handling:

1. During `FindMethodsAndFixupArguments`, by-ref parameters are identified
   and storage is allocated.
2. After the call, `FixupByRefArguments` reads the output values from the
   storage and sets corresponding Tcl variables.

## 8. Architecture Verification

Two sub-commands verify that a native library's architecture matches the
current process:

### `library matcharchitecture`

```tcl
if {[library matcharchitecture mylib.dll]} {
    set module [library load mylib.dll]
}
```

Returns `true` if the library's PE architecture matches the current process
(x86, x64, or ARM), `false` otherwise.

### `library verifyarchitecture`

```tcl
library verifyarchitecture mylib.dll   ;# Error if mismatch
```

Like `matcharchitecture` but raises an error on mismatch instead of
returning a boolean. Useful for fail-fast validation.

### How it works

`FileOps.CheckPeFileArchitecture` reads the PE file's magic value
(the `IMAGE_OPTIONAL_HEADER` magic field) and compares it against the
current process architecture:

| Magic value | Architecture |
|-------------|-------------|
| `0x10B` | PE32 (x86) |
| `0x20B` | PE32+ (x64) |

If the magics don't match, the library would fail to load or behave
unpredictably.

> **Note**: These sub-commands require the `NATIVE` and `TCL` compile-time
> features (they share PE-parsing infrastructure with the Tcl integration
> subsystem).

## 9. Certificate and Digital Signature Verification

The `library certificate` sub-command validates the digital signature of a
native library file:

```tcl
set cert [library certificate -chain kernel32.dll]
```

### What it does

1. `CertificateOps.GetCertificate2` retrieves the X.509 certificate
   embedded in the PE file's Authenticode signature.
2. If `-chain` is specified, `CertificateOps.VerifyChain` validates the
   full certificate chain:
   a. Creates an `X509Chain` object.
   b. Applies caller-specified verification flags, revocation mode, and
      revocation flags.
   c. Calls `chain.Build(certificate)`.
   d. Returns the certificate info on success, or an error with detailed
      chain status on failure.

### Options

| Option | Purpose |
|--------|---------|
| `-chain` | Verify the full certificate chain (not just the leaf) |
| `-cache` | Use cached certificate information |
| `-verificationflags flags` | X509 verification flags enum |
| `-revocationmode mode` | Revocation check mode |
| `-revocationflag flag` | Revocation flag |

### Integration with `library load`

The `-trustedonly` option on `library load` uses the same certificate
infrastructure to verify that a library is signed before loading it:

```tcl
# Only load if digitally signed
set module [library load -trustedonly important.dll]
```

## 10. All Sub-Commands Reference

### Module operations

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `load` | `library load ?options? fileName` | Load a native library |
| `checkload` | `library checkload ?options? fileName` | Load if not already loaded |
| `unload` | `library unload module` | Unload a native library |
| `handle` | `library handle fileName` | Get module handle by file name |

### Delegate operations

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `declare` | `library declare ?options?` | Declare a native function signature |
| `undeclare` | `library undeclare delegate` | Remove a function declaration |
| `resolve` | `library resolve ?options? delegate` | Bind delegate to function address |
| `unresolve` | `library unresolve ?options? delegate` | Unbind delegate from function |
| `call` | `library call ?options? delegate ?arg ...?` | Call a native function |

### Inspection operations

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `info delegate` | `library info delegate delegateName` | Delegate details (15 fields) |
| `info module` | `library info module moduleName` | Module details (8 fields) |

### Verification operations

| Sub-command | Syntax | Purpose |
|------------|--------|---------|
| `certificate` | `library certificate ?options? fileName` | Check digital signature |
| `matcharchitecture` | `library matcharchitecture fileName` | Check arch compatibility (bool) |
| `verifyarchitecture` | `library verifyarchitecture fileName` | Verify arch compatibility (error) |
| `test` | `library test ?fileName?` | Test library loading subsystem |

### Info sub-command output fields

**`library info delegate`** returns 15 key-value pairs:

| Field | Description |
|-------|-------------|
| `kind` | Always `NativeDelegate` |
| `id` | Internal object ID |
| `name` | Handle name (e.g., `IDelegate#1`) |
| `description` | Description string |
| `callingConvention` | Calling convention used |
| `returnType` | CLR return type |
| `parameterTypes` | List of CLR parameter types |
| `typeId` | Dynamic type ID |
| `typeName` | Dynamic type name |
| `moduleFlags` | Module flags |
| `moduleName` | Associated module handle name |
| `moduleFileName` | Native library file path |
| `moduleReferenceCount` | Module's current reference count |
| `functionName` | Native export function name |
| `address` | Resolved function pointer address |

**`library info module`** returns 8 key-value pairs:

| Field | Description |
|-------|-------------|
| `kind` | Always `NativeModule` |
| `id` | Internal object ID |
| `name` | Handle name (e.g., `IModule#1`) |
| `description` | Description string |
| `flags` | Module flags |
| `fileName` | Native library file path |
| `module` | Native module handle (pointer value) |
| `referenceCount` | Current reference count |

## 11. Comparisons to Other Languages

### Python — `ctypes`

```python
import ctypes
kernel32 = ctypes.windll.kernel32
hwnd = kernel32.GetConsoleWindow()
```

Python's `ctypes` is the closest analogue. Both `ctypes` and Eagle's
`[library]` command:
- Load libraries dynamically at runtime
- Declare function signatures (return types, parameter types)
- Call native functions with automatic type conversion
- Support multiple calling conventions

**Key differences:**
- `ctypes` uses Python class syntax for type declarations; Eagle uses
  script-level options (`-returntype`, `-parametertypes`)
- `ctypes` has built-in structure/union support; Eagle relies on .NET
  types via `[object]`
- Eagle's delegate declarations are explicit objects with lifecycle
  management (declare/undeclare); `ctypes` function objects are
  garbage-collected

### Ruby — `fiddle` / `ffi`

```ruby
require 'fiddle/import'
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  extern 'void* GetConsoleWindow()'
end
```

Ruby's `fiddle` (standard library) and the `ffi` gem provide similar
capability. Ruby `ffi` uses `extern` declarations with C-like type
syntax. Eagle uses explicit option-based declarations, which are more
verbose but require no type-syntax parser.

### Lua — LuaJIT FFI

```lua
local ffi = require("ffi")
ffi.cdef[[ void* GetConsoleWindow(); ]]
local hwnd = ffi.C.GetConsoleWindow()
```

LuaJIT's FFI accepts C header syntax directly, making declarations
very concise. Eagle's approach is more structured (individual options
per attribute) but avoids the need for a C parser.

### .NET — `DllImport` / P/Invoke

```csharp
[DllImport("kernel32.dll")]
static extern IntPtr GetConsoleWindow();
```

This is the compile-time equivalent of what Eagle's `[library]` does at
runtime. Eagle effectively generates these `DllImport`-style declarations
dynamically using `Reflection.Emit`, making them available from script
code without a compilation step.

### Node.js — `node-ffi-napi`

```javascript
const ffi = require('ffi-napi');
const kernel32 = ffi.Library('kernel32', {
  'GetConsoleWindow': ['pointer', []]
});
```

Similar pattern: load library, declare functions with types, call them.
Eagle's approach is more explicit about lifecycle management (load/unload,
declare/undeclare).

### Native Tcl — `[load]`

```tcl
load tcl_extension.so ExtensionInit
```

Tcl's `[load]` is fundamentally different: it loads **Tcl extensions** —
shared libraries that follow Tcl's package initialization protocol and
register Tcl commands. It cannot call arbitrary C functions by name and
signature. Eagle's `[library]` provides the true FFI capability that
native Tcl lacks.

## 12. Practical Patterns

### Pattern 1: Basic Windows API call

```tcl
# Load the library
set kernel32 [library load kernel32.dll]

# Declare the function
set getConsoleWindow [library declare \
    -functionname GetConsoleWindow \
    -returntype IntPtr \
    -module $kernel32]

# Call it
set hwnd [library call $getConsoleWindow]
puts "Console window handle: $hwnd"

# Cleanup
library undeclare $getConsoleWindow
library unload $kernel32
```

### Pattern 2: Function with parameters

```tcl
set kernel32 [library load kernel32.dll]

# GetStdHandle takes an int32, returns IntPtr
set getStdHandle [library declare \
    -functionname GetStdHandle \
    -returntype IntPtr \
    -parametertypes {int32} \
    -module $kernel32]

set STD_OUTPUT_HANDLE -11
set handle [library call $getStdHandle $STD_OUTPUT_HANDLE]

library undeclare $getStdHandle
library unload $kernel32
```

### Pattern 3: Multiple functions from one library

```tcl
set kernel32 [library load kernel32.dll]

# Declare multiple functions
set getConsoleWindow [library declare \
    -functionname GetConsoleWindow \
    -returntype IntPtr \
    -module $kernel32]

set getStdHandle [library declare \
    -functionname GetStdHandle \
    -returntype IntPtr \
    -parametertypes {int32} \
    -module $kernel32]

# Call them
set hwnd [library call $getConsoleWindow]
set handle [library call $getStdHandle -11]

# Module info shows reference count = 3 (1 base + 2 delegates)
puts [library info module $kernel32]

# Must undeclare all delegates before unloading
library undeclare $getStdHandle
library undeclare $getConsoleWindow
library unload $kernel32
```

### Pattern 4: Cross-library interop (calling Tcl from Eagle via FFI)

```tcl
# Load the Tcl shared library directly
set tclDll [library load tcl86.dll]

# Declare Tcl C API functions
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

# Use Tcl through the C API
set interp [library call -create $createInterp]
set code [library call $tclEval $interp {expr {2 + 2}}]

# Cleanup in reverse order
library call $deleteInterp $interp
library undeclare $deleteInterp
library undeclare $tclEval
library undeclare $createInterp
library unload $tclDll
```

### Pattern 5: Deferred resolution

```tcl
# Declare without a module — no auto-resolution
set myFunc [library declare \
    -functionname MyFunction \
    -returntype int32 \
    -parametertypes {String}]

# Load the module later
set myLib [library load mylib.dll]

# Resolve the function
library resolve -module $myLib $myFunc

# Now it can be called
set result [library call $myFunc "hello"]

# Re-resolve to a different module
set otherLib [library load otherlib.dll]
library unresolve $myFunc
library resolve -module $otherLib $myFunc
set result2 [library call $myFunc "hello"]

# Cleanup
library undeclare $myFunc
library unload $otherLib
library unload $myLib
```

### Pattern 6: Safe loading with architecture check

```tcl
set dllPath [file join $dir mylib.dll]

# Verify architecture before loading
if {[library matcharchitecture $dllPath]} {
    set module [library load $dllPath]
    # ... use it ...
} else {
    puts "Architecture mismatch — cannot load $dllPath"
}
```

### Pattern 7: Trusted-only loading

```tcl
# Only load digitally signed libraries
if {[catch {
    set module [library load -trustedonly sensitive.dll]
} err]} {
    puts "Untrusted library: $err"
} else {
    # Library is signed — safe to use
    # ...
    library unload $module
}
```

## 13. Security Considerations

The `[library]` command is inherently dangerous because it allows arbitrary
native code execution. Eagle addresses this through multiple layers:

### Command flags

The command is flagged with:
- **`CommandFlags.NativeCode`** — marks it as executing native code
- **`CommandFlags.Unsafe`** — marks it as unsafe
- **`CommandFlags.Critical`** — marks it as security-critical
- **`CommandFlags.NonStandard`** — marks it as a non-standard Eagle extension

These flags mean the command is **not available in safe interpreters** and
can be restricted via interpreter policies.

### Certificate verification

The `-trustedonly` option on `library load` verifies Authenticode signatures
before loading, ensuring only signed libraries from trusted publishers can
be loaded.

### Architecture verification

The `matcharchitecture` and `verifyarchitecture` sub-commands prevent
loading libraries with incompatible architectures, which could cause
crashes or undefined behavior.

### Reference counting

The reference counting mechanism prevents use-after-free scenarios: a
module cannot be unloaded while delegates still hold function pointers
into it.

### Interpreter modifiability check

The `library unresolve` sub-command checks `interpreter.IsModifiable`
before allowing changes, respecting interpreter lock-down policies.

## 14. Error Handling

### Common error scenarios

| Scenario | Error behavior |
|----------|---------------|
| Library file not found | Error from `NativeOps.LoadLibrary` |
| Function not found in library | Error from `NativeOps.GetProcAddress` |
| Architecture mismatch | `verifyarchitecture` raises error; `matcharchitecture` returns `false` |
| Untrusted library with `-trustedonly` | Error before loading |
| Unload with outstanding delegates | Error: reference count > 0 |
| Call unresolved delegate | Error: no function address bound |
| Argument type mismatch | Error from `MarshalOps.FindMethodsAndFixupArguments` |
| Missing compile-time features | Command not available at all |

### Error from native functions

Native function errors are handled differently depending on the function:

- If the function returns an error code, it is returned as the script result.
- If `-setlasterror` was specified during declaration, the Win32 last error
  code is captured and available via `Marshal.GetLastWin32Error()`.
- If the native function crashes (access violation, etc.), the behavior
  depends on the .NET runtime's structured exception handling.

## 15. Decision Guide

### When to use `[library]` vs `[object]`

| Situation | Use |
|-----------|-----|
| Calling managed (.NET) methods | `[object invoke]` |
| Calling native (C/C++) functions | `[library call]` |
| Loading .NET assemblies | `[object load]` |
| Loading native shared libraries | `[library load]` |
| .NET type manipulation | `[object create/invoke/dispose]` |
| P/Invoke-style native calls | `[library declare/call]` |

### When to use `[library]` vs `[tcl]`

| Situation | Use |
|-----------|-----|
| Calling arbitrary C functions | `[library]` |
| Running Tcl scripts from Eagle | `[tcl eval]` |
| Using Tcl packages | `[tcl eval]` with `package require` |
| Calling Tcl C API directly | Either — `[library]` is lower-level |
| Bidirectional command bridging | `[tcl]` (built-in bridge support) |
| One-off native function call | `[library]` (simpler setup) |

### When to use `[library]` vs `[exec]`

| Situation | Use |
|-----------|-----|
| Call a C function in a library | `[library]` |
| Run an external program | `[exec]` |
| Need function return values | `[library]` |
| Need stdin/stdout/stderr | `[exec]` |
| In-process native code | `[library]` |
| Subprocess isolation | `[exec]` |

## 16. Relationship to Other Commands

### `[object]` — Managed counterpart

The `[library]` command is the native/unmanaged counterpart to `[object]`.
Where `[object]` provides access to the managed .NET world (assemblies,
classes, methods, properties), `[library]` provides access to the native
world (shared libraries, C functions, pointers).

Both commands share the `MarshalOps` infrastructure for type coercion and
argument handling.

### `[tcl]` — Higher-level native Tcl integration

The `[tcl]` command provides a higher-level interface for native Tcl
integration that internally uses the same kind of native function binding
(via `TclApi` and `NativeStubs`). The `[library]` command provides the
general-purpose, lower-level FFI that can target any native library, not
just Tcl.

### `[info modules]` and `[info delegates]`

These `[info]` sub-commands list all currently loaded native modules and
declared delegates, respectively. They complement `library info module`
and `library info delegate` which provide detailed information about
specific items.

## 17. References

| Resource | Description |
|----------|-------------|
| [`core_language.md#cmd-library`](core_language.md#cmd-library) | Command syntax and options reference |
| [`core_examples.md#ex-library`](core_examples.md#ex-library) | Usage examples |
| [`tcl.md`](tcl.md) | Deep-dive on the `[tcl]` command (higher-level native Tcl integration) |
| [`exec.md`](exec.md) | Deep-dive on the `[exec]` command (external process execution) |
| [.NET P/Invoke documentation](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke) | Microsoft's P/Invoke reference |
| [System.Reflection.Emit](https://learn.microsoft.com/en-us/dotnet/api/system.reflection.emit) | The .NET API used for dynamic type creation |
