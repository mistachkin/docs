#!/bin/sh
#
# tcl-oracle.sh -- (POSIX sh)
#
# Run a Tcl snippet across whatever native Tcl interpreters are installed, so a
# claim that "Eagle differs from Tcl" can be checked against the real thing.
# Eagle targets Tcl 8.4 compatibility (plus selected 8.5/8.6 features), so the
# 8.4 result is the primary baseline.
#
# Written to POSIX sh for maximum portability (tested with dash); it has no bash
# or external dependencies beyond the Tcl interpreters themselves.
#
# Interpreter discovery is generic and platform-aware (no machine-specific
# paths): environment overrides first, then PATH, then the standard install
# prefixes for the detected OS (macOS Homebrew/MacPorts/framework, Linux,
# *BSD/pkgsrc). Each interpreter found is run once and labelled by its detected
# [info patchlevel].
#
# Usage:
#   tcl-oracle.sh 'puts [string trim " x "]'
#   echo 'puts [lsort -real {3 1 2}]' | tcl-oracle.sh -
#
# Environment overrides (optional):
#   TCLSH84 / TCLSH85 / TCLSH86   explicit interpreter paths to include first
#   TCLSH_ORACLES                 colon-separated list of extra interpreters
#
set -u

if [ "$#" -eq 0 ]; then
    echo "usage: tcl-oracle.sh <tcl-script> | -" >&2
    exit 2
fi
if [ "$1" = "-" ]; then script=$(cat); else script="$1"; fi

# A literal newline, used as the candidate-list separator (POSIX has no $'\n').
nl='
'
cands=""
add() { if [ -n "${1:-}" ]; then cands="${cands}$1${nl}"; fi; }

# 1) explicit overrides
add "${TCLSH84:-}"; add "${TCLSH85:-}"; add "${TCLSH86:-}"
if [ -n "${TCLSH_ORACLES:-}" ]; then
    oldifs=$IFS; IFS=:
    for x in $TCLSH_ORACLES; do add "$x"; done
    IFS=$oldifs
fi

# 2) standard names on PATH (cross-platform; dotted and undotted variants)
for n in tclsh tclsh8.4 tclsh8.5 tclsh8.6 tclsh9.0 tclsh84 tclsh85 tclsh86 tclsh90; do
    add "$(command -v "$n" 2>/dev/null || true)"
done

# 3) platform-standard install prefixes (best practice per OS), globbed below
case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin)
        prefixes="/opt/homebrew/bin /usr/local/bin /opt/local/bin /opt/homebrew/Cellar/tcl-tk*/*/bin /usr/local/Cellar/tcl-tk*/*/bin /usr/bin /System/Library/Frameworks/Tcl.framework/Versions/*/bin /Library/Frameworks/Tcl.framework/Versions/*/bin" ;;
    Linux)
        prefixes="/usr/bin /usr/local/bin /bin /snap/bin /opt/*/bin" ;;
    *BSD|DragonFly)
        prefixes="/usr/local/bin /usr/pkg/bin /usr/bin" ;;
    *)
        prefixes="/usr/local/bin /usr/bin /opt/local/bin" ;;
esac

# Expand prefixes (word-split + pathname expansion); POSIX leaves non-matching
# globs literal, so a [ -e ] test filters them out.
for pre in $prefixes; do
    for f in "$pre"/tclsh*; do
        [ -e "$f" ] || continue
        add "$f"
    done
done

# Run each unique interpreter once. A temp file (read via redirection, not a
# pipe) keeps the loop in the current shell so the dedup state persists.
tmp="${TMPDIR:-/tmp}/tcl-oracle.$$"
trap 'rm -f "$tmp"' EXIT INT TERM
printf '%s' "$cands" > "$tmp"

seen=" "
ran=0
while IFS= read -r bin; do
    [ -n "$bin" ] || continue
    real=$(command -v "$bin" 2>/dev/null || echo "$bin")
    { [ -x "$real" ] || [ -f "$real" ]; } || continue
    #
    # De-duplicate by device:inode (following symlinks) so the same binary
    # reached via different names (tclsh vs tclsh8.6) runs only once.
    #
    key=$(stat -L -f '%d:%i' "$real" 2>/dev/null \
        || stat -L -c '%d:%i' "$real" 2>/dev/null || echo "$real")
    case "$seen" in *" $key "*) continue ;; esac
    seen="$seen$key "
    ver=$(printf 'puts [info patchlevel]\n' | "$real" 2>/dev/null | tr -d '\r')
    [ -n "$ver" ] || ver="?"
    echo "=== Tcl $ver ($real) ==="
    printf '%s\n' "$script" | "$real" 2>&1 | tr -d '\r'
    ran=$((ran + 1))
done < "$tmp"

if [ "$ran" -eq 0 ]; then
    echo "tcl-oracle.sh: no Tcl interpreters found." >&2
    echo "  Put tclsh on PATH, or set TCLSH84/TCLSH85/TCLSH86 / TCLSH_ORACLES." >&2
    exit 1
fi
