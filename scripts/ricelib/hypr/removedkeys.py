#!/usr/bin/env python3
"""Refuse a staged config that sets a key REMOVED at the target Hyprland version.

A removed key is not a deprecation warning: at or after the release that removed it, it is a
hard parse error. This check runs FIRST in the apply, before the compositor is consulted at all,
because it needs neither a binary nor a session - its verdict is reached on hosts where the
offline check can only say `unverified`. Nothing is backed up or written behind it.

An UNKNOWN target version is not a pass. Whether a key is removed depends entirely on the
target, so with no target nothing was validated, and that is reported as its own outcome
(`unknown-target-version`) rather than silence that reads like approval.

Usage: validate-removed-keys.sh <staging-dir> [--version VER] [--ledger F] [--root D]
                                [--supported-targets]
Exit:  0 clean, 1 a removed key is set, 2 uncheckable/usage, 3 the target version is unknown.
"""
import os
import sys

from . import ledger

WORD = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-")


def key_paths(path, lang):
    """Every `key = value` assignment in a config, as (line-number, full:colon:path).

    Hyprland's config is nested blocks, so a key's identity is its PATH: `decoration:blur:size`,
    not `size`. This walks the braces to build that path, which is what the ledger's rows name.
    Comments are stripped first so a commented-out key is not reported as set."""
    out = []
    stack = []
    pending = ""
    pending_line = 0
    buf = ""
    awaiting = False

    def flush():
        nonlocal pending, buf, awaiting
        if awaiting and pending:
            prefix = "".join(f"{s}:" for s in stack if s)
            out.append((pending_line, prefix + pending))
        pending, awaiting, buf = "", False, ""

    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        return out

    for lineno, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        marker = "--" if lang == "lua" else "#"
        idx = line.find(marker)
        if idx >= 0:
            line = line[:idx]
        for c in line:
            if c in WORD:
                buf += c
                continue
            if c == "=":
                pending, pending_line, buf, awaiting = buf, lineno, "", True
                continue
            if c == "{":
                stack.append(pending if pending else buf)
                pending, buf, awaiting = "", "", False
                continue
            if c == "}":
                flush()
                if stack:
                    stack.pop()
                continue
            if c in ",;":
                flush()
                continue
            if c in " \t":
                continue
            if awaiting:
                continue
            buf = ""
        flush()
    return out


def _uncheckable(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    print("REMOVED_KEYS=uncheckable")
    return 2


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", "..", ".."))
    ledger_path = ""
    staging = ""
    version = os.environ.get("HYPR_VERSION", "")
    version_source = "supplied" if version else "none"
    list_targets = False

    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]; i += 1
        if a == "--version":
            if i >= len(args):
                print("ERROR: --version needs a value", file=sys.stderr); return 2
            version, version_source = args[i], "supplied"; i += 1
        elif a == "--ledger":
            if i >= len(args):
                print("ERROR: --ledger needs a value", file=sys.stderr); return 2
            ledger_path = args[i]; i += 1
        elif a == "--root":
            if i >= len(args):
                print("ERROR: --root needs a value", file=sys.stderr); return 2
            root = args[i]; i += 1
        elif a == "--supported-targets":
            list_targets = True
        elif a in ("-h", "--help"):
            print(__doc__.strip()); return 0
        elif a.startswith("-"):
            print(f"ERROR: unknown argument: {a}", file=sys.stderr); return 2
        else:
            if staging:
                print(f"ERROR: unexpected extra argument: {a}", file=sys.stderr); return 2
            staging = a

    if not ledger_path:
        ledger_path = ledger.default_path(root)

    if not os.path.isfile(ledger_path) or not os.access(ledger_path, os.R_OK):
        return _uncheckable(f"the version-cliff ledger '{ledger_path}' is missing or unreadable, "
                            "so there is no removed-key set to check against")

    if list_targets:
        targets = ledger.supported_targets(ledger_path)
        if not targets:
            return _uncheckable(f"the ledger '{ledger_path}' does not declare both a "
                                "support-floor and a newest-release, so the supported targets "
                                "cannot be enumerated")
        for t in targets:
            print(t)
        return 0

    if not staging:
        print("ERROR: usage: validate-removed-keys.sh <staging-dir> [--version VER]",
              file=sys.stderr)
        return 2
    if not os.path.isdir(staging) or not os.access(staging, os.R_OK):
        return _uncheckable(f"staging dir '{staging}' does not exist or cannot be read")

    print(f"REMOVED_KEYS_LEDGER={ledger_path}")
    rules = ledger.removed_keys(ledger_path)
    print(f"REMOVED_KEYS_RULES={len(rules)}")
    if not rules:
        return _uncheckable(f"the ledger '{ledger_path}' declares ZERO removed keys. A validator "
                            "with no rules would pass everything; that is not a verdict")

    if not version:
        from . import detectversion
        detected = detectversion.hypr_version()
        if detected and detected != "unknown":
            version, version_source = detected, "detected"

    if not version or version.lower() == "unknown":
        print("REMOVED_KEYS_TARGET=unknown")
        print("REMOVED_KEYS_TARGET_SOURCE=none")
        print("ERROR: the target Hyprland version could not be determined (no --version, no "
              "HYPR_VERSION, and detection found neither hyprctl nor Hyprland). Whether a key is "
              "removed depends entirely on the target, so NOTHING was validated here. This is "
              "not a pass: supply the target with --version <x.y.z> or HYPR_VERSION=<x.y.z>.",
              file=sys.stderr)
        print("REMOVED_KEYS=unknown-target-version")
        return 3

    print(f"REMOVED_KEYS_TARGET={version}")
    print(f"REMOVED_KEYS_TARGET_SOURCE={version_source}")

    staged = []
    for dirpath, _dirs, files in os.walk(staging):
        for n in sorted(files):
            if n.endswith((".conf", ".lua")):
                staged.append(os.path.join(dirpath, n))
    staged.sort()
    for f in staged:
        if not os.access(f, os.R_OK):
            return _uncheckable(f"staged file '{f}' cannot be read, so the staged set was not "
                                "checked")
    if not staged:
        return _uncheckable(f"staging dir '{staging}' holds no *.conf and no *.lua files, so "
                            "there was nothing to validate")

    found = 0
    for f in staged:
        print(f"REMOVED_KEYS_CHECKED={f}")
        lang = "lua" if f.endswith(".lua") else "conf"
        paths = key_paths(f, lang)
        if not paths:
            continue
        for key, removed_at, replacement, _src in rules:
            if ledger.vercmp(version, removed_at) == -1:
                continue
            for lno, path in paths:
                if path == key:
                    print(f"REMOVED_KEY={key} | {f}:{lno} | removed at {removed_at} | "
                          f"use {replacement}")
                    found += 1

    if found:
        print(f"The generated config above targets Hyprland {version}, where each key named is "
              "a hard parse error. Nothing has been installed.")
        print("REMOVED_KEYS=found")
        return 1

    print(f"REMOVED_KEYS=ok ({len(staged)} staged file(s) checked against {len(rules)} "
          f"removed-key rule(s) for target {version})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
