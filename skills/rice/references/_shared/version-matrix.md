# Hyprland version matrix (cross-cutting)

What's been added, removed, renamed, and how rice components branch by version. Authoritative
deprecation list: `${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/deprecations.md` —
this file summarizes the *branches the rice components have to make* on top of that. Branch on the
`HYPR_VERSION` field that `scripts/detect-version.sh` emits.

## Version cliffs that components branch on

| Cliff | What changed | Components affected |
|---|---|---|
| **0.42+** | Hyprland dropped wlroots for **aquamarine** ([PR #6608](https://github.com/hyprwm/Hyprland/pull/6608)). **All `WLR_*` env vars are silently no-ops** on every supported target (rice's floor is 0.50+ — well past 0.42). Notable: `WLR_DRM_NO_ATOMIC`, `WLR_NO_HARDWARE_CURSORS`. The aquamarine-side `AQ_NO_ATOMIC=1` exists but is "NOT recommended" per the env-vars wiki — do not emit. | `env` (don't list WLR_* in any default set), `gaming` (don't emit WLR_DRM_NO_ATOMIC), `_shared/version-matrix.md` (this entry). |
| **0.42+** | `master:new_is_master` → `master:new_status` rename (with values `master`/`slave`/`inherit`). | `look-feel` (master layout block). |
| **0.45+** | `gesture = FINGERS, DIR, ACTION` keyword API replaces `gestures { workspace_swipe = … }` block. **Action arg counts matter** — `float` action takes one optional arg (`gesture = 3, pinchin, float, tile` is invalid; use `gesture = 3, pinchin, float`). | `input` (gestures sub-question). Older targets use the block form. |
| **0.45+** | `hyprsunset` daemon ships as a Hyprland ecosystem tool — controlled via `hyprctl hyprsunset temperature <K>` / `hyprctl hyprsunset identity` (NOT by re-launching the binary; the second invocation does not toggle). | `accessibility`, `utilities`, `autostart` (don't bind `hyprsunset` as a toggle command). |
| **0.47+** | `decoration:rounding_power` added — corner-curve exponent. Use 2 by default; 2.3–4 for softer "squircle". | `look-feel`. |
| **0.51+** | **Gesture rework — REMOVED**: `gestures:workspace_swipe`, `workspace_swipe_fingers`, `workspace_swipe_min_fingers`. Remaining `workspace_swipe_*` tuning keys still valid. Use the 0.45+ `gesture =` keyword instead. | `input`. |
| **0.53+** | Window-rule **block form** (`windowrule { match:class = …; float = yes }`) is the shipped default. Single-line `windowrule = float, class:…` still parses for backward compat. **`windowrulev2` hard-errors** on 0.53+ (parser explicitly rejects with "windowrulev2 is deprecated"). | `window-rules`, `look-feel` (window-groups), `monitors` (workspace smart-gaps rules). |
| **0.54+** | `scrolling` is **core** (not a plugin). `general:layout = scrolling` + `scrolling {}` block + `layoutmsg` binds — safe uncommented. The old `hyprscrolling`/`hyprscroller` plugins are deprecated/superseded. **Cliff is 0.54, NOT 0.53** — verified absent at v0.53.0 `src/config/ConfigManager.cpp`, present at v0.54.0. | `look-feel` (layout option), `keybinds` (`layoutmsg, move +col` etc.), `plugins` (do NOT offer scrolling as a plugin). |
| **0.54+** | `layerrule` moved to the **block form**. **Bare-keyword line form `layerrule = blur, waybar` is rejected** at parse time (`invalid field blur: missing a value`) — fails the entire reload. Modern single-line form `layerrule = blur on, match:namespace waybar` **still parses**. Block form is the shipped default. | `window-rules` (the `layerrule` blocks), `waybar`, `launcher`, `notifications` (their blur rules). |
| **0.54+** | Verified `layerrule` block fields: `blur`, `no_anim`, `ignore_alpha = <0-1>`, `xray`, `animation = <style>`, `blur_popups`, `dim_around`, `order`, `above_lock`, `no_screen_share`. **No `ignore_zero`/`unique`** in block form. | `window-rules`. |
| **0.55+** | `misc:vfr` → `debug:vfr` (reclassified). Leaving `misc:vfr` set on 0.55 is a parse error. | `look-feel` (the `misc {}` block; `vfr = true` is set unconditionally as a default — branch the section by version). |
| **0.55+** | `dwindle:pseudotile` **removed** (was non-functional). The `pseudo` dispatcher and `windowrule = pseudo` still work. | `look-feel` (dwindle layout block — omit on 0.55+). |
| **0.55+** | `decoration:shadow:ignore_window` **removed** — behavior is now always on. | `look-feel`. |
| **0.55+** | `render:cm_fs_passthrough` **removed** — automatic when `render:cm_auto_hdr` is set. | (rarely used; uninvolved in defaults). |
| **0.55+** | `hyprctl setenv` **REMOVED** (gone in the Lua rewrite). Runtime env-set is now `hyprctl keyword env NAME,value` (drives the same `env` config keyword). | `env` (runtime propagation example). |
| **0.55+** | **Lua is the config language** (`~/.config/hypr/hyprland.lua`), and a `hyprland.lua` in the config dir is loaded **instead of** `hyprland.conf` (the check runs once, at startup). hyprlang is deprecated from 0.55 and supported for **1 - 2 releases starting from 0.55**, after which it is dropped ([upstream announcement](https://hypr.land/news/26_lua/)). From **0.56.0** a freshly installed Hyprland auto-generates a `hyprland.lua` into that directory the first time it starts, so the shadowing case is the default one, not an edge case. | **All components: the config LANGUAGE is itself a branch here.** `scripts/config-language.sh` resolves it (0.55+ -> lua, below -> hyprlang) and REFUSES to guess when the version is unknown; `scripts/emit-config.sh` writes in the resolved language; `scripts/install-config.sh` refuses to install a `.conf` into a directory that already holds a `hyprland.lua`; `scripts/migrate-config.sh` converts an existing `.conf` set. |
| **0.55+** | `decoration { glow {} }` (new effect), spring-based animation curve `animation = …, …, …, spring` — **but only via the Lua config API**. Hyprlang `.conf` `animation =` parser at v0.55.2 line 1454 still calls `bezierExists()` and rejects spring names. | `look-feel` (spring curves not emittable from `.conf`). |
| **0.55+** | Other additions: per-output ICC `icc = "<path>"`, dispatcher `moveintoorcreategroup`, `groupbar:middle_click_close`, scrolling-layout rules/messages (`scrolling_width`, `expel`/`consume`/`consume_or_expel`, `rotatesplit`), input device tags, windowrule `confine_pointer`. | (additive — opt-in surfaces). |

## External (non-Hyprland) version cliffs that matter

| Cliff | What changed | Components affected |
|---|---|---|
| **Firefox 121 (Dec 2023)** | Wayland is the **default** backend. `MOZ_ENABLE_WAYLAND=1` is a no-op (still respected; `=0` forces X11). | `env`, `default-apps`. |
| **alacritty 0.13 (Dec 2023)** | YAML config removed — TOML only (`alacritty.toml`, NOT `alacritty.yml`). | `terminal`. |
| **rofi 2.0.0 (Sep 2025)** | Wayland support **merged upstream**. Use repo `rofi`; the `rofi-wayland` AUR fork is obsolete and now `Provides/Replaces: rofi-wayland`. | `launcher`, `_shared/colors-contract.md`. |
| **hyprpaper 0.8.0** | **HARD BREAK** — config syntax changed: drop `preload = …` + `wallpaper = , …`; use `wallpaper { monitor=; path=; fit_mode=cover }` block. `ipc` defaults to `true`. Reload via `hyprctl hyprpaper wallpaper '[mon],[path],[fit_mode]'` and `hyprctl hyprpaper reload`. | `companion-daemons`, `theming/wallpaper.md`, `scripts/set-wallpaper.sh`. |
| **kernel 6.8** | Atomic-tearing support (rumored; couldn't verify primary source). Hyprland no longer uses wlroots regardless, so the old `WLR_DRM_NO_ATOMIC` kernel gate is moot. | `gaming` (no env gate needed). |
| **HyprPanel archived 2026-04-27** | Repo read-only; successor *Wayle* (Rust, GTK4, TOML). Still installable as `ags-hyprpanel-git` AUR. | `widgets`. |
| **hyprland-plugins PR #663 (2026-05-12)** | Dropped FIVE plugins from the official repo: `hyprexpo`, `hyprtrails`, `hyprscrolling`, `hyprwinwrap`, `xtra-dispatchers`. Now only `borders-plus-plus`, `csgo-vulkan-fix`, `hyprbars`, `hyprfocus` remain. Community forks: `sandwichfarm/hyprexpo`, `gen3vra/hyprwinwrap`. `Duckonaut/split-monitor-workspaces` was transferred to `zjeffer/split-monitor-workspaces`. | `plugins`. |

## Quick decision flow

```
detect-version → HYPR_VERSION

if HYPR_VERSION is unknown:
  - the CONFIG LANGUAGE cannot be assumed. config-language.sh reports both
    emittable languages and stops until an explicit choice is supplied
    (HYPR_CONFIG_LANG=lua|hyprlang).

if HYPR_VERSION ≥ 0.55:
  - config LANGUAGE is lua -> emit hyprland.lua, never hyprland.conf
  - emit debug:vfr instead of misc:vfr
  - omit dwindle:pseudotile from layout block
  - omit decoration:shadow:ignore_window
  - layerrule  → block form
  - windowrule → block form (already 0.53+)
  - scrolling layout safe uncommented (already 0.54+)
  - hyprctl setenv → hyprctl keyword env NAME,value

elif HYPR_VERSION ≥ 0.54:
  - config LANGUAGE is hyprlang -> emit hyprland.conf
  - layerrule → block form (HARD: bare-keyword line form fails parse)
  - scrolling layout core (this is the actual cliff)
  - keep misc:vfr (not yet moved)
  - keep dwindle:pseudotile

elif HYPR_VERSION ≥ 0.53:
  - windowrule → block form (preferred; line form still parses; windowrulev2 hard-errors)
  - layerrule → line form (block form not yet)
  - scrolling NOT yet core (still plugin territory)

elif HYPR_VERSION ≥ 0.51:
  - gestures:workspace_swipe REMOVED — use gesture = keyword

elif HYPR_VERSION ≥ 0.47:
  - rounding_power added

elif HYPR_VERSION ≥ 0.45:
  - gesture = … keyword API added
  - windowrulev2 / line forms

elif HYPR_VERSION ≥ 0.42:
  - aquamarine; WLR_* env vars become no-ops
  - master:new_is_master → master:new_status

else:
  - gestures {} block
  - windowrulev2 prefix
```

## Components' job

Each component's `gotchas.md` notes the version branches that touch its template; this matrix is
the index. The **validator** uses this file (plus `deprecations.md`) to flag deprecated syntax
emitted against the wrong target.

## Detect

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh"
# HYPR_VERSION=0.54.3
# HYPR_VERSION_MAJOR=0  HYPR_VERSION_MINOR=54  HYPR_VERSION_PATCH=3

bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/config-language.sh"
# CONFIG_LANGUAGE=hyprlang
# CONFIG_FILE=hyprland.conf
# CONFIG_LANGUAGE_RANGE=Hyprland up to 0.54; deprecated since 0.55 and supported for 1 - 2 releases starting from 0.55, after which hyprlang is dropped
```

If neither `hyprctl` nor `Hyprland` is on PATH the version is `unknown`. **Do not assume a
syntax and do not assume a language.** `config-language.sh` exits non-zero, reports the languages
it can emit with the version range of each, and waits for an explicit `HYPR_CONFIG_LANG` choice;
relay that to the user rather than picking for them. Guessing the language wrong does not produce
an error, it produces a config the compositor never reads.
