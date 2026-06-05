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

Tool-specific conflict notes (all from upstream docs):

- **Arch's `tlp` package conflicts with `power-profiles-daemon`** at the pacman level —
  installing tlp will prompt to remove PPD
  (<https://linrunner.de/tlp/installation/arch.html>).
- **`auto-cpufreq` from the AUR does NOT auto-mask PPD** — its README warns the user must run
  `sudo systemctl mask power-profiles-daemon.service` manually after install
  (<https://github.com/AdnanHodzic/auto-cpufreq>). The install output prints this line when
  `power_tool == "auto-cpufreq"`.
- **TLP 1.6+ also auto-skips conflicting settings** when it detects PPD at runtime, but only
  emits a log warning rather than refusing to start — so the user can still end up in a
  half-broken state if both are enabled.

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
- **TLP path** (`power_tool == "tlp"`) → **both** `START_CHARGE_THRESH_BAT0=75` and
  `STOP_CHARGE_THRESH_BAT0=80` in `/etc/tlp.conf`. TLP rejects the pair entirely if only the stop
  threshold is set ("You must always specify both charge thresholds … otherwise TLP will reject
  both thresholds" — <https://linrunner.de/tlp/settings/battery.html>). The generator prints the
  snippet; TLP applies it on its own service start. **Do not emit the one-shot when TLP is the
  picked tool** — they will write the same attribute on different schedules and TLP will "win"
  inconsistently, surfacing as the limit "sometimes not sticking".

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

## (i) Two community camps on lid handling — bind explicitly vs. delegate to logind

Looking at how the top corpus repos actually ship a default lid action splits cleanly in two:

- **Explicit `bindl`** — JaKooLit (`config/hypr/UserConfigs/Laptops.conf` commented examples
  showing `bindl = , switch:on:Lid Switch, exec, hyprctl keyword monitor "eDP-1, disable"`),
  ML4W (`hl.bind` calls with `{ locked = true }` for every `XF86*` key), and the laptop opt-in
  flow this component implements.
- **Delegate to `systemd-logind`** — end-4/dots-hyprland ships the lid bind **commented out**
  in `dots/.config/hypr/hyprland/keybinds.lua`:
  `-- hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), {locked = true} ) -- # [hidden] Suspend when laptop lid is closed, uncomment if for whatever reason it's not the default behavior`.
  The user is expected to let logind's default `HandleLidSwitch=suspend` do the work.

Both camps are valid; this component's interview picks camp (a) (explicit bind) because the
chosen action is theming-coherent — e.g. `lid_action == "lock"` flows through `loginctl
lock-session` → hypridle's `listener { on-lock = hyprlock; }` → hyprlock, which is the
lock-screen component's themed surface. Delegating to logind would still trigger
`before_sleep_cmd = loginctl lock-session` (the hypridle pattern every corpus rice uses
verbatim — see Ax-Shell `config/hypr/hypridle.conf`, JaKooLit `config/hypr/hypridle.conf`),
so the rice would still look right; the user just doesn't get to pick `clamshell` or `nothing`
without further config.

If the user picks `nothing`, the install output must still print the
`HandleLidSwitch*=ignore` snippet — otherwise logind keeps acting and `nothing` doesn't
actually do nothing. (Already covered by § a; calling it out here as the corpus reason
both camps exist.)

## (j) Brightness/volume OSD is the only theme-coupled laptop surface

The lid bind, power-tool daemon, and charge-limit unit are theming-orthogonal — they fire
behaviors, not pixels. The one laptop-adjacent surface that DOES render pixels in the rice
palette is the brightness / volume / mute OSD, and the corpus shows four mutually exclusive
routing strategies for it:

| Strategy | Where the OSD pixels live | Rices |
|---|---|---|
| **In-shell (Quickshell)** | The shell renders its own OSD QML, theme-coupled to matugen output. Bind calls a Quickshell IPC method, not `brightnessctl` directly. | end-4 (`qs ipc call brightness increment`), caelestia, AvengeMedia/DankMaterialShell |
| **`swayosd-client`** | A separate `swayosd-server` daemon draws the OSD; styling lives in a GTK CSS that's NOT auto-themed by matugen unless the rice ships a matugen template for it. | Matt-FTW (`bindle = , XF86MonBrightnessUp, exec, swayosd-client --brightness +10`) — but Matt-FTW ships no swayosd theme, so the OSD uses defaults and doesn't match the rest of the rice. **This is the most common cross-surface coherence miss in the corpus.** |
| **mako/swaync notification with `[app-name=OSD]` rule** | The notification daemon renders the OSD as a transient notification; palette comes from the notification daemon's matugen template. | dusky (`~/user_scripts/mako_osd/osd_router/osd_router.sh` + a `[app-name=OSD]` block in `.config/matugen/templates/mako.ini`), HyDE (`batterynotify.sh` → `notify-send -u CRITICAL`), JaKooLit (`config/hypr/scripts/Brightness.sh` → `notify-send -h int:value:N -u low`) |
| **Hardcoded brightnessctl with no OSD** | Bind fires `brightnessctl` directly, no visual feedback. The user sees nothing change unless they're looking at the screen brightness. | binnewbs partially (no dedicated OSD script in tree) |

Theming implication: when the lock-screen / notifications / look-feel components pick a
matugen-driven palette, **the OSD routing is what determines whether the brightness
indicator inherits that palette**. The rice's coherence depends on it. The waybar
`#battery.critical` CSS is the other touchpoint (see § k).

This component does **not** own OSD routing — that's split across `../notifications/`
(mako/swaync/dunst CSS), `../widgets/` (if Quickshell/AGS draws the OSD), or `../utilities/`
(if `swayosd` is shipped as a package). What this component does is **flag** to the
orchestrator which surface the user's chosen `power_tool` and `lid_action` make most
coherent. Open question for the orchestrator: should the laptop interview ask for the OSD
routing strategy too, or should it stay implicit and defer to the notification / widget
component's choice?

## (k) `#battery.critical` is a cross-surface coherence touchpoint

Across waybar rices, the battery module's critical class is the single most prominent
"laptop affects theme" pixel. Three palette strategies in the corpus:

- **Palette-keyed (`@error`, Material role)** — dusky (`.config/waybar/01_mechabar_h/style.css`):
  ```css
  #memory.critical, #cpu.critical, #battery.critical { color: @error; }
  #battery.charging { color: @on_tertiary_container; }
  ```
  This is the right shape for a theming-first plugin: the matugen template emits
  `@define-color error …` and every component's critical/error state references it.
- **Palette-keyed (`@red`, named palette)** — JaKooLit (`config/waybar/style/[Catppuccin] Mocha.css`):
  ```css
  #battery { color: @green; }
  #battery.critical:not(.charging) { background-color: @red; color: @theme_text_color; animation-name: blink; }
  ```
  Works for a named-palette rice (Catppuccin, Tokyo Night, Gruvbox) where `@red`/`@green`
  are stable engine outputs; less ideal for matugen which doesn't emit a `@red` by default.
- **Hard-coded hex (anti-pattern)** — ML4W (`dotfiles/.config/waybar/themes/default/style.css`)
  and binnewbs (`.config/waybar/style/islands.css`) both ship `#f53c3c` literal:
  ```css
  #battery.critical:not(.charging) { background-color: #f53c3c; color: #ffffff; animation: blink 0.5s infinite; }
  ```
  Re-theming the rice silently leaves the critical battery red regardless of palette —
  exactly the class of bug v0.13 caught for other components.

The rice's waybar component's `.tmpl` must wire `#battery.critical`'s color to the palette
key (`error` for Material/matugen-driven; the named palette's `red` for a Catppuccin-style
rice). The waybar component owns the actual CSS; this component owns the answer
(`laptop.power_tool == "ppd"`) that decides whether the battery module is even enabled in
the first place. No `.tmpl` change is needed here — flagging the touchpoint so the waybar
agent's deep-research pass knows to check it.

## (l) Blink animation on `#battery.critical` is the default — keep it palette-aware

JaKooLit, ML4W, and binnewbs all ship a `@keyframes blink` on the critical battery class.
Three observed shapes:

- JaKooLit fades to `@surface0` (Catppuccin palette key) over 3s, alternating —
  palette-coherent.
- ML4W fades to nothing (`color: #fff`) over 0.5s linear infinite — fast and palette-blind.
- binnewbs doesn't animate, only colors.

The recommended shape for a matugen/palette-first rice is the JaKooLit pattern but with
`@on_surface` or `@surface_container_low` as the fade target (matugen Material roles), not
a literal. This keeps the blink coherent across re-themes.

This component does not emit waybar CSS, so it doesn't apply the rule directly — but the
waybar component's recipe should reference it. Cross-ref → `../waybar/styling.md` § battery /
critical-state styling.

## (m) `XF86KbdBrightness*` is asus/lenovo-specific — not a default bind

JaKooLit's `config/hypr/configs/Laptops.conf` ships `binde = , xf86KbdBrightnessDown, exec,
$scriptsDir/BrightnessKbd.sh --dec` for keyboard backlight, but most laptops don't expose
that key (Lenovo ThinkPads via `asusctl led-mode` for the `XF86Launch3` button, ASUS ROG
via `rog-control-center` for `XF86Launch1`, etc.). Don't add these to the default bind
table unless the chassis / vendor detection turns them on — they'll just be no-ops on
generic hardware. This component does not enable them; if a future interview adds vendor
detection (`asusctl` / `tuxedo-control-center`), THAT layer would add them.

## (n) `before_sleep_cmd = loginctl lock-session` is the cross-component hand-off

When `laptop.lid_action == "suspend"`, the chain is: `bindl` fires `systemctl suspend`
→ systemd-logind emits `org.freedesktop.login1.Manager.PrepareForSleep` → hypridle's
`before_sleep_cmd = loginctl lock-session` fires → hypridle's `lock_cmd = pidof hyprlock ||
hyprlock` runs → hyprlock renders the themed lock screen → suspend completes. Every corpus
rice that ships hypridle uses this exact pattern verbatim (JaKooLit `config/hypr/hypridle.conf`,
Ax-Shell `config/hypr/hypridle.conf`, end-4 `dots/.config/hypr/hypridle.conf`). If the user
disables hypridle (`companion_daemons.hypridle == false`), `lid_action == "suspend"` will
suspend WITHOUT locking first — the lock-screen palette never renders. Document this in the
install output when both conditions hold. The chain matters for theming because suspend
→ unlock is when the lock-screen rice palette is most visible.

## Cross-references

- Strict-ask discipline (why the gate is always asked even when `IS_LAPTOP=0`)
  → `../../_interview-protocol.md`
- Where the lid bind lands → `template.md`
- Waybar's branch on `power_tool` → `../waybar/template.md`
- Touchpad config (NOT here) → `../input/`
- Brightness binds (NOT here) → `../keybinds/`
- `bindl` flag semantics → `../../_shared/dispatchers.md`
