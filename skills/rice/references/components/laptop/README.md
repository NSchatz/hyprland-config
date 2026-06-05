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

## Related components

- [`input`](../input/) — touchpad behavior (group 2). All `input { touchpad { … } }` sub-questions
  are asked there, even on a laptop.
- [`keybinds`](../keybinds/) — owns the bind table and the default `bindel` lines for
  brightness / volume / media keys. The lid-switch `bindl` from this component is merged in.
- [`monitors`](../monitors/) — `monitors.dock_undock` and the kanshi/shikane profile pair for
  docked-vs-bare. Not duplicated here.
- [`waybar`](../waybar/) — the `power-profiles-daemon` waybar module is only meaningful when
  `laptop.power_tool == "ppd"`. The waybar template branches on that key.
- [`utilities`](../utilities/) — `brightnessctl` and `playerctl` for the media binds are in the
  utilities batch, not the laptop packages.
- [`_interview-protocol.md`](../../_interview-protocol.md) — strict-ask discipline; opt-in gate
  rule (the gate is **always** asked; detection sets the default, not the answer).
- [`_shared/dispatchers.md`](../../_shared/dispatchers.md) — `bindl` flag semantics ("works while
  the screen is locked") and the `switch:on:` / `switch:off:` event syntax.
