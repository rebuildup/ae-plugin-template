#!/usr/bin/env bash
#
# install — build and deploy a plug-in into the per-user AE plug-in folder.
#
# This is intentionally a separate, explicit step rather than part of the
# build. A build that writes into a folder AE is scanning makes it impossible
# to tell which version AE loaded, and it leaves stray plug-ins behind when the
# working directory is deleted.
#
# Usage: scripts/install.sh [Debug|Release] [plugin-dir]

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

configuration="${1:-Debug}"
plugin_dir="${2:-$(project_root)/plugins/TemplateEffect}"
plugin_name="$(basename "$plugin_dir")"
bundle="$(project_root)/build/$configuration/$plugin_name.plugin"

if [ ! -d "$bundle" ]; then
    printf 'error: %s not found. Run scripts/build.sh %s first.\n' "$bundle" "$configuration" >&2
    exit 1
fi

destination_dir="$(ae_plugin_dir)"
destination="$destination_dir/$plugin_name.plugin"

mkdir -p "$destination_dir"

# Remove first so a renamed or deleted resource cannot survive from a previous
# install. rsync --delete would do this too, but only for files it considers the
# same; removing first is unambiguous.
if [ -e "$destination" ]; then
    rm -rf "$destination"
fi

cp -R "$bundle" "$destination"

# Copying invalidates the signature. Re-sign after the copy, never before it.
codesign --force --sign - --timestamp=none "$destination"

echo "Installed $plugin_name ($configuration)"
echo "  from $bundle"
echo "  to   $destination"
echo
echo "After Effects must be restarted for a newly installed plug-in to appear."