#!/usr/bin/env python3
"""Read picks from <staging>/answers.json without depending on jq.

The rice interview persists every `AskUserQuestion` answer to a JSON file (via
record-answer.py) before the install batch lands jq on disk. Downstream
generation-time steps (A3 file gen, A3b shell configs, A3c shell-prompt, A3d
install.sh, A4 palette) used to read the file with `jq` — that breaks on a
clean Arch box because jq isn't installed yet.

This helper covers the two jq invocations the generation steps actually use:

  get <file> <key.path> [default]
      Print the scalar value at the dotted path. Mirrors `jq -r .a.b.c`.
      For arrays prints a JSON list; for objects prints a JSON object;
      for null prints "null". Missing keys → exit 1 (or print *default* on exit 0).

  slice <file> <key1> [<key2> ...]
      Print a JSON object with just the named top-level keys, formatted
      compactly. Mirrors `jq '{a, b, c}'`. Keys absent in the source map to
      `null` (same as jq).

  list <file> <key.path>
      Print the array at the dotted path one element per line. Mirrors
      `jq -r '.a.b[]'`. Errors if the value is not an array.

  has <file> <key.path>
      Exit 0 if the dotted path exists and is non-null/non-false; exit 1
      otherwise. Mirrors `jq -e .a.b.c >/dev/null`.

Runtime helper scripts (keybind-cheatsheet.sh, eww data scripts) keep using jq
because they run *after* the install batch.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


USAGE = (
    "usage: answers.py get <file> <key.path> [default]\n"
    "       answers.py slice <file> <key1> [<key2> ...]\n"
    "       answers.py list <file> <key.path>\n"
    "       answers.py has <file> <key.path>"
)


def load(path: str) -> dict:
    try:
        return json.loads(Path(path).read_text() or "{}")
    except FileNotFoundError:
        print(f"ERROR: answers file not found: {path}", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {path}: {exc}", file=sys.stderr)
        sys.exit(2)


def get_path(obj, dotted_key: str, sentinel=None):
    cur = obj
    for p in dotted_key.split("."):
        if not isinstance(cur, dict) or p not in cur:
            return sentinel
        cur = cur[p]
    return cur


def render(value) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def cmd_get(argv: list[str]) -> int:
    if len(argv) < 2 or len(argv) > 3:
        print(USAGE, file=sys.stderr)
        return 1
    target, key = argv[0], argv[1]
    default = argv[2] if len(argv) == 3 else None
    sentinel = object()
    value = get_path(load(target), key, sentinel)
    if value is sentinel:
        if default is not None:
            print(default)
            return 0
        return 1
    print(render(value))
    return 0


def cmd_slice(argv: list[str]) -> int:
    if len(argv) < 2:
        print(USAGE, file=sys.stderr)
        return 1
    target, keys = argv[0], argv[1:]
    data = load(target)
    out = {k: data.get(k, None) for k in keys}
    json.dump(out, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


def cmd_list(argv: list[str]) -> int:
    if len(argv) != 2:
        print(USAGE, file=sys.stderr)
        return 1
    target, key = argv[0], argv[1]
    value = get_path(load(target), key)
    if value is None:
        return 0  # empty list — mirrors jq's behavior on null/missing
    if not isinstance(value, list):
        print(f"ERROR: value at {key} is not an array: {type(value).__name__}", file=sys.stderr)
        return 2
    for item in value:
        print(render(item))
    return 0


def cmd_has(argv: list[str]) -> int:
    if len(argv) != 2:
        print(USAGE, file=sys.stderr)
        return 1
    target, key = argv[0], argv[1]
    value = get_path(load(target), key)
    if value is None or value is False:
        return 1
    return 0


def main(argv: list[str]) -> int:
    if not argv:
        print(USAGE, file=sys.stderr)
        return 1
    op, rest = argv[0], argv[1:]
    handlers = {"get": cmd_get, "slice": cmd_slice, "list": cmd_list, "has": cmd_has}
    handler = handlers.get(op)
    if handler is None:
        print(f"ERROR: unknown command: {op}", file=sys.stderr)
        print(USAGE, file=sys.stderr)
        return 1
    return handler(rest)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
