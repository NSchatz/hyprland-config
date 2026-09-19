#!/usr/bin/env python3
"""The guest disk: where it lives, how it is made, and why a preview never writes to it.

Three layers, deliberately:

  base.qcow2         the official Arch cloud image, downloaded once
  provisioned.qcow2  that image after Hyprland and the companions are installed, snapshotted
                     so the slow part happens once rather than per preview
  overlay.qcow2      a qcow2 overlay per preview, backed by `provisioned`

The overlay is what makes "throwaway" honest and instant: the preview writes only to it, the
layer underneath is never opened for writing, and discarding a preview is `rm` on a file. It is
also why a preview that wrecks its own system cannot cost anything - the next one starts from
the same clean snapshot.

The ssh key lives here too, not in the repo, and is generated per machine.
"""
import os
import subprocess

from .. import proc

__all__ = [
    "cache_dir", "base_path", "provisioned_path", "overlay_path", "key_path", "seed_path",
    "BASE_URL", "have_base", "have_provisioned", "fetch_base", "make_overlay", "make_seed",
    "ensure_key", "provision", "snapshot_provisioned", "script_dir",
]

BASE_URL = ("https://geo.mirror.pkgbuild.com/images/latest/"
            "Arch-Linux-x86_64-cloudimg.qcow2")

# The guest package list deliberately lives in tests/preview/provision.sh, where it is actually
# executed, rather than being duplicated here where it would drift.

def cache_dir(env=None):
    """Where the guest images live. Big, regenerable, and not the user's config."""
    env = os.environ if env is None else env
    override = env.get("RICE_PREVIEW_CACHE", "")
    if override:
        return override
    base = env.get("XDG_CACHE_HOME") or os.path.join(env.get("HOME", ""), ".cache")
    return os.path.join(base, "hypr-preview")


def base_path(env=None):
    return os.path.join(cache_dir(env), "base.qcow2")


def provisioned_path(env=None):
    return os.path.join(cache_dir(env), "provisioned.qcow2")


def overlay_path(env=None, name="overlay"):
    """The throwaway disk. `name` exists so provisioning cannot clobber a running preview:
    both need an overlay, and they must not be the same file."""
    return os.path.join(cache_dir(env), f"{name}.qcow2")


def key_path(env=None):
    return os.path.join(cache_dir(env), "id_preview")


def seed_path(env=None):
    return os.path.join(cache_dir(env), "seed.iso")


def have_base(env=None):
    return os.path.isfile(base_path(env))


def have_provisioned(env=None):
    return os.path.isfile(provisioned_path(env))


def ensure_key(env=None):
    """An ssh keypair for the control channel, generated per machine. Returns the path or None."""
    key = key_path(env)
    if os.path.isfile(key) and os.path.isfile(key + ".pub"):
        return key
    os.makedirs(cache_dir(env), exist_ok=True)
    rc, _ = proc.run(["ssh-keygen", "-t", "ed25519", "-N", "", "-C", "hypr-preview",
                      "-f", key, "-q"])
    return key if rc == 0 else None


def fetch_base(env=None, url=BASE_URL):
    """Download the cloud image. Returns (ok, detail).

    Downloads to a `.part` and renames, so an interrupted fetch never leaves a truncated file
    that later looks cached."""
    os.makedirs(cache_dir(env), exist_ok=True)
    dest = base_path(env)
    part = dest + ".part"
    rc, out = proc.run(["curl", "-fL", "--retry", "3", "-o", part, url])
    if rc != 0:
        try:
            os.unlink(part)
        except OSError:
            pass
        return False, out.strip()[-500:]
    try:
        os.replace(part, dest)
    except OSError as exc:
        return False, str(exc)
    return True, dest


def make_seed(pubkey_text, env=None):
    """Build the cloud-init NoCloud seed that creates the user and enables ssh.

    `xorriso` rather than `cloud-localds`, because xorriso is already a dependency of things
    people have and cloud-image-utils usually is not."""
    d = cache_dir(env)
    seed_dir = os.path.join(d, "seed")
    os.makedirs(seed_dir, exist_ok=True)
    with open(os.path.join(seed_dir, "meta-data"), "w", encoding="utf-8") as fh:
        fh.write("instance-id: hypr-preview-0\nlocal-hostname: hypr-preview\n")
    with open(os.path.join(seed_dir, "user-data"), "w", encoding="utf-8") as fh:
        fh.write(
            "#cloud-config\n"
            "users:\n"
            "  - name: preview\n"
            "    sudo: ALL=(ALL) NOPASSWD:ALL\n"
            "    shell: /bin/bash\n"
            "    lock_passwd: false\n"
            "    plain_text_passwd: preview\n"
            "    ssh_authorized_keys:\n"
            f"      - {pubkey_text.strip()}\n"
            "ssh_pwauth: true\n"
            "growpart:\n"
            "  mode: auto\n"
            "  devices: ['/']\n"
            "runcmd:\n"
            "  - [ systemctl, enable, --now, sshd ]\n"
        )
    out = seed_path(env)
    rc, detail = proc.run([
        "xorriso", "-as", "mkisofs", "-output", out, "-volid", "cidata",
        "-joliet", "-rock",
        os.path.join(seed_dir, "user-data"), os.path.join(seed_dir, "meta-data"),
    ])
    return (rc == 0, out if rc == 0 else detail.strip()[-400:])


def make_overlay(backing, size="40G", env=None, name="overlay"):
    """A fresh throwaway overlay over `backing`. Any previous overlay of that name is discarded.

    40G is virtual, not allocated: a qcow2 overlay costs what is written to it. It is generous
    because a full rice install pulls fonts, a browser and a toolchain, and running out of disk
    halfway through an install.sh is a confusing way to fail."""
    out = overlay_path(env, name)
    try:
        os.unlink(out)
    except FileNotFoundError:
        pass
    except OSError as exc:
        return False, str(exc)
    rc, detail = proc.run([
        "qemu-img", "create", "-f", "qcow2",
        "-b", backing, "-F", "qcow2", out, size,
    ])
    return (rc == 0, out if rc == 0 else detail.strip()[-400:])


def script_dir(root):
    """Where the guest-side scripts live in the plugin checkout."""
    return os.path.join(root, "tests", "preview")


def provision(root, env=None, out=print):
    """Turn the stock cloud image into a preview guest, once, and cache the result.

    This is the step that used to be done by hand, which meant the cached image on one machine
    could not be reproduced on another. It boots the base image with a cloud-init seed, installs
    the minimal package set plus the toolchain a plugin or an AUR build needs, copies in the
    guest session scripts, shuts the guest down CLEANLY so the filesystem is flushed, and
    flattens the result into `provisioned.qcow2`.

    Returns (ok, detail)."""
    from . import guest
    from . import vm

    key = ensure_key(env)
    if not key:
        return False, "could not create the preview ssh key"
    if not have_base(env):
        out(f"FETCHING={BASE_URL}")
        ok, detail = fetch_base(env)
        if not ok:
            return False, f"could not fetch the base image: {detail}"

    with open(key + ".pub", "r", encoding="utf-8") as fh:
        ok, seed = make_seed(fh.read(), env)
    if not ok:
        return False, f"could not build the cloud-init seed: {seed}"

    ok, overlay = make_overlay(base_path(env), env=env, name="provision-overlay")
    if not ok:
        return False, f"could not create the overlay: {overlay}"

    d = cache_dir(env)
    pidfile = os.path.join(d, "provision.pid")
    qmp = os.path.join(d, "provision-qmp.sock")
    for stale in (qmp,):
        try:
            os.unlink(stale)
        except OSError:
            pass

    display = vm.free_display()
    port = vm.free_port()
    if display is None or port is None:
        return False, "no free display or port for the provisioning VM"

    argv = vm.qemu_argv(
        overlay=overlay, display=display, ssh_port=port,
        render_node=None,                      # provisioning needs no GPU
        seed=seed, qmp=qmp,
        serial=os.path.join(d, "provision-serial.log"),
    )
    started, detail = vm.start(argv, pidfile, os.path.join(d, "provision-qemu.log"))
    if not started:
        return False, f"could not start the provisioning VM: {detail}"

    try:
        out("PROVISION_PHASE=booting")
        ready, waited = guest.wait_ready(key, port, timeout=300)
        if not ready:
            return False, f"the provisioning guest never came up (waited {waited}s)"
        out(f"PROVISION_PHASE=booted ({waited}s)")

        scripts = [os.path.join(script_dir(root), n)
                   for n in ("provision.sh", "guest-session.sh", "guest-apply.sh")]
        missing = [s for s in scripts if not os.path.isfile(s)]
        if missing:
            return False, f"guest scripts missing from the checkout: {missing}"
        if not guest.copy_in(key, port, scripts, "/tmp/"):
            return False, "could not copy the guest scripts in"

        # guest-apply.sh has to be in place before provision.sh installs the session, because
        # the session script it writes invokes it by that path.
        guest.run(key, port, "mkdir -p ~/.local/bin && install -Dm755 /tmp/guest-apply.sh "
                             "~/.local/bin/guest-apply.sh", timeout=60, with_session=False)

        out("PROVISION_PHASE=installing (this is the slow part)")
        rc, output = guest.run(key, port, "bash /tmp/provision.sh", timeout=2400,
                               with_session=False)
        for line in output.splitlines():
            if line.startswith(("PROVISION", "AUR_HELPER")):
                out(line)
        if rc != 0 or "PROVISION=ok" not in output:
            return False, f"provisioning failed inside the guest:\n{output[-1500:]}"

        out("PROVISION_PHASE=shutting-down")
        guest.run(key, port, "sync", timeout=60, with_session=False)
        if not vm.powerdown(qmp):
            return False, "could not shut the provisioning guest down cleanly"
        if not vm.wait_gone(pidfile, timeout=120):
            return False, "the provisioning guest did not shut down"
    finally:
        vm.stop(pidfile)

    out("PROVISION_PHASE=snapshotting")
    ok, detail = snapshot_provisioned(env, name="provision-overlay")
    if not ok:
        return False, f"could not snapshot the provisioned image: {detail}"
    try:
        os.unlink(overlay)
    except OSError:
        pass
    return True, detail


def snapshot_provisioned(env=None, name="overlay"):
    """Promote the current overlay to the cached provisioned base.

    Flattening matters: a provisioned image that still referenced the overlay would break the
    moment the next preview recreated it."""
    rc, detail = proc.run([
        "qemu-img", "convert", "-O", "qcow2",
        overlay_path(env, name), provisioned_path(env) + ".tmp",
    ])
    if rc != 0:
        return False, detail.strip()[-400:]
    try:
        os.replace(provisioned_path(env) + ".tmp", provisioned_path(env))
    except OSError as exc:
        return False, str(exc)
    return True, provisioned_path(env)
