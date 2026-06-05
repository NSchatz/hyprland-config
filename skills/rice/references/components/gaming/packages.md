# gaming — packages

Everything this component emits — `allow_tearing`, per-class `immediate` rules, per-monitor
`vrr`, fullscreen effect-strip rules, the `SUPER+F1` bind, and the kernel-gated env line — is
**Hyprland-internal**. No package install is required for the component itself.

The shipped `gamemode.sh` script depends only on `hyprctl` (already installed with Hyprland) and
optionally `libnotify` for the `notify-send` toasts (almost always already present from the
notifications component). Neither needs to be added here.

## Optional

| Pick | Package | Repo / AUR | When | Notes |
|---|---|---|---|---|
| feral gamemode (CPU governor / nice tweaks) | `gamemode` | repo | User wants the system service `gamemoded` so they can prefix Steam launch options with `gamemoderun %command%`. | Pure userspace daemon, no kernel module. Not invoked by our `gamemode.sh` — different tool with the same name. Recommend if the user mentioned "Steam launch options" or "max CPU clock". |

This is **not** added by default. Surface it only if the interviewer agent picks up an explicit
ask for the system service. The component's `gamemode.sh` script is independent: it tweaks
Hyprland's animations / blur / shadows / gaps via `hyprctl keyword`, not CPU governors.

## Assembly rule

```bash
# Only when explicitly opted-in (not from gaming.enabled alone):
[ "$(jq -r '.gaming.system_gamemoded // false' answers.json)" = "true" ] && pkgs+=("gamemode")
```

The `gaming.system_gamemoded` key is **not** part of the standard schema (see
[`schema.md`](schema.md)) — it's a hand-edit-only opt-in for users who specifically want the
service. The interview does not surface it.

## Launch-wrapper tools (documented, never installed by this component)

Mentioned for completeness — these are **Steam launch options**, not Hyprland config:

| Tool | Launch option | Package |
|---|---|---|
| feral gamemode | `gamemoderun %command%` | `gamemode` |
| MangoHud | `mangohud %command%` | `mangohud` |
| gamescope | `gamescope -W <w> -H <h> -f -- %command%` | `gamescope` |

If the user installs `gamescope` separately, note that gamescope does its own VRR / tearing
management — the per-class `immediate` rules above are redundant inside a gamescope session.

## Cross-references

- The kernel-gated env line (`WLR_DRM_NO_ATOMIC,1`) → [`template.md`](template.md) §6 and
  [`gotchas.md`](gotchas.md).
- The shared script-install pattern → [`../utilities/README.md`](../utilities/README.md).
- Package routing (repo vs AUR auto-resolved by `install.sh`) → `skills/rice/scripts/`.
