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

Hyprland's own colours exist in two languages. A hyprlang config sources a file of
`$accent = rgb(...)` variables; a lua config - the only kind Hyprland 0.57 loads - `require`s a
module that returns them. The manifest row names one of the two, and a manifest written before
a config was converted to lua names the wrong one: the pass would keep re-rendering a `.conf`
that nothing reads while the borders stayed the old theme's colour. So when the config dir is
lua and a lua palette sits beside the hyprlang one, that module is refreshed from the same
rendered values (see `refresh_lua_palette`).

A palette that carries `cursor_theme` also has it written into Hyprland's env file - `env.lua`
when there is one, else `env.conf` - so the cursor follows the theme at the next login. That is
an edit to a file the user owns, so it is backed up first and skipped when it cannot be.

Manifest rows are TAB-separated:
    <name> <TAB> <template> <TAB> <output> <TAB> <reload-cmd> [<TAB> <next-x hint>]
The 5th column groups surfaces that cannot reload live (`next-launch`, `next-lock`,
`server-restart`) into one footer line, so the user is told once rather than per surface.

Usage: render-templates.sh [--no-reload] [<palette>] [<manifest>]
Exit:  0 rendered, 2 no config dir / missing palette or manifest.
"""
import os
import re
import shutil
import subprocess
import sys

from .. import xdg
from .. import restorepoint as rp
from ..clock import unique_backup
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


def hypr_dir(env):
    try:
        return rp.canon(xdg.config_path("hypr", env.get("HYPR_DIR", ""), env))
    except xdg.NoConfigDirError:
        return ""


def refresh_lua_palette(name, out, env):
    """Keep a lua config's palette module in step with the hyprlang palette just rendered.

    Applies when `out` is a file of `$variables` inside the Hyprland config dir, that dir's
    config is lua (`hyprland.lua` exists, so Hyprland reads no `.conf` there), and
    `<same name>.lua` already exists - which is what migrate-config.sh leaves behind. The
    `.conf` is still written as the manifest says: other tools may source it. Without the
    `.lua` there is nothing to refresh, and that is said rather than guessed at: creating a
    module no file requires would theme nothing either."""
    from . import migrateconfig

    hypr = hypr_dir(env)
    if not hypr or not out.endswith(".conf") or not out.startswith(hypr + "/"):
        return
    if not os.path.isfile(f"{hypr}/hyprland.lua"):
        return
    try:
        lines = migrateconfig.read_lines(out)
    except OSError:
        return
    if not migrateconfig.is_variables_file(lines):
        return
    twin = out[:-len(".conf")] + ".lua"
    stem = os.path.basename(twin)[:-len(".lua")]
    if not os.path.isfile(twin):
        print(f"NOTE {name}: {out} is a hyprlang palette, and {hypr}/hyprland.lua does not "
              f"load it. No {os.path.basename(twin)} exists beside it to refresh: convert the "
              "config with migrate-config.sh, or point this manifest row at hyprland-lua.tmpl "
              "and colors.lua.")
        return
    head, body = migrateconfig.variables_module(lines)
    text = "\n".join(
        head
        + ["-- Regenerated by hypr-rice on every theme change, from the same palette as "
           f"{os.path.basename(out)}.",
           f"-- Read it with:  local c = require({migrateconfig.lua_string(stem)})",
           "return {"]
        + body + ["}"]) + "\n"
    try:
        with open(twin, "w", encoding="utf-8") as fh:
            fh.write(text)
    except OSError:
        print(f"RENDER_FAILED {name} -> {twin} (the lua palette could not be written)")
        return
    print(f"RENDERED {name} -> {twin} (lua palette: hyprland.lua is the config Hyprland loads)")


CURSOR_THEME_OK = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._ +-]*$")


def persist_cursor(palette, env):
    """Write the palette's cursor theme into Hyprland's env file, so it survives a login.

    `env.lua` when it exists - a lua config is what Hyprland loads, and it ignores `env.conf`
    from then on - otherwise `env.conf`. Only the VALUE of an existing line is replaced: a
    third `true` argument, a trailing comment and the line's position all stay. A variable
    with no line gets one appended.

    This is a file the user owns, inside the config dir, edited in place. So: nothing is
    written when nothing would change; the file is copied to `<file>.bak.<stamp>` and the
    copy compared before the edit; and when that backup cannot be made the edit is skipped."""
    theme = palette.get("cursor_theme", "").strip()
    if not theme:
        return
    size = palette.get("cursor_size", "").strip() or "24"
    if not CURSOR_THEME_OK.match(theme) or not size.isdigit():
        print(f"CURSOR_ENV_SKIPPED (cursor_theme '{theme}' / cursor_size '{size}' is not a "
              "theme name and a number)")
        return
    hypr = hypr_dir(env)
    lua = bool(hypr) and os.path.isfile(f"{hypr}/env.lua")
    path = f"{hypr}/env.lua" if lua else f"{hypr}/env.conf"
    if not hypr or not os.path.isfile(path):
        print(f"CURSOR_ENV_SKIPPED (no env.lua or env.conf in {hypr or 'the config dir'})")
        return
    try:
        with open(path, encoding="utf-8") as fh:
            before = fh.read()
    except (OSError, UnicodeDecodeError):
        print(f"CURSOR_ENV_SKIPPED {path} (it could not be read)")
        return

    lines = before.split("\n")
    opaque = []
    for var, value in (("XCURSOR_THEME", theme), ("HYPRCURSOR_THEME", theme),
                       ("XCURSOR_SIZE", size), ("HYPRCURSOR_SIZE", size)):
        if lua:
            setter = re.compile(rf'^hl\.env\(\s*"{var}"\s*,')
            literal = re.compile(rf'^(hl\.env\(\s*"{var}"\s*,\s*)"(?:[^"\\]|\\.)*"(.*)$')
            new = f'hl.env("{var}", "{value}")'
        else:
            setter = literal = re.compile(rf"^(\s*envd?\s*=\s*{var}\s*,)[^#]*?(\s+#.*)?$")
            new = f"env = {var},{value}"
        found = False
        for i, line in enumerate(lines):
            if not setter.match(line):
                continue
            found = True
            m = literal.match(line)
            if not m:
                opaque.append(var)      # set by an expression: not ours to rewrite
            elif lua:
                lines[i] = f'{m.group(1)}"{value}"{m.group(2)}'
            else:
                lines[i] = f"{m.group(1)}{value}{m.group(2) or ''}"
        if not found:
            if lines and lines[-1] == "":
                lines.insert(len(lines) - 1, new)
            else:
                lines.append(new)
    after = "\n".join(lines)
    if not after.endswith("\n"):
        after += "\n"
    for var in opaque:
        print(f"CURSOR_ENV_NOTE {path}: {var} is set by an expression there and was left alone")
    if after == before:
        print(f"CURSOR_ENV={path} (unchanged: {theme}, size {size})")
        return

    backup = unique_backup(path, env)
    try:
        shutil.copy2(path, backup)
        with open(backup, encoding="utf-8") as fh:
            intact = fh.read() == before
    except (OSError, UnicodeDecodeError):
        intact = False
    if not intact:
        print(f"CURSOR_ENV_SKIPPED {path} (its backup {backup} could not be written and "
              "verified, so it was not edited)")
        return
    tmp = f"{path}.rice-tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(after)
        shutil.copymode(path, tmp)
        os.replace(tmp, path)
    except OSError:
        try:
            os.remove(tmp)
        except OSError:
            pass
        print(f"CURSOR_ENV_FAILED {path} (it could not be written; the copy at {backup} is "
              "what it still holds)")
        return
    print(f"CURSOR_ENV={path} ({theme}, size {size}; the previous version is {backup})")


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

    # A detached engine (RICE_DIR away from <config base>/hypr-rice) renders only inside its
    # own directory, reloads nothing and keeps its restore points beside it - otherwise a
    # scratch engine themes the live desktop with a palette the user never chose.
    detached = xdg.detached_engine(env)
    if detached:
        env = dict(env)
        env.setdefault("RICE_RESTORE_DIR", f"{rice_dir}/restore")
        print(f"RENDER_DETACHED={rice_dir} (RICE_DIR is not <config base>/hypr-rice: outputs "
              "outside it are skipped and no app is reloaded)")

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

        if detached and not xdg.within(out, rice_dir):
            print(f"RENDER_SKIPPED {name} -> {out} (outside the detached engine dir {rice_dir})")
            continue

        res = rp.protect(out, env)
        if not res.ok:
            print(f"RENDER_SKIPPED {name} -> {out} ({res.error})")
            continue

        if not render_one(tmpl, out, palette):
            print(f"RENDER_FAILED {name} -> {out} (the output could not be written)")
            continue

        print(f"RENDERED {name} -> {out}")
        refresh_lua_palette(name, out, env)

        if detached and rcmd:
            print(f"RELOAD_SKIPPED {name} (detached engine)")
        elif reload_apps and rcmd:
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

    if not detached:
        write_restore_script(rice_dir, env)
        write_lock_blur(palette_path, env)
        persist_cursor(palette, env)

    if env.get("RICE_APPLY_ID"):
        print(f"RESTORE_POINT={env['RICE_APPLY_ID']} (undo every file this apply wrote: "
              f"rice restore {env['RICE_APPLY_ID']})")
    print("RENDER=done")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
