#!/usr/bin/env python3
"""Negative tests for scripts/pipl_check.py.

The cross-check is only worth having if it actually fails when the PiPL and the
source disagree. Each case below introduces one specific defect into a copy of
the template plug-in and asserts the checker rejects it. The final case asserts
the unmodified template still passes, which guards against a checker that
rejects everything.

Run with the SDK available:

    AE_SDK_ROOT=/path/to/AfterEffectsSDK python3 scripts/pipl_check_test.py
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECKER = os.path.join(REPO, "scripts", "pipl_check.py")
PLUGIN = os.path.join(REPO, "plugins", "TemplateEffect")
SDK_ROOT = os.environ.get("AE_SDK_ROOT", "")

if not SDK_ROOT and not os.environ.get("AE_SDK_ROOT_FILE"):
    # Allow running the test directly with an explicit path.
    SDK_ROOT = sys.argv[1] if len(sys.argv) > 1 else ""
    if SDK_ROOT:
        sys.argv.pop(1)


def run_checker(plugin_dir: str) -> tuple[int, str]:
    proc = subprocess.run(
        [sys.executable, CHECKER, plugin_dir,
         os.path.join(plugin_dir, "Sources", "TemplateEffectPiPL.r")],
        capture_output=True,
        text=True,
        cwd=REPO,
    )
    return proc.returncode, proc.stdout.strip()


def copy_plugin(tmp: str, name: str) -> str:
    dest = os.path.join(tmp, name)
    shutil.copytree(PLUGIN, dest)
    return dest


def edit(path: str, old: str, new: str) -> None:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if old not in text:
        raise AssertionError(f"fixture text not found in {path}: {old!r}")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text.replace(old, new, 1))


def main() -> int:
    if not SDK_ROOT:
        print("AE_SDK_ROOT is not set to an SDK root; cannot run", file=sys.stderr)
        return 2

    tmp = tempfile.mkdtemp(prefix="pipl-check-test-")
    failures = 0
    try:
        cases = []

        # 1. PiPL effect version differs from what PF_Cmd_GLOBAL_SETUP reports.
        p = copy_plugin(tmp, "version")
        edit(os.path.join(p, "Sources", "TemplateEffectPiPL.r"),
             "524289 /* 1.0 */", "524288 /* 1.0 */")
        cases.append(("PiPL effect version mismatch", p, 1))

        # 2. PiPL global outflags differ from what the source sets.
        p = copy_plugin(tmp, "outflags")
        edit(os.path.join(p, "Sources", "TemplateEffectPiPL.r"),
             "0x02000000", "0x06000000")
        cases.append(("PiPL global outflags mismatch", p, 1))

        # 3. num_params exceeds the number of parameters actually registered.
        p = copy_plugin(tmp, "paramcount")
        edit(os.path.join(p, "Sources", "TemplateEffect.h"),
             "TEMPLATE_NUM_PARAMS\n};", "TEMPLATE_GHOST,\n    TEMPLATE_NUM_PARAMS\n};")
        cases.append(("num_params exceeds registrations", p, 1))

        # 4. The unmodified template must pass, otherwise the checker is useless.
        cases.append(("unmodified template passes", PLUGIN, 0))

        for name, plugin_dir, expected in cases:
            rc, out = run_checker(plugin_dir)
            last = out.splitlines()[-1] if out else "(no output)"
            if rc == expected:
                print(f"  ok    {name} (rc={rc})")
            else:
                print(f"  FAIL  {name}: expected rc={expected}, got rc={rc}")
                print(f"        {last}")
                failures += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if failures:
        print(f"pipl_check_test: {failures} case(s) failed")
        return 1
    print("pipl_check_test: all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())