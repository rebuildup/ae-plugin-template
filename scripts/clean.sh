#!/usr/bin/env bash
#
# clean — remove build artifacts and the generated Xcode project.
#
# Usage: scripts/clean.sh [--all]
#   (default) remove build output and DerivedData
#   --all     also remove the generated .xcodeproj and the skills lockfile

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

root="$(project_root)"
remove_all=0
[ "${1:-}" = "--all" ] && remove_all=1

if [ -d "$root/build" ]; then
    rm -rf "$root/build"
    echo "Removed build/"
fi

if [ "$remove_all" -eq 1 ]; then
    while IFS= read -r project; do
        rm -rf "$project"
        echo "Removed $project"
    done < <(find "$root/plugins" -maxdepth 2 -name '*.xcodeproj' -type d 2>/dev/null)
fi

echo "Clean."