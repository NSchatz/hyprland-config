#!/usr/bin/env python3
"""hypr-rice - the self-contained desktop theme engine CLI.

Installed beside the engine at `<config>/hypr-rice/` by rice-init, and deliberately STANDALONE:
it keeps working with the plugin removed, because everything it drives was copied next to it.

One palette is the source of truth. `apply` renders it into every app's colors file and reloads
what is running; `theme` swaps the whole palette plus its recorded wallpaper; `scheme` swaps only
the colors and KEEPS the wallpaper; `accent --pin` writes to the override layer, which survives
every later theme and wallpaper change.

Every apply opens ONE restore point, so `rice restore <id>` puts the whole change set back with
one command.
"""
import os
import random
import re
import shutil
import subprocess
import sys

from . import restorepoint as rp
from . import xdg
from .proc import have, ok, out

HEX_RE = re.compile(r"^[0-9a-fA-F]{6}$")
IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp")


def scheme_matches(row_scheme, want):
    """A catalog row matches a wanted scheme exactly, or as a family prefix either way:
    `catppuccin` wants `catppuccin-mocha`, and `catppuccin-mocha` accepts `catppuccin`."""
    if not want:
        return True
    return (row_scheme == want
            or row_scheme.startswith(want + "-")
            or want.startswith(row_scheme + "-"))


class Rice:
    def __init__(self):
        target = xdg.config_target("hypr-rice", os.environ.get("RICE_DIR", ""))
        if target is None:
            print("RICE=refused-no-config-dir", file=sys.stderr)
            raise SystemExit(2)
        self.dir = target
        self.palette = f"{self.dir}/palette.conf"
        self.user_palette = f"{self.dir}/palette.user.conf"

    # --- small file helpers -----------------------------------------------------------------
    def read_key(self, path, key):
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if line.startswith(key + "="):
                        return line[len(key) + 1:].strip()
        except OSError:
            pass
        return ""

    def set_key(self, path, key, value):
        """Replace `key=` in place, or append it. Every other byte of the file survives."""
        lines, seen = [], False
        if os.path.isfile(path):
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    for line in fh:
                        line = line.rstrip("\n")
                        if line.startswith(key + "="):
                            lines.append(f"{key}={value}")
                            seen = True
                        else:
                            lines.append(line)
            except OSError:
                return False
        if not seen:
            lines.append(f"{key}={value}")
        try:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write("\n".join(lines) + "\n")
        except OSError:
            return False
        return True

    def rows(self, name, min_fields):
        path = f"{self.dir}/{name}"
        if not os.path.isfile(path):
            return None
        out_rows = []
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    line = line.rstrip("\n")
                    if not line.strip() or line.lstrip().startswith("#"):
                        continue
                    cells = line.split("\t")
                    if len(cells) >= min_fields:
                        out_rows.append(cells)
        except OSError:
            return None
        return out_rows

    def run_component(self, name, *args):
        return subprocess.run(["bash", f"{self.dir}/{name}", *args]).returncode

    def render(self, *args):
        return self.run_component("render-templates.sh", *args)

    def profiles(self):
        d = f"{self.dir}/profiles"
        try:
            return sorted(n[:-5] for n in os.listdir(d) if n.endswith(".conf"))
        except OSError:
            return []


# --- commands ---------------------------------------------------------------------------------

def cmd_apply(r, args):
    # One restore point per apply: mint the id here so every stage shares it and
    # `rice restore <id>` puts the whole set back.
    if not os.environ.get("RICE_APPLY_ID"):
        os.environ["RICE_APPLY_ID"] = rp.new_id()
    r.render(*args)
    extra = f"{r.dir}/apply-extra.sh"
    if os.path.isfile(extra):
        subprocess.run(["bash", extra])
    return 0


def cmd_restore(r, args):
    comp = f"{r.dir}/rice-restore.sh"
    if not os.path.isfile(comp):
        print(f"no restore command installed ({comp}): re-run rice-init.sh", file=sys.stderr)
        return 1
    return r.run_component("rice-restore.sh", *args)


def cmd_installs(r, args):
    comp = f"{r.dir}/install-record.sh"
    if not os.path.isfile(comp):
        print(f"no install record component installed ({comp}): re-run rice-init.sh",
              file=sys.stderr)
        return 1
    return r.run_component("install-record.sh", "show", args[0]) if args \
        else r.run_component("install-record.sh", "list")


def cmd_prefs(r, args):
    comp = f"{r.dir}/firefox-prefs.sh"
    if not os.path.isfile(comp):
        print(f"no preference record component installed ({comp}): re-run rice-init.sh",
              file=sys.stderr)
        return 1
    sub = args[0] if args else "list"
    return r.run_component("firefox-prefs.sh", *( [sub] + args[1:] if sub in ("remove", "list")
                                                  else ["list"] ))


def cmd_wallpaper(r, args):
    if not args:
        print("usage: rice wallpaper <image> [--no-theme]", file=sys.stderr)
        return 1
    img = args[0]
    rest = args[1:]
    r.run_component("set-wallpaper.sh", img)
    # Setting a wallpaper is always the source of truth: persist it BEFORE any --no-theme
    # short-circuit, so the next apply/theme/save carries it.
    if os.path.isfile(r.palette):
        r.set_key(r.palette, "wallpaper", img)
    if "--no-theme" not in rest:
        if r.run_component("palette-from-wallpaper.sh", img) == 0:
            r.render()
    return 0


def cmd_random(r, args):
    d = args[0] if args else f"{os.environ.get('HOME', '')}/Pictures/wallpapers"
    found = []
    for dirpath, _dirs, files in os.walk(d):
        for n in files:
            if n.lower().endswith(IMAGE_EXT):
                found.append(os.path.join(dirpath, n))
    if not found:
        print(f"no images found in {d}", file=sys.stderr)
        return 1
    return cmd_wallpaper(r, [random.choice(found)])


def cmd_wallpapers(r, args):
    rows = r.rows("wallpapers.tsv", 4)
    if rows is None:
        print(f"no wallpaper catalog ({r.dir}/wallpapers.tsv)", file=sys.stderr)
        return 1
    want = args[0] if args else ""
    last, n = "", 0
    for scheme, name, width, url in (row[:4] for row in rows):
        if not (scheme_matches(scheme, want) or scheme == "any"):
            continue
        if scheme != last:
            print(f"\n[{scheme}]")
            last = scheme
        n += 1
        w = "?" if width == "?" else f"{width}px"
        print(f"  {n:2d}) {name:<26} {w:>6}  {url}")
    print()
    print("Download one with:  rice get-wallpaper <scheme> <number|name> [--set] [--min-res W]")
    return 0


def cmd_get_wallpaper(r, args):
    if len(args) < 2:
        print("usage: rice get-wallpaper <scheme> <number|name> [--set] [--dir DIR] "
              "[--min-res W]", file=sys.stderr)
        return 1
    scheme, sel = args[0], args[1]
    do_set, dest, min_res = False, f"{os.environ.get('HOME', '')}/Pictures/wallpapers", 0
    rest = args[2:]
    i = 0
    while i < len(rest):
        a = rest[i]; i += 1
        if a == "--set":
            do_set = True
        elif a == "--dir" and i < len(rest):
            dest = rest[i]; i += 1
        elif a == "--min-res" and i < len(rest):
            try:
                min_res = int(rest[i])
            except ValueError:
                min_res = 0
            i += 1

    rows = r.rows("wallpapers.tsv", 4)
    if rows is None:
        print(f"no wallpaper catalog ({r.dir}/wallpapers.tsv)", file=sys.stderr)
        return 1

    # Rows are listed descending by width per scheme, so the first match is the highest-res.
    # With --min-res, an unknown width (`?`) is dropped rather than gambled on.
    candidates = []
    for row in rows:
        rscheme, name, width, url = row[0], row[1], row[2], row[3]
        if not (scheme_matches(rscheme, scheme) or rscheme == "any"):
            continue
        w = 0 if width == "?" else (int(width) if width.isdigit() else 0)
        if min_res > 0 and w < min_res:
            continue
        candidates.append((name, url))

    if not candidates:
        print(f"no wallpapers for scheme '{scheme}' (see: rice wallpapers)", file=sys.stderr)
        return 1

    pick = None
    if sel.isdigit():
        idx = int(sel)
        if 1 <= idx <= len(candidates):
            pick = candidates[idx - 1]
    if pick is None:
        for name, url in candidates:
            if sel in name:
                pick = (name, url)
                break
    if pick is None:
        print(f"no match for '{sel}' in scheme '{scheme}' (see: rice wallpapers {scheme})",
              file=sys.stderr)
        return 1

    name, url = pick
    ext = url.rsplit(".", 1)[-1].lower()
    if ext not in ("jpg", "jpeg", "png", "webp"):
        ext = "jpg"
    os.makedirs(dest, exist_ok=True)
    target = f"{dest}/{scheme}-{name}.{ext}"
    print(f"Downloading {name} -> {target}")
    if not ok(["curl", "-fL", "--retry", "2", "--connect-timeout", "20", "-o", target, url]):
        print(f"DOWNLOAD=failed ({url})", file=sys.stderr)
        return 1
    print(f"WALLPAPER={target}")
    if do_set:
        if os.path.isfile(r.palette):
            r.set_key(r.palette, "wallpaper", target)
        if r.run_component("set-wallpaper.sh", target) == 0:
            print("SET=ok")
    return 0


def cmd_accents(r, args):
    rows = r.rows("accents.tsv", 3)
    if rows is None:
        print(f"no accent catalog ({r.dir}/accents.tsv)", file=sys.stderr)
        return 1
    want = args[0] if args else r.read_key(r.palette, "scheme")
    cur = r.read_key(r.palette, "accent").lower()
    n = 0
    for scheme, name, hexv in (row[:3] for row in rows):
        if not scheme_matches(scheme, want):
            continue
        n += 1
        mark = "  (current)" if hexv.lower() == cur else ""
        print(f"  {n:2d}) {name:<10} #{hexv}{mark}")
    print()
    print("Set one with:  rice accent <name|hex> [--pin]")
    return 0


def cmd_accent(r, args):
    if not args:
        print("usage: rice accent <name|hex> [--pin]  (see: rice accents)", file=sys.stderr)
        return 1
    sel = args[0]
    pin = "--pin" in args[1:]
    scheme = r.read_key(r.palette, "scheme")

    hexv = ""
    if HEX_RE.match(sel):
        hexv = sel.lower()
    else:
        rows = r.rows("accents.tsv", 3) or []
        for rscheme, name, h in (row[:3] for row in rows):
            if scheme_matches(rscheme, scheme) and name == sel:
                hexv = h
                break
    if not hexv:
        print(f"no accent '{sel}' for scheme '{scheme}' (see: rice accents)", file=sys.stderr)
        return 1

    # --pin writes to the OVERRIDE layer, which the render pass applies last, so the colour
    # survives every later theme and wallpaper change.
    target = r.user_palette if pin else r.palette
    r.set_key(target, "accent", hexv)
    print(f"ACCENT={hexv} (pinned in palette.user.conf)" if pin else f"ACCENT={hexv}")
    r.render()
    return 0


def cmd_save(r, args):
    if not args:
        print("usage: rice save <name>", file=sys.stderr)
        return 1
    os.makedirs(f"{r.dir}/profiles", exist_ok=True)
    try:
        shutil.copyfile(r.palette, f"{r.dir}/profiles/{args[0]}.conf")
    except OSError:
        print(f"could not save '{args[0]}'", file=sys.stderr)
        return 1
    print(f"SAVED profile '{args[0]}'")
    return 0


def cmd_theme(r, args):
    if not args:
        print("usage: rice theme <name>  (see: rice themes)", file=sys.stderr)
        return 1
    name = args[0]
    src = f"{r.dir}/profiles/{name}.conf"
    if not os.path.isfile(src):
        print(f"no profile '{name}' (see: rice themes)", file=sys.stderr)
        return 1
    shutil.copyfile(src, r.palette)

    wp = r.read_key(r.palette, "wallpaper")
    if wp.startswith("~"):
        wp = os.environ.get("HOME", "") + wp[1:]
    # A profile may carry a CATALOG SELECTOR (`scheme:name`) rather than a local path, so a
    # shipped preset can name a wallpaper without bundling the image.
    if wp and not os.path.isfile(wp) and re.match(r"^[A-Za-z0-9-]+:[A-Za-z0-9._-]+$", wp):
        sch, _, sel = wp.partition(":")
        text = out(["bash", f"{r.dir}/rice", "get-wallpaper", sch, sel])
        resolved = ""
        for line in text.splitlines():
            if line.startswith("WALLPAPER="):
                resolved = line[len("WALLPAPER="):]
        if resolved and os.path.isfile(resolved):
            r.set_key(r.palette, "wallpaper", resolved)   # so later applies do not re-download
            wp = resolved
        else:
            print(f"WARN: could not resolve wallpaper selector '{wp}' - skipping wallpaper set",
                  file=sys.stderr)
            wp = ""

    if wp and os.path.isfile(wp):
        subprocess.run(["bash", f"{r.dir}/set-wallpaper.sh", wp],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    r.render()
    print(f"APPLIED profile '{name}'")
    return 0


def cmd_scheme(r, args):
    """Swap the PALETTE and keep the current wallpaper.

    Also the documented way OUT of a high-contrast palette: those are fixed, so
    palette-from-wallpaper deliberately early-returns while one is active and a wallpaper change
    cannot re-derive colours. Switch scheme first, then re-derive."""
    if not args:
        cur = r.read_key(r.palette, "scheme")
        print(f"usage: rice scheme <name>   (current: {cur or 'none'}; see: rice themes)",
              file=sys.stderr)
        return 1
    name = args[0]
    src = f"{r.dir}/profiles/{name}.conf"
    if not os.path.isfile(src):
        print(f"no profile '{name}' (see: rice themes)", file=sys.stderr)
        return 1
    keep = r.read_key(r.palette, "wallpaper")
    shutil.copyfile(src, r.palette)
    r.set_key(r.palette, "wallpaper", keep)
    r.render()
    print(f"SCHEME '{name}' (wallpaper kept: {keep or 'none'})")
    return 0


def cmd_themes(r, args):
    names = r.profiles()
    if not names:
        print("(no profiles yet - save one with: rice save <name>)")
        return 0
    for n in names:
        print(n)
    return 0


def cmd_theme_toggle(r, args):
    if len(args) < 2:
        print("usage: rice theme-toggle <profileA> <profileB>", file=sys.stderr)
        return 1
    cur = r.read_key(r.palette, "scheme")
    return cmd_theme(r, [args[1] if cur == args[0] else args[0]])


def cmd_theme_next(r, args):
    names = r.profiles()
    if not names:
        print("(no profiles to cycle)", file=sys.stderr)
        return 1
    cur = r.read_key(r.palette, "scheme")
    nxt = names[0]
    if cur in names:
        nxt = names[(names.index(cur) + 1) % len(names)]
    return cmd_theme(r, [nxt])


def cmd_palette(r, args):
    try:
        with open(r.palette, encoding="utf-8", errors="replace") as fh:
            sys.stdout.write(fh.read())
    except OSError:
        print(f"no palette yet ({r.palette})")
    return 0


def cmd_templates(r, args):
    try:
        with open(f"{r.dir}/templates.list", encoding="utf-8", errors="replace") as fh:
            sys.stdout.write(fh.read())
    except OSError:
        print("no manifest yet")
    return 0


def cmd_edit(r, args):
    return subprocess.run([os.environ.get("EDITOR", "nano"), r.palette]).returncode


HELP = """hypr-rice - desktop theme engine ({dir})

  rice apply              render every template from palette.conf and reload apps
  rice apply --no-reload  render only (no app reloads)
  rice restore <id>       undo one apply, as one set (files it created are removed again)
  rice restore --list     what can be undone, newest first
  rice installs [<id>]    what this put on the machine: installed, already present, failed,
                          and any AUR helper built from source
  rice prefs [remove]     browser preferences this set, and the way to take them back off
  rice wallpaper <img>    set it, re-derive the palette from it, re-theme
  rice wallpaper <img> --no-theme    set it, keep the current palette
  rice random [dir]       a random wallpaper from dir (default ~/Pictures/wallpapers)
  rice wallpapers [scheme]           list curated downloadable wallpapers
  rice get-wallpaper <scheme> <n|name> [--set] [--dir D] [--min-res W]
  rice accents [scheme]   the accent variants for a scheme (default: current)
  rice accent <name|hex> [--pin]     set the accent; --pin survives every theme change
  rice save <name>        snapshot the current palette as a profile
  rice theme <name>       load a profile (palette + its wallpaper) and re-theme
                          NOTE: profiles are PALETTE-ONLY - structural look
                          (looknfeel.conf, waybar style.css, hyprlock layout) does not travel
  rice scheme <name>      swap the PALETTE only, keeping the current wallpaper
                          (the way out of a fixed high-contrast palette:
                           rice scheme catppuccin-mocha && rice wallpaper <img>)
  rice theme-toggle <a> <b>   flip between two profiles (the dark/light toggle keybind)
  rice theme-next         cycle to the next saved profile
  rice themes             list saved profiles
  rice palette            print palette.conf
  rice templates          print the render manifest (name -> output -> reload)
  rice edit               open palette.conf in $EDITOR

Add an app: drop a <name>.tmpl in templates/ (use {{{{accent}}}}, {{{{bg}}}}, {{{{color0}}}}...)
and a row in templates.list."""

COMMANDS = {
    "apply": cmd_apply, "restore": cmd_restore, "installs": cmd_installs, "prefs": cmd_prefs,
    "wallpaper": cmd_wallpaper, "random": cmd_random, "wallpapers": cmd_wallpapers,
    "get-wallpaper": cmd_get_wallpaper, "wallpaper-get": cmd_get_wallpaper,
    "accents": cmd_accents, "accent": cmd_accent, "save": cmd_save,
    "theme": cmd_theme, "load": cmd_theme, "scheme": cmd_scheme,
    "themes": cmd_themes, "list-themes": cmd_themes,
    "theme-toggle": cmd_theme_toggle, "theme-next": cmd_theme_next,
    "palette": cmd_palette, "templates": cmd_templates, "list": cmd_templates,
    "edit": cmd_edit,
}


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "help"
    args = argv[2:]
    if cmd in ("help", "-h", "--help"):
        r = Rice()
        print(HELP.format(dir=r.dir))
        return 0
    fn = COMMANDS.get(cmd)
    if not fn:
        print(f"unknown command: {cmd} (try: rice help)", file=sys.stderr)
        return 2
    return fn(Rice(), args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
