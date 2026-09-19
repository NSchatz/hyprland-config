#!/usr/bin/env python3
"""The one place this package asks what time it is.

Both the restore point and the install record mint identifiers from a timestamp, and both need
that timestamp to be steerable: a test has to be able to force two records into the same second
to prove the ordinal suffix sorts correctly, and a reproducible run wants a fixed stamp.

`RICE_STAMP_OVERRIDE` is that steering wheel. It takes the literal `YYYYmmdd-HHMMSS` string
rather than an epoch, so there is no timezone arithmetic between what a caller sets and what
lands in a filename. It follows the same convention as `HYPR_DIR`, `RICE_DIR`,
`RICE_RESTORE_DIR` and `RICE_INSTALL_RECORD_DIR` elsewhere in this plugin: an explicit override
that wins outright, and that the tests and power users set.

The bash it replaces steered the same thing by stubbing the `date` binary on PATH. A Python
process does not go through `date`, so the override is the equivalent seam.
"""
import os
import re
from datetime import datetime, timezone

STAMP_RE = re.compile(r"^\d{8}-\d{6}$")


def stamp(env=None):
    """`YYYYmmdd-HHMMSS`, local time, or the override when one is set and well-formed.

    A malformed override is IGNORED rather than honoured: a filename built from nonsense is
    worse than one built from the clock, and silently accepting it would put records somewhere
    `list` cannot order."""
    env = os.environ if env is None else env
    override = env.get("RICE_STAMP_OVERRIDE", "")
    if override and STAMP_RE.match(override):
        return override
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def iso_utc(env=None):
    """`YYYY-mm-ddTHH:MM:SSZ` for the `# when` header of a record."""
    env = os.environ if env is None else env
    override = env.get("RICE_STAMP_OVERRIDE", "")
    if override and STAMP_RE.match(override):
        d, t = override.split("-")
        return f"{d[0:4]}-{d[4:6]}-{d[6:8]}T{t[0:2]}:{t[2:4]}:{t[4:6]}Z"
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
