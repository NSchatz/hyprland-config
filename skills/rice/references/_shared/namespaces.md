# Layer / window namespaces (cross-cutting registry)

Single source of truth for **every layer-shell namespace** and **window class/title** the rice's
parallel writers either emit, match, or apply a blur rule to. The same defect class kept showing
up: writer A emits a window with namespace X, writer B emits a `match:namespace` for namespace Y,
and the blur rule silently no-ops because no surface exists at Y.

**Every writer that names a layer-shell window** (widgets, utilities, launcher, notifications,
companion-daemons, login-boot) **reads this file** to pick the namespace it sets, and **every
writer that emits a `layerrule` / `windowrule`** (window-rules, look-feel) reads this file to
pick what it matches.

The validator agent uses this registry to lint:
1. Every `match:namespace = X` in `windowrules.conf` corresponds to a `layer` row below whose
   `owner` is selected in `answers.json`.
2. No declared namespace lacks a matching layer-rule when the owner is selected AND blur is
   wanted.

## Layer-shell namespaces

| Namespace pattern        | Owner (writer)         | Selected when                                 | Default blur? | Notes |
|---|---|---|---|---|
| `waybar`                 | waybar                 | `bar.strategy ∈ {waybar, waybar+widgets}`     | yes           | exact match. |
| `quickshell:*`           | widgets                | `widgets.system == "quickshell"`              | yes           | match prefix `quickshell:.*`. |
| `eww-.*`                 | widgets                | `widgets.system == "eww"`                     | yes           | **Contract:** every eww `defwindow` declares `:namespace "eww-<name>"` (e.g. `eww-bar`, `eww-dashboard`, `eww-music`, `eww-sysinfo`, `eww-osd`). Single blur rule matches `eww-.*`. |
| `ags-.*`                 | widgets                | `widgets.system == "ags"`                     | yes           | AGS v3 windows declare `namespace: "ags-<name>"`. |
| `hyprpanel`              | widgets                | `widgets.system == "hyprpanel"`               | no            | HyprPanel owns its own theme; blur via its GUI. |
| `launcher`               | launcher (fuzzel)      | `launcher.tool == "fuzzel"`                   | yes           | upstream fuzzel default per `fuzzel.ini(5)`. |
| `rofi`                   | launcher (rofi)        | `launcher.tool == "rofi"`                     | yes           | upstream rofi default. |
| `wofi`                   | launcher (wofi)        | `launcher.tool == "wofi"`                     | yes           | upstream wofi default. |
| `anyrun`                 | launcher (anyrun)      | `launcher.tool == "anyrun"`                   | yes           | |
| `walker`                 | launcher (walker)      | `launcher.tool == "walker"` AND `HYPR_HAS_EXT_BG_EFFECT_V1=0` | conditional | on `HYPR_HAS_EXT_BG_EFFECT_V1=1`, walker handles its own blur via `ext_background_effect_blur`; the layerrule is redundant. |
| `tofi`                   | launcher (tofi)        | `launcher.tool == "tofi"`                     | yes           | |
| `vicinae`                | launcher (vicinae)     | `launcher.tool == "vicinae"`                  | yes           | |
| `notifications`          | notifications (mako/dunst) | `notifications.daemon ∈ {mako, dunst}`     | yes           | shared by both daemons. |
| `swaync-control-center`  | notifications (swaync) | `notifications.daemon == "swaync"`            | yes           | **swaync needs both** of its blocks (the panel and the popup are separate surfaces). |
| `swaync-notification-window` | notifications (swaync) | `notifications.daemon == "swaync"`        | yes           | |
| `logout_dialog`          | utilities (wlogout)    | `utilities.selected` ∋ `power-menu` AND wlogout flavor | yes  | verified across end-4, dusky, hyprdots, caelestia. |
| `swayosd`                | utilities (swayosd)    | `utilities.osd_route == "swayosd"`            | yes           | swayosd-server sets this layer namespace; without a matching blur rule the OSD pop renders against a flat background. |
| `selection`              | utilities (slurp/grim) | `utilities.selected` ∋ `screenshot`           | no            | transient — do not blur. |
| `session-lock`           | lock-screen (hyprlock) | `lock_screen.tool == "hyprlock"`              | no            | lock surface; blur is handled inside hyprlock.conf. |
| `regreet`                | login-boot (regreet)   | `login_boot.greeter == "regreet"`             | no            | runs before user session — no Hyprland blur. |

## Window classes (windowrule)

Windowrule `match:class` patterns referenced across writers. See
`components/window-rules/template.md` for the full per-class effect table; this list is the
registry of who emits what so the validator can cross-check.

| Class regex                                  | Owner (writer) | Notes |
|---|---|---|
| `^(pavucontrol\|nm-connection-editor\|blueman-manager)$` | window-rules (shipped default) | float utility dialogs. |
| `^(Picture-in-Picture)$` (title)             | window-rules   | float + pin. |
| `^.*\.exe$` / `^steam_app_.*` / `^gamescope` | gaming         | tearing/idle-inhibit. |
| `^(org.gnome.Calculator\|xcalc)$`            | (interview)    | per-app rules (group 11i). |

## Rules for writers

1. **A writer that owns a namespace declares it here first.** Do not invent a new namespace in
   a writer without adding a row above (and a sibling validator-rule line so misalignment with a
   matching blur rule trips a warning).
2. **A writer that matches a namespace reads from this file.** The `window-rules` template's
   blur block iterates the rows where the owner is selected in `answers.json` and the
   `Default blur?` column is `yes` — no hardcoded list.
3. **eww uses the `eww-<name>` family, period.** A bare `match:namespace = eww` matches no
   surface; eww never declares `:namespace "eww"`. Templates must use `eww-.*`.
4. **swayosd lives at namespace `swayosd`** — a writer that wants the OSD blurred matches that
   namespace.

## Cross-references

- `components/window-rules/template.md` — the `layerrule` block emitter.
- `components/widgets/template.md` — eww/ags/quickshell `defwindow :namespace` requirement.
- `components/launcher/gotchas.md` — fuzzel namespace cliff (`launcher`, not `fuzzel`).
- `components/notifications/gotchas.md` — swaync two-block rule.
- `components/utilities/template.md` — wlogout (`logout_dialog`) and swayosd namespaces.
