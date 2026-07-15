# HotKey Plugin Command Catalog

> **For AI agents**: This document catalogs all script commands provided by the HotKey plugin (Eagle Enterprise Edition). The HotKey plugin provides system-wide (global) hot-key registration that runs Eagle scripts on activation, plus a WinForms-based management/editor/viewer user interface and a set of dialog helpers, for the Eagle script engine. Use the [Command Summary](#command-summary) for a quick overview. The single `hotkey` ensemble command has an anchor `#cmd-hotkey` for direct linking. The plugin is GUI- and native-code-based; the command is marked **(Unsafe)** and requires an unsafe execution context (only the `add` sub-command is permitted in a safe interpreter).

## Table of Contents

- [Overview](#overview)
- [Command Summary](#command-summary)
- [Commands](#commands)
  - [`hotkey`](#cmd-hotkey) — Global hot-keys, management UI, and dialogs (53 sub-commands)
    - [Plugin and Diagnostics](#cat-plugin)
    - [Manager Thread and Lifecycle](#cat-lifecycle)
    - [Hot-Key Definition (CRUD)](#cat-crud)
    - [Registration and Persistence](#cat-persist)
    - [Activation, Results, and Hooks](#cat-activation)
    - [Editors and Viewers](#cat-editors)
    - [Form Utilities](#cat-forms)
    - [Logging](#cat-logging)
    - [Dialogs](#cat-dialogs)
- [Plugin Variant](#plugin-variant)
- [Safe Interpreter Policy](#safe-policy)
- [Conditional Compilation](#conditional-compilation)

---

## Overview

The **HotKey** plugin is the Eagle Enterprise Edition global hot-key and graphical management subsystem. Like all Eagle Enterprise Edition plugins, it requires a valid license certificate by default, but is now also open source. It provides:

- **Global hot-keys** — System-wide keyboard shortcuts (modifier + virtual-key combinations) registered with the operating system; when activated, each hot-key evaluates an associated Eagle script
- **Hot-key manager** — A dedicated WinForms message-loop thread that owns the hidden window receiving hot-key messages, tracks all defined hot-keys, and dispatches their scripts
- **Management UI** — Editor, viewer, and key-selection forms for creating, editing, and inspecting hot-keys, with optional Scintilla-based script editing
- **Dialog helpers** — Script-callable message boxes, yes/no/cancel prompts, busy indicators, and file/directory/list/key selection dialogs
- **Persistence and templates** — Save/load of hot-key definitions, auto-loading of hot-key files, and template scripts for new hot-keys
- **License certificate integration** — Optional license verification during plugin initialization (when compiled with `LICENSING`)

### Architecture

The HotKey plugin provides a single ensemble command (`hotkey`) with 53 sub-commands. The command class inherits from `Eagle._Commands.Default` and is marked with `CommandFlags.NativeCode | CommandFlags.Unsafe` and the `nativeEnvironment` object group. Sub-commands are dispatched via `Utility.TryExecuteSubCommandFromEnsemble`, subject to the command's policy (see [Safe Interpreter Policy](#safe-policy)).

The plugin requires an interpreter that supports Eagle threading. During initialization it starts a dedicated **hot-key manager** thread (a WinForms message loop owning the hidden hot-key window), registers the hot-key template packages, sets up the shared complaint form, and evaluates the hot-key startup script. Most sub-commands operate against the manager obtained from `Shell.Form.GetHotKeyManager()`; if the manager is not available they fail with "invalid hot-key manager".

### Key Concepts

**Hot-key:** A hot-key (the `IHotKey` interface) couples a key combination (modifiers plus a virtual key, expressed via the `System.Windows.Forms.Keys` flags), descriptive text, hit/registration state, and an Eagle script that runs on activation. Each hot-key has an integer **id** assigned by the manager; most sub-commands accept that id (or a value resolvable to one) to address a specific hot-key.

**Manager and forms:** The hot-key manager (the `IHotKeyManager` interface) owns the hidden hot-key window and the collection of hot-keys, and provides the count/list/find/get/set/add/remove/load/save operations. The editor (`HotKeyEditForm`), viewer (`HotKeyViewForm`), key selector (`SelectHotKeyForm`), and the various dialogs are WinForms forms shown on the manager thread; each is assigned a transient **form id** from `FormId`.

**Activation result:** When a hot-key's script runs, its return code, result, and error information are captured on the hot-key. `hotkey evaluate` runs the script on demand, and `hotkey result` retrieves the most recent captured result.

---

## Command Summary

| Command | Type | Sub-commands | Command Flags | Description |
|---------|------|-------------|---------------|-------------|
| [`hotkey`](#cmd-hotkey) | Ensemble | 53 | NativeCode, Unsafe | Global hot-keys, management UI, and dialogs |

---

## Commands

---

<a id="cmd-hotkey"></a>
### `hotkey` — Global Hot-Keys, Management UI, and Dialogs

```
hotkey option ?arg ...?
```

The single HotKey command is an ensemble with 53 sub-commands for defining and registering global hot-keys, managing the hot-key manager thread, showing editor/viewer/dialog forms, and logging. All sub-commands are dispatched via `Utility.TryExecuteSubCommandFromEnsemble`.

**Command flags:** `CommandFlags.NativeCode | CommandFlags.Unsafe`

**Object group:** `nativeEnvironment`

Many sub-commands accept an *id* argument that identifies a hot-key. Unless noted otherwise, *id* is any value resolvable to a hot-key id by the manager. Sub-commands that require the manager fail with "invalid hot-key manager" when it is unavailable.

#### Sub-commands

---

<a id="cat-plugin"></a>
#### Plugin and Diagnostics

- **about** — `hotkey about`
  - Returns the plugin "about" information (formatted plugin details plus, when `LICENSING` is enabled, license certificate details). Delegates to the plugin's `About` method.
  - **Returns:** Plugin about string.

- **certificate** — `hotkey certificate`
  - Returns the file name of the plugin's configured license certificate file.
  - **Requires:** `LICENSING`
  - **Returns:** Certificate file path, or an error when none is configured.

- **options** — `hotkey options`
  - Returns the compile-time options (preprocessor defines) that were active when the plugin assembly was built.
  - **Returns:** A list of compile option strings.

- **isolated** — `hotkey isolated`
  - Reports whether the plugin is running in a different application domain than the interpreter (cross-AppDomain isolation).
  - **Returns:** Boolean.

- **status** — `hotkey status`
  - Returns a short status summary for the plugin / hot-key subsystem.
  - **Returns:** Status string.

- **ready** — `hotkey ready`
  - Reports whether the hot-key manager has been started and is available (`Shell.Form.HaveHotKeyManager()`).
  - **Returns:** Boolean.

- **resource** — `hotkey resource name`
  - Retrieves the named embedded resource string from the plugin assembly via the plugin's `GetString` method.
  - **Returns:** The resource string; error if not found.

---

<a id="cat-lifecycle"></a>
#### Manager Thread and Lifecycle

- **startup** — `hotkey startup`
  - Ensures the hot-key manager thread is started (evaluates the hot-key startup sequence).
  - **Returns:** Result of the startup operation.

- **shutdown** — `hotkey shutdown`
  - Stops the dedicated hot-key manager thread (`Shell.Form.StopHotKeyManagerThread`).
  - **Returns:** Result of the shutdown operation.

- **lock** — `hotkey lock`
  - Locks the hot-key manager window so it can no longer be modified. **One-way only** — there is no corresponding unlock.
  - **Returns:** Result of the lock operation.

- **title** — `hotkey title ?text?`
  - Gets or sets the title of the hot-key manager form. With *text*, sets the title; otherwise returns the current title.
  - **Returns:** Current or new title.

- **directory** — `hotkey directory`
  - Returns the hot-key manager's working directory (`ManagerOps.GetDirectory()`).
  - **Returns:** Directory path.

- **root** — `hotkey root ?directory?`
  - Gets or sets the hot-key root directory. Supplying an empty *directory* clears it; when unset, the value defaults to the system Program Files folder.
  - **Returns:** Current or new root directory.

---

<a id="cat-crud"></a>
#### Hot-Key Definition (CRUD)

- **add** — `hotkey add keys flags text`
  - Adds a new hot-key for the given *keys* (a `Keys` flags value combining modifiers and a virtual key), `HotKeyFlags` *flags*, and descriptive *text*. This is the only sub-command permitted in a safe interpreter (see [Safe Interpreter Policy](#safe-policy)).
  - **Returns:** The new hot-key id.

- **get** — `hotkey get id ?full?`
  - Returns the definition of the hot-key identified by *id* as a list. The optional *full* boolean selects the full (all-fields) representation.
  - **Returns:** Hot-key field list.

- **set** — `hotkey set id hotKey`
  - Replaces the definition of the hot-key identified by *id* with the one parsed from *hotKey*.
  - **Returns:** The new hot-key definition list.

- **remove** — `hotkey remove id`
  - Removes the hot-key identified by *id* from the manager.
  - **Returns:** Result of the removal.

- **list** — `hotkey list`
  - Returns the ids of all defined hot-keys.
  - **Returns:** List of hot-key ids.

- **find** — `hotkey find ?options?`
  - Finds hot-key ids matching the supplied criteria.
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-keys` | Match by key combination (`Keys`). |
    | `-flags` | Match by `HotKeyFlags`. |
    | `-registered` | Match by registration state (boolean). |
    | `-exact` | Require an exact (rather than partial) match. |
    | `-all` | Return all matches rather than the first. |
  - **Returns:** List of matching hot-key ids.

- **count** — `hotkey count ?registered?`
  - Counts hot-keys. The optional *registered* boolean restricts the count to currently registered hot-keys.
  - **Returns:** The count (integer).

- **clear** — `hotkey clear ?unregisterOnly? ?force?`
  - Clears hot-keys. With *unregisterOnly*, only unregisters them (keeping the definitions); *force* clears even when normally disallowed.
  - **Returns:** Result of the clear operation.

---

<a id="cat-persist"></a>
#### Registration and Persistence

- **register** — `hotkey register id`
  - Registers the hot-key identified by *id* with the operating system so it becomes active.
  - **Returns:** Result of the registration.

- **unregister** — `hotkey unregister id`
  - Unregisters the hot-key identified by *id* so it is no longer active.
  - **Returns:** Result of the unregistration.

- **save** — `hotkey save ?strict?`
  - Serializes the current hot-key definitions to text. The optional *strict* boolean enforces stricter serialization rules.
  - **Returns:** The saved hot-key text.

- **load** — `hotkey load script ?strictCount? ?strictRegister?`
  - Loads hot-key definitions from *script*. *strictCount* requires the expected number of hot-keys; *strictRegister* requires each to register successfully.
  - **Returns:** Empty on success.

- **autoload** — `hotkey autoload`
  - Auto-loads the configured hot-key files into the manager.
  - **Returns:** A name/result dictionary on success; accumulated errors on failure.

---

<a id="cat-activation"></a>
#### Activation, Results, and Hooks

- **evaluate** — `hotkey evaluate id`
  - Evaluates the script associated with the hot-key identified by *id* (as if it had been activated), resetting its prior result first unless its `NoResetResult` flag is set, and returns the script's result and return code.
  - **Returns:** The hot-key script result.

- **result** — `hotkey result id`
  - Returns the most recent captured evaluation result of the hot-key identified by *id*.
  - **Returns:** The captured result (with its return code).

- **onhook** — `hotkey onhook ?options?`
  - Gets or sets the hook script associated with a hook type (`HotKeyHookType`), used to intercept hot-key processing.
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-type` | The hook type (`HotKeyHookType`) to get or set. |
    | `-text` | The hook script text to set. |
    | `-set` | Set (rather than get) the hook script. |
  - **Returns:** The current or new hook script text.

- **previouseventdata** — `hotkey previouseventdata`
  - Returns data describing the previous hot-key event processed by the manager.
  - **Returns:** Previous event data.

- **pendingcancel** — `hotkey pendingcancel`
  - Reports whether a script cancellation is currently pending (`ScriptOps.IsPendingCancel()`).
  - **Returns:** Boolean.

---

<a id="cat-editors"></a>
#### Editors and Viewers

- **edit** — `hotkey edit id ?idVarName? ?advanced? ?template?`
  - Shows the hot-key editor form for the hot-key identified by *id*. Already-registered hot-keys are opened read-only. *advanced* shows advanced fields; *template* edits the hot-key's template; *idVarName* receives the form id. On a non-read-only edit, the modified hot-key is saved back.
  - **Returns:** Result of the edit.

- **view** — `hotkey view ?idVarName? ?advanced?`
  - Shows the hot-key viewer form (a read-only list of all hot-keys). *advanced* shows advanced columns; *idVarName* receives the form id.
  - **Returns:** Result of the view operation.

- **selectkeys** — `hotkey selectkeys ?modifiers? ?virtualKey? ?idVarName?`
  - Shows the key-selection form to capture a single key combination, seeded with the optional *modifiers* and *virtualKey* (`Keys`). *idVarName* receives the form id.
  - **Returns:** A `{keys ... modifiers ... virtualKey ...}` list describing the selection.

- **anykeys** — `hotkey anykeys ?modifiers? ?keyList? ?idVarName?`
  - Like `selectkeys`, but captures an unlimited list of key names rather than a single virtual key.
  - **Returns:** A `{keys ... modifiers ... virtualKey ...}` list describing the selection.

- **script** — `hotkey script ?options? text`
  - Shows the script editor form (Scintilla-based when compiled with `SCINTILLA`) for the given script *text*.
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-varname` | Variable to receive the form id. |
    | `-readonly` | Open the editor read-only. |
    | `-isolated` | Edit/evaluate in an isolated context. |
  - **Returns:** The edited script text (or result of the editor).

- **secret** — `hotkey secret ?options? text`
  - Shows the secret (masked) editor form for the given *text*.
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-varname` | Variable to receive the form id. |
    | `-readonly` | Open the editor read-only. |
    | `-visible` | Show the secret text in clear rather than masked. |
    | `-copy` | Allow copying the value to the clipboard. |
  - **Returns:** The edited secret text (or result of the editor).

- **template** — `hotkey template ?options?`
  - With no template type, returns the template directory; with `-templatetype`, returns the file name for that template type.
  - **Options:**

    | Option | Description |
    |--------|-------------|
    | `-templatetype` | The template type (`HotKeyTemplateType`) whose file name is returned. |
    | `-user` | Use the user (rather than built-in) template location. |
    | `-strict` | Require the template file to exist. |
  - **Returns:** Template file name (with `-templatetype`) or the template directory.

---

<a id="cat-forms"></a>
#### Form Utilities

- **formid** — `hotkey formid`
  - Returns the most recently allocated form id (`FormId.GetPrevious()`).
  - **Returns:** The previous form id (integer).

- **formlist** — `hotkey formlist`
  - Lists the currently open plugin forms, each as a `{Id ... Name ... Text ...}` list.
  - **Returns:** List of form descriptions.

- **formwait** — `hotkey formwait id milliseconds`
  - Waits up to *milliseconds* for the form identified by *id* to be shown.
  - **Returns:** Empty on success; error if the form is not shown within the timeout.

- **click** — `hotkey click formPattern componentName ?rawFormOnly? ?exactOnly? ?asynchronous?`
  - Simulates a click on the control named *componentName* (empty for the form itself) of the form matching *formPattern*. *rawFormOnly* restricts to non-managed forms; *exactOnly* requires an exact name match; *asynchronous* performs the click without waiting.
  - **Returns:** Result of the click.

- **busy** — `hotkey busy ?busy? ?idOrTitle?`
  - With no argument, returns the count of open busy forms. With a true *busy*, shows a busy form (optionally titled *idOrTitle*) and returns its id. With a false *busy*, closes the busy form identified by *idOrTitle* (or all of them).
  - **Returns:** Busy form id, count, or close result.

- **wait** — `hotkey wait milliseconds`
  - Waits the specified number of *milliseconds* (a UI-friendly delay processed on the calling context).
  - **Returns:** Result of the wait.

---

<a id="cat-logging"></a>
#### Logging

- **log** — `hotkey log text`
  - Appends *text* to the hot-key manager's log.
  - **Returns:** Empty on success.

- **logging** — `hotkey logging ?enabled?`
  - Gets or sets whether the hot-key manager is logging.
  - **Returns:** Current or new logging state (boolean).

- **clearlog** — `hotkey clearlog`
  - Clears the hot-key manager's log.
  - **Returns:** Result of the clear operation.

- **copylog** — `hotkey copylog`
  - Copies the hot-key manager's log to the clipboard.
  - **Returns:** Result of the copy operation.

---

<a id="cat-dialogs"></a>
#### Dialogs

- **messagebox** — `hotkey messagebox ?options?`
  - Shows a Windows message box and returns the chosen result.
  - **Options:** `-text`, `-caption`, `-buttons`, `-icon`, `-default`, `-options`, `-help`, `-helpfile`, `-helpnavigator`, `-helpparam` (mirroring the WinForms `MessageBox.Show` parameters).
  - **Returns:** The dialog result (e.g. the chosen button).

- **yesno** — `hotkey yesno ?options? text`
  - Shows a yes/no prompt for *text*. The `-cancel` option adds a Cancel button (yes/no/cancel).
  - **Returns:** The chosen response.

- **selectfile** — `hotkey selectfile ?options?`
  - Shows an open- or save-file dialog.
  - **Options:** `-save` (save rather than open), `-strict`, `-directory`, `-filename`, `-rootfolder`, `-filter`, `-title`.
  - **Returns:** The selected file name.

- **selectdirectory** — `hotkey selectdirectory ?options?`
  - Shows a folder-selection dialog.
  - **Options:** `-strict`, `-directory`, `-rootfolder`, `-description`.
  - **Returns:** The selected directory.

- **selectitem** — `hotkey selectitem ?options? list`
  - Shows a list-selection dialog over the items in *list*.
  - **Options:** `-title`, `-executable`, `-all`, `-multiple`, `-lists`, `-duplicates`, `-item`, `-idvarname`.
  - **Returns:** The selected item(s).

---

## Plugin Variant

The HotKey assembly contains one plugin class:

| Package Name | Class | Description |
|---|---|---|
| `HotKey.Enterprise` | `HotKey.Enterprise` | Primary plugin. Starts and stops the hot-key manager thread, sets up the complaint form and template packages, evaluates the hot-key startup script, and verifies the license certificate. Implements `IStarted`. |

The `Enterprise` class inherits from `Eagle._Plugins.Default` and is marked with the plugin flags `Primary | User | Commercial | Command | NativeCode | MergeCommands | UserInterface | NoFunctions | NoTraces`. Notable behavior:

- **`Initialize()`** — Verifies the license certificate (if `LICENSING`); requires interpreter threading support; starts the hot-key manager thread; adds the hot-key template packages; sets up the complaint form; evaluates the hot-key startup script; then calls `base.Initialize()`.
- **`Terminate()`** — Cleans up the complaint form, stops the hot-key manager thread, and (with an interpreter) calls `base.Terminate()`. Also invoked from `Dispose`.
- **`GetString()`** — Resolves embedded resource strings via `Utility.GetAnyString`.

---

<a id="safe-policy"></a>
## Safe Interpreter Policy

The `hotkey` command carries a sub-command policy (`HotKey.Policies.HotKey.PolicyCallback`, using `Utility.SubCommandPolicy`). In a safe interpreter, only the sub-commands listed in `AllowedSubCommandNames` are permitted; that set contains a single entry:

- **`add`** — adding a hot-key definition.

All other sub-commands (registration, the manager thread, UI forms, dialogs, logging, persistence, etc.) are disallowed under the policy and require an unsafe interpreter.

---

## Conditional Compilation

Some features require specific compile-time flags (these are the symbols actually referenced by the HotKey command, plugin, and policy code):

| Flag | Features Gated |
|------|---------------|
| `WINFORMS` | The WinForms integration the whole plugin is built on (forms, controls, `formlist` handle/name/text lookups, click simulation). |
| `LICENSING` | License certificate verification during `Initialize`, the `certificate` sub-command, certificate fields/accessors, and `About` certificate details. |
| `SCINTILLA` / `SCINTILLA_30` | Scintilla-based source editing in the script/secret editor forms. |
| `OBFUSCATION` | Applies the `[Obfuscation]` renaming attribute to the command, plugin, and policy classes. |
| `NOTIFY` | Notification integration for hot-key events. |
| `NET_STANDARD_21` | Selects the `Index` constant alias on the relevant frameworks. |
| `THROW_ON_DISPOSED` | Enables disposed-object checking in the plugin. |

The plugin additionally requires an interpreter built with Eagle threading support; initialization fails with "interpreter does not support threading" otherwise.
