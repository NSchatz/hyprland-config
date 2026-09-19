#!/usr/bin/env python3
"""Derive the rice palette from a wallpaper.

Three generators, in order of quality for this purpose: matugen (Material You, the default in
the modern corpus), then wallust, then pywal. The first that produces a palette wins; if none
does, the EXISTING palette is kept rather than replaced with something worse.

`high-contrast-*` schemes are a deliberate exception. They are FIXED WCAG-AAA palettes, so a
wallpaper must not re-derive them - the wallpaper is recorded and the palette is left exactly
as it is, which is what keeps an accessibility choice from being undone by a pretty picture.

Usage: palette-from-wallpaper.sh <image>
Env:   MATUGEN_TYPE (scheme-tonal-spot), MATUGEN_MODE (dark), MATUGEN_PREFER (saturation)
Exit:  0 palette written (or deliberately skipped), 2 bad usage, 3 no generator produced one.
"""
import json
import os
import subprocess
import sys
import tempfile

from .. import xdg
from ..proc import expand_user, have, ok


def _read_scheme(pal):
    try:
        with open(pal, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if line.startswith("scheme="):
                    return line[len("scheme="):].strip()
    except OSError:
        pass
    return ""


def _record_wallpaper_only(pal, img):
    """Keep every line, replacing or appending just `wallpaper=`."""
    lines, seen = [], False
    try:
        with open(pal, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if line.startswith("wallpaper="):
                    lines.append(f"wallpaper={img}")
                    seen = True
                else:
                    lines.append(line)
    except OSError:
        return False
    if not seen:
        lines.append(f"wallpaper={img}")
    try:
        with open(pal, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    except OSError:
        return False
    return True


def _from_json(path, img, out):
    """wallust / pywal write the same colors.json shape."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return False
    sp = data.get("special", {})
    co = data.get("colors", {})

    def h(x):
        return (x or "").lstrip("#")

    lines = ["scheme=wallpaper",
             f"bg={h(sp.get('background'))}",
             f"fg={h(sp.get('foreground'))}",
             f"cursor={h(sp.get('cursor') or sp.get('foreground'))}"]
    for i in range(16):
        lines.append(f"color{i}={h(co.get('color' + str(i)))}")
    lines += [f"red={h(co.get('color1'))}", f"green={h(co.get('color2'))}",
              f"yellow={h(co.get('color3'))}", f"blue={h(co.get('color4'))}",
              f"magenta={h(co.get('color5'))}", f"cyan={h(co.get('color6'))}",
              f"accent={h(co.get('color4'))}", f"accent2={h(co.get('color5'))}",
              f"surface={h(co.get('color8') or sp.get('background'))}",
              f"muted={h(co.get('color8'))}", f"wallpaper={img}"]
    try:
        with open(out, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    except OSError:
        return False
    return True


def main(argv):
    env = os.environ
    rice_dir = xdg.config_target("hypr-rice", env.get("RICE_DIR", ""))
    if rice_dir is None:
        print("PALETTE=refused-no-config-dir", file=sys.stderr)
        return 2

    img = argv[1] if len(argv) > 1 else ""
    if not img:
        print("ERROR: usage: palette-from-wallpaper.sh <image>", file=sys.stderr)
        return 2
    img = expand_user(img, env)
    if not os.path.isfile(img):
        print(f"ERROR: no such image: {img}", file=sys.stderr)
        return 2

    pal = f"{rice_dir}/palette.conf"

    scheme = _read_scheme(pal) if os.path.isfile(pal) else ""
    if scheme.startswith("high-contrast-"):
        _record_wallpaper_only(pal, img)
        print(f"PALETTE=skipped (scheme={scheme} - fixed AAA palette; wallpaper recorded)")
        return 0

    # --- matugen ---------------------------------------------------------------------------
    if have("matugen"):
        tmpl = f"{rice_dir}/templates/palette.matugen.tmpl"
        if os.path.isfile(tmpl):
            out = f"{rice_dir}/.palette.matugen.out"
            cfg = ""
            try:
                fd, cfg = tempfile.mkstemp(suffix=".toml")
                # matugen 4.x needs a [config] table, and --prefer, or a multi-source-colour
                # image errors out headlessly.
                with os.fdopen(fd, "w") as fh:
                    fh.write("[config]\n\n[templates.palette]\n"
                             f"input_path = '{tmpl}'\noutput_path = '{out}'\n")
                good = ok(["matugen", "image", img, "--config", cfg,
                           "--type", env.get("MATUGEN_TYPE", "scheme-tonal-spot"),
                           "--mode", env.get("MATUGEN_MODE", "dark"),
                           "--prefer", env.get("MATUGEN_PREFER", "saturation")])
                if good and os.path.isfile(out):
                    with open(out, encoding="utf-8", errors="replace") as fh:
                        body = fh.read().replace("=#", "=")
                    with open(pal, "w", encoding="utf-8") as fh:
                        fh.write(body)
                        if not body.endswith("\n"):
                            fh.write("\n")
                        fh.write(f"wallpaper={img}\n")
                    print("PALETTE=ok (matugen)")
                    return 0
                print("PALETTE_WARN: matugen run failed, trying pywal/wallust", file=sys.stderr)
            finally:
                for f in (cfg, out):
                    if f and os.path.exists(f):
                        try:
                            os.remove(f)
                        except OSError:
                            pass

    # --- wallust / pywal --------------------------------------------------------------------
    ran = ""
    if have("wallust") and ok(["wallust", "run", img]):
        ran = "wallust"
    if not ran and have("wal") and ok(["wal", "-n", "-s", "-t", "-e", "-i", img]):
        ran = "pywal"

    home = env.get("HOME", "")
    for cand in (f"{home}/.cache/wal/colors.json", f"{home}/.cache/wallust/colors.json"):
        if os.path.isfile(cand) and _from_json(cand, img, pal):
            print(f"PALETTE=ok ({ran} json)")
            return 0

    print("PALETTE=skipped (no generator produced a palette; install matugen or wallust). "
          "Existing palette kept.", file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
