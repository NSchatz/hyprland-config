# laptop

Laptop-specific wiring: lid-close behavior, the power-profile daemon, and an optional battery
charge limit. **This is an opt-in component with a gate.** The chassis detector
(`scripts/detect-version.sh` → `IS_LAPTOP=1`) only sets the **default** of the gate — the user is
always asked, and can always pick the other answer. A short interview is a failed interview; the
gate is never skipped.

On **no** the rest of the component is skipped and `laptop.enabled = false` is recorded. On **yes**
the interview walks 21b → 21c → 21d.

What this component does **not** own:

- **Touchpad config** — `tap-to-click`, `natural_scroll`, `disable_while_typing`, gesture sub-questions.
  That's `../input/` (group 2). Asking it twice in the same interview is a bug.
- **Brightness / volume / media keys** — `bindel = , XF86MonBrightnessUp, exec, brightnessctl …`
  and the `XF86Audio*` binds live in the default `binds.conf` block in `../keybinds/`. They are
  not re-asked here even when the chassis is a laptop.
- **Per-monitor dock / undock profiles** — kanshi/shikane profiles for "plugged into dock vs.
  bare laptop" live in `../monitors/` (group 1, `monitors.dock_undock`).

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | The opt-in gate (21a) + sub-questions 21b (lid action), 21c (power tool), 21d (charge limit). Record-answer paths. |
| `schema.md` | The `laptop.{enabled, lid_action, power_tool, charge_limit}` slice of `answers.json` and its types. |
| `template.md` | The single `bindl = , switch:on:Lid Switch, …` line emitted into `binds.conf`. Plus **root-side documentation** (printed as commands to the user, not written to disk by the generator): the `/etc/systemd/logind.conf` override, `systemctl enable --now <daemon>`, and the charge-limit one-shot unit. |
| `gotchas.md` | Double-handling between Hyprland's `bindl` and `systemd-logind`; PPD / TLP / auto-cpufreq are mutually exclusive; PPD pairs with waybar's power module; charge limit is root-side (document, don't run); touchpad lives elsewhere. |
| `packages.md` | The single chosen power-tool package: `power-profiles-daemon` (repo) / `tlp` (repo) / `auto-cpufreq` (AUR). Repo `brightnessctl` is already in the utilities batch and not re-added here. |

## Where this component lands

- **Hyprland config:** one `bindl` line in `~/.config/hypr/binds.conf` (the lid switch). The
  bind table itself is owned by `../keybinds/template.md`; this component contributes its line
  via the same merge slot the gaming and accessibility components use.
- **System (root-side, NOT written by the generator):**
  - `/etc/systemd/logind.conf` — `HandleLidSwitch*=ignore` so logind doesn't double-suspend on top
    of the Hyprland `bindl` action. **Documented as a `sudo` command in the install output, never
    run by the agent.**
  - `systemctl enable --now power-profiles-daemon` (or `tlp` / `auto-cpufreq`). Documented; not run.
  - `/etc/systemd/system/battery-charge-limit.service` — a one-shot writing
    `/sys/class/power_supply/BAT*/charge_control_end_threshold`. Generated to the staging dir with
    the install command alongside it; the user runs `sudo install ... && sudo systemctl enable …`.

The generator's job ends at "produce the unit file + the exact `sudo` command". It does not exec
sudo, edit `/etc/`, or call `systemctl`.

## Theming angle (narrow but real)

This component is structural — it doesn't emit CSS or color tokens. But four downstream
surfaces DO render pixels whose appearance is decided by this component's answers, and the
deep-research pass identified them so sibling components know which palette key to wire
through. None of them are owned here; the table tells the orchestrator where each lives.

| Touchpoint | What this component decides | Where the pixels live | Palette key the sibling should use |
|---|---|---|---|
| **Battery low / critical color** | `power_tool` enables the waybar `battery` + `power-profiles-daemon` modules. | `../waybar/` `style.css` `#battery.critical` selector. | `@error` (Material/matugen) or `@red` (Catppuccin/named). Hard-coded `#f53c3c` is the v0.13-class anti-pattern (ML4W, binnewbs both ship it). See `gotchas.md` § k. |
| **Brightness / volume OSD** | The bind chain (volume/brightness `bindel` lines own the trigger; `power_tool` doesn't affect them, but the rice's OSD routing does affect cross-surface coherence). | Four routes seen in the corpus: in-shell (end-4, caelestia, dank), `swayosd-client` (Matt-FTW — usually un-themed), notification-daemon `[app-name=OSD]` rule (dusky, JaKooLit, HyDE), or no OSD. | mako/swaync `surface` + `on_surface` for the OSD frame; `primary_container` for the progress bar. See `gotchas.md` § j. |
| **Lock-screen palette render** | `lid_action == "suspend"` and `lid_action == "lock"` both eventually surface hyprlock (via hypridle's `before_sleep_cmd` hand-off — see `gotchas.md` § n). The user sees the rice's lock palette on every lid-close-then-open cycle. | `../lock-screen/` `hyprlock.conf` (rendered with hyprlock's color references). | All keys the lock-screen `.tmpl` emits — this component just decides *how often* the user sees them. |
| **PPD waybar module three-state icon** | `power_tool == "ppd"` enables the waybar `power-profiles-daemon` module. | `../waybar/` `#power-profiles-daemon` selector. | Same palette as `#battery` (universal-selector bundled — JaKooLit, dusky, binnewbs all do this). No per-state recoloring observed in the corpus. |

The interview itself adds zero theming sub-questions — these are all decided by sibling
components' interviews. The deep-research finding is that this component's answers *constrain*
those sibling answers (e.g. picking `power_tool == "none"` means waybar drops the PPD module,
so the rice's bar layout shifts; the waybar agent must read this key).

## Related components

- [`input`](../input/) — touchpad behavior (group 2). All `input { touchpad { … } }` sub-questions
  are asked there, even on a laptop.
- [`keybinds`](../keybinds/) — owns the bind table and the default `bindel` lines for
  brightness / volume / media keys. The lid-switch `bindl` from this component is merged in.
- [`monitors`](../monitors/) — `monitors.dock_undock` and the kanshi/shikane profile pair for
  docked-vs-bare. Not duplicated here.
- [`waybar`](../waybar/) — the `power-profiles-daemon` waybar module is only meaningful when
  `laptop.power_tool == "ppd"`. The waybar template branches on that key. **Also**: the
  `#battery.critical` palette wiring lives here (see `gotchas.md` § k); the waybar agent's
  research pass must wire it to the palette `error` / `red` key, never a literal.
- [`notifications`](../notifications/) — owns the mako/swaync/dunst CSS that paints the
  brightness/volume OSD when the rice routes the OSD through the notification daemon (dusky,
  HyDE, JaKooLit pattern — `gotchas.md` § j). The matugen template for the notification
  daemon decides whether the OSD is palette-coherent on re-theme.
- [`widgets`](../widgets/) — when the rice ships a Quickshell/AGS bar (end-4, caelestia,
  noctalia, dank), the brightness/volume OSD is in-shell QML, not a notification. The
  bind calls a shell IPC method (`qs ipc call brightness increment`) instead of
  `brightnessctl` directly. See `gotchas.md` § j for the routing-strategy split.
- [`utilities`](../utilities/) — `brightnessctl`, `playerctl`, and (when the rice picks the
  swayosd route) `swayosd` itself are added here. Note: shipping `swayosd` without a
  matugen template for `~/.config/swayosd/style.css` leaves the OSD un-themed — Matt-FTW
  does exactly that. The utilities agent should flag the package mismatch.
- [`lock-screen`](../lock-screen/) — `lid_action == "lock"` and `lid_action == "suspend"`
  both surface hyprlock via hypridle's `before_sleep_cmd = loginctl lock-session` hand-off
  (universal in the corpus: JaKooLit, Ax-Shell, end-4 all use the same line verbatim).
  If `companion_daemons.hypridle == false`, the suspend path skips the lock entirely.
- [`companion-daemons`](../companion-daemons/) — owns the hypridle config. The
  `listener { on-lock = hyprlock; }` line is what makes `loginctl lock-session` actually
  lock; without it, `lid_action == "lock"` is a no-op. Already documented in `template.md`.
- [`_interview-protocol.md`](../../_interview-protocol.md) — strict-ask discipline; opt-in gate
  rule (the gate is **always** asked; detection sets the default, not the answer).
- [`_shared/dispatchers.md`](../../_shared/dispatchers.md) — `bindl` flag semantics ("works while
  the screen is locked") and the `switch:on:` / `switch:off:` event syntax.
