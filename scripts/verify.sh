#!/usr/bin/env bash
#
# verify — check that a built .plugin is actually loadable-shaped.
#
# Compiling is not the same as being loadable. AE needs a specific bundle
# layout, a PiPL resource, an exported entry point, and (since macOS 15) a
# valid signature. This script asserts each of those so a broken plug-in is
# caught here instead of as a silent absence in the Effects panel.
#
# Usage: scripts/verify.sh [Debug|Release]

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

configuration="${1:-Debug}"
plugin_dir="$(project_root)/plugins/TemplateEffect"
plugin_name="$(basename "$plugin_dir")"
bundle="$(project_root)/build/$configuration/$plugin_name.plugin"

failures=0

fail() {
    printf '  FAIL  %s\n' "$*" >&2
    failures=$((failures + 1))
}

pass() {
    printf '  ok    %s\n' "$*"
}

check() {
    local label="$1"
    shift
    if "$@"; then
        pass "$label"
    else
        fail "$label"
    fi
}

[ -d "$bundle" ] || {
    printf 'error: %s does not exist. Run scripts/build.sh %s first.\n' "$bundle" "$configuration" >&2
    exit 1
}

echo "Verifying $bundle"
echo

# --- bundle layout -------------------------------------------------------

check "bundle is a directory" test -d "$bundle"
check "Contents/Info.plist exists" test -f "$bundle/Contents/Info.plist"

binary="$bundle/Contents/MacOS/$plugin_name"
check "Contents/MacOS/$plugin_name exists" test -f "$binary"

plist_get() { /usr/libexec/PlistBuddy -c "Print $1" "$bundle/Contents/Info.plist" 2>/dev/null || true; }

package_type="$(plist_get ':CFBundlePackageType')"
if [ "$package_type" = "eFKT" ]; then
    pass "CFBundlePackageType is eFKT"
else
    fail "CFBundlePackageType is '$package_type', expected 'eFKT'"
fi

signature="$(plist_get ':CFBundleSignature')"
if [ "$signature" = "FXTC" ]; then
    pass "CFBundleSignature is FXTC"
else
    fail "CFBundleSignature is '$signature', expected 'FXTC'"
fi

executable="$(plist_get ':CFBundleExecutable')"
if [ "$executable" = "$plugin_name" ]; then
    pass "CFBundleExecutable matches the binary name"
else
    fail "CFBundleExecutable is '$executable', expected '$plugin_name'"
fi

# --- architectures -------------------------------------------------------

arches="$(lipo -archs "$binary" 2>/dev/null || true)"
if printf '%s' "$arches" | tr ' ' '\n' | grep -qx arm64; then
    pass "contains an arm64 slice (required on Apple Silicon)"
else
    fail "no arm64 slice in $arches"
fi

if printf '%s' "$arches" | tr ' ' '\n' | grep -qx x86_64; then
    pass "contains an x86_64 slice (matches the PiPL CodeMacIntel64 entry)"
else
    fail "no x86_64 slice in $arches"
fi

# --- exported entry points ----------------------------------------------

# The PiPL names the entry point, so the binary has to export it under exactly
# that name or AE will load the bundle and then fail to find the effect.
if nm -gU "$binary" 2>/dev/null | grep -qE '_EffectMain$'; then
    pass "exports EffectMain"
else
    fail "does not export EffectMain"
fi

if nm -gU "$binary" 2>/dev/null | grep -qE '_PluginDataEntryFunction2$'; then
    pass "exports PluginDataEntryFunction2"
else
    fail "does not export PluginDataEntryFunction2"
fi

# --- PiPL resource -------------------------------------------------------

rsrc="$bundle/Contents/Resources/$plugin_name.rsrc"
check "PiPL resource file present" test -f "$rsrc"

if [ -f "$rsrc" ]; then
    check "PiPL declares AEEffect (kind eFKT)" bash -c \
        "grep -q 'eFKT' '$rsrc'"
    check "PiPL declares the arm64 entry point (ma64)" bash -c \
        "grep -q 'ma64' '$rsrc'"
    check "PiPL declares a match name (eMNA)" bash -c \
        "grep -q 'eMNA' '$rsrc'"
fi

# --- PiPL vs source -------------------------------------------------------

# AE reads the effect version, the global outflags and the parameter count from
# the PiPL for host-compatibility decisions, and asks the plug-in for the same
# values from PF_Cmd_GLOBAL_SETUP. When they disagree AE raises an error dialog
# rather than failing the build, so a plug-in can build, verify and ship with a
# PiPL that misencodes its own version.
#
# scripts/pipl_check.py recomputes both sides from source. A check it could not
# decide is reported as undecided and never counted as agreement.
pipl_source="$(find "$(project_root)/plugins" -maxdepth 3 -name '*PiPL.r' \
    -not -path '*/build/*' -print -quit 2>/dev/null || true)"

if [ -z "$pipl_source" ]; then
    fail "no PiPL resource source found"
elif ! command -v python3 >/dev/null 2>&1; then
    printf '  note  python3 unavailable; the PiPL cross-check did not run\n'
else
    # AEGPs do not declare AE_Effect_Global_OutFlags or a match name, so the
    # cross-check only applies to effects.
    pipl_rc=0
    if ! AE_SDK_ROOT="$(resolve_sdk_root)" python3 \
        "$(project_root)/scripts/pipl_check.py" \
        "$(dirname "$(dirname "$pipl_source")")" "$pipl_source"; then
        pipl_rc=$?
    fi
    case "$pipl_rc" in
        1) fail "PiPL disagrees with PF_Cmd_GLOBAL_SETUP" ;;
        2) note "PiPL cross-check could not decide; agreement is NOT established" ;;
    esac
fi

# --- signature -----------------------------------------------------------

# macOS 15 and later refuse to load unsigned plug-ins, so an unsigned or
# invalid bundle builds fine and then never appears in AE.
if codesign --verify --strict "$bundle" 2>/dev/null; then
    pass "signature is valid"
else
    fail "signature does not verify (macOS 15+ will refuse to load this)"
fi

# `codesign -dv` writes to stderr. Capture first rather than piping into grep:
# under `set -o pipefail`, grep exiting early would SIGPIPE codesign and turn a
# successful check into a failure.
signature_details="$(codesign -dv "$bundle" 2>&1 || true)"
if printf '%s\n' "$signature_details" | grep -q "Signature=adhoc"; then
    pass "signed ad-hoc, as expected for local development"
else
    fail "expected an ad-hoc signature for local development"
fi

# --- runtime dependencies ------------------------------------------------

# Anything linking a framework AE does not provide will fail to load, and the
# error message from AE is not specific about it.
if otool -L "$binary" | grep -qE '@executable_path|@loader_path'; then
    fail "binary references @executable_path/@loader_path; AE does not provide a loader path inside the plug-in bundle"
fi

# otool -L prints one "path (architecture N):" header per slice, and each of
# those headers contains this machine's absolute path to the bundle. Filtering on
# the leading tab keeps only real dependency lines; dropping just the first line
# leaves the second slice's header and looks like a /Users link.
deps="$(otool -L "$binary" | grep -E '^[[:space:]]' || true)"

if grep -qE '\->[[:space:]]*/Users/' <<<"$deps"; then
    fail "binary links an absolute /Users path; this bundle will not load on another machine"
else
    pass "no absolute /Users paths in link dependencies"
fi

# An OpenMP runtime would have to be present wherever the plug-in ships, which
# a plug-in bundle cannot guarantee.
if grep -qE 'libomp|libiomp|OpenMP' <<<"$deps"; then
    printf '  note  links an OpenMP runtime; confirm it exists wherever this plug-in ships\n'
fi

echo
if [ "$failures" -gt 0 ]; then
    printf 'verify: %d check(s) failed\n' "$failures" >&2
    exit 1
fi

printf 'verify: all checks passed\n'