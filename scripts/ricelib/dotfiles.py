#!/usr/bin/env python3
"""Version-control the desktop configs in git, by whichever method the user picked.

Three methods, one interface:
  bare      a bare repo at ~/.dotfiles with $HOME as the work tree - nothing is moved or
            symlinked, which is what makes it safe to bolt onto configs that already exist
  stow      a package tree at ~/dotfiles that GNU stow symlinks into place
  chezmoi   chezmoi's own source directory

    dotfiles.sh init <bare|stow|chezmoi> [remote]
    dotfiles.sh add <path>...
    dotfiles.sh add-defaults          track the desktop surfaces that actually exist
    dotfiles.sh commit [message]
    dotfiles.sh push
    dotfiles.sh status
    dotfiles.sh method                which method is in force

The chosen method is remembered in `<config>/hypr-rice/dotfiles.conf` so later commands do not
have to be told again.

Exit: 0 ok, 2 usage or not initialised, 3 the method's tool is not installed.
"""
import os
import shutil
import subprocess
import sys

from . import xdg

# The common desktop config surfaces, under whichever base this machine actually uses.
DEFAULT_NAMES = [
    "hypr", "hypr-rice", "waybar", "kitty", "rofi", "wofi", "mako", "dunst",
    "gtk-3.0", "gtk-4.0", "qt5ct", "qt6ct", "swaync", "wlogout", "fastfetch",
    "starship.toml",
]


def _run(cmd, **kw):
    try:
        return subprocess.run(cmd, **kw).returncode
    except (OSError, subprocess.SubprocessError):
        return 127


def _quiet(cmd, **kw):
    return _run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kw)


class Ctx:
    def __init__(self, env=None):
        self.env = os.environ if env is None else env
        self.home = self.env.get("HOME", "")
        base = xdg.resolve_base(self.env)
        if not base:
            raise xdg.NoConfigDirError(base.error)
        self.config_base = base.path
        target = self.env.get("RICE_DIR") or f"{base.path}/hypr-rice"
        self.state = self.env.get("DOTFILES_STATE") or f"{target}/dotfiles.conf"
        self.bare_dir = self.env.get("DOTFILES_BARE_DIR") or f"{self.home}/.dotfiles"
        self.stow_dir = self.env.get("DOTFILES_STOW_DIR") or f"{self.home}/dotfiles"

    def method(self):
        try:
            with open(self.state, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if line.startswith("method="):
                        return line[len("method="):].strip()
        except OSError:
            pass
        return ""

    def bare(self, *args, **kw):
        return _run(["git", f"--git-dir={self.bare_dir}", f"--work-tree={self.home}", *args], **kw)

    def bare_quiet(self, *args):
        return _quiet(["git", f"--git-dir={self.bare_dir}", f"--work-tree={self.home}", *args])

    def default_paths(self):
        return [f"{self.config_base}/{n}" for n in DEFAULT_NAMES]


def cmd_init(c, args):
    method = args[0] if args else ""
    remote = args[1] if len(args) > 1 else ""
    if not method:
        print("usage: dotfiles.sh init <bare|stow|chezmoi> [remote]", file=sys.stderr)
        return 2
    try:
        os.makedirs(os.path.dirname(c.state), exist_ok=True)
    except OSError:
        pass

    if method == "bare":
        if not os.path.isdir(c.bare_dir):
            _quiet(["git", "init", "-q", "--bare", c.bare_dir])
        c.bare_quiet("config", "status.showUntrackedFiles", "no")
        if remote:
            c.bare_quiet("remote", "remove", "origin")
            c.bare_quiet("remote", "add", "origin", remote)
        with open(c.state, "w", encoding="utf-8") as fh:
            fh.write(f"method=bare\nbare_dir={c.bare_dir}\n")
        print(f"DOTFILES_INIT=ok (bare repo at {c.bare_dir}; alias: git "
              f"--git-dir={c.bare_dir} --work-tree=$HOME)")
        return 0

    if method == "stow":
        if not shutil.which("stow"):
            print("ERROR: stow not installed", file=sys.stderr)
            return 3
        os.makedirs(c.stow_dir, exist_ok=True)
        if not os.path.isdir(f"{c.stow_dir}/.git"):
            _quiet(["git", "-C", c.stow_dir, "init", "-q"])
        if remote:
            _quiet(["git", "-C", c.stow_dir, "remote", "remove", "origin"])
            _quiet(["git", "-C", c.stow_dir, "remote", "add", "origin", remote])
        with open(c.state, "w", encoding="utf-8") as fh:
            fh.write(f"method=stow\nstow_dir={c.stow_dir}\n")
        print(f"DOTFILES_INIT=ok (stow repo at {c.stow_dir})")
        return 0

    if method == "chezmoi":
        if not shutil.which("chezmoi"):
            print("ERROR: chezmoi not installed", file=sys.stderr)
            return 3
        _quiet(["chezmoi", "init"])
        if remote:
            _quiet(["chezmoi", "git", "--", "remote", "add", "origin", remote])
        with open(c.state, "w", encoding="utf-8") as fh:
            fh.write("method=chezmoi\n")
        try:
            src = subprocess.run(["chezmoi", "source-path"], stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, text=True).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            src = ""
        print(f"DOTFILES_INIT=ok (chezmoi source at {src})")
        return 0

    print(f"unknown method: {method}", file=sys.stderr)
    return 2


def cmd_add(c, paths):
    if not paths:
        print("usage: dotfiles.sh add <path>...", file=sys.stderr)
        return 2
    m = c.method()
    if not m:
        print("ERROR: run 'dotfiles.sh init' first", file=sys.stderr)
        return 2
    for p in paths:
        pe = (c.home + p[1:]) if p.startswith("~") else p
        if not os.path.lexists(pe):
            print(f"SKIP (missing) {p}")
            continue
        if m == "bare":
            if c.bare_quiet("add", "-f", pe) == 0:
                print(f"ADDED {p}")
        elif m == "chezmoi":
            if _quiet(["chezmoi", "add", pe]) == 0:
                print(f"ADDED {p}")
        elif m == "stow":
            pkg = os.path.basename(pe)
            rel = pe[len(c.home) + 1:] if pe.startswith(c.home + "/") else pe.lstrip("/")
            dest = f"{c.stow_dir}/{pkg}/{rel}"
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            try:
                if os.path.isdir(pe) and not os.path.islink(pe):
                    shutil.copytree(pe, dest, symlinks=True, dirs_exist_ok=True)
                else:
                    shutil.copy2(pe, dest, follow_symlinks=False)
            except (OSError, shutil.Error):
                print(f"SKIP (could not copy) {p}")
                continue
            _quiet(["git", "-C", c.stow_dir, "add", "-A"])
            print(f"STAGED(stow) {p} - symlink it with: stow -d {c.stow_dir} -t $HOME {pkg}")
    return 0


def cmd_commit(c, args):
    msg = args[0] if args else "update dotfiles"
    m = c.method()
    if m == "bare":
        c.bare_quiet("add", "-u")
        rc = c.bare_quiet("commit", "-q", "-m", msg)
    elif m == "stow":
        _quiet(["git", "-C", c.stow_dir, "add", "-A"])
        rc = _quiet(["git", "-C", c.stow_dir, "commit", "-q", "-m", msg])
    elif m == "chezmoi":
        _quiet(["chezmoi", "git", "--", "add", "-A"])
        rc = _quiet(["chezmoi", "git", "--", "commit", "-m", msg])
    else:
        print("ERROR: run 'dotfiles.sh init' first", file=sys.stderr)
        return 2
    print("COMMITTED" if rc == 0 else "nothing to commit")
    return 0


def cmd_push(c):
    m = c.method()
    if m == "bare":
        return c.bare("push", "-u", "origin", "HEAD")
    if m == "stow":
        return _run(["git", "-C", c.stow_dir, "push", "-u", "origin", "HEAD"])
    if m == "chezmoi":
        return _run(["chezmoi", "git", "--", "push"])
    print("ERROR: not initialized", file=sys.stderr)
    return 2


def cmd_status(c):
    m = c.method()
    if m == "bare":
        return c.bare("status", "-sb")
    if m == "stow":
        return _run(["git", "-C", c.stow_dir, "status", "-sb"])
    if m == "chezmoi":
        return _run(["chezmoi", "git", "--", "status", "-sb"])
    print("not initialized")
    return 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "help"
    args = argv[2:]

    if cmd in ("help", "-h", "--help"):
        print(__doc__.strip())
        return 0

    try:
        c = Ctx()
    except xdg.NoConfigDirError:
        print("DOTFILES=refused-no-config-dir")
        return 2

    if cmd == "init":
        return cmd_init(c, args)
    if cmd == "add":
        return cmd_add(c, args)
    if cmd == "add-defaults":
        exist = [p for p in c.default_paths() if os.path.lexists(p)]
        if not exist:
            print("no default config paths found to track")
            return 0
        return cmd_add(c, exist)
    if cmd == "commit":
        return cmd_commit(c, args)
    if cmd == "push":
        return cmd_push(c)
    if cmd == "status":
        return cmd_status(c)
    if cmd == "method":
        m = c.method()
        print(m if m else "(none)")
        return 0

    print(__doc__.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
