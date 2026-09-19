#!/usr/bin/env python3
"""`rice preview` - run a generated desktop in a throwaway VM and look at it before applying it.

The preview is a virtual machine, not a container, and the reason is measured rather than
stylistic. Aquamarine builds its GBM allocator only from a backend that exposes a DRM fd
(`Backend.cpp:163-179`; `CHeadlessBackend::drmFD()` returns -1 at `Headless.cpp:133`), so
Hyprland needs either the machine's real display device or a parent compositor. A container can
be given one of those only by taking something from the user's own session. A VM has a virtual
KMS device of its own, so the preview gets a real Hyprland, a real seat and a real keyboard,
and the host session is never touched - which is the point: you can keep working while it runs.

Markers, one terminal line per invocation:
    PREVIEW=started|running|stopped|none|refused-*|failed-*
"""
import os
import shutil
import sys

from .. import clock
from . import guest
from . import guestimage as gi
from . import rfb
from . import session as ss
from . import vm

USAGE = """usage: rice preview <command>

  start [--from <dir>] [--size WxH] [--replace] [--no-install]
                          boot the staged (or given) config in a throwaway VM
  status                  what is running, and how to connect to it
  shot [--out <path>]     screenshot the guest, captured from outside over VNC
  reload [--surface ...]  re-copy the staged config into the guest and reload it in place
  exec -- <command>       run a command inside the guest
  demo                    launch the configured surfaces, for a config that autostarts
                          nothing of its own
  logs [--tail N]         the guest's serial console
  stop                    shut the VM down and discard its disk

The preview never writes to your home directory, never touches your Hyprland session, and has
its own seat and keyboard. `rice preview apply` promotes the exact tree you previewed through
the normal safe-apply path."""


def _err(msg):
    print(msg, file=sys.stderr)


def _opt(args, name, default=None):
    if name in args:
        i = args.index(name)
        if i + 1 < len(args):
            return args[i + 1]
    return default


def _staging_from(args, env):
    """Where the config to preview comes from.

    With no `--from`, the most recent rice staging dir is used. The rice flow creates those as
    /tmp/hypr-gen-<ts>-<pid> (skills/rice/references/modes/generate.md:29) and leaves no pointer
    file, so the newest one is the best available answer and the CLI prints which it picked."""
    if "--from" in args:
        i = args.index("--from")
        if i + 1 >= len(args):
            return None, "--from needs a directory"
        p = os.path.expanduser(args[i + 1])
        if not os.path.isdir(p):
            return None, f"not a directory: {p}"
        return p, ""

    import glob
    candidates = sorted((d for d in glob.glob("/tmp/hypr-gen-*") if os.path.isdir(d)),
                        key=os.path.getmtime, reverse=True)
    if not candidates:
        return None, ("no staged config found. Run the rice flow first, or point at one with "
                      "--from <dir> (a directory of *.conf, or ~/.config/hypr)")
    return candidates[0], ""


def autostart_entries(staging):
    """How many `exec-once` entries the staged config has, and what they launch.

    A rice that autostarts nothing boots to an empty desktop: no bar, no terminal, and with
    `force_default_wallpaper = 0` not even a wallpaper. That is a perfectly valid config and a
    useless preview, so the CLI says so rather than leaving someone looking at a black screen
    wondering whether the VM is broken."""
    import glob as _glob
    import re as _re
    found = []
    for path in sorted(_glob.glob(os.path.join(staging, "*.conf"))):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    m = _re.match(r"\s*exec-once\s*=\s*(.+?)\s*$", line)
                    if m:
                        found.append(m.group(1))
        except OSError:
            continue
    return found


def _paths(env):
    d = gi.cache_dir(env)
    return {
        "pid": os.path.join(d, "qemu.pid"),
        "log": os.path.join(d, "qemu.log"),
        "serial": os.path.join(d, "serial.log"),
        "qmp": os.path.join(d, "qmp.sock"),
    }


def _render_node(env=None):
    """The host render node QEMU uses for virgl, or None for software rendering.

    This is the HOST's GPU accelerating the guest's rendering. It is never handed to the guest:
    the guest only ever sees the virtio GPU."""
    env = os.environ if env is None else env
    forced = env.get("RICE_PREVIEW_RENDER_NODE", "")
    if forced:
        return forced
    try:
        nodes = sorted(n for n in os.listdir("/dev/dri") if n.startswith("renderD"))
    except OSError:
        return None
    return f"/dev/dri/{nodes[0]}" if nodes else None


def cmd_start(args, env):
    paths = _paths(env)

    if vm.alive(paths["pid"]):
        if "--replace" not in args:
            rec = ss.load(env)
            _err(f"a preview is already running (id {rec.id if rec else 'unknown'}). "
                 "Stop it, or pass --replace.")
            print("PREVIEW=refused-already-running")
            return 3
        cmd_stop([], env)

    staging, why = _staging_from(args, env)
    if not staging:
        _err(why)
        print("PREVIEW=refused-no-source")
        return 2

    for tool in ("qemu-system-x86_64", "qemu-img", "xorriso", "ssh"):
        if not shutil.which(tool):
            _err(f"{tool} is required and not installed. The preview needs:\n"
                 "  sudo pacman -S --needed qemu-desktop virglrenderer xorriso openssh")
            print("PREVIEW=refused-missing-tool")
            return 2

    if not vm.have_kvm():
        _err("no access to /dev/kvm. Without it the VM is emulated and far too slow to use.\n"
             "  sudo modprobe kvm_intel   (or kvm_amd), and check you are in the kvm group")
        print("PREVIEW=refused-no-kvm")
        return 2

    key = gi.ensure_key(env)
    if not key:
        _err("could not create the preview ssh key")
        print("PREVIEW=failed-key")
        return 1

    if not gi.have_base(env):
        print(f"FETCHING={gi.BASE_URL}")
        ok, detail = gi.fetch_base(env)
        if not ok:
            _err(detail)
            print("PREVIEW=failed-base-image")
            return 1

    backing = gi.provisioned_path(env) if gi.have_provisioned(env) else gi.base_path(env)
    print(f"BACKING={os.path.basename(backing)}")
    ok, detail = gi.make_overlay(backing, env=env)
    if not ok:
        _err(detail)
        print("PREVIEW=failed-overlay")
        return 1
    overlay = detail

    seed = None
    if backing == gi.base_path(env):
        # First run: the cloud image still needs a user and an authorized key.
        with open(key + ".pub", "r", encoding="utf-8") as fh:
            ok, detail = gi.make_seed(fh.read(), env)
        if not ok:
            _err(detail)
            print("PREVIEW=failed-seed")
            return 1
        seed = detail

    display = vm.free_display()
    ssh_port = vm.free_port()
    if display is None or ssh_port is None:
        _err("no free VNC display or forward port")
        print("PREVIEW=failed-no-port")
        return 1

    argv = vm.qemu_argv(
        overlay=overlay, display=display, ssh_port=ssh_port,
        render_node=_render_node(env), staging=staging,
        qmp=paths["qmp"], serial=paths["serial"], seed=seed,
    )
    started, detail = vm.start(argv, paths["pid"], paths["log"])
    if not started:
        _err(detail)
        print("PREVIEW=failed-start")
        return 1

    rec = ss.Session(
        id=ss.new_id(env), overlay=overlay, source=staging, staging=staging,
        size=_opt(args, "--size", "1280x800"), display=display, ssh_port=ssh_port,
        created=clock.iso_utc(env),
    )
    if not ss.save(rec, env):
        vm.stop(paths["pid"])
        _err("could not write the preview session record; the VM was shut down again.")
        print("PREVIEW=failed-record")
        return 1

    print(f"PREVIEW_ID={rec.id}")
    print(f"PREVIEW_SOURCE={staging}")
    print(f"PREVIEW_VNC=127.0.0.1:{vm.vnc_port(display)}  (gvncviewer 127.0.0.1:{display})")
    print(f"PREVIEW_SSH_PORT={ssh_port}")

    autostart = autostart_entries(staging)
    print(f"PREVIEW_AUTOSTART={len(autostart)}")
    if not autostart:
        _err(
            "note: this config has no `exec-once` entries, so the preview will come up as an\n"
            "empty desktop - no bar, no terminal, and no wallpaper if force_default_wallpaper\n"
            "is 0. That is the config, not a broken VM. Run `rice preview demo` to launch the\n"
            "configured surfaces so you can see the theming."
        )
    print("PREVIEW=started")
    return 0


def cmd_status(args, env):
    paths = _paths(env)
    rec = ss.load(env)
    running = vm.alive(paths["pid"])
    if rec:
        print(f"PREVIEW_ID={rec.id}")
        print(f"PREVIEW_SOURCE={rec.source}")
        if rec.display is not None:
            print(f"PREVIEW_VNC=127.0.0.1:{vm.vnc_port(rec.display)}")
    if running:
        print("PREVIEW=running")
        return 0
    if rec:
        # The record outliving the VM is the orphan case: a disk overlay, a display number and
        # a port are still claimed with nothing running to justify them.
        print("PREVIEW=stopped")
        _err("a preview record exists but no VM is running. `rice preview stop` clears it.")
        return 1
    print("PREVIEW=none")
    return 0


def cmd_stop(args, env):
    paths = _paths(env)
    rec = ss.load(env)
    had = rec is not None or vm.alive(paths["pid"])
    vm.stop(paths["pid"])
    # The overlay is the throwaway layer; the cached base underneath is never touched.
    if rec and rec.overlay:
        try:
            os.unlink(rec.overlay)
        except OSError:
            pass
    ss.clear(env)
    print("PREVIEW=stopped" if had else "PREVIEW=none")
    return 0


def _require_running(env):
    rec = ss.load(env)
    if not rec or not vm.alive(_paths(env)["pid"]):
        _err("no preview is running.")
        return None
    return rec


def cmd_shot(args, env):
    rec = _require_running(env)
    if not rec:
        print("PREVIEW=none")
        return 1
    out = _opt(args, "--out") or os.path.join(gi.cache_dir(env), "preview.png")
    try:
        w, h = rfb.capture("127.0.0.1", vm.vnc_port(rec.display), out)
    except rfb.RfbError as exc:
        _err(f"the screenshot failed: {exc}")
        print("PREVIEW=failed-shot")
        return 1
    print(f"PREVIEW_SHOT={out} ({w}x{h})")
    print("PREVIEW=running")
    return 0


def cmd_reload(args, env):
    rec = _require_running(env)
    if not rec:
        print("PREVIEW=none")
        return 1
    surfaces = [_opt(args, "--surface", "all")]
    rc, out = guest.reload_surfaces(gi.key_path(env), rec.ssh_port, surfaces)
    sys.stdout.write(out)
    print("PREVIEW=running" if rc == 0 else "PREVIEW=failed-reload")
    return 0 if rc == 0 else 1


def cmd_exec(args, env):
    if "--" in args:
        args = args[args.index("--") + 1:]
    if not args:
        _err("nothing to run. Usage: rice preview exec -- <command>")
        return 2
    rec = _require_running(env)
    if not rec:
        print("PREVIEW=none")
        return 1
    rc, out = guest.run(gi.key_path(env), rec.ssh_port, " ".join(args))
    sys.stdout.write(out)
    return rc


def cmd_demo(args, env):
    """Launch the configured surfaces so an otherwise-empty preview can be judged.

    Everything it starts is printed. This exists because judging a theme needs windows on the
    screen, and it must never be mistaken for what the config does on its own."""
    rec = _require_running(env)
    if not rec:
        print("PREVIEW=none")
        return 1
    key = gi.key_path(env)
    started = []
    # Only start a surface the staged config actually themes.
    for app, probe in (("waybar", "~/.config/waybar"),
                       ("mako", "~/.config/mako"),
                       ("kitty", "~/.config/kitty")):
        rc, _ = guest.run(key, rec.ssh_port, f"test -e {probe}", timeout=20)
        if rc == 0 and app != "kitty":
            guest.run(key, rec.ssh_port, f"(setsid {app} >/dev/null 2>&1 &)", timeout=20)
            started.append(app)
    # A terminal always, because it is what shows the font, the palette and the window
    # decoration all at once.
    guest.run(key, rec.ssh_port, "(setsid kitty >/dev/null 2>&1 &)", timeout=20)
    started.append("kitty")
    for name in started:
        print(f"DEMO_STARTED={name}")
    print("PREVIEW=running")
    return 0


def cmd_logs(args, env):
    serial = _paths(env)["serial"]
    tail = _opt(args, "--tail")
    try:
        with open(serial, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        _err(f"no serial log at {serial}")
        return 1
    if tail:
        try:
            lines = lines[-int(tail):]
        except ValueError:
            pass
    sys.stdout.write("".join(lines))
    return 0


COMMANDS = {
    "start": cmd_start,
    "status": cmd_status,
    "stop": cmd_stop,
    "shot": cmd_shot,
    "reload": cmd_reload,
    "exec": cmd_exec,
    "demo": cmd_demo,
    "logs": cmd_logs,
}


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    args = argv[2:]
    if cmd in ("help", "-h", "--help"):
        print(USAGE)
        return 0
    fn = COMMANDS.get(cmd)
    if not fn:
        _err(f"unknown command: {cmd} (try: rice preview help)")
        return 2
    return fn(args, os.environ)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
