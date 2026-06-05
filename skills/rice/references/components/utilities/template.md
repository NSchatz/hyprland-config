# utilities — template

This component's outputs are three things:

1. **Script files** copied verbatim from `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/` into
   `~/.config/hypr/scripts/<name>.sh`, with mode `0755`. No `{{var}}` substitution — these are
   plain shell scripts.
2. **Bind lines** appended to `~/.config/hypr/binds.conf` (owned by the `keybinds` component, but
   the lines below are *this* component's contribution).
3. **The wlogout recipe** (`layout` + `style.css`) when the user picked the wlogout flavor — see
   the dedicated section below. Colors flow in via `@import "colors.css"` rendered by the engine
   from `wlogout.tmpl`.

For each value in `utilities.selected`, walk the row below and emit the script copy (when there
is one) and the bind line.

## Script + bind map

| Value | Script (copy from `assets/scripts/`) | Runtime deps (auto-detected) | Bind line(s) emitted into `binds.conf` |
|---|---|---|---|
| `screenshot` | `screenshot.sh` | one of `grimblast`/`hyprshot`/(`grim`+`slurp`+`jq`); `wl-clipboard`; `satty` OR `swappy` for the `edit` arg | `bind = , Print, exec, ~/.config/hypr/scripts/screenshot.sh region` <br> `bind = $mainMod, Print, exec, ~/.config/hypr/scripts/screenshot.sh region edit` <br> `bind = ALT, Print, exec, ~/.config/hypr/scripts/screenshot.sh window` |
| `screen-record` | `screenrecord.sh` | one of `wl-screenrec` (HW, preferred) / `wf-recorder` (SW fallback); `slurp` for region | `bind = $mainMod SHIFT, Print, exec, ~/.config/hypr/scripts/screenrecord.sh region` |
| `ocr` | `ocr.sh` | `tesseract` + `tesseract-data-eng` (+ per-language packs); `grim`; `slurp`; `wl-clipboard` | `bind = $mainMod, O, exec, ~/.config/hypr/scripts/ocr.sh` |
| `color-picker` | `colorpicker.sh` | `hyprpicker`; `wl-clipboard` (for `-a` autocopy) | `bind = $mainMod SHIFT, P, exec, ~/.config/hypr/scripts/colorpicker.sh` |
| `power-menu` (rofi flavor) | `powermenu.sh` | `rofi` (≥ 2.0); `hyprlock`; systemd | `bind = $mainMod, Escape, exec, ~/.config/hypr/scripts/powermenu.sh` |
| `power-menu` (wlogout flavor) | *(no script — direct bind)* | `wlogout` | `bind = $mainMod SHIFT, M, exec, wlogout` |

Pick the wlogout flavor when the user selected `wlogout` upstream (companion-daemons or look-feel);
otherwise default to `powermenu.sh`.

## Bind-only tools (no script copy)

| Value | Bind line | Notes |
|---|---|---|
| `clipboard` | `bind = $mainMod SHIFT, V, exec, cliphist list \| $dmenu -i -p "Clipboard" \| cliphist decode \| wl-copy` | Use `$dmenu`, **not** `$menu`. `$mainMod, V` is usually toggle-float, so clipboard goes on `SHIFT+V`. The two `cliphist store` watchers must be in `autostart`. |
| `emoji` | `bind = $mainMod, period, exec, bemoji -t` | `bemoji` is self-contained — picks up whichever menu (`rofi`/`wofi`/`fuzzel`) is installed. `-t` types the choice; drop it to copy only. |
| `calculator` | `bind = $mainMod, C, exec, rofi -show calc -modi calc -no-show-match -no-sort \| wl-copy` | Needs `rofi-calc`. If the launcher is fuzzel/walker, route to its math plugin instead. |
| `night-light` | `bind = $mainMod SHIFT, N, exec, pkill hyprsunset \|\| hyprsunset -t 4000` | 4000 K warm; drop to 3500 K for stronger filtering. The `accessibility` component binds the same toggle. |
| `wifi-applet` | *(no bind — applet runs from autostart)* | `nm-applet --indicator` goes in `../autostart/template.md`. Needs a system tray on the bar (waybar `tray` module). |
| `bluetooth-applet` | *(no bind — applet runs from autostart)* | `blueman-applet` goes in `../autostart/template.md`. Same tray requirement. |

## Wi-Fi / Bluetooth — the keyboard-driven alternative

When the user explicitly wants keyboard-driven Wi-Fi instead of the tray, **do not** hand-author
an nmcli/bluetoothctl rofi parser — they break on SSIDs/device names with spaces and colons. Point
the user at the maintained external scripts:

- `rofi-network-manager` — single shell script the user drops in `~/.config/hypr/scripts/`.
- `rofi-bluetooth` — same.

Then emit:

```ini
bind = $mainMod, W, exec, ~/.config/hypr/scripts/rofi-network-manager.sh
```

This is opt-in only — surface it in the gotcha, not as a default option in the interview.

## Scripts ship verbatim — what does NOT belong here

- No palette substitution. These scripts are plain functional code; if a user wants a themed pop-up,
  that's the launcher's `theme.rasi` (themed by `launcher` component), not this script.
- No per-host variable injection. Paths are `~/.config/hypr/scripts/<name>.sh` literally.
- The autostart entries the scripts depend on (`cliphist` watchers, `nm-applet --indicator`,
  `blueman-applet`) — those belong in `../autostart/template.md`, not here.
- The actual bind table in `binds.conf` is assembled by the `keybinds` component; this file just
  documents the lines this component contributes.

## wlogout — `~/.config/wlogout/layout`

Emit only when `utilities.selected` contains `power-menu` AND the user picked `wlogout` upstream.
The file is a sequence of bare JSON objects (no array wrapper, no commas — the JSON-lines format
the `wlogout` parser expects per `man 5 wlogout`). Action lines are not themed; they pick the lock
binary the rest of the rice agreed on (`hyprlock`/`swaylock`/`loginctl lock-session`).

```jsonc
// Six buttons, corpus-canonical order (lock, hibernate, logout, shutdown, suspend, reboot).
// Upstream ArtsyMacaw/wlogout default order on master matches this exactly.
{
    "label" : "lock",
    "action" : "{{lock_cmd}}",
    "text" : "Lock",
    "keybind" : "l"
}
{
    "label" : "hibernate",
    "action" : "systemctl hibernate",
    "text" : "Hibernate",
    "keybind" : "h"
}
{
    "label" : "logout",
    "action" : "hyprctl dispatch exit 0",
    "text" : "Logout",
    "keybind" : "e"
}
{
    "label" : "shutdown",
    "action" : "systemctl poweroff",
    "text" : "Shutdown",
    "keybind" : "s"
}
{
    "label" : "suspend",
    "action" : "systemctl suspend",
    "text" : "Suspend",
    "keybind" : "u"
}
{
    "label" : "reboot",
    "action" : "systemctl reboot",
    "text" : "Reboot",
    "keybind" : "r"
}
```

`{{lock_cmd}}` resolution (writer-side):

| User's lock pick (`../lock-screen/`) | Substituted `action` |
|---|---|
| `hyprlock` (default) | `hyprlock` |
| `swaylock` | `swaylock` |
| neither / generic | `loginctl lock-session` (upstream default) |

The keybinds (`l/h/e/s/u/r`) are universal across the corpus
(`prasanthrangan/hyprdots:Configs/.config/wlogout/layout_1`,
`JaKooLit/Hyprland-Dots:config/wlogout/layout`,
`mylinuxforwork/dotfiles:dotfiles/.config/wlogout/layout`,
`binnewbs/arch-hyprland:.config/wlogout/layout`,
`linuxmobile/hyprland-dots:.config/wlogout/layout`) — do not renumber them.

For the "logout" action, `hyprctl dispatch exit 0` is the corpus-majority choice; the upstream
default `loginctl terminate-user $USER` ends the user session on all seats and can log out a TTY
mosh / SSH session you didn't mean to kill (`fufexan/dotfiles:home/programs/wayland/wlogout.nix`
uses `loginctl` because the rest of the rice is greetd-managed). Prefer `hyprctl` unless the user
explicitly asks for the loginctl form.

## wlogout — `~/.config/wlogout/style.css`

The user's `style.css` MUST `@import "colors.css"` at the top — that's how the rice palette
reaches wlogout. The engine renders `colors.css` from `wlogout.tmpl`; see `wlogout.tmpl` for the
exported var names (`bg fg accent surface`, per `_shared/colors-contract.md`).

```css
/* {{rice_name}} — wlogout. Colors flow in via the rice engine. */
@import "colors.css";

* {
    background-image: none;
    box-shadow: none;
    font-family: {{font_ui}};
    font-size: 16pt;
}

window {
    background-color: alpha(@bg, 0.85);  /* full-screen overlay backdrop */
}

button {
    color: @fg;
    background-color: @surface;
    border: 0;
    border-radius: 20px;
    margin: 10px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 20%;
    transition: all 0.3s cubic-bezier(.55, 0.0, .28, 1.682);
}

button:focus,
button:hover {
    background-color: @accent;
    color: @bg;
    background-size: 30%;
}

#lock     { background-image: image(url("/usr/share/wlogout/icons/lock.png"),     url("/usr/local/share/wlogout/icons/lock.png")); }
#logout   { background-image: image(url("/usr/share/wlogout/icons/logout.png"),   url("/usr/local/share/wlogout/icons/logout.png")); }
#suspend  { background-image: image(url("/usr/share/wlogout/icons/suspend.png"),  url("/usr/local/share/wlogout/icons/suspend.png")); }
#hibernate{ background-image: image(url("/usr/share/wlogout/icons/hibernate.png"),url("/usr/local/share/wlogout/icons/hibernate.png")); }
#shutdown { background-image: image(url("/usr/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png")); }
#reboot   { background-image: image(url("/usr/share/wlogout/icons/reboot.png"),   url("/usr/local/share/wlogout/icons/reboot.png")); }
```

Notes:

- **Icon fallback chain.** Use the upstream-provided icons via `image(url(…), url(…))` — the
  parser tries each url in order and picks the first that resolves
  (`prasanthrangan/hyprdots:Configs/.config/wlogout/style_1.css` uses the same triple-fallback).
  Don't ship custom PNGs unless the user explicitly asked for a themed icon set — those have to
  be installed separately and are out of scope for this recipe.
- **The `cubic-bezier(.55, 0, .28, 1.682)` curve** (an overshoot ease) appears in HyDE,
  JaKooLit, and binnewbs — it's the de-facto corpus default for the hover transition.
- **No literal hex.** Every color goes through `@bg`/`@fg`/`@accent`/`@surface`. The
  `colors.css` import is what makes a re-theme actually change wlogout — hardcoded hex silently
  drifts when the user runs `rice apply`.
- **`background-color: alpha(@bg, 0.85)` on `window`** — GTK CSS `alpha(@color, fraction)` is
  the correct way to derive a translucent backdrop from a palette color without inventing a new
  `@define-color`. This is also how libadwaita docs recommend deriving overlays. To get an
  actual blur behind the dialog (not just translucency), see the layerrule note in
  `gotchas.md`.

For deeper styling moves (per-icon hover scale, multi-row 2×3 grids, icon-tint via mask-image),
see `styling.md`.
