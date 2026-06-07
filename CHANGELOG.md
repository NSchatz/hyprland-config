# Changelog

## 0.19.0

End-to-end production-shakedown release. A complete `/hyprland-config:rice` run on Arch +
Hyprland 0.55.2 (Pascal/nouveau, ultrawide, uwsm, plugin v0.18.0) surfaced 17 defects spanning
templates, agents, the validator, and a missing cross-writer contract layer. v0.19 fixes them
at the recipe / writer / contract level (no patches in generated output) and adds the
matching semantic lints so the same defect classes can't ship silently again.

### Cross-writer integration contracts (new `_shared/` registries)

Defects #8, #11, #12, #14, and #17 are the same shape: writer A emits something writer B is
supposed to match (binary name, layer-shell namespace, keybind, bar module, helper script),
and they don't see each other's answers. Four new registries — the single source of truth —
are now consumed by every writer that needs the cross-component view:

- **`references/_shared/namespaces.md`** — every layer-shell namespace and window class any
  writer emits or matches. Eww uses `eww-<name>`; swayosd uses `swayosd`; quickshell uses
  `quickshell:*`; fuzzel uses `launcher` (not `fuzzel`). Window-rules reads from here.
- **`references/_shared/binaries.md`** — the detected-binary registry. SWWW resolves to
  `swww-daemon` (upstream, archived) or `awww-daemon` (fork). Every writer that emits a
  binary takes it from this registry or emits the agnostic `sh -c …` launcher when detection
  ran pre-install.
- **`references/_shared/expected-binds.md`** — when component X is selected, the keybind /
  waybar module that goes with it. Eww widgets, power-menu, blur-toggle, theme-switch are all
  declared here. The keybinds + waybar writers read this so a selection actually wires up.
- **`references/_shared/helper-scripts.md`** — the runtime helper scripts each surface needs.
  Eww's `sysinfo` / `audio` / `player` / `toggles` are declared here; the installer copies
  them. Without this registry, eww shipped as styled-empty widgets.

### Defect fixes (priority order)

- **#1 — generation-time jq dependency dropped.** `scripts/record-answer.py` (new) implements
  the answers-persistence helper in Python stdlib; `record-answer.sh` is now a thin wrapper.
  New `scripts/answers.py` (`get` / `slice` / `list` / `has`) replaces every generation-time
  `jq` invocation across SKILL.md, the interviewer, the component-writer, and the widgets
  gotchas. Runtime scripts (`keybind-cheatsheet.sh`, eww data scripts) keep using jq.
- **#2 — inline interview path is co-equal.** `SKILL.md` A1 now probes `AskUserQuestion`
  availability up-front and picks the agent vs inline path deterministically; the inline path
  is documented as a peer, not a fallback. The interviewer agent's message reflects the
  orchestrator pre-check.
- **#3 — `rgb($bg)` double-wrap removed.** `look-feel/template.md` emits `background_color =
  $bg` (palette vars in `colors.conf` are already `rgb(<hex>)`; re-wrapping fails the reload).
  Validator agent now lints `rgb($var)` / `rgba($var)` / `#$var` patterns in emitted `*.conf`.
- **#4 — rofi theme is self-contained.** `launcher/template.md` ships the global `*` block
  + explicit `background-color` on listview/element/element-text/element-icon + the full
  nine-state element matrix (`{normal,alternate,selected}.{normal,urgent,active}`). The base
  theme no longer bleeds through. Validator + `launcher/validation.md` lint each required
  selector.
- **#5/#6 — paru bootstrap rebuilt.** `agents/hyprland-package-installer.md` probes that the
  helper actually runs (`paru --version`), builds `paru` from source (not `paru-bin` —
  prebuilt fails on libalpm ABI bumps), and sweeps both `paru-bin` AND `paru-bin-debug`
  together before the source build (otherwise `paru-debug` from the new build conflicts with
  the orphan).
- **#7 — wf-recorder default + per-package AUR install.** `utilities/interview.md` /
  `template.md` / `packages.md` / `gotchas.md` default screen-record to `wf-recorder` (repo,
  C, no ffmpeg-next pin); `wl-screenrec` is opt-in with the AUR-Rust-build warning.
  `screenrecord.sh` prefers `wf-recorder` first. Installer agent now installs AUR packages
  individually so one broken build (typical: `wl-screenrec`) can't abort the whole batch.
- **#8 — SWWW binary threaded through.** `autostart/template.md` reads `SWWW_DAEMON_BIN`
  from `detect-version.sh` when present and otherwise emits the binary-agnostic launcher
  `sh -c 'command -v swww-daemon >/dev/null && exec swww-daemon || exec awww-daemon'`.
  Validator lints any literal `exec-once = swww-daemon` / `awww-daemon` outside the
  detector.
- **#9 — monitor magic-mode picker reworded.** `monitors/interview.md` lists the detected
  native mode first when one is reported, then `highres` (recommended, native resolution)
  before `highrr` (highest refresh, may downgrade resolution). `gotchas.md` documents why
  `highrr` can silently land at 1080p on an ultrawide.
- **#10 — eww helper scripts ship.** `assets/scripts/eww/{sysinfo,audio,player,toggles}` are
  new POSIX-shell helpers; the contract lives in `_shared/helper-scripts.md`; the installer
  copies them under `~/.config/eww/scripts/` and `chmod +x`s. `components/widgets/template.md`
  references the canonical paths and lists the runtime deps (`wireplumber`, `brightnessctl`,
  `playerctl`, `networkmanager`, `bluez-utils`); `widgets/packages.md` pulls them.
- **#11 — eww blur layerrule matches `eww-.*`.** `window-rules/template.md` matches the
  family namespace (not bare `eww`, which exists nowhere); the contract is declared in
  `_shared/namespaces.md`. Validator lints every `match:namespace` against the registry.
- **#12 — keybind contract.** `keybinds/template.md` emits widget-toggle binds gated on
  `widgets.system`/`widgets.enabled`, per `_shared/expected-binds.md`. Same contract used
  for #17.
- **#13 — OSD owner cross-validate.** `widgets/gotchas.md` documents the conflict-resolution
  rule when `widgets.enabled` ∋ OSD AND `utilities.osd_route == swayosd`. The orchestrator
  asks the user which side owns OSDs and drops the other instead of letting both render.
- **#14 — swayosd blur via the same namespace contract.** `window-rules/template.md`
  emits a `match:namespace = swayosd` block when `utilities.osd_route == "swayosd"`;
  `SKILL.md` A3b threads the utilities slice to the window-rules writer.
- **#15 — NVIDIA driver branch mapping.** `scripts/detect-version.sh` reads the PCI device
  id, maps it to a generation (blackwell/ada/ampere/turing/volta/pascal/maxwell/kepler/
  fermi), and emits `NVIDIA_GENERATION=` + `NVIDIA_DRIVER_BRANCH=`
  (`nvidia-open` for Turing+, `nvidia-580xx` for Volta/Pascal/Maxwell,
  `nvidia-470xx` for Kepler, `nvidia-390xx` for Fermi). `env/gotchas.md` documents the
  package set per branch + the AUR caveats. Validator lints a bare `nvidia` package install
  on Pascal-or-older.
- **#16 — cursor `no_hardware_cursors` comment fixed.** `look-feel/template.md` now says
  "0 = HW cursors / 1 = software / 2 = auto" plainly, instead of the confusing original
  "disable/enable/auto".
- **#17 — power-menu module on waybar.** `waybar/template.md` emits a `custom/power`
  module wired to `powermenu.sh` (rofi flavor) or `wlogout -p layer-shell` (wlogout
  flavor) when `utilities.selected ∋ power-menu`. Declared in
  `_shared/expected-binds.md` → "Waybar modules".

### Validator semantic lints (defect-class hardening)

`agents/hyprland-config-validator.md` step 6 (new) blocks each defect class above:

- No `rgb($var)` / `rgba($var)` / `#$var` double-wrap in emitted `*.conf`.
- Rofi themes declare the global `*` block AND the full nine-state element matrix.
- No literal `swww-daemon` / `awww-daemon` outside the binary registry and detector.
- Every `match:namespace` in `windowrules.conf` corresponds to a declared namespace whose
  owner is selected.
- Every gate in `expected-binds.md` that holds in `answers.json` has a matching `bind = …,
  exec, <cmd>` line.
- NVIDIA package recommendation matches the detected `NVIDIA_DRIVER_BRANCH`.

### Tests

- **`tests/test_record_answer.sh`**: now exercises the Python implementation and asserts
  `record-answer.py` runs with no `jq` on `PATH`.
- **`tests/test_answers.sh`** (new): full `get` / `slice` / `list` / `has` coverage for the
  new jq-free read helper; pins jq-independence.
- **`tests/test_semantic_lints.sh`** (new): regression tests for the recipe state the
  validator agent enforces — `rgb($var)` absence, the rofi state matrix, the SWWW exec-once
  literal absence, the `_shared/*` registry shape, the expected-binds emission. Catches each
  defect class at the template level.

### Skill

- **`SKILL.md`**: bumped to `0.19.0`.

## 0.18.0

Final orchestrator decision originally flagged: lock-screen wallpaper strategy. The
batch-3 `wallpaper.md` agent hinted at a `lock_screen.wallpaper_strategy` field that
didn't exist; reality was the existing `lock_screen.background` enum was missing one
corpus pattern (ML4W's pre-baked blur). v0.18 closes the gap.

### Lock-screen

- **`components/lock-screen/schema.md`** + **`interview.md`**: `background` enum grows
  from 3 → 4 values. New: `pre-baked-blur` (ML4W pattern — `path = ~/.cache/hypr-rice/lock-blur.png`
  + `blur_passes = 0`; cache file regenerated by the engine on every wallpaper-pick so
  GPU cost is paid once instead of every unlock).
- **`components/lock-screen/template.md`**: new background block for the
  `pre-baked-blur` case. Documents the ImageMagick dep and the fallback behavior.

### Engine

- **`scripts/render-templates.sh`**: new `write_lock_blur()` function. Gated on
  `RICE_LOCK_BLUR=pre-baked` env (mirrors `RICE_THEMING_ENGINE` shape). Reads the
  current wallpaper path from `palette.conf`, pre-blurs to
  `~/.cache/hypr-rice/lock-blur.png` via `magick`/`convert` (`-blur 0x12` matches
  hyprlock's perceptual blur_passes=3,blur_size=7). Soft-fails when ImageMagick isn't
  installed — the writer's coherence rule appends `imagemagick` to the install batch
  when the user picks `pre-baked-blur`, so this only fires for users who deliberately
  skipped the install.

### References

- **`theming/wallpaper.md`** § "Lock-screen wallpaper decoupling": stale field
  reference (`lock_screen.wallpaper_strategy`, never existed) corrected to
  `lock_screen.background`. Documents the new `pre-baked-blur` option and the engine
  hook.

### Agents

- **`agents/hyprland-component-writer.md`**: new coherence rule enumerating all four
  `lock_screen.background` forms and their emission shape, including the
  `imagemagick` install-batch append for `pre-baked-blur`.

### Skill

- **`SKILL.md`**: bumped to `0.18.0`.

### All orchestrator decisions complete

The four orchestrator decisions originally flagged in v0.14 are all shipped:

- v0.15 — `font_ui_scale` cross-surface multiplier (DMS/caelestia prior art)
- v0.16 — `high-contrast-dark` / `high-contrast-light` schemes (WCAG-AAA)
- v0.17 — `utilities.osd_route` (the #1 cross-surface coherence miss in the corpus)
- v0.18 — `lock_screen.background = pre-baked-blur` (ML4W pattern)

## 0.17.0

Lands the OSD-routing question (orchestrator decision #4 of 4 originally flagged).
The laptop batch-2 agent named this **the #1 cross-surface coherence miss across the
top-19 rices** — Matt-FTW ships `swayosd-client` binds without a swayosd matugen
template, and the OSD reverts to stock GTK colors that clash with the rest of the
rice. v0.17 makes the route an explicit interview pick and emits coherent recipes
for every choice.

### Interview

- **`components/utilities/interview.md`**: new sub-question **18b. OSD routing.**
  Four options — `in-shell` (Quickshell IPC), `swayosd` (dedicated daemon),
  `notification` (`notify-send -a OSD` + `[app-name=OSD]` palette block), `none`
  (silent). Defaults reordered per detected widget shell: `in-shell` when the user
  picks a Quickshell-based shell, `swayosd` otherwise.
- **`components/utilities/schema.md`**: `utilities.osd_route` enum added. Documents
  which downstream component-writer reads it for what emission.
- **`references/_interview-protocol.md`**: group 18 count `1 call` → `2 calls`.

### Recipes

- **`components/keybinds/template.md`**: media-key bind block (lines 183-189
  formerly) now switches on `utilities.osd_route`. Four variants — IPC, swayosd,
  notify-send, silent. Volume/brightness keys still WORK in every branch.
- **`components/notifications/template.md`** (mako + dunst sections): emits an
  `[app-name=OSD]` (mako) or `[osd_app]` (dunst) palette override block when
  `utilities.osd_route == "notification"`. Uses `{{accent}}` for the frame and
  `{{surface}}` for the bg so the OSD inherits the rice palette.
- **`components/autostart/template.md`**: the `swayosd` autostart gate is now keyed
  on `utilities.osd_route == "swayosd"` instead of a separate `autostart_env`
  entry — the route decision is what gates it.
- **`components/laptop/gotchas.md`** § (j): "Open question for the orchestrator"
  flipped to **"Resolved (v0.17+)"** with the schema reference.

### Agents

- **`agents/hyprland-component-writer.md`**: new coherence rule for OSD routing.
  Explicitly notes the Matt-FTW coherence-miss antipattern and prescribes the
  coherent recipe per route (don't double-render in-shell + swayosd; ship a
  swayosd matugen template when `osd_route == swayosd`).

### Skill

- **`SKILL.md`**: bumped to `0.17.0`.

### Orchestrator decisions still pending

- `lock-screen.wallpaper_strategy` schema addition (the last one).

## 0.16.0

Lands `high-contrast-dark` and `high-contrast-light` schemes — the WCAG-AAA palette pair
v0.14 flagged as the biggest accessibility unlock. Zero corpus rices ship a true
high-contrast variant; the rice now does, with documented contrast budgets and a
fixed-palette opt-out from wallpaper derivation.

### Palette schemes

- **`_shared/palette-schema.md`**: `scheme=` enum expanded — `high-contrast-dark` and
  `high-contrast-light` added with a "WCAG-AAA; opt out of matugen" note.
- **`theming/palettes.md`**:
  - New rows in dark/light catalog tables and the semantic-hues table with verified hex
    values. Dark: bg `000000` / fg `ffffff` / accent `ffff00`. Light: bg `ffffff` /
    fg `000000` / accent `0000ee`.
  - New **"High-contrast schemes"** section with:
    - Contrast budget table (every documented `fg`/`accent`/`accent2`/`muted`/`red` vs `bg`
      pair clears AAA — 21:1 / 19.6:1 / 16.7:1 / 14.6:1 / 8.2:1 on dark).
    - Opt-out from wallpaper-derivation explanation.
    - Interaction with GTK4 `prefers-contrast: more` — our `gtk4.tmpl` overrides system
      preference for our rendered surfaces.
- Removed stale "## Gaps surfaced" section (font_ui_scale shipped in 0.15, high-contrast
  ships here, M3 motion adjacent now noted inline).

### Scripts

- **`palette-from-wallpaper.sh`**: early-returns when current scheme is `high-contrast-*`.
  Keeps the fixed AAA palette intact and only updates the `wallpaper=` line so the user
  still sees their picked wallpaper behind the (still high-contrast) UI. To resume
  derivation: `rice scheme catppuccin-mocha && rice wallpaper <img>`.

### References

- **`theming/wallpaper.md`**: new "High-contrast schemes opt out of derivation" subsection
  under Dynamic theming.
- **`components/accessibility/gotchas.md`**: "no popular rice ships a high-contrast palette"
  finding flipped to "now shipped" with the dual-scheme reachability paths (interview pick
  AND `rice scheme high-contrast-dark`) and the GTK4 override note.

### Skill

- **`SKILL.md`**: preset list 12 → 14 (high-contrast-dark, high-contrast-light); bumped to
  `0.16.0`.

### Orchestrator decisions still pending

- laptop interview sub-question for OSD routing strategy.
- `lock-screen.wallpaper_strategy` schema addition.

## 0.15.0

Lands the **cross-surface font-scale** the v0.14 release flagged as pending. One palette
metadata key, every visual surface scales together — the accessibility / HiDPI knob the
corpus had as DankMaterialShell-only prior art is now a first-class rice feature.

### Cross-surface font-scale (`font_ui_scale`)

- **`_shared/palette-schema.md`**: new metadata key `font_ui_scale` (multiplier, default
  `1.0`; interview options `1.0|1.15|1.3|1.5`). Always populated; defaults to `1.0` if
  unset. Documented sizing rules show the per-surface convention.
- **`theming/palette.matugen.tmpl`**: emits `font_ui_scale=1.0` so a wallpaper-cycle
  re-render preserves the user's scale instead of dropping it.
- **`theming/fonts.md`**: "pending pattern" section flipped to **"Cross-surface
  font-scale"** with the per-surface convention (recipe-driven CSS surfaces use
  `font-size: calc(<base>px * {{font_ui_scale}})`; recipe-driven non-CSS surfaces
  multiply at generate time; quickshell exposes `Colors.fontScale` for QML).
- **`components/widgets/quickshell.tmpl`**: new `readonly property real fontScale:
  {{font_ui_scale}}` property; QML files use `font.pixelSize: <base> * Colors.fontScale`.
  Hot-reload picks it up.
- **`_shared/colors-contract.md`**: quickshell row now includes `fontScale` in the
  exported singleton names.
- **`agents/hyprland-component-writer.md`**: new coherence rule — every recipe fill scales
  font-sizes by `{{font_ui_scale}}`. CSS surfaces use `calc()`, non-CSS surfaces multiply
  at write time, QML surfaces use `Colors.fontScale`. Notes the DMS dual-knob pattern
  (`fontScale` + `dankBarFontScale`) as future per-surface override prior art.
- **`components/accessibility/gotchas.md`**: the "no shared font-scale" absence finding
  is rewritten as **"Shared font-scale variable (now exposed)"** with prior art and the
  complement to the `larger-ui` gsettings bridge.
- **`SKILL.md`**: A4 always populates `font_ui_scale`; bumped to `0.15.0`.

### Orchestrator decisions still pending
- `high-contrast-dark` / `high-contrast-light` scheme (ripple-list in `palettes.md`).
- laptop interview sub-question for OSD routing strategy.
- `lock-screen.wallpaper_strategy` schema addition.

## 0.14.0

Three-batch deep-research pass across the corpus (top ~19 community Hyprland rices on
github.com/topics/hyprland) — 22 component reference folders + 7 cross-cutting theming docs
updated against verified upstream sources. The skill, the writer + validator agents, and the
contract files are updated to leverage what landed.

### Engine scripts
- **`render-templates.sh`**: after the manifest loop, optionally writes
  `~/.config/hypr/scripts/restore-theme.sh` when `RICE_THEMING_ENGINE=matugen|wallust|wallbash`
  is set. The script re-paints the wallpaper and re-runs the theming engine on login so the
  desktop comes up matching the last rice state instead of a stale palette. Skipped on `none`
  or unset. Body per engine documented in `references/theming/engine.md`.
- **`detect-version.sh`**: emits `HYPR_HAS_EXT_BG_EFFECT_V1=1|0|unknown` — true at Hyprland
  commit `7d1e481` (May 2026, ~v0.50+) where `ext-background-effect-v1` lands. Walker's
  `ext_background_effect_blur = true` opt-in needs the protocol; on older Hyprland the only
  path is a `layerrule = blur, walker` block. The flag lets the writer + window-rules
  template branch correctly without re-parsing the version string.

### Color templates / contract
- **`components/launcher/fuzzel.tmpl`**: grows from 7 → 11 keys to match every documented
  fuzzel.ini(5) color slot. Adds `prompt` (→ `{{accent}}`), `placeholder` (→ `{{muted}}`),
  `input` (→ `{{fg}}`), `counter` (→ `{{muted}}`). No new palette schema keys.
- **`_shared/colors-contract.md`** rows brought into sync with the actual `.tmpl` content:
  - `kitty` row gains 10 chrome keys (`cursor_text_color`, `url_color`, `active_tab_*`,
    `inactive_tab_*`, `tab_bar_background`, `active_border_color`, `inactive_border_color`,
    `bell_border_color`) so themes don't fall back to kitty's gray defaults on the tab bar.
  - `gtk4` row grows from 14 → 24 keys (libadwaita 1.4+ standards: `headerbar_backdrop_color`,
    `card_fg_color`, `popover_fg_color`, `dialog_*`, `sidebar_*`, `error_color`). Prevents
    DMS's documented "white flash on window unfocus" and themes Nautilus/Loupe correctly.
  - `fuzzel` row grows from 7 → 11 keys (see above).
  - `quickshell` row: `term[16]` → `term0..term15` (individual properties — community uses
    `Colors.term3` direct, not array index), plus M3 motion tokens (`standard`,
    `standardAccel`, `standardDecel`, `emphasized`, `emphasizedAccel`, `emphasizedDecel`).

### Agents
- **`hyprland-component-writer`**: new "Cross-surface coherence" section codifies the
  corpus-validated rules every recipe fill must honour — pill `{{rounding}}` reuse,
  shared `{{accent}}`, hyprbars palette reuse, `#battery.critical → {{red}}`, per-tool
  layerrule namespace map (fuzzel→`launcher`, swaync→2 blocks, walker conditional),
  `envd =` for XDG vars, mako `urgency=critical` (not `high`), Astronaut SDDM
  `snake_case.conf` filenames.
- **`hyprland-config-validator`**: new lint rules step 6 catches the real-world breakage
  the corpus pass surfaced — fuzzel namespace, swaync dual-layer blur, blur master-gate
  dependency, hyprbars literal-hex anti-pattern, kitty chrome export gaps, `env =
  XDG_CURRENT_DESKTOP` (recommend `envd =`), invalid mako `urgency=high`, walker layerrule
  redundancy ≥0.50, Astronaut filename casing.

### References (component-level — batches 1+2)
- **Visual components** (waybar / launcher / notifications / widgets / look-feel /
  lock-screen / terminal / shell-prompt): 8 deep-research passes harvesting theming idioms,
  archetypes, battle-tested techniques, and cross-surface coherence rules from the corpus.
  Highlights: waybar `fixed-center`/`ipc`/JBM `font-feature-settings`; rofi state-selector
  `element selected.normal/urgent/active` syntax fix; quickshell `Singleton` root + M3
  motion tokens; kitty tab-bar chrome; mako `[urgency=critical]` correction; hyprlock
  matugen `hyprlock-colors.conf` archetype; look-feel locked-group color ladder; starship
  `command_timeout=500` + `⇡⇣⇕` glyphs.
- **Structural components** (monitors / input / keybinds / default-apps / env / window-rules
  / autostart / companion-daemons / plugins / utilities / login-boot / gaming / laptop /
  accessibility): 14 deep-research passes harvesting "how popular rices use this component IN
  SERVICE OF the theme". Highlights: window-rules per-tool layerrule emission with all 5
  batch-1 flags upstream-confirmed; autostart `restore-theme.sh` ownership + `dbus_propagation`
  schema; env `envd =` for XDG + Electron-Ozone non-NVIDIA split; plugins 0.55+ lua cliff;
  utilities `theming/apps.md` wlogout-path correction; accessibility three documented
  absence findings (no high-contrast palette, no shared font-scale, no motion-off profile).

### References (cross-cutting theming — batch 3)
- **`theming-architecture.md`**: documents the post-refactor `.tmpl` layout, the new
  dataflows (`restore-theme.sh`, `envd`, layerrule emission table), and cross-surface
  palette coherence (`decoration:rounding` canonical, `$accent` shared).
- **`engine.md`**: per-engine `restore-theme.sh` body table (matugen / wallust / wallbash /
  none) with the canonical guarded script, `HYPR_HAS_EXT_BG_EFFECT_V1` walker blur cliff.
  Palette-template audit confirmed clean: 0 missing exports across all 18 component
  `.tmpl`s and `gtk4.tmpl`.
- **`palettes.md`**: 4 corpus scheme-supply patterns, 26→12 / 40+→12 / `dank16` mapping
  tables, high-contrast scheme gap with the full ripple-list of files an enum would touch.
- **`fonts.md`**: per-rice font picks for 14 corpus rices, omarchy `omarchy-font-set` sweep
  as the model for the re-render path, per-app font-size unit table (rofi pt, fuzzel
  pt-suffix, kitty pt, waybar/QML px, hyprlock per-label pt), `font_ui_scale` pending
  pattern with caelestia/DMS prior art.
- **`wallpaper.md`**: daemon-by-rice table for all 19 corpus rices, Quickshell-owns-wallpaper
  architecture fork, canonical restore-script bodies per engine, lock-screen wallpaper
  decoupling.
- **`apps.md`**: per-app palette-export table resync against actual `.tmpl` content (kitty
  chrome, quickshell `term0..15`, plugins rows), default-apps ricochet table (which
  component's `.tmpl` re-themes each default-app pick), btop/cava `components/utilities/` →
  `components/terminal/` path correction.
- **`gtk-qt.md`**: cursor-coherence three-place table, toolkit footguns
  (`_JAVA_AWT_WM_NONREPARENTING`, `MOZ_DISABLE_RDD_SANDBOX`, `GSK_RENDERER=ngl`,
  `ELECTRON_OZONE_PLATFORM_HINT,auto`), default-app pairing
  (Dolphin→Kvantum, Nautilus→localsearch), `hyprctl setenv` → `hyprctl keyword env` (0.55+
  form).

### Skill
- **`SKILL.md`**: bumped to `0.14.0`. A3 documents the cross-surface coherence rules the
  writer agent enforces. A4 documents `RICE_THEMING_ENGINE` env for `restore-theme.sh`
  emission and the autostart `exec-once` wiring.

### Orchestrator decisions still pending (not in this release)
- New `scheme` enum values for `high-contrast-dark` / `high-contrast-light` (ripple-list
  in `palettes.md`).
- `font_ui_scale` metadata key with caelestia/DMS prior art (ripple to every visual
  `template.md`).
- laptop interview sub-question for OSD routing strategy (#1 cross-surface coherence miss
  in the corpus).
- `lock-screen.wallpaper_strategy` schema addition.

## 0.13.0

Corrections and hardening from an extensive real-world from-scratch build on **Hyprland 0.55.2**
(wallpaper-driven Everforest rice with an hourly matugen re-theme cycle).

### Engine scripts
- **`palette-from-wallpaper.sh`**: fixed for **matugen 4.x** — it now writes a top-level `[config]`
  table (required, else "missing field config") and passes `--prefer`/`--mode`/`--type` (headless
  matugen needs `--prefer` when an image yields multiple source colors). Overridable via
  `MATUGEN_TYPE`/`MATUGEN_MODE`/`MATUGEN_PREFER`. Without this, every wallpaper-driven theme/cycle
  silently kept the old palette.
- **`palette.matugen.tmpl`**: emits `font_ui`/`font_mono` so a re-render (e.g. a wallpaper cycle)
  no longer drops the fonts from `palette.conf`.
- **`safe-apply.sh`**: rollback no longer `rm -rf`s `~/.config/hypr` — a running Hyprland regenerates
  a STUB config the instant the dir goes empty, racing the restore and leaving a nested/stub mess. It
  now restores by overwriting backup files back over the target and pruning only the files the failed
  config added (the dir is never empty).
- **`rice-init.sh`**: derives the plugin's rice dir from the script's own location when
  `CLAUDE_PLUGIN_ROOT` is unset (was a hard abort).

### Color templates (re-theme coherence)
- **`waybar.tmpl`** now emits the full named palette (`…blue/magenta/cyan`) so per-module-hue styles
  re-theme; **`swaync.tmpl`** adds `muted`/`accent2`; **`rofi.tmpl`** switched to the
  `bg/bg-alt/fg/muted/accent/accent2/red/green` var names the theme.rasi actually imports. (Previously
  the engine emitted names the component styles didn't reference, so an `apply` broke the styling.)

### References
- **`components.md`**: waybar Nerd Font glyph rule — a linter strips 3-byte legacy-PUA glyphs
  (U+E000–U+F8FF) from `config.jsonc`, so use 4-byte Material Design icons (U+F0000+) + plain Unicode
  dots (`●`/`○`); verified glyph table; author via `python3 json.dump(ensure_ascii=False)` + re-verify.
  Far-end pill margins for the separated-pills archetype. The `$menu` vs `$dmenu` bug (`$menu -dmenu`
  is broken). swaync `backlight` widget only when a backlight device exists.
- **`config-templates.md`**: `follow_mouse` semantics corrected (`1` is focus-follows-mouse, `2` is
  detached); native **`scrolling`** layout (core in 0.53+, no plugin) + `scrolling {}` block + binds;
  `$dmenu` variable; hyprlock input field kept visible (`fade_on_empty=false`); plugin-dispatcher binds
  must be commented (they hard-error the reload).
- **`plugins.md`**: rewritten — `hyprexpo`/`hyprtrails`/`hyprscrolling` removed from the official repo
  (scrolling is native; hyprexpo via `sandwichfarm/hyprexpo`); hyprpm gotchas (root-owned
  `/var/cache/hyprpm` + internal sudo needs a TTY, `~/.local/share/hyprpm` must exist, don't chain
  enables, `hyprctl plugin load` no-root alternative, plugin dispatchers hard-error).
- **`interview.md`**: focus-model option mapping fixed; plugins catalog updated for native scrolling +
  removed plugins.
- **`theming.md` / `engine.md`**: GTK3/4 `settings.ini` + `~/.gtkrc-2.0` are required (gsettings alone
  leaves GTK3 apps light). eww SCSS uses `rgba()` not `alpha()` (grass 1-arg), no `:height "auto"`.
- **hyprland-reference `styling/`**: `eww.md`, `waybar.md`, `hyprlock.md` mirror the above.

### Agents & skill
- **`hyprland-interviewer`**: documents that `AskUserQuestion` may be disabled inside subagents — probe
  first, return `INTERVIEW=blocked`, never fabricate answers.
- **`hyprland-config-validator`**: flags uncommented plugin-dispatcher binds / plugin-layout lines as
  reload-breaking ERRORS (was wrongly treating them as inert).
- **rice `SKILL.md`**: A1 inline-interview fallback for the blocked case; A4 matugen-4.x note; A5 GTK
  settings.ini + the dynamic-wallpaper systemd-timer pattern; the fourth GTK gotcha.
