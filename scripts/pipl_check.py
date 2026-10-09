#!/usr/bin/env python3
"""Check that the PiPL agrees with what the source tells After Effects.

After Effects reads AE_Effect_Global_OutFlags and AE_Effect_Version from the PiPL
for host-compatibility decisions, and separately asks the plug-in for the same
values from PF_Cmd_GLOBAL_SETUP. When they disagree, AE reports it as an error
dialog rather than failing the build, so a plug-in can ship for years with a
PiPL that encodes its own version wrongly.

This module implements that cross-check. It is imported by scripts/verify.sh and
can be run directly:

    AE_SDK_ROOT=/path/to/sdk python3 scripts/pipl_check.py <repo> <PiPL.r>

Exit codes:
    0  every check agreed
    1  at least one mismatch
    2  at least one check could not be decided (agreement NOT established)
"""
from __future__ import annotations

import os
import re
import sys

SKIP_DIRS = {"build", ".git", "Mac", "Win", "x64", "Release", "Debug"}

STAGES = {
    "PF_Stage_DEVELOP": 0,
    "PF_Stage_ALPHA": 1,
    "PF_Stage_BETA": 2,
    "PF_Stage_RELEASE": 3,
}


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


def collect_sources(repo: str) -> list[str]:
    found: list[str] = []
    for dirpath, dirnames, filenames in os.walk(repo):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        found += [
            os.path.join(dirpath, f)
            for f in filenames
            if f.endswith((".cpp", ".h", ".mm", ".c"))
        ]
    return found


def load_flag_bits(sdk_root: str) -> dict[str, int]:
    """Map PF_OutFlag* / PF_OutFlag2* names to their bit values from the SDK."""
    header = os.path.join(sdk_root, "Examples", "Headers", "AE_Effect.h")
    bits: dict[str, int] = {}
    with open(header, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = re.search(r"\b(PF_OutFlag2?_[A-Z0-9_]+)\s*=\s*(\d+)L?\s*<<\s*(\d+)", line)
            if m:
                bits[m.group(1)] = int(m.group(2)) << int(m.group(3))
                continue
            # Zero-valued flags are written as `PF_OutFlag2_NONE = 0L,`
            m = re.search(r"\b(PF_OutFlag2?_[A-Z0-9_]+)\s*=\s*(\d+)L?\s*[,;]", line)
            if m:
                bits[m.group(1)] = int(m.group(2))
    return bits


def encode_version(vers: int, subvers: int, bugfix: int, stage: int, build: int) -> int:
    """Mirror of the PF_VERSION() macro in AE_Effect.h."""
    return (
        (((vers >> 3) & 0xF) << 26)
        | ((vers & 0x7) << 19)
        | (subvers << 15)
        | (bugfix << 11)
        | (stage << 9)
        | build
    )


class Checker:
    def __init__(self, repo: str, pipl_path: str, sdk_root: str):
        self.repo = repo
        self.pipl_path = pipl_path
        self.bits = load_flag_bits(sdk_root)
        with open(pipl_path, encoding="utf-8", errors="replace") as fh:
            self.pipl = strip_comments(fh.read())
        chunks = []
        for path in collect_sources(repo):
            with open(path, encoding="utf-8", errors="replace") as fh:
                chunks.append(strip_comments(fh.read()))
        self.source = "\n".join(chunks)

    # -- expression evaluation ------------------------------------------------

    def resolve(self, expr: str, depth: int = 0) -> int | None:
        """Turn a C++ expression into an integer, following identifiers.

        Handles the three shapes that appear in real plug-ins:
          * a literal                     0x02000000
          * an enum constant              PF_OutFlag2_NONE  -> header value
          * an enum whose value is a     MY_ENUM_COUNT     -> last member
            bare number                   (AE_Effect.h does
                                           this for *_NUM_PARAMS)
        """
        expr = expr.strip()
        m = re.search(r"0x[0-9a-fA-F]+", expr)
        if m:
            return int(m.group(0), 16)

        idents = re.findall(r"PF_OutFlag2?_[A-Z0-9_]+", expr)
        if idents:
            total = 0
            for ident in idents:
                if ident not in self.bits:
                    return None
                total |= self.bits[ident]
            return total

        m = re.search(r"(?<![A-Za-z_0-9])(\d+)(?![A-Za-z_0-9])", expr)
        if m and depth == 0:
            return int(m.group(1))

        if depth < 3:
            for ident in re.findall(r"\b[A-Za-z_][A-Za-z_0-9]*\b", expr):
                if ident.startswith("PF_OutFlag"):
                    continue
                dm = re.search(r"#define\s+" + re.escape(ident) + r"\s+([^\n]+)", self.source)
                if not dm:
                    dm = re.search(r"\b" + re.escape(ident) + r"\b\s*=\s*([^;]+);", self.source)
                if dm:
                    value = self.resolve(dm.group(1), depth + 1)
                    if value is not None:
                        return value
                value = self.enum_last_member(ident)
                if value is not None:
                    return value
        return None

    def enum_last_member(self, ident: str) -> int | None:
        """Resolve NAME to the value of the last member of `enum { ... NAME }`.

        The SDK's parameter enums end with `FOO_NUM_PARAMS // must be last`, and
        out_data->num_params is set from it. Reading the preceding members gives
        the index that enum actually assigns to NAME.
        """
        # The body must not contain '}', otherwise a lazy match can start at an
        # earlier enum in the concatenated sources and count foreign members.
        m = re.search(
            r"enum\s*\{([^}]*?\b" + re.escape(ident) + r"\b[^}]*)\}", self.source, re.S
        )
        if not m:
            return None
        body = m.group(1)
        value = 0
        seen = False
        for item in body.split(","):
            item = re.sub(r"//[^\n]*", " ", item).strip()
            if not item:
                continue
            if "=" in item:
                name, _, rhs = item.partition("=")
                name = name.strip()
                if re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", name):
                    seen = True
                    value = self.resolve_number(rhs.strip())
                    if value is None:
                        return None
                continue
            name = item.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", name):
                return None
            seen = True
            value += 1
        return value if seen else None

    def resolve_number(self, token: str) -> int | None:
        token = token.strip()
        if token in STAGES:
            return STAGES[token]
        try:
            return int(token, 0)
        except ValueError:
            pass
        dm = re.search(r"#define\s+" + re.escape(token) + r"\s+([^\n]+)", self.source)
        if not dm:
            return None
        value = dm.group(1).strip()
        if value in STAGES:
            return STAGES[value]
        try:
            return int(value, 0)
        except ValueError:
            return None

    # -- checks --------------------------------------------------------------

    def check_version(self) -> tuple[list[str], list[str]]:
        problems: list[str] = []
        undecided: list[str] = []

        vm = re.search(
            r"AE_Effect_Version\s*\{\s*([A-Za-z_][A-Za-z_0-9]*|0x[0-9a-fA-F]+|\d+)",
            self.pipl,
        )
        sm = re.search(
            r"\bout_data\s*->\s*my_version\s*=\s*PF_VERSION\s*\(([^)]*)\);", self.source
        )
        literal = None
        how = ""
        if not sm:
            alias = re.search(
                r"\bout_data\s*->\s*my_version\s*=\s*([A-Za-z_][A-Za-z_0-9]*)\s*;",
                self.source,
            )
            if alias:
                inner = re.search(
                    r"#define\s+" + re.escape(alias.group(1))
                    + r"\s+PF_VERSION\s*\(([^)]*)\)",
                    self.source,
                )
                lit = re.search(
                    r"#define\s+" + re.escape(alias.group(1))
                    + r"\s+(0x[0-9a-fA-F]+|\d+)",
                    self.source,
                )
                if inner:
                    sm = inner
                elif lit:
                    literal = int(lit.group(1), 0)
                    how = "the literal assigned to out_data->my_version"

        if not vm or (sm is None and literal is None):
            undecided.append("PiPL effect version or my_version assignment not found")
            return problems, undecided

        raw = vm.group(1)
        if re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", raw):
            dm = re.search(r"#define\s+" + re.escape(raw) + r"\s+([^\n]+)", self.source)
            if dm:
                pv = self.resolve(dm.group(1))
            else:
                pm = re.search(
                    r"#define\s+" + re.escape(raw) + r"\s+(0x[0-9a-fA-F]+|-?\d+)",
                    self.pipl,
                )
                if pm:
                    pv = int(pm.group(1), 0)
                else:
                    dm = re.search(r"\b" + re.escape(raw) + r"\b\s*=\s*([^;]+);", self.source)
                    pv = None if not dm else self.resolve(dm.group(1))
        else:
            pv = int(raw, 16) if raw.startswith("0x") else int(raw)

        if literal is not None:
            cv = literal
        else:
            parts = [p.strip() for p in sm.group(1).split(",")]
            nums = [self.resolve_number(part) for part in parts]
            if any(n is None for n in nums):
                undecided.append("my_version components could not be resolved")
                return problems, undecided
            cv = encode_version(*nums)
            how = "PF_VERSION(%s)" % sm.group(1).strip()

        if pv is None or cv is None:
            undecided.append("PiPL effect version could not be evaluated on both sides")
        elif pv != cv:
            problems.append(
                "AE_Effect_Version: PiPL says 0x%08X but PF_Cmd_GLOBAL_SETUP "
                "reports 0x%08X via %s" % (pv, cv, how)
            )
        return problems, undecided

    def check_outflags(self) -> tuple[list[str], list[str]]:
        problems: list[str] = []
        undecided: list[str] = []

        for prop, prefix in (
            ("AE_Effect_Global_OutFlags", "out_flags"),
            ("AE_Effect_Global_OutFlags_2", "out_flags2"),
        ):
            pm = re.search(re.escape(prop) + r"\s*\{([^}]*)\}", self.pipl, re.S)
            om = re.search(
                r"\bout_data\s*->\s*" + re.escape(prefix) + r"(?!\d)\s*=\s*([^;]+);",
                self.source,
            )
            if not pm:
                undecided.append("%s not found in the PiPL" % prop)
                continue
            if not om:
                undecided.append("%s is never assigned in PF_Cmd_GLOBAL_SETUP" % prefix)
                continue
            hv = re.search(r"0x[0-9a-fA-F]+|\d+", pm.group(1))
            if not hv:
                undecided.append("%s has no literal value" % prop)
                continue
            pipl_value = (
                int(hv.group(0), 16) if hv.group(0).startswith("0x") else int(hv.group(0))
            )
            source_value = self.resolve(om.group(1))
            if source_value is None:
                undecided.append(
                    "could not evaluate %s = %s" % (prefix, om.group(1).strip())
                )
                continue
            if source_value != pipl_value:
                problems.append(
                    "%s: PiPL says 0x%08x but PF_Cmd_GLOBAL_SETUP sets 0x%08x (%s)"
                    % (prop, pipl_value, source_value, om.group(1).strip())
                )
        return problems, undecided

    def check_param_count(self) -> tuple[list[str], list[str]]:
        """After Effects rejects an effect whose declared count does not match."""
        problems: list[str] = []
        undecided: list[str] = []

        if "out_data->num_params" not in self.source:
            undecided.append("no out_data->num_params assignment found")
            return problems, undecided

        pm = re.search(r"out_data\s*->\s*num_params\s*=\s*([^;]+);", self.source)
        if not pm:
            return problems, undecided
        expr = pm.group(1)

        declared = self.resolve(expr)
        if declared is None:
            undecided.append("could not evaluate out_data->num_params = %s" % expr.strip())
            return problems, undecided

        setup = self._params_setup_body()
        if setup is None:
            undecided.append("could not isolate PF_Cmd_PARAMS_SETUP")
            return problems, undecided

        registered = len(
            re.findall(r"\bPF_ADD_[A-Z_0-9]+\s*\(", re.sub(r"//[^\n]*", "", setup))
        )
        # num_params counts the source layer at index 0, so the plug-in must
        # register num_params - 1 parameters.
        expected = declared - 1
        if registered != expected:
            problems.append(
                "num_params is %d but PF_Cmd_PARAMS_SETUP registers %d parameter(s); "
                "After Effects rejects the effect with a parameter count mismatch"
                % (declared, registered)
            )
        return problems, undecided

    def _params_setup_body(self) -> str | None:
        """Return the function body that registers parameters.

        Locate it by out_data->num_params rather than by the PF_Cmd_PARAMS_SETUP
        dispatch case: the handler is a separate function, and the case body
        only calls it.
        """
        anchor = re.search(r"out_data\s*->\s*num_params\s*=", self.source)
        if not anchor:
            return None
        start = self.source.rfind("{", 0, anchor.start())
        if start < 0:
            return None
        depth = 0
        for i in range(start, len(self.source)):
            if self.source[i] == "{":
                depth += 1
            elif self.source[i] == "}":
                depth -= 1
                if depth == 0:
                    return self.source[start + 1 : i]
        return None

    def run(self) -> tuple[list[str], list[str]]:
        problems: list[str] = []
        undecided: list[str] = []
        for check in (self.check_version, self.check_outflags, self.check_param_count):
            p, u = check()
            problems += p
            undecided += u
        return problems, undecided


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    repo, pipl_path = argv[1], argv[2]
    sdk_root = os.environ.get("AE_SDK_ROOT", "")
    if not sdk_root or not os.path.isfile(
        os.path.join(sdk_root, "Examples", "Headers", "AE_Effect.h")
    ):
        print("  note  AE_SDK_ROOT is not set to an SDK root; PiPL cross-check skipped")
        return 2

    checker = Checker(repo, pipl_path, sdk_root)
    problems, undecided = checker.run()

    for u in undecided:
        print("  note  %s" % u)
    for p in problems:
        print("  FAIL  %s" % p)
    if problems:
        return 1
    if undecided:
        print("  note  PiPL/source cross-check incomplete; agreement NOT established")
        return 2
    print("  ok    PiPL version, outflags and parameter count agree with the source")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))