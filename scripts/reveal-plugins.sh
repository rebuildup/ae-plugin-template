#!/usr/bin/env bash
#
# reveal-plugins — open the per-user AE plug-in folder in Finder.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

destination_dir="$(ae_plugin_dir)"
mkdir -p "$destination_dir"
open "$destination_dir"