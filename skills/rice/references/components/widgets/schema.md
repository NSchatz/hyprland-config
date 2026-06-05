# widgets — answers.json slice

Keys this component owns under the top-level `widgets` key.

```json
{
  "widgets": {
    "system":  "none | eww | ags | quickshell | hyprpanel | turnkey",
    "turnkey": "end-4 | caelestia | noctalia | dankmaterial | null",
    "enabled": ["osd", "notification-center", "music", "dashboard",
                "calendar", "power-menu", "sidebar", "sysinfo",
                "overview", "clipboard"],
    "look":    "match-palette | material-you | glass | flat",
    "motion":  "smooth | snappy | static"
  }
}
```

## Types

| Key | Type | Required | Notes |
|---|---|---|---|
| `widgets.system` | string enum | **yes** (always) | The gate. `none` means no widget shell — every other key in this slice is "n/a" but still recorded for shape consistency. |
| `widgets.turnkey` | string or `null` | yes | The pre-built shell pick. Non-`null` **only** when `system == "turnkey"`; `null` otherwise. Downstream readers branch on `!= null`. |
| `widgets.enabled` | string-array | yes | Which widget archetypes to enable. Empty `[]` when `system == "none"`. Free-form strings — the values listed in `interview.md` 7b are the canonical set. |
| `widgets.look` | string enum | yes | Visual treatment. Recorded even on `system == "none"` (defaults to `match-palette`) so a later edit-config flip to a shell has a sensible starting point. |
| `widgets.motion` | string enum | yes | Animation density. Recorded even on a partial shell pick (eww); only **used** by full shells (Quickshell `Behavior`, AGS `transition_duration`, HyprPanel motion preset). Defaults to `smooth`. |

### Enum semantics

**`widgets.system`:**
- `none` — no widget shell. `~/.config/{eww,ags,quickshell,hyprpanel}/` is **not** created. Waybar
  stays as the bar (per group 6). The rice engine does not register any widget-template line.
- `eww` — a floating-widgets toolkit *next to* waybar. Waybar stays. Engine registers the `eww`
  manifest line (template → `~/.config/eww/colors.scss`, reload `eww reload`).
- `ags` — Astal + Gnim / AGS v3 shell. **Replaces waybar.** Engine registers `ags` manifest line
  (template → `~/.config/ags/colors.scss`, reload empty — the shell's file-monitor handles it).
- `quickshell` — QML shell. **Replaces waybar.** Engine registers `quickshell` manifest line
  (template → `~/.config/quickshell/.../Colors.qml`, reload empty — Quickshell hot-reloads on save).
- `hyprpanel` — turnkey AGS panel. **Replaces waybar.** Engine **does not** register a manifest
  line; HyprPanel is themed via its GUI / matugen. The installer adds the package; the rice skill
  configures matugen against the wallpaper.
- `turnkey` — a pre-built shell (`widgets.turnkey` names which). **Replaces waybar.** Engine **does
  not** register a manifest line. The shell is theme-driven by its own installer + matugen.

**`widgets.turnkey`** (only set when `system == "turnkey"`):
- `end-4` — illogical-impulse (Quickshell, Material You).
- `caelestia` — caelestia-dots/shell (Quickshell, Material 3).
- `noctalia` — Noctalia (Quickshell, multi-compositor, plugin ecosystem).
- `dankmaterial` — DankMaterialShell (Quickshell + Go, replaces bar / lock / idle / notifications
  / launcher; greetd greeter).

**`widgets.look`:**
- `match-palette` — the rice engine's normal path. The widget template renders palette.conf into
  the shell's colors file.
- `material-you` — matugen reads the wallpaper and renders the colors file directly. The rice
  engine **yields** colors ownership for this shell only — palette.conf still drives every other
  app. Adds `matugen` to the install batch.
- `glass` — translucent surfaces (`rgba($surface, 0.6)`-ish) + Hyprland `layerrule` blur. The
  template emits the colors normally; the shell's SCSS / QML uses translucent variants.
- `flat` — opaque surfaces, no blur. Same template; the shell's SCSS / QML uses solid colors.

**`widgets.motion`:**
- `smooth` — `transition_duration: 250ms`-ish, eased; soft shadows.
- `snappy` — `100–150ms`, linear or `Easing.OutCubic`.
- `static` — no animations (motion / accessibility preference).

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-interviewer` | Walks 7a → 7a-bis → 7b → 7c → 7d. Gates: `7a == none` skips the rest; `7a == turnkey` triggers 7a-bis; `7a != none && system != eww` triggers 7d. |
| `hyprland-component-writer` (`waybar`) | Reads `widgets.system`. When the value is `ags` / `quickshell` / `hyprpanel` / `turnkey`, **drops the waybar `exec-once`** from autostart (full shell owns the bar). |
| `hyprland-component-writer` (`autostart`) | Reads `widgets.system` and adds the shell's `exec-once` line (`exec-once = eww daemon; eww open bar` or `qs -c <name>` or `hyprpanel` or `caelestia shell -d` etc.). |
| `hyprland-component-writer` (`notifications`) | Reads `widgets.enabled`. When `notification-center` is in the array **and** `widgets.system` is a full shell, forces the notifications-daemon pick to `none` (D-Bus conflict). |
| `hyprland-component-writer` (`lock-screen`) | Reads `widgets.system` + `widgets.turnkey`. caelestia / Noctalia / DankMaterialShell can be the lock — drop hyprlock when one of these owns the lock. |
| `hyprland-component-writer` (`launcher`) | Optional: if the shell owns the launcher and `launcher.tool` would duplicate, the user picks one; not auto-resolved. |
| `hyprland-package-installer` | Reads `widgets.system` + `widgets.turnkey` + `widgets.look`; assembles `eww` / `aylurs-gtk-shell` / `quickshell` / `hyprpanel` from `packages.md`, plus `matugen` when `look == material-you` or `system == hyprpanel | turnkey`. |
| `theming/engine.md` render-manifest writer | Adds the one widget-shell line (eww / ags / quickshell) when `system` is one of those three. **Does not** add a line for `hyprpanel` / `turnkey` / `none`. |
| `rice apply` | Reads `widgets.system` to know which template to render and which reload hook to fire. |

## Validation

- `widgets.system` must be one of the enum values; missing or unknown → interview fails.
- `widgets.turnkey` must be `null` **unless** `widgets.system == "turnkey"`, in which case it must
  be one of the four enum values.
- `widgets.enabled` must be an array (possibly empty). Unknown archetype names are kept (a future
  shell may consume them) but not acted on.
- `widgets.look == "material-you"` **requires** `matugen` to be in the install batch. The package
  reader enforces this.
- `widgets.motion` is recorded even for `eww`-on-waybar — eww ignores it, but the slot stays for
  shape consistency.
