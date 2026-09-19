#!/usr/bin/env python3
"""The render pass: one palette -> every app's colors file -> reload what is running.

This is what makes the rice ONE theme rather than a pile of separately-coloured apps.
`palette.conf` is the source of truth; `templates.list` says which template renders to which
output and how to reload the app afterwards; `palette.user.conf` is the user's override layer
and is applied LAST, so a pinned colour survives every theme and wallpaper change.

Every output is backed up and enrolled in the apply's restore point BEFORE it is written. A
surface whose backup cannot be taken is NOT rendered - it is reported as `RENDER_SKIPPED` and
the rest of the manifest still applies. That is the same fail-safe every writer here follows:
never overwrite what you could not first make recoverable.

Manifest rows are TAB-separated:
    <name> <TAB> <template> <TAB> <output> <TAB> <reload-cmd> [<TAB> <next-x hint>]
The 5th column groups surfaces that cannot reload live (`next-launch`, `next-lock`,
`server-restart`) into one footer line, so the user is told once rather than per surface.

Usage: render-templates.sh [--no-reload] [<palette>] [<manifest>]
Exit:  0 rendered, 2 no config dir / missing palette or manifest.
"""
import os
import shutil
import subprocess
import sys

from .. import xdg
from .. import restorepoint as rp
from ..proc import have

HINT_LABELS = {
    "next-launch": "next launch",
    "next-lock": "next lock",
    "server-restart": "server restart",
    "restart": "restart",
}


def load_kv(path, into):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if not line or line.lstrip().startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                into["".join(k.split())] = v
    except OSError:
        pass


def render_one(tmpl, out, palette):
    try:
        with open(tmpl, encoding="utf-8", errors="replace") as fh:
            content = fh.read()
    except OSError:
        return False
    for k, v in palette.items():
        content = content.replace("{{" + k + "}}", v)
    try:
        parent = os.path.dirname(out)
        if parent:
            os.makedirs(parent, exist_ok=True)
        # A symlinked output is REPLACED, not written through. gtk-4.0/gtk.css is commonly a
        # root-owned symlink into a theme; writing through it either fails with permission
        # denied or edits somebody else's file.
        if os.path.islink(out):
            os.remove(out)
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(content)
    except OSError:
        return False
    return True


def write_restore_script(rice_dir, env):
    """A login-time re-apply for the DYNAMIC engines.

    matugen/wallust derive the palette from the wallpaper at apply time. After a reboot the
    wallpaper daemon starts fresh, so without this the desktop comes back with the rendered
    colors but no wallpaper behind them."""
    engine = env.get("RICE_THEMING_ENGINE", "")
    if engine in ("", "none"):
        return
    reapply = {
        "matugen": 'matugen --prefer image image "$wp"',
        "wallust": 'wallust run -s "$wp"',
        "wallbash": f'{env.get("HOME", "")}/.local/share/bin/swwwallpaper.sh -s "$wp"',
    }.get(engine)
    if reapply is None:
        print(f"RESTORE_SCRIPT_SKIPPED unknown engine: {engine}", file=sys.stderr)
        return
    try:
        hypr_dir = xdg.config_path("hypr", env.get("HYPR_DIR", ""), env)
    except xdg.NoConfigDirError:
        print("RESTORE_SCRIPT_SKIPPED no config directory could be determined", file=sys.stderr)
        return

    out = f"{hypr_dir}/scripts/restore-theme.sh"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    body = f'''set -e
wp=$(awk -F= '$1=="wallpaper"{{print $2}}' "{rice_dir}/palette.conf")
[ -n "$wp" ] && [ -f "$wp" ] || exit 0
swww_bin=$(command -v awww-daemon >/dev/null && echo awww || echo swww)
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x "${{swww_bin}}-daemon" >/dev/null && break
  sleep 0.2
done
"$swww_bin" img "$wp" || true
{reapply}
'''
    try:
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(body)
        os.chmod(out, 0o755)
    except OSError:
        print(f"RESTORE_SCRIPT_SKIPPED {out} (could not be written)", file=sys.stderr)
        return
    print(f"RESTORE_SCRIPT={out} (engine={engine})")


def write_lock_blur(palette_path, env):
    """Pre-blur the wallpaper for hyprlock, which has no blur of its own worth the frame time."""
    if env.get("RICE_LOCK_BLUR", "") != "pre-baked":
        return
    wp = ""
    try:
        with open(palette_path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if line.startswith("wallpaper="):
                    wp = line[len("wallpaper="):].strip()
                    break
    except OSError:
        pass
    if not wp or not os.path.isfile(wp):
        print(f"LOCK_BLUR_SKIPPED no wallpaper in {palette_path}")
        return
    # XDG_CACHE_HOME's base directory, deliberately NOT the config one: a cache is a separate
    # base directory with a separate default.
    out = f"{env.get('HOME', '')}/.cache/hypr-rice/lock-blur.png"
    im = "magick" if have("magick") else ("convert" if have("convert") else "")
    if not im:
        print("LOCK_BLUR_SKIPPED ImageMagick not installed (install 'imagemagick'); hyprlock "
              "will see a missing file", file=sys.stderr)
        return
    os.makedirs(os.path.dirname(out), exist_ok=True)
    res = rp.protect(out, env)
    if not res.ok:
        print(f"LOCK_BLUR_SKIPPED {out} ({res.error})", file=sys.stderr)
        return
    try:
        rc = subprocess.run([im, wp, "-resize", "2560x>", "-blur", "0x12", out],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
    except (OSError, subprocess.SubprocessError):
        rc = 1
    if rc == 0:
        print(f"LOCK_BLUR={out} ({im})")
    else:
        print(f"LOCK_BLUR_FAILED {im} exited non-zero - keep the previous cache", file=sys.stderr)


def main(argv):
    env = os.environ
    rice_dir = xdg.config_target("hypr-rice", env.get("RICE_DIR", ""))
    if rice_dir is None:
        print("RENDER=refused-no-config-dir (no config directory could be determined; nothing "
              "was rendered)")
        return 2

    args = argv[1:]
    reload_apps = True
    if args and args[0] == "--no-reload":
        reload_apps = False
        args = args[1:]

    palette_path = args[0] if len(args) > 0 else f"{rice_dir}/palette.conf"
    manifest_path = args[1] if len(args) > 1 else f"{rice_dir}/templates.list"

    if not os.path.isfile(palette_path):
        print(f"ERROR: palette not found: {palette_path}", file=sys.stderr)
        return 2
    if not os.path.isfile(manifest_path):
        print(f"ERROR: manifest not found: {manifest_path}", file=sys.stderr)
        return 2

    palette = {}
    load_kv(palette_path, palette)
    # The override layer wins: a pinned colour must survive a theme switch.
    load_kv(f"{rice_dir}/palette.user.conf", palette)

    next_groups = {}
    try:
        with open(manifest_path, encoding="utf-8", errors="replace") as fh:
            rows = fh.read().split("\n")
    except OSError:
        print(f"ERROR: manifest not readable: {manifest_path}", file=sys.stderr)
        return 2

    for row in rows:
        if not row or row.lstrip().startswith("#"):
            continue
        cells = row.split("\t")
        while len(cells) < 5:
            cells.append("")
        name, tmpl, out, rcmd, hint = cells[0], cells[1], cells[2], cells[3], cells[4]
        if not name:
            continue
        tmpl = xdg.expand_path(tmpl, env)[0]
        out = xdg.expand_path(out, env)[0]

        if not os.path.isfile(tmpl):
            print(f"SKIP {name} (no template: {tmpl})")
            continue

        res = rp.protect(out, env)
        if not res.ok:
            print(f"RENDER_SKIPPED {name} -> {out} ({res.error})")
            continue

        if not render_one(tmpl, out, palette):
            print(f"RENDER_FAILED {name} -> {out} (the output could not be written)")
            continue

        print(f"RENDERED {name} -> {out}")

        if reload_apps and rcmd:
            try:
                rc = subprocess.run(rcmd, shell=True, stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL).returncode
            except (OSError, subprocess.SubprocessError):
                rc = 1
            print(f"RELOADED {name}" if rc == 0 else f"RELOAD_SKIPPED {name}")

        if hint:
            next_groups.setdefault(hint, []).append(name)

    for hint, names in next_groups.items():
        label = HINT_LABELS.get(hint, hint)
        if len(names) == 1:
            print(f"1 surface applies on {label}: {names[0]}")
        else:
            print(f"{len(names)} surfaces apply on {label}: {', '.join(names)}")

    write_restore_script(rice_dir, env)
    write_lock_blur(palette_path, env)

    if env.get("RICE_APPLY_ID"):
        print(f"RESTORE_POINT={env['RICE_APPLY_ID']} (undo every file this apply wrote: "
              f"rice restore {env['RICE_APPLY_ID']})")
    print("RENDER=done")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
