#!/usr/bin/env python3
"""The control channel into the preview guest: ssh over a loopback-only forward.

Everything that has to happen *inside* the preview goes through here - reloading a surface
after the staged config changed, asking what the compositor thinks its monitors are, running a
command. Screenshots deliberately do NOT: they are taken from outside over VNC (see `rfb.py`),
because a capture that depends on the guest rendering a frame hangs exactly when a preview is
least healthy.

The key is generated per machine and lives beside the cached image, never in the repo. Host key
checking is off and the known-hosts file is /dev/null on purpose: the guest is a throwaway whose
host key changes every time the base image is rebuilt, and the connection is to a port bound on
127.0.0.1 that only this user can reach.
"""
import os
import subprocess

__all__ = ["ssh_argv", "run", "wait_ready", "copy_out", "copy_in", "apply_and_reload",
           "boot_status", "hyprctl"]

USER = "preview"

# Every command runs with the guest session's environment resolved first: a non-login ssh
# session has no HYPRLAND_INSTANCE_SIGNATURE and no WAYLAND_DISPLAY, so hyprctl cannot find the
# compositor it is meant to talk to. Same trap as a sibling shell in a container.
PRELUDE = (
    "export XDG_RUNTIME_DIR=/run/user/1000; "
    "export HYPRLAND_INSTANCE_SIGNATURE="
    "$(ls -t /run/user/1000/hypr 2>/dev/null | head -1); "
    "export WAYLAND_DISPLAY="
    "$(hyprctl -j instances 2>/dev/null | jq -r '.[0].wl_socket // \"wayland-1\"'); "
)


def ssh_argv(key, port, command=None, host="127.0.0.1"):
    argv = [
        "ssh", "-i", key,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/dev/null",
        "-o", "LogLevel=ERROR",
        "-o", "ConnectTimeout=5",
        "-o", "BatchMode=yes",
        "-p", str(port), f"{USER}@{host}",
    ]
    if command:
        argv.append(command)
    return argv


def run(key, port, command, timeout=60, with_session=True):
    """Run a command in the guest. Returns (rc, combined output). Never raises."""
    shell = (PRELUDE + command) if with_session else command
    try:
        proc = subprocess.run(
            ssh_argv(key, port, shell),
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=timeout,
        )
        return proc.returncode, proc.stdout or ""
    except subprocess.TimeoutExpired:
        return 124, f"the guest did not answer within {timeout}s"
    except OSError as exc:
        return 127, str(exc)


def wait_ready(key, port, timeout=180, interval=3):
    """Wait for the guest to accept ssh. Returns (ok, seconds_waited)."""
    import time
    start = time.time()
    while time.time() - start < timeout:
        rc, _ = run(key, port, "true", timeout=8, with_session=False)
        if rc == 0:
            return True, int(time.time() - start)
        time.sleep(interval)
    return False, int(time.time() - start)


def hyprctl(key, port, args, timeout=30):
    """One hyprctl call in the guest, with the session environment already resolved."""
    return run(key, port, f"hyprctl {args}", timeout=timeout)


def copy_out(key, port, remote, local, host="127.0.0.1"):
    argv = [
        "scp", "-i", key,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/dev/null",
        "-o", "LogLevel=ERROR",
        "-o", "BatchMode=yes",
        "-P", str(port), f"{USER}@{host}:{remote}", local,
    ]
    try:
        return subprocess.run(argv, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=60).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def copy_in(key, port, locals_, remote_dir, host="127.0.0.1"):
    """Copy files into the guest. True on success."""
    argv = [
        "scp", "-i", key,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/dev/null",
        "-o", "LogLevel=ERROR",
        "-o", "BatchMode=yes",
        "-P", str(port), *locals_, f"{USER}@{host}:{remote_dir}",
    ]
    try:
        return subprocess.run(argv, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=120).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def apply_and_reload(key, port, timeout=120):
    """Re-apply the staged config in the guest and reload what is running.

    This deliberately shells out to the SAME script the guest runs at boot
    (`tests/preview/guest-apply.sh`). Reimplementing the copy here in Python would give the
    boot path and the iteration path two different notions of what a staged config is, which
    is precisely the bug that made plugins, GTK2 theming and the shell surface silently
    untestable in the first version of this feature."""
    return run(key, port, "$HOME/.local/bin/guest-apply.sh --reload", timeout=timeout)


def boot_status(key, port, timeout=30):
    """What the guest's boot session did, as the markers it wrote.

    A preview that comes up wrong shows a black screen and explains nothing; this is where the
    explanation lives (which shares mounted, what was copied, whether install.sh ran)."""
    return run(key, port, "cat ~/preview-boot.status 2>/dev/null", timeout=timeout,
               with_session=False)
