# widgets — interview

Group 7. The widgets that make a desktop feel like a *rice* rather than a bar on a wallpaper:
dashboards / control centers, sidebars, OSDs (volume / brightness), music players, notification
centers, calendar panels, power menus, workspace overviews.

This is an **opt-in component with a gate**. Per `_interview-protocol.md` → "Strict — ask every
question" / "Opt-in gate questions": **the gate is always asked**, never silently defaulted from
the bar pick. Detection (e.g. what's already on disk) reorders the option list — it does **not**
answer the gate. A short interview is a failed interview; ask 7a unconditionally.

The gate has a real "I don't want a widget system" branch — on **none** the rest of group 7 is
skipped and `widgets.system = "none"` is recorded. On any other pick, walk 7b → 7c → 7d (and
7a-bis if the user picked `turnkey`).

## AskUserQuestion shape

Group 7 splits into **up to 2 calls** (≤ 4 sub-questions per call):

- **Call 1** (always asked): 7a — the system gate. On `none` / plain waybar, stop here.
- **Call 1-bis** (only if 7a == `turnkey`): 7a-bis — which prebuilt shell. Single-question call.
- **Call 2** (only if 7a != `none`): 7b (which widgets), 7c (look), 7d (motion / density).

On a re-theme (Mode B), this whole component is **skipped** — re-theming just re-renders the
colors file for whatever shell is already recorded.

## Sub-questions

### 7a. Widget system  *(always asked — opt-in gate)*

Pre-filled from group 6's `bar.strategy` answer (list the matching option first so the user can
confirm with one press), but the gate is asked anyway — the bar answer reorders, it does not
short-circuit. Options:

- **None / just waybar** *(default)* — no widget shell. Stops the interview at 7a. (Choose this
  for a bar-only desktop or if waybar's `custom/*` + group/drawer already cover it.)
- **eww** — yuck (S-expression) + SCSS. Floating widgets *next to* waybar; the most flexible
  no-programming option; GTK3 CSS knowledge transfers.
- **AGS / Astal** — TypeScript / JSX over GTK3 or GTK4 + SCSS. Batteries-included services
  (network, bluetooth, mpris, notifications); the dashboard heritage. Replaces waybar.
- **Quickshell** — QML / Qt 6. The modern, animation-rich shells; live window previews are a
  Quickshell-only feature. Steepest curve; replaces waybar.
- **HyprPanel** — turnkey AGS-based panel, GUI-configured (`.json` theme import). Note: archived
  2026-04 (successor *Wayle* in Rust) but still installs and runs. Replaces waybar.
- **Turnkey pre-built shell** — install a ready Quickshell desktop (see 7a-bis). Replaces waybar.

### 7a-bis. Turnkey shell  *(only when 7a == `turnkey`)*

A clone-and-install of someone else's full desktop. These have their own theming model; **don't
hand-theme them** — drive them with **matugen** on the chosen wallpaper. Warn the user that the
plugin's per-app theming yields to the shell's own. Options:

- **end-4 / illogical-impulse** — the most-starred, Material You, AI sidebar, OCR extras.
- **caelestia** — Material 3, per-monitor `shell.json`, fingerprint lock, C++ beat-detector
  visualizer.
- **Noctalia** — sleek minimal, multi-compositor, plugin ecosystem.
- **DankMaterialShell** — full shell replacing bar / lock / idle / notifications / launcher at
  once; ships a `greetd` greeter.

### 7b. Which widgets  *(only when 7a != `none`)*

**`multiSelect`**. Ordered by how often each archetype appears in the corpus; defaults marked
*(on)* go first in the list. A full shell typically ships most of these out of the box;
eww-on-waybar usually adds just a couple (an OSD + a dashboard).

| Widget | Default | Notes |
|---|---|---|
| OSD (volume / brightness) | **on** | The most common reason people leave plain waybar. |
| Notification center | **on** | Owns the `org.freedesktop.Notifications` D-Bus name → group 9 must be `none`. |
| Music / now-playing (MPRIS) | **on** | Blurred cover-art card is the AGS / Quickshell showpiece. |
| Dashboard / control center | off | Quick-toggles + sliders + sysinfo + media. The signature shell widget. |
| Calendar / clock panel | off | |
| Power / session menu | off | Replaces wlogout when a full shell is picked. |
| Sidebar / quick-settings | off | Sliding panel with wifi / bt / dnd toggles. |
| System-info gauges (CPU / RAM rings) | off | `circular-progress` (eww) or `circularprogress` (AGS / QS). |
| Workspace overview with live previews | off | **Quickshell only** — GTK toolkits can't easily do it. |
| Clipboard / emoji / color picker | off | fabric (Ax-Shell) has the widest set; Quickshell second. |

### 7c. Widget look  *(only when 7a != `none`)*

Single-select. Options:

- **Match my palette** *(default)* — engine-themed from the chosen scheme (group 12). The rice
  engine's normal path.
- **Material You** — matugen-driven from the wallpaper. The dominant full-shell look; requires
  the `matugen` package (auto-added to install batch when picked). Pairs naturally with
  Quickshell / AGS / HyprPanel.
- **Glass / translucent + blur** — `rgba($surface, 0.6)` + Hyprland `layerrule` blur on the
  shell's layer namespace.
- **Flat / opaque** — high-contrast, no blur, no transparency.

### 7d. Motion & density  *(only when 7a is a full shell — `ags` / `quickshell` / `hyprpanel` / `turnkey`)*

Two single-selects, packed into one call slot.

**Motion:**
- **Smooth eased** *(default)* — Material / `Behavior` animations, soft shadows. The
  caelestia / Noctalia feel.
- **Snappy / minimal** — short durations, minimal eased curves.
- **Static** — no animations.

**Card shape:**
- **Soft cards ~16px radius** *(default)* — the dominant modern look.
- **Pill / stadium** — `radius: height / 2` for buttons / cards.
- **Square** — flat panels, no rounding.

(For an eww-on-waybar pick, 7d is skipped — eww widgets follow waybar's look-feel answers.)

## Record paths

After each `AskUserQuestion` call, persist with `record-answer.sh` (see `_interview-protocol.md` →
"Recording answers"):

```bash
# 7a (always)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.system none
# or: eww | ags | quickshell | hyprpanel | turnkey

# 7a-bis (only if widgets.system == "turnkey")
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.turnkey end-4
# or: caelestia | noctalia | dankmaterial

# 7b — array
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.enabled \
  --json '["osd","notification-center","music","dashboard"]'

# 7c
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.look match-palette

# 7d (only for full shells)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.motion smooth
```

When 7a is `none`, record the gate and **skip 7a-bis / 7b / 7c / 7d**:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.system none
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.enabled --json '[]'
```

When 7a is **not** `turnkey`, record `widgets.turnkey` as `null` so downstream readers branch
cleanly on `!= null`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" widgets.turnkey --json null
```

## Cross-references

- Strict-ask discipline + opt-in-gate rule → `_interview-protocol.md`
- Schema slice + types → `schema.md`
- Per-shell file wiring → `template.md`
- The design library (archetypes + per-toolkit techniques) → `styling.md`
- Engine manifest wiring + reload hooks → `theming/engine.md` → "Widget-shell theming",
  `reload.md`
- Notification-daemon conflict → `gotchas.md`, `../notifications/gotchas.md`
- Bar-replaced-by-shell → `gotchas.md`, `../waybar/gotchas.md`
- Packages → `packages.md`
