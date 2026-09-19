#!/usr/bin/env python3
"""Parse-test a shell rc file. NEVER sources it.

Sourcing a user's rc to see whether it is valid EXECUTES it - every alias, every `exec`, every
`rm` someone put in there. So each shell's own parse-only flag is used instead: `bash -n`,
`zsh -n`, `fish --no-execute`. A clean parse proves the file is syntactically valid; it proves
nothing about what the file would DO, which is the point.

Usage: verify-shell.sh <rcfile> [shell]
Output: VERIFY_SHELL=ok|errors|skipped|error
Exit:   0 ok, 1 parse errors, 2 unusable input or the shell is not installed.
"""
import os
import sys

from ..proc import expand_user, have, run

PARSERS = {
    "bash": (["bash", "-n"], None),
    "zsh": (["zsh", "-n"], "zsh"),
    "fish": (["fish", "--no-execute"], "fish"),
}


def infer_shell(path):
    base = os.path.basename(path)
    low = path.lower()
    if base.endswith((".zshrc", ".zshenv", ".zprofile")) or "zsh" in low:
        return "zsh"
    if base == "config.fish" or base.endswith(".fish") or "fish" in low:
        return "fish"
    return "bash"


def main(argv):
    path = argv[1] if len(argv) > 1 else ""
    if not path:
        print("VERIFY_SHELL=error (usage: verify-shell.sh <rcfile> [shell])")
        return 2
    path = expand_user(path)
    if not os.path.isfile(path):
        print(f"VERIFY_SHELL=error (no such file: {path})")
        return 2

    shell = argv[2] if len(argv) > 2 else infer_shell(path)
    if shell not in PARSERS:
        print(f"VERIFY_SHELL=error (unknown shell: {shell})")
        return 2

    cmd, needs = PARSERS[shell]
    if needs and not have(needs):
        print(f"VERIFY_SHELL=skipped ({needs} not installed)")
        return 2

    rc, output = run(cmd + [path])
    if rc == 0:
        print(f"VERIFY_SHELL=ok ({shell})")
        return 0
    print(f"VERIFY_SHELL=errors ({shell})")
    if output:
        print(output, end="" if output.endswith("\n") else "\n")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
