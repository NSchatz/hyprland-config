# Validator lint catalogs

The detailed lint tables for steps 6 and 7 of the `hyprland-config-validator` agent's
validation process: the semantic lints (defect-class hardening) and the cross-surface
coherence checks.

These live here rather than in the agent prompt because the prompt loads in FULL on every
invocation, including the runs that never reach these steps. The agent reads this file when
it gets to step 6.

## Contents

- Semantic lints (defect-class hardening)
- Cross-surface coherence checks

---

6. **Semantic lints (defect-class hardening).** Syntax validity ≠ correct output. Each lint
   below corresponds to a concrete defect class the validator now blocks — the cross-cutting
   `_shared/` registries (`namespaces.md`, `binaries.md`, `expected-binds.md`,
   `helper-scripts.md`) are the source of truth.

   - **No `rgb($var)` / `rgba($var)` / `#$var` double-wrap in emitted `*.conf`** (defect #3).
     The rice's `colors.conf` already stores palette keys as `$accent = rgb(<hex>)` —
     re-wrapping produces `rgb(rgb(<hex>))` which Hyprland rejects with "invalid color" and the
     whole reload fails. Lint:
     ```bash
     if grep -nE '(rgb|rgba)\(\$[a-zA-Z_]+|#\$[a-zA-Z_]+' "$conf"; then
         echo "ERROR: $conf has a double-wrap; palette vars in colors.conf are already
                fully-formed rgb()/hex — emit \$var bare. See look-feel/template.md."
         exit_status=1
     fi
     ```
     This applies to every emitted Hyprland `*.conf` — `colors.conf`, `looknfeel.conf`,
     `env.conf`, `windowrules.conf`, hyprlock, etc.

   - **Rofi themes must define the global `*` block AND the full element state matrix**
     (defect #4). Rofi overlays the user theme on top of its base theme; unstyled selectors
     inherit base-theme (usually light) colors. Required selectors:
     `* { … }`, `listview`, `element-text`, `element-icon`, and `element {normal,alternate,selected}.{normal,urgent,active}` (9 element-state blocks total).
     Lint per `components/launcher/` → "Rofi theme.rasi is SELF-CONTAINED".

   - **No literal `swww-daemon` / `swww img` / `awww-daemon` / `awww img` outside the binary
     registry** (defect #8). Search emitted *.conf and shipped scripts for these strings;
     except in `_shared/binaries.md`, `set-wallpaper.sh`, `render-templates.sh`, and a binary-
     agnostic `sh -c …` launcher, the literal must not appear. Lint:
     ```bash
     if grep -nE '\b(swww-daemon|awww-daemon|swww img|awww img)\b' "$conf" \
            | grep -vE 'sh -c|binaries\.md|set-wallpaper|render-templates|restore-theme'; then
         echo "ERROR: $conf hard-codes a SWWW binary name; emit \$SWWW_DAEMON_BIN via detection
                (see _shared/binaries.md) or the binary-agnostic launcher."
         exit_status=1
     fi
     ```

   - **Every `match:namespace = X` in `windowrules.conf` corresponds to a declared namespace
     in `_shared/namespaces.md`** AND the owner of that namespace is selected in
     `answers.json` (defects #11/#14). Build a set of declared+selected namespaces from the
     registry, then grep `match:namespace = (.+)$` and check each match is in the set. Emit
     WARNING for an unmatched namespace (it's not a parse error, just a silent no-op blur).

   - **Every gate in `_shared/expected-binds.md` whose condition holds in `answers.json` has a
     matching `bind = …, exec, <cmd>` line in `binds.conf`** (defects #12/#17). For each row
     in the registry, evaluate the gate; if true, search the emitted binds.conf for a line
     whose tail matches the declared command. Missing → ERROR.

   - **NVIDIA package recommendation matches the detected `NVIDIA_DRIVER_BRANCH`** (defect #15).
     If `install.sh` pulls `nvidia` (bare) and detection reports
     `NVIDIA_GENERATION ∈ {volta,pascal,maxwell,kepler,fermi}`, ERROR — the bare `nvidia`
     package no longer exists for those generations; the user needs the legacy AUR branch.
     Suggest the exact package set from `components/env/gotchas.md` "NVIDIA package branch".

   - **Render-manifest completeness: every selected themable surface has a manifest line**
     (v0.20.0 Issue 16 — defects 10/11/12/13). Read `answers.json` AND the generated
     `templates.list`. For each row in the matrix below, evaluate the condition against
     `answers.json`; if true, the manifest must contain a line whose `name` field matches AND
     the referenced `.tmpl` file AND the output directory's parent both exist. ERROR on any
     miss — surfaces have been historically half-themed (env var set, no config emitted) and a
     warning lets this regress. The matrix is the single source of truth for "which surfaces
     does the engine re-render":

     | Selected in `answers.json` (gate) | Required manifest name | Required `.tmpl` | Required output dir |
     |---|---|---|---|
     | `lock_screen.style` selected (hyprlock present) OR `companion_configs.hyprlock == true` | `hyprlock` | `templates/hyprlock.tmpl` | `~/.config/hypr/` |
     | `default_apps.file_manager == "dolphin"` OR `default_apps.file_manager == "krusader"` OR `env.qt_platformtheme == "qt6ct"` OR any other selected Qt app | `qt6ct` | `templates/qt6ct.tmpl` | `~/.config/qt6ct/colors/` |
     | `utilities.osd_route == "swayosd"` | `swayosd` | `templates/swayosd.tmpl` | `~/.config/swayosd/` |
     | Any GTK3 app in `default_apps` (thunar, nm-connection-editor, blueman, etc.) OR `gtk_settings.gtk3 == true` | `gtk3` | `templates/gtk3.tmpl` | `~/.config/gtk-3.0/` |
     | `default_apps.browser == "firefox"` AND `browser_theming.opt_in == true` | `firefox` | `templates/firefox.tmpl` | `<firefox-profile>/chrome/` (where `<firefox-profile>` is resolved by `firefox-bootstrap.sh` — see `components/browser/template.md`) |
     | `terminal.emulator`, `bar.strategy`, `launcher.tool`, `notifications.daemon` (their existing rows) | their existing manifest entries | their existing `.tmpl` | their existing dirs |

     The lint:
     ```bash
     # Pseudocode — read answers + manifest, evaluate the matrix, ERROR on any miss.
     answers="$conf_dir/answers.json"
     manifest="$conf_dir/templates.list"
     [ -f "$answers" ] && [ -f "$manifest" ] || return 0   # nothing to assert if either is missing
     manifest_has() { awk -F'\t' -v want="$1" '$1==want{found=1} END{exit !found}' "$manifest"; }

     # one row per selected surface (the matrix above)
     if jq -re '.lock_screen.style // empty' "$answers" >/dev/null; then
         manifest_has hyprlock || { echo "ERROR: lock_screen selected but no `hyprlock` manifest line"; exit_status=1; }
     fi
     # ... (the rest of the rows; see the matrix above for the full set)
     ```

     The matrix is also the spec the rice component-writer reads when emitting `templates.list`.
     Keep it synchronized — when a new themable surface lands, add a row here AND wire the
     emission in `SKILL.md` §A4.3.

   - **Manifest entries with an empty reload-cmd must declare a `next-X` hint** (v0.21.0
     Issue 15.3). The 5th column of `templates.list` is the "applies on next launch / lock /
     server restart" classifier — `rice apply`'s footer reads it to print
     `"3 surfaces apply on next launch: gtk3, qt6ct, hyprlock"` instead of leaving the
     switch looking half-applied. Lint: for each manifest line whose `reload-cmd` is empty
     or `:`, the 5th column must be one of `next-launch`, `next-lock`, `server-restart`,
     `restart`. Empty 5th column is allowed ONLY for surfaces that pick up via file-watch
     (eww, ags, wofi, rofi, gtk4 — their existing rows). WARNING on a miss (not ERROR —
     `rice apply` still works, the footer just loses that surface).

   - **No literal wallpaper path in `autostart.conf`, `hyprpaper.conf`, `hyprlock.conf`**
     (v0.20.0 Issue 3). The plugin's contract (`_shared/wallpaper-pointer.md`) is that every
     wallpaper consumer references the live symlink `~/.config/hypr-rice/current-wallpaper`,
     never a literal path captured at generation time — so re-themes change one symlink and
     every consumer follows. Lint:
     ```bash
     for f in "$conf_dir/autostart.conf" "$conf_dir/hyprpaper.conf" "$conf_dir/hyprlock.conf"; do
         [ -f "$f" ] || continue
         if grep -nE '[~]?/.*/(wallpapers?|Pictures)/[^[:space:],]+\.(png|jpg|jpeg|webp)' "$f" | \
                grep -v 'current-wallpaper'; then
             echo "ERROR: $f references a literal wallpaper path — use ~/.config/hypr-rice/current-wallpaper"
             exit_status=1
         fi
     done
     ```

7. **Cross-surface coherence checks (from the v0.14 3-batch research pass).** These catch
   real-world breakage observed across the corpus. All cite the upstream evidence; check
   against the per-component `validation.md` / `gotchas.md` for the full rationale.
   - **fuzzel layerrule namespace** — `layerrule = blur, fuzzel` and `layerrule { match:namespace = fuzzel; … }`
     are stale. Upstream `fuzzel.ini(5)` sets the default layer namespace to **`launcher`**.
     Flag as WARNING with the corrected line. (Common in older HyDE-derived configs.)
   - **swaync needs TWO blur blocks** — `swaync-control-center` AND `swaync-notification-window`.
     Each is a different layer surface; a single block leaves one un-blurred. Flag any swaync
     config that has fewer than 2 blocks as WARNING.
   - **Blur master-gate dependency** — if `decoration:blur:enabled = false` (or `blur { enabled = false }`
     in the block form) AND any `layerrule blur` lines exist, INFO-note that every blur layerrule
     is silently a no-op. Hyprland's `OpenGL.cpp::preRender` gates per-surface blur on the master
     decoration flag.
   - **hyprbars literal-hex anti-pattern** — if a `plugin:hyprbars` block emits a literal `#hex`
     for `bar_color`/`bar_text_color`/etc. instead of an `$accent`/`$fg` style variable, WARN.
     The corpus convention (ml4w, Matt-FTW) is to reuse `$surface`/`$fg`/`$muted`/`$red`/`$yellow`
     so re-themes carry through.
   - **kitty chrome export** — if `~/.config/kitty/colors.conf` (or the included colors file)
     is missing any of `cursor_text_color`, `url_color`, `active_tab_*`, `inactive_tab_*`,
     `tab_bar_background`, `*_border_color`, INFO-note that the tab bar and window borders fall
     back to kitty's hardcoded gray defaults which always clash. Skip if `tab_bar_style = none`.
   - **`env = XDG_CURRENT_DESKTOP,...`** — flag as WARNING and recommend `envd =` (D-Bus push)
     so D-Bus-activated apps (notification clicks, portals) see the value. Plain `env =` only
     reaches direct compositor-spawned children.
   - **mako `urgency=high` invalid** — mako only knows `low|normal|critical`. `[urgency=high]`
     silently parses to nothing. Flag as ERROR. Verified against `emersion/mako` mako(5).
   - **walker `layerrule` only valid pre-v0.50** — if `layerrule = blur, walker` is present AND
     `HYPR_HAS_EXT_BG_EFFECT_V1=1`, INFO-note that walker now handles its own blur via
     `ext_background_effect_blur` (commit `7d1e481`, May 2026). The layerrule is redundant but
     not broken.
   - **Astronaut SDDM sub-theme filename** — `~/.config/sddm.conf.d/*.conf` referencing an
     Astronaut sub-theme: filenames are `snake_case.conf` (`black_hole.conf`, `hyprland_kath.conf`).
     A camelCase name silently falls back to the base theme. Verified against
     `Keyitdev/sddm-astronaut-theme/Themes/`.
