#!/usr/bin/env python3
"""Record one interview answer into a JSON file, creating it if absent.

The interviewer agent (rice Mode A1) calls this after each AskUserQuestion, so
downstream steps (A3 file gen, A3d packages, A4 palette, the component-writer
agents) read picks deterministically from disk instead of recalling them from a
long chat history.

Usage:
  record-answer.py <answers-file> <key.path> <value>            # string value
  record-answer.py <answers-file> <key.path> --json <jsonval>   # array/object/number/bool/null

Examples:
  record-answer.py /tmp/hypr-gen-abc/answers.json palette.scheme catppuccin-mocha
  record-answer.py /tmp/hypr-gen-abc/answers.json bar.modules --json '["workspaces","clock","tray"]'
  record-answer.py /tmp/hypr-gen-abc/answers.json laptop.enabled --json true
  record-answer.py /tmp/hypr-gen-abc/answers.json notifications.timeout --json 5

Why Python: this script runs at *interview time*, before the install batch lands jq
on disk. Generation-time tooling must depend on Python stdlib only (pacman pulls in
python3 as a base dep on Arch). Runtime helper scripts (keybind-cheatsheet.sh, eww
data scripts) can still use jq — they run after install.

Exit codes:
  0  ok
  1  missing arguments (usage error)
  2  invalid JSON value, corrupt target file, or unwritable path
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


USAGE = (
    "usage: record-answer.py <file> <key.path> <value> "
    "| <file> <key.path> --json <jsonval>"
)


def die(msg: str, code: int) -> "NoReturn":  # type: ignore[name-defined]
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def expand(path: str) -> Path:
    # Match the shell script's tilde handling (POSIX `~user` not supported in the
    # original; we match os.path.expanduser which handles plain `~` and `~user`).
    return Path(os.path.expanduser(path))


def load_or_init(target: Path) -> dict:
    """Return the parsed JSON object at *target*, creating it as `{}` if absent."""
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("{}\n")
        return {}
    try:
        text = target.read_text()
    except OSError as exc:
        die(f"cannot read {target}: {exc}", 2)
    try:
        data = json.loads(text or "{}")
    except json.JSONDecodeError:
        die(
            f"{target} is not valid JSON (delete it to start over, or fix by hand)",
            2,
        )
    if not isinstance(data, dict):
        die(f"{target} top-level must be a JSON object, got {type(data).__name__}", 2)
    return data


def set_path(obj: dict, dotted_key: str, value) -> None:
    """Insert *value* at *dotted_key* (creating intermediate dicts)."""
    parts = dotted_key.split(".")
    if not parts or any(p == "" for p in parts):
        die(f"invalid key path: {dotted_key!r}", 1)
    cur = obj
    for p in parts[:-1]:
        nxt = cur.get(p)
        if not isinstance(nxt, dict):
            nxt = {}
            cur[p] = nxt
        cur = nxt
    cur[parts[-1]] = value


def get_path(obj: dict, dotted_key: str):
    cur = obj
    for p in dotted_key.split("."):
        if not isinstance(cur, dict) or p not in cur:
            return None
        cur = cur[p]
    return cur


def atomic_write(target: Path, data: dict) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    # Same-directory temp file so the rename is atomic on a single filesystem.
    fd, tmp_path = tempfile.mkstemp(
        prefix=".answers.", suffix=".json.tmp", dir=str(target.parent)
    )
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=True)
            f.write("\n")
        os.replace(tmp_path, target)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def format_final(value) -> str:
    """Format the final stored value for the echo line — mirrors `jq -r` output."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        die(USAGE, 1)
    target = expand(argv[0])
    key = argv[1]
    rest = argv[2:]

    if rest[0] == "--json":
        if len(rest) < 2:
            die("missing JSON value after --json", 1)
        raw = rest[1]
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            die(f"--json value is not valid JSON: {raw}", 2)
    else:
        # String value — accept the rest joined so spaces work like the shell version.
        value = rest[0]

    data = load_or_init(target)
    set_path(data, key, value)
    atomic_write(target, data)

    final = get_path(data, key)
    print(f"RECORDED {key}={format_final(final)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
