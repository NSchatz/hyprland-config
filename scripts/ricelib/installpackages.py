#!/usr/bin/env python3
"""The ONE install routine: repo-vs-AUR routing, the AUR-helper bootstrap, the non-Arch skip,
and the record that says what this put on the machine.

The generated `install.sh` and the installer agent's ad-hoc list both come through here, so both
leave the SAME record in the same place and the same form. A record only one route writes is a
record a user cannot rely on.

It refuses to install at all when it cannot find the recorder: an install nobody can look up
afterwards is the defect this whole path exists to close.

Usage: install-packages.sh [options] <pkg> [<pkg> ...]
  --route <name>    what is driving this (install.sh | package-list | ...)
  --label <text>    a note stored with the record
  --helper <h>      force the AUR helper (paru | yay)
  --noconfirm       pass --noconfirm to pacman and the helper
  --assume-yes      answer the AUR source-build confirmation with yes
  --assume-no       answer it with no (an unanswered prompt is a decline either way)

Exit: 0 ok/partial/skipped, 1 failed or the record could not be written, 2 usage, 4 the AUR
source build was declined.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

from . import installrecord, xdg

# `paru`, not `paru-bin`: the prebuilt package is a third party's binary, and if a source build
# is what this is disclosing, it should be what it does.
AUR_HELPER_PKG = "paru"
AUR_HELPER_URL = "https://aur.archlinux.org/paru.git"


def _run(cmd, **kw):
    """Run and capture combined output. Never raises on a non-zero exit."""
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, errors="replace", **kw)
        return p.returncode, p.stdout or ""
    except (OSError, subprocess.SubprocessError) as exc:
        return 127, str(exc)


def _have(binary):
    return shutil.which(binary) is not None


def _installed(pkg):
    rc, _ = _run(["pacman", "-Qq", pkg])
    return rc == 0


def _in_repo(pkg):
    rc, _ = _run(["pacman", "-Si", pkg])
    return rc == 0


def _helper_works(h):
    if not h or not _have(h):
        return False
    rc, _ = _run([h, "--version"])
    return rc == 0


def reason_for(pkg, out):
    """The one-line reason the install reported for a package."""
    lines = out.splitlines()
    pat = re.compile(r"error|failed|not found|conflict|unable", re.I)
    for line in lines:
        if pkg in line and pat.search(line):
            return line.strip()
    for line in lines:
        if re.match(r"^(error|==> ERROR)", line, re.I):
            return line.strip()
    return "the install reported no error but the package is not installed afterwards"


def _find_recorder(here):
    """The recorder component, wherever it lives. Returns a path or None."""
    rice_dir = os.environ.get("RICE_DIR", "")
    if not rice_dir:
        try:
            rice_dir = xdg.config_path("hypr-rice")
        except xdg.NoConfigDirError:
            rice_dir = ""
    for c in (f"{here}/install-record.sh",
              f"{os.environ.get('CLAUDE_PLUGIN_ROOT', '')}/scripts/install-record.sh",
              f"{rice_dir}/install-record.sh" if rice_dir else ""):
        if c and os.path.isfile(c):
            return c
    return None


def main(argv):
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    route, label, forced_helper = "package-list", "", ""
    noconfirm = False
    assume = ""
    pkgs = []

    args = argv[1:]
    i = 0
    while i < len(args):
        opt = args[i]; i += 1
        if opt in ("--route", "--label", "--helper"):
            val = args[i] if i < len(args) else ""
            i += 1
            if opt == "--route":
                route = val
            elif opt == "--label":
                label = val
            else:
                forced_helper = val
        elif opt == "--noconfirm":
            noconfirm = True
        elif opt == "--assume-yes":
            assume = "yes"
        elif opt == "--assume-no":
            assume = "no"
        elif opt in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        elif opt == "--":
            pkgs.extend(args[i:])
            i = len(args)
        elif opt.startswith("-"):
            print(f"ERROR: unknown option '{opt}' (try: install-packages.sh --help)",
                  file=sys.stderr)
            return 2
        else:
            pkgs.append(opt)

    if not pkgs:
        print("ERROR: usage: install-packages.sh [options] <pkg> [<pkg> ...]", file=sys.stderr)
        return 2

    recorder = _find_recorder(here)
    if not recorder:
        print(f"ERROR: the install record component (install-record.sh) was not found next to "
              f"{here}, in $CLAUDE_PLUGIN_ROOT/scripts, or in the rice directory.", file=sys.stderr)
        print("ERROR: nothing was installed. An install that leaves no record is exactly what "
              "this path refuses to do - re-run rice-init.sh.", file=sys.stderr)
        print("INSTALL=failed")
        return 2

    txn = []   # (status, package, origin, note)

    print(f"PACKAGES={' '.join(pkgs)}")
    for p in pkgs:
        print(f"  {p}")

    if not _have("pacman"):
        print("PACMAN=absent")
        print("This host has no pacman, so nothing was installed: no package manager and no AUR "
              "helper was invoked.")
        print("The list above is what an Arch host would install; install the equivalents with "
              "your own package manager.")
        # Nothing installed, nothing present, nothing failed. There was no transaction, so there
        # is no record: a record here would invent a history.
        print("INSTALL=skipped (non-arch)")
        return 0

    sudo = []
    if os.geteuid() != 0:
        if _have("sudo"):
            sudo = ["sudo"]
        else:
            print("ERROR: pacman needs root and neither sudo nor a root shell is available.",
                  file=sys.stderr)
            print("INSTALL=failed")
            return 1

    nc = ["--noconfirm"] if noconfirm else []

    present, repo, aur = [], [], []
    for p in pkgs:
        if _installed(p):
            present.append(p)
            txn.append(("present", p, "-", "already installed; left alone"))
        elif _in_repo(p):
            repo.append(p)
        else:
            aur.append(p)

    n_installed = n_failed = 0

    if repo:
        print(f"REPO_PACKAGES={' '.join(repo)}")
        _, out = _run(sudo + ["pacman", "-S", "--needed"] + nc + repo)
        print(out, end="" if out.endswith("\n") else "\n")
        for p in repo:
            if _installed(p):
                txn.append(("installed", p, "repo", ""))
                n_installed += 1
            else:
                txn.append(("failed", p, "repo", reason_for(p, out)))
                n_failed += 1

    declined = False
    helper = ""

    if aur:
        print(f"AUR_PACKAGES={' '.join(aur)}")
        for h in ([forced_helper] if forced_helper else []) + ["paru", "yay"]:
            if _helper_works(h):
                helper = h
                break

        if not helper:
            # DISCLOSE BEFORE BUILDING. The user authorised installing packages, not compiling a
            # package manager they did not know they were missing - so name what is about to be
            # built, say it is a source build on this machine, and show where it comes from, all
            # before anything is cloned or built.
            print(f"AUR_BUILD_REQUIRED={AUR_HELPER_PKG}")
            print("These packages are not in the Arch repositories and need an AUR helper, and "
                  "no working helper is installed:")
            for p in aur:
                print(f"  {p}")
            print(f"To install them, {AUR_HELPER_PKG} would be BUILT FROM SOURCE on this machine "
                  "(git clone, then makepkg -si).")
            print(f"AUR_BUILD_PACKAGE={AUR_HELPER_PKG}")
            print(f"AUR_BUILD_URL={AUR_HELPER_URL}")
            print("Nothing has been cloned, built or installed from the AUR yet.")

            answer = assume
            if not answer:
                print(f"Build {AUR_HELPER_PKG} from source now? [y/N] ", end="", flush=True)
                try:
                    answer = input()
                except EOFError:
                    answer = ""       # an unanswered prompt is a decline, never an assumed yes
                print()
            answer = "yes" if answer.strip().lower() in ("y", "yes") else "no"

            if answer == "no":
                declined = True
                print("AUR_BOOTSTRAP=declined")
                print("Nothing was cloned and nothing was built. The AUR packages above were not "
                      "installed.")
                for p in aur:
                    txn.append(("failed", p, "aur",
                                f"not installed: the {AUR_HELPER_PKG} source build was declined, "
                                "so there is no AUR helper"))
                    n_failed += 1
            else:
                print("AUR_BOOTSTRAP=building")
                _run(sudo + ["pacman", "-S", "--needed"] + nc + ["base-devel", "git", "rust"])
                build_ok = False
                try:
                    build_tmp = tempfile.mkdtemp(prefix="hypr-rice-aur.")
                except OSError:
                    build_tmp = ""
                if build_tmp:
                    clone = f"{build_tmp}/{AUR_HELPER_PKG}"
                    rc, _ = _run(["git", "clone", AUR_HELPER_URL, clone])
                    if rc == 0:
                        _run(["makepkg", "-si", "--noconfirm"], cwd=clone)
                        build_ok = _helper_works(AUR_HELPER_PKG)
                    shutil.rmtree(build_tmp, ignore_errors=True)
                if build_ok:
                    helper = AUR_HELPER_PKG
                    print("AUR_BOOTSTRAP=built")
                    txn.append(("built-from-source", AUR_HELPER_PKG, AUR_HELPER_URL,
                                "built here with makepkg -si"))
                else:
                    print("AUR_BOOTSTRAP=failed")
                    for p in aur:
                        txn.append(("failed", p, "aur",
                                    f"not installed: the {AUR_HELPER_PKG} source build failed, "
                                    "so there is no AUR helper"))
                        n_failed += 1
        else:
            print(f"AUR_HELPER={helper}")

        # AUR packages install ONE AT A TIME: one aborted build must not take the rest with it.
        if helper:
            for p in aur:
                _, out = _run([helper, "-S", "--needed"] + nc + [p])
                print(out, end="" if out.endswith("\n") else "\n")
                if _installed(p):
                    txn.append(("installed", p, "aur", ""))
                    n_installed += 1
                else:
                    txn.append(("failed", p, "aur", reason_for(p, out)))
                    n_failed += 1
    else:
        print("AUR_BOOTSTRAP=not-needed")

    # --- record it ------------------------------------------------------------------------
    rec_args = [recorder, "record", "--route", route, "--helper", helper or "none"]
    if label:
        rec_args += ["--label", label]
    body = "".join(f"{s}\t{p}\t{o}\t{n}\n" for s, p, o, n in txn)
    try:
        rec = subprocess.run(["bash"] + rec_args, input=body, text=True)
        record_rc = rec.returncode
    except (OSError, subprocess.SubprocessError):
        record_rc = 1

    # --- verdict --------------------------------------------------------------------------
    if declined:
        print("INSTALL=declined-aur-build")
        return 4
    if record_rc != 0:
        # The packages landed, but the account of them did not. Do not call that a clean install.
        print("INSTALL=partial (the packages above were installed, but the record was not written)")
        return 1
    if n_failed > 0 and n_installed == 0 and not present:
        print("INSTALL=failed")
        return 1
    if n_failed > 0:
        print("INSTALL=partial")
        return 0
    print("INSTALL=ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
