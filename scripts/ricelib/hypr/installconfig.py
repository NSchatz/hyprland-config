#!/usr/bin/env python3
"""Install a staged config set into the hypr config directory - after refusing every way it
could silently not take effect.

The refusals are the point. Since Hyprland 0.55 a `hyprland.lua` is loaded INSTEAD OF
`hyprland.conf`, so installing a hyprlang config into a directory that already holds a lua one
would report success for a change the compositor never reads. That, a staging dir holding both
languages, a target that is not a directory, one that cannot be written, and a backup that
cannot be taken are all refusals that change NOTHING.

Usage: install-config.sh <staging-dir>
Exit:  0 installed, 2 bad usage / no config dir, 3 refused (ambiguous, mixed, shadowed),
       4 refused (target unusable, backup failed).
"""
import os
import re
import shutil
import sys

from .. import xdg
from ..clock import unique_backup
from . import configlang

RANGE_RE = re.compile(r"^[#-][#-]*\s*CONFIG_LANGUAGE_RANGE=(.*)$")


def _glob(d, ext):
    try:
        return sorted(f"{d}/{n}" for n in os.listdir(d) if n.endswith(ext))
    except OSError:
        return []


def main(argv):
    staging = argv[1] if len(argv) > 1 else ""
    if not staging:
        print("ERROR: missing <staging-dir> argument", file=sys.stderr)
        return 2
    if not os.path.isdir(staging):
        print(f"ERROR: staging dir '{staging}' does not exist", file=sys.stderr)
        return 2

    has_conf = os.path.lexists(f"{staging}/hyprland.conf")
    has_lua = os.path.lexists(f"{staging}/hyprland.lua")

    if has_conf and has_lua:
        print(f"ERROR: staging dir '{staging}' holds BOTH a hyprland.lua and a hyprland.conf.",
              file=sys.stderr)
        print("       Hyprland loads hyprland.lua and IGNORES hyprland.conf, so installing both",
              file=sys.stderr)
        print("       would quietly make the .conf dead. Stage exactly one config language.",
              file=sys.stderr)
        print("REFUSED=ambiguous-staging")
        return 3

    if has_lua:
        language, config_files, stray, stray_lang = "lua", _glob(staging, ".lua"), _glob(staging, ".conf"), "hyprlang"
    elif has_conf:
        language, config_files, stray, stray_lang = "hyprlang", _glob(staging, ".conf"), _glob(staging, ".lua"), "lua"
    else:
        print("ERROR: staging dir is missing a main config (no hyprland.lua and no hyprland.conf)",
              file=sys.stderr)
        return 2

    if not config_files:
        print(f"ERROR: no config files found in '{staging}'", file=sys.stderr)
        return 2

    if stray:
        print(f"ERROR: staging dir '{staging}' holds a {language} config plus {len(stray)} "
              f"{stray_lang} file(s).", file=sys.stderr)
        print(f"       Only the {language} files would be installed and the rest would be dropped",
              file=sys.stderr)
        print("       without a word. Stage exactly one config language:", file=sys.stderr)
        for f in stray:
            print(f"STRAY={os.path.basename(f)}")
        print("REFUSED=mixed-staging")
        return 3

    target = xdg.config_target("hypr", os.environ.get("HYPR_DIR", ""))
    if target is None:
        print("REFUSED=no-config-directory")
        return 2

    if language == "hyprlang" and os.path.lexists(f"{target}/hyprland.lua"):
        print(f"ERROR: '{target}/hyprland.lua' already exists.", file=sys.stderr)
        print("       Since Hyprland 0.55 a hyprland.lua TAKES PRECEDENCE over hyprland.conf:",
              file=sys.stderr)
        print("       the lua config is loaded and the .conf is ignored. Installing a hyprlang",
              file=sys.stderr)
        print("       .conf here would report success for a change the compositor never reads.",
              file=sys.stderr)
        print(f"       Emit a lua config instead, or move '{target}/hyprland.lua' aside first.",
              file=sys.stderr)
        print(f"SHADOWED_BY={target}/hyprland.lua")
        print("PRECEDENCE=hyprland.lua takes precedence over hyprland.conf")
        print(f"TARGET={target}")
        print("REFUSED=lua-config-takes-precedence")
        return 3

    if os.path.lexists(target) and not os.path.isdir(target):
        print(f"ERROR: install target '{target}' exists but is not a directory.", file=sys.stderr)
        print(f"TARGET={target}")
        print("REFUSED=target-not-a-directory")
        return 4

    if os.path.isdir(target) and not os.access(target, os.W_OK):
        print(f"ERROR: install target '{target}' exists but cannot be written to "
              "(permission denied).", file=sys.stderr)
        print("       Nothing was changed. Fix the permissions on that directory and re-run.",
              file=sys.stderr)
        print(f"TARGET={target}")
        print("REFUSED=target-not-writable")
        return 4

    try:
        has_content = os.path.isdir(target) and bool(os.listdir(target))
    except OSError:
        has_content = False

    if has_content:
        backup = unique_backup(target)
        try:
            shutil.copytree(target, backup, symlinks=True, dirs_exist_ok=False)
        except (OSError, shutil.Error):
            print(f"ERROR: could not back up '{target}' to '{backup}'; nothing was changed.",
                  file=sys.stderr)
            print(f"TARGET={target}")
            print("REFUSED=backup-failed")
            return 4
        print(f"BACKUP={backup}")
    else:
        print("BACKUP=none (no existing config to back up)")

    staged_main = f"{staging}/{configlang.lang_file(language)}"
    rng = ""
    try:
        with open(staged_main, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = RANGE_RE.match(line.rstrip("\n"))
                if m:
                    rng = m.group(1)
                    break
    except OSError:
        pass
    if not rng:
        rng = configlang.lang_range(language)

    print(f"CONFIG_LANGUAGE={language}")
    print(f"CONFIG_LANGUAGE_RANGE={rng}")

    os.makedirs(target, exist_ok=True)
    for f in config_files:
        shutil.copyfile(f, f"{target}/{os.path.basename(f)}")
        print(f"INSTALLED={os.path.basename(f)}")

    # A config that outlives the session that made it should still say what wrote it and which
    # language it is, so a later reader is not left guessing which file the compositor reads.
    installed_main = f"{target}/{configlang.lang_file(language)}"
    if os.path.isfile(installed_main):
        try:
            with open(installed_main, encoding="utf-8", errors="replace") as fh:
                body = fh.read()
            if "CONFIG_LANGUAGE=" not in body:
                with open(installed_main, "w", encoding="utf-8") as fh:
                    fh.write(configlang.provenance(language) + "\n" + body)
                print(f"PROVENANCE=added to {os.path.basename(installed_main)}")
        except OSError:
            pass

    print(f"TARGET={target}")
    print("DONE=ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
