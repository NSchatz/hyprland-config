# widgets - common

Cross-tool content for the `widgets` surface: what holds no matter which tool was picked.
Read this **plus** the one `tools/<your-tool>.md` the interview selected.

## Contents

- Template
- Validation
- Reload

---

## Template


Per-shell wiring. The rice engine doesn't own the shell's own config (`eww.yuck`, `style.scss`,
`shell.qml`) — it owns the **colors file** the shell imports, plus one render-manifest line that
re-themes it on every `rice apply`. This matches every other visual component: the user (or the
shell's installer) writes the look once, the engine re-renders the palette.

The colors-file variable names per shell are the contract — see
[`_shared/colors-contract.md`](../../_shared/colors-contract.md) → `eww` / `ags / astal` /
`quickshell` rows. Renaming a `$var` without updating the shell's stylesheet silently un-themes
that surface.

## Render-manifest lines

TAB-separated `name TAB template TAB output TAB reload-cmd`. The rice skill registers **one** of
these when 7a is one of `eww` / `ags` / `quickshell`; nothing for `hyprpanel` / `turnkey` /
`none`. (Source: `theming/engine.md` → "Widget-shell theming".)

```
eww         ~/.config/hypr-rice/templates/eww.tmpl         ~/.config/eww/colors.scss             pgrep -x eww >/dev/null && eww reload || true
ags         ~/.config/hypr-rice/templates/ags.tmpl         ~/.config/ags/colors.scss
quickshell  ~/.config/hypr-rice/templates/quickshell.tmpl  ~/.config/quickshell/<name>/Colors.qml
```

Output paths vary per shell layout — an Astal project may want `style/colors.scss`, a Quickshell
config may want `theme/Colors.qml` next to its `qmldir`. Match the shell's actual layout.

**eww reload-cmd** must be the guarded form `pgrep -x eww >/dev/null && eww reload || true`.
Plain `eww reload` non-zero-exits when the daemon isn't running, which `render-templates.sh`
surfaces as `RELOAD_SKIPPED eww` — and worse, the shipped recipe previously had **no** reload-cmd
at all, so a re-themed `colors.scss` sat on disk until the user manually re-ran eww. The guarded
form is a no-op when eww isn't running (returns 0 via the `|| true`) and a successful reload when
it is. eww `reload` is supported in elkowar/eww ≥ 0.5.

The reload-cmd is **empty** for AGS (the shell's *user-written* file-monitor — `Utils.monitorFile`
in v1, a `monitorFile` + `app.apply_css(scss)` pair in v3 — picks up the colors-file write) and
for Quickshell ("loads changes as soon as they're saved", per the docs).

## Cross-references

- Engine manifest + the broader theming pipeline → `theming/engine.md`
- Per-shell colors-file variable names → `_shared/colors-contract.md`
- Palette source of truth → `_shared/palette-schema.md`
- eww / AGS / Quickshell design techniques → `styling.md`
- The full-shell-replaces-waybar rule and the notifications conflict → `gotchas.md`
- Reload mechanics per shell → `reload.md`

---

## Styling


The widgets component spans **four toolkits** (eww, AGS / Astal, Quickshell, plus the cross-cutting
design vocabulary), so this file is a concatenation of the four matching design references. Read
the first section (**design**) to pick a system; then jump to the section for the toolkit the
interview landed on. The per-toolkit sections are the verbatim references for *that* toolkit only —
there's no harm reading just yours.

Sections (in order):

1. `## design (cross-cutting)` — the system-choice + archetype catalog. Read this first.
2. `## eww` — yuck + SCSS. Floating widgets next to waybar.
3. `## AGS / Astal` — TS/JS + GTK + SCSS. Replaces waybar.
4. `## Quickshell` — QML / Qt 6. Replaces waybar.

HyprPanel and the turnkey shells (end-4, caelestia, Noctalia, DankMaterialShell) don't get a
section — you don't style them by hand. Drive them via matugen on the wallpaper; see `gotchas.md`
→ "HyprPanel and Material-You-native shells drive via matugen".

---

## design (cross-cutting)

[`waybar.md`](../waybar/styling.md) covers the **status bar**. This page covers everything *beyond* the bar — the **desktop widget shells** that dominate the modern Hyprland / r/unixporn scene: dashboards, control centers, sidebars, on-screen displays (OSDs), music players, notification centers, app launchers, calendars, power menus, and workspace overviews with live previews. Read this section **first** to pick a system; then go deep in the per-toolkit section: `## eww`, `## AGS / Astal`, `## Quickshell`.

> **Why this is a separate decision from the bar.** Some widget systems *add* widgets next to Waybar (eww floating widgets, a swaync control center). Others *replace the bar entirely* — caelestia's tagline is literally "‼️ No waybar here ‼️", and a Quickshell/AGS shell owns the bar, OSD, notifications, lock screen and dashboard as one program. So the first question is **strategy**: keep Waybar and bolt widgets on, or commit to a full shell.

### The landscape (and where momentum is, 2025–2026)

Two tools remain the most-starred *individual* utilities — **eww** (~12.5k★) and **Waybar** (~11.4k★) — but the highest-star *rices* of 2025–2026 are now **QML/Quickshell** shells: `end-4/dots-hyprland` (~14.7k★, which famously migrated AGS→Quickshell), `caelestia-dots/shell` (~9.8k★), `noctalia-shell` (~7.3k★), `DankMaterialShell` (~6.6k★). **Astal/AGS** (TypeScript over GTK) is the established mid-ground; **fabric** (Python) and **nwg-shell** (Python + GUI) are the niche-but-maintained options. The former turnkey darlings **HyprPanel** and **Ax-Shell** were **both archived in 2026** — still usable, no longer maintained.

Three trends shape any recommendation:
1. **AGS → Quickshell is the defining migration.** AGS v1 was deprecated for Astal/AGS v2, but gravity has shifted to **Quickshell** (QtQuick/QML). Its killer feature — **live window previews / overview** — is near-impossible in GTK toolkits.
2. **matugen / Material You is the default theming engine**, displacing pywal. Named-scheme (Catppuccin/Nord) and wallbash/wallust camps coexist, but new full shells almost all ship matugen-driven Material You.
3. **"Shell as a product" is consolidating** but churning at the framework layer (HyprPanel→Wayle, Ax-Shell→Ambxst). The survivors (caelestia, noctalia, DankMaterialShell) explicitly target *multiple* compositors, so "Hyprland-specific" is fading.

### Choosing a widget system — decision matrix

| System | Type | Language you write | Effort | Flexibility | Looks ceiling | Maintenance (2026) | Styling model |
|---|---|---|---|---|---|---|---|
| **Waybar + custom modules** | Status bar | none / JSONC + GTK-CSS (+shell for `custom/*`) | **Lowest** | Bar-shaped only | High for a bar | Very active | GTK3 CSS — see [`waybar.md`](../waybar/styling.md) |
| **HyprPanel** | Turnkey panel | none (GUI) / JSON | **Lowest** (GUI) | Low–medium (preset modules) | High | **Archived 2026-04** (→Wayle) | GUI + `.json` theme import; matugen |
| **nwg-shell** | Turnkey GTK suite | none (GUI) / JSON + GTK-CSS | Low (GUI) | Medium | Medium | Active | GTK3 CSS `style.css` |
| **eww** | Widget toolkit | **yuck + SCSS** | Medium | Very high (any shape) | Very high | Active | GTK3 CSS/SCSS — `## eww` below |
| **AGS / Astal** | TS/JS framework | **TypeScript/JSX + SCSS** | Medium–high | Very high | Very high | Active | GTK3/4 CSS/SCSS — `## AGS / Astal` below |
| **fabric** (+Ax-Shell) | Python framework | **Python + GTK-CSS** | Medium–high | Very high | Very high | fabric active; **Ax-Shell archived** | GTK3 CSS |
| **Quickshell** | QML toolkit | **QML** | High | **Highest** (live previews) | **Highest** | Very active | QML properties (not CSS) — `## Quickshell` below |

**Recommendations by user type:**
- **Beginner / "I just want it to work":** **Waybar + custom modules** for a bar (zero new language; reuses styling you already know), plus **swaync** for a notification-center widget. If you want a full GUI-configured suite that is *still maintained*, **nwg-shell** (prefer it over the archived HyprPanel).
- **Tinkerer / "I'll write some config":** **eww** (yuck + SCSS — GTK-CSS knowledge transfers, no real programming) for arbitrary floating widgets; or **AGS/Astal** if you're comfortable in TypeScript and want batteries-included services (network, bluetooth, mpris, notifications).
- **Perfectionist / "pixel-perfect, animations, live previews":** **Quickshell (QML)** — where the highest-effort, best-looking rices now live (caelestia, noctalia, DankMaterialShell, end-4), with hot-reload and live previews out of the box. **fabric** (Python) is the equivalent for someone who prefers Python to QML.

**Styling-knowledge transfer.** Waybar, eww, nwg-shell, fabric, AGS/Astal, and HyprPanel are **all GTK** under the hood, so the **GTK3-CSS subset** from [`waybar.md`](../waybar/styling.md) (`@define-color`/`@import`, `alpha()`/`shade()`/`mix()`, `border-radius`, `@keyframes`; no flexbox/`transform`/`calc`) carries across all of them. **Quickshell is the exception** — Qt/QML, so none of the GTK-CSS techniques transfer; styling is QML properties. **matugen is the common theming bridge** across HyprPanel, fabric, eww, AGS, and most QML shells (it generates a color file the config imports).

### Common widget archetypes (ranked by prevalence)

What people actually build, roughly in order of how often it shows up across the corpus, with the toolkit it's usually built in. These power the rice interview's "which widgets" question.

1. **Status bar** — universal. Waybar (standalone) or rolled into a full shell (Quickshell/AGS/fabric).
2. **App launcher** — near-universal. rofi/wofi/fuzzel for Waybar rices; a built-in spotlight launcher in shell toolkits.
3. **Notification center** — swaync/mako/dunst for Waybar rices; native in Quickshell/AGS/fabric (their `Notifd`/`Notifications` service *replaces* the daemon — don't run both).
4. **OSD (volume / brightness / caps-lock)** — the most common reason people leave plain Waybar; built into every shell toolkit, or a tiny eww popup.
5. **Dashboard / control center** (quick-settings toggles + sliders + sysinfo + media) — the *signature* shell widget. Quickshell (caelestia, Dank, noctalia), AGS (HyprPanel), fabric (Ax-Shell), or an eww overlay.
6. **Music / now-playing (MPRIS)** with blurred cover art — eww historically (adi1090x, gh0stzk); now a Quickshell/AGS/fabric card.
7. **Power / session menu** — wlogout for Waybar rices; a built-in session widget in shells.
8. **Calendar / clock panel** — eww historically; Quickshell/AGS widgets now.
9. **Wallpaper picker + dynamic theming** — shell scripts around swww/matugen/wallbash/wallust (every Material You rice).
10. **Lock screen** — hyprlock for Waybar rices; a *native* Quickshell lock (`SessionLock`) in full shells (caelestia, noctalia, Dank).
11. **Overview / window switcher with live previews** — a **Quickshell** specialty (end-4's signature); GTK toolkits can't easily do it.
12. **Clipboard / emoji / color picker / sidebar** — fabric (Ax-Shell has the widest set) and Quickshell.

### Theming flow (how the palette gets in)

Whatever the toolkit, the rice contract is the same: **render the palette into a colors file the widget config reads, then hot-reload.** The mechanism per toolkit:

| Toolkit | Colors file | Wired by | Reload |
|---|---|---|---|
| eww | `~/.config/eww/colors.scss` (`$key: #hex;`) | `@import "colors";` at top of `eww.scss` | `eww reload` |
| AGS / Astal | `colors.scss` (`$key: #hex;` / `@define-color`) | `@use`/`@import` in `style.scss` | file-monitor → `resetCss`/`applyCss` |
| Quickshell | `Colors.qml` singleton or `colors.json` | `import` the singleton / `FileView`+`JsonAdapter` | automatic on file save |
| HyprPanel | (its `.json` theme / matugen) | GUI / matugen | in-app |
| nwg-shell | `style.css` (GTK CSS) | per-panel style | `nwg-panel` restart |

The rice engine ships templates for the first three (`eww.tmpl`, `ags.tmpl`, `quickshell.tmpl`) and registers the chosen one in the manifest so `rice apply` re-themes the widget shell with everything else — see `theming/engine.md` → "Widget-shell theming". For Material-You-native shells (end-4, caelestia, HyprPanel), the alternative is to let **matugen** own the widget colors (mapping `primary→accent`, `surface→bg`, …) while the engine owns the core surfaces — keep one palette source per run so they stay consistent.

### Pitfalls (cross-toolkit)

- **Notification-daemon conflict.** A full shell's notification service (AGS `Notifd`, Quickshell `Notifications`, swaync) owns the `org.freedesktop.Notifications` D-Bus name — running mako/dunst alongside it means duplicate or swallowed notifications. Pick one.
- **Two bars at once.** If you adopt a full shell that includes a bar, *stop Waybar* (remove its `exec-once`) or you get two bars fighting for the top edge / exclusive zone.
- **Blur is the compositor's job.** GTK *and* QML widgets only frost a translucent surface if a Hyprland `layerrule` blurs that window's layer namespace — same failure mode as Waybar without the blur rule. Set the namespace and `match:namespace`.
- **Chasing an archived project.** HyprPanel (→Wayle) and Ax-Shell (→Ambxst) are frozen, and end-4 left AGS for Quickshell. They're great *visual* references, but don't start a new config on a dead codebase.
- **Picking the heaviest tool for one widget.** If you only want a weather readout or a notification bell, a Waybar `custom/*` module beats standing up a whole QML shell. Match effort to the goal.

## Provenance

Citations for this file live at `.research/sources/components-widgets-styling.md` (repo root), kept out of
the load path on purpose. Read them when reviewing a recommendation, not when
authoring a config.

---

## Validation


After the widgets component renders, the relevant `~/.config/{eww,ags,quickshell,hyprpanel}/` is
parseable / compilable before any reload hook runs. The validation step is **per-shell**, gated on
`widgets.system`.

## Validation matrix

| `widgets.system` | Validator | Tool | Hard-fails on |
|---|---|---|---|
| `none` | nothing to validate | — | — |
| `eww` | yuck + SCSS parse | `eww` (CLI) | invalid yuck S-expression, SCSS compile error, unknown widget type |
| `ags` | TS compile + SCSS parse | `tsc` (in `ags` CLI) / `dart-sass` | TS type errors, SCSS unknown-variable, missing `@use` target |
| `quickshell` | QML parse | `qmllint` | unbalanced braces, unknown type, missing import |
| `hyprpanel` | JSON parse only | `jq` | malformed `~/.config/hyprpanel/config.json` |
| `turnkey` | none (the project's installer owns validation) | — | — |

## Cross-references

- The eww pitfalls catalog → `gotchas.md` / `styling.md` → `## eww` → "Pitfalls"
- The Quickshell pitfalls catalog → `styling.md` → `## Quickshell` → "Pitfalls"
- The AGS v1↔v2 incompatibility list → `gotchas.md` / `styling.md` → `## AGS / Astal`
- The colors-file variable contract → `_shared/colors-contract.md`
- Per-shell reload hooks (fired only after validation passes) → `reload.md`

---

## Gotchas


## A full shell REPLACES waybar — drop the waybar `exec-once`

When `widgets.system` is `ags`, `quickshell`, `hyprpanel`, or `turnkey`, the shell owns its own
bar. Running waybar alongside means two bars fighting for the same exclusive zone — both reserve
space at the top edge, one wins the layer, the other floats in a half-broken state. The visible
symptom is duplicated clocks / workspace indicators and tiled windows shoved into the wrong region.

**Fix:** when `widgets.system` is anything other than `none` or `eww`, **remove** `exec-once =
waybar` from `hyprland.conf` (or never write it in the first place). The autostart component reads
`widgets.system` and gates the waybar line:

```bash
A="${CLAUDE_PLUGIN_ROOT}/scripts/answers.py"
sys="$(python3 "$A" get answers.json widgets.system)"
if [ "$sys" != "none" ] && [ "$sys" != "eww" ]; then
  # full shell owns the bar — skip waybar
  :
else
  echo "exec-once = waybar" >> hyprland.conf
fi
```

Only **eww** (the toolkit, not the panel) pairs *with* waybar — eww is for floating widgets that
sit next to a separate bar. Every other widget pick replaces the bar.

## Widget shells may own notifications — set group 9 to `none`

A full shell's notification service is the notification daemon. AGS exposes `Notifd`, Quickshell
exposes `Quickshell.Services.Notifications`, DankMaterialShell ships one out of the box, and
HyprPanel handles notifications via its own AGS-backed widget. All four claim the
`org.freedesktop.Notifications` D-Bus name — the same name mako / dunst / swaync need. Running
both means duplicate or swallowed notifications (whichever daemon wins the name-acquire race owns
them; the loser sees nothing).

**Fix:** when `widgets.enabled` includes `notification-center` **and** `widgets.system` is a full
shell, set `notifications.daemon = "none"` (the notifications component's gate). The notifications
component reads `widgets.{system,enabled}` and short-circuits its own interview:

```bash
A="${CLAUDE_PLUGIN_ROOT}/scripts/answers.py"
sys=$(python3 "$A" get answers.json widgets.system)
case "$sys" in
  ags|quickshell|hyprpanel|turnkey)
    if python3 "$A" list answers.json widgets.enabled | grep -qx notification-center; then
      bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" answers.json notifications.daemon none
    fi ;;
esac
```

The user is told *why* the daemon defaulted to `none` in the review pass.

## OSD owner: pick exactly one (defect #13)

Two of the rice's components can render volume / brightness OSDs: the widget shell
(`widgets.enabled ∋ OSD`) and `swayosd` (`utilities.osd_route == swayosd`). When the user
opts in to both, both render the same key-press, the two OSDs flicker over each other on top
of the bar, and the rice "feels broken." The interview-time check that prevents this:

```bash
A="${CLAUDE_PLUGIN_ROOT}/scripts/answers.py"
osd_widget="$(python3 "$A" list answers.json widgets.enabled | grep -qFx 'OSD (volume / brightness)' && echo 1 || echo 0)"
osd_route="$(python3 "$A" get answers.json utilities.osd_route)"
if [ "$osd_widget" = "1" ] && [ "$osd_route" = "swayosd" ]; then
    # Conflict — ask the user which one should own OSDs (in_shell:in-shell or swayosd:swayosd),
    # then drop the other:
    #   if they pick "shell OSD" → record utilities.osd_route = in-shell (route to shell IPC)
    #   if they pick "swayosd" → remove OSD from widgets.enabled
    : # (handled in the rice-skill orchestrator, not silently — see SKILL.md A1)
fi
```

The orchestrator (`SKILL.md` A1, after the review pass) runs this check. When it fires, it
asks the user — *don't* silently drop one side. Defaults if the user has no preference: prefer
the widget shell's OSD when `widgets.system` is a "full shell" (ags/quickshell/hyprpanel/turnkey,
which can't easily relinquish OSD rendering); prefer swayosd when `widgets.system` is `eww`
(eww's OSD is opt-in, not the shell's responsibility).

The notification-daemon-OSD route (`utilities.osd_route == "notification"`) doesn't conflict
with widget-shell OSDs — they fire at different points in the pipeline — so no check is
needed there.

## Heavy shells take real build time at install — warn the user

`quickshell`, `aylurs-gtk-shell` (and any turnkey shell that builds from source) all pull in Qt /
GTK toolchains and compile out-of-band. On Arch via `yay -S quickshell-git` or `paru -S
hyprpanel`, expect tens of minutes — much longer than every other package in the install batch
combined. Surface this in the install-step preamble so the user doesn't think the installer hung.

```text
Warning: quickshell-git builds Qt 6 + Qt Quick Effects from source.
Expect 20–40 minutes on this CPU. The install continues automatically.
```

Same applies to `caelestia`, `noctalia-shell`, `dms` (DankMaterialShell), end-4's installer — they
all do a Quickshell build on first run.

## Wallpaper-driven theming needs a wallpaper tool that survives theme switches

`widgets.look == material-you` reads the *current* wallpaper. If the wallpaper is set with a
one-shot command (`swww img …` without a daemon, or a hyprpaper `preload` that never reloads), the
matugen run keys off a stale path. Make sure the `autostart` component picks a wallpaper tool with
a persistent daemon (`swww-daemon` or `hyprpaper`) so the wallpaper-set / matugen-run sequence is
deterministic on every `rice apply`.

---

## Reload


How a re-rendered colors file is picked up by the running shell. Each shell has its own hook;
`rice apply` reads `widgets.system` and fires the right one. Hooks are **guarded** — a no-op if
the daemon / shell isn't running yet, so the first `rice apply` after install doesn't fail just
because the user hasn't started the shell.

## Hooks by `widgets.system`

| `widgets.system` | Reload command | Guard | Latency |
|---|---|---|---|
| `none` | (nothing) | — | — |
| `eww` | `eww reload` | `pgrep -x eww >/dev/null` | < 200 ms — recompiles SCSS in place; widgets re-skin without daemon restart, no flicker |
| `ags` | (none — file-monitor) | the shell's `Utils.monitorFile` / dart-sass watcher | < 500 ms after the file write |
| `quickshell` | (none — hot-reload on save) | the shell's `FileView { watchChanges: true }` or `pragma Singleton` reload | instant on save |
| `hyprpanel` | (GUI-driven) | — | Theming changes go through HyprPanel's settings dialog or matugen; the rice skill writes the matugen config, then runs `matugen run` |
| `turnkey` | per-project (`caelestia restart`, `dms reload`, …) — most just consume the matugen-regenerated colors.json | the shell's own file watcher | varies |

## Composite reload sequence (`rice apply`)

```bash
# Step 1: render-templates.sh has already written every output file from palette.conf.
#         The widget shell's colors file is among them.

# Step 2: per-shell reload hook (gated on widgets.system + matugen flags).
case "$(jq -r .widgets.system answers.json)" in
  none) ;;
  eww)
    pgrep -x eww >/dev/null && eww reload || true ;;
  ags|quickshell)
    : ;;                  # file-monitor handles it
  hyprpanel|turnkey)
    if command -v matugen >/dev/null; then
      wallpaper=$(jq -r .wallpaper.path answers.json)
      [ -f "$wallpaper" ] && matugen image "$wallpaper" >/dev/null 2>&1 || true
    fi ;;
esac
```

The `|| true` everywhere is deliberate — `rice apply` should never fail because a hot-reload
couldn't find a running daemon. The validator's job is to catch real problems (broken SCSS,
missing colors, parse errors) *before* the hook runs; the hook itself is best-effort.

## Cross-references

- The manifest format and render flow → `_shared/palette-schema.md` → "Render flow",
  `theming/engine.md` → "Widget-shell theming"
- Where each shell's colors file lands → `template.md`
- Validation (runs before the hook) → `validation.md`
- Matugen + the Material-You path → `gotchas.md` → "HyprPanel and Material-You-native shells"

