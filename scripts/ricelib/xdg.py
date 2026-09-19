#!/usr/bin/env python3
"""WHERE THIS PLUGIN'S CONFIGURATION LIVES - the one decision, made once.

Hyprland reads its config from `$XDG_CONFIG_HOME/hypr/hyprland.lua`; `~/.config/hypr` is only
the common case. A user who moved `XDG_CONFIG_HOME` moved their whole desktop's configuration,
and every script here has to follow them there - otherwise the plugin backs up, installs,
live-tests and reports success against a directory the compositor never reads.

It is ONE decision on purpose. Five scripts each resolving their own target is how a backup gets
taken from directory A while the reset wipes directory B, and that wipe has no inverse: the
backup is of the wrong tree. This module is that decision; `scripts/xdg-config.sh` is a thin
shim over it so the bash callers that source it keep working unchanged.

The rule, in order:
  1. an explicit override (HYPR_DIR, RICE_DIR, ...) wins outright, whatever XDG_CONFIG_HOME
     holds - it is what the tests and power users set;
  2. else $XDG_CONFIG_HOME, when it is an ABSOLUTE path;
  3. else $HOME/.config, the XDG default when XDG_CONFIG_HOME "is either not set or empty";
  4. else nothing: refuse, say so, and write nothing. Resolving `/.config` from an unset HOME,
     or `.config` from the working directory, are both worse than stopping.

A RELATIVE XDG_CONFIG_HOME is invalid, not merely unusual: "All paths set in these environment
variables must be absolute. If an implementation encounters a relative path in any of these
variables it should consider the path invalid and ignore it"
(<https://specifications.freedesktop.org/basedir/latest/>). It is ignored, the default is used,
and the notice says both out loud - a silent fallback is how a user ends up with a config they
cannot find.

Only XDG_CONFIG_HOME. XDG_DATA_HOME, XDG_STATE_HOME, XDG_CACHE_HOME and XDG_RUNTIME_DIR are
separate base directories with separate defaults; nothing here touches how a cache, state or
runtime path resolves.

CLI (what the bash shim calls):
    xdg.py base                 -> CONFIG_BASE/CONFIG_BASE_SOURCE/notice on stdout, 4 if unresolved
    xdg.py path <name> [ovr]    -> the absolute dir, no diagnostics (safe in $(...)), 1 if unresolved
    xdg.py target <name> [ovr]  -> the dir plus the diagnostics a user-facing run owes
    xdg.py expand <path>        -> `~` expansion, config-aware (see expand_path)
    xdg.py report               -> the human resolution dump
"""
import os
import sys

__all__ = ["Base", "resolve_base", "config_path", "expand_path", "NoConfigDirError"]


class NoConfigDirError(Exception):
    """No config directory could be determined. Callers must not write."""


class Base:
    """The outcome of one resolution."""

    def __init__(self, path=None, source=None, ignored=None, error=None):
        self.path = path            # absolute base dir, or None
        self.source = source        # "XDG_CONFIG_HOME" | "HOME"
        self.ignored = ignored      # the XDG_CONFIG_HOME value rejected as invalid
        self.error = error          # why nothing could be determined

    def __bool__(self):
        return self.path is not None


def _trim_slashes(p):
    """`/tmp/cfg/` and `/tmp/cfg` are one path; `/` stays `/`."""
    while len(p) > 1 and p.endswith("/"):
        p = p[:-1]
    return p


def resolve_base(env=None):
    """Apply rules 2-4. Never raises, never prints: the caller decides how loud to be."""
    env = os.environ if env is None else env
    ignored = None

    v = env.get("XDG_CONFIG_HOME", "")
    if v:
        if v.startswith("/"):
            return Base(path=_trim_slashes(v), source="XDG_CONFIG_HOME")
        # Relative: invalid per the specification. Remembered so the fallback can be
        # reported rather than taken silently.
        ignored = v

    h = env.get("HOME", "")
    if h.startswith("/"):
        h = _trim_slashes(h)
        if h == "/":
            h = ""
        return Base(path=h + "/.config", source="HOME", ignored=ignored)

    xch = env["XDG_CONFIG_HOME"] if "XDG_CONFIG_HOME" in env else "<unset>"
    home = env["HOME"] if "HOME" in env else "<unset>"
    return Base(
        ignored=ignored,
        error=(
            "cannot determine a config directory: "
            f"XDG_CONFIG_HOME=[{xch}] is not an absolute path "
            f"and HOME=[{home}] is not one either"
        ),
    )


def config_path(name="", override="", env=None):
    """The absolute directory for a config surface (`hypr`, `hypr-rice`, `waybar`, ...).

    Pure: no diagnostics. An empty name gives the base itself. An override wins outright."""
    if override:
        return override
    base = resolve_base(env)
    if not base:
        raise NoConfigDirError(base.error)
    return base.path if not name else f"{base.path}/{name}"


def expand_path(p, env=None):
    """Expand a leading `~`, with one difference: `~/.config/<rest>` names a CONFIG SURFACE, so
    it resolves under the base above rather than blindly under $HOME. That is what makes a
    render-manifest row reading `~/.config/waybar/colors.css` land where the config actually is.

    Every other `~/...` path - `~/.cache/...`, `~/.local/share/...`, `~/Pictures/...` - keeps
    expanding under $HOME. Those are other base directories with their own variables.

    Returns (path, ok). ok is False when a `~/.config` path had to fall back to a bare $HOME
    expansion because no base could be determined; the legacy value is still returned, since
    this is also used on READ paths where refusing outright would be worse. Callers that WRITE
    resolve through config_path/target first and refuse there."""
    env = os.environ if env is None else env
    home = env.get("HOME", "")

    if p == "~/.config" or p.startswith("~/.config/"):
        rest = p[len("~/.config/"):] if p != "~/.config" else ""
        base = resolve_base(env)
        if base:
            return (f"{base.path}/{rest}" if rest else base.path), True
        return (f"{home}/.config/{rest}" if rest else f"{home}/.config"), False

    if p == "~" or p.startswith("~/"):
        return home + p[1:], True

    return p, True


def _notice(base, out=sys.stdout):
    """The report a rejected XDG_CONFIG_HOME is owed: the value refused AND the absolute path
    used instead. Silent when nothing was rejected."""
    if not base.ignored:
        return
    print(f"XDG_CONFIG_HOME_IGNORED={base.ignored}", file=out)
    print(
        f"CONFIG_BASE={base.path} (XDG_CONFIG_HOME={base.ignored} is a relative path, which the "
        "XDG base directory specification says is invalid and must be ignored; the default was "
        "used instead)",
        file=out,
    )


def _refusal(base):
    print(f"ERROR: {base.error or 'cannot determine a config directory'}", file=sys.stderr)
    print(
        "ERROR: nothing was written. Set XDG_CONFIG_HOME to an absolute path, or set HOME.",
        file=sys.stderr,
    )
    print("CONFIG_DIR=unresolved")


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "report"
    name = argv[2] if len(argv) > 2 else ""
    override = argv[3] if len(argv) > 3 else ""

    if cmd == "path":
        try:
            print(config_path(name, override))
        except NoConfigDirError:
            return 1
        return 0

    if cmd == "target":
        if override:
            print(override)
            return 0
        base = resolve_base()
        if not base:
            _refusal(base)
            return 1
        _notice(base)
        print(base.path if not name else f"{base.path}/{name}")
        return 0

    if cmd == "expand":
        path, ok = expand_path(name)
        print(path)
        return 0 if ok else 1

    if cmd in ("base", "report"):
        base = resolve_base()
        if not base:
            _refusal(base)
            return 4
        _notice(base)
        print(f"CONFIG_BASE={base.path}")
        print(f"CONFIG_BASE_SOURCE={base.source}")
        print(f"HYPR_DIR={config_path('hypr', os.environ.get('HYPR_DIR', ''))}")
        print(f"RICE_DIR={config_path('hypr-rice', os.environ.get('RICE_DIR', ''))}")
        return 0

    print(f"ERROR: unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
