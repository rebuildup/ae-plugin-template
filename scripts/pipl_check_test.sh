#!/usr/bin/env bash
#
# pipl_check_test.sh — resolve the SDK, then run the PiPL check's own tests.
#
# Resolution lives in scripts/lib/sdk.sh so there is exactly one place that
# decides where the Adobe SDK is, and no absolute path is committed here.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/sdk.sh
source "$script_dir/lib/sdk.sh"

AE_SDK_ROOT="$(resolve_sdk_root)"
export AE_SDK_ROOT

exec python3 "$script_dir/pipl_check_test.py" "$@"
