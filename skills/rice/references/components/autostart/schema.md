# autostart — answers.json slice

Keys this component owns under the top-level `autostart_env` key. The sibling key
`autostart_env.env` (the `env = …` lines) is owned by [`../env/schema.md`](../env/schema.md); the
two components share the `autostart_env` parent but never write to each other's sub-keys.

```json
{
  "autostart_env": {
    "wallpaper_tool": "hyprpaper | swww | none",
    "polkit":         "hyprpolkitagent | polkit-gnome | polkit-kde | none",
    "dbus_propagation": "explicit | all",
    "autostart": [
      "cliphist-text", "cliphist-image",
      "nm-applet", "blueman",
      "hypridle", "hyprsunset", "swayosd"
    ]
  }
}
```

## Types

- `autostart_env.wallpaper_tool` — string, enum. `"none"` means no wallpaper daemon `exec-once`
  line is emitted. Always populated.
- `autostart_env.polkit` — string, enum. `"none"` means no polkit-agent `exec-once` line is
  emitted (auth prompts will silently fail — usually only chosen on minimal/embedded setups).
  Always populated.
- `autostart_env.dbus_propagation` — string, enum, defaults to `"explicit"`. `"explicit"` emits
  only the `DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` propagation pair (the standard
  screen-share fix). `"all"` additionally emits `dbus-update-activation-environment --systemd
  --all`, which broadcasts every env var the compositor has to systemd-activated services — fixes
  the "GTK file-picker doesn't see my PATH" class of bug HyDE / dusky hit, at the cost of leaking
  every compositor env var. Default is `"explicit"`; flip to `"all"` only when the user reports
  portal-activated apps missing rice-specific env. See `gotchas.md`.
- `autostart_env.autostart` — array of strings (possibly empty). Each entry is a short token
  the `autostart.conf` template branches on. Order doesn't matter; the template emits a fixed
  order. The empty array is valid and downstream code (`jq -r '.autostart_env.autostart[]'`) must
  handle it; never omit the key.

## Token catalog

| Token | Emits |
|---|---|
| `cliphist-text` | `exec-once = wl-paste --type text --watch cliphist store` |
| `cliphist-image` | `exec-once = wl-paste --type image --watch cliphist store` |
| `nm-applet` | `exec-once = nm-applet --indicator` |
| `blueman` | `exec-once = blueman-applet` |
| `hypridle` | `exec-once = hypridle` |
| `hyprsunset` | `exec-once = hyprsunset -t 4000` |
| `swayosd` | `exec-once = swayosd-server` |

Unknown tokens are a validator error — keep this list and `template.md` in sync.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (autostart topic) | Writes `autostart.conf` from `template.md` — branches every `exec-once` line on these keys plus the upstream `bar.strategy` / `notifications.daemon` picks (read from sibling slices) and the `SWWW_DAEMON_BIN` from detection. |
| `hyprland-package-installer` | Reads `autostart_env.wallpaper_tool` and `autostart_env.polkit` to add the matching package; reads each entry in `autostart_env.autostart` and maps to packages via `packages.md`. |
| `hyprland-validator` | Flags duplicate polkit agents, duplicate wallpaper daemons, unknown tokens, and a hard-coded `swww-daemon` line under an `awww` fork install. |

## Cross-slice reads

This component's template reads — but does not own — these sibling keys:

| Key | Owner | Used for |
|---|---|---|
| `bar.strategy` | `../waybar/schema.md` | Emit `exec-once = waybar` only on `"waybar"` / `"waybar+widgets"`. |
| `notifications.daemon` | `../notifications/schema.md` | Emit `exec-once = {{daemon}}` only when non-null and the daemon is the notification owner (see `gotchas.md`). |

`HYPR_VERSION` and `SWWW_DAEMON_BIN` come from `detect-version.sh`, not `answers.json`.

## Validation

- `wallpaper_tool` is required; one of `hyprpaper`, `swww`, `none`.
- `polkit` is required; one of `hyprpolkitagent`, `polkit-gnome`, `polkit-kde`, `none`.
- `dbus_propagation` is required; one of `explicit`, `all`. Defaults to `explicit` if the
  interviewer didn't ask (the question is opt-in — adding it to the interview is a separate
  decision; see `interview.md`).
- `autostart` is required (may be `[]`); every entry must be in the token catalog above.
- The validator rejects a template emission with two `exec-once` polkit lines or two `exec-once`
  wallpaper-daemon lines.
