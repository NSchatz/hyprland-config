# Sources - skills/rice/references/components/look-feel/styling.md

Research provenance for `skills/rice/references/components/look-feel/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- Hyprland Wiki — Variables (`general`, `decoration`, `blur`, `shadow` tables, defaults):
  <https://wiki.hypr.land/Configuring/Basics/Variables/>
- Hyprland Wiki — Animations (bezier/animation syntax, animation tree, styles):
  <https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/>
- Shipped default config, Hyprland **0.54.3** (`/usr/share/hypr/hyprland.conf`) — source of the
  verbatim default `general`/`decoration`/`animations` blocks above.
- JaKooLit Hyprland-Dots — community bezier presets:
  <https://github.com/JaKooLit/Hyprland-Dots>
- end-4/dots-hyprland — Material-Design motion curves & layered animations:
  <https://github.com/end-4/dots-hyprland>
- This skill's `deprecations.md` (blur/shadow subcategory migration, `rounding_power`, gestures,
  windowrule) and `window-rules.md` / layer-rule blur (`layerrule { blur = true }`).

**Community config corpus** — the "Battle-tested techniques" section was harvested by reading these
`hyprland.conf` / nix / Lua-wrapper configs directly. Grouped by what they best demonstrate:

- *Two-stop gradient borders + rotating `borderangle` + wind/winIn/winOut beziers*: prasanthrangan/hyprdots (`Configs/.config/hypr/themes/theme.conf`, `animations/animations-default.conf` — origin of the `wind` family + the one-shot `borderangle … once`), HyDE-Project/HyDE (`Configs/.config/hypr/themes/theme.conf`, swappable `animations/*.conf` presets), JaKooLit/Hyprland-Dots (`UserConfigs/UserDecorations.conf` + `UserAnimations.conf` — `$color12` shadow tint, `borderangle … loop`), typecraft-dev/dotfiles (`$mauve $flamingo 90deg`, `borderangle` loop with near-instant windows).
- *Material Design 3 motion + borderless rounding*: mylinuxforwork/dotfiles / ml4w (`conf/decorations/default.lua`, `conf/animations/default.lua` — full MD3 bezier set, `rounding_power 2`, `passes 4`), koeqaife/hyprland-material-you "HyprYou" (`hypryou-assets/hyprland/animation.conf` — MD3 decel/accel, `border_size 0`), chadcat7/crystal (MD3 set, `gaps_in = gaps_out = 20` airy borderless).
- *Expressive-spatial / heavy frosted glass*: end-4/dots-hyprland (`dots/.config/hypr/hyprland/general.lua` — `rounding 18`/`rounding_power 2.5`, full `noise`+`contrast`+`vibrancy` blur, "expressive spatial" overshoot beziers; **shell is AGS/Quickshell, inspiration-only — only the decoration/animation values transfer**), linkfrg/dotfiles (`home/desktop/hyprland/general.nix` — `size 12`/`passes 4` glass, one `quart` curve everywhere).
- *Nix frosted preset + spring physics + role-mapped easing*: fufexan/dotfiles (`system/programs/hyprland/{settings,animations}.lua`, `variables.nix` — `spring { mass/stiffness/dampening }`, `passes 4`/`size 7`, `scale 0.97` shadow), sioodmy/dotfiles (`user/wrapped/hypr/configs/Hyprland.nix` — same blur preset, `rounding 0`), Frost-Phoenix/nixos-config (`modules/home/hyprland/settings.nix` — modern `shadow {}` block, `contrast 1.4`, per-property beziers).
- *Flat designer-distro doctrine + single-accent variable*: basecamp/omarchy (`default/hypr/looknfeel.conf` + per-theme `themes/*/hyprland.conf` — `rounding 0`, `$activeBorderColor` reused for window+group border, per-theme terminal opacity), Matt-FTW/dotfiles (`.config/hypr/theme/decoration.conf` — `color`/`color_inactive` shadow depth, selective per-app opacity).
- *Named-palette source convention*: catppuccin/hyprland (`themes/mocha.conf` @ tag `v1.3` — dual `$mauve`/`$mauveAlpha` color forms, semantic neutral ladder), SolDoesTech/HyprV4 (`HyprV/hypr/hyprland.conf` — tutorial-grade solid-accent starter; note its `drop_shadow`/`shadow_range` is the deprecated flat form).
- *Window-groups three-tier ladder + matched groupbar pills*: caelestia-dots/caelestia (`hypr/hyprland/group.conf`, `hypr/variables.conf` — `$activeWindowBorderColour` reused on `group:col.border_active` + `col.border_locked_active`, `groupbar { gradient_rounding = 5; gradient_round_only_edges = false; indicator_height = 0 }`), basecamp/omarchy (`default/hypr/looknfeel.conf` — `$activeBorderColor` reused across `general:col.active_border`, `group:col.border_active`, `group:col.border_locked_active`; `groupbar { gradient_rounding = 0 }`), prasanthrangan/hyprdots (`Configs/.config/hypr/themes/theme.conf` — gradient-on-everything: same `rgba(ca9ee6ff) rgba(f2d5cfff) 45deg` on all four group color fields).
- *`$variables.conf` design-system externalisation*: caelestia-dots/caelestia (`hypr/variables.conf` — full sliding-knob set: `$blurEnabled`/`$blurSize`/`$blurPasses`/`$blurXray`/`$blurSpecialWs`/`$shadowEnabled`/`$shadowRange`/`$shadowColour`/`$workspaceGaps`/`$windowGapsIn`/`$windowGapsOut`/`$windowOpacity`/`$windowRounding`/`$windowBorderSize`/`$activeWindowBorderColour`/`$inactiveWindowBorderColour`), mylinuxforwork/dotfiles (`conf/decorations/default.lua` — Lua-table equivalent: `hl.config({ decoration = { rounding = 10, rounding_power = 2, blur = { size = 4, passes = 4, … } } })`).
- *Compositor fallback bg = palette bg*: caelestia-dots/caelestia (`hypr/hyprland/misc.conf` — `background_color = rgb($surfaceContainer)`), prasanthrangan/hyprdots (theme blocks set `$base` as the background tone). Pre-hyprpaper flash matches the rice instead of jumping to upstream's `0xff111111` near-black.
- *Workspace-slide gutter via `gaps_workspaces`*: end-4/dots-hyprland (`dots/.config/hypr/hyprland/general.lua` — `gaps_workspaces = 50` in `hl.config({ general = { … } })`), caelestia-dots/caelestia (`$workspaceGaps = 20` in `variables.conf`). Only valuable when the workspace animation has a spatial component (`slide`, `slidevert`, `slidefade`); harmless but invisible with `fade`-only.
- *Spring-physics animations via Lua* (0.55+): fufexan/dotfiles (`system/programs/hyprland/animations.lua` — `hl.curve("bounce", { type = "spring", mass = 1, stiffness = 50, dampening = 10 })` + `hl.animation({ leaf = "windows", spring = "bounce", style = "popin 80%" })`). **Lua-only — hyprlang `.conf` `animation =` rejects non-bezier curve names** (verified `handleAnimation` at v0.55.2 line 1421). This rice emits `.conf`, so it's a reference for what's deliberately *not* offered (use overshoot beziers instead).
- *MD3 + full named-bezier set*: mylinuxforwork/dotfiles (`conf/animations/default.lua` — `md3_standard`/`md3_decel`/`md3_accel`/`overshot`/`crazyshot`/`hyprnostretch`/`menu_decel`/`menu_accel`/`easeInOutCirc`/`easeOutCirc`/`easeOutExpo`/`softAcDecel`/`md2` curves all registered, with `style = "popin 60%"` and `style = "slide"` on layer animations).
