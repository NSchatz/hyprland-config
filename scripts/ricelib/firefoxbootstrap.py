#!/usr/bin/env python3
"""One-time bootstrap for Firefox userChrome theming.

Resolves the default Firefox profile from `~/.mozilla/firefox/profiles.ini` (the directory name
is dynamic - `xxxxxxxx.default-release`), creates `<profile>/chrome/` if missing, copies the
static `userChrome.css` + `user.js` into place, and prints the resolved paths so the caller can
write the render-manifest line.

Usage:
    firefox-bootstrap.sh                      bootstrap the default profile
    firefox-bootstrap.sh --profile <dir>      bootstrap a specific profile
    firefox-bootstrap.sh --no-create-profile  do not auto-create one if missing

Output:
    FIREFOX_PROFILE=<abs>        resolved profile directory
    FIREFOX_CHROME=<abs>         the chrome/ subdir written
    FIREFOX_RICE_COLORS=<abs>    rice-colors.css render target
    RESTORE_POINT=<apply-id>     undo it: rice restore <apply-id>

Every profile file this touches is backed up first and enrolled in the apply's restore point,
under the SAME apply id as every other surface when RICE_APPLY_ID is exported by the caller. A
file whose backup cannot be written is NOT written at all (FIREFOX_SKIPPED).

Exit: 0 succeeded, 1 no profile and --no-create-profile, 2 bad args / no Firefox / a surface
could not be protected.
"""
import configparser
import os
import re
import shutil
import subprocess
import sys

from . import firefoxprefs as fp
from . import restorepoint as rp

PREF_RE = re.compile(r'^user_pref\("([^"]*)"')


def resolve_default_profile(profiles_ini):
    """The Default=1 profile, else the first [Profile...] block. `Path=` may be relative to the
    firefox dir or absolute."""
    if not os.path.isfile(profiles_ini):
        return ""
    cp = configparser.RawConfigParser()
    cp.optionxform = str
    try:
        cp.read(profiles_ini, encoding="utf-8")
    except (OSError, configparser.Error):
        return ""
    first = ""
    for section in cp.sections():
        if not section.startswith("Profile"):
            continue
        path = cp.get(section, "Path", fallback="")
        if not path:
            continue
        if not first:
            first = path
        if cp.get(section, "Default", fallback="") == "1":
            return path
    return first


def line_terminated(path):
    """True when the file is empty or its last byte is a newline.

    An append CONTINUES the last line of a file that does not end in one, which would glue a
    preference this sets onto the end of a line the user wrote. The line the record names would
    then exist nowhere in the file, so the documented removal path could never take it back off,
    and it would report this plugin's own write as one the user changed by hand."""
    try:
        if os.path.getsize(path) == 0:
            return True
        with open(path, "rb") as fh:
            fh.seek(-1, os.SEEK_END)
            return fh.read(1) == b"\n"
    except OSError:
        return True


def main(argv):
    assets = os.environ.get("RICE_FIREFOX_ASSETS", "")
    if not assets:
        here = os.path.dirname(os.path.abspath(argv[0])) if argv[0] else os.getcwd()
        assets = here
    profile_override = ""
    auto_create = True

    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]; i += 1
        if a == "--profile":
            profile_override = args[i] if i < len(args) else ""
            i += 1
        elif a == "--no-create-profile":
            auto_create = False
        elif a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        else:
            print(f"ERROR: unknown arg: {a}", file=sys.stderr)
            return 2

    if not shutil.which("firefox"):
        print("ERROR: firefox not installed", file=sys.stderr)
        return 2

    home = os.environ.get("HOME", "")
    ff_dir = f"{home}/.mozilla/firefox"
    profiles_ini = f"{ff_dir}/profiles.ini"

    profile_dir = profile_override or resolve_default_profile(profiles_ini)

    if not profile_dir:
        if not auto_create:
            print("ERROR: no Firefox profile found and --no-create-profile set", file=sys.stderr)
            print("       launch Firefox once, then re-run this script", file=sys.stderr)
            return 1
        # Firefox's documented headless CreateProfile flow: writes profiles.ini AND creates the
        # directory with a random prefix.
        try:
            subprocess.run(["firefox", "--headless", "--no-remote",
                            "--CreateProfile", "default-release"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        except (OSError, subprocess.SubprocessError):
            pass
        profile_dir = resolve_default_profile(profiles_ini)
        if not profile_dir:
            print("ERROR: --CreateProfile didn't produce a usable profile", file=sys.stderr)
            return 1

    if not profile_dir.startswith("/"):
        profile_dir = f"{ff_dir}/{profile_dir}"

    if not os.path.isdir(profile_dir):
        print(f"ERROR: resolved profile dir does not exist: {profile_dir}", file=sys.stderr)
        return 1

    chrome_dir = f"{profile_dir}/chrome"
    # A chrome/ dir this step CREATES is a surface this apply wrote too: enrol it so the restore
    # removes it again instead of leaving an empty orphan. An EXISTING one is left to the
    # per-file enrolments below - it was not created here, and folding its files into a
    # directory-wide backup would drop the per-file sidecars this step has always written.
    if not os.path.isdir(chrome_dir):
        res = rp.protect(chrome_dir)
        if not res.ok:
            print(f"FIREFOX_SKIPPED {chrome_dir} ({res.error})", file=sys.stderr)
            return 2
    os.makedirs(chrome_dir, exist_ok=True)

    # userChrome.css - do not clobber a user-modified one; append the @import instead.
    src_css = f"{assets}/userChrome.css"
    if os.path.isfile(src_css):
        target = f"{chrome_dir}/userChrome.css"
        res = rp.protect(target)
        if res.ok:
            existing = ""
            if os.path.exists(target):
                try:
                    with open(target, encoding="utf-8", errors="replace") as fh:
                        existing = fh.read()
                except OSError:
                    existing = ""
            if existing and "rice-colors.css" not in existing:
                with open(target, "a", encoding="utf-8") as fh:
                    fh.write('\n/* hypr-rice: pull in rice-colors.css */\n'
                             '@import "rice-colors.css";\n')
            else:
                shutil.copyfile(src_css, target)
        else:
            print(f"FIREFOX_SKIPPED {target} ({res.error})", file=sys.stderr)

    # user.js - merge prefs idempotently. Firefox re-applies every line here at each start and
    # shows none of them as changed in its own UI, so these are the writes a config restore
    # cannot undo. Each one ACTUALLY added is recorded against the profile's absolute path
    # BEFORE it is written. A pref already in the file is left alone and NOT recorded: this
    # plugin did not set it and must not offer to remove it.
    src_js = f"{assets}/user.js"
    if os.path.isfile(src_js):
        target = f"{profile_dir}/user.js"
        res = rp.protect(target)
        if res.ok:
            open(target, "a", encoding="utf-8").close()
            try:
                with open(target, encoding="utf-8", errors="replace") as fh:
                    current = fh.read()
            except OSError:
                current = ""
            record_failed = ""
            with open(src_js, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    line = line.rstrip("\n")
                    m = PREF_RE.match(line)
                    if not m:
                        continue
                    key = m.group(1)
                    if f'user_pref("{key}"' in current:
                        continue
                    ok, err = fp.record(profile_dir, line)
                    if not ok:
                        record_failed = err
                        break
                    if not line_terminated(target):
                        with open(target, "a", encoding="utf-8") as out:
                            out.write("\n")
                    with open(target, "a", encoding="utf-8") as out:
                        out.write(line + "\n")
                    current += line + "\n"
                    print(f"FIREFOX_PREF_SET={key}")
            if record_failed:
                # A preference that cannot be recorded is one nothing documents a way back from.
                # Stop merging rather than set one: what was already recorded and written is
                # still removable, and `rice restore <apply-id>` still covers the file.
                print(f"FIREFOX_PREFS_UNRECORDED {target} ({record_failed})", file=sys.stderr)
            print(f"FIREFOX_PREF_RECORD={fp.record_file()}")
        else:
            print(f"FIREFOX_SKIPPED {target} ({res.error})", file=sys.stderr)

    print(f"FIREFOX_PROFILE={profile_dir}")
    print(f"FIREFOX_CHROME={chrome_dir}")
    print(f"FIREFOX_RICE_COLORS={chrome_dir}/rice-colors.css")
    if os.environ.get("RICE_APPLY_ID"):
        print(f"RESTORE_POINT={os.environ['RICE_APPLY_ID']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
