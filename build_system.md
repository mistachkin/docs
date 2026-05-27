# Eagle Build System (POSIX) — Reference

*Building, testing, and installing Eagle on Linux and macOS with the official
POSIX `Makefile`, plus the native (Garuda/Spilornis) build and the build-time
MSBuild task library.*

This document describes how to build Eagle from source on POSIX platforms. For
Windows builds, see the `quick_start_guide.md` (Visual Studio and `build.bat`);
this guide focuses on the `make`-driven workflow rooted at the repository's
`Makefile`.

## 1. Overview

Eagle ships an official POSIX `Makefile` (declared `.POSIX:`) that wraps the
.NET SDK (`dotnet`) for the managed assemblies and a pair of shell scripts for
the optional native libraries. The same `Makefile` also installs and uninstalls
a complete runtime tree under a configurable prefix.

| Layer | Built by | Output |
|-------|----------|--------|
| Managed core + shell | `dotnet build` on a solution file | `Eagle.dll`, `EagleShell.dll`, `EagleShell.runtimeconfig.json` |
| Native bridge/utility | `compile-debug.sh` / `compile-release.sh` (C compiler) | `libGarudaCore`, `libSpilornis` |
| Build-time tooling | `EagleTasks.dll` (MSBuild tasks) | version stamping, code generation, file substitution |

> [!NOTE]
> The managed build is the only part required to obtain a working Eagle
> interpreter and shell. The native libraries are **optional** and are skipped
> unless `DOTNET_SDK_VERSION` is set (see [§6](#6-native-build-garuda-and-spilornis)).

The quickest path from a fresh checkout to a running shell:

```sh
cd Eagle
make build      # restore + build the managed assemblies
make test       # run the full test suite (Library/Tests/all.eagle)
make run        # start the interactive shell
```

`make help` prints the list of fully supported targets at any time.

## 2. Prerequisites

- A recent **.NET SDK** providing the `dotnet` CLI. The projects target
  `netcoreapp3.0` but are launched with `--roll-forward Major`, so they run on
  .NET 5+ runtimes.
- **Git** — only required for the `fetch*` targets (cloning the docs and extra
  repositories); not needed for a plain build.
- For the optional native build: a **C compiler** (`gcc`/`clang`), **Tcl 8.6**
  development files and stub library (`libtclstub8.6`), `tclsh`, and the
  `DOTNET_SDK_VERSION` environment variable set to the installed SDK version so
  the scripts can locate the `hostfxr`/`nethost` headers in the .NET host pack.

> [!IMPORTANT]
> `DOTNET_SDK_VERSION` is intentionally **not** set in the `Makefile`. Set it in
> your environment or pass it on the command line (for example
> `make build DOTNET_SDK_VERSION=10.0.7`). Without it, `build-native` prints a
> "Skipping build-native" message and exits successfully — the managed build is
> unaffected.

## 3. Targets

Targets are grouped below as they appear in the `Makefile`. The default target
is `all`, which is an alias for `build`.

### 3.1 Validation

| Target | Purpose |
|--------|---------|
| `validate-dotnet` | Fails the build unless `dotnet --info` works. Prerequisite of every build/clean/run target. |
| `validate-git` | Fails unless `git --version` works. Prerequisite of the `fetch*` targets. |
| `validate-dirs` | Requires `PREFIX` to be a non-empty absolute path and `DESTDIR` to be empty or absolute. Prerequisite of every install/uninstall/fetch target. |

### 3.2 Build

| Target | Purpose |
|--------|---------|
| `build` | Build everything: `build-native` then `build-managed`. |
| `all` | Default target; alias for `build`. |
| `build-managed` | Build the managed assemblies only (see [§4](#4-the-managed-build)). |
| `build-native` | Build the native libraries only; skipped unless `DOTNET_SDK_VERSION` is set (see [§6](#6-native-build-garuda-and-spilornis)). |
| `rebuild` | Force a clean rebuild of everything (`rebuild-native` then `rebuild-managed`). |
| `rebuild-managed` | `dotnet build /target:Rebuild` of the managed assemblies. |
| `rebuild-native` | `force-clean` followed by `build-native`. |
| `fresh` | `force-clean` followed by `build`. |
| `restore` | Restore NuGet packages for the active solution. |
| `add-sds-pkg` | Inject the `System.Data.SQLite.Core` package reference into the shell project and restore it (run automatically by the managed build). |

### 3.3 Clean

| Target | Purpose |
|--------|---------|
| `clean` | Clean through the .NET build system (`dotnet build /target:Clean`). |
| `force-clean` | Forcibly remove `bin/`, `obj/`, and other output directories, and `fossil revert` the generated native version headers (`pkgVersion.h`, `rcVersion.h`). |
| `dist-clean` / `distclean` | Aliases for `force-clean`. |

### 3.4 Run and test

| Target | Purpose |
|--------|---------|
| `run` | Launch the interactive shell: `dotnet exec --roll-forward Major EagleShell.dll -anyFile Makefile.eagle`. |
| `shell` | Alias for `run`. |
| `test` | Run the suite: the `run` invocation plus `-file Library/Tests/all.eagle $(TEST_ARGS)`. |
| `check` | Alias for `test`. |

> [!TIP]
> Pass extra arguments to the test driver with `TEST_ARGS`, for example
> `make test TEST_ARGS="-file basic.eagle"`. The `-anyFile Makefile.eagle`
> argument loads the init-pipeline helper described in [§5](#5-makefileeagle-and-eaglesh).

### 3.5 Install and uninstall

| Target | Purpose |
|--------|---------|
| `install` | `build`, then install binaries, libraries, and tests under `$(DESTDIR)$(PREFIX)`. |
| `install-bin` | Install `EagleShell.runtimeconfig.json`, `EagleShell.dll`, `Eagle.dll` (mode 644) and `eagle.sh` (mode 755) into `bin/`. |
| `install-lib` | Install the `Eagle1.0` and `Test1.0` script libraries into `lib/`. |
| `install-tests` | Install `Library/Tests` into `Tests/` (omitting `Default.cs`). |
| `install-dirs` / `installdirs` | Create the `bin`, `lib/Eagle1.0`, `lib/Test1.0`, and `Tests` directories. |
| `install-all-dirs` | `install-dirs` plus the `docs` and `lib/Extra1.0` directories. |
| `install-all` | `fetch` (clone docs + extras) then `install`. |
| `uninstall` | Remove installed binaries, libraries, and tests, then `rmdir` the prefix if empty. |
| `uninstall-bin` / `uninstall-lib` / `uninstall-tests` | Remove the corresponding installed components. |
| `uninstall-all` | `unfetch` then `uninstall`. |

A typical staged install (for packaging) uses both `DESTDIR` and `PREFIX`:

```sh
make install DESTDIR=/tmp/stage PREFIX=/opt/eagle
```

### 3.6 Fetch (remote docs and extras)

| Target | Purpose |
|--------|---------|
| `fetch` | `git clone` the docs and extra repositories into the prefix. |
| `fetch-docs` | Clone `$(GIT_DOCS_URI)` into `$(DESTDIR)$(PREFIX)/docs/`. |
| `fetch-extra` | Clone `$(GIT_EXTRA_URI)` into `$(DESTDIR)$(PREFIX)/lib/Extra1.0`. |
| `unfetch` / `unfetch-docs` / `unfetch-extra` | Remove the corresponding cloned trees. |

> [!WARNING]
> The `fetch*` targets `git clone` into directories under the prefix, so those
> directories must **not** already exist. Running `install-all-dirs` (which
> pre-creates `docs` and `lib/Extra1.0`) before a `fetch` will cause the clone
> to fail — this trade-off is noted directly in the `Makefile`.

## 4. The managed build

`build-managed` runs `dotnet build /target:Build` against the first solution
that succeeds, trying the Enterprise edition first and falling back to the open
source edition:

1. `EagleEnterpriseNetStandard2X.sln` (`BUILD_SOLUTION_1`)
2. `EagleNetStandard2X.sln` (`BUILD_SOLUTION_2`)

It builds the `Debug` configuration (`BUILD_MANAGED_CONFIGURATION`) of build
type `NetStandard21` (`BUILD_TYPE`), passing these MSBuild arguments
(`BUILD_ARGS`):

```text
/maxcpucount:1
/property:EagleBuildType=NetStandard21
/property:EaglePatchLevel=false
```

Output lands in `BUILD_DIRECTORY`:

```text
bin/DebugNetStandard21/bin/netcoreapp3.0/
```

Two post-build copy steps run automatically:

- The SQLite native interop (`SQLite.Interop.dll`) for the current runtime
  identifier (RID) is copied next to the managed assemblies.
- Everything in `Library/Configurations/` is copied into the output directory.

The key produced files are `Eagle.dll` (the core library), `EagleShell.dll`
(the shell entry point), and `EagleShell.runtimeconfig.json`.

## 5. `Makefile.eagle` and `eagle.sh`

These two helpers are part of the build/run experience but are not build
targets.

- **`Makefile.eagle`** — an Eagle script loaded via `-anyFile Makefile.eagle`
  whenever `make run` or `make test` starts the shell. It configures the
  interpreter's initialization pipeline (`-preInitialize` / `-initialize` /
  `-postInitialize`), resets trace listeners, detects the GitHub Actions CI
  environment, and disables timing/memory-leak-sensitive tests under CI. See
  `architecture_patterns.md` for the init-pipeline mechanism.
- **`Shell/Tools/eagle.sh`** — the installed launcher (placed in
  `$(PREFIX)/bin`). It locates `EagleShell.dll` (overridable via the
  `EAGLE_DLL` environment variable), exports `InitializeFlags=+Unsupported`, and
  runs `dotnet exec --roll-forward Major EagleShell.dll "$@"`. The `dotnet`
  binary itself can be overridden via the `DOTNET` environment variable.

## 6. Native build (Garuda and Spilornis)

The optional native build produces two shared libraries:

| Library | Source | macOS / Linux name |
|---------|--------|--------------------|
| Garuda (Tcl ↔ Eagle bridge) | `Native/Package` | `libGarudaCore.dylib` / `libGarudaCore.so` |
| Spilornis (native utility) | `Native/Utility` | `libSpilornis.dylib` / `libSpilornis.so` |

`build-native` invokes `Native/Utility/Tools/compile-$(BUILD_NATIVE_CONFIGURATION).sh`
and then `Native/Package/Tools/compile-$(BUILD_NATIVE_CONFIGURATION).sh` (where
`BUILD_NATIVE_CONFIGURATION` is `[debug]` by default), with
`CONFIGURATION_SUFFIX=NetStandard21` exported. Each script:

1. Locates the .NET host pack for the current OS/architecture under the SDK
   identified by `DOTNET_SDK_VERSION`, and detects `hostfxr` capabilities.
2. Runs a `tclsh`-based version-tagging step (`Common/Tools/tagViaBuild.tcl`).
3. Compiles the C sources with `gcc -g -fPIC -shared`, linking against the Tcl
   stub library (`-ltclstub8.6`) and the .NET host (`-lnethost`).
4. Moves the resulting library into the managed `BUILD_DIRECTORY` and copies the
   companion `*.tcl` files alongside it.

On macOS the scripts expect Tcl/Tk from Homebrew (`tcl-tk@8`); on Linux they use
the system Tcl. See `garuda.md` for the architecture and runtime use of the
native package.

> [!NOTE]
> Because the C compiler, Tcl stub library, and a matching `DOTNET_SDK_VERSION`
> must all line up, native builds are environment-sensitive. If `build-native`
> is skipped or fails, the managed Eagle interpreter and shell still build and
> run normally — only the native Tcl-integration features are unavailable.

## 7. Build-time MSBuild tasks (`EagleTasks.dll`)

The `Build/` project (`EagleTasks.csproj`) compiles a small library of custom
MSBuild tasks used during the managed build itself — for example to stamp
version information and substitute values into generated files. They are
declared via `<UsingTask>` in `Targets/Eagle.tasks`
(`AssemblyFile="$(EagleTaskPath)EagleTasks.dll"`) and live in the
`Eagle._Tasks` namespace:

| Task | Role |
|------|------|
| `EvaluateScript` | Evaluate an inline Eagle script at build time. |
| `EvaluateFile` | Evaluate an Eagle script file at build time. |
| `EvaluateExpression` | Evaluate an Eagle expression and return its value. |
| `SubstituteString` | Perform Eagle-based substitution on an inline string. |
| `SubstituteFile` | Perform Eagle-based substitution on a file. |

All five derive from the abstract base `Script` (`Build/Tasks/Script.cs`), which
extends MSBuild's `Task` and implements `IDisposable`; it creates and disposes a
dedicated Eagle interpreter to run the build-time logic. Related MSBuild glue
lives in `Targets/` (`Eagle.targets`, `Eagle.Builds.targets`,
`Eagle.Settings.targets`, and so on).

## 8. Configuration variables

Override any of these on the `make` command line (for example
`make install PREFIX=/usr/local`). Defaults are shown in parentheses.

### 8.1 Installation and fetch

| Variable | Purpose |
|----------|---------|
| `PREFIX` (`/opt/eagle`) | Installation root; must be an absolute path. |
| `DESTDIR` (empty) | Staging prefix prepended to `PREFIX` for packaging; empty or absolute. |
| `GIT` (`git`) | Git executable used by the `fetch*` targets. |
| `GIT_DOCS_URI` | Source repository for the documentation. |
| `GIT_EXTRA_URI` | Source repository for the extra libraries. |

### 8.2 .NET and build

| Variable | Purpose |
|----------|---------|
| `DOTNET_SDK_VERSION` (unset) | SDK version used to locate native host packs; required for `build-native`. |
| `DOTNET` (`dotnet`) | .NET CLI executable. |
| `DOTNET_FRAMEWORK` (`netcoreapp3.0`) | Target framework folder name in the output path. |
| `DOTNET_ARGS` (`--roll-forward Major`) | Arguments to `dotnet exec` for `run`/`test`. |
| `BUILD_MANAGED_CONFIGURATION` (`Debug`) | MSBuild configuration for the managed build. |
| `BUILD_NATIVE_CONFIGURATION` (`[debug]`) | Selects `compile-debug.sh` vs `compile-release.sh`. |
| `BUILD_TYPE` (`NetStandard21`) | Eagle build type; also selects the output subdirectory. |
| `BUILD_SOLUTION_1` / `BUILD_SOLUTION_2` | Primary (Enterprise) and fallback (open source) solution files. |
| `BUILD_DIRECTORY` | Computed output path (`bin/DebugNetStandard21/bin/netcoreapp3.0`). |
| `DOTNET_SDS_PKG_NAME` / `DOTNET_SDS_PKG_VERSION` | SQLite package injected by `add-sds-pkg` (`System.Data.SQLite.Core` `1.0.119.0`). |
| `TEST_ARGS` (empty) | Extra arguments appended to the `test` invocation. |

### 8.3 Tooling and telemetry

`INSTALL`/`INSTALL_BIN` (`install -m 755`)/`INSTALL_DATA` (`install -m 644`),
`MKDIR_P`, `CP`/`CP_R`, `MV`, `SED`, and `CHMOD`/`CHMOD_R`/`CHMOD_PERMS`
(`a+rX,og-w`) name the POSIX utilities used during install. A block of
telemetry-opt-out variables (`DOTNET_NOLOGO`, `DOTNET_CLI_TELEMETRY_OPTOUT`,
`VCPKG_DISABLE_METRICS`, and friends) is exported to every `dotnet` invocation
via `DOTNET_ENV`.

## 9. Windows and IDE builds (non-POSIX)

The POSIX `Makefile` is one of several supported build paths. On Windows, or for
IDE-based development, use:

- **Visual Studio** — open one of the `*.sln` files (for example `Eagle.sln` or
  `EagleNetStandard2X.sln`) and build.
- **`Library/Tools/build.bat`** — the Windows command-line build script.
- **`Installer/` and `Setup/`** — Windows installer (WiX/MSI) sources and custom
  actions; not used by the POSIX build.
- **`MonoDevelop/`** — legacy MonoDevelop IDE integration; not used by the POSIX
  build.

See `quick_start_guide.md` for the Windows and cross-platform `dotnet build`
quick start.

## 10. Source files

| Path | Role |
|------|------|
| `Makefile` | The POSIX build/install entry point described here. |
| `Makefile.eagle` | Init-pipeline helper loaded by `run`/`test`. |
| `Shell/Tools/eagle.sh` | Installed shell launcher. |
| `Native/Package/Tools/compile-*.sh` | Garuda native build scripts. |
| `Native/Utility/Tools/compile-*.sh` | Spilornis native build scripts. |
| `Build/EagleTasks.csproj`, `Build/Tasks/*.cs` | Build-time MSBuild task library. |
| `Targets/Eagle.tasks`, `Targets/Eagle.targets` | MSBuild task declarations and glue. |
| `Library/Tests/all.eagle` | Entry point for the test suite run by `make test`. |
