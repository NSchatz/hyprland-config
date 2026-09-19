#!/usr/bin/env python3
"""The QEMU invocation and the VM's lifecycle.

`qemu_argv` is a PURE function, for the same reason the container design made its docker argv
one: the isolation properties have to be assertable without starting anything. The lesson that
forced this was measured on the container route - `--gpus all` injected the host's real
`/dev/dri/card0` into a container whose argv never asked for it, so an argv-level check was not
enough there. A VM has no such back door: the guest sees only the virtio devices QEMU gives it,
and there is no host device passthrough anywhere in this file. The test asserts that stays true.

Why a VM at all, in one line: Aquamarine builds its GBM allocator only from a backend with a
DRM fd (`Backend.cpp:163-179`, `Headless.cpp:133`), so Hyprland needs either the machine's real
display device or a parent compositor. A VM hands it a virtual KMS device of its own, which is
the only arrangement that is both real and isolated.
"""
import os
import signal
import socket
import subprocess

__all__ = [
    "qemu_argv", "start", "stop", "alive", "pid", "free_display", "free_port", "vnc_port",
    "have_kvm", "powerdown", "wait_gone", "IsolationError",
]

# VNC display N listens on 5900+N. Displays below 10 collide with a user's own servers often
# enough to be worth skipping.
VNC_BASE = 5900
FIRST_DISPLAY = 10


def have_kvm():
    """KVM turns this from an emulator into something usable. Absence is worth reporting."""
    return os.access("/dev/kvm", os.R_OK | os.W_OK)


def vnc_port(display):
    return VNC_BASE + display


def _port_free(port, host="127.0.0.1"):
    with socket.socket() as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind((host, port))
            return True
        except OSError:
            return False


def free_display(first=FIRST_DISPLAY, count=40):
    """A VNC display number nothing is listening on, or None."""
    for d in range(first, first + count):
        if _port_free(vnc_port(d)):
            return d
    return None


def free_port(first=22220, count=200):
    for p in range(first, first + count):
        if _port_free(p):
            return p
    return None


# How host-side options reach the guest's boot session. QEMU's fw_cfg puts them in the guest's
# sysfs, so there is no guest agent to install and no writable share to open just to pass two
# booleans. The guest reads
# /sys/firmware/qemu_fw_cfg/by_name/opt/com.hyprland-config.preview/raw.
FW_CFG_NAME = "opt/com.hyprland-config.preview"


def qemu_argv(overlay, display, ssh_port, render_node=None, staging=None, plugin=None,
              memory=6144, cpus=4, qmp=None, serial=None, seed=None, accel=True,
              options=None):
    """The full QEMU argv for one preview.

    Every isolating choice here is deliberate:
      - the disk is an OVERLAY; the base image is never opened for writing, so a preview cannot
        corrupt the cached base and "throw it away" is `rm`.
      - VNC and the ssh forward bind to 127.0.0.1 only. A preview of someone's half-built
        desktop is not something to put on a network by accident.
      - the staging share is read-only: the guest may read the config being previewed and may
        not write back into the tree the host is still editing.
      - `-vga none` leaves exactly one GPU, so the guest gets one predictable output instead of
        racing the default VGA adapter.
      - the PLUGIN share is read-only too. It is not a convenience: the generated install.sh
        hands off to install-packages.sh, which refuses to install anything at all when it
        cannot find install-record.sh, so without this share every package in a previewed
        config fails and the preview quietly tests nothing.
    """
    argv = ["qemu-system-x86_64"]
    if accel:
        argv += ["-enable-kvm", "-cpu", "host"]
    argv += [
        "-machine", "q35",
        "-m", str(memory),
        "-smp", str(cpus),
        "-drive", f"file={overlay},if=virtio,format=qcow2",
        "-netdev", f"user,id=n0,hostfwd=tcp:127.0.0.1:{ssh_port}-:22",
        "-device", "virtio-net-pci,netdev=n0",
        "-device", "virtio-gpu-gl-pci",
        "-vga", "none",
        "-vnc", f"127.0.0.1:{display}",
    ]

    # GPU acceleration through the host's render node. Without it QEMU falls back to software
    # rendering in the guest, which still works and still shows a real Hyprland, just slowly.
    if render_node:
        argv += ["-display", f"egl-headless,rendernode={render_node}"]
    else:
        argv += ["-display", "egl-headless"]

    if seed:
        argv += ["-drive", f"file={seed},if=virtio,format=raw,readonly=on"]
    if staging:
        argv += ["-virtfs",
                 f"local,path={staging},mount_tag=staging,security_model=mapped-xattr,readonly=on"]
    if plugin:
        argv += ["-virtfs",
                 f"local,path={plugin},mount_tag=plugin,security_model=mapped-xattr,readonly=on"]
    if options:
        argv += ["-fw_cfg", f"name={FW_CFG_NAME},string={options}"]
    if qmp:
        argv += ["-qmp", f"unix:{qmp},server,nowait"]
    if serial:
        argv += ["-serial", f"file:{serial}"]

    return _check_isolation(argv)


class IsolationError(Exception):
    """The argv was about to give the guest something of the host's."""


def _check_isolation(argv):
    """Refuse an argv that hands the guest a host device or opens it to the network."""
    joined = " ".join(argv)
    for bad, why in (
        ("/dev/dri/card", "a host KMS device is the machine's real display"),
        ("vfio-pci", "PCI passthrough gives the guest real hardware"),
        ("-device usb-host", "USB passthrough reaches the host's input devices"),
    ):
        if bad in joined:
            raise IsolationError(f"refusing to start a preview VM with {bad}: {why}")
    for i, a in enumerate(argv):
        if a == "-vnc" and not argv[i + 1].startswith("127.0.0.1:"):
            raise IsolationError(
                f"refusing to bind the preview's VNC to {argv[i + 1]}: it would be reachable "
                "from the network. Forward the port deliberately instead."
            )
    return argv


def powerdown(qmp_path, timeout=10):
    """Ask the guest to shut down properly through QMP.

    This matters more than it looks. Killing QEMU leaves the guest filesystem unflushed, and a
    provisioned image snapshotted from an unflushed overlay silently loses whatever was written
    last - which is exactly how an earlier attempt at this lost the mount points it had just
    created and produced an image that looked fine and was not."""
    import json
    try:
        sock = socket.socket(socket.AF_UNIX)
        sock.settimeout(timeout)
        sock.connect(qmp_path)
    except OSError:
        return False
    try:
        fh = sock.makefile("rw", encoding="utf-8", newline="\n")
        fh.readline()                                   # the greeting
        for cmd in ({"execute": "qmp_capabilities"}, {"execute": "system_powerdown"}):
            fh.write(json.dumps(cmd) + "\n")
            fh.flush()
            while True:
                line = fh.readline()
                if not line:
                    return False
                reply = json.loads(line)
                if "return" in reply or "error" in reply:
                    break
        return True
    except (OSError, ValueError):
        return False
    finally:
        sock.close()


def wait_gone(pidfile, timeout=90):
    """Wait for the VM to exit on its own after a powerdown."""
    import time
    deadline = time.time() + timeout
    while time.time() < deadline:
        if pid(pidfile) is None:
            return True
        time.sleep(1)
    return False


def pid(pidfile):
    """The running VM's pid, or None. A stale pidfile reads as not running."""
    try:
        with open(pidfile, "r", encoding="utf-8") as fh:
            p = int(fh.read().strip())
    except (OSError, ValueError):
        return None
    try:
        os.kill(p, 0)
    except OSError:
        return None
    return p


def alive(pidfile):
    return pid(pidfile) is not None


def start(argv, pidfile, logfile):
    """Launch QEMU detached and record its pid. Returns (ok, detail)."""
    try:
        with open(logfile, "ab") as log:
            proc = subprocess.Popen(
                argv, stdout=log, stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL, start_new_session=True,
            )
    except OSError as exc:
        return False, str(exc)
    try:
        with open(pidfile, "w", encoding="utf-8") as fh:
            fh.write(f"{proc.pid}\n")
    except OSError as exc:
        proc.terminate()
        return False, f"could not record the VM pid: {exc}"
    return True, str(proc.pid)


def stop(pidfile, timeout=15):
    """Shut the VM down. True when nothing of it is left running.

    SIGTERM first, because QEMU flushes the disk on it; SIGKILL only if it will not go."""
    p = pid(pidfile)
    if p is None:
        try:
            os.unlink(pidfile)
        except OSError:
            pass
        return True
    try:
        os.kill(p, signal.SIGTERM)
    except OSError:
        pass
    import time
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            os.kill(p, 0)
        except OSError:
            break
        time.sleep(0.3)
    else:
        try:
            os.kill(p, signal.SIGKILL)
        except OSError:
            pass
    try:
        os.unlink(pidfile)
    except OSError:
        pass
    return pid(pidfile) is None
