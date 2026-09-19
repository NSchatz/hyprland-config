#!/usr/bin/env python3
"""Small process helpers shared by the ported scripts.

The bash these replace leaned on `command -v`, `pgrep -x`, `$(...)` and `killall`. Collecting
the equivalents here keeps every port spelling them the same way, which is the same reason
xdg.py and restorepoint.py exist: a second spelling is where behaviour drifts.
"""
import os
import shutil
import signal
import subprocess

__all__ = ["have", "run", "out", "ok", "running", "signal_named", "expand_user"]


def have(binary):
    """`command -v <binary>`"""
    return shutil.which(binary) is not None


def run(cmd, **kw):
    """Run, returning (rc, combined output). Never raises."""
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, errors="replace", **kw)
        return p.returncode, p.stdout or ""
    except (OSError, subprocess.SubprocessError) as exc:
        return 127, str(exc)


def out(cmd, **kw):
    """stdout only, stderr discarded, empty string on any failure."""
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           text=True, errors="replace", **kw)
        return p.stdout or ""
    except (OSError, subprocess.SubprocessError):
        return ""


def ok(cmd, **kw):
    """True when the command exits zero."""
    return run(cmd, **kw)[0] == 0


def running(name):
    """`pgrep -x <name>` - an EXACT process-name match, never a substring."""
    return ok(["pgrep", "-x", name])


def signal_named(name, sig=signal.SIGUSR2, exact=True):
    """Signal every process with that exact name. True when at least one was signalled."""
    flag = ["-x"] if exact else []
    pids = out(["pgrep", *flag, name]).split()
    sent = False
    for pid in pids:
        try:
            os.kill(int(pid), sig)
            sent = True
        except (OSError, ValueError):
            pass
    return sent


def expand_user(p, env=None):
    """Expand a leading `~` against $HOME. NOT config-aware - use ricelib.xdg.expand_path when
    the path may name a config surface."""
    env = os.environ if env is None else env
    if p.startswith("~"):
        return env.get("HOME", "") + p[1:]
    return p
