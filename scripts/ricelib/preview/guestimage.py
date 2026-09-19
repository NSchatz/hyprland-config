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
    "ensure_key",
]

BASE_URL = ("https://geo.mirror.pkgbuild.com/images/latest/"
            "Arch-Linux-x86_64-cloudimg.qcow2")

# What a preview guest needs to be a desktop at all. The rice's own generated install.sh runs
# on top of this and pulls whatever the interview actually picked.
GUEST_PACKAGES = (
    "hyprland kitty waybar wofi mako grim jq "
    "ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji mesa"
)


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


def overlay_path(env=None):
    return os.path.join(cache_dir(env), "overlay.qcow2")


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


def make_overlay(backing, size="24G", env=None):
    """A fresh throwaway overlay over `backing`. Any previous overlay is discarded."""
    out = overlay_path(env)
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


def snapshot_provisioned(env=None):
    """Promote the current overlay to the cached provisioned base.

    Flattening matters: a provisioned image that still referenced the overlay would break the
    moment the next preview recreated it."""
    rc, detail = proc.run([
        "qemu-img", "convert", "-O", "qcow2",
        overlay_path(env), provisioned_path(env) + ".tmp",
    ])
    if rc != 0:
        return False, detail.strip()[-400:]
    try:
        os.replace(provisioned_path(env) + ".tmp", provisioned_path(env))
    except OSError as exc:
        return False, str(exc)
    return True, provisioned_path(env)
