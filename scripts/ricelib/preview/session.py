#!/usr/bin/env python3
"""The record of the one preview that may be running, and the lock that keeps it to one.

Why one at a time. A preview VM costs real memory and a real CPU share, and the disk overlay is
a single cached file. Several at once would need a pool of overlays, displays and ports for a
workflow that is inherently one-at-a-time: you look at a desktop, then you change it. So: one
preview, a single record, and `--replace` as the explicit way to swap it.

Why a file rather than "ask the hypervisor". The VM is only half the state. A preview also owns
a disk overlay, a VNC display number and a forwarded port. If the VM dies, or the machine
reboots, those are still allocated and still have to be released. The record outlives the
process on purpose, which is what makes orphan detection possible at all.

State lives under the same root as restore points and install records
(`restorepoint.state_root`), because that is the one place in this package that resolves
XDG_STATE_HOME. `RICE_PREVIEW_DIR` overrides it, following the convention of `HYPR_DIR`,
`RICE_DIR`, `RICE_RESTORE_DIR` and `RICE_INSTALL_RECORD_DIR`.
"""
import json
import os

from .. import clock
from .. import restorepoint as rp

__all__ = ["state_dir", "record_path", "load", "save", "clear", "new_id", "Session"]


def state_dir(env=None):
    """Where the preview record lives. `RICE_PREVIEW_DIR` wins outright."""
    env = os.environ if env is None else env
    override = env.get("RICE_PREVIEW_DIR", "")
    if override:
        return override
    return f"{rp.state_root(env)}/preview"


def record_path(env=None):
    """The single record. Its existence is the lock."""
    return f"{state_dir(env)}/session.json"


def new_id(env=None):
    """A timestamp id, matching restore-point and install-record ids."""
    return clock.stamp(env)


class Session:
    """One preview, as it is written to disk.

    `display` and `ssh_port` are the load-bearing fields: they are how a later invocation finds
    a VM that is already running, and they outlive the process that started it."""

    FIELDS = (
        "id",
        "overlay",       # the throwaway disk this preview writes to
        "source",        # where the config came from, as the user named it
        "staging",       # the tree actually shared into the guest
        "size",
        "display",       # VNC display number; the port is 5900 + this
        "ssh_port",      # the loopback-only control channel
        "created",
    )

    def __init__(self, **kw):
        for f in self.FIELDS:
            setattr(self, f, kw.get(f))

    def as_dict(self):
        return {f: getattr(self, f) for f in self.FIELDS}


def load(env=None):
    """The current session, or None when no preview is claimed.

    A record that cannot be parsed is treated as no record rather than as an error: a
    half-written file must not wedge the feature shut, and `start` will simply overwrite it."""
    path = record_path(env)
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    return Session(**data)


def save(session, env=None):
    """Write the record atomically. False means the caller must not proceed to start.

    Atomic because the alternative is a truncated record that `load` discards, which would
    orphan a running VM and the disk, display and port it holds."""
    d = state_dir(env)
    path = record_path(env)
    tmp = f"{path}.tmp"
    try:
        os.makedirs(d, exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(session.as_dict(), fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.replace(tmp, path)
        return True
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False


def clear(env=None):
    """Drop the record. True when no record remains, including when there never was one."""
    try:
        os.unlink(record_path(env))
        return True
    except FileNotFoundError:
        return True
    except OSError:
        return False
