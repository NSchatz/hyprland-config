# autostart — interview

Group 15 **Call 1 — services**. Four sub-questions (15a–15d), fits a single `AskUserQuestion` call
(≤ 4 cap respected). Call 2 of group 15 — the env-var multi-select — lives in
[`../env/interview.md`](../env/interview.md).

Prefer first-party Hypr ecosystem tools as the **first-listed** option (defaults). The same menu
is presented regardless of what's currently installed — detection only reorders the option list,
never filters it (see [`../../_interview-protocol.md`](../../_interview-protocol.md)).

## Sub-questions

**15a. Wallpaper tool** → `hyprpaper` (default, first-party, static only) · `swww` (animated
transitions) · `none`.
For the swww path, **emit the binary `SWWW_DAEMON_BIN` reports** from `detect-version.sh`
(`swww-daemon` for upstream, `awww-daemon` for the awww fork). Never hard-code `swww-daemon` — see
`gotchas.md`.

**15b. Polkit agent** → `hyprpolkitagent` (default, first-party; started via `systemctl --user
start hyprpolkitagent` which survives Hyprland reloads) · `polkit-gnome` · `polkit-kde` · `none`.
At most one is emitted into `autostart.conf`.

**15c. Also autostart** (multi-select; the listed defaults are pre-checked):
- `cliphist-text` — `wl-paste --type text --watch cliphist store` **(default on)**
- `cliphist-image` — `wl-paste --type image --watch cliphist store` **(default on)**
- `nm-applet` — `nm-applet --indicator` **(default on if `HAVE_NETWORKMANAGER=1`)**
- `blueman` — `blueman-applet` (off by default)
- `hypridle` — idle daemon **(default on)**
- `hyprsunset` — `hyprsunset -t 4000` blue-light filter (off)
- `swayosd` — `swayosd-server` volume/brightness OSD (off)

The portal env-propagation pair (`dbus-update-activation-environment --systemd …` +
`systemctl --user import-environment …`) is the standard "screen-share is black" fix — it is
**always emitted** in `autostart.conf`, not a user choice. Mention it in the question prose so the
user knows it's included.

**15d. Screen sharing / portals** (inform-only) — the generated config relies on
`xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk` plus `XDG_CURRENT_DESKTOP=Hyprland` in
`env.conf`. The env line is owned by `../env/`; the packages are added to the install batch via
`packages.md`. List missing packages here so the user sees what gets installed.

## Record paths

After the user answers, record with `record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  autostart_env.wallpaper_tool hyprpaper

bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  autostart_env.polkit hyprpolkitagent

bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  autostart_env.autostart --json '["cliphist-text","cliphist-image","nm-applet","hypridle"]'
```

`autostart_env.autostart` is always an array (possibly empty). Use `--json '[]'` when the user
unchecks everything — never omit the key, downstream code does `jq -r '.autostart_env.autostart[]'`
which errors on absent keys.

For 15d there's nothing to record — the packages are added by the installer agent reading this
component's `packages.md`, and the `XDG_CURRENT_DESKTOP` env line is owned by `../env/`.

## Cross-references

- Schema → `schema.md`
- The actual `autostart.conf` template → `template.md`
- Env-var half of group 15 (Call 2) → `../env/interview.md`
- Reload-vs-relaunch behaviour for the user-facing warning → `gotchas.md`
- Packages → `packages.md`
