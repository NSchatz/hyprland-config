#!/usr/bin/env python3
"""The preferences a config restore cannot undo, recorded and removable.

Firefox re-applies `user.js` at every start and hides those values from its own UI, so a
preference this plugin merged there is not undone by putting a config file back - and nothing
told the user how to undo it. This records which preferences were merged, against that profile's
absolute path, and ships the way back.

It records only what it actually merged: a key already present and left at the user's value is
never recorded, because this did not set it and must not remove it.

    firefox-prefs.sh record <profile> <user_pref line>   record one merged preference
    firefox-prefs.sh list                                what is recorded, and whether still set
    firefox-prefs.sh remove [profile]                    remove them again
    firefox-prefs.sh where                               the record's path

`remove` backs each profile file up before editing it (enrolled in a restore point, so the
removal itself goes back with `rice restore <apply-id>`), removes ONLY the recorded lines leaving
every other byte identical, leaves a line changed by hand alone and reports it rather than
deleting the user's value, reports a profile file that is gone by path without creating it, and
on a second run says there is nothing left to remove.

Removing `toolkit.legacyUserProfileCustomizations.stylesheets` turns the browser theming off
entirely, which is why this is a command you run rather than something that happens to you.

Exit: 0 done, 1 something was skipped, 2 usage / no restore library, 3 nothing to remove.
"""
import os
import re
import sys

from . import restorepoint as rp
from .clock import iso_utc

PREF_KEY_RE = re.compile(r'^\s*user_pref\("([^"]*)"')


def record_file(env=None):
    env = os.environ if env is None else env
    override = env.get("RICE_PREF_RECORD")
    if override:
        return override
    return f"{rp.state_root(env)}/browser-prefs.tsv"


def pref_key(line):
    m = PREF_KEY_RE.match(line or "")
    return m.group(1) if m else ""


def _rows(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                raw = raw.rstrip("\n")
                if not raw:
                    continue
                parts = raw.split("\t")
                while len(parts) < 4:
                    parts.append("")
                yield parts[0], parts[1], parts[2], parts[3]
    except OSError:
        return


def record(profile, line, env=None):
    """Record one preference as set in one profile. Idempotent: the same profile+key once.

    Returns (ok, error). A False is the caller's cue NOT to set the preference: a preference
    merged with no record of it is exactly what this component exists to prevent."""
    key = pref_key(line)
    if not profile or not key:
        return False, "a preference record needs a profile path and a user_pref line"
    # TABs are the record's field separator; a pref line has none, but never trust that.
    line = (line or "").replace("\t", "")
    f = record_file(env)
    try:
        os.makedirs(os.path.dirname(f), exist_ok=True)
    except OSError:
        return False, f"the preference record directory could not be created: {os.path.dirname(f)}"
    for p, k, _l, _w in _rows(f):
        if p == profile and k == key:
            return True, ""
    try:
        with open(f, "a", encoding="utf-8") as fh:
            fh.write(f"{profile}\t{key}\t{line}\t{iso_utc(env)}\n")
    except OSError:
        return False, f"the preference record could not be written: {f}"
    return True, ""


def _file_lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read().split("\n")
    except OSError:
        return None


def cmd_list(env=None):
    f = record_file(env)
    rows = list(_rows(f))
    if not rows:
        print(f"(no browser preference is recorded under {f})")
        return 0
    for profile, key, line, _when in rows:
        target = f"{profile}/user.js"
        content = _file_lines(target)
        if content is None:
            state = "profile file missing"
        elif line in content:
            state = "still set"
        elif any(f'user_pref("{key}"' in l for l in content):
            state = "changed by hand"
        else:
            state = "already removed"
        print(f"{target}\t{key}\t{state}")
    return 0


def cmd_remove(only="", env=None):
    env = os.environ if env is None else env
    f = record_file(env)
    rows = list(_rows(f))
    if not rows:
        print(f"PREFS=nothing-to-remove (no browser preference is recorded under {f}: this "
              "plugin has set none, or they have already been removed)")
        return 3

    profiles = []
    for p, _k, _l, _w in rows:
        if (not only or p == only) and p not in profiles:
            profiles.append(p)
    if not profiles:
        print(f"PREFS=nothing-to-remove (nothing is recorded for {only or 'any profile'} under {f})")
        return 3

    # Entries that survive: everything for a profile not being touched, plus hand-changed lines.
    keep = [r for r in rows if only and r[0] != only]
    removed = changed = missing = untouched = skipped = 0
    edited = False

    for p in profiles:
        target = f"{p}/user.js"
        content = _file_lines(target)
        if content is None:
            # Recorded, but gone. Say so by path, create nothing, carry on - and KEEP the record,
            # because nothing was removed and that file may yet come back.
            print(f"PREFS_MISSING={target} (recorded, but that file is not there; nothing was created)")
            keep.extend(r for r in rows if r[0] == p)
            missing += 1
            continue

        to_remove, staged = [], []
        this_changed = False
        for rprofile, key, line, when in rows:
            if rprofile != p:
                continue
            if line in content:
                to_remove.append(line)
                staged.append((rprofile, key, line, when))
            elif any(f'user_pref("{key}"' in l for l in content):
                # The key is still there but the line is not the one this plugin wrote: the user
                # changed the value. That value is theirs; report it, keep the record, move on.
                print(f"PREF_CHANGED={target} {key} (changed by hand since this plugin set it; "
                      "left alone)")
                keep.append((rprofile, key, line, when))
                changed += 1
                this_changed = True
            # Neither present nor changed: already gone, so it leaves the record.

        if not to_remove:
            if not this_changed:
                print(f"PREFS_NOTHING={target} (nothing this plugin recorded is still set there; "
                      "the file was not touched)")
                untouched += 1
            continue

        # Back up before editing, or do not edit. The rule every writer in this plugin follows.
        res = rp.protect(target, env)
        if not res.ok:
            print(f"PREFS_SKIPPED={target} ({res.error})")
            keep.extend(staged)          # still set, so still recorded
            skipped += 1
            continue

        # Exact whole-line matches only, so every other byte of the file survives untouched.
        drop = set(to_remove)
        filtered = [l for l in content if l not in drop]
        try:
            # Write back through the existing file so its permissions and inode survive the edit.
            with open(target, "w", encoding="utf-8") as fh:
                fh.write("\n".join(filtered))
        except OSError:
            print(f"PREFS_SKIPPED={target} (the file could not be rewritten)")
            keep.extend(staged)
            skipped += 1
            continue

        for line in to_remove:
            print(f"PREF_REMOVED={target} {pref_key(line)}")
            removed += 1
        edited = True

    # Rewrite the record: what was removed is no longer set, so it is no longer recorded.
    try:
        with open(f, "w", encoding="utf-8") as fh:
            for r in keep:
                fh.write("\t".join(r) + "\n")
    except OSError:
        pass

    if edited and env.get("RICE_APPLY_ID"):
        print(f"RESTORE_POINT={env['RICE_APPLY_ID']}")
    print(f"PREFS=removed:{removed} changed:{changed} missing:{missing} untouched:{untouched}")
    return 1 if skipped else 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "help"
    args = argv[2:]

    if cmd == "where":
        print(record_file())
        return 0
    if cmd == "list":
        return cmd_list()
    if cmd == "record":
        if len(args) < 2:
            print("ERROR: usage: firefox-prefs.sh record <profile> <user_pref line>",
                  file=sys.stderr)
            return 2
        ok, err = record(args[0], args[1])
        if ok:
            print(f"PREF_RECORDED={args[0]}/user.js {pref_key(args[1])}")
            return 0
        print(f"PREF_RECORD_FAILED={record_file()} ({err})", file=sys.stderr)
        return 1
    if cmd == "remove":
        return cmd_remove(args[0] if args else "")
    if cmd in ("help", "-h", "--help"):
        print(__doc__.strip())
        return 0

    print(f"unknown command: {cmd} (try: firefox-prefs.sh help)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
