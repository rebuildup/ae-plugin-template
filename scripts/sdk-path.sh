#!/usr/bin/env bash
#
# sdk-path — print the resolved Adobe After Effects SDK location.
#
# Useful for confirming that AE_SDK_ROOT / .env.local actually points where you
# think it does before diagnosing a build failure.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

resolve_sdk_root