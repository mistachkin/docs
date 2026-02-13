# Eagle Integration Sub-Projects

> **For AI agents**: This document covers Eagle's four official integration
> sub-projects (MSBuild, WiX, PowerShell, MonoDevelop). For core language
> syntax, see [core_language.md](core_language.md). For worked examples, see
> [core_examples.md](core_examples.md). For script library procedures, see
> [core_script_library.md](core_script_library.md). For the Garuda native Tcl
> package, see [garuda.md](garuda.md).

Eagle provides four integration sub-projects that embed the Eagle interpreter
into external host environments. Each integration adapts Eagle's core
evaluation and substitution capabilities to a specific platform: two build-time
tools (MSBuild, WiX), one shell (PowerShell), and one IDE (MonoDevelop).

## Table of Contents

- [Overview](#overview)
  - [Purpose of the Integration Sub-Projects](#purpose-of-the-integration-sub-projects)
  - [The Five Operations Pattern](#the-five-operations-pattern)
  - [Integration Summary](#integration-summary)
  - [Source File Reference](#source-file-reference)
- [MSBuild Integration (Eagle/Build)](#msbuild-integration-eaglebuild)
  - [Architecture](#architecture)
  - [Setup and Configuration](#setup-and-configuration)
  - [Task Reference](#task-reference)
  - [Parameters](#parameters)
  - [The \_\_task Object](#the-__task-object)
  - [Examples](#examples)
  - [Known Limitations](#known-limitations)
- [WiX Toolset Integration (Eagle/Installer)](#wix-toolset-integration-eagleinstaller)
  - [Architecture](#architecture-1)
  - [Variable Access](#variable-access)
  - [Function Invocation](#function-invocation)
  - [Pragma Processing (WiX 3.5+)](#pragma-processing-wix-35)
  - [Interpreter Lifecycle](#interpreter-lifecycle)
  - [Examples](#examples-1)
  - [WiX Version Support](#wix-version-support)
  - [Known Limitations](#known-limitations-1)
- [PowerShell Integration (Eagle/Management)](#powershell-integration-eaglemanagement)
  - [Architecture](#architecture-2)
  - [Installation](#installation)
  - [Cmdlet Reference](#cmdlet-reference)
  - [Parameters](#parameters-1)
  - [The \[cmdlet\] Meta-Command](#the-cmdlet-meta-command)
  - [Policy Engine](#policy-engine)
  - [Interpreter Lifecycle](#interpreter-lifecycle-1)
  - [Verb Naming](#verb-naming)
  - [Examples](#examples-2)
  - [Known Limitations](#known-limitations-2)
- [MonoDevelop Integration (Eagle/MonoDevelop)](#monodevelop-integration-eaglemonodevelop)
  - [Status: Proof-of-Concept Only](#status-proof-of-concept-only)
  - [Architecture](#architecture-3)
  - [Command Reference](#command-reference)
  - [Interpreter Lifecycle](#interpreter-lifecycle-2)
  - [Result Handling](#result-handling)
  - [Configuration](#configuration)
  - [Limitations](#limitations)
- [Cross-Integration Comparison](#cross-integration-comparison)
  - [Feature Matrix](#feature-matrix)
  - [Interpreter Lifecycle Comparison](#interpreter-lifecycle-comparison)
  - [When to Use Which Integration](#when-to-use-which-integration)

---

## Overview

### Purpose of the Integration Sub-Projects

These four sub-projects serve three complementary purposes:

**1. Direct use with their respective host environments.**
Each integration is a fully functional component designed for production use
in its target platform (with the exception of the MonoDevelop add-in, which
is an explicit proof-of-concept). The MSBuild tasks, WiX preprocessor
extension, and PowerShell cmdlets are all shipped, tested, and used in real
build and deployment pipelines.

**2. Idiomatic examples of how to embed the Eagle interpreter.**
Beyond their immediate utility, these sub-projects serve as reference
implementations that demonstrate how to write code that uses the Eagle core
library. Each one illustrates a different embedding pattern: inheriting from
a host base class (`Task`, `PreprocessorExtension`, `Cmdlet`,
`CommandHandler`), creating and configuring an `Interpreter` instance with
appropriate creation flags, calling the five `Engine` methods, and managing
the interpreter lifecycle. Developers building their own Eagle integrations
can study these sub-projects to see how interpreter creation, startup option
processing, object registration (e.g., `__task`), policy enforcement, and
error handling are done idiomatically in practice.

**3. Customizable starting points for new integrations.**
The source code for these integrations is not written in stone. The
architectural choices documented in this file -- interpreter lifecycle
management, creation flag defaults, parameter surface area, bridge object
registration -- are all deliberate design decisions made for the specific
host environment, but they can be changed rather easily to suit different
requirements. For example, the MSBuild integration creates a new interpreter
per task invocation for clean isolation; if a particular workflow would
benefit from a shared interpreter across tasks (for state continuity or
reduced startup overhead), the `Script` base class can be modified to
support that. Similarly, the PowerShell integration uses
`CreateFlags.SafeEmbeddedUse` by default, but this is a single constant
that can be changed to `EmbeddedUse` or any other combination. This ease of
customization is a core part of Eagle's design philosophy: the interpreter
is straightforward to integrate with in a variety of different ways, and
these sub-projects demonstrate the range of possibilities while providing
practical starting points.

### The Five Operations Pattern

All four integrations expose the same five core operations, which map directly
to methods on the Eagle `Engine` class:

| Operation | Engine Method | Mode | Input |
|-----------|--------------|------|-------|
| EvaluateExpression | `Engine.EvaluateExpression` | Evaluation | Mathematical or logical expression |
| EvaluateScript | `Engine.EvaluateScript` | Evaluation | Eagle script text |
| EvaluateFile | `Engine.EvaluateFile` | Evaluation | Path to an Eagle script file |
| SubstituteString | `Engine.SubstituteString` | Substitution | Template string with embedded commands/variables |
| SubstituteFile | `Engine.SubstituteFile` | Substitution | Path to a template file |

**Evaluation** fully parses and executes the input as Eagle code, returning
the script result.

**Substitution** performs command, variable, and backslash substitutions within
the input text but does not parse it as a complete script. This is analogous to
Tcl's `subst` command.

### Integration Summary

| Name | Directory | Host Environment | Production Status | Interpreter Lifecycle | Parameter Count |
|------|-----------|------------------|-------------------|----------------------|-----------------|
| Eagle/Build | `Eagle/Build/` | MSBuild | Production | New per task | 12 input + 2 output |
| Eagle/Installer | `Eagle/Installer/` | WiX Toolset | Production | Shared per compilation | N/A (host-driven) |
| Eagle/Management | `Eagle/Management/` | PowerShell | Production | New per cmdlet | 20+ input |
| Eagle/MonoDevelop | `Eagle/MonoDevelop/` | MonoDevelop IDE | Proof-of-concept | Shared per add-in lifetime | None (text input only) |

### Source File Reference

| Integration | File | Description |
|-------------|------|-------------|
| MSBuild | `Eagle/Build/Tasks/Script.cs` | Abstract base class (689 lines) |
| MSBuild | `Eagle/Build/Tasks/EvaluateExpression.cs` | Expression evaluation task |
| MSBuild | `Eagle/Build/Tasks/EvaluateScript.cs` | Script evaluation task |
| MSBuild | `Eagle/Build/Tasks/EvaluateFile.cs` | File evaluation task |
| MSBuild | `Eagle/Build/Tasks/SubstituteString.cs` | String substitution task |
| MSBuild | `Eagle/Build/Tasks/SubstituteFile.cs` | File substitution task |
| MSBuild | `Eagle/Targets/Eagle.tasks` | UsingTask declarations |
| MSBuild | `Eagle/Targets/Eagle.Settings.targets` | Build settings |
| MSBuild | `Eagle/Targets/Eagle.Sample.targets` | Usage examples (226 lines) |
| WiX | `Eagle/Installer/Extensions/Eagle.cs` | WixExtension class |
| WiX | `Eagle/Installer/Extensions/Preprocessor.cs` | PreprocessorExtension (571 lines) |
| WiX | `Eagle/Installer/Tests/test.wxs` | Test WiX source |
| WiX | `Eagle/Installer/Tests/Scripts/test.eagle` | Test Eagle helper script |
| PowerShell | `Eagle/Management/Cmdlets/Script.cs` | Abstract base class (~1,900 lines) |
| PowerShell | `Eagle/Management/Cmdlets/EvaluateExpression.cs` | Expression cmdlet |
| PowerShell | `Eagle/Management/Cmdlets/EvaluateScript.cs` | Script cmdlet |
| PowerShell | `Eagle/Management/Cmdlets/EvaluateFile.cs` | File cmdlet |
| PowerShell | `Eagle/Management/Cmdlets/SubstituteString.cs` | String substitution cmdlet |
| PowerShell | `Eagle/Management/Cmdlets/SubstituteFile.cs` | File substitution cmdlet |
| PowerShell | `Eagle/Management/Commands/Cmdlet.cs` | Meta-command (~700 lines) |
| PowerShell | `Eagle/Management/Components/Private/Constants.cs` | Help strings and constants |
| PowerShell | `Eagle/Management/SnapIns/Default.cs` | PSSnapIn registration |
| PowerShell | `Eagle/Management/Tools/EagleCmdlets.ps1` | Installation script |
| MonoDevelop | `Eagle/MonoDevelop/Handlers/Script.cs` | Abstract base class (~600 lines) |
| MonoDevelop | `Eagle/MonoDevelop/Handlers/EvaluateExpression.cs` | Expression handler |
| MonoDevelop | `Eagle/MonoDevelop/Handlers/EvaluateScript.cs` | Script handler |
| MonoDevelop | `Eagle/MonoDevelop/Handlers/EvaluateFile.cs` | File handler |
| MonoDevelop | `Eagle/MonoDevelop/Handlers/SubstituteString.cs` | String substitution handler |
| MonoDevelop | `Eagle/MonoDevelop/Handlers/SubstituteFile.cs` | File substitution handler |
| MonoDevelop | `Eagle/MonoDevelop/Resources/Eagle.MonoDevelop.addin.xml` | Add-in manifest |

---

## MSBuild Integration (Eagle/Build)

The MSBuild integration provides five custom build tasks that allow Eagle
scripts to be executed during the build process. This enables build-time code
generation, validation, file-version queries, and other tasks that are
difficult or impossible with MSBuild alone.

### Architecture

The integration uses a template method pattern:

- **`Script`** (`Eagle._Tasks.Script`) is an abstract base class that inherits
  from `Microsoft.Build.Utilities.Task` and implements `IDisposable`. It
  contains all parameter definitions, interpreter creation logic, and the five
  engine helper methods.

- **Five sealed task classes** each override the `Execute` method to call one
  specific engine helper:

  | Class | Engine Call |
  |-------|-----------|
  | `EvaluateExpression` | `Engine.EvaluateExpression` |
  | `EvaluateScript` | `Engine.EvaluateScript` |
  | `EvaluateFile` | `Engine.EvaluateFile` |
  | `SubstituteString` | `Engine.SubstituteString` |
  | `SubstituteFile` | `Engine.SubstituteFile` |

Default interpreter creation flags:

- `CreateFlags.EmbeddedUse` -- initializes the script library, throws on
  disposed object access, throws on interpreter creation failure, keeps only
  existing directories in the auto-path.
- `HostCreateFlags.EmbeddedUse` -- does not change console title, does not
  change console icon, does not intercept Ctrl-C.

Each `Execute` method follows the same pattern:
1. `PreCreateInterpreter` -- updates creation flags from startup options.
2. `CreateInterpreter` -- creates a new `Interpreter` instance.
3. `PostCreateInterpreter` -- processes startup options and registers the
   `__task` object handle.
4. Calls the appropriate engine method.
5. Disposes the interpreter.

### Setup and Configuration

Three MSBuild files control the integration:

**`Eagle.Settings.targets`** defines default properties:

- `EagleTaskTargets` (default: `true`) -- master switch for enabling Eagle
  build tasks.
- `EagleTaskPath` -- path to the directory containing `EagleTasks.dll`.

**`Eagle.tasks`** contains `UsingTask` declarations that register each task.
All five tasks are loaded from the same `EagleTasks.dll` assembly, conditional
on the assembly file existing at `$(EagleTaskPath)`:

```xml
<UsingTask TaskName="EvaluateExpression"
           Condition="'$(EagleTaskPath)' != '' And
                      HasTrailingSlash('$(EagleTaskPath)') And
                      Exists('$(EagleTaskPath)EagleTasks.dll')"
           AssemblyFile="$(EagleTaskPath)EagleTasks.dll" />
```

The same pattern applies to `EvaluateScript`, `EvaluateFile`,
`SubstituteString`, and `SubstituteFile`.

**`.user` file overrides** -- both `Eagle.tasks` and `Eagle.Sample.targets`
check for a `.user` companion file (e.g., `Eagle.tasks.user`,
`Eagle.Sample.targets.user`) and import it if present. This allows per-user
settings to override the defaults without modifying the checked-in files.

### Task Reference

| Task | Text Parameter Meaning | Operation |
|------|----------------------|-----------|
| `EvaluateExpression` | Expression string (e.g., `2 + 2`) | Evaluates a mathematical/logical expression |
| `EvaluateScript` | Eagle script text | Evaluates a complete Eagle script |
| `EvaluateFile` | File path to an Eagle script | Evaluates the contents of a script file |
| `SubstituteString` | Template string with embedded substitutions | Performs command, variable, and backslash substitutions |
| `SubstituteFile` | File path to a template file | Performs substitutions on file contents |

### Parameters

All five tasks share the same parameter set, defined in the `Script` base
class:

**Input parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Text` | `string` | Yes | The expression, script, file path, or template to process |
| `Args` | `string` | No | Command-line arguments for the interpreter (space-separated list) |
| `CreateFlags` | `CreateFlags` | No | Interpreter creation flags (default: `EmbeddedUse`) |
| `HostCreateFlags` | `HostCreateFlags` | No | Host creation flags (default: `EmbeddedUse`) |
| `EngineFlags` | `EngineFlags` | No | Flags for modifying engine behavior (default: `None`) |
| `SubstitutionFlags` | `SubstitutionFlags` | No | Flags for substitution behavior (default: `Default`) |
| `EventFlags` | `EventFlags` | No | Flags for event handling (default: `Default`) |
| `ExpressionFlags` | `ExpressionFlags` | No | Flags for expression evaluation (default: `Default`) |
| `Exceptions` | `bool` | No | Allow non-Ok return codes as success (default: `false`) |
| `ShowStackTrace` | `bool` | No | Display exception stack traces in error output (default: `true`) |

Each flag parameter also has a corresponding `*String` variant (e.g.,
`CreateFlagsString`) that accepts a parseable string representation instead
of the enum value.

**Output parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `Code` | `ReturnCode` | The Eagle return code (`Ok`, `Error`, etc.) |
| `Result` | `string` | The result value on success, or error message on failure |

### The \_\_task Object

After interpreter creation, the `PostCreateInterpreter` method registers the
task instance itself as an opaque object handle named `__task` in the
interpreter. This allows Eagle scripts running inside the task to call back
into the MSBuild build engine.

The most common use is accessing `BuildEngine` to log messages:

```tcl
catch {
  __task BuildEngine.LogMessageEvent [set e \
      [object create \
          Microsoft.Build.Framework.BuildMessageEventArgs \
          {some high-priority build message} null \
          EagleTasks $argv]]
  unset e
}
```

The `catch` wrapper is necessary (see [Known Limitations](#known-limitations))
because a CLR version mismatch between the built Eagle assembly and MSBuild
can cause reflection errors when accessing `BuildEngine`.

### Examples

All examples are derived from `Eagle/Targets/Eagle.Sample.targets`.

**Simple expression evaluation:**

```xml
<EvaluateExpression Text="2 + 2">
  <Output TaskParameter="Code"
          PropertyName="EvaluateExpressionCode" />
  <Output TaskParameter="Result"
          PropertyName="EvaluateExpressionResult" />
</EvaluateExpression>
```

Result: `Code` = `Ok`, `Result` = `4`.

**Script: query a file version:**

```xml
<EvaluateScript Text="return [file version {$(TargetPath)}]">
  <Output TaskParameter="Code"
          PropertyName="EvaluateScriptCode1" />
  <Output TaskParameter="Result"
          PropertyName="EvaluateScriptResult1" />
</EvaluateScript>
```

Uses the MSBuild property `$(TargetPath)` embedded in the script text. The
Eagle `file version` command retrieves the Win32 file version.

**Script with Args parameter:**

```xml
<EvaluateScript Args="one two {three four}"
                Text="return [list [llength $argv] $argv]">
  <Output TaskParameter="Code"
          PropertyName="EvaluateScriptCode2" />
  <Output TaskParameter="Result"
          PropertyName="EvaluateScriptResult2" />
</EvaluateScript>
```

Result: `Code` = `Ok`, `Result` = `3 one two {three four}`.

**\_\_task BuildEngine logging with catch:**

```xml
<EvaluateScript
    Args="High"
    Text="catch {__task BuildEngine.LogMessageEvent
          [set e [object create
          Microsoft.Build.Framework.BuildMessageEventArgs
          {some high-priority build message} null
          EagleTasks $argv]]; unset e}">
  <Output TaskParameter="Code"
          PropertyName="EvaluateScriptCode3" />
  <Output TaskParameter="Result"
          PropertyName="EvaluateScriptResult3" />
</EvaluateScript>
```

The `catch` command prevents build errors from CLR version mismatches. The
`Args` parameter sets `$argv` to `High`, which becomes the message importance
level.

**SubstituteString:**

```xml
<SubstituteString Text="[file version {$(TargetPath)}]">
  <Output TaskParameter="Code"
          PropertyName="SubstituteStringCode" />
  <Output TaskParameter="Result"
          PropertyName="SubstituteStringResult" />
</SubstituteString>
```

Performs command substitution on the template. The `[file version ...]` command
is evaluated inline, and the result replaces the command substitution in the
output string.

**EvaluateFile with conditional path check:**

```xml
<EvaluateFile
    Condition="'$(EagleLibraryDir)' != '' And
               HasTrailingSlash('$(EagleLibraryDir)') And
               Exists('$(EagleLibraryDir)Tests\data\evaluate.eagle')"
    Text="$(EagleLibraryDir)Tests\data\evaluate.eagle">
  <Output TaskParameter="Code"
          PropertyName="EvaluateFileCode" />
  <Output TaskParameter="Result"
          PropertyName="EvaluateFileResult" />
</EvaluateFile>
```

The MSBuild `Condition` attribute ensures the file exists before attempting
evaluation. The `Text` parameter specifies the file path, not a script string.

### Known Limitations

- **CLR version mismatch**: When Eagle is built for one .NET Framework version
  (e.g., .NET 2.0) and MSBuild runs under another (e.g., .NET 4.0), accessing
  `BuildEngine` or other MSBuild types through the `__task` object may cause
  reflection errors. Wrap such calls in `catch` to handle this gracefully.

- **New interpreter per task invocation** (design choice): Each task creates
  and disposes its own interpreter instance, providing clean isolation between
  tasks. This is a deliberate default, not a fixed constraint -- the `Script`
  base class can be modified to share an interpreter across tasks if a
  particular workflow benefits from state continuity or reduced startup
  overhead. With the current default, if you need state across tasks, write
  intermediate values to MSBuild properties or files.

- **Mono: resource generation targets disabled**: The `EagleSamplePackagesResGen`
  target is disabled when `$(BuildTool)` is not `MSBuild` (i.e., when building
  under Mono), due to incorrect handling of `UseSourcePath` semantics that
  causes referenced file paths to contain extra directory components.

---

## WiX Toolset Integration (Eagle/Installer)

The WiX integration embeds Eagle into the WiX Toolset preprocessor, enabling
Eagle variables, functions, and scripts to be used during installer
compilation. This is useful for injecting build-time values (timestamps,
version numbers, environment data) into WiX source files and for generating
dynamic XML fragments.

### Architecture

The integration consists of two classes:

- **`Eagle`** (`Eagle._Extensions.Eagle`) is an `internal sealed` class that
  extends `WixExtension` and implements `IDisposable`. It serves as the entry
  point and lazily initializes the `Preprocessor` instance.

- **`Preprocessor`** (`Eagle._Extensions.Preprocessor`) is an `internal sealed`
  class that extends `PreprocessorExtension` and implements `IDisposable`. This
  class (571 lines) contains all the integration logic: variable access,
  function invocation, and pragma processing.

The preprocessor prefix is `"eagle"`, derived from the Eagle script file
extension (`.eagle` with the leading dot removed).

Default flags:

- `CreateFlags.EmbeddedUse` (with `ThrowOnDisposed` removed for pre-3.5
  builds)
- `HostCreateFlags.EmbeddedUse`

### Variable Access

Eagle variables are accessed from WiX source files using the syntax:

```
$(eagle.variableName)
```

**Bracket-to-parenthesis translation**: Because WiX uses parentheses for its
own preprocessor syntax, array element access requires bracket notation. The
preprocessor automatically translates `[` to `(` and `]` to `)` before
querying the Eagle interpreter:

| WiX Syntax | Eagle Variable |
|------------|----------------|
| `$(eagle.tcl_platform[os])` | `tcl_platform(os)` |
| `$(eagle.env[USERNAME])` | `env(USERNAME)` |
| `$(eagle.myVar)` | `myVar` |

If the variable does not exist, a `ScriptException` is thrown with the error
details.

### Function Invocation

Eagle commands can be invoked from WiX using the function call syntax:

```
$(eagle.commandName(arg1,arg2,...))
```

The preprocessor calls `Interpreter.Invoke` with the command name and
arguments. The string result is returned to WiX. For example:

| WiX Syntax | Eagle Command |
|------------|---------------|
| `$(eagle.set(dir,value))` | `set dir value` |
| `$(eagle.clock(build))` | `clock build` |

### Pragma Processing (WiX 3.5+)

WiX 3.5 and later support custom pragma processing instructions. The Eagle
preprocessor handles pragmas with the `eagle` prefix:

```xml
<?pragma eagle.Mode arguments?>
```

Where `Mode` is one of:

| Mode | Description |
|------|-------------|
| `EvaluateExpression` | Evaluate an Eagle expression |
| `EvaluateScript` | Evaluate an Eagle script |
| `EvaluateFile` | Evaluate an Eagle script file |
| `SubstituteString` | Perform substitutions on a string |
| `SubstituteFile` | Perform substitutions on a file |

The result of the operation is written as **raw XML** at the pragma location
in the output document using `XmlWriter.WriteRaw`. This means the result must
be valid XML (or empty) for the WiX compilation to succeed.

Line endings in the pragma arguments are normalized before processing.

### Interpreter Lifecycle

The WiX integration uses a **single interpreter per compilation session**:

- **`InitializePreprocess`**: Creates the interpreter with the configured
  creation flags, processes startup options, and makes it available for all
  subsequent variable, function, and pragma operations.

- **`FinalizePreprocess`** (WiX 3.5+): Disposes the interpreter at the end
  of the compilation session.

Because the interpreter persists across the entire compilation, variables set
in one pragma or function call are available to later ones. This enables
patterns like setting a directory variable early and referencing it in
subsequent pragmas.

### Examples

All examples are derived from `Eagle/Installer/Tests/test.wxs` and
`Eagle/Installer/Tests/Scripts/test.eagle`.

**Variable access -- operating system:**

```xml
<Property Id="BuildOperatingSystem"
          Value="$(eagle.tcl_platform[os])" />
```

Accesses `tcl_platform(os)` (the bracket-to-parenthesis translation converts
`[os]` to `(os)`). The WiX property receives the operating system name from
the Eagle interpreter.

**Function invocation -- set a directory variable:**

```xml
<Property Id="BuildSourceFileDir"
          Value="$(eagle.set(dir,$(sys.SOURCEFILEDIR)))" />
```

Invokes the Eagle `set` command to store the WiX system variable
`$(sys.SOURCEFILEDIR)` into an Eagle variable named `dir`. This variable is
then available to subsequent scripts and pragmas in the same compilation
session.

**Function invocation -- build number:**

```xml
<Property Id="BuildNumber"
          Value="$(eagle.clock(build))" />
```

Invokes the Eagle `clock build` command to get the daily build number.

**Pragma -- EvaluateScript with source and makeProperty:**

```xml
<?pragma eagle.EvaluateScript
  #
  # NOTE: This is a fairly trivial example of how to do something
  #       useful in an Eagle script that is being evaluated from
  #       inside the WiX preprocessor.  The final result of this
  #       script will be inserted as raw XML into the XML document
  #       at this location.
  #
  source [file normalize [file join $dir Scripts test.eagle]]
  makeProperty BuildUserName $env(USERNAME)
?>
```

This pragma evaluates an Eagle script that:
1. Sources a helper script (`test.eagle`) from the `Scripts` subdirectory.
2. Calls `makeProperty` to generate a WiX `<Property>` XML element.

**The `makeProperty` helper procedure** (from `test.eagle`):

```tcl
proc makeProperty { name value } {
  return [appendArgs <Property " " \
      Id=\" $name "\" " Value=\" $value "\" />"]
}
```

This procedure generates a WiX `<Property>` XML element as a string. When
returned from a pragma, the raw XML is inserted into the output document at
the pragma location.

### WiX Version Support

| WiX Version | Variable Access | Function Invocation | Pragma Processing |
|-------------|----------------|---------------------|-------------------|
| 3.0 | Yes | Yes | No |
| 3.5 | Yes | Yes | Yes |
| 3.6 | Yes | Yes | Yes |
| 3.7 | Yes | Yes | Yes |
| 3.8 | Yes | Yes | Yes |
| 3.9 | Yes | Yes | Yes |
| 3.10 | Yes | Yes | Yes |
| 3.11 | Yes | Yes | Yes |

Pragma processing requires WiX 3.5 or higher. The `FinalizePreprocess` method
(which properly disposes the interpreter) also requires WiX 3.5+.

### Known Limitations

- **Bracket syntax for array access**: Accessing array elements requires
  brackets (`[os]`) instead of the natural Tcl/Eagle parentheses (`(os)`).
  This is because WiX reserves parentheses for its own preprocessor syntax.

- **Pragma support requires WiX 3.5+**: The five-operation pragma mechanism
  is not available in WiX versions prior to 3.5. Only variable access and
  function invocation are available in WiX 3.0.

- **Shared interpreter state** (design choice): Because a single interpreter
  is shared across the entire compilation session, variables and state changes
  from one operation are visible to all subsequent operations. This is
  deliberate -- it enables useful patterns like setting a directory variable
  early and referencing it in later pragmas. If isolation between operations
  is preferred, the `Preprocessor` class can be modified to create a fresh
  interpreter for each pragma or function call. Scripts that need cleanup
  within the shared model can use `unset -nocomplain` or `try`/`finally`
  blocks to manage state explicitly.

---

## PowerShell Integration (Eagle/Management)

The PowerShell integration provides a set of cmdlets that allow Eagle
expressions, scripts, and files to be evaluated directly from the PowerShell
command line or scripts. It includes a policy engine for controlling command
execution and a meta-command that bridges Eagle scripts back into the
PowerShell pipeline.

### Architecture

The integration is structured as a PSSnapIn (PowerShell snap-in):

- **`Default`** (`Eagle._SnapIns.Default`) is the PSSnapIn registration class,
  marked with `[RunInstaller(true)]`. It registers the snap-in under the name
  `"EagleCmdlets"`.

- **`Script`** (`Eagle._Cmdlets.Script`) is the abstract base class (~1,900
  lines) that inherits from `System.Management.Automation.Cmdlet` and
  implements `IDisposable`. It defines all parameters, manages the interpreter
  lifecycle, and provides the five engine helper methods.

- **Five sealed cmdlet classes** each override `ProcessRecord` to call one
  specific engine helper.

- **`Cmdlet`** (`Eagle._Commands.Cmdlet`, ~700 lines) is the internal
  meta-command that can optionally be injected into the interpreter to bridge
  Eagle scripts back into PowerShell.

Default interpreter creation flags:

- `CreateFlags.SafeEmbeddedUse`
- `HostCreateFlags.SafeEmbeddedUse`

Note the use of **Safe** embedded flags (unlike MSBuild and WiX which use
plain `EmbeddedUse`), restricting available commands by default.

### Installation

The snap-in is installed using the `EagleCmdlets.ps1` script:

```powershell
# Install the snap-in and add it to the current session
.\EagleCmdlets.ps1 install

# Uninstall the snap-in
.\EagleCmdlets.ps1 uninstall
```

The script:
1. Detects the .NET Framework version and platform (x86/x64).
2. Locates `InstallUtil.exe` in the appropriate framework directory.
3. Runs `InstallUtil /LogFile= EagleCmdlets.dll` to register the snap-in.
4. On successful installation, runs `Add-PSSnapin EagleCmdlets` to load the
   snap-in into the current session.

### Cmdlet Reference

The integration provides five cmdlets (plus one internal meta-command). Each
cmdlet has two possible verb names depending on compile-time configuration:

| Default Name | APPROVED_VERBS Name | Operation |
|-------------|---------------------|-----------|
| `Evaluate-EagleExpression` | `Invoke-EagleExpression` | Evaluate an expression |
| `Evaluate-EagleScript` | `Invoke-EagleScript` | Evaluate a script |
| `Evaluate-EagleScriptFile` | `Invoke-EagleScriptFile` | Evaluate a script file |
| `Substitute-EagleText` | `Resolve-EagleText` | Substitute a string |
| `Substitute-EagleTextFile` | `Resolve-EagleTextFile` | Substitute a file |

All cmdlets declare `SupportsShouldProcess = true`.

### Parameters

All cmdlets share the same parameter set, defined in the `Script` base class.
The `Text` parameter (position 0) is mandatory and accepts pipeline input.
All other parameters accept pipeline input by property name.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Text` | `string` | The string, expression, script, or file name to process (required) |
| `-Args` | `string` | Command-line arguments for the interpreter |
| `-PreInitialize` | `string` | Script to evaluate during interpreter creation |
| `-CreateFlags` | `CreateFlags` | Flags for interpreter creation (default: `SafeEmbeddedUse`) |
| `-HostCreateFlags` | `HostCreateFlags` | Flags for interpreter host creation (default: `SafeEmbeddedUse`) |
| `-InitializeFlags` | `InitializeFlags` | Flags for interpreter initialization (default: `Default`) |
| `-ScriptFlags` | `ScriptFlags` | Flags for script library behavior (default: `Default`) |
| `-InterpreterFlags` | `InterpreterFlags` | Flags for interpreter behavior (default: `Default`) |
| `-EngineFlags` | `EngineFlags` | Flags for engine behavior (default: `None`) |
| `-SubstitutionFlags` | `SubstitutionFlags` | Flags for substitution behavior (default: `Default`) |
| `-EventFlags` | `EventFlags` | Flags for event handling (default: `Default`) |
| `-ExpressionFlags` | `ExpressionFlags` | Flags for expression evaluation (default: `Default`) |
| `-Console` | `SwitchParameter` | Allow console messages |
| `-Unsafe` | `SwitchParameter` | Allow unsafe commands |
| `-Standard` | `SwitchParameter` | Allow only standard commands |
| `-Force` | `SwitchParameter` | Skip confirmation prompts |
| `-Exceptions` | `SwitchParameter` | Allow non-Ok return codes as success |
| `-Policies` | `SwitchParameter` | Use the cmdlet command execution policies |
| `-Deny` | `SwitchParameter` | Deny command execution by default |
| `-MetaCommand` | `SwitchParameter` | Add the `[cmdlet]` meta-command to the interpreter |

The `-Text` parameter accepts several aliases: `-Expression`, `-String`,
`-Script`, `-File`, `-FileName`.

### The \[cmdlet\] Meta-Command

When the `-MetaCommand` switch is enabled, the `[cmdlet]` command is added to
the interpreter. This command bridges Eagle scripts back into the PowerShell
pipeline, providing 9 sub-commands:

| Sub-Command | Arguments | Description |
|-------------|-----------|-------------|
| `about` | (none) | Returns plugin about information |
| `debug` | `text` | Calls `WriteDebug` on the PowerShell cmdlet |
| `error` | `code result` | Writes an error record to the PowerShell error stream |
| `invoke` | `?options? script` | Invokes a PowerShell pipeline command |
| `options` | (none) | Returns compile-time define constants or plugin options |
| `progress` | `?options? activityId activity statusDescription` | Writes a progress record |
| `remove` | (none) | Removes the meta-command from the interpreter |
| `status` | (none) | Returns cmdlet object status and properties |
| `verbose` | `text` | Calls `WriteVerbose` on the PowerShell cmdlet |

The `invoke` sub-command supports the `-addToHistory` option. The `progress`
sub-command supports `-currentOperation`, `-parentActivityId`,
`-percentComplete`, `-recordType`, and `-secondsRemaining` options.

### Policy Engine

The `-Policies` switch enables command execution policies within the Eagle
interpreter. When active:

- Each command execution is subject to a policy callback
  (`_Policies._Cmdlet.PolicyCallback`).
- The callback uses `ShouldProcess` and `ShouldContinue` for user
  confirmation.
- The `-Deny` switch inverts the default policy: approved commands are denied
  instead of allowed.
- The `-Force` switch suppresses confirmation prompts.

Policy descriptions shown to the user:
- Process caption: `"Eagle Cmdlet Policy"`
- Continue caption: `"Eagle Cmdlet Policy (Confirm)"`
- Verbose description: `"Executing command: {0}"`
- Unsafe warning: `"Detected use of the command name \"{0}\", marked as
  'unsafe', allow anyway?"`

### Interpreter Lifecycle

Each cmdlet invocation creates a **new interpreter** (full isolation):

- **`BeginProcessing`**: Creates the interpreter with the configured flags,
  sets up policies (if `-Policies` is enabled), evaluates the pre-initialization
  script (if `-PreInitialize` is specified), and adds the meta-command (if
  `-MetaCommand` is enabled).

- **`ProcessRecord`**: Calls the appropriate engine method with the `Text`
  parameter.

- **`EndProcessing`**: Disposes the interpreter and resets policy data.

- **`StopProcessing`**: Cancels any in-progress evaluation and disposes the
  interpreter (called when the pipeline is stopped).

### Verb Naming

The cmdlet verb names are controlled by a compile-time flag:

- **Default** (without `APPROVED_VERBS`): Uses `Evaluate` and `Substitute`
  verbs, which are compatible with Tcl terminology but are not on the
  PowerShell approved verb list.

- **With `APPROVED_VERBS` defined**: Uses `Invoke` and `Resolve` verbs, which
  are on the PowerShell approved verb list.

This choice is fixed at build time and cannot be changed at runtime.

### Examples

**Simple expression evaluation:**

```powershell
Evaluate-EagleExpression "2 + 2"
```

**Script evaluation with -Args:**

```powershell
Evaluate-EagleScript -Args "one two" -Text "return [llength $argv]"
```

**Using -MetaCommand with [cmdlet invoke]:**

```powershell
Evaluate-EagleScript -MetaCommand -Text "cmdlet invoke Get-Date"
```

The `[cmdlet invoke]` sub-command executes a PowerShell pipeline command from
within an Eagle script and returns the result.

**Using -Policies and -Force:**

```powershell
Evaluate-EagleScript -Policies -Force -Text "return hello"
```

Enables the policy engine but suppresses confirmation prompts with `-Force`.

### Known Limitations

- **PSSnapIn is legacy**: The integration uses the PSSnapIn registration
  mechanism, which is supported only in Windows PowerShell (versions up to
  5.1). It is **not compatible** with PowerShell Core (6.0+) or PowerShell 7+.

- **New interpreter per invocation** (design choice): Each cmdlet call creates
  and disposes a fresh interpreter, providing full isolation. This is a
  deliberate default -- the `Script` base class can be modified to cache and
  reuse an interpreter across invocations if a particular workflow benefits
  from shared state or reduced startup overhead.

- **Safe mode by default**: The default `CreateFlags.SafeEmbeddedUse` restricts
  the set of available commands. Use the `-Unsafe` switch to access the full
  command set, or specify custom `-CreateFlags` to fine-tune behavior.

- **APPROVED_VERBS choice is fixed at build time**: You cannot switch between
  `Evaluate`/`Substitute` and `Invoke`/`Resolve` verb names at runtime. The
  choice must be made when compiling the `EagleCmdlets.dll` assembly.

---

## MonoDevelop Integration (Eagle/MonoDevelop)

### Status: Proof-of-Concept Only

> **WARNING**: This integration is a proof-of-concept only. It is **NOT**
> production ready.

The following warning appears verbatim in all source files:

```
*WARNING* *WARNING* *WARNING* *WARNING* *WARNING* *WARNING* *WARNING*

Please do not use this code, it is a proof-of-concept only.  It is not
production ready.

*WARNING* *WARNING* *WARNING* *WARNING* *WARNING* *WARNING* *WARNING*
```

### Architecture

The MonoDevelop integration is packaged as a MonoDevelop add-in:

- **`addin.xml`** declares the add-in metadata:
  - **ID**: `Eagle`
  - **Namespace**: `MonoDevelop`
  - **Name**: `Eagle Handlers for MonoDevelop`
  - **Category**: `Scripting`
  - **Version**: `1.0`
  - **Dependencies**: MonoDevelop Core >= 2.6, MonoDevelop Ide >= 2.6
  - **Runtime assembly**: `Eagle.dll`
  - Commands are registered under the `"Eagle Integration"` category in
    `/MonoDevelop/Ide/Commands` and added to the Edit menu.

- **`Script`** (`Eagle._Handlers.Script`) is an `internal` base class (~600
  lines) that inherits from `MonoDevelop.Components.Commands.CommandHandler`
  and implements `IDisposable`. It manages the shared interpreter and provides
  the five engine helper methods.

- **Five sealed handler classes** each override the `Run` and `Update` methods
  from `CommandHandler`:

  | Class | Menu Label | Input Source | Result Mode |
  |-------|-----------|-------------|-------------|
  | `EvaluateExpression` | Evaluate Eagle Expression | Selected text | Replace or Document |
  | `EvaluateScript` | Evaluate Eagle Script | Selected text | Replace or Document |
  | `EvaluateFile` | Evaluate Eagle File | Active document path | Document |
  | `SubstituteString` | Substitute Eagle String | Selected text | Replace or Document |
  | `SubstituteFile` | Substitute Eagle File | Active document path | Document |

Default interpreter creation flags:

- `CreateFlags.EmbeddedUse`
- `HostCreateFlags.EmbeddedUse`

### Command Reference

All five commands appear in the MonoDevelop Edit menu under the
`"Eagle Integration"` category:

| Command | Description | Enabled When |
|---------|-------------|-------------|
| Evaluate Eagle Expression | Evaluates the selected text as an Eagle expression | Text is selected |
| Evaluate Eagle Script | Evaluates the selected text as an Eagle script | Text is selected |
| Evaluate Eagle File | Evaluates the active document as an Eagle script file | Document is open |
| Substitute Eagle String | Performs substitutions on the selected text | Text is selected |
| Substitute Eagle File | Performs substitutions on the active document file | Document is open |

The `Update` method on each handler enables or disables the command based on
whether the required input (selected text or open document) is available.

### Interpreter Lifecycle

The MonoDevelop integration uses a **single shared interpreter** for the
lifetime of the add-in:

- The interpreter is created once in the `Initialize` method of the base
  `Script` class, using `Interpreter.Create` with the configured creation
  flags.
- The same interpreter instance is used for all subsequent command invocations.
- The interpreter is disposed when the handler is disposed.

Because the interpreter persists, **state accumulates across invocations**.
Variables set by one evaluation are visible to later evaluations. This is
by design for interactive use but can lead to unexpected side effects.

### Result Handling

Results are presented in one of two modes:

- **Replace mode** (default for text-based operations): The selected text in
  the active editor buffer is replaced with the formatted result. The
  replacement is performed inside an atomic undo block, so it can be reverted
  with a single undo.

- **Document mode** (used by file-based operations and as an alternative for
  text-based operations): A new document tab is opened with the result. The
  document is named `"Eagle {Type} {Result/Error} #{id}"`.

The `EvaluateFile` and `SubstituteFile` commands always use document mode
because they operate on the entire file, not on a text selection.

### Configuration

The MonoDevelop integration has no cmdlet-style parameters. Configuration is
limited to environment variables:

| Environment Variable | Effect |
|---------------------|--------|
| `Eagle_Console` | Enables console output when set |
| `Eagle_NoConsole` | Disables console output when set |

The `NeedConsole` method checks these environment variables to determine
whether console output should be enabled.

### Limitations

- **Not production ready**: The integration is explicitly marked as a
  proof-of-concept. Do not use it for production work.
- **No syntax highlighting, debugging, or code completion**: The add-in
  provides only evaluation and substitution commands. There is no Eagle
  language support integrated into the IDE editor.
- **Single shared interpreter** (design choice): State persists across
  invocations -- variables and side effects from one command are visible to
  subsequent commands. This is convenient for interactive exploration but may
  cause surprises. The `Script` base class can be modified to create a fresh
  interpreter per invocation if isolation is preferred.
- **No parameters beyond text input**: Unlike MSBuild and PowerShell, there
  are no flags, creation options, or policy controls. The only input is the
  selected text or active document.
- **MonoDevelop 2.6+ required**: The add-in requires MonoDevelop version 2.6
  or higher. MonoDevelop is largely unmaintained as a standalone IDE (its
  successor is Visual Studio for Mac, which has itself been discontinued).

---

## Cross-Integration Comparison

### Feature Matrix

| Feature | MSBuild | WiX | PowerShell | MonoDevelop |
|---------|---------|-----|------------|-------------|
| Host Environment | MSBuild build engine | WiX Toolset preprocessor | PowerShell shell | MonoDevelop IDE |
| Production Status | Production | Production | Production | Proof-of-concept |
| Configurable Parameters | 12 input + 2 output | N/A (host-driven) | 20+ input | None |
| Interpreter Lifecycle | New per task | Shared per compilation | New per cmdlet | Shared per add-in lifetime |
| Bridge Object | `__task` (BuildEngine) | N/A | `[cmdlet]` meta-command | N/A |
| Policy Engine | No | No | Yes (`-Policies`) | No |
| Pragma/Macro Support | N/A | Yes (WiX 3.5+) | N/A | N/A |
| Default CreateFlags | `EmbeddedUse` | `EmbeddedUse` | `SafeEmbeddedUse` | `EmbeddedUse` |
| Pipeline/Output Support | MSBuild properties | Raw XML injection | PowerShell pipeline | Text replace / new document |

### Interpreter Lifecycle Comparison

| Integration | Lifecycle | State Sharing | Default Trade-off | Customizable? |
|-------------|-----------|---------------|-------------------|---------------|
| MSBuild | New per task invocation | None between tasks | Clean isolation; startup cost per task | Yes -- `Script` base class can be modified to share |
| WiX | Shared per compilation session | Yes, across all operations | Enables cross-reference; requires state discipline | Yes -- `Preprocessor` can create per-operation interpreters |
| PowerShell | New per cmdlet invocation | None between cmdlets | Clean isolation; startup cost per cmdlet | Yes -- `Script` base class can be modified to cache |
| MonoDevelop | Shared per add-in lifetime | Yes, across all commands | Interactive convenience; state accumulates | Yes -- `Script` base class can create per-invocation interpreters |

### When to Use Which Integration

- **MSBuild**: Use for build-time code generation, validation, file-version
  queries, and other tasks that need to run as part of the MSBuild pipeline.
  Best when you need Eagle's string processing, file inspection, or .NET
  interop capabilities during a build.

- **WiX**: Use for injecting build-time values into Windows Installer packages.
  Best for dynamic property generation, build numbers, environment-dependent
  configuration, and conditional XML fragment generation during installer
  compilation.

- **PowerShell**: Use for interactive or scripted Eagle evaluation from the
  command line. Best for ad-hoc scripting, automation pipelines, and scenarios
  where you want to combine Eagle's capabilities with PowerShell's ecosystem.

- **MonoDevelop**: Use for experimentation and proof-of-concept only. The
  add-in can evaluate expressions and scripts interactively within the IDE,
  but it lacks the polish and features needed for production use.
