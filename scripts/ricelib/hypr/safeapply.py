#!/usr/bin/env python3
"""Prove a staged Hyprland config parses, THEN install it, live-test it, and AUTO-ROLL-BACK if
it fails to load.

The ORDER is the safety property:

  0.  removed-key check   a STATIC read of the staged files against the version-cliff ledger.
                          First, and deliberately independent of everything below: it needs no
                          compositor, so a host that can only report `preflight-unverified`
                          still gets a real verdict. Nothing is backed up or written behind it.
  0b. offline preflight   the compositor's OWN check, against the staged files, in a sandbox.
                          Runs before any backup and any write, so a bad config is refused with
                          the config directory never touched.
  1.  install             timestamped backup of the whole config dir, then install
  2.  live-test           hyprctl reload + configerrors + "is the file I wrote the one you
                          loaded?"
  3.  on parse errors     restore the backup, reload again, report ROLLED_BACK

Step 0 is a FIRST net, not a replacement for 1-3: a config can parse offline and still fail
against a live compositor, so install / live-test / rollback stays exactly as it was behind it.

Read the final SAFE_APPLY= line. `ok` means installed, clean, AND the compositor confirms it is
what it loaded - not merely that it declined to complain.
"""
import os
import shutil
import sys

from .. import xdg
from . import configlang, installconfig, preflightconfig, removedkeys, verifyconfig


def _capture(fn, *args):
    import io
    from contextlib import redirect_stdout
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = fn(*args)
    return rc, buf.getvalue()


def _echo(text):
    if text:
        print(text, end="" if text.endswith("\n") else "\n")


def _field(text, key):
    for line in text.splitlines():
        if line.startswith(key):
            return line[len(key):]
    return ""


def main(argv):
    staging = argv[1] if len(argv) > 1 else ""
    if not staging:
        print("ERROR: usage: safe-apply.sh <staging-dir>", file=sys.stderr)
        return 2

    # The SAME resolution install/backup/reset use. This is where a split would be lethal: a
    # rollback that restores into a different directory from the one the backup came out of has
    # no inverse.
    target = xdg.config_target("hypr", os.environ.get("HYPR_DIR", ""))
    if target is None:
        print("SAFE_APPLY=no-config-dir (nothing was checked, backed up or written)")
        return 2

    # --- 0. removed keys -------------------------------------------------------------------
    rk_rc, rk_out = _capture(removedkeys.main, ["validate-removed-keys", staging])
    _echo(rk_out)
    if rk_rc == 1:
        print(f"Nothing was installed and nothing was backed up; {target} is untouched.")
        print("SAFE_APPLY=removed-keys-failed (the staged config sets a key removed at the "
              "target version)")
        return 2
    if rk_rc == 3:
        print("The removed-key check reached NO verdict (the target version is unknown); the "
              "checks below do not depend on one.")

    # --- 0b. offline preflight --------------------------------------------------------------
    pf_rc, pf_out = _capture(preflightconfig.main, ["preflight-config", staging])
    _echo(pf_out)
    if pf_rc == 1:
        print(f"Nothing was installed and nothing was backed up; {target} is untouched.")
        print("SAFE_APPLY=preflight-failed (the offline check found errors in the staged config)")
        return 2
    if pf_rc not in (0, 2):
        print(f"Nothing was installed and nothing was backed up; {target} is untouched.")
        print("SAFE_APPLY=preflight-uncheckable (the offline check could not be run against the "
              "staged config)")
        return 2

    # --- 1. install ---------------------------------------------------------------------------
    inst_rc, inst_out = _capture(installconfig.main, ["install-config", staging])
    _echo(inst_out)
    if inst_rc != 0:
        # 3 and 4 are install-config's REFUSALS: it declined before changing anything. Never let
        # that read as an ordinary failure, and never as ok.
        if inst_rc in (3, 4):
            print("SAFE_APPLY=refused (install-config declined; nothing was changed)")
            return 2
        print("SAFE_APPLY=install-failed")
        return 2

    backup = _field(inst_out, "BACKUP=")
    installed_lang = _field(inst_out, "CONFIG_LANGUAGE=")
    installed_target = _field(inst_out, "TARGET=") or target

    installed_main = ""
    if installed_lang:
        name = configlang.lang_file(installed_lang)
        if name:
            installed_main = f"{installed_target}/{name}"

    # --- 2. live-test ---------------------------------------------------------------------------
    # --expect makes `ok` mean "the compositor says it loaded THIS file", not "the compositor
    # declined to complain".
    args = ["verify-config"] + (["--expect", installed_main] if installed_main else [])
    v_rc, v_out = _capture(verifyconfig.main, args)
    _echo(v_out)

    if v_rc == 0:
        print("SAFE_APPLY=ok")
        return 0
    if v_rc == 2:
        print("SAFE_APPLY=installed-untested (no running Hyprland; relied on static validation)")
        return 0
    if v_rc == 3:
        # Installed cleanly, but the running compositor is not reading it. Rolling back would be
        # wrong - the config is not the thing that is broken - and reporting ok would be a
        # success message for a change that never reached the compositor.
        print(f"The file above is what the compositor loaded; {installed_main} is on disk but is "
              "not what is running.")
        print("SAFE_APPLY=unconfirmed (installed with no parse errors, but the compositor did "
              "not confirm it loaded it)")
        return 1

    # --- 3. parse errors: roll back ---------------------------------------------------------------
    if backup.startswith("/") and os.path.isdir(backup):
        # Restore WITHOUT emptying the target dir. A running Hyprland regenerates a STUB config
        # the instant the config dir goes empty, which races the removal and leaves a
        # nested-backup mess. Instead: copy every backup file back over the target, then prune
        # only the files the failed config ADDED. The dir is never empty.
        shutil.copytree(backup, target, symlinks=True, dirs_exist_ok=True)
        for dirpath, _dirs, files in os.walk(target):
            for n in files:
                full = os.path.join(dirpath, n)
                rel = os.path.relpath(full, target)
                if not os.path.lexists(os.path.join(backup, rel)):
                    try:
                        os.remove(full)
                    except OSError:
                        pass
        _capture(verifyconfig.main, ["verify-config"])   # reload the restored config
        print(f"SAFE_APPLY=rolled-back (new config had errors; restored {backup})")
        return 1

    print("SAFE_APPLY=errors-no-backup (new config has parse errors; no backup existed to restore)")
    print(f"Inspect {target} and fix, or remove the generated files.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
