# The isolation properties of the preview VM, asserted on the generated QEMU argv.
#
# No VM is started and no GPU is needed: `vm.qemu_argv` is a pure function, and that is exactly
# why it is one.
#
# The lesson this inherits was learned the expensive way on the container design that preceded
# it. There, the docker argv was clean and the container still ended up holding the machine's
# real display device, because `--gpus all` makes the NVIDIA container runtime inject all of
# /dev/dri behind the argv's back. An argv-level check was not sufficient there.
#
# It IS sufficient here, and that is the point of choosing a VM: QEMU gives the guest exactly
# the devices named on its command line, there is no runtime hook adding more, and the guest's
# GPU is a virtio device that does not exist on the host. These assertions keep it that way.

if ! command -v python3 >/dev/null 2>&1; then
    skip "preview vm argv" "python3 missing"
    return 0
fi

tmp="$(mktemp_test_dir preview-vm-argv)"
trap 'rm -rf "$tmp"' EXIT

py() { PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c "$1" 2>&1; }

argv="$(py '
from ricelib.preview import vm
a = vm.qemu_argv(overlay="/cache/overlay.qcow2", display=11, ssh_port=22222,
                 render_node="/dev/dri/renderD128", staging="/tmp/hypr-gen-1",
                 qmp="/cache/qmp.sock", serial="/cache/serial.log")
print("\n".join(a))
')"
if [ -z "$argv" ] || printf '%s' "$argv" | grep -q 'Traceback'; then
    fail "qemu_argv builds an argv" "$argv"
    return 0
fi
pass "qemu_argv builds an argv without a VM, a GPU or a hypervisor"
printf '%s\n' "$argv" > "$tmp/argv"

# --- the guest gets no host hardware -----------------------------------------------------
if grep -q '/dev/dri/card' "$tmp/argv"; then
    fail "no host KMS device reaches the guest" "$(grep -n card "$tmp/argv")"
else
    pass "no host KMS device reaches the guest"
fi
for bad in vfio-pci usb-host; do
    if grep -q "$bad" "$tmp/argv"; then
        fail "no $bad passthrough" "$bad appeared in the argv"
    else
        pass "no $bad passthrough"
    fi
done

# The guest's GPU is virtual. This is what makes the whole design work: Hyprland gets a real
# KMS device to run its DRM backend on, and it is one QEMU invented.
assert_grep '^virtio-gpu-gl-pci$' "$tmp/argv" "the guest's GPU is a virtio device"

# --- nothing is exposed to the network ---------------------------------------------------
assert_grep '^127\.0\.0\.1:11$' "$tmp/argv" "VNC binds to loopback only"
assert_grep 'hostfwd=tcp:127\.0\.0\.1:22222-:22' "$tmp/argv" \
    "the ssh forward binds to loopback only"

bind_guard="$(py '
from ricelib.preview import vm
try:
    vm._check_isolation(["qemu-system-x86_64", "-vnc", "0.0.0.0:11"])
    print("NO_REFUSAL")
except vm.IsolationError:
    print("REFUSED")
')"
assert_eq "REFUSED" "$bind_guard" "binding VNC to a public address is refused, not warned about"

card_guard="$(py '
from ricelib.preview import vm
try:
    vm._check_isolation(["qemu-system-x86_64", "-device", "vfio-pci,host=01:00.0"])
    print("NO_REFUSAL")
except vm.IsolationError:
    print("REFUSED")
')"
assert_eq "REFUSED" "$card_guard" "PCI passthrough is refused"

# --- the disk is the throwaway layer, never the cached base ------------------------------
assert_grep 'file=/cache/overlay\.qcow2,if=virtio,format=qcow2' "$tmp/argv" \
    "the VM boots the overlay, so the cached base is never opened for writing"
if grep -qE 'file=[^ ]*(base|provisioned)\.qcow2,[^ ]*' "$tmp/argv"; then
    fail "the cached base is never attached directly" "$(grep -n 'qcow2' "$tmp/argv")"
else
    pass "the cached base is never attached directly"
fi

# --- the staged config goes in read-only -------------------------------------------------
assert_grep 'path=/tmp/hypr-gen-1,.*readonly=on' "$tmp/argv" \
    "the staged config is shared read-only (the guest cannot write back into it)"

# --- one GPU, so the guest has one predictable output ------------------------------------
assert_grep '^none$' "$tmp/argv" "the default VGA adapter is disabled (-vga none)"

# --- software-rendering fallback still produces a usable argv ----------------------------
soft="$(py '
from ricelib.preview import vm
a = vm.qemu_argv(overlay="/c/o.qcow2", display=12, ssh_port=22223, render_node=None)
print("\n".join(a))
')"
printf '%s\n' "$soft" > "$tmp/argv-soft"
assert_grep '^egl-headless$' "$tmp/argv-soft" \
    "with no render node the VM still starts, just without GPU acceleration"
if grep -q 'rendernode=' "$tmp/argv-soft"; then
    fail "no render node means no rendernode= argument" "$(grep -n rendernode "$tmp/argv-soft")"
else
    pass "no render node means no rendernode= argument"
fi
