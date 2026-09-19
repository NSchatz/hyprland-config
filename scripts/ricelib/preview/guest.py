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

__all__ = ["ssh_argv", "run", "wait_ready", "copy_out", "reload_surfaces", "hyprctl"]

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


# Per-surface reload, mirroring what `hypr/applytheme.py` already does on a real desktop. The
# commands are the same ones the edit-config skill documents, so a preview reload and a real
# reload go through the same knowledge rather than two divergent copies.
RELOADS = {
    "hyprland": "hyprctl reload >/dev/null && echo RELOAD_hyprland=ok",
    "bar":      "pkill -SIGUSR2 -x waybar && echo RELOAD_bar=ok || echo RELOAD_bar=skipped",
    "notify":   "(makoctl reload 2>/dev/null && echo RELOAD_notify=ok) || "
                "(dunstctl reload 2>/dev/null && echo RELOAD_notify=ok) || "
                "(swaync-client -rs 2>/dev/null && echo RELOAD_notify=ok) || "
                "echo RELOAD_notify=skipped",
    "terminal": "pkill -SIGUSR1 -x kitty && echo RELOAD_terminal=ok || "
                "echo RELOAD_terminal=skipped",
    # Launchers have no reload mechanism at all - no daemon, no signal, no IPC. A change is
    # visible on the next launch, and saying so is better than pretending to reload it.
    "launcher": "echo RELOAD_launcher=next-launch",
}


def reload_surfaces(key, port, surfaces=None, staging_mount="/mnt/staging"):
    """Re-copy the shared staging tree into place, then reload each surface. (rc, output)."""
    names = list(RELOADS) if not surfaces or "all" in surfaces else list(surfaces)
    script = (
        f"sudo mount -o remount {staging_mount} 2>/dev/null; "
        f"cp -f {staging_mount}/*.conf ~/.config/hypr/ 2>/dev/null; "
        f"for d in {staging_mount}/_shell/*/; do "
        f"  [ -d \"$d\" ] || continue; a=$(basename \"$d\"); "
        f"  mkdir -p ~/.config/$a && cp -rf \"$d\".  ~/.config/$a/ 2>/dev/null; "
        f"done; "
        + "; ".join(RELOADS[n] for n in names if n in RELOADS)
    )
    return run(key, port, script, timeout=90)
