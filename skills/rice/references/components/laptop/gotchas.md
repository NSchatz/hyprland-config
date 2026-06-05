# laptop — gotchas

## (a) Double-handling: Hyprland `bindl` + systemd-logind both act on the lid

`systemd-logind`'s default is `HandleLidSwitch=suspend` — and it fires on the *kernel* lid event,
independently of Hyprland. If the user picks `lid_action = suspend` (or `lock`, or `clamshell`)
without telling logind to back off, **both** handlers run: logind suspends the machine *and*
Hyprland fires `systemctl suspend` (or `loginctl lock-session`) at roughly the same time. Visible
symptoms are double-wake races, the lock screen appearing twice on resume, or `clamshell` failing
because logind suspends before the `hyprctl keyword monitor` runs.

The fix is **root-side and the agent does NOT run it** — it prints the snippet to the install
output. In `/etc/systemd/logind.conf`:

```
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

Then `sudo systemctl restart systemd-logind`. The user runs this; the agent only documents it.

Skipping this snippet is the single most common reason a generated laptop config "kind of works
but does weird things on lid close". See `template.md` → "Root-side: `/etc/systemd/logind.conf`".

## (b) PPD, TLP, and auto-cpufreq are mutually exclusive

Never enable two together. They all fight for the same kernel knobs (`scaling_governor`, EPP,
platform-profile, intel_pstate hints). Concrete failure modes:

- **PPD + TLP** → TLP sets a profile, PPD overrides it on the next D-Bus event, both write
  conflicting EPP values; the system oscillates between "balanced" and TLP's `TLP_DEFAULT_MODE`.
- **PPD + auto-cpufreq** → auto-cpufreq's adaptive governor is overwritten every time PPD switches
  profile; users see "performance mode does nothing".
- **TLP + auto-cpufreq** → both daemons race on `scaling_governor`; symptoms are random throttling.

Enforcement is at two levels:

1. **Interview level** — sub-question 21c is single-select. The schema records exactly one of
   `ppd | tlp | auto-cpufreq | none`.
2. **Installer level** — `hyprland-package-installer` adds only the one package mapped from
   `laptop.power_tool`. If detection (`POWER_TOOL=tlp`) shows the user *already has* a different
   tool installed, the install batch does **not** auto-remove it; the install output prints a
   `# WARNING: tlp is installed; you picked ppd — uninstall tlp or stop+disable its service
   before enabling ppd.` line. Removal is the user's call.

## (c) PPD pairs with the waybar `power-profiles-daemon` module

The waybar power-profiles-daemon module talks to PPD over D-Bus (`net.hadess.PowerProfiles`). It
is meaningful **only** when `laptop.power_tool == "ppd"`. The waybar template branches on the key
(see `../waybar/template.md`):

- `power_tool == "ppd"` → enable the module, add it to the bar's module list, theme its three
  states (`performance` / `balanced` / `power-saver`) against the palette.
- `power_tool == "tlp"` → no equivalent module ships with waybar by default; the user gets a
  static `tlp-stat -s` reading via `custom/tlp` if they want it (not auto-added).
- `power_tool == "auto-cpufreq"` → same as TLP; no default module.
- `power_tool == "none"` / `null` → no module.

A waybar config that lists `power-profiles-daemon` when PPD isn't installed will silently hide the
module on startup; not catastrophic, but worth catching during validation. The validator should
flag the mismatch.

## (d) Battery charge limit is root-side — generate, document, don't run

The kernel attribute at `/sys/class/power_supply/BAT*/charge_control_end_threshold` is owned by
root, and writes don't persist across reboot (it's a sysfs node, not a setting). The two viable
persistence paths:

- **Systemd one-shot** (PPD / auto-cpufreq / none users) → generator emits
  `battery-charge-limit.service` to the staging dir and prints the `sudo install …` +
  `sudo systemctl enable --now` commands.
- **TLP path** (`power_tool == "tlp"`) → `STOP_CHARGE_THRESH_BAT0=80` in `/etc/tlp.conf`. The
  generator prints the snippet; TLP applies it on its own service start. **Do not emit the
  one-shot when TLP is the picked tool** — they will write the same attribute on different
  schedules and TLP will "win" inconsistently, surfacing as the limit "sometimes not sticking".

The agent never runs `sudo`, never touches `/etc/`, never calls `systemctl`. Its role is: emit the
unit file to staging, print the exact commands to the user, and stop.

## (e) Touchpad config is NOT here — `../input/`

Every `input { touchpad { … } }` sub-question (`tap-to-click`, `natural_scroll`,
`disable_while_typing`, `clickfinger_behavior`, gestures) is part of group 2. If the interview
asks them again here, that's a bug — go re-read `_interview-protocol.md` → "Components walked (in
order)". Group 2 fires regardless of chassis detection (a wired touchpad on a desktop is
possible); group 21 is the opt-in laptop policy layer on top.

## (f) Brightness / volume / media binds are NOT here — `../keybinds/`

`bindel = , XF86MonBrightnessUp, exec, brightnessctl set 5%+` (and the matching down, mute,
volume up/down, media keys) live in the default `binds.conf` block owned by
`../keybinds/template.md`. They are emitted on every install — desktop keyboards have these keys
too. Re-asking them in the laptop interview would be redundant; emitting them from this template
would duplicate them in `binds.conf`.

## (g) Internal panel detection can fail at generate-time

The `clamshell` `lid_action` needs the internal panel's Hyprland output name (`eDP-1`, `LVDS-1`,
sometimes `eDP-2` on dual-iGPU machines). The generator should call `hyprctl monitors -j` and
pick the output flagged `"description"` containing `eDP` or `LVDS`. If detection fails (running
the generator offline, or in a TTY before Hyprland has started), emit the line **commented out**
with a TODO so the reload doesn't error, and surface the TODO in the install output.

## (h) Version branches

`bindl` and `switch:on:`/`switch:off:` device events have been stable since well before 0.45 —
no version branching is needed for this component. The validator does not flag any `laptop` line
against the version matrix.

## Cross-references

- Strict-ask discipline (why the gate is always asked even when `IS_LAPTOP=0`)
  → `../../_interview-protocol.md`
- Where the lid bind lands → `template.md`
- Waybar's branch on `power_tool` → `../waybar/template.md`
- Touchpad config (NOT here) → `../input/`
- Brightness binds (NOT here) → `../keybinds/`
- `bindl` flag semantics → `../../_shared/dispatchers.md`
