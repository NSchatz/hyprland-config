#!/usr/bin/env python3
"""Ask the COMPOSITOR ITSELF whether the staged config parses - before anything is backed up or
written.

`Hyprland --verify-config` is the only checker whose opinion actually decides whether a config
loads. Running it against the STAGED files, in a sandbox, means a bad config is refused while the
user's desktop is still untouched: a refusal costs them nothing, where the old order made every
failure start from an already-overwritten config directory.

The three outcomes are deliberately distinct:
    ok           the compositor parsed the staged files and found nothing wrong
    errors       it parsed them and found something; the lines name the STAGED paths
    unverified   no binary, or the binary has no --verify-config. NOT checked, so NOT clean -
                 the caller falls through to install/live-test/rollback unchanged
    uncheckable  the check could not be run at all (missing, unreadable or ambiguous main
                 config, sandbox failure, or the invocation was rejected before parsing)

`unverified` and `uncheckable` must never read as `ok`. "Nothing was found wrong" and "nothing
was looked at" are different sentences.

Usage: preflight-config.sh <staging-dir>
Exit:  0 ok, 1 errors, 2 unverified, 3 uncheckable, 4 usage.
"""
import os
import re
import shutil
import sys
import tempfile

from ..proc import have, run
from . import configlang

PARSE_MARKER = "======== Config parsing result:"


def _uncheckable(msg, reason):
    print(f"ERROR: {msg}", file=sys.stderr)
    print(f"PREFLIGHT_REASON={reason}")
    print("PREFLIGHT=uncheckable")
    return 3


def _unverified(reason, msg):
    print(f"PREFLIGHT_REASON={reason}")
    print(f"PREFLIGHT=unverified ({msg})")
    return 2


def main(argv):
    staging = argv[1] if len(argv) > 1 else ""
    if not staging:
        print("ERROR: usage: preflight-config.sh <staging-dir>", file=sys.stderr)
        return 4
    if not os.path.isdir(staging):
        return _uncheckable(f"staging dir '{staging}' does not exist", "staging-dir-missing")
    try:
        staging = os.path.realpath(staging)
    except OSError:
        return _uncheckable(f"staging dir '{staging}' is unreadable", "staging-dir-unreadable")

    has_conf = os.path.lexists(f"{staging}/hyprland.conf")
    has_lua = os.path.lexists(f"{staging}/hyprland.lua")

    if has_conf and has_lua:
        return _uncheckable(
            f"staging dir '{staging}' holds BOTH a hyprland.lua and a hyprland.conf, so there "
            "is no single main config to check", "ambiguous-staging")

    if has_lua:
        language = "lua"
        staged_files = sorted(f"{staging}/{n}" for n in os.listdir(staging) if n.endswith(".lua"))
    elif has_conf:
        language = "hyprlang"
        staged_files = sorted(f"{staging}/{n}" for n in os.listdir(staging) if n.endswith(".conf"))
    else:
        return _uncheckable(
            f"staging dir '{staging}' has no main config (no hyprland.lua and no hyprland.conf)",
            "no-main-config")

    main_name = configlang.lang_file(language)
    staged_main = f"{staging}/{main_name}"
    if not os.path.isfile(staged_main):
        return _uncheckable(f"staged main config '{staged_main}' is not a regular file",
                            "staged-main-not-a-file")
    if not os.access(staged_main, os.R_OK):
        return _uncheckable(f"staged main config '{staged_main}' cannot be read",
                            "staged-main-unreadable")

    hypr_bin = shutil.which("Hyprland")
    if not hypr_bin:
        return _unverified("no-compositor-binary",
                           "no Hyprland binary on PATH; the staged config was NOT checked - it "
                           "is unverified, not verified")

    try:
        sandbox = tempfile.mkdtemp(prefix="hypr-preflight.")
    except OSError:
        print("ERROR: could not create a sandbox directory", file=sys.stderr)
        print("PREFLIGHT_REASON=no-sandbox")
        print("PREFLIGHT=uncheckable")
        return 3

    try:
        sandbox_home = f"{sandbox}/home"
        sandbox_run = f"{sandbox}/run"
        mirror = f"{sandbox_home}/.config/hypr"
        try:
            os.makedirs(mirror, exist_ok=True)
            os.makedirs(sandbox_run, exist_ok=True)
            os.makedirs(f"{sandbox}/cache", exist_ok=True)
            os.chmod(sandbox_run, 0o700)
        except OSError:
            print(f"ERROR: could not populate the sandbox under '{sandbox}'", file=sys.stderr)
            print("PREFLIGHT_REASON=no-sandbox")
            print("PREFLIGHT=uncheckable")
            return 3

        # The check runs entirely inside the sandbox: it must never read or write the user's real
        # config, cache or runtime dir while deciding whether a STAGED file parses.
        env = dict(os.environ)
        env.update({
            "HOME": sandbox_home,
            "XDG_RUNTIME_DIR": sandbox_run,
            "XDG_CACHE_HOME": f"{sandbox}/cache",
            "XDG_CONFIG_HOME": f"{sandbox_home}/.config",
        })

        _, help_out = run([hypr_bin, "--help"], env=env)
        if "--verify-config" not in help_out:
            return _unverified(
                "no-offline-check",
                f"'{hypr_bin}' does not offer --verify-config; the staged config was NOT checked "
                "- it is unverified, not verified")

        print(f"PREFLIGHT_BIN={hypr_bin}")
        print(f"PREFLIGHT_MAIN={staged_main}")

        for f in staged_files:
            try:
                shutil.copyfile(f, f"{mirror}/{os.path.basename(f)}")
            except OSError:
                return _uncheckable(f"staged file '{f}' could not be read into the sandbox",
                                    "staged-file-unreadable")
            print(f"STAGED={os.path.basename(f)}")

        mirror_main = f"{mirror}/{main_name}"
        mirror_real = os.path.realpath(mirror)

        rc, out = run([hypr_bin, "--verify-config", "-c", mirror_main], env=env)
        # Report the STAGED paths, not the sandbox mirror's: the user has to be able to open the
        # file the error is about.
        report = out.replace(f"{mirror_real}/", f"{staging}/").replace(f"{mirror}/", f"{staging}/")

        if PARSE_MARKER not in report:
            for line in report.splitlines():
                print(f"  {line}", file=sys.stderr)
            return _uncheckable(
                f"'{hypr_bin}' did not parse the staged config (exit {rc}, no parsing result "
                "reported); the invocation was rejected before any parsing happened",
                "invocation-rejected")

        tail = report.split(PARSE_MARKER, 1)[1].splitlines()[1:]
        body = [l for l in tail if l.strip()]

        if any("File failed to open" in l for l in body):
            return _uncheckable(f"'{staged_main}' reached the parser but could not be opened",
                                "staged-main-unreadable")

        if rc == 0 and any(l.strip() == "config ok" for l in body):
            print("PREFLIGHT=ok (the compositor's own offline check parsed the staged config "
                  "with no errors)")
            return 0

        for line in body:
            print(f"PREFLIGHT_ERROR={line}")
        print(f"The errors above are in the STAGED files under {staging}; nothing has been "
              "installed.")
        print("PREFLIGHT=errors")
        return 1
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
