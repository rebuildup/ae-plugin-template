#!/usr/bin/env bash
#
# generate — produce the Xcode project from project.yml
#
# The .xcodeproj is a build artifact: it embeds absolute SDK paths, so it is not
# committed. Regenerate it after changing project.yml or after moving the SDK.
#
# Usage: scripts/generate.sh [plugin-dir]

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

AE_SDK_ROOT="$(resolve_sdk_root)"
export AE_SDK_ROOT

plugin_dir="${1:-$(project_root)/plugins/TemplateEffect}"

if [ ! -f "$plugin_dir/project.yml" ]; then
    printf 'error: no project.yml at %s\n' "$plugin_dir" >&2
    exit 1
fi

echo "SDK root: $AE_SDK_ROOT"
echo "Plugin:   $(basename "$plugin_dir")"

xcodegen generate --spec "$plugin_dir/project.yml" --project "$plugin_dir"