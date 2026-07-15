# Demo Plugin Command Catalog

> **For AI agents**: This document catalogs all script commands provided by the Demo plugin (Eagle Enterprise Edition; assembly codename **Spizaetus**, a genus of hawk-eagles). The Demo plugin installs a custom interpreter **host** that replays a script as simulated interactive input — typing it back into the interactive loop one character at a time — and exposes a single `demo` ensemble command to drive and configure that playback. Use the [Command Summary](#command-summary) for a quick overview. The single `demo` ensemble command has an anchor `#cmd-demo` for direct linking. The command is marked **(Unsafe)** and, having no sub-command policy, is entirely unavailable in a safe interpreter.

## Table of Contents

- [Overview](#overview)
- [Command Summary](#command-summary)
- [Commands](#commands)
  - [`demo`](#cmd-demo) — Demo host playback control and configuration (19 sub-commands)
    - [Plugin and Diagnostics](#cat-plugin)
    - [Demo Lifecycle](#cat-lifecycle)
    - [Playback Settings](#cat-playback)
    - [Stop and Cancellation Settings](#cat-stop)
    - [Input and Host Behavior](#cat-input)
- [Plugin Variant](#plugin-variant)
- [Safe Interpreter Policy](#safe-policy)
- [Conditional Compilation](#conditional-compilation)

---

## Overview

The **Demo** plugin is the Eagle Enterprise Edition interactive-demonstration subsystem. It is the worked example of a host-swapping plugin: on initialization it replaces the interpreter's console host with a derived **demo host**, then restores the original host on termination. Like all Eagle Enterprise Edition plugins, it requires a valid license certificate by default, but is now also open source. It provides:

- **Scripted playback** — A demo host that reads lines from a supplied script file and "types" each line back into the interactive loop one character at a time, with a configurable inter-character delay, so a demonstration appears to be entered live
- **Playback control** — Start, stop, and shut down playback; query whether playback is currently active
- **Tunable behavior** — Per-character delay, pause/beep between lines, end-of-stream and Control-C handling, optional timeout, and several host-input behavior switches
- **License certificate integration** — Optional license verification during plugin initialization (when compiled with `LICENSING`)

### Architecture

The Demo plugin provides a single ensemble command (`demo`) with 19 sub-commands. The command class inherits from `Eagle._Commands.Default` and is marked with `CommandFlags.Unsafe` and the `managedEnvironment` object group. Sub-commands are dispatched via `Utility.TryExecuteSubCommandFromEnsemble`.

The plugin (`Demo.Enterprise`) requires the interpreter host to be (or derive from) the Eagle `Console` or `Wrapper` host; otherwise it refuses to initialize with an "unsupported host type" error. During initialization it saves the interpreter's current host and swaps in the demo host (`Demo.Hosts.Demo`), creating one if the caller did not supply one via client data. On termination it restores the saved host and disposes the demo host if it created it. Most sub-commands operate against the demo host obtained from the plugin (`IDemoPlugin.DemoHost`); if it is unavailable they fail with "invalid demo host" (or "invalid demo plugin").

### Key Concepts

**Demo host:** The demo host (the `IDemoHost` interface, implemented by `Demo.Hosts.Demo` on top of the Eagle console host) overrides `ReadLine` so that, while a playback script is active, each line is played back as simulated input rather than read from the keyboard. Playback for a line is performed on a queued work item that writes one character at a time, waiting the configured number of milliseconds between characters and stopping early if the stop event is signaled.

**Playback state:** Playback is "active" whenever the host has play input set (`demo active`). Settings such as the per-character delay (`playmilliseconds`), pause/beep behavior, and the stop/timeout values are properties of the demo host; the matching sub-commands get the current value (no argument) or set a new one (with an argument). The defaults come from the plugin's `Defaults` constants.

**Timeout:** An optional timeout (`timeoutmilliseconds`) starts a background thread that shuts down the demo and stops playback after the interval elapses; a value less than zero disables it. `demo startup` refreshes the timeout when it begins playback.

---

## Common patterns

*Test-verified quick start (from `Plugins/Commercial/Enterprise/Demo/Tests/basic.eagle` and `Scripts/`). Demo swaps in a custom **host** on load and restores it on unload; the current host must be the Console or Wrapper host (run under the shell), or `Initialize` fails with `unsupported host type`.*

Load and play a script as simulated interactive input:

```eagle
package require Demo.Enterprise
demo startup -path [file join $path data demo0.eagle]   ;# lines appear at the % prompt and run
demo shutdown                                            ;# restore normal input (always end this way)
```

Presentation mode (pause + beep before each line):

```eagle
demo startup -pause true -beep true -path $fileName
```

Timed / externally-stopped playback:

```eagle
demo startup -path $fileName; demo playmilliseconds 1000
after 2000 [list demo stop]
```

Demo is also the canonical **reference for building a host-swapping plugin**: declare `PluginFlags.Host`, then in `Initialize` validate the current host type and do `savedHost = interpreter.Host; interpreter.Host = demoHost;`, and in `Terminate`/`Dispose` restore it guarded by `ReferenceEquals(current, demoHost)` (dispose only a host you created).

## Command Summary

| Command | Type | Sub-commands | Command Flags | Description |
|---------|------|-------------|---------------|-------------|
| [`demo`](#cmd-demo) | Ensemble | 19 | Unsafe | Demo host playback control and configuration |

---

## Commands

---

<a id="cmd-demo"></a>
### `demo` — Demo Host Playback Control and Configuration

```
demo option ?arg ...?
```

The single Demo command is an ensemble with 19 sub-commands for starting, stopping, and configuring scripted playback through the demo host. All sub-commands are dispatched via `Utility.TryExecuteSubCommandFromEnsemble`.

**Command flags:** `CommandFlags.Unsafe`

**Object group:** `managedEnvironment`

Most sub-commands require the demo host and fail with "invalid demo host" when it is unavailable (or "invalid demo plugin" when the command's plugin is not the demo plugin). The settings sub-commands follow a common get/set shape: invoked with no value argument they return the current value; with a value argument they set it and return the new value.

#### Sub-commands

---

<a id="cat-plugin"></a>
#### Plugin and Diagnostics

- **about** — `demo about`
  - Returns the plugin "about" information (formatted plugin details plus, when `LICENSING` is enabled, license certificate details). Delegates to the plugin's `About` method.
  - **Returns:** Plugin about string.

- **certificate** — `demo certificate`
  - Returns the file name of the plugin's configured license certificate file (via the plugin's `GetCertificateFileName`); meaningful when `LICENSING` is enabled.
  - **Returns:** Certificate file path, or an error when none is configured.

- **options** — `demo options`
  - Returns the compile-time options (preprocessor defines) that were active when the plugin assembly was built.
  - **Returns:** A list of compile option strings.

- **isolated** — `demo isolated`
  - Reports whether the plugin is running in a different application domain than the interpreter (cross-AppDomain isolation).
  - **Returns:** Boolean.

- **active** — `demo active`
  - Reports whether playback is currently active (i.e. the demo host has play input set).
  - **Returns:** Boolean.

---

<a id="cat-lifecycle"></a>
#### Demo Lifecycle

- **startup** — `demo startup ?options?`
  - Begins scripted playback: reads the demo script, initializes the demo host settings from the supplied options, sets the host's play input, and refreshes the timeout. With `-native` (and a native-capable build) it starts the native keyboard-simulation stream instead.
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-path` | The demo script file to play back (default `demo.eagle`). |
    | `-playmilliseconds` | The delay, in milliseconds, between simulated key presses. |
    | `-stopmilliseconds` | The delay, in milliseconds, used when stopping. |
    | `-timeoutmilliseconds` | The demo timeout, in milliseconds (less than zero disables it). |
    | `-pause` | Pause after each line of non-comment input (boolean). |
    | `-beep` | Beep before pausing (boolean). |
    | `-cancel` | Stop playback when the Control-C key is pressed (boolean). |
    | `-endofstream` | Stop playback at the end of the input stream (boolean). |
    | `-basereadline` | Treat calling the base `ReadLine` without active input as a failure (boolean). |
    | `-closed` | Report the host as closed when there is no active play input (boolean). |
    | `-native` | Use the native operating-system keyboard API to simulate input (boolean; requires a `NATIVE && WINDOWS` build, and only implemented under `TEST`). |
  - **Returns:** Empty on success.

- **shutdown** — `demo shutdown ?options?`
  - Shuts down the active demo (closing its play input) and halts playback. With `-exit`, also requests that the interactive loop terminate.
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-stopmilliseconds` | The delay, in milliseconds, used when stopping (defaults to the configured default). |
    | `-native` | Signal/await the native playback events instead of the managed shutdown (boolean; requires a `NATIVE && WINDOWS` build, and only implemented under `TEST`). |
    | `-exit` | Set the interpreter `Exit` property to true after shutting down (boolean). |
  - **Returns:** Empty on success.

- **stop** — `demo stop ?options?`
  - Stops the active playback (signals the stop event and waits for completion).
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-stopmilliseconds` | The maximum number of milliseconds to wait for playback to stop. |
  - **Returns:** Result of the stop operation.

- **reset** — `demo reset`
  - Resets the demo host settings to their zero / disabled state (`CommonOps.ResetDemoSettings`).
  - **Returns:** Empty on success.

---

<a id="cat-playback"></a>
#### Playback Settings

- **playmilliseconds** — `demo playmilliseconds ?milliseconds?`
  - Gets or sets the number of milliseconds to wait between simulated key presses.
  - **Returns:** Current or new value (integer).

- **pause** — `demo pause ?pause?`
  - Gets or sets whether to pause after each line of non-comment input.
  - **Returns:** Current or new value (boolean).

- **beep** — `demo beep ?beep?`
  - Gets or sets whether to beep before pausing.
  - **Returns:** Current or new value (boolean).

- **debuglevel** — `demo debuglevel ?level?`
  - Gets or sets the debugging level for diagnostic trace messages emitted by the demo host.
  - **Returns:** Current or new value (integer).

---

<a id="cat-stop"></a>
#### Stop and Cancellation Settings

- **stopmilliseconds** — `demo stopmilliseconds ?milliseconds?`
  - Gets or sets the number of milliseconds to wait after attempting to stop playback.
  - **Returns:** Current or new value (integer).

- **cancel** — `demo cancel ?cancel?`
  - Gets or sets whether playback stops when the Control-C key is pressed.
  - **Returns:** Current or new value (boolean).

- **endofstream** — `demo endofstream ?endofstream?`
  - Gets or sets whether playback stops at the end of the input stream.
  - **Returns:** Current or new value (boolean).

---

<a id="cat-input"></a>
#### Input and Host Behavior

- **basereadline** — `demo basereadline ?basereadline?`
  - Gets or sets whether calling the base host `ReadLine` method without active input is treated as a failure.
  - **Returns:** Current or new value (boolean).

- **closed** — `demo closed ?closed?`
  - Gets or sets whether the host reports as closed (its `IsOpen` returns false) when there is no active play input.
  - **Returns:** Current or new value (boolean).

- **timeoutmilliseconds** — `demo timeoutmilliseconds ?milliseconds?`
  - Gets or sets the number of milliseconds before the demo times out. A value less than zero disables the timeout; the timeout is (re)started when playback begins.
  - **Returns:** Current or new value (integer).

---

## Plugin Variant

The Demo assembly contains one plugin class:

| Package Name | Class | Description |
|---|---|---|
| `Demo.Enterprise` | `Demo.Enterprise` | Primary plugin. Swaps a demo host into the interpreter (saving and later restoring the original host), provides the `demo` command's plugin operations, and verifies the license certificate. Implements `IDemoPlugin` and `IDisposable`. |

The `Enterprise` class inherits from `Eagle._Plugins.Default` and is marked with the plugin flags `Primary | User | Commercial | Host | NoFunctions | NoPolicies | NoTraces`. Notable behavior:

- **`Initialize()`** — Verifies the license certificate (if `LICENSING`); requires the interpreter host to be (or derive from) the Eagle `Console` or `Wrapper` host; gets or creates the demo host; saves the interpreter's current host and installs the demo host; then calls `base.Initialize()`.
- **`Terminate()`** — Restores the saved host, disposes the demo host if the plugin created it, and calls `base.Terminate()`.
- **`GetString()`** — Resolves embedded resource strings via `Utility.GetAnyString`.
- **`Options()`** — Returns the build-time compile options (`CommonOps.GetDefineConstants`).

The demo host itself (`Demo.Hosts.Demo`) derives from the Eagle console host and implements `IDemoHost`; it requires console support (`CONSOLE`) at compile time.

---

<a id="safe-policy"></a>
## Safe Interpreter Policy

Unlike some Enterprise plugins, the Demo plugin defines **no sub-command policy**. The `demo` command is simply marked `CommandFlags.Unsafe`, so the entire command — every sub-command — is unavailable in a safe interpreter and requires an unsafe execution context.

---

## Conditional Compilation

Some features require specific compile-time flags (these are the symbols actually referenced by the Demo command, plugin, and host code):

| Flag | Features Gated |
|------|---------------|
| `CONSOLE` | Required by the demo host; the host file fails to compile with console support disabled. |
| `LICENSING` | License certificate verification during `Initialize`, the certificate fields/accessors, `About` certificate details, and a meaningful `certificate` sub-command result. |
| `NATIVE && WINDOWS` | The native operating-system keyboard-simulation path for the `-native` option of `startup`/`shutdown`; without it, `-native` is marked unsupported. |
| `TEST` | Together with `NATIVE && WINDOWS`, provides the actual native keyboard-stream / signal-and-wait implementation (otherwise the `-native` path returns "not implemented"). |
| `OBFUSCATION` | Applies the `[Obfuscation]` renaming attribute to the command, plugin, and host classes. |
| `THROW_ON_DISPOSED` | Enables disposed-object checking in the plugin and host. |
| `NET_STANDARD_21` | Selects the `Index` constant alias on the relevant frameworks. |
