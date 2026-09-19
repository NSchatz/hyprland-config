#!/usr/bin/env python3
"""Restart Firefox so it picks up a re-rendered userChrome.

Firefox reads `chrome/` only at startup, so a re-theme does not show until it restarts. This
waits for the profile to be genuinely released before starting it again: `.parentlock` outliving
the process is what causes the "Firefox is already running" dialog, and starting into that is
worse than not restarting at all.

Output: FIREFOX_RESTART=ok | skipped (not running) | stuck (still running after 5s)
Exit:   0 always - a browser that will not close is reported, not treated as a failed apply.
"""
import os
import subprocess
import sys
import time

from .firefoxbootstrap import resolve_default_profile
from .proc import ok, running


def main(argv):
    if not running("firefox"):
        print("FIREFOX_RESTART=skipped (not running)")
        return 0

    ok(["pkill", "-x", "firefox"])

    home = os.environ.get("HOME", "")
    profile_dir = resolve_default_profile(f"{home}/.mozilla/firefox/profiles.ini")
    if profile_dir and not profile_dir.startswith("/"):
        profile_dir = f"{home}/.mozilla/firefox/{profile_dir}"

    # Both conditions matter: the process gone AND the profile lock released.
    for _ in range(10):
        if not running("firefox"):
            if profile_dir and os.path.lexists(f"{profile_dir}/.parentlock"):
                time.sleep(0.5)
                continue
            break
        time.sleep(0.5)

    if running("firefox"):
        print("FIREFOX_RESTART=stuck (Firefox still running after 5s; restart manually)",
              file=sys.stderr)
        return 0

    try:
        subprocess.Popen(["firefox"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        print("FIREFOX_RESTART=stuck (firefox could not be started)", file=sys.stderr)
        return 0
    print("FIREFOX_RESTART=ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
