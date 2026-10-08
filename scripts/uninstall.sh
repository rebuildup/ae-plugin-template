#!/usr/bin/env bash
#
# uninstall — remove plug-ins built from this repository.
#
# Only removes .plugin bundles that this repository knows how to build, so it
# cannot delete an unrelated third-party plug-in from a shared AE installation.
#
# Usage: scripts/uninstall.sh [plugin-dir ...]

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

destination_dir="$(ae_plugin_dir)"

if [ ! -d "$destination_dir" ]; then
    echo "Nothing to remove: $destination_dir does not exist."
    exit 0
fi

if [ "$#" -gt 0 ]; then
    plugin_dirs=("$@")
else
    plugin_dirs=()
    while IFS= read -r d; do
        plugin_dirs+=("$d")
    done < <(find "$(project_root)/plugins" -mindepth 1 -maxdepth 1 -type d | sort)
fi

removed=0

for plugin_dir in "${plugin_dirs[@]}"; do
    name="$(basename "$plugin_dir")"
    target="$destination_dir/$name.plugin"

    if [ -e "$target" ]; then
        rm -rf "$target"
        echo "Removed $target"
        removed=$((removed + 1))
    else
        echo "Not installed: $name"
    fi
done

echo
if [ "$removed" -gt 0 ]; then
    echo "After Effects must be restarted for the removal to take effect."
else
    echo "Nothing was removed."
fi