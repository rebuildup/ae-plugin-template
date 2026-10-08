#!/usr/bin/env bash
#
# Resolve the location of the Adobe After Effects C++ SDK.
#
# The SDK is licensed material and is not vendored into this repository, so the
# location is configuration, not source. Resolution order:
#
#   1. $AE_SDK_ROOT                       (explicit, wins over everything)
#   2. .env.local                         (project-local, gitignored)
#   3. $AE_SDK_ROOT_FILE                  (path to a file holding the root)
#   4. common install locations           (last-resort convenience)
#
# A candidate is only accepted if it actually looks like an SDK.

set -euo pipefail

SDK_ROOT_ENV_NAME="AE_SDK_ROOT"
# Subdirectory of the SDK root that must exist for the path to be usable.
SDK_MARKER_SUBDIR="Examples/Headers"

# Candidates searched when nothing explicit is configured.
# Expand ~ here rather than relying on the caller's shell.
_default_candidates() {
    cat <<'EOF'
~/Documents/projects/adobe/AeSDK
~/Developer/AfterEffectsSDK
~/Developer/AE_SDK
~/sdk/AfterEffectsSDK
/opt/AfterEffectsSDK
/usr/local/share/AfterEffectsSDK
EOF
}

# _sdk_is_valid <root>
# Returns 0 if <root> contains the headers this project compiles against.
_sdk_is_valid() {
    local root="$1"
    [ -n "$root" ] && [ -d "$root" ] || return 1
    [ -f "$root/$SDK_MARKER_SUBDIR/AE_Effect.h" ]
}

# _sdk_first_line_of <file>
# Emits the first non-empty, non-comment line of a file, trimmed.
_sdk_first_line_of() {
    local file="$1"
    [ -f "$file" ] || return 1
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file" | head -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# resolve_sdk_root
# Emits the resolved SDK root on stdout, or fails with an actionable message.
resolve_sdk_root() {
    local candidate=""

    # 1. explicit environment variable
    if [ -n "${!SDK_ROOT_ENV_NAME:-}" ]; then
        candidate="${!SDK_ROOT_ENV_NAME}"
        if _sdk_is_valid "$candidate"; then
            printf '%s\n' "$(cd "$candidate" && pwd)"
            return 0
        fi
        _die "$SDK_ROOT_ENV_NAME is set to '$candidate' but $candidate/$SDK_MARKER_SUBDIR/AE_Effect.h does not exist."
    fi

    # 2. project-local override file
    local env_local="$(project_root)/.env.local"
    if [ -f "$env_local" ]; then
        candidate="$(_sdk_first_line_of "$env_local" || true)"
        if [ -n "$candidate" ]; then
            # Allow a leading "~" in the file, which the shell would not expand.
            candidate="${candidate/#\~/$HOME}"
            if _sdk_is_valid "$candidate"; then
                printf '%s\n' "$(cd "$candidate" && pwd)"
                return 0
            fi
            _die ".env.local points to '$candidate' but $candidate/$SDK_MARKER_SUBDIR/AE_Effect.h does not exist."
        fi
    fi

    # 3. file containing the path
    if [ -n "${AE_SDK_ROOT_FILE:-}" ]; then
        if [ ! -f "$AE_SDK_ROOT_FILE" ]; then
            _die "AE_SDK_ROOT_FILE points to '$AE_SDK_ROOT_FILE' which is not a file."
        fi
        candidate="$(_sdk_first_line_of "$AE_SDK_ROOT_FILE" || true)"
        if [ -n "$candidate" ]; then
            candidate="${candidate/#\~/$HOME}"
            if _sdk_is_valid "$candidate"; then
                printf '%s\n' "$(cd "$candidate" && pwd)"
                return 0
            fi
            _die "AE_SDK_ROOT_FILE contains '$candidate' but $candidate/$SDK_MARKER_SUBDIR/AE_Effect.h does not exist."
        fi
    fi

    # 4. well-known locations
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        candidate="${line/#\~/$HOME}"
        if _sdk_is_valid "$candidate"; then
            printf '%s\n' "$(cd "$candidate" && pwd)"
            return 0
        fi
    done < <(_default_candidates)

    _die "Could not locate the After Effects SDK.
Point at it with an environment variable:

    export $SDK_ROOT_ENV_NAME=/path/to/AfterEffectsSDK

or write the path into $env_local (gitignored), for example:

    /Users/you/Documents/projects/adobe/AeSDK
"
}

# Absolute path of this repository, resolved when this file is sourced.
# Captured eagerly because BASH_SOURCE[0] inside a function refers to the file
# that defined the function, not the caller's file.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# project_root
# Absolute path of this repository, regardless of the caller's directory.
project_root() {
    printf '%s\n' "$PROJECT_ROOT"
}

# _die <message...>
# Report a configuration error on stderr and exit non-zero.
_die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# ae_plugin_dir
# The per-user plug-in directory recommended by Adobe for development.
# The "7.0" component is literal and has been unchanged across every CC and
# current AE release.
ae_plugin_dir() {
    printf '%s\n' "$HOME/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore"
}