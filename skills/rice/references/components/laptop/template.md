# laptop — template

This component has two output channels:

1. **Hyprland-side** — a single `bindl` line (sometimes two, for clamshell) merged into the
   `binds.conf` table owned by `../keybinds/template.md`.
2. **Root-side** — `/etc/systemd/logind.conf` overrides, the power-tool daemon enable, and the
   battery-charge-limit unit. **These are printed as `sudo` commands in the install output, not
   written to disk by the generator.** The generator does emit the charge-limit `.service` file
   to the staging dir so the user can `sudo install` it.

Only the Hyprland-side line touches `~/.config/`. Everything else is documentation the user runs.

## Hyprland: line(s) emitted into `binds.conf`

Branch on `laptop.enabled` and `laptop.lid_action`:

```ini
{{#if (and laptop.enabled (ne laptop.lid_action "nothing"))}}
# Lid switch — from laptop.lid_action = {{laptop.lid_action}}
{{#switch laptop.lid_action}}
  {{#case "suspend"}}
bindl = , switch:on:Lid Switch, exec, systemctl suspend
  {{/case}}
  {{#case "lock"}}
bindl = , switch:on:Lid Switch, exec, loginctl lock-session
  {{/case}}
  {{#case "clamshell"}}
bindl = , switch:on:Lid Switch,  exec, hyprctl keyword monitor "{{INTERNAL_PANEL}}, disable"
bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "{{INTERNAL_PANEL}}, preferred, auto, 1"
  {{/case}}
{{/switch}}
{{/if}}
```

- `{{INTERNAL_PANEL}}` is detected at generate-time from `hyprctl monitors -j` — the eDP / LVDS
  output. If detection fails, emit the line **commented out** with a `# TODO: replace eDP-1 with
  your internal panel name (hyprctl monitors)` so reload doesn't error.
- `bindl` (`l` flag) is required: the bind must fire while the screen is locked, otherwise closing
  the lid on a locked session is a no-op. See `_shared/dispatchers.md` → "Bind-flag composition".
- The `switch:on:Lid Switch` device name comes from libinput; verify against `hyprctl devices`
  (some firmwares report `LID0` or `Lid 0`). The generator should run `hyprctl devices -j` at
  generate-time and substitute the actual name when it differs.
- When `lid_action == "nothing"`, **emit no line**. Leaving an empty `bindl` would be a parse error.

## Hyprland: nothing else lands in any `.conf`

Brightness / volume / media keys (`XF86MonBrightness*`, `XF86Audio*`) are owned by
`../keybinds/template.md` and emitted unconditionally for every install — they are not gated on
`laptop.enabled` because keyboards on desktops have them too.

## Root-side: `/etc/systemd/logind.conf`  *(documented; never written)*

The interview-driven generator prints this to the install output. **Do not run `sudo` from the
agent.** If `laptop.lid_action != "nothing"`, append the snippet below — otherwise the lid event
gets handled twice (logind's default + the `bindl`), producing visible double-suspend / wake races.

```
# Append to /etc/systemd/logind.conf and reload:
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore

# Then:
sudo systemctl restart systemd-logind
```

The agent's install output should print these lines verbatim, prefaced with "Run as root to stop
logind from also acting on the lid:". See `gotchas.md` § a.

## Root-side: power-tool daemon  *(documented; never run)*

The package itself is installed by `hyprland-package-installer` reading `packages.md`. Enabling
the daemon is root-side. Branch on `laptop.power_tool`:

| `power_tool` | Command printed to install output |
|---|---|
| `"ppd"` | `sudo systemctl enable --now power-profiles-daemon.service` |
| `"tlp"` | `sudo systemctl enable --now tlp.service` (and `sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket` if TLP's rfkill conflict bites) |
| `"auto-cpufreq"` | `sudo systemctl enable --now auto-cpufreq.service` |
| `"none"` / `null` | (no command printed) |

PPD also enables the `power-profiles-daemon` waybar module (see `../waybar/template.md` — that
template reads `laptop.power_tool` and conditionally enables the module). TLP and auto-cpufreq
have no waybar module by default.

## Root-side: battery charge limit  *(unit emitted to staging; sudo install documented)*

If `laptop.charge_limit != null`, the generator writes a one-shot unit to
`<staging>/etc/systemd/system/battery-charge-limit.service`:

```ini
[Unit]
Description=Set battery charge limit to {{charge_limit}}%
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do echo {{charge_limit}} > "$f"; done'

[Install]
WantedBy=multi-user.target
```

And prints to the install output:

```
sudo install -m644 <staging>/etc/systemd/system/battery-charge-limit.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now battery-charge-limit.service
```

**TLP override:** when `power_tool == "tlp"`, the preferred path is `STOP_CHARGE_THRESH_BAT0=80`
in `/etc/tlp.conf`. The generator should print that snippet instead of the one-shot — TLP owns
the threshold attribute and a separate one-shot will fight it.

## What does NOT land here

- Per-monitor dock/undock profiles (kanshi / shikane). Owned by `../monitors/template.md`.
- Touchpad config. Owned by `../input/template.md`.
- `hypridle` / `hyprlock` config. Owned by `../lock-screen/` and `../companion-daemons/`.
  The `loginctl lock-session` lid bind merely triggers hyprlock via hypridle's lock listener.
- Brightness / volume / media binds. Owned by `../keybinds/template.md`.

## Cross-references

- Bind-flag semantics (`bindl`), switch-device syntax → `../../_shared/dispatchers.md`
- Validator's branch on `laptop.power_tool` for waybar → `../waybar/template.md`
- Why `HandleLidSwitch*=ignore` is documented and not run → `gotchas.md` § a, § d
- Package list keyed off `power_tool` → `packages.md`
