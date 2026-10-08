#!/usr/bin/env bash
#
# build — build a plug-in and leave the .plugin bundle in build/
#
# Output deliberately stays inside the repository (build/<config>/) so a build
# never writes into a location AE happens to be scanning. Use scripts/install.sh
# to deploy it.
#
# Usage: scripts/build.sh [Debug|Release] [plugin-dir]

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

configuration="${1:-Debug}"
plugin_dir="${2:-$(project_root)/plugins/TemplateEffect}"
plugin_name="$(basename "$plugin_dir")"

AE_SDK_ROOT="$(resolve_sdk_root)"
export AE_SDK_ROOT

if [ ! -d "$plugin_dir/$plugin_name.xcodeproj" ]; then
    echo "Generating Xcode project..."
    xcodegen generate --spec "$plugin_dir/project.yml" --project "$plugin_dir" >/dev/null
fi

build_dir="$(project_root)/build/$configuration"

echo "Building $plugin_name ($configuration)"
echo "SDK:  $AE_SDK_ROOT"
echo "Out:  $build_dir"
echo

xcodebuild \
    -project "$plugin_dir/$plugin_name.xcodeproj" \
    -scheme "$plugin_name" \
    -configuration "$configuration" \
    -derivedDataPath "$(project_root)/build/DerivedData" \
    CONFIGURATION_BUILD_DIR="$build_dir" \
    ONLY_ACTIVE_ARCH=NO \
    build

echo
echo "Built: $build_dir/$plugin_name.plugin"