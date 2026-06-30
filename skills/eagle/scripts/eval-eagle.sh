#!/bin/sh
#
# eval-eagle.sh -- (POSIX sh)
#
# Run an Eagle script through the official "eagle.sh" wrapper so any assertion in
# this skill can be VERIFIED by execution before it is trusted. Output is cleaned
# (startup banners suppressed, CRLF -> LF, stderr merged) for easy comparison.
#
# Written to POSIX sh for maximum portability (tested with dash). Note: eagle.sh
# itself requires bash, so bash must be installed to actually run Eagle -- this
# wrapper only needs a POSIX shell for its own logic.
#
# Discovery follows the official eagle.sh contract, with no machine-specific
# paths:
#   * The Eagle shell is located via EAGLE_SHELL (the path to eagle.sh); if that
#     is unset, "eagle.sh" is used from PATH.
#   * EagleShell.dll is resolved by eagle.sh itself -- co-located beside it, or
#     via the EAGLE_DLL environment variable. This script just passes the
#     environment through.
#
# Usage:
#   eval-eagle.sh 'puts [expr {2**10}]'        # evaluate a script string
#   eval-eagle.sh -file foo.eagle [args...]    # pass options straight to the shell
#   echo 'puts ok' | eval-eagle.sh -           # read the script from stdin
#
# Environment:
#   EAGLE_SHELL   path to eagle.sh (default: "eagle.sh" on PATH)
#   EAGLE_DLL     path to a built EagleShell.dll (consumed by eagle.sh)
#   DOTNET        dotnet muxer to use (consumed by eagle.sh; default "dotnet")
#   EAGLE_RAW=1   bypass output cleanup (see below)
#
# Output: by default the supported NoStartups=1 environment variable suppresses
# the shell's startup scripts/banners at the source (NoStartups is presence-based
# -- set => disabled regardless of value; to re-enable you must UNSET it), stderr
# is merged into stdout, and CRs are stripped (the shell emits CRLF) -- so you get
# just your script's LF output plus any real error text. Set EAGLE_RAW=1 for the
# unfiltered, separate-stream, CRLF original with startups enabled. The Eagle exit
# code is always preserved (captured directly, since POSIX has no PIPESTATUS).
#
set -u

# Locate the Eagle shell wrapper. Rely on EAGLE_SHELL; fall back to PATH.
eagle_shell="${EAGLE_SHELL:-}"
if [ -z "$eagle_shell" ]; then
    if command -v eagle.sh >/dev/null 2>&1; then
        eagle_shell=$(command -v eagle.sh)
    fi
fi
if [ -z "$eagle_shell" ]; then
    echo "eval-eagle.sh: Eagle shell not found." >&2
    echo "  Set EAGLE_SHELL to the path of eagle.sh, or put eagle.sh on PATH." >&2
    echo "  (eagle.sh resolves EagleShell.dll itself, or via the EAGLE_DLL var.)" >&2
    exit 1
fi

# Invoke directly if executable; otherwise via bash (eagle.sh requires bash).
run_eagle() {
    if [ -f "$eagle_shell" ] && [ ! -x "$eagle_shell" ]; then
        bash "$eagle_shell" "$@"
    else
        "$eagle_shell" "$@"
    fi
}

if [ "$#" -eq 0 ]; then
    echo "usage: eval-eagle.sh <script> | -file <path> | -" >&2
    exit 2
fi

# A leading "-" reads the script from stdin; a leading option (e.g. -file) is
# passed through; otherwise the single argument is an Eagle script to evaluate.
if [ "$1" = "-" ]; then
    s=$(cat)
    set -- -evaluate "$s"
else
    case "$1" in
        -*) : ;;
        *) set -- -evaluate "$1" ;;
    esac
fi

# EAGLE_RAW=1: original experience (startups on, no cleanup).
if [ -n "${EAGLE_RAW:-}" ]; then
    unset NoStartups 2>/dev/null || :
    run_eagle "$@"
    exit $?
fi

# Clean mode: suppress startups at the source, capture output to recover Eagle's
# exit code (POSIX pipelines expose only the last stage's status), strip CRs.
NoStartups=1
export NoStartups

out=$(run_eagle "$@" 2>&1)
rc=$?
if [ -n "$out" ]; then
    printf '%s\n' "$out" | tr -d '\r'
fi
exit "$rc"
