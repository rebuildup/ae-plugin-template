#!/usr/bin/env bash
#
# validate — checks that need neither the Adobe SDK nor Xcode.
#
# Deliberately separate from scripts/verify.sh: verify.sh asserts properties of a
# built bundle, this asserts properties of the repository itself. Both are meant
# to run in CI where the SDK is not available.
#
# Scope is limited to things that are mechanically decidable from the repository
# contents. See docs/adr/ADR-0002-ci-build-policy.md for why CI does not build.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

failures=0

fail() {
    printf '  FAIL  %s\n' "$*" >&2
    failures=$((failures + 1))
}

pass() { printf '  ok    %s\n' "$*"; }

root="$(project_root)"
cd "$root"

echo "Validating $root"
echo

# --- shell script syntax --------------------------------------------------

for script in scripts/*.sh scripts/lib/*.sh; do
    if bash -n "$script" 2>/dev/null; then
        pass "$script parses"
    else
        fail "$script has a syntax error"
        bash -n "$script" || true
    fi
done

# --- every script is executable and has a shebang ------------------------

for script in scripts/*.sh; do
    if head -n1 "$script" | grep -q '^#!/usr/bin/env bash'; then
        pass "$script has a shebang"
    else
        fail "$script is missing a '#!/usr/bin/env bash' shebang"
    fi

    if [ -x "$script" ]; then
        pass "$script is executable"
    else
        fail "$script is not executable"
    fi
done

# --- generated artifacts are not committed --------------------------------

if git ls-files --error-unmatch '*.xcodeproj' >/dev/null 2>&1; then
    fail "an .xcodeproj is tracked; it is a generated artifact (ADR-0004)"
else
    pass "no .xcodeproj is tracked"
fi

if git ls-files --error-unmatch '.env.local' >/dev/null 2>&1; then
    fail ".env.local is tracked; it holds a machine-specific SDK path"
else
    pass ".env.local is not tracked"
fi

# --- SDK headers must not be vendored -------------------------------------

# ADR-0001 keeps the SDK out of the repository. Detect the two shapes that
# matter: a whole SDK tree, and individual Adobe header names.
if git ls-files | grep -qE '(^|/)Examples/Headers/AE_Effect\.h$'; then
    fail "an Adobe SDK header appears to be committed; see ADR-0001"
else
    pass "no Adobe SDK headers are committed"
fi

if git ls-files | grep -qE '(^|/)AE_General\.r$'; then
    fail "AE_General.r (Adobe PiPL macros) appears to be committed; see ADR-0001"
else
    pass "no Adobe PiPL macros are committed"
fi

# --- mise tasks point at scripts that exist -------------------------------

if command -v mise >/dev/null 2>&1; then
    while IFS= read -r referenced; do
        if [ -x "$referenced" ]; then
            pass "mise task target $referenced exists"
        else
            fail "mise.toml references $referenced, which is missing or not executable"
        fi
    done < <(grep -oE 'run = "scripts/[a-z-]+\.sh"' mise.toml | sed -E 's/run = "(.*)"/\1/')
else
    printf '  skip  mise not installed; cannot check mise task targets\n'
fi

# --- per-plug-in consistency ---------------------------------------------

# The bundle name, the Info.plist CFBundleExecutable, the PiPL entry point and
# the exported symbol must all agree. A mismatch here produces a plug-in that
# compiles and then never appears in After Effects, which is expensive to
# diagnose by hand.
while IFS= read -r project; do
    plugin_dir="$(dirname "$project")"
    plugin_name="$(basename "$plugin_dir")"
    spec="$plugin_dir/project.yml"

    if ! grep -q "name: $plugin_name" "$spec"; then
        fail "$plugin_dir: project.yml does not declare a target named $plugin_name"
    fi

    plist="$plugin_dir/Resources/$plugin_name.plugin-Info.plist"
    if [ ! -f "$plist" ]; then
        fail "$plugin_dir: Resources/$plugin_name.plugin-Info.plist is missing"
    else
        executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null || true)"
        if [ "$executable" != "$plugin_name" ]; then
            fail "$plugin_dir: CFBundleExecutable is '$executable', expected '$plugin_name'"
        else
            pass "$plugin_dir: CFBundleExecutable matches the bundle name"
        fi
    fi

    pipl="$(find "$plugin_dir/Sources" -maxdepth 1 -name '*PiPL.r' -print -quit 2>/dev/null || true)"
    if [ -z "$pipl" ]; then
        fail "$plugin_dir: no *PiPL.r resource source"
    elif ! grep -q 'CodeMacARM64 {"EffectMain"}' "$pipl"; then
        fail "$plugin_dir: PiPL does not declare the arm64 entry point"
    else
        pass "$plugin_dir: PiPL declares the arm64 entry point"
    fi

    header="$(find "$plugin_dir/Sources" -maxdepth 1 -name '*.h' ! -name '*_Strings.h' -print -quit 2>/dev/null || true)"
    if [ -z "$header" ]; then
        fail "$plugin_dir: no main header"
    elif ! grep -q 'DllExport PF_Err EffectMain' "$header"; then
        fail "$plugin_dir: main header does not declare an exported EffectMain"
    else
        pass "$plugin_dir: main header exports EffectMain"
    fi
done < <(find plugins -maxdepth 2 -name project.yml | sort)

echo
if [ "$failures" -gt 0 ]; then
    printf 'validate: %d check(s) failed\n' "$failures" >&2
    exit 1
fi

printf 'validate: all checks passed\n'